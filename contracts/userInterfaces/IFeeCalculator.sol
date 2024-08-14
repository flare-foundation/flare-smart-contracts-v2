// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./ICChainVotePower.sol";


/**
 * FeeCalculator interface.
 */
interface IFeeCalculator {
    function calculateFee(uint256[] memory _indices) external view returns (uint256 _fee);

    function getFeedFee(bytes21 _feedId) external view returns (uint256 _fee);

    function categoryDefaultFee(uint8 _category) external view returns (uint256 _fee);
}

