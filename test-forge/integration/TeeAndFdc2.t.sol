// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { FlareTeeManagerDeployer } from "../utils/FlareTeeManagerDeployer.sol";
import { IIFlareTeeManager } from "../../contracts/tee/interface/IIFlareTeeManager.sol";
import { IDiamondLoupe } from "../../contracts/diamond/interfaces/IDiamondLoupe.sol";
import { IMachineManager } from "../../contracts/userInterfaces/tee/IMachineManager.sol";
import { TEE_SOURCE_ID } from "../../contracts/userInterfaces/tee/IVerification.sol";
import { IExtensionGovernance } from "../../contracts/userInterfaces/tee/IExtensionGovernance.sol";
import { ITeeExtensionStateVerifier } from "../../contracts/userInterfaces/tee/ITeeExtensionStateVerifier.sol";
import { ISystemStateVerifier } from "../../contracts/userInterfaces/tee/ISystemStateVerifier.sol";
import { IWalletManager } from "../../contracts/userInterfaces/tee/IWalletManager.sol";
import { IWalletKeyManager } from "../../contracts/userInterfaces/tee/IWalletKeyManager.sol";
import { IWalletBackupManager } from "../../contracts/userInterfaces/tee/IWalletBackupManager.sol";
import { ITeeAvailabilityCheck, TEE_AVAILABILITY_CHECK_ATTESTATION_TYPE }
    from "../../contracts/userInterfaces/fdc2/ITeeAvailabilityCheck.sol";
import { IFdc2Hub } from "../../contracts/userInterfaces/fdc2/IFdc2Hub.sol";
import { IFdc2Verification } from "../../contracts/userInterfaces/fdc2/IFdc2Verification.sol";
import { IRelay } from "../../contracts/userInterfaces/IRelay.sol";
import { Fdc2Hub } from "../../contracts/fdc2/implementation/Fdc2Hub.sol";
import { Fdc2HubProxy } from "../../contracts/fdc2/proxy/Fdc2HubProxy.sol";
import { Fdc2Verification } from "../../contracts/fdc2/implementation/Fdc2Verification.sol";
import { Fdc2VerificationProxy } from "../../contracts/fdc2/proxy/Fdc2VerificationProxy.sol";
import {
    Fdc2RequestFeeConfigurations
} from "../../contracts/fdc2/implementation/Fdc2RequestFeeConfigurations.sol";
import {
    Fdc2RequestFeeConfigurationsProxy
} from "../../contracts/fdc2/proxy/Fdc2RequestFeeConfigurationsProxy.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import { PublicKey } from "../../contracts/userInterfaces/IPublicKey.sol";
import { Signature } from "../../contracts/userInterfaces/ISignature.sol";
import { PublicKeyHelper } from "../utils/PublicKeyHelper.sol";
import { SignatureHelper } from "../utils/SignatureHelper.sol";
import { ProtocolsV2Interface } from "../../contracts/userInterfaces/LTS/ProtocolsV2Interface.sol";
import { RandomNumberV2Interface } from "../../contracts/userInterfaces/LTS/RandomNumberV2Interface.sol";
import { IIRewardManager } from "../../contracts/protocol/interface/IIRewardManager.sol";

/**
 * @title TeeAndFdc2Test
 * @notice End-to-end integration test for the TEE day-1 diamond (16 facets, no later facets)
 *         together with the FDC2 contracts (Fdc2Hub, Fdc2Verification, Fdc2RequestFeeConfigurations).
 *         Only truly external infrastructure is mocked: Relay, FlareSystemsManager, RewardManager.
 */
