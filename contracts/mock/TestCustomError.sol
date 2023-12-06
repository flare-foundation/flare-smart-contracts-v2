// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

error CustomErrorMessage(string message);
error CustomError();
error CustomErrorUint(string message, uint256 value);


contract TestCustomError {

    function testError(bool _message) public {
        if (_message) {
            revert CustomErrorMessage("some error message");
        }
        else {
            revert CustomError();
        }
    }

    function testErrorUint(uint256 _value) public {
            revert CustomErrorUint("error message", _value);
    }

}
