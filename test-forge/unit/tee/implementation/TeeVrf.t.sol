// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { TeeVrf } from "../../../../contracts/tee/implementation/TeeVrf.sol";
import { TeeVrfProxy } from "../../../../contracts/tee/proxy/TeeVrfProxy.sol";
import { ITeeVrf } from "../../../../contracts/userInterfaces/tee/ITeeVrf.sol";
import { ITeeMachineRegistry } from "../../../../contracts/userInterfaces/tee/ITeeMachineRegistry.sol";
import { ITeeWalletKeyManager } from "../../../../contracts/userInterfaces/tee/ITeeWalletKeyManager.sol";
import { ITeeWalletManager } from "../../../../contracts/userInterfaces/tee/ITeeWalletManager.sol";
import { ITeeWalletProjectManager } from "../../../../contracts/userInterfaces/tee/ITeeWalletProjectManager.sol";
import { ITeeExtensionRegistry } from "../../../../contracts/userInterfaces/tee/ITeeExtensionRegistry.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

contract TeeVrfTest is Test {

    TeeVrf private teeVrf;
    TeeVrf private teeVrfImpl;
    TeeVrfProxy private teeVrfProxy;

    address private mockTeeExtensionRegistry;
    address private mockTeeMachineRegistry;
    address private mockTeeWalletKeyManager;
    address private mockTeeWalletManager;
    address private mockTeeWalletProjectManager;
    address private governance;
    address private addressUpdater;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    address private walletOwner;
    address private authAddress;
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
        mockTeeMachineRegistry = makeAddr("teeMachineRegistry");
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
        contractNameHashes = new bytes32[](6);
        contractAddresses = new address[](6);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractAddresses[0] = addressUpdater;
        contractNameHashes[1] = keccak256(abi.encode("TeeExtensionRegistry"));
        contractAddresses[1] = mockTeeExtensionRegistry;
        contractNameHashes[2] = keccak256(abi.encode("TeeMachineRegistry"));
        contractAddresses[2] = mockTeeMachineRegistry;
        contractNameHashes[3] = keccak256(abi.encode("TeeWalletKeyManager"));
        contractAddresses[3] = mockTeeWalletKeyManager;
        contractNameHashes[4] = keccak256(abi.encode("TeeWalletManager"));
        contractAddresses[4] = mockTeeWalletManager;
        contractNameHashes[5] = keccak256(abi.encode("TeeWalletProjectManager"));
        contractAddresses[5] = mockTeeWalletProjectManager;
        teeVrf.updateContractAddresses(contractNameHashes, contractAddresses);

        walletOwner = makeAddr("walletOwner");
        authAddress = makeAddr("authAddress");
        walletId = keccak256(abi.encode("walletId"));
        projectId = keccak256(abi.encode("projectId"));
        keyId = 0;
        teeId = makeAddr("teeId");
        nonce = bytes("test-nonce");
        instructionId = keccak256(abi.encode("instructionId"));
    }

    // requestVrf tests

    function testRequestVrfRevertNonceEmpty() public {
        vm.prank(authAddress);
        vm.expectRevert(ITeeVrf.NonceEmpty.selector);
        teeVrf.requestVrf(walletId, keyId, bytes(""), address(0));
    }

    function testRequestVrfRevertOnlyAuthorizationAddress() public {
        _mockGetWalletProjectId(walletId, projectId);
        _mockGetOwner(projectId, walletOwner);
        // set auth address, then call from a different address
        vm.prank(walletOwner);
        teeVrf.setVrfAuthorizationAddress(walletId, authAddress);

        vm.prank(makeAddr("randomCaller"));
        vm.expectRevert(ITeeVrf.OnlyAuthorizationAddress.selector);
        teeVrf.requestVrf(walletId, keyId, nonce, address(0));
    }

    function testRequestVrfRevertOnlyAuthorizationAddressNoAuthSet() public {
        // no auth address set (default address(0))
        vm.prank(walletOwner);
        vm.expectRevert(ITeeVrf.OnlyAuthorizationAddress.selector);
        teeVrf.requestVrf(walletId, keyId, nonce, address(0));
    }

    function testRequestVrfRevertWalletNotInProduction() public {
        _setupAuthAddress();
        _mockGetWalletStatus(walletId, ITeeWalletManager.WalletStatus.INITIALIZED);
        vm.prank(authAddress);
        vm.expectRevert(ITeeVrf.WalletNotInProduction.selector);
        teeVrf.requestVrf(walletId, keyId, nonce, address(0));
    }

    function testRequestVrfRevertNoTeesForKey() public {
        _setupAuthAddress();
        _mockGetWalletStatus(walletId, ITeeWalletManager.WalletStatus.PRODUCTION);
        _mockGetWalletKeyTeeIds(walletId, keyId, new address[](0));
        vm.prank(authAddress);
        vm.expectRevert(ITeeVrf.NoTeesForKey.selector);
        teeVrf.requestVrf(walletId, keyId, nonce, address(0));
    }

    function testRequestVrfRevertNoTeesForKeyAllNonProduction() public {
        address[] memory teeIds = new address[](2);
        teeIds[0] = makeAddr("tee0");
        teeIds[1] = makeAddr("tee1");
        _setupAuthAddress();
        _mockGetWalletStatus(walletId, ITeeWalletManager.WalletStatus.PRODUCTION);
        _mockGetWalletKeyTeeIds(walletId, keyId, teeIds);
        // all TEEs are not in PRODUCTION
        _mockGetTeeMachineStatus(teeIds[0], ITeeMachineRegistry.TeeStatus.INITIALIZED);
        _mockGetTeeMachineStatus(teeIds[1], ITeeMachineRegistry.TeeStatus.SUSPENDED);
        vm.prank(authAddress);
        vm.expectRevert(ITeeVrf.NoTeesForKey.selector);
        teeVrf.requestVrf(walletId, keyId, nonce, address(0));
    }

    function testRequestVrf() public {
        address[] memory teeIds = new address[](1);
        teeIds[0] = teeId;
        _setupHappyPath(teeIds);
        _mockSendInstructions(instructionId);

        vm.prank(authAddress);
        vm.expectEmit();
        emit ITeeVrf.VrfRequested(walletId, keyId, instructionId);
        bytes32 returnedId = teeVrf.requestVrf(walletId, keyId, nonce, address(0));
        assertEq(returnedId, instructionId);
    }

    function testRequestVrfForwardsValue() public {
        address[] memory teeIds = new address[](1);
        teeIds[0] = teeId;
        _setupHappyPath(teeIds);
        _mockSendInstructions(instructionId);

        vm.deal(authAddress, 1 ether);
        vm.expectCall(
            mockTeeExtensionRegistry,
            1 ether,
            abi.encodePacked(ITeeExtensionRegistry.sendInstructions.selector)
        );
        vm.prank(authAddress);
        teeVrf.requestVrf{value: 1 ether}(walletId, keyId, nonce, address(0));
    }

    function testRequestVrfMultipleTees() public {
        address[] memory teeIds = new address[](3);
        teeIds[0] = makeAddr("teeId0");
        teeIds[1] = makeAddr("teeId1");
        teeIds[2] = makeAddr("teeId2");
        _setupHappyPath(teeIds);
        _mockSendInstructions(instructionId);

        vm.prank(authAddress);
        vm.expectEmit();
        emit ITeeVrf.VrfRequested(walletId, keyId, instructionId);
        bytes32 returnedId = teeVrf.requestVrf(walletId, keyId, nonce, address(0));
        assertEq(returnedId, instructionId);
    }

    function testRequestVrfFiltersNonProductionTees() public {
        address[] memory teeIds = new address[](3);
        teeIds[0] = makeAddr("teeProduction");
        teeIds[1] = makeAddr("teeSuspended");
        teeIds[2] = makeAddr("teeProduction2");
        _setupAuthAddress();
        _mockGetWalletStatus(walletId, ITeeWalletManager.WalletStatus.PRODUCTION);
        _mockGetWalletKeyTeeIds(walletId, keyId, teeIds);
        _mockGetTeeMachineStatus(teeIds[0], ITeeMachineRegistry.TeeStatus.PRODUCTION);
        _mockGetTeeMachineStatus(teeIds[1], ITeeMachineRegistry.TeeStatus.SUSPENDED);
        _mockGetTeeMachineStatus(teeIds[2], ITeeMachineRegistry.TeeStatus.PRODUCTION);
        _mockSendInstructions(instructionId);

        vm.prank(authAddress);
        vm.expectEmit();
        emit ITeeVrf.VrfRequested(walletId, keyId, instructionId);
        bytes32 returnedId = teeVrf.requestVrf(walletId, keyId, nonce, address(0));
        assertEq(returnedId, instructionId);
    }

    // setVrfAuthorizationAddress tests

    function testSetVrfAuthorizationAddress() public {
        _mockGetWalletProjectId(walletId, projectId);
        _mockGetOwner(projectId, walletOwner);

        vm.prank(walletOwner);
        vm.expectEmit();
        emit ITeeVrf.VrfAuthorizationAddressSet(walletId, authAddress);
        teeVrf.setVrfAuthorizationAddress(walletId, authAddress);

        assertEq(teeVrf.getVrfAuthorizationAddress(walletId), authAddress);
    }

    function testSetVrfAuthorizationAddressToZero() public {
        _mockGetWalletProjectId(walletId, projectId);
        _mockGetOwner(projectId, walletOwner);

        // first set to non-zero
        vm.prank(walletOwner);
        teeVrf.setVrfAuthorizationAddress(walletId, authAddress);
        assertEq(teeVrf.getVrfAuthorizationAddress(walletId), authAddress);

        // then set to zero to disable
        vm.prank(walletOwner);
        vm.expectEmit();
        emit ITeeVrf.VrfAuthorizationAddressSet(walletId, address(0));
        teeVrf.setVrfAuthorizationAddress(walletId, address(0));

        assertEq(teeVrf.getVrfAuthorizationAddress(walletId), address(0));
    }

    function testSetVrfAuthorizationAddressRevertOnlyWalletOwner() public {
        _mockGetWalletProjectId(walletId, projectId);
        _mockGetOwner(projectId, walletOwner);

        vm.prank(makeAddr("notOwner"));
        vm.expectRevert(ITeeVrf.OnlyWalletOwner.selector);
        teeVrf.setVrfAuthorizationAddress(walletId, authAddress);
    }

    // getVrfAuthorizationAddress tests

    function testGetVrfAuthorizationAddressDefault() public view {
        assertEq(teeVrf.getVrfAuthorizationAddress(walletId), address(0));
    }

    // Proxy tests

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

    function _setupAuthAddress() internal {
        _mockGetWalletProjectId(walletId, projectId);
        _mockGetOwner(projectId, walletOwner);
        vm.prank(walletOwner);
        teeVrf.setVrfAuthorizationAddress(walletId, authAddress);
    }

    function _setupHappyPath(address[] memory _teeIds) internal {
        _setupAuthAddress();
        _mockGetWalletStatus(walletId, ITeeWalletManager.WalletStatus.PRODUCTION);
        _mockGetWalletKeyTeeIds(walletId, keyId, _teeIds);
        for (uint256 i = 0; i < _teeIds.length; i++) {
            _mockGetTeeMachineStatus(_teeIds[i], ITeeMachineRegistry.TeeStatus.PRODUCTION);
        }
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

    function _mockGetTeeMachineStatus(address _teeId, ITeeMachineRegistry.TeeStatus _status) internal {
        vm.mockCall(
            mockTeeMachineRegistry,
            abi.encodeWithSelector(ITeeMachineRegistry.getTeeMachineStatus.selector, _teeId),
            abi.encode(_status)
        );
    }

    function _mockSendInstructions(bytes32 _instructionId) internal {
        vm.mockCall(
            mockTeeExtensionRegistry,
            abi.encodePacked(ITeeExtensionRegistry.sendInstructions.selector),
            abi.encode(_instructionId)
        );
    }
}
