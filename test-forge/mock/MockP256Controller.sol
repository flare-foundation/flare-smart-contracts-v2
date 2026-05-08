// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockP256Controller {
    bool public result;

    constructor(bool _initial) {
        result = _initial;
    }

    function setResult(bool v) external {
        result = v;
    }

    function shouldVerify(
        bytes32 /*message*/,
        bytes32 /*r*/,
        bytes32 /*s*/,
        bytes32 /*pubX*/,
        bytes32 /*pubY*/
    ) external view returns (bool) {
        return result;
    }
}