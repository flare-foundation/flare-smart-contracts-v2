# Anchor Feeds

The anchor protocol — historically branded "FTSO Scaling" — produces one weighted-median value per voting epoch (90 s) per registered feed. It runs entirely on the FSP voting infrastructure: providers submit through `Submission`, sign through `Submission.submitSignatures`, and the result Merkle root is finalized through `Relay`. The corresponding leaf data is then republished to a fast on-chain lookup by [`FtsoFeedPublisher`](../../../contracts/ftso/implementation/FtsoFeedPublisher.sol).

This page describes the on-chain side; the four-phase commit / reveal / sign / finalize protocol itself is run by off-chain providers reading and writing through `Submission` and `Relay`.

## Round structure

Each anchor voting round spans **two consecutive voting epochs** but is identified by the start epoch ID. The four phases:

| Phase | Window (relative to round start at $t_\text{start}(j)$) | Where |
|-------|--------------------------------------------------------|-------|
| **Commit** | $[t_\text{start}(j),\ t_\text{start}(j+1))$ — full 90 s of epoch $j$ | `Submission.submit1` from each provider's `submitAddress`; calldata carries `commitHash = hash(addr, j, rand_i, data_i)` |
| **Reveal** | $[t_\text{start}(j+1),\ t_\text{start}(j+1) + 45\text{s})$ — first half of epoch $j+1$ | `Submission.submit2` carrying `(rand_i, data_i)`, validated off-chain against the prior commit |
| **Sign** | Starts at end of reveal | `Submission.submitSignatures` — providers compute the weighted median, build the round's Merkle root, sign it |
| **Finalize** | Overlapping with sign phase | `Relay.relay()` — once threshold signatures are collected, the root is written |

### Commit hash

```
commitHash_i(j) = keccak256(addr_i || j || rand_i || data_i)
```

`data_i` is the per-feed packed `int32` vector (4 bytes per feed) encoding provider $i$'s estimate `Anchor_i(j)` for each feed in offset-binary form. `rand_i` is a 32-byte locally-generated random; revealed alongside `data_i`, it both blinds the commit (against pre-image searches) and seeds the round's random number (see [Random Number](../FSP/RandomNumber.md)).

### Weighted-median calculation

The aggregate is computed off-chain. Providers' submissions `Anchor_i(j)` are ordered ascending; let $W_C = \sum_i W_{i,C}$ be the total **FTSO calculation weight** across all providers (capped delegation, no stake — see [FSP/Weighting / FTSO calculation weight](../FSP/Weighting.md#ftso-calculation-weight-a-different-weight)), and $W_m = \sum_{i=1}^m W_{i,C}$ the running cumulative. The median is the value at the index where $W_m$ first crosses $\lceil W_C/2 \rceil$ (or the average of two adjacent values for even cumulative sums). All providers compute the same aggregate, so the Merkle root over per-feed `(votingRoundId, id, value, turnoutBIPS, decimals)` leaves is deterministic.

### Round random number

The per-round random is the modular sum of every provider's revealed `rand_i`:

$$\mathrm{rand}(j) = \left(\sum_i \mathrm{rand}_i\right) \bmod 2^{256}.$$

