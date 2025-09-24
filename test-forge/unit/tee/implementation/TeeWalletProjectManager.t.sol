// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { TeeWalletProjectManager } from "../../../../contracts/tee/implementation/TeeWalletProjectManager.sol";
import { TeeWalletProjectManagerProxy } from "../../../../contracts/tee/proxy/TeeWalletProjectManagerProxy.sol";
import { ITeeExtensionRegistry } from "../../../../contracts/userInterfaces/tee/ITeeExtensionRegistry.sol";
import { ITeeWalletProjectManager } from "../../../../contracts/userInterfaces/tee/ITeeWalletProjectManager.sol";
import { ITeeWalletManager } from "../../../../contracts/userInterfaces/tee/ITeeWalletManager.sol";
import { ITeeOwnerAllowlist } from "../../../../contracts/userInterfaces/tee/ITeeOwnerAllowlist.sol";
import { IGovernanceSettings } from "flare-smart-contracts/contracts/userInterfaces/IGovernanceSettings.sol";

contract TeeWalletProjectManagerTest is Test {

    TeeWalletProjectManager private teeWalletProjectManager;
    TeeWalletProjectManager private teeWalletProjectManagerImpl;
    TeeWalletProjectManagerProxy private teeWalletProjectManagerProxy;

    address private teeExtensionRegistryMock;
    address private mockTeeOwnerAllowlist;
    address private mockTeeWalletManager;
    address private governance;
    address private addressUpdater;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    address private authorizationAddress1;
    address private authorizationAddress2;
    bytes32 private keyType1;
    bytes32 private keyType2;
    bytes32 private signingAlgo1;
    bytes32 private signingAlgo2;
    address private projectOwner1;
    address private projectOwner2;
    bytes32 private defaultWalletId;

    function setUp() public {
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");
        mockTeeOwnerAllowlist = makeAddr("mockTeeOwnerAllowlist");
        mockTeeWalletManager = makeAddr("mockTeeWalletManager");
        teeExtensionRegistryMock = makeAddr("teeExtensionRegistryMock");

        teeWalletProjectManagerImpl = new TeeWalletProjectManager();
        teeWalletProjectManagerProxy = new TeeWalletProjectManagerProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            address(teeWalletProjectManagerImpl)
        );
        teeWalletProjectManager = TeeWalletProjectManager(address(teeWalletProjectManagerProxy));

        vm.prank(addressUpdater);
        contractNameHashes = new bytes32[](4);
        contractAddresses = new address[](4);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractAddresses[0] = address(addressUpdater);
        contractNameHashes[1] = keccak256(abi.encode("TeeOwnerAllowlist"));
        contractAddresses[1] = address(mockTeeOwnerAllowlist);
        contractNameHashes[2] = keccak256(abi.encode("TeeWalletManager"));
        contractAddresses[2] = address(mockTeeWalletManager);
        contractNameHashes[3] = keccak256(abi.encode("TeeExtensionRegistry"));
        contractAddresses[3] = teeExtensionRegistryMock;
        teeWalletProjectManager.updateContractAddresses(contractNameHashes, contractAddresses);

        authorizationAddress1 = makeAddr("authorizationAddress1");
        authorizationAddress2 = makeAddr("authorizationAddress2");
        keyType1 = keccak256(abi.encode("keyType1"));
        keyType2 = keccak256(abi.encode("keyType2"));
        signingAlgo1 = keccak256(abi.encode("signingAlgo1"));
        signingAlgo2 = keccak256(abi.encode("signingAlgo2"));
        projectOwner1 = makeAddr("projectOwner");
        projectOwner2 = makeAddr("projectOwner2");
        defaultWalletId = keccak256(abi.encode("defaultWalletId"));
        _mockIsTeeWalletProjectOwnerAllowed(projectOwner1, true);
        _mockIsTeeWalletProjectOwnerAllowed(projectOwner2, true);
    }

    function testCreateProjectRevertOwnerNotAllowed() public {
        _mockIsTeeWalletProjectOwnerAllowed(projectOwner1, false);
        vm.prank(projectOwner1);
        vm.expectRevert(ITeeWalletProjectManager.OwnerNotAllowed.selector);
        teeWalletProjectManager.createProject(0, keyType1, signingAlgo1, authorizationAddress1);
    }

    function testCreateProjectRevertWrongKeyType() public {
        _mockIsKeyTypeSupported(keyType1, false);
        vm.prank(projectOwner1);
        vm.expectRevert(ITeeWalletProjectManager.KeyTypeNotSupported.selector);
        teeWalletProjectManager.createProject(0, keyType1, signingAlgo1, authorizationAddress1);
    }

    function testCreateProjectRevertSigningAlgoNotSupported() public {
        _mockIsKeyTypeSupported(keyType1, true);
        _mockIsSigningAlgoSupported(keyType1, signingAlgo1, false);
        vm.prank(projectOwner1);
        vm.expectRevert(ITeeWalletProjectManager.SigningAlgoNotSupported.selector);
        teeWalletProjectManager.createProject(0, keyType1, signingAlgo1, authorizationAddress1);
    }

    function testCreateProjectRevertAuthorizationAddressZero() public {
        _mockIsKeyTypeSupported(keyType1, true);
        _mockIsSigningAlgoSupported(keyType1, signingAlgo1, true);
        vm.prank(projectOwner1);
        vm.expectRevert(ITeeWalletProjectManager.AuthorizationAddressZero.selector);
        teeWalletProjectManager.createProject(0, keyType1, signingAlgo1, address(0));
    }

    function testCreateProject() public {
        _mockIsKeyTypeSupported(keyType1, true);
        _mockIsSigningAlgoSupported(keyType1, signingAlgo1, true);
        vm.prank(projectOwner1);
        bytes32 projectId = teeWalletProjectManager.createProject(0, keyType1, signingAlgo1, authorizationAddress1);
        assertEq(projectId, keccak256(abi.encode("PROJECT", projectOwner1, 1)));

        _mockIsKeyTypeSupported(keyType2, true);
        _mockIsSigningAlgoSupported(keyType2, signingAlgo2, true);
        vm.prank(projectOwner2);
        bytes32 projectId2 = teeWalletProjectManager.createProject(0, keyType2, signingAlgo2, authorizationAddress2);
        assertEq(projectId2, keccak256(abi.encode("PROJECT", projectOwner2, 2)));
    }

    function testGetOwner() public {
        testCreateProject();
        bytes32 projectId1 = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        bytes32 projectId2 = keccak256(abi.encode("PROJECT", projectOwner2, 2));
        assertEq(projectOwner1, teeWalletProjectManager.getOwner(projectId1));
        assertEq(projectOwner2, teeWalletProjectManager.getOwner(projectId2));
    }

    function testGetExtensionId() public {
        bytes32 projectId = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        assertEq(teeWalletProjectManager.getExtensionId(projectId), 0);
        testCreateProject();
        assertEq(teeWalletProjectManager.getExtensionId(projectId), 0);
    }

    function testGetKeyType() public {
        testCreateProject();
        bytes32 projectId1 = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        bytes32 projectId2 = keccak256(abi.encode("PROJECT", projectOwner2, 2));
        assertEq(teeWalletProjectManager.getKeyType(projectId1), keyType1);
        assertEq(teeWalletProjectManager.getKeyType(projectId2), keyType2);
    }

    function testGetSigningAlgo() public {
        testCreateProject();
        bytes32 projectId1 = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        bytes32 projectId2 = keccak256(abi.encode("PROJECT", projectOwner2, 2));
        assertEq(teeWalletProjectManager.getSigningAlgo(projectId1), signingAlgo1);
        assertEq(teeWalletProjectManager.getSigningAlgo(projectId2), signingAlgo2);
    }

    function testGetAuthorizationAddress() public {
        testCreateProject();
        bytes32 projectId1 = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        bytes32 projectId2 = keccak256(abi.encode("PROJECT", projectOwner2, 2));
        assertEq(authorizationAddress1, teeWalletProjectManager.getAuthorizationAddress(projectId1));
        assertEq(authorizationAddress2, teeWalletProjectManager.getAuthorizationAddress(projectId2));
    }

    function testSetBackupManager() public {
        testCreateProject();
        bytes32 projectId = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        address backupManager = makeAddr("backupManager");
        vm.prank(projectOwner1);
        vm.expectEmit();
        emit ITeeWalletProjectManager.BackupManagerSet(projectId, backupManager);
        teeWalletProjectManager.setBackupManager(projectId, backupManager);
        assertEq(backupManager, teeWalletProjectManager.getBackupManager(projectId));
    }

    // revert if project doesn't exist
    function testSetBackupManagerRevert() public {
        address backupManager = makeAddr("backupManager");
        bytes32 projectId = keccak256(abi.encode("PROJECT", projectOwner1, 2));
        vm.expectRevert(ITeeWalletProjectManager.OnlyOwner.selector);
        teeWalletProjectManager.setBackupManager(projectId, backupManager);
    }

    function testSetBackupManagerRevert2() public {
        testCreateProject();
        bytes32 projectId = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        address backupManager = makeAddr("backupManager");
        vm.prank(projectOwner2);
        vm.expectRevert(ITeeWalletProjectManager.OnlyOwner.selector);
        teeWalletProjectManager.setBackupManager(projectId, backupManager);
    }

    function testProposeNewOwner() public {
        testCreateProject();
        bytes32 projectId1 = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        address newOwner = makeAddr("newOwner");
        _mockIsTeeWalletProjectOwnerAllowed(newOwner, true);
        vm.prank(projectOwner1);
        vm.expectEmit();
        emit ITeeWalletProjectManager.NewOwnerProposed(projectId1, newOwner);
        teeWalletProjectManager.proposeNewOwner(projectId1, newOwner);
        assertEq(newOwner, teeWalletProjectManager.proposedProjectOwner(projectId1));
    }

    function testProposeNewOwnerRevertOwnerNotAllowed() public {
        testCreateProject();
        bytes32 projectId1 = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        address newOwner = makeAddr("newOwner");
        _mockIsTeeWalletProjectOwnerAllowed(newOwner, false);
        vm.prank(projectOwner1);
        vm.expectRevert(ITeeWalletProjectManager.OwnerNotAllowed.selector);
        teeWalletProjectManager.proposeNewOwner(projectId1, newOwner);
    }

    function testConfirmOwnership() public {
        testProposeNewOwner();
        bytes32 projectId1 = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        address newOwner = makeAddr("newOwner");
        vm.prank(newOwner);
        vm.expectEmit();
        emit ITeeWalletProjectManager.OwnershipConfirmed(projectId1, newOwner);
        teeWalletProjectManager.confirmOwnership(projectId1);
        assertEq(newOwner, teeWalletProjectManager.getOwner(projectId1));
    }

    function testConfirmOwnershipRevertOnlyProposedOwner() public {
        testProposeNewOwner();
        bytes32 projectId1 = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        vm.prank(projectOwner2);
        vm.expectRevert(ITeeWalletProjectManager.OnlyProposedOwner.selector);
        teeWalletProjectManager.confirmOwnership(projectId1);
    }

    function testConfirmOwnershipRevertOwnerNotAllowed() public {
        testProposeNewOwner();
        bytes32 projectId1 = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        address newOwner = makeAddr("newOwner");
        _mockIsTeeWalletProjectOwnerAllowed(newOwner, false);
        vm.prank(newOwner);
        vm.expectRevert(ITeeWalletProjectManager.OwnerNotAllowed.selector);
        teeWalletProjectManager.confirmOwnership(projectId1);
    }

    //// Proxy upgrade
    function testUpgradeProxy() public {
        testCreateProject();
        bytes32 projectId1 = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        assertEq(projectOwner1, teeWalletProjectManager.getOwner(projectId1));
        assertEq(teeWalletProjectManager.implementation(), address(teeWalletProjectManagerImpl));
        // upgrade
        TeeWalletProjectManager newImpl = new TeeWalletProjectManager();
        vm.prank(governance);
        teeWalletProjectManager.upgradeToAndCall(address(newImpl), bytes(""));
        // check
        assertEq(teeWalletProjectManager.implementation(), address(newImpl));
        assertEq(teeWalletProjectManager.governance(), governance);
        assertEq(projectOwner1, teeWalletProjectManager.getOwner(projectId1));
    }

    function testUpgradeProxyRevertOnlyGovernance() public {
        TeeWalletProjectManager newImpl = new TeeWalletProjectManager();
        vm.expectRevert("only governance");
        teeWalletProjectManager.upgradeToAndCall(address(newImpl), bytes(""));
    }

    // should revert if trying to initialize again
    // revert in GovernedBase.initialise
    function testUpgradeProxyAndInitializeRevert() public {
        TeeWalletProjectManager newImpl = new TeeWalletProjectManager();
        vm.prank(governance);
        vm.expectRevert("initialised != false");
        teeWalletProjectManager.upgradeToAndCall(address(newImpl), abi.encodeCall(
            TeeWalletProjectManager.initialize, (
                IGovernanceSettings(makeAddr("governanceSettings")),
                governance,
                addressUpdater
            )
        ));
    }

    function _mockIsTeeWalletProjectOwnerAllowed(address _owner, bool _isAllowed) internal {
        vm.mockCall(
            mockTeeOwnerAllowlist,
            abi.encodeWithSelector(
                ITeeOwnerAllowlist.isAllowedTeeWalletProjectOwner.selector, 0, _owner
            ),
            abi.encode(_isAllowed)
        );
    }

    function _mockIsKeyTypeSupported(bytes32 _keyType, bool _isSupported) internal {
        vm.mockCall(
            teeExtensionRegistryMock,
            abi.encodeWithSelector(
                ITeeExtensionRegistry.isKeyTypeSupported.selector, 0, _keyType
            ),
            abi.encode(_isSupported)
        );
    }

    function _mockIsSigningAlgoSupported(bytes32 _keyType, bytes32 _signingAlgo, bool _isSupported) internal {
        vm.mockCall(
            teeExtensionRegistryMock,
            abi.encodeWithSelector(
                ITeeExtensionRegistry.isSigningAlgoSupported.selector, _keyType, _signingAlgo
            ),
            abi.encode(_isSupported)
        );
    }

    function _mockGetWalletProjectId(bytes32 _walletId, bytes32 _projectId) internal {
        vm.mockCall(
            mockTeeWalletManager,
            abi.encodeWithSelector(
                ITeeWalletManager.getWalletProjectId.selector,
                _walletId
            ),
            abi.encode(_projectId)
        );
    }

    function _mockGetWalletStatus(bytes32 _walletId, ITeeWalletManager.WalletStatus _status) internal {
        vm.mockCall(
            mockTeeWalletManager,
            abi.encodeWithSelector(
                ITeeWalletManager.getWalletStatus.selector,
                _walletId
            ),
            abi.encode(_status)
        );
    }
}