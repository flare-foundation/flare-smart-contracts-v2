// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { FlareUpgradeableBase } from "../../governance/implementation/FlareUpgradeableBase.sol";
import { AddressUpdatable } from "../../utils/implementation/AddressUpdatable.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import { IFdc2Hub, FDC2_OP_TYPE } from "../../userInterfaces/fdc2/IFdc2Hub.sol";
import { IIFlareTeeManager } from "../../tee/interface/IIFlareTeeManager.sol";
import { IMachineManager } from "../../userInterfaces/tee/IMachineManager.sol";
import { IInstructions } from "../../userInterfaces/tee/IInstructions.sol";
import { IFlareSystemsManager } from "../../userInterfaces/IFlareSystemsManager.sol";
import { IIRewardManager } from "../../protocol/interface/IIRewardManager.sol";
import { IFdc2RequestFeeConfigurations } from "../../userInterfaces/fdc2/IFdc2RequestFeeConfigurations.sol";

/**
 * Fdc2Hub is used for requesting FDC2 attestations.
 */
contract Fdc2Hub is IFdc2Hub, FlareUpgradeableBase {

    uint256 internal constant MAX_BIPS = 1e4;
    bytes32 internal constant PROVE = bytes32("PROVE");

    /// FlareTeeManager Diamond contract.
    IIFlareTeeManager public flareTeeManager;
    /// Flare systems manager contract.
    IFlareSystemsManager public flareSystemsManager;
    /// Reward manager contract.
    IIRewardManager public rewardManager;
    /// FDC2 request fee configurations contract.
    IFdc2RequestFeeConfigurations public fdc2RequestFeeConfigurations;

    /// The minimum threshold in BIPS.
    uint16 public minThresholdBIPS;
    /// The default number of TEEs used for attestation.
    uint8 public defaultNumberOfTees;

    /**
     * Constructor that initializes with invalid parameters to prevent direct deployment/updates.
     */
    constructor() FlareUpgradeableBase() {}

    /**
     * Proxyable initialization method. Can be called only once, from the proxy constructor
     * (single call is assured by the `initializer` modifier).
     */
    function initialize(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        uint16 _minThresholdBIPS,
        uint8 _defaultNumberOfTees
    )
        external virtual
        initializer
    {
        FlareUpgradeableBase.initializeBase(_governanceSettings, _initialGovernance, _addressUpdater);

        _setMinThresholdBIPS(_minThresholdBIPS);
        _setDefaultNumberOfTees(_defaultNumberOfTees);
    }

    /**
     * @inheritdoc IFdc2Hub
     */
    function requestAttestation(
        Fdc2AttestationRequest calldata _attestationRequest,
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
        IMachineManager.TeeMachine[] memory teeMachines;
        if (_teeIds.length == 0) {
            if (_numberOfTees == 0) {
                _numberOfTees = defaultNumberOfTees;
            }
            _teeIds = flareTeeManager.getRandomTeeIds(0, _numberOfTees);
            // all random tee machines are in PRODUCTION status and belong to the system extension
            teeMachines = new IMachineManager.TeeMachine[](_teeIds.length);
            for (uint256 i = 0; i < _teeIds.length; i++) {
                teeMachines[i] = flareTeeManager.getTeeMachine(_teeIds[i]);
            }
        } else {
            teeMachines = new IMachineManager.TeeMachine[](_teeIds.length);
            // For all TEE machines check their status and that they belong to the system extension.
            for (uint256 i = 0; i < _teeIds.length; i++) {
                address teeId = _teeIds[i];
                // check for duplicated teeIds
                for (uint256 j = i + 1; j < _teeIds.length; j++) {
                    require(teeId != _teeIds[j], DuplicatedTeeId(teeId));
                }
                // check the TEE machine status
                IMachineManager.TeeStatus status = flareTeeManager.getTeeMachineStatus(teeId);
                if (status == IMachineManager.TeeStatus.PAUSED_FOR_UPGRADE) {
                    // if the TEE machine is PAUSED_FOR_UPGRADE use its replicating TEE machine if exists, else revert
                    address replicatingTeeId = flareTeeManager.getReplicatingTeeId(teeId);
                    require(replicatingTeeId != address(0), TeeMachineNotAvailable());
                    teeMachines[i] = flareTeeManager.getTeeMachine(replicatingTeeId);
                    teeMachines[i].teeId = teeId; // keep the original teeId
                } else {
                    // else require the TEE machine to be in INITIALIZED or PRODUCTION status
                    require(
                        status == IMachineManager.TeeStatus.INITIALIZED ||
                        status == IMachineManager.TeeStatus.PRODUCTION,
                        TeeMachineNotAvailable()
                    );
                    teeMachines[i] = flareTeeManager.getTeeMachine(teeId);
                }
                // check that the TEE machine belongs to the system extension
                require(
                    flareTeeManager.getExtensionId(teeId) == 0,
                    OnlySystemExtensionId(teeId)
                );
            }
        }
        bytes32 attestationType = _attestationRequest.header.attestationType;
        bytes32 sourceId = _attestationRequest.header.sourceId;
        uint256 fee = fdc2RequestFeeConfigurations.getTypeAndSourceFee(attestationType, sourceId);
        require(msg.value >= fee, FeeTooLow());
        //slither-disable-next-line arbitrary-send-eth
        rewardManager.receiveRewards{value: fee}(flareSystemsManager.getCurrentRewardEpochId(), false);

        bytes32 instructionId = _sendRequestAttestationInstructions(
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
    function setMinThresholdBIPS(
        uint16 _minThresholdBIPS
    )
        external
        onlyGovernance
    {
        _setMinThresholdBIPS(_minThresholdBIPS);
    }

    /**
     * Sets the default number of TEEs used for attestation.
     * @param _defaultNumberOfTees The default number of TEEs.
     * Can only be called by the governance.
     */
    function setDefaultNumberOfTees(
        uint8 _defaultNumberOfTees
    )
        external
        onlyGovernance
    {
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
        flareTeeManager = IIFlareTeeManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareTeeManager"));
        flareSystemsManager = IFlareSystemsManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsManager"));
        rewardManager = IIRewardManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "RewardManager"));
        fdc2RequestFeeConfigurations = IFdc2RequestFeeConfigurations(
            _getContractAddress(_contractNameHashes, _contractAddresses, "Fdc2RequestFeeConfigurations"));
    }

    function _setMinThresholdBIPS(
        uint16 _minThresholdBIPS
    )
        internal
    {
        require(0 < _minThresholdBIPS && _minThresholdBIPS <= MAX_BIPS, MinThresholdInvalid());
        minThresholdBIPS = _minThresholdBIPS;
        emit MinThresholdBIPSSet(_minThresholdBIPS);
    }

    function _setDefaultNumberOfTees(
        uint8 _defaultNumberOfTees
    )
        internal
    {
        require(_defaultNumberOfTees > 0, DefaultNumberOfTeesZero());
        defaultNumberOfTees = _defaultNumberOfTees;
        emit DefaultNumberOfTeesSet(_defaultNumberOfTees);
    }

    function _sendRequestAttestationInstructions(
        IMachineManager.TeeMachine[] memory _teeMachines,
        bytes memory _message,
        address[] memory _cosigners,
        uint64 _cosignersThreshold,
        address _claimBackAddress,
        uint256 _instructionsFee
    )
        internal
        returns (bytes32 _instructionId)
    {
        return flareTeeManager.sendSystemInstructions{value: _instructionsFee}(
            bytes32(0),
            _teeMachines,
            IInstructions.TeeInstructionParams(
                FDC2_OP_TYPE,
                PROVE,
                _message,
                _cosigners,
                _cosignersThreshold,
                _claimBackAddress
            )
        );
    }
}
