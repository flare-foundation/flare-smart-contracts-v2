// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * IFtsoFeedIdConverter interface.
 */
interface IFtsoFeedIdConverter {

    /**
     * Returns the feed id for given category and name.
     * @param _category Feed category.
     * @param _name Feed name.
     * @return Feed id.
     */
    function getFeedId(uint8 _category, string memory _name) external view returns(bytes21);

    /**
     * Returns the feed category and name for given feed id.
     * @param _feedId Feed id.
     * @return _category Feed category.
     * @return _name Feed name.
     */
    function getFeedCategoryAndName(bytes21 _feedId) external pure returns(uint8 _category, string memory _name);
}
