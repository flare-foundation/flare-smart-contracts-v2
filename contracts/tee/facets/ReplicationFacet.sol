// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IIReplication } from "../interface/IIReplication.sol";
import { IReplication } from "../../userInterfaces/tee/IReplication.sol";
import { IInstructions } from "../../userInterfaces/tee/IInstructions.sol";
import { IMachineManager, REG_OP_TYPE } from "../../userInterfaces/tee/IMachineManager.sol";
import { ITeeAvailabilityCheck } from "../../userInterfaces/fdc2/ITeeAvailabilityCheck.sol";
import { ITeeCommonErrors } from "../../userInterfaces/tee/ITeeCommonErrors.sol";
import { Replication } from "../library/Replication.sol";
import { MachineManager } from "../library/MachineManager.sol";
import { Verification } from "../library/Verification.sol";
import { UpgradeManager } from "../library/UpgradeManager.sol";
import { Instructions } from "../library/Instructions.sol";
import { FlareGovernedAccess } from "../../governance/implementation/FlareGovernedAccess.sol";

/**
 * @title ReplicationFacet
 * @notice Facet for TEE machine replication and upgrade management.
 */
contract ReplicationFacet is IIReplication, FlareGovernedAccess {

    bytes32 internal constant TO_PAUSE_FOR_UPGRADE = bytes32("TO_PAUSE_FOR_UPGRADE");
    bytes32 internal constant REPLICATE_FROM = bytes32("REPLICATE_FROM");

    modifier onlyMachineOwner(address _teeId) {
        require(
            msg.sender == MachineManager.getTeeMachineOwner(_teeId),
            OnlyMachineOwner()
        );
        _;
    }

    /// @inheritdoc IReplication
    function toPauseForUpgrade(
        address _teeId,
        address _claimBackAddress
    )
        external payable
        onlyMachineOwner(_teeId)
    {
        IMachineManager.TeeStatus status = MachineManager.getTeeMachineStatus(_teeId);
        MachineManager.checkTeeStatus(
            status,
            IMachineManager.TeeStatus.PAUSED,
            IMachineManager.TeeStatus.PAUSED_FOR_UPGRADE
        );
        if (status == IMachineManager.TeeStatus.PAUSED) {
            Replication.State storage s = Replication.getState();
            require(
                MachineManager.getLastStatusChangeTs(_teeId) +
                    s.pauseBeforeUpgradeMinDurationSeconds < block.timestamp,
                TooSoon()
            );
            MachineManager.changeStatus(_teeId, IMachineManager.TeeStatus.PAUSED_FOR_UPGRADE);
        }

        IMachineManager.TeeMachineWithAttestationData memory teeMachine =
            MachineManager.getTeeMachineWithAttestationData(_teeId);
        PauseForUpgrade memory message = PauseForUpgrade({
            teeId: _teeId,
            initialTeeId: teeMachine.initialTeeId
        });
        address[] memory teeIds = new address[](1);
        teeIds[0] = _teeId;
        _sendInstructions(teeIds, TO_PAUSE_FOR_UPGRADE, abi.encode(message), _claimBackAddress);
        emit TeeMachinePausedForUpgrade(_teeId);
    }

    /// @inheritdoc IReplication
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
        IMachineManager.TeeStatus oldStatus = MachineManager.getTeeMachineStatus(_oldTeeId);
        MachineManager.checkTeeStatus(oldStatus, IMachineManager.TeeStatus.PAUSED_FOR_UPGRADE);
        IMachineManager.TeeStatus newStatus = MachineManager.getTeeMachineStatus(newTeeId);
        require(
            newStatus == IMachineManager.TeeStatus.INITIALIZED ||
            (Replication.getReplicatingTeeId(_oldTeeId) == newTeeId &&
                newStatus == IMachineManager.TeeStatus.REPLICATING), // retry
            IMachineManager.InvalidTeeStatus()
        );
        uint256 extensionId = MachineManager.getExtensionId(_oldTeeId);
        require(extensionId == MachineManager.getExtensionId(newTeeId), ExtensionMismatch());
        IMachineManager.TeeMachineWithAttestationData memory newTeeMachine =
            MachineManager.getTeeMachineWithAttestationData(newTeeId);
        MachineManager.checkCodeHashPlatformSupported(extensionId, newTeeMachine.codeHash, newTeeMachine.platform);
        IMachineManager.TeeMachineWithAttestationData memory oldTeeMachine =
            MachineManager.getTeeMachineWithAttestationData(_oldTeeId);
        _checkTeeMachinesCompatible(_teeUpgradeId, extensionId, oldTeeMachine, newTeeMachine);
        MachineManager.validateAvailabilityCheckStatus(_proof.responseBody.status);
        MachineManager.validateAvailabilityCheckTs(newTeeId, _proof.header.timestamp);
        require(_proof.responseBody.state.systemStateVersion != bytes32(0), InvalidSystemStateVersion());

        require(
            Verification.verifyAvailabilityCheckProof(newTeeMachine, newStatus, _proof),
            ITeeCommonErrors.InvalidResponseData()
        );

        Replication.getState().replicatingTeeIds[_oldTeeId] = newTeeId;
        MachineManager.changeStatus(newTeeId, IMachineManager.TeeStatus.REPLICATING);

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

    /// @inheritdoc IReplication
    function confirmReplicate(
        address _newTeeId,
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        external
        onlyMachineOwner(_proof.requestBody.teeId)
        onlyMachineOwner(_newTeeId)
    {
        address oldTeeId = _proof.requestBody.teeId;
        require(Replication.getReplicatingTeeId(oldTeeId) == _newTeeId, ReplicationNotValid());
        delete Replication.getState().replicatingTeeIds[oldTeeId];
        require(
            _proof.responseBody.state.systemStateVersion != bytes32(0),
            InvalidSystemStateVersion()
        );
        _replicate(_newTeeId, _proof);
        emit TeeMachineReplicationConfirmed(oldTeeId, _newTeeId);
    }

    /// @inheritdoc IIReplication
    function setPauseBeforeUpgradeMinDurationSeconds(
        uint256 _pauseBeforeUpgradeMinDurationSeconds
    )
        external
        onlyGovernance
    {
        Replication.setPauseBeforeUpgradeMinDurationSeconds(_pauseBeforeUpgradeMinDurationSeconds);
    }

    /// @inheritdoc IReplication
    function getReplicatingTeeId(
        address _oldTeeId
    )
        external view
        returns (address)
    {
        return Replication.getReplicatingTeeId(_oldTeeId);
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
        MachineManager.TeeMachineState storage oldState =
            MachineManager.getTeeMachineState(oldTeeId);
        MachineManager.TeeMachineState storage newState =
            MachineManager.getTeeMachineState(_newTeeId);

        MachineManager.checkTeeStatus(
            oldState.status, IMachineManager.TeeStatus.PAUSED_FOR_UPGRADE
        );
        MachineManager.checkTeeStatus(
            newState.status, IMachineManager.TeeStatus.REPLICATING
        );
        assert(_newTeeId == newState.initialTeeId);
        require(oldState.owner == newState.owner, IMachineManager.OwnerMismatch());
        require(
            oldState.extensionId == newState.extensionId,
            ITeeCommonErrors.ExtensionIdMismatch()
        );
        MachineManager.checkCodeHashPlatformSupported(
            newState.extensionId, newState.codeHash, newState.platform
        );
        MachineManager.validateAvailabilityCheckStatus(_proof.responseBody.status);
        MachineManager.validateAvailabilityCheckTs(_newTeeId, _proof.header.timestamp);

        // copy TEE machine data from new TEE machine to old TEE machine
        oldState.initialTeeId = newState.initialTeeId;
        oldState.teeProxyId = newState.teeProxyId;
        oldState.codeHash = newState.codeHash;
        oldState.platform = newState.platform;
        oldState.url = newState.url;
        oldState.initialSigningPolicyId = _proof.responseBody.initialSigningPolicyId;
        oldState.status = IMachineManager.TeeStatus.REPLICATING;

        // delete the new TEE machine state
        MachineManager.State storage regState = MachineManager.getState();
        delete regState.teeMachineStates[_newTeeId];

        // verify the availability check proof for the updated TEE machine data
        IMachineManager.TeeMachineWithAttestationData memory oldTeeMachine =
            IMachineManager.TeeMachineWithAttestationData({
                teeId: oldTeeId,
                initialTeeId: oldState.initialTeeId,
                url: oldState.url,
                codeHash: oldState.codeHash,
                platform: oldState.platform
            });
        require(
            Verification.verifyAvailabilityCheckProof(
                oldTeeMachine, IMachineManager.TeeStatus.REPLICATING, _proof
            ),
            ITeeCommonErrors.InvalidResponseData()
        );

        // put TEE machine into production
        MachineManager.changeStatus(oldTeeId, IMachineManager.TeeStatus.PRODUCTION);
        Verification.extendAvailability(_proof);
    }

    function _sendInstructions(
        address[] memory _teeIds,
        bytes32 _opCommand,
        bytes memory _message,
        address _claimBackAddress
    )
        private
    {
        Instructions.sendInstructions(
            bytes32(0),
            _teeIds,
            IInstructions.TeeInstructionParams(
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
        IMachineManager.TeeMachineWithAttestationData memory _oldTeeMachine,
        IMachineManager.TeeMachineWithAttestationData memory _newTeeMachine
    )
        private view
    {
        require(
            UpgradeManager.isTeeUpgradePathValid(
                _teeUpgradeId,
                _extensionId,
                _oldTeeMachine.codeHash,
                _oldTeeMachine.platform,
                _newTeeMachine.codeHash,
                _newTeeMachine.platform
            ),
            InvalidUpgradePath()
        );
        require(UpgradeManager.isTeeUpgradeSigned(_teeUpgradeId), TeeUpgradeNotSigned());
    }
}
