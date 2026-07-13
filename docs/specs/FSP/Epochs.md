# Epochs

FSP organizes time into two nested grids: the **voting epoch** (the basic protocol round, currently 90 seconds) and the **reward epoch** (the accounting period for voter registration, signing policies, and reward distribution, currently 3360 voting epochs ≈ 3.5 days). All sub-protocols read these boundaries from [`FlareSystemsManager`](../../../contracts/protocol/implementation/FlareSystemsManager.sol).

## Voting epoch

A voting epoch is a fixed-length window during which sub-protocols collect commit/reveal data and signatures for one round.

| Parameter | Source | Typical value |
|-----------|--------|---------------|
| `firstVotingRoundStartTs` | `FlareSystemsManager` immutable | network deployment timestamp |
| `votingEpochDurationSeconds` | `FlareSystemsManager` immutable | `90` |

The voting-epoch ID at any timestamp $t$ is

$$\mathrm{votingEpoch}(t) = \left\lfloor \frac{t - \mathrm{firstVotingRoundStartTs}}{\mathrm{votingEpochDurationSeconds}} \right\rfloor.$$

Voting epoch $v$ covers blocks whose timestamps fall in $[t_{\text{start}}(v),\, t_{\text{start}}(v+1))$ where $t_{\text{start}}(v) = \mathrm{firstVotingRoundStartTs} + v \cdot \mathrm{votingEpochDurationSeconds}$.

Within a voting epoch, sub-protocols schedule their phases against a **reveal deadline** offset (typically 45 s — the boundary between the commit and reveal phases of FTSO anchor). The exact deadline is defined per sub-protocol; FSP itself does not enforce a single global value. See `getCurrentVotingEpochId` and the corresponding view methods on `FlareSystemsManager` for the canonical accessors.

Each voting epoch begins with a hook on the orchestrator: when `daemonize()` observes `currentVotingEpochId > lastInitializedVotingRoundId`, it calls [`Submission.initNewVotingRound`](../../../contracts/protocol/implementation/Submission.sol) with the registered submit / submit-signatures addresses for the current reward epoch, marking those addresses eligible for one gas-refunded `submit1` / `submit2` / `submit3` / `submitSignatures` call this round.

## Reward epoch

A reward epoch spans a configurable number of voting epochs and is the unit at which voter registration and reward distribution occur.

| Parameter | Source | Typical value |
|-----------|--------|---------------|
| `firstRewardEpochStartTs` | `FlareSystemsManager` immutable | derived from `firstVotingRoundStartTs + firstRewardEpochStartVotingRoundId * votingEpochDurationSeconds` |
| `rewardEpochDurationSeconds` | `FlareSystemsManager` immutable | derived: `rewardEpochDurationInVotingEpochs * votingEpochDurationSeconds` (typically `3360 * 90 = 302400` s) |
| `currentRewardEpochExpectedEndTs` | `FlareSystemsManager` storage | updated each time a new epoch starts |

Important: the *expected* end timestamp of a reward epoch (`currentRewardEpochExpectedEndTs`) is when the lifecycle would prefer the next epoch to start; the **actual** start can be later, gated by [`FlareSystemsManager._isNextRewardEpochId`](../../../contracts/protocol/implementation/FlareSystemsManager.sol):

```solidity
return block.timestamp >= currentRewardEpochExpectedEndTs &&
    _getSigningPolicyHash(_nextRewardEpochId) != bytes32(0) &&
    _getCurrentVotingEpochId() >= rewardEpochState[_nextRewardEpochId].startVotingRoundId;
```

A new reward epoch starts when **all three** conditions hold:

1. Wall-clock time has reached `currentRewardEpochExpectedEndTs`.
2. The next signing policy has been **initialized** and published to `Relay` (i.e. voter registration completed and `_initializeNextSigningPolicy` ran). Note: *signing* of the policy by the previous epoch's voters is **not** required here — see [Signing Policy](./SigningPolicy.md).
3. The current voting epoch has reached `startVotingRoundId` (which is set when the policy is initialized to current voting round + `newSigningPolicyMinNumberOfVotingRoundsDelay`, default 3).

