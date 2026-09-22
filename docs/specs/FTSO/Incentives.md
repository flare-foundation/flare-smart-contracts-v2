# Volatility Incentives

The block-latency feeds have two parameters that any user can temporarily move by paying a fee:

- **Expected sample size** ($e$) — the average number of providers selected per block of sortition. Larger $e$ means more updates per block.
- **Range** — the maximum cumulative absolute movement $\Delta P / P$ achievable in one block via deltas, controlled by the precision parameter $p$ (since `scale = 1 + p`). Larger range means each unit-delta moves the price farther.

The contract that meters these is [`FastUpdateIncentiveManager`](../../../contracts/fastUpdates/implementation/FastUpdateIncentiveManager.sol). It is also a [`RewardOffersManagerBase`](../../../contracts/protocol/implementation/RewardOffersManagerBase.sol), so it sits on the inflation pipeline and forwards FLR to `RewardManager`. Anyone — DApps, market makers, application developers — can call `offerIncentive(IncentiveOffer)` with FLR attached to bias the parameters during volatility events.

## The `IncentiveOffer`

```solidity
struct IncentiveOffer {
    Range rangeIncrease;
    Range rangeLimit;
}

function offerIncentive(IncentiveOffer calldata _offer) external payable;
```

`Range` is a 128-bit fixed-point fraction (`FixedPointArithmetic.Range`). `rangeLimit` is the caller's "don't bump beyond this" upper bound on the *total* range; `rangeIncrease` is how much they want to add. The contract applies whichever is smaller of `rangeLimit`, `rangeIncreaseLimit` (governance setting), and `range + rangeIncrease`.

Processing in `_processIncentiveOffer`:

1. **Range increase first.** If `rangeIncrease > 0`, compute the cost: `rangeCost = rangeIncreasePrice × rangeIncrease`. The remaining `msg.value - rangeCost` is available for sample-size increase.
2. **Sample-size increase second.** If any contribution is left, it goes into `_increaseExcessOfferValue`. The sample size grows by `mul(frac(payment, excessOfferValue), sampleIncreaseLimit)` — i.e. the marginal cost of pushing the sample size up grows with each successive offer (an exponentially increasing price designed to make the parameter expensive to dominate).
3. Whatever the offer doesn't actually consume (because of `rangeLimit` or zero remaining contribution) is refunded to `msg.sender`.
4. The consumed amount is forwarded: `rewardManager.receiveRewards{value: dc}(currentRewardEpochId, false)` — these funds land in `RewardManager` as a community offer for the *current* reward epoch.
5. `IncentiveOffered(rewardEpochId, dr, de, dc)` is emitted (the per-block `R_vol` reward stream that the reward calculator reads).

The offer is **immediately** active. The next block's sortition uses the bumped parameters.

## Decay

Incentive bumps don't last forever. The base contract [`IncreaseManager`](../../../contracts/fastUpdates/implementation/IncreaseManager.sol) maintains FIFO queues `sampleIncreases` and `rangeIncreases` of pending bumps along with the block they expire on. Each block, `FastUpdater.daemonize()` calls `fastUpdateIncentiveManager.advance()` which calls `_step()` — pops any expired entries, decrementing `sampleSize` and `range` accordingly. Per-bump duration `_dur` is governance-settable; the natural value is roughly the `submissionWindow` length so a bump persists for the lifetime of one round of sortition.

The base values `sampleSize` and `range` (i.e. with all bumps subtracted) are what `getBaseScale()` returns, used by `FastUpdater._adjustScaleOfFeeds` and `resetFeeds` for cross-epoch normalization.

## Inflation top-up

`FastUpdateIncentiveManager` also receives inflation each reward epoch through the standard offers-manager pattern. `_triggerInflationOffers` is called once at reward-epoch switchover by `FlareSystemsManager`:

```solidity
totalRewardsAmount = (totalInflationReceivedWei - totalInflationRewardsOfferedWei)
    × rewardEpochDurationSeconds
    / (intervalEnd - intervalStart);
```

Where `intervalStart` is two epochs back and `intervalEnd` is the start of the current epoch (or the last inflation receipt + 1 day, whichever is later). The amount is then:

1. Logged as `InflationRewardsOffered(nextRewardEpochId, feedConfigurations, totalRewardsAmount)` — the off-chain reward calculator uses this event to know the inflation pool for next epoch.
2. Forwarded to `RewardManager.receiveRewards{value}(nextRewardEpochId, true)`.
3. Tracked in `totalInflationRewardsOfferedWei` so the inflation accounting (via `IITokenPool`) stays consistent.

`_setDailyAuthorizedInflation` and `_receiveInflation` are no-ops — the inflation is held on the contract's balance and only released to `RewardManager` when `_triggerInflationOffers` runs at epoch switchover. This avoids dust accumulation across days.

## Governance levers

| Setting | Method | Notes |
|---------|--------|-------|
| `sampleIncreaseLimit` | `setSampleIncreaseLimit(SampleSize)` | Maximum *additional* sample size purchasable per offer. Used in the formula `_sampleSizeIncrease = frac(payment, excessOfferValue) × sampleIncreaseLimit`. |
| `rangeIncreaseLimit` | `setRangeIncreaseLimit(Range)` | Cap on absolute total range. Validated against the current base range and the current base sample size to ensure precision (= range / sampleSize) cannot exceed 100%. |
| `rangeIncreasePrice` | `setRangeIncreasePrice(Fee)` | Price per unit `Range` of bump. Validated to be high enough that buying 1e-6 of base range costs at least 1 wei — otherwise rounding errors could let buyers overpay or get free movement. |
| Base parameters | `setIncentiveParameters(SampleSize, Range, Fee, uint256)` | Governance reset of the **base** sample size, base range, base sample-size increase price, and bump duration. **Clears all currently active bumps** — so don't run during a volatility event. |

## Reading the live state

| Method | Returns |
|--------|---------|
| `getExpectedSampleSize()` | Current $e$ including any active increases (used by the score-cutoff calculation in `FastUpdater._currentScoreCutoff`). |
| `getRange()` | Current absolute range. |
| `getCurrentSampleSizeIncreasePrice()` | Marginal price (`excessOfferValue`) for the next sample-size purchase. Grows with each preceding purchase. |
| `getPrecision()` | Range / sampleSize, the per-block max relative move. |
| `getScale()` | `1 + p` — the multiplier that `FastUpdater.daemonize` reads into `currentScale` each block. |
| `getBaseScale()` | The scale corresponding to base (no bumps) precision; used only for cross-epoch resets. |

## Reward consequences

Volatility incentives manifest as `R_vol` in the block-latency reward formula (see [Rewarding](./Rewarding.md)). Each block:

$$R_\text{ftot} = R_\text{part} / b_{re} + R_\text{acc} / b_{ve} + R_\text{vol}$$

Where $R_\text{vol}$ for a block is the sum, over still-active incentive offers $o$, of `o.contribution / o.duration_blocks`. Active updates in that block split $R_\text{ftot}$ equally per update, so a higher sample size that came from a paid incentive directly translates into more updates being rewarded that block.
