// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

interface IIVoterRegistrationTrigger {

    /**
     * Enables system registration of voters.
     * @param _rewardEpochId Reward epoch id for which the voter registration should be triggered.
     */
    function triggerVoterRegistration(uint24 _rewardEpochId) external;
}
