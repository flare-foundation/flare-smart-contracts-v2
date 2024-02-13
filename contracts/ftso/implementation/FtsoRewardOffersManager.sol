// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../protocol/interface/IIRewardManager.sol";
import "../../protocol/implementation/RewardOffersManagerBase.sol";
import "../../userInterfaces/IFtsoInflationConfigurations.sol";
import "../../userInterfaces/IFtsoRewardOffersManager.sol";
import "../../userInterfaces/IFtsoFeedDecimals.sol";
import "../../utils/lib/SafePct.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * FtsoRewardOffersManager contract.
 *
 * This contract is used to manage the FTSO reward offers and receive the inflation.
 * It is used by the Flare system to trigger the reward offers.
 */
contract FtsoRewardOffersManager is RewardOffersManagerBase, IFtsoRewardOffersManager {
    using SafePct for uint256;

    uint256 internal constant MAX_BIPS = 1e4;
    uint256 internal constant PPM_MAX = 1e6;

    /// Total rewards offered by inflation (in wei).
    uint256 public totalInflationRewardsOfferedWei;
    /// Mininal rewards offer value (in wei).
    uint256 public minimalRewardsOfferValueWei;

    /// The RewardManager contract.
    IIRewardManager public rewardManager;
    /// The FtsoInflationConfigurations contract.
    IFtsoInflationConfigurations public ftsoInflationConfigurations;
    /// The FtsoFeedDecimals contract.
    IFtsoFeedDecimals public ftsoFeedDecimals;

    /**
     * Constructor.
     * @param _governanceSettings The address of the GovernanceSettings contract.
     * @param _initialGovernance The initial governance address.
     * @param _addressUpdater The address of the AddressUpdater contract.
     * @param _minimalRewardsOfferValueWei The minimal rewards offer value (in wei).
     */
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        uint128 _minimalRewardsOfferValueWei
    )
        RewardOffersManagerBase(_governanceSettings, _initialGovernance, _addressUpdater)
    {
        minimalRewardsOfferValueWei = _minimalRewardsOfferValueWei;
        emit MinimalRewardsOfferValueSet(_minimalRewardsOfferValueWei);
    }

    /**
     * @inheritdoc IFtsoRewardOffersManager
     */
    function offerRewards(
        uint24 _nextRewardEpochId,
        Offer[] calldata _offers
    )
        external payable mustBalance
    {
        uint24 currentRewardEpochId = flareSystemsManager.getCurrentRewardEpochId();
        require(_nextRewardEpochId == currentRewardEpochId + 1, "not next reward epoch id");
        require(flareSystemsManager.currentRewardEpochExpectedEndTs() >
            block.timestamp + flareSystemsManager.newSigningPolicyInitializationStartSeconds(),
            "too late for next reward epoch");
        uint256 sumRewardsOfferValues = 0;
        for (uint256 i = 0; i < _offers.length; ++i) {
            Offer calldata offer = _offers[i];
            require(offer.minRewardedTurnoutBIPS <= MAX_BIPS, "invalid minRewardedTurnoutBIPS value");
            require(offer.primaryBandRewardSharePPM <= PPM_MAX, "invalid primaryBandRewardSharePPM value");
            require(offer.secondaryBandWidthPPM <= PPM_MAX, "invalid secondaryBandWidthPPM value");
            require(offer.amount >= minimalRewardsOfferValueWei, "rewards offer value too small");
            sumRewardsOfferValues += offer.amount;
            address claimBackAddress = offer.claimBackAddress;
            if (claimBackAddress == address(0)) {
                claimBackAddress = msg.sender;
            }
            emit RewardsOffered(
                _nextRewardEpochId,
                offer.feedName,
                ftsoFeedDecimals.getDecimals(offer.feedName, _nextRewardEpochId),
                offer.amount,
                offer.minRewardedTurnoutBIPS,
                offer.primaryBandRewardSharePPM,
                offer.secondaryBandWidthPPM,
                claimBackAddress
            );
        }
        require(sumRewardsOfferValues == msg.value, "amount offered is not the same as value sent");
        rewardManager.receiveRewards{value: msg.value} (_nextRewardEpochId, false);
    }

    /**
     * Allows governance to set the minimal rewards offer value.
     * @param _minimalRewardsOfferValueWei The minimal rewards offer value (in wei).
     * @dev Only governance can call this method.
     */
    function setMinimalRewardsOfferValue(uint128 _minimalRewardsOfferValueWei) external onlyGovernance {
        minimalRewardsOfferValueWei = _minimalRewardsOfferValueWei;
        emit MinimalRewardsOfferValueSet(_minimalRewardsOfferValueWei);
    }

    /**
     * Implement this function to allow updating inflation receiver contracts through `AddressUpdater`.
     * @return Contract name.
     */
    function getContractName() external pure returns (string memory) {
        return "FtsoRewardOffersManager";
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
        ftsoInflationConfigurations = IFtsoInflationConfigurations(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FtsoInflationConfigurations"));
        ftsoFeedDecimals = IFtsoFeedDecimals(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FtsoFeedDecimals"));
    }

    /**
     * @inheritdoc InflationReceiver
     */
    function _setDailyAuthorizedInflation(uint256 _toAuthorizeWei) internal override {
        // all authorized inflation should be forwarded to the reward manager
        rewardManager.addDailyAuthorizedInflation(_toAuthorizeWei);
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
        IFtsoInflationConfigurations.FtsoConfiguration[] memory configurations =
            ftsoInflationConfigurations.getFtsoConfigurations();

        uint256 length = configurations.length;
        uint256 inflationShareSum = 0;
        for (uint256 i = 0; i < length; i++) {
            inflationShareSum += configurations[i].inflationShare;
        }
        if (inflationShareSum == 0) { // also covers length == 0
            return;
        }

        uint256 remainingRewardsAmount = totalRewardsAmount;
        for (uint256 i = 0; i < length; i++) {
            IFtsoInflationConfigurations.FtsoConfiguration memory config = configurations[i];
            uint256 amount = _getRewardsAmount(remainingRewardsAmount, inflationShareSum, config.inflationShare);
            remainingRewardsAmount -= amount;
            inflationShareSum -= config.inflationShare;
            emit InflationRewardsOffered(
                nextRewardEpochId,
                config.feedNames,
                ftsoFeedDecimals.getDecimalsBulk(config.feedNames, nextRewardEpochId),
                amount,
                config.minRewardedTurnoutBIPS,
                config.primaryBandRewardSharePPM,
                config.secondaryBandWidthPPMs,
                config.mode
            );
        }
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

    /**
     * @dev Returns the rewards amount for `_inflationShare` of `_inflationShareSum` of `_totalRewardAmount`.
     * @param _totalRewardAmount The total reward amount.
     * @param _inflationShareSum The sum of all inflation shares.
     * @param _inflationShare The inflation share.
     */
    function _getRewardsAmount(
        uint256 _totalRewardAmount,
        uint256 _inflationShareSum,
        uint256 _inflationShare
    )
        internal pure returns(uint256)
    {
        if (_inflationShare == 0) {
            return 0;
        }

        if (_totalRewardAmount == 0) {
            return 0;
        }
        if (_inflationShare == _inflationShareSum) {
            return _totalRewardAmount;
        }
        assert(_inflationShare < _inflationShareSum);
        return _totalRewardAmount.mulDiv(_inflationShare, _inflationShareSum);
    }
}
