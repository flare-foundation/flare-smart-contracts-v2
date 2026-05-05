# Block-Latency Feeds

The block-latency feeds — historically branded **FTSO Fast Updates** — produce a fresh value per block (not per voting epoch). They run as a separate protocol from the anchor feeds, with their own contracts, their own sortition-based eligibility, and their own incentive layer. The headline contract is [`FastUpdater`](../../../contracts/fastUpdates/implementation/FastUpdater.sol).

The model: each block, a small randomly-selected subset of registered providers submits a **packed array of two-bit deltas** (one per feed: `00` = no change, `01` = up, `11` = down). The deltas multiply (or divide) the feed's running value by the current `Scale`. Eight feed values are packed into a single 32-byte storage slot for efficiency.

## Per-block lifecycle

The protocol runs on every block via [`FastUpdater.daemonize`](../../../contracts/fastUpdates/implementation/FastUpdater.sol), called by the genesis [`FlareDaemon`](https://gitlab.com/flarenetwork/flare-smart-contracts/-/blob/master/contracts/genesis/implementation/FlareDaemon.sol):

1. **Apply pending deltas** (`_applySubmitted`) — reads the circular buffer of submitted delta blobs (`submittedDeltas`, capacity `MAX_SUBMITTED_DELTAS_BACKLOG = 500`) from the previous block(s), applies each two-bit delta to the corresponding feed value (multiply or divide by `currentScale`), and clears the backlog.
2. **Detect new voting epoch** — if `_getCurrentVotingEpochId() > currentVotingEpochId`, emit `FastUpdateFeeds(votingEpochId-1, feeds[], decimals[])` so off-chain rewards calculation has the per-epoch end-of-epoch values.
3. **Detect new reward epoch** — if `flareSystemsManager.getCurrentRewardEpochId()` advanced, run `_adjustScaleOfFeeds()` to re-scale every feed against the new base scale (which the incentive manager refreshes each epoch).
4. **Delete old data** — remove records older than `MAX_BLOCKS_HISTORY = 100` blocks.
5. **Step the incentive manager** — `fastUpdateIncentiveManager.advance()` decays active sample-size and range increases.
6. **Recompute the next score cutoff** — `thresholds[(block.number + 1) % (submissionWindow + 1)] = _currentScoreCutoff()` records the threshold that submitters in the *next* block will need to beat.
7. **Refresh `currentScale`** — `currentScale = fastUpdateIncentiveManager.getScale()` (reflects any incentive-driven scale increase).

The result: every block has a deterministic score cutoff, and any pending submissions from earlier blocks have been folded into the per-feed running values before the block finishes.

## Sortition

Each block is a round of sortition. Provider $i$'s probability of being selected is:

$$p_\mathrm{sort}(i) = W_{i,\mathrm{sign}}^* \cdot e$$

where $W_{i,\mathrm{sign}}^*$ is the **normalized signing weight** (from FSP — see [FSP/Weighting](../FSP/Weighting.md)) and $e$ is the **expected sample size**, set per reward epoch by [`FastUpdateIncentiveManager`](../../../contracts/fastUpdates/implementation/FastUpdateIncentiveManager.sol) and dynamically increasable through volatility incentives (see [Incentives](./Incentives.md)).

Selection is independent across providers — the actual count of selected providers per block follows a binomial distribution with mean $e$.

The cryptographic implementation:

- Each provider has a **sortition public key** (a `G1Point` on the alt-bn128 curve) registered through [`EntityManager.registerPublicKey`](../../../contracts/protocol/implementation/EntityManager.sol). `FastUpdater` itself implements `IIPublicKeyVerifier` — `verifyPublicKey(voter, p1, p2, verificationData)` is the verifier installed in `EntityManager` for FTSO-purpose public keys, and uses BLS-style key-of-knowledge verification (`Bn256.verifySignature(pk, sha256(voter), σ, R)`).
- `FastUpdater._currentScoreCutoff()` translates the `expectedSampleSize` into a uniform-distribution score threshold against the curve order $p$. Each provider has weight $W_{i,\mathrm{sign}}^*$ scaled to virtual providers (`VIRTUAL_PROVIDER_BITS = 12` → 4096 virtual providers per provider weight unit).
- A provider proves eligibility for block $B$, replicate $k$ via a [`Sortition.verifySortitionCredential`](../../../contracts/fastUpdates/lib/Sortition.sol) check: a Schnorr-proof that `keccak256(pk, B, k) < scoreCutoff[B]` using the FSP signing-policy seed for the current reward epoch (`flareSystemsManager.getSeed(rewardEpochId)`) as additional input. If the provider has weight $w$, they may attempt up to $w \times 2^{12}$ replicates per block.

Selected providers know in advance — sortition is verifiable from public state — and have a window of `submissionWindow` blocks (settable by governance, default ~10) to submit.

## Submission

Selected providers call:

```solidity
struct FastUpdates {
    uint256 sortitionBlock;
    SortitionCredential sortitionCredential;
    bytes deltas;
    Signature signature;
}

function submitUpdates(FastUpdates calldata _updates) external;
```

The contract:

1. Checks `sortitionBlock <= block.number < sortitionBlock + submissionWindow`.
2. Recovers `signingPolicyAddress` from the ECDSA signature over `sha256(abi.encode(sortitionBlock, sortitionCredential, deltas))`.
3. Looks up the provider's sortition public key and normalized weight via `voterRegistry.getPublicKeyAndNormalisedWeight(currentRewardEpochId, signingPolicyAddress)`. Computes the per-provider sortition weight: `mulDivRoundUp(normalizedWeight, 1 << VIRTUAL_PROVIDER_BITS, normalisedWeightsSum)`.
4. Recomputes the per-credential `hashedRandomness = sha256(pk, sortitionBlock, replicate)` and rejects it if the same credential has already been submitted (`submittedHashes[sortitionBlock]`). This prevents the same provider from claiming multiple updates per replicate per block.
5. Verifies the sortition proof against the recorded threshold `thresholds[sortitionBlock % (submissionWindow + 1)]`.
6. Stores the `deltas` blob in the circular `submittedDeltas` buffer at index `currentDelta` (advances by one mod 500).
7. Increments `numOfUpdatesInBlock[block.number]`.
8. Emits `FastUpdateFeedsSubmitted(votingEpochId, signingPolicyAddress)`.

The deltas blob itself is **not validated for content** here — encoding correctness is enforced by `_applySubmitted` semantics (each two-bit slot is interpreted directly), and incorrect deltas just produce a wrong update that the reward calculator can later penalize via the accuracy criterion.

## Delta encoding

Each feed in a single update consumes 2 bits:

| Bits | Meaning | Effect |
|------|---------|--------|
| `00` | no change | feed unchanged |
| `01` | +1 unit | `feed = (feed × scale) >> 127` |
| `11` | −1 unit | `feed = (feed << 127) / scale` |
| `10` | (reserved) | not used |

`scale` is `(1 + p)` in fixed-point form where `p` is the precision parameter, currently a 15-bit fractional value chosen so that one unit-delta represents a small per-update step (~0.01–0.1% depending on epoch). Volatility incentives temporarily raise `scale` for a configurable duration so that per-block movements get larger.

128 deltas pack into one 32-byte storage slot; for $N$ feeds the deltas blob is $\lceil N/128 \rceil$ slots long. Eight 32-bit feed values pack into one 32-byte storage slot, so the feed table is $\lceil N/8 \rceil$ slots long.

## Reading values

Consumers use [`FtsoV2.getFeedByIdInWei(feedId)`](../../../contracts/protocol/implementation/FtsoV2.sol) (or sibling methods), which transparently route fast-update feed IDs to `FastUpdater.fetchCurrentFeeds(indices)`. `fetchCurrentFeeds`:

1. Looks up the per-feed read fee through [`FeeCalculator`](../../../contracts/userInterfaces/IFeeCalculator.sol) and requires the caller's `msg.value` to cover it (forwards the fee to `feeDestination`). Addresses on the `freeFetchAddresses` allowlist (governance-set) are exempt.
2. Reads the latest feed values *and* applies any deltas still sitting in `submittedDeltas` between `backlogDelta` and `currentDelta` — i.e. a fetch that runs in the same block as a `submitUpdates` sees the freshest possible value, not just the last `daemonize`-applied state.
3. Returns the in-storage decimals (in a packed `bytes` array) and the timestamp of the most recent submission (`_getLastSubmissionTs`).

The `_timestamp` field reflects the latest submission, the latest daemonized block, or the previous block — whichever is freshest given the in-memory delta backlog.

## Adding and removing feeds

Feed catalog management is delegated to [`FastUpdatesConfiguration`](../../../contracts/fastUpdates/implementation/FastUpdatesConfiguration.sol):

- **`addFeeds(FeedConfiguration[])`** (governance) — adds new feeds, reusing any indices in `unusedIndices` from prior removals. Each `FeedConfiguration` carries `feedId`, `rewardBandValue` (the symmetric percentage band parameter `q` used by the anchor reward calculation; see [Rewarding](./Rewarding.md) and [Anchor Feeds](./AnchorFeeds.md)), and `inflationShare`. After registering, calls `FastUpdater.resetFeeds(indices)` to seed each new feed's running value from the latest published anchor value.
- **`updateFeeds(FeedConfiguration[])`** (governance) — replace `rewardBandValue` / `inflationShare` for an existing feed (does not change the feed's index or running value).
- **`removeFeeds(bytes21[])`** (governance) — frees indices to the `unusedIndices` pool; then calls `FastUpdater.removeFeeds(indices)` which zeros the corresponding feed slot.

`FastUpdater.resetFeeds(indices)` reads `ftsoFeedPublisher.getCurrentFeed(feedId)` for each new index and seeds the value, requiring the anchor feed to be at most `MAX_FEED_AGE_IN_VOTING_EPOCHS = 20` voting epochs old. If the anchor is too stale, the reset reverts — governance must wait for a fresh anchor before adding the feed.

`getUnusedIndices()` and `getNumberOfFeeds()` let off-chain tooling enumerate the registry. Removed-but-still-allocated slots show as `bytes21(0)` in `getFeedIds()`; consumers should skip these.

## Cross-feed reset on reward-epoch change

At each reward-epoch boundary, `FastUpdater._adjustScaleOfFeeds` walks every feed and:

- Re-derives a new base scale from `fastUpdateIncentiveManager.getBaseScale()`,
- Calls `_adjustDecimals(value, decimals, scale)` to ensure each value sits in a band where the multiplicative scale produces meaningful precision (target: `2^28` < value < `2^29`, with at least 3 bits of precision per multiplication).

This keeps feeds within the storage-packed `int32` range as the underlying asset prices change over time and as the scale parameter changes. The scale update itself happens implicitly each block via `currentScale = fastUpdateIncentiveManager.getScale()` in `daemonize`.

## What governance can change

| Lever | Who | Effect |
|-------|-----|--------|
| `submissionWindow` | governance, via `setSubmissionWindow(uint8)` | Number of blocks each round of sortition stays valid. Capped at `MAX_BLOCKS_HISTORY - 1 = 99`. Resets `thresholds` ring buffer. |
| `freeFetchAddresses` | governance, via `setFreeFetchAddresses(address[])` | Allowlist of contracts that can call `fetchCurrentFeeds` without paying. |
| `feeDestination` | governance, via `setFeeDestination(address)` | Where collected read fees flow. |
| Sample size / range / fees | governance via [`FastUpdateIncentiveManager`](./Incentives.md) | The expected sample size $e$, range, and incentive economics. |
| Feed catalog | governance via `FastUpdatesConfiguration` | Add / update / remove feeds. |

The protocol does not have a separate pause switch — the only way to halt fast updates is to either set `submissionWindow = 0` (which makes every submission expired) or remove all feeds.
