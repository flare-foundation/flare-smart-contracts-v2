// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IInstructions } from "../../userInterfaces/tee/IInstructions.sol";


interface TeeInstructionsStructs {

    function teeInstructionParamsStruct(IInstructions.TeeInstructionParams calldata) external;
}
