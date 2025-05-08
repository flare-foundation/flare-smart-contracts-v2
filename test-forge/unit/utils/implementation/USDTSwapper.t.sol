// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../../contracts/utils/implementation/USDTSwapper.sol";
import "../../../../contracts/mock/ERC20Mock.sol";

contract USDTSwapperTest is Test {

    address private sender1;
    address private sender2;
    address private owner;
    ERC20Mock public usdte;
    ERC20Mock public usdt0;
    USDTSwapper public swapper;

    event Swapped(address indexed sender, uint256 amount);


    function setUp() public {
        sender1 = makeAddr("sender1");
        sender2 = makeAddr("sender2");
        owner = makeAddr("owner");
        usdte = new ERC20Mock("USDT.e", "USDT.e", 6);
        usdt0 = new ERC20Mock("USDT0", "USDT0", 6);
        swapper = new USDTSwapper(owner, usdte, usdt0);

        usdte.mintAmount(sender1, 1000);
        usdte.mintAmount(sender2, 5000);
        usdt0.mintAmount(owner, 3000);
    }

    function testDecimals() public {
        assertEq(usdte.decimals(), 6);
        assertEq(usdt0.decimals(), 6);
    }

    function testDepositUSDT0() public {
        assertEq(usdte.balanceOf(address(swapper)), 0);
        assertEq(usdt0.balanceOf(address(swapper)), 0);
        assertEq(usdt0.balanceOf(owner), 3000);
        vm.prank(owner);
        usdt0.approve(address(swapper), 2500);
        vm.prank(owner);
        swapper.depositUSDT0(2000);
        assertEq(usdte.balanceOf(address(swapper)), 0);
        assertEq(usdt0.balanceOf(owner), 1000);
        assertEq(usdt0.balanceOf(address(swapper)), 2000);
    }

    function testSwap() public {
        testDepositUSDT0();
        vm.prank(sender1);
        usdte.approve(address(swapper), 100);
        vm.prank(sender1);
        vm.expectEmit();
        emit Swapped(sender1, 100);
        swapper.swap(100);
        assertEq(usdte.balanceOf(address(swapper)), 100);
        assertEq(usdt0.balanceOf(address(swapper)), 1900);
        assertEq(usdte.balanceOf(sender1), 900);
        assertEq(usdt0.balanceOf(sender1), 100);
    }

    function testPause() public {
        assertEq(swapper.paused(), false);
        vm.prank(owner);
        swapper.pause();
        assertEq(swapper.paused(), true);
    }

    function testUnpause() public {
        testPause();
        vm.prank(owner);
        swapper.unpause();
        assertEq(swapper.paused(), false);
    }

    function testWithdrawUSDT0() public {
        testDepositUSDT0();
        vm.prank(owner);
        swapper.withdrawUSDT0(2000);
        assertEq(usdt0.balanceOf(address(swapper)), 0);
        assertEq(usdt0.balanceOf(owner), 3000);
    }

    function testWithdrawUSDTe() public {
        testSwap();
        vm.prank(owner);
        swapper.withdrawUSDTe(100);
        assertEq(usdte.balanceOf(address(swapper)), 0);
        assertEq(usdte.balanceOf(owner), 100);
    }

    function testDepositUSDT0RevertOnlyOwner() public {
        vm.expectRevert("only owner");
        vm.prank(sender1);
        swapper.depositUSDT0(2000);
    }

    function testSwapRevertSwappingIsPaused() public {
        testPause();
        vm.expectRevert("swapping is paused");
        vm.prank(sender1);
        swapper.swap(100);
    }

    function testSwapRevertInsufficientAllowance() public {
        testDepositUSDT0();
        vm.prank(sender1);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(swapper), 0, 100));
        swapper.swap(100);
    }

    function testSwapRevertInsufficientBalance() public {
        testDepositUSDT0();
        vm.prank(sender2);
        usdte.approve(address(swapper), 5000);
        vm.prank(sender2);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(swapper), 2000, 5000));
        swapper.swap(5000);
    }

    function testPauseRevertOnlyOwner() public {
        vm.expectRevert("only owner");
        vm.prank(sender1);
        swapper.pause();
    }

    function testUnpauseRevertOnlyOwner() public {
        testPause();
        vm.expectRevert("only owner");
        vm.prank(sender1);
        swapper.unpause();
    }

    function testWithdrawUSDT0RevertOnlyOwner() public {
        testDepositUSDT0();
        vm.expectRevert("only owner");
        vm.prank(sender1);
        swapper.withdrawUSDT0(2000);
    }

    function testWithdrawUSDTeRevertOnlyOwner() public {
        testSwap();
        vm.expectRevert("only owner");
        vm.prank(sender1);
        swapper.withdrawUSDTe(100);
    }
}
