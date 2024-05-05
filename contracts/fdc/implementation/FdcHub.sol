// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../interface/IFdcHub.sol";

contract FdcHub is IFdcHub {
    uint256 public constant MINIMAL_FEE = 1 wei;

    constructor() {}

    function requestAttestation(bytes calldata _data) external payable {
        require(msg.value >= MINIMAL_FEE, "fee to low");

        emit AttestationRequest(_data, msg.value);
    }

    function getBaseFee(bytes calldata _data) external view returns (uint256) {
        return MINIMAL_FEE;
    }
}