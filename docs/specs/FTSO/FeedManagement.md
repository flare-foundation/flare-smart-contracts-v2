# Feed Management

There are two registries for feeds: [`FastUpdatesConfiguration`](../../../contracts/fastUpdates/implementation/FastUpdatesConfiguration.sol) for the **fast-update feeds** (the bulk of the FTSO catalog), and [`FtsoV2`](../../../contracts/protocol/implementation/FtsoV2.sol)'s `customFeeds` mapping for **custom feeds** (computed-from-other-feeds, like sFLR / stXRP rate-of-return adapters). Per-reward-epoch settings — primary/secondary band parameters, default feed list, inflation shares — live in [`FtsoInflationConfigurations`](../../../contracts/ftso/implementation/FtsoInflationConfigurations.sol).

This page covers the registries, the feed ID format, custom-feed development, and the Chainlink-compatibility adapter.

## Feed ID format

Feed IDs are `bytes21` values: the first byte is a **category**, the remaining 20 bytes are a left-padded ASCII name. [`FtsoFeedIdConverter`](../../../contracts/ftso/implementation/FtsoFeedIdConverter.sol) is a pure helper:

```solidity
function getFeedId(uint8 _category, string memory _name) external pure returns(bytes21);
function getFeedCategoryAndName(bytes21 _feedId) external pure returns(uint8 _category, string memory _name);
```

**Categories**:

| Range | Use |
|-------|-----|
| `0` – `31` (`0x00`–`0x1F`) | Reserved system / standard feeds (e.g. crypto pairs, fiat, commodities). |
| `32` – `63` (`0x20`–`0x3F`) | **Custom feeds**. `FtsoV2._isCustomFeedId` recognizes this range and routes reads through the `customFeeds` registry rather than `FastUpdater`. |
| `64` – `255` | Currently unused. |

Names shorter than 20 bytes are right-padded with `0x00` in the ID.

## Fast-update feed registry: `FastUpdatesConfiguration`

[`FastUpdatesConfiguration`](../../../contracts/fastUpdates/implementation/FastUpdatesConfiguration.sol) is the source of truth for **which** fast-update feeds exist and at **what index** in the in-storage `feeds[]` array of [`FastUpdater`](../../../contracts/fastUpdates/implementation/FastUpdater.sol). One on-chain `FeedConfiguration` per feed:

```solidity
struct FeedConfiguration {
    bytes21 feedId;
    uint32  rewardBandValue;   // reward band value (interpreted off-chain) in relation to the median
    uint24  inflationShare;    // share of FTSO Fast Updates inflation, relative to other feeds
}
```

- `addFeeds(FeedConfiguration[])` (governance) — adds new feeds, reusing freed indices from `unusedIndices` first. Then calls `FastUpdater.resetFeeds(indices)` to seed each feed's running value from the latest published anchor value.
- `updateFeeds(FeedConfiguration[])` (governance) — replaces `rewardBandValue` and `inflationShare` for an already-registered feed without touching its index or running value.
- `removeFeeds(bytes21[])` (governance) — frees indices to `unusedIndices` and zeros the slot in `FastUpdater`. The freed index will be reused by the next `addFeeds`.

`feedIdToIndex[feedId]` is stored as `index + 1` so a zero return clearly means "not registered". `getFeedIndex(feedId)` reverts with `"feed does not exist"` for unknown feeds. Removed slots show as `bytes21(0)` in `getFeedIds()` — consumers iterating the catalog must skip these.

## Custom feeds: `IICustomFeed` and `FtsoV2`

A **custom feed** is any contract implementing [`IICustomFeed`](../../../contracts/customFeeds/interface/IICustomFeed.sol):

```solidity
function feedId() external view returns (bytes21);
function getCurrentFeed() external payable returns (int256 value, int8 decimals, uint64 timestamp);
function calculateFee()   external view  returns (uint256 fee);
```

`FtsoV2` keeps a per-ID registry:

```solidity
struct CustomFeedData {
    IICustomFeed customFeed;
    uint96       index;  // 1-based
}
mapping(bytes21 customFeedId => CustomFeedData) private customFeeds;
```

Three governance methods manage it:

- `addCustomFeeds(IICustomFeed[])` — registers a new custom feed. Reverts if the feed's category is outside 32–63 (`"invalid feed category"`) or if the same ID is already registered.
- `replaceCustomFeeds(IICustomFeed[])` — points an existing feed ID at a new contract (used to upgrade a custom feed implementation). Emits `CustomFeedReplaced`.
- `removeCustomFeeds(bytes21[])` — unregisters. The last entry is swap-removed into the freed slot.

