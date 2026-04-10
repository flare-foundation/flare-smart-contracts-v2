// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IITeeReplicationFacet } from "../interface/IITeeReplicationFacet.sol";
import { ITeeReplicationFacet } from "../../userInterfaces/tee/ITeeReplicationFacet.sol";
import { ITeeExtensionRegistryFacet } from "../../userInterfaces/tee/ITeeExtensionRegistryFacet.sol";
import { ITeeMachineRegistryFacet, REG_OP_TYPE } from "../../userInterfaces/tee/ITeeMachineRegistryFacet.sol";
import { ITeeAvailabilityCheck } from "../../userInterfaces/fdc2/ITeeAvailabilityCheck.sol";
import { ITeeCommonErrors } from "../../userInterfaces/tee/ITeeCommonErrors.sol";
import { TeeReplication } from "../library/TeeReplication.sol";
import { TeeMachineRegistry } from "../library/TeeMachineRegistry.sol";
import { TeeVerification } from "../library/TeeVerification.sol";
import { TeeVersionManager } from "../library/TeeVersionManager.sol";
import { TeeInstructionSender } from "../library/TeeInstructionSender.sol";
import { GovernedFacet } from "./GovernedFacet.sol";

/**
 * @title TeeReplicationFacet
 * @notice Facet for TEE machine replication and upgrade management.
 */
