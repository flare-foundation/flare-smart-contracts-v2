// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "flare-smart-contracts/contracts/userInterfaces/IFlareContractRegistry.sol";
import "../../userInterfaces/IFeeCalculator.sol";
import "../../userInterfaces/IFastUpdater.sol";
import "../../userInterfaces/IFastUpdatesConfiguration.sol";
import "../interface/IICustomFeed.sol";

interface ISFlr {
    function getPooledFlrByShares(uint256) external view returns (uint256);
}

/**
 * SFlrCustomFeed contract.
 * The contract is used to calculate the sFLR custom feed using the reference feed (FLR) and the sFLR contract.
 */
contract SFlrCustomFeed is IICustomFeed {

    /// The feed id.
    bytes21 public immutable feedId;

    /// The reference feed id.
    bytes21 public immutable referenceFeedId;

    /// The FlareContractRegistry contract.
    IFlareContractRegistry public immutable flareContractRegistry;

    /// The SFlr contract.
    ISFlr public immutable sFlr;

    /**
     * Constructor.
     */
    constructor(
        bytes21 _feedId,
        bytes21 _referenceFeedId,
        IFlareContractRegistry _flareContractRegistry,
        ISFlr _sFlr
    )
    {
        feedId = _feedId;
        referenceFeedId = _referenceFeedId;
        flareContractRegistry = _flareContractRegistry;
        sFlr = _sFlr;
    }

    /**
     * @inheritdoc IICustomFeed
     */
    function getCurrentFeed() external payable returns (uint256 _value, int8 _decimals, uint64 _timestamp) {
        IFastUpdatesConfiguration fastUpdatesConfiguration =
            IFastUpdatesConfiguration(flareContractRegistry.getContractAddressByName("FastUpdatesConfiguration"));
        IFastUpdater fastUpdater = IFastUpdater(flareContractRegistry.getContractAddressByName("FastUpdater"));

        uint256[] memory indices = new uint256[](1);
        indices[0] = fastUpdatesConfiguration.getFeedIndex(referenceFeedId);
        (uint256[] memory values, int8[] memory decimals, uint64 timestamp) =
            fastUpdater.fetchCurrentFeeds{value: msg.value} (indices);
        _value = sFlr.getPooledFlrByShares(values[0]);
        _decimals = decimals[0];
        _timestamp = timestamp;
    }

    /**
     * @inheritdoc IICustomFeed
     */
    function calculateFee() external view returns (uint256 _fee) {
        IFeeCalculator feeCalculator = IFeeCalculator(flareContractRegistry.getContractAddressByName("FeeCalculator"));
        bytes21[] memory feedIds = new bytes21[](1);
        feedIds[0] = referenceFeedId;
        return feeCalculator.calculateFeeByIds(feedIds);
    }
}
