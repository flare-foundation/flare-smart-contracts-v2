// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IFlareContractRegistry } from "@flarenetwork/flare-periphery-contracts/flare/IFlareContractRegistry.sol";
import { IFeeCalculator } from "../../userInterfaces/IFeeCalculator.sol";
import { IFastUpdater } from "../../userInterfaces/IFastUpdater.sol";
import { IFastUpdatesConfiguration } from "../../userInterfaces/IFastUpdatesConfiguration.sol";
import { IICustomFeed } from "../interface/IICustomFeed.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

/**
 * StXrpCustomFeed contract.
 * The contract is used to calculate the stXRP custom feed using the reference feed (XRP) and the stXRP contract.
 */
contract StXrpCustomFeed is IICustomFeed {

    /// The feed id.
    bytes21 public immutable feedId;

    /// The reference feed id.
    bytes21 public immutable referenceFeedId;

    /// The FlareContractRegistry contract.
    IFlareContractRegistry public immutable flareContractRegistry;

    /// The stXRP contract.
    IERC4626 public immutable stXrp;

    /**
     * Constructor.
     */
    constructor(
        bytes21 _feedId,
        bytes21 _referenceFeedId,
        IFlareContractRegistry _flareContractRegistry,
        IERC4626 _stXrp
    )
    {
        feedId = _feedId;
        referenceFeedId = _referenceFeedId;
        flareContractRegistry = _flareContractRegistry;
        stXrp = _stXrp;
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
        _value = stXrp.convertToAssets(values[0]);
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
