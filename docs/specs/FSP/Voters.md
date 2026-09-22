# Voters

Voting in Flare is performed by **data providers** acting as **voters**. The model has two layers:

- An **entity** is a long-lived identity — a set of bound addresses and a list of validator node IDs — managed by [`EntityManager`](../../../contracts/protocol/implementation/EntityManager.sol). Once registered, an entity persists across reward epochs.
- A **voter** is an entity that has self-registered for a *specific reward epoch* via [`VoterRegistry`](../../../contracts/protocol/implementation/VoterRegistry.sol). Voter status must be re-acquired every reward epoch.

## The entity model

An entity in `EntityManager` is keyed by a single `identityAddress` and binds five address roles plus an optional public key and validator node IDs:

| Role | Purpose |
|------|---------|
| `identityAddress` | Primary identifier. Used for administrative operations (`registerNodeId`, `propose...Address`). Intended to be a cold-storage key. (`setMaxNodeIdsPerEntity` is `onlyGovernance`, not an entity operation.) |
| `delegationAddress` | Receives WNat delegations from the community. Vote-power of WNat delegations to this address counts toward the entity's signing weight. |
| `submitAddress` | Used to call `submit1`/`submit2` on `Submission` for sub-protocol round payloads. |
| `submitSignaturesAddress` | Used to call `submitSignatures` on `Submission` for finalization signatures. |
| `signingPolicyAddress` | Used to sign signing-policy approvals, rewards hashes, and pre-registrations. The address that recovers from the ECDSA signature in `VoterRegistry.registerVoter`. |
| `publicKey` (optional) | A 64-byte point on the elliptic curve, registered through a `IIPublicKeyVerifier`. Required for FTSO block-latency feed sortition. |
| `nodeIds` (list) | P-chain validator node IDs the entity controls; their staked FLR contributes to the entity's signing weight. |

### Address registration: propose-then-confirm

Each of the four delegated address roles (delegation, submit, submit-signatures, signing-policy) is registered through a two-step pattern that proves the entity controls both ends of the binding:

1. The entity's `identityAddress` calls `propose<Role>Address(newAddress)` on `EntityManager`. The proposed address is parked in a per-voter queue.
2. The proposed `newAddress` itself calls `confirm<Role>AddressRegistration(voter)` from its own key. `EntityManager` checks the queue, replaces the previous binding, and emits the corresponding `*Confirmed` event.

The same address can only be bound to one entity at a time — `EntityManager` rejects re-use across entities. Bindings are **history-tracked**: every change is checkpointed by block number, so vote-power-block lookups (`getDelegationAddressOfAt(voter, block)`, `getVoterAddressesAt(voter, block)`) return the binding that was in force at that block. If a role is unset at the queried block, the entity's identity address is returned as a fallback.

### Node IDs

`registerNodeId(nodeId, certificateRaw, signature)` requires the entity to prove ownership of the validator's BLS key by submitting a signed certificate that [`NodePossessionVerifier`](../../../contracts/protocol/implementation/NodePossessionVerifier.sol) (set as `nodePossessionVerifier`) validates. Up to `maxNodeIdsPerEntity` node IDs can be bound at once; the limit can only be raised by governance.

### Public key

`registerPublicKey(part1, part2, verificationData)` — an optional public key (intended for FTSO block-latency sortition) registered through a configured `IIPublicKeyVerifier`. The key is hashed (`keccak256(abi.encode(part1, part2))`); each hash can be bound to at most one entity at a time. Replacing an existing key for the same entity unregisters the previous one.

## Voter registration

Becoming a voter for reward epoch $e$ means appearing in `VoterRegistry`'s register for that epoch. Registration is **self-service** — the system does not select voters — and capped: at most `maxVoters` (currently `100`, hard-capped by the `MAX_VOTERS = 300` constant in [`VoterRegistry`](../../../contracts/protocol/implementation/VoterRegistry.sol)) entities make it into a single signing policy.

### `registerVoter`

The window opens when `FlareSystemsManager` selects the next epoch's vote-power block and emits `VotePowerBlockSelected`. It closes once `voterRegistrationMinDurationSeconds` (30 min), `voterRegistrationMinDurationBlocks` (900), and `signingPolicyMinNumberOfVoters` are all satisfied.

```solidity
function registerVoter(address _voter, Signature calldata _signature) external;
```

Caller can be any address — the function authenticates the *content*, not the sender:

