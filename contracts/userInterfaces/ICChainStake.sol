// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./ICChainVotePower.sol";


/**
 * Interface for the `CChainStake` contract.
 */
interface ICChainStake is ICChainVotePower {

    /**
     * Total amount of tokens at current block.
     * @return The current total amount of tokens.
     **/
    function totalSupply() external view returns (uint256);

    /**
     * Total amount of tokens at a specific `_blockNumber`.
     * @param _blockNumber The block number when the totalSupply is queried.
     * @return The total amount of tokens at `_blockNumber`.
     **/
    function totalSupplyAt(uint256 _blockNumber) external view returns(uint256);

    /**
     * Queries the token balance of `_owner` at current block.
     * @param _owner The address from which the balance will be retrieved.
     * @return The current balance.
     **/
    function balanceOf(address _owner) external view returns (uint256);

    /**
     * Queries the token balance of `_owner` at a specific `_blockNumber`.
     * @param _owner The address from which the balance will be retrieved.
     * @param _blockNumber The block number when the balance is queried.
     * @return The balance at `_blockNumber`.
     **/
    function balanceOfAt(address _owner, uint256 _blockNumber) external view returns (uint256);
}
