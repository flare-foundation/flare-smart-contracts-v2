# Staking

The Flare validator-staking subsystem has one production on-chain piece in this repo:

- [`ValidatorRewardOffersManager`](../../contracts/staking/implementation/ValidatorRewardOffersManager.sol) — the inflation receiver for validator-staking rewards.

P-chain stake mirroring itself is read through the `flare-periphery` `IPChainStakeMirror` interface (the deployed `PChainStakeMirror` lives in the v1 repo); this repo only carries a mock `PChainStakeMirrorVerifier` ([`contracts/mock/PChainStakeMirrorVerifier.sol`](../../contracts/mock/PChainStakeMirrorVerifier.sol)) for testing.

The validator-staking infrastructure itself lives in the v1 contracts repo (`PChainStakeMirror`, the staking module of the Flare validator binary). This repo handles the **rewarding** layer for validator participation.

## Reward stream

Validator staking takes a fixed inflation share — currently 30% per [FSP / Rewarding](./FSP/Rewarding.md). The flow:

1. Inflation arrives at [`ValidatorRewardOffersManager`](../../contracts/staking/implementation/ValidatorRewardOffersManager.sol) through the standard `InflationReceiver` interface.
2. At each reward-epoch switchover, `_triggerInflationOffers` fires. Same time-weighted formula as every other offers manager:

   ```
   totalRewardsAmount = (totalInflationReceivedWei - totalInflationRewardsOfferedWei)
                       × rewardEpochDurationSeconds
                       / (intervalEnd - intervalStart);
   ```

3. A single `InflationRewardsOffered(nextRewardEpochId, totalRewardsAmount)` event is emitted (no per-feed configuration — staking has no feed shape).
4. `RewardManager.receiveRewards{value}(nextRewardEpochId, true)` is called to forward the FLR.

The off-chain reward calculator then distributes the validator pool across providers based on:

- **Active stake.** The amount of FLR staked to the provider's node IDs at the reward epoch's vote-power block (read from `PChainStakeMirror`).
- **Uptime.** The provider's recorded uptime over the reward epoch (signed via `FlareSystemsManager.signUptimeVote`; see [FSP / Rewarding / Uptime vote sign](./FSP/Rewarding.md#1-uptime-vote-sign)).
- **Minimal participation.** Per [FSP / Rewarding / FIP-10 passes](./FSP/Rewarding.md#minimal-participation-conditions-fip-10-passes) — a validator must have ≥80% uptime and ≥1M FLR active self-bond to earn anything; ≥3M FLR self-bond and ≥15M FLR active stake to earn or lose passes.

Validator rewards are produced as `MIRROR`-type claims in the unified rewards Merkle tree (beneficiary = node ID, distributed to stakers per their share of stake on that node).

## P-chain stake mirroring

P-chain stake doesn't live on the Flare C-chain — validators stake on the P-chain (Avalanche-style staking) and the stake state is **mirrored** to the C-chain so smart contracts can read it. The mirroring contract is [`PChainStakeMirror`](https://github.com/flare-foundation/flare-smart-contracts) in the v1 repo, consumed in this repo through the `flare-periphery` `IPChainStakeMirror` interface.

[`FlareSystemsCalculator`](../../contracts/protocol/implementation/FlareSystemsCalculator.sol) reads mirrored stake when computing voter registration weights — when its `pChainStakeMirror` address is set it calls `pChainStakeMirror.batchVotePowerOfAt(nodeIds, votePowerBlock)` to get each voter's mirrored stake at the snapshot block. See [FSP / Weighting](./FSP/Weighting.md).

## Node ID registration

A data provider must register each P-chain node ID it operates with `EntityManager.registerNodeId(nodeId, certificateRaw, signature)`. The `NodePossessionVerifier` (configured in `EntityManager`) verifies that the supplied `certificate + signature` proves possession of the node's BLS key. Up to `maxNodeIdsPerEntity` node IDs can be linked to a single entity. See [FSP / Voters / Node IDs](./FSP/Voters.md#node-ids).

Once registered, the node ID's mirrored stake counts toward the entity's FSP signing weight. Stake on a node ID that's not registered to any entity contributes to no one — the staker's own claim path is through the validator's reward, not via FSP rewards.

## C-chain stake (forward-compat)

[`RewardManager`](../../contracts/protocol/implementation/RewardManager.sol) supports a `CCHAIN` claim type and a `cChainStakeEnabled` flag. When enabled (currently disabled by default), C-chain delegators can claim a share of validator rewards proportional to their C-chain stake. The plumbing is via [`ICChainStake`](../../contracts/userInterfaces/ICChainStake.sol) and [`ICChainVotePower`](../../contracts/userInterfaces/ICChainVotePower.sol).

When `cChainStakeEnabled` is set, the off-chain reward calculator produces an additional `CCHAIN` claim per validator delegate, beneficiary being the C-chain stake address. Deactivating it stops new C-chain claims from being computed (existing claims for past epochs remain claimable until they expire).

## Validators in FSP / FCC

Validator participation is enmeshed with the rest of the system:

- **Daemon execution.** Every Flare validator runs the `FlareDaemon` genesis contract's daemonised hooks, which is what calls `daemonize()` on `FlareSystemsManager` and `FastUpdater` every block. So validators are doing both block production and protocol orchestration.
- **Relay clients.** Validators that are also data providers run relay clients, which sign FSP voting-round results and FCC instructions. This earns them additional FSP / FTSO / FDC / FCC rewards on top of validator-staking rewards.
- **Cross-protocol passes.** A provider that fails any of the FIP-10 minimal-participation conditions in *any* protocol can lose all rewards (see [FSP / Rewarding](./FSP/Rewarding.md#minimal-participation-conditions-fip-10-passes)). Validators that aren't also data providers don't lose validator rewards from this — but validators that *are* data providers expose all their earnings (validator + FTSO + FDC + FCC) to the cross-protocol pass system.

## Reward-offer flow on-chain (summary)

```
inflation → InflationReceiver → ValidatorRewardOffersManager
                                  │
                                  └─ on reward-epoch switchover:
                                     emit InflationRewardsOffered(nextEpochId, amount)
                                     receiveRewards{value}(nextEpochId, true) → RewardManager

(off-chain reward calculator reads InflationRewardsOffered + uptime votes
 + PChainStakeMirror events + minimal-participation tally → builds claims)

→ FlareSystemsManager.signRewards (current signing policy)
→ RewardManager.claim by beneficiary (node-ID) and per-staker share
```

There's no community-offer entry point on `ValidatorRewardOffersManager` — community parties can't fund validator rewards directly the way they can fund FTSO rewards. The validator pool is purely inflation-funded.
