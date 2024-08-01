// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * FtsoV2 interface.
 */
interface IFtsoV2 {

    struct FeedData {
        uint32 votingRoundId;
        bytes21 id;
        int32 value;
        uint16 turnoutBIPS;
        int8 decimals;
    }

    struct FeedDataWithProof {
        bytes32[] proof;
        FeedData body;
    }

    function getFeedByIndex(
        uint256 _index
    )
        external payable
        returns (
            uint256 _value,
            int8 _decimals,
            uint64 _timestamp
        );

    function getFeedById(bytes21 _id)
        external payable
        returns (
            uint256 _value,
            int8 _decimals,
            uint64 _timestamp
        );

    function getFeedsByIndex(uint256[] calldata _indices)
        external payable
        returns (
            uint256[] memory _values,
            int8[] memory _decimals,
            uint64 _timestamp
        );

    function getFeedsById(bytes21[] calldata _ids)
        external payable
        returns (
            uint256[] memory _values,
            int8[] memory _decimals,
            uint64 _timestamp
        );

    function getFeedByIndexInWei(
        uint256 _index
    )
        external payable
        returns (
            uint256 _value,
            uint64 _timestamp
        );

    function getFeedByIdInWei(bytes21 _id)
        external payable
        returns (
            uint256 _value,
            uint64 _timestamp
        );

    function getFeedsByIndexInWei(uint256[] calldata _indices)
        external payable
        returns (
            uint256[] memory _values,
            uint64 _timestamp
        );

    function getFeedsByIdInWei(bytes21[] calldata _ids)
        external payable
        returns (
            uint256[] memory _values,
            uint64 _timestamp
        );

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

    function verifyFeedData(FeedDataWithProof calldata _feedData) external view returns (bool);


}