// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9;

import { Signature } from "../ISignature.sol";
import { ITeeOracleInstructionsSender } from "./ITeeOracleInstructionsSender.sol";

// Domain prefix for the TEE-oracle feed-update signed payload. See `SignedPayload`.
// One constant for every deployed feed store — per-feed separation comes from the
// `extensionId` and `feedId` fields inside the signed feed update itself.
bytes32 constant TEE_ORACLE_FEED = bytes32("TEE_ORACLE_FEED");

/**
 * @title ITeeOracleFeedStore
 * @notice Public interface for a TEE oracle feed value store.
 * @dev Accepts TEE-signed feed updates and stores the latest one. Submission is open;
 *      trust is the TEE signature (verified through `IFdc2Verification` against the
 *      extension id read from the instructions sender) plus the feed's latest published
 *      configuration generation. A submission carries `requiredSignatures` distinct machines'
 *      own observations at one instant in a single atomic batch, and the store stores the median
 *      of them, subject to a governance-set deviation bound — see `submitFeedUpdates`, the SOLE
 *      submission entry point (a single signature is a one-element array).
 *      Strictly increasing, never-future `observedAt`
 *      covers replay and out-of-order delivery (observations are stamped with an on-chain
 *      event timestamp inside the enclave), and the signed feed update is bound to this
 *      exact feed via its `extensionId` and `feedId` fields. The concrete store also implements the
 *      FTSO custom feed interface (`IICustomFeed`: `getCurrentFeed` / `feedId` /
 *      `calculateFee`), so it is registered with FtsoV2 directly — no separate adapter
 *      contract. Reading is payable like every other feed: `calculateFee` resolves
 *      through the central `FeeCalculator` (per-feed override → category fee → default
 *      fee, all governance-settable there), FtsoV2 forwards exactly that fee, and
 *      `getCurrentFeed` forwards the entire msg.value to the governance-set
 *      `feeDestination` (nothing accumulates on the store).
 */
interface ITeeOracleFeedStore {

    /**
     * A TEE-signed feed update. The signed digest is
     * `SignedPayload.messageHash(TEE_ORACLE_FEED, keccak256(abi.encode(feedUpdate)))` wrapped
     * as an eth-signed message — see `SignedPayload`.
     * @param extensionId The extension the signing machine serves; must match the store's.
     * @param feedId The feed the update is for; must match the store's. Binds the update
     * to one feed, so it cannot be replayed onto another feed served by the same extension.
     * @param value The observed feed value, scaled by 10^decimals (FTSO-style int32
     * representation — the enclave picks `decimals` so the value fits).
     * @param decimals The update's fixed-point decimal scale; stored alongside the value,
     * so the scale is dynamic per update.
     * @param observedAt The observation timestamp — the timestamp of an emitted on-chain
     * event, so always strictly in the past at submission; must strictly increase.
     * @param endpointsHash The endpoints payload hash the machine was running; must equal the
     * sender's `latestEndpointsHash(feedId)`.
     * @param adminsHash The admin-sets hash the machine was running; must equal the sender's
     * `latestAdminsHash(feedId)`.
     */
    struct FeedUpdate {
        uint256 extensionId;
        bytes21 feedId;
        int32 value;
        int8 decimals;
        uint64 observedAt;
        bytes32 endpointsHash;
        bytes32 adminsHash;
    }

    /**
     * One element of a threshold submission: a feed update together with the TEE signature over
     * it. Every element is signed by a different machine over ITS OWN observation, so the
     * elements share only `observedAt` (one observation instant) — their `value` and `decimals` may
     * differ, and the store derives one stored value from them (see `submitFeedUpdates`).
     * @param feedUpdate The feed update, exactly as signed.
     * @param signature The TEE signature over that feed update.
     */
    struct SignedFeedUpdate {
        FeedUpdate feedUpdate;
        Signature signature;
    }