contract TeeReplicationFacet is IITeeReplicationFacet, GovernedFacet {

    bytes32 internal constant TO_PAUSE_FOR_UPGRADE = bytes32("TO_PAUSE_FOR_UPGRADE");
    bytes32 internal constant REPLICATE_FROM = bytes32("REPLICATE_FROM");

    modifier onlyMachineOwner(address _teeId) {
        require(
            msg.sender == TeeMachineRegistry.getTeeMachineOwner(_teeId),
            OnlyMachineOwner()
        );
        _;
    }

    /// @inheritdoc ITeeReplicationFacet
    function toPauseForUpgrade(
        address _teeId,
        address _claimBackAddress
    )
        external payable
        onlyMachineOwner(_teeId)
    {
        ITeeMachineRegistryFacet.TeeStatus status = TeeMachineRegistry.getTeeMachineStatus(_teeId);
        TeeMachineRegistry.checkTeeStatus(
            status,
            ITeeMachineRegistryFacet.TeeStatus.PAUSED,
            ITeeMachineRegistryFacet.TeeStatus.PAUSED_FOR_UPGRADE
        );
        if (status == ITeeMachineRegistryFacet.TeeStatus.PAUSED) {
            TeeReplication.State storage s = TeeReplication.getState();
            require(
                TeeMachineRegistry.getLastStatusChangeTs(_teeId) +
                    s.pauseBeforeUpgradeMinDurationSeconds < block.timestamp,
                TooSoon()
            );
            TeeMachineRegistry.changeStatus(_teeId, ITeeMachineRegistryFacet.TeeStatus.PAUSED_FOR_UPGRADE);
        }

        ITeeMachineRegistryFacet.TeeMachineWithAttestationData memory teeMachine =
            TeeMachineRegistry.getTeeMachineWithAttestationData(_teeId);
        PauseForUpgrade memory message = PauseForUpgrade({
            teeId: _teeId,
            initialTeeId: teeMachine.initialTeeId
        });
        address[] memory teeIds = new address[](1);
        teeIds[0] = _teeId;
        _sendInstructions(teeIds, TO_PAUSE_FOR_UPGRADE, abi.encode(message), _claimBackAddress);
        emit TeeMachinePausedForUpgrade(_teeId);
    }

    /// @inheritdoc ITeeReplicationFacet
    function replicateFrom(
        address _oldTeeId,
        ITeeAvailabilityCheck.Proof calldata _proof,
        uint256 _teeUpgradeId,
        address _claimBackAddress
    )
        external payable
        onlyMachineOwner(_oldTeeId)
        onlyMachineOwner(_proof.requestBody.teeId)
    {
        address newTeeId = _proof.requestBody.teeId;
        ITeeMachineRegistryFacet.TeeStatus oldStatus = TeeMachineRegistry.getTeeMachineStatus(_oldTeeId);
        TeeMachineRegistry.checkTeeStatus(oldStatus, ITeeMachineRegistryFacet.TeeStatus.PAUSED_FOR_UPGRADE);
        ITeeMachineRegistryFacet.TeeStatus newStatus = TeeMachineRegistry.getTeeMachineStatus(newTeeId);
        require(
            newStatus == ITeeMachineRegistryFacet.TeeStatus.INITIALIZED ||
            (TeeReplication.getReplicatingTeeId(_oldTeeId) == newTeeId &&
                newStatus == ITeeMachineRegistryFacet.TeeStatus.REPLICATING), // retry
            ITeeMachineRegistryFacet.InvalidTeeStatus()
        );
        uint256 extensionId = TeeMachineRegistry.getExtensionId(_oldTeeId);
        require(extensionId == TeeMachineRegistry.getExtensionId(newTeeId), ExtensionMismatch());
        ITeeMachineRegistryFacet.TeeMachineWithAttestationData memory newTeeMachine =
            TeeMachineRegistry.getTeeMachineWithAttestationData(newTeeId);
        TeeMachineRegistry.checkCodeHashPlatformSupported(extensionId, newTeeMachine.codeHash, newTeeMachine.platform);
        ITeeMachineRegistryFacet.TeeMachineWithAttestationData memory oldTeeMachine =
            TeeMachineRegistry.getTeeMachineWithAttestationData(_oldTeeId);
        _checkTeeMachinesCompatible(_teeUpgradeId, extensionId, oldTeeMachine, newTeeMachine);
        TeeMachineRegistry.validateAvailabilityCheckStatus(_proof.responseBody.status);
        TeeMachineRegistry.validateAvailabilityCheckTs(newTeeId, _proof.header.timestamp);
        require(_proof.responseBody.state.systemStateVersion != bytes32(0), InvalidSystemStateVersion());

        require(
            TeeVerification.verifyAvailabilityCheckProof(newTeeMachine, newStatus, _proof),
            ITeeCommonErrors.InvalidResponseData()
        );

        TeeReplication.getState().replicatingTeeIds[_oldTeeId] = newTeeId;
        TeeMachineRegistry.changeStatus(newTeeId, ITeeMachineRegistryFacet.TeeStatus.REPLICATING);

        ReplicateTeeMachine memory message = ReplicateTeeMachine({
            oldTeeMachine: oldTeeMachine,
            newTeeMachine: newTeeMachine
        });
        address[] memory teeIds = new address[](2);
        teeIds[0] = _oldTeeId;
        teeIds[1] = newTeeId;
        _sendInstructions(teeIds, REPLICATE_FROM, abi.encode(message), _claimBackAddress);
        emit TeeMachineReplicationTriggered(_oldTeeId, newTeeId, _teeUpgradeId);
    }

    /// @inheritdoc ITeeReplicationFacet
    function confirmReplicate(
        address _newTeeId,
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        external
        onlyMachineOwner(_proof.requestBody.teeId)
        onlyMachineOwner(_newTeeId)
    {
        address oldTeeId = _proof.requestBody.teeId;
        require(TeeReplication.getReplicatingTeeId(oldTeeId) == _newTeeId, ReplicationNotValid());
        delete TeeReplication.getState().replicatingTeeIds[oldTeeId];
        require(
            _proof.responseBody.state.systemStateVersion != bytes32(0),
            InvalidSystemStateVersion()
        );
        _replicate(_newTeeId, _proof);
        emit TeeMachineReplicationConfirmed(oldTeeId, _newTeeId);
    }

    /// @inheritdoc IITeeReplicationFacet
    function setPauseBeforeUpgradeMinDurationSeconds(
        uint256 _pauseBeforeUpgradeMinDurationSeconds
    )
        external
        onlyGovernance
    {
        TeeReplication.setPauseBeforeUpgradeMinDurationSeconds(_pauseBeforeUpgradeMinDurationSeconds);
    }

    /// @inheritdoc ITeeReplicationFacet
    function getReplicatingTeeId(
        address _oldTeeId
    )
        external view
        returns (address)
    {
        return TeeReplication.getReplicatingTeeId(_oldTeeId);
    }

    // =========================================================================
    // Private helpers
    // =========================================================================

    function _replicate(
        address _newTeeId,
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        private
    {
        address oldTeeId = _proof.requestBody.teeId;
        TeeMachineRegistry.TeeMachineState storage oldState =
            TeeMachineRegistry.getTeeMachineState(oldTeeId);
        TeeMachineRegistry.TeeMachineState storage newState =
            TeeMachineRegistry.getTeeMachineState(_newTeeId);

        TeeMachineRegistry.checkTeeStatus(
            oldState.status, ITeeMachineRegistryFacet.TeeStatus.PAUSED_FOR_UPGRADE
        );
        TeeMachineRegistry.checkTeeStatus(
            newState.status, ITeeMachineRegistryFacet.TeeStatus.REPLICATING
        );
        assert(_newTeeId == newState.initialTeeId);
        require(oldState.owner == newState.owner, ITeeMachineRegistryFacet.OwnerMismatch());
        require(
            oldState.extensionId == newState.extensionId,
            ITeeCommonErrors.ExtensionIdMismatch()
        );
        TeeMachineRegistry.checkCodeHashPlatformSupported(
            newState.extensionId, newState.codeHash, newState.platform
        );
        TeeMachineRegistry.validateAvailabilityCheckStatus(_proof.responseBody.status);
        TeeMachineRegistry.validateAvailabilityCheckTs(_newTeeId, _proof.header.timestamp);

        // copy TEE machine data from new TEE machine to old TEE machine
        oldState.initialTeeId = newState.initialTeeId;
        oldState.teeProxyId = newState.teeProxyId;
        oldState.codeHash = newState.codeHash;
        oldState.platform = newState.platform;
        oldState.url = newState.url;
        oldState.initialSigningPolicyId = _proof.responseBody.initialSigningPolicyId;
        oldState.status = ITeeMachineRegistryFacet.TeeStatus.REPLICATING;

        // delete the new TEE machine state
        TeeMachineRegistry.State storage regState = TeeMachineRegistry.getState();
        delete regState.teeMachineStates[_newTeeId];

        // verify the availability check proof for the updated TEE machine data
        ITeeMachineRegistryFacet.TeeMachineWithAttestationData memory oldTeeMachine =
            ITeeMachineRegistryFacet.TeeMachineWithAttestationData({
                teeId: oldTeeId,
                initialTeeId: oldState.initialTeeId,
                url: oldState.url,
                codeHash: oldState.codeHash,
                platform: oldState.platform
            });
        require(
            TeeVerification.verifyAvailabilityCheckProof(
                oldTeeMachine, ITeeMachineRegistryFacet.TeeStatus.REPLICATING, _proof
            ),
            ITeeCommonErrors.InvalidResponseData()
        );

        // put TEE machine into production
        TeeMachineRegistry.changeStatus(oldTeeId, ITeeMachineRegistryFacet.TeeStatus.PRODUCTION);
        TeeVerification.extendAvailability(_proof);
    }

    function _sendInstructions(
        address[] memory _teeIds,
        bytes32 _opCommand,
        bytes memory _message,
        address _claimBackAddress
    )
        private
    {
        TeeInstructionSender.sendInstructions(
            bytes32(0),
            _teeIds,
            ITeeExtensionRegistryFacet.TeeInstructionParams(
                REG_OP_TYPE,
                _opCommand,
                _message,
                new address[](0),
                0,
                _claimBackAddress
            )
        );
    }

    function _checkTeeMachinesCompatible(
        uint256 _teeUpgradeId,
        uint256 _extensionId,
        ITeeMachineRegistryFacet.TeeMachineWithAttestationData memory _oldTeeMachine,
        ITeeMachineRegistryFacet.TeeMachineWithAttestationData memory _newTeeMachine
    )
        private view
    {
        require(
            TeeVersionManager.isTeeUpgradePathValid(
                _teeUpgradeId,
                _extensionId,
                _oldTeeMachine.codeHash,
                _oldTeeMachine.platform,
                _newTeeMachine.codeHash,
                _newTeeMachine.platform
            ),
            InvalidUpgradePath()
        );
        require(TeeVersionManager.isTeeUpgradeSigned(_teeUpgradeId), TeeUpgradeNotSigned());
    }
}
