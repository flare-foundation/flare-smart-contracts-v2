# Replication

A single TEE machine is a single point of failure for whatever wallets and keys it custodies. **Replication** copies a machine's state — including its private keys — to one or more additional TEE machines, so the keys survive a hardware failure, a deliberate retirement, or a software upgrade.

Replication is administered by [`ReplicationFacet`](../../../contracts/tee/facets/ReplicationFacet.sol) on top of [`library/Replication`](../../../contracts/tee/library/Replication.sol). The replication-init flow is in [`ReplicationInit`](../../../contracts/tee/facets/ReplicationInit.sol).

## Replication groups

A **replication group** is an *equivalence class* of TEE machines that share the same wallet keys. Each group has:

- A primary TEE machine (the original, or the one currently considered authoritative).
- Zero or more replicating TEE machines, in `REPLICATING` status while pairing is in progress, then `PRODUCTION` once pairing succeeds.
- A shared set of wallet keys that all members of the group hold.

A machine is in at most one replication group. Joining a group requires going through the pairing flow described below.

## Pairing flow

Adding a new machine `B` to the same replication group as an existing machine `A`:

1. **Register `B`.** The new machine goes through normal [registration](./MachineLifecycle.md#registration) and must become `INITIALIZED`.
2. **Mark `A` as `REPLICATING`.** The owner of `A` (or governance) calls a `ReplicationFacet` entry that pauses `A` from accepting new instructions and signals to the off-chain layer that key transfer is starting.
3. **Off-chain key transfer.** `A`'s TEE proxy negotiates an attested handshake with `B`'s proxy, encrypts the wallet keys for `B`'s TEE public key, and transfers them. `B` ingests the keys and signs an attestation that it now holds them.
4. **`B` reports completion.** `B`'s availability check, signed by the new machine, attests that key transfer succeeded. The off-chain layer surfaces the proof.
5. **Both → `PRODUCTION`.** With the proof, the on-chain replication state is updated: the group membership is recorded, both machines transition to `PRODUCTION`, and they are both added to `extensionActiveTeeIds`. From that point on, instructions targeting wallets in this group can be sent to either machine and produce identical (or at least equivalent — the deterministic-signing contract is wallet-specific) responses.

The replication state machine is conservative: failures (handshake rejected, attestation mismatch, keys not transferred) leave both machines either `PAUSED` (recoverable) or `BANNED` (irrecoverable, governance action). The group is never left in a "half-replicated" state where some machines have the keys and the bookkeeping says they don't.

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

`getReplicatingTeeId(teeId)` returns one of the group's replicating siblings, or `address(0)` if no sibling is in `PRODUCTION`. The hub substitutes the sibling but keeps the original `teeId` in the emitted event so consumers see "the request was for TEE X" even though the work was done on TEE Y.

## Why replicate at all

Three reasons:

- **Availability.** A single TEE machine can fail (hardware crash, network partition, DDoS). Without replication, every wallet that machine holds would be locked out for the duration. With replication, a sibling can serve the wallet's instructions while the primary recovers.
- **Upgrades without downtime.** When an extension's TEE software is upgraded, all PRODUCTION machines on the old version must transition through `PAUSED_FOR_UPGRADE` to a new machine running the new version. Replication lets the upgrade happen incrementally — bring up a new replicating sibling on the new version, transfer keys, retire the old machine — without ever pausing wallet access.
- **Geographic redundancy.** A TEE operator running multiple machines in different regions can replicate across them so a regional outage doesn't take wallets offline.

## What replication is *not*

- **Not a quorum.** A replication group is not a multisig. Each member of the group holds the *same* keys and produces the *same* signed responses. The threshold-of-N model that FDC2 uses (require N TEEs to sign) is per-instruction; replication is per-machine continuity.
- **Not a backup.** Members of a replication group are all live, attested machines. Backups (Shamir-shared key shares held by key admins, see [Key Management](./KeyManagement.md)) are a separate mechanism intended for catastrophic recovery, not for online failover.
- **Not automatic.** New machines don't auto-join replication groups when they register. Pairing is an explicit on-chain action by the owner of the existing machine, gated by attestation proofs.

## Reading the replication state

`flareTeeManager.getReplicatingTeeId(teeId)` returns the address of one currently-`PRODUCTION` sibling of the given machine in its replication group, or `address(0)` if none. There are also full-group enumeration views (the exact method names live on `ReplicationFacet` / `IReplication`) that let off-chain tooling list every member of a group along with each one's status.

## What `ReplicationInit` does

[`ReplicationInit`](../../../contracts/tee/facets/ReplicationInit.sol) is the diamondCut-only init helper for the replication subsystem. Like `FlareTeeManagerInit`, it is not a facet — it's `delegatecall`ed once during a `diamondCut` to seed the replication state on a fresh deployment or migrate state during a major upgrade. Day-to-day replication logic runs through `ReplicationFacet` and the `Replication` library.
