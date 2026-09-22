# FTSO Rewarding

FTSO rewards are paid out of two streams — a slice of FLR inflation, and community / volatility offers — split between **anchor feeds** (~70%) and **block-latency feeds** (~30%, configurable). Like every other Flare protocol, FTSO follows the standard pattern: on-chain offers managers collect FLR and emit events; off-chain calculation produces a Merkle tree of claims; the active signing policy threshold-signs the reward hash; and beneficiaries claim from `RewardManager`. See [FSP/Rewarding](../FSP/Rewarding.md) for the cross-protocol scaffolding.

This page covers the FTSO-specific reward formulas and the on-chain entrypoints — not the off-chain math, which is implemented in the reward calculator.

## On-chain entrypoints

Two offers managers, one per FTSO flavor:

- [`FtsoRewardOffersManager`](../../../contracts/ftso/implementation/FtsoRewardOffersManager.sol) — **anchor feeds**.
- [`FastUpdateIncentiveManager`](../../../contracts/fastUpdates/implementation/FastUpdateIncentiveManager.sol) — **block-latency feeds**, also handles `IncentiveOffer` (see [Incentives](./Incentives.md)).

Both extend [`RewardOffersManagerBase`](../../../contracts/protocol/implementation/RewardOffersManagerBase.sol) and forward FLR to `RewardManager.receiveRewards{value}(epochId, isInflation)`.

### `FtsoRewardOffersManager.offerRewards`

Anyone can offer rewards for the **next** reward epoch's anchor feeds:

```solidity
struct Offer {
    uint120 amount;
    bytes21 feedId;
    uint16  minRewardedTurnoutBIPS;
    uint24  primaryBandRewardSharePPM;
    uint24  secondaryBandWidthPPM;
    address claimBackAddress;
}

function offerRewards(uint24 _nextRewardEpochId, Offer[] calldata _offers) external payable;
```

The contract enforces:

- `_nextRewardEpochId == currentRewardEpochId + 1`.
- `block.timestamp + newSigningPolicyInitializationStartSeconds < currentRewardEpochExpectedEndTs` — i.e. offers must be made before the next epoch's signing-policy initialization opens (otherwise the off-chain calculator would not see them in time).
- Per-offer parameter bounds (`minRewardedTurnoutBIPS ≤ 10000`, `*PPM ≤ 1_000_000`, `amount ≥ minimalRewardsOfferValueWei`).
- Sum of offer amounts equals `msg.value` (no over- or under-payment).

