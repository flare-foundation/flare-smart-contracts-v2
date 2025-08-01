// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../../../../contracts/tee/implementation/TeeOwnerAllowlist.sol";
import "../../../../contracts/tee/proxy/TeeOwnerAllowlistProxy.sol";
import "../../../../contracts/userInterfaces/tee/ITeeOwnerAllowlist.sol";

contract TeeOwnerAllowlistTest is Test {

    TeeOwnerAllowlist private teeOwnerAllowlistImpl;
    TeeOwnerAllowlistProxy private teeOwnerAllowlistProxy;

    uint256 private extensionId;

    address private initialGovernance;
    address private addressUpdater;

    address private realOwner;
    address private registryAddress;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    address[] private owners;


    function setUp() public {
        extensionId = 1;
        realOwner = makeAddr("extensionOwner");
        owners = new address[](2);
        owners[0] = makeAddr("addr1");
        owners[1] = makeAddr("addr2");

        initialGovernance = makeAddr("initialGovernance");
        addressUpdater = makeAddr("addressUpdater");
        teeOwnerAllowlistImpl = new TeeOwnerAllowlist();
        teeOwnerAllowlistProxy = new TeeOwnerAllowlistProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            initialGovernance,
            addressUpdater,
            address(teeOwnerAllowlistImpl)
        );

        teeOwnerAllowlistImpl = TeeOwnerAllowlist(address(teeOwnerAllowlistProxy));
        contractNameHashes = new bytes32[](2);
        contractAddresses = new address[](2);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("TeeExtensionRegistry"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = makeAddr("TeeExtensionRegistry");

        vm.prank(addressUpdater);
        teeOwnerAllowlistImpl.updateContractAddresses(contractNameHashes, contractAddresses);
        registryAddress = address(teeOwnerAllowlistImpl.teeExtensionRegistry());

        vm.mockCall(
            registryAddress,
            abi.encodeWithSelector(
                ITeeExtensionRegistry.getExtensionOwner.selector,
                extensionId
            ),
            abi.encode(realOwner)
        );
    }


    function testAddAllowedTeeMachineOwnersOnlyExtensionOwner() public {
        address mockOwner = makeAddr("mockOwner");
        vm.expectRevert(ITeeOwnerAllowlist.OnlyExtensionOwner.selector);
        vm.prank(mockOwner);
        teeOwnerAllowlistImpl.addAllowedTeeMachineOwners(extensionId, owners);
    }


    function testAddAllowedTeeMachineOwners() public {
        vm.expectEmit();
        emit ITeeOwnerAllowlist.AllowedTeeMachineOwnersAdded(extensionId, owners);
        vm.prank(realOwner);
        teeOwnerAllowlistImpl.addAllowedTeeMachineOwners(extensionId, owners);
    }


    function testAddAllowedTeeWalletProjectOwners() public {
        vm.expectEmit();
        emit ITeeOwnerAllowlist.AllowedTeeWalletProjectOwnersAdded(extensionId, owners);
        vm.prank(realOwner);
        teeOwnerAllowlistImpl.addAllowedTeeWalletProjectOwners(extensionId, owners);
    }


    function testAllowAllTeeMachineOwnersAndAllowAllTeeMachineOwners() public {
        vm.startPrank(realOwner);
        assertFalse(teeOwnerAllowlistImpl.isAllowedTeeMachineOwner(extensionId, owners[0]));
        teeOwnerAllowlistImpl.allowAllTeeMachineOwners(extensionId);
        assertTrue(teeOwnerAllowlistImpl.isAllowedTeeMachineOwner(extensionId, owners[0]));
        assertTrue(teeOwnerAllowlistImpl.isAllowedTeeMachineOwner(extensionId, owners[1]));
        vm.stopPrank();
    }


    function testAllowAllTeeMachineOwnersAndAddAllowedTeeMachineOwners() public {
        address[] memory oneOwner = new address[](1);
        oneOwner[0] = makeAddr("oneOwner");

        vm.startPrank(realOwner);
        teeOwnerAllowlistImpl.addAllowedTeeMachineOwners(extensionId, oneOwner);
        // false
        assertFalse(teeOwnerAllowlistImpl.isAllowedTeeMachineOwner(extensionId, owners[0]));
        assertFalse(teeOwnerAllowlistImpl.isAllowedTeeMachineOwner(extensionId, owners[1]));
        // true
        assertTrue(teeOwnerAllowlistImpl.isAllowedTeeMachineOwner(extensionId, oneOwner[0]));
        vm.stopPrank();
    }
    

    function testAllowAllTeeWalletProjectOwnersAndAllowAllTeeWalletProjectOwners() public {
        vm.startPrank(realOwner);
        assertFalse(teeOwnerAllowlistImpl.isAllowedTeeWalletProjectOwner(extensionId, owners[0]));
        teeOwnerAllowlistImpl.allowAllTeeWalletProjectOwners(extensionId);
        assertTrue(teeOwnerAllowlistImpl.isAllowedTeeWalletProjectOwner(extensionId, owners[0]));
        assertTrue(teeOwnerAllowlistImpl.isAllowedTeeWalletProjectOwner(extensionId, owners[1]));
        vm.stopPrank();
    }


    function testAllowAllTeeWalletProjectOwnersAndAddAllowedTeeWalletProjectOwners() public {
        address[] memory oneOwner = new address[](1);
        oneOwner[0] = makeAddr("oneOwner");

        vm.startPrank(realOwner);
        teeOwnerAllowlistImpl.addAllowedTeeWalletProjectOwners(extensionId, oneOwner);
        // false
        assertFalse(teeOwnerAllowlistImpl.isAllowedTeeWalletProjectOwner(extensionId, owners[0]));
        assertFalse(teeOwnerAllowlistImpl.isAllowedTeeWalletProjectOwner(extensionId, owners[1]));
        // true
        assertTrue(teeOwnerAllowlistImpl.isAllowedTeeWalletProjectOwner(extensionId, oneOwner[0]));
        vm.stopPrank();
    }
    

    function testGetAllowedTeeMachineOwners() public {
        address[] memory allowedTeeMachineOwners;
        
        vm.startPrank(realOwner);
        allowedTeeMachineOwners = teeOwnerAllowlistImpl.getAllowedTeeMachineOwners(extensionId);
        assertEq(allowedTeeMachineOwners.length, 0);

        teeOwnerAllowlistImpl.addAllowedTeeMachineOwners(extensionId, owners);
        allowedTeeMachineOwners = teeOwnerAllowlistImpl.getAllowedTeeMachineOwners(extensionId);
        assertEq(allowedTeeMachineOwners.length, 2);
        assertEq(allowedTeeMachineOwners[0], owners[0]);
        assertEq(allowedTeeMachineOwners[1], owners[1]);
        vm.stopPrank();
    }
   

    function testGetAllowedTeeProjectWalletOwners() public {
        address[] memory allowedTeeProjectWalletOwners;
        
        vm.startPrank(realOwner);
        allowedTeeProjectWalletOwners = teeOwnerAllowlistImpl.getAllowedTeeWalletProjectOwners(extensionId);
        assertEq(allowedTeeProjectWalletOwners.length, 0);

        teeOwnerAllowlistImpl.addAllowedTeeWalletProjectOwners(extensionId, owners);
        allowedTeeProjectWalletOwners = teeOwnerAllowlistImpl.getAllowedTeeWalletProjectOwners(extensionId);
        assertEq(allowedTeeProjectWalletOwners.length, 2);
        assertEq(allowedTeeProjectWalletOwners[0], owners[0]);
        assertEq(allowedTeeProjectWalletOwners[1], owners[1]);
        vm.stopPrank();
    }
}
