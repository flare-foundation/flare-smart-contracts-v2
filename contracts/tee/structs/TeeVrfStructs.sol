// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { ITeeVrf } from "../../userInterfaces/tee/ITeeVrf.sol";

interface TeeVrfStructs {

    function vrfInstructionMessageStruct(ITeeVrf.VrfInstructionMessage calldata) external;
}
