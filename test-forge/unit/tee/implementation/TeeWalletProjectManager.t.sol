// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { TeeWalletProjectManager } from "../../../../contracts/tee/implementation/TeeWalletProjectManager.sol";
import { TeeWalletProjectManagerProxy } from "../../../../contracts/tee/proxy/TeeWalletProjectManagerProxy.sol";
import { ITeeExtensionRegistry } from "../../../../contracts/userInterfaces/tee/ITeeExtensionRegistry.sol";
import { ITeeWalletProjectManager } from "../../../../contracts/userInterfaces/tee/ITeeWalletProjectManager.sol";
import { ITeeWalletManager } from "../../../../contracts/userInterfaces/tee/ITeeWalletManager.sol";
import { ITeeOwnerAllowlist } from "../../../../contracts/userInterfaces/tee/ITeeOwnerAllowlist.sol";
import {
    ITeeWalletProjectOpTypeConstants
} from "../../../../contracts/userInterfaces/tee/ITeeWalletProjectOpTypeConstants.sol";
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

    address private submitAddress1;
    address private submitAddress2;
    bytes32 private opType1;
    bytes32 private opType2;
    address private projectOwner1;
    address private projectOwner2;
    bytes32 private defaultWalletId;

    ITeeWalletProjectOpTypeConstants private teeWalletProjectOpTypeConstants;

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

        teeWalletProjectOpTypeConstants =
            ITeeWalletProjectOpTypeConstants(makeAddr("teeWalletProjectOpTypeConstants"));
        submitAddress1 = makeAddr("submitAddress1");
        submitAddress2 = makeAddr("submitAddress2");
        opType1 = keccak256(abi.encode("opType1"));
        opType2 = keccak256(abi.encode("opType2"));
        projectOwner1 = makeAddr("projectOwner");
        projectOwner2 = makeAddr("projectOwner2");
        defaultWalletId = keccak256(abi.encode("defaultWalletId"));
        _mockIsTeeWalletProjectOwnerAllowed(projectOwner1, true);
        _mockIsTeeWalletProjectOwnerAllowed(projectOwner2, true);
    }

    function testCreateProjectRevertWrongOpType() public {
        bytes32 opType = keccak256(abi.encode("wrongOpType"));
        _mockIsOpTypeSupported(opType, false);
        vm.prank(projectOwner1);
        vm.expectRevert(ITeeWalletProjectManager.OpTypeNotSupported.selector);
        teeWalletProjectManager.createProject(0, opType, submitAddress1);
    }

    function testCreateProjectRevertOwnerNotAllowed() public {
        _mockIsOpTypeSupported(opType1, true);
        _mockIsTeeWalletProjectOwnerAllowed(projectOwner1, false);
        vm.prank(projectOwner1);
        vm.expectRevert(ITeeWalletProjectManager.OwnerNotAllowed.selector);
        teeWalletProjectManager.createProject(0, opType1, submitAddress1);
    }

    function testCreateProjectRevertSubmitAddressZero() public {
        _mockIsOpTypeSupported(opType1, true);
        vm.prank(projectOwner1);
        vm.expectRevert(ITeeWalletProjectManager.SubmitAddressZero.selector);
        teeWalletProjectManager.createProject(0, opType1, address(0));
    }

    function testCreateProject() public {
        _mockIsOpTypeSupported(opType1, true);
        _mockIsOpTypeSupported(opType2, true);
        vm.prank(projectOwner1);
        bytes32 projectId = teeWalletProjectManager.createProject(0, opType1, submitAddress1);
        assertEq(projectId, keccak256(abi.encode("PROJECT", projectOwner1, 1)));

        vm.prank(projectOwner2);
        bytes32 projectId2 = teeWalletProjectManager.createProject(0, opType2, submitAddress2);
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

    function testGetOpType() public {
        testCreateProject();
        bytes32 projectId1 = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        bytes32 projectId2 = keccak256(abi.encode("PROJECT", projectOwner2, 2));
        assertEq(teeWalletProjectManager.getOpType(projectId1), opType1);
        assertEq(teeWalletProjectManager.getOpType(projectId2), opType2);
    }

    function testGetSubmitAddress() public {
        testCreateProject();
        bytes32 projectId1 = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        bytes32 projectId2 = keccak256(abi.encode("PROJECT", projectOwner2, 2));
        assertEq(submitAddress1, teeWalletProjectManager.getSubmitAddress(projectId1));
        assertEq(submitAddress2, teeWalletProjectManager.getSubmitAddress(projectId2));
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

    function testSetDefaultWallet() public {
        testCreateProject();
        bytes32 projectId = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        _mockGetWalletProjectId(defaultWalletId, projectId);
        _mockGetWalletStatus(defaultWalletId, ITeeWalletManager.WalletStatus.PRODUCTION);
        vm.prank(projectOwner1);
        vm.expectEmit();
        emit ITeeWalletProjectManager.DefaultWalletSet(projectId, defaultWalletId);
        teeWalletProjectManager.setDefaultWallet(projectId, defaultWalletId);
    }

    // wallet not part of the project
    function testSetDefaultWalletRevert1() public {
        testCreateProject();
        bytes32 projectId1 = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        bytes32 projectId2 = keccak256(abi.encode("PROJECT", projectOwner2, 2));
        _mockGetWalletProjectId(defaultWalletId, projectId2);
        _mockGetWalletStatus(defaultWalletId, ITeeWalletManager.WalletStatus.PRODUCTION);
        vm.prank(projectOwner1);
        vm.expectRevert(ITeeWalletProjectManager.WalletNotPartOfProject.selector);
        teeWalletProjectManager.setDefaultWallet(projectId1, defaultWalletId);
    }

    // wallet not in production
    function testSetDefaultWalletRevert2() public {
        testCreateProject();
        bytes32 projectId = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        _mockGetWalletProjectId(defaultWalletId, projectId);
        _mockGetWalletStatus(defaultWalletId, ITeeWalletManager.WalletStatus.PAUSED);
        vm.prank(projectOwner1);
        vm.expectRevert(ITeeWalletProjectManager.WalletNotProductionReady.selector);
        teeWalletProjectManager.setDefaultWallet(projectId, defaultWalletId);
    }

    function testGetDefaultWalletInfo() public {
        testSetDefaultWallet();
        bytes32 projectId = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        (bytes32 walletId, bytes32 opType, address submitAddress) =
            teeWalletProjectManager.getDefaultWalletInfo(projectId);
        assertEq(walletId, keccak256(abi.encode("defaultWalletId")));
        assertEq(opType, opType1);
        assertEq(submitAddress, submitAddress1);
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

    function testGetOpTypeConstants() public {
        _mockGetWalletProjectOpTypeConstantsProvider();
        _mockGetOpTypeConstants();
        bytes32 projectId1 = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        assertEq(teeWalletProjectManager.getOpTypeConstants(projectId1), "opTypeConstants");
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

    function _mockIsOpTypeSupported(bytes32 _opType, bool _isSupported) internal {
        vm.mockCall(
            teeExtensionRegistryMock,
            abi.encodeWithSelector(
                ITeeExtensionRegistry.isWalletProjectOpTypeSupported.selector, 0, _opType
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

    function _mockGetWalletProjectOpTypeConstantsProvider() private {
        vm.mockCall(
            teeExtensionRegistryMock,
            abi.encodeWithSelector(
                ITeeExtensionRegistry.getWalletProjectOpTypeConstantsProvider.selector
            ),
            abi.encode(teeWalletProjectOpTypeConstants)
        );
    }

    function _mockGetOpTypeConstants() private {
        vm.mockCall(
            address(teeWalletProjectOpTypeConstants),
            abi.encodeWithSelector(
                ITeeWalletProjectOpTypeConstants.getOpTypeConstants.selector
            ),
            abi.encode(bytes("opTypeConstants"))
        );
    }
}