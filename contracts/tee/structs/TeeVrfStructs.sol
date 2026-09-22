// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IVrf } from "../../userInterfaces/tee/IVrf.sol";

interface TeeVrfStructs {

    function vrfInstructionMessageStruct(IVrf.VrfInstructionMessage calldata) external;
}
