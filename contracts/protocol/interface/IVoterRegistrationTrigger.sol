// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;


interface IVoterRegistrationTrigger {

    /**
     * Enables system registration of voters
     * @param _rewardEpochId reward epoch id for which the voter registration should be triggered
     */
    function triggerVoterRegistration(uint24 _rewardEpochId) external;
}