    /**
     * The store's submission policy: how many distinct machines must sign one submission and how
     * far their values may diverge. Governance-set, and set once at initialization.
     * @param requiredSignatures The number of distinct PRODUCTION-machine signatures a submission
     * must carry; non-zero and at most 32.
     * @param maxSpreadBIPS The relative term of the accepted deviation, in BIPS of `abs(median)`;
     * at most 10000 (100%).
     * @param maxSpreadAbsolute The absolute term of the accepted deviation, always in units of
     * `10**-8` (a FIXED reference scale, so the setting's real-world meaning never moves with a
     * submission's own `decimals`); it is rescaled to each submission's normalisation scale
     * before use. Zero gives a purely relative bound. To ask for a real-world tolerance `T` in
     * the feed's own units, set `maxSpreadAbsolute = T * 1e8` — the rescaling makes the term
     * worth `maxSpreadAbsolute * 1e-8` at EVERY normalisation scale. Two traps, neither of which
     * can be checked on chain because the scale is the enclaves' choice and is only known per
     * batch: the rescale FLOORS, so a setting below one unit of the batch's own scale
     * (`maxSpreadAbsolute < 10**(8 - decimals)`) silently becomes zero; and once the RESCALED
     * term exceeds the largest reachable deviation (~4.3e17) the rejection AND the flagging are
     * disabled entirely. `decimals >= 29` guarantees that for any non-zero setting, but a large
     * setting reaches it far earlier — `maxSpreadAbsolute = 1e18` already does so at
     * `decimals = 8`, the reference scale itself. The rule is
     * `maxSpreadAbsolute * 10**(decimals - 8) > ~4.3e17`. Pin the enclave's `decimals` per feed
     * and size the setting against it.
     */
    struct SubmissionPolicy {
        uint8 requiredSignatures;
        uint16 maxSpreadBIPS;
        uint64 maxSpreadAbsolute;
    }

    /**
     * What a submission aggregated from its batch — returned by `submitFeedUpdates`, so the
     * transaction that updated the feed also reports the numbers it acted on, and an `eth_call`
     * on the very same function is a complete dry run. Every field
     * is exactly what the call used, not a recomputation: `median` / `decimals` are the aggregated
     * pair (`decimals` is the batch's NORMALISATION scale — the largest of the contributions' —
     * which may be finer than the scale the median is finally STORED at, and it is the scale
     * `FeedOutliers` reports in), and `outlierTeeIds` / `outlierDeviations` are the very arrays
     * `FeedOutliers` carried, empty exactly when no event was emitted.
     * @param median The median of the normalised values, at the `decimals` scale.
     * @param minValue The smallest normalised value, at the `decimals` scale.
     * @param maxValue The largest normalised value, at the `decimals` scale.
     * @param decimals The normalisation scale every value above is expressed in — the batch's
     * largest `decimals`.
     * @param spread The value the rejection test actually compared against `allowedDeviation`, at
     * the `decimals` scale: `upperNeighbour - lowerNeighbour` for an even count, HALF of it for an
     * odd one, and zero for a single element. Returned because it cannot be re-derived from the
     * other fields — a dry-run caller would otherwise have to re-normalise and re-sort the batch
     * to learn its acceptance headroom.
     * @param allowedDeviation The deviation bound this batch was judged against, at the same
     * scale: `maxSpreadAbsolute` (rescaled) plus `maxSpreadBIPS` of `abs(median)`. The bracketing
     * spread stayed inside it (else the call reverted with `SpreadTooBig`); a single contribution
     * outside it is an outlier below.
     * @param outlierTeeIds The machines whose own contribution deviated from `median` by more
     * than `allowedDeviation`, in submission order — the feed updated anyway.
     * @param outlierDeviations The matching signed deviations (`value - median`), at the
     * `decimals` scale, so the direction of each divergence is visible.
     */
    struct FeedAggregation {
        int256 median;
        int256 minValue;
        int256 maxValue;
        int8 decimals;
        int256 spread;
        int256 allowedDeviation;
        address[] outlierTeeIds;
        int256[] outlierDeviations;
    }

    /// Emitted once at initialization with the immutable per-instance configuration
    /// (the settable configuration additionally emits its setter events at initialization).
    event FeedStoreInitialised(
        address indexed instructionsSender,
        uint256 indexed extensionId,
        bytes21 indexed feedId
    );

    /// Emitted when a feed update is accepted and the stored value updates. `value` and
    /// `decimals` are the aggregated ones actually stored (see `submitFeedUpdates`), and
    /// `teeIds` names every machine that contributed a signature, in submission order.
    /// The contributor list is not indexed - an `address[]` topic could only be indexed as a
    /// hash of the whole array, which is not searchable per machine.
    event FeedUpdated(int32 indexed value, int8 decimals, uint64 indexed observedAt, address[] teeIds);

