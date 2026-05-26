// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { FlareTeeManagerDeployer } from "../../../utils/FlareTeeManagerDeployer.sol";
import { IIFlareTeeManager } from "../../../../contracts/tee/interface/IIFlareTeeManager.sol";
import {
    IWalletProjectManager
} from "../../../../contracts/userInterfaces/tee/IWalletProjectManager.sol";
import { ITeeExtensionStateVerifier } from "../../../../contracts/userInterfaces/tee/ITeeExtensionStateVerifier.sol";
import { ITeeCommonErrors } from "../../../../contracts/userInterfaces/tee/ITeeCommonErrors.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

contract WalletProjectManagerFacetTest is Test {

    IIFlareTeeManager private flareTeeManager;

    address private initialGovernance;
    address private addressUpdater;

    bytes32 private keyType1;
    bytes32 private keyType2;
    bytes32 private signingAlgo1;
    bytes32 private signingAlgo2;
    address private projectOwner1;
    address private projectOwner2;
    bytes32 private defaultWalletId;

    uint256 private extensionId;

    function setUp() public {
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

        // Update contract addresses
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

        // Register an extension via the diamond
        address extensionOwner = makeAddr("extensionOwner");
        address instructionsSender = makeAddr("instructionsSender");
        vm.prank(extensionOwner);
        extensionId = flareTeeManager.register(ITeeExtensionStateVerifier(address(0)), instructionsSender);

        // Add supported key types and signing algos via governance
        keyType1 = keccak256(abi.encode("keyType1"));
        keyType2 = keccak256(abi.encode("keyType2"));
        signingAlgo1 = keccak256(abi.encode("signingAlgo1"));
        signingAlgo2 = keccak256(abi.encode("signingAlgo2"));

        bytes32[] memory keyTypes = new bytes32[](2);
        keyTypes[0] = keyType1;
        keyTypes[1] = keyType2;
        bytes32[][] memory signingAlgosByKeyType = new bytes32[][](2);
        signingAlgosByKeyType[0] = new bytes32[](1);
        signingAlgosByKeyType[0][0] = signingAlgo1;
        signingAlgosByKeyType[1] = new bytes32[](1);
        signingAlgosByKeyType[1][0] = signingAlgo2;
        vm.prank(initialGovernance);
        flareTeeManager.addSystemSupportedKeyTypesAndSigningAlgos(keyTypes, signingAlgosByKeyType);

        // Add supported key types to the extension
        vm.prank(extensionOwner);
        flareTeeManager.addSupportedKeyTypes(extensionId, keyTypes);

        projectOwner1 = makeAddr("projectOwner");
        projectOwner2 = makeAddr("projectOwner2");
        defaultWalletId = keccak256(abi.encode("defaultWalletId"));

        // Allowlist project owners
        address[] memory owners1 = new address[](1);
        owners1[0] = projectOwner1;
        vm.prank(extensionOwner);
        flareTeeManager.addAllowedTeeWalletProjectOwners(extensionId, owners1);

        address[] memory owners2 = new address[](1);
        owners2[0] = projectOwner2;
        vm.prank(extensionOwner);
        flareTeeManager.addAllowedTeeWalletProjectOwners(extensionId, owners2);
    }

    function testCreateProjectRevertOwnerNotAllowed() public {
        address notAllowed = makeAddr("notAllowed");
        vm.prank(notAllowed);
        vm.expectRevert(ITeeCommonErrors.OwnerNotAllowed.selector);
        flareTeeManager.createProject(extensionId, keyType1, signingAlgo1);
    }

    function testCreateProjectRevertWrongKeyType() public {
        bytes32 unsupportedKeyType = keccak256(abi.encode("unsupportedKeyType"));
        vm.prank(projectOwner1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeCommonErrors.KeyTypeNotSupported.selector,
                unsupportedKeyType
            )
        );
        flareTeeManager.createProject(extensionId, unsupportedKeyType, signingAlgo1);
    }

    function testCreateProjectRevertSigningAlgoNotSupported() public {
        bytes32 unsupportedSigningAlgo = keccak256(abi.encode("unsupportedSigningAlgo"));
        vm.prank(projectOwner1);
        vm.expectRevert(IWalletProjectManager.SigningAlgoNotSupported.selector);
        flareTeeManager.createProject(extensionId, keyType1, unsupportedSigningAlgo);
    }

    function testCreateProject() public {
        vm.prank(projectOwner1);
        bytes32 projectId = flareTeeManager.createProject(extensionId, keyType1, signingAlgo1);
        assertEq(projectId, keccak256(abi.encode("PROJECT", projectOwner1, 1)));

        vm.prank(projectOwner2);
        bytes32 projectId2 = flareTeeManager.createProject(extensionId, keyType2, signingAlgo2);
        assertEq(projectId2, keccak256(abi.encode("PROJECT", projectOwner2, 2)));
    }

    function testGetOwner() public {
        testCreateProject();
        bytes32 projectId1 = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        bytes32 projectId2 = keccak256(abi.encode("PROJECT", projectOwner2, 2));
        assertEq(projectOwner1, flareTeeManager.getOwner(projectId1));
        assertEq(projectOwner2, flareTeeManager.getOwner(projectId2));
    }

    function testGetExtensionId() public {
        bytes32 projectId = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        assertEq(flareTeeManager.getExtensionId(projectId), 0);
        testCreateProject();
        assertEq(flareTeeManager.getExtensionId(projectId), extensionId);
    }

    function testGetKeyType() public {
        testCreateProject();
        bytes32 projectId1 = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        bytes32 projectId2 = keccak256(abi.encode("PROJECT", projectOwner2, 2));
        assertEq(flareTeeManager.getKeyType(projectId1), keyType1);
        assertEq(flareTeeManager.getKeyType(projectId2), keyType2);
    }

    function testGetSigningAlgo() public {
        testCreateProject();
        bytes32 projectId1 = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        bytes32 projectId2 = keccak256(abi.encode("PROJECT", projectOwner2, 2));
        assertEq(flareTeeManager.getSigningAlgo(projectId1), signingAlgo1);
        assertEq(flareTeeManager.getSigningAlgo(projectId2), signingAlgo2);
    }

    function testSetBackupManager() public {
        testCreateProject();
        bytes32 projectId = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        address backupManager = makeAddr("backupManager");
        vm.prank(projectOwner1);
        vm.expectEmit();
        emit IWalletProjectManager.BackupManagerSet(projectId, backupManager);
        flareTeeManager.setBackupManager(projectId, backupManager);
        assertEq(backupManager, flareTeeManager.getBackupManager(projectId));
    }

    // revert if project doesn't exist
    function testSetBackupManagerRevert() public {
        address backupManager = makeAddr("backupManager");
        bytes32 projectId = keccak256(abi.encode("PROJECT", projectOwner1, 2));
        vm.expectRevert(ITeeCommonErrors.OnlyOwner.selector);
        flareTeeManager.setBackupManager(projectId, backupManager);
    }

    function testSetBackupManagerRevert2() public {
        testCreateProject();
        bytes32 projectId = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        address backupManager = makeAddr("backupManager");
        vm.prank(projectOwner2);
        vm.expectRevert(ITeeCommonErrors.OnlyOwner.selector);
        flareTeeManager.setBackupManager(projectId, backupManager);
    }

    function testProposeNewOwner() public {
        testCreateProject();
        bytes32 projectId1 = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        address newOwner = makeAddr("newOwner");
        // Allowlist new owner
        address extensionOwner = makeAddr("extensionOwner");
        address[] memory owners = new address[](1);
        owners[0] = newOwner;
        vm.prank(extensionOwner);
        flareTeeManager.addAllowedTeeWalletProjectOwners(extensionId, owners);

        vm.prank(projectOwner1);
        vm.expectEmit();
        emit IWalletProjectManager.NewOwnerProposed(projectId1, newOwner);
        flareTeeManager.proposeNewOwner(projectId1, newOwner);
    }

    function testProposeNewOwnerRevertOwnerNotAllowed() public {
        testCreateProject();
        bytes32 projectId1 = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        address newOwner = makeAddr("newOwner");
        // newOwner is NOT allowlisted
        vm.prank(projectOwner1);
        vm.expectRevert(ITeeCommonErrors.OwnerNotAllowed.selector);
        flareTeeManager.proposeNewOwner(projectId1, newOwner);
    }

    function testConfirmOwnership() public {
        testProposeNewOwner();
        bytes32 projectId1 = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        address newOwner = makeAddr("newOwner");
        vm.prank(newOwner);
        vm.expectEmit();
        emit IWalletProjectManager.OwnershipConfirmed(projectId1, newOwner);
        flareTeeManager.confirmOwnership(projectId1);
        assertEq(newOwner, flareTeeManager.getOwner(projectId1));
    }

    function testConfirmOwnershipRevertOnlyProposedOwner() public {
        testProposeNewOwner();
        bytes32 projectId1 = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        vm.prank(projectOwner2);
        vm.expectRevert(ITeeCommonErrors.OnlyProposedOwner.selector);
        flareTeeManager.confirmOwnership(projectId1);
    }

    function testConfirmOwnershipRevertOwnerNotAllowed() public {
        testProposeNewOwner();
        bytes32 projectId1 = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        address newOwner = makeAddr("newOwner");
        // Remove newOwner from allowlist
        address extensionOwner = makeAddr("extensionOwner");
        address[] memory owners = new address[](1);
        owners[0] = newOwner;
        vm.prank(extensionOwner);
        flareTeeManager.removeAllowedTeeWalletProjectOwners(extensionId, owners);

        vm.prank(newOwner);
        vm.expectRevert(ITeeCommonErrors.OwnerNotAllowed.selector);
        flareTeeManager.confirmOwnership(projectId1);
    }
}
