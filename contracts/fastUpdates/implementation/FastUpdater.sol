// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;


import "../../governance/implementation/Governed.sol";
import "../../utils/implementation/AddressUpdatable.sol";
import "./CircularListManager.sol";
import "../../userInterfaces/IFlareSystemsManager.sol";
import "../../userInterfaces/IFtsoFeedPublisher.sol";
import "../../userInterfaces/IFastUpdatesConfiguration.sol";
import "../../protocol/interface/IIVoterRegistry.sol";
import "../interface/IIFastUpdater.sol";
import "../lib/Bn256.sol";
import "../interface/IIFastUpdateIncentiveManager.sol";
import { SortitionState, verifySortitionCredential, verifySignature } from "../lib/Sortition.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "../../utils/lib/SafePct.sol";

// The number of units of weight distributed among providers is 1 << VIRTUAL_PROVIDER_BITS
uint256 constant VIRTUAL_PROVIDER_BITS = 12;
// Value p is split into three parts,
// since FPA.Scale is 128 bits value with 120 bits for decimals all 3 parts
// need to be smaller than UINT_SPLIT number of bits
uint256 constant UINT_SPLIT = 256 - (120 + VIRTUAL_PROVIDER_BITS);
uint256 constant SMALL_P = Bn256.p & (2 ** UINT_SPLIT - 1);
uint256 constant MEDIUM_P = (Bn256.p >> UINT_SPLIT) & (2 ** UINT_SPLIT - 1);
uint256 constant BIG_P = Bn256.p >> (2 * UINT_SPLIT);


/**
 * @title Record of sortition-eligible providers+replicates that have already been submitted
 * @dev Each update transaction's verifiable, random "score" is recorded as a probably-unique description of the
 * provider, including the replicate if the provider has weight greater than 1, that submitted the transaction.
 */
struct SubmittedHashes {
    bytes32[] hashes;
}

/**
 * @title Main contract for submitting fast updates and maintaining current data feed values
 * @notice Providers will call `submitUpdates` with data of type `IFastUpdater.FastUpdates`. Anyone
 * may call `fetchCurrentFeeds` to view the current values for select data feeds.
 * @dev The contract stores references to several others that provide services, in particular the
 * `FastUpdateIncentiveManager` as well as several Flare system contracts for managing providers and the daemon.
 */
