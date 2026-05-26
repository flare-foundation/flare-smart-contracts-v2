// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { FlareTeeManagerDeployer } from "../../../utils/FlareTeeManagerDeployer.sol";
import { IIFlareTeeManager } from "../../../../contracts/tee/interface/IIFlareTeeManager.sol";
import { IOwnerAllowlist } from "../../../../contracts/userInterfaces/tee/IOwnerAllowlist.sol";
import { ITeeExtensionStateVerifier } from "../../../../contracts/userInterfaces/tee/ITeeExtensionStateVerifier.sol";
import { ITeeCommonErrors } from "../../../../contracts/userInterfaces/tee/ITeeCommonErrors.sol";
import { IFlareGovernance } from "../../../../contracts/userInterfaces/IFlareGovernance.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

contract OwnerAllowlistFacetTest is Test {

    IIFlareTeeManager private flareTeeManager;

    uint256 private extensionId;
    uint256 private extensionId2;

    address private initialGovernance;
    address private addressUpdater;

    address private extensionOwner;
    address private extensionOwner2;

    address[] private owners;

    function setUp() public {
        extensionOwner = makeAddr("extensionOwner");
        extensionOwner2 = makeAddr("extensionOwner2");
        owners = new address[](2);
        owners[0] = makeAddr("owner1");
        owners[1] = makeAddr("owner2");

        initialGovernance = makeAddr("initialGovernance");
        addressUpdater = makeAddr("AddressUpdater");

        flareTeeManager = FlareTeeManagerDeployer.deployDay1Facets(FlareTeeManagerDeployer.Day1DeployParams({
            governanceSettings: IGovernanceSettings(makeAddr("governanceSettings")),
            initialGovernance: initialGovernance,
            addressUpdater: addressUpdater,
            availabilityCheckValidityDurationSeconds: 3600,
            signingPolicyValidityDurationInRewardEpochs: 6,
            challengeValidityDurationSeconds: 600,
            defaultFee: 1000,
            publicExtensionCreationEnabled: true,
            emergencyUnpauseGracePeriodSeconds: 7200
        }));
        vm.startPrank(initialGovernance);
        FlareTeeManagerDeployer.deployLaterFacets(flareTeeManager, FlareTeeManagerDeployer.LaterDeployParams({
            pauseBeforeUpgradeMinDurationSeconds: 600
        }));
        vm.stopPrank();

        // Update contract addresses so the diamond resolves AddressUpdater
        bytes32[] memory nameHashes = new bytes32[](6);
        nameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        nameHashes[1] = keccak256(abi.encode("FlareSystemsManager"));
        nameHashes[2] = keccak256(abi.encode("RewardManager"));
        nameHashes[3] = keccak256(abi.encode("Relay"));
        nameHashes[4] = keccak256(abi.encode("Fdc2Hub"));
        nameHashes[5] = keccak256(abi.encode("Fdc2Verification"));
        address[] memory addresses = new address[](6);
        addresses[0] = addressUpdater;
        addresses[1] = makeAddr("FlareSystemsManager");
        addresses[2] = makeAddr("RewardManager");
        addresses[3] = makeAddr("Relay");
        addresses[4] = makeAddr("Fdc2Hub");
        addresses[5] = makeAddr("Fdc2Verification");
        vm.prank(addressUpdater);
        flareTeeManager.updateContractAddresses(nameHashes, addresses);

        // Register two extensions via the diamond
        ITeeExtensionStateVerifier verifier = ITeeExtensionStateVerifier(address(0));
        address instructionsSender = makeAddr("instructionsSender");

        vm.prank(extensionOwner);
        extensionId = flareTeeManager.register(verifier, instructionsSender);

        vm.prank(extensionOwner2);
        extensionId2 = flareTeeManager.register(verifier, instructionsSender);
    }

    // =========================================================================
    // addAllowedTeeMachineOwners
    // =========================================================================

    function testAddAllowedTeeMachineOwnersRevertOnlyExtensionOwner() public {
        vm.expectRevert(ITeeCommonErrors.OnlyExtensionOwner.selector);
        flareTeeManager.addAllowedTeeMachineOwners(extensionId, owners);
    }

    function testAddAllowedTeeMachineOwners() public {
        vm.expectEmit();
        emit IOwnerAllowlist.AllowedTeeMachineOwnersAdded(extensionId, owners);
        vm.prank(extensionOwner);
        flareTeeManager.addAllowedTeeMachineOwners(extensionId, owners);
    }

    // =========================================================================
    // removeAllowedTeeMachineOwners
    // =========================================================================

    function testRemoveAllowedTeeMachineOwnersRevertOnlyExtensionOwner() public {
        // First add owners so there is something to remove
        vm.prank(extensionOwner);
        flareTeeManager.addAllowedTeeMachineOwners(extensionId, owners);

        vm.expectRevert(ITeeCommonErrors.OnlyExtensionOwner.selector);
        flareTeeManager.removeAllowedTeeMachineOwners(extensionId, owners);
    }

    function testRemoveAllowedTeeMachineOwners() public {
        vm.prank(extensionOwner);
        flareTeeManager.addAllowedTeeMachineOwners(extensionId, owners);

        vm.expectEmit();
        emit IOwnerAllowlist.AllowedTeeMachineOwnersRemoved(extensionId, owners);
        vm.prank(extensionOwner);
        flareTeeManager.removeAllowedTeeMachineOwners(extensionId, owners);

        address[] memory allowedOwners = flareTeeManager.getAllowedTeeMachineOwners(extensionId);
        assertEq(allowedOwners.length, 0);
    }

    // =========================================================================
    // addAllowedTeeWalletProjectOwners
    // =========================================================================

    function testAddAllowedTeeWalletProjectOwnersRevertOnlyExtensionOwner() public {
        vm.expectRevert(ITeeCommonErrors.OnlyExtensionOwner.selector);
        flareTeeManager.addAllowedTeeWalletProjectOwners(extensionId, owners);
    }

    function testAddAllowedTeeWalletProjectOwners() public {
        vm.expectEmit();
        emit IOwnerAllowlist.AllowedTeeWalletProjectOwnersAdded(extensionId, owners);
        vm.prank(extensionOwner);
        flareTeeManager.addAllowedTeeWalletProjectOwners(extensionId, owners);
    }

    // =========================================================================
    // removeAllowedTeeWalletProjectOwners
    // =========================================================================

    function testRemoveAllowedTeeWalletProjectOwnersRevertOnlyExtensionOwner() public {
        // First add owners so there is something to remove
        vm.prank(extensionOwner);
        flareTeeManager.addAllowedTeeWalletProjectOwners(extensionId, owners);

        vm.expectRevert(ITeeCommonErrors.OnlyExtensionOwner.selector);
        flareTeeManager.removeAllowedTeeWalletProjectOwners(extensionId, owners);
    }

    function testRemoveAllowedTeeWalletProjectOwners() public {
        vm.prank(extensionOwner);
        flareTeeManager.addAllowedTeeWalletProjectOwners(extensionId, owners);

        vm.expectEmit();
        emit IOwnerAllowlist.AllowedTeeWalletProjectOwnersRemoved(extensionId, owners);
        vm.prank(extensionOwner);
        flareTeeManager.removeAllowedTeeWalletProjectOwners(extensionId, owners);

        address[] memory allowedOwners = flareTeeManager.getAllowedTeeWalletProjectOwners(extensionId);
        assertEq(allowedOwners.length, 0);
    }

    // =========================================================================
    // allowAllTeeMachineOwners
    // =========================================================================

    function testAllowAllTeeMachineOwnersRevertOnlyExtensionOwner() public {
        vm.expectRevert(ITeeCommonErrors.OnlyExtensionOwner.selector);
        flareTeeManager.allowAllTeeMachineOwners(extensionId);
    }

    function testAllowAllTeeMachineOwners() public {
        assertFalse(flareTeeManager.isAllowedTeeMachineOwner(extensionId, owners[0]));

        vm.prank(extensionOwner2);
        flareTeeManager.addAllowedTeeMachineOwners(extensionId2, owners);
        assertTrue(flareTeeManager.isAllowedTeeMachineOwner(extensionId2, owners[0]));
        assertTrue(flareTeeManager.isAllowedTeeMachineOwner(extensionId2, owners[1]));

        vm.prank(extensionOwner);
        flareTeeManager.allowAllTeeMachineOwners(extensionId);
        assertTrue(flareTeeManager.isAllowedTeeMachineOwner(extensionId, owners[0]));
        assertTrue(flareTeeManager.isAllowedTeeMachineOwner(extensionId, owners[1]));
    }

    // =========================================================================
    // disallowAllTeeMachineOwners
    // =========================================================================

    function testDisallowAllTeeMachineOwnersRevertOnlyExtensionOwner() public {
        vm.prank(extensionOwner);
        flareTeeManager.allowAllTeeMachineOwners(extensionId);

        vm.expectRevert(ITeeCommonErrors.OnlyExtensionOwner.selector);
        flareTeeManager.disallowAllTeeMachineOwners(extensionId);
    }

    function testDisallowAllTeeMachineOwners() public {
        vm.prank(extensionOwner);
        flareTeeManager.allowAllTeeMachineOwners(extensionId);
        assertTrue(flareTeeManager.allTeeMachineOwnersAllowed(extensionId));
        assertTrue(flareTeeManager.isAllowedTeeMachineOwner(extensionId, owners[0]));

        vm.expectEmit();
        emit IOwnerAllowlist.AllTeeMachineOwnersDisallowed(extensionId);
        vm.prank(extensionOwner);
        flareTeeManager.disallowAllTeeMachineOwners(extensionId);

        assertFalse(flareTeeManager.allTeeMachineOwnersAllowed(extensionId));
        assertFalse(flareTeeManager.isAllowedTeeMachineOwner(extensionId, owners[0]));
    }

    // =========================================================================
    // allowAllTeeWalletProjectOwners
    // =========================================================================

    function testAllowAllTeeWalletProjectOwnersRevertOnlyExtensionOwner() public {
        vm.expectRevert(ITeeCommonErrors.OnlyExtensionOwner.selector);
        flareTeeManager.allowAllTeeWalletProjectOwners(extensionId);
    }

    function testAllowAllTeeWalletProjectOwners() public {
        assertFalse(flareTeeManager.isAllowedTeeWalletProjectOwner(extensionId, owners[0]));

        vm.prank(extensionOwner2);
        flareTeeManager.addAllowedTeeWalletProjectOwners(extensionId2, owners);
        assertTrue(flareTeeManager.isAllowedTeeWalletProjectOwner(extensionId2, owners[0]));
        assertTrue(flareTeeManager.isAllowedTeeWalletProjectOwner(extensionId2, owners[1]));

        vm.prank(extensionOwner);
        flareTeeManager.allowAllTeeWalletProjectOwners(extensionId);
        assertTrue(flareTeeManager.isAllowedTeeWalletProjectOwner(extensionId, owners[0]));
        assertTrue(flareTeeManager.isAllowedTeeWalletProjectOwner(extensionId, owners[1]));
    }

    // =========================================================================
    // disallowAllTeeWalletProjectOwners
    // =========================================================================

    function testDisallowAllTeeWalletProjectOwnersRevertOnlyExtensionOwner() public {
        vm.prank(extensionOwner);
        flareTeeManager.allowAllTeeWalletProjectOwners(extensionId);

        vm.expectRevert(ITeeCommonErrors.OnlyExtensionOwner.selector);
        flareTeeManager.disallowAllTeeWalletProjectOwners(extensionId);
    }

    function testDisallowAllTeeWalletProjectOwners() public {
        vm.prank(extensionOwner);
        flareTeeManager.allowAllTeeWalletProjectOwners(extensionId);
        assertTrue(flareTeeManager.allTeeWalletProjectOwnersAllowed(extensionId));
        assertTrue(flareTeeManager.isAllowedTeeWalletProjectOwner(extensionId, owners[0]));

        vm.expectEmit();
        emit IOwnerAllowlist.AllTeeWalletProjectOwnersDisallowed(extensionId);
        vm.prank(extensionOwner);
        flareTeeManager.disallowAllTeeWalletProjectOwners(extensionId);

        assertFalse(flareTeeManager.allTeeWalletProjectOwnersAllowed(extensionId));
        assertFalse(flareTeeManager.isAllowedTeeWalletProjectOwner(extensionId, owners[0]));
    }

    // =========================================================================
    // View functions
    // =========================================================================

    function testGetAllowedTeeMachineOwners() public {
        address[] memory allowedTeeMachineOwners;

        allowedTeeMachineOwners = flareTeeManager.getAllowedTeeMachineOwners(extensionId);
        assertEq(allowedTeeMachineOwners.length, 0);

        vm.prank(extensionOwner);
        flareTeeManager.addAllowedTeeMachineOwners(extensionId, owners);
        allowedTeeMachineOwners = flareTeeManager.getAllowedTeeMachineOwners(extensionId);
        assertEq(allowedTeeMachineOwners.length, 2);
        assertEq(allowedTeeMachineOwners[0], owners[0]);
        assertEq(allowedTeeMachineOwners[1], owners[1]);
    }

    function testGetAllowedTeeProjectWalletOwners() public {
        address[] memory allowedTeeProjectWalletOwners;

        allowedTeeProjectWalletOwners = flareTeeManager.getAllowedTeeWalletProjectOwners(extensionId);
        assertEq(allowedTeeProjectWalletOwners.length, 0);

        vm.prank(extensionOwner);
        flareTeeManager.addAllowedTeeWalletProjectOwners(extensionId, owners);
        allowedTeeProjectWalletOwners = flareTeeManager.getAllowedTeeWalletProjectOwners(extensionId);
        assertEq(allowedTeeProjectWalletOwners.length, 2);
        assertEq(allowedTeeProjectWalletOwners[0], owners[0]);
        assertEq(allowedTeeProjectWalletOwners[1], owners[1]);
    }

    function testAllTeeMachineOwnersAllowed() public {
        assertFalse(flareTeeManager.allTeeMachineOwnersAllowed(extensionId));

        vm.prank(extensionOwner);
        flareTeeManager.allowAllTeeMachineOwners(extensionId);
        assertTrue(flareTeeManager.allTeeMachineOwnersAllowed(extensionId));
    }

    function testAllTeeWalletProjectOwnersAllowed() public {
        assertFalse(flareTeeManager.allTeeWalletProjectOwnersAllowed(extensionId));

        vm.prank(extensionOwner);
        flareTeeManager.allowAllTeeWalletProjectOwners(extensionId);
        assertTrue(flareTeeManager.allTeeWalletProjectOwnersAllowed(extensionId));
    }

    function testIsAllowedTeeMachineOwner() public {
        assertFalse(flareTeeManager.isAllowedTeeMachineOwner(extensionId, owners[0]));
        assertFalse(flareTeeManager.isAllowedTeeMachineOwner(extensionId, owners[1]));

        vm.prank(extensionOwner);
        flareTeeManager.addAllowedTeeMachineOwners(extensionId, owners);

        assertTrue(flareTeeManager.isAllowedTeeMachineOwner(extensionId, owners[0]));
        assertTrue(flareTeeManager.isAllowedTeeMachineOwner(extensionId, owners[1]));
        assertFalse(flareTeeManager.isAllowedTeeMachineOwner(extensionId, makeAddr("nonOwner")));
    }

    function testIsAllowedTeeWalletProjectOwner() public {
        assertFalse(flareTeeManager.isAllowedTeeWalletProjectOwner(extensionId, owners[0]));
        assertFalse(flareTeeManager.isAllowedTeeWalletProjectOwner(extensionId, owners[1]));

        vm.prank(extensionOwner);
        flareTeeManager.addAllowedTeeWalletProjectOwners(extensionId, owners);

        assertTrue(flareTeeManager.isAllowedTeeWalletProjectOwner(extensionId, owners[0]));
        assertTrue(flareTeeManager.isAllowedTeeWalletProjectOwner(extensionId, owners[1]));
        assertFalse(flareTeeManager.isAllowedTeeWalletProjectOwner(extensionId, makeAddr("nonOwner")));
    }

    // =========================================================================
    // Global extension-owner allowlist (governance-gated)
    // =========================================================================

    function testAllExtensionOwnersAllowedInitiallyTrue() public view {
        // setUp deploys with publicExtensionCreationEnabled = true
        assertTrue(flareTeeManager.allExtensionOwnersAllowed());
    }

    function testDisallowAllExtensionOwners() public {
        vm.prank(initialGovernance);
        vm.expectEmit();
        emit IOwnerAllowlist.AllExtensionOwnersDisallowed();
        flareTeeManager.disallowAllExtensionOwners();
        assertFalse(flareTeeManager.allExtensionOwnersAllowed());
    }

    function testDisallowAllExtensionOwnersRevertOnlyGovernance() public {
        vm.expectRevert(IFlareGovernance.OnlyGovernance.selector);
        flareTeeManager.disallowAllExtensionOwners();
    }

    function testAllowAllExtensionOwners() public {
        vm.prank(initialGovernance);
        flareTeeManager.disallowAllExtensionOwners();
        vm.prank(initialGovernance);
        vm.expectEmit();
        emit IOwnerAllowlist.AllExtensionOwnersAllowed();
        flareTeeManager.allowAllExtensionOwners();
        assertTrue(flareTeeManager.allExtensionOwnersAllowed());
    }

    function testAllowAllExtensionOwnersRevertOnlyGovernance() public {
        vm.expectRevert(IFlareGovernance.OnlyGovernance.selector);
        flareTeeManager.allowAllExtensionOwners();
    }

    function testAddAllowedExtensionOwners() public {
        vm.prank(initialGovernance);
        vm.expectEmit();
        emit IOwnerAllowlist.AllowedExtensionOwnersAdded(owners);
        flareTeeManager.addAllowedExtensionOwners(owners);
        address[] memory got = flareTeeManager.getAllowedExtensionOwners();
        assertEq(got.length, 2);
        assertEq(got[0], owners[0]);
        assertEq(got[1], owners[1]);
    }

    function testAddAllowedExtensionOwnersRevertOnlyGovernance() public {
        vm.expectRevert(IFlareGovernance.OnlyGovernance.selector);
        flareTeeManager.addAllowedExtensionOwners(owners);
    }

    function testAddAllowedExtensionOwnersRevertInvalidAddress() public {
        address[] memory bad = new address[](1);
        bad[0] = address(0);
        vm.prank(initialGovernance);
        vm.expectRevert(ITeeCommonErrors.InvalidAddress.selector);
        flareTeeManager.addAllowedExtensionOwners(bad);
    }

    function testAddAllowedExtensionOwnersRevertAddressAlreadyInSet() public {
        vm.prank(initialGovernance);
        flareTeeManager.addAllowedExtensionOwners(owners);
        vm.prank(initialGovernance);
        vm.expectRevert(
            abi.encodeWithSelector(ITeeCommonErrors.AddressAlreadyInSet.selector, owners[0])
        );
        flareTeeManager.addAllowedExtensionOwners(owners);
    }

    function testRemoveAllowedExtensionOwners() public {
        vm.prank(initialGovernance);
        flareTeeManager.addAllowedExtensionOwners(owners);
        vm.prank(initialGovernance);
        vm.expectEmit();
        emit IOwnerAllowlist.AllowedExtensionOwnersRemoved(owners);
        flareTeeManager.removeAllowedExtensionOwners(owners);
        assertEq(flareTeeManager.getAllowedExtensionOwners().length, 0);
    }

    function testRemoveAllowedExtensionOwnersRevertOnlyGovernance() public {
        vm.expectRevert(IFlareGovernance.OnlyGovernance.selector);
        flareTeeManager.removeAllowedExtensionOwners(owners);
    }

    function testRemoveAllowedExtensionOwnersRevertAddressNotInSet() public {
        vm.prank(initialGovernance);
        vm.expectRevert(
            abi.encodeWithSelector(ITeeCommonErrors.AddressNotInSet.selector, owners[0])
        );
        flareTeeManager.removeAllowedExtensionOwners(owners);
    }

    function testIsAllowedExtensionOwner() public {
        // With allExtensionOwnersAllowed = true, every address passes.
        assertTrue(flareTeeManager.isAllowedExtensionOwner(owners[0]));
        assertTrue(flareTeeManager.isAllowedExtensionOwner(makeAddr("random")));
        // Once closed, only explicitly added addresses pass.
        vm.prank(initialGovernance);
        flareTeeManager.disallowAllExtensionOwners();
        assertFalse(flareTeeManager.isAllowedExtensionOwner(owners[0]));
        vm.prank(initialGovernance);
        flareTeeManager.addAllowedExtensionOwners(owners);
        assertTrue(flareTeeManager.isAllowedExtensionOwner(owners[0]));
        assertTrue(flareTeeManager.isAllowedExtensionOwner(owners[1]));
        assertFalse(flareTeeManager.isAllowedExtensionOwner(makeAddr("random")));
    }

    // =========================================================================
    // Empty-input reverts (all six add/remove methods)
    // =========================================================================

    function testAddAllowedExtensionOwnersRevertNoAddresses() public {
        vm.prank(initialGovernance);
        vm.expectRevert(ITeeCommonErrors.NoAddresses.selector);
        flareTeeManager.addAllowedExtensionOwners(new address[](0));
    }

    function testRemoveAllowedExtensionOwnersRevertNoAddresses() public {
        vm.prank(initialGovernance);
        vm.expectRevert(ITeeCommonErrors.NoAddresses.selector);
        flareTeeManager.removeAllowedExtensionOwners(new address[](0));
    }

    function testAddAllowedTeeMachineOwnersRevertNoAddresses() public {
        vm.prank(extensionOwner);
        vm.expectRevert(ITeeCommonErrors.NoAddresses.selector);
        flareTeeManager.addAllowedTeeMachineOwners(extensionId, new address[](0));
    }

    function testRemoveAllowedTeeMachineOwnersRevertNoAddresses() public {
        vm.prank(extensionOwner);
        vm.expectRevert(ITeeCommonErrors.NoAddresses.selector);
        flareTeeManager.removeAllowedTeeMachineOwners(extensionId, new address[](0));
    }

    function testAddAllowedTeeWalletProjectOwnersRevertNoAddresses() public {
        vm.prank(extensionOwner);
        vm.expectRevert(ITeeCommonErrors.NoAddresses.selector);
        flareTeeManager.addAllowedTeeWalletProjectOwners(extensionId, new address[](0));
    }

    function testRemoveAllowedTeeWalletProjectOwnersRevertNoAddresses() public {
        vm.prank(extensionOwner);
        vm.expectRevert(ITeeCommonErrors.NoAddresses.selector);
        flareTeeManager.removeAllowedTeeWalletProjectOwners(extensionId, new address[](0));
    }
}
