// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../../userInterfaces/IFlareSystemCalculator.sol";

/**
 * FlareSystemCalculator internal interface.
 */
interface IIFlareSystemCalculator is IFlareSystemCalculator {

    /**
     * Calculates the registration weight of a voter.
     * It is approximation of the staking weight and capped WNat weight to the power of 0.75.
     * @param _voter The address of the voter.
     * @param _rewardEpochId The reward epoch id.
     * @param _votePowerBlockNumber The block number at which the vote power is calculated.
     * @return _registrationWeight The registration weight of the voter.
     * @dev Only VoterRegistry can call this method.
     */
    function calculateRegistrationWeight(
        address _voter,
        uint24 _rewardEpochId,
        uint256 _votePowerBlockNumber
    )
        external
        returns (uint256 _registrationWeight);


    /**
     * Calculates the burn factor for a voter in a given reward epoch.
     * @param _rewardEpochId The reward epoch id.
     * @param _voter The address of the voter.
     */
    function calculateBurnFactorPPM(uint24 _rewardEpochId, address _voter) external view returns(uint256);

}
