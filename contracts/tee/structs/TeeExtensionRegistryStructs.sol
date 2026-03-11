// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { ITeeExtensionRegistry } from "../../userInterfaces/tee/ITeeExtensionRegistry.sol";


interface TeeExtensionRegistryStructs {

    function teeInstructionParamsStruct(ITeeExtensionRegistry.TeeInstructionParams calldata) external;
}
