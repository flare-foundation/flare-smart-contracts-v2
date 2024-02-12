// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * FtsoFeedPublisher interface.
 */
interface IFtsoFeedPublisher {

    /// The FTSO feed struct.
    struct Feed {
        uint32 votingRoundId;
        bytes8 name;
        int32 value;
        uint16 turnoutBIPS;
        int8 decimals;
    }

    /// The FTSO random struct.
    struct Random {
        uint32 votingRoundId;
        uint256 value;
        bool isSecure;
    }

    /// The FTSO feed with proof struct.
    struct FeedWithProof {
        bytes32[] merkleProof;
        Feed body;
    }

    /// Event emitted when a new feed is published.
    event FtsoFeedPublished(
        uint32 indexed votingRoundId,
        bytes8 indexed name,
        int32 value,
        uint16 turnoutBIPS,
        int8 decimals
    );

    /**
     * Publishes feeds.
     * @param _proofs The FTSO feeds with proofs to publish.
     */
    function publish(FeedWithProof[] calldata _proofs) external;

    /**
     *The FTSO protocol id.
     */
    function ftsoProtocolId() external view returns(uint8);

    /**
     * The size of the feeds history.
     */
    function feedsHistorySize() external view returns(uint256);

    /**
     * Returns the current feed.
     * @param _feedName Feed name.
     */
    function getCurrentFeed(bytes8 _feedName) external view returns(Feed memory);

    /**
     * Returns the feed for given voting round id.
     * @param _feedName Feed name.
     * @param _votingRoundId Voting round id.
     */
    function getFeed(bytes8 _feedName, uint256 _votingRoundId) external view returns(Feed memory _feed);
}
