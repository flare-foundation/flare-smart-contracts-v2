// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title AddressHistory library
 * A contract to manage checkpoints as of a given block.
 * @dev Store value history by block number with detachable state.
 **/
library AddressHistory {

    /**
     * @dev `CheckPoint` is the structure that attaches a block number to a
     *  given address; the block number attached is the one that last changed the
     *  address
     **/
    struct CheckPoint {
        // `account` is the address at a specific block number
        address account;
        // `fromBlock` is the block number that the address was set from
        uint64 fromBlock;
    }

    struct CheckPointHistoryState {
        // `checkpoints` is an array that tracks delegations at non-contiguous block numbers
        mapping(uint256 => CheckPoint) checkpoints;
        // `checkpoints` before `startIndex` have been deleted
        // INVARIANT: checkpoints.endIndex == 0 || startIndex < checkpoints.endIndex      (strict!)
        // startIndex and endIndex are both less then fromBlock, so 64 bits is enough
        uint64 startIndex;
        // the index AFTER last
        uint64 endIndex;
    }

    /**
     * Changes the address at the current block.
     * @param _self A CheckPointHistoryState instance to manage.
     * @param _account The address to change.
     **/
    function setAddress(
        CheckPointHistoryState storage _self,
        address _account
    )
        internal
    {
        uint256 historyCount = _self.endIndex;
        if (historyCount == 0) {
            // checkpoints array empty, push new CheckPoint
            if (_account != address(0)) {
                _self.checkpoints[0] = CheckPoint(_account, SafeCast.toUint64(block.number));
                _self.endIndex = 1;
            }
        } else {
            // historyCount - 1 is safe, since historyCount != 0
            CheckPoint storage lastCheckpoint = _self.checkpoints[historyCount - 1];
            uint256 lastBlock = lastCheckpoint.fromBlock;
            // slither-disable-next-line incorrect-equality
            if (block.number == lastBlock) {
                // If last check point is the current block, just update
                lastCheckpoint.account = _account;
            } else {
                // we should never have future blocks in history
                assert(block.number > lastBlock);
                // last check point block is before, push new CheckPoint
                _self.checkpoints[historyCount] = CheckPoint(_account, SafeCast.toUint64(block.number));
                _self.endIndex = SafeCast.toUint64(historyCount + 1);  // historyCount <= block.number
            }
        }
    }

    /**
     * Delete at most `_count` of the oldest checkpoints.
     * At least one checkpoint at or before `_cleanupBlockNumber` will remain
     * (unless the history was empty to start with).
     */
    function cleanupOldCheckpoints(
        CheckPointHistoryState storage _self,
        uint256 _count,
        uint256 _cleanupBlockNumber
    )
        internal
        returns (uint256)
    {
        if (_cleanupBlockNumber == 0) return 0;   // optimization for when cleaning is not enabled
        uint256 length = _self.endIndex;
        if (length == 0) return 0;
        uint256 startIndex = _self.startIndex;
        // length - 1 is safe, since length != 0 (check above)
        uint256 endIndex = Math.min(startIndex + _count, length - 1);    // last element can never be deleted
        uint256 index = startIndex;
        // we can delete `checkpoint[index]` while the next checkpoint is at `_cleanupBlockNumber` or before
        while (index < endIndex && _self.checkpoints[index + 1].fromBlock <= _cleanupBlockNumber) {
            delete _self.checkpoints[index];
            index++;
        }
        if (index > startIndex) {   // index is the first not deleted index
            _self.startIndex = SafeCast.toUint64(index);
        }
        return index - startIndex;  // safe: index = startIndex at start and increases in loop
    }

    /**
     * Get address at a time.
     * @param _self A CheckPointHistoryState instance to manage.
     * @param _blockNumber The block number to query.
     * @return The active address at the time.
     **/
    function addressAt(
        CheckPointHistoryState storage _self,
        uint256 _blockNumber
    )
        internal view
        returns (
            address
        )
    {
        uint256 historyCount = _self.endIndex;

        // No _checkpoints, return address(0)
        if (historyCount == 0) return address(0);

        // Shortcut for the actual account (extra optimized for current block, to save one storage read)
        // historyCount - 1 is safe, since historyCount != 0
        if (_blockNumber >= block.number || _blockNumber >= _self.checkpoints[historyCount - 1].fromBlock) {
            return _self.checkpoints[historyCount - 1].account;
        }

        // guard values at start
        uint256 startIndex = _self.startIndex;
        if (_blockNumber < _self.checkpoints[startIndex].fromBlock) {
            // reading data before `startIndex` is only safe before first cleanup
            require(startIndex == 0, "AddressHistory: reading from cleaned-up block");
            return address(0);
        }

        // Find the block with number less than or equal to block given
        uint256 index = _indexOfGreatestBlockLessThan(_self.checkpoints, startIndex, _self.endIndex, _blockNumber);

        return _self.checkpoints[index].account;
    }

    /**
     * Get current address.
     * @param _self A CheckPointHistoryState instance to manage.
     * @return The currently active address.
     **/
    function addressAtNow(
        CheckPointHistoryState storage _self
    )
        internal view
        returns (
            address
        )
    {
        uint256 historyCount = _self.endIndex;
        // No _checkpoints, return address(0)
        if (historyCount == 0) return address(0);
        // Return last value
        return _self.checkpoints[historyCount - 1].account;
    }

    /**
     * Binary search of _checkpoints array.
     * @param _checkpoints An array of CheckPoint to search.
     * @param _startIndex Smallest possible index to be returned.
     * @param _blockNumber The block number to search for.
     */
    function _indexOfGreatestBlockLessThan(
        mapping(uint256 => CheckPoint) storage _checkpoints,
        uint256 _startIndex,
        uint256 _endIndex,
        uint256 _blockNumber
    )
        private view
        returns (uint256 index)
    {
        // Binary search of the value by given block number in the array
        uint256 min = _startIndex;
        uint256 max = _endIndex - 1;
        while (max > min) {
            uint256 mid = (max + min + 1) / 2;
            if (_checkpoints[mid].fromBlock <= _blockNumber) {
                min = mid;
            } else {
                max = mid - 1;
            }
        }
        return min;
    }
}
