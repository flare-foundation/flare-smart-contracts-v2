# Finalization

A sub-protocol round produces a Merkle root off-chain. **Finalization** is the act of getting that root onto the chain, signed by enough of the active signing policy to be trustworthy. All sub-protocols finalize through one contract — [`Relay`](../../../contracts/protocol/implementation/Relay.sol) — which checks signatures, stores the root, and emits `ProtocolMessageRelayed`. Consumers downstream prove their data items against that root via `Relay.verify`.

`Relay` is heavily assembly-optimized so finalization can carry a large signing policy and many signatures within a single transaction. The high-level shape, though, is straightforward.

## What `Relay` stores

| Storage | Description |
|---------|-------------|
| `toSigningPolicyHashPrivate[rewardEpochId] → bytes32` | Hash of the signing policy for that epoch: `keccak256(sourceChainId ‖ encoded policy bytes)`, one keccak over the 32-byte configured source chain id followed by the raw 43 + 22 × n encoded bytes. Set by `setSigningPolicy` (callable only by the authorized `signingPolicySetter`, which is `FlareSystemsManager`). Read by every relay. |
| `startingVotingRoundIds[rewardEpochId] → uint256` | First voting round the policy is in force for. |
| `merkleRootsPrivate[protocolId][votingRoundId] → bytes32` | The finalized Merkle root for that protocol/round. Once written, it does not change. |
| `isSecureRandomMap[votingRoundId / 256] → bytes32` | One bit per voting round indicating whether a finalized FTSO round produced a secure random. |
| `stateData` | A packed `StateData` struct with the active random-number protocol ID, voting-epoch parameters, the BIPS threshold-increase for cross-epoch relays, and the finalization window. |

`stateData.lastInitializedRewardEpoch` is bumped each time `setSigningPolicy` is called for the next reward epoch. The signing-policy struct passed in must satisfy:

- `voters.length > 0` and `≤ MAX_VOTERS` (`300`),
- weights sum below `2^16`,
- threshold ≥ `5000` BIPS of total weight (50%),
- threshold ≤ `6600` BIPS of total weight (66%).

These bounds are enforced **by `Relay` itself** in `setSigningPolicy`, independent of whatever `signingPolicyThresholdPPM` `FlareSystemsManager` configured.

## The `relay()` flow

```solidity
function relay() external returns (bytes memory);
```

`relay()` is a no-arg public function — the *message* is the entire calldata after the 4-byte selector. The expected layout (assembly-parsed):

1. **Signing policy bytes** — the canonical encoding of the signing policy (43 + 22 × `numberOfVoters` bytes). The contract recomputes its hash on the fly — a single `keccak256(sourceChainId ‖ signingPolicyBytes)` over the 32-byte configured source chain id followed by the raw encoded bytes (RLY-23 chain-domain binding, no padding) — and checks it against `toSigningPolicyHashPrivate[rewardEpochId]`. Wrong policy → revert.
2. **Protocol message** (38 bytes) — `protocolId` (1) + `votingRoundId` (4) + `isSecureRandom` (1) + `merkleRoot` (32). The digest this message is signed under is the analogous single keccak, `keccak256(sourceChainId ‖ protocolMessage)` (before the EIP-191 `"\x19Ethereum Signed Message:\n32"` prefix applied at signature verification).
3. **Signatures** — count (2 bytes) followed by 67 bytes per signature: `v` (1) + `r` (32) + `s` (32) + `index` (2). The index points into the signing-policy voter list. The contract recovers each signature, checks the recovered address equals `signingPolicy.voters[index]`, accumulates `signingPolicy.weights[index]`, and short-circuits as soon as accumulated weight passes the threshold.

If the protocol message is finalized using a signing policy whose reward epoch matches `lastInitializedRewardEpoch`, the threshold is **multiplied** by `stateData.thresholdIncreaseBIPS / THRESHOLD_BIPS` — `thresholdIncreaseBIPS` is governance-settable, must be ≥ `THRESHOLD_BIPS = 10000` (i.e. ≥ 1.0×), and defaults to `12000` (1.2×). The exact code (in the `relay()` assembly) is `threshold := div(mul(threshold, thresholdIncreaseBIPS), THRESHOLD_BIPS)`. Providers signing a round that straddles a reward-epoch boundary face a slightly higher bar to compensate for the reduced participation a fresh policy might see.

If the threshold is reached, `merkleRootsPrivate[protocolId][votingRoundId]` is written and `ProtocolMessageRelayed(protocolId, votingRoundId, isSecureRandom, merkleRoot)` is emitted. If not, the call reverts with `NotEnoughWeight()`.

