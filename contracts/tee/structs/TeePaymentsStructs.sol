// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../../userInterfaces/tee/ITeePayments.sol";


interface TeePaymentsStructs {

    function paymentInstructionStruct(ITeePayments.PaymentInstruction calldata) external;

    function paymentInstructionMessageStruct(ITeePayments.PaymentInstructionMessage calldata) external;
}
