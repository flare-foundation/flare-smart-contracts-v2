// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./IEVMTransaction.sol";

interface IEVMTransactionVerification {

    function verifyEVMTransaction(IEVMTransaction.Proof calldata _proof)
        external view returns (bool _proved);
}
