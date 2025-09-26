// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { TeeWalletBackupManager } from "../../../../contracts/tee/implementation/TeeWalletBackupManager.sol";
import { TeeWalletBackupManagerProxy } from "../../../../contracts/tee/proxy/TeeWalletBackupManagerProxy.sol";
import { TeeExtensionRegistry } from "../../../../contracts/tee/implementation/TeeExtensionRegistry.sol";
import { TeeExtensionRegistryProxy } from "../../../../contracts/tee/proxy/TeeExtensionRegistryProxy.sol";
import { IITeeWalletKeyManager } from "../../../../contracts/tee/interface/IITeeWalletKeyManager.sol";
import { ITeeWalletBackupManager } from "../../../../contracts/userInterfaces/tee/ITeeWalletBackupManager.sol";
import { ITeeWalletKeyManager } from "../../../../contracts/userInterfaces/tee/ITeeWalletKeyManager.sol";
import { ITeeMachineRegistry } from "../../../../contracts/userInterfaces/tee/ITeeMachineRegistry.sol";
import { ITeeWalletProjectManager } from "../../../../contracts/userInterfaces/tee/ITeeWalletProjectManager.sol";
import { ITeeWalletManager } from "../../../../contracts/userInterfaces/tee/ITeeWalletManager.sol";
import { ITeeFeeCalculator } from "../../../../contracts/userInterfaces/tee/ITeeFeeCalculator.sol";
import { IIRewardManager } from "../../../../contracts/protocol/interface/IIRewardManager.sol";
import { ProtocolsV2Interface } from "../../../../contracts/userInterfaces/LTS/ProtocolsV2Interface.sol";
import { IGovernanceSettings } from "flare-smart-contracts/contracts/userInterfaces/IGovernanceSettings.sol";

