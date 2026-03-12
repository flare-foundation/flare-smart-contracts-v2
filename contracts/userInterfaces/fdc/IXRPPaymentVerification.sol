// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IXRPPayment } from "./IXRPPayment.sol";

interface IXRPPaymentVerification {
    function verifyXRPPayment(IXRPPayment.Proof calldata _proof)
        external view returns (bool _proved);
}
