// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IXRPPaymentNonexistence } from "./IXRPPaymentNonexistence.sol";

interface IXRPPaymentNonexistenceVerification {
    function verifyXRPPaymentNonexistence(IXRPPaymentNonexistence.Proof calldata _proof)
        external view returns (bool _proved);
}
