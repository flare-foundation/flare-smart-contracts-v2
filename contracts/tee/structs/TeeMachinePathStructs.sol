// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IMachinePathManager } from "../../userInterfaces/tee/IMachinePathManager.sol";


interface TeeMachinePathStructs {

    function machinePathStruct(IMachinePathManager.MachinePath calldata) external;
}
