// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./ICChainVotePower.sol";


/**
 * FeeCalculator interface.
 */
interface IFeeCalculator {
    /**
     * Calculates a fee that needs to be paid to fetch feeds' data.
     * @param _ids List of feed ids.
    */
    function calculateFeeByIds(bytes21[] memory _ids) external view returns (uint256 _fee);
}

