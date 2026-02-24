// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { Test } from "forge-std/Test.sol";
import { ChainlinkAdapter } from "../../../../contracts/adapters/implementation/ChainlinkAdapter.sol";
import { ChainlinkAdapterProxy } from "../../../../contracts/adapters/implementation/ChainlinkAdapterProxy.sol";
import { IGovernanceSettings } from "flare-smart-contracts/contracts/userInterfaces/IGovernanceSettings.sol";
import { IFlareContractRegistry } from "flare-smart-contracts/contracts/userInterfaces/IFlareContractRegistry.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

contract ChainlinkAdapterTest is Test {

    //solhint-disable-next-line const-name-snakecase
    address internal constant flareContractRegistryMock = 0xaD67FE66660Fb8dFE9d6b1b4240d8650e30F6019;

    ChainlinkAdapter internal chainlinkAdapterImpl;
    ChainlinkAdapter internal chainlinkAdapter;
    ChainlinkAdapterProxy internal chainlinkAdapterProxy;

    bytes21 internal ftsoFeedId;
    uint64 internal staleTimeSeconds;
    string internal description;
    address internal governanceSettings;
    address internal governance;

    address internal ftsoV2Mock;

    function setUp() public {
        governance = makeAddr("governance");
        ftsoFeedId = bytes21("Feed1");
        staleTimeSeconds = 300; // 5 minutes
        description = "Feed1 Chainlink Adapter for FtsoV2";
        governanceSettings = makeAddr("GovernanceSettings");
        ftsoV2Mock = makeAddr("FtsoV2Mock");

        chainlinkAdapterImpl = new ChainlinkAdapter();
        chainlinkAdapterProxy = new ChainlinkAdapterProxy(
            IGovernanceSettings(governanceSettings),
            governance,
            ftsoFeedId,
            staleTimeSeconds,
            description,
            address(chainlinkAdapterImpl)
        );
        chainlinkAdapter = ChainlinkAdapter(address(chainlinkAdapterProxy));

        _getContractAddressByHashMock("FtsoV2", ftsoV2Mock);
    }

    function testLatestRoundDataRevertNoDataPresent() public {
        _getFeedByIdInWeiMock(ftsoFeedId, 0, 0);
        vm.expectRevert(abi.encodeWithSelector(ChainlinkAdapter.NoDataPresent.selector));
        chainlinkAdapter.latestRoundData();
    }

    function testLatestRoundDataRevertStaleData() public {
        uint256 currentTimestamp = 10000;
        vm.warp(currentTimestamp); // set current block timestamp
        uint256 timestamp = currentTimestamp - (staleTimeSeconds + 1); // make data stale
        _getFeedByIdInWeiMock(ftsoFeedId, 0, uint64(timestamp));
        vm.expectRevert(abi.encodeWithSelector(ChainlinkAdapter.StaleData.selector));
        chainlinkAdapter.latestRoundData();
    }

    function testLatestRoundData() public {
        uint256 currentTimestamp = 10000;
        vm.warp(currentTimestamp); // set current block timestamp
        uint256 timestamp = currentTimestamp - (staleTimeSeconds - 1); // fresh data
        uint256 value = 123456789012345678;
        _getFeedByIdInWeiMock(ftsoFeedId, value, uint64(timestamp));
        (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = chainlinkAdapter.latestRoundData();

        assertEq(answer, int256(value));
        assertEq(updatedAt, timestamp);
        assertEq(startedAt, timestamp);
        assertEq(roundId, uint80(timestamp));
        assertEq(answeredInRound, uint80(timestamp));
    }

    function testGetRoundDataRevertNotImplemented() public {
        vm.expectRevert(abi.encodeWithSelector(ChainlinkAdapter.NotImplemented.selector));
        chainlinkAdapter.getRoundData(1);
    }

    function testSetStaleTimeSecondsRevertOnlyGovernance() public {
        vm.prank(makeAddr("only governance"));
        vm.expectRevert();
        chainlinkAdapter.setStaleTimeSeconds(600);
    }

    function testSetStaleTimeSeconds() public {
        uint64 newStaleTimeSeconds = 120; // 2 minutes
        vm.prank(governance);
        vm.expectEmit();
        emit ChainlinkAdapter.StaleTimeSecondsSet(newStaleTimeSeconds);
        chainlinkAdapter.setStaleTimeSeconds(newStaleTimeSeconds);
        assertEq(chainlinkAdapter.staleTimeSeconds(), newStaleTimeSeconds);
    }

    // revert if staleTimeSeconds changes and data is stale
    function testLatestRoundDataRevertStaleData1() public {
       testLatestRoundData();

        uint256 currentTimestamp = 10000;
        vm.warp(currentTimestamp); // set current block timestamp
        uint256 timestamp = currentTimestamp - (staleTimeSeconds - 1);
        uint256 value = 123456789012345678;
        _getFeedByIdInWeiMock(ftsoFeedId, value, uint64(timestamp));

        // decrease stale time to make data stale
        uint64 newStaleTimeSeconds = 100;
        vm.prank(governance);
        chainlinkAdapter.setStaleTimeSeconds(newStaleTimeSeconds);

        vm.expectRevert(abi.encodeWithSelector(ChainlinkAdapter.StaleData.selector));
        chainlinkAdapter.latestRoundData();
    }

    function testUpgradeToAndCallRevertOnlyGovernance() public {
        address newImpl = address(new ChainlinkAdapter());
        vm.prank(makeAddr("only governance"));
        vm.expectRevert();
        chainlinkAdapter.upgradeToAndCall(newImpl, "");
    }

    function testUpgradeToAndCall() public {
        address newImpl = address(new ChainlinkAdapter());
        vm.prank(governance);
        chainlinkAdapter.upgradeToAndCall(newImpl, "");
        assertEq(chainlinkAdapter.implementation(), newImpl);
    }

    function testUpgradeToAndCallWithTimelock() public {
        address newImpl = address(new ChainlinkAdapter());
        vm.prank(governance);
        chainlinkAdapter.switchToProductionMode();

        vm.mockCall(
            governanceSettings,
            abi.encodeWithSelector(
                IGovernanceSettings.getGovernanceAddress.selector
            ),
            abi.encode(governance)
        );

        vm.mockCall(
            governanceSettings,
            abi.encodeWithSelector(
                IGovernanceSettings.getTimelock.selector
            ),
            abi.encode(3600)
        );

        address governanceExecutor = makeAddr("governanceExecutor");
        vm.mockCall(
            governanceSettings,
            abi.encodeWithSelector(
                IGovernanceSettings.isExecutor.selector,
                governanceExecutor
            ),
            abi.encode(true)
        );

        vm.prank(governance);
        chainlinkAdapter.upgradeToAndCall(newImpl, "");
        assertNotEq(chainlinkAdapter.implementation(), newImpl);
        skip(3600); // 1 hour time lock
        vm.prank(governanceExecutor);
        chainlinkAdapter.executeGovernanceCall(UUPSUpgradeable.upgradeToAndCall.selector);
        assertEq(chainlinkAdapter.implementation(), newImpl);
    }

    function testUpgradeToAndCallRevertOnlyProxy() public {
        address newImpl = address(new ChainlinkAdapter());
        vm.prank(governance);
        vm.expectRevert();
        chainlinkAdapterImpl.upgradeToAndCall(newImpl, "");
    }

    function testUpgradeToAndCallWithData() public {
        address newImpl = address(new ChainlinkAdapter());
        bytes memory data = abi.encodeWithSelector(
            ChainlinkAdapter.setStaleTimeSeconds.selector,
            uint64(123)
        );
        vm.prank(governance);
        chainlinkAdapter.upgradeToAndCall(newImpl, data);
        assertEq(chainlinkAdapter.implementation(), newImpl);
        assertEq(chainlinkAdapter.staleTimeSeconds(), 123);
    }

    function testInitialization() public view {
        assertEq(chainlinkAdapter.ftsoFeedId(), ftsoFeedId);
        assertEq(chainlinkAdapter.staleTimeSeconds(), staleTimeSeconds);
        assertEq(chainlinkAdapter.description(), description);
        assertEq(chainlinkAdapter.decimals(), 18);
        assertEq(chainlinkAdapter.version(), 2);
    }

    //// helper functions for mocking
    function _getContractAddressByHashMock(string memory _name, address _address) internal {
        bytes32 nameHash = keccak256(abi.encode(_name));
        vm.mockCall(
            flareContractRegistryMock,
            abi.encodeWithSelector(
                IFlareContractRegistry.getContractAddressByHash.selector,
                nameHash
            ),
            abi.encode(_address)
        );
    }

    function _getFeedByIdInWeiMock(bytes21 _feedId, uint256 _value, uint64 _timestamp) internal {
        vm.mockCall(
            ftsoV2Mock,
            abi.encodeWithSignature(
                "getFeedByIdInWei(bytes21)",
                _feedId
            ),
            abi.encode(_value, _timestamp)
        );
    }

}