// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { TeeOwnerAllowlist } from "../../../../contracts/tee/implementation/TeeOwnerAllowlist.sol";
import { TeeOwnerAllowlistProxy } from "../../../../contracts/tee/proxy/TeeOwnerAllowlistProxy.sol";
import { ITeeOwnerAllowlist } from "../../../../contracts/userInterfaces/tee/ITeeOwnerAllowlist.sol";
import { ITeeExtensionRegistry } from "../../../../contracts/userInterfaces/tee/ITeeExtensionRegistry.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

contract TeeOwnerAllowlistTest is Test {

    TeeOwnerAllowlist private teeOwnerAllowlist;
    TeeOwnerAllowlist private teeOwnerAllowlistImpl;
    TeeOwnerAllowlistProxy private teeOwnerAllowlistProxy;

    uint256 private extensionId;

    address private initialGovernance;
    address private addressUpdater;

    address private realOwnerExtension1;
    address private realOwnerExtension2;
    address private registryAddress;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    address[] private owners;


    function setUp() public {
        extensionId = 1;
        realOwnerExtension1 = makeAddr("realOwnerExtension1");
        realOwnerExtension2 = makeAddr("realOwnerExtension2");
        owners = new address[](2);
        owners[0] = makeAddr("owner1");
        owners[1] = makeAddr("owner2");

        initialGovernance = makeAddr("initialGovernance");
        addressUpdater = makeAddr("addressUpdater");
        teeOwnerAllowlistImpl = new TeeOwnerAllowlist();
        teeOwnerAllowlistProxy = new TeeOwnerAllowlistProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            initialGovernance,
            addressUpdater,
            address(teeOwnerAllowlistImpl)
        );

        teeOwnerAllowlist = TeeOwnerAllowlist(address(teeOwnerAllowlistProxy));
        contractNameHashes = new bytes32[](2);
        contractAddresses = new address[](2);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("TeeExtensionRegistry"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = makeAddr("TeeExtensionRegistry");

        vm.prank(addressUpdater);
        teeOwnerAllowlist.updateContractAddresses(contractNameHashes, contractAddresses);
        registryAddress = address(teeOwnerAllowlist.teeExtensionRegistry());

        vm.mockCall(
            registryAddress,
            abi.encodeWithSelector(
                ITeeExtensionRegistry.getExtensionOwner.selector,
                extensionId
            ),
            abi.encode(realOwnerExtension1)
        );
        vm.mockCall(
            registryAddress,
            abi.encodeWithSelector(
                ITeeExtensionRegistry.getExtensionOwner.selector,
                extensionId + 1
            ),
            abi.encode(realOwnerExtension2)
        );
    }


    function testAddAllowedTeeMachineOwnersRevertOnlyExtensionOwner() public {
        vm.expectRevert(ITeeOwnerAllowlist.OnlyExtensionOwner.selector);
        teeOwnerAllowlist.addAllowedTeeMachineOwners(extensionId, owners);
    }


    function testAddAllowedTeeMachineOwners() public {
        vm.expectEmit();
        emit ITeeOwnerAllowlist.AllowedTeeMachineOwnersAdded(extensionId, owners);
        vm.prank(realOwnerExtension1);
        teeOwnerAllowlist.addAllowedTeeMachineOwners(extensionId, owners);
    }


    function testAddAllowedTeeWalletProjectOwnersRevertOnlyExtensionOwner() public {
        vm.expectRevert(ITeeOwnerAllowlist.OnlyExtensionOwner.selector);
        teeOwnerAllowlist.addAllowedTeeWalletProjectOwners(extensionId, owners);
    }


    function testAddAllowedTeeWalletProjectOwners() public {
        vm.expectEmit();
        emit ITeeOwnerAllowlist.AllowedTeeWalletProjectOwnersAdded(extensionId, owners);
        vm.prank(realOwnerExtension1);
        teeOwnerAllowlist.addAllowedTeeWalletProjectOwners(extensionId, owners);
    }


    function testAllowAllTeeMachineOwnersRevertOnlyExtensionOwner() public {
        vm.expectRevert(ITeeOwnerAllowlist.OnlyExtensionOwner.selector);
        teeOwnerAllowlist.allowAllTeeMachineOwners(extensionId);
    }


    function testAllowAllTeeMachineOwners() public {
        assertFalse(teeOwnerAllowlist.isAllowedTeeMachineOwner(extensionId, owners[0]));

        vm.prank(realOwnerExtension2);
        teeOwnerAllowlist.addAllowedTeeMachineOwners(extensionId + 1, owners);
        assertTrue(teeOwnerAllowlist.isAllowedTeeMachineOwner(extensionId + 1, owners[0]));
        assertTrue(teeOwnerAllowlist.isAllowedTeeMachineOwner(extensionId + 1, owners[1]));

        vm.prank(realOwnerExtension1);
        teeOwnerAllowlist.allowAllTeeMachineOwners(extensionId);
        assertTrue(teeOwnerAllowlist.isAllowedTeeMachineOwner(extensionId, owners[0]));
        assertTrue(teeOwnerAllowlist.isAllowedTeeMachineOwner(extensionId, owners[1]));
    }


    function testAllowAllTeeWalletProjectOwnersRevertOnlyExtensionOwner() public {
        vm.expectRevert(ITeeOwnerAllowlist.OnlyExtensionOwner.selector);
        teeOwnerAllowlist.allowAllTeeWalletProjectOwners(extensionId);
    }


    function testAllowAllTeeWalletProjectOwners() public {
        assertFalse(teeOwnerAllowlist.isAllowedTeeWalletProjectOwner(extensionId, owners[0]));

        vm.prank(realOwnerExtension2);
        teeOwnerAllowlist.addAllowedTeeWalletProjectOwners(extensionId + 1, owners);
        assertTrue(teeOwnerAllowlist.isAllowedTeeWalletProjectOwner(extensionId + 1, owners[0]));
        assertTrue(teeOwnerAllowlist.isAllowedTeeWalletProjectOwner(extensionId + 1, owners[1]));

        vm.prank(realOwnerExtension1);
        teeOwnerAllowlist.allowAllTeeWalletProjectOwners(extensionId);
        assertTrue(teeOwnerAllowlist.isAllowedTeeWalletProjectOwner(extensionId, owners[0]));
        assertTrue(teeOwnerAllowlist.isAllowedTeeWalletProjectOwner(extensionId, owners[1]));
    }


    function testGetAllowedTeeMachineOwners() public {
        address[] memory allowedTeeMachineOwners;

        allowedTeeMachineOwners = teeOwnerAllowlist.getAllowedTeeMachineOwners(extensionId);
        assertEq(allowedTeeMachineOwners.length, 0);

        vm.prank(realOwnerExtension1);
        teeOwnerAllowlist.addAllowedTeeMachineOwners(extensionId, owners);
        allowedTeeMachineOwners = teeOwnerAllowlist.getAllowedTeeMachineOwners(extensionId);
        assertEq(allowedTeeMachineOwners.length, 2);
        assertEq(allowedTeeMachineOwners[0], owners[0]);
        assertEq(allowedTeeMachineOwners[1], owners[1]);
    }


    function testGetAllowedTeeProjectWalletOwners() public {
        address[] memory allowedTeeProjectWalletOwners;

        allowedTeeProjectWalletOwners = teeOwnerAllowlist.getAllowedTeeWalletProjectOwners(extensionId);
        assertEq(allowedTeeProjectWalletOwners.length, 0);

        vm.prank(realOwnerExtension1);
        teeOwnerAllowlist.addAllowedTeeWalletProjectOwners(extensionId, owners);
        allowedTeeProjectWalletOwners = teeOwnerAllowlist.getAllowedTeeWalletProjectOwners(extensionId);
        assertEq(allowedTeeProjectWalletOwners.length, 2);
        assertEq(allowedTeeProjectWalletOwners[0], owners[0]);
        assertEq(allowedTeeProjectWalletOwners[1], owners[1]);
    }
}
