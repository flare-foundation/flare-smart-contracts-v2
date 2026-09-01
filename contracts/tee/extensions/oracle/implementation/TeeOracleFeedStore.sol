// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { FlareUpgradeableBase } from "../../../../governance/implementation/FlareUpgradeableBase.sol";
import { IICustomFeed } from "../../../../customFeeds/interface/IICustomFeed.sol";
import { IFdc2Verification } from "../../../../userInterfaces/fdc2/IFdc2Verification.sol";
import { IFeeCalculator } from "../../../../userInterfaces/IFeeCalculator.sol";
import {
    ITeeOracleInstructionsSender
} from "../../../../userInterfaces/tee/ITeeOracleInstructionsSender.sol";
import {
    ITeeOracleFeedStore,
    TEE_ORACLE_FEED
} from "../../../../userInterfaces/tee/ITeeOracleFeedStore.sol";
import { IITeeOracleFeedStore } from "../interface/IITeeOracleFeedStore.sol";
import { SignedPayload } from "../../../../utils/lib/SignedPayload.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

/**
 * TeeOracleFeedStore contract.
 *
 * Accepts TEE-signed feed updates for one extension and stores the latest one. Submission
 * is open; trust is the TEE signature (verified through `Fdc2Verification` against the
 * extension id read from the instructions sender — PRODUCTION status and the extension
 * emergency pause included) plus the configuration commitments the sender publishes.
 * Strictly increasing, never-future `observedAt` covers replay and out-of-order delivery
 * (observations are stamped with an on-chain event timestamp inside the enclave), and the
 * signed feed update is bound to this exact feed via its `extensionId` and `feedId` fields.
 *
 * One submission carries `requiredSignatures` distinct machines' OWN observations of one event
 * in a single atomic batch through the sole entry point `submitFeedUpdates` (a single signature is
 * a one-element array),
 * and the store stores the median of them — normalised in int256, because the machines
 * deliberately leave the scale undefined, then written back into the int32/int8 shape consumers
 * read. A governance-set deviation bound is applied twice: the values bracketing the median must
 * agree (else the submission is rejected), and any single contribution outside the bound is named
 * in `FeedOutliers` without blocking the update. See `ITeeOracleFeedStore.submitFeedUpdates`.
 *
 * The store itself implements the FTSO custom feed interface (`IICustomFeed`), so it is
 * registered with FtsoV2 directly — upgrades keep the proxy address, hence the
 * registration; no separate adapter contract is needed. Reading is payable like every
 * other feed: `calculateFee` resolves through the central `FeeCalculator` and
 * `getCurrentFeed` forwards the entire msg.value to `feeDestination`.
 */