    /// Emitted alongside `FeedUpdated`, and only then, when at least one contribution deviates
    /// from the accepted median by more than the deviation bound. The feed still updates: a tail
    /// outlier does not undermine a median, and rejecting the batch over one would only teach
    /// submitters to filter the batch off chain, which is exactly where the divergence
    /// information would be lost. Publishing and flagging instead means a submitter who does not
    /// filter hands over a complete divergence report on chain, while consumers keep a live feed.
    /// `median`, `decimals` and `deviations` are all expressed in the submission's normalisation
    /// scale (its largest `decimals`) — NOT the possibly coarser scale the value is stored at,
    /// which `FeedUpdated` carries. Each deviation is signed (`value - median`), so the direction
    /// of the divergence is visible; `teeIds[i]` is the machine that submitted `deviations[i]`.
    /// Join with `FeedUpdated` on the indexed `observedAt`.
    event FeedOutliers(
        uint64 indexed observedAt,
        int256 median,
        int8 decimals,
        address[] teeIds,
        int256[] deviations
    );

    /// Emitted when the fee destination changes.
    event FeeDestinationSet(address feeDestination);

    /// Emitted when the submission policy changes (also once at initialization).
    event SubmissionPolicySet(uint8 requiredSignatures, uint16 maxSpreadBIPS, uint64 maxSpreadAbsolute);

    error WrongExtensionId();
    error WrongFeedId();
    error ZeroExtensionId();
    error NotNewer();
    error TooFarAhead();
    error FeeTooLow();
    error FeeTransferFailed();
    error ZeroAddress();
    error InvalidFeedCategory();
    error StaleEndpoints();
    error NoEndpointsPublished();
    error StaleAdmins();
    error NoAdminsPublished();
    error NoValuePublished();
    error NotEnoughSignatures();
    error TooManySignatures();
    error DuplicateTeeId();
    error ObservedAtMismatch();
    error DecimalsSpreadTooBig();
    /// The spread at the median position exceeds the accepted deviation, so the median itself is
    /// not well determined. Carries the offending numbers - all three at the `decimals` scale the
    /// batch was normalised to - so a trace names the divergence without a second call. Note the
    /// judged spread is `upperNeighbour - lowerNeighbour` for an even count and HALF of it for an
    /// odd one (see `submitFeedUpdates`), so compare accordingly when reading a trace.
    error SpreadTooBig(
        int256 lowerNeighbour,
        int256 upperNeighbour,
        int256 median,
        int8 decimals
    );
    error InvalidSubmissionPolicy();
    /// Defensive: the aggregated median could not be brought into `int32` without pushing its
    /// scale below `int8`. Unreachable for inputs that are themselves `int32` values (see
    /// `submitFeedUpdates`).
    error ValueOutOfRange();

