// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../../userInterfaces/tee/ITeeMachineRegistry.sol";
import "../../userInterfaces/tee/ITeeReplication.sol";


interface TeeMachineRegistryStructs {

    function teeMachineStruct(ITeeMachineRegistry.TeeMachine calldata) external;

    function teeMachineWithAttestationDataStruct(ITeeMachineRegistry.TeeMachineWithAttestationData calldata) external;

    function pauseForUpgradeStruct(ITeeReplication.PauseForUpgrade calldata) external;

    function replicateTeeMachineStruct(ITeeReplication.ReplicateTeeMachine calldata) external;
}
