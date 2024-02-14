// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * ValidatorRewardOffersManager interface.
 */
interface IValidatorRewardOffersManager {

    /// Event emitted when inflation rewards are offered.
    event InflationRewardsOffered(
        // reward epoch id
        uint24 indexed rewardEpochId,
        // amount (in wei) of reward in native coin
        uint256 amount
    );

}
