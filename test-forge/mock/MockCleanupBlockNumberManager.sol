// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../contracts/protocol/interface/IICleanupBlockNumberManager.sol";

contract MockCleanupBlockNumberManager is IICleanupBlockNumberManager {
    //solhint-disable-next-line no-unused-vars
    function setCleanUpBlockNumber(uint256 _cleanupBlock) external pure {
        revert("error123");
    }
}