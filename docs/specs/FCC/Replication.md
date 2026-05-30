# Replication

A single TEE machine is a single point of failure for whatever wallets and keys it custodies. **Replication** copies a machine's state — including its private keys — to one or more additional TEE machines, so the keys survive a hardware failure, a deliberate retirement, or a software upgrade.

Replication is administered by [`ReplicationFacet`](../../../contracts/tee/facets/ReplicationFacet.sol) on top of [`library/Replication`](../../../contracts/tee/library/Replication.sol). The replication-init flow is in [`ReplicationInit`](../../../contracts/tee/facets/ReplicationInit.sol).

## Replication groups

A **replication group** is an *equivalence class* of TEE machines that share the same wallet keys. Each group has:

- A primary TEE machine (the original, or the one currently considered authoritative).
- Zero or more replicating TEE machines, in `REPLICATING` status while pairing is in progress, then `PRODUCTION` once pairing succeeds.
- A shared set of wallet keys that all members of the group hold.

A machine is in at most one replication group. Joining a group requires going through the pairing flow described below.

## Authorization: the machine-path list + replication-capable gate

Two independent gates must clear for a `(source, destination)` pair to replicate:

1. **Machine-path list.** Every replication source→destination pair must appear in the extension's currently-active [machine-path list](./Governance.md#machine-path-manager). That list is a per-extension, governance-signed allow-list of `(sourceTeeIds, destinationTeeIds)` paths, administered by [`MachinePathManagerFacet`](../../../contracts/tee/facets/MachinePathManagerFacet.sol). Activation requires every involved governance configuration (the union of `governanceHash`es of all `teeId`s in the list) to reach its threshold of signatures. The list takes over the role that the now-removed `UpgradeManagerFacet` (per-codeHash upgrade paths) used to play. The destination machine in a replication is allowed to be in `INITIALIZED` status when the list is signed — the path-list eligibility check requires only that the TEE machine has a recorded non-zero `governanceHash`, not that it has reached `PRODUCTION`.

2. **Replication-capable.** Both source and destination must individually have `initialTeeId != 0 && governanceHash != 0` on chain. `governanceHash` is the owner's choice at registration; `initialTeeId` is captured from the first availability check when the TEE binary attests a populated `TeeSystemState` (see [Verification / System state verification](./Verification.md#system-state-verification)). A machine whose binary lacks replication code signs an empty payload, leaves `initialTeeId` at zero, and is permanently classified non-replication. A machine whose owner chose `governanceHash = 0` at registration is by definition outside any governance and cannot be replicated either, even if its binary would support it.

`ReplicationFacet.toPauseForUpgrade` and `ReplicationFacet.replicateFrom` reject calls on non-replication-capable machines with `NotReplicationCapable(teeId)` — the gate fires before the status check and before the path-list lookup. `replicateFrom` additionally checks the destination machine's `governanceHash` pre-flight; the destination's `initialTeeId` is captured during the verifier call from the proof's `TeeSystemState` (the `InvalidSystemStateVersion` guard plus the verifier's `state.initialTeeId == newTeeId` check together enforce that the destination binary is replication-capable).

## Pairing flow

Adding a new machine `B` to the same replication group as an existing machine `A`:

