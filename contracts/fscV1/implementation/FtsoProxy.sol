// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "flare-smart-contracts/contracts/userInterfaces/IFtso.sol";
import "../../userInterfaces/IFastUpdaterView.sol";
import "../../userInterfaces/IFastUpdatesConfiguration.sol";
import "../../userInterfaces/IRelay.sol";
import "../../userInterfaces/IFlareSystemsManager.sol";
import "../../protocol/interface/IIFtsoManagerProxy.sol";

/**
 * FtsoProxy is a compatibility contract replacing Ftso contract
 * that is used for proxying data from V2 contracts.
 */
contract FtsoProxy is IFtso {

    /// Address of the `FtsoManager` contract.
    IIFtsoManagerProxy immutable public ftsoManager;

    /// @inheritdoc IFtso
    string public symbol;

    uint8 public immutable randomNumberProtocolId;
    bytes21 public feedId;

    /// Number of decimal places in an asset's USD price.
    /// Actual USD price is the integer value divided by 10^`ASSET_PRICE_USD_DECIMALS`
    uint256 public constant ASSET_PRICE_USD_DECIMALS = 5;

    constructor(
        string memory _symbol,
        bytes21 _feedId,
        uint8 _randomNumberProtocolId,
        IIFtsoManagerProxy _ftsoManager
    )
    {
        symbol = _symbol;
        feedId = _feedId;
        randomNumberProtocolId = _randomNumberProtocolId;
        ftsoManager = _ftsoManager;
    }

    /**
     * @inheritdoc IFtso
     */
    function active() external pure returns (bool) {
        return true;
    }

    /**
     * @inheritdoc IFtso
     */
    function getCurrentEpochId() external view returns (uint256) {
        return IFlareSystemsManager(ftsoManager.flareSystemsManager()).getCurrentVotingEpochId();
    }

    /**
     * @inheritdoc IFtso
     */
    function getEpochId(uint256 _timestamp) external view returns (uint256) {
        IFlareSystemsManager flareSystemsManager = IFlareSystemsManager(ftsoManager.flareSystemsManager());
        return (_timestamp - flareSystemsManager.firstVotingRoundStartTs()) /
            flareSystemsManager.votingEpochDurationSeconds();
    }

    /**
     * @inheritdoc IFtso
     */
    function getRandom(uint256 _votingRoundId) external view returns (uint256 _randomNumber) {
        (_randomNumber, , ) = IRelay(ftsoManager.relay()).getRandomNumberHistorical(_votingRoundId);
    }

    /**
     * @inheritdoc IFtso
     * @dev Deprecated - reverts
     */
    function getEpochPrice(uint256) external pure returns (uint256) {
        revert("not supported");
    }

    /**
     * @inheritdoc IFtso
     */
    function getPriceEpochData() external view
        returns (
            uint256 _epochId,
            uint256 _epochSubmitEndTime,
            uint256 _epochRevealEndTime,
            uint256 _votePowerBlock,
            bool _fallbackMode
        )
    {
        IFlareSystemsManager flareSystemsManager = IFlareSystemsManager(ftsoManager.flareSystemsManager());
        uint256 votingEpochDuration = flareSystemsManager.votingEpochDurationSeconds();
        _epochId = flareSystemsManager.getCurrentVotingEpochId();
        _epochSubmitEndTime = flareSystemsManager.firstVotingRoundStartTs() + (_epochId + 1) * votingEpochDuration;
        _epochRevealEndTime = _epochSubmitEndTime + votingEpochDuration / 2;
        _votePowerBlock = flareSystemsManager.getVotePowerBlock(flareSystemsManager.getCurrentRewardEpoch());
        _fallbackMode = false;
    }

    /**
     * @inheritdoc IFtso
     */
    function getPriceEpochConfiguration() external view
        returns (
            uint256 _firstEpochStartTs,
            uint256 _submitPeriodSeconds,
            uint256 _revealPeriodSeconds
        )
    {
        IFlareSystemsManager flareSystemsManager = IFlareSystemsManager(ftsoManager.flareSystemsManager());
        _firstEpochStartTs = flareSystemsManager.firstVotingRoundStartTs();
        _submitPeriodSeconds = flareSystemsManager.votingEpochDurationSeconds();
        _revealPeriodSeconds = _submitPeriodSeconds / 2;
    }

    /**
     * @inheritdoc IFtso
     * @dev Deprecated - reverts
     */
    function getEpochPriceForVoter(uint256, address) external pure returns (uint256) {
        revert("not supported");
    }

    /**
     * @inheritdoc IFtso
     */
    function getCurrentPrice() external view returns (uint256, uint256) {
        return _getCurrentPrice();
    }

    /**
     * @inheritdoc IFtso
     */
    function getCurrentPriceWithDecimals()
        external view
        returns (
            uint256 _value,
            uint256 _timestamp,
            uint256 _decimals
        )
    {
        (_value, _timestamp) = _getCurrentPrice();
        _decimals = ASSET_PRICE_USD_DECIMALS;
    }


    /**
     * @inheritdoc IFtso
     */
    function getCurrentPriceDetails()
        external view
        returns (
            uint256,
            uint256,
            PriceFinalizationType,
            uint256,
            PriceFinalizationType
        )
    {
        (uint256 price, uint256 timestamp) = _getCurrentPrice();
        return (
            price,
            timestamp,
            PriceFinalizationType.WEIGHTED_MEDIAN,
            timestamp,
            PriceFinalizationType.WEIGHTED_MEDIAN
        );
    }

    /**
     * @inheritdoc IFtso
     * @dev Deprecated - reverts
     */
    function getCurrentPriceFromTrustedProviders() external pure returns (uint256, uint256) {
        revert("not supported");
    }

    /**
     * @inheritdoc IFtso
     * @dev Deprecated - reverts
     */
    function getCurrentPriceWithDecimalsFromTrustedProviders() external pure returns (uint256, uint256, uint256) {
        revert("not supported");
    }

    /**
     * @inheritdoc IFtso
     */
    function getCurrentRandom() external view returns (uint256 _currentRandom) {
        (_currentRandom, , ) = IRelay(ftsoManager.relay()).getRandomNumber();
    }

    function _getCurrentPrice() internal view returns (uint256 _price, uint64 _timestamp) {
        uint256[] memory indices = new uint256[](1);
        indices[0] = IFastUpdatesConfiguration(ftsoManager.fastUpdatesConfiguration()).getFeedIndex(feedId);
        uint256[] memory values;
        int8[] memory decimals;
        (values, decimals, _timestamp) = IFastUpdaterView(ftsoManager.fastUpdater()).fetchCurrentFeeds(indices);
        _price = values[0];
        int256 decimalsDiff = int256(ASSET_PRICE_USD_DECIMALS) - decimals[0];
        if (decimalsDiff < 0) {
            _price = _price / (10 ** uint256(-decimalsDiff));
        } else {
            _price = _price * (10 ** uint256(decimalsDiff));
        }
    }

}