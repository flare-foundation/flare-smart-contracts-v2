// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "../protocol/interface/ICChainStake.sol";
import { IIGovernanceVotePower, IGovernanceVotePower, WNat, CheckPointsByAddress,
        DelegateCheckPointsByAddress, IVPToken, IPChainStakeMirror, SafeMath, SafeCast }
    from "../../flattened/FlareSmartContracts.sol";


/**
 * Contract managing governance vote power and its delegation.
 */
contract GovernanceVotePower is IIGovernanceVotePower {
    using SafeMath for uint256;
    using SafeCast for uint256;
    using CheckPointsByAddress for CheckPointsByAddress.CheckPointsByAddressState;
    using DelegateCheckPointsByAddress for DelegateCheckPointsByAddress.DelegateCheckPointsByAddressState;

    // `votePowerFromDelegationsHistory` tracks vote power balances obtained by delegation
    CheckPointsByAddress.CheckPointsByAddressState private votePowerFromDelegationsHistory;

    // `delegatesHistory` tracks delegates' addresses history
    DelegateCheckPointsByAddress.DelegateCheckPointsByAddressState private delegatesHistory;

    /**
     * The VPToken, IPChainStakeMirror and CPChainStake contracts that own this GovernanceVotePower.
     * All state changing methods may be called only from these addresses.
     * This is because original `msg.sender` is typically sent in a parameter
     * and we must make sure that it cannot be faked by directly calling
     * GovernanceVotePower methods.
     */
    IVPToken public immutable override ownerToken;
    IPChainStakeMirror public immutable override pChainStakeMirror;
    ICChainStake public immutable cChainStake;

    // The number of history cleanup steps executed for every write operation.
    // It is more than 1 to make as certain as possible that all history gets cleaned eventually.
    uint256 private constant CLEANUP_COUNT = 2;

    // Historic data for the blocks before `cleanupBlockNumber` can be erased,
    // history before that block should never be used since it can be inconsistent.
    uint256 private cleanupBlockNumber;

    /// Address of the contract that is allowed to call methods for history cleaning.
    /// Set with `setCleanerContract()`.
    address public cleanerContract;

    /**
     * All external methods in GovernanceVotePower can only be executed by the owner token.
     */
    modifier onlyOwnerToken {
        require(msg.sender == address(ownerToken), "only owner token");
        _;
    }

    /**
     * Method `updateAtTokenTransfer` in GovernanceVotePower can only be executed by the owner contracts.
     */
    modifier onlyOwnerContracts {
        require(msg.sender == address(ownerToken) || msg.sender == address(pChainStakeMirror) ||
            msg.sender == address(cChainStake), "only owner contracts");
        _;
    }

    /**
     * History cleaning methods can be called only from the cleaner address.
     */
    modifier onlyCleaner {
        require(msg.sender == cleanerContract, "only cleaner contract");
        _;
    }

    /**
     * Construct GovernanceVotePower for given VPToken.
     */
    constructor(IVPToken _ownerToken, IPChainStakeMirror _pChainStakeMirror, ICChainStake _cChainStake) {
        require(address(_ownerToken) != address(0), "_ownerToken zero");
        require(address(_pChainStakeMirror) != address(0), "_pChainStakeMirror zero");
        require(address(_cChainStake) != address(0), "_cChainStake zero");
        ownerToken = _ownerToken;
        pChainStakeMirror = _pChainStakeMirror;
        cChainStake = _cChainStake;
    }

    /**
     * @inheritdoc IGovernanceVotePower
     */
    function delegate(address _to) public override {
        require(_to != msg.sender, "can't delegate to yourself");

        uint256 senderBalance = ownerToken.balanceOf(msg.sender)
            .add(pChainStakeMirror.balanceOf(msg.sender))
            .add(cChainStake.balanceOf(msg.sender));

        address currentTo = getDelegateOfAtNow(msg.sender);

        // msg.sender has already delegated
        if (currentTo != address(0)) {
            _subVP(msg.sender, currentTo, senderBalance);
        }

        // write delegate's address to checkpoint
        delegatesHistory.writeAddress(msg.sender, _to);
        // cleanup checkpoints
        delegatesHistory.cleanupOldCheckpoints(msg.sender, CLEANUP_COUNT, cleanupBlockNumber);

        if (_to != address(0)) {
            _addVP(msg.sender, _to, senderBalance);
        }

        emit DelegateChanged(msg.sender, currentTo, _to);
    }

    /**
     * @inheritdoc IGovernanceVotePower
     */
    function undelegate() public override {
        delegate(address(0));
    }

    /**
     * @inheritdoc IIGovernanceVotePower
     */
    function updateAtTokenTransfer(
        address _from,
        address _to,
        uint256 /* fromBalance */,
        uint256 /* toBalance */,
        uint256 _amount
    )
        external override onlyOwnerContracts
    {
        require(_from != _to, "Can't transfer to yourself"); // should already revert in _beforeTokenTransfer
        require(_from != address(0) || _to != address(0));

        address fromDelegate = _from == address(0) ? address(0) : getDelegateOfAtNow(_from);
        address toDelegate = _to == address(0) ? address(0) : getDelegateOfAtNow(_to);

        if (_from == address(0)) { // mint
            if (toDelegate != address(0)) {
                _addVP(_to, toDelegate, _amount);
            }
        } else if (_to == address(0)) { // burn
            if (fromDelegate != address(0)) {
                _subVP(_from, fromDelegate, _amount);
            }
        } else if (fromDelegate != toDelegate) { // transfer
            if (fromDelegate != address(0)) {
                _subVP(_from, fromDelegate, _amount);
            }
            if (toDelegate != address(0)) {
                _addVP(_to, toDelegate, _amount);
            }
        }
    }

    /**
     * @inheritdoc IIGovernanceVotePower
     *
     * @dev This method can be called by the ownerToken only.
     */
    function setCleanupBlockNumber(uint256 _blockNumber) external override onlyOwnerToken {
        require(_blockNumber >= cleanupBlockNumber, "cleanup block number must never decrease");
        require(_blockNumber < block.number, "cleanup block must be in the past");
        cleanupBlockNumber = _blockNumber;
    }

    /**
     * @inheritdoc IIGovernanceVotePower
     */
    function getCleanupBlockNumber() external view override returns(uint256) {
        return cleanupBlockNumber;
    }

    /**
     * @inheritdoc IIGovernanceVotePower
     *
     * @dev This method can be called by the ownerToken only.
     */
    function setCleanerContract(address _cleanerContract) external override onlyOwnerToken {
        cleanerContract = _cleanerContract;
    }

    /**
     * Delete governance vote power checkpoints that expired (i.e. are before `cleanupBlockNumber`).
     * Method can only be called from the `cleanerContract` (which may be a proxy to external cleaners).
     * @param _owner Vote power owner account address.
     * @param _count Maximum number of checkpoints to delete.
     * @return The number of deleted checkpoints.
     */
    function delegatedGovernanceVotePowerHistoryCleanup(
        address _owner,
        uint256 _count
    ) external onlyCleaner returns (uint256) {
        return votePowerFromDelegationsHistory.cleanupOldCheckpoints(_owner, _count, cleanupBlockNumber);
    }

    /**
     * Delete delegates checkpoints that expired (i.e. are before `cleanupBlockNumber`).
     * Method can only be called from the `cleanerContract` (which may be a proxy to external cleaners).
     * @param _owner Vote power owner account address.
     * @param _count Maximum number of checkpoints to delete.
     * @return The number of deleted checkpoints.
     */
    function delegatesHistoryCleanup(
        address _owner,
        uint256 _count
    ) external onlyCleaner returns (uint256) {
        return delegatesHistory.cleanupOldCheckpoints(_owner, _count, cleanupBlockNumber);
    }

    /**
     * @inheritdoc IGovernanceVotePower
     */
    function votePowerOfAt(address _who, uint256 _blockNumber) public override view returns (uint256) {
        uint256 votePower = votePowerFromDelegationsHistory.valueOfAt(_who, _blockNumber);

        address to = getDelegateOfAt(_who, _blockNumber);
        if (to == address(0)) { // _who didn't delegate at _blockNumber
            uint256 balance = ownerToken.balanceOfAt(_who, _blockNumber)
                .add(pChainStakeMirror.balanceOfAt(_who, _blockNumber))
                .add(cChainStake.balanceOfAt(_who, _blockNumber));
            votePower += balance;
        }

        return votePower;
    }

    /**
     * @inheritdoc IGovernanceVotePower
     */
    function getVotes(address _who) public override view returns (uint256) {
        return votePowerOfAt(_who, block.number);
    }

    /**
     * @inheritdoc IGovernanceVotePower
     */
    function getDelegateOfAt(address _who, uint256 _blockNumber) public override view returns (address) {
        return delegatesHistory.delegateAddressOfAt(_who, _blockNumber);
    }

    /**
     * @inheritdoc IGovernanceVotePower
     */
    function getDelegateOfAtNow(address _who) public override view returns (address) {
        return delegatesHistory.delegateAddressOfAtNow(_who);
    }

    function _addVP(address /* _from */, address _to, uint256 _amount) internal {
        uint256 toOldVP = votePowerFromDelegationsHistory.valueOfAtNow(_to);
        uint256 toNewVP = toOldVP.add(_amount);

        votePowerFromDelegationsHistory.writeValue(_to, toNewVP);
        votePowerFromDelegationsHistory.cleanupOldCheckpoints(_to, CLEANUP_COUNT, cleanupBlockNumber);

        emit DelegateVotesChanged(_to, toOldVP, toNewVP);
    }

    function _subVP(address /* _from */, address _to, uint256 _amount) internal {
        uint256 toOldVP = votePowerFromDelegationsHistory.valueOfAtNow(_to);
        uint256 toNewVP = toOldVP.sub(_amount);

        votePowerFromDelegationsHistory.writeValue(_to, toNewVP);
        votePowerFromDelegationsHistory.cleanupOldCheckpoints(_to, CLEANUP_COUNT, cleanupBlockNumber);

        emit DelegateVotesChanged(_to, toOldVP, toNewVP);
    }

}
