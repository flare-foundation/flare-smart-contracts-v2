# Signing Policy

The **signing policy** is the canonical record of who can vote in a given reward epoch and what each voter's weight is. It is generated once per reward epoch by [`FlareSystemsManager`](../../../contracts/protocol/implementation/FlareSystemsManager.sol), threshold-signed by the *previous* reward epoch's voters, and stored on [`Relay`](../../../contracts/protocol/implementation/Relay.sol) where every sub-protocol consumes it for finalization.

## What a signing policy contains

The on-chain signing policy struct (see `IIRelay.SigningPolicy`) is:

| Field | Description |
|-------|-------------|
| `rewardEpochId` | The reward epoch this policy is valid for. |
| `startVotingRoundId` | The first voting round this policy is in force for. New rounds before this round still use the previous policy. |
| `voters[]` | The signing-policy addresses of the registered voters (`uint16`-keyed by index in the order returned by `VoterRegistry.createSigningPolicySnapshot`). |
| `weights[]` | Each voter's normalized weight: `registrationWeight * type(uint16).max / sumOfRegistrationWeights`. The values fit in `uint16`. |
| `threshold` | `mulDivRoundUp(sum(weights), signingPolicyThresholdPPM, PPM_MAX)` — currently set so the threshold is "more than half" of total normalized weight. Stored as `uint16`. |
| `seed` | The secure random number drawn at vote-power-block selection. Used by sub-protocols for finalizer sortition (see [Finalization](./Finalization.md)) and as the random seed exposed to FTSO and FCC. |

`Relay.setSigningPolicy(signingPolicy)` stores its keccak hash, retrievable via `Relay.toSigningPolicyHash(rewardEpochId)`. `Relay.SigningPolicyInitialized(...)` is emitted with the full struct as event data; off-chain consumers reconstruct the policy from logs.

## Definition lifecycle

The orchestrator advances through five phases in `daemonize()`. Each phase ends when the corresponding storage timestamp on `RewardEpochState` becomes non-zero; reading the timestamp tells you exactly which phase the next reward epoch is in.

### 1. Random acquisition

Opens `newSigningPolicyInitializationStartSeconds` (default 2 hours) before `currentRewardEpochExpectedEndTs`. The orchestrator sets `randomAcquisitionStartTs/Block` and emits `RandomAcquisitionStarted(rewardEpochId, ts)`. It also calls `voterRegistry.setNewSigningPolicyInitializationStartBlockNumber(rewardEpochId)` so address-history lookups for the snapshot align on a single block.

On every subsequent `daemonize()` until the phase ends, it polls `relay.getRandomNumber()`. The phase succeeds when the returned `(random, isSecureRandom, randomTs)` satisfies `randomTs > randomAcquisitionStartTs` and `isSecureRandom == true`. If the phase exceeds both `randomAcquisitionMaxDurationSeconds` (8 h) and `randomAcquisitionMaxDurationBlocks` (15 000) without a secure random, the previous reward epoch's `votePowerBlock` and `seed` are reused — the system makes progress with possibly-stale randomness rather than stalling.

### 2. Vote-power-block selection

Once a usable random is in hand, the orchestrator computes the vote-power block by `_selectVotePowerBlock`:

```
numberOfBlocks = (current epoch's randomAcquisitionStartBlock) - (previous epoch's randomAcquisitionStartBlock)
votePowerBlocksAgo = random mod numberOfBlocks
votePowerBlock = currentRandomAcquisitionStartBlock - votePowerBlocksAgo
```

This picks a uniformly random block from the previous random-acquisition window. For the very first reward epoch the lower bound is `min(endBlock, initialRandomVotePowerBlockSelectionSize)` so the genesis case is well-defined.

`randomAcquisitionEndTs/Block` and the chosen `votePowerBlock`, `seed` are stored; `VotePowerBlockSelected(rewardEpochId, votePowerBlock, ts)` is emitted; voter registration is now open.

If a `voterRegistrationTriggerContract` is set (typically `VoterPreRegistry`), it's called via `triggerVoterRegistration(rewardEpochId)` — pre-registered voters get bulk-registered immediately. Failures are caught and surface as `TriggeringVoterRegistrationFailed`.

### 3. Voter registration

See [Voters](./Voters.md). Open until all of:

- `voterRegistrationMinDurationSeconds` (30 minutes) elapsed,
- `voterRegistrationMinDurationBlocks` (900) elapsed,
- at least `signingPolicyMinNumberOfVoters` voters registered.

`isVoterRegistrationEnabled(rewardEpochId)` returns the live status. The window's *upper bound* is implicit: it closes the next time `daemonize()` runs after all three minimums are satisfied.

### 4. Signing policy snapshot

When `daemonize()` first observes voter registration as no longer enabled, it runs `_initializeNextSigningPolicy`:

```solidity
SigningPolicy signingPolicy;
signingPolicy.rewardEpochId       = nextRewardEpochId;
signingPolicy.startVotingRoundId  = _getStartVotingRoundId();
(signingPolicy.voters,
 signingPolicy.weights,
 normalisedWeightsSum)            = voterRegistry.createSigningPolicySnapshot(nextRewardEpochId);
signingPolicy.threshold           = mulDivRoundUp(normalisedWeightsSum, signingPolicyThresholdPPM, PPM_MAX);
signingPolicy.seed                = state.seed;
relay.setSigningPolicy(signingPolicy);
```

