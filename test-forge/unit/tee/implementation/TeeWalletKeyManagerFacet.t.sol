// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";

import { FlareTeeManagerDeployer } from "../../../utils/FlareTeeManagerDeployer.sol";

import { IIFlareTeeManager } from "../../../../contracts/tee/interface/IIFlareTeeManager.sol";
import { ITeeWalletKeyManagerFacet } from "../../../../contracts/userInterfaces/tee/ITeeWalletKeyManagerFacet.sol";
import { ITeeWalletManagerFacet } from "../../../../contracts/userInterfaces/tee/ITeeWalletManagerFacet.sol";
import { ITeeMachineRegistryFacet } from "../../../../contracts/userInterfaces/tee/ITeeMachineRegistryFacet.sol";
import { ITeeCommonErrors } from "../../../../contracts/userInterfaces/tee/ITeeCommonErrors.sol";
import { TeeIdKeyIdPair } from "../../../../contracts/userInterfaces/tee/ITeeIdKeyIdPair.sol";
import { PublicKey } from "../../../../contracts/userInterfaces/IPublicKey.sol";
import { Signature } from "../../../../contracts/userInterfaces/ISignature.sol";
import { IIRewardManager } from "../../../../contracts/protocol/interface/IIRewardManager.sol";
import { ProtocolsV2Interface } from "../../../../contracts/userInterfaces/LTS/ProtocolsV2Interface.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import { IDiamond } from "../../../../contracts/diamond/interfaces/IDiamond.sol";
import { IDiamondCut } from "../../../../contracts/diamond/interfaces/IDiamondCut.sol";

import { TeeMachineRegistry } from "../../../../contracts/tee/library/TeeMachineRegistry.sol";
import { TeeWalletProjectManager } from "../../../../contracts/tee/library/TeeWalletProjectManager.sol";
import { TeeWalletManager } from "../../../../contracts/tee/library/TeeWalletManager.sol";
import { TeeWalletKeyManager } from "../../../../contracts/tee/library/TeeWalletKeyManager.sol";

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title TestKeyManagerHelperFacet
 * @notice A test-only facet added to the diamond to write internal state directly,
 *         bypassing the complex registration, attestation, and wallet lifecycle flows.
 */
