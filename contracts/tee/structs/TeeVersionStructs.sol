// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../../userInterfaces/tee/ITeeVersionManager.sol";


interface TeeVersionStructs {

    function teeNodeVersionStruct(ITeeVersionManager.TeeNodeVersion calldata) external;

    function teeUpgradePathStruct(ITeeVersionManager.TeeUpgradePath calldata) external;
}
