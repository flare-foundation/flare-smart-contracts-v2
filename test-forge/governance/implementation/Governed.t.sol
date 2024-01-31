// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../contracts/governance/mock/GovernedMock.sol";

contract GovernedTest is Test {

    GovernedMock private governedMock;

    address private governance;
    address private governanceSettings;
    address private initialGovernance;

    bytes4 private selectorChangeA = bytes4(keccak256("changeA(uint256)"));
    bytes4 private selectorChangeWithRevert = bytes4(keccak256("changeWithRevert(uint256)"));
    uint256 private constant HOUR = 3600;

    event GovernanceCallTimelocked(bytes4 selector, uint256 allowedAfterTimestamp, bytes encodedCall);
    event TimelockedGovernanceCallExecuted(bytes4 selector, uint256 timestamp);
    event TimelockedGovernanceCallCanceled(bytes4 selector, uint256 timestamp);
    event GovernanceInitialised(address initialGovernance);
    event GovernedProductionModeEntered(address governanceSettings);

    function setUp() public {
        governance = makeAddr("governance");
        initialGovernance = makeAddr("initialGovernance");
        governanceSettings = makeAddr("governanceSettings");
        governedMock = new GovernedMock();

        vm.mockCall(
            address(governanceSettings),
            abi.encodeWithSelector(bytes4(keccak256("getGovernanceAddress()"))),
            abi.encode(governance)
        );

        vm.mockCall(
            address(governanceSettings),
            abi.encodeWithSelector(bytes4(keccak256("getTimelock()"))),
            abi.encode(HOUR)
        );
    }

    function testInitialise() public {
        assertEq(governedMock.governance(), address(0));
        vm.expectEmit();
        emit GovernanceInitialised(initialGovernance);
        governedMock.initialise(IGovernanceSettings(governanceSettings), initialGovernance);
        assertEq(governedMock.governance(), initialGovernance);
    }

    function testInitialisedRevertAlreadyInitialised() public {
        testInitialise();
        vm.expectRevert("initialised != false");
        governedMock.initialise(IGovernanceSettings(governanceSettings), initialGovernance);
    }

    function testInitialisedRevertGovernanceSettingsZero() public {
        vm.expectRevert("governance settings zero");
        governedMock.initialise(IGovernanceSettings(address(0)), initialGovernance);
    }

    function testInitialisedRevertInitialGovernanceZero() public {
        vm.expectRevert("_governance zero");
        governedMock.initialise(IGovernanceSettings(governanceSettings), address(0));
    }

    function testSwitchToProductionMode() public {
        testInitialise();
        vm.prank(initialGovernance);
        vm.expectEmit();
        emit GovernedProductionModeEntered(governanceSettings);
        governedMock.switchToProductionMode();
        assertEq(governedMock.governance(), governance);
    }

    function testSwitchToProductionModeRevertAlreadyInProdMode() public {
        testSwitchToProductionMode();
        vm.prank(governance);
        vm.expectRevert("already in production mode");
        governedMock.switchToProductionMode();
    }

    function testExecuteGovernanceCall() public {
        vm.mockCall(
            address(governanceSettings),
            abi.encodeWithSelector(bytes4(keccak256("isExecutor(address)")), governance),
            abi.encode(true)
        );
        testSwitchToProductionMode();

        vm.startPrank(governance);
        governedMock.changeA(3);

        vm.warp(block.timestamp + HOUR);
        vm.expectEmit();
        emit TimelockedGovernanceCallExecuted(selectorChangeA, block.timestamp);
        governedMock.executeGovernanceCall(selectorChangeA);
        assertEq(governedMock.a(), 3);
        vm.stopPrank();
    }

    function testExecuteGovernanceCallRevertNotExecutor() public {
        vm.expectRevert("only executor");
        governedMock.executeGovernanceCall(selectorChangeA);
    }

    function testExecuteGovernanceCallRevertInvalidSelector() public {
        vm.mockCall(
            address(governanceSettings),
            abi.encodeWithSelector(bytes4(keccak256("isExecutor(address)")), governance),
            abi.encode(true)
        );
        testSwitchToProductionMode();
        vm.prank(governance);
        vm.expectRevert("timelock: invalid selector");
        governedMock.executeGovernanceCall(selectorChangeA);
    }

    function testExecuteGovernanceCallRevertNotAllowedYet() public {
        vm.mockCall(
            address(governanceSettings),
            abi.encodeWithSelector(bytes4(keccak256("isExecutor(address)")), governance),
            abi.encode(true)
        );
        testSwitchToProductionMode();

        vm.startPrank(governance);
        governedMock.changeA(3);

        vm.warp(block.timestamp + HOUR - 60);
        vm.expectRevert("timelock: not allowed yet");
        governedMock.executeGovernanceCall(selectorChangeA);
    }

    function testExecuteGovernanceCallRevertNotSuccessful() public {
        vm.mockCall(
            address(governanceSettings),
            abi.encodeWithSelector(bytes4(keccak256("isExecutor(address)")), governance),
            abi.encode(true)
        );
        testSwitchToProductionMode();

        vm.startPrank(governance);
        governedMock.changeWithRevert(3);

        vm.warp(block.timestamp + HOUR);
        vm.expectRevert("this is revert");
        governedMock.executeGovernanceCall(selectorChangeWithRevert);
        vm.stopPrank();
    }

    function testExecuteNotInProductionMode() public {
        testInitialise();
        vm.prank(initialGovernance);
        governedMock.changeA(23);
        assertEq(governedMock.a(), 23);
    }

    function testCancelGovernanceCall() public {
        testSwitchToProductionMode();

        vm.startPrank(governance);
        governedMock.changeA(3);

        vm.warp(block.timestamp + HOUR - 60);
        vm.expectEmit();
        emit TimelockedGovernanceCallCanceled(selectorChangeA, block.timestamp);
        governedMock.cancelGovernanceCall(selectorChangeA);
        vm.stopPrank();
    }

    function testCancelGovernanceCallRevert() public {
        testInitialise();
        vm.prank(initialGovernance);
        vm.expectRevert("timelock: invalid selector");
        governedMock.cancelGovernanceCall(selectorChangeA);
    }

}