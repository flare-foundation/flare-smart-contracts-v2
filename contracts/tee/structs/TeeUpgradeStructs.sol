// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { ITeeVersionManagerFacet } from "../../userInterfaces/tee/ITeeVersionManagerFacet.sol";
import { ITeeReplicationFacet } from "../../userInterfaces/tee/ITeeReplicationFacet.sol";


interface TeeUpgradeStructs {

    function teeNodeVersionStruct(ITeeVersionManagerFacet.TeeNodeVersion calldata) external;

    function teeUpgradePathStruct(ITeeVersionManagerFacet.TeeUpgradePath calldata) external;

    function pauseForUpgradeStruct(ITeeReplicationFacet.PauseForUpgrade calldata) external;

    function replicateTeeMachineStruct(ITeeReplicationFacet.ReplicateTeeMachine calldata) external;
}