The two paths that delay the new epoch beyond `currentRewardEpochExpectedEndTs` are: (a) the random acquisition phase failing to acquire a secure random in time (the orchestrator falls back to the previous epoch's vote-power block and seed after `randomAcquisitionMaxDuration*` is exceeded), and (b) voter registration not completing in the minimum window. Slow signing of the policy itself does not delay the new epoch — it only affects late-signing burn factors and reward distribution for the *previous* epoch.

The reward-epoch ID for a given voting-epoch ID is computed against the per-epoch `startVotingRoundId` recorded in `RewardEpochState` — the orchestrator stores the actual starting voting round of every epoch when the epoch begins.

## Per-reward-epoch state

Every reward epoch has a `RewardEpochState` record (in `FlareSystemsManager`) tracking the timestamps and block numbers of each phase the orchestrator drives through. The phases, in order:

1. **Random acquisition** — `randomAcquisitionStartTs/Block`, `randomAcquisitionEndTs/Block`. Opens `newSigningPolicyInitializationStartSeconds` (default 2 hours) before `currentRewardEpochExpectedEndTs`. Ends when a secure FTSO random with a timestamp later than the start arrives, **or** when both `randomAcquisitionMaxDurationSeconds` (8 hours) and `randomAcquisitionMaxDurationBlocks` (15 000) elapse, in which case the previous epoch's vote-power block and seed are reused.
2. **Voter registration** — opens at the moment of vote-power-block selection (`randomAcquisitionEndTs`). Closes when the orchestrator detects all of:
   - `voterRegistrationMinDurationSeconds` (default 30 minutes) has elapsed,
   - `voterRegistrationMinDurationBlocks` (default 900) has elapsed,
   - at least `signingPolicyMinNumberOfVoters` voters have registered.
3. **Signing policy initialization** — once registration closes, `_initializeNextSigningPolicy` snapshots weights via `VoterRegistry.createSigningPolicySnapshot`, computes the threshold, and publishes the policy to `Relay`. `signingPolicySignStartTs/Block` is set; `Relay.SigningPolicyInitialized` is emitted.
4. **Signing policy sign phase** — the *previous* reward epoch's voters call `signNewSigningPolicy`. When accumulated weight passes the previous policy's threshold, `signingPolicySignEndTs/Block` is set.
5. **Reward epoch start** — when the new policy is signed and `newSigningPolicyMinNumberOfVotingRoundsDelay` (default 3) voting rounds have passed since signing, the orchestrator advances `currentRewardEpochExpectedEndTs`, sets `rewardEpochStartTs/Block`, and emits `RewardEpochStarted`.
6. **Submit uptime vote phase** — after the previous reward epoch's `submitUptimeVoteMinDurationSeconds` and `submitUptimeVoteMinDurationBlocks` elapse from its start, voters submit `submitUptimeVote(rewardEpochId, nodeIds[], signature)`. Tracked per voter in `submitUptimeVoteVotes`.
7. **Sign uptime vote phase** — `signUptimeVote(rewardEpochId, uptimeVoteHash, signature)`. When threshold is reached, the canonical `uptimeVoteHash[rewardEpochId]` is fixed and `rewardsSignStartTs/Block` is set — this is the gate that unlocks rewards signing.
8. **Rewards sign phase** — `signRewards(rewardEpochId, noOfWeightBasedClaims, rewardsHash, signature)`. When threshold is reached, `rewardsSignEndTs/Block` is set and `rewardsHash[rewardEpochId]` is recorded; `RewardManager` is now ready to honor claims for this epoch.

Each phase is driven by `FlareSystemsManager.daemonize()`, which is called once per block by the genesis [`FlareDaemon`](https://gitlab.com/flarenetwork/flare-smart-contracts/-/blob/master/contracts/genesis/implementation/FlareDaemon.sol) contract (defined in the v1 contracts repo, deployed at network genesis). Off-chain participants watch the corresponding events:

- `RandomAcquisitionStarted(rewardEpochId, ts)`
- `VotePowerBlockSelected(rewardEpochId, votePowerBlock, ts)`
- `Relay.SigningPolicyInitialized(rewardEpochId, ...)`
- `SigningPolicySigned(rewardEpochId, signingPolicyAddress, voter, ts, thresholdReached)`
- `RewardEpochStarted(rewardEpochId, startVotingRoundId, ts)`
- `SignUptimeVoteEnabled(rewardEpochId, ts)`
- `UptimeVoteSubmitted(rewardEpochId, ...)`, `UptimeVoteSigned(rewardEpochId, ..., thresholdReached)`
- `RewardsSigned(rewardEpochId, ..., thresholdReached)`

## Reward-epoch expiration and cleanup

Old reward epochs eventually expire. Two paths drive expiration:

- If `triggerExpirationAndCleanup` is enabled, every time a new reward epoch starts the orchestrator runs `_closeExpiredRewardEpochs(currentRewardEpochId)` and `_cleanupOnRewardEpochFinalization()` to reclaim FLR from unclaimed rewards and free the WNat vote-power checkpoint.
- Otherwise, on each `daemonize()` the orchestrator advances `rewardEpochIdToExpireNext` past any reward epoch whose vote-power block is older than `RewardManager.cleanupBlockNumber()`, calling `RewardManager.closeExpiredRewardEpoch` for each. Failures emit `ClosingExpiredRewardEpochFailed` and stop the loop.

The expiry offset itself is controlled by `rewardExpiryOffsetSeconds` and the cleanup block is managed by `IICleanupBlockNumberManager`.
