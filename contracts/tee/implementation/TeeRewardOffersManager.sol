// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ITeeRewardOffersManager } from "../../userInterfaces/tee/ITeeRewardOffersManager.sol";
import { IIRewardManager } from "../../protocol/interface/IIRewardManager.sol";
import { RewardOffersManagerBase } from "../../protocol/implementation/RewardOffersManagerBase.sol";
import { SafePct } from "../../utils/lib/SafePct.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import { IITokenPool } from "@flarenetwork/flare-periphery-contracts/flare/tokenPools/interfaces/IITokenPool.sol";
import { InflationReceiver } from "../../inflation/implementation/InflationReceiver.sol";
import { TokenPoolBase } from "../../utils/implementation/TokenPoolBase.sol";
import { AddressUpdatable } from "../../utils/implementation/AddressUpdatable.sol";

/**
 * TeeRewardOffersManager contract.
 *
 * This contract is used to manage the TEE reward offers and receive the inflation.
 * It is used by the Flare system to trigger the reward offers.
 */
contract TeeRewardOffersManager is RewardOffersManagerBase, ITeeRewardOffersManager {
    using SafePct for uint256;

    uint256 internal constant PPM_MAX = 1e6;

    /// Total rewards offered by inflation (in wei).
    uint256 public totalInflationRewardsOfferedWei;

    /// The RewardManager contract.
    IIRewardManager public rewardManager;

    /// Part of the rewards that goes to the TEE owners.
    uint24 public teeOwnersPPM;

    /**
     * Constructor.
     * @param _governanceSettings The address of the GovernanceSettings contract.
     * @param _initialGovernance The initial governance address.
     * @param _addressUpdater The address of the AddressUpdater contract.
     * @param _teeOwnersPPM The part of the rewards that goes to the TEE owners, in parts per million (PPM).
     */
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        uint24 _teeOwnersPPM
    )
        RewardOffersManagerBase(_governanceSettings, _initialGovernance, _addressUpdater)
    {
        require(_teeOwnersPPM <= PPM_MAX, InvalidTeeOwnersPPMValue());
        teeOwnersPPM = _teeOwnersPPM;
    }

    /**
     * Set the part of the rewards that goes to the TEE owners.
     * @param _teeOwnersPPM The part of the rewards that goes to the TEE owners.
     */
    function setTeeOwnersPPM(uint24 _teeOwnersPPM) external onlyGovernance {
        require(_teeOwnersPPM <= PPM_MAX, InvalidTeeOwnersPPMValue());
        teeOwnersPPM = _teeOwnersPPM;
    }

    /**
     * @inheritdoc IITokenPool
     */
    function getTokenPoolSupplyData()
        external view
        returns (
            uint256 _lockedFundsWei,
            uint256 _totalInflationAuthorizedWei,
            uint256 _totalClaimedWei
        )
    {
        _lockedFundsWei = 0;
        _totalInflationAuthorizedWei = totalInflationAuthorizedWei;
        _totalClaimedWei = totalInflationRewardsOfferedWei;
    }

    /**
     * Implement this function to allow updating inflation receiver contracts through `AddressUpdater`.
     * @return Contract name.
     */
    function getContractName() external pure returns (string memory) {
        return "TeeRewardOffersManager";
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
        // do nothing
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
        emit InflationRewardsOffered(nextRewardEpochId, totalRewardsAmount, teeOwnersPPM);
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
