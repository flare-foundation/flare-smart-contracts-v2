// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * FtsoV2 long term support interface.
 */
interface FtsoV2Interface {

    /// Feed data structure
    struct FeedData {
        uint32 votingRoundId;
        bytes21 id;
        int32 value;
        uint16 turnoutBIPS;
        int8 decimals;
    }

    /// Feed data with proof structure
    struct FeedDataWithProof {
        bytes32[] proof;
        FeedData body;
    }

    /// Feed id change structure
    struct FeedIdChange {
        bytes21 oldFeedId;
        bytes21 newFeedId;
    }

    /// Event emitted when a feed id is changed (e.g. feed renamed).
    event FeedIdChanged(bytes21 indexed oldFeedId, bytes21 indexed newFeedId);

    /**
     * Returns stored data of a feed.
     * A fee (calculated by the FeeCalculator contract) may need to be paid.
     * NOTE: reverts with "value negative" if the requested custom feed reports a negative value -
     * use the signed `getCurrentFeed` for feeds with a signed source.
     * @param _feedId The id of the feed.
     * @return _value The value for the requested feed.
     * @return _decimals The decimal places for the requested feed.
     * @return _timestamp The timestamp of the last update.
     */
    function getFeedById(bytes21 _feedId)
        external payable
        returns (
            uint256 _value,
            int8 _decimals,
            uint64 _timestamp
        );

    /**
     * Returns stored data of each feed.
     * A fee (calculated by the FeeCalculator contract) may need to be paid.
     * Reverts if the requested feeds do not report the same timestamp - only possible if a custom feed
     * with its own timestamp source is included. It is recommended to use `getCurrentFeeds` instead,
     * which returns a timestamp for each feed.
     * NOTE: reverts with "value negative" if a requested custom feed reports a negative value -
     * use the signed `getCurrentFeeds` for feeds with a signed source.
     * @param _feedIds The list of feed ids.
     * @return _values The list of values for the requested feeds.
     * @return _decimals The list of decimal places for the requested feeds.
     * @return _timestamp The timestamp of the last update, shared by all requested feeds.
     */
    function getFeedsById(bytes21[] memory _feedIds)
        external payable
        returns (
            uint256[] memory _values,
            int8[] memory _decimals,
            uint64 _timestamp
        );

    /**
     * Returns value in wei and timestamp of a feed.
     * A fee (calculated by the FeeCalculator contract) may need to be paid.
     * NOTE: reverts with "value negative" if the requested custom feed reports a negative value -
     * use the signed `getCurrentFeedInWei` for feeds with a signed source.
     * @param _feedId The id of the feed.
     * @return _value The value for the requested feed in wei (i.e. with 18 decimal places).
     * @return _timestamp The timestamp of the last update.
     */
    function getFeedByIdInWei(bytes21 _feedId)
        external payable
        returns (
            uint256 _value,
            uint64 _timestamp
        );

    /** Returns value of each feed and a timestamp.
     * For some feeds, a fee (calculated by the FeeCalculator contract) may need to be paid.
     * Reverts if the requested feeds do not report the same timestamp - only possible if a custom feed
     * with its own timestamp source is included. It is recommended to use `getCurrentFeedsInWei` instead,
     * which returns a timestamp for each feed.
     * NOTE: reverts with "value negative" if a requested custom feed reports a negative value -
     * use the signed `getCurrentFeedsInWei` for feeds with a signed source.
     * @param _feedIds Ids of the feeds.
     * @return _values The list of values for the requested feeds in wei (i.e. with 18 decimal places).
     * @return _timestamp The timestamp of the last update, shared by all requested feeds.
     */
    function getFeedsByIdInWei(bytes21[] memory _feedIds)
        external payable
        returns (
            uint256[] memory _values,
            uint64 _timestamp
        );

