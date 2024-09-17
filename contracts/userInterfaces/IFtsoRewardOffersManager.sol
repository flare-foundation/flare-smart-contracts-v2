// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * FtsoRewardOffersManager interface.
 */
interface IFtsoRewardOffersManager {

    /**
    * Defines a reward offer.
    */
    struct Offer {
        // amount (in wei) of reward in native coin
        uint120 amount;
        // feed id - i.e. category + base/quote symbol
        bytes21 feedId;
        // minimal reward eligibility turnout threshold in BIPS (basis points)
        uint16 minRewardedTurnoutBIPS;
        // primary band reward share in PPM (parts per million)
        uint24 primaryBandRewardSharePPM;
        // secondary band width in PPM (parts per million) in relation to the median
        uint24 secondaryBandWidthPPM;
        // address that can claim undistributed part of the reward (or burn address)
        address claimBackAddress;
    }

    /// Event emitted when the minimal rewards offer value is set.
    event MinimalRewardsOfferValueSet(uint256 valueWei);

    /// Event emitted when a reward offer is received.
    event RewardsOffered(
        // reward epoch id
        uint24 indexed rewardEpochId,
        // feed id - i.e. category + base/quote symbol
        bytes21 feedId,
        // number of decimals (negative exponent)
        int8 decimals,
        // amount (in wei) of reward in native coin
        uint256 amount,
        // minimal reward eligibility turnout threshold in BIPS (basis points)
        uint16 minRewardedTurnoutBIPS,
        // primary band reward share in PPM (parts per million)
        uint24 primaryBandRewardSharePPM,
        // secondary band width in PPM (parts per million) in relation to the median
        uint24 secondaryBandWidthPPM,
        // address that can claim undistributed part of the reward (or burn address)
        address claimBackAddress
    );

    /// Event emitted when inflation rewards are offered.
    event InflationRewardsOffered(
        // reward epoch id
        uint24 indexed rewardEpochId,
        // feed ids - i.e. category + base/quote symbols - multiple of 21 (one feedId is bytes21)
        bytes feedIds,
        // decimals encoded to - multiple of 1 (int8)
        bytes decimals,
        // amount (in wei) of reward in native coin
        uint256 amount,
        // minimal reward eligibility turnout threshold in BIPS (basis points)
        uint16 minRewardedTurnoutBIPS,
        // primary band reward share in PPM (parts per million)
        uint24 primaryBandRewardSharePPM,
        // secondary band width in PPM (parts per million) in relation to the median - multiple of 3 (uint24)
        bytes secondaryBandWidthPPMs,
        // rewards split mode (0 means equally, 1 means random,...)
        uint16 mode
    );

    /**
     * Allows community to offer rewards.
     * @param _nextRewardEpochId The next reward epoch id.
     * @param _offers The list of offers.
     */
    function offerRewards(
        uint24 _nextRewardEpochId,
        Offer[] calldata _offers
    )
        external payable;

    /**
     * Minimal rewards offer value (in wei).
     */
    function minimalRewardsOfferValueWei() external view returns(uint256);
}
