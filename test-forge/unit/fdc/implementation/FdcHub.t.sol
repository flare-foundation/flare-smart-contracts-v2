// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
// import "../../../../contracts/ftso/implementation/FtsoFeedDecimals.sol";
import "../../../../contracts/fdc/implementation/FdcHub.sol";

contract FdcHubTest is Test {
  FdcHub private fdcHub;

  address private governance;
  address private addressUpdater;

  function setUp() public {
    governance = makeAddr("governance");
    addressUpdater = makeAddr("addressUpdater");
    fdcHub = new FdcHub(
      IGovernanceSettings(makeAddr("governanceSettings")),      
      governance,
      addressUpdater
    );
  }

  function testGetContractName() public {
        assertEq(fdcHub.getContractName(), "FdcHub");
    }

  function testSettingFee() public {
    vm.prank(governance);
    bytes32 atType = 0x5061796d656e7400000000000000000000000000000000000000000000000000;
    bytes32 source = 0x7465737458525000000000000000000000000000000000000000000000000000;
    fdcHub.setTypeAndSourceFee(atType, source, 100);
    // TODO: no idea how to pass a calldata to method call
    bytes memory data = bytes("0x5061796d656e74000000000000000000000000000000000000000000000000007465737458525000000000000000000000000000000000000000000000000000974578ed414a4d5ab784a5b0bcab92c07abef6bf80d35b5a731b26e53a87bdb91d24cd21d86ba709a5f81a3e584b39c16cef99f8a2332d4494d3b4321dc9e38700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000");
    assertEq(fdcHub.getRequestFee(data), 100);
    // vm.expectRevert("offset too small");
  }
}
