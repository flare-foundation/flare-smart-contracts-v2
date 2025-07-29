// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../../userInterfaces/tee/ITeeMachineRegistry.sol";


interface TeeMachineRegistryStructs {

    function teeMachineStruct(ITeeMachineRegistry.TeeMachine calldata) external;

    function teeMachineWithAttestationDataStruct(ITeeMachineRegistry.TeeMachineWithAttestationData calldata) external;
}
