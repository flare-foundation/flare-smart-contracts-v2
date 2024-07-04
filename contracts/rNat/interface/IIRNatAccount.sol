// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;


import "../../userInterfaces/IRNatAccount.sol";
import "../../protocol/interface/IIClaimSetupManager.sol";

interface IIRNatAccount is IRNatAccount {

    /**
     * Initialization of a new deployed contract.
     * @param _owner contract owner address
     * @param _rNat contract rNat address
     */
    function initialize(address _owner, IRNat _rNat) external;

    /**
     * Allows the owner to transfer `WNat` wrapped tokens from this contract to the owner account.
     * In case there are some self-destruct native tokens left on the contract,
     * they can be transferred to the owner account using this method and `_wrap = false`.
     * @param _wNat The `WNat` contract.
     * @param _firstMonthStartTs The start timestamp of the first month.
     * @param _amount Amount of tokens to transfer, in wei.
     * @param _wrap If `true`, the tokens will be sent wrapped in `WNat`. If `false`, they will be sent as `Nat`.
     */
    function withdraw(IWNat _wNat, uint256 _firstMonthStartTs, uint128 _amount, bool _wrap) external returns(uint128);

    /**
     * Allows the owner to transfer `WNat` wrapped tokens from this contact to the owner account.
     * In case there are some self-destruct native tokens left on the contract,
     * they can be transferred to the owner account using this method and `_wrap = false`.
     * @param _wNat The `WNat` contract.
     * @param _firstMonthStartTs The start timestamp of the first month.
     * @param _wrap If `true`, the tokens will be sent wrapped in `WNat`. If `false`, they will be sent as `Nat`.
     */
    function withdrawAll(IWNat _wNat, uint256 _firstMonthStartTs, bool _wrap) external returns(uint128);

    /**
     * Sets the addresses of executors and adds the owner as an executor.
     *
     * If any of the executors is a registered executor, some fee needs to be paid.
     * @param _claimSetupManager The `ClaimSetupManager` contract.
     * @param _executors The new executors. All old executors will be deleted and replaced by these.
     */
    function setClaimExecutors(IIClaimSetupManager _claimSetupManager, address[] memory _executors) external payable;

    /**
     * Receives rewards from the `RNat` contract and wraps them on `WNat` contract.
     * @param _wNat The `WNat` contract.
     * @param _months The months for which the rewards are being received.
     * @param _amounts The amounts of rewards being received.
     */
    function receiveRewards(IWNat _wNat, uint256[] memory _months, uint256[] memory _amounts) external payable;

    /**
     * Allows the owner to transfer ERC-20 tokens from this contact to the owner account.
     *
     * The main use case is to move ERC-20 tokes received by mistake (by an airdrop, for example) out of the
     * RNat account and move them into the main account, where they can be more easily managed.
     *
     * Reverts if the target token is the `WNat` contract: use method `withdraw` or `withdrawAll` for that.
          * @param _wNat The `WNat` contract.
     * @param _token Target token contract address.
     * @param _amount Amount of tokens to transfer.
     */
    function transferExternalToken(IWNat _wNat, IERC20 _token, uint256 _amount) external;

    /**
     * Returns the balance of the `RNat` tokens held by this contract.
     */
    function rNatBalance() external view returns(uint256);

    /**
     * Returns the balance of the `WNat` tokens held by this contract. It is a sum of the `RNat` balance and the
     * additionally wrapped tokens.
     */
    function wNatBalance(IWNat _wNat) external view returns(uint256);

    /**
     * Returns the vested/locked balance of the `RNat` tokens held by this contract.
     */
    function lockedBalance(uint256 _firstMonthStartTs) external view returns(uint256);
}
