// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { TeeExtensionInstructionsSenderMock } from "../mock/TeeExtensionInstructionsSenderMock.sol";


interface TeeExtensionInstructionsSenderMockStructs {

    function transactionStruct(TeeExtensionInstructionsSenderMock.Transaction calldata) external;

    function signTransactionStruct(TeeExtensionInstructionsSenderMock.SignTransaction calldata) external;
}
