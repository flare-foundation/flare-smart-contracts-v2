// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/**
 * @title Suicidal Mock
 * Provide a means to test behavior of contracts that are targets of a self-destructing contract.
 **/
contract SuicidalMock {
    address payable public target;
    constructor(address payable _target) {
        target = _target;
    }

    receive() external payable {}

    function die() external payable {
        //slither-disable-next-line suicidal
        selfdestruct(target);
    }
}
