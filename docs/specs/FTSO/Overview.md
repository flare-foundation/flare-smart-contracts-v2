# FTSO Overview

The Flare Time Series Oracle (FTSO) provides decentralized time-series feeds — typically asset prices — secured by data-provider consensus. FTSO uses **protocol ID 100** (`FtsoV2.FTSO_PROTOCOL_ID`) on `Relay`. There are two distinct feed protocols, both running against the same FSP signing policy:

| Flavor | Cadence | Mechanism | Headline contract |
|--------|---------|-----------|-------------------|
| **Anchor feeds** (also known as "FTSO Scaling") | One value per voting epoch (90 s) | Commit / reveal / sign / finalize across all registered providers; weighted median; Merkle-rooted via `Relay` | [`FtsoFeedPublisher`](../../../contracts/ftso/implementation/FtsoFeedPublisher.sol) |
| **Block-latency feeds** (also known as "FTSO Fast Updates") | One or more updates per block | Random subset of providers (cryptographic sortition) submits ±1 unit deltas applied to a running value | [`FastUpdater`](../../../contracts/fastUpdates/implementation/FastUpdater.sol) |

A consumer reading "the current price of FLR/USD" gets a single number through [`FtsoV2`](../../../contracts/protocol/implementation/FtsoV2.sol), which transparently reads the block-latency feed (the live, frequently-updated value) and uses the anchor feed only as a periodic re-sync anchor.

## How the two flavors fit together

Conceptually, the anchor feed is the slow, accurate ground truth, and the block-latency feed is the fast tracker that follows it:

- Each voting epoch, the anchor protocol produces a fresh weighted-median value via commit / reveal / sign / finalize. The result is published to `Relay` (Merkle root) and republished into [`FtsoFeedPublisher`](../../../contracts/ftso/implementation/FtsoFeedPublisher.sol)'s public lookup.
- Between anchor updates, the block-latency feed evolves block-by-block: at each block, a randomly sampled subset of registered providers submits a 2-bit delta per feed (`-1`, `0`, `+1`). The deltas are applied to a packed in-storage running value via the configured precision parameter.
- When a new anchor arrives, [`FastUpdater._adjustScaleOfFeeds`](../../../contracts/fastUpdates/implementation/FastUpdater.sol) (called once per reward epoch) and [`FastUpdater.resetFeeds`](../../../contracts/fastUpdates/implementation/FastUpdater.sol) (called when feeds are added or governance triggers a reset) realign the live block-latency value to the anchor.

In normal operation the block-latency feed is what consumers read; the anchor feed is what they (and the system) trust as the slower-but-stronger correctness check. The reward calculator additionally uses the anchor feed's IQR / PCT bands as the accuracy reference for both flavors (see [Rewarding](./Rewarding.md)).

## Public reader: `FtsoV2`

[`FtsoV2`](../../../contracts/protocol/implementation/FtsoV2.sol) is a UUPS-upgradeable proxy that consolidates feed reads behind one interface:

- `getFeedById(feedId)` / `getFeedByIdInWei(feedId)` — current value, decimals, timestamp; either from `FastUpdater` or from a registered custom feed contract (see [Feed Management](./FeedManagement.md)).
- `getFeedsById(feedIds[])` / `getFeedsByIdInWei(feedIds[])` — batched reads with a single shared timestamp; revert if the feeds report different timestamps (only possible with custom feeds — see [Feed Management](./FeedManagement.md)).
- `getCurrentFeed(feedId)` / `getCurrentFeedInWei(feedId)` / `getCurrentFeeds(feedIds[])` / `getCurrentFeedsInWei(feedIds[])` — the **signed** read family (`int256` values), with the batched variants returning a timestamp per feed for batches mixing custom feeds with their own timestamp source. All ID-based batch getters revert if the list is empty. Fast-update feeds are always non-negative, but a custom feed with a signed source may report negative values. Wei conversion truncates toward zero when scaling down, but panics with arithmetic overflow if its power-of-ten factor or scaled-up result would not fit in the return type (`int256` for signed reads or `uint256` for unsigned reads); the `getFeedsById` family stays unsigned and also reverts with `"value negative"` for negative values.
- `getFeedByIndex(index)` / `getFeedByIndexInWei(index)` — the same, looked up by `FastUpdatesConfiguration` index (fast-update feeds only, so a single timestamp always applies).
- `verifyFeedData(FeedDataWithProof)` — Merkle-prove an FTSO anchor leaf against `Relay.merkleRoots(100, votingRoundId)`.
- `getSupportedFeedIds()`, `getFeedIdChanges()` — discovery.
- `calculateFeeById(feedId)` / `calculateFeeByIds(feedIds[])` — fee preview (paid through [`FeeCalculator`](../../../contracts/userInterfaces/IFeeCalculator.sol) for fast-update feeds, through the custom-feed contract for custom feeds).

