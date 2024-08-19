// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./IReferencedPaymentNonexistence.sol";

interface IReferencedPaymentNonexistenceVerification {
    function verifyReferencedPaymentNonexistence(IReferencedPaymentNonexistence.Proof calldata _proof)
        external view returns (bool _proved);
}
