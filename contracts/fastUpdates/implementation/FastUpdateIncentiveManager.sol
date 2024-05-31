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
    /// The maximum value that the range can be increased to by an incentive offer.
    FPA.Range public rangeIncreaseLimit;
    /// The price for increasing the per-block range of variation by 1, prorated for the actual amount of increase.
    FPA.Fee public rangeIncreasePrice;
    /// Base scale value.
    FPA.Scale internal baseScale;

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
     * @param _ril The range increase limit
     * @param _x The initial sample size increase price (wei)
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
        FPA.Range _ril,
        FPA.Fee _x,
        FPA.Fee _rip,
        uint256 _dur
    )
        RewardOffersManagerBase(_governanceSettings, _initialGovernance, _addressUpdater)
        IncreaseManager(_ss, _r, _x, _dur)
    {
        _checkRangeParameters(_r, _ril, _rip);
        _checkPrecisionBound(_ril, _ss);
        _setSampleIncreaseLimit(_sil);
        _setRangeIncreaseLimit(_ril);
        _setRangeIncreasePrice(_rip);
        _setBaseScale();
    }

    /**
     * @inheritdoc IFastUpdateIncentiveManager
     */
    function offerIncentive(IncentiveOffer calldata _offer) external payable mustBalance {
        (FPA.Fee dc, FPA.Range dr, FPA.SampleSize de) = _processIncentiveOffer(_offer);

        uint24 currentRewardEpochId = rewardManager.getCurrentRewardEpochId();
        rewardManager.receiveRewards{value: FPA.Fee.unwrap(dc)} (currentRewardEpochId, false);
        emit IncentiveOffered(currentRewardEpochId, dr, de, dc);
        /* solhint-disable avoid-low-level-calls */
        //slither-disable-next-line arbitrary-send-eth
        (bool success, ) = msg.sender.call{value: msg.value - FPA.Fee.unwrap(dc)}("");
        /* solhint-enable avoid-low-level-calls */
        require(success, "Transfer failed");
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
     * unaffordable beyond a certain upper bound.
     */
    function setSampleIncreaseLimit(FPA.SampleSize _lim) external onlyGovernance {
        _setSampleIncreaseLimit(_lim);
    }

    /** Governance-only setter for the range increase limit
     * @param _lim The new limit.
     */
    function setRangeIncreaseLimit(FPA.Range _lim) external onlyGovernance {
        FPA.Range baseRange = FPA.sub(range, FPA.sum(rangeIncreases));
        _checkRangeParameters(baseRange, _lim, rangeIncreasePrice);
        FPA.SampleSize baseSampleSize = FPA.sub(sampleSize, FPA.sum(sampleIncreases));
        _checkPrecisionBound(_lim, baseSampleSize);
        _setRangeIncreaseLimit(_lim);
    }

    /**
     * Governance-only setter for the range increase price.
     * @param _price The new range increase price (wei). This should be carefully considered by governance to balance
     * the implicit cost due to loss of precision of increasing the scale rather than the expected sample size
     */
    function setRangeIncreasePrice(FPA.Fee _price) external onlyGovernance {
        FPA.Range baseRange = FPA.sub(range, FPA.sum(rangeIncreases));
        _checkRangeParameters(baseRange, rangeIncreaseLimit, _price);
        _setRangeIncreasePrice(_price);
    }

    /**
     * Governance-only setter for updating increase manager settings. This clears all active incentives.
     * @param _ss The new expected sample size.
     * @param _r The new expected range.
     * @param _x The new sample size increase price (wei).
     * @param _dur The new incentive duration (in blocks). This should be carefully considered by governance so
     * that the cost of making an offer matches the expected value to the offering party of having an increased
     * variation range for the duration. A reasonable value is the length of the `FastUpdater` submission window,
     * with the cost considerations delegated to the choice of the range increase price, but there may be a need for
     * longer or shorter characteristic periods of volatility.
     */
    function setIncentiveParameters(
        FPA.SampleSize _ss,
        FPA.Range _r,
        FPA.Fee _x,
        uint256 _dur
    )
        external onlyGovernance
    {
        _checkRangeParameters(_r, rangeIncreaseLimit, rangeIncreasePrice);
        _checkPrecisionBound(rangeIncreaseLimit, _ss);
        _updateSettings(_ss, _r, _x, _dur);
        _setBaseScale();
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
    function getCurrentSampleSizeIncreasePrice() external view returns (FPA.Fee) {
        return excessOfferValue;
    }

    /**
     * @inheritdoc IFastUpdateIncentiveManager
     */
    function getPrecision() external view returns (FPA.Precision) {
        return _computePrecision();
    }

    /**
     * @inheritdoc IFastUpdateIncentiveManager
     */
    function getScale() external view returns (FPA.Scale) {
        return FPA.scaleWithPrecision(_computePrecision());
    }

    /**
     * @inheritdoc IFastUpdateIncentiveManager
     */
    function getBaseScale() external view returns (FPA.Scale) {
        return baseScale;
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

    function _setBaseScale() internal {
        baseScale = FPA.scaleWithPrecision(_computePrecision());
    }

    function _setSampleIncreaseLimit(FPA.SampleSize _lim) internal {
        require(FPA.check(_lim), "Sample increase limit too large");
        sampleIncreaseLimit = _lim;
    }

    function _setRangeIncreaseLimit(FPA.Range _lim) internal {
        require(FPA.check(_lim), "Range increase limit too large");
        rangeIncreaseLimit = _lim;
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
     * @return _sampleSizeIncrease The amount by which the sample size is increased, which is computed from the
     * contribution and the range increase.
     */
    function _processIncentiveOffer(
        IncentiveOffer calldata _offer
    )
        internal
        returns (FPA.Fee _contribution, FPA.Range _rangeIncrease, FPA.SampleSize _sampleSizeIncrease)
    {
        require(msg.value >> 120 == 0, "Incentive offer value capped at 120 bits");
        require(FPA.check(_offer.rangeIncrease), "Range increase too large");
        _contribution = FPA.Fee.wrap(msg.value);
        _rangeIncrease = _offer.rangeIncrease;

        // Apply the range limit to the range increase. If the range increase is greater than the limit,
        // adjust the contribution to reflect the reduced range increase.
        FPA.Fee rangeCost = FPA.zeroF;
        if (FPA.lessThan(FPA.zeroR, _rangeIncrease)) {
            FPA.Range rangeLimit = FPA.lessThan(_offer.rangeLimit, rangeIncreaseLimit) ?
                _offer.rangeLimit : rangeIncreaseLimit;
            if (FPA.lessThan(rangeLimit, FPA.add(range, _rangeIncrease))) {
                FPA.Range newRangeIncrease = FPA.lessThan(rangeLimit, range) ? FPA.zeroR : FPA.sub(rangeLimit, range);
                _contribution = FPA.mul(FPA.frac(newRangeIncrease, _rangeIncrease), _contribution);
                _rangeIncrease = newRangeIncrease;
            }

            // Calculate the cost of the range increase and apply it if the contribution is sufficient.
            rangeCost = FPA.mul(rangeIncreasePrice, _rangeIncrease);
            require(!FPA.lessThan(_contribution, rangeCost), "Insufficient contribution to pay for range increase");

            _increaseRange(_rangeIncrease);
        } else if (FPA.lessThan(FPA.zeroR, _offer.rangeLimit) && FPA.lessThan(_offer.rangeLimit, range)) {
            _contribution = FPA.zeroF;
            _rangeIncrease = FPA.zeroR;
        }

        // Remaining contribution is used for sample size increase.
        FPA.Fee sampleSizeIncreasePayment = FPA.sub(_contribution, rangeCost);

        // sampleSizeIncreasePayment == 0 means _sampleSizeIncrease = 0
        if (FPA.lessThan(FPA.zeroF, sampleSizeIncreasePayment)) {
            // The formula implies that the payment required to increase the sample size is exponentially increasing.
            _increaseExcessOfferValue(sampleSizeIncreasePayment);
            _sampleSizeIncrease = FPA.mul(FPA.frac(sampleSizeIncreasePayment, excessOfferValue), sampleIncreaseLimit);

            _increaseSampleSize(_sampleSizeIncrease);
        }
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
        IFastUpdatesConfiguration.FeedConfiguration[] memory feedConfigurations =
            fastUpdatesConfiguration.getFeedConfigurations();
        // emit offers
        emit InflationRewardsOffered(
            nextRewardEpochId,
            feedConfigurations,
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
     * Checks the range parameters. Range cannot be greater than the range increase limit.
     * Range should be more than 1e6 and price high enough to make the range increase meaningful.
     * @param _r The range.
     * @param _ril The range increase limit.
     * @param _rip The range increase price.
     */
    function _checkRangeParameters(FPA.Range _r, FPA.Range _ril, FPA.Fee _rip) internal pure {
        require(!FPA.lessThan(_ril, _r), "Range cannot be greater than the range increase limit");
        // this check implies that the rounding error in offerIncentive does not cause to overpay
        // more that (1e-6 * range) of range change
        require(FPA.lessThan(FPA.zeroF, FPA.mul(_rip, FPA.Range.wrap(FPA.Range.unwrap(_r) / 1e6))),
            "Range increase price too low, range increase of 1e-6 of base range should cost at least 1 wei");
    }

    /**
     * Checks that the precision can never be greater than 100%.
     * @param _ril The range increase limit.
     * @param _ss The expected sample size.
     */
    function _checkPrecisionBound(FPA.Range _ril, FPA.SampleSize _ss) internal pure {
        require(FPA.lessThan(_ril, _ss), "Parameters should not allow making the precision greater than 100%");
    }
}
