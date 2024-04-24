// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * Increase manager interface.
 */
interface IIncreaseManager {
    function getIncentiveDuration() external view returns (uint256);
}
