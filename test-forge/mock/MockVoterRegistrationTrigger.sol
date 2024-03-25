// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../contracts/protocol/interface/IIVoterRegistrationTrigger.sol";

contract MockVoterRegistrationTrigger is IIVoterRegistrationTrigger {
    //solhint-disable-next-line no-unused-vars
    function triggerVoterRegistration(uint24 _rewardEpochId) external pure {
        revert("error456");
    }
}