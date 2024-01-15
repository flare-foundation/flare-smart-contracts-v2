// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../protocol/implementation/RewardManager.sol";
import "../../protocol/implementation/RewardOffersManagerBase.sol";
import "../interface/IFtsoInflationConfigurations.sol";
import "../../utils/lib/SafePct.sol";


contract FtsoRewardOffersManager is RewardOffersManagerBase {
    using SafePct for uint256;

    /**
    * Defines a reward offer.
    */
    struct Offer {
        // amount (in wei) of reward in native coin
        uint120 amount;
        // offer name - i.e. base/quote symbol
        bytes8 name;
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

    struct Decimals {               // used for storing data provider fee percentage settings
        int8 value;                 // number of decimals (negative exponent)
        uint24 validFromEpochId;    // id of the reward epoch from which the value is valid
    }

    uint256 internal constant PPM_MAX = 1e6;
    uint8 internal constant INT8_MIN = uint8(-type(int8).min);

    int8 public immutable defaultDecimals; // default value for number of decimals
    uint24 public immutable decimalsUpdateOffset; // decimals update timelock measured in reward epochs
    mapping(bytes8 => Decimals[]) internal decimals;

    /// total rewards offered by inflation (in wei)
    uint256 public totalInflationRewardsOfferedWei;
    /// mininal rewards offer (in wei)
    uint256 public minimalRewardsOfferValueWei;

    RewardManager public rewardManager;
    IFtsoInflationConfigurations public ftsoInflationConfigurations;

    event MinimalRewardsOfferValueSet(uint256 valueWei);

    event RewardsOffered(
        // reward epoch id
        uint24 rewardEpochId,
        // name of the offer - i.e. base/quote symbol
        bytes8 name,
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

    event InflationRewardsOffered(
        // reward epoch id
        uint24 rewardEpochId,
        // offer names - i.e. base/quote symbols - multiple of 8 (one name)
        bytes names,
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

    event DecimalsChanged(bytes8 name, int8 decimals, uint24 rewardEpochId);

    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        uint128 _minimalRewardsOfferValueWei,
        int8 _defaultDecimals,
        uint24 _decimalsUpdateOffset
    )
        RewardOffersManagerBase(_governanceSettings, _initialGovernance, _addressUpdater)
    {
        require(_decimalsUpdateOffset > 1, "offset too small");
        minimalRewardsOfferValueWei = _minimalRewardsOfferValueWei;
        defaultDecimals = _defaultDecimals;
        decimalsUpdateOffset = _decimalsUpdateOffset;
        emit MinimalRewardsOfferValueSet(_minimalRewardsOfferValueWei);
    }

    // This contract does not have any concept of names and it is
    // entirely up to the clients to keep track of the total amount allocated to
    // them and determine the correct distribution of rewards to voters.
    // Ultimately, of course, only the actual amount of value stored for an
    // epoch's rewards can be claimed.
    //
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
                offer.name,
                _getDecimals(offer.name, _nextRewardEpochId),
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

    function setMinimalRewardsOfferValue(uint128 _minimalRewardsOfferValueWei) external onlyGovernance {
        minimalRewardsOfferValueWei = _minimalRewardsOfferValueWei;
        emit MinimalRewardsOfferValueSet(_minimalRewardsOfferValueWei);
    }

    /**
     * Allows governance to set (or update last) decimal for given name.
     * @param _name name
     * @param _decimals number of decimals (negative exponent)
     */
    function setDecimals(bytes8 _name, int8 _decimals) external onlyGovernance {
        uint24 rewardEpochId = flareSystemManager.getCurrentRewardEpochId() + decimalsUpdateOffset;
        Decimals[] storage decimalsForName = decimals[_name];

        // determine whether to update the last setting or add a new one
        uint256 position = decimalsForName.length;
        if (position > 0) {
            // do not allow updating the settings in the past
            assert(rewardEpochId >= decimalsForName[position - 1].validFromEpochId);

            if (rewardEpochId == decimalsForName[position - 1].validFromEpochId) {
                // update
                position = position - 1;
            }
        }
        if (position == decimalsForName.length) {
            // add
            decimalsForName.push();
        }

        // apply setting
        decimalsForName[position].value = _decimals;
        decimalsForName[position].validFromEpochId = rewardEpochId;

        emit DecimalsChanged(_name, _decimals, rewardEpochId);
    }

    /**
     * Returns current decimals set for `_name`
     * @param _name                 name
     */
    function getCurrentDecimals(bytes8 _name) external view returns (int8) {
        return _getDecimals(_name, flareSystemManager.getCurrentRewardEpochId());
    }

    /**
     * Returns the decimals of `_name` for given reward epoch id
     * @param _name                 name
     * @param _rewardEpochId        reward epoch id
     * **NOTE:** decimals might still change for future reward epoch ids
     */
    function getDecimals(
        bytes8 _name,
        uint256 _rewardEpochId
    )
        external view
        returns (int8)
    {
        return _getDecimals(_name, _rewardEpochId);
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
        ftsoInflationConfigurations = IFtsoInflationConfigurations(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FtsoInflationConfigurations"));
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
        uint256 totalRewardsAmount = (totalInflationReceivedWei - totalInflationRewardsOfferedWei)
            .mulDiv(intervalEnd - intervalStart, _rewardEpochDurationSeconds);
        // emit offers
        uint24 nextRewardEpochId = _currentRewardEpochId + 1;
        IFtsoInflationConfigurations.FtsoConfiguration[] memory configurations =
            ftsoInflationConfigurations.getFtsoConfigurations();

        uint256 length = configurations.length;
        uint256 inflationShareSum = 0;
        for (uint256 i = 0; i < length; i++) {
            inflationShareSum += configurations[i].inflationShare;
        }
        if (length == 0 || inflationShareSum == 0) {
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
                config.names,
                _getDecimalsBulk(config.names, nextRewardEpochId),
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
     * Returns decimals setting for `_name` at `_rewardEpochId`.
     * @param _name                 name for offer
     * @param _rewardEpochId        reward epoch id
     */
    function _getDecimals(
        bytes8 _name,
        uint256 _rewardEpochId
    )
        internal view
        returns (int8)
    {
        Decimals[] storage decimalsForName = decimals[_name];
        uint256 index = decimalsForName.length;
        while (index > 0) {
            index--;
            if (_rewardEpochId >= decimalsForName[index].validFromEpochId) {
                return decimalsForName[index].value;
            }
        }
        return defaultDecimals;
    }

    /**
     * Returns decimals setting for `_names` at `_rewardEpochId`.
     * @param _names                concatenated names (each name bytes8)
     * @param _rewardEpochId        reward epoch id
     */
    function _getDecimalsBulk(
        bytes memory _names,
        uint256 _rewardEpochId
    )
        internal view
        returns (bytes memory _decimals)
    {
        //slither-disable-next-line weak-prng
        assert(_names.length % 8 == 0);
        uint256 length = _names.length / 8;
        _decimals = new bytes(length);
        bytes memory name = new bytes(8);
        for (uint256 i = 0; i < length; i++) {
            for (uint256 j = 0; j < 8; j++) {
                name[j] = _names[8 * i + j];
            }
            int8 dec = _getDecimals(bytes8(name), _rewardEpochId);
            _decimals[i] = bytes1(uint8(dec));
        }
    }

    /**
     * @dev Method that is used in `mustBalance` modifier. It should return expected balance after
     *      triggered function completes (receiving offers, receiving inflation,...).
     */
    function _getExpectedBalance() internal view override returns(uint256 _balanceExpectedWei) {
        return totalInflationReceivedWei - totalInflationRewardsOfferedWei;
    }

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
