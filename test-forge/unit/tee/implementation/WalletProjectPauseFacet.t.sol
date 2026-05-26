// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { FlareTeeManagerDeployer } from "../../../utils/FlareTeeManagerDeployer.sol";
import { IIFlareTeeManager } from "../../../../contracts/tee/interface/IIFlareTeeManager.sol";
import { IWalletProjectPause } from "../../../../contracts/userInterfaces/tee/IWalletProjectPause.sol";
import { ITeeCommonErrors } from "../../../../contracts/userInterfaces/tee/ITeeCommonErrors.sol";
import { ITeeExtensionStateVerifier } from "../../../../contracts/userInterfaces/tee/ITeeExtensionStateVerifier.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

contract WalletProjectPauseFacetTest is Test {

    IIFlareTeeManager private flareTeeManager;

    address private initialGovernance;
    address private addressUpdater;
    address private extensionOwner;
    address private projectOwner;
    address private projectOwner2;

    uint256 private extensionId;
    bytes32 private projectId;
    bytes32 private projectId2;

    address[] private addrs;

    function setUp() public {
        initialGovernance = makeAddr("initialGovernance");
        addressUpdater = makeAddr("AddressUpdater");
        extensionOwner = makeAddr("extensionOwner");
        projectOwner = makeAddr("projectOwner");
        projectOwner2 = makeAddr("projectOwner2");

        addrs = new address[](2);
        addrs[0] = makeAddr("addr1");
        addrs[1] = makeAddr("addr2");

        flareTeeManager = FlareTeeManagerDeployer.deployDay1Facets(FlareTeeManagerDeployer.Day1DeployParams({
            governanceSettings: IGovernanceSettings(makeAddr("governanceSettings")),
            initialGovernance: initialGovernance,
            addressUpdater: addressUpdater,
            availabilityCheckValidityDurationSeconds: 3600,
            signingPolicyValidityDurationInRewardEpochs: 6,
            challengeValidityDurationSeconds: 600,
            defaultFee: 0,
            publicExtensionCreationEnabled: true,
            emergencyUnpauseGracePeriodSeconds: 7200
        }));
        vm.startPrank(initialGovernance);
        FlareTeeManagerDeployer.deployLaterFacets(flareTeeManager, FlareTeeManagerDeployer.LaterDeployParams({
            pauseBeforeUpgradeMinDurationSeconds: 600
        }));
        vm.stopPrank();

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

        vm.prank(extensionOwner);
        extensionId = flareTeeManager.register(ITeeExtensionStateVerifier(address(0)), makeAddr("instructionsSender"));

        bytes32 keyType = keccak256(abi.encode("keyType1"));
        bytes32 signingAlgo = keccak256(abi.encode("signingAlgo1"));
        bytes32[] memory keyTypes = new bytes32[](1);
        keyTypes[0] = keyType;
        bytes32[][] memory signingAlgosByKeyType = new bytes32[][](1);
        signingAlgosByKeyType[0] = new bytes32[](1);
        signingAlgosByKeyType[0][0] = signingAlgo;
        vm.prank(initialGovernance);
        flareTeeManager.addSystemSupportedKeyTypesAndSigningAlgos(keyTypes, signingAlgosByKeyType);
        vm.prank(extensionOwner);
        flareTeeManager.addSupportedKeyTypes(extensionId, keyTypes);

        address[] memory owners = new address[](2);
        owners[0] = projectOwner;
        owners[1] = projectOwner2;
        vm.prank(extensionOwner);
        flareTeeManager.addAllowedTeeWalletProjectOwners(extensionId, owners);

        vm.prank(projectOwner);
        projectId = flareTeeManager.createProject(extensionId, keyType, signingAlgo);
        vm.prank(projectOwner2);
        projectId2 = flareTeeManager.createProject(extensionId, keyType, signingAlgo);
    }

    // =========================================================================
    // addWalletProjectPausers
    // =========================================================================

    function testAddWalletProjectPausers() public {
        vm.expectEmit();
        emit IWalletProjectPause.WalletProjectPausersAdded(projectId, addrs);
        vm.prank(projectOwner);
        flareTeeManager.addWalletProjectPausers(projectId, addrs);

        assertTrue(flareTeeManager.isWalletProjectPauser(projectId, addrs[0]));
        assertTrue(flareTeeManager.isWalletProjectPauser(projectId, addrs[1]));
        address[] memory got = flareTeeManager.getWalletProjectPausers(projectId);
        assertEq(got.length, 2);
    }

    function testAddWalletProjectPausersRevertOnlyOwner() public {
        vm.expectRevert(ITeeCommonErrors.OnlyOwner.selector);
        flareTeeManager.addWalletProjectPausers(projectId, addrs);
    }

    function testAddWalletProjectPausersRevertInvalidAddress() public {
        address[] memory bad = new address[](1);
        bad[0] = address(0);
        vm.prank(projectOwner);
        vm.expectRevert(ITeeCommonErrors.InvalidAddress.selector);
        flareTeeManager.addWalletProjectPausers(projectId, bad);
    }

    function testAddWalletProjectPausersRevertAlreadyInSet() public {
        vm.prank(projectOwner);
        flareTeeManager.addWalletProjectPausers(projectId, addrs);
        vm.prank(projectOwner);
        vm.expectRevert(
            abi.encodeWithSelector(ITeeCommonErrors.AddressAlreadyInSet.selector, addrs[0])
        );
        flareTeeManager.addWalletProjectPausers(projectId, addrs);
    }

    // =========================================================================
    // removeWalletProjectPausers
    // =========================================================================

    function testRemoveWalletProjectPausers() public {
        vm.prank(projectOwner);
        flareTeeManager.addWalletProjectPausers(projectId, addrs);

        vm.expectEmit();
        emit IWalletProjectPause.WalletProjectPausersRemoved(projectId, addrs);
        vm.prank(projectOwner);
        flareTeeManager.removeWalletProjectPausers(projectId, addrs);

        assertFalse(flareTeeManager.isWalletProjectPauser(projectId, addrs[0]));
        assertEq(flareTeeManager.getWalletProjectPausers(projectId).length, 0);
    }

    function testRemoveWalletProjectPausersRevertOnlyOwner() public {
        vm.prank(projectOwner);
        flareTeeManager.addWalletProjectPausers(projectId, addrs);
        vm.expectRevert(ITeeCommonErrors.OnlyOwner.selector);
        flareTeeManager.removeWalletProjectPausers(projectId, addrs);
    }

    function testRemoveWalletProjectPausersRevertNotInSet() public {
        vm.prank(projectOwner);
        vm.expectRevert(
            abi.encodeWithSelector(ITeeCommonErrors.AddressNotInSet.selector, addrs[0])
        );
        flareTeeManager.removeWalletProjectPausers(projectId, addrs);
    }

    // =========================================================================
    // addWalletProjectUnpausers
    // =========================================================================

    function testAddWalletProjectUnpausers() public {
        vm.expectEmit();
        emit IWalletProjectPause.WalletProjectUnpausersAdded(projectId, addrs);
        vm.prank(projectOwner);
        flareTeeManager.addWalletProjectUnpausers(projectId, addrs);

        assertTrue(flareTeeManager.isWalletProjectUnpauser(projectId, addrs[0]));
        assertTrue(flareTeeManager.isWalletProjectUnpauser(projectId, addrs[1]));
    }

    function testAddWalletProjectUnpausersRevertOnlyOwner() public {
        vm.expectRevert(ITeeCommonErrors.OnlyOwner.selector);
        flareTeeManager.addWalletProjectUnpausers(projectId, addrs);
    }

    function testAddWalletProjectUnpausersRevertInvalidAddress() public {
        address[] memory bad = new address[](1);
        bad[0] = address(0);
        vm.prank(projectOwner);
        vm.expectRevert(ITeeCommonErrors.InvalidAddress.selector);
        flareTeeManager.addWalletProjectUnpausers(projectId, bad);
    }

    function testAddWalletProjectUnpausersRevertAlreadyInSet() public {
        vm.prank(projectOwner);
        flareTeeManager.addWalletProjectUnpausers(projectId, addrs);
        vm.prank(projectOwner);
        vm.expectRevert(
            abi.encodeWithSelector(ITeeCommonErrors.AddressAlreadyInSet.selector, addrs[0])
        );
        flareTeeManager.addWalletProjectUnpausers(projectId, addrs);
    }

    // =========================================================================
    // removeWalletProjectUnpausers
    // =========================================================================

    function testRemoveWalletProjectUnpausers() public {
        vm.prank(projectOwner);
        flareTeeManager.addWalletProjectUnpausers(projectId, addrs);

        vm.expectEmit();
        emit IWalletProjectPause.WalletProjectUnpausersRemoved(projectId, addrs);
        vm.prank(projectOwner);
        flareTeeManager.removeWalletProjectUnpausers(projectId, addrs);

        assertFalse(flareTeeManager.isWalletProjectUnpauser(projectId, addrs[0]));
        assertEq(flareTeeManager.getWalletProjectUnpausers(projectId).length, 0);
    }

    function testRemoveWalletProjectUnpausersRevertOnlyOwner() public {
        vm.prank(projectOwner);
        flareTeeManager.addWalletProjectUnpausers(projectId, addrs);
        vm.expectRevert(ITeeCommonErrors.OnlyOwner.selector);
        flareTeeManager.removeWalletProjectUnpausers(projectId, addrs);
    }

    function testRemoveWalletProjectUnpausersRevertNotInSet() public {
        vm.prank(projectOwner);
        vm.expectRevert(
            abi.encodeWithSelector(ITeeCommonErrors.AddressNotInSet.selector, addrs[0])
        );
        flareTeeManager.removeWalletProjectUnpausers(projectId, addrs);
    }

    // =========================================================================
    // Project isolation: lists are keyed by projectId
    // =========================================================================

    function testListsAreIsolatedPerProject() public {
        vm.prank(projectOwner);
        flareTeeManager.addWalletProjectPausers(projectId, addrs);
        // project2 must have an empty pauser list
        assertEq(flareTeeManager.getWalletProjectPausers(projectId2).length, 0);
        assertFalse(flareTeeManager.isWalletProjectPauser(projectId2, addrs[0]));
    }

    function testPauserAndUnpauserListsAreSeparate() public {
        vm.prank(projectOwner);
        flareTeeManager.addWalletProjectPausers(projectId, addrs);
        // unpauser list must remain empty
        assertEq(flareTeeManager.getWalletProjectUnpausers(projectId).length, 0);
        assertFalse(flareTeeManager.isWalletProjectUnpauser(projectId, addrs[0]));
    }

    // =========================================================================
    // pauseWallets / unpauseWallets — auth checks only (no PRODUCTION wallet here)
    // =========================================================================
    // The full action behavior (PRODUCTION -> PAUSED via pausers, PAUSED -> PRODUCTION
    // via unpausers) is covered in WalletManagerFacetTest where the setup helper
    // produces wallets in the required statuses.

    function testPauseWalletsRevertNotOwnerOrPauser() public {
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = keccak256("nonexistent");
        // Caller is not the owner of any project that owns `ids[0]` (it's not in any
        // project's storage either, so projectId == bytes32(0) and owner == address(0)).
        vm.prank(makeAddr("stranger"));
        vm.expectRevert(
            abi.encodeWithSelector(ITeeCommonErrors.NotOwnerOrPauser.selector, makeAddr("stranger"))
        );
        flareTeeManager.pauseWallets(ids);
    }

    function testUnpauseWalletsRevertNotOwnerOrUnpauser() public {
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = keccak256("nonexistent");
        vm.prank(makeAddr("stranger"));
        vm.expectRevert(
            abi.encodeWithSelector(ITeeCommonErrors.NotOwnerOrUnpauser.selector, makeAddr("stranger"))
        );
        flareTeeManager.unpauseWallets(ids);
    }

    // =========================================================================
    // Empty-input reverts
    // =========================================================================

    function testAddWalletProjectPausersRevertNoAddresses() public {
        vm.prank(projectOwner);
        vm.expectRevert(ITeeCommonErrors.NoAddresses.selector);
        flareTeeManager.addWalletProjectPausers(projectId, new address[](0));
    }

    function testRemoveWalletProjectPausersRevertNoAddresses() public {
        vm.prank(projectOwner);
        vm.expectRevert(ITeeCommonErrors.NoAddresses.selector);
        flareTeeManager.removeWalletProjectPausers(projectId, new address[](0));
    }

    function testAddWalletProjectUnpausersRevertNoAddresses() public {
        vm.prank(projectOwner);
        vm.expectRevert(ITeeCommonErrors.NoAddresses.selector);
        flareTeeManager.addWalletProjectUnpausers(projectId, new address[](0));
    }

    function testRemoveWalletProjectUnpausersRevertNoAddresses() public {
        vm.prank(projectOwner);
        vm.expectRevert(ITeeCommonErrors.NoAddresses.selector);
        flareTeeManager.removeWalletProjectUnpausers(projectId, new address[](0));
    }

    function testPauseWalletsRevertNoWalletIds() public {
        vm.prank(makeAddr("anyone"));
        vm.expectRevert(IWalletProjectPause.NoWalletIds.selector);
        flareTeeManager.pauseWallets(new bytes32[](0));
    }

    function testUnpauseWalletsRevertNoWalletIds() public {
        vm.prank(makeAddr("anyone"));
        vm.expectRevert(IWalletProjectPause.NoWalletIds.selector);
        flareTeeManager.unpauseWallets(new bytes32[](0));
    }
}