1. **Register `B`.** The new machine goes through normal [registration](./MachineLifecycle.md#registration) with `governanceHash` set to the extension's current `latestTeeGovernanceHash` (zero is allowed at registration but would block replication later). After registration `B` is `INITIALIZED` with `initialTeeId = 0` — the chain captures the actual value at first attestation in step 5.
2. **Sign a machine-path list authorising `(A, B)`.** The extension owner creates a list via `createNewMachinePathList`, appends a `MachinePath { sourceTeeIds: [A], destinationTeeIds: [B] }` via `addMachinePaths`, finalises it, and collects signatures from every involved governance (the governance bound to `A`'s machine plus the one bound to `B`'s). Once each governance threshold is met, the list becomes the extension's active list.
3. **Move `A` to `PAUSED_FOR_UPGRADE`.** The owner of `A` calls `ReplicationFacet.toPauseForUpgrade(_teeId, _claimBackAddress)`. The call gates on `onlyMachineOwner` and on the replication-capable check (`A.initialTeeId != 0 && A.governanceHash != 0`, else `NotReplicationCapable(A)`). `A` must already be `PAUSED` (and have been paused at least `pauseBeforeUpgradeMinDurationSeconds`, else `TooSoon()`); the call moves it to `PAUSED_FOR_UPGRADE` and dispatches a `TO_PAUSE_FOR_UPGRADE` instruction signalling to the off-chain layer that key transfer is starting.
4. **Off-chain key transfer.** `A`'s TEE proxy negotiates an attested handshake with `B`'s proxy, encrypts the wallet keys for `B`'s TEE public key, and transfers them. `B` ingests the keys and signs an attestation that it now holds them.
5. **`B` enters `REPLICATING`.** The owner calls `ReplicationFacet.replicateFrom(_oldTeeId, _proof, _claimBackAddress)`, where `_proof` is `B`'s availability-check proof. `A` must be `PAUSED_FOR_UPGRADE`; `B` must be `INITIALIZED` (first call) or `REPLICATING` (retry). Pre-flight checks: `A.initialTeeId != 0 && A.governanceHash != 0` (else `NotReplicationCapable(A)`), and `B.governanceHash != 0` (else `NotReplicationCapable(B)`). `B`'s `initialTeeId` is captured here on the first call: the `InvalidSystemStateVersion()` guard plus the verifier's `state.initialTeeId == B` check together enforce that `B`'s TEE binary attests its provisioning identity, and the facet writes that into `MachineManager.TeeMachineState.initialTeeId` for `B`. Then `MachinePathManager.requireActiveListNonceForPath(extensionId, A, B)` reverts `NoActiveMachinePathList()` if no list is signed, or `InvalidMachinePath()` if the (A,B) pair isn't in the active list. On success the call records `replicatingTeeIds[A] = B`, moves `B` to `REPLICATING`, and dispatches a `REPLICATE_FROM` instruction to both machines. The instruction payload carries `machinePathListNonce`, so the TEE proxy can fetch and re-verify the exact authorising list off-chain. Access is `onlyMachineOwner` for both `A` and `B`.
6. **`A` → `PRODUCTION`, `B` absorbed.** The owner calls `ReplicationFacet.confirmReplicate(_newTeeId, _proof)`, where `_proof` is signed for `A`'s teeId. The call copies `B`'s machine data (`initialTeeId`, `teeProxyId`, `codeHash`, `platform`, `governanceHash`, `url`, `initialSigningPolicyId`) into `A`'s state row, **deletes `B`'s state row**, clears `replicatingTeeIds[A]`, and transitions `A` to `PRODUCTION` (re-adding it to the active sets). From that point on, `A` runs the new machine's identity and software; `B`'s teeId no longer exists as a separate row.

The replication state machine is conservative: the `replicatingTeeIds[A] = B` link is only set in `replicateFrom` and only cleared in `confirmReplicate`, so the group is never left in a "half-replicated" state where the bookkeeping disagrees with which machine holds the keys. A failed/incomplete upgrade can be retried by calling `replicateFrom` again while `B` is still `REPLICATING`.

## Why `PAUSED_FOR_UPGRADE` matters

A machine entering an extension upgrade goes from `PRODUCTION` to `PAUSED_FOR_UPGRADE`. While it's paused, instructions for wallets in its replication group can still run on the *other* group members — the system finds a replicating sibling and routes the instruction there.

This is the mechanism `Fdc2Hub.requestAttestation` uses ([code](../../../contracts/fdc2/implementation/Fdc2Hub.sol)):

```solidity
if (status == TeeStatus.PAUSED_FOR_UPGRADE) {
    address replicatingTeeId = flareTeeManager.getReplicatingTeeId(teeId);
    require(replicatingTeeId != address(0), TeeMachineNotAvailable());
    teeMachines[i] = flareTeeManager.getTeeMachine(replicatingTeeId);
    teeMachines[i].teeId = teeId;  // keep original ID for event semantics
}
```

`getReplicatingTeeId(teeId)` returns the address recorded in `replicatingTeeIds[teeId]` — the new machine currently in `REPLICATING` status mid-upgrade — or `address(0)` if no replication is in progress (the link is set in `replicateFrom` and cleared in `confirmReplicate`). The hub substitutes that machine but keeps the original `teeId` in the emitted event so consumers see "the request was for TEE X" even though the work was done on TEE Y.

## Why replicate at all

Three reasons:

- **Availability.** A single TEE machine can fail (hardware crash, network partition, DDoS). Without replication, every wallet that machine holds would be locked out for the duration. With replication, a sibling can serve the wallet's instructions while the primary recovers.
- **Upgrades without downtime.** When an extension's TEE software is upgraded, all PRODUCTION machines on the old version must transition through `PAUSED_FOR_UPGRADE` to a new machine running the new version. Replication lets the upgrade happen incrementally — bring up a new replicating sibling on the new version, transfer keys, retire the old machine — without ever pausing wallet access.
- **Geographic redundancy.** A TEE operator running multiple machines in different regions can replicate across them so a regional outage doesn't take wallets offline.

## What replication is *not*

- **Not a quorum.** A replication group is not a multisig. Each member of the group holds the *same* keys and produces the *same* signed responses. The threshold-of-N model that FDC2 uses (require N TEEs to sign) is per-instruction; replication is per-machine continuity.
- **Not a backup.** Members of a replication group are all live, attested machines. Backups (Shamir-shared key shares held by key admins, see [Key Management](./KeyManagement.md)) are a separate mechanism intended for catastrophic recovery, not for online failover.
- **Not automatic.** New machines don't auto-join replication groups when they register. Pairing is an explicit on-chain action by the owner of the existing machine, gated by a governance-signed machine-path list.

## Reading the replication state

`flareTeeManager.getReplicatingTeeId(teeId)` returns the address recorded in `replicatingTeeIds[teeId]` — the new machine in `REPLICATING` status during an in-progress upgrade — or `address(0)` if no replication is in progress. This is the only read view exposed by `IReplication`; there are no full-group enumeration views.

## What `ReplicationInit` does

[`ReplicationInit`](../../../contracts/tee/facets/ReplicationInit.sol) is the diamondCut-only init helper for the replication subsystem. Like `FlareTeeManagerInit`, it is not a facet — it's `delegatecall`ed once during a `diamondCut` to seed the replication state on a fresh deployment or migrate state during a major upgrade. Day-to-day replication logic runs through `ReplicationFacet` and the `Replication` library.
