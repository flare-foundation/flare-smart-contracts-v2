// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

contract ExecuteMock {
    uint256 internal num;

    function setNum(uint256 _n) public payable {
        num = _n;
    }

    function setNum1(uint256 _n) public payable {
        require(_n == 100);
        num = _n;
    }

    function setNum2(uint256 _n) public payable {
        require(_n == 100, "wrong number");
        num = _n;
    }

    function getNum() public view returns (uint256) {
        return num;
    }
}