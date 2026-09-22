// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { TeeExtensionInstructionsSenderMock } from "../mock/TeeExtensionInstructionsSenderMock.sol";


interface TeeExtensionInstructionsSenderMockStructs {

    function transactionStruct(TeeExtensionInstructionsSenderMock.Transaction calldata) external;

    function signTransactionStruct(TeeExtensionInstructionsSenderMock.SignTransaction calldata) external;
}