// solhint-disable func-name-mixedcase
// solhint-disable-next-line max-states-count
contract TeeAndFdc2Test is Test {

    struct Signer {
        address addr;
        uint256 privateKey;
    }

    IIFlareTeeManager private flareTeeManager;
    Fdc2Hub private fdc2Hub;
    Fdc2Verification private fdc2Verification;
    Fdc2RequestFeeConfigurations private fdc2RequestFeeConfigurations;

    address private initialGovernance;
    address private addressUpdater;
    address private extensionOwner;
    address private instructionsSender;
    address private projectOwner;
    address private teeOwner;

    address private flareSystemsManager;
    address private rewardManager;
    address private relay;

    uint256 private extensionId;
    bytes32 private keyType;
    bytes32 private signingAlgo;
    bytes32 private codeHash;
    bytes32 private platform;
    uint256 private randomNumber;

    uint256 private teePrivateKey;
    PublicKey private teePublicKey;
    address private teeId;
    address private teeProxyId;
    string private teeUrl;

    Signer[] private cosigners;
    uint64 private cosignersThreshold;

    mapping(address => uint256) private registerTimestamps;

    function setUp() public {
        initialGovernance = makeAddr("initialGovernance");
        addressUpdater = makeAddr("AddressUpdater");
        extensionOwner = makeAddr("extensionOwner");
        instructionsSender = makeAddr("instructionsSender");
        projectOwner = makeAddr("projectOwner");
        teeOwner = makeAddr("teeOwner");

        flareSystemsManager = makeAddr("FlareSystemsManager");
        rewardManager = makeAddr("RewardManager");
        relay = makeAddr("Relay");

        codeHash = keccak256("codeHash");
        platform = keccak256("SGX");
        keyType = keccak256(abi.encode("keyType1"));
        signingAlgo = keccak256(abi.encode("signingAlgo1"));
        randomNumber = 12345;

        teePrivateKey = PublicKeyHelper.getRandomPrivateKey(vm);
        teePublicKey = PublicKeyHelper.getPublicKey(vm, teePrivateKey);
        teeId = PublicKeyHelper.getAddress(teePublicKey);
        teeProxyId = makeAddr("teeProxy");
        teeUrl = "https://tee.example.com";

        cosigners.push();
        (cosigners[0].addr, cosigners[0].privateKey) = makeAddrAndKey("cosigner1");
        cosignersThreshold = 1;

        // =====================================================================
        // Deploy day-1 only TEE diamond
        // =====================================================================

        flareTeeManager = FlareTeeManagerDeployer.deployDay1Facets(
            FlareTeeManagerDeployer.Day1DeployParams({
                governanceSettings: IGovernanceSettings(address(this)),
                initialGovernance: initialGovernance,
                addressUpdater: addressUpdater,
                availabilityCheckValidityDurationSeconds: 3600,
                signingPolicyValidityDurationInRewardEpochs: 6,
                challengeValidityDurationSeconds: 600,
                defaultFee: 1000
            })
        );

        // =====================================================================
        // Deploy real FDC2 contracts
        // =====================================================================

        Fdc2Verification fdc2VerImpl = new Fdc2Verification();
        Fdc2VerificationProxy fdc2VerProxy = new Fdc2VerificationProxy(
            IGovernanceSettings(address(this)), initialGovernance, addressUpdater, address(fdc2VerImpl)
        );
        fdc2Verification = Fdc2Verification(address(fdc2VerProxy));

        Fdc2Hub fdc2HubImpl = new Fdc2Hub();
        Fdc2HubProxy fdc2HubProxy = new Fdc2HubProxy(
            IGovernanceSettings(address(this)), initialGovernance, addressUpdater,
            5000, 1, address(fdc2HubImpl)
        );
        fdc2Hub = Fdc2Hub(address(fdc2HubProxy));

        Fdc2RequestFeeConfigurations fdc2FeeImpl = new Fdc2RequestFeeConfigurations();
        Fdc2RequestFeeConfigurationsProxy fdc2FeeProxy = new Fdc2RequestFeeConfigurationsProxy(
            IGovernanceSettings(address(this)), initialGovernance, address(fdc2FeeImpl)
        );
        fdc2RequestFeeConfigurations = Fdc2RequestFeeConfigurations(address(fdc2FeeProxy));

        // =====================================================================
        // Wire everything together
        // =====================================================================

        _updateTeeManagerAddresses();
        _updateFdc2HubAddresses();
        _updateFdc2VerificationAddresses();

        // =====================================================================
        // Mock only external infrastructure
        // =====================================================================

        _mockExternalInfra();

        // Set cosigners on the diamond
        vm.prank(initialGovernance);
        flareTeeManager.setCosigners(_cosignerAddresses(), cosignersThreshold);

        vm.warp(block.timestamp + 1000);
    }

    // // IGovernanceSettings mock — test contract acts as governance settings
    // function getGovernanceAddress() external view returns (address) { return initialGovernance; }
    // function getTimelock() external pure returns (uint256) { return 0; }
    // function getExecutors() external pure returns (address[] memory) { return new address[](0); }
    // function isExecutor(address) external pure returns (bool) { return false; }

    // =========================================================================
    // A. Diamond Introspection + Excluded Selectors
    // =========================================================================

    function testDay1_facetCount() public view {
        assertEq(IDiamondLoupe(address(flareTeeManager)).facets().length, 15);
    }

    function testDay1_excludedSelectorsRevert() public {
        vm.expectRevert(
            abi.encodeWithSignature("FunctionNotFound(bytes4)", IExtensionGovernance.setNewTeeGovernance.selector)
        );
        address(flareTeeManager).call(
            abi.encodeWithSelector(IExtensionGovernance.setNewTeeGovernance.selector, 0, new address[](0), 0)
        );
    }

    // =========================================================================
    // B. Extension + Machine Registration + toProduction (full e2e)
    // =========================================================================

    function testDay1_registerAndToProduction() public {
        _setupExtension();
        _registerTeeMachine();
        assertEq(
            uint256(flareTeeManager.getTeeMachineStatus(teeId)),
            uint256(IMachineManager.TeeStatus.INITIALIZED)
        );

        _toProduction(teeId, teeProxyId, teeUrl);
        assertEq(
            uint256(flareTeeManager.getTeeMachineStatus(teeId)),
            uint256(IMachineManager.TeeStatus.PRODUCTION)
        );
    }

    // =========================================================================
    // C. Wallet Lifecycle (full e2e: project → wallet → admins → close)
    // =========================================================================

    function testDay1_walletLifecycle() public {
        _setupExtension();

        bytes32 projId = _createProject();
        assertEq(flareTeeManager.getOwner(projId), projectOwner);

        vm.prank(projectOwner);
        flareTeeManager.createWallet(projId);
        bytes32 walletId = keccak256(abi.encode("WALLET", projectOwner, 1));

        PublicKey[] memory admins = new PublicKey[](1);
        admins[0] = PublicKeyHelper.getRandomPublicKey(vm);
        vm.prank(projectOwner);
        flareTeeManager.setAdmins(walletId, admins, 1);
        vm.prank(PublicKeyHelper.getAddress(admins[0]));
        flareTeeManager.confirmAdmin(walletId);

        vm.prank(projectOwner);
        flareTeeManager.closeWalletInitialization(walletId);
        assertEq(
            uint256(flareTeeManager.getWalletStatus(walletId)),
            uint256(IWalletManager.WalletStatus.INITIALIZED)
        );
    }

    // =========================================================================
    // D. Add Key + Confirm Key (full e2e with TEE signature)
    // =========================================================================

    function testDay1_addAndConfirmKey() public {
        _setupExtension();
        _registerTeeMachine();
        _toProduction(teeId, teeProxyId, teeUrl);

        bytes32 projId = _createProject();
        bytes32 walletId = _createAndInitializeWallet(projId);

        vm.deal(projectOwner, 1 ether);
        vm.prank(projectOwner);
        uint64 keyIdVal = flareTeeManager.addKey{value: 1000}(teeId, walletId, address(0));

        _confirmKey(walletId, keyIdVal, teeId, teePrivateKey);

        bytes memory pk = flareTeeManager.getWalletKeyPublicKey(walletId, keyIdVal);
        assertTrue(pk.length > 0);
    }

    // =========================================================================
    // E. Backup Restore (full e2e)
    // =========================================================================

    function testDay1_backupRestore() public {
        _setupExtension();
        _registerTeeMachine();
        _toProduction(teeId, teeProxyId, teeUrl);

        address backupManager = makeAddr("backupManager");
        bytes32 projId = _createProjectWithBackupManager(backupManager);
        bytes32 walletId = _createAndInitializeWallet(projId);

        vm.deal(projectOwner, 1 ether);
        vm.prank(projectOwner);
        uint64 keyIdVal = flareTeeManager.addKey{value: 1000}(teeId, walletId, address(0));
        _confirmKey(walletId, keyIdVal, teeId, teePrivateKey);

        vm.prank(projectOwner);
        flareTeeManager.setMultisigThreshold(walletId, 1);
        vm.prank(projectOwner);
        flareTeeManager.enableWallet(walletId);

        // Register a second TEE for restore target
        uint256 restorePrivKey = PublicKeyHelper.getRandomPrivateKey(vm);
        PublicKey memory restorePubKey = PublicKeyHelper.getPublicKey(vm, restorePrivKey);
        address restoreTeeId = PublicKeyHelper.getAddress(restorePubKey);
        address restoreProxy = makeAddr("restoreProxy");
        string memory restoreUrl = "https://restore.tee.url";
        _registerTeeMachineWith(restorePrivKey, restorePubKey, restoreProxy, restoreUrl);
        _toProduction(restoreTeeId, restoreProxy, restoreUrl);

        IWalletBackupManager.BackupId memory backupIdStruct = IWalletBackupManager.BackupId(
            teeId, walletId, keyIdVal, keyType, signingAlgo,
            bytes("generatedPubKey"), 1, bytes32("randomNonce")
        );

        vm.deal(projectOwner, 1 ether);
        vm.prank(projectOwner);
        flareTeeManager.backupRestore{value: 1000}(restoreTeeId, backupIdStruct, "backupUrl", address(0));

        // Verify key is still held only by original TEE before restore confirmation
        address[] memory teeIdsBefore = flareTeeManager.getWalletKeyTeeIds(walletId, keyIdVal);
        assertEq(teeIdsBefore.length, 1);
        assertEq(teeIdsBefore[0], teeId);

        // Confirm the restored key on the new TEE machine (nonce was incremented to 1 by backupRestore)
        _confirmRestoredKey(walletId, keyIdVal, restoreTeeId, restorePrivKey);

        // Verify the key is now held by both the original and the restore TEE
        address[] memory teeIdsAfter = flareTeeManager.getWalletKeyTeeIds(walletId, keyIdVal);
        assertEq(teeIdsAfter.length, 2);
        assertEq(teeIdsAfter[0], teeId);
        assertEq(teeIdsAfter[1], restoreTeeId);
    }

    // =========================================================================
    // F. VRF (full e2e)
    // =========================================================================

    function testDay1_requestVrf() public {
        _setupExtension();
        _registerTeeMachine();
        _toProduction(teeId, teeProxyId, teeUrl);

        bytes32 projId = _createProject();
        bytes32 walletId = _createAndInitializeWallet(projId);

        vm.deal(projectOwner, 1 ether);
        vm.prank(projectOwner);
        uint64 keyIdVal = flareTeeManager.addKey{value: 1000}(teeId, walletId, address(0));
        _confirmKey(walletId, keyIdVal, teeId, teePrivateKey);

        vm.prank(projectOwner);
        flareTeeManager.setMultisigThreshold(walletId, 1);
        vm.prank(projectOwner);
        flareTeeManager.enableWallet(walletId);

        address authAddress = makeAddr("authAddress");
        vm.prank(projectOwner);
        flareTeeManager.setVrfAuthorizationAddress(walletId, authAddress);

        vm.deal(authAddress, 1 ether);
        vm.prank(authAddress);
        bytes32 returnedId = flareTeeManager.requestVrf{value: 1000}(
            walletId, keyIdVal, bytes("test-nonce"), address(0)
        );
        assertTrue(returnedId != bytes32(0));
    }

    // =========================================================================
    // G. FDC2 contracts wired to day-1 diamond
    // =========================================================================

    function testDay1_fdc2DeployAndInitialize() public view {
        assertEq(fdc2Hub.minThresholdBIPS(), 5000);
        assertEq(fdc2Hub.defaultNumberOfTees(), 1);
        assertEq(address(fdc2Hub.flareTeeManager()), address(flareTeeManager));
        assertEq(address(fdc2Verification.flareTeeManager()), address(flareTeeManager));
    }

    function testDay1_fdc2FeeConfigurations() public {
        bytes32 attestationType = bytes32("TeeAvailabilityCheck");
        bytes32 sourceId = bytes32("TEE");

        vm.prank(initialGovernance);
        fdc2RequestFeeConfigurations.setTypeAndSourceFee(attestationType, sourceId, 1000);
        assertEq(fdc2RequestFeeConfigurations.getTypeAndSourceFee(attestationType, sourceId), 1000);
    }

    function testDay1_fdc2GovernanceFunctions() public {
        vm.prank(initialGovernance);
        fdc2Hub.setMinThresholdBIPS(3000);
        assertEq(fdc2Hub.minThresholdBIPS(), 3000);

        vm.prank(initialGovernance);
        fdc2Hub.setDefaultNumberOfTees(3);
        assertEq(fdc2Hub.defaultNumberOfTees(), 3);
    }

    function testDay1_fdc2RequestAttestationRevertsNoTees() public {
        bytes32 attestationType = bytes32("TeeAvailabilityCheck");
        bytes32 sourceId = bytes32("TEE");
        vm.prank(initialGovernance);
        fdc2RequestFeeConfigurations.setTypeAndSourceFee(attestationType, sourceId, 100);

        vm.expectRevert();
        fdc2Hub.requestAttestation{value: 100}(
            IFdc2Hub.Fdc2AttestationRequest({
                header: IFdc2Hub.Fdc2RequestHeader(attestationType, sourceId, 5000, address(0)),
                requestBody: ""
            }),
            0, new address[](0), new address[](0), 0, address(0)
        );
    }

    // =========================================================================
    // Helpers — full flows via facets
    // =========================================================================

    function _setupExtension() private {
        vm.prank(extensionOwner);
        extensionId = flareTeeManager.register(ITeeExtensionStateVerifier(address(0)), instructionsSender);

        bytes32[] memory platforms = new bytes32[](1);
        platforms[0] = platform;
        vm.prank(initialGovernance);
        flareTeeManager.addSystemSupportedPlatforms(platforms);

        bytes32[] memory keyTypes = new bytes32[](1);
        keyTypes[0] = keyType;
        bytes32[][] memory sigAlgos = new bytes32[][](1);
        sigAlgos[0] = new bytes32[](1);
        sigAlgos[0][0] = signingAlgo;
        vm.prank(initialGovernance);
        flareTeeManager.addSystemSupportedKeyTypesAndSigningAlgos(keyTypes, sigAlgos);

        vm.prank(extensionOwner);
        flareTeeManager.addSupportedKeyTypes(extensionId, keyTypes);

        vm.prank(extensionOwner);
        flareTeeManager.addTeeVersion(extensionId, "v1.0.0", codeHash, platforms, bytes32(0));

        vm.prank(extensionOwner);
        flareTeeManager.allowAllTeeMachineOwners(extensionId);
        vm.prank(extensionOwner);
        flareTeeManager.allowAllTeeWalletProjectOwners(extensionId);
    }

    function _registerTeeMachine() private {
        _registerTeeMachineWith(teePrivateKey, teePublicKey, teeProxyId, teeUrl);
    }

    function _registerTeeMachineWith(
        uint256 _privKey,
        PublicKey memory _pubKey,
        address _proxyId,
        string memory _url
    )
        private
    {
        IMachineManager.TeeMachineData memory data = IMachineManager.TeeMachineData({
            extensionId: extensionId,
            publicKey: _pubKey,
            initialOwner: teeOwner,
            codeHash: codeHash,
            platform: platform
        });
        Signature memory sig = SignatureHelper.createSignature(vm, keccak256(abi.encode(data)), _privKey);

        address id = PublicKeyHelper.getAddress(_pubKey);
        registerTimestamps[id] = block.timestamp;

        vm.deal(teeOwner, 1 ether);
        vm.prank(teeOwner);
        flareTeeManager.register{value: 1000}(data, sig, _proxyId, _url, address(0));
    }

    function _toProduction(address _teeId, address _proxyId, string memory _url) private {
        ITeeAvailabilityCheck.Proof memory proof = _buildAvailabilityCheckProof(_teeId, _proxyId, _url);
        vm.warp(block.timestamp + 1);
        vm.prank(teeOwner);
        flareTeeManager.toProduction(proof);
    }

    function _buildAvailabilityCheckProof(
        address _teeId,
        address _proxyId,
        string memory _url
    )
        private
        returns (ITeeAvailabilityCheck.Proof memory)
    {
        bytes32 challenge = keccak256(abi.encode(_teeId, registerTimestamps[_teeId], randomNumber));

        IFdc2Hub.Fdc2ResponseHeader memory header = IFdc2Hub.Fdc2ResponseHeader(
            TEE_AVAILABILITY_CHECK_ATTESTATION_TYPE,
            TEE_SOURCE_ID,
            0,
            address(0),
            _cosignerAddresses(),
            cosignersThreshold,
            uint64(block.timestamp)
        );

        ITeeAvailabilityCheck.RequestBody memory reqBody = ITeeAvailabilityCheck.RequestBody(
            _teeId, _proxyId, _url, challenge, keccak256(abi.encode(extensionId))
        );

        ISystemStateVerifier.TeeSystemState memory sysState = ISystemStateVerifier.TeeSystemState(
            ISystemStateVerifier.TeeMachineStatus.ACTIVE, _teeId, bytes32(0)
        );

        ITeeAvailabilityCheck.ResponseBody memory respBody = ITeeAvailabilityCheck.ResponseBody(
            ITeeAvailabilityCheck.AvailabilityCheckStatus.OK,
            uint64(block.timestamp),
            codeHash,
            platform,
            1, // initialSigningPolicyId
            1, // lastSigningPolicyId
            ITeeAvailabilityCheck.TeeState(abi.encode(sysState), bytes32("v1"), new bytes(0), bytes32(0))
        );

        bytes32 messageHash = keccak256(abi.encode(
            keccak256(abi.encode(header)),
            keccak256(abi.encode(reqBody)),
            keccak256(abi.encode(respBody))
        ));

        // Create real cosigner signatures — verified by the real Fdc2Verification (pure ECDSA)
        bytes32 cosignersMessageHash = keccak256(bytes.concat(hex"010000000000", messageHash));
        Signature[] memory cosignerSigs = new Signature[](cosignersThreshold);
        for (uint256 i = 0; i < cosignersThreshold; i++) {
            cosignerSigs[i] = SignatureHelper.createSignature(vm, cosignersMessageHash, cosigners[i].privateKey);
        }

        // Mock Relay.verifyCustomSignature (signing policy verification delegates to Relay)
        vm.mockCall(
            relay,
            abi.encodeWithSelector(IRelay.verifyCustomSignature.selector),
            abi.encode(uint256(1))
        );

        IFdc2Verification.Fdc2Signatures memory sigs;
        sigs.cosignerSignatures = cosignerSigs;

        return ITeeAvailabilityCheck.Proof(sigs, header, reqBody, respBody);
    }

    function _createProject() private returns (bytes32) {
        return _createProjectWithBackupManager(address(0));
    }

    function _createProjectWithBackupManager(address _backupManager) private returns (bytes32 projId) {
        vm.prank(projectOwner);
        projId = flareTeeManager.createProject(extensionId, keyType, signingAlgo);
        if (_backupManager != address(0)) {
            vm.prank(projectOwner);
            flareTeeManager.setBackupManager(projId, _backupManager);
        }
    }

    function _createAndInitializeWallet(bytes32 _projId) private returns (bytes32 walletId) {
        vm.prank(projectOwner);
        flareTeeManager.createWallet(_projId);
        walletId = keccak256(abi.encode("WALLET", projectOwner, 1));

        PublicKey[] memory admins = new PublicKey[](1);
        admins[0] = PublicKeyHelper.getRandomPublicKey(vm);
        vm.prank(projectOwner);
        flareTeeManager.setAdmins(walletId, admins, 1);
        vm.prank(PublicKeyHelper.getAddress(admins[0]));
        flareTeeManager.confirmAdmin(walletId);

        vm.prank(projectOwner);
        flareTeeManager.closeWalletInitialization(walletId);
    }

    function _confirmKey(
        bytes32 _walletId,
        uint64 _keyId,
        address _teeId,
        uint256 _teePrivKey
    )
        private
    {
        (PublicKey[] memory admins, uint64 adminsThreshold) =
            flareTeeManager.getWalletAdminsPublicKeysAndThreshold(_walletId);
        (address[] memory walletCosigners, uint64 walletCosignersThreshold) =
            flareTeeManager.getWalletCosignersAndThreshold(_walletId);

        IWalletKeyManager.KeyExistence memory proof = IWalletKeyManager.KeyExistence({
            teeId: _teeId,
            walletId: _walletId,
            keyId: _keyId,
            keyType: keyType,
            signingAlgo: signingAlgo,
            publicKey: bytes("generatedPubKey"),
            nonce: 0,
            restored: false,
            configConstants: IWalletKeyManager.KeyConfigConstants(
                admins, adminsThreshold, walletCosigners, walletCosignersThreshold
            ),
            settingsVersion: bytes32(0),
            settings: bytes("")
        });

        Signature memory teeSig = SignatureHelper.createSignature(
            vm, keccak256(abi.encode(proof)), _teePrivKey
        );

        vm.prank(projectOwner);
        flareTeeManager.confirmKey(proof, teeSig);
    }

    function _confirmRestoredKey(
        bytes32 _walletId,
        uint64 _keyId,
        address _teeId,
        uint256 _teePrivKey
    )
        private
    {
        (PublicKey[] memory admins, uint64 adminsThreshold) =
            flareTeeManager.getWalletAdminsPublicKeysAndThreshold(_walletId);
        (address[] memory walletCosigners, uint64 walletCosignersThreshold) =
            flareTeeManager.getWalletCosignersAndThreshold(_walletId);

        // Use the existing public key and nonce=1 (set by backupRestore)
        bytes memory existingPubKey = flareTeeManager.getWalletKeyPublicKey(_walletId, _keyId);

        IWalletKeyManager.KeyExistence memory proof = IWalletKeyManager.KeyExistence({
            teeId: _teeId,
            walletId: _walletId,
            keyId: _keyId,
            keyType: keyType,
            signingAlgo: signingAlgo,
            publicKey: existingPubKey,
            nonce: 1,
            restored: true,
            configConstants: IWalletKeyManager.KeyConfigConstants(
                admins, adminsThreshold, walletCosigners, walletCosignersThreshold
            ),
            settingsVersion: bytes32(0),
            settings: bytes("")
        });

        Signature memory teeSig = SignatureHelper.createSignature(
            vm, keccak256(abi.encode(proof)), _teePrivKey
        );

        vm.prank(projectOwner);
        flareTeeManager.confirmKey(proof, teeSig);
    }

    // =========================================================================
    // Helpers — address wiring
    // =========================================================================

    function _cosignerAddresses() private view returns (address[] memory addrs) {
        addrs = new address[](cosigners.length);
        for (uint256 i = 0; i < cosigners.length; i++) {
            addrs[i] = cosigners[i].addr;
        }
    }

    function _updateTeeManagerAddresses() private {
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
        addresses[3] = relay;
        addresses[4] = address(fdc2Hub);
        addresses[5] = address(fdc2Verification);
        vm.prank(addressUpdater);
        flareTeeManager.updateContractAddresses(nameHashes, addresses);
    }

    function _updateFdc2HubAddresses() private {
        bytes32[] memory nameHashes = new bytes32[](5);
        address[] memory addresses = new address[](5);
        nameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        nameHashes[1] = keccak256(abi.encode("FlareTeeManager"));
        nameHashes[2] = keccak256(abi.encode("FlareSystemsManager"));
        nameHashes[3] = keccak256(abi.encode("RewardManager"));
        nameHashes[4] = keccak256(abi.encode("Fdc2RequestFeeConfigurations"));
        addresses[0] = addressUpdater;
        addresses[1] = address(flareTeeManager);
        addresses[2] = flareSystemsManager;
        addresses[3] = rewardManager;
        addresses[4] = address(fdc2RequestFeeConfigurations);
        vm.prank(addressUpdater);
        fdc2Hub.updateContractAddresses(nameHashes, addresses);
    }

    function _updateFdc2VerificationAddresses() private {
        bytes32[] memory nameHashes = new bytes32[](3);
        address[] memory addresses = new address[](3);
        nameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        nameHashes[1] = keccak256(abi.encode("FlareTeeManager"));
        nameHashes[2] = keccak256(abi.encode("Relay"));
        addresses[0] = addressUpdater;
        addresses[1] = address(flareTeeManager);
        addresses[2] = relay;
        vm.prank(addressUpdater);
        fdc2Verification.updateContractAddresses(nameHashes, addresses);
    }

    function _mockExternalInfra() private {
        vm.mockCall(
            relay,
            abi.encodeWithSelector(RandomNumberV2Interface.getRandomNumber.selector),
            abi.encode(randomNumber, true, uint256(0))
        );
        vm.mockCall(
            flareSystemsManager,
            abi.encodeWithSelector(ProtocolsV2Interface.getCurrentRewardEpochId.selector),
            abi.encode(uint256(1))
        );
        vm.mockCall(
            rewardManager,
            abi.encodeWithSelector(IIRewardManager.receiveRewards.selector),
            ""
        );
    }
}
