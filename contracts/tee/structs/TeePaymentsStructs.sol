// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../../userInterfaces/tee/ITeePaymentsEVM.sol";


interface TeePaymentsStructs {

    function paymentInstructionStruct(ITeePayments.PaymentInstruction calldata) external;

    function paymentInstructionMessageStruct(ITeePayments.PaymentInstructionMessage calldata) external;

    function opTypeConstantsEVMStruct(ITeePaymentsEVM.OpTypeConstantsEVM calldata) external;
}
