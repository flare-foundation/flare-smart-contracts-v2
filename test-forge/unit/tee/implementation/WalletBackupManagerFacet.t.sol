// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";

import { FlareTeeManagerDeployer } from "../../../utils/FlareTeeManagerDeployer.sol";

import { IIFlareTeeManager } from "../../../../contracts/tee/interface/IIFlareTeeManager.sol";
import {
    IWalletBackupManagerFacet
} from "../../../../contracts/userInterfaces/tee/IWalletBackupManagerFacet.sol";
import { IMachineManagerFacet } from "../../../../contracts/userInterfaces/tee/IMachineManagerFacet.sol";
import { IWalletManagerFacet } from "../../../../contracts/userInterfaces/tee/IWalletManagerFacet.sol";
import { ITeeCommonErrors } from "../../../../contracts/userInterfaces/tee/ITeeCommonErrors.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

import { ProtocolsV2Interface } from "../../../../contracts/userInterfaces/LTS/ProtocolsV2Interface.sol";
import { IIRewardManager } from "../../../../contracts/protocol/interface/IIRewardManager.sol";
import { PublicKey } from "../../../../contracts/userInterfaces/IPublicKey.sol";

import { IDiamond } from "../../../../contracts/diamond/interfaces/IDiamond.sol";
import { IDiamondCut } from "../../../../contracts/diamond/interfaces/IDiamondCut.sol";

import { MachineManager } from "../../../../contracts/tee/library/MachineManager.sol";
import { WalletProjectManager } from "../../../../contracts/tee/library/WalletProjectManager.sol";
import { WalletManager } from "../../../../contracts/tee/library/WalletManager.sol";
import { WalletKeyManager } from "../../../../contracts/tee/library/WalletKeyManager.sol";

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

interface ITestStateHelperFacet {
    function setTeeMachineState(
        address _teeId,
        uint256 _extensionId,
        address _owner,
        IMachineManagerFacet.TeeStatus _status,
        PublicKey calldata _publicKey,
        uint32 _initialSigningPolicyId,
        string calldata _url
    ) external;

    function setProjectState(
        bytes32 _projectId,
        address _owner,
        uint256 _extensionId,
        bytes32 _keyType,
        bytes32 _signingAlgo,
        address _backupManager
    ) external;

    function setWalletState(
        bytes32 _walletId,
        bytes32 _projectId,
        PublicKey[] calldata _adminsPublicKeys,
        uint64 _adminsThreshold
    ) external;

    function setKeyState(
        bytes32 _walletId,
        uint64 _keyId,
        bytes calldata _publicKey,
        address[] calldata _teeIds,
        uint64 _keyIdCounter
    ) external;

    function setExtensionInstructionCounter(
        uint256 _extensionId,
        uint256 _counter
    ) external;
}

/**
 * @title TestStateHelperFacet
 * @notice A test-only facet added to the diamond to write internal state directly,
 *         bypassing the complex registration, attestation, and wallet lifecycle flows.
 */
