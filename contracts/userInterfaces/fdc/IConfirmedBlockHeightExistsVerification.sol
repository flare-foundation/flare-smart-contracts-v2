// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./IConfirmedBlockHeightExists.sol";

interface IConfirmedBlockHeightExistsVerification {
    function verifyConfirmedBlockHeightExists(IConfirmedBlockHeightExists.Proof calldata _proof)
        external view returns (bool _proved);
}
