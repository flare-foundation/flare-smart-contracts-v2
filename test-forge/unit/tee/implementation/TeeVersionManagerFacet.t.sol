// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { FlareTeeManagerDeployer } from "../../../utils/FlareTeeManagerDeployer.sol";
import { IIFlareTeeManager } from "../../../../contracts/tee/interface/IIFlareTeeManager.sol";
import { ITeeVersionManagerFacet } from "../../../../contracts/userInterfaces/tee/ITeeVersionManagerFacet.sol";
import { ITeeCommonErrors } from "../../../../contracts/userInterfaces/tee/ITeeCommonErrors.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import { ITeeExtensionStateVerifier } from "../../../../contracts/userInterfaces/tee/ITeeExtensionStateVerifier.sol";
import { SignatureHelper } from "../../../utils/SignatureHelper.sol";
import { Signature } from "../../../../contracts/userInterfaces/ISignature.sol";

contract TeeVersionManagerFacetTest is Test {

    IIFlareTeeManager private flareTeeManager;

    address private initialGovernance;
    address private addressUpdater;

    address private owner;
    uint256 private extensionId;
    bytes32 private sourceTeeGovernanceHash;
    bytes32 private targetTeeGovernanceHash;
    uint256 private teeUpgradeId;
    bytes32 private sourceCodeHash;
    bytes32 private targetCodeHash;
    bytes32 private sourcePlatform;
    bytes32 private targetPlatform;

    address[] private sourceSigners;
    uint256[] private sourcePrivateKeys;
    address[] private targetSigners;
    uint256[] private targetPrivateKeys;

    function setUp() public {
        owner = makeAddr("owner");
        teeUpgradeId = 0;
        sourceCodeHash = keccak256("sourceCodeHash");
        targetCodeHash = keccak256("targetCodeHash");
        sourcePlatform = keccak256("sourcePlatform");
        targetPlatform = keccak256("targetPlatform");

        initialGovernance = makeAddr("initialGovernance");
        addressUpdater = makeAddr("addressUpdater");

        flareTeeManager = FlareTeeManagerDeployer.deployDay1Facets(FlareTeeManagerDeployer.Day1DeployParams({
            governanceSettings: IGovernanceSettings(makeAddr("governanceSettings")),
            initialGovernance: initialGovernance,
            addressUpdater: addressUpdater,
            availabilityCheckValidityDurationSeconds: 3600,
            signingPolicyValidityDurationInRewardEpochs: 6,
            challengeValidityDurationSeconds: 600,
            defaultFee: 1000
        }));
        vm.startPrank(initialGovernance);
        FlareTeeManagerDeployer.deployLaterFacets(flareTeeManager, FlareTeeManagerDeployer.LaterDeployParams({
            pauseBeforeUpgradeMinDurationSeconds: 600
        }));
        vm.stopPrank();

        bytes32[] memory nameHashes = new bytes32[](6);
        address[] memory addresses = new address[](6);
        nameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        nameHashes[1] = keccak256(abi.encode("FlareSystemsManager"));
        nameHashes[2] = keccak256(abi.encode("RewardManager"));
        nameHashes[3] = keccak256(abi.encode("Relay"));
        nameHashes[4] = keccak256(abi.encode("Fdc2Hub"));
        nameHashes[5] = keccak256(abi.encode("Fdc2Verification"));
        addresses[0] = addressUpdater;
        addresses[1] = makeAddr("FlareSystemsManager");
        addresses[2] = makeAddr("RewardManager");
        addresses[3] = makeAddr("Relay");
        addresses[4] = makeAddr("Fdc2Hub");
        addresses[5] = makeAddr("Fdc2Verification");

        vm.prank(addressUpdater);
        flareTeeManager.updateContractAddresses(nameHashes, addresses);

        // Register extension via the diamond
        ITeeExtensionStateVerifier verifier = ITeeExtensionStateVerifier(address(0));
        vm.prank(owner);
        extensionId = flareTeeManager.register(verifier, makeAddr("instructionsSender"));

        // Add supported platforms via governance
        bytes32[] memory platforms = new bytes32[](2);
        platforms[0] = sourcePlatform;
        platforms[1] = targetPlatform;
        vm.prank(initialGovernance);
        flareTeeManager.addSystemSupportedPlatforms(platforms);

        // Set up source governance signers
        sourceSigners = new address[](1);
        sourcePrivateKeys = new uint256[](1);
        (sourceSigners[0], sourcePrivateKeys[0]) = makeAddrAndKey("sourceSigner1");

        // Set up target governance signers
        targetSigners = new address[](1);
        targetPrivateKeys = new uint256[](1);
        (targetSigners[0], targetPrivateKeys[0]) = makeAddrAndKey("targetSigner1");

        // Set source governance hash and add source version while it's current
        sourceTeeGovernanceHash = keccak256(abi.encode(sourceSigners, uint64(1)));
        vm.prank(owner);
        flareTeeManager.setNewTeeGovernance(extensionId, sourceSigners, 1);

        bytes32[] memory sourcePlatforms = new bytes32[](1);
        sourcePlatforms[0] = sourcePlatform;
        vm.prank(owner);
        flareTeeManager.addTeeVersion(extensionId, "v1.0.0", sourceCodeHash, sourcePlatforms, sourceTeeGovernanceHash);

        // Now set target governance hash
        targetTeeGovernanceHash = keccak256(abi.encode(targetSigners, uint64(1)));
        vm.prank(owner);
        flareTeeManager.setNewTeeGovernance(extensionId, targetSigners, 1);

        bytes32[] memory targetPlatforms = new bytes32[](1);
        targetPlatforms[0] = targetPlatform;
        vm.prank(owner);
        flareTeeManager.addTeeVersion(extensionId, "v2.0.0", targetCodeHash, targetPlatforms, targetTeeGovernanceHash);
    }

    // createNewTeeUpgrade
    function testCreateNewTeeUpgradeRevertOnlyExtensionOwner() public {
        vm.expectRevert(ITeeCommonErrors.OnlyExtensionOwner.selector);
        flareTeeManager.createNewTeeUpgrade(extensionId, sourceTeeGovernanceHash, targetTeeGovernanceHash);
    }

    function testCreateNewTeeUpgradeRevertInvalidFromGovernanceHash() public {
        vm.prank(owner);
        vm.expectRevert(ITeeVersionManagerFacet.InvalidFromGovernanceHash.selector);
        flareTeeManager.createNewTeeUpgrade(extensionId, keccak256("invalidHash"), targetTeeGovernanceHash);
    }

    function testCreateNewTeeUpgradeRevertInvalidToGovernanceHash() public {
        vm.prank(owner);
        vm.expectRevert(ITeeVersionManagerFacet.InvalidToGovernanceHash.selector);
        flareTeeManager.createNewTeeUpgrade(extensionId, sourceTeeGovernanceHash, keccak256("invalidHash"));
    }

    function testCreateNewTeeUpgrade() public {
        vm.prank(owner);
        vm.expectEmit();
        emit ITeeVersionManagerFacet.TeeUpgradeStarted(
            extensionId,
            teeUpgradeId,
            sourceTeeGovernanceHash,
            targetTeeGovernanceHash
        );
        assertEq(
            flareTeeManager.createNewTeeUpgrade(extensionId, sourceTeeGovernanceHash, targetTeeGovernanceHash),
            teeUpgradeId
        );
    }

    // addTeeUpgradePaths
    function testAddTeeUpgradePathsRevertInvalidUpgradeId() public {
        ITeeVersionManagerFacet.TeeUpgradePath[] memory upgradePaths = _getUpgradePaths();
        vm.expectRevert(ITeeVersionManagerFacet.InvalidUpgradeId.selector);
        flareTeeManager.addTeeUpgradePaths(teeUpgradeId, upgradePaths);
    }

    function testAddTeeUpgradePathsRevertOnlyExtensionOwner() public {
        testCreateNewTeeUpgrade();
        ITeeVersionManagerFacet.TeeUpgradePath[] memory upgradePaths = _getUpgradePaths();
        vm.expectRevert(ITeeCommonErrors.OnlyExtensionOwner.selector);
        flareTeeManager.addTeeUpgradePaths(teeUpgradeId, upgradePaths);
    }

    function testAddTeeUpgradePathsRevertUpgradeAlreadyFinalized() public {
        testFinalizeTeeUpgrade();
        ITeeVersionManagerFacet.TeeUpgradePath[] memory upgradePaths = _getUpgradePaths();
        vm.prank(owner);
        vm.expectRevert(ITeeVersionManagerFacet.UpgradeAlreadyFinalized.selector);
        flareTeeManager.addTeeUpgradePaths(teeUpgradeId, upgradePaths);
    }

    function testAddTeeUpgradePathsRevertNoUpgradePaths() public {
        testCreateNewTeeUpgrade();
        ITeeVersionManagerFacet.TeeUpgradePath[] memory upgradePaths =
            new ITeeVersionManagerFacet.TeeUpgradePath[](0);
        vm.prank(owner);
        vm.expectRevert(ITeeVersionManagerFacet.NoUpgradePaths.selector);
        flareTeeManager.addTeeUpgradePaths(teeUpgradeId, upgradePaths);
    }

    function testAddTeeUpgradePathsRevertNoSourceVersions() public {
        testCreateNewTeeUpgrade();
        ITeeVersionManagerFacet.TeeUpgradePath[] memory upgradePaths =
            new ITeeVersionManagerFacet.TeeUpgradePath[](1);
        vm.prank(owner);
        vm.expectRevert(ITeeVersionManagerFacet.NoSourceVersions.selector);
        flareTeeManager.addTeeUpgradePaths(teeUpgradeId, upgradePaths);
    }

    function testAddTeeUpgradePathsRevertNoTargetVersions() public {
        testCreateNewTeeUpgrade();
        ITeeVersionManagerFacet.TeeUpgradePath[] memory upgradePaths = _getUpgradePaths();
        upgradePaths[0].targetVersions = new ITeeVersionManagerFacet.TeeNodeVersion[](0);
        vm.prank(owner);
        vm.expectRevert(ITeeVersionManagerFacet.NoTargetVersions.selector);
        flareTeeManager.addTeeUpgradePaths(teeUpgradeId, upgradePaths);
    }

    function testAddTeeUpgradePathsRevertSourceCodeHashAndPlatformNotSupported() public {
        testCreateNewTeeUpgrade();
        ITeeVersionManagerFacet.TeeUpgradePath[] memory upgradePaths = _getUpgradePaths();
        upgradePaths[0].sourceVersions[0].codeHash = keccak256("unsupportedCodeHash");
        vm.prank(owner);
        vm.expectRevert(ITeeVersionManagerFacet.SourceCodeHashAndPlatformNotSupported.selector);
        flareTeeManager.addTeeUpgradePaths(teeUpgradeId, upgradePaths);
    }

    function testAddTeeUpgradePathsRevertSourceGovernanceHashMismatch() public {
        // Register a new code hash with the target governance hash, then use it as source
        bytes32 mismatchCodeHash = keccak256("mismatchCodeHash");
        bytes32[] memory mismatchPlatforms = new bytes32[](1);
        mismatchPlatforms[0] = sourcePlatform;
        vm.prank(owner);
        flareTeeManager.addTeeVersion(
            extensionId, "v3.0.0", mismatchCodeHash, mismatchPlatforms, targetTeeGovernanceHash
        );

        testCreateNewTeeUpgrade();
        ITeeVersionManagerFacet.TeeUpgradePath[] memory upgradePaths = _getUpgradePaths();
        upgradePaths[0].sourceVersions[0].codeHash = mismatchCodeHash;
        vm.prank(owner);
        vm.expectRevert(ITeeVersionManagerFacet.SourceGovernanceHashMismatch.selector);
        flareTeeManager.addTeeUpgradePaths(teeUpgradeId, upgradePaths);
    }

    function testAddTeeUpgradePathsRevertSourceVersionAlreadyExists() public {
        testAddTeeUpgradePaths();
        ITeeVersionManagerFacet.TeeUpgradePath[] memory upgradePaths = new ITeeVersionManagerFacet.TeeUpgradePath[](1);
        upgradePaths[0].sourceVersions = new ITeeVersionManagerFacet.TeeNodeVersion[](2);
        upgradePaths[0].sourceVersions[0] =
            ITeeVersionManagerFacet.TeeNodeVersion(sourceCodeHash, sourcePlatform);
        upgradePaths[0].sourceVersions[1] = upgradePaths[0].sourceVersions[0];
        upgradePaths[0].targetVersions = new ITeeVersionManagerFacet.TeeNodeVersion[](1);
        upgradePaths[0].targetVersions[0] =
            ITeeVersionManagerFacet.TeeNodeVersion(targetCodeHash, targetPlatform);
        vm.prank(owner);
        vm.expectRevert(ITeeVersionManagerFacet.SourceVersionAlreadyExists.selector);
        flareTeeManager.addTeeUpgradePaths(teeUpgradeId, upgradePaths);
    }

    function testAddTeeUpgradePathsRevertTargetVersionAlreadyExists() public {
        testAddTeeUpgradePaths();
        ITeeVersionManagerFacet.TeeUpgradePath[] memory upgradePaths = new ITeeVersionManagerFacet.TeeUpgradePath[](1);
        upgradePaths[0].sourceVersions = new ITeeVersionManagerFacet.TeeNodeVersion[](1);
        upgradePaths[0].sourceVersions[0] =
            ITeeVersionManagerFacet.TeeNodeVersion(sourceCodeHash, sourcePlatform);
        upgradePaths[0].targetVersions = new ITeeVersionManagerFacet.TeeNodeVersion[](2);
        upgradePaths[0].targetVersions[0] =
            ITeeVersionManagerFacet.TeeNodeVersion(targetCodeHash, targetPlatform);
        upgradePaths[0].targetVersions[1] = upgradePaths[0].targetVersions[0];
        vm.prank(owner);
        vm.expectRevert(ITeeVersionManagerFacet.TargetVersionAlreadyExists.selector);
        flareTeeManager.addTeeUpgradePaths(teeUpgradeId, upgradePaths);
    }

    function testAddTeeUpgradePathsRevertTargetCodeHashAndPlatformNotSupported() public {
        testCreateNewTeeUpgrade();
        ITeeVersionManagerFacet.TeeUpgradePath[] memory upgradePaths = _getUpgradePaths();
        upgradePaths[0].targetVersions[0].codeHash = keccak256("unsupportedTargetCodeHash");
        vm.prank(owner);
        vm.expectRevert(ITeeVersionManagerFacet.TargetCodeHashAndPlatformNotSupported.selector);
        flareTeeManager.addTeeUpgradePaths(teeUpgradeId, upgradePaths);
    }

    function testAddTeeUpgradePathsRevertTargetGovernanceHashMismatch() public {
        // Register a new code hash with the source governance hash, then use it as target
        // First switch governance back to source so we can add a version with source hash
        vm.prank(owner);
        flareTeeManager.setNewTeeGovernance(extensionId, sourceSigners, 1);

        bytes32 mismatchCodeHash = keccak256("mismatchTargetCodeHash");
        bytes32[] memory mismatchPlatforms = new bytes32[](1);
        mismatchPlatforms[0] = targetPlatform;
        vm.prank(owner);
        flareTeeManager.addTeeVersion(
            extensionId, "v4.0.0", mismatchCodeHash, mismatchPlatforms, sourceTeeGovernanceHash
        );

        // Switch governance back to target
        vm.prank(owner);
        flareTeeManager.setNewTeeGovernance(extensionId, targetSigners, 1);

        testCreateNewTeeUpgrade();
        ITeeVersionManagerFacet.TeeUpgradePath[] memory upgradePaths = _getUpgradePaths();
        upgradePaths[0].targetVersions[0].codeHash = mismatchCodeHash;
        vm.prank(owner);
        vm.expectRevert(ITeeVersionManagerFacet.TargetGovernanceHashMismatch.selector);
        flareTeeManager.addTeeUpgradePaths(teeUpgradeId, upgradePaths);
    }

    function testAddTeeUpgradePaths() public {
        testCreateNewTeeUpgrade();
        ITeeVersionManagerFacet.TeeUpgradePath[] memory upgradePaths = _getUpgradePaths();
        vm.prank(owner);
        vm.expectEmit();
        emit ITeeVersionManagerFacet.TeeUpgradePathsAdded(teeUpgradeId, upgradePaths);
        flareTeeManager.addTeeUpgradePaths(teeUpgradeId, upgradePaths);
    }

    // finalizeTeeUpgrade
    function testFinalizeTeeUpgradeRevertInvalidUpgradeId() public {
        vm.expectRevert(ITeeVersionManagerFacet.InvalidUpgradeId.selector);
        flareTeeManager.finalizeTeeUpgrade(teeUpgradeId);
    }

    function testFinalizeTeeUpgradeRevertOnlyExtensionOwner() public {
        testCreateNewTeeUpgrade();
        vm.expectRevert(ITeeCommonErrors.OnlyExtensionOwner.selector);
        flareTeeManager.finalizeTeeUpgrade(teeUpgradeId);
    }

    function testFinalizeTeeUpgradeRevertUpgradeAlreadyFinalized() public {
        testFinalizeTeeUpgrade();
        vm.prank(owner);
        vm.expectRevert(ITeeVersionManagerFacet.UpgradeAlreadyFinalized.selector);
        flareTeeManager.finalizeTeeUpgrade(teeUpgradeId);
    }

    function testFinalizeTeeUpgradeRevertNoUpgradePaths() public {
        testCreateNewTeeUpgrade();
        vm.prank(owner);
        vm.expectRevert(ITeeVersionManagerFacet.NoUpgradePaths.selector);
        flareTeeManager.finalizeTeeUpgrade(teeUpgradeId);
    }

    function testFinalizeTeeUpgrade() public {
        testAddTeeUpgradePaths();
        vm.prank(owner);
        vm.expectEmit();
        emit ITeeVersionManagerFacet.TeeUpgradeFinalized(teeUpgradeId);
        flareTeeManager.finalizeTeeUpgrade(teeUpgradeId);
    }

    // signTeeUpgrade
    function testSignTeeUpgradeRevertInvalidUpgradeId() public {
        Signature memory signature = _createSourceSignature();
        vm.expectRevert(ITeeVersionManagerFacet.InvalidUpgradeId.selector);
        flareTeeManager.signTeeUpgrade(teeUpgradeId, signature);
    }

    function testSignTeeUpgradeRevertUpgradeAlreadySigned() public {
        testSignTeeUpgrade();
        Signature memory signature = _createSourceSignature();
        vm.prank(owner);
        vm.expectRevert(ITeeVersionManagerFacet.UpgradeAlreadySigned.selector);
        flareTeeManager.signTeeUpgrade(teeUpgradeId, signature);
    }

    function testSignTeeUpgradeRevertUpgradeNotFinalized() public {
        testCreateNewTeeUpgrade();
        Signature memory signature = _createSourceSignature();
        vm.prank(owner);
        vm.expectRevert(ITeeVersionManagerFacet.UpgradeNotFinalized.selector);
        flareTeeManager.signTeeUpgrade(teeUpgradeId, signature);
    }

    function testSignTeeUpgrade() public {
        testFinalizeTeeUpgrade();
        // Sign with source signer
        Signature memory sourceSignature = _createSourceSignature();
        vm.prank(sourceSigners[0]);
        flareTeeManager.signTeeUpgrade(teeUpgradeId, sourceSignature);

        // Sign with target signer
        Signature memory targetSignature = _createTargetSignature();
        vm.prank(targetSigners[0]);
        vm.expectEmit();
        emit ITeeVersionManagerFacet.TeeUpgradeSigned(teeUpgradeId);
        flareTeeManager.signTeeUpgrade(teeUpgradeId, targetSignature);
    }

    function testSignTeeUpgrade1() public {
        // Set source governance with threshold 2 (needs 2 source signatures)
        address[] memory newSourceSigners = new address[](2);
        uint256[] memory newSourcePrivateKeys = new uint256[](2);
        (newSourceSigners[0], newSourcePrivateKeys[0]) = makeAddrAndKey("newSourceSigner1");
        (newSourceSigners[1], newSourcePrivateKeys[1]) = makeAddrAndKey("newSourceSigner2");
        vm.prank(owner);
        flareTeeManager.setNewTeeGovernance(extensionId, newSourceSigners, 2);
        bytes32 newSourceGovHash = keccak256(abi.encode(newSourceSigners, uint64(2)));

        // Re-register source code hash with new governance
        bytes32 newSourceCodeHash = keccak256("newSourceCodeHash1");
        bytes32[] memory srcPlatforms = new bytes32[](1);
        srcPlatforms[0] = sourcePlatform;
        vm.prank(owner);
        flareTeeManager.addTeeVersion(extensionId, "v5.0.0", newSourceCodeHash, srcPlatforms, newSourceGovHash);

        // Create upgrade with threshold-2 source governance
        vm.prank(owner);
        uint256 upgradeId = flareTeeManager.createNewTeeUpgrade(
            extensionId, newSourceGovHash, targetTeeGovernanceHash
        );

        ITeeVersionManagerFacet.TeeUpgradePath[] memory upgradePaths = new ITeeVersionManagerFacet.TeeUpgradePath[](1);
        upgradePaths[0].sourceVersions = new ITeeVersionManagerFacet.TeeNodeVersion[](1);
        upgradePaths[0].sourceVersions[0] =
            ITeeVersionManagerFacet.TeeNodeVersion(newSourceCodeHash, sourcePlatform);
        upgradePaths[0].targetVersions = new ITeeVersionManagerFacet.TeeNodeVersion[](1);
        upgradePaths[0].targetVersions[0] =
            ITeeVersionManagerFacet.TeeNodeVersion(targetCodeHash, targetPlatform);
        vm.prank(owner);
        flareTeeManager.addTeeUpgradePaths(upgradeId, upgradePaths);
        vm.prank(owner);
        flareTeeManager.finalizeTeeUpgrade(upgradeId);

        // Sign with target signer (threshold 1 - satisfied)
        bytes32 messageHash = keccak256(abi.encode(flareTeeManager.getTeeUpgradePaths(upgradeId)));
        Signature memory targetSig = SignatureHelper.createSignature(vm, messageHash, targetPrivateKeys[0]);
        vm.prank(targetSigners[0]);
        flareTeeManager.signTeeUpgrade(upgradeId, targetSig);

        // Sign with one source signer (threshold 2 - not yet satisfied)
        Signature memory sourceSig = SignatureHelper.createSignature(vm, messageHash, newSourcePrivateKeys[0]);
        vm.prank(newSourceSigners[0]);
        flareTeeManager.signTeeUpgrade(upgradeId, sourceSig);

        // Not signed yet because source needs 2
        assertFalse(flareTeeManager.isTeeUpgradeSigned(upgradeId));
    }

    function testSignTeeUpgrade2() public {
        // Set target governance with threshold 2 (needs 2 target signatures)
        address[] memory newTargetSigners = new address[](2);
        uint256[] memory newTargetPrivateKeys = new uint256[](2);
        (newTargetSigners[0], newTargetPrivateKeys[0]) = makeAddrAndKey("newTargetSigner1");
        (newTargetSigners[1], newTargetPrivateKeys[1]) = makeAddrAndKey("newTargetSigner2");
        vm.prank(owner);
        flareTeeManager.setNewTeeGovernance(extensionId, newTargetSigners, 2);
        bytes32 newTargetGovHash = keccak256(abi.encode(newTargetSigners, uint64(2)));

        // Re-register target code hash with new governance
        bytes32 newTargetCodeHash = keccak256("newTargetCodeHash2");
        bytes32[] memory tgtPlatforms = new bytes32[](1);
        tgtPlatforms[0] = targetPlatform;
        vm.prank(owner);
        flareTeeManager.addTeeVersion(extensionId, "v6.0.0", newTargetCodeHash, tgtPlatforms, newTargetGovHash);

        // Create upgrade with threshold-2 target governance
        vm.prank(owner);
        uint256 upgradeId = flareTeeManager.createNewTeeUpgrade(
            extensionId, sourceTeeGovernanceHash, newTargetGovHash
        );

        ITeeVersionManagerFacet.TeeUpgradePath[] memory upgradePaths = new ITeeVersionManagerFacet.TeeUpgradePath[](1);
        upgradePaths[0].sourceVersions = new ITeeVersionManagerFacet.TeeNodeVersion[](1);
        upgradePaths[0].sourceVersions[0] =
            ITeeVersionManagerFacet.TeeNodeVersion(sourceCodeHash, sourcePlatform);
        upgradePaths[0].targetVersions = new ITeeVersionManagerFacet.TeeNodeVersion[](1);
        upgradePaths[0].targetVersions[0] =
            ITeeVersionManagerFacet.TeeNodeVersion(newTargetCodeHash, targetPlatform);
        vm.prank(owner);
        flareTeeManager.addTeeUpgradePaths(upgradeId, upgradePaths);
        vm.prank(owner);
        flareTeeManager.finalizeTeeUpgrade(upgradeId);

        // Sign with source signer (threshold 1 - satisfied)
        bytes32 messageHash = keccak256(abi.encode(flareTeeManager.getTeeUpgradePaths(upgradeId)));
        Signature memory sourceSig = SignatureHelper.createSignature(vm, messageHash, sourcePrivateKeys[0]);
        vm.prank(sourceSigners[0]);
        flareTeeManager.signTeeUpgrade(upgradeId, sourceSig);

        // Sign with one target signer (threshold 2 - not yet satisfied)
        Signature memory targetSig = SignatureHelper.createSignature(vm, messageHash, newTargetPrivateKeys[0]);
        vm.prank(newTargetSigners[0]);
        flareTeeManager.signTeeUpgrade(upgradeId, targetSig);

        // Not signed yet because target needs 2
        assertFalse(flareTeeManager.isTeeUpgradeSigned(upgradeId));
    }

    // isTeeUpgradePathValid
    function testIsTeeUpgradePathValidRevertInvalidUpgradeId() public {
        vm.expectRevert(ITeeVersionManagerFacet.InvalidUpgradeId.selector);
        flareTeeManager.isTeeUpgradePathValid(
            teeUpgradeId, extensionId, sourceCodeHash, sourcePlatform, targetCodeHash, targetPlatform
        );
    }

    function testIsTeeUpgradePathValidRevertExtensionIdMismatch() public {
        testAddTeeUpgradePaths();
        vm.expectRevert(ITeeCommonErrors.ExtensionIdMismatch.selector);
        flareTeeManager.isTeeUpgradePathValid(
            teeUpgradeId, extensionId + 1, sourceCodeHash, sourcePlatform, targetCodeHash, targetPlatform
        );
    }

    function testIsTeeUpgradePathValidRevertUpgradeNotFinalized() public {
        testAddTeeUpgradePaths();
        vm.expectRevert(ITeeVersionManagerFacet.UpgradeNotFinalized.selector);
        flareTeeManager.isTeeUpgradePathValid(
            teeUpgradeId, extensionId, sourceCodeHash, sourcePlatform, targetCodeHash, targetPlatform
        );
    }

    function testIsTeeUpgradePathValidTrue() public {
        testFinalizeTeeUpgrade();
        bool isValid = flareTeeManager.isTeeUpgradePathValid(
            teeUpgradeId, extensionId, sourceCodeHash, sourcePlatform, targetCodeHash, targetPlatform
        );
        assertEq(isValid, true);
    }

    function testIsTeeUpgradePathValidFalse1() public {
        testFinalizeTeeUpgrade();
        bool isValid = flareTeeManager.isTeeUpgradePathValid(
            teeUpgradeId, extensionId, keccak256("wrongSourceCodeHash"), sourcePlatform, targetCodeHash, targetPlatform
        );
        assertEq(isValid, false);
    }

    function testIsTeeUpgradePathValidFalse2() public {
        testFinalizeTeeUpgrade();
        bool isValid = flareTeeManager.isTeeUpgradePathValid(
            teeUpgradeId, extensionId, sourceCodeHash, sourcePlatform, keccak256("wrongTargetCodeHash"), targetPlatform
        );
        assertEq(isValid, false);
    }

    // isTeeUpgradeFinalized
    function testIsTeeUpgradeFinalizedRevertInvalidUpgradeId() public {
        vm.expectRevert(ITeeVersionManagerFacet.InvalidUpgradeId.selector);
        flareTeeManager.isTeeUpgradeFinalized(teeUpgradeId);
    }

    function testIsTeeUpgradeFinalizedFalse() public {
        testCreateNewTeeUpgrade();
        assertEq(
            flareTeeManager.isTeeUpgradeFinalized(teeUpgradeId),
            false
        );
    }

    function testIsTeeUpgradeFinalizedTrue() public {
        testFinalizeTeeUpgrade();
        assertEq(
            flareTeeManager.isTeeUpgradeFinalized(teeUpgradeId),
            true
        );
    }

    // isTeeUpgradeSigned
    function testIsTeeUpgradeSignedRevertInvalidUpgradeId() public {
        vm.expectRevert(ITeeVersionManagerFacet.InvalidUpgradeId.selector);
        flareTeeManager.isTeeUpgradeSigned(teeUpgradeId);
    }

    function testIsTeeUpgradeSignedFalse() public {
        testCreateNewTeeUpgrade();
        assertEq(
            flareTeeManager.isTeeUpgradeSigned(teeUpgradeId),
            false
        );
    }

    function testIsTeeUpgradeSignedTrue() public {
        testSignTeeUpgrade();
        assertEq(
            flareTeeManager.isTeeUpgradeSigned(teeUpgradeId),
            true
        );
    }

    // getTeeUpgradesCount
    function testGetTeeUpgradesCount() public {
        uint256 count = flareTeeManager.getTeeUpgradesCount();
        assertEq(count, 0);
        testCreateNewTeeUpgrade();
        count = flareTeeManager.getTeeUpgradesCount();
        assertEq(count, 1);
    }

    // getTeeUpgradePaths
    function testGetTeeUpgradePathsRevertInvalidUpgradeId() public {
        vm.expectRevert(ITeeVersionManagerFacet.InvalidUpgradeId.selector);
        flareTeeManager.getTeeUpgradePaths(teeUpgradeId);
    }

    function testGetTeeUpgradePaths() public {
        ITeeVersionManagerFacet.TeeUpgradePath[] memory upgradePaths = _getUpgradePaths();
        testSignTeeUpgrade();
        ITeeVersionManagerFacet.TeeUpgradePath[] memory returnedUpgradePaths =
            flareTeeManager.getTeeUpgradePaths(teeUpgradeId);
        assertEq(returnedUpgradePaths.length, 1);
        assertEq(returnedUpgradePaths[0].sourceVersions[0].codeHash, upgradePaths[0].sourceVersions[0].codeHash);
        assertEq(returnedUpgradePaths[0].sourceVersions[0].platform, upgradePaths[0].sourceVersions[0].platform);
    }

    // getTeeUpgradeSignatures
    function testGetTeeUpgradeSignaturesRevertInvalidUpgradeId() public {
        vm.expectRevert(ITeeVersionManagerFacet.InvalidUpgradeId.selector);
        flareTeeManager.getTeeUpgradeSignatures(teeUpgradeId);
    }

    function testGetTeeUpgradeSignatures() public {
        testSignTeeUpgrade();
        (Signature[] memory source, Signature[] memory target) =
            flareTeeManager.getTeeUpgradeSignatures(teeUpgradeId);
        Signature memory sourceSignature = _createSourceSignature();
        Signature memory targetSignature = _createTargetSignature();
        assertEq(sourceSignature.v, source[0].v);
        assertEq(sourceSignature.r, source[0].r);
        assertEq(sourceSignature.s, source[0].s);
        assertEq(targetSignature.v, target[0].v);
        assertEq(targetSignature.r, target[0].r);
        assertEq(targetSignature.s, target[0].s);
    }

    function _getUpgradePaths()
        private view
        returns (ITeeVersionManagerFacet.TeeUpgradePath[] memory)
    {
        ITeeVersionManagerFacet.TeeUpgradePath[] memory upgradePaths = new ITeeVersionManagerFacet.TeeUpgradePath[](1);
        upgradePaths[0].sourceVersions = new ITeeVersionManagerFacet.TeeNodeVersion[](1);
        upgradePaths[0].sourceVersions[0] =
            ITeeVersionManagerFacet.TeeNodeVersion(sourceCodeHash, sourcePlatform);
        upgradePaths[0].targetVersions = new ITeeVersionManagerFacet.TeeNodeVersion[](1);
        upgradePaths[0].targetVersions[0] =
            ITeeVersionManagerFacet.TeeNodeVersion(targetCodeHash, targetPlatform);
        return upgradePaths;
    }

    function _createSourceSignature()
        private view
        returns (Signature memory)
    {
        bytes32 messageHash = keccak256(abi.encode(_getUpgradePaths()));
        return SignatureHelper.createSignature(vm, messageHash, sourcePrivateKeys[0]);
    }

    function _createTargetSignature()
        private view
        returns (Signature memory)
    {
        bytes32 messageHash = keccak256(abi.encode(_getUpgradePaths()));
        return SignatureHelper.createSignature(vm, messageHash, targetPrivateKeys[0]);
    }
}