    /**
     * Returns stored data of a feed - the signed variant of `getFeedById`.
     * A fee (calculated by the FeeCalculator contract) may need to be paid.
     * Values are signed: fast update feeds are always non-negative, but a custom feed with a
     * signed source may report negative values.
     * @param _feedId The id of the feed.
     * @return _value The value for the requested feed; may be negative for custom feeds.
     * @return _decimals The decimal places for the requested feed.
     * @return _timestamp The timestamp of the last update.
     */
    function getCurrentFeed(bytes21 _feedId)
        external payable
        returns (
            int256 _value,
            int8 _decimals,
            uint64 _timestamp
        );

    /**
     * Returns value in wei and timestamp of a feed - the signed variant of `getFeedByIdInWei`.
     * A fee (calculated by the FeeCalculator contract) may need to be paid.
     * Negative values truncate toward zero when scaled down to 18 decimals.
     * @param _feedId The id of the feed.
     * @return _value The value for the requested feed in wei (i.e. with 18 decimal places);
     * may be negative for custom feeds.
     * @return _timestamp The timestamp of the last update.
     */
    function getCurrentFeedInWei(bytes21 _feedId)
        external payable
        returns (
            int256 _value,
            uint64 _timestamp
        );

    /**
     * Returns stored data of each feed, with the timestamp of each feed.
     * A fee (calculated by the FeeCalculator contract) may need to be paid.
     * In contrast to `getFeedsById`, the timestamps may differ between feeds - all fast update feeds
     * share the same timestamp, while custom feeds report their own. Values are signed: fast update
     * feeds are always non-negative, but a custom feed with a signed source may report negative values.
     * @param _feedIds The list of feed ids.
     * @return _values The list of values for the requested feeds; may be negative for custom feeds.
     * @return _decimals The list of decimal places for the requested feeds.
     * @return _timestamps The list of timestamps of the last update, one for each requested feed.
     */
    function getCurrentFeeds(bytes21[] memory _feedIds)
        external payable
        returns (
            int256[] memory _values,
            int8[] memory _decimals,
            uint64[] memory _timestamps
        );

    /** Returns value of each feed, with the timestamp of each feed.
     * For some feeds, a fee (calculated by the FeeCalculator contract) may need to be paid.
     * In contrast to `getFeedsByIdInWei`, the timestamps may differ between feeds - all fast update
     * feeds share the same timestamp, while custom feeds report their own. Values are signed like
     * in `getCurrentFeeds`; negative values truncate toward zero when scaled down to 18 decimals.
     * @param _feedIds Ids of the feeds.
     * @return _values The list of values for the requested feeds in wei (i.e. with 18 decimal
     * places); may be negative for custom feeds.
     * @return _timestamps The list of timestamps of the last update, one for each requested feed.
     */
    function getCurrentFeedsInWei(bytes21[] memory _feedIds)
        external payable
        returns (
            int256[] memory _values,
            uint64[] memory _timestamps
        );

    /**
     * Returns the FTSO protocol id.
     */
    function getFtsoProtocolId() external view returns (uint256);

    /**
     * Returns the list of supported feed ids (currently active feed ids).
     * To get the list of all available feed ids, combine with `getFeedIdChanges()`.
     * @return _feedIds The list of supported feed ids.
     */
    function getSupportedFeedIds() external view returns (bytes21[] memory _feedIds);

    /**
     * Returns the list of feed id changes.
     * @return _feedIdChanges The list of changed feed id pairs (old and new feed id).
     */
    function getFeedIdChanges() external view returns (FeedIdChange[] memory _feedIdChanges);

    /**
     * Calculates the fee for fetching a feed.
     * @param _feedId The id of the feed.
     * @return _fee The fee for fetching the feed.
     */
    function calculateFeeById(bytes21 _feedId) external view returns (uint256 _fee);

    /**
     * Calculates the fee for fetching feeds.
     * @param _feedIds The list of feed ids.
     * @return _fee The fee for fetching the feeds.
     */
    function calculateFeeByIds(bytes21[] memory _feedIds) external view returns (uint256 _fee);

    /**
     * Checks if the feed data is valid (i.e. is part of the confirmed Merkle tree).
     * @param _feedData Structure containing data about the feed (FeedData structure) and Merkle proof.
     * @return true if the feed data is valid.
     */
    function verifyFeedData(FeedDataWithProof calldata _feedData) external view returns (bool);
}
