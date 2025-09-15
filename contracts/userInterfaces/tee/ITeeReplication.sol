// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { ITeeMachineRegistry } from "./ITeeMachineRegistry.sol";
import { ITeeAvailabilityCheck } from "../ftdc/ITeeAvailabilityCheck.sol";

/**
 * TeeReplication interface.
 */
interface ITeeReplication {

    struct PauseForUpgrade {
        address teeId;
        address initialTeeId;
    }

    struct ReplicateTeeMachine {
        ITeeMachineRegistry.TeeMachineWithAttestationData oldTeeMachine;
        ITeeMachineRegistry.TeeMachineWithAttestationData newTeeMachine;
    }

    event PauseBeforeUpgradeMinDurationSecondsSet(
        uint256 pauseBeforeUpgradeMinDurationSeconds
    );

    event TeeMachinePausedForUpgrade(
        address indexed teeId
    );

    event TeeMachineReplicationTriggered(
        address indexed oldTeeId,
        address indexed newTeeId,
        uint256 teeUpgradeId
    );

    event TeeMachineReplicationConfirmed(
        address indexed oldTeeId,
        address indexed newTeeId
    );

    error TooSoon();
    error InvalidTeeStatus();
    error ExtensionMismatch();
    error InvalidResponseData();
    error ReplicationNotValid();
    error InvalidSystemStateVersion();
    error AvailabilityCheckTimestampInvalid();
    error VersionNotSupported();
    error InvalidUpgradePath();
    error TeeUpgradeNotSigned();
    error OnlyMachineOwner();
    error InvalidAvailabilityCheckStatus();
    error InvalidDuration();

    /**
     * Pause a TEE machine for upgrade. It has to be paused for long enough time first.
     * Emits TeeMachinePausedForUpgrade event.
     * @param _teeId The TEE machine id.
     * Can only be called by the TEE machine owner.
     */
    function toPauseForUpgrade(address _teeId)
        external payable;

    /**
     * Replicate a TEE machine.
     * Emits TeeMachineReplicationTriggered event.
     * @param _oldTeeId The old TEE machine id.
     * @param _proof The availability check proof for the new TEE machine.
     * @param _teeUpgradeId The TEE upgrade id.
     * Can only be called by the TEE machines owner.
     */
    function replicateFrom(
        address _oldTeeId,
        ITeeAvailabilityCheck.Proof calldata _proof,
        uint256 _teeUpgradeId
    )
        external payable;

    /**
     * Confirm the replication of a TEE machine.
     * Emits TeeMachineReplicationConfirmed event.
     * @param _newTeeId The new TEE machine id.
     * @param _proof The availability check proof for the new TEE machine with the old TEE id.
     * Can only be called by the TEE machines owner.
     */
    function confirmReplicate(
        address _newTeeId,
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        external;

    /**
     * Returns the TEE machine id that is replicating the given old TEE machine id.
     * @param _oldTeeId The old TEE machine id.
     * @return The new TEE machine id that is replicating the old TEE machine id or address(0) if not found.
     */
    function getReplicatingTeeId(address _oldTeeId) external view returns(address);
}
