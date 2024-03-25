// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../contracts/governance/implementation/GovernedBase.sol";

contract GovernedMock is GovernedBase {
    uint256 public a;
    uint256 public b;

    constructor() {
    }

    function changeA(uint256 _value)
        external
        onlyGovernance
    {
        a = _value;
    }

    function changeWithRevert(uint256 _value)
        external
        onlyGovernance
    {
        a = _value;
        revert("this is revert");
    }
}
