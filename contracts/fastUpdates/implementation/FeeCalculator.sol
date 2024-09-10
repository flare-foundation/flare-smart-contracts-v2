// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../governance/implementation/Governed.sol";
import "../../utils/implementation/AddressUpdatable.sol";
import "../../userInterfaces/IFastUpdatesConfiguration.sol";
import "../interface/IIFeeCalculator.sol";

/**
 * FeeCalculator is a contract that calculates fees for fetching current feeds' data from FastUpdater contract.
 */
contract FeeCalculator is Governed, AddressUpdatable, IIFeeCalculator {

    /// The FastUpdatesConfiguration contract.
    IFastUpdatesConfiguration public fastUpdatesConfiguration;

    mapping(uint8 category => uint256) internal categoryFee; // fee + 1, to distinguish from 0
    mapping(bytes21 feedId => uint256) internal feedFee; // fee + 1, to distinguish from 0
    /// Default fee for fetching feeds' data.
    uint256 public defaultFee;

    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        uint256 _defaultFee
    )
        Governed(_governanceSettings, _initialGovernance) AddressUpdatable(_addressUpdater)
    {
        _setDefaultFee(_defaultFee);
    }

    /**
     * @inheritdoc IIFeeCalculator
     */
    function setDefaultFee(uint256 _fee) external onlyGovernance {
        _setDefaultFee(_fee);
    }

    /**
     * @inheritdoc IIFeeCalculator
     */
    function setCategoriesFees(
        uint8[] memory _categories,
        uint256[] memory _fees
    )
        external onlyGovernance
    {
        require(_categories.length == _fees.length, "lengths mismatch");
        for (uint256 i = 0; i < _categories.length; i++) {
            categoryFee[_categories[i]] = _fees[i] + 1; // to distinguish from 0
            emit CategoryFeeSet(_categories[i], _fees[i]);
        }
    }

    /**
     * @inheritdoc IIFeeCalculator
     */
    function removeCategoriesFees(uint8[] memory _categories) external onlyGovernance {
        for (uint256 i = 0; i < _categories.length; i++) {
            delete categoryFee[_categories[i]];
            emit CategoryFeeRemoved(_categories[i]);
        }
    }

    /**
     * @inheritdoc IIFeeCalculator
     */
    function setFeedsFees(
        bytes21[] memory _feedIds,
        uint256[] memory _fees
    )
        external onlyGovernance
    {
        require(_feedIds.length == _fees.length, "lengths mismatch");
        for (uint256 i = 0; i < _feedIds.length; i++) {
            feedFee[_feedIds[i]] = _fees[i] + 1; // to distinguish from 0
            emit FeedFeeSet(_feedIds[i], _fees[i]);
        }
    }

    /**
     * @inheritdoc IIFeeCalculator
     */
    function removeFeedsFees(bytes21[] memory _feedIds) external onlyGovernance {
        for (uint256 i = 0; i < _feedIds.length; i++) {
            delete feedFee[_feedIds[i]];
            emit FeedFeeRemoved(_feedIds[i]);
        }
    }

    /**
     * @inheritdoc IFeeCalculator
     */
    function calculateFeeByIndices(uint256[] memory _indices) external view returns (uint256 _fee) {
        for (uint256 i = 0; i < _indices.length; i++) {
            bytes21 feedId = fastUpdatesConfiguration.getFeedId(_indices[i]);
            if (feedFee[feedId] > 0) {
                _fee += feedFee[feedId] - 1;
            } else if(categoryFee[uint8(feedId[0])] > 0) {
                _fee += categoryFee[uint8(feedId[0])] - 1;
            } else {
                _fee += defaultFee;
            }
        }
    }

    /**
     * @inheritdoc IFeeCalculator
     */
    function calculateFeeByIds(bytes21[] memory _feedIds) external view returns (uint256 _fee) {
        for (uint256 i = 0; i < _feedIds.length; i++) {
            bytes21 feedId = _feedIds[i];
            if (feedFee[feedId] > 0) {
                _fee += feedFee[feedId] - 1;
            } else if(categoryFee[uint8(feedId[0])] > 0) {
                _fee += categoryFee[uint8(feedId[0])] - 1;
            } else {
                _fee += defaultFee;
            }
        }
    }

    /**
     * @inheritdoc IIFeeCalculator
     */
    function getFeedFee(bytes21 _feedId) external view returns (uint256 _fee) {
        _fee = feedFee[_feedId];
        require(_fee != 0, "feed fee not set; category feed or default fee will be used");
        _fee--;
    }

    /**
     * @inheritdoc IIFeeCalculator
     */
    function getCategoryFee(uint8 _category) external view returns (uint256 _fee) {
        _fee = categoryFee[_category];
        require(_fee != 0, "category fee not set; default fee will be used");
        _fee--;
    }

    function _setDefaultFee(uint256 _fee) internal {
        require(_fee > 0, "default fee zero");
        defaultFee = _fee;
        emit DefaultFeeSet(_fee);
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
        fastUpdatesConfiguration = IFastUpdatesConfiguration(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FastUpdatesConfiguration"));
    }

}