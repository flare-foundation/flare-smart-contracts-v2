// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { TeeBase } from "./TeeBase.sol";
import { IITeeMachineRegistry } from "../interface/IITeeMachineRegistry.sol";
import { ITeeVersionManager } from "../../userInterfaces/tee/ITeeVersionManager.sol";
import { ITeeVerification } from "../../userInterfaces/tee/ITeeVerification.sol";
import { ITeeMachineRegistry } from "../../userInterfaces/tee/ITeeMachineRegistry.sol";
import { ITeeReplication } from "../../userInterfaces/tee/ITeeReplication.sol";
import { ITeeExtensionRegistry } from "../../userInterfaces/tee/ITeeExtensionRegistry.sol";
import { ITeeAvailabilityCheck } from "../../userInterfaces/ftdc/ITeeAvailabilityCheck.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import { AddressUpdatable } from "../../utils/implementation/AddressUpdatable.sol";

/**
 * TeeReplication is used for replication of TEE machines.
 */
contract TeeReplication is ITeeReplication, TeeBase {

    bytes32 public constant REG_OP_TYPE = bytes32("F_REG");
    bytes32 public constant TO_PAUSE_FOR_UPGRADE = bytes32("TO_PAUSE_FOR_UPGRADE");
    bytes32 public constant REPLICATE_FROM = bytes32("REPLICATE_FROM");

    /// TEE extension registry contract.
    ITeeExtensionRegistry public teeExtensionRegistry;
    /// TEE version manager contract.
    ITeeVersionManager public teeVersionManager;
    /// TEE machine registry contract.
    IITeeMachineRegistry public teeMachineRegistry;
    /// TEE verification contract.
    ITeeVerification public teeVerification;

    /// The minimum duration (in paused status) before a TEE machine can be upgraded.
    uint256 public pauseBeforeUpgradeMinDurationSeconds;

    mapping(address oldTeeId => address newTeeId) public replications;
    /// Proposed new TEE owner.
    mapping(address teeId => address) public proposedTeeOwner;

    modifier onlyOwner(address _teeId) {
        _checkOnlyOwner(_teeId);
        _;
    }

    /**
     * Constructor that initializes with invalid parameters to prevent direct deployment/updates.
     */
    constructor() TeeBase() {}

    /**
     * Proxyable initialization method. Can be called only once, from the proxy constructor
     * (single call is assured by GovernedBase.initialise).
     */
    function initialize(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        uint256 _pauseBeforeUpgradeMinDurationSeconds
    )
        external
    {
        TeeBase.initializeBase(_governanceSettings, _initialGovernance, _addressUpdater);
        _setPauseBeforeUpgradeMinDurationSeconds(_pauseBeforeUpgradeMinDurationSeconds);
    }

    /**
     * @inheritdoc ITeeReplication
     */
    function toPauseForUpgrade(address _teeId, address _claimBackAddress)
        external payable
        onlyOwner(_teeId)
    {
        ITeeMachineRegistry.TeeStatus status = teeMachineRegistry.getTeeMachineStatus(_teeId);
        _checkTeeStatus(
            status,
            ITeeMachineRegistry.TeeStatus.PAUSED,
            ITeeMachineRegistry.TeeStatus.PAUSED_FOR_UPGRADE
        );
        if (status == ITeeMachineRegistry.TeeStatus.PAUSED) {
            require(
                teeMachineRegistry.getLastStatusChangeTs(_teeId) + pauseBeforeUpgradeMinDurationSeconds <
                block.timestamp,
                TooSoon()
            );
            teeMachineRegistry.changeStatus(_teeId, ITeeMachineRegistry.TeeStatus.PAUSED_FOR_UPGRADE);
        }

        ITeeMachineRegistry.TeeMachineWithAttestationData memory teeMachine =
            _getTeeMachineWithAttestationData(_teeId);
        PauseForUpgrade memory message = PauseForUpgrade({
            teeId: _teeId,
            initialTeeId: teeMachine.initialTeeId
        });
        address[] memory teeIds = new address[](1);
        teeIds[0] = _teeId;
        _sendInstructions(
            teeIds,
            TO_PAUSE_FOR_UPGRADE,
            abi.encode(message),
            _claimBackAddress
        );
        emit TeeMachinePausedForUpgrade(_teeId);
    }

    /**
     * @inheritdoc ITeeReplication
     */
    function replicateFrom(
        address _oldTeeId,
        ITeeAvailabilityCheck.Proof calldata _proof,
        uint256 _teeUpgradeId,
        address _claimBackAddress
    )
        external payable
        onlyOwner(_oldTeeId)
        onlyOwner(_proof.requestBody.teeId)
    {
        address newTeeId = _proof.requestBody.teeId;
        ITeeMachineRegistry.TeeStatus oldStatus = teeMachineRegistry.getTeeMachineStatus(_oldTeeId);
        _checkTeeStatus(oldStatus, ITeeMachineRegistry.TeeStatus.PAUSED_FOR_UPGRADE);
        ITeeMachineRegistry.TeeStatus newStatus = teeMachineRegistry.getTeeMachineStatus(newTeeId);
        require(
            newStatus == ITeeMachineRegistry.TeeStatus.INITIALIZED ||
            (replications[_oldTeeId] == newTeeId && newStatus == ITeeMachineRegistry.TeeStatus.REPLICATING), // retry
            InvalidTeeStatus()
        );
        uint256 extensionId = teeMachineRegistry.getExtensionId(_oldTeeId);
        require(extensionId == teeMachineRegistry.getExtensionId(newTeeId), ExtensionMismatch());
        _checkCodeHashPlatformSupported(extensionId, newTeeId);
        _checkTeeMachinesCompatible(_teeUpgradeId, extensionId, _oldTeeId, newTeeId);
        _validateAvailabilityCheckStatus(_proof.responseBody.status);
        _validateAvailabilityCheckTs(newTeeId, _proof.header.timestamp);
        require(_proof.responseBody.state.systemStateVersion != bytes32(0), InvalidSystemStateVersion());
        require(teeVerification.verifyAvailabilityCheckProof(_proof), InvalidResponseData());

        replications[_oldTeeId] = newTeeId;
        teeMachineRegistry.changeStatus(newTeeId, ITeeMachineRegistry.TeeStatus.REPLICATING);

        ReplicateTeeMachine memory message = ReplicateTeeMachine({
            oldTeeMachine: _getTeeMachineWithAttestationData(_oldTeeId),
            newTeeMachine: _getTeeMachineWithAttestationData(newTeeId)
        });
        address[] memory teeIds = new address[](2);
        teeIds[0] = _oldTeeId;
        teeIds[1] = newTeeId;
        _sendInstructions(
            teeIds,
            REPLICATE_FROM,
            abi.encode(message),
            _claimBackAddress
        );
        emit TeeMachineReplicationTriggered(_oldTeeId, newTeeId, _teeUpgradeId);
    }

    /**
     * @inheritdoc ITeeReplication
     */
    function confirmReplicate(
        address _newTeeId,
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        external
        onlyOwner(_proof.requestBody.teeId)
        onlyOwner(_newTeeId)
    {
        address oldTeeId = _proof.requestBody.teeId;
        // in case multiple replications are triggered only the last one can be confirmed
        require(replications[oldTeeId] == _newTeeId, ReplicationNotValid());
        delete replications[oldTeeId];
        require(_proof.responseBody.state.systemStateVersion != bytes32(0), InvalidSystemStateVersion());
        teeMachineRegistry.replicate(_newTeeId, _proof);
        emit TeeMachineReplicationConfirmed(oldTeeId, _newTeeId);
    }

    /**
     * Sets the minimum duration (in paused status) before a TEE machine can be upgraded.
     * @param _pauseBeforeUpgradeMinDurationSeconds The minimum duration in seconds.
     */
    function setPauseBeforeUpgradeMinDurationSeconds(
        uint256 _pauseBeforeUpgradeMinDurationSeconds
    )
        external onlyGovernance
    {
        _setPauseBeforeUpgradeMinDurationSeconds(_pauseBeforeUpgradeMinDurationSeconds);
    }

    /**
     * @inheritdoc ITeeReplication
     */
    function getReplicatingTeeId(address _oldTeeId) external view returns(address) {
        return replications[_oldTeeId];
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
        teeExtensionRegistry = ITeeExtensionRegistry(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeExtensionRegistry"));
        teeVersionManager = ITeeVersionManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeVersionManager"));
        teeMachineRegistry = IITeeMachineRegistry(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeMachineRegistry"));
        teeVerification = ITeeVerification(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeVerification"));
    }

    function _setPauseBeforeUpgradeMinDurationSeconds(
        uint256 _pauseBeforeUpgradeMinDurationSeconds
    )
        internal
    {
        _validateDuration(_pauseBeforeUpgradeMinDurationSeconds, 1 minutes, 1 days);
        pauseBeforeUpgradeMinDurationSeconds = _pauseBeforeUpgradeMinDurationSeconds;
        emit PauseBeforeUpgradeMinDurationSecondsSet(_pauseBeforeUpgradeMinDurationSeconds);
    }

    function _sendInstructions(
        address[] memory _teeIds,
        bytes32 _opCommand,
        bytes memory _message,
        address _claimBackAddress
    )
        internal
    {
        teeExtensionRegistry.sendInstructions{value: msg.value}(
            _teeIds,
            REG_OP_TYPE,
            _opCommand,
            _message,
            new address[](0),
            0,
            _claimBackAddress
        );
    }

    function _validateAvailabilityCheckTs(address _teeId, uint256 _availabilityCheckTs) internal view {
        require(_availabilityCheckTs >= teeMachineRegistry.getLastStatusChangeTs(_teeId),
            AvailabilityCheckTimestampInvalid()
        );
    }

    function _getTeeMachineWithAttestationData(address _teeId)
        internal view
        returns(ITeeMachineRegistry.TeeMachineWithAttestationData memory)
    {
        return teeMachineRegistry.getTeeMachineWithAttestationData(_teeId);
    }

    function _checkCodeHashPlatformSupported(
        uint256 _extensionId,
        address _teeId
    )
        internal view
    {
        ITeeMachineRegistry.TeeMachineWithAttestationData memory teeMachine =
            _getTeeMachineWithAttestationData(_teeId);
        require(
            teeExtensionRegistry.isCodeHashPlatformSupported(_extensionId, teeMachine.codeHash, teeMachine.platform),
            VersionNotSupported()
        );
    }

    function _checkTeeMachinesCompatible(
        uint256 _teeUpgradeId,
        uint256 _extensionId,
        address _oldTeeId,
        address _newTeeId
    )
        internal view
    {
        ITeeMachineRegistry.TeeMachineWithAttestationData memory oldTeeMachine =
            _getTeeMachineWithAttestationData(_oldTeeId);
        ITeeMachineRegistry.TeeMachineWithAttestationData memory newTeeMachine =
            _getTeeMachineWithAttestationData(_newTeeId);
        require(
            teeVersionManager.isTeeUpgradePathValid(
                _teeUpgradeId,
                _extensionId,
                oldTeeMachine.codeHash,
                oldTeeMachine.platform,
                newTeeMachine.codeHash,
                newTeeMachine.platform
            ),
            InvalidUpgradePath()
        );
        require(teeVersionManager.isTeeUpgradeSigned(_teeUpgradeId),
            TeeUpgradeNotSigned()
        );
    }

    function _checkOnlyOwner(address _teeId) internal view {
        require(msg.sender == teeMachineRegistry.getTeeMachineOwner(_teeId), OnlyMachineOwner());
    }

    function _checkTeeStatus(
        ITeeMachineRegistry.TeeStatus _actualStatus,
        ITeeMachineRegistry.TeeStatus _expectedStatus
    )
        internal pure
    {
        require(_actualStatus == _expectedStatus, InvalidTeeStatus());
    }

    function _checkTeeStatus(
        ITeeMachineRegistry.TeeStatus _actualStatus,
        ITeeMachineRegistry.TeeStatus _expectedStatus1,
        ITeeMachineRegistry.TeeStatus _expectedStatus2
    )
        internal pure
    {
        require(_actualStatus == _expectedStatus1 || _actualStatus == _expectedStatus2, InvalidTeeStatus());
    }

    function _validateAvailabilityCheckStatus(
        ITeeAvailabilityCheck.AvailabilityCheckStatus _status
    )
        internal pure
    {
        require(_status == ITeeAvailabilityCheck.AvailabilityCheckStatus.OK, InvalidAvailabilityCheckStatus());
    }

    function _validateDuration(
        uint256 _duration,
        uint256 _minDuration,
        uint256 _maxDuration
    )
        internal pure
    {
        require(_minDuration <= _duration && _duration <= _maxDuration, InvalidDuration());
    }
}
