// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * FtsoFeedPublisher interface.
 */
interface IFtsoFeedPublisher {

    /// The FTSO feed struct.
    struct Feed {
        uint32 votingRoundId;
        bytes21 id;
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
        bytes21 indexed id,
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
     * @param _feedId Feed id.
     */
    function getCurrentFeed(bytes21 _feedId) external view returns(Feed memory);

    /**
     * Returns the feed for given voting round id.
     * @param _feedId Feed id.
     * @param _votingRoundId Voting round id.
     */
    function getFeed(bytes21 _feedId, uint256 _votingRoundId) external view returns(Feed memory);
}
