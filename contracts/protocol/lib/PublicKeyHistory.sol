// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title PublicKeyHistory library
 * A contract to manage checkpoints as of a given block.
 * @dev Store value history by block number with detachable state.
 **/
library PublicKeyHistory {

    /**
     * @dev `CheckPoint` is the structure that attaches a block number to a
     *  given address; the block number attached is the one that last changed the
     *  address
     **/
    struct CheckPoint {
        // the first part of public key
        bytes32 part1;
        // the second part of public key
        bytes32 part2;
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
     * Changes the public key at the current block.
     * @param _self A CheckPointHistoryState instance to manage.
     * @param _part1 first part of public key
     * @param _part2 second part of public key
     **/
    function setPublicKey(
        CheckPointHistoryState storage _self,
        bytes32 _part1,
        bytes32 _part2
    )
        internal
    {
        uint256 historyCount = _self.endIndex;
        if (historyCount == 0) {
            // checkpoints array empty, push new CheckPoint
            if (_part1 != bytes32(0) && _part2 != bytes32(0)) {
                _self.checkpoints[0] = CheckPoint(_part1, _part2, SafeCast.toUint64(block.number));
                _self.endIndex = 1;
            }
        } else {
            // historyCount - 1 is safe, since historyCount != 0
            CheckPoint storage lastCheckpoint = _self.checkpoints[historyCount - 1];
            uint256 lastBlock = lastCheckpoint.fromBlock;
            // slither-disable-next-line incorrect-equality
            if (block.number == lastBlock) {
                // If last check point is the current block, just update
                lastCheckpoint.part1 = _part1;
                lastCheckpoint.part2 = _part2;
            } else {
                // we should never have future blocks in history
                assert(block.number > lastBlock);
                // last check point block is before, push new CheckPoint
                _self.checkpoints[historyCount] = CheckPoint(_part1, _part2, SafeCast.toUint64(block.number));
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
     * Get public key at a time.
     * @param _self A CheckPointHistoryState instance to manage.
     * @param _blockNumber The block number to query.
     * @return First and second part of public key.
     **/
    function publicKeyAt(
        CheckPointHistoryState storage _self,
        uint256 _blockNumber
    )
        internal view
        returns (
            bytes32,
            bytes32
        )
    {
        uint256 historyCount = _self.endIndex;

        // No _checkpoints, return (bytes32(0), bytes32(0))
        if (historyCount == 0) return (bytes32(0), bytes32(0));

        // Shortcut for the actual account (extra optimized for current block, to save one storage read)
        // historyCount - 1 is safe, since historyCount != 0
        if (_blockNumber >= block.number || _blockNumber >= _self.checkpoints[historyCount - 1].fromBlock) {
            return (_self.checkpoints[historyCount - 1].part1, _self.checkpoints[historyCount - 1].part2);
        }

        // guard values at start
        uint256 startIndex = _self.startIndex;
        if (_blockNumber < _self.checkpoints[startIndex].fromBlock) {
            // reading data before `startIndex` is only safe before first cleanup
            require(startIndex == 0, "PublicKeyHistory: reading from cleaned-up block");
            return (bytes32(0), bytes32(0));
        }

        // Find the block with number less than or equal to block given
        uint256 index = _indexOfGreatestBlockLessThan(_self.checkpoints, startIndex, _self.endIndex, _blockNumber);

        return (_self.checkpoints[index].part1, _self.checkpoints[index].part2);
    }

    /**
     * Get current public key.
     * @param _self A CheckPointHistoryState instance to manage.
     * @return First and second part of public key.
     **/
    function publicKeyAtNow(
        CheckPointHistoryState storage _self
    )
        internal view
        returns (
            bytes32,
            bytes32
        )
    {
        uint256 historyCount = _self.endIndex;
        // No _checkpoints, return address(0)
        if (historyCount == 0) return (bytes32(0), bytes32(0));
        // Return last value
        return (_self.checkpoints[historyCount - 1].part1, _self.checkpoints[historyCount - 1].part2);
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