contract TestStateHelperFacet is ITestStateHelperFacet {
    using EnumerableSet for EnumerableSet.AddressSet;

    function setTeeMachineState(
        address _teeId,
        uint256 _extensionId,
        address _owner,
        IMachineManagerFacet.TeeStatus _status,
        PublicKey calldata _publicKey,
        uint32 _initialSigningPolicyId,
        string calldata _url
    )
        external
    {
        MachineManager.State storage s = MachineManager.getState();
        s.teeMachineStates[_teeId] = MachineManager.TeeMachineState({
            extensionId: _extensionId,
            teePublicKey: _publicKey,
            initialTeeId: _teeId,
            initialSigningPolicyId: _initialSigningPolicyId,
            owner: _owner,
            teeProxyId: _teeId,
            status: _status,
            lastStatusChangeTs: block.timestamp,
            codeHash: bytes32(0),
            platform: bytes32(0),
            url: _url
        });
        if (_status == IMachineManagerFacet.TeeStatus.PRODUCTION) {
            s.activeTeeIds.add(_teeId);
            s.extensionActiveTeeIds[_extensionId].add(_teeId);
        }
    }

    function setProjectState(
        bytes32 _projectId,
        address _owner,
        uint256 _extensionId,
        bytes32 _keyType,
        bytes32 _signingAlgo,
        address _backupManager
    )
        external
    {
        WalletProjectManager.State storage s = WalletProjectManager.getState();
        s.projects[_projectId] = WalletProjectManager.TeeWalletProjectState({
            owner: _owner,
            extensionId: _extensionId,
            keyType: _keyType,
            signingAlgo: _signingAlgo,
            backupManager: _backupManager
        });
    }

    function setWalletState(
        bytes32 _walletId,
        bytes32 _projectId,
        PublicKey[] calldata _adminsPublicKeys,
        uint64 _adminsThreshold
    )
        external
    {
        WalletManager.State storage s = WalletManager.getState();
        WalletManager.TeeWalletState storage wallet = s.wallets[_walletId];
        wallet.projectId = _projectId;
        wallet.status = IWalletManagerFacet.WalletStatus.PRODUCTION;
        wallet.adminsThreshold = _adminsThreshold;
        while (wallet.adminsPublicKeys.length > 0) {
            wallet.adminsPublicKeys.pop();
        }
        for (uint256 i = 0; i < _adminsPublicKeys.length; i++) {
            wallet.adminsPublicKeys.push(_adminsPublicKeys[i]);
        }
    }

    function setKeyState(
        bytes32 _walletId,
        uint64 _keyId,
        bytes calldata _publicKey,
        address[] calldata _teeIds,
        uint64 _keyIdCounter
    )
        external
    {
        WalletKeyManager.State storage s = WalletKeyManager.getState();
        WalletKeyManager.TeeWalletKeysState storage keys = s.walletKeys[_walletId];
        keys.keyIdCounter = _keyIdCounter;
        WalletKeyManager.KeyDefinition storage keyDef = keys.keyDefinitions[_keyId];
        keyDef.publicKey = _publicKey;
        // clear existing teeIds
        while (keyDef.teeIds.length > 0) {
            keyDef.teeIds.pop();
        }
        for (uint256 i = 0; i < _teeIds.length; i++) {
            keyDef.teeIds.push(_teeIds[i]);
        }
    }

    function setExtensionInstructionCounter(
        uint256 _extensionId,
        uint256 _counter
    )
        external
    {
        // instructionCounter was removed from TeeExtension struct
        (_extensionId, _counter); // suppress unused variable warning
    }
}