    /**
     * Submits a threshold of TEE-signed feed updates in one atomic call and stores the value
     * aggregated from them. Anyone may call it; the machines themselves need no funded accounts
     * and nothing accumulates between transactions — a batch either lands whole or reverts.
     *
     * PER ELEMENT, exactly the checks a single-signature submission has always applied:
     * the signer must be a PRODUCTION-status TEE machine on the store's extension (verified
     * through `IFdc2Verification.verifyTeeSignature`, which also rejects submissions while the
     * extension is emergency paused), the signed update must name this store's extension id and
     * feed id (`WrongExtensionId` / `WrongFeedId`), and it must carry the FEED's latest published
     * configuration generation — `endpointsHash` / `adminsHash` against the sender's
     * `latestEndpointsHash` / `latestAdminsHash` (`NoEndpointsPublished` / `NoAdminsPublished`
     * when the feed has no publication of that kind, `StaleEndpoints` / `StaleAdmins` on a
     * mismatch). That check is deliberately the feed-level generation and not the version the
     * machine was last dispatched: a publication therefore invalidates every machine still
     * running the previous configuration until it adopts the new one. What that buys is immediacy
     * on the REJECTION side: a superseded configuration stops being accepted at once, not machine
     * by machine. The rollout gap it opens is NOT contractually bounded — publication and dispatch
     * are on-chain and immediate, but an enclave receives and adopts asynchronously and can miss
     * the instruction entirely, which is what the sender's permissionless `pushEndpoints` /
     * `pushAdmins` exist for. One consequence of the batch: while a publication is rolling out, a
     * batch that MIXES generations is rejected as a whole, so a threshold is a reason to keep the
     * fleet's configuration homogeneous.
     *
     * ACROSS THE BATCH:
     * - the element count must be at least `requiredSignatures` (`NotEnoughSignatures`) and at
     *   most 32 (`TooManySignatures`, the cap that bounds the O(N^2) distinctness scan and sort);
     * - the signers must be pairwise distinct (`DuplicateTeeId`) — otherwise one machine could
     *   reach the threshold alone;
     * - every element must carry the SAME `observedAt` (`ObservedAtMismatch`): the contributors
     *   share one observation timestamp, so a mismatch means the collector mixed rounds. Note the
     *   limit of what equality proves: `observedAt` is the timestamp of the triggering on-chain
     *   event and nothing binds a `FeedUpdate` to the instruction that produced it, so several
     *   independent requests landing in ONE block yield responses that all carry that block's
     *   timestamp and may be combined into one batch. It establishes a common INSTANT, not a
     *   common request. That single common
     *   timestamp is then checked once against the store's ratchet (`NotNewer`) and against the
     *   accepting block (`TooFarAhead`), exactly as a single submission is;
     * - `value` and `decimals` MAY differ between elements. The machines deliberately leave the
     *   scale undefined (the observed magnitude fluctuates), so the store normalises rather than
     *   pinning a scale.
     *
     * AGGREGATION — median, computed in `int256`:
     * 1. `maxDecimals - minDecimals` across the batch must be at most 8
     *    (`DecimalsSpreadTooBig`): `decimals` is `int8`, so an unbounded difference would
     *    overflow `10**k`, and an eight-decade disagreement is not two machines reporting the
     *    same quantity.
     * 2. every value is normalised to `maxDecimals` in `int256` —
     *    `value_i * 10**(maxDecimals - decimals_i)`, correct for negative `decimals` and negative
     *    values, and bounded by ~2.15e17 (`int32` input times `10**8`).
     * 3. the median of the normalised values: the middle one for an odd count, the `int256`
     *    average of the two middle ones for an even count (Solidity division truncates toward
     *    zero, so a half lands on the value nearer zero).
     * 4. the deviation bound is
     *    `allowed = maxSpreadAbsolute (rescaled) + maxSpreadBIPS * abs(median) / 10000`, and it
     *    is applied TWICE, to two different questions:
     *    - REJECTION — "is the median well determined?" The spread at the median position must not
     *      exceed `allowed`, else the call reverts with
     *      `SpreadTooBig(lowerNeighbour, upperNeighbour, median, decimals)` — a median whose
     *      bracketing values disagree wildly is meaningless and must not be published. That spread
     *      is parity-dependent:
     *      - EVEN count: `values[mid] - values[mid-1]`, the RAW gap between the two values being
     *        averaged.
     *      - ODD count: the median is flanked by TWO gaps, so the spread is their average,
     *        `(values[mid+1] - values[mid-1]) / 2`, and integer division FLOORS it — a raw
     *        bracketing gap of `2 * allowed + 1` therefore still lands.
     *      Halving the odd branch is what makes UNIFORMLY spaced adjacent gaps judged alike at
     *      either parity — without it such a batch would be judged twice as harshly whenever its
     *      element count is odd. It is exact only for that uniform case: for an asymmetric
     *      sample the two parities are genuinely different statistics, an average of two gaps
     *      against one raw gap. It is exactly FAssets' `_calculateMedian`. Note the error reports
     *      the RAW neighbours, so at an odd count the judged spread is half what it shows.
     *      Unlike FAssets, which can only skip the feed (its aggregation is a side
     *      effect of a multi-feed publication), this reverts: one feed per store and one batch
     *      per transaction mean nothing else in the transaction needs protecting.
     *    - FLAGGING — "which machines disagree?" Every contribution whose own deviation from the
     *      median exceeds `allowed` is named in a `FeedOutliers` event, emitted alongside
     *      `FeedUpdated` and only when at least one is found. It never rejects: a tail outlier
     *      does not undermine a median, and a revert would only teach submitters to filter the
     *      batch off chain — destroying exactly the divergence information the flag preserves.
     *      Note the condition, because it is narrower than "one faulty machine cannot stall it":
     *      a faulty machine is harmless to LIVENESS only when it is not one of the two bracketing
     *      values. At N = 3 those are `sorted[0]` and `sorted[2]` — so a faulty machine at either
     *      extreme does enter the spread. One that sorts into the middle stays out of the spread
     *      but not out of the test: it becomes the median, and `allowed` is computed from
     *      `abs(median)`, so it still moves the threshold the spread is compared against. At
     *      N = 4 the extremes `sorted[0]` and `sorted[3]` are excluded from the spread
     *      UNCONDITIONALLY, whatever they are, and the central gap alone decides whether the
     *      batch lands. A faulty machine can also simply
     *      withhold, which no threshold prevents. What `requiredSignatures >= 2f+1` buys is that
     *      the median lies inside the honest range — not that the median, or either bracketing
     *      value, is itself an honest machine's value.
     *    The two tests read the SAME `allowed` with different metrics, and an operator has to
     *    size the number knowing which one bites: rejection compares a SPREAD at the median
     *    position, flagging compares each machine's own DEVIATION from the median. NEITHER test
     *    dominates the other, and which one bites depends on the batch's PARITY and on how
     *    asymmetric the sample is:
     *    - EVEN count: the judged spread is the gap between the two values being averaged, so a
     *      pair straddling the median at `+/- d` is REJECTED at `2d` while each is FLAGGED at `d`
     *      - rejection bites at half the per-machine displacement.
     *    - ODD count: the judged spread is the MEAN of the two gaps flanking the median,
     *      `(L + R) / 2`, while flagging fires on the largest single deviation, which is at least
     *      `max(L, R) >= (L + R) / 2`. Rejection therefore bites LATER than flagging here - up to
     *      2x later when the sample is maximally asymmetric, i.e. one neighbour sitting ON the
     *      median. That is exactly why an accepted batch can name an outlier from N = 3 onwards.
     *    Size `allowed` from the rejection side for LIVENESS - it is the test that stalls the feed
     *    - but do not read either test as implying the other.
     *    Flagging is unreachable for N <= 2 — a single element deviates from itself by zero, and
     *    for a pair the median lies between the two values, so the two deviations are the FLOOR
     *    and CEILING halves of the spread (the median truncates toward zero, so they are equal
     *    only when the pair sums to an even number) — and the larger of them is still at most the
     *    spread, which has already had to fit inside `allowed`. From N = 3 it is reachable, and the asymmetry above
     *    is why: `(0, 0, 20)` at `allowed` 15 has a judged spread of `(20 - 0) / 2 = 10`, so it
     *    publishes a median of 0 and names the machine at 20, whose own deviation is 20.
     *    Note that the test is centre-local, so it is not monotone in N: a batch rejected at
     *    N = 3 can be accepted, with the same median, by adding a fourth signature that lands
     *    between the original three. That is inherent to judging the median by its neighbours
     *    rather than by the full range — more corroboration AT THE CENTRE is exactly what makes
     *    the median better determined — and it is the property that stops one tail outlier from
     *    stalling the feed.
     *    `abs(median)` plus the absolute floor keeps the bound usable at a zero or negative
     *    median: `value` is a SIGNED int32, so a feed may legitimately sit at or cross zero,
     *    where a purely relative bound collapses to zero and leaves only the absolute term. With
     *    BOTH terms zero the rule is parity-split: at an EVEN count the two central values must be
     *    IDENTICAL, at an ODD count they may differ by one unit of the batch's scale (the halving
     *    floors). Values OUTSIDE the bracketing pair escape the REJECTION test only — the
     *    flagging test judges every element — and they first exist at an even count of 4 or an
     *    odd count of 5; at N = 3 every element is the median or a bracketing value. The absolute term is a
     *    governance setting at a FIXED `10**-8` reference scale, rescaled to the batch's
     *    normalisation scale before use, so its real-world meaning does not move with the
     *    machines' choice of `decimals`.
     * 5. the median is stored back into the same `int32 value` / `int8 decimals` shape external
     *    consumers already read, at the FINEST scale where it fits `int32`: starting from
     *    `maxDecimals`, the scale is coarsened a decade at a time until the value fits, and the
     *    rounding — half AWAY from zero, symmetrically for negatives — is applied ONCE, to
     *    the ORIGINAL median, at whichever scale is finally used. Rounding per decade could
     *    land one unit away from that value in the last place. Nothing
     *    meaningful is lost: every input is itself an `int32` carrying at most ~9.3 significant
     *    digits and the median lies between the smallest and largest input, so the result is
     *    representable in the same ~9.3 digits at its own magnitude. When the machines submit the
     *    same `decimals` the median is exactly representable and the loop does not run at all.
     *
     * A ONE-ELEMENT submission therefore behaves exactly as a single-signature submission always
     * did: the neighbour spread is 0 and the single deviation is 0, so neither bound bites, and
     * the median is the submitted value at its submitted scale. A `requiredSignatures` of 1 only
     * PERMITS such a batch — it does not force one, since the count is the submitter's choice
     * anywhere from the threshold up to 32, and a larger batch is judged like any other.
     *
     * DRY RUN: an `eth_call` on THIS function is the supported way to rehearse a batch — there is
     * no separate preview view, deliberately. The call returns the aggregation it acted on and
     * reverts in exactly the places a real submission would, which a view over a subset of the
     * rules could not promise: signature verification, the extension pause, the feed binding, the
     * configuration generation and the `observedAt` ratchet are all enforced here, so a batch that
     * `eth_call`s cleanly is a batch that can land, and a failing rehearsal names the reason
     * (`SpreadTooBig` carries both bracketing values and the median, so the divergence is
     * diagnosable from the trace alone). A view could also silently drift out of agreement with
     * this path; the same function cannot.
     * @param _signedFeedUpdates The signed feed updates, one per contributing machine.
     * @return _feedAggregation The aggregation this submission acted on: the median, the range's
     * ends, the normalisation scale they are expressed in, the deviation bound the batch was
     * judged against, and the flagged machines with their signed deviations. These are the SAME
     * numbers the emitted `FeedUpdated` / `FeedOutliers` carry (up to `FeedUpdated`'s re-scaling
     * of the median into `int32`), read from the same arrays.
     */
    function submitFeedUpdates(
        SignedFeedUpdate[] calldata _signedFeedUpdates
    )
        external
        returns (FeedAggregation memory _feedAggregation);