1. The signature is checked against the entity's `signingPolicyAddress` for `keccak256(abi.encode(block.chainid, rewardEpochId, _voter))` (Ethereum-prefixed). Wrong key → `"invalid signature"`.
2. `FlareSystemsCalculator.calculateRegistrationWeight(_voter, rewardEpochId, votePowerBlock)` computes the entity's weight from staked FLR (mirrored P-chain stake on the entity's node IDs) and capped WNat delegation to its delegation address. See [Weighting](./Weighting.md).
3. The entity must have a delegation address bound at the vote-power block (else `"delegation address not set"`).
4. Weight must be non-zero (else `"voter weight zero"`).
5. If `publicKeyRequired` is set and the entity has no public key registered at the policy-init block, the call reverts `"public key required"`.

### Slot allocation and displacement

Once those preconditions pass, the slot logic in `_registerVoter`:

- If `register[rewardEpochId].voters.length < maxVoters`, append the voter and record their weight.
- Otherwise, scan the table for the **lowest-weight** entity (preferring the highest index on ties — a tie-break that favors earlier registrants, since later-registered entries are pushed lower in the ordering).
  - If the new voter's weight is **not strictly higher** than that minimum, `revert("vote power too low")`.
  - Otherwise, the lowest-weight entry is removed (`VoterRemoved(removedVoter, rewardEpochId)` emitted), and the new voter takes its slot.

The result is an unordered set of at most `maxVoters` entries; the snapshot at the end of the registration window will sort them out.

### Signing policy snapshot

When the registration window closes, `FlareSystemsManager` calls `VoterRegistry.createSigningPolicySnapshot(rewardEpochId)`. This:

1. Reads each registered voter's `signingPolicyAddress` and public key as of the `newSigningPolicyInitializationStartBlockNumber`.
2. Computes per-voter normalized weights `weights[i] * UINT16_MAX / weightsSum`.
3. Returns the signing-policy address list, normalized weights, and their sum, plus the sub-sum corresponding to voters that have a public key registered (so block-latency feeds can compute their stake-weighted sortition).

Those numbers feed straight into the published `SigningPolicy` record (see [Signing Policy](./SigningPolicy.md)).

## Pre-registration

[`VoterPreRegistry`](../../../contracts/protocol/implementation/VoterPreRegistry.sol) provides a fast lane for entities already in the **current** signing policy — the typical case for incumbents. It has no weight check; it just records signed registration intent so the orchestrator can convert intents into actual `registerVoter` calls automatically when the window opens.

```solidity
function preRegisterVoter(address _voter, Signature calldata _signature) external;
```

- The target reward epoch is implicit: `currentRewardEpochId + 1`.
- The signature uses the same hash as `registerVoter` and recovers via `EntityManager.getVoterForSigningPolicyAddress`. The signer must be the entity's signing-policy address as of the current block, and the resolved voter must equal `_voter`. Wrong signer or stale binding → `"invalid signature"`.
- Pre-registration is open until `randomAcquisitionEndBlock != 0` for the next epoch (i.e. up until the vote-power block has been selected). After that, `"pre-registration not opened anymore"`.
- Re-calling for the same `(_voter, rewardEpochId)` updates the stored signature in place — useful if the entity's `signingPolicyAddress` changed and the previous pre-registration would no longer verify against the new binding.

When `daemonize()` reaches Phase B (`VotePowerBlockSelected`) and a `voterRegistrationTriggerContract` is set, it calls `triggerVoterRegistration(nextRewardEpochId)`. The pre-registry then iterates its stored list and bulk-calls `voterRegistry.registerVoter` for each pre-registered voter. Each call is wrapped in `try/catch` — failures (e.g. weight dropped to zero, slot displaced by a higher-weight entrant earlier in the same trigger run) emit `VoterRegistrationFailed(voter, rewardEpochId)` and **don't** abort the loop. Voters whose pre-registration fails can still call `registerVoter` directly for the duration of the open window.

## Chilling

`VoterRegistry.chill(beneficiaries[], noOfRewardEpochs)` is a governance-only escape hatch. For each beneficiary (a 20-byte address or node ID), it sets `chilledUntilRewardEpochId[beneficiary] = currentRewardEpochId + noOfRewardEpochs + 1`. While chilled:

- For a node ID, the P-chain stake on that node contributes 0 to the entity's registration weight (`FlareSystemsCalculator.calculateRegistrationWeight` checks `chilledUntilRewardEpochId(nodeIds[i])`).
- For a delegation address, the WNat delegation portion contributes 0.

The contract emits `BeneficiaryChilled(beneficiary, untilRewardEpochId)`. Used as a response to evidence of misbehavior (e.g. FTSO collusion) without a full revocation of the entity.