Providers who fail to reveal are **benched** for the next 20 voting rounds (their reveal-fee subsidies are withheld and they don't accrue accuracy rewards). If any provider was benched in round $j$, the random for that round is flagged **insecure**; otherwise (and if at least two unbenched providers contributed), it is flagged **secure**. Both the value and the secure flag travel as part of the protocol message that `Relay.relay()` ingests, and end up in `stateData.isSecureRandom` and `isSecureRandomMap`. See [FSP/RandomNumber](../FSP/RandomNumber.md).

### Finalization

Once the threshold of weighted signatures over the round's Merkle root is reached, any address can call `Relay.relay()` to write `merkleRootsPrivate[100][votingRoundId]`. The grace-period reward selection (about 5% of total weight, sampled from the signing policy seed) determines who gets paid for finalizing — the off-chain reward calculator credits the grace-period set when one of them finalizes within the window, otherwise it credits the first finalizer afterwards. See [FSP/Finalization](../FSP/Finalization.md).

## Republishing to `FtsoFeedPublisher`

`Relay` stores only the Merkle root per round. To make per-feed values available cheaply on-chain, [`FtsoFeedPublisher`](../../../contracts/ftso/implementation/FtsoFeedPublisher.sol) holds:

- **Latest** value per feed: `lastFeeds[feedId] → Feed`
- **History ring buffer** per feed: `publishedFeeds[feedId][votingRoundId % feedsHistorySize] → Feed`

The `Feed` struct (from `IFtsoFeedPublisher`):

```solidity
struct Feed {
    uint32 votingRoundId;
    bytes21 id;
    int32   value;
    uint16  turnoutBIPS;   // share of total weight that contributed to this median
    int8    decimals;
}
```

Two ways to publish:

- **`publish(FeedWithProof[])`** — open to anyone. Each entry carries a Merkle proof against `relay.merkleRoots(ftsoProtocolId, feed.votingRoundId)`. The contract verifies and stores. Useful for ensuring a particular feed/round is on-chain when no privileged publisher has done it yet.
- **`publishFeeds(Feed[])`** — restricted to the configured `feedsPublisher` address. Skips the Merkle proof — used by a trusted relayer service to bulk-publish without extra calldata. The trust assumption is that the address is run by infrastructure that itself proves against `Relay` before calling.

Both paths emit `FtsoFeedPublished(votingRoundId, id, value, turnoutBIPS, decimals)`. Reads:

- `getCurrentFeed(feedId)` returns the latest published `Feed`.
- `getFeed(feedId, votingRoundId)` returns the historical entry; reverts with `"too old voting round id"` if the round is outside the ring-buffer window or `"feed not published yet"` if it was never republished.

`feedsHistorySize` is set immutable at construction (typical mainnet value: tens of thousands of rounds, weeks of history).

## Decimals

[`FtsoFeedDecimals`](../../../contracts/ftso/implementation/FtsoFeedDecimals.sol) holds per-feed decimal exponents independently of the feed value, with **delayed-effective** updates:

- `setDecimals(feedIds[], decimals[])` is governance-only. New values become effective `decimalsUpdateOffset` reward epochs in the future (immutable, must be ≥ 2). This means the off-chain reward calculator and reward-offers manager always know the decimals that will apply to a given epoch's settlement before that epoch starts.
- Per-feed history is stored as `Decimals[]` ordered by `validFromEpochId`. `_getDecimals(feedId, rewardEpochId)` walks back to find the right entry; if no entry applies, falls back to `defaultDecimals`.
- `getCurrentDecimals(feedId)`, `getDecimals(feedId, rewardEpochId)` (must be ≤ current + offset), and bulk variants on packed `bytes21` lists.

Decimals are also part of each `Feed` struct in `FtsoFeedPublisher`, so consumers reading the published value get matching decimals atomically. The two views agree at any time because `FtsoRewardOffersManager` quotes `ftsoFeedDecimals.getDecimals(offer.feedId, _nextRewardEpochId)` when emitting `RewardsOffered`, fixing the decimals for the offer's reward epoch ahead of time.

## Verifying anchor data on-chain

A consumer contract that wants to use a published anchor value can either:

1. Read it directly from `FtsoFeedPublisher.getCurrentFeed(feedId)` (cheap, but trusts the publisher and requires periodic republication).
2. Verify a Merkle proof itself via `FtsoV2.verifyFeedData(FeedDataWithProof)` (which calls `proof.verifyCalldata(relay.merkleRoots(100, votingRoundId), keccak256(abi.encode(body)))`).

For frequent reads, `FtsoV2.getFeedByIdInWei(feedId)` is the recommended path — it uses the block-latency feed for the current value, with the anchor feed acting as the periodic accuracy ground truth that the reward calculator and `FastUpdater._adjustScaleOfFeeds` ride on.

## Penalization

The off-chain reward calculator burns rewards when:

- A provider's reveal hash doesn't match its commit (mismatched reveal).
- A provider signs more than one Merkle root in the sign phase (excess signature).

Each penalization burns `R_pen × W_iC* × R_anchor(j)` of the provider's accumulated rewards for the round, applied at reward-epoch end. `R_pen` is a system parameter set by governance. Penalties exceeding the provider's FTSO earnings can spill over into FDC and other protocols. See [Rewarding](./Rewarding.md).
