// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

contract ExecuteMockSquare {
    mapping(uint256 => uint256) internal square;

    function setSquare(uint256 _n) public payable {
        square[_n] = _n * _n;
    }

    function getSquare(uint256 _n) public view returns (uint256) {
        return square[_n];
    }
}