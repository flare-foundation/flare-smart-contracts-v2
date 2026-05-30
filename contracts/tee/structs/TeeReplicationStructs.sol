// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IReplication } from "../../userInterfaces/tee/IReplication.sol";


interface TeeReplicationStructs {

    function pauseForUpgradeStruct(IReplication.PauseForUpgrade calldata) external;

    function replicateTeeMachineStruct(IReplication.ReplicateTeeMachine calldata) external;
}
