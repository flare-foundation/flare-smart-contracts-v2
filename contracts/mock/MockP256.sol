// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IP256Controller {
    function shouldVerify(
        bytes32 message,
        bytes32 r,
        bytes32 s,
        bytes32 pubX,
        bytes32 pubY
    ) external view returns (bool);
}

/**
 * @title P256 Mock (for Forge coverage)
 */
library P256 {
    // fixed controller address; tests can deploy a controller here to set outcome
    address internal constant CONTROLLER = 0x00000000000000000000000000000000000000A1;

    function verify(
        bytes32 _message,
        bytes32 _r,
        bytes32 _s,
        bytes32 _pubX,
        bytes32 _pubY
    )
        internal view
        returns (bool)
    {
        // require controller code to be present; tests must use etch + init storage
        require(CONTROLLER.code.length > 0, "P256 controller code missing");
        (bool success, bytes memory data) = CONTROLLER.staticcall(
            abi.encodeWithSelector(
                IP256Controller.shouldVerify.selector,
                _message,
                _r,
                _s,
                _pubX,
                _pubY
            )
        );
        if (!success || data.length < 32) {
            return false;
        }
        return abi.decode(data, (bool));
    }
}