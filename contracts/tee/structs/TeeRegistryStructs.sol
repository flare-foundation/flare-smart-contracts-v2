// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../../userInterfaces/tee/ITeeRegistry.sol";


interface TeeRegistryStructs {

    function teeMachineStruct(ITeeRegistry.TeeMachine calldata) external;

    function teeMachineWithAttestationDataStruct(ITeeRegistry.TeeMachineWithAttestationData calldata) external;

    function availabilityCheckRequestStruct(ITeeRegistry.AvailabilityCheckRequest calldata) external;

    function availabilityCheckResponseStruct(ITeeRegistry.AvailabilityCheckResponse calldata) external;

    function pauseForUpgradeStruct(ITeeRegistry.PauseForUpgrade calldata) external;

    function replicateTeeMachineStruct(ITeeRegistry.ReplicateTeeMachine calldata) external;
}