When a consumer calls unsigned `FtsoV2.getFeedById(feedId)` or signed `FtsoV2.getCurrentFeed(feedId)`, the contract:

1. Translates `feedId` through the rename map (`feedIdChanges`) to the current ID — this is what supports renaming a feed without breaking integrations.
2. If the (current) category is in 32–63, looks up the `CustomFeedData`, requires `address(customFeed) != 0`, and routes the read to `customFeed.getCurrentFeed()`.
3. Otherwise, routes the read to `FastUpdater.fetchCurrentFeeds(indices)` with the index from `FastUpdatesConfiguration.getFeedIndex(feedId)`.

FtsoV2 calculates and checks each downstream fee before forwarding it. If the value remaining from the current call is below that fee, it reverts with `"too low fee"` before calling that downstream source. FtsoV2 forwards exactly the required amount; overpayment is not refunded, and the current caller's excess is burned after a successful read.

The signed getter passes through negative custom-feed values; the unsigned getter reverts with `"value negative"`. The corresponding `InWei` getters apply the same signed/unsigned distinction after converting to 18 decimals.

For batched calls (`getFeedsById` / `getCurrentFeeds`), `FtsoV2` separates fast-update feeds from custom feeds, calls the relevant target for each, and stitches results back together. Payment routing depends on the batch:

- Each custom feed's fee is calculated and checked by `FtsoV2`, and the custom feed receives exactly that amount. This preserves the deterministic `"too low fee"` revert even after an earlier feed has consumed all value supplied by the call.
- If the batch contains fast-update feeds, `FtsoV2` calculates and checks their aggregate fee and forwards exactly that amount to `FastUpdater`.
- After a successful read, `FtsoV2` burns the current caller's excess native-token value.

Only the current call's `msg.value` is available for its fees; a pre-existing FtsoV2 balance cannot subsidize a later caller and remains untouched. Consequently, FtsoV2-routed reads do not overpay `FastUpdater` or a custom feed. Direct callers of either downstream contract remain subject to that contract's own payment behavior. Call `calculateFeeById` / `calculateFeeByIds` and avoid overpaying.

FastUpdater's `freeFetchAddresses` allowlist requires its immediate caller to send zero value. Neither FtsoV2 nor a custom feed that forwards value to FastUpdater may be added to this allowlist, because FtsoV2 routes the fee reported by the configured fee source.

**Batch timestamp semantics.** All four ID-based batch getters revert with `"feed ids empty"` for an empty list. `getFeedsById` / `getFeedsByIdInWei` return a single timestamp for a non-empty batch and revert with `"timestamps do not match"` if the requested feeds do not all report the same timestamp. All fast-update feeds share `FastUpdater`'s timestamp, and the bundled custom feeds (`SFlrCustomFeed`, `StXrpCustomFeed`) pass that same timestamp through, so a mismatch is only possible when the batch includes a custom feed with its own timestamp source. For such batches, `getCurrentFeeds` / `getCurrentFeedsInWei` return a timestamp **per feed** instead of enforcing equality. The `getCurrentFeeds` pair is also the **signed** read: [`IICustomFeed.getCurrentFeed`](../../../contracts/customFeeds/interface/IICustomFeed.sol) returns `int256`, so a custom feed with a signed source can report negative values through both variants. Wei conversion truncates toward zero when scaling down, but panics with arithmetic overflow if its power-of-ten factor or scaled-up result would not fit in the return type (`int256` for signed reads or `uint256` for unsigned reads); the unsigned `getFeedsById` family also reverts with `"value negative"` for negative custom-feed values.

### Custom feed: `SFlrCustomFeed`

