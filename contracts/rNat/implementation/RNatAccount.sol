// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../interface/IIRNatAccount.sol";
import "../../utils/lib/SafePct.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


/**
 * RNatAccount contract is a personal RNat account contract for a RNat holder.
 * It is used to manage linear vesting (over 12 months) of RNat tokens (rewards) per user.
 * Token sent to this contract will be automatically wrapped into WNat.
 */
contract RNatAccount is IIRNatAccount {
    using SafeERC20 for IERC20;
    using SafePct for uint256;

    address payable constant internal BURN_ADDRESS = payable(0x000000000000000000000000000000000000dEaD);
    uint256 internal constant MONTH = 30 days;

    string internal constant ERR_TRANSFER_FAILURE = "transfer failed";
    string internal constant ERR_RNAT_ONLY = "only rNat";

    /// Contract owner address
    address public owner;
    /// RNat contract address
    IRNat public rNat;
    bool internal disableAutoWrapping;

    mapping(uint256 month => uint256) internal rewards;
    /// Total rewards received
    uint128 public receivedRewards;
    /// Total rewards withdrawn
    uint128 public withdrawnRewards;

    /**
     * Most of the external methods in RNatAccount contract can only be executed through the rNat contract.
     */
    modifier onlyRNat {
        _checkOnlyRNat();
        _;
    }

    /**
     * Receives funds and automatically wraps them on `WNat` contract.
     * @dev Special case needed to allow `WNat.withdraw` to send back funds, since there is no `withdrawTo` method.
     */
    receive() external payable {
        if (!disableAutoWrapping) {
            rNat.wNat().deposit{value: msg.value}();
        }
    }

    /**
     * @inheritdoc IIRNatAccount
     */
    function initialize(
        address _owner,
        IRNat _rNat
    )
        external
    {
        require(address(owner) == address(0), "owner already set");
        require(address(_owner) != address(0), "owner address zero");
        require(address(_rNat) != address(0), "rNat address zero");
        owner = _owner;
        rNat = _rNat;
        emit Initialized(owner, _rNat);
    }

    /**
     * @inheritdoc IIRNatAccount
     */
    function receiveRewards(
        IWNat _wNat,
        uint256[] memory _months,
        uint256[] memory _amounts
    )
        external payable onlyRNat
    {
        assert(_months.length == _amounts.length);
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < _months.length; i++) {
            rewards[_months[i]] += _amounts[i];
            totalAmount += _amounts[i];
        }
        assert(totalAmount == msg.value);
        receivedRewards += uint128(totalAmount);
        _wNat.deposit{value: totalAmount}();
    }

    /**
     * @inheritdoc IIRNatAccount
     */
    function withdraw(
        IWNat _wNat,
        uint256 _firstMonthStartTs,
        uint128 _amount,
        bool _wrap
    )
        external onlyRNat
        returns(uint128 _withdrawnRewards)
    {
        uint128 rNatRewardsBalance = receivedRewards - withdrawnRewards;
        uint128 balance = uint128(_wNat.balanceOf(address(this)));
        assert(balance >= rNatRewardsBalance);
        uint256 locked = _lockedRewards(_firstMonthStartTs);
        require(balance - locked >= _amount, "insufficient balance");
        // withdraw RNat rewards last, only if needed
        _withdrawnRewards = balance - rNatRewardsBalance >= _amount ? 0 : _amount - (balance - rNatRewardsBalance);
        withdrawnRewards += _withdrawnRewards;
        emit FundsWithdrawn(_amount, _wrap);
        if (!_wrap) {
            disableAutoWrapping = true;
            _wNat.withdraw(_amount);
            disableAutoWrapping = false;
            _transferCurrentBalanceToOwner();
        } else {
            bool success = _wNat.transfer(owner, _amount);
            require(success, ERR_TRANSFER_FAILURE);
        }
    }

    /**
     * @inheritdoc IIRNatAccount
     */
    function withdrawAll(
        IWNat _wNat,
        uint256 _firstMonthStartTs,
        bool _wrap
    )
        external onlyRNat
        returns(uint128 _withdrawnRewards)
    {
        uint256 balance = _wNat.balanceOf(address(this));
        uint256 locked = _lockedRewards(_firstMonthStartTs);
        uint256 amount = balance - locked / 2;
        uint256 burnAmount = balance - amount;
        uint256 currentMonth = _getCurrentMonth(_firstMonthStartTs);
        uint256 fromMonth = currentMonth > 11 ? currentMonth - 11 : 0;
        // Reset rewards for the last 12 months
        for (uint256 i = fromMonth; i <= currentMonth; i++) {
            rewards[i] = 0;
        }
        _withdrawnRewards = receivedRewards - withdrawnRewards;
        withdrawnRewards += _withdrawnRewards;
        emit FundsWithdrawn(amount, _wrap);
        disableAutoWrapping = true;
        _wNat.withdraw(_wrap ? burnAmount : balance);
        disableAutoWrapping = false;
        emit LockedAmountBurned(burnAmount);
        BURN_ADDRESS.transfer(burnAmount);

        if (!_wrap) {
            _transferCurrentBalanceToOwner();
        } else {
            bool success = _wNat.transfer(owner, amount);
            require(success, ERR_TRANSFER_FAILURE);
        }
    }

    /**
     * @inheritdoc IIRNatAccount
     */
    function setClaimExecutors(
        IIClaimSetupManager _claimSetupManager,
        address[] memory _executors
    )
        external payable onlyRNat
    {
        bool addOwner = true;
        for (uint256 i = 0; i < _executors.length; i++) {
            if (_executors[i] == owner) {
                addOwner = false;
                break;
            }
        }
        address[] memory executorsWithOwner;
        if (addOwner) {
            executorsWithOwner = new address[](_executors.length + 1);
            for (uint256 i = 0; i < _executors.length; i++) {
                executorsWithOwner[i] = _executors[i];
            }
            executorsWithOwner[_executors.length] = owner;
        } else {
            executorsWithOwner = _executors;
        }
        emit ClaimExecutorsSet(executorsWithOwner);
        disableAutoWrapping = true;
        _claimSetupManager.setClaimExecutors{value: msg.value}(executorsWithOwner);
        disableAutoWrapping = false;
        _transferCurrentBalanceToOwner();
    }

    /**
     * @inheritdoc IIRNatAccount
     */
    function transferExternalToken(IWNat _wNat, IERC20 _token, uint256 _amount) external onlyRNat {
        require(address(_token) != address(_wNat), "Transfer from wNat not allowed");
        emit ExternalTokenTransferred(_token, _amount);
        _token.safeTransfer(owner, _amount);
    }

    /**
     * @inheritdoc IIRNatAccount
     */
    function rNatBalance() external view onlyRNat returns(uint256) {
        return receivedRewards - withdrawnRewards;
    }

    /**
     * @inheritdoc IIRNatAccount
     */
    function wNatBalance(IWNat _wNat) external view onlyRNat returns(uint256) {
        return _wNat.balanceOf(address(this));
    }

    /**
     * @inheritdoc IIRNatAccount
     */
    function lockedBalance(uint256 _firstMonthStartTs) external view onlyRNat returns(uint256) {
        return _lockedRewards(_firstMonthStartTs);
    }

    /**
     * Transfers the current balance to the owner.
     */
    function _transferCurrentBalanceToOwner() internal {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            /* solhint-disable avoid-low-level-calls */
            //slither-disable-next-line arbitrary-send-eth
            (bool success, ) = owner.call{value: balance}("");
            /* solhint-enable avoid-low-level-calls */
            require(success, ERR_TRANSFER_FAILURE);
        }
    }

    /**
     * Returns the amount of vested/locked rewards. The vesting period is 12 months.
     * Locked amounts are calculated as linear vesting from the start of each month, even if they are received later.
     * @param _firstMonthStartTs The start timestamp of the first month.
     */
    function _lockedRewards(uint256 _firstMonthStartTs) internal view returns(uint256) {
        uint256 currentMonth = _getCurrentMonth(_firstMonthStartTs);
        uint256 lockedRewards = 0;
        uint256 fromMonth = currentMonth > 11 ? currentMonth - 11 : 0;
        for (uint256 i = fromMonth; i <= currentMonth; i++) {
            uint256 monthStartTs = _firstMonthStartTs + i * MONTH;
            lockedRewards += rewards[i].mulDivRoundUp(12 * MONTH + monthStartTs - block.timestamp, 12 * MONTH);
        }
        return lockedRewards;
    }

    /**
     * Returns the current month.
     * @param _firstMonthStartTs The start timestamp of the first month.
     */
    function _getCurrentMonth(uint256 _firstMonthStartTs) internal view returns (uint256) {
        return (block.timestamp - _firstMonthStartTs) / MONTH;
    }

    /**
     * Checks if the caller is the `rNat` contract.
     */
    function _checkOnlyRNat() internal view {
        require(msg.sender == address(rNat), ERR_RNAT_ONLY);
    }
}