For the FTSO random-number protocol (`stateData.randomNumberProtocolId`), `relay()` additionally updates `stateData.randomVotingRoundId`, `stateData.isSecureRandom`, and the bit in `isSecureRandomMap`. See [Random Number](./RandomNumber.md).

### Cross-epoch boundary

A round whose `votingRoundId < startingVotingRoundIds[nextEpoch]` is signed by the *previous* signing policy. Within the finalization window (`stateData.messageFinalizationWindowInRewardEpochs`), the contract still accepts these. Outside the window, they are rejected. This is a soft-finality boundary: a few epochs of grace, then the historical round is closed for new finalizations.

## Finalizer selection (the grace period)

Within each voting round, a small subset of voters is selected as **grace-period finalizers** — those who get the on-chain reward for finalizing the round if they do so before the grace window closes. The selection is deterministic from the signing policy seed and the round number, and identical for all participants:

1. Let `seed = keccak256(abi.encode(signingPolicySeed, protocolId, votingRoundId))`.
2. Let `W = total weight` and `t = W × 0.05`.
3. Sample voters by repeated `(seed mod W)` look-ups against the cumulative weight, replacing `seed` with `keccak256(seed)` after each successful pick, until the accumulated weight of distinct picked voters exceeds `t`.

Selected voters are precomputable and known before the round starts. If a selected voter calls `relay()` (from their `signingPolicyAddress`) inside the grace period and either finalizes the round *or* tries to finalize an already-finalized round, they earn an equal share of the per-round finalization reward `V(i) / N(i)` where `N(i)` is the size of the selection set. If they don't, their portion is burned. After the grace window closes, the next address to successfully `relay()` takes the entire reward.

The exact grace-period duration is a sub-protocol concern (FTSO anchor, FDC, FCC each have slightly different windows) and is enforced by the off-chain reward calculator, not on-chain.

> **Note.** The grace-period selection is **not** enforced by `Relay` — `relay()` accepts a finalization from any address that produces a valid threshold of signatures. The reward consequence (who gets paid, who gets burned) is computed entirely off-chain by the reward calculator from `ProtocolMessageRelayed` events, the seed, the protocol ID, and the round number. This is by design: putting the selection on-chain would force every relay to do the sortition computation, which would dominate the gas cost.

## Reading finalized data

Consumers on Flare prove individual data items against a finalized root via:

```solidity
function verify(
    uint256 _protocolId,
    uint256 _votingRoundId,
    bytes32 _leaf,
    bytes32[] calldata _proof
) external payable returns (bool);
```

`verify` requires `msg.value >= protocolFeeInWei[_protocolId]` and forwards the fee to `feeCollectionAddress`. It uses OpenZeppelin's `MerkleProof.verifyCalldata`. `protocolId > 1` is enforced — protocol IDs `0` and `1` are reserved.

Other read-only views:

- `isFinalized(protocolId, votingRoundId)` — true if the root is set.
- `merkleRoots(protocolId, votingRoundId)` — read the root directly (only when `signingPolicySetter` is set, i.e. on the live deployments).
- `toSigningPolicyHash(rewardEpochId)` — the signing-policy hash, used by `FlareSystemsManager.signNewSigningPolicy` and by off-chain consumers verifying the policy.
- `getVotingRoundId(timestamp)` — convert a timestamp to a voting round.

## What `Relay` does **not** do

- It does not enforce one-relay-per-round. Anyone can call `relay()` with a valid threshold of signatures and finalize a round; subsequent `relay()` calls for the same `(protocolId, votingRoundId)` succeed but are no-ops with respect to the stored root (it is unchanged once non-zero).
- It does not enforce the grace-period reward selection (see above).
- It does not pay anything to finalizers. Finalizer rewards are part of the off-chain reward calculation, paid via `RewardManager` like all other reward types.

## Migrating from v1

`Relay` supports an optional `oldRelay` chain — if set, `verify`, `merkleRoots`, `getRandomNumberHistorical`, and `toSigningPolicyHash` transparently delegate to the previous `Relay` for any voting round / reward epoch ID strictly less than `startingVotingRoundIdForInitialRewardEpochId` / `initialRewardEpochId`. This lets the contract be redeployed without breaking historical proofs.

The `oldRelay` chain is **home-only**: `initialize` rejects it on a relay-mode (mirror) deployment (`OldRelayNotAllowedInRelayMode`) and requires the old relay itself to be a setter-mode deployment (`OldRelayIncompatible`). Mirrors charge `verify()` fees, and delegating pre-boundary calls to an old relay would entangle its fee schedule with the new contract's fee and fee-exemption logic; on a home (setter-mode) deployment every fee is structurally zero, so delegation is fee-neutral. Mirrors seed a fresh source snapshot instead of chaining.