//solhint-disable-next-line max-states-count
contract TeeWalletBackupManagerTest is Test {

    TeeWalletBackupManager private teeWalletBackupManager;
    TeeWalletBackupManager private teeWalletBackupManagerImpl;
    TeeWalletBackupManagerProxy private teeWalletBackupManagerProxy;

    TeeExtensionRegistry private teeExtensionRegistry;
    TeeExtensionRegistry private teeExtensionRegistryImpl;
    TeeExtensionRegistryProxy private teeExtensionRegistryProxy;

    address private owner;
    address private backupManager;

    address private initialGovernance;
    address private addressUpdater;
    address private teeWalletProjectManager;
    address private teeWalletManager;
    address private teeMachineRegistry;
    address private teeWalletKeyManager;
    address private flareSystemsManager;
    address private rewardManager;

    address private teeFeeCalculator;

    address private teeId;
    address private backupTeeId;
    bytes32 private projectId;
    ITeeWalletBackupManager.BackupId private backupId;
    string private backupUrl;
    uint64 private keyId;
    bytes private publicKey;
    address private keyHolderTeeId;
    uint32 private rewardEpochId;
    bytes32 private keyType;
    bytes32 private signingAlgo;
    uint256 private extensionId;
    uint256 private nonce;

    address[] private admins;
    uint64 private adminsThreshold;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    function setUp() public {
        initialGovernance = makeAddr("initialGovernance");
        addressUpdater = makeAddr("addressUpdater");
        teeMachineRegistry =

        owner = makeAddr("owner");
        backupManager = makeAddr("backupManager");
        teeId = makeAddr("teeId");
        backupTeeId = makeAddr("backupTeeId");
        projectId = keccak256("projectId");
        keyId = 1;
        publicKey = bytes("publicKey");
        rewardEpochId = 1;
        keyHolderTeeId = makeAddr("keyHolderTeeId");
        nonce = 1;
        backupUrl = "backupUrl";
        extensionId = 10;

        teeWalletBackupManagerImpl = new TeeWalletBackupManager();
        teeWalletBackupManagerProxy = new TeeWalletBackupManagerProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            initialGovernance,
            addressUpdater,
            address(teeWalletBackupManagerImpl)
        );
        teeWalletBackupManager = TeeWalletBackupManager(address(teeWalletBackupManagerProxy));

        teeExtensionRegistryImpl = new TeeExtensionRegistry();
        teeExtensionRegistryProxy = new TeeExtensionRegistryProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            initialGovernance,
            addressUpdater,
            address(teeExtensionRegistryImpl)
        );
        teeExtensionRegistry = TeeExtensionRegistry(address(teeExtensionRegistryProxy));

        contractNameHashes = new bytes32[](7);
        contractAddresses = new address[](7);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("TeeExtensionRegistry"));
        contractNameHashes[2] = keccak256(abi.encode("TeeMachineRegistry"));
        contractNameHashes[3] = keccak256(abi.encode("TeeWalletProjectManager"));
        contractNameHashes[4] = keccak256(abi.encode("TeeWalletManager"));
        contractNameHashes[5] = keccak256(abi.encode("TeeWalletKeyManager"));
        contractNameHashes[6] = keccak256(abi.encode("FlareSystemsManager"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = address(teeExtensionRegistry);
        contractAddresses[2] = makeAddr("TeeMachineRegistry");
        contractAddresses[3] = makeAddr("TeeWalletProjectManager");
        contractAddresses[4] = makeAddr("TeeWalletManager");
        contractAddresses[5] = makeAddr("TeeWalletKeyManager");
        contractAddresses[6] = makeAddr("FlareSystemsManager");

        vm.prank(addressUpdater);
        teeWalletBackupManager.updateContractAddresses(contractNameHashes, contractAddresses);

        contractNameHashes = new bytes32[](6);
        contractAddresses = new address[](6);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("TeeGovernance"));
        contractNameHashes[2] = keccak256(abi.encode("TeeMachineRegistry"));
        contractNameHashes[3] = keccak256(abi.encode("TeeFeeCalculator"));
        contractNameHashes[4] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[5] = keccak256(abi.encode("RewardManager"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = makeAddr("TeeGovernance");
        contractAddresses[2] = makeAddr("TeeMachineRegistry");
        contractAddresses[3] = makeAddr("TeeFeeCalculator");
        contractAddresses[4] = makeAddr("FlareSystemsManager");
        contractAddresses[5] = makeAddr("RewardManager");

        vm.prank(addressUpdater);
        teeExtensionRegistry.updateContractAddresses(contractNameHashes, contractAddresses);

        teeWalletProjectManager = address(teeWalletBackupManager.teeWalletProjectManager());
        teeWalletManager = address(teeWalletBackupManager.teeWalletManager());
        teeMachineRegistry = address(teeWalletBackupManager.teeMachineRegistry());
        teeWalletKeyManager = address(teeWalletBackupManager.teeWalletKeyManager());
        flareSystemsManager = address(teeWalletBackupManager.flareSystemsManager());

        teeFeeCalculator = address(teeExtensionRegistry.teeFeeCalculator());
        rewardManager = address(teeExtensionRegistry.rewardManager());

        keyType = keccak256("keyType");
        signingAlgo = keccak256("signingAlgo");
        backupId = ITeeWalletBackupManager.BackupId(
            backupTeeId,
            keccak256("walletId"),
            keyId,
            keyType,
            signingAlgo,
            publicKey,
            rewardEpochId,
            bytes32("randomNonce")
        );

        _mockGetTeeMachineStatus(teeId, ITeeMachineRegistry.TeeStatus.PRODUCTION);
        _mockGetTeeMachineStatus(backupTeeId, ITeeMachineRegistry.TeeStatus.PRODUCTION);
        _mockGetWalletKeyTeeIds(keyHolderTeeId);
        _mockGetWalletKeyPublicKey(publicKey);

        vm.mockCall(
            teeWalletProjectManager,
            abi.encodeWithSelector(
                ITeeWalletProjectManager.getOwner.selector,
                projectId
            ),
            abi.encode(owner)
        );

        vm.mockCall(
            teeWalletProjectManager,
            abi.encodeWithSelector(
                ITeeWalletProjectManager.getBackupManager.selector,
                projectId
            ),
            abi.encode(backupManager)
        );

        vm.mockCall(
            teeWalletManager,
            abi.encodeWithSelector(
                ITeeWalletManager.getWalletProjectId.selector
            ),
            abi.encode(projectId)
        );

        vm.mockCall(
            teeMachineRegistry,
            abi.encodeWithSelector(
                ITeeMachineRegistry.getInitialSigningPolicyId.selector
            ),
            abi.encode(uint32(1))
        );

        vm.mockCall(
            flareSystemsManager,
            abi.encodeWithSelector(
                ProtocolsV2Interface.getCurrentRewardEpochId.selector
            ),
            abi.encode(uint24(15))
        );

        vm.mockCall(
            teeWalletProjectManager,
            abi.encodeWithSelector(
                ITeeWalletProjectManager.getKeyType.selector
            ),
            abi.encode(keyType)
        );

        vm.mockCall(
            teeWalletProjectManager,
            abi.encodeWithSelector(
                ITeeWalletProjectManager.getSigningAlgo.selector
            ),
            abi.encode(signingAlgo)
        );

        vm.mockCall(
            teeWalletProjectManager,
            abi.encodeWithSelector(
                ITeeWalletProjectManager.getExtensionId.selector
            ),
            abi.encode(extensionId)
        );

        vm.mockCall(
            teeWalletKeyManager,
            abi.encodeWithSelector(
                IITeeWalletKeyManager.increaseKeyNonce.selector
            ),
            abi.encode(nonce + 1)
        );

        vm.mockCall(
            teeFeeCalculator,
            abi.encodeWithSelector(
                ITeeFeeCalculator.calculateFeeByTeeIds.selector
            ),
            abi.encode(0)
        );

        vm.mockCall(
            address(teeExtensionRegistry.teeMachineRegistry()),
            abi.encodeWithSelector(
                ITeeMachineRegistry.getExtensionId.selector
            ),
            abi.encode(extensionId)
        );

        vm.mockCall(
            teeMachineRegistry,
            abi.encodeWithSelector(
                ITeeMachineRegistry.getTeeMachine.selector
            ),
            abi.encode(ITeeMachineRegistry.TeeMachine(teeId, teeId, backupUrl))
        );

        vm.mockCall(
            rewardManager,
            abi.encodeWithSelector(
                IIRewardManager.receiveRewards.selector
            ),
            abi.encode("")
        );

        admins = new address[](2);
        admins[0] = makeAddr("admin1");
        admins[1] = makeAddr("admin2");
        adminsThreshold = 2;

        vm.mockCall(
            teeWalletManager,
            abi.encodeWithSelector(ITeeWalletManager.getWalletAdminsAndThreshold.selector, backupId.walletId),
            abi.encode(admins, adminsThreshold)
        );
    }


    // backupRestore
    function testBackupRestoreRevertOnlyOwnerOrBackupManager() public {
        vm.expectRevert(ITeeWalletBackupManager.OnlyOwnerOrBackupManager.selector);
        teeWalletBackupManager.backupRestore(teeId, backupId, backupUrl);
    }


    function testBackupRestoreRevertTeeMachineNotAvailable() public {
        _mockGetTeeMachineStatus(teeId, ITeeMachineRegistry.TeeStatus.INITIALIZED);
        vm.expectRevert(ITeeWalletBackupManager.TeeMachineNotAvailable.selector);
        vm.prank(owner);
        teeWalletBackupManager.backupRestore(teeId, backupId, backupUrl);
    }


    function testBackupRestoreRevertInvalidTeeMachine() public {
        _mockGetTeeMachineStatus(backupTeeId, ITeeMachineRegistry.TeeStatus.INITIALIZED);
        vm.expectRevert(ITeeWalletBackupManager.InvalidTeeMachine.selector);
        vm.prank(owner);
        teeWalletBackupManager.backupRestore(teeId, backupId, backupUrl);
    }


    function testBackupRestoreRevertKeyAlreadyAvailable() public {
        _mockGetWalletKeyTeeIds(teeId);
        vm.prank(owner);
        vm.expectRevert(ITeeWalletBackupManager.KeyAlreadyAvailable.selector);
        teeWalletBackupManager.backupRestore(teeId, backupId, backupUrl);
    }


    function testBackupRestoreRevertKeyNotConfirmed() public {
        _mockGetWalletKeyPublicKey(bytes(""));
        vm.prank(owner);
        vm.expectRevert(ITeeWalletBackupManager.KeyNotConfirmed.selector);
        teeWalletBackupManager.backupRestore(teeId, backupId, backupUrl);
    }


    function testBackupRestoreRevertInvalidPublicKey() public {
        _mockGetWalletKeyPublicKey(bytes("invalidKey"));
        vm.prank(owner);
        vm.expectRevert(ITeeWalletBackupManager.InvalidPublicKey.selector);
        teeWalletBackupManager.backupRestore(teeId, backupId, backupUrl);
    }


    function testBackupRestoreRevertUnsupportedRewardEpochId() public {
        backupId.rewardEpochId = 0;
        vm.prank(owner);
        vm.expectRevert(ITeeWalletBackupManager.UnsupportedRewardEpochId.selector);
        teeWalletBackupManager.backupRestore(teeId, backupId, backupUrl);
    }


    function testBackupRestoreRevertInvalidRewardEpochId() public {
        backupId.rewardEpochId = 20;
        vm.prank(owner);
        vm.expectRevert(ITeeWalletBackupManager.InvalidRewardEpochId.selector);
        teeWalletBackupManager.backupRestore(teeId, backupId, backupUrl);
    }


    function testBackupRestoreRevertInvalidKeyType() public {
        backupId.keyType = keccak256("InvalidKeyType");
        vm.prank(owner);
        vm.expectRevert(ITeeWalletBackupManager.InvalidKeyType.selector);
        teeWalletBackupManager.backupRestore(teeId, backupId, backupUrl);
    }


    function testBackupRestoreRevertInvalidSigningAlgo() public {
        backupId.signingAlgo = keccak256("InvalidSigningAlgo");
        vm.prank(owner);
        vm.expectRevert(ITeeWalletBackupManager.InvalidSigningAlgo.selector);
        teeWalletBackupManager.backupRestore(teeId, backupId, backupUrl);
    }


    function testBackupRestoreRevertExtensionIdMismatch1() public {
        _mockGetExtensionId(backupTeeId, extensionId + 1);
        vm.prank(owner);
        vm.expectRevert(ITeeWalletBackupManager.ExtensionIdMismatch.selector);
        teeWalletBackupManager.backupRestore(teeId, backupId, backupUrl);

        _mockGetExtensionId(backupTeeId, extensionId);
        _mockGetExtensionId(teeId, extensionId + 1);
        vm.prank(owner);
        vm.expectRevert(ITeeWalletBackupManager.ExtensionIdMismatch.selector);
        teeWalletBackupManager.backupRestore(teeId, backupId, backupUrl);
    }


    function _mockGetTeeMachineStatus(
        address _teeId,
        ITeeMachineRegistry.TeeStatus _status
    )
        private
    {
        vm.mockCall(
            teeMachineRegistry,
            abi.encodeWithSelector(
                ITeeMachineRegistry.getTeeMachineStatus.selector,
                _teeId
            ),
            abi.encode(_status)
        );
    }


    function _mockGetWalletKeyTeeIds(address _teeId) private {
        address[] memory teeIds = new address[](1);
        teeIds[0] = _teeId;
        vm.mockCall(
            teeWalletKeyManager,
            abi.encodeWithSelector(
                ITeeWalletKeyManager.getWalletKeyTeeIds.selector
            ),
            abi.encode(teeIds)
        );
    }


    function _mockGetWalletKeyPublicKey(bytes memory _publicKey) private {
        vm.mockCall(
            teeWalletKeyManager,
            abi.encodeWithSelector(
                ITeeWalletKeyManager.getWalletKeyPublicKey.selector
            ),
            abi.encode(_publicKey)
        );
    }


    function _mockGetExtensionId(address _teeId, uint256 _extensionId) private {
        vm.mockCall(
            teeMachineRegistry,
            abi.encodeWithSelector(
                ITeeMachineRegistry.getExtensionId.selector,
                _teeId
            ),
            abi.encode(_extensionId)
        );
    }
}