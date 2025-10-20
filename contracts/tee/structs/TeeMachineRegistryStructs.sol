// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { ITeeMachineRegistry } from "../../userInterfaces/tee/ITeeMachineRegistry.sol";


interface TeeMachineRegistryStructs {

    function teeMachineDataStruct(ITeeMachineRegistry.TeeMachineData calldata) external;

    function teeMachineStruct(ITeeMachineRegistry.TeeMachine calldata) external;

    function teeMachineWithAttestationDataStruct(ITeeMachineRegistry.TeeMachineWithAttestationData calldata) external;
}
