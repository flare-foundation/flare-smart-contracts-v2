// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./IPayment.sol";

interface IPaymentVerification {

    function verifyPayment(IPayment.Proof calldata _proof)
        external view returns (bool _proved);
}
