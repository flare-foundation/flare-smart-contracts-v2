// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { GovernedProxyImplementation } from "../../governance/implementation/GovernedProxyImplementation.sol";
import { GovernedBase } from "../../governance/implementation/GovernedBase.sol";
import { InflationReceiver } from "../../inflation/implementation/InflationReceiver.sol";
import { TokenPoolBase } from "../../utils/implementation/TokenPoolBase.sol";
import { AddressUpdatable } from "../../utils/implementation/AddressUpdatable.sol";
import { IIFlareSystemsManager } from "../interface/IIFlareSystemsManager.sol";
import { IIRewardEpochSwitchoverTrigger } from "../interface/IIRewardEpochSwitchoverTrigger.sol";
import { IIRewardManager } from "../interface/IIRewardManager.sol";
import { SafePct } from "../../utils/lib/SafePct.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import { IITokenPool } from "@flarenetwork/flare-periphery-contracts/flare/tokenPools/interfaces/IITokenPool.sol";

/**
 * RewardOffersManagerProxyBase contract.
 *
 * Sibling of RewardOffersManagerBase for UUPS-upgradeable reward offers managers.
 * Combines GovernedProxyImplementation + UUPSUpgradeable with the inflation pool
 * accounting from InflationReceiver (which itself brings AddressUpdatable) and the
 * reward-epoch switchover trigger plumbing.
 *
 * Subclasses only need to override `_emitInflationRewardsOffered` to emit their
 * subclass-specific event payload.
 */
abstract contract RewardOffersManagerProxyBase is
    GovernedProxyImplementation,
    UUPSUpgradeable,
    InflationReceiver,
    IIRewardEpochSwitchoverTrigger
{
    using SafePct for uint256;

    uint256 internal constant INFLATION_TIME_FRAME_SEC = 1 days;

    /// Total rewards offered by inflation (in wei).
    uint256 public totalInflationRewardsOfferedWei;

    /// The FlareSystemsManager contract.
    IIFlareSystemsManager public flareSystemsManager;

    /// The RewardManager contract.
    IIRewardManager public rewardManager;

    /// Only FlareSystemsManager contract can call this method.
    modifier onlyFlareSystemsManager {
        require(msg.sender == address(flareSystemsManager), "only flare system manager");
        _;
    }

    /**
     * Constructor that initializes with invalid parameters to prevent direct deployment/updates.
     * GovernedProxyImplementation sets a dummy governance address; InflationReceiver(address(0))
     * propagates address(0) to AddressUpdatable. Real values are set via initialize().
     */
    constructor() GovernedProxyImplementation() InflationReceiver(address(0)) {}

    /**
     * @inheritdoc IIRewardEpochSwitchoverTrigger
     * @dev Computes the pro-rata reward amount, emits the subclass-specific event via
     *      `_emitInflationRewardsOffered`, and forwards the rewards to RewardManager.
     */
    function triggerRewardEpochSwitchover(
        uint24 _currentRewardEpochId,
        uint64 _currentRewardEpochExpectedEndTs,
        uint64 _rewardEpochDurationSeconds
    )
        external virtual
        onlyFlareSystemsManager
    {
        // start of previous reward epoch
        uint256 intervalStart = _currentRewardEpochExpectedEndTs - 2 * _rewardEpochDurationSeconds;
        uint256 intervalEnd = Math.max(lastInflationReceivedTs + INFLATION_TIME_FRAME_SEC,
            _currentRewardEpochExpectedEndTs - _rewardEpochDurationSeconds); // start of current reward epoch (in past)
        // _rewardEpochDurationSeconds <= intervalEnd - intervalStart
        uint256 totalRewardsAmount = (totalInflationReceivedWei - totalInflationRewardsOfferedWei)
            .mulDiv(_rewardEpochDurationSeconds, intervalEnd - intervalStart);
        uint24 nextRewardEpochId = _currentRewardEpochId + 1;
        _emitInflationRewardsOffered(nextRewardEpochId, totalRewardsAmount);
        // send reward amount to reward manager
        totalInflationRewardsOfferedWei += totalRewardsAmount;
        //slither-disable-next-line arbitrary-send-eth
        rewardManager.receiveRewards{value: totalRewardsAmount}(nextRewardEpochId, true);
    }

    /**
     * @inheritdoc IITokenPool
     */
    function getTokenPoolSupplyData()
        external view virtual
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
     * Returns the current implementation address.
     * @return The current implementation address.
     */
    function implementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    /**
     * @inheritdoc UUPSUpgradeable
     * @dev Only governance can call this method.
     */
    function upgradeToAndCall(
        address _newImplementation,
        bytes memory _data
    )
        public payable virtual override
        onlyGovernance
    {
        super.upgradeToAndCall(_newImplementation, _data);
    }

    /**
     * @inheritdoc AddressUpdatable
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal virtual override
    {
        super._updateContractAddresses(_contractNameHashes, _contractAddresses);
        flareSystemsManager = IIFlareSystemsManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsManager"));
        rewardManager = IIRewardManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "RewardManager"));
    }

    /**
     * @inheritdoc InflationReceiver
     */
    function _setDailyAuthorizedInflation(
        uint256 _toAuthorizeWei
    )
        internal virtual override
    {
        // do nothing
    }

    /**
     * @inheritdoc InflationReceiver
     */
    function _receiveInflation() internal virtual override {
        // do nothing
    }

    /**
     * @inheritdoc TokenPoolBase
     */
    function _getExpectedBalance()
        internal view virtual override
        returns (uint256 _balanceExpectedWei)
    {
        return totalInflationReceivedWei - totalInflationRewardsOfferedWei;
    }

    /**
     * Initializes governance + UUPS + address-updater. Subclasses call from their own initialize.
     */
    function initializeBase(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater
    )
        internal virtual
    {
        GovernedBase.initialise(_governanceSettings, _initialGovernance);
        AddressUpdatable.setAddressUpdaterValue(_addressUpdater);
    }

    /**
     * Unused. Present just to satisfy UUPSUpgradeable requirement.
     * The real check is in onlyGovernance modifier on upgradeToAndCall.
     */
    function _authorizeUpgrade(address _newImplementation) internal virtual override {}

    /**
     * Subclass hook: emit the InflationRewardsOffered event. Each subclass declares its
     * own event signature (Tee emits PPM, FDC2 emits a configurations array, etc.) and
     * implements this hook to fire it. Called from `triggerRewardEpochSwitchover` after
     * the pro-rata amount has been computed and before funds are forwarded to RewardManager.
     */
    function _emitInflationRewardsOffered(
        uint24 _nextRewardEpochId,
        uint256 _amount
    )
        internal virtual;
}
