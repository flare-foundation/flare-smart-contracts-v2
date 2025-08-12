// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../../../../contracts/tee/implementation/TeeVersionManager.sol";
import "../../../../contracts/tee/proxy/TeeVersionManagerProxy.sol";

contract TeeVersionManagerTest is Test {

    TeeVersionManager private teeVersionManager;
    TeeVersionManager private teeVersionManagerImpl;
    TeeVersionManagerProxy private teeVersionManagerProxy;

    address private initialGovernance;
    address private addressUpdater;
    address private teeExtensionRegistry;
    address private teeGovernance;

    address private owner;
    uint256 private extensionId;
    bytes32 private sourceTeeGovernanceHash;
    bytes32 private targetTeeGovernanceHash;
    uint256 private teeUpgradeId;
    bytes32 private sourceCodeHash;
    bytes32 private targetCodeHash;
    bytes32 private sourcePlatform;
    bytes32 private targetPlatform;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    function setUp() public {
        owner = makeAddr("owner");
        extensionId = 1;
        sourceTeeGovernanceHash = keccak256("sourceTeeGovernanceHash");
        targetTeeGovernanceHash = keccak256("targetTeeGovernanceHash");
        teeUpgradeId = 0;
        sourceCodeHash = keccak256("sourceCodeHash");
        targetCodeHash = keccak256("targetCodeHash");
        sourcePlatform = keccak256("sourcePlatform");
        targetPlatform = keccak256("targetPlatform");

        initialGovernance = makeAddr("initialGovernance");
        addressUpdater = makeAddr("addressUpdater");

        teeVersionManagerImpl = new TeeVersionManager();
        teeVersionManagerProxy = new TeeVersionManagerProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            initialGovernance,
            addressUpdater,
            address(teeVersionManagerImpl)
        );
        teeVersionManager = TeeVersionManager(address(teeVersionManagerProxy));

        contractNameHashes = new bytes32[](3);
        contractAddresses = new address[](3);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("TeeExtensionRegistry"));
        contractNameHashes[2] = keccak256(abi.encode("TeeGovernance"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = makeAddr("TeeExtensionRegistry");
        contractAddresses[2] = makeAddr("TeeGovernance");

        vm.prank(addressUpdater);
        teeVersionManager.updateContractAddresses(contractNameHashes, contractAddresses);

        teeExtensionRegistry = address(teeVersionManager.teeExtensionRegistry());
        teeGovernance = address(teeVersionManager.teeGovernance());

        _mockIsGovernanceHashValid(sourceTeeGovernanceHash, true);
        _mockIsGovernanceHashValid(targetTeeGovernanceHash, true);
        _mockIsCodeHashPlatformSupported(sourceCodeHash, true);
        _mockIsCodeHashPlatformSupported(targetCodeHash, true);
        _mockCodeHashPlatformDisabled(false);
        _mockGetTeeGovernanceHash(sourceCodeHash, sourceTeeGovernanceHash);
        _mockGetTeeGovernanceHash(targetCodeHash, targetTeeGovernanceHash);

        vm.mockCall(
            teeExtensionRegistry,
            abi.encodeWithSelector(
                ITeeExtensionRegistry.getExtensionOwner.selector
            ),
            abi.encode(owner)
        );

        vm.mockCall(
            teeGovernance,
            abi.encodeWithSelector(
                ITeeGovernance.getTeeGovernanceThreshold.selector
            ),
            abi.encode(1)
        );

        vm.mockCall(
            teeGovernance,
            abi.encodeWithSelector(
                ITeeGovernance.isTeeGovernanceSigner.selector
            ),
            abi.encode(true)
        );
    }


    // createNewTeeUpgrade
    function testCreateNewTeeUpgradeRevertOnlyExtensionOwner() public {
        vm.expectRevert(ITeeVersionManager.OnlyExtensionOwner.selector);
        teeVersionManager.createNewTeeUpgrade(extensionId, sourceTeeGovernanceHash, targetTeeGovernanceHash);
    }


    function testCreateNewTeeUpgradeRevertInvalidFromGovernanceHash() public {
        _mockIsGovernanceHashValid(sourceTeeGovernanceHash, false);
        vm.prank(owner);
        vm.expectRevert(ITeeVersionManager.InvalidFromGovernanceHash.selector);
        teeVersionManager.createNewTeeUpgrade(extensionId, sourceTeeGovernanceHash, targetTeeGovernanceHash);
    }


    function testCreateNewTeeUpgradeRevertInvalidToGovernanceHash() public {
        _mockIsGovernanceHashValid(targetTeeGovernanceHash, false);
        vm.prank(owner);
        vm.expectRevert(ITeeVersionManager.InvalidToGovernanceHash.selector);
        teeVersionManager.createNewTeeUpgrade(extensionId, sourceTeeGovernanceHash, targetTeeGovernanceHash);
    }


    function testCreateNewTeeUpgrade() public {
        vm.prank(owner);
        vm.expectEmit();
        emit ITeeVersionManager.TeeUpgradeStarted(
            extensionId,
            teeUpgradeId,
            sourceTeeGovernanceHash,
            targetTeeGovernanceHash
        );
        assertEq(
            teeVersionManager.createNewTeeUpgrade(extensionId, sourceTeeGovernanceHash, targetTeeGovernanceHash),
            teeUpgradeId
        );
    }


    // addTeeUpgradePaths
    function testAddTeeUpgradePathsRevertInvalidUpgradeId() public {
        ITeeVersionManager.TeeUpgradePath[] memory upgradePaths = _getUpgradePaths();
        vm.expectRevert(ITeeVersionManager.InvalidUpgradeId.selector);
        teeVersionManager.addTeeUpgradePaths(teeUpgradeId, upgradePaths);
    }


    function testAddTeeUpgradePathsRevertOnlyExtensionOwner() public {
        testCreateNewTeeUpgrade();
        ITeeVersionManager.TeeUpgradePath[] memory upgradePaths = _getUpgradePaths();
        vm.expectRevert(ITeeVersionManager.OnlyExtensionOwner.selector);
        teeVersionManager.addTeeUpgradePaths(teeUpgradeId, upgradePaths);
    }


    function testAddTeeUpgradePathsRevertUpgradeAlreadyFinalized() public {
        testFinalizeTeeUpgrade();
        ITeeVersionManager.TeeUpgradePath[] memory upgradePaths = _getUpgradePaths();
        vm.prank(owner);
        vm.expectRevert(ITeeVersionManager.UpgradeAlreadyFinalized.selector);
        teeVersionManager.addTeeUpgradePaths(teeUpgradeId, upgradePaths);
    }


    function testAddTeeUpgradePathsRevertNoUpgradePaths() public {
        testCreateNewTeeUpgrade();
        ITeeVersionManager.TeeUpgradePath[] memory upgradePaths =
            new ITeeVersionManager.TeeUpgradePath[](0);
        vm.prank(owner);
        vm.expectRevert(ITeeVersionManager.NoUpgradePaths.selector);
        teeVersionManager.addTeeUpgradePaths(teeUpgradeId, upgradePaths);
    }


    function testAddTeeUpgradePathsRevertNoSourceVersions() public {
        testCreateNewTeeUpgrade();
        ITeeVersionManager.TeeUpgradePath[] memory upgradePaths =
            new ITeeVersionManager.TeeUpgradePath[](1);
        vm.prank(owner);
        vm.expectRevert(ITeeVersionManager.NoSourceVersions.selector);
        teeVersionManager.addTeeUpgradePaths(teeUpgradeId, upgradePaths);
    }


    function testAddTeeUpgradePathsRevertNoTargetVersions() public {
        testCreateNewTeeUpgrade();
        ITeeVersionManager.TeeUpgradePath[] memory upgradePaths = _getUpgradePaths();
        upgradePaths[0].targetVersions = new ITeeVersionManager.TeeNodeVersion[](0);
        vm.prank(owner);
        vm.expectRevert(ITeeVersionManager.NoTargetVersions.selector);
        teeVersionManager.addTeeUpgradePaths(teeUpgradeId, upgradePaths);
    }


    function testAddTeeUpgradePathsRevertSourceCodeHashAndPlatformNotSupported() public {
        testCreateNewTeeUpgrade();
        _mockIsCodeHashPlatformSupported(sourceCodeHash, false);
        ITeeVersionManager.TeeUpgradePath[] memory upgradePaths = _getUpgradePaths();
        vm.prank(owner);
        vm.expectRevert(ITeeVersionManager.SourceCodeHashAndPlatformNotSupported.selector);
        teeVersionManager.addTeeUpgradePaths(teeUpgradeId, upgradePaths);
    }


    function testAddTeeUpgradePathsRevertSourceGovernanceHashMismatch() public {
        testCreateNewTeeUpgrade();
        _mockGetTeeGovernanceHash(sourceCodeHash, keccak256(""));
        ITeeVersionManager.TeeUpgradePath[] memory upgradePaths = _getUpgradePaths();
        vm.prank(owner);
        vm.expectRevert(ITeeVersionManager.SourceGovernanceHashMismatch.selector);
        teeVersionManager.addTeeUpgradePaths(teeUpgradeId, upgradePaths);
    }


    function testAddTeeUpgradePathsRevertSourceVersionAlreadyExists() public {
        testAddTeeUpgradePaths();
        ITeeVersionManager.TeeUpgradePath[] memory upgradePaths = new ITeeVersionManager.TeeUpgradePath[](1);
        upgradePaths[0].sourceVersions = new ITeeVersionManager.TeeNodeVersion[](2);
        upgradePaths[0].sourceVersions[0] =
            ITeeVersionManager.TeeNodeVersion(sourceCodeHash, sourcePlatform);
        upgradePaths[0].sourceVersions[1] = upgradePaths[0].sourceVersions[0];
        upgradePaths[0].targetVersions = new ITeeVersionManager.TeeNodeVersion[](1);
        upgradePaths[0].targetVersions[0] =
            ITeeVersionManager.TeeNodeVersion(targetCodeHash, targetPlatform);
        vm.prank(owner);
        vm.expectRevert(ITeeVersionManager.SourceVersionAlreadyExists.selector);
        teeVersionManager.addTeeUpgradePaths(teeUpgradeId, upgradePaths);
    }

    function testAddTeeUpgradePathsRevertTargetVersionAlreadyExists() public {
        testAddTeeUpgradePaths();
        ITeeVersionManager.TeeUpgradePath[] memory upgradePaths = new ITeeVersionManager.TeeUpgradePath[](1);
        upgradePaths[0].sourceVersions = new ITeeVersionManager.TeeNodeVersion[](1);
        upgradePaths[0].sourceVersions[0] =
            ITeeVersionManager.TeeNodeVersion(sourceCodeHash, sourcePlatform);
        upgradePaths[0].targetVersions = new ITeeVersionManager.TeeNodeVersion[](2);
        upgradePaths[0].targetVersions[0] =
            ITeeVersionManager.TeeNodeVersion(targetCodeHash, targetPlatform);
        upgradePaths[0].targetVersions[1] = upgradePaths[0].targetVersions[0];
        vm.prank(owner);
        vm.expectRevert(ITeeVersionManager.TargetVersionAlreadyExists.selector);
        teeVersionManager.addTeeUpgradePaths(teeUpgradeId, upgradePaths);
    }


    function testAddTeeUpgradePathsRevertTargetCodeHashAndPlatformNotSupported() public {
        testCreateNewTeeUpgrade();
        _mockIsCodeHashPlatformSupported(targetCodeHash, false);
        ITeeVersionManager.TeeUpgradePath[] memory upgradePaths = _getUpgradePaths();
        vm.prank(owner);
        vm.expectRevert(ITeeVersionManager.TargetCodeHashAndPlatformNotSupported.selector);
        teeVersionManager.addTeeUpgradePaths(teeUpgradeId, upgradePaths);
    }


    function testAddTeeUpgradePathsRevertTargetGovernanceHashMismatch() public {
        testCreateNewTeeUpgrade();
        _mockGetTeeGovernanceHash(targetCodeHash, keccak256(""));
        ITeeVersionManager.TeeUpgradePath[] memory upgradePaths = _getUpgradePaths();
        vm.prank(owner);
        vm.expectRevert(ITeeVersionManager.TargetGovernanceHashMismatch.selector);
        teeVersionManager.addTeeUpgradePaths(teeUpgradeId, upgradePaths);
    }

    function testAddTeeUpgradePaths() public {
        testCreateNewTeeUpgrade();
        ITeeVersionManager.TeeUpgradePath[] memory upgradePaths = _getUpgradePaths();
        vm.prank(owner);
        vm.expectEmit();
        emit ITeeVersionManager.TeeUpgradePathAdded(teeUpgradeId, upgradePaths[0]);
        teeVersionManager.addTeeUpgradePaths(teeUpgradeId, upgradePaths);
    }


    // finalizeTeeUpgrade
    function testFinalizeTeeUpgradeRevertInvalidUpgradeId() public {
        vm.expectRevert(ITeeVersionManager.InvalidUpgradeId.selector);
        teeVersionManager.finalizeTeeUpgrade(teeUpgradeId);
    }


    function testFinalizeTeeUpgradeRevertOnlyExtensionOwner() public {
        testCreateNewTeeUpgrade();
        vm.expectRevert(ITeeVersionManager.OnlyExtensionOwner.selector);
        teeVersionManager.finalizeTeeUpgrade(teeUpgradeId);
    }


    function testFinalizeTeeUpgradeRevertUpgradeAlreadyFinalized() public {
        testFinalizeTeeUpgrade();
        vm.prank(owner);
        vm.expectRevert(ITeeVersionManager.UpgradeAlreadyFinalized.selector);
        teeVersionManager.finalizeTeeUpgrade(teeUpgradeId);
    }


    function testFinalizeTeeUpgradeRevertNoUpgradePaths() public {
        testCreateNewTeeUpgrade();
        vm.prank(owner);
        vm.expectRevert(ITeeVersionManager.NoUpgradePaths.selector);
        teeVersionManager.finalizeTeeUpgrade(teeUpgradeId);
    }


    function testFinalizeTeeUpgrade() public {
        testAddTeeUpgradePaths();
        vm.prank(owner);
        vm.expectEmit();
        emit ITeeVersionManager.TeeUpgradeFinalized(teeUpgradeId);
        teeVersionManager.finalizeTeeUpgrade(teeUpgradeId);
    }


    // signTeeUpgrade
    function testSignTeeUpgradeRevertInvalidUpgradeId() public {
        Signature memory signature = _createSignature();
        vm.expectRevert(ITeeVersionManager.InvalidUpgradeId.selector);
        teeVersionManager.signTeeUpgrade(teeUpgradeId, signature);
    }


    function testSignTeeUpgradeRevertUpgradeAlreadySigned() public {
        testSignTeeUpgrade();
        Signature memory signature = _createSignature();
        vm.prank(owner);
        vm.expectRevert(ITeeVersionManager.UpgradeAlreadySigned.selector);
        teeVersionManager.signTeeUpgrade(teeUpgradeId, signature);
    }


    function testSignTeeUpgradeRevertUpgradeNotFinalized() public {
        testCreateNewTeeUpgrade();
        Signature memory signature = _createSignature();
        vm.prank(owner);
        vm.expectRevert(ITeeVersionManager.UpgradeNotFinalized.selector);
        teeVersionManager.signTeeUpgrade(teeUpgradeId, signature);
    }


    function testSignTeeUpgrade() public {
        testFinalizeTeeUpgrade();
        Signature memory signature = _createSignature();
        vm.prank(owner);
        vm.expectEmit();
        emit ITeeVersionManager.TeeUpgradeSigned(teeUpgradeId);
        teeVersionManager.signTeeUpgrade(teeUpgradeId, signature);
    }


    // isTeeUpgradePathValid
    function testIsTeeUpgradePathValidRevertInvalidUpgradeId() public {
        vm.expectRevert(ITeeVersionManager.InvalidUpgradeId.selector);
        teeVersionManager.isTeeUpgradePathValid(
            teeUpgradeId, extensionId, sourceCodeHash, sourcePlatform, targetCodeHash, targetPlatform
        );
    }


    function testIsTeeUpgradePathValidRevertExtensionIdMismatch() public {
        testAddTeeUpgradePaths();
        vm.expectRevert(ITeeVersionManager.ExtensionIdMismatch.selector);
        teeVersionManager.isTeeUpgradePathValid(
            teeUpgradeId, extensionId + 1, sourceCodeHash, sourcePlatform, targetCodeHash, targetPlatform
        );
    }


    function testIsTeeUpgradePathValidRevertUpgradeNotFinalized() public {
        testAddTeeUpgradePaths();
        vm.expectRevert(ITeeVersionManager.UpgradeNotFinalized.selector);
        teeVersionManager.isTeeUpgradePathValid(
            teeUpgradeId, extensionId, sourceCodeHash, sourcePlatform, targetCodeHash, targetPlatform
        );
    }


    function testIsTeeUpgradePathValidTrue() public {
        testFinalizeTeeUpgrade();
        bool isValid = teeVersionManager.isTeeUpgradePathValid(
            teeUpgradeId, extensionId, sourceCodeHash, sourcePlatform, targetCodeHash, targetPlatform
        );
        assertEq(isValid, true);
    }


    function testIsTeeUpgradePathValidFalse() public {
        testFinalizeTeeUpgrade();
        bool isValid = teeVersionManager.isTeeUpgradePathValid(
            teeUpgradeId, extensionId, keccak256("wrongSourceCodeHash"), sourcePlatform, targetCodeHash, targetPlatform
        );
        assertEq(isValid, false);
    }


    // isTeeUpgradeFinalized
    function testIsTeeUpgradeFinalizedRevertInvalidUpgradeId() public {
        vm.expectRevert(ITeeVersionManager.InvalidUpgradeId.selector);
        teeVersionManager.isTeeUpgradeFinalized(teeUpgradeId);
    }


    function testIsTeeUpgradeFinalizedFalse() public {
        testCreateNewTeeUpgrade();
        assertEq(
            teeVersionManager.isTeeUpgradeFinalized(teeUpgradeId),
            false
        );
    }


    function testIsTeeUpgradeFinalizedTrue() public {
        testFinalizeTeeUpgrade();
        assertEq(
            teeVersionManager.isTeeUpgradeFinalized(teeUpgradeId),
            true
        );
    }


    // isTeeUpgradeSigned
    function testIsTeeUpgradeSignedRevertInvalidUpgradeId() public {
        vm.expectRevert(ITeeVersionManager.InvalidUpgradeId.selector);
        teeVersionManager.isTeeUpgradeSigned(teeUpgradeId);
    }


    function testIsTeeUpgradeSignedFalse() public {
        testCreateNewTeeUpgrade();
        assertEq(
            teeVersionManager.isTeeUpgradeSigned(teeUpgradeId),
            false
        );
    }


    function testIsTeeUpgradeSignedTrue() public {
        testSignTeeUpgrade();
        assertEq(
            teeVersionManager.isTeeUpgradeSigned(teeUpgradeId),
            true
        );
    }


    // getTeeUpgradesCount
    function testGetTeeUpgradesCount() public {
        uint256 count = teeVersionManager.getTeeUpgradesCount();
        assertEq(count, 0);
        testCreateNewTeeUpgrade();
        count = teeVersionManager.getTeeUpgradesCount();
        assertEq(count, 1);
    }


    // getTeeUpgradePaths
    function testGetTeeUpgradePathsRevertInvalidUpgradeId() public {
        vm.expectRevert(ITeeVersionManager.InvalidUpgradeId.selector);
        teeVersionManager.getTeeUpgradePaths(teeUpgradeId);
    }


    function testGetTeeUpgradePaths() public {
        ITeeVersionManager.TeeUpgradePath[] memory upgradePaths = _getUpgradePaths();
        testSignTeeUpgrade();
        ITeeVersionManager.TeeUpgradePath[] memory returnedUpgradePaths =
            teeVersionManager.getTeeUpgradePaths(teeUpgradeId);
        assertEq(returnedUpgradePaths.length, 1);
        assertEq(returnedUpgradePaths[0].sourceVersions[0].codeHash, upgradePaths[0].sourceVersions[0].codeHash);
        assertEq(returnedUpgradePaths[0].sourceVersions[0].platform, upgradePaths[0].sourceVersions[0].platform);
    }


    // getTeeUpgradeSignatures
    function testGetTeeUpgradeSignaturesRevertInvalidUpgradeId() public {
        vm.expectRevert(ITeeVersionManager.InvalidUpgradeId.selector);
        teeVersionManager.getTeeUpgradeSignatures(teeUpgradeId);
    }


    function testGetTeeUpgradeSignatures() public {
        testSignTeeUpgrade();
        (Signature[] memory source, Signature[] memory target) =
            teeVersionManager.getTeeUpgradeSignatures(teeUpgradeId);
        Signature memory signature = _createSignature();
        assertEq(signature.v, source[0].v);
        assertEq(signature.r, source[0].r);
        assertEq(signature.s, source[0].s);
        assertEq(signature.v, target[0].v);
        assertEq(signature.r, target[0].r);
        assertEq(signature.s, target[0].s);
    }


    function _mockIsGovernanceHashValid(bytes32 _governanceHash, bool _isValid) private {
        vm.mockCall(
            teeGovernance,
            abi.encodeWithSelector(
                ITeeGovernance.isGovernanceHashValid.selector,
                extensionId,
                _governanceHash
            ),
            abi.encode(_isValid)
        );
    }


    function _mockIsCodeHashPlatformSupported(bytes32 _codeHash, bool _isValid) private {
        vm.mockCall(
            teeExtensionRegistry,
            abi.encodeWithSelector(
                ITeeExtensionRegistry.isCodeHashPlatformSupported.selector,
                extensionId,
                _codeHash
            ),
            abi.encode(_isValid)
        );
    }


    function _mockCodeHashPlatformDisabled(bool _isDisabled) private {
        vm.mockCall(
            teeExtensionRegistry,
            abi.encodeWithSelector(
                ITeeExtensionRegistry.codeHashPlatformDisabled.selector
            ),
            abi.encode(_isDisabled)
        );
    }


    function _mockGetTeeGovernanceHash(bytes32 _codeHash, bytes32 _governanceHash) private {
        vm.mockCall(
            teeExtensionRegistry,
            abi.encodeWithSelector(
                ITeeExtensionRegistry.getTeeGovernanceHash.selector,
                extensionId,
                _codeHash
            ),
            abi.encode(_governanceHash)
        );
    }


    function _getUpgradePaths()
        private view
        returns (ITeeVersionManager.TeeUpgradePath[] memory)
    {
        ITeeVersionManager.TeeUpgradePath[] memory upgradePaths = new ITeeVersionManager.TeeUpgradePath[](1);
        upgradePaths[0].sourceVersions = new ITeeVersionManager.TeeNodeVersion[](1);
        upgradePaths[0].sourceVersions[0] =
            ITeeVersionManager.TeeNodeVersion(sourceCodeHash, sourcePlatform);
        upgradePaths[0].targetVersions = new ITeeVersionManager.TeeNodeVersion[](1);
        upgradePaths[0].targetVersions[0] =
            ITeeVersionManager.TeeNodeVersion(targetCodeHash, targetPlatform);
        return upgradePaths;
    }


    function _createSignature()
        private view
        returns (Signature memory)
    {
        bytes32 signedMessageHash =
            MessageHashUtils.toEthSignedMessageHash(keccak256(abi.encode(_getUpgradePaths())));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, signedMessageHash);
        return Signature(v, r, s);
    }
}