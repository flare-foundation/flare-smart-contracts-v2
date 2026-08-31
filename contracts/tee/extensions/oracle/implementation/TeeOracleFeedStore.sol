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
import { Signature } from "../../../../userInterfaces/ISignature.sol";
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
 * The store itself implements the FTSO custom feed interface (`IICustomFeed`), so it is
 * registered with FtsoV2 directly — upgrades keep the proxy address, hence the
 * registration; no separate adapter contract is needed. Reading is payable like every
 * other feed: `calculateFee` resolves through the central `FeeCalculator` and
 * `getCurrentFeed` forwards the entire msg.value to `feeDestination`.
 */
contract TeeOracleFeedStore is IITeeOracleFeedStore, IICustomFeed, FlareUpgradeableBase {

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
     */
    function initialize(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        ITeeOracleInstructionsSender _instructionsSender,
        bytes21 _feedId,
        address _feeDestination
    )
        external
        initializer
    {
        FlareUpgradeableBase.initializeBase(_governanceSettings, _initialGovernance, _addressUpdater);
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
    }

    /**
     * @inheritdoc ITeeOracleFeedStore
     */
    function submitFeedUpdate(
        FeedUpdate calldata _feedUpdate,
        Signature calldata _signature
    )
        external
    {
        // Recovers the signer and requires a PRODUCTION machine on this extension; also
        // rejects while the extension is emergency paused. Reverts with typed
        // Fdc2Verification / ECDSA errors on any failure.
        address teeId = fdc2Verification.verifyTeeSignature(
            extensionId,
            _signature,
            SignedPayload.messageHash(TEE_ORACLE_FEED, keccak256(abi.encode(_feedUpdate)))
        );

        // The signed update must name this exact feed — the feed id binding prevents
        // replaying an update onto another feed served by the same extension.
        bytes21 feedId_ = feedId;
        require(_feedUpdate.extensionId == extensionId, WrongExtensionId());
        require(_feedUpdate.feedId == feedId_, WrongFeedId());

        // The machine must prove it runs the feed's LATEST published configuration and admin
        // sets - the feed-level generation, not whatever this machine was last dispatched. The
        // admin sets decide who may install credentials in the enclave, so they are checked on
        // the same terms as the endpoints. Publishing is therefore an immediate invalidation of
        // every machine still running the previous generation: acceptable because a feed
        // publishes at most hourly, and it is the property a per-machine record cannot give.
        ITeeOracleInstructionsSender sender = instructionsSender; // used more than once
        bytes32 expected = sender.latestEndpointsHash(feedId_);
        require(expected != bytes32(0), NoEndpointsPublished());
        require(_feedUpdate.endpointsHash == expected, StaleEndpoints());

        bytes32 expectedAdmins = sender.latestAdminsHash(feedId_);
        require(expectedAdmins != bytes32(0), NoAdminsPublished());
        require(_feedUpdate.adminsHash == expectedAdmins, StaleAdmins());

        // Strictly increasing observedAt covers replay and out-of-order delivery.
        require(_feedUpdate.observedAt > observedAt, NotNewer());

        // Observations are stamped with the timestamp of an emitted on-chain event, and
        // the round trip to the machine and back cannot complete within one block, so an
        // acceptable observation is always strictly older than the accepting block.
        // observedAt only ratchets up, so without this check a future-dated update would
        // freeze the feed irreversibly.
        require(_feedUpdate.observedAt < block.timestamp, TooFarAhead());

        value = _feedUpdate.value;
        decimals = _feedUpdate.decimals;
        observedAt = _feedUpdate.observedAt;

        emit FeedUpdated(_feedUpdate.value, _feedUpdate.decimals, _feedUpdate.observedAt, teeId);
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
        _collectFee();
        uint64 observedAt_ = observedAt;
        // observedAt only ratchets up from the first accepted update, so this triggers
        // only while the feed is unpublished; the slot is already loaded — the check is free.
        require(observedAt_ != 0, NoValuePublished());
        _value = value;
        _decimals = decimals;
        _timestamp = observedAt_;
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
}
