// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

contract PassContract {
    address public account;
    uint16 public value;

    function setData1(address _account, uint16 _value) external returns(uint8) {
        account = _account;
        value = _value;

        return 5;
    }

    function setData2() external {
        value = 5;
        revert("testError");
    }
}