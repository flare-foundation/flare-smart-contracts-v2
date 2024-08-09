// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../governance/implementation/Governed.sol";
import "../../utils/implementation/AddressUpdatable.sol";
import "../../userInterfaces/IFastUpdatesConfiguration.sol";
import "../interface/IIFeeCalculator.sol";

/**
 * @title FeeCalculator
*/
contract FeeCalculator is Governed, AddressUpdatable, IIFeeCalculator {

    /// The FastUpdatesConfiguration contract.
    IFastUpdatesConfiguration public fastUpdatesConfiguration;

    mapping(uint8 category => uint256) public defaultFee;
    mapping(bytes21 feedId => uint256) internal feedFee; // fee + 1, to distinguish from 0

    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater
    )
        Governed(_governanceSettings, _initialGovernance) AddressUpdatable(_addressUpdater)
    {
    }

    function setCategoriesDefaultFees(
        uint8[] memory _categories,
        uint256[] memory _fees
    )
        external onlyGovernance
    {
        require(_categories.length == _fees.length, "lengths mismatch");
        for (uint256 i = 0; i < _categories.length; i++) {
            defaultFee[_categories[i]] = _fees[i];
            emit DefaultFeeSet(_categories[i], _fees[i]);
        }
    }

    // set fee for feeds that override the default fee for feed category
    function setFeedsFees(
        bytes21[] memory _feedIds,
        uint256[] memory _fees
    )
        external onlyGovernance
    {
        require(_feedIds.length == _fees.length, "lengths mismatch");
        for (uint256 i = 0; i < _feedIds.length; i++) {
            feedFee[_feedIds[i]] = _fees[i] + 1; // to distinguish from 0
            emit FeeSet(_feedIds[i], _fees[i]);
        }
    }

    function removeFeedsFees(bytes21[] memory _feedIds) external onlyGovernance {
        for (uint256 i = 0; i < _feedIds.length; i++) {
            delete feedFee[_feedIds[i]];
            emit FeeRemoved(_feedIds[i]);
        }
    }

    function calculateFee(uint256[] memory _indices) external view returns (uint256 _fee) {
        for (uint256 i = 0; i < _indices.length; i++) {
            bytes21 feedId = fastUpdatesConfiguration.getFeedId(_indices[i]);
            if (feedFee[feedId] > 0) {
                _fee += feedFee[feedId] - 1;
            } else {
                _fee += defaultFee[uint8(feedId[0])];
            }
        }
    }

    function getFeedFee(bytes21 _feedId) external view returns (uint256 _fee) {
        _fee = feedFee[_feedId];
        require(_fee != 0, "overriding fee not set; category default fee will be used");
        // todo revert or return default fee for category??
        _fee--;
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