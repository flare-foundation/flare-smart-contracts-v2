// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../governance/implementation/Governed.sol";
import "./InflationReceiver.sol";
import "./FlareSystemManager.sol";
import "./RewardManager.sol";


contract FtsoRewardOffersManager is Governed, InflationReceiver {
    /**
    * Defines a reward offer in native coin or ERC20 token.
    */
    struct Offer {
        uint256 amount; // amount of reward in native coin or ERC20 token
        address currencyAddress; // zero address for native currency or address of ERC20 token
        bytes4 offerSymbol; // offer symbol of the reward feed (4-byte encoded string with nulls on the right)
        bytes4 quoteSymbol; // quote symbol of the reward feed (4-byte encoded string with nulls on the right)
        address[] leadProviders; // list of lead providers
        // reward belt in PPM (parts per million) in relation to the median price of the lead providers.
        uint256 rewardBeltPPM;
        // elastic band width in PPM (parts per million) in relation to the median price.
        uint256 elasticBandWidthPPM;
        // Each offer defines IQR and PCT share in PPM (parts per million). The sum of all offers must be 1M.
        uint256 iqrSharePPM;
        uint256 pctSharePPM;
        address remainderClaimer; // address that can claim undistributed part of the reward
    }

    uint128 public totalInflationRewardOffersWei;
    uint128 public minimalOfferValueWei;
    uint64 public maxRewardEpochsInTheFuture;
    uint64 public lastOfferBeforeRewardEpochEndSeconds;
    uint64 public lastRewardEpochIdWithInflationRewardOffers;

    FlareSystemManager public flareSystemManager;
    RewardManager public rewardManager;

    event RewardOffered(
        uint256 rewardEpochId, // reward epoch id
        uint256 amount, // amount of reward in native coin
        address currencyAddress, // zero address for native currency or address of ERC20 token
        bytes4 offerSymbol, // offer symbol of the reward feed (4-byte encoded string with nulls on the right)
        bytes4 quoteSymbol, // quote symbol of the reward feed (4-byte encoded string with nulls on the right)
        address[] leadProviders, // list of trusted providers
        // reward belt in PPM (parts per million) in relation to the median price of the trusted providers.
        uint256 rewardBeltPPM,
        // elastic band width in PPM (parts per million) in relation to the median price.
        uint256 elasticBandWidthPPM,
        // Each offer defines IQR and PCT share in PPM (parts per million). The sum of all offers must be 1M.
        uint256 iqrSharePPM,
        uint256 pctSharePPM,
        address remainderClaimer,  // address that can claim undistributed part of the reward
        bool inflationRewards // indicates if offer is triggered by system (inflation)
    );

    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        uint128 _minimalOfferValueWei,
        uint64 _maxRewardEpochsInTheFuture,
        uint64 _lastOfferBeforeRewardEpochEndSeconds
    )
        Governed(_governanceSettings, _initialGovernance) InflationReceiver(_addressUpdater)
    {
        minimalOfferValueWei = _minimalOfferValueWei;
        maxRewardEpochsInTheFuture = _maxRewardEpochsInTheFuture;
        lastOfferBeforeRewardEpochEndSeconds = _lastOfferBeforeRewardEpochEndSeconds;
    }

    // This contract does not have any concept of symbols/price feeds and it is
    // entirely up to the clients to keep track of the total amount allocated to
    // them and determine the correct distribution of rewards to voters.
    // Ultimately, of course, only the actual amount of value stored for an
    // epoch's rewards can be claimed.
    //
    function offerRewards(
        uint32 _rewardEpochId,
        Offer[] calldata _offers
    ) external payable mustBalance {
        uint32 currentRewardEpochId = flareSystemManager.getCurrentRewardEpochId();
        require(_rewardEpochId > currentRewardEpochId, "not future reward epoch id");
        require(_rewardEpochId <= currentRewardEpochId + maxRewardEpochsInTheFuture,
            "reward epoch id too far in the future");
        require(_rewardEpochId > currentRewardEpochId + 1 || flareSystemManager.currentRewardEpochExpectedEndTs() >=
            block.timestamp + lastOfferBeforeRewardEpochEndSeconds, "too late for next reward epoch");
        uint256 sumOfferAmounts = 0;
        for (uint i = 0; i < _offers.length; ++i) {
            Offer calldata offer = _offers[i];
            require(offer.amount >= minimalOfferValueWei, "offer amount too small");
            require(offer.iqrSharePPM + offer.pctSharePPM == 1000000, "iqrSharePPM + pctSharePPM != 1000000");
            sumOfferAmounts += offer.amount;
            address remainderClaimer = offer.remainderClaimer;
            if (remainderClaimer == address(0)) {
                remainderClaimer = msg.sender;
            }
            emit RewardOffered(
                _rewardEpochId,
                offer.amount,
                offer.currencyAddress,
                offer.offerSymbol,
                offer.quoteSymbol,
                offer.leadProviders,
                offer.rewardBeltPPM,
                offer.elasticBandWidthPPM,
                offer.iqrSharePPM,
                offer.pctSharePPM,
                remainderClaimer,
                false
            );
        }
        require(sumOfferAmounts == msg.value, "amount offered is not the same as value sent");
        rewardManager.receiveRewards{value: msg.value} (_rewardEpochId, false);
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
        flareSystemManager = FlareSystemManager(_getContractAddress(
            _contractNameHashes, _contractAddresses, "FlareSystemManager"));
        rewardManager = RewardManager(_getContractAddress(_contractNameHashes, _contractAddresses, "RewardManager"));
        inflation = _getContractAddress(_contractNameHashes, _contractAddresses, "Inflation");
    }


    /**
     * @dev Method that is called when new inflation is received.
     */
    function _receiveInflation() internal override {
        uint32 currentRewardEpochId = flareSystemManager.getCurrentRewardEpochId();
        if (currentRewardEpochId > lastRewardEpochIdWithInflationRewardOffers) {
            // TODO
        }
    }

    /**
     * @dev Method that is used in `mustBalance` modifier. It should return expected balance after
     *      triggered function completes (receiving offers, receiving inflation,...).
     */
    function _getExpectedBalance() internal view override returns(uint256 _balanceExpectedWei) {
        return totalInflationReceivedWei - totalInflationRewardOffersWei;
    }
}
