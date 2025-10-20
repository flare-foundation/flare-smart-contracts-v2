// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { TeeWalletKeyManager } from "../../../../contracts/tee/implementation/TeeWalletKeyManager.sol";
import { TeeWalletKeyManagerProxy } from "../../../../contracts/tee/proxy/TeeWalletKeyManagerProxy.sol";
import { TeeExtensionRegistry } from "../../../../contracts/tee/implementation/TeeExtensionRegistry.sol";
import { TeeExtensionRegistryProxy } from "../../../../contracts/tee/proxy/TeeExtensionRegistryProxy.sol";
import { ITeeMachineRegistry } from "../../../../contracts/userInterfaces/tee/ITeeMachineRegistry.sol";
import { ITeeExtensionRegistry } from "../../../../contracts/userInterfaces/tee/ITeeExtensionRegistry.sol";
import { ITeeWalletProjectManager } from "../../../../contracts/userInterfaces/tee/ITeeWalletProjectManager.sol";
import { ITeeWalletManager } from "../../../../contracts/userInterfaces/tee/ITeeWalletManager.sol";
import { ITeeWalletKeyManager } from "../../../../contracts/userInterfaces/tee/ITeeWalletKeyManager.sol";
import { ITeeFeeCalculator } from "../../../../contracts/userInterfaces/tee/ITeeFeeCalculator.sol";
import { TeeIdKeyIdPair } from "../../../../contracts/userInterfaces/tee/ITeeWalletKeyManager.sol";
import { Signature } from "../../../../contracts/userInterfaces/ISignature.sol";
import { PublicKey } from "../../../../contracts/userInterfaces/IPublicKey.sol";
import { IIRewardManager } from "../../../../contracts/protocol/interface/IIRewardManager.sol";
import { ProtocolsV2Interface } from "../../../../contracts/userInterfaces/LTS/ProtocolsV2Interface.sol";
import { IGovernanceSettings } from "flare-smart-contracts/contracts/userInterfaces/IGovernanceSettings.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";


