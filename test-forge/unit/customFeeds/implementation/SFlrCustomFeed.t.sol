// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../../contracts/customFeeds/implementation/SFlrCustomFeed.sol";

contract SFlrCustomFeedTest is Test {

    SFlrCustomFeed private sFlrCustomFeed;
    address private mockFlareContractRegistry;
    address private mockSFlr;
    address private mockFastUpdatesConfiguration;
    address private mockFastUpdater;
    address private mockFeeCalculator;

    bytes21 private feedId;
    bytes21 private referenceFeedId;

    function setUp() public {
        feedId = bytes21("feedId");
        referenceFeedId = bytes21("referenceFeedId");
        mockFlareContractRegistry = makeAddr("FlareContractRegistry");
        mockSFlr = makeAddr("SFlr");
        mockFastUpdatesConfiguration = makeAddr("FastUpdatesConfiguration");
        mockFastUpdater = makeAddr("FastUpdater");
        mockFeeCalculator = makeAddr("FeeCalculator");
        sFlrCustomFeed = new SFlrCustomFeed(
            feedId,
            referenceFeedId,
            IFlareContractRegistry(mockFlareContractRegistry),
            ISFlr(mockSFlr)
        );
    }

    function testGetCurrentFeed() public {
        _mockGetContractAddressByName("FastUpdatesConfiguration", mockFastUpdatesConfiguration);
        _mockGetContractAddressByName("FastUpdater", mockFastUpdater);
        _mockGetPooledFlrByShares(100);
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
        decimals[0] = 18;
        vm.mockCall(
            mockFastUpdater,
            abi.encodeWithSelector(IFastUpdater.fetchCurrentFeeds.selector, indices),
            abi.encode(
                values,
                decimals,
                987654321
            )
        );

        (uint256 returnValue, int8 returnDecimals, uint64 returnTimestamp) = sFlrCustomFeed.getCurrentFeed();
        assertEq(returnValue, 100 * 2);
        assertEq(returnDecimals, 18);
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
        assertEq(sFlrCustomFeed.calculateFee(), fee);
    }


    //// helper functions
    function _mockGetContractAddressByName(string memory _contractName, address _contractAddr) private {
        vm.mockCall(
            mockFlareContractRegistry,
            abi.encodeWithSelector(IFlareContractRegistry.getContractAddressByName.selector, _contractName),
            abi.encode(_contractAddr)
        );
    }

    function _mockGetPooledFlrByShares(uint256 _value) private {
        vm.mockCall(
            mockSFlr,
            abi.encodeWithSelector(ISFlr.getPooledFlrByShares.selector, _value),
            abi.encode(_value * 2)
        );
    }


}