contract FastUpdater is Governed, IIFastUpdater, CircularListManager, AddressUpdatable {

    /// Maximum number of updates that can be stored in the backlog.
    uint256 private constant MAX_SUBMITTED_DELTAS_BACKLOG = 1000;

    /// Maximum age of a feed when reseting values, in voting epochs.
    uint256 public constant MAX_FEED_AGE_IN_VOTING_EPOCHS = 20;
    /// Number of decimal places in the internal representation of feed values.
    bytes internal decimals;

    /**
     * @dev This is purely internal as it may be stored in an odd structure for gas optimization. Access to it is only
     * through `fetchCurrentFeeds`.
     */
    bytes32[] private feeds;
    /**
     * @notice The submission window is a number of blocks forming a "grace period" after a round of sortition starts,
     * during which providers may submit updates for that round. In other words, each block starts a new round of
     * sortition and that round lasts `submissionWindow` blocks.
     */
    uint256 public submissionWindow;

    /// Timestamp when the first voting epoch started, in seconds since UNIX epoch.
    uint64 public immutable firstVotingRoundStartTs;
    /// Duration of voting epochs, in seconds.
    uint64 public immutable votingEpochDurationSeconds;

    /// The FlareDaemon contract, set at construction time.
    address public immutable flareDaemon;
    /// The last voting epoch id with emitted feeds.
    uint64 internal lastVotingEpochIdWithEmittedFeeds;
    /// The FlareSystemsManager contract.
    IFlareSystemsManager public flareSystemsManager;
    /// The FastUpdateIncentiveManager contract.
    IIFastUpdateIncentiveManager public fastUpdateIncentiveManager;
    /// The VoterRegistry contract.
    IIVoterRegistry public voterRegistry;
    /// The ftso feed publisher contract.
    IFtsoFeedPublisher public ftsoFeedPublisher;
    /// The FastUpdatesConfiguration contract.
    IFastUpdatesConfiguration public fastUpdatesConfiguration;

    /**
     * @dev This list is a circular buffer of updates that have already been accepted,
     * to prevent duplicate submissions. It keeps this record only for the active sortition rounds,
     * i.e. the most recent `submissionWindow` blocks plus the current one.
     */
    SubmittedHashes[] internal submittedHashes;

    bytes[] internal submittedDeltas;
    uint256 internal currentDelta;
    uint256 internal backlogDelta;

    /// Modifier for allowing only FlareDaemon contract to call the method.
    modifier onlyFlareDaemon {
        require(msg.sender == flareDaemon, "only flare daemon");
        _;
    }

    /**
     * The `FastUpdater` contract is initialized with data for interacting with the larger Flare system, as well as
     * initial values for the update-related storage.
     * @param _governanceSettings The address of the GovernanceSettings contract.
     * @param _initialGovernance The initial governance address.
     * @param _addressUpdater The address updater contract address.
     * @param _flareDaemon The flare daemon contract address.
     * @param _firstVotingRoundStartTs The timestamp of the first voting round start.
     * @param _votingEpochDurationSeconds The duration of voting epochs in seconds.
     * @param _submissionWindow Initialization of `submissionWindow`.
     */
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        address _flareDaemon,
        uint32 _firstVotingRoundStartTs,
        uint8 _votingEpochDurationSeconds,
        uint256 _submissionWindow
    )
        Governed(_governanceSettings, _initialGovernance) AddressUpdatable(_addressUpdater)
        CircularListManager(_submissionWindow + 1)
    {
        require(_flareDaemon != address(0), "flare daemon zero");
        require(_votingEpochDurationSeconds > 0, "voting epoch duration zero");
        // set immutable settings
        flareDaemon = _flareDaemon;
        firstVotingRoundStartTs = _firstVotingRoundStartTs;
        votingEpochDurationSeconds = _votingEpochDurationSeconds;
        lastVotingEpochIdWithEmittedFeeds = _getCurrentVotingEpochId();

        _setSubmissionWindow(_submissionWindow);
        _initSubmittedHashes();
        submittedDeltas = new bytes[](MAX_SUBMITTED_DELTAS_BACKLOG);
    }

    /**
     * Governance-only setter for the submission window length.
     * @param _submissionWindow The new submission window length.
     */
    function setSubmissionWindow(uint256 _submissionWindow) external onlyGovernance {
        _setSubmissionWindow(_submissionWindow);
        _setCircularLength(_submissionWindow + 1);
        delete submittedHashes;
        _initSubmittedHashes();
    }

    /**
     * @inheritdoc IIFastUpdater
     */
    function resetFeeds(uint256[] calldata _indices) external {
        require(msg.sender == address(fastUpdatesConfiguration) || msg.sender == governance(),
            "only fast updates configuration or governance");
        _applySubmitted();
        uint256 maxIndex = 0;
        for (uint256 i = 0; i < _indices.length; i++) {
            if (_indices[i] > maxIndex) {
                maxIndex = _indices[i];
            }
        }

        for (uint256 i = decimals.length; i <= maxIndex; i++) {
            decimals.push();
        }

        for (uint256 i = feeds.length; i <= (maxIndex / 8); i++) {
            feeds.push();
        }

        assert(8 * feeds.length >= decimals.length);
        uint256 currentVotingEpochId = _getCurrentVotingEpochId();
        for (uint256 i = 0; i < _indices.length; i++) {
            bytes21 feedId = fastUpdatesConfiguration.getFeedId(_indices[i]);
            require(feedId != bytes21(0), "index not supported");
            IFtsoFeedPublisher.Feed memory feed = ftsoFeedPublisher.getCurrentFeed(feedId);
            require(feed.votingRoundId + MAX_FEED_AGE_IN_VOTING_EPOCHS > currentVotingEpochId, "feed too old");
            require(feed.value > 0, "feed value zero or negative");

            uint256 slot = _indices[i] / 8;
            uint256 position = (7 - (_indices[i] % 8)) * 32;
            bytes32 mask = ~(bytes32(uint256(2**32 - 1)) << position);

            feeds[slot] = (feeds[slot] & mask) | (bytes32(uint256(uint32(feed.value))) << position);

            decimals[_indices[i]] = bytes1(uint8(feed.decimals));
            emit FastUpdateFeedReset(currentVotingEpochId, _indices[i], feedId, uint32(feed.value), feed.decimals);
        }
    }

    /**
     * @inheritdoc IIFastUpdater
     */
    function removeFeeds(uint256[] memory _indices) external {
        require(msg.sender == address(fastUpdatesConfiguration), "only fast updates configuration");
        _applySubmitted();
        for (uint256 i = 0; i < _indices.length; i++) {
            uint256 slot = _indices[i] / 8;
            uint256 position = (7 - (_indices[i] % 8)) * 32;
            bytes32 mask = ~(bytes32(uint256(2**32 - 1)) << position);
            feeds[slot] = feeds[slot] & mask;
            decimals[_indices[i]] = 0;
            emit FastUpdateFeedRemoved(_indices[i]);
        }
    }

    /**
     * @inheritdoc IFlareDaemonize
     */
    function daemonize() external onlyFlareDaemon returns (bool) {
        _applySubmitted();
        uint64 currentVotingEpochId = _getCurrentVotingEpochId();
        if (currentVotingEpochId > lastVotingEpochIdWithEmittedFeeds) {
            (uint256[] memory currentFeeds, int8[] memory currentDecimals) = _fetchAllCurrentFeeds();
            lastVotingEpochIdWithEmittedFeeds = currentVotingEpochId;
            emit FastUpdateFeeds(currentVotingEpochId, currentFeeds, currentDecimals);
        }
        delete submittedHashes[_nextIx()];
        fastUpdateIncentiveManager.advance();
        return true;
    }

    /**
     * @inheritdoc IFastUpdater
     */
    function submitUpdates(FastUpdates calldata _updates) external {
        require(
            block.number < _updates.sortitionBlock + submissionWindow,
            "Updates no longer accepted for the given block"
        );
        require(block.number >= _updates.sortitionBlock, "Updates not yet available for the given block");
        require((_updates.deltas.length * 4) <= feeds.length * 8, "More updates than available feeds");
        bytes32 msgHashed = sha256(abi.encode(_updates.sortitionBlock, _updates.sortitionCredential, _updates.deltas));
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(msgHashed);
        Signature calldata signature = _updates.signature;
        address signingPolicyAddress = ECDSA.recover(signedMessageHash, signature.v, signature.r, signature.s);
        require(signingPolicyAddress != address(0), "ECDSA: invalid signature");

        (Bn256.G1Point memory key, uint256 weight) = _providerData(signingPolicyAddress);
        SortitionState memory sortitionState = SortitionState({
            baseSeed: flareSystemsManager.getSeed(flareSystemsManager.getCurrentRewardEpochId()),
            blockNumber: _updates.sortitionBlock,
            scoreCutoff: _currentScoreCutoff(),
            weight: weight,
            pubKey: key
        });

        SubmittedHashes storage submittedI = _getSubmitted(_updates.sortitionBlock);
        bytes32 hashedRandomness =
            sha256(abi.encode(key, _updates.sortitionBlock, _updates.sortitionCredential.replicate));

        for (uint256 j = 0; j < submittedI.hashes.length; j++) {
            if (submittedI.hashes[j] == hashedRandomness) {
                revert("submission already provided");
            }
        }
        submittedI.hashes.push(hashedRandomness);

        (bool check, ) = verifySortitionCredential(sortitionState, _updates.sortitionCredential);
        require(check, "sortition proof invalid");

        _submitDeltas(_updates.deltas);

        emit FastUpdateFeedsSubmitted(signingPolicyAddress);
    }

    /**
     * @inheritdoc IFastUpdater
     */
    function fetchAllCurrentFeeds()
        external view
        returns (
            bytes21[] memory _feedIds,
            uint256[] memory _feeds,
            int8[] memory _decimals
        )
    {
        _feedIds = fastUpdatesConfiguration.getFeedIds();
        assert(_feedIds.length == decimals.length);
        uint256[] memory indices = new uint256[](_feedIds.length);
        for (uint256 i = 0; i < indices.length; i++) {
            indices[i] = i;
        }
        (_feeds, _decimals) = this.fetchCurrentFeeds(indices);
    }

    /**
     * @inheritdoc IFastUpdater
     */
    function fetchCurrentFeeds(uint256[] calldata _indices)
        external view
        returns (
            uint256[] memory _feeds,
            int8[] memory _decimals
        )
    {
        _decimals = new int8[](_indices.length);
        for (uint256 i = 0; i < _indices.length; ++i) {
            _decimals[i] = int8(uint8(decimals[_indices[i]]));
        }
        _feeds = new uint256[](_indices.length);
        FPA.Scale scale = fastUpdateIncentiveManager.getScale();

        // solhint-disable-next-line no-inline-assembly
        assembly {
            let arg := mload(0x40)
            // let arg2 := add(arg, 0x20) // not defined to lower the stack size
            // let arg3 := add(arg, 0x40) // not defined to lower the stack size
            // let locationDeltasBacklog := add(arg, 0x60) // not defined to lower the stack size
            let locationDeltas := add(arg, 0x80)
            let locationFeeds := add(arg, 0xa0)

            let length
            let delta
            let feed
            let tmpVar

            length := mul(sload(feeds.slot), 8)
            mstore(locationFeeds, feeds.slot)
            mstore(locationFeeds, keccak256(locationFeeds, 32))
            // location of deltas backlog, not defined in a variable to lower the stack size
            mstore(add(arg, 0x60), submittedDeltas.slot)
            mstore(add(arg, 0x60), keccak256(add(arg, 0x60), 32))
            // current position in the backlog, not defined in a variable to lower the stack size
            mstore(add(arg, 0xc0), sload(currentDelta.slot))

            calldatacopy(arg, _indices.offset, 0x20)
            mstore(add(arg, 0x20), div(mload(arg), 8)) // slot
            mstore(add(arg, 0x40), mod(mload(arg), 8))  // position
            feed := sload(add(mload(locationFeeds), mload(add(arg, 0x20))))

            for { let j := 0 } lt(j, _indices.length) { j := add(j, 1) } {
                calldatacopy(arg, add(_indices.offset, mul(j, 0x20)), 0x20)
                if iszero(lt(mload(arg), length)) {
                    revert(0, 0)
                }

                tmpVar := div(mload(arg), 8)  // use tmpVar for temporary value of slot
                mstore(add(arg, 0x40), mod(mload(arg), 8))  // position
                if iszero(eq(tmpVar, mload(add(arg, 0x20)))) {
                    mstore(add(arg, 0x20), tmpVar)
                    feed := sload(add(mload(locationFeeds), tmpVar))
                }

                tmpVar := shl(mul(mload(add(arg, 0x40)), 32), feed) // use tmpVar for temporary value extracting feed
                mstore(add(add(_feeds, 0x20), mul(j, 0x20)), shr(224, tmpVar))
            }

            // iterate over updates in the backlog
            for {
                let i := sload(backlogDelta.slot)
            } iszero(eq(i, mload(add(arg, 0xc0)))) {
                i := mod(add(i, 1), MAX_SUBMITTED_DELTAS_BACKLOG)
            } {
                // get location of the i-th update in the updates backlog
                mstore(locationDeltas, add(mload(add(arg, 0x60)), i))
                length := sload(mload(locationDeltas))

                // data is stored differently if there is more or less than 31 bytes
                // more than 31 bytes
                if eq(mod(length, 2), 1) {
                    mstore(locationDeltas, keccak256(locationDeltas, 32))
                    length := div(length, 2)
                    // length := add(div(sub(length, 1), 32), 1)
                    // get index of the first feed
                    calldatacopy(arg, _indices.offset, 0x20)
                    mstore(add(arg, 0x20), div(mload(arg), 128))  // slot offset

                    // get delta that has information about the first feed, if it exists
                    if lt(mload(arg), mul(length, 4)) {
                        delta := sload(add(mload(locationDeltas), mload(add(arg, 0x20))))
                    }

                    for { let j := 0 } lt(j, _indices.length) { j := add(j, 1) } {
                        calldatacopy(arg, add(_indices.offset, mul(j, 0x20)), 0x20)
                        tmpVar := div(mload(arg), 128) // use tmpVar for temporary value of slot

                        // if this update did not update the requested feed, skip it
                        if iszero(lt(mload(arg), mul(length, 4))) {
                            continue
                        }

                        mstore(add(arg, 0x40), mod(mload(arg), 128))  // position

                        if iszero(eq(tmpVar, mload(add(arg, 0x20)))) {
                            mstore(add(arg, 0x20), tmpVar)
                            delta := sload(add(mload(locationDeltas), tmpVar))
                        }

                        // use tmpVar for temporary value extracting one delta
                        tmpVar := shl(mul(mload(add(arg, 0x40)), 2), delta)
                        tmpVar := shr(254, tmpVar)
                        if eq(tmpVar, 1) {
                            // mul
                            feed := mul(mload(add(add(_feeds, 0x20), mul(j, 0x20))), scale)
                            mstore(add(add(_feeds, 0x20), mul(j, 0x20)), shr(127, feed))
                        }
                        if eq(tmpVar, 3) {
                            // div
                            feed := shl(127, mload(add(add(_feeds, 0x20), mul(j, 0x20))))
                            mstore(add(add(_feeds, 0x20), mul(j, 0x20)), div(feed, scale))
                        }
                    }
                    length := 1 // to avoid executing the other if case
                }

                // less than 32 bytes
                if eq(mod(length, 2), 0) {
                    delta := length
                    length := div(mod(length, 64), 2)

                    // get index of the first feed
                    calldatacopy(arg, _indices.offset, 0x20)
                    mstore(add(arg, 0x20), div(mload(arg), 128))  // slot offset

                    for { let j := 0 } lt(j, _indices.length) { j := add(j, 1) } {
                        calldatacopy(arg, add(_indices.offset, mul(j, 0x20)), 0x20)

                        // if this update did not update the requested feed, skip it
                        if iszero(lt(mload(arg), mul(length, 4))) {
                            continue
                        }

                        mstore(add(arg, 0x40), mod(mload(arg), 128))  // position

                        // use tmpVar for temporary value extracting one delta
                        tmpVar := shl(mul(mload(add(arg, 0x40)), 2), delta)
                        tmpVar := shr(254, tmpVar)
                        if eq(tmpVar, 1) {
                            // mul
                            feed := mul(mload(add(add(_feeds, 0x20), mul(j, 0x20))), scale)
                            mstore(add(add(_feeds, 0x20), mul(j, 0x20)), shr(127, feed))
                        }
                        if eq(tmpVar, 3) {
                            // div
                            feed := shl(127, mload(add(add(_feeds, 0x20), mul(j, 0x20))))
                            mstore(add(add(_feeds, 0x20), mul(j, 0x20)), div(feed, scale))
                        }
                    }
                }
            }
        }
    }

    /**
     * @inheritdoc IIPublicKeyVerifier
     */
    function verifyPublicKey(
        address _voter,
        bytes32 _part1,
        bytes32 _part2,
        bytes memory _verificationData
    )
        external view
    {
        (uint256 signature, uint256 rx, uint256 ry) = abi.decode(_verificationData, (uint256, uint256, uint256));

        Bn256.G1Point memory pk = Bn256.G1Point(uint256(_part1), uint256(_part2));
        require(Bn256.isG1PointOnCurve(pk));
        Bn256.G1Point memory r = Bn256.G1Point(rx, ry);
        require(Bn256.isG1PointOnCurve(r));
        verifySignature(pk, sha256(abi.encodePacked(_voter)), signature, r);
    }

    /**
     * @inheritdoc IFastUpdater
     */
    function currentSortitionWeight(address _signingPolicyAddress) external view returns (uint256 _weight) {
        (, _weight) = _providerData(_signingPolicyAddress);
    }

    /**
     * @inheritdoc IFastUpdater
     */
    function currentScoreCutoff() external view returns (uint256 _cutoff) {
        return _currentScoreCutoff();
    }

    /**
     * @inheritdoc IFlareDaemonize
     */
    function switchToFallbackMode() external view onlyFlareDaemon returns (bool) {
        // do nothing - there is no fallback mode in FastUpdater contract
        return false;
    }

    /**
     * @inheritdoc IFlareDaemonize
     */
    function getContractName() external pure returns (string memory) {
        return "FastUpdater";
    }

    /// Abstraction for setting the submission window, currently just a wrapper for assignment.
    function _setSubmissionWindow(uint256 _submissionWindow) internal {
        submissionWindow = _submissionWindow;
    }

    /// Sets the length of the buffer of already-submitted hashes of updates.
    function _initSubmittedHashes() internal {
        for (uint256 i = 0; i < circularLength; ++i) {
            submittedHashes.push();
        }
    }

    /// Internal method for storing a new set of updates to the buffer.
    function _submitDeltas(bytes calldata _deltas) internal {
        submittedDeltas[currentDelta] = _deltas;
        currentDelta = (currentDelta + 1) % MAX_SUBMITTED_DELTAS_BACKLOG;
    }

    /**
     * @inheritdoc AddressUpdatable
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal override
    {
        flareSystemsManager = IFlareSystemsManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsManager"));
        fastUpdateIncentiveManager = IIFastUpdateIncentiveManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FastUpdateIncentiveManager"));
        voterRegistry = IIVoterRegistry(
            _getContractAddress(_contractNameHashes, _contractAddresses, "VoterRegistry"));
        ftsoFeedPublisher = IFtsoFeedPublisher(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FtsoFeedPublisher"));
        fastUpdatesConfiguration = IFastUpdatesConfiguration(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FastUpdatesConfiguration"));
    }

    /// Internal method that applies the submitted updates to the current feed values.
    function _applySubmitted() internal {
        FPA.Scale scale = fastUpdateIncentiveManager.getScale();
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let arg := mload(0x40)
            let slot := add(arg, 0x20)
            let locationDeltas := add(arg, 0x40)
            let locationFeeds := add(arg, 0x60)
            // add(arg, 0x80) not saved in a variable to avoid the stack too long error
            mstore(add(arg, 0x80), sload(currentDelta.slot))
            let deltaReduced
            let feed
            let feedReduced
            let newFeed
            let delta
            let deltasLen

            mstore(locationFeeds, feeds.slot)
            mstore(locationFeeds, keccak256(locationFeeds, 32))
            mstore(slot, submittedDeltas.slot)

            // iterate over updates in the backlog
            for {
                let i := sload(backlogDelta.slot)
            } iszero(eq(i, mload(add(arg, 0x80)))) {
                i := mod(add(i, 1), MAX_SUBMITTED_DELTAS_BACKLOG)
            } {
                // get location of the i-th update in the updates backlog
                mstore(locationDeltas, add(keccak256(slot, 32), i))
                deltasLen := sload(mload(locationDeltas))

                // data is stored differently if there is more or less than 31 bytes
                // more than 31 bytes
                if eq(mod(deltasLen, 2), 1) {
                    mstore(locationDeltas, keccak256(locationDeltas, 32))
                    deltasLen := div(deltasLen, 2)
                    for { let j := 0 } lt(j, add(div(sub(deltasLen, 1), 32), 1)) { j := add(j, 1) } {
                        // load from storage a bytes32 element containing 128 deltas
                        delta := sload(add(mload(locationDeltas), j))

                        // the delta consists of 128 updates saved in 256 bits
                        for { let k := 0 } lt(k, 256) {} {
                            if iszero(lt(add(mul(j, 32), div(k, 8)), deltasLen)) {
                                break
                            }
                            // load from storage the value that covers 8 feeds
                            feed := sload(add(mload(locationFeeds), add(mul(j, 16), div(k, 16))))

                            // use 8 updates to change 8 feeds
                            newFeed := 0
                            for { let l := 0 } lt(l, 8) {l := add(l, 1) } {
                                feedReduced := shl(mul(l, 32), feed)
                                feedReduced := shr(224, feedReduced)

                                if lt(add(mul(j, 32), div(k, 8)), deltasLen) {
                                    deltaReduced := shl(k, delta)
                                    deltaReduced := shr(254, deltaReduced)

                                    if eq(deltaReduced, 1) {
                                        // mul
                                        feedReduced := mul(feedReduced, scale)
                                        feedReduced := shr(127, feedReduced)
                                    }
                                    if eq(deltaReduced, 3) {
                                        // div
                                        feedReduced := shl(127, feedReduced)
                                        feedReduced := div(feedReduced, scale)
                                    }
                                }
                                feedReduced := shl(sub(224, mul(l, 32)), feedReduced)
                                newFeed := or(newFeed, feedReduced)

                                k:= add(k, 2)
                            }

                            // store a new value covering 8 feeds
                            sstore(add(mload(locationFeeds), add(mul(j, 16), div(sub(k, 16), 16))), newFeed)
                        }
                    }
                    deltasLen := 1 // to avoid executing the other if case
                }

                // less than 32 bytes
                if eq(mod(deltasLen, 2), 0) {
                    delta := deltasLen
                    deltasLen := div(mod(deltasLen, 64), 2)

                    // the delta consists of 128 updates saved in 256 bits
                    for { let k := 0 } lt(k, 256) {} {
                        if iszero(lt(div(k, 8), deltasLen)) {
                            break
                        }
                        // load from storage the value that covers 8 feeds
                        feed := sload(add(mload(locationFeeds), div(k, 16)))

                        // use 8 updates to change 8 feeds
                        newFeed := 0
                        for { let l := 0 } lt(l, 8) {l := add(l, 1) } {
                            feedReduced := shl(mul(l, 32), feed)
                            feedReduced := shr(224, feedReduced)
                            if lt(div(k, 8), deltasLen) {
                                deltaReduced := shl(k, delta)
                                deltaReduced := shr(254, deltaReduced)
                                if eq(deltaReduced, 1) {
                                    // mul
                                    feedReduced := mul(feedReduced, scale)
                                    feedReduced := shr(127, feedReduced)
                                }
                                if eq(deltaReduced, 3) {
                                    // div
                                    feedReduced := shl(127, feedReduced)
                                    feedReduced := div(feedReduced, scale)
                                }
                            }
                            feedReduced := shl(sub(224, mul(l, 32)), feedReduced)
                            newFeed := or(newFeed, feedReduced)

                            k:= add(k, 2)
                        }

                        // store a new value covering 8 feeds
                        sstore(add(mload(locationFeeds), div(sub(k, 16), 16)), newFeed)
                    }
                }
            }
            // change backlogDelta variable to equal currentDelta
            sstore(backlogDelta.slot, mload(add(arg, 0x80)))
        }
    }

    /**
     * Internal access to the stored data of all feeds
     * @return _feeds The list of data for all feeds.
     * @return _decimals The list of decimal places all feeds.
     */
    function _fetchAllCurrentFeeds()
        internal view
        returns (
            uint256[] memory _feeds,
            int8[] memory _decimals
        )
    {
        _feeds = new uint256[](decimals.length);
        _decimals = new int8[](decimals.length);
        uint256 position;
        uint256 fullSlots = decimals.length / 8;
        for (uint256 slot = 0; slot < fullSlots; slot++) {
            uint256 feedsValues = uint256(feeds[slot]);
            for (uint256 i = 0; i < 8; i++) {
                uint256 index = slot * 8 + i;
                _decimals[index] = int8(uint8(decimals[index]));
                position = i * 32;
                _feeds[index] = (feedsValues << position) >> 224;
            }
        }
        if (decimals.length % 8 != 0) {
            uint256 feedsValues = uint256(feeds[fullSlots]);
            for (uint256 i = fullSlots * 8; i < decimals.length; i++) {
                _decimals[i] = int8(uint8(decimals[i]));
                position = (i % 8) * 32;
                _feeds[i] = (feedsValues << position) >> 224;
            }
        }
    }

    /**
     * Computes the score cutoff for sortition by fetching the current expected sample size from the
     * `FastUpdateIncentiveManager` contract and scaling it from the number of virtual providers to the score range.
     * @return _cutoff The score cutoff for this block.
     */
    function _currentScoreCutoff() internal view returns (uint256 _cutoff) {
        FPA.SampleSize expectedSampleSize = fastUpdateIncentiveManager.getExpectedSampleSize();
        // The formula is: (exp. s.size)/(num. prov.) = (score)/(score range)
        //   score range = p = 21888242871839275222246405745257275088696311157297823662689037894645226208583
        //   num. providers = 2**VIRTUAL_PROVIDER_BITS
        //   exp. sample size = "expectedSampleSize8x120 >> 120", in that we keep the fractional bits:
        _cutoff = BIG_P * uint256(FPA.SampleSize.unwrap(expectedSampleSize)) <<
            (2*UINT_SPLIT - VIRTUAL_PROVIDER_BITS - 120);
        _cutoff += MEDIUM_P * uint256(FPA.SampleSize.unwrap(expectedSampleSize)) >>
            (VIRTUAL_PROVIDER_BITS + 120 - UINT_SPLIT);
        _cutoff += (SMALL_P * uint256(FPA.SampleSize.unwrap(expectedSampleSize))) >>
            (VIRTUAL_PROVIDER_BITS + 120);
    }

    /// Internal utility for fetching hashes of submitted updates for an active sortition round.
    function _getSubmitted(uint256 _blockNum) internal view returns (SubmittedHashes storage _submittedI) {
        string memory failMsg = "Sortition round for the given block is no longer or not yet available";
        uint256 ix = _blockIx(_blockNum, failMsg);
        _submittedI = submittedHashes[ix];
    }

    /**
     * Extends `currentSortitionWeight` by giving all public sortition data for a provider.
     * @param _signingPolicyAddress The provider's registered address
     * @return _key The provider's sortition public key (via the "altbn_128" elliptic curve)
     * @return _weight The provider's current sortition weight, defined to be the normalized delegation weight out of
     * the number of virtual providers.
     */
    function _providerData(address _signingPolicyAddress)
        internal view
        returns (Bn256.G1Point memory _key, uint256 _weight)
    {
        uint256 epochId = flareSystemsManager.getCurrentRewardEpochId();
        (bytes32 pk1, bytes32 pk2, uint16 normalizedWeight, uint16 normalisedWeightsSum) =
            voterRegistry.getPublicKeyAndNormalisedWeight(epochId, _signingPolicyAddress);
        _key = Bn256.G1Point(uint256(pk1), uint256(pk2));
        _weight = SafePct.mulDivRoundUp(normalizedWeight, 1 << VIRTUAL_PROVIDER_BITS, normalisedWeightsSum);
    }

    /**
     * Returns the current voting epoch id.
     */
    function _getCurrentVotingEpochId() internal view returns(uint64) {
        return uint64((block.timestamp - firstVotingRoundStartTs) / votingEpochDurationSeconds);
    }

}
