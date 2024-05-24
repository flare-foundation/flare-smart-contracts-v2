// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * FastUpdatesConfiguration interface.
 */
interface IFastUpdatesConfiguration {

    /**
     * The feed configuration struct.
     */
    struct FeedConfiguration {
        // feed id
        bytes21 feedId;
        // reward band value (interpreted off-chain) in relation to the median
        uint32 rewardBandValue;
        // inflation share
        uint24 inflationShare;
    }

    /// Event emitted when a feed is added.
    event FeedAdded(bytes21 indexed feedId, uint32 rewardBandValue, uint24 inflationShare, uint256 index);
    /// Event emitted when a feed is updated.
    event FeedUpdated(bytes21 indexed feedId, uint32 rewardBandValue, uint24 inflationShare, uint256 index);
    /// Event emitted when a feed is removed.
    event FeedRemoved(bytes21 indexed feedId, uint256 index);

    /**
     * Returns the index of a feed.
     * @param _feedId The feed id.
     * @return _index The index of the feed.
     */
    function getFeedIndex(bytes21 _feedId) external view returns (uint256 _index);

    /**
     * Returns the feed id at a given index. Removed (unused) feed index will return bytes21(0).
     * @param _index The index.
     * @return _feedId The feed id.
     */
    function getFeedId(uint256 _index) external view returns (bytes21 _feedId);

    /**
     * Returns all feed ids. For removed (unused) feed indices, the feed id will be bytes21(0).
     */
    function getFeedIds() external view returns (bytes21[] memory);

    /**
     * Returns the number of feeds, including removed ones.
     */
    function getNumberOfFeeds() external view returns (uint256);

    /**
     * Returns the feed configurations, including removed ones.
     */
    function getFeedConfigurations() external view returns (FeedConfiguration[] memory);

    /**
     * Returns the unused indices - indices of removed feeds.
     */
    function getUnusedIndices() external view returns (uint256[] memory);
}
