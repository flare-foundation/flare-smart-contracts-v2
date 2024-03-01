// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * Interface for the vote power part of the `CChainStakeMirror` contract.
 */
interface ICChainVotePower {

    /**
     * Event triggered when a stake is confirmed or at the time it ends.
     * Definition: `votePowerFromTo(owner, account)` is `changed` from `priorVotePower` to `newVotePower`.
     * @param owner The account that has changed the amount of vote power it is staking.
     * @param account The account whose received vote power has changed.
     * @param priorVotePower The vote power originally on that account.
     * @param newVotePower The new vote power that triggered this event.
     */
    event VotePowerChanged(
        address indexed owner,
        address indexed account,
        uint256 priorVotePower,
        uint256 newVotePower
    );

    /**
     * Emitted when a vote power cache entry is created.
     * Allows history cleaners to track vote power cache cleanup opportunities off-chain.
     * @param account The account whose vote power has just been cached.
     * @param blockNumber The block number at which the vote power has been cached.
     */
    event VotePowerCacheCreated(address account, uint256 blockNumber);

    /**
    * Get the vote power of `_owner` at block `_blockNumber` using cache.
    *   It tries to read the cached value and if not found, reads the actual value and stores it in cache.
    *   Can only be used if _blockNumber is in the past, otherwise reverts.
    * @param _owner The account to get voting power.
    * @param _blockNumber The block number at which to fetch.
    * @return Vote power of `_owner` at `_blockNumber`.
    */
    function votePowerOfAtCached(address _owner, uint256 _blockNumber) external returns(uint256);

    /**
    * Get the total vote power at block `_blockNumber` using cache.
    *   It tries to read the cached value and if not found, reads the actual value and stores it in cache.
    *   Can only be used if `_blockNumber` is in the past, otherwise reverts.
    * @param _blockNumber The block number at which to fetch.
    * @return The total vote power at the block (sum of all accounts' vote powers).
    */
    function totalVotePowerAtCached(uint256 _blockNumber) external returns(uint256);

    /**
     * Get the current total vote power.
     * @return The current total vote power (sum of all accounts' vote powers).
     */
    function totalVotePower() external view returns(uint256);

    /**
    * Get the total vote power at block `_blockNumber`
    * @param _blockNumber The block number at which to fetch.
    * @return The total vote power at the block  (sum of all accounts' vote powers).
    */
    function totalVotePowerAt(uint256 _blockNumber) external view returns(uint256);

    /**
     * Get the amounts and accounts being staked to by a vote power owner.
     * @param _owner The address being queried.
     * @return _accounts Array of accounts.
     * @return _amounts Array of staked amounts, for each account.
     */
    function stakesOf(address _owner)
        external view
        returns (
            address[] memory _accounts,
            uint256[] memory _amounts
        );

    /**
     * Get the amounts and accounts being staked to by a vote power owner,
     * at a given block.
     * @param _owner The address being queried.
     * @param _blockNumber The block number being queried.
     * @return _accounts Array of accounts.
     * @return _amounts Array of staked amounts, for each account.
     */
    function stakesOfAt(
        address _owner,
        uint256 _blockNumber
    )
        external view
        returns (
            address[] memory _accounts,
            uint256[] memory _amounts
        );

    /**
     * Get the current vote power of `_account`.
     * @param _account The account to get voting power.
     * @return Current vote power of `_account`.
     */
    function votePowerOf(address _account) external view returns(uint256);

    /**
    * Get the vote power of `_account` at block `_blockNumber`
    * @param _account The account to get voting power.
    * @param _blockNumber The block number at which to fetch.
    * @return Vote power of `_account` at `_blockNumber`.
    */
    function votePowerOfAt(address _account, uint256 _blockNumber) external view returns(uint256);

    /**
    * Get current staked vote power from `_owner` staked to `_account`.
    * @param _owner Address of vote power owner.
    * @param _account Account.
    * @return The staked vote power.
    */
    function votePowerFromTo(address _owner, address _account) external view returns(uint256);

    /**
    * Get current staked vote power from `_owner` staked to `_account` at `_blockNumber`.
    * @param _owner Address of vote power owner.
    * @param _account Account.
    * @param _blockNumber The block number at which to fetch.
    * @return The staked vote power.
    */
    function votePowerFromToAt(address _owner, address _account, uint256 _blockNumber) external view returns(uint256);

    /**
     * Return vote powers for several accounts in a batch.
     * @param _accounts The list of accounts to fetch vote power of.
     * @param _blockNumber The block number at which to fetch.
     * @return A list of vote powers.
     */
    function batchVotePowerOfAt(
        address[] memory _accounts,
        uint256 _blockNumber
    ) external view returns(uint256[] memory);
}
