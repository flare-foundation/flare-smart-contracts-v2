// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { ITeeMachineRegistryFacet } from "./ITeeMachineRegistryFacet.sol";
import { ITeeAvailabilityCheck } from "../fdc2/ITeeAvailabilityCheck.sol";

/**
 * @title ITeeReplicationFacet
 * @notice Public interface for the TeeReplicationFacet.
 */
interface ITeeReplicationFacet {

    struct PauseForUpgrade {
        address teeId;
        address initialTeeId;
    }

    struct ReplicateTeeMachine {
        ITeeMachineRegistryFacet.TeeMachineWithAttestationData oldTeeMachine;
        ITeeMachineRegistryFacet.TeeMachineWithAttestationData newTeeMachine;
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
    error ExtensionMismatch();
    error ReplicationNotValid();
    error InvalidSystemStateVersion();
    error InvalidUpgradePath();
    error TeeUpgradeNotSigned();
    error OnlyMachineOwner();

    /**
     * Pause a TEE machine for upgrade. It has to be paused for long enough time first.
     * Emits TeeMachinePausedForUpgrade event.
     * @param _teeId The TEE machine id.
     * @param _claimBackAddress An address that can claim back the fee if instructions are not executed.
     * Can only be called by the TEE machine owner.
     */
    function toPauseForUpgrade(
        address _teeId,
        address _claimBackAddress
    )
        external payable;

    /**
     * Replicate a TEE machine.
     * Emits TeeMachineReplicationTriggered event.
     * @param _oldTeeId The old TEE machine id.
     * @param _proof The availability check proof for the new TEE machine.
     * @param _teeUpgradeId The TEE upgrade id.
     * @param _claimBackAddress An address that can claim back the fee if instructions are not executed.
     * Can only be called by the TEE machines owner.
     */
    function replicateFrom(
        address _oldTeeId,
        ITeeAvailabilityCheck.Proof calldata _proof,
        uint256 _teeUpgradeId,
        address _claimBackAddress
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
     * @return The new TEE machine id or address(0) if not found.
     */
    function getReplicatingTeeId(
        address _oldTeeId
    )
        external view
        returns (address);
}
