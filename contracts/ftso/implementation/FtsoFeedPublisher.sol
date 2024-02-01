// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../interface/IIFtsoFeedPublisher.sol";
import "../../userInterfaces/IRelay.sol";
import "../../utils/implementation/AddressUpdatable.sol";
import "../../governance/implementation/Governed.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";


/**
 * FtsoFeedPublisher contract.
 *
 * This contract is used to publish the FTSO feeds.
 */
contract FtsoFeedPublisher is Governed, AddressUpdatable, IIFtsoFeedPublisher {
    using MerkleProof for bytes32[];

    mapping(bytes8 feedName => Feed) internal lastFeeds;
    mapping(bytes8 feedName => mapping(uint256 feedHistoryPosition => Feed)) internal publishedFeeds;

    /// The Relay contract.
    IRelay public relay;
    /// The FTSO protocol id.
    uint8 public immutable ftsoProtocolId;
    /// The size of the feeds history.
    uint256 public immutable feedsHistorySize;
    /// The address of the feeds publisher contract.
    address public feedsPublisher;

    /// Only feeds publisher can call this method.
    modifier onlyFeedsPublisher {
        require(msg.sender == feedsPublisher, "only feeds publisher");
        _;
    }

    /**
     * Constructor.
     * @param _governanceSettings The address of the GovernanceSettings contract.
     * @param _initialGovernance The initial governance address.
     * @param _addressUpdater The address of the AddressUpdater contract.
     * @param _ftsoProtocolId The FTSO protocol id.
     * @param _feedsHistorySize The size of the feeds history.
     */
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        uint8 _ftsoProtocolId,
        uint256 _feedsHistorySize
    )
        Governed(_governanceSettings, _initialGovernance) AddressUpdatable(_addressUpdater)
    {
        require(_ftsoProtocolId > 0, "invalid ftso protocol id");
        require(_feedsHistorySize > 0, "history size zero");
        ftsoProtocolId = _ftsoProtocolId;
        feedsHistorySize = _feedsHistorySize;
    }

    /**
     * @inheritdoc IFtsoFeedPublisher
     */
    function publish(FeedWithProof[] calldata _proofs) external {
        uint256 minVotingRoundId = _getMinVotingRoundId();
        uint256 length = _proofs.length;
        for (uint i = 0; i < length; i++) {
            FeedWithProof calldata proof = _proofs[i];
            Feed calldata feed = proof.body;
            bool addLastFeed = feed.votingRoundId > lastFeeds[feed.name].votingRoundId;
            //slither-disable-next-line weak-prng
            uint256 feedHistoryPosition = feed.votingRoundId % feedsHistorySize;
            bool addHistoryFeed = feed.votingRoundId >= minVotingRoundId &&
                publishedFeeds[feed.name][feedHistoryPosition].votingRoundId != feed.votingRoundId;
            if (addLastFeed || addHistoryFeed) {
                bytes32 feedHash = keccak256(abi.encode(feed));
                bytes32 merkleRoot = relay.merkleRoots(ftsoProtocolId, feed.votingRoundId);
                require(proof.merkleProof.verifyCalldata(merkleRoot, feedHash), "merkle proof invalid");
                if (addLastFeed) {
                    lastFeeds[feed.name] = feed;
                }
                if (addHistoryFeed) {
                    publishedFeeds[feed.name][feedHistoryPosition] = feed;
                }
                emit FtsoFeedPublished(feed.votingRoundId, feed.name, feed.value, feed.turnoutBIPS, feed.decimals);
            }
        }
    }

    /**
     * @inheritdoc IIFtsoFeedPublisher
     */
    function publishFeeds(Feed[] memory _feeds) external onlyFeedsPublisher {
        uint256 minVotingRoundId = _getMinVotingRoundId();
        uint256 length = _feeds.length;
        for (uint i = 0; i < length; i++) {
            Feed memory feed = _feeds[i];
            bool addLastFeed = feed.votingRoundId > lastFeeds[feed.name].votingRoundId;
            //slither-disable-next-line weak-prng
            uint256 feedHistoryPosition = feed.votingRoundId % feedsHistorySize;
            bool addHistoryFeed = feed.votingRoundId >= minVotingRoundId &&
                publishedFeeds[feed.name][feedHistoryPosition].votingRoundId != feed.votingRoundId;
            if (addLastFeed || addHistoryFeed) {
                if (addLastFeed) {
                    lastFeeds[feed.name] = feed;
                }
                if (addHistoryFeed) {
                    publishedFeeds[feed.name][feedHistoryPosition] = feed;
                }
                emit FtsoFeedPublished(feed.votingRoundId, feed.name, feed.value, feed.turnoutBIPS, feed.decimals);
            }
        }
    }

    /**
     * Sets the feeds publisher address.
     * @param _feedsPublisher The address of the feeds publisher contract.
     * @dev Only governance can call this method.
     */
    function setFeedsPublisher(address _feedsPublisher) external onlyGovernance {
        feedsPublisher = _feedsPublisher;
    }

    /**
     * @inheritdoc IFtsoFeedPublisher
     */
    function getCurrentFeed(bytes8 _feedName) external view returns(Feed memory) {
        return lastFeeds[_feedName];
    }

    /**
     * @inheritdoc IFtsoFeedPublisher
     */
    function getFeed(bytes8 _feedName, uint256 _votingRoundId) external view returns(Feed memory _feed) {
        require(_getMinVotingRoundId() <= _votingRoundId, "too old voting round id");
        //slither-disable-next-line weak-prng
        _feed = publishedFeeds[_feedName][_votingRoundId % feedsHistorySize];
        require(_feed.votingRoundId == _votingRoundId, "feed not published yet");
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
        relay = IRelay(_getContractAddress(_contractNameHashes, _contractAddresses, "Relay"));
    }

    /**
     * Returns the minimum voting round id.
     */
    function _getMinVotingRoundId() internal view returns(uint256 _minVotingRoundId) {
        uint256 currentVotingRoundId = relay.getVotingRoundId(block.timestamp);
        if (currentVotingRoundId > feedsHistorySize) {
            _minVotingRoundId = currentVotingRoundId - feedsHistorySize;
        }
    }
}
