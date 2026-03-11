// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { ITeePayments } from "../../userInterfaces/tee/ITeePayments.sol";


interface TeePaymentsStructs {

    function pmwMultisigAccountStruct(ITeePayments.PMWMultisigAccount calldata) external;

    function paymentInstructionStruct(ITeePayments.PaymentInstruction calldata) external;

    function reissueFeeParamsStruct(ITeePayments.ReissueFeeParams calldata) external;

    function paymentInstructionMessageStruct(ITeePayments.PaymentInstructionMessage calldata) external;

    function setPaymentLimitsStruct(ITeePayments.SetPaymentLimits calldata) external;

}
