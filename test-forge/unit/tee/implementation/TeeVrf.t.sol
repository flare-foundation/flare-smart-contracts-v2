// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { TeeVrf } from "../../../../contracts/tee/implementation/TeeVrf.sol";
import { TeeVrfProxy } from "../../../../contracts/tee/proxy/TeeVrfProxy.sol";
import { ITeeVrf } from "../../../../contracts/userInterfaces/tee/ITeeVrf.sol";
import { ITeeWalletKeyManager } from "../../../../contracts/userInterfaces/tee/ITeeWalletKeyManager.sol";
import { ITeeWalletManager } from "../../../../contracts/userInterfaces/tee/ITeeWalletManager.sol";
import { ITeeWalletProjectManager } from "../../../../contracts/userInterfaces/tee/ITeeWalletProjectManager.sol";
import { IGovernanceSettings } from "flare-smart-contracts/contracts/userInterfaces/IGovernanceSettings.sol";

contract TeeVrfTest is Test {

    // selector for sendSystemInstructions(bytes32,address[],bytes32,bytes32,bytes,address[],uint64)
    bytes4 private constant SEND_SYSTEM_INSTRUCTIONS_SELECTOR =
        bytes4(keccak256("sendSystemInstructions(bytes32,address[],bytes32,bytes32,bytes,address[],uint64)"));

    TeeVrf private teeVrf;
    TeeVrf private teeVrfImpl;
    TeeVrfProxy private teeVrfProxy;

    address private mockTeeExtensionRegistry;
    address private mockTeeWalletKeyManager;
    address private mockTeeWalletManager;
    address private mockTeeWalletProjectManager;
    address private governance;
    address private addressUpdater;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    address private walletOwner;
    bytes32 private walletId;
    bytes32 private projectId;
    uint64 private keyId;
    address private teeId;
    bytes private nonce;
    bytes32 private instructionId;

    function setUp() public {
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");
        mockTeeExtensionRegistry = makeAddr("teeExtensionRegistry");
        mockTeeWalletKeyManager = makeAddr("teeWalletKeyManager");
        mockTeeWalletManager = makeAddr("teeWalletManager");
        mockTeeWalletProjectManager = makeAddr("teeWalletProjectManager");

        teeVrfImpl = new TeeVrf();
        teeVrfProxy = new TeeVrfProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            address(teeVrfImpl)
        );
        teeVrf = TeeVrf(address(teeVrfProxy));

        vm.prank(addressUpdater);
        contractNameHashes = new bytes32[](5);
        contractAddresses = new address[](5);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractAddresses[0] = addressUpdater;
        contractNameHashes[1] = keccak256(abi.encode("TeeExtensionRegistry"));
        contractAddresses[1] = mockTeeExtensionRegistry;
        contractNameHashes[2] = keccak256(abi.encode("TeeWalletKeyManager"));
        contractAddresses[2] = mockTeeWalletKeyManager;
        contractNameHashes[3] = keccak256(abi.encode("TeeWalletManager"));
        contractAddresses[3] = mockTeeWalletManager;
        contractNameHashes[4] = keccak256(abi.encode("TeeWalletProjectManager"));
        contractAddresses[4] = mockTeeWalletProjectManager;
        teeVrf.updateContractAddresses(contractNameHashes, contractAddresses);

        walletOwner = makeAddr("walletOwner");
        walletId = keccak256(abi.encode("walletId"));
        projectId = keccak256(abi.encode("projectId"));
        keyId = 0;
        teeId = makeAddr("teeId");
        nonce = bytes("test-nonce");
        instructionId = keccak256(abi.encode("instructionId"));
    }

    function testRequestVrfRevertNonceEmpty() public {
        vm.prank(walletOwner);
        vm.expectRevert(ITeeVrf.NonceEmpty.selector);
        teeVrf.requestVrf(walletId, keyId, bytes(""));
    }

    function testRequestVrfRevertOnlyWalletOwner() public {
        _mockGetWalletProjectId(walletId, projectId);
        _mockGetOwner(projectId, makeAddr("otherOwner"));
        vm.prank(walletOwner);
        vm.expectRevert(ITeeVrf.OnlyWalletOwner.selector);
        teeVrf.requestVrf(walletId, keyId, nonce);
    }

    function testRequestVrfRevertWalletNotInProduction() public {
        _mockGetWalletProjectId(walletId, projectId);
        _mockGetOwner(projectId, walletOwner);
        _mockGetWalletStatus(walletId, ITeeWalletManager.WalletStatus.INITIALIZED);
        vm.prank(walletOwner);
        vm.expectRevert(ITeeVrf.WalletNotInProduction.selector);
        teeVrf.requestVrf(walletId, keyId, nonce);
    }

    function testRequestVrfRevertNoTeesForKey() public {
        _mockGetWalletProjectId(walletId, projectId);
        _mockGetOwner(projectId, walletOwner);
        _mockGetWalletStatus(walletId, ITeeWalletManager.WalletStatus.PRODUCTION);
        _mockGetWalletKeyTeeIds(walletId, keyId, new address[](0));
        vm.prank(walletOwner);
        vm.expectRevert(ITeeVrf.NoTeesForKey.selector);
        teeVrf.requestVrf(walletId, keyId, nonce);
    }

    function testRequestVrf() public {
        address[] memory teeIds = new address[](1);
        teeIds[0] = teeId;
        _setupHappyPath(teeIds);
        _mockSendSystemInstructions(instructionId);

        vm.prank(walletOwner);
        vm.expectEmit();
        emit ITeeVrf.VrfRequested(walletId, keyId, instructionId);
        bytes32 returnedId = teeVrf.requestVrf(walletId, keyId, nonce);
        assertEq(returnedId, instructionId);
    }

    function testRequestVrfForwardsValue() public {
        address[] memory teeIds = new address[](1);
        teeIds[0] = teeId;
        _setupHappyPath(teeIds);
        _mockSendSystemInstructions(instructionId);

        vm.deal(walletOwner, 1 ether);
        vm.expectCall(
            mockTeeExtensionRegistry,
            1 ether,
            abi.encodePacked(SEND_SYSTEM_INSTRUCTIONS_SELECTOR)
        );
        vm.prank(walletOwner);
        teeVrf.requestVrf{value: 1 ether}(walletId, keyId, nonce);
    }

    function testRequestVrfMultipleTees() public {
        address[] memory teeIds = new address[](3);
        teeIds[0] = makeAddr("teeId0");
        teeIds[1] = makeAddr("teeId1");
        teeIds[2] = makeAddr("teeId2");
        _setupHappyPath(teeIds);
        _mockSendSystemInstructions(instructionId);

        vm.prank(walletOwner);
        vm.expectEmit();
        emit ITeeVrf.VrfRequested(walletId, keyId, instructionId);
        bytes32 returnedId = teeVrf.requestVrf(walletId, keyId, nonce);
        assertEq(returnedId, instructionId);
    }

    function testUpgradeProxy() public {
        TeeVrf newImpl = new TeeVrf();
        assertEq(teeVrf.implementation(), address(teeVrfImpl));
        vm.prank(governance);
        teeVrf.upgradeToAndCall(address(newImpl), bytes(""));
        assertEq(teeVrf.implementation(), address(newImpl));
        assertEq(teeVrf.governance(), governance);
    }

    function testUpgradeProxyRevertOnlyGovernance() public {
        TeeVrf newImpl = new TeeVrf();
        vm.expectRevert("only governance");
        teeVrf.upgradeToAndCall(address(newImpl), bytes(""));
    }

    function testUpgradeProxyAndInitializeRevert() public {
        TeeVrf newImpl = new TeeVrf();
        vm.prank(governance);
        vm.expectRevert("initialised != false");
        teeVrf.upgradeToAndCall(address(newImpl), abi.encodeCall(
            TeeVrf.initialize, (
                IGovernanceSettings(makeAddr("governanceSettings")),
                governance,
                addressUpdater
            )
        ));
    }

    //// Helpers

    function _setupHappyPath(address[] memory _teeIds) internal {
        _mockGetWalletProjectId(walletId, projectId);
        _mockGetOwner(projectId, walletOwner);
        _mockGetWalletStatus(walletId, ITeeWalletManager.WalletStatus.PRODUCTION);
        _mockGetWalletKeyTeeIds(walletId, keyId, _teeIds);
    }

    function _mockGetWalletProjectId(bytes32 _walletId, bytes32 _projectId) internal {
        vm.mockCall(
            mockTeeWalletManager,
            abi.encodeWithSelector(ITeeWalletManager.getWalletProjectId.selector, _walletId),
            abi.encode(_projectId)
        );
    }

    function _mockGetOwner(bytes32 _projectId, address _owner) internal {
        vm.mockCall(
            mockTeeWalletProjectManager,
            abi.encodeWithSelector(ITeeWalletProjectManager.getOwner.selector, _projectId),
            abi.encode(_owner)
        );
    }

    function _mockGetWalletStatus(bytes32 _walletId, ITeeWalletManager.WalletStatus _status) internal {
        vm.mockCall(
            mockTeeWalletManager,
            abi.encodeWithSelector(ITeeWalletManager.getWalletStatus.selector, _walletId),
            abi.encode(_status)
        );
    }

    function _mockGetWalletKeyTeeIds(bytes32 _walletId, uint64 _keyId, address[] memory _teeIds) internal {
        vm.mockCall(
            mockTeeWalletKeyManager,
            abi.encodeWithSelector(ITeeWalletKeyManager.getWalletKeyTeeIds.selector, _walletId, _keyId),
            abi.encode(_teeIds)
        );
    }

    function _mockSendSystemInstructions(bytes32 _instructionId) internal {
        // Match on selector only so any call to sendSystemInstructions(bytes32,address[],...) is intercepted.
        vm.mockCall(
            mockTeeExtensionRegistry,
            abi.encodePacked(SEND_SYSTEM_INSTRUCTIONS_SELECTOR),
            abi.encode(_instructionId)
        );
    }
}
