// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IFdc2InflationConfigurations } from "./IFdc2InflationConfigurations.sol";

/**
 * Fdc2RewardOffersManager interface.
 */
interface IFdc2RewardOffersManager {

    /// Event emitted when inflation rewards are offered.
    event InflationRewardsOffered(
        // reward epoch id
        uint24 indexed rewardEpochId,
        // fdc2 configurations
        IFdc2InflationConfigurations.Fdc2Configuration[] fdc2Configurations,
        // amount (in wei) of reward in native coin
        uint256 amount
    );

    /**
     * The FDC2 inflation configurations contract.
     */
    function fdc2InflationConfigurations()
        external view
        returns (IFdc2InflationConfigurations);
}
