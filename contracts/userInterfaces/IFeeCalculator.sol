// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./ICChainVotePower.sol";


/**
 * FeeCalculator interface.
 */
interface IFeeCalculator {
    /**
     * Calculates a fee that needs to be paid to fetch feeds' data.
     * @param _indices Indices of the feeds, corresponding to feed ids in
     * the FastUpdatesConfiguration contract.
    */
    function calculateFee(uint256[] memory _indices) external view returns (uint256 _fee);

    /**
     * Returns a fee for a feed.
     * @param _feedId Feed id for which to return the fee.
     // todo if fee is not set revert or return default fee for category??
     */
    function getFeedFee(bytes21 _feedId) external view returns (uint256 _fee);

    /**
     * Returns a default fee for a category.
     * @param _category Category for which to return the default fee.
     */
    function categoryDefaultFee(uint8 _category) external view returns (uint256 _fee);
}