contract TeeOracleFeedStore is IITeeOracleFeedStore, IICustomFeed, FlareUpgradeableBase {

    /// What `_aggregate` derives from one batch. Internal only - the public surface returns the
    /// subset that is meaningful to a caller as `FeedAggregation`; carrying the working set as one
    /// memory struct between the internal helpers keeps the submission's stack frame shallow.
    struct Aggregation {
        /// The normalised values in SUBMISSION order - the outlier scan needs them keyed by
        /// element, so the sort works on a copy.
        int256[] normalisedValues;
        int256 median;
        int256 minValue;
        int256 maxValue;
        /// The two values bracketing the median position, reported verbatim by `SpreadTooBig`.
        int256 lowerNeighbour;
        int256 upperNeighbour;
        /// What the rejection bound actually judges: their difference for an even count, HALF of
        /// it for an odd one, so the number does not depend on the batch's parity. Zero for a
        /// single element.
        int256 spread;
        /// The bound both checks use: rescaled absolute term + maxSpreadBIPS of abs(median).
        int256 allowedDeviation;
        int8 decimals;
        bool withinSpread;
    }

    /// Hard cap on the number of signatures one submission may carry. It bounds the nested
    /// distinctness scan and the insertion sort, and sits far above any realistic fleet.
    uint256 private constant MAX_SIGNATURES = 32;
    /// Largest accepted difference between the batch's largest and smallest `decimals`.
    /// `decimals` is int8, so an unbounded difference would overflow the `10**k` normalisation
    /// multiplier — and an eight-decade disagreement is not two machines reporting the same
    /// quantity in the first place.
    int256 private constant MAX_DECIMALS_SPREAD = 8;
    /// Basis-points denominator of `maxSpreadBIPS`.
    uint256 private constant MAX_BIPS = 10000;
    /// The FIXED reference scale of `maxSpreadAbsolute`: the setting is always in units of
    /// `10**-8`, whatever scale a submission happens to use, and is rescaled to the submission's
    /// normalisation scale before it is compared with anything. Without a pinned reference the
    /// same stored number would mean 1e-4 for a batch at `decimals` 4 and 1e-2 for one at 2 - a
    /// governance setting whose real-world meaning moves silently.
    int256 private constant MAX_SPREAD_ABSOLUTE_DECIMALS = 8;
    /// Clamp for the rescaled absolute term. A normalised value is bounded by ~2.15e17 (see
    /// `_aggregate`), so no deviation can exceed ~4.3e17: any bound at or above this constant
    /// already permits everything, and clamping there keeps `10**k` inside uint256 no matter how
    /// far apart the reference scale and the batch's scale are.
    uint256 private constant UNBOUNDED_SPREAD = 1e19;

    /// The Fdc2Verification contract (TEE signature verification).
    IFdc2Verification public fdc2Verification;
    /// The FeeCalculator contract (read-fee resolution: feed override → category → default).
    IFeeCalculator public feeCalculator;

    /// The extension's instructions sender — the configuration-commitment source.
    ITeeOracleInstructionsSender public instructionsSender;
    /// Destination address collected read fees are forwarded to.
    address public feeDestination;
    /// The feed id returned to FtsoV2 at registration; sole authority on the id.
    bytes21 public feedId;

    // The three submission-policy fields below complete `feedId`'s slot exactly
    // (21 + 1 + 2 + 8 = 32 bytes), so the whole policy comes for free with the feed id a
    // submission has to read anyway: one SLOAD, no new storage.
    /// Number of distinct PRODUCTION-machine signatures a submission must carry.
    uint8 public requiredSignatures;
    /// Relative term of the accepted deviation, in BIPS of `abs(median)`.
    uint16 public maxSpreadBIPS;
    /// Absolute term of the accepted deviation, in units of 10^-8 (MAX_SPREAD_ABSOLUTE_DECIMALS),
    /// rescaled to each submission's own normalisation scale before use.
    uint64 public maxSpreadAbsolute;
    /// The extension whose TEE machines may sign feed updates. Cached from the instructions
    /// sender at initialization — the sender's extension id is initializer-only, so it
    /// cannot diverge, and a local read is cheaper than an external call per update.
    uint256 public extensionId;

    // The feed state below packs into a single storage slot (13 bytes), so an accepted
    // update is a single storage write. The value and decimals are internal — reading
    // the feed is paid, through getCurrentFeed (the fee gates on-chain consumers;
    // off-chain readers can always inspect storage directly).
    /// Latest accepted feed value, scaled by 10^decimals (FTSO-style int32 representation).
    int32 internal value;
    /// Fixed-point decimal scale of the latest accepted value; dynamic per update —
    /// the enclave picks it so the value fits int32.
    int8 internal decimals;
    /// Timestamp of the latest accepted observation; strictly increasing and always
    /// strictly in the past.
    uint64 public observedAt;

    /**
     * Constructor that initializes with invalid parameters to prevent direct deployment/updates.
     */
    constructor() FlareUpgradeableBase() {}

    /**
     * Proxyable initialization method. Can be called only once, from the proxy constructor
     * (single call is assured by the `initializer` modifier).
     * @param _governanceSettings The governance settings contract.
     * @param _initialGovernance The initial governance address.
     * @param _addressUpdater The AddressUpdater contract.
     * @param _instructionsSender The extension's instructions sender (commitment source and
     * extension id source).
     * @param _feedId The FTSO feed id; the category (first byte) must be in the custom
     * range [0x20, 0x40), checked here so a bad id fails at deploy time rather than inside
     * a timelocked `FtsoV2.addCustomFeeds` execution.
     * @param _feeDestination The destination address collected read fees are forwarded to.
     * @param _submissionPolicy The initial submission policy; a `requiredSignatures` of 1 makes
     * the store behave as a single-signature store until governance raises it.
     */
    function initialize(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        ITeeOracleInstructionsSender _instructionsSender,
        bytes21 _feedId,
        address _feeDestination,
        SubmissionPolicy calldata _submissionPolicy
    )
        external
        initializer
    {
        FlareUpgradeableBase.initializeBase(_governanceSettings, _initialGovernance, _addressUpdater);
        // `AddressUpdatable.setAddressUpdaterValue` does not check this, and a zero updater
        // cannot be corrected through the normal path: `updateContractAddresses` is gated on
        // `msg.sender == addressUpdater`, so `fdc2Verification` and `feeCalculator` would stay
        // unset and every submission and every paid read would revert. Only a governance UUPS
        // upgrade to an implementation that rewrites the slot could recover it.
        require(_addressUpdater != address(0), ZeroAddress());
        require(address(_instructionsSender) != address(0), ZeroAddress());
        uint8 category = uint8(_feedId[0]);
        require(category >= 0x20 && category < 0x40, InvalidFeedCategory());
        require(_feeDestination != address(0), ZeroAddress());
        // Cached once — the sender's extension id is initializer-only. A zero id means
        // the sender is not initialized yet (deployment ordering mistake).
        uint256 senderExtensionId = _instructionsSender.extensionId();
        require(senderExtensionId != 0, ZeroExtensionId());
        extensionId = senderExtensionId;
        instructionsSender = _instructionsSender;
        feedId = _feedId;
        feeDestination = _feeDestination;
        emit FeedStoreInitialised(address(_instructionsSender), senderExtensionId, _feedId);
        emit FeeDestinationSet(_feeDestination);
        // validates and emits SubmissionPolicySet
        _setSubmissionPolicy(_submissionPolicy);
    }

    /**
     * @inheritdoc ITeeOracleFeedStore
     * @dev The whole submission path lives in this method — it is the sole entry point, so a
     * one-element batch and an N-element batch are subject to exactly the same rules, and an
     * `eth_call` on either is a faithful dry run.
     */
    function submitFeedUpdates(
        SignedFeedUpdate[] calldata _signedFeedUpdates
    )
        external
        returns (FeedAggregation memory _feedAggregation)
    {
        // The aggregation runs first: it validates the batch's shape (element count, one common
        // observedAt, the decimals spread) and derives the number, so a malformed batch fails
        // before a single signature is verified.
        Aggregation memory aggregation = _aggregate(_signedFeedUpdates);
        // The REJECTION check: if the two values bracketing the median disagree by more than the
        // bound, the median is not well determined and must not be published. Reverting rather
        // than skipping (as FAssets must) is affordable here: one feed per store and one batch
        // per transaction, so nothing else in the transaction is at stake. Note this is NOT a
        // check on the tails - those are flagged below, not rejected.
        require(
            aggregation.withinSpread,
            SpreadTooBig(
                aggregation.lowerNeighbour,
                aggregation.upperNeighbour,
                aggregation.median,
                aggregation.decimals
            )
        );

        // One common observedAt for the whole batch (equality enforced in `_aggregate`), so the
        // ratchet and the never-future rule are checked exactly once, on the same terms a single
        // submission has always been: strictly increasing observedAt covers replay and
        // out-of-order delivery, and - since observations are stamped with the timestamp of an
        // emitted on-chain event and the round trip cannot complete within one block - an
        // acceptable observation is always strictly older than the accepting block. observedAt
        // only ratchets up, so without the latter a future-dated batch would freeze the feed
        // irreversibly.
        uint64 batchObservedAt = _signedFeedUpdates[0].feedUpdate.observedAt;
        require(batchObservedAt > observedAt, NotNewer());
        require(batchObservedAt < block.timestamp, TooFarAhead());

        address[] memory teeIds = _verifyContributors(_signedFeedUpdates);

        // Back into the int32 / int8 shape external consumers (FAssets among them) already read.
        // The scale is NOT restricted here: `getCurrentFeed` reports the value together with its
        // own `decimals`, and picking a read that can represent it is the consumer's call —
        // FtsoV2's `get*InWei` family converts to 18 decimals and therefore cannot serve every
        // scale, which is a property of that conversion rather than of the value this store holds.
        (int32 value_, int8 decimals_) = _toStoredScale(aggregation.median, aggregation.decimals);

        value = value_;
        decimals = decimals_;
        observedAt = batchObservedAt;

        emit FeedUpdated(value_, decimals_, batchObservedAt, teeIds);
        // The FLAGGING check, after the feed has been updated: naming the machines that diverged
        // costs the submitter one event and keeps the divergence on chain, where a revert would
        // only have pushed the filtering (and the information) off it.
        (address[] memory outlierTeeIds, int256[] memory outlierDeviations) =
            _emitOutliers(aggregation, teeIds, batchObservedAt);

        // The returned report is built from the SAME memory the event was emitted from, so the
        // two cannot disagree - which is what makes an eth_call on this function a dry run a
        // caller can rely on rather than a second, drifting implementation.
        _feedAggregation = FeedAggregation({
            median: aggregation.median,
            minValue: aggregation.minValue,
            maxValue: aggregation.maxValue,
            decimals: aggregation.decimals,
            allowedDeviation: aggregation.allowedDeviation,
            outlierTeeIds: outlierTeeIds,
            outlierDeviations: outlierDeviations
        });
    }

    /**
     * @inheritdoc IICustomFeed
     * @dev A fee (see `calculateFee`) must be paid; FtsoV2 forwards exactly that fee.
     * The entire msg.value is forwarded to `feeDestination` — no refund of overpayment,
     * so nothing ever accumulates on this contract (same semantics as the TEE
     * instructions fee). Reverts with `NoValuePublished` until the first feed update lands —
     * an unpublished store must not read as "value 0" to consumers that skip staleness
     * checks. Stale values are returned with their true timestamp — staleness is the
     * consumer's check, as with every FTSO feed, and the timestamp is always strictly
     * below `block.timestamp` (enforced at submission). The value is signed — negative values flow through
     * `FtsoV2.getCurrentFeeds`; FtsoV2's unsigned read paths reject them there.
     */
    function getCurrentFeed()
        external payable
        returns (
            int256 _value,
            int8 _decimals,
            uint64 _timestamp
        )
    {
        uint64 observedAt_ = observedAt;
        // observedAt only ratchets up from the first accepted update, so this triggers
        // only while the feed is unpublished; the slot is already loaded — the check is free.
        require(observedAt_ != 0, NoValuePublished());
        _value = value;
        _decimals = decimals;
        _timestamp = observedAt_;
        // LAST: `_collectFee` hands control to `feeDestination`, so this call's own reads are all
        // done and the values it returns are already fixed - a destination that re-enters cannot
        // change what THIS invocation reports. It does NOT make the destination harmless: it still
        // receives control with all remaining gas, and FtsoV2 runs this inside a loop over a
        // caller-supplied feed list while holding value it has yet to forward to later feeds, so a
        // contract destination can still re-enter FtsoV2 or this store between elements, and one
        // that reverts still fails every read of this feed. See
        // `IITeeOracleFeedStore.setFeeDestination` for the constraint that actually governs this.
        _collectFee();
    }

    /**
     * @inheritdoc IITeeOracleFeedStore
     */
    function setFeeDestination(
        address _feeDestination
    )
        external
        onlyGovernance
    {
        require(_feeDestination != address(0), ZeroAddress());
        feeDestination = _feeDestination;
        emit FeeDestinationSet(_feeDestination);
    }

    /**
     * @inheritdoc IITeeOracleFeedStore
     */
    function setSubmissionPolicy(
        SubmissionPolicy calldata _submissionPolicy
    )
        external
        onlyGovernance
    {
        _setSubmissionPolicy(_submissionPolicy);
    }

    /**
     * @inheritdoc ITeeOracleFeedStore
     */
    function getSubmissionPolicy()
        external view
        returns (SubmissionPolicy memory)
    {
        return SubmissionPolicy(requiredSignatures, maxSpreadBIPS, maxSpreadAbsolute);
    }

    /**
     * @inheritdoc IICustomFeed
     * @dev Resolves through the central `FeeCalculator`: per-feed override → category fee
     * → default fee, all governance-settable there.
     */
    function calculateFee()
        external view
        returns (uint256 _fee)
    {
        return _calculateFee();
    }

    /**
     * Names every contribution whose own deviation from the accepted median exceeds the deviation
     * bound, in one `FeedOutliers` event - and emits nothing at all when there is none - then
     * returns the very arrays it logged (both empty when there is no outlier). It never reverts:
     * the feed has already been updated by the time this runs, deliberately.
     */
    function _emitOutliers(
        Aggregation memory _aggregation,
        address[] memory _teeIds,
        uint64 _observedAt
    )
        internal
        returns (
            address[] memory _outlierTeeIds,
            int256[] memory _outlierDeviations
        )
    {
        uint256 count = _teeIds.length;
        // Two passes so the emitted arrays are exactly the right length: memory arrays cannot be
        // shortened, and an over-allocated one would log trailing zero entries.
        uint256 outlierCount = 0;
        for (uint256 i = 0; i < count; i++) {
            if (_isOutlier(_aggregation, i)) {
                outlierCount++;
            }
        }
        if (outlierCount == 0) {
            // both returns stay empty, which is exactly the "no event was emitted" signal
            return (new address[](0), new int256[](0));
        }
        _outlierTeeIds = new address[](outlierCount);
        _outlierDeviations = new int256[](outlierCount);
        uint256 next = 0;
        for (uint256 i = 0; i < count; i++) {
            if (_isOutlier(_aggregation, i)) {
                _outlierTeeIds[next] = _teeIds[i];
                // signed, so the direction of the divergence is visible in the log
                _outlierDeviations[next] = _aggregation.normalisedValues[i] - _aggregation.median;
                next++;
            }
        }
        emit FeedOutliers(
            _observedAt,
            _aggregation.median,
            _aggregation.decimals,
            _outlierTeeIds,
            _outlierDeviations
        );
    }

    /**
     * Validates and stores the submission policy, and emits `SubmissionPolicySet`.
     * NOTE: `requiredSignatures` is deliberately NOT checked against the live number of
     * PRODUCTION machines running the feed's configuration - that set moves under the store, and
     * checking it would cost an external call per submission. Keeping the threshold reachable is
     * a governance invariant; exceeding it silently stops the feed from updating.
     * NOTE: nor are the two deviation terms given a floor. Setting BOTH to zero is a legitimate
     * policy - it is how a discrete or binary feed demands exact agreement - but only up to a
     * SUBMITTED count of 2. From 3 it does NOT give unanimity: only the values at the median
     * position must match, so (0, 0, 1) has a judged spread of (1 - 0) / 2 == 0, publishes 0 and
     * merely flags the dissenter. The count is the submitter's choice, bounded below by
     * `requiredSignatures` and above by 32, so a threshold of 2 does not pin it to 2. On a
     * continuous feed a zero bound stops every non-identical batch.
     * See `ITeeOracleFeedStore.SubmissionPolicy`.
     * NOTE: this setter is an ordinary timelocked governance call, keyed by the hash of its whole
     * calldata, so two policies can be pending at once and execute in either order - an older,
     * weaker one landing last silently restores a lower `requiredSignatures`. Unlike the sender's
     * configuration publications there is no signed version to make the loser unexecutable, so
     * governance MUST cancel a superseded policy call rather than leave it queued.
     */
    function _setSubmissionPolicy(
        SubmissionPolicy calldata _submissionPolicy
    )
        internal
    {
        require(
            _submissionPolicy.requiredSignatures != 0 &&
                _submissionPolicy.requiredSignatures <= MAX_SIGNATURES &&
                _submissionPolicy.maxSpreadBIPS <= MAX_BIPS,
            InvalidSubmissionPolicy()
        );
        requiredSignatures = _submissionPolicy.requiredSignatures;
        maxSpreadBIPS = _submissionPolicy.maxSpreadBIPS;
        maxSpreadAbsolute = _submissionPolicy.maxSpreadAbsolute;
        emit SubmissionPolicySet(
            _submissionPolicy.requiredSignatures,
            _submissionPolicy.maxSpreadBIPS,
            _submissionPolicy.maxSpreadAbsolute
        );
    }

    /**
     * Updates external contract addresses.
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal override
    {
        fdc2Verification = IFdc2Verification(
            _getContractAddress(_contractNameHashes, _contractAddresses, "Fdc2Verification"));
        feeCalculator = IFeeCalculator(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FeeCalculator"));
    }

    /**
     * Requires the read fee to be covered and forwards the entire msg.value to
     * `feeDestination` — no refund of overpayment, so nothing ever accumulates on this
     * contract (same semantics as the TEE instructions fee).
     */
    // feeDestination is set by governance, not an arbitrary caller.
    //slither-disable-next-line arbitrary-send-eth
    function _collectFee()
        internal
    {
        require(msg.value >= _calculateFee(), FeeTooLow());
        if (msg.value > 0) {
            //solhint-disable-next-line avoid-low-level-calls
            (bool success, ) = feeDestination.call{value: msg.value}("");
            require(success, FeeTransferFailed());
        }
    }

    /**
     * Returns this feed's read fee, resolved through the central `FeeCalculator`.
     */
    function _calculateFee()
        internal view
        returns (uint256 _fee)
    {
        bytes21[] memory feedIds = new bytes21[](1);
        feedIds[0] = feedId;
        return feeCalculator.calculateFeeByIds(feedIds);
    }

    /**
     * Authorizes every element of the batch and returns the contributing machines in submission
     * order. Per element this is exactly what a single-signature submission has always checked.
     */
    function _verifyContributors(
        SignedFeedUpdate[] calldata _signedFeedUpdates
    )
        internal view
        returns (address[] memory _teeIds)
    {
        bytes21 feedId_ = feedId; // used more than once
        uint256 extensionId_ = extensionId; // used per element
        // The machines must prove they run the feed's LATEST published configuration and admin
        // sets - the feed-level generation, not whatever a machine was last dispatched. The admin
        // sets decide who may install credentials in the enclave, so they are checked on the same
        // terms as the endpoints. Publishing is therefore an immediate invalidation of every
        // machine still running the previous generation: acceptable because a feed publishes at
        // most hourly, and it is the property a per-machine record cannot give. Both hashes are
        // feed-level, so they are read ONCE for the whole batch - and a batch that mixes
        // generations simply fails on the element that lags.
        bytes32 expectedEndpoints = instructionsSender.latestEndpointsHash(feedId_);
        require(expectedEndpoints != bytes32(0), NoEndpointsPublished());
        bytes32 expectedAdmins = instructionsSender.latestAdminsHash(feedId_);
        require(expectedAdmins != bytes32(0), NoAdminsPublished());

        uint256 count = _signedFeedUpdates.length;
        _teeIds = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            FeedUpdate calldata feedUpdate = _signedFeedUpdates[i].feedUpdate;
            // Recovers the signer and requires a PRODUCTION machine on this extension; also
            // rejects while the extension is emergency paused. Reverts with typed
            // Fdc2Verification / ECDSA errors on any failure. Every element carries its OWN
            // observation, hence its own digest - which is why this is the single-signature
            // overload per element rather than `verifyTeeSignatures` over one shared hash.
            address teeId = fdc2Verification.verifyTeeSignature(
                extensionId_,
                _signedFeedUpdates[i].signature,
                SignedPayload.messageHash(TEE_ORACLE_FEED, keccak256(abi.encode(feedUpdate)))
            );

            // Distinct signers: otherwise one machine could reach the threshold alone. The nested
            // scan is the right shape at N <= MAX_SIGNATURES and touches no storage, so a
            // rejected batch leaves nothing behind.
            for (uint256 j = 0; j < i; j++) {
                require(_teeIds[j] != teeId, DuplicateTeeId());
            }
            _teeIds[i] = teeId;

            // The signed update must name this exact feed - the feed id binding prevents
            // replaying an update onto another feed served by the same extension.
            require(feedUpdate.extensionId == extensionId_, WrongExtensionId());
            require(feedUpdate.feedId == feedId_, WrongFeedId());
            require(feedUpdate.endpointsHash == expectedEndpoints, StaleEndpoints());
            require(feedUpdate.adminsHash == expectedAdmins, StaleAdmins());
        }
    }

    /**
     * The batch's shape checks and its aggregation - everything that produces the number, and
     * nothing that decides whether the batch may land. The subset of it that is meaningful to a
     * caller is what `submitFeedUpdates` returns as `FeedAggregation`.
     * Reverts with `NotEnoughSignatures` / `TooManySignatures` on the element count,
     * `ObservedAtMismatch` when the elements do not all observe one event, and
     * `DecimalsSpreadTooBig` when their scales disagree by more than `MAX_DECIMALS_SPREAD`.
     * @return _aggregation The normalised values in submission order, the median, the range's
     * ends, the two values bracketing the median and the parity-neutral spread derived from them,
     * the normalisation scale they are all expressed in (the batch's largest `decimals`), the
     * deviation bound the batch is judged against, and whether that spread stays inside it.
     * Whether individual contributions do is a separate question, answered by `_isOutlier`.
     */
    function _aggregate(
        SignedFeedUpdate[] calldata _signedFeedUpdates
    )
        internal view
        returns (Aggregation memory _aggregation)
    {
        uint256 count = _signedFeedUpdates.length;
        // requiredSignatures is never zero (see `_setSubmissionPolicy`), so this also rejects an
        // empty batch before the indexing below.
        require(count >= requiredSignatures, NotEnoughSignatures());
        require(count <= MAX_SIGNATURES, TooManySignatures());

        FeedUpdate calldata first = _signedFeedUpdates[0].feedUpdate;
        uint64 batchObservedAt = first.observedAt;
        int8 maxDecimals = first.decimals;
        int8 minDecimals = maxDecimals;
        for (uint256 i = 1; i < count; i++) {
            FeedUpdate calldata feedUpdate = _signedFeedUpdates[i].feedUpdate;
            // The contributors observe ONE event, so a differing observedAt means the collector
            // mixed rounds - the values would not be comparable at all.
            require(feedUpdate.observedAt == batchObservedAt, ObservedAtMismatch());
            if (feedUpdate.decimals > maxDecimals) {
                maxDecimals = feedUpdate.decimals;
            } else if (feedUpdate.decimals < minDecimals) {
                minDecimals = feedUpdate.decimals;
            }
        }
        require(
            int256(maxDecimals) - int256(minDecimals) <= MAX_DECIMALS_SPREAD,
            DecimalsSpreadTooBig()
        );

        // Normalise every value to the batch's finest scale, in int256. The multiplier is
        // 10**(maxDecimals - decimals_i), an exponent in [0, MAX_DECIMALS_SPREAD]: only the
        // DIFFERENCE of the two int8 scales matters, so negative `decimals` are handled by
        // construction, and the multiplier is always positive, so negative values scale
        // correctly too. Worst case |int32| * 10**8 ~= 2.15e17 - far inside int256.
        int256[] memory values = new int256[](count);
        for (uint256 i = 0; i < count; i++) {
            FeedUpdate calldata feedUpdate = _signedFeedUpdates[i].feedUpdate;
            values[i] = int256(feedUpdate.value) *
                int256(10 ** uint256(int256(maxDecimals) - int256(feedUpdate.decimals)));
        }
        // Kept in SUBMISSION order for the outlier scan, which has to name machines; the sort
        // below therefore works on a copy and the batch is never reordered.
        _aggregation.normalisedValues = values;
        _aggregation.decimals = maxDecimals;

        int256[] memory sorted = new int256[](count);
        for (uint256 i = 0; i < count; i++) {
            sorted[i] = values[i];
        }
        _sortAscending(sorted);
        _aggregation.minValue = sorted[0];
        _aggregation.maxValue = sorted[count - 1];

        // The judged spread, kept parity-neutral - see `_aggregation.spread`. This follows FAssets'
        // `_calculateMedian` exactly, including the HALVING in the odd branch: an odd count's
        // neighbours straddle the median across TWO gaps, an even count's across one, so without
        // the division the same real dispersion would be judged twice as harshly whenever the
        // batch happens to have an odd number of elements.
        uint256 middle = count / 2;
        int256 spread;
        if (count % 2 == 1) {
            _aggregation.median = sorted[middle];
            // The values immediately bracketing the median position; for a single element the
            // median brackets itself, so the spread is zero.
            _aggregation.lowerNeighbour = count == 1 ? sorted[0] : sorted[middle - 1];
            _aggregation.upperNeighbour = count == 1 ? sorted[0] : sorted[middle + 1];
            // The AVERAGE of the two gaps flanking the median, so the comparison is against one
            // gap either way. `upperNeighbour >= lowerNeighbour` (the array is sorted), so the
            // division is a floor and cannot round away from zero.
            spread = count == 1
                ? int256(0)
                : (_aggregation.upperNeighbour - _aggregation.lowerNeighbour) / 2;
        } else {
            // An even count has no middle element: the two values that ARE averaged into the
            // median are the ones bracketing it, and their difference is already a single gap.
            _aggregation.lowerNeighbour = sorted[middle - 1];
            _aggregation.upperNeighbour = sorted[middle];
            // Solidity division truncates TOWARD ZERO, so a half-way average lands on the value
            // nearer zero: (1 + 2) / 2 == 1 and (-1 + -2) / 2 == -1.
            _aggregation.median = (sorted[middle - 1] + sorted[middle]) / 2;
            spread = _aggregation.upperNeighbour - _aggregation.lowerNeighbour;
        }
        _aggregation.spread = spread;

        // One bound, two uses (see `ITeeOracleFeedStore.submitFeedUpdates`): the parity-neutral
        // neighbour spread must stay inside it, and any single contribution outside it is flagged. abs(median) is
        // the relative base - `value` is signed, so the median may be zero or negative - and the
        // absolute term is what keeps the bound usable there. Computed in uint256, where
        // maxSpreadBIPS * abs(median) cannot overflow, then widened back: both terms are bounded
        // by UNBOUNDED_SPREAD + 2.15e17, far inside int256.
        uint256 absMedian = _aggregation.median >= 0
            ? uint256(_aggregation.median)
            : uint256(-_aggregation.median);
        _aggregation.allowedDeviation = int256(
            _absoluteAllowance(maxDecimals) + (uint256(maxSpreadBIPS) * absMedian) / MAX_BIPS
        );
        _aggregation.withinSpread = _aggregation.spread <= _aggregation.allowedDeviation;
    }

    /**
     * `maxSpreadAbsolute`, rescaled from its fixed `10**-8` reference scale to `_decimals`.
     * Clamped at both ends: a bound scaled up beyond `UNBOUNDED_SPREAD` already permits every
     * possible deviation, and one scaled down below a single unit of the batch's scale is zero.
     * The clamps are also what keep `10**k` inside uint256 - `_decimals` is an int8, so the two
     * scales can be up to 136 decades apart (`shift = _decimals - 8` spans [-136, 119]).
     */
    function _absoluteAllowance(
        int8 _decimals
    )
        internal view
        returns (uint256)
    {
        uint256 absolute = maxSpreadAbsolute;
        if (absolute == 0) {
            return 0; // the default: a purely relative bound
        }
        int256 shift = int256(_decimals) - MAX_SPREAD_ABSOLUTE_DECIMALS;
        if (shift > 20) {
            return UNBOUNDED_SPREAD;
        }
        if (shift < -20) {
            return 0;
        }
        if (shift >= 0) {
            // <= (2**64 - 1) * 10**20 ~= 1.8e39, inside uint256
            uint256 scaled = absolute * 10 ** uint256(shift);
            return scaled > UNBOUNDED_SPREAD ? UNBOUNDED_SPREAD : scaled;
        }
        return absolute / 10 ** uint256(-shift);
    }

    /**
     * Whether the batch's `_index`-th contribution deviates from the accepted median by more than
     * the deviation bound. Shared by the two passes of `_emitOutliers` so they cannot disagree.
     */
    function _isOutlier(
        Aggregation memory _aggregation,
        uint256 _index
    )
        internal pure
        returns (bool)
    {
        int256 deviation = _aggregation.normalisedValues[_index] - _aggregation.median;
        if (deviation < 0) {
            deviation = -deviation;
        }
        return deviation > _aggregation.allowedDeviation;
    }

    /**
     * Sorts a memory array of values ascending, in place. Insertion sort: N is capped at
     * MAX_SIGNATURES, where the quadratic term is a rounding error next to one ECDSA recovery.
     */
    function _sortAscending(
        int256[] memory _values
    )
        internal pure
    {
        for (uint256 i = 1; i < _values.length; i++) {
            int256 current = _values[i];
            uint256 j = i;
            while (j > 0 && _values[j - 1] > current) {
                _values[j] = _values[j - 1];
                j--;
            }
            _values[j] = current;
        }
    }

    /**
     * Brings an aggregated value into the stored `int32` / `int8` shape at the FINEST scale where
     * it fits, dividing by ten and decrementing the scale while it does not. Rounding is half
     * AWAY from zero, symmetrically for negatives (15 -> 2, -15 -> -2).
     * Nothing meaningful is lost: every contributed value is itself an int32, carrying at most
     * ~9.3 significant digits, and the median lies between the smallest and largest contribution,
     * so the result is representable in the same ~9.3 digits at its own magnitude. When the
     * machines agree on `decimals` the median is exactly representable and the loop does not run.
     * @param _value The aggregated value, at the `_decimals` scale.
     * @param _decimals The scale `_value` is expressed in.
     * @return _storedValue The value at the coarsest scale needed to fit int32.
     * @return _storedDecimals That scale.
     */
    function _toStoredScale(
        int256 _value,
        int8 _decimals
    )
        internal pure
        returns (
            int32 _storedValue,
            int8 _storedDecimals
        )
    {
        int256 scaled = _value;
        int256 scale = _decimals;
        while (scaled > int256(type(int32).max) || scaled < int256(type(int32).min)) {
            scaled = scaled >= 0 ? (scaled + 5) / 10 : (scaled - 5) / 10;
            scale -= 1;
        }
        // Unreachable for the batches this contract aggregates: each contribution is an int32 at
        // its own scale and the median lies between the smallest and the largest of them, so the
        // loop always terminates at or before the batch's SMALLEST `decimals` - itself an int8.
        // The check is here so that no future caller can silently truncate the scale instead.
        require(scale >= int256(type(int8).min), ValueOutOfRange());
        return (int32(scaled), int8(scale));
    }
}