// solhint-disable-next-line max-states-count
contract TeeWalletKeyManagerTest is Test {

    bytes32 public constant WALLET_OP_TYPE = bytes32("F_WALLET");
    bytes32 public constant KEY_GENERATE = bytes32("KEY_GENERATE");

    TeeWalletKeyManager private teeWalletKeyManager;
    TeeWalletKeyManager private teeWalletKeyManagerImpl;
    TeeWalletKeyManagerProxy private teeWalletKeyManagerProxy;

    TeeExtensionRegistry private teeExtensionRegistryImpl;
    TeeExtensionRegistry private teeExtensionRegistry;
    TeeExtensionRegistryProxy private teeExtensionRegistryProxy;

    address private owner;
    bytes32 private walletId;
    bytes32 private projectId;
    address private teeId;
    uint256 private privateKey;
    address private backupManager;
    address private newTeeId;
    uint256 private newPrivateKey;
    uint64 private keyId;

    uint256 private extensionId;
    bytes32 private keyType;
    bytes32 private signingAlgo;
    ITeeWalletKeyManager.KeyExistence private proof;
    Signature private teeSignature;
    uint256 private fee;
    PublicKey[] private publicKeys;
    address[] private cosigners;

    address private initialGovernance;
    address private addressUpdater;
    address private teeWalletManager;
    address private teeWalletProjectManager;
    address private teeMachineRegistry;
    address private teeWalletBackupManager;
    address private teeFeeCalculatorMock;
    address private flareSystemsManagerMock;
    address private rewardManagerMock;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;


    function setUp() public {
        owner = makeAddr("owner");
        backupManager = makeAddr("backupManager");
        walletId = keccak256("walletId");
        projectId = keccak256("projectId");
        (teeId, privateKey) = makeAddrAndKey("teeId");
        (newTeeId, newPrivateKey) = makeAddrAndKey("newTeeId");
        extensionId = 1;
        keyType = keccak256("keyType");
        signingAlgo = keccak256("signingAlgo");
        keyId = 0;

        PublicKey memory pk = PublicKey(keccak256("1"), keccak256("1"));
        publicKeys.push(pk);
        cosigners = new address[](1);
        cosigners[0] = makeAddr("cosigner1");

        proof.teeId = teeId;
        proof.walletId = walletId;
        proof.nonce = 0;
        proof.keyType = keyType;
        proof.signingAlgo = signingAlgo;
        proof.configConstants.adminsPublicKeys.push(publicKeys[0]);
        proof.configConstants.adminsThreshold = 1;
        proof.configConstants.cosigners.push(cosigners[0]);
        proof.configConstants.cosignersThreshold = 1;
        proof.publicKey = abi.encode("publicKey");
        proof.restored = true;
        proof.keyId = keyId;
        proof.settingsVersion = bytes32(0);
        proof.settings = bytes("");

        teeSignature = _createSignature(privateKey);

        initialGovernance = makeAddr("initialGovernance");
        addressUpdater = makeAddr("addressUpdater");

        teeWalletKeyManagerImpl = new TeeWalletKeyManager();
        teeWalletKeyManagerProxy = new TeeWalletKeyManagerProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            initialGovernance,
            addressUpdater,
            address(teeWalletKeyManagerImpl)
        );
        teeWalletKeyManager = TeeWalletKeyManager(address(teeWalletKeyManagerProxy));

        teeExtensionRegistryImpl = new TeeExtensionRegistry();
        teeExtensionRegistryProxy = new TeeExtensionRegistryProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            initialGovernance,
            addressUpdater,
            address(teeExtensionRegistryImpl)
        );
        teeExtensionRegistry = TeeExtensionRegistry(address(teeExtensionRegistryProxy));

        teeFeeCalculatorMock = makeAddr("TeeFeeCalculator");
        flareSystemsManagerMock = makeAddr("FlareSystemsManager");
        rewardManagerMock = makeAddr("RewardManager");

        vm.startPrank(addressUpdater);
        contractNameHashes = new bytes32[](7);
        contractAddresses = new address[](7);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("TeeExtensionRegistry"));
        contractNameHashes[2] = keccak256(abi.encode("TeeMachineRegistry"));
        contractNameHashes[3] = keccak256(abi.encode("TeeWalletProjectManager"));
        contractNameHashes[4] = keccak256(abi.encode("TeeWalletManager"));
        contractNameHashes[5] = keccak256(abi.encode("TeeWalletBackupManager"));
        contractNameHashes[6] = keccak256(abi.encode("FlareSystemsManager"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = address(teeExtensionRegistry);
        contractAddresses[2] = makeAddr("TeeMachineRegistry");
        contractAddresses[3] = makeAddr("TeeWalletProjectManager");
        contractAddresses[4] = makeAddr("TeeWalletManager");
        contractAddresses[5] = makeAddr("TeeWalletBackupManager");
        contractAddresses[6] = flareSystemsManagerMock;
        teeWalletKeyManager.updateContractAddresses(contractNameHashes, contractAddresses);

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
        contractAddresses[3] = teeFeeCalculatorMock;
        contractAddresses[4] = makeAddr("FlareSystemsManager");
        contractAddresses[5] = rewardManagerMock;
        teeExtensionRegistry.updateContractAddresses(contractNameHashes, contractAddresses);
        vm.stopPrank();

        teeWalletManager = address(teeWalletKeyManager.teeWalletManager());
        teeWalletProjectManager = address(teeWalletKeyManager.teeWalletProjectManager());
        teeMachineRegistry = address(teeWalletKeyManager.teeMachineRegistry());
        teeWalletBackupManager = address(teeWalletKeyManager.teeWalletBackupManager());

        _mockGetOwner(owner);
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.INITIALIZED);
        _mockGetTeeMachineStatus(ITeeMachineRegistry.TeeStatus.PRODUCTION);
        _mockGetExtensionId(extensionId);

        vm.mockCall(
            teeWalletManager,
            abi.encodeWithSelector(
                ITeeWalletManager.getWalletProjectId.selector
            ),
            abi.encode(projectId)
        );

        vm.mockCall(
            teeWalletProjectManager,
            abi.encodeWithSelector(
                ITeeWalletProjectManager.getExtensionId.selector
            ),
            abi.encode(extensionId)
        );

        vm.mockCall(
            teeWalletManager,
            abi.encodeWithSelector(
                ITeeWalletManager.getWalletAdminsPublicKeysAndThreshold.selector
            ),
            abi.encode(
                publicKeys, uint64(1)
            )
        );

        vm.mockCall(
            teeWalletManager,
            abi.encodeWithSelector(
                ITeeWalletManager.getWalletCosignersAndThreshold.selector
            ),
            abi.encode(cosigners, uint64(1))
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
                ITeeWalletProjectManager.getBackupManager.selector
            ),
            abi.encode(backupManager)
        );

        address[] memory instructionsSenders = new address[](1);
        instructionsSenders[0] = address(teeWalletKeyManager);
        vm.prank(initialGovernance);
        teeExtensionRegistry.registerSystemInstructionsSenders(instructionsSenders);

        fee = 123;
        vm.mockCall(
            teeFeeCalculatorMock,
            abi.encodeWithSelector(
                ITeeFeeCalculator.calculateFeeByTeeIds.selector
            ),
            abi.encode(fee)
        );
        vm.deal(owner, 1 ether);

        vm.mockCall(
            rewardManagerMock,
            abi.encodeWithSelector(IIRewardManager.receiveRewards.selector),
            abi.encode()
        );
    }


    // setMultisigThreshold
    function testSetMultisigThresholdRevertOnlyOwner() public {
        vm.expectRevert(ITeeWalletKeyManager.OnlyOwner.selector);
        teeWalletKeyManager.setMultisigThreshold(walletId, 2);
    }


    function testSetMultisigThresholdRevertInvalidThreshold() public {
        vm.prank(owner);
        vm.expectRevert(ITeeWalletKeyManager.InvalidThreshold.selector);
        teeWalletKeyManager.setMultisigThreshold(walletId, 0);
    }


    function testSetMultisigThresholdRevertInvalidWalletStatus() public {
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        vm.prank(owner);
        vm.expectRevert(ITeeWalletKeyManager.InvalidWalletStatus.selector);
        teeWalletKeyManager.setMultisigThreshold(walletId, 1);
    }


    function testSetMultisigThreshold() public {
        vm.prank(owner);
        vm.expectEmit();
        emit ITeeWalletKeyManager.WalletMultisigThresholdSet(walletId, 1);
        teeWalletKeyManager.setMultisigThreshold(walletId, 1);
    }


    // addKey
    function testAddKeyRevertOnlyOwner() public {
        vm.expectRevert(ITeeWalletKeyManager.OnlyOwner.selector);
        teeWalletKeyManager.addKey(teeId, walletId);
    }


    function testAddKeyRevertTeeMachineNotAvailable() public {
        _mockGetTeeMachineStatus(ITeeMachineRegistry.TeeStatus.PAUSED);
        vm.prank(owner);
        vm.expectRevert(ITeeWalletKeyManager.TeeMachineNotAvailable.selector);
        teeWalletKeyManager.addKey(teeId, walletId);
    }


    function testAddKeyRevertInvalidWalletStatus() public {
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        vm.prank(owner);
        vm.expectRevert(ITeeWalletKeyManager.InvalidWalletStatus.selector);
        teeWalletKeyManager.addKey(teeId, walletId);
    }


    function testAddKeyRevertExtensionIdMismatch() public {
        _mockGetExtensionId(extensionId + 1);
        vm.prank(owner);
        vm.expectRevert(ITeeWalletKeyManager.ExtensionIdMismatch.selector);
        teeWalletKeyManager.addKey(teeId, walletId);
    }


    function testAddKey() public {
        ITeeMachineRegistry.TeeMachine[] memory teeMachines = new ITeeMachineRegistry.TeeMachine[](1);
        teeMachines[0] = ITeeMachineRegistry.TeeMachine(teeId, makeAddr("teeProxy"), "url");
        vm.mockCall(
            teeMachineRegistry,
            abi.encodeWithSelector(
                ITeeMachineRegistry.getTeeMachine.selector, teeId
            ),
            abi.encode(teeMachines[0])
        );
        uint24 currentRewardEpochId = 8;
        vm.mockCall(
            flareSystemsManagerMock,
            abi.encodeWithSelector(
                ProtocolsV2Interface.getCurrentRewardEpochId.selector
            ),
            abi.encode(currentRewardEpochId)
        );

        ITeeWalletKeyManager.KeyGenerate memory message = ITeeWalletKeyManager.KeyGenerate({
            teeId: teeId,
            walletId: walletId,
            keyId: keyId,
            keyType: keyType,
            signingAlgo: signingAlgo,
            configConstants: ITeeWalletKeyManager.KeyConfigConstants({
                adminsPublicKeys: publicKeys,
                adminsThreshold: 1,
                cosigners: cosigners,
                cosignersThreshold: 1
            })
        });
        bytes32 instructionId = keccak256(abi.encode(
            WALLET_OP_TYPE, KEY_GENERATE, walletId, keyId
        ));

        vm.prank(owner);
        vm.expectEmit();
        emit ITeeWalletKeyManager.WalletKeyAdded(teeId, walletId, 0);
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            extensionId,
            instructionId,
            currentRewardEpochId,
            teeMachines,
            WALLET_OP_TYPE,
            KEY_GENERATE,
            abi.encode(message),
            new address[](0),
            0,
            2 * fee
        );
        teeWalletKeyManager.addKey{value: 2 * fee}(teeId, walletId);
    }


    // confirmKey
    function testConfirmKeyRevertOnlyOwnerOrBackupManager() public {
        vm.expectRevert(ITeeWalletKeyManager.OnlyOwnerOrBackupManager.selector);
        teeWalletKeyManager.confirmKey(proof, teeSignature);
    }


    function testConfirmKeyRevertTeeMachineNotAvailable() public {
        _mockGetTeeMachineStatus(ITeeMachineRegistry.TeeStatus.REPLICATING);
        vm.prank(owner);
        vm.expectRevert(ITeeWalletKeyManager.TeeMachineNotAvailable.selector);
        teeWalletKeyManager.confirmKey(proof, teeSignature);
    }


    function testConfirmKeyRevertInvalidKeyId() public {
        vm.prank(owner);
        vm.expectRevert(ITeeWalletKeyManager.InvalidKeyId.selector);
        teeWalletKeyManager.confirmKey(proof, teeSignature);
    }


    function testConfirmKeyRevertInvalidNonce() public {
        proof.nonce = 1;
        testAddKey();
        vm.prank(owner);
        vm.expectRevert(ITeeWalletKeyManager.InvalidNonce.selector);
        teeWalletKeyManager.confirmKey(proof, teeSignature);
    }


    function testConfirmKeyRevertInvalidKeyType() public {
        proof.keyType = keccak256("invalidKeyType");
        testAddKey();
        vm.prank(owner);
        vm.expectRevert(ITeeWalletKeyManager.InvalidKeyType.selector);
        teeWalletKeyManager.confirmKey(proof, teeSignature);
    }


    function testConfirmKeyRevertInvalidSigningAlgo() public {
        proof.signingAlgo = keccak256("invalidSigningAlgo");
        testAddKey();
        vm.prank(owner);
        vm.expectRevert(ITeeWalletKeyManager.InvalidSigningAlgo.selector);
        teeWalletKeyManager.confirmKey(proof, teeSignature);
    }


    function testConfirmKeyRevertInvalidSettings() public {
        proof.settings = bytes("invalidSettings");
        testAddKey();
        vm.prank(owner);
        vm.expectRevert(ITeeWalletKeyManager.InvalidSettings.selector);
        teeWalletKeyManager.confirmKey(proof, teeSignature);
    }


    function testConfirmKeyRevertInvalidSettings2() public {
        proof.settingsVersion = bytes32("invalidVersion");
        testAddKey();
        vm.prank(owner);
        vm.expectRevert(ITeeWalletKeyManager.InvalidSettings.selector);
        teeWalletKeyManager.confirmKey(proof, teeSignature);
    }


    function testConfirmKeyRevertLengthsMismatchAdminsPublicKeys() public {
        proof.configConstants.adminsPublicKeys.push();
        testAddKey();
        vm.prank(owner);
        vm.expectRevert(ITeeWalletKeyManager.LengthsMismatch.selector);
        teeWalletKeyManager.confirmKey(proof, teeSignature);
    }


    function testConfirmKeyRevertInvalidThresholdAdmins() public {
        proof.configConstants.adminsThreshold = 2;
        testAddKey();
        vm.prank(owner);
        vm.expectRevert(ITeeWalletKeyManager.InvalidThreshold.selector);
        teeWalletKeyManager.confirmKey(proof, teeSignature);
    }


    function testConfirmKeyRevertInvalidPublicKeyAdmins() public {
        proof.configConstants.adminsPublicKeys[0].x = keccak256("invalidX");
        testAddKey();
        vm.prank(owner);
        vm.expectRevert(ITeeWalletKeyManager.InvalidPublicKey.selector);
        teeWalletKeyManager.confirmKey(proof, teeSignature);
    }


    function testConfirmKeyRevertLengthsMismatchCosigners() public {
        proof.configConstants.cosigners.pop();
        testAddKey();
        vm.prank(owner);
        vm.expectRevert(ITeeWalletKeyManager.LengthsMismatch.selector);
        teeWalletKeyManager.confirmKey(proof, teeSignature);
    }


    function testConfirmKeyRevertInvalidThresholdCosigners() public {
        proof.configConstants.cosignersThreshold = 2;
        testAddKey();
        vm.prank(owner);
        vm.expectRevert(ITeeWalletKeyManager.InvalidThreshold.selector);
        teeWalletKeyManager.confirmKey(proof, teeSignature);
    }


    function testConfirmKeyRevertInvalidAddressCosigners() public {
        proof.configConstants.cosigners[0] = makeAddr("invalidCosigner");
        testAddKey();
        vm.prank(owner);
        vm.expectRevert(ITeeWalletKeyManager.InvalidAddress.selector);
        teeWalletKeyManager.confirmKey(proof, teeSignature);
    }


    function testConfirmKeyRevertInvalidTeeSignature() public {
        proof.teeId = makeAddr("invalidTeeId");
        teeSignature = _createSignature(privateKey);
        testAddKey();
        vm.prank(owner);
        vm.expectRevert(ITeeWalletKeyManager.InvalidTeeSignature.selector);
        teeWalletKeyManager.confirmKey(proof, teeSignature);
    }


    function testConfirmKeyRevertInvalidPublicKeyNotInWallet() public {
        proof.publicKey = new bytes(0);
        teeSignature = _createSignature(privateKey);
        testAddKey();
        vm.prank(owner);
        vm.expectRevert(ITeeWalletKeyManager.InvalidPublicKey.selector);
        teeWalletKeyManager.confirmKey(proof, teeSignature);
    }


    function testConfirmKeyRevertInvalidWalletStatus() public {
        testAddKey();
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        vm.prank(owner);
        vm.expectRevert(ITeeWalletKeyManager.InvalidWalletStatus.selector);
        teeWalletKeyManager.confirmKey(proof, teeSignature);
    }


    function testConfirmKeyRevertOnlyOwner() public {
        testAddKey();
        vm.prank(backupManager);
        vm.expectRevert(ITeeWalletKeyManager.OnlyOwner.selector);
        teeWalletKeyManager.confirmKey(proof, teeSignature);
    }

    // nonce == 0
    function testConfirmKeyRevertKeyNotGeneratedOnTeeMachine() public {
        testAddKey();
        vm.prank(owner);
        vm.expectRevert(ITeeWalletKeyManager.KeyNotGeneratedOnTeeMachine.selector);
        teeWalletKeyManager.confirmKey(proof, teeSignature);
    }

    function testConfirmKeyNotInWallet() public {
        proof.restored = false;
        teeSignature = _createSignature(privateKey);
        testAddKey();
        vm.prank(owner);
        vm.expectEmit();
        emit ITeeWalletKeyManager.WalletKeyConfirmed(
            teeId,
            walletId,
            proof.keyId,
            proof.publicKey
        );
        teeWalletKeyManager.confirmKey(proof, teeSignature);
    }

    // nonce == 0
    function testConfirmKeyRevertKeyNotRestoredOnTeeMachine1() public {
        testConfirmKeyNotInWallet();
        teeSignature = _createSignature(privateKey);
        vm.prank(owner);
        vm.expectRevert(ITeeWalletKeyManager.KeyNotRestoredOnTeeMachine.selector);
        teeWalletKeyManager.confirmKey(proof, teeSignature);
    }

    // nonce > 0, restored == false
    function testConfirmKeyRevertKeyNotRestoredOnTeeMachine2() public {
        testConfirmKeyNotInWallet();
        proof.nonce = 1;
        proof.restored = false;
        teeSignature = _createSignature(privateKey);
        vm.prank(teeWalletBackupManager);
        teeWalletKeyManager.increaseKeyNonce(teeId, walletId, keyId);
        vm.prank(owner);
        vm.expectRevert(ITeeWalletKeyManager.KeyNotRestoredOnTeeMachine.selector);
        teeWalletKeyManager.confirmKey(proof, teeSignature);
    }

    function testConfirmKeyRevertInvalidPublicKeyInWallet() public {
        _setupConfirmKeyInWallet();
        proof.publicKey = abi.encode("invalidPublicKey");
        teeSignature = _createSignature(privateKey);
        vm.prank(owner);
        vm.expectRevert(ITeeWalletKeyManager.InvalidPublicKey.selector);
        teeWalletKeyManager.confirmKey(proof, teeSignature);
    }


    function testConfirmKeyRevertTeeIdAlreadyAdded() public {
        _setupConfirmKeyInWallet();
        teeSignature = _createSignature(privateKey);
        vm.prank(owner);
        vm.expectRevert(ITeeWalletKeyManager.TeeIdAlreadyAdded.selector);
        teeWalletKeyManager.confirmKey(proof, teeSignature);
    }


    function testConfirmKeyInWallet() public {
        _setupConfirmKeyInWallet();
        vm.prank(teeWalletBackupManager);
        teeWalletKeyManager.increaseKeyNonce(newTeeId, walletId, keyId);

        proof.teeId = newTeeId;
        teeSignature = _createSignature(newPrivateKey);
        vm.prank(owner);
        vm.expectEmit();
        emit ITeeWalletKeyManager.WalletKeyConfirmed(
            newTeeId,
            walletId,
            keyId,
            proof.publicKey
        );
        teeWalletKeyManager.confirmKey(proof, teeSignature);
    }


    // deleteKey
    function testDeleteKeyRevertOnlyOwner() public {
        vm.expectRevert(ITeeWalletKeyManager.OnlyOwner.selector);
        teeWalletKeyManager.deleteKey(teeId, walletId, keyId);
    }


    function testDeleteKeyRevertTeeMachineNotAvailable() public {
        _mockGetTeeMachineStatus(ITeeMachineRegistry.TeeStatus.INITIALIZED);
        vm.prank(owner);
        vm.expectRevert(ITeeWalletKeyManager.TeeMachineNotAvailable.selector);
        teeWalletKeyManager.deleteKey(teeId, walletId, keyId);
    }


    function testDeleteKeyRevertExtensionIdMismatch() public {
        _mockGetExtensionId(extensionId + 1);
        vm.prank(owner);
        vm.expectRevert(ITeeWalletKeyManager.ExtensionIdMismatch.selector);
        teeWalletKeyManager.deleteKey(teeId, walletId, keyId);
    }


    function testDeleteKeyRevertInvalidKeyId() public {
        testConfirmKeyNotInWallet();
        // non-existent keyId or walletId
        vm.startPrank(owner);
        vm.expectRevert(ITeeWalletKeyManager.InvalidKeyId.selector);
        teeWalletKeyManager.deleteKey(teeId, walletId, keyId + 1);

        vm.expectRevert(ITeeWalletKeyManager.InvalidKeyId.selector);
        teeWalletKeyManager.deleteKey(teeId, keccak256("invalidWalletId"), keyId);
        vm.stopPrank();
    }


    function testDeleteKey() public {
        _setupConfirmKeyInWallet();
        ITeeMachineRegistry.TeeMachine[] memory teeMachines = new ITeeMachineRegistry.TeeMachine[](1);
        teeMachines[0] = ITeeMachineRegistry.TeeMachine(newTeeId, makeAddr("teeProxy"), "url");
        vm.mockCall(
            teeMachineRegistry,
            abi.encodeWithSelector(
                ITeeMachineRegistry.getTeeMachine.selector, newTeeId
            ),
            abi.encode(teeMachines[0])
        );
        uint24 currentRewardEpochId = 8;
        vm.mockCall(
            flareSystemsManagerMock,
            abi.encodeWithSelector(
                ProtocolsV2Interface.getCurrentRewardEpochId.selector
            ),
            abi.encode(currentRewardEpochId)
        );
        vm.prank(owner);
        teeWalletKeyManager.addKey{value: fee}(newTeeId, walletId);
        vm.prank(teeWalletBackupManager);
        teeWalletKeyManager.increaseKeyNonce(newTeeId, walletId, keyId);
        proof.teeId = newTeeId;
        proof.restored = true;
        teeSignature = _createSignature(newPrivateKey);
        vm.prank(owner);
        teeWalletKeyManager.confirmKey(proof, teeSignature);

        address[] memory teeIds = teeWalletKeyManager.getWalletKeyTeeIds(walletId, keyId);
        assertEq(teeIds.length, 2);

        vm.prank(owner);
        vm.expectEmit();
        emit ITeeWalletKeyManager.WalletKeyDeleted(teeId, walletId, keyId);
        teeWalletKeyManager.deleteKey{value: fee}(teeId, walletId, keyId);
    }


    // cleanUpTeeIds
    function testCleanUpTeeIdsRevertOnlyOwnerOrBackupManager() public {
        vm.expectRevert(ITeeWalletKeyManager.OnlyOwnerOrBackupManager.selector);
        teeWalletKeyManager.cleanUpTeeIds(walletId, keyId);
    }


    function testCleanUpTeeIdsRevertInvalidKeyId() public {
        testConfirmKeyNotInWallet();
        // non-existent keyId or walletId
        vm.startPrank(owner);
        vm.expectRevert(ITeeWalletKeyManager.InvalidKeyId.selector);
        teeWalletKeyManager.cleanUpTeeIds(walletId, keyId + 1);

        vm.expectRevert(ITeeWalletKeyManager.InvalidKeyId.selector);
        teeWalletKeyManager.cleanUpTeeIds(keccak256("invalidWalletId"), keyId);
        vm.stopPrank();
    }


    function testCleanUpTeeIds() public {
        testConfirmKeyNotInWallet();
        _mockGetTeeMachineStatus(ITeeMachineRegistry.TeeStatus.REPLICATING);
        vm.prank(owner);
        vm.expectEmit();
        emit ITeeWalletKeyManager.WalletKeyDeleted(teeId, walletId, keyId);
        teeWalletKeyManager.cleanUpTeeIds(walletId, keyId);
    }


    // receivingTeesAndKeys
    function testReceivingTeesAndKeysRevertThresholdNotMet() public {
        testConfirmKeyNotInWallet();
        vm.prank(owner);
        teeWalletKeyManager.setMultisigThreshold(walletId, 2);
        vm.expectRevert(ITeeWalletKeyManager.ThresholdNotMet.selector);
        teeWalletKeyManager.receivingTeesAndKeys(walletId);
    }


    function testReceivingTeesAndKeys() public {
        uint64[] memory keyIds = new uint64[](1);
        keyIds[0] = keyId;
        testConfirmKeyNotInWallet();
        TeeIdKeyIdPair[] memory pairs = teeWalletKeyManager.receivingTeesAndKeys(walletId);
        assertEq(pairs.length, 1);
        assertEq(pairs[0].teeId, teeId);
        assertEq(pairs[0].keyId, keyId);
        _mockGetTeeMachineStatus(ITeeMachineRegistry.TeeStatus.PAUSED);
        vm.expectEmit();
        emit ITeeWalletKeyManager.WalletKeysNotAvailable(walletId, keyIds);
        pairs = teeWalletKeyManager.receivingTeesAndKeys(walletId);
        assertEq(pairs.length, 0);
    }


    // increaseKeyNonce
    function testIncreaseKeyNonceRevertOnlyBackupManager() public {
        vm.expectRevert(ITeeWalletKeyManager.OnlyBackupManager.selector);
        teeWalletKeyManager.increaseKeyNonce(teeId, walletId, keyId);
    }


    function testIncreaseKeyNonceRevertInvalidKeyId() public {
        testConfirmKeyNotInWallet();
        vm.prank(teeWalletBackupManager);
        vm.expectRevert(ITeeWalletKeyManager.InvalidKeyId.selector);
        teeWalletKeyManager.increaseKeyNonce(teeId, walletId, keyId + 1);
    }


    function testIncreaseKeyNonce() public {
        testConfirmKeyNotInWallet();
        vm.prank(teeWalletBackupManager);
        assertEq(teeWalletKeyManager.increaseKeyNonce(teeId, walletId, keyId), 1);
    }


    // getWalletKeysInfo
    function testGetWalletKeysInfo() public {
        (uint64 multisigThreshold, uint64[] memory keyIds, uint64 counter)
            = teeWalletKeyManager.getWalletKeysInfo(walletId);
        assertEq(multisigThreshold, 0);
        assertEq(keyIds.length, 0);
        assertEq(counter, 0);
        testConfirmKeyNotInWallet();
        (multisigThreshold, keyIds, counter) = teeWalletKeyManager.getWalletKeysInfo(walletId);
        assertEq(multisigThreshold, 0);
        assertEq(keyIds[0], keyId);
        assertEq(counter, 1);
    }


    // getWalletKeyPublicKey
    function testGetWalletKeyPublicKey() public {
        bytes memory pk = teeWalletKeyManager.getWalletKeyPublicKey(walletId, keyId);
        assertEq(pk, "");
        testConfirmKeyNotInWallet();
        pk = teeWalletKeyManager.getWalletKeyPublicKey(walletId, keyId);
        assertEq(pk, proof.publicKey);
    }


    // getWalletKeyTeeIds
    function testGetWalletKeyTeeIds() public {
        address[] memory teeIds = teeWalletKeyManager.getWalletKeyTeeIds(walletId, keyId);
        assertEq(teeIds.length, 0);
        testConfirmKeyNotInWallet();
        teeIds = teeWalletKeyManager.getWalletKeyTeeIds(walletId, keyId);
        assertEq(teeIds.length, 1);
        assertEq(teeIds[0], teeId);
    }


    function _setupConfirmKeyInWallet() private {
        testIncreaseKeyNonce();
        proof.restored = true;
        proof.nonce++;
    }


    function _mockGetOwner(address _owner) private {
        vm.mockCall(
            teeWalletProjectManager,
            abi.encodeWithSelector(
                ITeeWalletProjectManager.getOwner.selector
            ),
            abi.encode(_owner)
        );
    }


    function _mockGetWalletStatus(ITeeWalletManager.WalletStatus _status) private {
        vm.mockCall(
            teeWalletManager,
            abi.encodeWithSelector(
                ITeeWalletManager.getWalletStatus.selector
            ),
            abi.encode(_status)
        );
    }


    function _mockGetTeeMachineStatus(ITeeMachineRegistry.TeeStatus _status) private {
        vm.mockCall(
            teeMachineRegistry,
            abi.encodeWithSelector(
                ITeeMachineRegistry.getTeeMachineStatus.selector
            ),
            abi.encode(_status)
        );
    }


    function _mockGetExtensionId(uint256 _extensionId) private {
        vm.mockCall(
            teeMachineRegistry,
            abi.encodeWithSelector(
                ITeeMachineRegistry.getExtensionId.selector
            ),
            abi.encode(_extensionId)
        );
    }


    function _createSignature(
        uint256 _privateKey
    )
        private view
        returns (Signature memory)
    {
        bytes32 signedMessageHash =
            MessageHashUtils.toEthSignedMessageHash(keccak256(abi.encode(proof)));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_privateKey, signedMessageHash);
        return Signature(v, r, s);
    }
}