For each offer, the contract emits `RewardsOffered(nextRewardEpochId, feedId, decimals, amount, minRewardedTurnoutBIPS, primaryBandRewardSharePPM, secondaryBandWidthPPM, claimBackAddress)` (with decimals snapshotted from `FtsoFeedDecimals.getDecimals(feedId, _nextRewardEpochId)` so the offer's reward calculation uses the decimals that will be in force at settlement). Then forwards `msg.value` to `RewardManager` as a non-inflation offer for the next reward epoch.

`claimBackAddress` (defaults to `msg.sender`) is the recipient for any portion of the offer that goes unawarded — for example if a feed's secondary band is empty, that portion gets returned via a `DIRECT` claim back to this address.

### Inflation offers

Both managers receive inflation through [`InflationReceiver`](../../../contracts/inflation/implementation/InflationReceiver.sol). At reward-epoch switchover, `FlareSystemsManager` calls `triggerRewardEpochSwitchover` on every registered offers manager. Each:

1. Computes its slice of inflation as a time-weighted average:

   ```
   totalRewardsAmount = (totalInflationReceivedWei - totalInflationRewardsOfferedWei)
                       × rewardEpochDurationSeconds
                       / (intervalEnd - intervalStart);
   ```

   (`intervalStart` is two epochs back; `intervalEnd` is the start of the *current* epoch or the last inflation receipt + 1 day, whichever is later.)
2. For `FtsoRewardOffersManager`: walks `FtsoInflationConfigurations.getFtsoConfigurations()`, splits the slice by per-config `inflationShare`, and emits one `InflationRewardsOffered(nextRewardEpochId, feedIds, decimals, amount, minRewardedTurnoutBIPS, primaryBandRewardSharePPM, secondaryBandWidthPPMs, mode)` per configuration. For `FastUpdateIncentiveManager`: emits a single `InflationRewardsOffered(nextRewardEpochId, feedConfigurations, totalRewardsAmount)` covering all fast-update feeds.
3. Forwards the slice to `RewardManager.receiveRewards{value}(nextRewardEpochId, true)`.
4. Tracks `totalInflationRewardsOfferedWei` for the `IITokenPool` accounting interface.

Both managers' `_setDailyAuthorizedInflation` and `_receiveInflation` are no-ops — inflation is held on-balance and only released at epoch switchover. This avoids tiny daily transfers and makes the `intervalStart`/`intervalEnd` averaging stable.

## Per-round rewarded-feed selection

A round's rewards are computed on **one** randomly-chosen feed, not aggregated across the catalog. This stops providers from gaming by dumping accuracy on whatever feeds they expect to be rewarded.

For voting round $j$, the rewarded feed is selected using `keccak256(s, V)` where:

- `s` is the **earliest secure** random number from any voting round $j + k$ for $k \geq 1$,
- `V` is the count of registered feeds at $j$.

If no secure random arrives within the rest of the current reward epoch *and* the first 30 rounds of the next epoch, no feed is selected and **all rewards** for round $j$ (and every subsequent round in the epoch that's similarly unselected) are burned. This ties the FTSO reward correctness to the same secure-random source the rest of FSP relies on (see [FSP/RandomNumber](../FSP/RandomNumber.md)).

## Anchor feed rewards

Each round's anchor allocation $R_\text{anchor}(j)$ splits 80 / 10 / 10 across accuracy, signing, and finalization:

### Accuracy (~80%)

Two reward bands:

- **Primary (IQR) band** — the weighted interquartile range of submitted estimates. Submissions that land in this range get a share of `R_IQR(j)` proportional to their FTSO calculation weight share among IQR submitters. Border ties are broken randomly.
- **Secondary (PCT) band** — `[median × (1 − q), median × (1 + q)]` where `q` is the per-feed `secondaryBandWidthPPM` (set in `FtsoInflationConfigurations` for inflation-funded offers, in the `Offer` struct for community offers). Submitters that land here split `R_PCT(j)`.

The split between IQR and PCT pools is governed by `primaryBandRewardSharePPM`: `R_IQR(j) = R_med(j) × primaryBandRewardSharePPM / 1e6`, `R_PCT(j) = R_med(j) − R_IQR(j)`. Bands typically overlap, so a single submission can earn from both.

If the secondary band is empty (a theoretical edge case), `R_PCT(j)` is burned.

### Signing (~10%)

Providers who:

- Received accuracy rewards on the rewarded feed for round $j$, **and**
- Submitted a valid signature for the agreed Merkle root in the sign phase or before finalization

share `R_sign(j)` weighted by their normalized signing weight. Late signatures (after finalization but before sign-phase end) still count.

### Finalization (~10%)

`R_fin(j)` is split equally among the providers selected for the grace-period finalizer set (see [FSP/Finalization](../FSP/Finalization.md)) who:

- Received accuracy rewards on the rewarded feed for round $j$, **and**
- Submitted a valid finalization in the grace window.

If no selected provider finalizes, the **first** provider to do so after the grace window ends takes the entire `R_fin(j)`. Selected providers who don't finalize, or who didn't get accuracy rewards, lose their share to the burn address.

### Penalties

Two penalizable behaviors, each burning a chunk of the offending provider's earnings:

- **Mismatched reveal** — the revealed `(rand_i, data_i)` doesn't hash to the round's `commitHash_i`.
- **Excess signature** — signing more than one Merkle root in the sign phase.

Each penalty burns `R_pen × W_iC* × R_anchor(j)` of the provider's accumulated rewards for the reward epoch (where `W_iC*` is the provider's normalized FTSO calculation weight and `R_pen` is a system parameter). Penalties are applied at reward-epoch end. If a provider's FTSO penalties exceed its FTSO earnings, the overflow can spill into FDC and other protocol earnings — i.e. the provider can lose more than the FTSO revenue it earned in that epoch.

## Block-latency feed rewards

Each block, the total rewards on offer satisfy:

$$R_\text{ftot} = \frac{R_\text{part}}{b_{re}} + \frac{R_\text{acc}}{b_{ve}} + R_\text{vol}$$

where:

- $R_\text{part}$ — **participation reward** for the reward epoch, split equally across all blocks in the epoch ($b_{re}$). Comes from inflation. Allocated proportionally to the number of updates each provider submits in the reward epoch.
- $R_\text{acc}$ — **accuracy reward** for the voting epoch, split equally across blocks in the voting epoch ($b_{ve}$). Triggered only when the block-latency feed value at $t_\text{start}(j+1)$ lies within the **primary band** of the round's rewarded anchor feed. If the band is missed, $R_\text{acc} = 0$ for that voting epoch's blocks.
- $R_\text{vol}$ — **volatility reward** for the block, derived from active `IncentiveOffer`s (see [Incentives](./Incentives.md)). For each active offer with monetary value $m$ and remaining duration $T_v$ blocks, $m / T_v$ is added to the per-block reward.

Per-block, **all updates submitted that block share $R_\text{ftot}$ equally** — so a higher sample size (more eligible providers selected by sortition) directly translates into more updates collecting reward.

Total inflation for both flavors is split by governance:

$$R_\text{FTSO}(j) = R_\text{anchor}(j) + R_\text{block}(j).$$

The split parameter is set on `FtsoInflationConfigurations` and `FastUpdateIncentiveManager`'s respective `inflationShare` configs.

## Putting it together

For a single reward epoch, the FTSO reward graph is:

```
inflation → InflationReceiver → triggerRewardEpochSwitchover
                                    │
                                    ├─→ FtsoRewardOffersManager.       FastUpdateIncentiveManager.
                                    │   _triggerInflationOffers       _triggerInflationOffers
                                    │     emits InflationRewardsOffered     emits InflationRewardsOffered
                                    └─→ both forward FLR → RewardManager (inflation = true)

community offers (FTSO anchor)  → FtsoRewardOffersManager.offerRewards
                                    emits RewardsOffered
                                    forwards FLR → RewardManager (inflation = false)

volatility offers (FTSO blocks) → FastUpdateIncentiveManager.offerIncentive
                                    emits IncentiveOffered
                                    forwards consumed amount → RewardManager (inflation = false)

per voting round events →
   FastUpdater.FastUpdateFeeds, FastUpdateFeedsSubmitted (block-latency)
   Submission events + Relay.ProtocolMessageRelayed (anchor)

  (off-chain reward calculator reads everything above
   + signing policy + per-feed registrations
   → builds RewardClaim Merkle tree)

→ FlareSystemsManager.signRewards (current signing policy threshold)
→ RewardManager.claim / autoClaim by beneficiaries
```

The off-chain reward calculator is the only piece that knows the IQR/PCT/signing/finalization formulas; on-chain the contracts only collect FLR, log the inputs to calculation, and gate the claim on the signed reward hash.
