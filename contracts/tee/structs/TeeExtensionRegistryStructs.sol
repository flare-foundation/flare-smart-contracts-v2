// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { ITeeExtensionRegistryFacet } from "../../userInterfaces/tee/ITeeExtensionRegistryFacet.sol";


interface TeeExtensionRegistryStructs {

    function teeInstructionParamsStruct(ITeeExtensionRegistryFacet.TeeInstructionParams calldata) external;
}