    /**
     * Returns the whole submission policy in one call.
     */
    function getSubmissionPolicy()
        external view
        returns (SubmissionPolicy memory);

    /**
     * Returns the number of distinct PRODUCTION-machine signatures a submission must carry.
     * NOTE: governance must keep this at or below the number of PRODUCTION machines running the
     * feed's latest published configuration — the store cannot check that (the active set moves
     * under it, and a check would cost an external call per submission), and a threshold above it
     * silently stops the feed from updating.
     */
    function requiredSignatures()
        external view
        returns (uint8);

    /**
     * Returns the relative term of the accepted deviation, in BIPS of `abs(median)`.
     * The bound it forms is used twice: the median's two bracketing values must stay inside it
     * (else `SpreadTooBig`), and any single contribution outside it is named in `FeedOutliers`.
     */
    function maxSpreadBIPS()
        external view
        returns (uint16);

    /**
     * Returns the absolute term of the accepted deviation, in units of `10**-8` — a FIXED
     * reference scale, rescaled to each submission's own normalisation scale before use, so that
     * the setting's real-world meaning cannot move with the machines' choice of `decimals`.
     * It is what keeps the bound usable at a median of or near zero, where the relative term alone
     * collapses to zero. With both terms zero the two central values must be IDENTICAL at an even
     * count and may differ by one unit at an odd one (the halving floors); values outside the
     * bracketing pair — first existing at an even count of 4 or an odd count of 5 — never enter
     * the rejection spread, so a batch can still publish with wildly divergent extremes, which
     * the flagging test then names.
     * Zero (the default) makes the bound purely relative.
     */
    function maxSpreadAbsolute()
        external view
        returns (uint64);

    /**
     * Returns the extension id whose TEE machines may sign feed updates.
     * Cached from the instructions sender at initialization — the sender's extension id
     * is initializer-only, so it cannot diverge.
     */
    function extensionId()
        external view
        returns (uint256);

    /**
     * Returns the extension's instructions sender (the configuration-commitment source).
     */
    function instructionsSender()
        external view
        returns (ITeeOracleInstructionsSender);

    /**
     * Returns the destination address collected read fees are forwarded to.
     */
    function feeDestination()
        external view
        returns (address);

    /**
     * Returns the timestamp of the latest accepted observation.
     * The value and decimals themselves have no free getters — reading the feed is paid,
     * through `getCurrentFeed` (the fee gates on-chain consumers; off-chain readers can
     * always inspect storage directly).
     */
    function observedAt()
        external view
        returns (uint64);

}
