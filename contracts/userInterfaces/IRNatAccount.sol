// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./IRNat.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IRNatAccount {

    event FundsWithdrawn(uint256 amount, bool wrap);
    event LockedAmountBurned(uint256 amount);
    event ExternalTokenTransferred(IERC20 token, uint256 amount);
    event Initialized(address owner, IRNat rNat);
    event ClaimExecutorsSet(address[] executors);

    /**
     * Returns the owner of the contract.
     */
    function owner() external view returns (address);

    /**
     * Returns the `RNat` contract.
     */
    function rNat() external view returns (IRNat);

    /**
     * Returns the total amount of rewards received ever.
     */
    function receivedRewards() external view returns (uint128);

    /**
     * Returns the total amount of rewards withdrawn ever.
     */
    function withdrawnRewards() external view returns (uint128);
}
