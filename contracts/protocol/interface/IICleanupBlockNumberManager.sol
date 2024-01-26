// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;


/**
 * Interface of token history cleanup manager.
 *
 * Maintains the list of cleanable tokens for which history cleanup can be collectively executed.
 */
interface IICleanupBlockNumberManager {

    /**
     * Sets clean up block number on managed cleanable tokens.
     * @param _blockNumber cleanup block number
     */
    function setCleanUpBlockNumber(uint256 _blockNumber) external;
}
