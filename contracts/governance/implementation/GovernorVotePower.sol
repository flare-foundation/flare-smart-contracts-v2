// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "flare-smart-contracts/contracts/token/interface/IIGovernanceVotePower.sol";

abstract contract GovernorVotePower {

    IIGovernanceVotePower public votePower;

    constructor() {}

    function setVotePowerContract(IIGovernanceVotePower _votePowerAddress) internal {
            votePower = _votePowerAddress;
    }

    function votePowerOfAt(address _owner, uint256 _blockNumber) internal view returns (uint256) {
        return votePower.votePowerOfAt(_owner, _blockNumber);
    }
}
