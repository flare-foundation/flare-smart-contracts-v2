// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;


/**
 * FeeCalculator interface.
 */
interface IFeeCalculator {
    /**
     * Calculates a fee that needs to be paid to fetch feeds' data.
     * @param _feedIds List of feed ids.
    */
    function calculateFeeByIds(bytes21[] memory _feedIds) external view returns (uint256 _fee);

    /**
     * Calculates a fee that needs to be paid to fetch feeds' data.
     * @param _indices Indices of the feeds, corresponding to feed ids in
     * the FastUpdatesConfiguration contract.
    */
    function calculateFeeByIndices(uint256[] memory _indices) external view returns (uint256 _fee);
}

