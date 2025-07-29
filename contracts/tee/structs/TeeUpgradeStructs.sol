// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../../userInterfaces/tee/ITeeVersionManager.sol";
import "../../userInterfaces/tee/ITeeReplication.sol";


interface TeeUpgradeStructs {

    function teeNodeVersionStruct(ITeeVersionManager.TeeNodeVersion calldata) external;

    function teeUpgradePathStruct(ITeeVersionManager.TeeUpgradePath calldata) external;

    function pauseForUpgradeStruct(ITeeReplication.PauseForUpgrade calldata) external;

    function replicateTeeMachineStruct(ITeeReplication.ReplicateTeeMachine calldata) external;
}
