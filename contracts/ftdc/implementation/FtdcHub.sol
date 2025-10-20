// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { AddressUpdatable } from "../../utils/implementation/AddressUpdatable.sol";
import { Governed } from "../../governance/implementation/Governed.sol";
import { IGovernanceSettings } from "flare-smart-contracts/contracts/userInterfaces/IGovernanceSettings.sol";
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
contract FtdcHub is IFtdcHub, Governed, AddressUpdatable {

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
     * Constructor.
     * @param _governanceSettings The address of the GovernanceSettings contract.
     * @param _initialGovernance The initial governance address.
     * @param _addressUpdater The address of the AddressUpdater contract.
     */
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        uint16 _minThresholdBIPS,
        uint8 _defaultNumberOfTees
    )
        Governed(_governanceSettings, _initialGovernance) AddressUpdatable(_addressUpdater)
    {
        _setMinThresholdBIPS(_minThresholdBIPS);
        _setDefaultNumberOfTees(_defaultNumberOfTees);
    }

    /**
     * @inheritdoc IFtdcHub
     */
    function requestAttestation(
        uint16 _thresholdBIPS,
        uint256 _numberOfTees,
        address[] memory _teeIds,
        address[] memory _cosigners,
        uint64 _cosignersThreshold,
        bytes32 _attestationType,
        bytes32 _sourceId,
        bytes calldata _requestBody
    )
        external payable
    {
        require(
            _thresholdBIPS == 0 || (minThresholdBIPS <= _thresholdBIPS && _thresholdBIPS <= MAX_BIPS),
            ThresholdInvalid()
        );
        require(
            _numberOfTees == 0 || _teeIds.length == 0 || _numberOfTees == _teeIds.length,
            NumberOfTeesAndTeeIdsInvalid()
        );
        require(_cosigners.length >= _cosignersThreshold, CosignersThresholdInvalid());
        require(_thresholdBIPS == 0 || _thresholdBIPS >= MAX_BIPS / 2 ||
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
        // Send the fee to the reward manager.
        uint256 fee = ftdcRequestFeeConfigurations.getTypeAndSourceFee(_attestationType, _sourceId);
        require(msg.value >= fee, FeeTooLow());
        //slither-disable-next-line arbitrary-send-eth
        rewardManager.receiveRewards{value: fee}(flareSystemsManager.getCurrentRewardEpochId(), false);
        emit AttestationRequested(_attestationType, _sourceId, _requestBody, fee);
        // Create the attestation request message.
        FtdcAttestationRequest memory message = FtdcAttestationRequest({
            header: FtdcRequestHeader({
                attestationType: _attestationType,
                sourceId: _sourceId,
                thresholdBIPS: _thresholdBIPS
            }),
            requestBody: _requestBody
        });

        _sendInstructions(
            teeMachines,
            abi.encode(message),
            _cosigners,
            _cosignersThreshold,
            msg.value - fee
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
        bytes memory _encodedMessage,
        address[] memory _cosigners,
        uint64 _cosignersThreshold,
        uint256 _value
    ) internal {
        teeExtensionRegistry.sendSystemInstructions{value: _value}(
            bytes32(0),
            _teeMachines,
            FTDC_OP_TYPE,
            PROVE,
            _encodedMessage,
            _cosigners,
            _cosignersThreshold
        );
    }

}
