// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IVrfFacet } from "../../userInterfaces/tee/IVrfFacet.sol";

interface TeeVrfStructs {

    function vrfInstructionMessageStruct(IVrfFacet.VrfInstructionMessage calldata) external;
}
