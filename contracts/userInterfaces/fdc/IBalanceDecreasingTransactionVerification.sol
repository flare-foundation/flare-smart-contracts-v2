// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./IBalanceDecreasingTransaction.sol";

interface IBalanceDecreasingTransactionVerification {
    function verifyBalanceDecreasingTransaction(IBalanceDecreasingTransaction.Proof calldata _proof)
        external view returns (bool _proved);
}
