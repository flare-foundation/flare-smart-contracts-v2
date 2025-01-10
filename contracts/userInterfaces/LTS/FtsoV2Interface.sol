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

    /**
     * Returns the list of supported feed ids.
     * @return _feedIds The list of supported feed ids.
     */
    function getSupportedFeedIds() external view returns (bytes21[] memory _feedIds);

    /**
     * Calculates the fee for fetching a feed.
     * @param _feedId The id of the feed.
     * @return _fee The fee for fetching the feed.
     */
    function calculateGetFeedFee(bytes21 _feedId) external view returns (uint256 _fee);

    /**
     * Calculates the fee for fetching feeds.
     * @param _feedIds The list of feed ids.
     * @return _fee The fee for fetching the feeds.
     */
    function calculateGetFeedsFee(bytes21[] calldata _feedIds) external view returns (uint256 _fee);

    /**
     * Returns stored data of a feed.
     * A fee (calculated by the FeeCalculator contract) may need to be paid.
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
     * @param _feedIds The list of feed ids.
     * @return _values The list of values for the requested feeds.
     * @return _decimals The list of decimal places for the requested feeds.
     * @return _timestamp The timestamp of the last update.
     */
    function getFeedsById(bytes21[] calldata _feedIds)
        external payable
        returns (
            uint256[] memory _values,
            int8[] memory _decimals,
            uint64 _timestamp
        );


    /**
     * Returns value in wei and timestamp of a feed.
     * A fee (calculated by the FeeCalculator contract) may need to be paid.
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
     * @param _feedIds Ids of the feeds.
     * @return _values The list of values for the requested feeds in wei (i.e. with 18 decimal places).
     * @return _timestamp The timestamp of the last update.
     */
    function getFeedsByIdInWei(bytes21[] calldata _feedIds)
        external payable
        returns (
            uint256[] memory _values,
            uint64 _timestamp
        );

    /**
     * Checks if the feed data is valid (i.e. is part of the confirmed Merkle tree).
     * @param _feedData Structure containing data about the feed (FeedData structure) and Merkle proof.
     * @return true if the feed data is valid.
     */
    function verifyFeedData(FeedDataWithProof calldata _feedData) external view returns (bool);
}