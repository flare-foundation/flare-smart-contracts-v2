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
 *      configuration generation. Strictly increasing, never-future `observedAt`
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

    /// Emitted once at initialization with the immutable per-instance configuration
    /// (the settable configuration additionally emits its setter events at initialization).
    event FeedStoreInitialised(
        address indexed instructionsSender,
        uint256 indexed extensionId,
        bytes21 indexed feedId
    );

    /// Emitted when a feed update is accepted and the stored value updates.
    event FeedUpdated(int32 indexed value, int8 decimals, uint64 indexed observedAt, address indexed teeId);

    /// Emitted when the fee destination changes.
    event FeeDestinationSet(address feeDestination);

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

    /**
     * Submits a TEE-signed feed update.
     * The signer must be a PRODUCTION-status TEE machine on the store's extension
     * (verified through `IFdc2Verification.verifyTeeSignature`, which also rejects
     * submissions while the extension is emergency paused), the update must name this
     * store's extension id and feed id, and its observation timestamp must strictly increase and
     * be strictly older than the accepting block.
     * It must also carry the FEED's latest published configuration generation: `endpointsHash`
     * and `adminsHash` are checked against the sender's `latestEndpointsHash` /
     * `latestAdminsHash` (`NoEndpointsPublished` / `NoAdminsPublished` when the feed has no
     * publication of that kind, `StaleEndpoints` / `StaleAdmins` on a mismatch). This is
     * deliberately the feed-level generation and not the version the machine was last dispatched:
     * a publication therefore invalidates every machine still running the previous configuration
     * until it adopts the new one. The rollout gap that opens is bounded — a feed publishes at
     * most hourly and a publication auto-dispatches to the live active set — and it is what
     * makes a configuration change take effect at once instead of machine by machine.
     * @param _feedUpdate The feed update, exactly as signed.
     * @param _signature The TEE signature over the update.
     */
    function submitFeedUpdate(
        FeedUpdate calldata _feedUpdate,
        Signature calldata _signature
    )
        external;

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
