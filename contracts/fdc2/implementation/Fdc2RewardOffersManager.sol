// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IFdc2RewardOffersManager } from "../../userInterfaces/fdc2/IFdc2RewardOffersManager.sol";
import { IFdc2InflationConfigurations } from "../../userInterfaces/fdc2/IFdc2InflationConfigurations.sol";
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
 * Fdc2RewardOffersManager contract.
 *
 * This contract is used to manage the FDC2 reward offers and receive the inflation.
 * It is triggered by the Flare systems manager to emit the inflation reward offers.
 */
contract Fdc2RewardOffersManager is RewardOffersManagerBase, IFdc2RewardOffersManager {
    using SafePct for uint256;

    /// Total rewards offered by inflation (in wei).
    uint256 public totalInflationRewardsOfferedWei;

    /// The RewardManager contract.
    IIRewardManager public rewardManager;

    /// The FDC2 inflation configurations contract.
    IFdc2InflationConfigurations public fdc2InflationConfigurations;

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
    function getContractName()
        external pure
        returns (string memory)
    {
        return "Fdc2RewardOffersManager";
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
        rewardManager = IIRewardManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "RewardManager"));
        fdc2InflationConfigurations = IFdc2InflationConfigurations(
            _getContractAddress(_contractNameHashes, _contractAddresses, "Fdc2InflationConfigurations"));
    }

    /**
     * @inheritdoc InflationReceiver
     */
    function _setDailyAuthorizedInflation(
        uint256 _toAuthorizeWei
    )
        internal override
    {
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
        uint24 nextRewardEpochId = _currentRewardEpochId + 1;
        // emit offer
        emit InflationRewardsOffered(
            nextRewardEpochId,
            fdc2InflationConfigurations.getFdc2Configurations(),
            totalRewardsAmount
        );
        // send reward amount to reward manager
        totalInflationRewardsOfferedWei += totalRewardsAmount;
        //slither-disable-next-line arbitrary-send-eth
        rewardManager.receiveRewards{value: totalRewardsAmount} (nextRewardEpochId, true);
    }

    /**
     * @inheritdoc TokenPoolBase
     */
    function _getExpectedBalance()
        internal view override
        returns (uint256 _balanceExpectedWei)
    {
        return totalInflationReceivedWei - totalInflationRewardsOfferedWei;
    }
}
