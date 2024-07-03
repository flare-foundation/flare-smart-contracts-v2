// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../../contracts/fdc/implementation/FdcHub.sol";

contract FdcHubTest is Test {
    FdcHub private fdcHub;

    address private governance;
    address private addressUpdater;
    address private mockRewardManager;
    address private mockFlareSystemsManager;
    address private mockInflation;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    function setUp() public {
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");
        mockRewardManager = makeAddr("rewardManager");
        mockFlareSystemsManager = makeAddr("flareSystemsManager");
        mockInflation = makeAddr("inflation");

        fdcHub = new FdcHub(
          IGovernanceSettings(makeAddr("governanceSettings")),
          governance,
          addressUpdater
        );

        vm.prank(addressUpdater);
        contractNameHashes = new bytes32[](4);
        contractAddresses = new address[](4);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("RewardManager"));
        contractNameHashes[2] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[3] = keccak256(abi.encode("Inflation"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = mockRewardManager;
        contractAddresses[2] = mockFlareSystemsManager;
        contractAddresses[3] = mockInflation;
        fdcHub.updateContractAddresses(contractNameHashes, contractAddresses);
    }

    function testGetContractName() public {
        assertEq(fdcHub.getContractName(), "FdcHub");
    }

    function testSettingFee() public {
        vm.prank(governance);
        bytes32 atType = 0x5061796d656e7400000000000000000000000000000000000000000000000000;
        bytes32 source = 0x7465737458525000000000000000000000000000000000000000000000000000;
        fdcHub.setTypeAndSourceFee(atType, source, 100);
        bytes memory data = hex"5061796d656e74000000000000000000000000000000000000000000000000007465737458525000000000000000000000000000000000000000000000000000974578ed414a4d5ab784a5b0bcab92c07abef6bf80d35b5a731b26e53a87bdb91d24cd21d86ba709a5f81a3e584b39c16cef99f8a2332d4494d3b4321dc9e38700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
        assertEq(fdcHub.getRequestFee(data), 100);
    }
}
