// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { StXrpCustomFeed , IERC4626 } from "../../../../contracts/customFeeds/implementation/StXrpCustomFeed.sol";
import { IFastUpdatesConfiguration } from "../../../../contracts/userInterfaces/IFastUpdatesConfiguration.sol";
import { IFastUpdater } from "../../../../contracts/userInterfaces/IFastUpdater.sol";
import { IFeeCalculator } from "../../../../contracts/userInterfaces/IFeeCalculator.sol";
import { IFlareContractRegistry } from "@flarenetwork/flare-periphery-contracts/flare/IFlareContractRegistry.sol";

contract StXrpCustomFeedTest is Test {

    StXrpCustomFeed private stXrpCustomFeed;
    address private mockFlareContractRegistry;
    address private mockStXrp;
    address private mockFastUpdatesConfiguration;
    address private mockFastUpdater;
    address private mockFeeCalculator;

    bytes21 private feedId;
    bytes21 private referenceFeedId;

    function setUp() public {
        feedId = bytes21("feedId");
        referenceFeedId = bytes21("referenceFeedId");
        mockFlareContractRegistry = makeAddr("FlareContractRegistry");
        mockStXrp = makeAddr("StXrp");
        mockFastUpdatesConfiguration = makeAddr("FastUpdatesConfiguration");
        mockFastUpdater = makeAddr("FastUpdater");
        mockFeeCalculator = makeAddr("FeeCalculator");
        stXrpCustomFeed = new StXrpCustomFeed(
            feedId,
            referenceFeedId,
            IFlareContractRegistry(mockFlareContractRegistry),
            IERC4626(mockStXrp)
        );
    }

    function testGetCurrentFeed() public {
        _mockGetContractAddressByName("FastUpdatesConfiguration", mockFastUpdatesConfiguration);
        _mockGetContractAddressByName("FastUpdater", mockFastUpdater);
        _mockConvertToAssets(100);
        uint256 index = 8;
        vm.mockCall(
            mockFastUpdatesConfiguration,
            abi.encodeWithSelector(IFastUpdatesConfiguration.getFeedIndex.selector, referenceFeedId),
            abi.encode(index)
        );
        uint256[] memory indices = new uint256[](1);
        indices[0] = index;
        uint256[] memory values = new uint256[](1);
        values[0] = 100;
        int8[] memory decimals = new int8[](1);
        decimals[0] = 5;
        vm.mockCall(
            mockFastUpdater,
            abi.encodeWithSelector(IFastUpdater.fetchCurrentFeeds.selector, indices),
            abi.encode(
                values,
                decimals,
                987654321
            )
        );

        (uint256 returnValue, int8 returnDecimals, uint64 returnTimestamp) = stXrpCustomFeed.getCurrentFeed();
        assertEq(returnValue, 100 * 2);
        assertEq(returnDecimals, 5);
        assertEq(returnTimestamp, 987654321);
    }

    function testCalculateFee() public {
        _mockGetContractAddressByName("FeeCalculator", mockFeeCalculator);
        uint256 fee = 93;
        bytes21[] memory feedIds = new bytes21[](1);
        feedIds[0] = referenceFeedId;
        vm.mockCall(
            mockFeeCalculator,
            abi.encodeWithSelector(IFeeCalculator.calculateFeeByIds.selector, feedIds),
            abi.encode(fee)
        );
        assertEq(stXrpCustomFeed.calculateFee(), fee);
    }


    //// helper functions
    function _mockGetContractAddressByName(string memory _contractName, address _contractAddr) private {
        vm.mockCall(
            mockFlareContractRegistry,
            abi.encodeWithSelector(IFlareContractRegistry.getContractAddressByName.selector, _contractName),
            abi.encode(_contractAddr)
        );
    }

    function _mockConvertToAssets(uint256 _value) private {
        vm.mockCall(
            mockStXrp,
            abi.encodeWithSelector(IERC4626.convertToAssets.selector, _value),
            abi.encode(_value * 2)
        );
    }


}