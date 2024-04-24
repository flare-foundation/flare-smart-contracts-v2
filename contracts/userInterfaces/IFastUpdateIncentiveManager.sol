// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../fastUpdates/lib/FixedPointArithmetic.sol" as FPA;
import "./IIncreaseManager.sol";

/**
 * Fast update incentive manager interface.
 */
interface IFastUpdateIncentiveManager is IIncreaseManager {

    /// Incentive offer structure.
    struct IncentiveOffer {
        FPA.Range rangeIncrease;
        FPA.Range rangeLimit;
    }

    /// Event emitted when an incentive is offered.
    event IncentiveOffered(FPA.Range rangeIncrease, FPA.SampleSize sampleSizeIncrease, FPA.Fee offerAmount);

    /// Event emitted when inflation rewards are offered.
    event InflationRewardsOffered(
        // reward epoch id
        uint24 indexed rewardEpochId,
        // feed ids - i.e. type + base/quote symbols - multiple of 21 (one feedId is bytes21)
        bytes feedIds,
        // reward band values (interpreted off-chain) in relation to the median - multiple of 4 (uint32)
        bytes rewardBandValues,
        // inflation shares - multiple of 3 (uint24)
        bytes inflationShares,
        // amount (in wei) of reward in native coin
        uint256 amount
    );

    /**
     * The entry point for third parties to make incentive offers. It accepts a payment and, using the contents of
     * `_offer`, computes how much the expected sample size will be increased to apply the requested (but capped) range
     * increase. If the ultimate value of the range exceeds the cap, funds are returned to the sender in proportion to
     * the amount by which the increase is adjusted to reach the cap.
     * @param _offer The requested amount of per-block variation range increase,
     * along with a cap for the ultimate range.
     */
    function offerIncentive(IncentiveOffer calldata _offer) external payable;

    /// Viewer for the current value of the expected sample size.
    function getExpectedSampleSize() external view returns (FPA.SampleSize);

    /// Viewer for the current value of the unit delta's precision (the fractional part of the scale).
    function getPrecision() external view returns (FPA.Precision);

    /// Viewer for the current value of the per-block variation range.
    function getRange() external view returns (FPA.Range);

    /// Viewer for the current value of the scale itself.
    function getScale() external view returns (FPA.Scale);
}
