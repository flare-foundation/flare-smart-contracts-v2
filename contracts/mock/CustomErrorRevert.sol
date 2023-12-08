// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

error CustomErrorMessage(string message);
error CustomError();
error CustomErrorUint(string message, uint256 value);


contract CustomErrorRevert {

    function errorRevert(bool _message) public pure {
        if (_message) {
            revert CustomErrorMessage("some error message");
        }
        else {
            revert CustomError();
        }
    }

    function errorRevertUint(uint256 _value) public pure {
            revert CustomErrorUint("error message", _value);
    }

}
