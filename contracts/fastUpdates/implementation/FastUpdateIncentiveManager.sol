// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../governance/implementation/Governed.sol";
import "../../utils/implementation/AddressUpdatable.sol";
import "../../protocol/interface/IIRewardManager.sol";
import "../../protocol/implementation/RewardOffersManagerBase.sol";
import "../../userInterfaces/IFastUpdatesConfiguration.sol";
import { IncreaseManager } from "./IncreaseManager.sol";
import "../interface/IIFastUpdateIncentiveManager.sol";
import "../../utils/lib/SafePct.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title Fast update-specific configuration contract for managing the volatility incentive and its effects
 * @notice Anyone, not necessarily a provider, may call `offerIncentive` to buy an increase the performance parameters
 * of the fast updates protocol.
 * @dev When an incentive offer is accepted, it changes the expected sample size (corresponding to the score cutoff in
 * `FastUpdater`) and the scale (as used in `FastUpdater._applyUpdates), immediately. The funds offered are forwarded
 * to the central reward manager for Flare protocols, where rewards may be claimed as they are published by
 * the FTSO scaling protocol.
 */
contract FastUpdateIncentiveManager is IncreaseManager, RewardOffersManagerBase, IIFastUpdateIncentiveManager {
    using SafePct for uint256;

    /// The address of the FastUpdater contract.
    address public fastUpdater;
    /// The RewardManager contract.
    IIRewardManager public rewardManager;
    /// The FastUpdatesConfiguration contract.
    IFastUpdatesConfiguration public fastUpdatesConfiguration;

    /// Total rewards offered by inflation (in wei).
    uint256 public totalInflationRewardsOfferedWei;

    /// The maximum amount by which the expected sample size can be increased by an incentive offer.
    /// This is controlled by governance and forces a minimum cost to increasing the sample size greatly,
    /// which would otherwise be an attack on the protocol.
    FPA.SampleSize public sampleIncreaseLimit;
    /// The price for increasing the per-block range of variation by 1, prorated for the actual amount of increase.
    FPA.Fee public rangeIncreasePrice;

    /// Modifier for allowing only FastUpdater contract to call the method.
    modifier onlyFastUpdater {
        require(msg.sender == fastUpdater, "only fast updater");
        _;
    }

    /**
     * The `FastUpdateIncentiveManager` is initialized with data for various Flare system services, as well as the base
     * values of the incentive-controlled parameters and the parameters for offering incentives.
     * @param _governanceSettings The address of the GovernanceSettings contract
     * @param _initialGovernance The initial governance address
     * @param _addressUpdater The address updater contract address
     * @param _ss The initial base sample size
     * @param _r The initial base range
     * @param _sil The initial sample increase limit
     * @param _rip The initial range increase price (wei)
     * @param _dur The initial value of the duration of an incentive offer's effect
     */
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        FPA.SampleSize _ss,
        FPA.Range _r,
        FPA.SampleSize _sil,
        FPA.Fee _rip,
        uint256 _dur
    )
        RewardOffersManagerBase(_governanceSettings, _initialGovernance, _addressUpdater)
        IncreaseManager(_ss, _r, FPA.oneF, _dur) // _x is arbitrary initial value, but must not be 0
    {
        _setSampleIncreaseLimit(_sil);
        _setRangeIncreasePrice(_rip);
    }

    /**
     * @inheritdoc IFastUpdateIncentiveManager
     */
    function offerIncentive(IncentiveOffer calldata _offer) external payable mustBalance {
        (FPA.Fee dc, FPA.Range dr) = _processIncentiveOffer(_offer);
        FPA.SampleSize de = _sampleSizeIncrease(dc, dr);

        rewardManager.receiveRewards{value: FPA.Fee.unwrap(dc)} (rewardManager.getCurrentRewardEpochId(), false);
        emit IncentiveOffered(dr, de, dc);
        payable(msg.sender).transfer(msg.value - FPA.Fee.unwrap(dc));
    }

    /**
     * @inheritdoc IIFastUpdateIncentiveManager
     * @dev This method can only be called by the FastUpdater contract.
     */
    function advance() external onlyFastUpdater {
        _step();
    }

    /** Governance-only setter for the sample increase limit
     * @param _lim The new limit. This should be carefully considered by governance to make sample increases
     * unaffordablebeyond a certain upper bound.
     */
    function setSampleIncreaseLimit(FPA.SampleSize _lim) external onlyGovernance {
        _setSampleIncreaseLimit(_lim);
    }

    /**
     * Governance-only setter for the range increase price.
     * @param _price The new range increase price (wei). This should be carefully considered by governance to balance
     * the implicit cost due to loss of precision of increasing the scale rather than the expected sample size
     */
    function setRangeIncreasePrice(FPA.Fee _price) external onlyGovernance {
        _setRangeIncreasePrice(_price);
    }

    /**
     * Governance-only setter for updating increase manager settings. This clears all active incentives.
     * @param _ss The new expected sample size.
     * @param _r The new expected range.
     * @param _dur The new incentive duration (in blocks). This should be carefully considered by governance so
     * that the cost of making an offer matches the expected value to the offering party of having an increased
     * variation range for the duration. A reasonable value is the length of the `FastUpdater` submission window,
     * with the cost considerations delegated to the choice of the range increase price, but there may be a need for
     * longer or shorter characteristic periods of volatility.
     */
    function setIncentiveParameters(
        FPA.SampleSize _ss,
        FPA.Range _r,
        uint256 _dur
    )
        external onlyGovernance
    {
        _updateSettings(_ss, _r, FPA.oneF, _dur);
    }

    /**
     * @inheritdoc IFastUpdateIncentiveManager
     */
    function getExpectedSampleSize() external view returns (FPA.SampleSize) {
        return sampleSize;
    }

    /**
     * @inheritdoc IFastUpdateIncentiveManager
     */
    function getRange() external view returns (FPA.Range) {
        return range;
    }

    /**
     * @inheritdoc IFastUpdateIncentiveManager
     */
    function getPrecision() external view returns (FPA.Precision) {
        return _computePrecision();
    }

    /// Viewer for the current value of the scale itself.
    function getScale() external view returns (FPA.Scale) {
        return FPA.scaleWithPrecision(_computePrecision());
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
        return "FastUpdateIncentiveManager";
    }

    function _setSampleIncreaseLimit(FPA.SampleSize _lim) internal {
        require(FPA.check(_lim), "Sample increase limit too large");
        sampleIncreaseLimit = _lim;
    }

    function _setRangeIncreasePrice(FPA.Fee _price) internal {
        require(FPA.check(_price), "Range increase price too large");
        rangeIncreasePrice = _price;
    }

    /**
     * This function is the guts of `offerIncentive`.
     * @param _offer The data submitted in the offer transaction
     * @return _contribution The amount of the offered payment that is actually applied, which may be less than the
     * total offered amount due to the range limit.
     * @return _rangeIncrease The amount by which the range is actually increased, which may be less than the amount
     * requested due to the range limit.
     */
    function _processIncentiveOffer(
        IncentiveOffer calldata _offer
    )
        internal
        returns (FPA.Fee _contribution, FPA.Range _rangeIncrease)
    {
        require(msg.value >> 120 == 0, "Incentive offer value capped at 120 bits");
        _contribution = FPA.Fee.wrap(uint240(msg.value));
        _rangeIncrease = _offer.rangeIncrease;

        FPA.Range finalRange = FPA.add(range, _rangeIncrease);
        if (FPA.lessThan(_offer.rangeLimit, finalRange)) {
            finalRange = _offer.rangeLimit;
            FPA.Range newRangeIncrease = FPA.lessThan(finalRange, range) ? FPA.zeroR : FPA.sub(finalRange, range);
            _contribution = FPA.mul(FPA.frac(newRangeIncrease, _rangeIncrease), _contribution);
            _rangeIncrease = newRangeIncrease;
        }
        require(FPA.lessThan(finalRange, sampleSize), "Offer would make the precision greater than 100%");
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
        fastUpdater = _getContractAddress(_contractNameHashes, _contractAddresses, "FastUpdater");
        rewardManager = IIRewardManager(_getContractAddress(_contractNameHashes, _contractAddresses, "RewardManager"));
        fastUpdatesConfiguration = IFastUpdatesConfiguration(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FastUpdatesConfiguration"));
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
        uint24 nextRewardEpochId = _currentRewardEpochId + 1;
        (bytes memory feedIds, bytes memory rewardBandValues, bytes memory inflationShares) =
            fastUpdatesConfiguration.getFeedConfigurationsBytes();
        // emit offers
        emit InflationRewardsOffered(
            nextRewardEpochId,
            feedIds,
            rewardBandValues,
            inflationShares,
            totalRewardsAmount
        );
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

    /// By definition, the precision is the range divided by the expected sample size.
    function _computePrecision() internal view returns (FPA.Precision) {
        return FPA.div(range, sampleSize); // range < sampleSize
    }

    /**
     * Converts the amounts of range increase and payment into the sample size increase. The formula implies that
     * the payment required to achieve greater sample sizes is exponentially increasing, with each incentive offer
     * having a maximum sample size increase.
     * @param _dc The increment of "contribution" offered for the incentive, after refunds
     * @param _dr The increment of range, after capping
     * @return _de The increment of sample size
     */
    function _sampleSizeIncrease(FPA.Fee _dc, FPA.Range _dr) private returns (FPA.SampleSize _de) {
        FPA.Fee rangeCost = FPA.mul(rangeIncreasePrice, _dr);
        require(!FPA.lessThan(_dc, rangeCost), "Insufficient contribution to pay for range increase");
        FPA.Fee _dx = FPA.sub(_dc, rangeCost);

        _increaseExcessOfferValue(_dx);

        _de = FPA.mul(FPA.frac(_dx, excessOfferValue), sampleIncreaseLimit);

        _increaseSampleSize(_de);
        _increaseRange(_dr);
    }
}
