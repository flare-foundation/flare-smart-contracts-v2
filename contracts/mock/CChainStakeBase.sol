// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "../userInterfaces/ICChainVotePower.sol";
import "./CChainStakeHistory.sol";
import { CheckPointable, VotePower, VotePowerCache, SafePct, SafeMath } from "../../flattened/FlareSmartContracts.sol";


/**
 * Helper contract handling all the vote power and balance functionality for the CChainStake.
 */
contract CChainStakeBase is ICChainVotePower, CheckPointable {
    using CChainStakeHistory for CChainStakeHistory.CheckPointHistoryState;
    using SafeMath for uint256;
    using SafePct for uint256;
    using VotePower for VotePower.VotePowerState;
    using VotePowerCache for VotePowerCache.CacheState;

    // The number of history cleanup steps executed for every write operation.
    // It is more than 1 to make as certain as possible that all history gets cleaned eventually.
    uint256 private constant CHECKPOINTS_CLEANUP_COUNT = 2;

    mapping(address => CChainStakeHistory.CheckPointHistoryState) private stakes;

    // `votePower` tracks all vote power balances
    VotePower.VotePowerState private votePower;

    // `votePowerCache` tracks all cached vote power balances
    VotePowerCache.CacheState private votePowerCache;

    // history cleanup methods

    /**
     * Delete vote power checkpoints that expired (i.e. are before `cleanupBlockNumber`).
     * Method can only be called from the `cleanerContract` (which may be a proxy to external cleaners).
     * @param _account vote power account
     * @param _count maximum number of checkpoints to delete
     * @return the number of checkpoints deleted
     */
    function votePowerHistoryCleanup(address _account, uint256 _count) external onlyCleaner returns (uint256) {
        return votePower.cleanupOldCheckpoints(_account, _count, _cleanupBlockNumber());
    }

    /**
     * Delete vote power cache entry that expired (i.e. is before `cleanupBlockNumber`).
     * Method can only be called from the `cleanerContract` (which may be a proxy to external cleaners).
     * @param _account vote power account
     * @param _blockNumber the block number for which total supply value was cached
     * @return the number of cache entries deleted (always 0 or 1)
     */
    function votePowerCacheCleanup(address _account, uint256 _blockNumber) external onlyCleaner returns (uint256) {
        require(_blockNumber < _cleanupBlockNumber(), "No cleanup after cleanup block");
        return votePowerCache.deleteValueAt(_account, _blockNumber);
    }

    /**
     * Delete stakes checkpoints that expired (i.e. are before `cleanupBlockNumber`).
     * Method can only be called from the `cleanerContract` (which may be a proxy to external cleaners).
     * @param _owner Balance owner account address.
     * @param _count Maximum number of checkpoints to delete.
     * @return Number of deleted checkpoints.
     */
    function stakesHistoryCleanup(address _owner, uint256 _count) external onlyCleaner returns (uint256) {
        return stakes[_owner].cleanupOldCheckpoints(_count, _cleanupBlockNumber());
    }

    /**
     * @inheritdoc ICChainVotePower
     */
    function totalVotePowerAtCached(uint256 _blockNumber) external override returns(uint256) {
        return _totalSupplyAtCached(_blockNumber);
    }

    /**
     * @inheritdoc ICChainVotePower
     */
    function votePowerOfAtCached(
        address _account,
        uint256 _blockNumber
    )
        external override
        notBeforeCleanupBlock(_blockNumber)
        returns(uint256)
    {
        require(_blockNumber < block.number, "Can only be used for past blocks");
        (uint256 vp, bool createdCache) = votePowerCache.valueOfAt(votePower, _account, _blockNumber);
        if (createdCache) emit VotePowerCacheCreated(_account, _blockNumber);
        return vp;
    }

    /**
     * @inheritdoc ICChainVotePower
     */
    function totalVotePower() external view override returns(uint256) {
        return totalSupplyAt(block.number);
    }

    /**
     * @inheritdoc ICChainVotePower
     */
    function totalVotePowerAt(uint256 _blockNumber) external view override returns(uint256) {
        return totalSupplyAt(_blockNumber);
    }

    /**
     * @inheritdoc ICChainVotePower
     */
    function stakesOf(address _owner)
        external view override
        returns (
            address[] memory _accounts,
            uint256[] memory _amounts
        )
    {
        return stakes[_owner].stakesAtNow();
    }

    /**
     * @inheritdoc ICChainVotePower
     */
    function stakesOfAt(
        address _owner,
        uint256 _blockNumber
    )
        external view override
        notBeforeCleanupBlock(_blockNumber)
        returns (
            address[] memory _accounts,
            uint256[] memory _amounts
        )
    {
        return stakes[_owner].stakesAt(_blockNumber);
    }

    /**
     * @inheritdoc ICChainVotePower
     */
    function votePowerFromTo(
        address _owner,
        address _account
    )
        external view override
        returns(uint256 _votePower)
    {
        return stakes[_owner].valueOfAtNow(_account);
    }

    /**
     * @inheritdoc ICChainVotePower
     */
    function votePowerFromToAt(
        address _owner,
        address _account,
        uint256 _blockNumber
    )
        external view override
        notBeforeCleanupBlock(_blockNumber)
        returns(uint256 _votePower)
    {
        return stakes[_owner].valueOfAt(_account, _blockNumber);
    }

    /**
     * @inheritdoc ICChainVotePower
     */
    function votePowerOf(address _account) external view override returns(uint256) {
        return votePower.votePowerOfAtNow(_account);
    }

    /**
     * @inheritdoc ICChainVotePower
     */
    function votePowerOfAt(
        address _account,
        uint256 _blockNumber
    )
        external view override
        notBeforeCleanupBlock(_blockNumber)
        returns(uint256)
    {
        // read cached value for past blocks (and possibly get a cache speedup)
        if (_blockNumber < block.number) {
            return votePowerCache.valueOfAtReadonly(votePower, _account, _blockNumber);
        } else {
            return votePower.votePowerOfAtNow(_account);
        }
    }

    /**
     * @inheritdoc ICChainVotePower
     */
    function batchVotePowerOfAt(
        address[] memory _owners,
        uint256 _blockNumber
    )
        external view override
        notBeforeCleanupBlock(_blockNumber)
        returns(uint256[] memory _votePowers)
    {
        require(_blockNumber < block.number, "Can only be used for past blocks");
        _votePowers = new uint256[](_owners.length);
        for (uint256 i = 0; i < _owners.length; i++) {
            // read through cache, much faster if it has been set
            _votePowers[i] = votePowerCache.valueOfAtReadonly(votePower, _owners[i], _blockNumber);
        }
    }

    /**
     * Increase vote power by `_amount` for `_account` from `_owner`
     * @param _owner The address of the owner
     * @param _account The account of the recipient
     * @param _amount The increasing amount of vote power
     **/
    function _increaseVotePower(
        address _owner,
        address _account,
        uint256 _amount
    )
        internal virtual
    {
        require(_account != address(0), "Cannot stake to zero");
        votePower.changeValue(_account, _amount, 0);
        votePower.cleanupOldCheckpoints(_account, CHECKPOINTS_CLEANUP_COUNT, _cleanupBlockNumber());

        // Get the vote power of the sender
        CChainStakeHistory.CheckPointHistoryState storage ownerStake = stakes[_owner];

        // the amounts
        uint256 priorAmount = ownerStake.valueOfAtNow(_account);
        uint256 newAmount = priorAmount.add(_amount);

        // Add/replace stake
        ownerStake.writeValue(_account, newAmount);
        ownerStake.cleanupOldCheckpoints(CHECKPOINTS_CLEANUP_COUNT, _cleanupBlockNumber());

        // emit event for stake change
        emit VotePowerChanged(_owner, _account, priorAmount, newAmount);
    }

    /**
     * Decrease vote power by `_amount` for `_account` from `_owner`
     * @param _owner The address of the owner
     * @param _account The account of the recipient
     * @param _amount The decreasing amount of vote power
     **/
    function _decreaseVotePower(
        address _owner,
        address _account,
        uint256 _amount
    )
        internal virtual
    {
        require(_account != address(0), "Cannot stake to zero");
        votePower.changeValue(_account, 0, _amount);
        votePower.cleanupOldCheckpoints(_account, CHECKPOINTS_CLEANUP_COUNT, _cleanupBlockNumber());

        // Get the vote power of the sender
        CChainStakeHistory.CheckPointHistoryState storage ownerStake = stakes[_owner];

        // the amounts
        uint256 priorAmount = ownerStake.valueOfAtNow(_account);
        uint256 newAmount = priorAmount.sub(_amount);

        // Add/replace stake
        ownerStake.writeValue(_account, newAmount);
        ownerStake.cleanupOldCheckpoints(CHECKPOINTS_CLEANUP_COUNT, _cleanupBlockNumber());

        // emit event for stake change
        emit VotePowerChanged(_owner, _account, priorAmount, newAmount);
    }
}