[`SFlrCustomFeed`](../../../contracts/customFeeds/implementation/SFlrCustomFeed.sol) is a derivative feed for sFLR (Flare's liquid-staking token). It returns "the value, in the reference asset, of one sFLR share":

1. Reads the underlying reference feed (e.g. `FLR/USD`) from `FastUpdater.fetchCurrentFeeds`.
2. Calls `sFlr.getPooledFlrByShares(value)` to convert from FLR units to sFLR units (the LSD's exchange rate).
3. Returns the converted value with the reference feed's decimals and timestamp.

`calculateFee` defers to `FeeCalculator.calculateFeeByIds([referenceFeedId])` — the required fee is the same as for the underlying feed. `getCurrentFeed` forwards all value it receives to `FastUpdater`. FtsoV2-routed reads send it only the calculated fee, while a caller invoking the custom feed directly can still overpay; `FastUpdater` does not refund such direct overpayment.

[`StXrpCustomFeed`](../../../contracts/customFeeds/implementation/StXrpCustomFeed.sol) follows the same pattern for staked XRP.

The custom-feed pattern is open-ended: anyone can write an `IICustomFeed` implementation that combines / synthesizes / rate-converts FTSO feeds, and governance can register it in `FtsoV2`. Examples a future custom feed might compute: weighted basket prices, USD-denominated stake, cross-asset implied rates.

## Per-reward-epoch settings: `FtsoInflationConfigurations`

[`FtsoInflationConfigurations`](../../../contracts/ftso/implementation/FtsoInflationConfigurations.sol) holds an array of `FtsoConfiguration` records that the off-chain reward calculator and `FtsoRewardOffersManager._triggerInflationOffers` use to allocate inflation across feed groups:

```solidity
struct FtsoConfiguration {
    bytes   feedIds;                 // packed bytes21[] (length must be % 21 == 0)
    uint24  inflationShare;          // weight for splitting inflation across configurations
    uint16  minRewardedTurnoutBIPS;  // min turnout for the round to be eligible for rewards
    uint24  primaryBandRewardSharePPM;
    bytes   secondaryBandWidthPPMs;  // packed uint24[] - per-feed q parameter for the PCT band
    uint16  mode;                    // rewards split mode (0 means equally, 1 means random,...)
}
```

Validation in `_checkFtsoConfiguration`:

- `minRewardedTurnoutBIPS ≤ 10000`
- `primaryBandRewardSharePPM ≤ 1_000_000`
- `feedIds.length % 21 == 0` and `secondaryBandWidthPPMs.length % 3 == 0`
- The two arrays must have matching counts (`feedIds.length / 21 == secondaryBandWidthPPMs.length / 3`).
- Each per-feed `secondaryBandWidthPPMs` value must be ≤ `1_000_000`.

Governance methods: `addFtsoConfiguration`, `replaceFtsoConfiguration(index, …)`, `removeFtsoConfiguration(index)` (last entry swap-removed).

`FtsoRewardOffersManager._triggerInflationOffers` (per reward-epoch switchover) iterates the configurations, splits the inflation pool by `inflationShare`, and emits one `InflationRewardsOffered` per configuration with the per-feed parameters. The off-chain reward calculator uses these to compute the IQR and PCT band rewards for each feed group.

## Chainlink compatibility: `ChainlinkAdapter`

[`ChainlinkAdapter`](../../../contracts/adapters/implementation/ChainlinkAdapter.sol) wraps a single FTSO feed in [Chainlink's `AggregatorV3Interface`](../../../contracts/adapters/interface/AggregatorV3Interface.sol), so existing dApps written for Chainlink price feeds can read FTSO data without code changes. It uses the unsigned `getFeedByIdInWei` path, so a custom feed that reports a negative value is not supported and causes the adapter read to revert:

- `decimals()` returns `18` (constant — the adapter always reports values in wei).
- `latestRoundData()` calls `IFtsoV2View(flareContractRegistry.getContractAddressByHash(keccak256("FtsoV2"))).getFeedByIdInWei(ftsoFeedId)`, returns the value as `int256 _answer` and the timestamp packed into `_roundId`, `_startedAt`, `_updatedAt`, `_answeredInRound` (all the same value — Chainlink's "round" model doesn't quite map to FTSO's per-block updates, so the timestamp does duty for everything).
- `getRoundData(uint80)` reverts with `NotImplemented()` — historical lookups are not supported.

`staleTimeSeconds` (governance-settable) bounds how old the underlying FTSO timestamp can be. If `block.timestamp - timestamp >= staleTimeSeconds`, the adapter reverts with `StaleData()`. Setting `staleTimeSeconds = 0` disables the check (useful for testing only).

The adapter is **UUPS-upgradeable** with governance-gated `upgradeToAndCall`. Each adapter instance wraps exactly one feed; deploying the same code with different `_ftsoFeedId` parameters at construction lets governance run multiple Chainlink-shaped feeds.

The `flareContractRegistry` address is hard-coded (`0xaD67…6019`) — the same on every Flare network. Calling code does not need to know any FTSO-specific addresses; it just calls Chainlink's standard interface.