Reads are **payable** because `FastUpdater.fetchCurrentFeeds` charges per-feed fees (calculated by [`FeeCalculator`](../../../contracts/userInterfaces/IFeeCalculator.sol)) unless its immediate caller is on the `freeFetchAddresses` allowlist. For an FtsoV2-routed read, that caller is `FtsoV2` or a custom-feed contract, not the end user. FtsoV2 calculates and checks each downstream fee before forwarding it. If the value remaining from the current call is below that fee, it reverts with `"too low fee"` before calling that downstream source. FtsoV2 forwards only the required amount, never uses a pre-existing balance to subsidize a call, and does not refund overpayment; it burns the current caller's excess after a successful read while leaving any pre-existing balance untouched. Neither FtsoV2 nor a custom feed that forwards value to FastUpdater may be added to `freeFetchAddresses`, because allowlisted callers must send zero value. See [Feed Management](./FeedManagement.md) for the exact routing rules.

`FTSO_PROTOCOL_ID` is hard-coded to `100`. The contract supports renaming feed IDs (`changeFeedIds`) — useful when a feed's underlying asset is rebranded or replaced — without requiring callers to update.

## Code layout

```
contracts/protocol/implementation/
├── FtsoV2.sol                     # public reader, UUPS upgradeable
├── FtsoV2Proxy.sol                # UUPS proxy storage contract

contracts/ftso/implementation/
├── FtsoFeedPublisher.sol          # anchor feed publication + history
├── FtsoFeedDecimals.sol           # per-feed decimals, with reward-epoch offset
├── FtsoFeedIdConverter.sol        # (category, name) <-> bytes21 utility
├── FtsoInflationConfigurations.sol# per-reward-epoch FTSO config (default feeds, IQR shares, secondary band widths)
├── FtsoRewardOffersManager.sol    # community + inflation reward offers for anchor feeds

contracts/fastUpdates/implementation/
├── FastUpdater.sol                # block-latency feed values, sortition, deltas
├── FastUpdatesConfiguration.sol   # registered fast-update feed list (governance)
├── FastUpdateIncentiveManager.sol # volatility incentive offers + inflation rewards for fast updates
├── FeeCalculator.sol              # per-feed read fees
├── IncreaseManager.sol            # base for sample-size / range increases
├── CircularListManager.sol        # base for ring-buffer state

contracts/customFeeds/implementation/
├── SFlrCustomFeed.sol             # sFLR rate-of-return-derived feed
├── StXrpCustomFeed.sol            # stXRP rate-of-return-derived feed

contracts/adapters/implementation/
├── ChainlinkAdapter.sol           # exposes one FTSO feed via Chainlink AggregatorV3Interface
├── ChainlinkAdapterProxy.sol      # UUPS proxy
```

The next docs in this section walk through each piece in detail.

## Feed identifiers

A feed ID is a `bytes21` value: 1 byte **category** + 20 bytes **name** (`bytes21 = bytes1(category) || bytes20(name)`). [`FtsoFeedIdConverter`](../../../contracts/ftso/implementation/FtsoFeedIdConverter.sol) is a pure utility for the mapping. Categories `0–31` are reserved for system feeds; categories `32–63` (`0x20–0x3F`) identify **custom feeds** ([`FtsoV2._isCustomFeedId`](../../../contracts/protocol/implementation/FtsoV2.sol)). Calls to `FtsoV2.getFeedById` route by category: anything in 32–63 goes to a registered `IICustomFeed` implementation (`SFlrCustomFeed`, `StXrpCustomFeed`, future feeds), everything else goes through the fast-updates pipeline.
