// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../../../../contracts/tee/implementation/TeeOwnerAllowlist.sol";
import "../../../../contracts/tee/proxy/TeeOwnerAllowlistProxy.sol";
import "../../../../contracts/userInterfaces/tee/ITeeOwnerAllowlist.sol";

contract TeeOwnerAllowlistTest is Test {

    TeeOwnerAllowlist private teeOwnerAllowlist;
    TeeOwnerAllowlist private teeOwnerAllowlistImpl;
    TeeOwnerAllowlistProxy private teeOwnerAllowlistProxy;

    uint256 private extensionId;

    address private initialGovernance;
    address private addressUpdater;

    address private realOwner;
    address private mockOwner;
    address private registryAddress;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    address[] private owners;


    function setUp() public {
        extensionId = 1;
        realOwner = makeAddr("realOwner");
        mockOwner = makeAddr("mockOwner");
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
            abi.encode(realOwner)
        );
    }


    function testAddAllowedTeeMachineOwnersRevertOnlyExtensionOwner() public {
        vm.expectRevert(ITeeOwnerAllowlist.OnlyExtensionOwner.selector);
        vm.prank(mockOwner);
        teeOwnerAllowlist.addAllowedTeeMachineOwners(extensionId, owners);
    }


    function testAddAllowedTeeMachineOwners() public {
        vm.expectEmit();
        emit ITeeOwnerAllowlist.AllowedTeeMachineOwnersAdded(extensionId, owners);
        vm.prank(realOwner);
        teeOwnerAllowlist.addAllowedTeeMachineOwners(extensionId, owners);
    }


    function testAddAllowedTeeWalletProjectOwnersRevertOnlyExtensionOwner() public {
        vm.expectRevert(ITeeOwnerAllowlist.OnlyExtensionOwner.selector);
        vm.prank(mockOwner);
        teeOwnerAllowlist.addAllowedTeeWalletProjectOwners(extensionId, owners);
    }


    function testAddAllowedTeeWalletProjectOwners() public {
        vm.expectEmit();
        emit ITeeOwnerAllowlist.AllowedTeeWalletProjectOwnersAdded(extensionId, owners);
        vm.prank(realOwner);
        teeOwnerAllowlist.addAllowedTeeWalletProjectOwners(extensionId, owners);
    }


    function testAllowAllTeeMachineOwnersRevertOnlyExtensionOwner() public {
        vm.expectRevert(ITeeOwnerAllowlist.OnlyExtensionOwner.selector);
        vm.prank(mockOwner);
        teeOwnerAllowlist.allowAllTeeMachineOwners(extensionId);
    }


    function testAllowAllTeeMachineOwnersAndIsAllowedTeeMachineOwner() public {
        assertFalse(teeOwnerAllowlist.isAllowedTeeMachineOwner(extensionId, owners[0]));
        vm.prank(realOwner);
        teeOwnerAllowlist.allowAllTeeMachineOwners(extensionId);
        assertTrue(teeOwnerAllowlist.isAllowedTeeMachineOwner(extensionId, owners[0]));
        assertTrue(teeOwnerAllowlist.isAllowedTeeMachineOwner(extensionId, owners[1]));
    }


    function testAllowAllTeeWalletProjectOwnersRevertOnlyExtensionOwner() public {
        vm.expectRevert(ITeeOwnerAllowlist.OnlyExtensionOwner.selector);
        vm.prank(mockOwner);
        teeOwnerAllowlist.allowAllTeeWalletProjectOwners(extensionId);
    }
    

    function testAllowAllTeeWalletProjectOwnersAndIsAllowedTeeWalletProjectOwner() public {
        assertFalse(teeOwnerAllowlist.isAllowedTeeWalletProjectOwner(extensionId, owners[0]));
        vm.prank(realOwner);
        teeOwnerAllowlist.allowAllTeeWalletProjectOwners(extensionId);
        assertTrue(teeOwnerAllowlist.isAllowedTeeWalletProjectOwner(extensionId, owners[0]));
        assertTrue(teeOwnerAllowlist.isAllowedTeeWalletProjectOwner(extensionId, owners[1]));
    }
    

    function testGetAllowedTeeMachineOwners() public {
        address[] memory allowedTeeMachineOwners;
        
        vm.startPrank(realOwner);
        allowedTeeMachineOwners = teeOwnerAllowlist.getAllowedTeeMachineOwners(extensionId);
        assertEq(allowedTeeMachineOwners.length, 0);

        teeOwnerAllowlist.addAllowedTeeMachineOwners(extensionId, owners);
        allowedTeeMachineOwners = teeOwnerAllowlist.getAllowedTeeMachineOwners(extensionId);
        assertEq(allowedTeeMachineOwners.length, 2);
        assertEq(allowedTeeMachineOwners[0], owners[0]);
        assertEq(allowedTeeMachineOwners[1], owners[1]);
        vm.stopPrank();
    }
   

    function testGetAllowedTeeProjectWalletOwners() public {
        address[] memory allowedTeeProjectWalletOwners;
        
        vm.startPrank(realOwner);
        allowedTeeProjectWalletOwners = teeOwnerAllowlist.getAllowedTeeWalletProjectOwners(extensionId);
        assertEq(allowedTeeProjectWalletOwners.length, 0);

        teeOwnerAllowlist.addAllowedTeeWalletProjectOwners(extensionId, owners);
        allowedTeeProjectWalletOwners = teeOwnerAllowlist.getAllowedTeeWalletProjectOwners(extensionId);
        assertEq(allowedTeeProjectWalletOwners.length, 2);
        assertEq(allowedTeeProjectWalletOwners[0], owners[0]);
        assertEq(allowedTeeProjectWalletOwners[1], owners[1]);
        vm.stopPrank();
    }
}
