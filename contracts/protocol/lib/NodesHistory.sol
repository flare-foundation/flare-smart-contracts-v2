// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title NodesHistory library
 * A contract to manage checkpoints as of a given block.
 * @dev Store value history by block number with detachable state.
 **/
library NodesHistory {

    struct Node {
        bytes20 nodeId;
        // nodeIds[0] will also hold length and blockNumber to save 1 slot of storage per checkpoint
        // for all other indexes these fields will be 0
        // also, when checkpoint is empty, `length` will automatically be 0, which is ok
        uint64 fromBlock;
        uint32 length;       // length is limited to MAX_NODES which fits in 32 bits
    }

    /**
     * @dev `CheckPoint` is the structure that attaches a block number to a
     *  given value; the block number attached is the one that last changed the
     *  value
     **/
    struct CheckPoint {
        // the list of nodeIds at the time
        mapping(uint256 => Node) nodeIds;
    }

    struct CheckPointHistoryState {
        // `checkpoints` is an array that tracks nodeIds at non-contiguous block numbers
        mapping(uint256 => CheckPoint) checkpoints;
        // `checkpoints` before `startIndex` have been deleted
        // INVARIANT: checkpoints.length == 0 || startIndex < checkpoints.length      (strict!)
        uint64 startIndex;
        uint64 length;
    }

    string private constant MAX_NODES_MSG = "Max nodes exceeded";

    /**
     * Adds or removes the nodeId at the current block.
     * @param _self A CheckPointHistoryState instance to manage.
     * @param _nodeId The nodeId to update.
     * @param _add Indicates if _nodeId should be added (true) or removed (false)
     **/
    function addRemoveNodeId(
        CheckPointHistoryState storage _self,
        bytes20 _nodeId,
        bool _add,
        uint32 _maxNodeIds
    )
        internal
    {
        uint256 historyCount = _self.length;
        if (historyCount == 0) {
            // checkpoints array empty, push new CheckPoint
            if (_add) {
                CheckPoint storage cp = _self.checkpoints[historyCount];
                _self.length = SafeCast.toUint64(historyCount + 1);
                cp.nodeIds[0] = Node({
                    nodeId: _nodeId,
                    fromBlock:  SafeCast.toUint64(block.number),
                    length: 1
                });
            }
        } else {
            // historyCount - 1 is safe, since historyCount != 0
            CheckPoint storage lastCheckpoint = _self.checkpoints[historyCount - 1];
            uint256 lastBlock = lastCheckpoint.nodeIds[0].fromBlock;
            // slither-disable-next-line incorrect-equality
            if (block.number == lastBlock) {
                // If last check point is the current block, just update
                _updateNodeIds(lastCheckpoint, _nodeId, _add, _maxNodeIds);
            } else {
                // we should never have future blocks in history
                assert(block.number > lastBlock);
                // last check point block is before
                CheckPoint storage cp = _self.checkpoints[historyCount];
                _self.length = SafeCast.toUint64(historyCount + 1);
                _copyAndUpdateNodeIds(cp, lastCheckpoint, _nodeId, _add, _maxNodeIds);
                cp.nodeIds[0].fromBlock = SafeCast.toUint64(block.number);
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
        uint256 length = _self.length;
        if (length == 0) return 0;
        uint256 startIndex = _self.startIndex;
        // length - 1 is safe, since length != 0 (check above)
        uint256 endIndex = Math.min(startIndex + _count, length - 1);    // last element can never be deleted
        uint256 index = startIndex;
        // we can delete `checkpoint[index]` while the next checkpoint is at `_cleanupBlockNumber` or before
        while (index < endIndex && _self.checkpoints[index + 1].nodeIds[0].fromBlock <= _cleanupBlockNumber) {
            CheckPoint storage cp = _self.checkpoints[index];
            uint256 cplength = cp.nodeIds[0].length;
            for (uint256 i = 0; i < cplength; i++) {
                delete cp.nodeIds[i];
            }
            index++;
        }
        if (index > startIndex) {   // index is the first not deleted index
            _self.startIndex = SafeCast.toUint64(index);
        }
        return index - startIndex;  // safe: index = startIndex at start and increases in loop
    }

    /**
     * Get all node ids at a time.
     * @param _self A CheckPointHistoryState instance to manage.
     * @param _blockNumber The block number to query.
     * @return _nodeIds The active nodeIds at the time.
     **/
    function nodeIdsAt(
        CheckPointHistoryState storage _self,
        uint256 _blockNumber
    )
        internal view
        returns (
            bytes20[] memory _nodeIds
        )
    {
        (bool found, uint256 index) = _findGreatestBlockLessThan(_self, _blockNumber);
        if (!found) {
            return new bytes20[](0);
        }

        // copy nodeIds to memory arrays
        // (to prevent caller updating the stored value)
        CheckPoint storage cp = _self.checkpoints[index];
        uint256 length = cp.nodeIds[0].length;
        _nodeIds = new bytes20[](length);
        for (uint256 i = 0; i < length; i++) {
            Node storage dlg = cp.nodeIds[i];
            _nodeIds[i] = dlg.nodeId;
        }
    }

    /////////////////////////////////////////////////////////////////////////////////
    // helper functions for updateNodeIds

    function _copyAndUpdateNodeIds(
        CheckPoint storage _cp,
        CheckPoint storage _orig,
        bytes20 _nodeId,
        bool _add,
        uint256 _maxNodeIds
    )
        private
    {
        uint256 length = _orig.nodeIds[0].length;
        uint256 newlength = 0;
        for (uint256 i = 0; i < length; i++) {
            Node memory origNode = _orig.nodeIds[i];
            if (origNode.nodeId != _nodeId) {
                // copy all other nodeIds
                newlength = _appendNodeId(_cp, origNode.nodeId, newlength, _maxNodeIds);
            }
        }
        if (_add) {
            // add also nodeId
            newlength = _appendNodeId(_cp, _nodeId, newlength, _maxNodeIds);
        }
        // safe - newlength <= length + 1 <= MAX_NODES
        _cp.nodeIds[0].length = SafeCast.toUint32(newlength);
    }

    function _updateNodeIds(CheckPoint storage _cp, bytes20 _nodeId, bool _add, uint256 _maxNodeIds) private {
        uint256 length = _cp.nodeIds[0].length;
        uint256 i = 0;
        while (i < length && _cp.nodeIds[i].nodeId != _nodeId) ++i;
        if (i < length) { // nodeId already exists
            if (!_add) {
                _deleteNodeId(_cp, i, length - 1);  // length - 1 is safe:  0 <= i < length
                _cp.nodeIds[0].length = SafeCast.toUint32(length - 1);
            }
        } else if (_add) {
            uint256 newlength = _appendNodeId(_cp, _nodeId, length, _maxNodeIds);
            _cp.nodeIds[0].length = SafeCast.toUint32(newlength);  // safe - length < MAX_NODES
        }
    }

    function _appendNodeId(CheckPoint storage _cp, bytes20 _nodeId, uint256 _length, uint256 _maxNodeIds)
        private
        returns (uint256)
    {
        require(_length < _maxNodeIds, MAX_NODES_MSG);
        Node storage dlg = _cp.nodeIds[_length];
        dlg.nodeId = _nodeId;
        // for nodeIds[0], fromBlock and length are assigned outside
        return _length + 1;
    }

    function _deleteNodeId(CheckPoint storage _cp, uint256 _index, uint256 _last) private {
        Node storage dlg = _cp.nodeIds[_index];
        Node storage lastDlg = _cp.nodeIds[_last];
        if (_index < _last) {
            dlg.nodeId = lastDlg.nodeId;
        }
        lastDlg.nodeId = bytes20(0);
    }

    /////////////////////////////////////////////////////////////////////////////////
    // helper functions for querying

    /**
     * Binary search of _checkpoints array.
     * @param _checkpoints An array of CheckPoint to search.
     * @param _startIndex Smallest possible index to be returned.
     * @param _blockNumber The block number to search for.
     */
    function _binarySearchGreatestBlockLessThan(
        mapping(uint256 => CheckPoint) storage _checkpoints,
        uint256 _startIndex,
        uint256 _endIndex,
        uint256 _blockNumber
    )
        private view
        returns (uint256 _index)
    {
        // Binary search of the value by given block number in the array
        uint256 min = _startIndex;
        uint256 max = _endIndex - 1;
        while (max > min) {
            uint256 mid = (max + min + 1) / 2;
            if (_checkpoints[mid].nodeIds[0].fromBlock <= _blockNumber) {
                min = mid;
            } else {
                max = mid - 1;
            }
        }
        return min;
    }

    /**
     * Binary search of _checkpoints array. Extra optimized for the common case when we are
     *   searching for the last block.
     * @param _self The state to query.
     * @param _blockNumber The block number to search for.
     * @return _found true if value was found (only `false` if `_blockNumber` is before first
     *   checkpoint or the checkpoint array is empty)
     * @return _index index of the newest block with number less than or equal `_blockNumber`
     */
    function _findGreatestBlockLessThan(
        CheckPointHistoryState storage _self,
        uint256 _blockNumber
    )
        private view
        returns (
            bool _found,
            uint256 _index
        )
    {
        uint256 historyCount = _self.length;
        // No _checkpoints, return (false, 0)
        if (historyCount == 0) {
            return (false, 0);
        }

        // Shortcut for the actual node ids (extra optimized for current block, to save one storage read)
        // historyCount - 1 is safe, since historyCount != 0
        if (_blockNumber >= block.number || _blockNumber >= _self.checkpoints[historyCount - 1].nodeIds[0].fromBlock) {
            return (true, historyCount - 1);
        }

        uint256 startIndex = _self.startIndex;
        if (_blockNumber < _self.checkpoints[startIndex].nodeIds[0].fromBlock) {
            // reading data before `_startIndex` is only safe before first cleanup
            require(startIndex == 0, "NodesHistory: reading from cleaned-up block");
            return (false, 0);
        }

        // Find the block with number less than or equal to block given
        return (true, _binarySearchGreatestBlockLessThan(_self.checkpoints, startIndex, historyCount, _blockNumber));
    }
}
