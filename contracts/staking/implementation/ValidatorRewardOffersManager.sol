// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../protocol/interface/IIRewardManager.sol";
import "../../protocol/implementation/RewardOffersManagerBase.sol";
import "../../userInterfaces/IValidatorRewardOffersManager.sol";
import "../../utils/lib/SafePct.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * ValidatorRewardOffersManager contract.
 *
 * This contract is used to manage the validator reward offers and receive the inflation.
 * It is used by the Flare system to trigger the reward offers.
 */
contract ValidatorRewardOffersManager is RewardOffersManagerBase, IValidatorRewardOffersManager {
    using SafePct for uint256;

    /// Total rewards offered by inflation (in wei).
    uint256 public totalInflationRewardsOfferedWei;

    /// The RewardManager contract.
    IIRewardManager public rewardManager;

    /**
     * Constructor.
     * @param _governanceSettings The address of the GovernanceSettings contract.
     * @param _initialGovernance The initial governance address.
     * @param _addressUpdater The address of the AddressUpdater contract.
     */
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater
    )
        RewardOffersManagerBase(_governanceSettings, _initialGovernance, _addressUpdater)
    { }

    /**
     * Implement this function to allow updating inflation receiver contracts through `AddressUpdater`.
     * @return Contract name.
     */
    function getContractName() external pure returns (string memory) {
        return "ValidatorRewardOffersManager";
    }

    /**
     * @inheritdoc AddressUpdatable
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal override
    {
        super._updateContractAddresses(_contractNameHashes, _contractAddresses);
        rewardManager = IIRewardManager(_getContractAddress(_contractNameHashes, _contractAddresses, "RewardManager"));
    }

    /**
     * @inheritdoc InflationReceiver
     */
    function _setDailyAuthorizedInflation(uint256 _toAuthorizeWei) internal override {
        // all authorized inflation should be forwarded to the reward manager
        rewardManager.addDailyAuthorizedInflation(_toAuthorizeWei);
    }

    /**
     * @inheritdoc InflationReceiver
     */
    function _receiveInflation() internal override {
        // do nothing
    }

    /**
     * @inheritdoc RewardOffersManagerBase
     */
    function _triggerInflationOffers(
        uint24 _currentRewardEpochId,
        uint64 _currentRewardEpochExpectedEndTs,
        uint64 _rewardEpochDurationSeconds
    )
        internal override
    {
        // start of previous reward epoch
        uint256 intervalStart = _currentRewardEpochExpectedEndTs - 2 * _rewardEpochDurationSeconds;
        uint256 intervalEnd = Math.max(lastInflationReceivedTs + INFLATION_TIME_FRAME_SEC,
            _currentRewardEpochExpectedEndTs - _rewardEpochDurationSeconds); // start of current reward epoch (in past)
        // _rewardEpochDurationSeconds <= intervalEnd - intervalStart
        uint256 totalRewardsAmount = (totalInflationReceivedWei - totalInflationRewardsOfferedWei)
            .mulDiv(_rewardEpochDurationSeconds, intervalEnd - intervalStart);
        // emit offers
        uint24 nextRewardEpochId = _currentRewardEpochId + 1;
        emit InflationRewardsOffered(nextRewardEpochId, totalRewardsAmount);
        // send reward amount to reward manager
        totalInflationRewardsOfferedWei += totalRewardsAmount;
        rewardManager.receiveRewards{value: totalRewardsAmount} (nextRewardEpochId, true);
    }

    /**
     * @inheritdoc TokenPoolBase
     */
    function _getExpectedBalance() internal view override returns(uint256 _balanceExpectedWei) {
        return totalInflationReceivedWei - totalInflationRewardsOfferedWei;
    }

}
