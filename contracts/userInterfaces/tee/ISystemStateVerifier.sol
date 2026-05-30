// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * @title ISystemStateVerifier
 * @notice Type definitions for the TEE-signed system-state payload.
 *
 * @dev The TEE-signed `TeeSystemState` payload doubles as the on-chain signal for replication
 *      capability of the TEE binary:
 *      - A binary that supports replication signs a populated `TeeSystemState` with its own
 *        `initialTeeId` (the address derived from the TEE's provisioning-baked keypair). The
 *        chain pre-commits that value at the first availability check (machine status
 *        `INITIALIZED`) before invoking the verifier, so the strict-compare check accepts only
 *        if the TEE attests the expected id.
 *      - A binary that doesn't support replication signs an empty payload. The chain stores no
 *        `initialTeeId` for the machine, and the path-list / replication flow refuses to operate
 *        on it (`ReplicationFacet.NotReplicationCapable`).
 *
 *      `initialTeeId` is invariant on the physical TEE: it does not change when the chain
 *      re-binds the on-chain `teeId` (e.g. during replication, when `_replicate` writes
 *      `oldState.initialTeeId = newState.initialTeeId`). The cross-check catches the case where
 *      a caller points the chain flow at the wrong physical machine — the proxy of the wrong
 *      TEE will report its own provisioning identity, not the one the chain expects.
 *
 *      `status` is the TEE software's view of its own runtime status; the verifier requires it
 *      to be `ACTIVE` for the proof to be admissible.
 *
 *      The verifier itself lives in the [`SystemStateVerifier` library](../../tee/library/SystemStateVerifier.sol)
 *      and is consumed only internally by `Verification._validateResponseBody`. No diamond facet
 *      exposes it externally; off-chain consumers should look up the machine's stored
 *      `initialTeeId` via `IMachineManager.getTeeMachineWithAttestationData`.
 */
interface ISystemStateVerifier {

    enum TeeMachineStatus { ACTIVE, PAUSED, PAUSED_FOR_UPGRADE }

    struct TeeSystemState {
        TeeMachineStatus status;
        address initialTeeId;
    }
}
