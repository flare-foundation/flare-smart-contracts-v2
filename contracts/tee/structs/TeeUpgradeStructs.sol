// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IUpgradeManagerFacet } from "../../userInterfaces/tee/IUpgradeManagerFacet.sol";
import { IReplicationFacet } from "../../userInterfaces/tee/IReplicationFacet.sol";


interface TeeUpgradeStructs {

    function teeNodeVersionStruct(IUpgradeManagerFacet.TeeNodeVersion calldata) external;

    function teeUpgradePathStruct(IUpgradeManagerFacet.TeeUpgradePath calldata) external;

    function pauseForUpgradeStruct(IReplicationFacet.PauseForUpgrade calldata) external;

    function replicateTeeMachineStruct(IReplicationFacet.ReplicateTeeMachine calldata) external;
}
