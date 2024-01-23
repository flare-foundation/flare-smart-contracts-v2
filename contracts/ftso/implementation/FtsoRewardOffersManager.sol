// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../protocol/implementation/RewardManager.sol";
import "../../protocol/implementation/RewardOffersManagerBase.sol";
import "../interface/IFtsoInflationConfigurations.sol";
import "./FtsoFeedDecimals.sol";
import "../../utils/lib/SafePct.sol";

/**
 * FtsoRewardOffersManager contract.
 *
 * This contract is used to manage the FTSO reward offers and receive the inflation.
 * It is used by the Flare system to trigger the reward offers.
 */
contract FtsoRewardOffersManager is RewardOffersManagerBase {
    using SafePct for uint256;

    /**
    * Defines a reward offer.
    */
    struct Offer {
        // amount (in wei) of reward in native coin
        uint120 amount;
        // feed name - i.e. base/quote symbol
        bytes8 feedName;
        // primary band reward share in PPM (parts per million)
        uint24 primaryBandRewardSharePPM;
        // secondary band width in PPM (parts per million) in relation to the median
        uint24 secondaryBandWidthPPM;
        // reward eligibility in PPM (parts per million) in relation to the median of the lead providers
        uint24 rewardEligibilityPPM;
        // list of lead providers
        address[] leadProviders;
        // address that can claim undistributed part of the reward (or burn address)
        address claimBackAddress;
    }

    uint256 internal constant PPM_MAX = 1e6;

    /// Total rewards offered by inflation (in wei).
    uint256 public totalInflationRewardsOfferedWei;
    /// Mininal rewards offer value (in wei).
    uint256 public minimalRewardsOfferValueWei;

    /// The RewardManager contract.
    RewardManager public rewardManager;
    /// The FtsoInflationConfigurations contract.
    IFtsoInflationConfigurations public ftsoInflationConfigurations;
    /// The FtsoFeedDecimals contract.
    FtsoFeedDecimals public ftsoFeedDecimals;

    /// Event emitted when the minimal rewards offer value is set.
    event MinimalRewardsOfferValueSet(uint256 valueWei);

    /// Event emitted when a reward offer is received.
    event RewardsOffered(
        // reward epoch id
        uint24 rewardEpochId,
        // feed name - i.e. base/quote symbol
        bytes8 feedName,
        // number of decimals (negative exponent)
        int8 decimals,
        // amount (in wei) of reward in native coin
        uint256 amount,
        // primary band reward share in PPM (parts per million)
        uint24 primaryBandRewardSharePPM,
        // secondary band width in PPM (parts per million) in relation to the median
        uint24 secondaryBandWidthPPM,
        // reward eligibility in PPM (parts per million) in relation to the median of the lead providers
        uint24 rewardEligibilityPPM,
        // list of lead providers
        address[] leadProviders,
        // address that can claim undistributed part of the reward (or burn address)
        address claimBackAddress
    );

    /// Event emitted when inflation rewards are offered.
    event InflationRewardsOffered(
        // reward epoch id
        uint24 rewardEpochId,
        // feed names - i.e. base/quote symbols - multiple of 8 (one feedName is bytes8)
        bytes feedNames,
        // decimals encoded to - multiple of 1 (int8)
        bytes decimals,
        // amount (in wei) of reward in native coin
        uint256 amount,
        // rewards split mode (0 means equally, 1 means random,...)
        uint16 mode,
        // primary band reward share in PPM (parts per million)
        uint24 primaryBandRewardSharePPM,
        // secondary band width in PPM (parts per million) in relation to the median - multiple of 3 (uint24)
        bytes secondaryBandWidthPPMs
    );

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
     * Allows community to offer rewards.
     * @param _nextRewardEpochId The next reward epoch id.
     * @param _offers The list of offers.
     */
    function offerRewards(
        uint24 _nextRewardEpochId,
        Offer[] calldata _offers
    ) external payable mustBalance {
        uint24 currentRewardEpochId = flareSystemManager.getCurrentRewardEpochId();
        require(_nextRewardEpochId == currentRewardEpochId + 1, "not next reward epoch id");
        require(flareSystemManager.currentRewardEpochExpectedEndTs() >
            block.timestamp + flareSystemManager.newSigningPolicyInitializationStartSeconds(),
            "too late for next reward epoch");
        uint256 sumRewardsOfferValues = 0;
        for (uint i = 0; i < _offers.length; ++i) {
            Offer calldata offer = _offers[i];
            require(offer.primaryBandRewardSharePPM <= PPM_MAX, "invalid primaryBandRewardSharePPM value");
            require(offer.secondaryBandWidthPPM <= PPM_MAX, "invalid secondaryBandWidthPPM value");
            require(offer.rewardEligibilityPPM <= PPM_MAX, "invalid rewardEligibilityPPM value");
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
                offer.primaryBandRewardSharePPM,
                offer.secondaryBandWidthPPM,
                offer.rewardEligibilityPPM,
                offer.leadProviders,
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
    function getContractName() external pure override returns (string memory) {
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
        rewardManager = RewardManager(_getContractAddress(_contractNameHashes, _contractAddresses, "RewardManager"));
        ftsoInflationConfigurations = IFtsoInflationConfigurations(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FtsoInflationConfigurations"));
        ftsoFeedDecimals = FtsoFeedDecimals(
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
        for (uint i = 0; i < length; i++) {
            IFtsoInflationConfigurations.FtsoConfiguration memory config = configurations[i];
            uint256 amount = _getRewardsAmount(remainingRewardsAmount, inflationShareSum, config.inflationShare);
            remainingRewardsAmount -= amount;
            inflationShareSum -= config.inflationShare;
            emit InflationRewardsOffered(
                nextRewardEpochId,
                config.feedNames,
                ftsoFeedDecimals.getDecimalsBulk(config.feedNames, nextRewardEpochId),
                amount,
                config.mode,
                config.primaryBandRewardSharePPM,
                config.secondaryBandWidthPPMs
            );
        }
        // send reward amount to reward manager
        totalInflationRewardsOfferedWei += totalRewardsAmount;
        rewardManager.receiveRewards{value: totalRewardsAmount} (nextRewardEpochId, true);
    }

    /**
     * @dev Method that is used in `mustBalance` modifier. It should return expected balance after
     *      triggered function completes (receiving offers, receiving inflation,...).
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
