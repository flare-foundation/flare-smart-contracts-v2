// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../userInterfaces/IFastUpdateIncentiveManager.sol";
import "../../userInterfaces/IFastUpdater.sol";
import "../../userInterfaces/IFastUpdatesConfiguration.sol";
import "../../userInterfaces/IFtsoRewardOffersManager.sol";
import "../../userInterfaces/IIncreaseManager.sol";
import "../../governance/implementation/Governed.sol";
import "../../utils/implementation/AddressUpdatable.sol";

contract FtsoV2Proxy is IFastUpdateIncentiveManager, IFastUpdater,
IFastUpdatesConfiguration, IFtsoRewardOffersManager, Governed, AddressUpdatable {

    IFastUpdateIncentiveManager public fastUpdateIncentiveManager;
    IFastUpdater public fastUpdater;
    IFastUpdatesConfiguration public fastUpdatesConfiguration;
    IFtsoRewardOffersManager public ftsoRewardOffersManager;

    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater
    )
        Governed(_governanceSettings, _initialGovernance) AddressUpdatable(_addressUpdater)
    {
    }

    receive() external payable {
        require(msg.sender == address(fastUpdateIncentiveManager));
    }

    //// IFastUpdateIncentiveManager

    /**
     * @inheritdoc IFastUpdateIncentiveManager
     */
    function offerIncentive(IncentiveOffer calldata _offer) external payable {
        uint256 balanceBefore = address(this).balance - msg.value;
        fastUpdateIncentiveManager.offerIncentive{value: msg.value}(_offer);
        // send what was received from FastUpdateIncentiveManager back to the sender
        (bool success, ) = msg.sender.call{value: address(this).balance - balanceBefore}("");
        require(success, "transfer failed");
    }

    /**
     * @inheritdoc IFastUpdateIncentiveManager
     */
    function getExpectedSampleSize() external view returns (FPA.SampleSize) {
        return fastUpdateIncentiveManager.getExpectedSampleSize();
    }

    /**
     * @inheritdoc IFastUpdateIncentiveManager
     */
    function getPrecision() external view returns (FPA.Precision) {
        return fastUpdateIncentiveManager.getPrecision();
    }

    /**
     * @inheritdoc IFastUpdateIncentiveManager
     */
    function getRange() external view returns (FPA.Range) {
        return fastUpdateIncentiveManager.getRange();
    }

    /**
     * @inheritdoc IFastUpdateIncentiveManager
     */
    function getCurrentSampleSizeIncreasePrice() external view returns (FPA.Fee) {
        return fastUpdateIncentiveManager.getCurrentSampleSizeIncreasePrice();
    }

    /**
     * @inheritdoc IFastUpdateIncentiveManager
     */
    function getScale() external view returns (FPA.Scale) {
        return fastUpdateIncentiveManager.getScale();
    }

    /**
     * @inheritdoc IFastUpdateIncentiveManager
     */
    function getBaseScale() external view returns (FPA.Scale) {
        return fastUpdateIncentiveManager.getBaseScale();
    }

    /**
     * @inheritdoc IFastUpdateIncentiveManager
     */
    function rangeIncreaseLimit() external view returns (FPA.Range) {
        return fastUpdateIncentiveManager.rangeIncreaseLimit();
    }

    /**
     * @inheritdoc IFastUpdateIncentiveManager
     */
    function rangeIncreasePrice() external view returns (FPA.Fee) {
        return fastUpdateIncentiveManager.rangeIncreasePrice();
    }

    /**
     * @inheritdoc IFastUpdateIncentiveManager
     * @dev Not supported - reverts
     */
    function sampleIncreaseLimit() external view returns (FPA.SampleSize) {
        revert("not supported, use FastUpdateIncentiveManager");
    }

    /**
     * @inheritdoc IIncreaseManager
     * @dev Not supported - reverts
     */
    function getIncentiveDuration() external view returns (uint256) {
        revert("not supported, use FastUpdateIncentiveManager");
    }

    //// IFastUpdater
    /**
     * @inheritdoc IFastUpdater
     */
    function fetchCurrentFeeds(uint256[] calldata _indices)
        external view
        returns (
            uint256[] memory,
            int8[] memory,
            uint64
        )
    {
        return fastUpdater.fetchCurrentFeeds(_indices);
    }

    /**
     * @inheritdoc IFastUpdater
     * @dev Not supported - reverts
     */
    function submitUpdates(FastUpdates calldata) external {
        revert("not supported, use FastUpdater");
    }

    /**
     * @inheritdoc IFastUpdater
     * @dev Not supported - reverts
     */
    function fetchAllCurrentFeeds()
        external view
        returns (
            bytes21[] memory,
            uint256[] memory,
            int8[] memory,
            uint64
        )
    {
        revert("not supported, use FastUpdater");
    }

    /**
     * @inheritdoc IFastUpdater
     * @dev Not supported - reverts
     */
    function currentScoreCutoff() external view returns (uint256) {
        revert("not supported, use FastUpdater");
    }

    /**
     * @inheritdoc IFastUpdater
     * @dev Not supported - reverts
     */
    function blockScoreCutoff(uint256) external view returns (uint256) {
        revert("not supported, use FastUpdater");
    }

    /**
     * @inheritdoc IFastUpdater
     * @dev Not supported - reverts
     */
    function currentSortitionWeight(address) external view returns (uint256) {
        revert("not supported, use FastUpdater");
    }

    /**
     * @inheritdoc IFastUpdater
     * @dev Not supported - reverts
     */
    function submissionWindow() external view returns (uint8) {
        revert("not supported, use FastUpdater");
    }

    /**
     * @inheritdoc IFastUpdater
     * @dev Not supported - reverts
     */
    function currentRewardEpochId() external view returns (uint24) {
        revert("not supported, use FastUpdater");
    }

    /**
     * @inheritdoc IFastUpdater
     * @dev Not supported - reverts
     */
    function numberOfUpdates(uint256) external view returns (uint256[] memory) {
        revert("not supported, use FastUpdater");
    }

    /**
     * @inheritdoc IFastUpdater
     * @dev Not supported - reverts
     */
    function numberOfUpdatesInBlock(uint256) external view returns (uint256) {
        revert("not supported, use FastUpdater");
    }

    //// IFastUpdatesConfiguration
    /**
     * @inheritdoc IFastUpdatesConfiguration
     */
    function getFeedConfigurations() external view returns (FeedConfiguration[] memory) {
        return fastUpdatesConfiguration.getFeedConfigurations();
    }

    /**
     * @inheritdoc IFastUpdatesConfiguration
     */
    function getFeedId(uint256 _index) external view returns (bytes21) {
        return fastUpdatesConfiguration.getFeedId(_index);
    }

    /**
     * @inheritdoc IFastUpdatesConfiguration
     */
    function getFeedIndex(bytes21 _feedId) external view returns (uint256) {
        return fastUpdatesConfiguration.getFeedIndex(_feedId);
    }

    /**
     * @inheritdoc IFastUpdatesConfiguration
     */
    function getNumberOfFeeds() external view returns (uint256) {
        return fastUpdatesConfiguration.getNumberOfFeeds();
    }

    /**
     * @inheritdoc IFastUpdatesConfiguration
     */
    function getUnusedIndices() external view returns (uint256[] memory) {
        return fastUpdatesConfiguration.getUnusedIndices();
    }

    /**
     * @inheritdoc IFastUpdatesConfiguration
     * @dev Not supported - reverts
     */
    function getFeedIds() external view returns (bytes21[] memory) {
        revert("not supported, use FastUpdatesConfiguration");
    }

    //// IFtsoFeedVerifier


    //// IFtsoRewardOffersManager
    /**
     * @inheritdoc IFtsoRewardOffersManager
     */
    function offerRewards(uint24 _nextRewardEpochId, Offer[] memory _offers) external payable {
        for (uint256 i = 0; i < _offers.length; i++) {
            if(_offers[i].claimBackAddress == address(0)) {
                // if claimBackAddress is not set, set it to the sender
                _offers[i].claimBackAddress = msg.sender;
            }
        }
        ftsoRewardOffersManager.offerRewards{value: msg.value}(_nextRewardEpochId, _offers);
    }

    /**
     * @inheritdoc IFtsoRewardOffersManager
     */    function minimalRewardsOfferValueWei() external view returns (uint256) {
        return ftsoRewardOffersManager.minimalRewardsOfferValueWei();
    }

    /**
     * Implementation of the AddressUpdatable abstract method.
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal override
    {
        fastUpdateIncentiveManager = IFastUpdateIncentiveManager(
                _getContractAddress(_contractNameHashes, _contractAddresses, "FastUpdateIncentiveManager"));
        fastUpdater = IFastUpdater(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FastUpdater"));
        fastUpdatesConfiguration = IFastUpdatesConfiguration(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FastUpdatesConfiguration"));
        ftsoRewardOffersManager = IFtsoRewardOffersManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FtsoRewardOffersManager"));
    }
}