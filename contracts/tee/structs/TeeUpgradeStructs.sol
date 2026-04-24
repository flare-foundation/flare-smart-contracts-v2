// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IUpgradeManager } from "../../userInterfaces/tee/IUpgradeManager.sol";
import { IReplication } from "../../userInterfaces/tee/IReplication.sol";


interface TeeUpgradeStructs {

    function teeNodeVersionStruct(IUpgradeManager.TeeNodeVersion calldata) external;

    function teeUpgradePathStruct(IUpgradeManager.TeeUpgradePath calldata) external;

    function pauseForUpgradeStruct(IReplication.PauseForUpgrade calldata) external;

    function replicateTeeMachineStruct(IReplication.ReplicateTeeMachine calldata) external;
}