// solhint-disable-next-line max-states-count
contract WalletBackupManagerFacetTest is Test {

    IIFlareTeeManager private flareTeeManager;

    address private owner;
    address private backupManager;

    address private initialGovernance;
    address private addressUpdater;
    IGovernanceSettings private governanceSettings;
    address private flareSystemsManager;
    address private rewardManager;

    address private teeId;
    address private backupTeeId;
    address private teeMachineOwner;
    bytes32 private projectId;
    bytes32 private walletId;
    IWalletBackupManagerFacet.BackupId private backupId;
    string private backupUrl;
    uint64 private keyId;
    bytes private publicKey;
    address private keyHolderTeeId;
    uint32 private rewardEpochId;
    bytes32 private keyType;
    bytes32 private signingAlgo;
    uint256 private extensionId;
    uint256 private nonce;

    PublicKey private adminPk1;
    PublicKey private adminPk2;
    uint64 private adminsThreshold;

    function setUp() public {
        initialGovernance = makeAddr("initialGovernance");
        addressUpdater = makeAddr("AddressUpdater");
        governanceSettings = IGovernanceSettings(makeAddr("governanceSettings"));
        flareSystemsManager = makeAddr("FlareSystemsManager");
        rewardManager = makeAddr("RewardManager");

        owner = makeAddr("owner");
        backupManager = makeAddr("backupManager");
        teeMachineOwner = makeAddr("teeMachineOwner");

        teeId = makeAddr("teeId");
        backupTeeId = makeAddr("backupTeeId");
        keyHolderTeeId = makeAddr("keyHolderTeeId");
        projectId = keccak256("projectId");
        walletId = keccak256("walletId");
        keyId = 1;
        publicKey = bytes("publicKey");
        rewardEpochId = 1;
        nonce = 1;
        backupUrl = "backupUrl";
        extensionId = 10;

        keyType = keccak256("keyType");
        signingAlgo = keccak256("signingAlgo");

        // Use valid ec points for admin public keys
        VmSafe.Wallet memory w1 = vm.createWallet("admin1");
        adminPk1 = PublicKey(bytes32(w1.publicKeyX), bytes32(w1.publicKeyY));
        VmSafe.Wallet memory w2 = vm.createWallet("admin2");
        adminPk2 = PublicKey(bytes32(w2.publicKeyX), bytes32(w2.publicKeyY));
        adminsThreshold = 2;

        backupId = IWalletBackupManagerFacet.BackupId(
            backupTeeId,
            walletId,
            keyId,
            keyType,
            signingAlgo,
            publicKey,
            rewardEpochId,
            bytes32("randomNonce")
        );

        // =====================================================================
        // Deploy FlareTeeManager Diamond
        // =====================================================================

        flareTeeManager = FlareTeeManagerDeployer.deployDay1Facets(FlareTeeManagerDeployer.Day1DeployParams({
            governanceSettings: governanceSettings,
            initialGovernance: initialGovernance,
            addressUpdater: addressUpdater,
            availabilityCheckValidityDurationSeconds: 3600,
            signingPolicyValidityDurationInRewardEpochs: 6,
            challengeValidityDurationSeconds: 600,
            defaultFee: 0
        }));
        vm.startPrank(initialGovernance);
        FlareTeeManagerDeployer.deployLaterFacets(flareTeeManager, FlareTeeManagerDeployer.LaterDeployParams({
            pauseBeforeUpgradeMinDurationSeconds: 600
        }));
        vm.stopPrank();

        // =====================================================================
        // Add TestStateHelperFacet to the diamond
        // =====================================================================

        TestStateHelperFacet helperImpl = new TestStateHelperFacet();
        bytes4[] memory helperSelectors = new bytes4[](5);
        helperSelectors[0] = ITestStateHelperFacet.setTeeMachineState.selector;
        helperSelectors[1] = ITestStateHelperFacet.setProjectState.selector;
        helperSelectors[2] = ITestStateHelperFacet.setWalletState.selector;
        helperSelectors[3] = ITestStateHelperFacet.setKeyState.selector;
        helperSelectors[4] = ITestStateHelperFacet.setExtensionInstructionCounter.selector;

        IDiamond.FacetCut[] memory cuts = new IDiamond.FacetCut[](1);
        cuts[0] = IDiamond.FacetCut(
            address(helperImpl),
            IDiamond.FacetCutAction.Add,
            helperSelectors
        );

        vm.prank(initialGovernance);
        IDiamondCut(address(flareTeeManager)).diamondCut(cuts, address(0), "");

        // =====================================================================
        // Update external contract addresses
        // =====================================================================

        bytes32[] memory nameHashes = new bytes32[](6);
        address[] memory addresses = new address[](6);
        nameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        nameHashes[1] = keccak256(abi.encode("FlareSystemsManager"));
        nameHashes[2] = keccak256(abi.encode("RewardManager"));
        nameHashes[3] = keccak256(abi.encode("Relay"));
        nameHashes[4] = keccak256(abi.encode("Fdc2Hub"));
        nameHashes[5] = keccak256(abi.encode("Fdc2Verification"));
        addresses[0] = addressUpdater;
        addresses[1] = flareSystemsManager;
        addresses[2] = rewardManager;
        addresses[3] = makeAddr("Relay");
        addresses[4] = makeAddr("Fdc2Hub");
        addresses[5] = makeAddr("Fdc2Verification");
        vm.prank(addressUpdater);
        flareTeeManager.updateContractAddresses(nameHashes, addresses);

        // =====================================================================
        // Set up diamond state through the helper facet
        // =====================================================================

        ITestStateHelperFacet helper = ITestStateHelperFacet(address(flareTeeManager));

        // Set teeId as PRODUCTION TEE machine
        helper.setTeeMachineState(
            teeId,
            extensionId,
            teeMachineOwner,
            IMachineManagerFacet.TeeStatus.PRODUCTION,
            PublicKey(bytes32(0), bytes32(0)),
            1, // initialSigningPolicyId
            "https://tee.url"
        );

        // Set backupTeeId as PRODUCTION TEE machine (not INITIALIZED)
        helper.setTeeMachineState(
            backupTeeId,
            extensionId,
            teeMachineOwner,
            IMachineManagerFacet.TeeStatus.PRODUCTION,
            PublicKey(bytes32(0), bytes32(0)),
            1,
            "https://backup.tee.url"
        );

        // Set up keyHolderTeeId as PRODUCTION TEE machine (separate from teeId)
        helper.setTeeMachineState(
            keyHolderTeeId,
            extensionId,
            teeMachineOwner,
            IMachineManagerFacet.TeeStatus.PRODUCTION,
            PublicKey(bytes32(0), bytes32(0)),
            1,
            "https://keyholder.tee.url"
        );

        // Set up project state
        helper.setProjectState(
            projectId,
            owner,
            extensionId,
            keyType,
            signingAlgo,
            backupManager
        );

        // Set up wallet state with admin public keys
        PublicKey[] memory adminsPublicKeys = new PublicKey[](2);
        adminsPublicKeys[0] = adminPk1;
        adminsPublicKeys[1] = adminPk2;
        helper.setWalletState(walletId, projectId, adminsPublicKeys, adminsThreshold);

        // Set up key state: keyHolderTeeId holds the key (not teeId)
        address[] memory keyTeeIds = new address[](1);
        keyTeeIds[0] = keyHolderTeeId;
        helper.setKeyState(walletId, keyId, publicKey, keyTeeIds, keyId + 1);

        // Set extension instruction counter so generateInstructionId works
        helper.setExtensionInstructionCounter(extensionId, 1);

        // =====================================================================
        // Mock external contracts
        // =====================================================================

        vm.mockCall(
            flareSystemsManager,
            abi.encodeWithSelector(ProtocolsV2Interface.getCurrentRewardEpochId.selector),
            abi.encode(uint24(15))
        );

        vm.mockCall(
            rewardManager,
            abi.encodeWithSelector(IIRewardManager.receiveRewards.selector),
            abi.encode("")
        );
    }

    // =========================================================================
    // backupRestore - revert tests
    // =========================================================================

    function testBackupRestoreRevertOnlyOwnerOrBackupManager() public {
        vm.expectRevert(ITeeCommonErrors.OnlyOwnerOrBackupManager.selector);
        flareTeeManager.backupRestore(teeId, backupId, backupUrl, address(0));
    }

    function testBackupRestoreRevertTeeMachineNotAvailable() public {
        // Set teeId to INITIALIZED status
        ITestStateHelperFacet(address(flareTeeManager)).setTeeMachineState(
            teeId,
            extensionId,
            teeMachineOwner,
            IMachineManagerFacet.TeeStatus.INITIALIZED,
            PublicKey(bytes32(0), bytes32(0)),
            1,
            "https://tee.url"
        );
        vm.expectRevert(ITeeCommonErrors.TeeMachineNotAvailable.selector);
        vm.prank(owner);
        flareTeeManager.backupRestore(teeId, backupId, backupUrl, address(0));
    }

    function testBackupRestoreRevertInvalidTeeMachine() public {
        // Set backupTeeId to INITIALIZED status
        ITestStateHelperFacet(address(flareTeeManager)).setTeeMachineState(
            backupTeeId,
            extensionId,
            teeMachineOwner,
            IMachineManagerFacet.TeeStatus.INITIALIZED,
            PublicKey(bytes32(0), bytes32(0)),
            1,
            "https://backup.tee.url"
        );
        vm.expectRevert(IWalletBackupManagerFacet.InvalidTeeMachine.selector);
        vm.prank(owner);
        flareTeeManager.backupRestore(teeId, backupId, backupUrl, address(0));
    }

    function testBackupRestoreRevertKeyAlreadyAvailable() public {
        // Set key held by teeId (the target restore TEE)
        address[] memory keyTeeIds = new address[](1);
        keyTeeIds[0] = teeId;
        ITestStateHelperFacet(address(flareTeeManager)).setKeyState(
            walletId, keyId, publicKey, keyTeeIds, keyId + 1
        );
        vm.prank(owner);
        vm.expectRevert(IWalletBackupManagerFacet.KeyAlreadyAvailable.selector);
        flareTeeManager.backupRestore(teeId, backupId, backupUrl, address(0));
    }

    function testBackupRestoreRevertKeyNotConfirmed() public {
        // Set key with empty public key
        address[] memory keyTeeIds = new address[](1);
        keyTeeIds[0] = keyHolderTeeId;
        ITestStateHelperFacet(address(flareTeeManager)).setKeyState(
            walletId, keyId, bytes(""), keyTeeIds, keyId + 1
        );
        vm.prank(owner);
        vm.expectRevert(IWalletBackupManagerFacet.KeyNotConfirmed.selector);
        flareTeeManager.backupRestore(teeId, backupId, backupUrl, address(0));
    }

    function testBackupRestoreRevertInvalidPublicKey() public {
        // Set key with different public key than backupId.publicKey
        address[] memory keyTeeIds = new address[](1);
        keyTeeIds[0] = keyHolderTeeId;
        ITestStateHelperFacet(address(flareTeeManager)).setKeyState(
            walletId, keyId, bytes("invalidKey"), keyTeeIds, keyId + 1
        );
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.InvalidPublicKey.selector);
        flareTeeManager.backupRestore(teeId, backupId, backupUrl, address(0));
    }

    function testBackupRestoreRevertUnsupportedRewardEpochId() public {
        backupId.rewardEpochId = 0;
        vm.prank(owner);
        vm.expectRevert(IWalletBackupManagerFacet.UnsupportedRewardEpochId.selector);
        flareTeeManager.backupRestore(teeId, backupId, backupUrl, address(0));
    }

    function testBackupRestoreRevertInvalidRewardEpochId() public {
        backupId.rewardEpochId = 20;
        vm.prank(owner);
        vm.expectRevert(IWalletBackupManagerFacet.InvalidRewardEpochId.selector);
        flareTeeManager.backupRestore(teeId, backupId, backupUrl, address(0));
    }

    function testBackupRestoreRevertInvalidKeyType() public {
        backupId.keyType = keccak256("InvalidKeyType");
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.InvalidKeyType.selector);
        flareTeeManager.backupRestore(teeId, backupId, backupUrl, address(0));
    }

    function testBackupRestoreRevertInvalidSigningAlgo() public {
        backupId.signingAlgo = keccak256("InvalidSigningAlgo");
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.InvalidSigningAlgo.selector);
        flareTeeManager.backupRestore(teeId, backupId, backupUrl, address(0));
    }

    function testBackupRestoreRevertExtensionIdMismatch1() public {
        // Set backupTeeId to a different extensionId
        ITestStateHelperFacet(address(flareTeeManager)).setTeeMachineState(
            backupTeeId,
            extensionId + 1,
            teeMachineOwner,
            IMachineManagerFacet.TeeStatus.PRODUCTION,
            PublicKey(bytes32(0), bytes32(0)),
            1,
            "https://backup.tee.url"
        );
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.ExtensionIdMismatch.selector);
        flareTeeManager.backupRestore(teeId, backupId, backupUrl, address(0));

        // Restore backupTeeId, set teeId to a different extensionId
        ITestStateHelperFacet(address(flareTeeManager)).setTeeMachineState(
            backupTeeId,
            extensionId,
            teeMachineOwner,
            IMachineManagerFacet.TeeStatus.PRODUCTION,
            PublicKey(bytes32(0), bytes32(0)),
            1,
            "https://backup.tee.url"
        );
        ITestStateHelperFacet(address(flareTeeManager)).setTeeMachineState(
            teeId,
            extensionId + 1,
            teeMachineOwner,
            IMachineManagerFacet.TeeStatus.PRODUCTION,
            PublicKey(bytes32(0), bytes32(0)),
            1,
            "https://tee.url"
        );
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.ExtensionIdMismatch.selector);
        flareTeeManager.backupRestore(teeId, backupId, backupUrl, address(0));
    }

    // =========================================================================
    // backupRestore - happy path
    // =========================================================================

    function testBackupRestore() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit IWalletBackupManagerFacet.BackupRestoreTriggered(
            teeId,
            walletId,
            keyId,
            1 // nonce (increaseKeyNonce returns ++nonce, first call = 1)
        );
        flareTeeManager.backupRestore(teeId, backupId, backupUrl, address(0));
    }

    function testBackupRestoreByBackupManager() public {
        vm.prank(backupManager);
        vm.expectEmit(true, true, true, true);
        emit IWalletBackupManagerFacet.BackupRestoreTriggered(
            teeId,
            walletId,
            keyId,
            1
        );
        flareTeeManager.backupRestore(teeId, backupId, backupUrl, address(0));
    }
}
