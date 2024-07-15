// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "flare-smart-contracts/contracts/tokenPools/interface/IIFtsoRewardManager.sol";
import "../interface/IIRewardManager.sol";
import "../interface/IIFlareSystemsManager.sol";
import "../../userInterfaces/IWNatDelegationFee.sol";
import "../../governance/implementation/Governed.sol";
import "../../utils/implementation/AddressUpdatable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";


/**
 * FtsoRewardManagerProxy is a compatibility contract replacing FtsoRewardManager
 * that is used for claiming rewards through RewardManager.
 */

contract FtsoRewardManagerProxy is IFtsoRewardManager, Governed, ReentrancyGuard, AddressUpdatable {
    using SafeCast for uint256;

    /// Indicates if the contract is enabled - claims are enabled.
    bool public enabled;

    /// addresses
    IIRewardManager public rewardManager;
    IIFlareSystemsManager public flareSystemsManager;
    IWNatDelegationFee public wNatDelegationFee;
    address public wNat;

    // for redeploy (name is kept for compatibility)
    address public immutable oldFtsoRewardManager;
    address public newFtsoRewardManager;

    modifier onlyIfEnabled() {
        _checkOnlyEnabled();
        _;
    }

    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        address _oldFtsoRewardManager
    )
        Governed(_governanceSettings, _initialGovernance) AddressUpdatable(_addressUpdater)
    {
        oldFtsoRewardManager = _oldFtsoRewardManager;
    }

    /**
     * @inheritdoc IFtsoRewardManager
     * @dev It does not support claiming of rewards of type DIRECT and FEE.
     */
    function claimReward(
        address payable _recipient,
        uint256[] calldata _rewardEpochs
    )
        external
        onlyIfEnabled
        nonReentrant
        returns (uint256 _rewardAmount)
    {
        uint256 maxRewardEpoch = 0;
        for (uint256 i = 0; i < _rewardEpochs.length; i++) {
            if (maxRewardEpoch < _rewardEpochs[i]) {
                maxRewardEpoch = _rewardEpochs[i];
            }
        }
        IRewardManager.RewardClaimWithProof[] memory proofs = new IRewardManager.RewardClaimWithProof[](0);
        return rewardManager.claimProxy(msg.sender, msg.sender, _recipient, maxRewardEpoch.toUint24(), false, proofs);
    }

    /**
     * @inheritdoc IFtsoRewardManager
     * @dev It does not support claiming of rewards of type DIRECT and FEE.
     */
    function claim(
        address _rewardOwner,
        address payable _recipient,
        uint256 _rewardEpoch,
        bool _wrap
    )
        external
        onlyIfEnabled
        nonReentrant
        returns (uint256 _rewardAmount)
    {
        IRewardManager.RewardClaimWithProof[] memory proofs = new IRewardManager.RewardClaimWithProof[](0);
        return rewardManager.claimProxy(msg.sender, _rewardOwner, _recipient, _rewardEpoch.toUint24(), _wrap, proofs);
    }

    /**
     * Activates ftso reward manager proxy (allows claiming rewards if rewardManager is active).
     */
    function enable() external onlyImmediateGovernance {
        require(address(rewardManager) != address(0), "reward manager not set");
        enabled = true;
    }

    /**
     * Deactivates ftso reward manager proxy (prevents claiming rewards through it).
     */
    function disable() external onlyImmediateGovernance {
        enabled = false;
    }

    /**
     * Sets new ftso reward manager address.
     * @dev Should be called at the time of switching to the new ftso reward manager, can be called only once
     */
    function setNewFtsoRewardManager(address _newFtsoRewardManager) external onlyGovernance {
        require(newFtsoRewardManager == address(0), "already set");
        require(_newFtsoRewardManager != address(0), "address zero");
        newFtsoRewardManager = _newFtsoRewardManager;
    }

    /**
     * @inheritdoc IFtsoRewardManager
     */
    function active() external view returns (bool) {
        return enabled && rewardManager.active();
    }

    /**
     * @inheritdoc IFtsoRewardManager
     */
    function getDataProviderCurrentFeePercentage(address _dataProvider)
        external view
        returns (uint256 _feePercentageBIPS)
    {
        return wNatDelegationFee.getVoterCurrentFeePercentage(_dataProvider);
    }

    /**
     * @inheritdoc IFtsoRewardManager
     */
    function getDataProviderFeePercentage(
        address _dataProvider,
        uint256 _rewardEpoch
    )
        external view
        returns (uint256 _feePercentageBIPS)
    {
        return wNatDelegationFee.getVoterFeePercentage(_dataProvider, _rewardEpoch);
    }

    /**
     * @inheritdoc IFtsoRewardManager
     */
    function getDataProviderScheduledFeePercentageChanges(address _dataProvider) external view
        returns (
            uint256[] memory _feePercentageBIPS,
            uint256[] memory _validFromEpoch,
            bool[] memory _fixed
        )
    {
        return wNatDelegationFee.getVoterScheduledFeePercentageChanges(_dataProvider);
    }

    /**
     * @inheritdoc IFtsoRewardManager
     */
    function getEpochReward(uint256 _rewardEpoch) external view
        returns (uint256 _totalReward, uint256 _claimedReward)
    {
        (_totalReward, , , _claimedReward, ) = rewardManager.getRewardEpochTotals(_rewardEpoch.toUint24());
    }

    /**
     * @inheritdoc IFtsoRewardManager
     */
    function getStateOfRewards(
        address _beneficiary,
        uint256 _rewardEpoch
    )
        external view
        returns (
            address[] memory _dataProviders,
            uint256[] memory _rewardAmounts,
            bool[] memory _claimed,
            bool _claimable
        )
    {
        try rewardManager.getStateOfRewardsAt(_beneficiary, _rewardEpoch.toUint24()) returns (
            IRewardManager.RewardState[] memory rewardStates
        ) {
            _dataProviders = new address[](rewardStates.length);
            _rewardAmounts = new uint256[](rewardStates.length);
            _claimed = new bool[](rewardStates.length);
            _claimable = true;
            for (uint256 i = 0; i < rewardStates.length; i++) {
                IRewardManager.RewardState memory rewardState = rewardStates[i];
                _dataProviders[i] = address(rewardState.beneficiary);
                _rewardAmounts[i] = rewardState.amount;
                if (!rewardState.initialised) {
                    revert("not initialised");
                }
            }
        } catch Error(string memory _error) {
            string memory errorString = "already claimed"; // error message from RewardManager
            if (keccak256(abi.encode(errorString)) == keccak256(abi.encode(_error))) {
                _claimable = false;
            } else {
                revert(_error);
            }
        } catch {
            _claimable = false;
        }
    }

    /**
     * @inheritdoc IFtsoRewardManager
     */
    function getEpochsWithClaimableRewards() external view
        returns (uint256 _startEpochId, uint256 _endEpochId)
    {
        return rewardManager.getRewardEpochIdsWithClaimableRewards();
    }

    /**
     * @inheritdoc IFtsoRewardManager
     */
    function nextClaimableRewardEpoch(address _rewardOwner) external view returns (uint256) {
        return rewardManager.getNextClaimableRewardEpochId(_rewardOwner);
    }

    /**
     * @inheritdoc IFtsoRewardManager
     */
    function getEpochsWithUnclaimedRewards(address _beneficiary) external view
        returns (uint256[] memory _epochIds)
    {
        IRewardManager.RewardState[][] memory rewardStates = rewardManager.getStateOfRewards(_beneficiary);
        uint256[] memory epochIds = new uint256[](rewardStates.length);
        uint256 count = 0;
        for (uint256 i = 0; i < rewardStates.length; i++) {
            if (rewardStates[i].length > 0) {
                bool allInitialized = true;
                for (uint256 j = 0; j < rewardStates[i].length; j++) {
                    if (!rewardStates[i][j].initialised) {
                        allInitialized = false;
                        break;
                    }
                }
                if (allInitialized) {
                    epochIds[count] = rewardStates[i][0].rewardEpochId;
                    count++;
                } else {
                    break;
                }
            }
        }
        _epochIds = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            _epochIds[i] = epochIds[i];
        }
    }

    /**
     * @inheritdoc IFtsoRewardManager
     */
    function getClaimedReward(
        uint256 _rewardEpoch,
        address _dataProvider,
        address _claimer
    )
        external view
        returns (
            bool _claimed,
            uint256 _amount
        )
    {
         try rewardManager.getStateOfRewardsAt(_claimer, _rewardEpoch.toUint24()) returns (
            IRewardManager.RewardState[] memory rewardStates
        ) {
            for (uint256 i = 0; i < rewardStates.length; i++) {
                IRewardManager.RewardState memory rewardState = rewardStates[i];
                if (address(rewardState.beneficiary) == _dataProvider) {
                    return (false, rewardState.amount);
                }
            }
        } catch Error(string memory _error) {
            string memory errorString = "already claimed"; // error message from RewardManager
            if (keccak256(abi.encode(errorString)) == keccak256(abi.encode(_error))) {
                _claimed = true;
            } else {
                revert(_error);
            }
        } catch {
            _claimed = true;
        }
    }

    /**
     * @inheritdoc IFtsoRewardManager
     */
    function getRewardEpochToExpireNext() external view returns (uint256) {
        return rewardManager.getRewardEpochIdToExpireNext();
    }

    /**
     * @inheritdoc IFtsoRewardManager
     */
    function getRewardEpochVotePowerBlock(uint256 _rewardEpoch) external view returns (uint256) {
        return flareSystemsManager.getVotePowerBlock(_rewardEpoch);
    }

    /**
     * @inheritdoc IFtsoRewardManager
     */
    function getCurrentRewardEpoch() external view returns (uint256) {
        return rewardManager.getCurrentRewardEpochId();
    }

    /**
     * @inheritdoc IFtsoRewardManager
     */
    function getInitialRewardEpoch() external view returns (uint256 _initialRewardEpoch) {
        return rewardManager.getInitialRewardEpochId();
    }

    /**
     * @inheritdoc IFtsoRewardManager
     * @dev Deprecated
     */
    function claimRewardFromDataProviders(
        address payable,
        uint256[] calldata,
        address[] calldata
    )
        external pure returns (uint256)
    {
        // return 0
    }

    /**
     * @inheritdoc IFtsoRewardManager
     * @dev Deprecated
     */
    function claimFromDataProviders(
        address,
        address payable,
        uint256[] calldata,
        address[] calldata,
        bool
    )
        external pure returns (uint256)
    {
        // return 0
    }

    /**
     * @inheritdoc IFtsoRewardManager
     * @dev Deprecated - reverts
     */
    function autoClaim(address[] calldata, uint256) external pure {
        revert("not supported, use RewardManager");
    }

    /**
     * @inheritdoc IFtsoRewardManager
     * @dev Deprecated - reverts
     */
    function setDataProviderFeePercentage(uint256)
        external pure
        returns (uint256)
    {
        revert("not supported, use WNatDelegationFee");
    }

    /**
     * @inheritdoc IFtsoRewardManager
     * @dev Deprecated
     */
    function getStateOfRewardsFromDataProviders(
        address,
        uint256,
        address[] calldata
    )
        external pure
        returns (
            uint256[] memory,
            bool[] memory,
            bool
        )
    {
        // return empty array, empty array, false
    }

    /**
     * @inheritdoc IFtsoRewardManager
     * @dev Deprecated
     */
    function getDataProviderPerformanceInfo(
        uint256,
        address
    )
        external pure
        returns (
            uint256,
            uint256
        )
    {
        // return 0, 0
    }

    /**
     * Implementation of the AddressUpdatable abstract method.
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal override
    {
        rewardManager = IIRewardManager(_getContractAddress(_contractNameHashes, _contractAddresses, "RewardManager"));
        flareSystemsManager = IIFlareSystemsManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsManager"));
        wNatDelegationFee = IWNatDelegationFee(
            _getContractAddress(_contractNameHashes, _contractAddresses, "WNatDelegationFee"));
        wNat = _getContractAddress(_contractNameHashes, _contractAddresses, "WNat");
    }

    /**
     * Checks if the contract is enabled.
     */
    function _checkOnlyEnabled() private view {
        require(enabled, "ftso reward manager proxy disabled");
    }
}
