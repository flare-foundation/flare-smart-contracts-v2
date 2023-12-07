// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

// import {Test, console2} from "forge-std/Test.sol";
import "forge-std/Test.sol";
import "../../contracts/mock/TestCustomError.sol";


contract TestCustomErrorTest is Test {

    TestCustomError private testCustomError;

    function setUp() public {
        testCustomError = new TestCustomError();
    }

    function testExpectCustomRevert() public {
        vm.expectRevert(
            abi.encodeWithSelector(CustomErrorUint.selector, "error message", 123)
        );
        testCustomError.testErrorUint(123);

        vm.expectRevert(
            abi.encodeWithSelector(CustomErrorMessage.selector, "some error message")
        );
        testCustomError.testError(true);

        vm.expectRevert(CustomError.selector);
        testCustomError.testError(false);
    }

}
