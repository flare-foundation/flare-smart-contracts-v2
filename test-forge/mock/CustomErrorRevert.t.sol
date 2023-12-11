// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

// import {Test, console2} from "forge-std/Test.sol";
import "forge-std/Test.sol";
import "../../contracts/mock/CustomErrorRevert.sol";


contract CustomErrorRevertTest is Test {

    CustomErrorRevert private customErrorRevert;

    function setUp() public {
        customErrorRevert = new CustomErrorRevert();
    }

    function testExpectCustomRevert() public {
        vm.expectRevert(
            abi.encodeWithSelector(CustomErrorUint.selector, "error message", 123)
        );
        customErrorRevert.errorRevertUint(123);

        vm.expectRevert(
            abi.encodeWithSelector(CustomErrorMessage.selector, "some error message")
        );
        customErrorRevert.errorRevert(true);

        vm.expectRevert(CustomError.selector);
        customErrorRevert.errorRevert(false);
    }

}
