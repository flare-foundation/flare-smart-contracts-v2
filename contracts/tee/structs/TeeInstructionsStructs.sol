// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IInstructionsFacet } from "../../userInterfaces/tee/IInstructionsFacet.sol";


interface TeeInstructionsStructs {

    function teeInstructionParamsStruct(IInstructionsFacet.TeeInstructionParams calldata) external;
}
