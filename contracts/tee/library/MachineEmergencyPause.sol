// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IMachineEmergencyPause } from "../../userInterfaces/tee/IMachineEmergencyPause.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title MachineEmergencyPause
 * @notice Library holding per-extension emergency-pause state and pauser/unpauser allowlists.
 * @dev Uses ERC-7201 namespaced storage. Contains only read helpers reused by other
 *      libraries / facets (`Instructions.sendInstructions`, `MachineManagerFacet.pause`).
 *      Mutation logic lives in MachineEmergencyPauseFacet.
 *
 *      The emergency pause is a boolean overlay per extension — it does not mutate any
 *      TEE machine status or any active set. The single on-chain effect is that
 *      `Instructions.sendInstructions` rejects every dispatch targeting machines in the
 *      paused extension (both regular and system opTypes). Read getters
 *      (`getActiveTeeMachines`, `getAllActiveTeeMachines`, `getRandomTeeIds`) keep
 *      returning the raw active set; off-chain consumers that need "is this usable
 *      right now" should also call `isExtensionEmergencyPaused`.
 *
 *      After unpause, a global grace window blocks third-party expired-availability
 *      pauses for `emergencyUnpauseGracePeriodSeconds`, so owners have time to refresh
 *      their attestations before anyone can shove their machines to SUSPENDED. The
 *      grace window combines both the machine's own extension AND the system extension
 *      (id 0): an availability refresh needs `requestTeeAttestation` (sent to the
 *      machine's extension) AND `requestAvailabilityCheckAttestation` (sent to system-
 *      extension TEEs via FDC2). If either side has been recently emergency-paused, the
 *      protection holds for the longer of the two grace windows.
 */
library MachineEmergencyPause {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// Per-extension state, packed to one slot (1 + 8 = 9 bytes).
    struct ExtensionPauseState {
        bool emergencyPaused;
        uint64 lastUnpauseTs;
    }

    /// @custom:storage-location erc7201:tee.MachineEmergencyPause.State
    struct State {
        // Global tunable — applies to every extension. Governance-set.
        uint256 emergencyUnpauseGracePeriodSeconds;

        // Per-extension state — packed bool + uint64 in one slot.
        mapping(uint256 extensionId => ExtensionPauseState) extensions;

        // Per-extension delegation lists.
        mapping(uint256 extensionId => EnumerableSet.AddressSet) pausers;
        mapping(uint256 extensionId => EnumerableSet.AddressSet) unpausers;
    }

    /// Hard floor and ceiling on the governance-configurable grace period.
    /// Floor (30 min) is roughly 6× the automated availability-refresh roundtrip
    /// (request TEE attestation → off-chain TEE response → FDC2 voting round →
    /// confirmAvailability) — gives operators a reasonable window to react after
    /// unpause without over-constraining governance.
    uint256 internal constant MIN_GRACE_PERIOD_SECONDS = 30 minutes;
    uint256 internal constant MAX_GRACE_PERIOD_SECONDS = 1 days;

    /// The system extension id. FDC2 attestations (the proof-generation half of the
    /// availability-refresh flow) are routed exclusively to TEEs in this extension.
    uint256 internal constant SYSTEM_EXTENSION_ID = 0;

    bytes32 internal constant STATE_POSITION = keccak256(
        abi.encode(uint256(keccak256("tee.MachineEmergencyPause.State")) - 1)
    ) & ~bytes32(uint256(0xff));

    /// Validates the input against `[MIN_GRACE_PERIOD_SECONDS, MAX_GRACE_PERIOD_SECONDS]`,
    /// writes the new value into ERC-7201 storage, and emits
    /// `IMachineEmergencyPause.EmergencyUnpauseGracePeriodSet`. Shared by
    /// `MachineEmergencyPauseFacet.setEmergencyUnpauseGracePeriodSeconds` (governance-
    /// gated runtime setter) and `FlareTeeManagerInit.init` (deploy-time initialization).
    /// Auth is the caller's responsibility.
    function setGracePeriodSeconds(
        uint256 _seconds
    )
        internal
    {
        require(
            _seconds >= MIN_GRACE_PERIOD_SECONDS,
            IMachineEmergencyPause.GracePeriodTooShort(_seconds)
        );
        require(
            _seconds <= MAX_GRACE_PERIOD_SECONDS,
            IMachineEmergencyPause.GracePeriodTooLong(_seconds)
        );
        getState().emergencyUnpauseGracePeriodSeconds = _seconds;
        emit IMachineEmergencyPause.EmergencyUnpauseGracePeriodSet(_seconds);
    }

    /// Used by `Instructions.sendInstructions` to reject dispatches whose target extension
    /// is in emergency pause. Also exposed via the public view getter.
    function isExtensionEmergencyPaused(
        uint256 _extensionId
    )
        internal view
        returns (bool)
    {
        return getState().extensions[_extensionId].emergencyPaused;
    }

    /// True if `_extensionId` is currently emergency-paused OR within the post-unpause
    /// grace window OR the system extension (0) is in either state. The system extension
    /// is folded in because an availability refresh requires both the machine's own
    /// extension (for `requestTeeAttestation`) and the system extension (for
    /// `requestAvailabilityCheckAttestation`, which FDC2 routes exclusively to extension
    /// 0 TEEs). If either side is unavailable, the owner couldn't have refreshed
    /// availability, so the third-party expired-availability `pause()` branch must stay
    /// blocked. Caller is `MachineManagerFacet.pause()`'s third-party branch.
    function isExtensionInEmergencyOrGrace(
        uint256 _extensionId
    )
        internal view
        returns (bool)
    {
        if (_isInEmergencyOrGrace(_extensionId)) return true;
        if (_extensionId == SYSTEM_EXTENSION_ID) return false;
        return _isInEmergencyOrGrace(SYSTEM_EXTENSION_ID);
    }

    function isPauser(
        uint256 _extensionId,
        address _addr
    )
        internal view
        returns (bool)
    {
        return getState().pausers[_extensionId].contains(_addr);
    }

    function isUnpauser(
        uint256 _extensionId,
        address _addr
    )
        internal view
        returns (bool)
    {
        return getState().unpausers[_extensionId].contains(_addr);
    }

    function getState()
        internal pure
        returns (State storage _state)
    {
        bytes32 position = STATE_POSITION;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            _state.slot := position
        }
    }

    function _isInEmergencyOrGrace(
        uint256 _extensionId
    )
        private view
        returns (bool)
    {
        State storage s = getState();
        ExtensionPauseState storage e = s.extensions[_extensionId];
        if (e.emergencyPaused) return true;
        // `block.timestamp >> MAX_GRACE_PERIOD_SECONDS` (24h) on any real chain
        return block.timestamp < uint256(e.lastUnpauseTs) + s.emergencyUnpauseGracePeriodSeconds;
    }
}
