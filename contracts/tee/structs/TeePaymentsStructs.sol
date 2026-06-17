// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { ITeePaymentsBase } from "../../userInterfaces/tee/ITeePaymentsBase.sol";
import { ITeePayments } from "../../userInterfaces/tee/ITeePayments.sol";
import { ITeePaymentsUtxo } from "../../userInterfaces/tee/ITeePaymentsUtxo.sol";
import { ITeePaymentsLimitsManager } from "../../userInterfaces/tee/ITeePaymentsLimitsManager.sol";


interface TeePaymentsStructs {

    function pmwMultisigAccountStruct(ITeePaymentsBase.PMWMultisigAccount calldata) external;

    function paymentInstructionStruct(ITeePaymentsBase.PaymentInstruction calldata) external;

    function reissueFeeParamsStruct(ITeePaymentsBase.ReissueFeeParams calldata) external;

    function paymentInstructionMessageStruct(ITeePayments.PaymentInstructionMessage calldata) external;

    function utxoPaymentInstructionMessageStruct(ITeePaymentsUtxo.UtxoPaymentInstructionMessage calldata) external;

    function utxoAnchorStateStruct(ITeePaymentsUtxo.UtxoAnchorState calldata) external;

    function setPaymentLimitsStruct(ITeePaymentsLimitsManager.SetPaymentLimitsMessage calldata) external;

}
