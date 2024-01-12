// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../protocol/implementation/RewardManager.sol";
import "../../protocol/implementation/RewardOffersManagerBase.sol";
import "../../utils/lib/SafePct.sol";


contract FtsoRewardOffersManager is RewardOffersManagerBase {
    using SafePct for uint256;
    /**
    * Defines a reward offer.
    */
    struct Offer {
        // amount (in wei) of reward in native coin
        uint256 amount;
        // offer/quote symbol (each symbol is 4-byte encoded string with nulls on the right)
        bytes8 feedSymbol;
        // primary band reward share in PPM (parts per million)
        uint24 primaryBandRewardSharePPM;
        // secondary band width in PPM (parts per million) in relation to the median price
        uint24 secondaryBandWidthPPM;
        // reward eligibility in PPM (parts per million) in relation to the median price of the lead providers
        uint24 rewardEligibilityPPM;
        // list of lead providers
        address[] leadProviders;
        // address that can claim undistributed part of the reward (or burn address)
        address claimBackAddress;
    }

    /**
     * Defines Ftso settings for inflation rewards
     */
    struct Ftso {
        // offer/quote symbol (each symbol is 4-byte encoded string with nulls on the right)
        bytes8 feedSymbol;
        // primary band reward share in PPM (parts per million)
        uint24 primaryBandRewardSharePPM;
        // secondary band width in PPM (parts per million) in relation to the median price
        uint24 secondaryBandWidthPPM;
    }

    uint256 public constant DEFAULT_PRICE_DECIMALS = 5;

    /// total rewards offered by inflation (in wei)
    uint128 public totalInflationRewardOffersWei;
    /// mininal offer amount (in wei)
    uint128 public minimalOfferValueWei;
    /// rewards can be offered for up to `maxRewardEpochsInTheFuture` future reward epochs
    uint24 public maxRewardEpochsInTheFuture;
    /// default primary band reward share in PPM (parts per million) in relation to the median price - inflation offers
    uint24 public defaultPrimaryBandRewardSharePPM;

    RewardManager public rewardManager;
    Ftso[] internal inflationSupportedFtsos;
    mapping(bytes8 => uint256) internal decimals;

    event RewardOffered(
        uint24 rewardEpochId, // reward epoch id
        // amount (in wei) of reward in native coin
        uint256 amount,
        // offer/quote symbol (each symbol is 4-byte encoded string with nulls on the right)
        bytes8 feedSymbol,
        // primary band reward share in PPM (parts per million)
        uint24 primaryBandRewardSharePPM,
        // secondary band width in PPM (parts per million) in relation to the median price
        uint24 secondaryBandWidthPPM,
        // reward eligibility in PPM (parts per million) in relation to the median price of the lead providers
        uint24 rewardEligibilityPPM,
        // list of lead providers
        address[] leadProviders,
        // address that can claim undistributed part of the reward (or burn address)
        address claimBackAddress,
        // indicates if offer is triggered by system (inflation)
        bool inflationRewards
    );

    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        uint128 _minimalOfferValueWei,
        uint24 _maxRewardEpochsInTheFuture
    )
        RewardOffersManagerBase(_governanceSettings, _initialGovernance, _addressUpdater)
    {
        require(_maxRewardEpochsInTheFuture > 0, "_maxRewardEpochsInTheFuture zero");
        minimalOfferValueWei = _minimalOfferValueWei;
        maxRewardEpochsInTheFuture = _maxRewardEpochsInTheFuture;
    }

    // This contract does not have any concept of symbols/price feeds and it is
    // entirely up to the clients to keep track of the total amount allocated to
    // them and determine the correct distribution of rewards to voters.
    // Ultimately, of course, only the actual amount of value stored for an
    // epoch's rewards can be claimed.
    //
    function offerRewards(
        uint24 _rewardEpochId,
        Offer[] calldata _offers
    ) external payable mustBalance {
        uint24 currentRewardEpochId = flareSystemManager.getCurrentRewardEpochId();
        require(_rewardEpochId > currentRewardEpochId, "not future reward epoch id");
        require(_rewardEpochId <= currentRewardEpochId + maxRewardEpochsInTheFuture,
            "reward epoch id too far in the future");
        require(_rewardEpochId > currentRewardEpochId + 1 || flareSystemManager.currentRewardEpochExpectedEndTs() >
            block.timestamp + flareSystemManager.newSigningPolicyInitializationStartSeconds(),
            "too late for next reward epoch");
        uint256 sumOfferAmounts = 0;
        for (uint i = 0; i < _offers.length; ++i) {
            Offer calldata offer = _offers[i];
            require(offer.amount >= minimalOfferValueWei, "offer amount too small");
            sumOfferAmounts += offer.amount;
            address claimBackAddress = offer.claimBackAddress;
            if (claimBackAddress == address(0)) {
                claimBackAddress = msg.sender;
            }
            emit RewardOffered(
                _rewardEpochId,
                offer.amount,
                offer.feedSymbol,
                offer.primaryBandRewardSharePPM,
                offer.secondaryBandWidthPPM,
                offer.rewardEligibilityPPM,
                offer.leadProviders,
                claimBackAddress,
                false
            );
        }
        require(sumOfferAmounts == msg.value, "amount offered is not the same as value sent");
        rewardManager.receiveRewards{value: msg.value} (_rewardEpochId, false);
    }

    function setOfferSettings(
        uint128 _minimalOfferValueWei,
        uint24 _maxRewardEpochsInTheFuture
    )
        external onlyGovernance
    {
        require(_maxRewardEpochsInTheFuture > 0, "_maxRewardEpochsInTheFuture zero");
        minimalOfferValueWei = _minimalOfferValueWei;
        maxRewardEpochsInTheFuture = _maxRewardEpochsInTheFuture;
    }

    function addInflationSupportedFtsos(Ftso[] calldata _ftsos) external onlyGovernance {
        for (uint256 i = 0; i < _ftsos.length; i++) {
            inflationSupportedFtsos.push(_ftsos[i]); // TODO check duplicates
        }
    }

    // TODO add remove method

    function setDefaultPrimaryBandRewardSharePPM(uint24 _defaultPrimaryBandRewardSharePPM) external onlyGovernance {
        defaultPrimaryBandRewardSharePPM = _defaultPrimaryBandRewardSharePPM;
    }

    function setDecimals(bytes8 _feedSymbol, uint256 _decimals) external onlyGovernance {
        decimals[_feedSymbol] = _decimals + 1; // to separate from 0
    }

    function getDecimals(bytes8 _feedSymbol) external view returns (uint256 _decimals) {
        _decimals = decimals[_feedSymbol];
        if (_decimals > 0) {
            _decimals -= 1;
        } else {
            _decimals = DEFAULT_PRICE_DECIMALS;
        }
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
        flareSystemManager = FlareSystemManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemManager"));
        rewardManager = RewardManager(_getContractAddress(_contractNameHashes, _contractAddresses, "RewardManager"));
    }

    /**
     * @dev Method that is called when new daily inflation is authorized.
     */
    function _setDailyAuthorizedInflation(uint256 _toAuthorizeWei) internal override {
        // all authorized inflation should be forwarded to the reward manager
        rewardManager.addDailyAuthorizedInflation(_toAuthorizeWei);
    }

    // beginning of the current reward epoch
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
        uint256 availableFunds = (totalInflationReceivedWei - totalInflationRewardOffersWei)
            .mulDiv(intervalEnd - intervalStart, _rewardEpochDurationSeconds);
        // emit offers
        uint24 nextRewardEpochId = _currentRewardEpochId + 1;
        uint256 length = inflationSupportedFtsos.length;
        uint256 amountWei = availableFunds / length;
        address burnAddress = BURN_ADDRESS; // load in memory
        uint24 defaultPrimarySharePPM = defaultPrimaryBandRewardSharePPM; // load in memory
        address[] memory leadProviders = new address[](0);
        for (uint i = 0; i < length; ++i) {
            Ftso storage ftso = inflationSupportedFtsos[i];
            emit RewardOffered(
                nextRewardEpochId,
                amountWei,
                ftso.feedSymbol,
                ftso.primaryBandRewardSharePPM == 0 ? defaultPrimarySharePPM : ftso.primaryBandRewardSharePPM,
                ftso.secondaryBandWidthPPM,
                0,
                leadProviders,
                burnAddress,
                true
            );
        }
        // send reward amount to reward manager
        uint128 rewardAmount = uint128(amountWei * length);
        rewardManager.receiveRewards{value: rewardAmount} (nextRewardEpochId, true);
        totalInflationRewardOffersWei += rewardAmount;
    }

    /**
     * @dev Method that is used in `mustBalance` modifier. It should return expected balance after
     *      triggered function completes (receiving offers, receiving inflation,...).
     */
    function _getExpectedBalance() internal view override returns(uint256 _balanceExpectedWei) {
        return totalInflationReceivedWei - totalInflationRewardOffersWei;
    }
}
