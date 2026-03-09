// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { AddressUpdatable } from "../../utils/implementation/AddressUpdatable.sol";
import { GovernedProxyImplementation } from "../../governance/implementation/GovernedProxyImplementation.sol";
import { GovernedBase } from "../../governance/implementation/GovernedBase.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import { IFtdcHub } from "../../userInterfaces/ftdc/IFtdcHub.sol";
import { IITeeExtensionRegistry } from "../../tee/interface/IITeeExtensionRegistry.sol";
import { ITeeMachineRegistry } from  "../../userInterfaces/tee/ITeeMachineRegistry.sol";
import { ITeeReplication } from "../../userInterfaces/tee/ITeeReplication.sol";
import { IFlareSystemsManager } from "../../userInterfaces/IFlareSystemsManager.sol";
import { IIRewardManager } from "../../protocol/interface/IIRewardManager.sol";
import { IFtdcRequestFeeConfigurations } from "../../userInterfaces/ftdc/IFtdcRequestFeeConfigurations.sol";

/**
 * FtdcHub is used for requesting FTDC attestations.
 */
contract FtdcHub is IFtdcHub, GovernedProxyImplementation, UUPSUpgradeable, AddressUpdatable {

    uint256 internal constant MAX_BIPS = 1e4;
    bytes32 public constant FTDC_OP_TYPE = bytes32("F_FTDC");
    bytes32 public constant PROVE = bytes32("PROVE");

    /// TEE extension registry contract.
    IITeeExtensionRegistry public teeExtensionRegistry;
    /// TEE machine registry contract.
    ITeeMachineRegistry public teeMachineRegistry;
    /// TEE replication contract.
    ITeeReplication public teeReplication;
    /// Flare systems manager contract.
    IFlareSystemsManager public flareSystemsManager;
    /// Reward manager contract.
    IIRewardManager public rewardManager;
    /// FTDC request fee configurations contract.
    IFtdcRequestFeeConfigurations public ftdcRequestFeeConfigurations;

    /// The minimum threshold in BIPS.
    uint16 public minThresholdBIPS;
    /// The default number of TEEs used for attestation.
    uint8 public defaultNumberOfTees;

    /**
     * Constructor that initializes with invalid parameters to prevent direct deployment/updates.
     */
    constructor() GovernedProxyImplementation() AddressUpdatable(address(0)) {}

    /**
     * Proxyable initialization method. Can be called only once, from the proxy constructor
     * (single call is assured by GovernedBase.initialise).
     */
    function initialize(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        uint16 _minThresholdBIPS,
        uint8 _defaultNumberOfTees
    )
        external virtual
    {
        GovernedBase.initialise(_governanceSettings, _initialGovernance);
        AddressUpdatable.setAddressUpdaterValue(_addressUpdater);

        _setMinThresholdBIPS(_minThresholdBIPS);
        _setDefaultNumberOfTees(_defaultNumberOfTees);
    }

    /**
     * @inheritdoc IFtdcHub
     */
    function requestAttestation(
        FtdcAttestationRequest calldata _attestationRequest,
        uint256 _numberOfTees,
        address[] memory _teeIds,
        address[] memory _cosigners,
        uint64 _cosignersThreshold,
        address _claimBackAddress
    )
        external payable
    {
        // thresholdBIPS == 0 uses signing policy threshold
        uint16 thresholdBIPS = _attestationRequest.header.thresholdBIPS;
        require(
            thresholdBIPS == 0 || (minThresholdBIPS <= thresholdBIPS && thresholdBIPS <= MAX_BIPS),
            ThresholdInvalid()
        );
        require(
            _numberOfTees == 0 || _teeIds.length == 0 || _numberOfTees == _teeIds.length,
            NumberOfTeesAndTeeIdsInvalid()
        );
        require(_cosigners.length >= _cosignersThreshold, CosignersThresholdInvalid());
        require(thresholdBIPS == 0 || thresholdBIPS >= MAX_BIPS / 2 ||
            _cosignersThreshold > _cosigners.length / 2, MultipleResponsesPossible());
        ITeeMachineRegistry.TeeMachine[] memory teeMachines;
        if (_teeIds.length == 0) {
            if (_numberOfTees == 0) {
                _numberOfTees = defaultNumberOfTees;
            }
            _teeIds = teeMachineRegistry.getRandomTeeIds(0, _numberOfTees);
            // all random tee machines are in PRODUCTION status and belong to the system extension
            teeMachines = new ITeeMachineRegistry.TeeMachine[](_teeIds.length);
            for (uint256 i = 0; i < _teeIds.length; i++) {
                teeMachines[i] = teeMachineRegistry.getTeeMachine(_teeIds[i]);
            }
        } else {
            teeMachines = new ITeeMachineRegistry.TeeMachine[](_teeIds.length);
            // For all TEE machines check their status and that they belong to the system extension.
            for (uint256 i = 0; i < _teeIds.length; i++) {
                address teeId = _teeIds[i];
                // check for duplicated teeIds
                for (uint256 j = i + 1; j < _teeIds.length; j++) {
                    require(teeId != _teeIds[j], DuplicatedTeeId(teeId));
                }
                // check the TEE machine status
                ITeeMachineRegistry.TeeStatus status = teeMachineRegistry.getTeeMachineStatus(teeId);
                if (status == ITeeMachineRegistry.TeeStatus.PAUSED_FOR_UPGRADE) {
                    // if the TEE machine is PAUSED_FOR_UPGRADE use its replicating TEE machine if exists, else revert
                    address replicatingTeeId = teeReplication.getReplicatingTeeId(teeId);
                    require(replicatingTeeId != address(0), TeeMachineNotAvailable());
                    teeMachines[i] = teeMachineRegistry.getTeeMachine(replicatingTeeId);
                    teeMachines[i].teeId = teeId; // keep the original teeId
                } else {
                    // else require the TEE machine to be in INITIALIZED or PRODUCTION status
                    require(
                        status == ITeeMachineRegistry.TeeStatus.INITIALIZED ||
                        status == ITeeMachineRegistry.TeeStatus.PRODUCTION,
                        TeeMachineNotAvailable()
                    );
                    teeMachines[i] = teeMachineRegistry.getTeeMachine(teeId);
                }
                // check that the TEE machine belongs to the system extension
                require(
                    teeMachineRegistry.getExtensionId(teeId) == 0,
                    OnlySystemExtensionId(teeId)
                );
            }
        }
        bytes32 attestationType = _attestationRequest.header.attestationType;
        bytes32 sourceId = _attestationRequest.header.sourceId;
        uint256 fee = ftdcRequestFeeConfigurations.getTypeAndSourceFee(attestationType, sourceId);
        require(msg.value >= fee, FeeTooLow());
        //slither-disable-next-line arbitrary-send-eth
        rewardManager.receiveRewards{value: fee}(flareSystemsManager.getCurrentRewardEpochId(), false);

        bytes32 instructionId = _sendInstructions(
            teeMachines,
            abi.encode(_attestationRequest),
            _cosigners,
            _cosignersThreshold,
            _claimBackAddress,
            msg.value - fee
        );
        emit AttestationRequested(
            instructionId,
            attestationType,
            sourceId,
            _attestationRequest.header.proofOwner,
            _claimBackAddress,
            fee
        );
    }

    /**
     * Sets the minimum threshold in BIPS.
     * @param _minThresholdBIPS The minimum threshold in BIPS.
     * Can only be called by the governance.
     */
    function setMinThresholdBIPS(uint16 _minThresholdBIPS) external onlyGovernance {
        _setMinThresholdBIPS(_minThresholdBIPS);
    }

    /**
     * Sets the default number of TEEs used for attestation.
     * @param _defaultNumberOfTees The default number of TEEs.
     * Can only be called by the governance.
     */
    function setDefaultNumberOfTees(uint8 _defaultNumberOfTees) external onlyGovernance {
        _setDefaultNumberOfTees(_defaultNumberOfTees);
    }

    /**
     * Returns the current implementation address.
     * @return The current implementation address.
     */
    function implementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    /**
     * @inheritdoc UUPSUpgradeable
     * @dev Only governance can call this method.
     */
    function upgradeToAndCall(address _newImplementation, bytes memory _data)
        public payable virtual override
        onlyGovernance
    {
        super.upgradeToAndCall(_newImplementation, _data);
    }

    /**
     * Unused. Present just to satisfy UUPSUpgradeable requirement.
     * The real check is in onlyGovernance modifier on upgradeToAndCall.
     */
    function _authorizeUpgrade(address _newImplementation) internal virtual override {}

    /**
     * @inheritdoc AddressUpdatable
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal override
    {
        teeExtensionRegistry = IITeeExtensionRegistry(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeExtensionRegistry"));
        teeMachineRegistry = ITeeMachineRegistry(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeMachineRegistry"));
        teeReplication = ITeeReplication(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeReplication"));
        flareSystemsManager = IFlareSystemsManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsManager"));
        rewardManager = IIRewardManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "RewardManager"));
        ftdcRequestFeeConfigurations = IFtdcRequestFeeConfigurations(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FtdcRequestFeeConfigurations"));
    }

    function _setMinThresholdBIPS(uint16 _minThresholdBIPS) internal {
        require(0 < _minThresholdBIPS && _minThresholdBIPS <= MAX_BIPS, MinThresholdInvalid());
        minThresholdBIPS = _minThresholdBIPS;
        emit MinThresholdBIPSSet(_minThresholdBIPS);
    }

    function _setDefaultNumberOfTees(uint8 _defaultNumberOfTees) internal {
        require(_defaultNumberOfTees > 0, DefaultNumberOfTeesZero());
        defaultNumberOfTees = _defaultNumberOfTees;
        emit DefaultNumberOfTeesSet(_defaultNumberOfTees);
    }

    function _sendInstructions(
        ITeeMachineRegistry.TeeMachine[] memory _teeMachines,
        bytes memory _message,
        address[] memory _cosigners,
        uint64 _cosignersThreshold,
        address _claimBackAddress,
        uint256 _instructionsFee
    )
        internal
        returns (bytes32 _instructionId)
    {
        return teeExtensionRegistry.sendSystemInstructions{value: _instructionsFee}(
            bytes32(0),
            _teeMachines,
            FTDC_OP_TYPE,
            PROVE,
            _message,
            _cosigners,
            _cosignersThreshold,
            _claimBackAddress
        );
    }
}
