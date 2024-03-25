// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * IFtsoFeedIdConverter interface.
 */
interface IFtsoFeedIdConverter {

    /**
     * Returns the feed id for given type and name.
     * @param _type Feed type.
     * @param _name Feed name.
     * @return Feed id.
     */
    function getFeedId(uint8 _type, string memory _name) external view returns(bytes21);

    /**
     * Returns the feed type and name for given feed id.
     * @param _feedId Feed id.
     * @return _type Feed type.
     * @return _name Feed name.
     */
    function getFeedTypeAndName(bytes21 _feedId) external pure returns(uint8 _type, string memory _name);
}
