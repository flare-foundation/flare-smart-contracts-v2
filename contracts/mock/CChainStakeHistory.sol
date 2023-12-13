// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import { Math, SafeMath, SafeCast, SafePct } from "../../flattened/FlareSmartContracts.sol";

/**
 * CChainStakeHistory library
 * A contract to manage checkpoints as of a given block.
 * Store value history by block number with detachable state.
 **/
library CChainStakeHistory {
    using SafeMath for uint256;
    using SafePct for uint256;
    using SafeCast for uint256;

    /**
     * Structure describing stake parameters.
     */
    struct Stake {
        uint256 value;
        address account;

        // stakes[0] will also hold length and blockNumber to save 1 slot of storage per checkpoint
        // for all other indexes these fields will be 0
        // also, when checkpoint is empty, `length` will automatically be 0, which is ok
        uint64 fromBlock;
        uint8 length;       // length is limited to MAX_ACCOUNTS which fits in 8 bits
    }

    /**
     * `CheckPoint` is the structure that attaches a block number to a
     * given value; the block number attached is the one that last changed the value
     **/
    struct CheckPoint {
        // the list of stakes at the time
        mapping(uint256 => Stake) stakes;
    }

    /**
     * Structure for saving checkpoints per address.
     */
    struct CheckPointHistoryState {
        // `checkpoints` is an array that tracks stakes at non-contiguous block numbers
        mapping(uint256 => CheckPoint) checkpoints;
        // `checkpoints` before `startIndex` have been deleted
        // INVARIANT: checkpoints.length == 0 || startIndex < checkpoints.length      (strict!)
        uint64 startIndex;
        uint64 length;
    }

    /// Number of max staking accounts per address
    uint256 public constant MAX_ACCOUNTS = 3;
    string private constant MAX_ACCOUNTS_MSG = "Max accounts exceeded";

    /**
     * Writes the value at the current block.
     * @param _self A CheckPointHistoryState instance to manage.
     * @param _account The account to update.
     * @param _value The new value to set for this stake (value `0` deletes `_account` from the list).
     **/
    function writeValue(
        CheckPointHistoryState storage _self,
        address _account,
        uint256 _value
    )
        internal
    {
        uint256 historyCount = _self.length;
        if (historyCount == 0) {
            // checkpoints array empty, push new CheckPoint
            if (_value != 0) {
                CheckPoint storage cp = _self.checkpoints[historyCount];
                _self.length = SafeCast.toUint64(historyCount + 1);
                cp.stakes[0] = Stake({
                    account: _account,
                    value: _value,
                    fromBlock:  block.number.toUint64(),
                    length: 1
                });
            }
        } else {
            // historyCount - 1 is safe, since historyCount != 0
            CheckPoint storage lastCheckpoint = _self.checkpoints[historyCount - 1];
            uint256 lastBlock = lastCheckpoint.stakes[0].fromBlock;
            // slither-disable-next-line incorrect-equality
            if (block.number == lastBlock) {
                // If last check point is the current block, just update
                _updateStakes(lastCheckpoint, _account, _value);
            } else {
                // we should never have future blocks in history
                assert(block.number > lastBlock);
                // last check point block is before
                CheckPoint storage cp = _self.checkpoints[historyCount];
                _self.length = SafeCast.toUint64(historyCount + 1);
                _copyAndUpdateStakes(cp, lastCheckpoint, _account, _value);
                cp.stakes[0].fromBlock = block.number.toUint64();
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
        uint256 endIndex = Math.min(startIndex.add(_count), length - 1);    // last element can never be deleted
        uint256 index = startIndex;
        // we can delete `checkpoint[index]` while the next checkpoint is at `_cleanupBlockNumber` or before
        while (index < endIndex && _self.checkpoints[index + 1].stakes[0].fromBlock <= _cleanupBlockNumber) {
            CheckPoint storage cp = _self.checkpoints[index];
            uint256 cplength = cp.stakes[0].length;
            for (uint256 i = 0; i < cplength; i++) {
                delete cp.stakes[i];
            }
            index++;
        }
        if (index > startIndex) {   // index is the first not deleted index
            _self.startIndex = SafeCast.toUint64(index);
        }
        return index - startIndex;  // safe: index = startIndex at start and increases in loop
    }

    /**
     * Queries the value at a specific `_blockNumber`
     * @param _self A CheckPointHistoryState instance to manage.
     * @param _account The account for which we need value.
     * @param _blockNumber The block number of the value active at that time
     * @return _value The value of the `_account` at `_blockNumber`
     **/
    function valueOfAt(
        CheckPointHistoryState storage _self,
        address _account,
        uint256 _blockNumber
    )
        internal view
        returns (uint256 _value)
    {
        (bool found, uint256 index) = _findGreatestBlockLessThan(_self, _blockNumber);
        if (!found) return 0;
        return _getValueForAccount(_self.checkpoints[index], _account);
    }

    /**
     * Queries the value at `block.number`
     * @param _self A CheckPointHistoryState instance to manage.
     * @param _account The account for which we need value.
     * @return _value The value at `block.number`
     **/
    function valueOfAtNow(
        CheckPointHistoryState storage _self,
        address _account
    )
        internal view
        returns (uint256 _value)
    {
        uint256 length = _self.length;
        if (length == 0) return 0;
        return _getValueForAccount(_self.checkpoints[length - 1], _account);
    }

    /**
     * Get all account stakes active at a time.
     * @param _self A CheckPointHistoryState instance to manage.
     * @param _blockNumber The block number to query.
     * @return _accounts The active accounts at the time.
     * @return _values The accounts' values at the time.
     **/
    function stakesAt(
        CheckPointHistoryState storage _self,
        uint256 _blockNumber
    )
        internal view
        returns (
            address[] memory _accounts,
            uint256[] memory _values
        )
    {
        (bool found, uint256 index) = _findGreatestBlockLessThan(_self, _blockNumber);
        if (!found) {
            return (new address[](0), new uint256[](0));
        }

        // copy stakes and values to memory arrays
        // (to prevent caller updating the stored value)
        CheckPoint storage cp = _self.checkpoints[index];
        uint256 length = cp.stakes[0].length;
        _accounts = new address[](length);
        _values = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            Stake storage stake = cp.stakes[i];
            _accounts[i] = stake.account;
            _values[i] = stake.value;
        }
    }

    /**
     * Get all account stakes active now.
     * @param _self A CheckPointHistoryState instance to manage.
     * @return _accounts The active accounts stakes.
     * @return _values The stakes' values.
     **/
    function stakesAtNow(
        CheckPointHistoryState storage _self
    )
        internal view
        returns (address[] memory _accounts, uint256[] memory _values)
    {
        return stakesAt(_self, block.number);
    }

    /////////////////////////////////////////////////////////////////////////////////
    // helper functions for writeValueAt

    function _copyAndUpdateStakes(
        CheckPoint storage _cp,
        CheckPoint storage _orig,
        address _account,
        uint256 _value
    )
        private
    {
        uint256 length = _orig.stakes[0].length;
        bool updated = false;
        uint256 newlength = 0;
        for (uint256 i = 0; i < length; i++) {
            Stake memory origStake = _orig.stakes[i];
            if (origStake.account == _account) {
                // copy account, but with new value
                newlength = _appendStake(_cp, origStake.account, _value, newlength);
                updated = true;
            } else {
                // just copy the stake with original value
                newlength = _appendStake(_cp, origStake.account, origStake.value, newlength);
            }
        }
        if (!updated) {
            // _account is not in the original list, so add it
            newlength = _appendStake(_cp, _account, _value, newlength);
        }
        // safe - newlength <= length + 1 <= MAX_ACCOUNTS
        _cp.stakes[0].length = uint8(newlength);
    }

    function _updateStakes(CheckPoint storage _cp, address _account, uint256 _value) private {
        uint256 length = _cp.stakes[0].length;
        uint256 i = 0;
        while (i < length && _cp.stakes[i].account != _account) ++i;
        if (i < length) {
            if (_value != 0) {
                _cp.stakes[i].value = _value;
            } else {
                _deleteStake(_cp, i, length - 1);  // length - 1 is safe:  0 <= i < length
                _cp.stakes[0].length = uint8(length - 1);
            }
        } else {
            uint256 newlength = _appendStake(_cp, _account, _value, length);
            _cp.stakes[0].length = uint8(newlength);  // safe - length <= MAX_ACCOUNTS
        }
    }

    function _appendStake(CheckPoint storage _cp, address _account, uint256 _value, uint256 _length)
        private
        returns (uint256)
    {
        if (_value != 0) {
            require(_length < MAX_ACCOUNTS, MAX_ACCOUNTS_MSG);
            Stake storage stake = _cp.stakes[_length];
            stake.account = _account;
            stake.value = _value;
            // for stakes[0], fromBlock and length are assigned outside
            return _length + 1;
        }
        return _length;
    }

    function _deleteStake(CheckPoint storage _cp, uint256 _index, uint256 _last) private {
        Stake storage stake = _cp.stakes[_index];
        Stake storage lastStake = _cp.stakes[_last];
        if (_index < _last) {
            stake.account = lastStake.account;
            stake.value = lastStake.value;
        }
        lastStake.account = address(0);
        lastStake.value = 0;
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
        uint256 max = _endIndex.sub(1);
        while (max > min) {
            uint256 mid = (max.add(min).add(1)).div(2);
            if (_checkpoints[mid].stakes[0].fromBlock <= _blockNumber) {
                min = mid;
            } else {
                max = mid.sub(1);
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
        uint256 startIndex = _self.startIndex;
        uint256 historyCount = _self.length;
        if (historyCount == 0) {
            _found = false;
        } else if (_blockNumber >= _self.checkpoints[historyCount - 1].stakes[0].fromBlock) {
            _found = true;
            _index = historyCount - 1;  // safe, historyCount != 0 in this branch
        } else if (_blockNumber < _self.checkpoints[startIndex].stakes[0].fromBlock) {
            // reading data before `_startIndex` is only safe before first cleanup
            assert(startIndex == 0);
            _found = false;
        } else {
            _found = true;
            _index = _binarySearchGreatestBlockLessThan(_self.checkpoints, startIndex, historyCount, _blockNumber);
        }
    }

    /**
     * Find stake and return its value or 0 if not found.
     */
    function _getValueForAccount(CheckPoint storage _cp, address _account) private view returns (uint256) {
        uint256 length = _cp.stakes[0].length;
        for (uint256 i = 0; i < length; i++) {
            Stake storage stake = _cp.stakes[i];
            if (stake.account == _account) {
                return stake.value;
            }
        }
        return 0;   // _account not found
    }
}
