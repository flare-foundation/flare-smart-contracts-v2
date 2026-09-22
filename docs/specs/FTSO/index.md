# Flare Time Series Oracle (FTSO)

Decentralized time-series feeds — typically asset prices — secured by data-provider consensus. FTSO has two flavors: **anchor feeds** (one new value every 90 seconds, weighted median of provider submissions) and **block-latency feeds** (per-block incremental updates by a randomly selected subset of providers).

## Documents

- [Overview](./Overview.md) — both feed types at a glance, how they relate
- [Anchor Feeds](./AnchorFeeds.md) — `FtsoFeedPublisher`, `FtsoFeedDecimals`, `FtsoFeedIdConverter`, weighted-median calculation
- [Block-Latency Feeds](./BlockLatencyFeeds.md) — `FastUpdater`, `FastUpdatesConfiguration`, sortition and circular updates
- [Incentives](./Incentives.md) — `FastUpdateIncentiveManager`: sample size, range, scale, duration
- [Feed Management](./FeedManagement.md) — `FtsoInflationConfigurations`, custom feeds, `ChainlinkAdapter`, `SFlrCustomFeed`
- [Rewarding](./Rewarding.md) — `FtsoRewardOffersManager` and the reward claim flow

## Key contracts

- Anchor feeds: [`FtsoV2`](../../../contracts/protocol/implementation/FtsoV2.sol), [`FtsoV2Proxy`](../../../contracts/protocol/implementation/FtsoV2Proxy.sol), and contracts under [`contracts/ftso/implementation/`](../../../contracts/ftso/implementation/)
- Fast updates: contracts under [`contracts/fastUpdates/implementation/`](../../../contracts/fastUpdates/implementation/)
- Custom feeds: [`contracts/customFeeds/`](../../../contracts/customFeeds/), [`contracts/adapters/`](../../../contracts/adapters/)
