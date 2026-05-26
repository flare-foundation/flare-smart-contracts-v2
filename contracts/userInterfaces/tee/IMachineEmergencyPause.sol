// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { ITeeCommonErrors } from "./ITeeCommonErrors.sol";

/**
 * @title IMachineEmergencyPause
 * @notice Public interface for the MachineEmergencyPauseFacet.
 * @dev Per-extension emergency pause overlay. While the flag is set,
 *      `Instructions.sendInstructions` rejects every dispatch targeting machines in the
 *      paused extension (both regular and system opTypes) with
 *      `EmergencyPauseActive(extensionId)`. Individual TEE statuses, the active sets,
 *      and the read getters (`getActiveTeeMachines`, `getAllActiveTeeMachines`,
 *      `getRandomTeeIds`) are not affected — off-chain consumers that need
 *      "is this usable right now" should also call `isExtensionEmergencyPaused`.
 *      Clearing the flag instantly restores dispatch capability.
 *
 *      To stop a third party from shoving still-PRODUCTION-but-stale machines to
 *      SUSPENDED right after a long emergency pause (the third-party
 *      expired-availability branch of `MachineManagerFacet.pause`), the same branch is
 *      additionally blocked for a configurable grace window after unpause, set via
 *      `setEmergencyUnpauseGracePeriodSeconds`. The protection window combines both
 *      the machine's own extension and the system extension (id 0): refreshing
 *      availability requires `requestTeeAttestation` (routed to the machine's
 *      extension) AND `requestAvailabilityCheckAttestation` (routed via FDC2 to
 *      system-extension TEEs only), so if either is in pause or grace, third-party
 *      pause stays blocked.
 *
 *      List-management methods are gated by the extension owner. The pause/unpause
 *      actions accept either the extension owner or a list member. The grace setter is
 *      governance-only and timelocked.
 */
interface IMachineEmergencyPause is ITeeCommonErrors {

    event ExtensionEmergencyPausersAdded(uint256 indexed extensionId, address[] addresses);
    event ExtensionEmergencyPausersRemoved(uint256 indexed extensionId, address[] addresses);
    event ExtensionEmergencyUnpausersAdded(uint256 indexed extensionId, address[] addresses);
    event ExtensionEmergencyUnpausersRemoved(uint256 indexed extensionId, address[] addresses);

    event ExtensionEmergencyPaused(uint256 indexed extensionId);
    event ExtensionEmergencyUnpaused(uint256 indexed extensionId, uint64 unpauseTs);
    event EmergencyUnpauseGracePeriodSet(uint256 graceSeconds);

    error ExtensionAlreadyEmergencyPaused(uint256 extensionId);
    error ExtensionNotEmergencyPaused(uint256 extensionId);
    error EmergencyPauseActive(uint256 extensionId);
    error EmergencyProtectionActive(uint256 extensionId);
    error GracePeriodTooShort(uint256 graceSeconds);
    error GracePeriodTooLong(uint256 graceSeconds);

    /**
     * Adds addresses to the extension's emergency-pauser list.
     * Emits ExtensionEmergencyPausersAdded event.
     * @param _extensionId The extension id.
     * @param _addresses The addresses to add.
     * Can only be called by the extension owner.
     */
    function addExtensionEmergencyPausers(
        uint256 _extensionId,
        address[] calldata _addresses
    )
        external;

    /**
     * Removes addresses from the extension's emergency-pauser list.
     * Emits ExtensionEmergencyPausersRemoved event.
     * @param _extensionId The extension id.
     * @param _addresses The addresses to remove.
     * Can only be called by the extension owner.
     */
    function removeExtensionEmergencyPausers(
        uint256 _extensionId,
        address[] calldata _addresses
    )
        external;

    /**
     * Adds addresses to the extension's emergency-unpauser list.
     * Emits ExtensionEmergencyUnpausersAdded event.
     * @param _extensionId The extension id.
     * @param _addresses The addresses to add.
     * Can only be called by the extension owner.
     */
    function addExtensionEmergencyUnpausers(
        uint256 _extensionId,
        address[] calldata _addresses
    )
        external;

    /**
     * Removes addresses from the extension's emergency-unpauser list.
     * Emits ExtensionEmergencyUnpausersRemoved event.
     * @param _extensionId The extension id.
     * @param _addresses The addresses to remove.
     * Can only be called by the extension owner.
     */
    function removeExtensionEmergencyUnpausers(
        uint256 _extensionId,
        address[] calldata _addresses
    )
        external;

    /**
     * Flips the extension into emergency-paused state.
     * Emits ExtensionEmergencyPaused event.
     * @param _extensionId The extension id.
     * Can only be called by the extension owner OR an address on the pauser list.
     * Reverts ExtensionAlreadyEmergencyPaused if the flag is already set.
     */
    function emergencyPauseExtension(
        uint256 _extensionId
    )
        external;

    /**
     * Clears the extension's emergency-pause flag and records the unpause timestamp.
     * The recorded timestamp opens the grace window during which third-party
     * expired-availability `pause()` calls are blocked.
     * Emits ExtensionEmergencyUnpaused event.
     * @param _extensionId The extension id.
     * Can only be called by the extension owner OR an address on the unpauser list.
     * Reverts ExtensionNotEmergencyPaused if the flag is not set.
     */
    function emergencyUnpauseExtension(
        uint256 _extensionId
    )
        external;

    /**
     * Returns the extension's pauser addresses.
     * @param _extensionId The extension id.
     * @return _addresses The pauser addresses.
     */
    function getExtensionEmergencyPausers(
        uint256 _extensionId
    )
        external view
        returns (address[] memory _addresses);

    /**
     * Returns the extension's unpauser addresses.
     * @param _extensionId The extension id.
     * @return _addresses The unpauser addresses.
     */
    function getExtensionEmergencyUnpausers(
        uint256 _extensionId
    )
        external view
        returns (address[] memory _addresses);

    /**
     * Returns true if `_addr` is on the extension's pauser list.
     * @param _extensionId The extension id.
     * @param _addr The address to check.
     * @return _isPauser True if `_addr` is on the pauser list.
     */
    function isExtensionEmergencyPauser(
        uint256 _extensionId,
        address _addr
    )
        external view
        returns (bool _isPauser);

    /**
     * Returns true if `_addr` is on the extension's unpauser list.
     * @param _extensionId The extension id.
     * @param _addr The address to check.
     * @return _isUnpauser True if `_addr` is on the unpauser list.
     */
    function isExtensionEmergencyUnpauser(
        uint256 _extensionId,
        address _addr
    )
        external view
        returns (bool _isUnpauser);

    /**
     * Returns true if the extension is currently in emergency-paused state.
     * @param _extensionId The extension id.
     * @return _paused True if the flag is set.
     */
    function isExtensionEmergencyPaused(
        uint256 _extensionId
    )
        external view
        returns (bool _paused);

    /**
     * Returns the timestamp of the most recent emergency unpause for this extension.
     * Off-chain consumers can combine this with `getEmergencyUnpauseGracePeriodSeconds`
     * to compute the grace window's end.
     * @param _extensionId The extension id.
     * @return _ts The last unpause timestamp (0 if the extension has never been unpaused).
     */
    function getLastUnpauseTs(
        uint256 _extensionId
    )
        external view
        returns (uint64 _ts);

    /**
     * Returns the current global grace duration applied after emergency unpause.
     * @return _seconds Grace duration in seconds.
     */
    function getEmergencyUnpauseGracePeriodSeconds()
        external view
        returns (uint256 _seconds);
}