contract TestKeyManagerHelperFacet {
    using EnumerableSet for EnumerableSet.AddressSet;

    function setTeeMachineState(
        address _teeId,
        uint256 _extensionId,
        address _owner,
        ITeeMachineRegistryFacet.TeeStatus _status,
        PublicKey calldata _publicKey,
        uint32 _initialSigningPolicyId,
        string calldata _url
    )
        external
    {
        TeeMachineRegistry.State storage s = TeeMachineRegistry.getState();
        s.teeMachineStates[_teeId] = TeeMachineRegistry.TeeMachineState({
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
        if (_status == ITeeMachineRegistryFacet.TeeStatus.PRODUCTION) {
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
        TeeWalletProjectManager.State storage s = TeeWalletProjectManager.getState();
        s.projects[_projectId] = TeeWalletProjectManager.TeeWalletProjectState({
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
        ITeeWalletManagerFacet.WalletStatus _status,
        PublicKey[] calldata _adminsPublicKeys,
        uint64 _adminsThreshold,
        address[] calldata _cosigners,
        uint64 _cosignersThreshold
    )
        external
    {
        TeeWalletManager.State storage s = TeeWalletManager.getState();
        TeeWalletManager.TeeWalletState storage wallet = s.wallets[_walletId];
        wallet.projectId = _projectId;
        wallet.status = _status;
        wallet.adminsThreshold = _adminsThreshold;
        wallet.cosignersThreshold = _cosignersThreshold;
        while (wallet.adminsPublicKeys.length > 0) {
            wallet.adminsPublicKeys.pop();
        }
        for (uint256 i = 0; i < _adminsPublicKeys.length; i++) {
            wallet.adminsPublicKeys.push(_adminsPublicKeys[i]);
        }
        while (wallet.cosigners.length > 0) {
            wallet.cosigners.pop();
        }
        for (uint256 i = 0; i < _cosigners.length; i++) {
            wallet.cosigners.push(_cosigners[i]);
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
        TeeWalletKeyManager.State storage s = TeeWalletKeyManager.getState();
        TeeWalletKeyManager.TeeWalletKeysState storage keys = s.walletKeys[_walletId];
        keys.keyIdCounter = _keyIdCounter;
        TeeWalletKeyManager.KeyDefinition storage keyDef = keys.keyDefinitions[_keyId];
        keyDef.publicKey = _publicKey;
        while (keyDef.teeIds.length > 0) {
            keyDef.teeIds.pop();
        }
        for (uint256 i = 0; i < _teeIds.length; i++) {
            keyDef.teeIds.push(_teeIds[i]);
        }
    }

    function setKeyIds(
        bytes32 _walletId,
        uint64[] calldata _keyIds
    )
        external
    {
        TeeWalletKeyManager.State storage s = TeeWalletKeyManager.getState();
        TeeWalletKeyManager.TeeWalletKeysState storage keys = s.walletKeys[_walletId];
        while (keys.keyIds.length > 0) {
            keys.keyIds.pop();
        }
        for (uint256 i = 0; i < _keyIds.length; i++) {
            keys.keyIds.push(_keyIds[i]);
        }
    }

    function setMultisigThresholdDirect(
        bytes32 _walletId,
        uint64 _multisigThreshold
    )
        external
    {
        TeeWalletKeyManager.State storage s = TeeWalletKeyManager.getState();
        s.walletKeys[_walletId].multisigThreshold = _multisigThreshold;
    }
}

interface ITestKeyManagerHelperFacet {
    function setTeeMachineState(
        address _teeId,
        uint256 _extensionId,
        address _owner,
        ITeeMachineRegistryFacet.TeeStatus _status,
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
        ITeeWalletManagerFacet.WalletStatus _status,
        PublicKey[] calldata _adminsPublicKeys,
        uint64 _adminsThreshold,
        address[] calldata _cosigners,
        uint64 _cosignersThreshold
    ) external;

    function setKeyState(
        bytes32 _walletId,
        uint64 _keyId,
        bytes calldata _publicKey,
        address[] calldata _teeIds,
        uint64 _keyIdCounter
    ) external;

    function setKeyIds(
        bytes32 _walletId,
        uint64[] calldata _keyIds
    ) external;

    function setMultisigThresholdDirect(
        bytes32 _walletId,
        uint64 _multisigThreshold
    ) external;
}

// solhint-disable-next-line max-states-count
contract TeeWalletKeyManagerFacetTest is Test {

    bytes32 public constant WALLET_OP_TYPE = bytes32("F_WALLET");
    bytes32 public constant KEY_GENERATE = bytes32("KEY_GENERATE");
    bytes32 public constant KEY_DELETE = bytes32("KEY_DELETE");

    IIFlareTeeManager private flareTeeManager;
    ITestKeyManagerHelperFacet private helper;

    address private owner;
    address private backupManager;
    address private teeMachineOwner;

    address private initialGovernance;
    address private addressUpdater;
    address private flareSystemsManager;
    address private rewardManager;

    address private teeId;
    uint256 private teePrivateKey;
    address private newTeeId;
    uint256 private newTeePrivateKey;

    bytes32 private projectId;
    bytes32 private walletId;
    uint64 private keyId;
    uint256 private extensionId;
    bytes32 private keyType;
    bytes32 private signingAlgo;

    PublicKey[] private adminsPublicKeys;
    address[] private cosigners;

    ITeeWalletKeyManagerFacet.KeyExistence private proof;
    Signature private teeSignature;

    function setUp() public {
        initialGovernance = makeAddr("initialGovernance");
        addressUpdater = makeAddr("AddressUpdater");
        flareSystemsManager = makeAddr("FlareSystemsManager");
        rewardManager = makeAddr("RewardManager");

        owner = makeAddr("owner");
        backupManager = makeAddr("backupManager");
        teeMachineOwner = makeAddr("teeMachineOwner");

        (teeId, teePrivateKey) = makeAddrAndKey("teeId");
        (newTeeId, newTeePrivateKey) = makeAddrAndKey("newTeeId");

        projectId = keccak256("projectId");
        walletId = keccak256("walletId");
        keyId = 0;
        extensionId = 10;

        keyType = keccak256("keyType");
        signingAlgo = keccak256("signingAlgo");

        // Admin public keys
        VmSafe.Wallet memory w1 = vm.createWallet("admin1");
        adminsPublicKeys.push(PublicKey(bytes32(w1.publicKeyX), bytes32(w1.publicKeyY)));
        cosigners = new address[](1);
        cosigners[0] = makeAddr("cosigner1");

        // Build proof struct in storage
        proof.teeId = teeId;
        proof.walletId = walletId;
        proof.nonce = 0;
        proof.keyType = keyType;
        proof.signingAlgo = signingAlgo;
        proof.configConstants.adminsPublicKeys.push(adminsPublicKeys[0]);
        proof.configConstants.adminsThreshold = 1;
        proof.configConstants.cosigners.push(cosigners[0]);
        proof.configConstants.cosignersThreshold = 1;
        proof.publicKey = abi.encode("publicKey");
        proof.restored = true;
        proof.keyId = keyId;
        proof.settingsVersion = bytes32(0);
        proof.settings = bytes("");

        teeSignature = _createSignature(teePrivateKey);

        // =====================================================================
        // Deploy FlareTeeManager Diamond
        // =====================================================================

        flareTeeManager = FlareTeeManagerDeployer.deployDay1Facets(FlareTeeManagerDeployer.Day1DeployParams({
            governanceSettings: IGovernanceSettings(makeAddr("governanceSettings")),
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
        // Add TestKeyManagerHelperFacet to the diamond
        // =====================================================================

        TestKeyManagerHelperFacet helperImpl = new TestKeyManagerHelperFacet();
        bytes4[] memory helperSelectors = new bytes4[](6);
        helperSelectors[0] = ITestKeyManagerHelperFacet.setTeeMachineState.selector;
        helperSelectors[1] = ITestKeyManagerHelperFacet.setProjectState.selector;
        helperSelectors[2] = ITestKeyManagerHelperFacet.setWalletState.selector;
        helperSelectors[3] = ITestKeyManagerHelperFacet.setKeyState.selector;
        helperSelectors[4] = ITestKeyManagerHelperFacet.setKeyIds.selector;
        helperSelectors[5] = ITestKeyManagerHelperFacet.setMultisigThresholdDirect.selector;

        IDiamond.FacetCut[] memory cuts = new IDiamond.FacetCut[](1);
        cuts[0] = IDiamond.FacetCut(
            address(helperImpl),
            IDiamond.FacetCutAction.Add,
            helperSelectors
        );

        vm.prank(initialGovernance);
        IDiamondCut(address(flareTeeManager)).diamondCut(cuts, address(0), "");

        helper = ITestKeyManagerHelperFacet(address(flareTeeManager));

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

        // Set teeId as PRODUCTION TEE machine
        helper.setTeeMachineState(
            teeId,
            extensionId,
            teeMachineOwner,
            ITeeMachineRegistryFacet.TeeStatus.PRODUCTION,
            PublicKey(bytes32(0), bytes32(0)),
            1,
            "https://tee.url"
        );

        // Set newTeeId as PRODUCTION TEE machine
        helper.setTeeMachineState(
            newTeeId,
            extensionId,
            teeMachineOwner,
            ITeeMachineRegistryFacet.TeeStatus.PRODUCTION,
            PublicKey(bytes32(0), bytes32(0)),
            1,
            "https://newtee.url"
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

        // Set up wallet state (INITIALIZED, with admins and cosigners)
        PublicKey[] memory admins = new PublicKey[](1);
        admins[0] = adminsPublicKeys[0];
        helper.setWalletState(
            walletId,
            projectId,
            ITeeWalletManagerFacet.WalletStatus.INITIALIZED,
            admins,
            1,
            cosigners,
            1
        );

        // =====================================================================
        // Mock external contracts
        // =====================================================================

        vm.mockCall(
            flareSystemsManager,
            abi.encodeWithSelector(ProtocolsV2Interface.getCurrentRewardEpochId.selector),
            abi.encode(uint24(10))
        );

        vm.mockCall(
            rewardManager,
            abi.encodeWithSelector(IIRewardManager.receiveRewards.selector),
            abi.encode("")
        );

        vm.deal(owner, 1 ether);
    }

    // =========================================================================
    // setMultisigThreshold
    // =========================================================================

    function testSetMultisigThresholdRevertOnlyOwner() public {
        vm.expectRevert(ITeeCommonErrors.OnlyOwner.selector);
        flareTeeManager.setMultisigThreshold(walletId, 2);
    }

    function testSetMultisigThresholdRevertInvalidThreshold() public {
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.InvalidThreshold.selector);
        flareTeeManager.setMultisigThreshold(walletId, 0);
    }

    function testSetMultisigThresholdRevertInvalidWalletStatus() public {
        helper.setWalletState(
            walletId,
            projectId,
            ITeeWalletManagerFacet.WalletStatus.PRODUCTION,
            new PublicKey[](0),
            0,
            new address[](0),
            0
        );
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.InvalidWalletStatus.selector);
        flareTeeManager.setMultisigThreshold(walletId, 1);
    }

    function testSetMultisigThreshold() public {
        vm.prank(owner);
        vm.expectEmit();
        emit ITeeWalletKeyManagerFacet.WalletMultisigThresholdSet(walletId, 1);
        flareTeeManager.setMultisigThreshold(walletId, 1);
    }

    // =========================================================================
    // addKey
    // =========================================================================

    function testAddKeyRevertOnlyOwner() public {
        vm.expectRevert(ITeeCommonErrors.OnlyOwner.selector);
        flareTeeManager.addKey(teeId, walletId, address(0));
    }

    function testAddKeyRevertTeeMachineNotAvailable() public {
        helper.setTeeMachineState(
            teeId,
            extensionId,
            teeMachineOwner,
            ITeeMachineRegistryFacet.TeeStatus.PAUSED,
            PublicKey(bytes32(0), bytes32(0)),
            1,
            "https://tee.url"
        );
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.TeeMachineNotAvailable.selector);
        flareTeeManager.addKey(teeId, walletId, address(0));
    }

    function testAddKeyRevertInvalidWalletStatus() public {
        helper.setWalletState(
            walletId,
            projectId,
            ITeeWalletManagerFacet.WalletStatus.PRODUCTION,
            new PublicKey[](0),
            0,
            new address[](0),
            0
        );
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.InvalidWalletStatus.selector);
        flareTeeManager.addKey(teeId, walletId, address(0));
    }

    function testAddKeyRevertExtensionIdMismatch() public {
        // Set teeId to a different extensionId
        helper.setTeeMachineState(
            teeId,
            extensionId + 1,
            teeMachineOwner,
            ITeeMachineRegistryFacet.TeeStatus.PRODUCTION,
            PublicKey(bytes32(0), bytes32(0)),
            1,
            "https://tee.url"
        );
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.ExtensionIdMismatch.selector);
        flareTeeManager.addKey(teeId, walletId, address(0));
    }

    function testAddKey() public {
        vm.prank(owner);
        vm.expectEmit();
        emit ITeeWalletKeyManagerFacet.WalletKeyAdded(teeId, walletId, 0);
        uint64 returnedKeyId = flareTeeManager.addKey{value: 0}(teeId, walletId, address(0));
        assertEq(returnedKeyId, 0);

        // Verify key counter incremented
        (, , uint64 counter) = flareTeeManager.getWalletKeysInfo(walletId);
        assertEq(counter, 1);
    }

    function testAddKeyWithClaimBackAddress() public {
        address claimBack = makeAddr("claimBack");
        vm.prank(owner);
        vm.expectEmit();
        emit ITeeWalletKeyManagerFacet.WalletKeyAdded(teeId, walletId, 0);
        flareTeeManager.addKey{value: 0}(teeId, walletId, claimBack);
    }

    // =========================================================================
    // confirmKey
    // =========================================================================

    function testConfirmKeyRevertOnlyOwnerOrBackupManager() public {
        address nobody = makeAddr("nobody");
        vm.prank(nobody);
        vm.expectRevert(ITeeCommonErrors.OnlyOwnerOrBackupManager.selector);
        flareTeeManager.confirmKey(proof, teeSignature);
    }

    function testConfirmKeyRevertTeeMachineNotAvailable() public {
        helper.setTeeMachineState(
            teeId,
            extensionId,
            teeMachineOwner,
            ITeeMachineRegistryFacet.TeeStatus.REPLICATING,
            PublicKey(bytes32(0), bytes32(0)),
            1,
            "https://tee.url"
        );
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.TeeMachineNotAvailable.selector);
        flareTeeManager.confirmKey(proof, teeSignature);
    }

    function testConfirmKeyRevertInvalidKeyId() public {
        // keyIdCounter is 0 by default, so keyId 0 is invalid
        vm.prank(owner);
        vm.expectRevert(ITeeWalletKeyManagerFacet.InvalidKeyId.selector);
        flareTeeManager.confirmKey(proof, teeSignature);
    }

    function testConfirmKeyRevertInvalidNonce() public {
        _addKey();
        proof.nonce = 1;
        teeSignature = _createSignature(teePrivateKey);
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.InvalidNonce.selector);
        flareTeeManager.confirmKey(proof, teeSignature);
    }

    function testConfirmKeyRevertInvalidKeyType() public {
        _addKey();
        proof.keyType = keccak256("invalidKeyType");
        teeSignature = _createSignature(teePrivateKey);
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.InvalidKeyType.selector);
        flareTeeManager.confirmKey(proof, teeSignature);
    }

    function testConfirmKeyRevertInvalidSigningAlgo() public {
        _addKey();
        proof.signingAlgo = keccak256("invalidSigningAlgo");
        teeSignature = _createSignature(teePrivateKey);
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.InvalidSigningAlgo.selector);
        flareTeeManager.confirmKey(proof, teeSignature);
    }

    function testConfirmKeyRevertInvalidSettings() public {
        _addKey();
        proof.settings = bytes("invalidSettings");
        teeSignature = _createSignature(teePrivateKey);
        vm.prank(owner);
        vm.expectRevert(ITeeWalletKeyManagerFacet.InvalidSettings.selector);
        flareTeeManager.confirmKey(proof, teeSignature);
    }

    function testConfirmKeyRevertInvalidSettings2() public {
        _addKey();
        proof.settingsVersion = bytes32("invalidVersion");
        teeSignature = _createSignature(teePrivateKey);
        vm.prank(owner);
        vm.expectRevert(ITeeWalletKeyManagerFacet.InvalidSettings.selector);
        flareTeeManager.confirmKey(proof, teeSignature);
    }

    function testConfirmKeyRevertLengthsMismatchAdminsPublicKeys() public {
        _addKey();
        proof.configConstants.adminsPublicKeys.push();
        teeSignature = _createSignature(teePrivateKey);
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.LengthsMismatch.selector);
        flareTeeManager.confirmKey(proof, teeSignature);
    }

    function testConfirmKeyRevertInvalidThresholdAdmins() public {
        _addKey();
        proof.configConstants.adminsThreshold = 2;
        teeSignature = _createSignature(teePrivateKey);
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.InvalidThreshold.selector);
        flareTeeManager.confirmKey(proof, teeSignature);
    }

    function testConfirmKeyRevertInvalidPublicKeyAdmins() public {
        _addKey();
        proof.configConstants.adminsPublicKeys[0].x = keccak256("invalidX");
        teeSignature = _createSignature(teePrivateKey);
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.InvalidPublicKey.selector);
        flareTeeManager.confirmKey(proof, teeSignature);
    }

    function testConfirmKeyRevertLengthsMismatchCosigners() public {
        _addKey();
        proof.configConstants.cosigners.pop();
        teeSignature = _createSignature(teePrivateKey);
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.LengthsMismatch.selector);
        flareTeeManager.confirmKey(proof, teeSignature);
    }

    function testConfirmKeyRevertInvalidThresholdCosigners() public {
        _addKey();
        proof.configConstants.cosignersThreshold = 2;
        teeSignature = _createSignature(teePrivateKey);
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.InvalidThreshold.selector);
        flareTeeManager.confirmKey(proof, teeSignature);
    }

    function testConfirmKeyRevertInvalidAddressCosigners() public {
        _addKey();
        proof.configConstants.cosigners[0] = makeAddr("invalidCosigner");
        teeSignature = _createSignature(teePrivateKey);
        vm.prank(owner);
        vm.expectRevert(ITeeWalletKeyManagerFacet.InvalidAddress.selector);
        flareTeeManager.confirmKey(proof, teeSignature);
    }

    function testConfirmKeyRevertInvalidTeeSignature() public {
        _addKey();
        // Register an invalidTeeId as PRODUCTION so checkTeeMachineInProduction passes
        address invalidTeeId = makeAddr("invalidTeeId");
        helper.setTeeMachineState(
            invalidTeeId,
            extensionId,
            teeMachineOwner,
            ITeeMachineRegistryFacet.TeeStatus.PRODUCTION,
            PublicKey(bytes32(0), bytes32(0)),
            1,
            "https://invalid.url"
        );
        proof.teeId = invalidTeeId;
        teeSignature = _createSignature(teePrivateKey);
        vm.prank(owner);
        vm.expectRevert(ITeeWalletKeyManagerFacet.InvalidTeeSignature.selector);
        flareTeeManager.confirmKey(proof, teeSignature);
    }

    function testConfirmKeyRevertInvalidPublicKeyNotInWallet() public {
        _addKey();
        proof.publicKey = new bytes(0);
        teeSignature = _createSignature(teePrivateKey);
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.InvalidPublicKey.selector);
        flareTeeManager.confirmKey(proof, teeSignature);
    }

    function testConfirmKeyRevertInvalidWalletStatus() public {
        _addKey();
        // Change wallet status to PRODUCTION while keeping admins/cosigners intact
        PublicKey[] memory admins = new PublicKey[](1);
        admins[0] = adminsPublicKeys[0];
        helper.setWalletState(
            walletId,
            projectId,
            ITeeWalletManagerFacet.WalletStatus.PRODUCTION,
            admins,
            1,
            cosigners,
            1
        );
        // Need to re-sign since proof is unchanged
        proof.restored = false;
        teeSignature = _createSignature(teePrivateKey);
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.InvalidWalletStatus.selector);
        flareTeeManager.confirmKey(proof, teeSignature);
    }

    function testConfirmKeyRevertOnlyOwner() public {
        _addKey();
        // backupManager can call confirmKey via onlyOwnerOrBackupManager,
        // but for first confirm (nonce==0) _checkOnlyOwner is also called
        vm.prank(backupManager);
        vm.expectRevert(ITeeCommonErrors.OnlyOwner.selector);
        flareTeeManager.confirmKey(proof, teeSignature);
    }

    // nonce == 0, restored == true
    function testConfirmKeyRevertKeyNotGeneratedOnTeeMachine() public {
        _addKey();
        // proof.restored is already true from setUp
        teeSignature = _createSignature(teePrivateKey);
        vm.prank(owner);
        vm.expectRevert(ITeeWalletKeyManagerFacet.KeyNotGeneratedOnTeeMachine.selector);
        flareTeeManager.confirmKey(proof, teeSignature);
    }

    function testConfirmKeyNotInWallet() public {
        _addKey();
        proof.restored = false;
        teeSignature = _createSignature(teePrivateKey);
        vm.prank(owner);
        vm.expectEmit();
        emit ITeeWalletKeyManagerFacet.WalletKeyConfirmed(
            teeId,
            walletId,
            proof.keyId,
            proof.publicKey
        );
        flareTeeManager.confirmKey(proof, teeSignature);

        // Verify key data
        bytes memory pk = flareTeeManager.getWalletKeyPublicKey(walletId, keyId);
        assertEq(pk, proof.publicKey);
        address[] memory teeIds = flareTeeManager.getWalletKeyTeeIds(walletId, keyId);
        assertEq(teeIds.length, 1);
        assertEq(teeIds[0], teeId);
    }

    // nonce == 0 after confirmKeyNotInWallet (key already in wallet, nonce is still 0)
    function testConfirmKeyRevertKeyNotRestoredOnTeeMachine1() public {
        testConfirmKeyNotInWallet();
        teeSignature = _createSignature(teePrivateKey);
        vm.prank(owner);
        vm.expectRevert(ITeeWalletKeyManagerFacet.KeyNotRestoredOnTeeMachine.selector);
        flareTeeManager.confirmKey(proof, teeSignature);
    }

    // nonce > 0, restored == false
    function testConfirmKeyRevertKeyNotRestoredOnTeeMachine2() public {
        testConfirmKeyNotInWallet();
        proof.nonce = 1;
        proof.restored = false;
        teeSignature = _createSignature(teePrivateKey);
        vm.prank(owner);
        // nonce mismatch since we didn't actually increase nonce
        vm.expectRevert(ITeeCommonErrors.InvalidNonce.selector);
        flareTeeManager.confirmKey(proof, teeSignature);
    }

    function testConfirmKeyRevertInvalidPublicKeyInWallet() public {
        _setupConfirmKeyInWallet();
        proof.publicKey = abi.encode("invalidPublicKey");
        teeSignature = _createSignature(teePrivateKey);
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.InvalidPublicKey.selector);
        flareTeeManager.confirmKey(proof, teeSignature);
    }

    function testConfirmKeyRevertTeeIdAlreadyAdded() public {
        // First confirm key (adds teeId to the key's teeIds)
        _setupConfirmKeyInWallet();
        // Now teeId was removed by deleteKey, re-confirm to add it back
        teeSignature = _createSignature(teePrivateKey);
        vm.prank(owner);
        flareTeeManager.confirmKey(proof, teeSignature);
        // teeId is now in the key's teeIds again. Delete to get nonce=2, then try to add again
        vm.prank(owner);
        flareTeeManager.deleteKey{value: 0}(teeId, walletId, keyId, address(0));
        // nonces[teeId] = 2 now, but teeId was also re-added by confirmKey above and then removed by deleteKey
        // Actually we need teeId to be present in teeIds AND try to re-add it.
        // Let's re-confirm again, then try to confirm a third time without deleting
        proof.nonce = 2;
        teeSignature = _createSignature(teePrivateKey);
        vm.prank(owner);
        flareTeeManager.confirmKey(proof, teeSignature);
        // Now teeId IS in teeIds. Delete to increase nonce but... deleteKey removes teeId.
        // The trick: we need to deleteKey on a DIFFERENT teeId to not remove our teeId.
        // Use newTeeId: deleteKey(newTeeId, walletId, keyId) => nonces[newTeeId]++
        // But we want nonces[teeId] to increase. Let's use a different approach:
        // We can add newTeeId to the key, then try to add teeId again (which is already there).
        vm.prank(owner);
        flareTeeManager.deleteKey{value: 0}(newTeeId, walletId, keyId, address(0));
        // nonces[newTeeId] = 1
        proof.teeId = newTeeId;
        proof.nonce = 1;
        proof.restored = true;
        teeSignature = _createSignature(newTeePrivateKey);
        vm.prank(owner);
        flareTeeManager.confirmKey(proof, teeSignature);
        // Now both teeId and newTeeId are in teeIds.
        // Try to add teeId again (it's already there)
        vm.prank(owner);
        flareTeeManager.deleteKey{value: 0}(teeId, walletId, keyId, address(0));
        // nonces[teeId] = 3, teeId removed from teeIds
        // Re-add teeId
        proof.teeId = teeId;
        proof.nonce = 3;
        teeSignature = _createSignature(teePrivateKey);
        vm.prank(owner);
        flareTeeManager.confirmKey(proof, teeSignature);
        // teeId is back in teeIds along with newTeeId
        // Now try to add teeId again without deleting
        // Need nonces[teeId] = 3 still, but we just confirmed at nonce 3, so next would need nonce 4
        // but actual nonce in storage is 3. So try with nonce 3 again... that should fail with
        // TeeIdAlreadyAdded before the nonce check matters
        // Actually nonce check happens BEFORE the duplicate check. Let me re-read the code.
        // Looking at confirmKey: nonce check comes first, then if publicKey.length > 0,
        // it checks nonce > 0 && restored, then checks for duplicate teeId.
        // So we need a valid nonce. After the last confirmKey, nonces[teeId] is still 3
        // (confirmKey doesn't change nonces). So proof.nonce = 3 should work.
        proof.nonce = 3;
        teeSignature = _createSignature(teePrivateKey);
        vm.prank(owner);
        vm.expectRevert(ITeeWalletKeyManagerFacet.TeeIdAlreadyAdded.selector);
        flareTeeManager.confirmKey(proof, teeSignature);
    }

    function testConfirmKeyInWallet() public {
        _setupConfirmKeyInWallet();
        // After _setupConfirmKeyInWallet: key confirmed for teeId, then deleteKey removed teeId
        // and increased nonces[teeId] to 1. proof.nonce = 1, proof.restored = true.

        // Re-confirm teeId (restore it back into the key)
        teeSignature = _createSignature(teePrivateKey);
        vm.prank(owner);
        vm.expectEmit();
        emit ITeeWalletKeyManagerFacet.WalletKeyConfirmed(
            teeId,
            walletId,
            keyId,
            proof.publicKey
        );
        flareTeeManager.confirmKey(proof, teeSignature);

        // Verify teeId was re-added
        address[] memory teeIds = flareTeeManager.getWalletKeyTeeIds(walletId, keyId);
        assertEq(teeIds.length, 1);
        assertEq(teeIds[0], teeId);

        // Now add newTeeId: deleteKey to increase its nonce, then confirmKey
        vm.prank(owner);
        flareTeeManager.deleteKey{value: 0}(newTeeId, walletId, keyId, address(0));
        // nonces[newTeeId] = 1 (newTeeId wasn't in teeIds, but deleteKey still increments nonce)

        proof.teeId = newTeeId;
        proof.nonce = 1;
        proof.restored = true;
        teeSignature = _createSignature(newTeePrivateKey);
        vm.prank(owner);
        vm.expectEmit();
        emit ITeeWalletKeyManagerFacet.WalletKeyConfirmed(
            newTeeId,
            walletId,
            keyId,
            proof.publicKey
        );
        flareTeeManager.confirmKey(proof, teeSignature);

        // Verify both teeIds are now in the key
        teeIds = flareTeeManager.getWalletKeyTeeIds(walletId, keyId);
        assertEq(teeIds.length, 2);
        assertEq(teeIds[0], teeId);
        assertEq(teeIds[1], newTeeId);
    }

    // =========================================================================
    // deleteKey
    // =========================================================================

    function testDeleteKeyRevertOnlyOwner() public {
        vm.expectRevert(ITeeCommonErrors.OnlyOwner.selector);
        flareTeeManager.deleteKey(teeId, walletId, keyId, address(0));
    }

    function testDeleteKeyRevertTeeMachineNotAvailable() public {
        helper.setTeeMachineState(
            teeId,
            extensionId,
            teeMachineOwner,
            ITeeMachineRegistryFacet.TeeStatus.INITIALIZED,
            PublicKey(bytes32(0), bytes32(0)),
            1,
            "https://tee.url"
        );
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.TeeMachineNotAvailable.selector);
        flareTeeManager.deleteKey(teeId, walletId, keyId, address(0));
    }

    function testDeleteKeyRevertExtensionIdMismatch() public {
        helper.setTeeMachineState(
            teeId,
            extensionId + 1,
            teeMachineOwner,
            ITeeMachineRegistryFacet.TeeStatus.PRODUCTION,
            PublicKey(bytes32(0), bytes32(0)),
            1,
            "https://tee.url"
        );
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.ExtensionIdMismatch.selector);
        flareTeeManager.deleteKey(teeId, walletId, keyId, address(0));
    }

    function testDeleteKeyRevertInvalidKeyId() public {
        testConfirmKeyNotInWallet();
        // non-existent keyId
        vm.prank(owner);
        vm.expectRevert(ITeeWalletKeyManagerFacet.InvalidKeyId.selector);
        flareTeeManager.deleteKey(teeId, walletId, keyId + 1, address(0));
    }

    function testDeleteKeyRevertOnlyOwnerInvalidWalletId() public {
        testConfirmKeyNotInWallet();
        // invalid walletId has no project => OnlyOwner check fails
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.OnlyOwner.selector);
        flareTeeManager.deleteKey(teeId, keccak256("invalidWalletId"), keyId, address(0));
    }

    function testDeleteKey() public {
        // Set up: confirm key for teeId, then add and confirm for newTeeId
        testConfirmKeyNotInWallet();

        // Add key for newTeeId (this doesn't create a new keyId, it adds to the same wallet)
        vm.prank(owner);
        flareTeeManager.addKey{value: 0}(newTeeId, walletId, address(0));

        // Delete key for newTeeId to get nonce, then confirm to add newTeeId
        vm.prank(owner);
        flareTeeManager.deleteKey{value: 0}(newTeeId, walletId, keyId, address(0));

        proof.teeId = newTeeId;
        proof.nonce = 1;
        proof.restored = true;
        teeSignature = _createSignature(newTeePrivateKey);
        vm.prank(owner);
        flareTeeManager.confirmKey(proof, teeSignature);

        address[] memory teeIds = flareTeeManager.getWalletKeyTeeIds(walletId, keyId);
        assertEq(teeIds.length, 2);

        // Now delete teeId from the key
        vm.prank(owner);
        vm.expectEmit();
        emit ITeeWalletKeyManagerFacet.WalletKeyDeleted(teeId, walletId, keyId);
        flareTeeManager.deleteKey{value: 0}(teeId, walletId, keyId, address(0));

        // teeId should be removed
        teeIds = flareTeeManager.getWalletKeyTeeIds(walletId, keyId);
        assertEq(teeIds.length, 1);
        assertEq(teeIds[0], newTeeId);
    }

    function testDeleteKeyWithClaimBackAddress() public {
        testConfirmKeyNotInWallet();
        address claimBack = makeAddr("claimBack");
        vm.prank(owner);
        vm.expectEmit();
        emit ITeeWalletKeyManagerFacet.WalletKeyDeleted(teeId, walletId, keyId);
        flareTeeManager.deleteKey{value: 0}(teeId, walletId, keyId, claimBack);
    }

    // =========================================================================
    // cleanUpTeeIds
    // =========================================================================

    function testCleanUpTeeIdsRevertOnlyOwnerOrBackupManager() public {
        address nobody = makeAddr("nobody");
        vm.prank(nobody);
        vm.expectRevert(ITeeCommonErrors.OnlyOwnerOrBackupManager.selector);
        flareTeeManager.cleanUpTeeIds(walletId, keyId);
    }

    function testCleanUpTeeIdsRevertInvalidKeyId() public {
        testConfirmKeyNotInWallet();
        // non-existent keyId
        vm.prank(owner);
        vm.expectRevert(ITeeWalletKeyManagerFacet.InvalidKeyId.selector);
        flareTeeManager.cleanUpTeeIds(walletId, keyId + 1);
    }

    function testCleanUpTeeIdsRevertOnlyOwnerOrBackupManagerInvalidWalletId() public {
        testConfirmKeyNotInWallet();
        // invalid walletId has no project => OnlyOwnerOrBackupManager check fails
        vm.prank(owner);
        vm.expectRevert(ITeeCommonErrors.OnlyOwnerOrBackupManager.selector);
        flareTeeManager.cleanUpTeeIds(keccak256("invalidWalletId"), keyId);
    }

    function testCleanUpTeeIds() public {
        testConfirmKeyNotInWallet();
        // Set teeId to non-PRODUCTION
        helper.setTeeMachineState(
            teeId,
            extensionId,
            teeMachineOwner,
            ITeeMachineRegistryFacet.TeeStatus.REPLICATING,
            PublicKey(bytes32(0), bytes32(0)),
            1,
            "https://tee.url"
        );
        vm.prank(owner);
        vm.expectEmit();
        emit ITeeWalletKeyManagerFacet.WalletKeyDeleted(teeId, walletId, keyId);
        flareTeeManager.cleanUpTeeIds(walletId, keyId);

        // teeId should be removed
        address[] memory teeIds = flareTeeManager.getWalletKeyTeeIds(walletId, keyId);
        assertEq(teeIds.length, 0);
    }

    // =========================================================================
    // receivingTeesAndKeys
    // =========================================================================

    function testReceivingTeesAndKeysRevertThresholdNotMet() public {
        testConfirmKeyNotInWallet();
        vm.prank(owner);
        flareTeeManager.setMultisigThreshold(walletId, 2);
        vm.expectRevert(ITeeWalletKeyManagerFacet.ThresholdNotMet.selector);
        flareTeeManager.receivingTeesAndKeys(walletId);
    }

    function testReceivingTeesAndKeys() public {
        testConfirmKeyNotInWallet();
        TeeIdKeyIdPair[] memory pairs = flareTeeManager.receivingTeesAndKeys(walletId);
        assertEq(pairs.length, 1);
        assertEq(pairs[0].teeId, teeId);
        assertEq(pairs[0].keyId, keyId);

        // Set teeId to PAUSED - key should become unavailable
        helper.setTeeMachineState(
            teeId,
            extensionId,
            teeMachineOwner,
            ITeeMachineRegistryFacet.TeeStatus.PAUSED,
            PublicKey(bytes32(0), bytes32(0)),
            1,
            "https://tee.url"
        );
        uint64[] memory keyIds = new uint64[](1);
        keyIds[0] = keyId;
        vm.expectEmit();
        emit ITeeWalletKeyManagerFacet.WalletKeysNotAvailable(walletId, keyIds);
        pairs = flareTeeManager.receivingTeesAndKeys(walletId);
        assertEq(pairs.length, 0);
    }

    // =========================================================================
    // getWalletKeysInfo
    // =========================================================================

    function testGetWalletKeysInfo() public {
        (uint64 multisigThreshold, uint64[] memory keyIds, uint64 counter)
            = flareTeeManager.getWalletKeysInfo(walletId);
        assertEq(multisigThreshold, 0);
        assertEq(keyIds.length, 0);
        assertEq(counter, 0);

        testConfirmKeyNotInWallet();
        (multisigThreshold, keyIds, counter) = flareTeeManager.getWalletKeysInfo(walletId);
        assertEq(multisigThreshold, 0);
        assertEq(keyIds.length, 1);
        assertEq(keyIds[0], keyId);
        assertEq(counter, 1);
    }

    // =========================================================================
    // getWalletKeyPublicKey
    // =========================================================================

    function testGetWalletKeyPublicKey() public {
        bytes memory pk = flareTeeManager.getWalletKeyPublicKey(walletId, keyId);
        assertEq(pk, "");

        testConfirmKeyNotInWallet();
        pk = flareTeeManager.getWalletKeyPublicKey(walletId, keyId);
        assertEq(pk, proof.publicKey);
    }

    // =========================================================================
    // getWalletKeyTeeIds
    // =========================================================================

    function testGetWalletKeyTeeIds() public {
        address[] memory teeIds = flareTeeManager.getWalletKeyTeeIds(walletId, keyId);
        assertEq(teeIds.length, 0);

        testConfirmKeyNotInWallet();
        teeIds = flareTeeManager.getWalletKeyTeeIds(walletId, keyId);
        assertEq(teeIds.length, 1);
        assertEq(teeIds[0], teeId);
    }

    // =========================================================================
    // Private helpers
    // =========================================================================

    function _addKey() private {
        vm.prank(owner);
        flareTeeManager.addKey{value: 0}(teeId, walletId, address(0));
    }

    function _setupConfirmKeyInWallet() private {
        // First confirm key (not in wallet)
        testConfirmKeyNotInWallet();
        // Now key is in wallet. To confirm again on the same teeId,
        // we need nonce > 0 and restored == true.
        // Use deleteKey to increment the nonce for teeId
        vm.prank(owner);
        flareTeeManager.deleteKey{value: 0}(teeId, walletId, keyId, address(0));
        // After deleteKey, nonces[teeId] = 1 and teeId is removed from teeIds
        proof.nonce = 1;
        proof.restored = true;
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
