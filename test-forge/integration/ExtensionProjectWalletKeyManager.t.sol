// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../../contracts/tee/implementation/TeeExtensionRegistry.sol";
import "../../contracts/tee/implementation/TeeWalletProjectManager.sol";
import "../../contracts/tee/implementation/TeeWalletKeyManager.sol";
import "../../contracts/tee/implementation/TeeWalletManager.sol";
import "../../contracts/tee/implementation/TeeWalletBackupManager.sol";
import "../../contracts/tee/proxy/TeeExtensionRegistryProxy.sol";
import "../../contracts/tee/proxy/TeeWalletProjectManagerProxy.sol";
import "../../contracts/tee/proxy/TeeWalletKeyManagerProxy.sol";
import "../../contracts/tee/proxy/TeeWalletManagerProxy.sol";
import "../../contracts/tee/proxy/TeeWalletBackupManagerProxy.sol";
import "../../contracts/userInterfaces/LTS/ProtocolsV2Interface.sol";

// solhint-disable-next-line max-states-count
contract ExtensionProjectWalletKeyManagerTest is Test {

    TeeExtensionRegistry private teeExtensionRegistry;
    TeeWalletProjectManager private teeWalletProjectManager;
    TeeWalletKeyManager private teeWalletKeyManager;
    TeeWalletManager private teeWalletManager;

    TeeExtensionRegistry private teeExtensionRegistryImpl;
    TeeWalletProjectManager private teeWalletProjectManagerImpl;
    TeeWalletKeyManager private teeWalletKeyManagerImpl;
    TeeWalletManager private teeWalletManagerImpl;

    TeeExtensionRegistryProxy private teeExtensionRegistryProxy;
    TeeWalletProjectManagerProxy private teeWalletProjectManagerProxy;
    TeeWalletKeyManagerProxy private teeWalletKeyManagerProxy;
    TeeWalletManagerProxy private teeWalletManagerProxy;

    address private initialGovernance;
    address private addressUpdater;
    address private teeGovernance;
    address private teeMachineRegistry;
    address private teeFeeCalculator;
    address private flareSystemsManager;
    address private rewardManager;
    address private teeOwnerAllowList;
    address private teeWalletBackupManager;

    address private extensionOwner;
    ITeeExtensionStateVerifier private teeExtensionStateVerifier;
    address private teeInstructionSender;
    uint256 private extensionId;
    bytes32 private projectId;
    bytes32 private opType;
    address private submitAddress;
    address private teeId;
    address private newTeeId;
    uint256 private privateKey;
    uint256 private newPrivateKey;
    bytes32 private walletId;
    address private projectOwner;
    ITeeWalletProjectOpTypeConstants[] private opTypeConstantsProviders;
    bytes private opTypeConstants;
    uint64 private keyId;
    ITeeWalletKeyManager.KeyExistence private proof;
    address private backupManager;
    address[] private pausingAddresses;
    address[] private cosigners;
    ITeeWalletBackupManager.BackupId private backupId;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    function setUp() public {
        extensionOwner = makeAddr("extensionOwner");
        teeInstructionSender = makeAddr("teeInstructionSender");
        extensionId = 1;
        opType = keccak256("OP_TYPE");
        submitAddress = makeAddr("submitAddress");
        (teeId, privateKey) = makeAddrAndKey("teeId");
        (newTeeId, newPrivateKey) = makeAddrAndKey("newTeeId");
        backupManager = makeAddr("backupManager");
        pausingAddresses = new address[](1);
        pausingAddresses[0] = makeAddr("pausingAddresses1");
        cosigners = new address[](1);
        cosigners[0] = makeAddr("cosigner1");

        initialGovernance = makeAddr("initialGovernance");
        addressUpdater = makeAddr("AddressUpdater");
        IGovernanceSettings governanceSettings = IGovernanceSettings(makeAddr("governanceSettings"));
        teeGovernance = makeAddr("TeeGovernance");
        teeMachineRegistry = makeAddr("TeeMachineRegistry");
        teeFeeCalculator = makeAddr("TeeFeeCalculator");
        teeWalletBackupManager = makeAddr("TeeWalletBackupManager");
        flareSystemsManager = makeAddr("FlareSystemsManager");
        rewardManager = makeAddr("RewardManager");
        teeOwnerAllowList = makeAddr("TeeOwnerAllowList");
        opTypeConstantsProviders = new ITeeWalletProjectOpTypeConstants[](1);
        opTypeConstantsProviders[0] = ITeeWalletProjectOpTypeConstants(makeAddr("opTypeConstantsProviders1"));
        opTypeConstants = abi.encode("OP_TYPE_CONSTANTS");

        PublicKey[] memory publicKeys = new PublicKey[](1);
        publicKeys[0] = PublicKey(keccak256("1"), keccak256("1"));

        proof.teeId = teeId;
        proof.walletId = walletId;
        proof.nonce = 0;
        proof.opType = opType;
        //proof.configConstants.adminsPublicKeys.push(publicKeys[0]);
        proof.configConstants.adminsThreshold = 1;
        proof.configConstants.cosignersThreshold = 1;
        proof.configConstants.opTypeConstants = opTypeConstants;
        proof.publicKey = abi.encode("publicKey");
        proof.addressStr = "address";
        proof.restored = true;
        proof.keyId = keyId;
        proof.configConstants.cosigners.push(cosigners[0]);

        teeExtensionRegistryImpl = new TeeExtensionRegistry();
        teeExtensionRegistryProxy = new TeeExtensionRegistryProxy(
            governanceSettings,
            initialGovernance,
            addressUpdater,
            address(teeExtensionRegistryImpl)
        );
        teeExtensionRegistry = TeeExtensionRegistry(address(teeExtensionRegistryProxy));

        teeWalletProjectManagerImpl = new TeeWalletProjectManager();
        teeWalletProjectManagerProxy = new TeeWalletProjectManagerProxy(
            governanceSettings,
            initialGovernance,
            addressUpdater,
            address(teeWalletProjectManagerImpl)
        );
        teeWalletProjectManager = TeeWalletProjectManager(address(teeWalletProjectManagerProxy));

        teeWalletKeyManagerImpl = new TeeWalletKeyManager();
        teeWalletKeyManagerProxy = new TeeWalletKeyManagerProxy(
            governanceSettings,
            initialGovernance,
            addressUpdater,
            address(teeWalletKeyManagerImpl)
        );
        teeWalletKeyManager = TeeWalletKeyManager(address(teeWalletKeyManagerProxy));

        teeWalletManagerImpl = new TeeWalletManager();
        teeWalletManagerProxy = new TeeWalletManagerProxy(
            governanceSettings,
            initialGovernance,
            addressUpdater,
            address(teeWalletManagerImpl)
        );
        teeWalletManager = TeeWalletManager(address(teeWalletManagerProxy));

        vm.startPrank(addressUpdater);
        contractNameHashes = new bytes32[](6);
        contractAddresses = new address[](6);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("TeeGovernance"));
        contractNameHashes[2] = keccak256(abi.encode("TeeMachineRegistry"));
        contractNameHashes[3] = keccak256(abi.encode("TeeFeeCalculator"));
        contractNameHashes[4] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[5] = keccak256(abi.encode("RewardManager"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = teeGovernance;
        contractAddresses[2] = teeMachineRegistry;
        contractAddresses[3] = teeFeeCalculator;
        contractAddresses[4] = flareSystemsManager;
        contractAddresses[5] = rewardManager;
        teeExtensionRegistry.updateContractAddresses(contractNameHashes, contractAddresses);

        contractNameHashes = new bytes32[](4);
        contractAddresses = new address[](4);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("TeeExtensionRegistry"));
        contractNameHashes[2] = keccak256(abi.encode("TeeOwnerAllowlist"));
        contractNameHashes[3] = keccak256(abi.encode("TeeWalletManager"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = address(teeExtensionRegistry);
        contractAddresses[2] = teeOwnerAllowList;
        contractAddresses[3] = address(teeWalletManager);
        teeWalletProjectManager.updateContractAddresses(contractNameHashes, contractAddresses);

        contractNameHashes = new bytes32[](6);
        contractAddresses = new address[](6);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("TeeExtensionRegistry"));
        contractNameHashes[2] = keccak256(abi.encode("TeeMachineRegistry"));
        contractNameHashes[3] = keccak256(abi.encode("TeeWalletProjectManager"));
        contractNameHashes[4] = keccak256(abi.encode("TeeWalletKeyManager"));
        contractNameHashes[5] = keccak256(abi.encode("FlareSystemsManager"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = address(teeExtensionRegistry);
        contractAddresses[2] = teeMachineRegistry;
        contractAddresses[3] = address(teeWalletProjectManager);
        contractAddresses[4] = address(teeWalletKeyManager);
        contractAddresses[5] = flareSystemsManager;
        teeWalletManager.updateContractAddresses(contractNameHashes, contractAddresses);

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
        contractAddresses[2] = teeMachineRegistry;
        contractAddresses[3] = address(teeWalletProjectManager);
        contractAddresses[4] = address(teeWalletManager);
        contractAddresses[5] = teeWalletBackupManager;
        contractAddresses[6] = flareSystemsManager;
        teeWalletKeyManager.updateContractAddresses(contractNameHashes, contractAddresses);
        vm.stopPrank();

        vm.mockCall(
            teeOwnerAllowList,
            abi.encodeWithSelector(ITeeOwnerAllowlist.isAllowedTeeWalletProjectOwner.selector),
            abi.encode(true)
        );

        vm.mockCall(
            address(opTypeConstantsProviders[0]),
            abi.encodeWithSelector(ITeeWalletProjectOpTypeConstants.getOpTypeConstants.selector),
            abi.encode(opTypeConstants)
        );

        vm.mockCall(
            address(opTypeConstantsProviders[0]),
            abi.encodeWithSelector(ITeeWalletProjectOpTypeConstants.getOpType.selector),
            abi.encode(opType)
        );

        vm.mockCall(
            teeMachineRegistry,
            abi.encodeWithSelector(ITeeMachineRegistry.getTeeMachineStatus.selector),
            abi.encode(ITeeMachineRegistry.TeeStatus.PRODUCTION)
        );

        vm.mockCall(
            teeMachineRegistry,
            abi.encodeWithSelector(ITeeMachineRegistry.getExtensionId.selector),
            abi.encode(extensionId)
        );

        vm.mockCall(
            teeFeeCalculator,
            abi.encodeWithSelector(ITeeFeeCalculator.calculateFeeByTeeIds.selector),
            abi.encode(0)
        );

        vm.mockCall(
            teeFeeCalculator,
            abi.encodeWithSelector(ITeeFeeCalculator.calculateFeeByTeeIds.selector),
            abi.encode(0)
        );

        vm.mockCall(
            teeMachineRegistry,
            abi.encodeWithSelector(ITeeMachineRegistry.getTeeMachine.selector),
            abi.encode(ITeeMachineRegistry.TeeMachine(
                teeId, teeId, "url"
            ))
        );

        vm.mockCall(
            flareSystemsManager,
            abi.encodeWithSelector(ProtocolsV2Interface.getCurrentRewardEpochId.selector),
            abi.encode(1)
        );

        vm.mockCall(
            rewardManager,
            abi.encodeWithSelector(IIRewardManager.receiveRewards.selector),
            abi.encode(1)
        );

        vm.mockCall(
            teeMachineRegistry,
            abi.encodeWithSelector(ITeeMachineRegistry.getInitialSigningPolicyId.selector),
            abi.encode(1)
        );
    }

    function testProductionWallet() public {
        PublicKey[] memory adminsPublicKeys = new PublicKey[](1);
        adminsPublicKeys[0] = _getRandomPublicKey();
        address admin = _getAddress(adminsPublicKeys[0]);
        address[] memory instructionInitiators = new address[](1);
        instructionInitiators[0] = address(teeWalletKeyManager);

        vm.startPrank(extensionOwner);
        teeExtensionRegistry.register(teeExtensionStateVerifier, teeInstructionSender);
        teeExtensionRegistry.addOrUpdateSupportedWalletProjectOpTypes(extensionId, opTypeConstantsProviders);
        vm.stopPrank();

        vm.prank(initialGovernance);
        teeExtensionRegistry.registerSystemInstructionInitiators(instructionInitiators);

        vm.startPrank(projectOwner);
        projectId = teeWalletProjectManager.createProject(extensionId, opType, submitAddress);
        walletId = teeWalletManager.createWallet(projectId);
        teeWalletManager.setAdmins(walletId, adminsPublicKeys, 1);
        teeWalletManager.setCosigners(walletId, cosigners, 1);
        vm.stopPrank();

        vm.prank(admin);
        teeWalletManager.confirmAdmin(walletId);

        vm.prank(cosigners[0]);
        teeWalletManager.confirmCosigner(walletId);

        vm.startPrank(projectOwner);
        vm.expectRevert(ITeeWalletManager.InvalidWalletStatus.selector);
        teeWalletKeyManager.addKey(teeId, walletId);

        teeWalletManager.closeWalletInitialization(walletId);
        teeWalletKeyManager.addKey(teeId, walletId);
        keyId = teeWalletKeyManager.addKey(newTeeId, walletId);

        proof.keyId = keyId;
        proof.walletId = walletId;
        proof.restored = false;
        proof.configConstants.adminsPublicKeys.push(adminsPublicKeys[0]);
        teeWalletKeyManager.confirmKey(proof, _createSignature(privateKey));

        vm.stopPrank();

        vm.prank(teeWalletBackupManager);
        teeWalletKeyManager.increaseKeyNonce(newTeeId, walletId, keyId);

        vm.startPrank(projectOwner);
        proof.teeId = newTeeId;
        proof.restored = true;
        proof.nonce = 1;
        teeWalletKeyManager.confirmKey(proof, _createSignature(newPrivateKey));


        address[] memory teeIdKeyStore = teeWalletKeyManager.getWalletKeyTeeIds(walletId, keyId);
        assertEq(teeIdKeyStore.length, 2);

        keyId = teeWalletKeyManager.addKey(teeId, walletId);
        proof.teeId = teeId;
        proof.keyId = keyId;
        proof.nonce = 0;
        proof.restored = false;
        teeWalletKeyManager.confirmKey(proof, _createSignature(privateKey));

        teeWalletKeyManager.deleteKey(teeId, walletId, keyId);

        teeWalletKeyManager.setMultisigThreshold(walletId, 3);
        vm.expectRevert(ITeeWalletManager.NotEnoughKeys.selector);
        teeWalletManager.enableWallet(walletId);

        teeWalletKeyManager.setMultisigThreshold(walletId, 2);

        teeWalletManager.enableWallet(walletId);

        teeWalletProjectManager.setDefaultWallet(projectId, walletId);
        vm.stopPrank();

        address newProjectOwner = makeAddr("newProjectOwner");
        vm.startPrank(projectOwner);
        teeWalletProjectManager.proposeNewOwner(projectId, newProjectOwner);
        teeWalletManager.createWallet(projectId);
        vm.stopPrank();

        vm.startPrank(newProjectOwner);
        teeWalletProjectManager.confirmOwnership(projectId);
        teeWalletManager.createWallet(projectId);
        vm.stopPrank();

        // not the owner anymore
        vm.expectRevert(ITeeWalletManager.OnlyOwner.selector);
        vm.prank(projectOwner);
        teeWalletManager.createWallet(projectId);


        vm.startPrank(newProjectOwner);
        teeWalletManager.pauseWallet(walletId);
        vm.expectRevert(ITeeWalletKeyManager.InvalidWalletStatus.selector);
        teeWalletKeyManager.addKey(teeId, walletId);
        teeWalletManager.enableWallet(walletId);
        vm.stopPrank();

        vm.prank(initialGovernance);
        teeExtensionRegistry.unregisterSystemInstructionInitiators(instructionInitiators);

        vm.startPrank(newProjectOwner);
        vm.expectRevert(ITeeWalletKeyManager.ThresholdNotMet.selector);
        teeWalletManager.setPausingAddresses(walletId, pausingAddresses);

        proof.nonce = 1;
        proof.restored = true;
        teeWalletKeyManager.confirmKey(proof, _createSignature(privateKey));
        vm.expectRevert(ITeeExtensionRegistry.OnlyInstructionsSender.selector);
        teeWalletManager.setPausingAddresses(walletId, pausingAddresses);
        vm.stopPrank();

    }

    function _getRandomPublicKey() internal returns (PublicKey memory) {
        // call external script to get random public key coordinates
        string[] memory command = new string[](2);
        command[0] = "node";
        command[1] = "test-forge/utils/generate-key.js";
        // command[0] = "bash";
        // command[1] = "-c";
        // command[2] = "cast wallet public-key --raw-private-key \"$(cast wallet new --json | jq -r 'if type==\"array\" then .[0].private_key else .private_key end')\"";

        bytes memory result = vm.ffi(command);

        // check if result is 64 bytes
        require(result.length == 64, "invalid output length");

        // extract x and y as bytes32
        bytes32 x;
        bytes32 y;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            x := mload(add(result, 32)) // first 32 bytes (hex-decoded)
            y := mload(add(result, 64)) // second 32 bytes
        }

        PublicKey memory pk = PublicKey(x, y);

        return pk;
    }

    function _getAddress(PublicKey memory _pk) internal pure returns (address) {
        uint256[2] memory publicKeyPair = [uint256(_pk.x), uint256(_pk.y)];
        bytes32 hash = keccak256(abi.encodePacked(publicKeyPair));
        return address(uint160(uint256(hash)));
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