// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { ITeeVrfFacet } from "../../userInterfaces/tee/ITeeVrfFacet.sol";

interface TeeVrfStructs {

    function vrfInstructionMessageStruct(ITeeVrfFacet.VrfInstructionMessage calldata) external;
}
