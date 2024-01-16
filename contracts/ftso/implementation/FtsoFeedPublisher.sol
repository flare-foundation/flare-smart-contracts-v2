// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../interface/IFtsoFeedPublisher.sol";
import "../../protocol/implementation/Relay.sol";
import "../../utils/implementation/AddressUpdatable.sol";
import "../../governance/implementation/Governed.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";


contract FtsoFeedPublisher is Governed, AddressUpdatable, IFtsoFeedPublisher {
    using MerkleProof for bytes32[];

    mapping(bytes8 => Feed) internal lastFeeds;
    mapping(bytes8 => mapping(uint256 => Feed)) internal publishedFeeds;

    Relay public relay;
    uint8 public immutable ftsoProtocolId;
    uint256 public immutable feedsHistorySize;
    address public feedsPublisher;

    event FtsoFeedPublished(Feed feed);

    modifier onlyFeedsPublisher {
        require(msg.sender == feedsPublisher, "only feeds publisher");
        _;
    }

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

    function publish(FeedWithProof[] calldata _proofs) external override {
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
                emit FtsoFeedPublished(feed);
            }
        }
    }

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
                emit FtsoFeedPublished(feed);
            }
        }
    }

    function setFeedsPublisher(address _feedsPublisher) external onlyGovernance {
        feedsPublisher = _feedsPublisher;
    }

    function getCurrentFeed(bytes8 _feedName) external view returns(Feed memory) {
        return lastFeeds[_feedName];
    }

    function getFeed(bytes8 _feedName, uint256 _votingRoundId) external view returns(Feed memory _feed) {
        require(_getMinVotingRoundId() <= _votingRoundId, "too old voting round id");
        //slither-disable-next-line weak-prng
        _feed = publishedFeeds[_feedName][_votingRoundId % feedsHistorySize];
        require(_feed.votingRoundId == _votingRoundId, "feed not published yet");
    }

    /**
     * @notice Implementation of the AddressUpdatable abstract method.
     * @dev It can be overridden if other contracts are needed.
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal override
    {
        relay = Relay(_getContractAddress(_contractNameHashes, _contractAddresses, "Relay"));
    }

    function _getMinVotingRoundId() internal view returns(uint256 _minVotingRoundId) {
        uint256 currentVotingRoundId = relay.getVotingRoundId(block.timestamp);
        if (currentVotingRoundId > feedsHistorySize) {
            _minVotingRoundId = currentVotingRoundId - feedsHistorySize;
        }
    }
}