`signingPolicySignStartTs/Block` is set on `RewardEpochState`. `Relay.SigningPolicyInitialized` is emitted carrying the full policy. `state.threshold` and `state.startVotingRoundId` are mirrored into `RewardEpochState` so subsequent on-chain checks don't need to ask `Relay`.

`_getStartVotingRoundId` is an internal helper that returns the first voting round the new policy will be in force for; it is set to the current voting round plus `newSigningPolicyMinNumberOfVotingRoundsDelay` (default 3) so there is always a small buffer between the on-chain policy snapshot and the policy taking effect — enough for the previous epoch's voters to threshold-sign it.

### 5. Signing policy sign phase

The *previous* reward epoch's voters now sign the new policy via:

```solidity
function signNewSigningPolicy(
    uint24 _rewardEpochId,
    bytes32 _newSigningPolicyHash,
    Signature calldata _signature
) external;
```

The hash must equal `Relay.toSigningPolicyHash(rewardEpochId)`. The signature is recovered to a signing-policy address and resolved against the **previous** epoch's signing policy via `voterRegistry.getVoterWithNormalisedWeight(rewardEpochId - 1, signingPolicyAddress)` — only voters of the previous epoch can sign. Each voter can only sign once (`_checkIfVoterAlreadySigned` enforces this).

When `state.signingPolicyVotes.accumulatedWeight + weight > rewardEpochState[rewardEpochId - 1].threshold`, the threshold is reached: `signingPolicySignEndTs/Block` is set.

`SigningPolicySigned(rewardEpochId, signingPolicyAddress, voter, ts, thresholdReached)` is emitted on every sign call.

> **Note.** The new reward epoch's start is **not** gated on this signing — see [Epochs / Per-reward-epoch state](./Epochs.md#per-reward-epoch-state). `_isNextRewardEpochId` requires only that the policy is *initialized* (signing-policy hash is non-zero), not that it is signed. What threshold-signing the policy by the previous epoch's voters *does* gate is (a) the late-signing burn factor in [`FlareSystemsCalculator.calculateBurnFactorPPM`](./Weighting.md#burn-factor-for-late-signing) — which requires `signingPolicySignEndTs != 0` to compute — and (b) the rewards-signing flow, which uses the previous-epoch threshold to validate `signRewards` signatures. Slow signing therefore only impacts reward distribution for the current (signing) epoch's voters, never the start of the next reward epoch.

### 6. Reward epoch start

`_isNextRewardEpochId(nextRewardEpochId)` returns true once:

- `block.timestamp >= currentRewardEpochExpectedEndTs`,
- `_getSigningPolicyHash(nextRewardEpochId) != 0` (i.e. the policy was *initialized* in step 4 — note that signing in step 5 is **not** a precondition),
- `_getCurrentVotingEpochId() >= rewardEpochState[nextRewardEpochId].startVotingRoundId`.

When all three hold, `daemonize()` advances `currentRewardEpochExpectedEndTs += rewardEpochDurationSeconds`, sets `rewardEpochStartTs/Block`, calls any registered `IIRewardEpochSwitchoverTrigger` contracts (each protocol's reward-offers manager registers itself here so inflation can flow), and emits `RewardEpochStarted(rewardEpochId, startVotingRoundId, ts)`.

## Penalties for late signing

Late signing of the new policy is the only protocol penalty applied at the FSP layer (sub-protocols apply their own penalties on top). [`FlareSystemsCalculator.calculateBurnFactorPPM`](../../../contracts/protocol/implementation/FlareSystemsCalculator.sol) computes a burn factor for each voter:

- `0` if the policy was signed within `signingPolicySignNonPunishableDurationSeconds` (20 min) **and** `signingPolicySignNonPunishableDurationBlocks` (600), or if the voter individually signed within those bounds (`signBlock <= startBlock + signingPolicySignNonPunishableDurationBlocks`).
- Otherwise, a quadratic ramp on `punishableBlocks = signBlock - lastNonPunishableBlock`: `linear = punishableBlocks * PPM_MAX / signingPolicySignNoRewardsDurationBlocks`, `burn = linear² / PPM_MAX`.
- Saturates at `PPM_MAX` (full burn) when `punishableBlocks >= signingPolicySignNoRewardsDurationBlocks` (default 600).

Voters who never sign at all are treated as having signed at the end of the phase (`signBlock = endBlock`) for this calculation. The off-chain reward calculator multiplies this burn factor into the voter's `FEE`, `WNAT`, and `MIRROR` claims for reward epoch `_rewardEpochId`. The signing-policy phase that drives the penalty is for *the next* signing policy (`_rewardEpochId + 1`), since that's the policy the voters of `_rewardEpochId` are responsible for signing.

## Reading the policy

Off-chain consumers and other contracts reconstruct the policy from `Relay.SigningPolicyInitialized` event data and verify it against `Relay.toSigningPolicyHash(rewardEpochId)`. Per-voter weights and addresses can also be queried directly from `VoterRegistry` (`getRegisteredSigningPolicyAddresses`, `getVoterWithNormalisedWeight`, etc.). The threshold for an epoch is `RewardEpochState.threshold` (queryable via `FlareSystemsManager.getThreshold(rewardEpochId)`).
