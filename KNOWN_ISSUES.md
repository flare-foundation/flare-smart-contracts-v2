# Known Issues

### Overflow Issue in `SafePct.mulDivRoundUp`

The `SafePct.mulDivRoundUp` method can overflow due to an unchecked intermediate addition.

**Risk Assessment:** This issue is not exploitable in our current use cases.

### Incorrect Condition in `PublicKeyHistory.setPublicKey`

When the checkpoint history is empty, `setPublicKey` uses `&&` instead of `||` to check the key parts, so a key with exactly one zero part would silently skip writing the checkpoint.

**Risk Assessment:** This issue is not reachable under the current `publicKeyVerifier`, which enforces valid BN256 curve points—preventing keys with a single zero coordinate. It could become reachable if the verifier is changed to a curve that permits such keys.

### Vote Tracking Key Collision in `FlareSystemsManager.signUptimeVote`

The `uptimeVoteVotes` state is keyed by `_uptimeVoteHash` rather than `messageHash`. If different reward epochs produce identical node lists, their `_uptimeVoteHash` values collide, causing vote weights to be shared across epochs.

**Risk Assessment:** The uptime vote functionality is not currently active and is only planned for future use.

### Cross-Chain Signature Replay in `VoterRegistry.registerVoter`

The `messageHash` in `registerVoter` is computed from `(rewardEpochId, _voter)` without including `chainId`. A valid registration signature from one chain (e.g., Songbird) can be replayed on another (e.g., Flare) if the same entity addresses and reward epoch ID are used, potentially registering a voter without their knowledge.

**Risk Assessment:** Exploiting this requires the data provider to reuse the same entity addresses across chains, which is strongly discouraged.

### Reward Epoch Mismatch in `FastUpdater.submitUpdates`

The `SortitionState` used for credential verification is constructed using `currentRewardEpochId` (the epoch at submission time) rather than the reward epoch corresponding to `_updates.sortitionBlock`. When the submission window spans a reward epoch boundary, the seed and provider weights used for verification belong to the wrong epoch.

**Risk Assessment:** This is by design to save gas — resolving the correct reward epoch for a given sortition block would require additional storage writes or extra reads from `FlareSystemsManager` on each submission. The mismatch is only triggerable when a submission window crosses a reward epoch boundary, which is a narrow time window, and the practical impact is limited.

### Forced Native Balance Blocks `RNatAccount.setClaimExecutors`

`_transferCurrentBalanceToOwner` pushes the account's entire native balance to the owner and reverts if that transfer fails, and `setClaimExecutors` invokes it unconditionally. Native forced onto an existing RNat account via `selfdestruct` bypasses the auto-wrapping `receive`, so an owner that cannot accept a plain native transfer can no longer set claim executors for that account, and the forced amount stays on the account.

**Risk Assessment:** This only affects owners that are contracts without a payable `receive`/`fallback`; EOAs always accept the transfer. In practice, claim executors on RNat accounts were only needed to auto-claim FlareDrops, which is no longer required, so no owner is expected to call `setClaimExecutors` going forward. No funds are at risk — claiming, `_wrap = true` withdrawals and external token recovery do not reach the sweep, so the balance remains fully recoverable as `WNat`. `RewardManager._transferOrWrap` applies the same `require(success)` to unwrapped claims, so the requirement that a reward owner be able to accept native tokens, or use only wrapped paths, is a protocol-wide assumption rather than specific to `RNatAccount`.
