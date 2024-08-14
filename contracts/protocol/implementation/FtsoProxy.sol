// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "flare-smart-contracts/contracts/userInterfaces/IFtso.sol";
import "../../userInterfaces/IFastUpdaterView.sol";
import "../../userInterfaces/IFastUpdatesConfiguration.sol";
import "../../userInterfaces/IRandomProvider.sol";
import "../../userInterfaces/IFlareSystemsManager.sol";
import "../../protocol/interface/IIFtsoManagerProxy.sol";

/**
 * FtsoProxy is a compatibility contract replacing Ftso contract
 * that is used for proxying data from V2 contracts.
 */
contract FtsoProxy is IFtso {

    IFastUpdaterView public immutable fastUpdater;
    IFastUpdatesConfiguration public immutable fastUpdatesConfiguration;
    IFlareSystemsManager public immutable flareSystemsManager;
    IRandomProvider public immutable submission;
    /// Address of the `FtsoManager` contract.
    address immutable public ftsoManager;

    /// @inheritdoc IFtso
    string public symbol;

    uint8 public immutable randomNumberProtocolId;
    bytes21 public feedId;

    /// Number of decimal places in an asset's USD price.
    /// Actual USD price is the integer value divided by 10^`ASSET_PRICE_USD_DECIMALS`
    // solhint-disable-next-line var-name-mixedcase
    int256 public constant ASSET_PRICE_USD_DECIMALS = 5;

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
        fastUpdater = IFastUpdaterView(_ftsoManager.fastUpdater());
        fastUpdatesConfiguration = IFastUpdatesConfiguration(
            _ftsoManager.fastUpdatesConfiguration()
        );
        flareSystemsManager = IFlareSystemsManager(_ftsoManager.flareSystemsManager());
        submission = IRandomProvider(_ftsoManager.submission());
        ftsoManager = address((_ftsoManager));
    }

    /**
     * @inheritdoc IFtso
     */
    function active() external view returns (bool) {
        return true;
    }

    /**
     * @inheritdoc IFtso
     */
    function getCurrentEpochId() external view returns (uint256) {
        return flareSystemsManager.getCurrentVotingEpochId();
    }

    /**
     * @inheritdoc IFtso
     */
    function getEpochId(uint256 _timestamp) external view returns (uint256) {
        return (_timestamp - flareSystemsManager.firstVotingRoundStartTs()) /
            flareSystemsManager.votingEpochDurationSeconds();
    }

    /**
     * @inheritdoc IFtso
     * @dev Deprecated - reverts
     */
    function getRandom(uint256) external view returns (uint256) {
        revert("not supported");
    }

    /**
     * @inheritdoc IFtso
     * @dev Deprecated - reverts
     */
    function getEpochPrice(uint256) external view returns (uint256) {
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
        _firstEpochStartTs = flareSystemsManager.firstVotingRoundStartTs();
        _submitPeriodSeconds = flareSystemsManager.votingEpochDurationSeconds();
        _revealPeriodSeconds = _submitPeriodSeconds / 2;
    }

    /**
     * @inheritdoc IFtso
     * @dev Deprecated - reverts
     */
    function getEpochPriceForVoter(uint256, address) external view returns (uint256) {
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
        _decimals = uint256(ASSET_PRICE_USD_DECIMALS);
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
    function getCurrentPriceFromTrustedProviders() external view returns (uint256, uint256) {
        revert("not supported");
    }

    /**
     * @inheritdoc IFtso
     * @dev Deprecated - reverts
     */
    function getCurrentPriceWithDecimalsFromTrustedProviders() external view returns (uint256, uint256, uint256) {
        revert("not supported");
    }

    /**
     * @inheritdoc IFtso
     */
    function getCurrentRandom() external view returns (uint256 _currentRandom) {
        (_currentRandom, ) = submission.getCurrentRandomWithQuality();
    }

    function _getCurrentPrice() internal view returns (uint256 _price, uint64 _timestamp) {
        uint256[] memory indices = new uint256[](1);
        indices[0] = fastUpdatesConfiguration.getFeedIndex(feedId);
        uint256[] memory values;
        int8[] memory decimals;
        (values, decimals, _timestamp) = fastUpdater.fetchCurrentFeeds(indices);
        _price = values[0];
        int256 decimalsDiff = ASSET_PRICE_USD_DECIMALS - decimals[0];
        if (decimalsDiff < 0) {
            _price = _price / (10 ** uint256(-decimalsDiff));
        } else {
            _price = _price * (10 ** uint256(decimalsDiff));
        }
    }

}