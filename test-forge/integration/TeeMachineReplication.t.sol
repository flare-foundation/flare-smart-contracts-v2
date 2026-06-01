// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";

import { FlareTeeManagerDeployer } from "../utils/FlareTeeManagerDeployer.sol";

// TEE interfaces
import { IIFlareTeeManager } from "../../contracts/tee/interface/IIFlareTeeManager.sol";
import { IExtensionManager } from "../../contracts/userInterfaces/tee/IExtensionManager.sol";
import { IMachineManager, TEE_MACHINE_REGISTER } from "../../contracts/userInterfaces/tee/IMachineManager.sol";
import { SignedPayload } from "../../contracts/utils/lib/SignedPayload.sol";
import { IOwnerAllowlist } from "../../contracts/userInterfaces/tee/IOwnerAllowlist.sol";
import { IExtensionGovernance } from "../../contracts/userInterfaces/tee/IExtensionGovernance.sol";
import { IReplication } from "../../contracts/userInterfaces/tee/IReplication.sol";
import { IVerification, TEE_SOURCE_ID } from "../../contracts/userInterfaces/tee/IVerification.sol";
import { ISystemStateVerifier } from "../../contracts/userInterfaces/tee/ISystemStateVerifier.sol";
import { IMachinePathManager } from "../../contracts/userInterfaces/tee/IMachinePathManager.sol";
import { ITeeExtensionStateVerifier } from "../../contracts/userInterfaces/tee/ITeeExtensionStateVerifier.sol";
import { ExtensionManager } from "../../contracts/tee/library/ExtensionManager.sol";

// FDC2
import { Fdc2Verification } from "../../contracts/fdc2/implementation/Fdc2Verification.sol";
import { Fdc2VerificationProxy } from "../../contracts/fdc2/proxy/Fdc2VerificationProxy.sol";
import { Fdc2Hub } from "../../contracts/fdc2/implementation/Fdc2Hub.sol";
import { Fdc2HubProxy } from "../../contracts/fdc2/proxy/Fdc2HubProxy.sol";
import { Fdc2RequestFeeConfigurations } from "../../contracts/fdc2/implementation/Fdc2RequestFeeConfigurations.sol";
import { Fdc2RequestFeeConfigurationsProxy } from "../../contracts/fdc2/proxy/Fdc2RequestFeeConfigurationsProxy.sol";
import { IFdc2Verification } from "../../contracts/userInterfaces/fdc2/IFdc2Verification.sol";
import { IFdc2Hub, FDC2 } from "../../contracts/userInterfaces/fdc2/IFdc2Hub.sol";
import { ITeeAvailabilityCheck, TEE_AVAILABILITY_CHECK_ATTESTATION_TYPE }
    from "../../contracts/userInterfaces/fdc2/ITeeAvailabilityCheck.sol";

// External interfaces
import { ProtocolsV2Interface } from "../../contracts/userInterfaces/LTS/ProtocolsV2Interface.sol";
import { RandomNumberV2Interface } from "../../contracts/userInterfaces/LTS/RandomNumberV2Interface.sol";
import { IIRewardManager } from "../../contracts/protocol/interface/IIRewardManager.sol";
import { IRelay } from "../../contracts/userInterfaces/IRelay.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

import { PublicKey } from "../../contracts/userInterfaces/IPublicKey.sol";
import { Signature } from "../../contracts/userInterfaces/ISignature.sol";
import { SignatureHelper } from "../utils/SignatureHelper.sol";

// solhint-disable-next-line max-states-count
contract TeeMachineReplicationTest is Test {

    struct Signer {
        address addr;
        uint256 privateKey;
    }

    IIFlareTeeManager private flareTeeManager;

    Fdc2Hub private fdc2Hub;
    Fdc2Hub private fdc2HubImpl;
    Fdc2HubProxy private fdc2HubProxy;
    Fdc2Verification private fdc2Verification;
    Fdc2Verification private fdc2VerificationImpl;
    Fdc2VerificationProxy private fdc2VerificationProxy;
    Fdc2RequestFeeConfigurations private fdc2RequestFeeConfigurations;
    Fdc2RequestFeeConfigurations private fdc2RequestFeeConfigurationsImpl;
    Fdc2RequestFeeConfigurationsProxy private fdc2RequestFeeConfigurationsProxy;

    IGovernanceSettings private governanceSettings;
    address private initialGovernance;
    address private addressUpdater;
    address private flareSystemsManager;
    address private rewardManager;
    address private relay;

    address private extensionOwner;
    address private instructionsSender;
    uint256 private extensionId;
    address private teeMachineOwner;
    PublicKey private teePublicKey;
    uint256 private teePrivateKey;
    address private teeId;
    address private teeProxyId;
    string private teeUrl;
    PublicKey private newTeePublicKey;
    uint256 private newTeePrivateKey;
    address private newTeeId;
    address private newTeeProxyId;
    string private newTeeUrl;

    Signer[] private governanceSigners1;
    Signer[] private governanceSigners2;
    uint64 private governanceSignersThreshold1;
    uint64 private governanceSignersThreshold2;

    Signer[] private cosigners;
    uint64 private cosignersThreshold;

    bytes32 private governanceHash1;
    bytes32 private governanceHash2;
    bytes32 private codeHash1;
    bytes32 private codeHash2;
    bytes32[] private platforms1;
    bytes32[] private platforms2;

    uint256 private randomNumber;

    function setUp() public {
        extensionId = 0;
        extensionOwner = makeAddr("extensionOwner");
        instructionsSender = makeAddr("instructionsSender");
        teeMachineOwner = makeAddr("teeMachineOwner");
        vm.deal(teeMachineOwner, 1 ether);

        VmSafe.Wallet memory wallet = vm.createWallet("teeId");
        teePublicKey.x = bytes32(wallet.publicKeyX);
        teePublicKey.y = bytes32(wallet.publicKeyY);
        teePrivateKey = wallet.privateKey;
        teeId = wallet.addr;
        teeProxyId = makeAddr("teeProxyId");
        teeUrl = "https://tee.proxy.url";

        wallet = vm.createWallet("newTeeId");
        newTeePublicKey.x = bytes32(wallet.publicKeyX);
        newTeePublicKey.y = bytes32(wallet.publicKeyY);
        newTeePrivateKey = wallet.privateKey;
        newTeeId = wallet.addr;
        newTeeProxyId = makeAddr("newTeeProxyId");
        newTeeUrl = "https://new.tee.proxy.url";

        initialGovernance = makeAddr("initialGovernance");
        addressUpdater = makeAddr("AddressUpdater");
        governanceSettings = IGovernanceSettings(makeAddr("governanceSettings"));
        flareSystemsManager = makeAddr("FlareSystemsManager");
        rewardManager = makeAddr("RewardManager");
        relay = makeAddr("Relay");

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
            defaultFee: 1000,
            publicExtensionCreationEnabled: true,
            emergencyUnpauseGracePeriodSeconds: 7200
        }));
        vm.startPrank(initialGovernance);
        FlareTeeManagerDeployer.deployLaterFacets(flareTeeManager, FlareTeeManagerDeployer.LaterDeployParams({
            pauseBeforeUpgradeMinDurationSeconds: 600
        }));
        vm.stopPrank();

        // =====================================================================
        // Deploy FDC2 contracts (unchanged - still UUPS proxies)
        // =====================================================================

        fdc2HubImpl = new Fdc2Hub();
        fdc2HubProxy = new Fdc2HubProxy(
            IGovernanceSettings(address(this)),
            initialGovernance,
            addressUpdater,
            5000,
            1,
            address(fdc2HubImpl)
        );
        fdc2Hub = Fdc2Hub(address(fdc2HubProxy));

        fdc2VerificationImpl = new Fdc2Verification();
        fdc2VerificationProxy = new Fdc2VerificationProxy(
            IGovernanceSettings(address(this)),
            initialGovernance,
            addressUpdater,
            address(fdc2VerificationImpl)
        );
        fdc2Verification = Fdc2Verification(address(fdc2VerificationProxy));

        fdc2RequestFeeConfigurationsImpl = new Fdc2RequestFeeConfigurations();
        fdc2RequestFeeConfigurationsProxy = new Fdc2RequestFeeConfigurationsProxy(
            IGovernanceSettings(address(this)),
            initialGovernance,
            addressUpdater,
            address(fdc2RequestFeeConfigurationsImpl)
        );
        fdc2RequestFeeConfigurations = Fdc2RequestFeeConfigurations(address(fdc2RequestFeeConfigurationsProxy));

        // set signers and thresholds
        governanceSigners1.push();
        (governanceSigners1[0].addr, governanceSigners1[0].privateKey) = makeAddrAndKey("signer1");
        governanceSigners1.push();
        (governanceSigners1[1].addr, governanceSigners1[1].privateKey) = makeAddrAndKey("signer2");
        governanceSigners1.push();
        (governanceSigners1[2].addr, governanceSigners1[2].privateKey) = makeAddrAndKey("signer3");
        governanceSignersThreshold1 = 2;

        governanceSigners2.push();
        (governanceSigners2[0].addr, governanceSigners2[0].privateKey) = makeAddrAndKey("signer4");
        governanceSigners2.push();
        (governanceSigners2[1].addr, governanceSigners2[1].privateKey) = makeAddrAndKey("signer5");
        governanceSigners2.push();
        (governanceSigners2[2].addr, governanceSigners2[2].privateKey) = makeAddrAndKey("signer6");
        governanceSigners2.push();
        (governanceSigners2[3].addr, governanceSigners2[3].privateKey) = makeAddrAndKey("signer7");
        governanceSignersThreshold2 = 3;

        cosigners.push();
        (cosigners[0].addr, cosigners[0].privateKey) = makeAddrAndKey("cosigner1");
        cosigners.push();
        (cosigners[1].addr, cosigners[1].privateKey) = makeAddrAndKey("cosigner2");
        cosigners.push();
        (cosigners[2].addr, cosigners[2].privateKey) = makeAddrAndKey("cosigner3");
        cosignersThreshold = 2;

        // compute governance hashes
        governanceHash1 = keccak256(abi.encode(_getSignersAddresses(governanceSigners1), governanceSignersThreshold1));
        governanceHash2 = keccak256(abi.encode(_getSignersAddresses(governanceSigners2), governanceSignersThreshold2));

        // set code hashes and platforms
        codeHash1 = keccak256(abi.encodePacked("codeHash1"));
        codeHash2 = keccak256(abi.encodePacked("codeHash2"));
        platforms1.push(keccak256(abi.encodePacked("platform1")));
        platforms1.push(keccak256(abi.encodePacked("platform2")));
        platforms2.push(keccak256(abi.encodePacked("platform1")));
        platforms2.push(keccak256(abi.encodePacked("platform2")));
        platforms2.push(keccak256(abi.encodePacked("platform3")));

        // =====================================================================
        // Update contract addresses
        // =====================================================================

        // FlareTeeManager only resolves external addresses (5 contracts)
        bytes32[] memory teeNameHashes = new bytes32[](6);
        teeNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        teeNameHashes[1] = keccak256(abi.encode("FlareSystemsManager"));
        teeNameHashes[2] = keccak256(abi.encode("RewardManager"));
        teeNameHashes[3] = keccak256(abi.encode("Relay"));
        teeNameHashes[4] = keccak256(abi.encode("Fdc2Hub"));
        teeNameHashes[5] = keccak256(abi.encode("Fdc2Verification"));

        address[] memory teeAddresses = new address[](6);
        teeAddresses[0] = addressUpdater;
        teeAddresses[1] = flareSystemsManager;
        teeAddresses[2] = rewardManager;
        teeAddresses[3] = relay;
        teeAddresses[4] = address(fdc2Hub);
        teeAddresses[5] = address(fdc2Verification);

        // FDC2 contracts need "FlareTeeManager" in the name list
        bytes32[] memory contractNameHashes = new bytes32[](7);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[2] = keccak256(abi.encode("RewardManager"));
        contractNameHashes[3] = keccak256(abi.encode("Relay"));
        contractNameHashes[4] = keccak256(abi.encode("FlareTeeManager"));
        contractNameHashes[5] = keccak256(abi.encode("Fdc2Hub"));
        contractNameHashes[6] = keccak256(abi.encode("Fdc2RequestFeeConfigurations"));

        address[] memory contractAddresses = new address[](7);
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = flareSystemsManager;
        contractAddresses[2] = rewardManager;
        contractAddresses[3] = relay;
        contractAddresses[4] = address(flareTeeManager);
        contractAddresses[5] = address(fdc2Hub);
        contractAddresses[6] = address(fdc2RequestFeeConfigurations);

        vm.startPrank(addressUpdater);
        flareTeeManager.updateContractAddresses(teeNameHashes, teeAddresses);
        fdc2Verification.updateContractAddresses(contractNameHashes, contractAddresses);
        fdc2Hub.updateContractAddresses(contractNameHashes, contractAddresses);
        vm.stopPrank();

        vm.startPrank(initialGovernance);
        // register system instructions senders
        // In the Diamond, replication/verification facets call the library directly,
        // so only external callers like fdc2Hub need to be registered.
        address[] memory systemInstructionsSenders = new address[](1);
        systemInstructionsSenders[0] = address(fdc2Hub);
        flareTeeManager.registerSystemInstructionsSenders(
            systemInstructionsSenders
        );

        // add supported platforms
        flareTeeManager.addSystemSupportedPlatforms(platforms2);

        // set tee fees
        bytes32[] memory opTypes = new bytes32[](3);
        bytes32[] memory opCommands = new bytes32[](3);
        uint256[] memory fees = new uint256[](3);
        opTypes[0] = bytes32("F_REG");
        opTypes[1] = bytes32("F_REG");
        opTypes[2] = bytes32("F_REG");
        opCommands[0] = bytes32("TEE_ATTESTATION");
        opCommands[1] = bytes32("TO_PAUSE_FOR_UPGRADE");
        opCommands[2] = bytes32("REPLICATE_FROM");
        fees[0] = 100;
        fees[1] = 200;
        fees[2] = 300;
        flareTeeManager.setOperationFees(opTypes, opCommands, fees);

        // set fdc2 fees
        fdc2RequestFeeConfigurations.setTypeAndSourceFee(
            TEE_AVAILABILITY_CHECK_ATTESTATION_TYPE,
            TEE_SOURCE_ID,
            50
        );

        // set cosigners
        flareTeeManager.setCosigners(
            _getSignersAddresses(cosigners),
            cosignersThreshold
        );
        vm.stopPrank();

        // mock calls to other contracts
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

        randomNumber = 12345;
        vm.mockCall(
            relay,
            abi.encodeWithSelector(RandomNumberV2Interface.getRandomNumber.selector),
            abi.encode(randomNumber, true, 0)
        );

        vm.mockCall(
            relay,
            abi.encodeWithSelector(IRelay.verifyCustomSignature.selector),
            abi.encode(1)
        );

        // advance time
        vm.warp(block.timestamp + 1000);
    }

    function testRegisterNewTeeExtension() public {
        ITeeExtensionStateVerifier verifier = ITeeExtensionStateVerifier(address(0));
        uint256 expectedId = ExtensionManager.PUBLIC_EXTENSION_ID_START;
        vm.prank(extensionOwner);
        vm.expectEmit();
        emit IExtensionManager.TeeExtensionRegistered(expectedId, extensionOwner);
        vm.expectEmit();
        emit IExtensionManager.TeeExtensionContractsSet(
            expectedId,
            verifier,
            instructionsSender
        );
        extensionId = flareTeeManager.register(verifier, instructionsSender);
        assertEq(extensionId, expectedId);
        assertEq(flareTeeManager.getExtensionOwner(extensionId), extensionOwner);
        assertEq(address(flareTeeManager.getTeeExtensionStateVerifier(extensionId)), address(0));
        assertEq(flareTeeManager.getTeeExtensionInstructionsSender(extensionId), instructionsSender);
    }

    function testSetGovernanceHash() public {
        testRegisterNewTeeExtension();
        _setGovernanceHash(governanceHash1, governanceSigners1, governanceSignersThreshold1);
    }

    function testAddTeeVersion() public {
        testSetGovernanceHash();
        _addTeeVersion("v1.0.0", codeHash1, platforms1);
    }

    function testAddAllowedTeeMachineOwners() public {
        testAddTeeVersion();
        address[] memory teeMachineOwners = new address[](1);
        teeMachineOwners[0] = teeMachineOwner;
        vm.prank(extensionOwner);
        vm.expectEmit();
        emit IOwnerAllowlist.AllowedTeeMachineOwnersAdded(extensionId, teeMachineOwners);
        flareTeeManager.addAllowedTeeMachineOwners(extensionId, teeMachineOwners);
        assertTrue(flareTeeManager.isAllowedTeeMachineOwner(extensionId, teeMachineOwner));
        address[] memory owners = flareTeeManager.getAllowedTeeMachineOwners(extensionId);
        assertEq(owners.length, 1);
        assertEq(owners[0], teeMachineOwner);
    }

    function testRegisterTeeMachine() public {
        testAddAllowedTeeMachineOwners();
        vm.prank(teeMachineOwner);
        vm.expectEmit();
        emit IMachineManager.TeeMachineRegistered(
            teeId, teeProxyId, teeMachineOwner, extensionId, teeUrl, codeHash1, platforms1[0], governanceHash1
        );

        IMachineManager.TeeMachineData memory teeMachineData = IMachineManager.TeeMachineData({
            extensionId: extensionId,
            publicKey: teePublicKey,
            initialOwner: teeMachineOwner,
            codeHash: codeHash1,
            platform: platforms1[0],
            governanceHash: governanceHash1
        });
        Signature memory signature = SignatureHelper.createSignature(
            vm,
            SignedPayload.messageHash(TEE_MACHINE_REGISTER, keccak256(abi.encode(teeMachineData))),
            teePrivateKey
        );
        flareTeeManager.register{value: 150}(
            teeMachineData,
            signature,
            teeProxyId,
            teeUrl,
            address(0)
        );
    }

    function testPutTeeMachineToProduction() public {
        testRegisterTeeMachine();

        IFdc2Hub.Fdc2ResponseHeader memory header = IFdc2Hub.Fdc2ResponseHeader(
            TEE_AVAILABILITY_CHECK_ATTESTATION_TYPE,
            TEE_SOURCE_ID,
            0,
            address(0),
            _getSignersAddresses(cosigners),
            cosignersThreshold,
            uint64(block.timestamp)
        );
        ITeeAvailabilityCheck.RequestBody memory reqBody = ITeeAvailabilityCheck.RequestBody(
            teeId,
            teeProxyId,
            teeUrl,
            keccak256(abi.encode(teeId, block.timestamp, randomNumber)),
            keccak256(abi.encode(extensionId))
        );
        ISystemStateVerifier.TeeSystemState memory systemState = ISystemStateVerifier.TeeSystemState(
            ISystemStateVerifier.TeeMachineStatus.ACTIVE,
            teeId
        );
        ITeeAvailabilityCheck.ResponseBody memory respBody = ITeeAvailabilityCheck.ResponseBody(
            ITeeAvailabilityCheck.AvailabilityCheckStatus.OK,
            uint64(block.timestamp),
            codeHash1,
            platforms1[0],
            1,
            1,
            ITeeAvailabilityCheck.TeeState(abi.encode(systemState), bytes32("v1"), new bytes(0), bytes32(0))
        );

        bytes32 messageHash = SignedPayload.messageHash(
            FDC2,
            keccak256(abi.encode(header, reqBody, respBody))
        );
        bytes32 cosignersMessageHash = keccak256(bytes.concat(hex"010000000000", messageHash));

        IFdc2Verification.Fdc2Signatures memory sigs;
        sigs.cosignerSignatures = new Signature[](cosignersThreshold);
        for (uint256 i = 0; i < cosignersThreshold; i++) {
            sigs.cosignerSignatures[i] =
                SignatureHelper.createSignature(vm, cosignersMessageHash, cosigners[i].privateKey);
        }

        ITeeAvailabilityCheck.Proof memory proof = ITeeAvailabilityCheck.Proof(
            sigs,
            header,
            reqBody,
            respBody
        );

        vm.warp(block.timestamp + 1);
        vm.prank(teeMachineOwner);
        vm.expectEmit();
        emit IMachineManager.TeeMachineStatusChanged(teeId, IMachineManager.TeeStatus.PRODUCTION);
        flareTeeManager.toProduction(proof);
        assert(flareTeeManager.getTeeMachineStatus(teeId) == IMachineManager.TeeStatus.PRODUCTION);
    }

    function testAddNewTeeVersion() public {
        testPutTeeMachineToProduction();
        _setGovernanceHash(governanceHash2, governanceSigners2, governanceSignersThreshold2);
        _addTeeVersion("v2.0.0", codeHash2, platforms2);
    }

    function testPauseTeeMachine() public {
        testAddNewTeeVersion();
        vm.prank(teeMachineOwner);
        vm.expectEmit();
        emit IMachineManager.TeeMachineStatusChanged(teeId, IMachineManager.TeeStatus.PAUSED);
        flareTeeManager.pause(teeId);
        assert(flareTeeManager.getTeeMachineStatus(teeId) == IMachineManager.TeeStatus.PAUSED);
    }

    function testPutTeeMachineToPauseForUpgrade() public {
        testPauseTeeMachine();
        vm.warp(block.timestamp + 1000);
        vm.prank(teeMachineOwner);
        vm.expectEmit();
        emit IMachineManager.TeeMachineStatusChanged(
            teeId, IMachineManager.TeeStatus.PAUSED_FOR_UPGRADE
        );
        flareTeeManager.toPauseForUpgrade{value: 200}(teeId, address(0));
        assert(flareTeeManager.getTeeMachineStatus(teeId) == IMachineManager.TeeStatus.PAUSED_FOR_UPGRADE);
    }

    function testRegisterNewTeeMachine() public {
        testPutTeeMachineToPauseForUpgrade();
        vm.prank(teeMachineOwner);
        vm.expectEmit();
        emit IMachineManager.TeeMachineRegistered(
            newTeeId, newTeeProxyId, teeMachineOwner, extensionId, newTeeUrl, codeHash2, platforms2[1],
            governanceHash2
        );

        IMachineManager.TeeMachineData memory newTeeMachineData = IMachineManager.TeeMachineData({
            extensionId: extensionId,
            publicKey: newTeePublicKey,
            initialOwner: teeMachineOwner,
            codeHash: codeHash2,
            platform: platforms2[1],
            governanceHash: governanceHash2
        });
        Signature memory signature = SignatureHelper.createSignature(
            vm,
            SignedPayload.messageHash(TEE_MACHINE_REGISTER, keccak256(abi.encode(newTeeMachineData))),
            newTeePrivateKey
        );
        flareTeeManager.register{value: 150}(
            newTeeMachineData,
            signature,
            newTeeProxyId,
            newTeeUrl,
            address(0)
        );
    }

    /**
     * Stages the per-extension authorization for the replication: builds a machine-path list with
     * the (teeId → newTeeId) path. The list spans two involved governances (governanceHash1 from
     * the source machine, governanceHash2 from the destination machine) so it must reach the
     * threshold of EACH governance before activation. Returns the activated nonce.
     */
    function testCreateAndSignMachinePathList() public returns (uint256 _nonce) {
        testRegisterNewTeeMachine();

        vm.prank(extensionOwner);
        _nonce = flareTeeManager.createNewMachinePathList(extensionId);
        assertEq(_nonce, 1);

        IMachinePathManager.MachinePath[] memory paths = new IMachinePathManager.MachinePath[](1);
        address[] memory sources = new address[](1);
        sources[0] = teeId;
        address[] memory destinations = new address[](1);
        destinations[0] = newTeeId;
        paths[0] = IMachinePathManager.MachinePath(sources, destinations);

        vm.prank(extensionOwner);
        flareTeeManager.addMachinePaths(extensionId, _nonce, paths);

        vm.prank(extensionOwner);
        flareTeeManager.finalizeMachinePathList(extensionId, _nonce);
        assertTrue(flareTeeManager.isMachinePathListFinalized(extensionId, _nonce));

        bytes32 messageHash = flareTeeManager.getMachinePathListMessageHash(extensionId, _nonce);
        // Sign with both governances; activation requires every involved governance threshold.
        for (uint256 i = 0; i < governanceSignersThreshold1; i++) {
            Signature memory sig = SignatureHelper.createSignature(
                vm, messageHash, governanceSigners1[i].privateKey
            );
            flareTeeManager.signMachinePathList(extensionId, _nonce, sig);
        }
        for (uint256 i = 0; i < governanceSignersThreshold2; i++) {
            Signature memory sig = SignatureHelper.createSignature(
                vm, messageHash, governanceSigners2[i].privateKey
            );
            flareTeeManager.signMachinePathList(extensionId, _nonce, sig);
        }
        assertTrue(flareTeeManager.isMachinePathListSigned(extensionId, _nonce));
        assertEq(flareTeeManager.getActiveMachinePathListNonce(extensionId), _nonce);
    }

    function testReplicateFromTeeMachine() public {
        uint256 listNonce = testCreateAndSignMachinePathList();

        // update current reward epoch id
        vm.mockCall(
            flareSystemsManager,
            abi.encodeWithSelector(ProtocolsV2Interface.getCurrentRewardEpochId.selector),
            abi.encode(2)
        );

        IFdc2Hub.Fdc2ResponseHeader memory header = IFdc2Hub.Fdc2ResponseHeader(
            TEE_AVAILABILITY_CHECK_ATTESTATION_TYPE,
            TEE_SOURCE_ID,
            0,
            address(0),
            _getSignersAddresses(cosigners),
            cosignersThreshold,
            uint64(block.timestamp)
        );
        ITeeAvailabilityCheck.RequestBody memory reqBody = ITeeAvailabilityCheck.RequestBody(
            newTeeId,
            newTeeProxyId,
            newTeeUrl,
            keccak256(abi.encode(newTeeId, block.timestamp, randomNumber)),
            bytes32("instructionId")
        );
        ISystemStateVerifier.TeeSystemState memory systemState = ISystemStateVerifier.TeeSystemState(
            ISystemStateVerifier.TeeMachineStatus.ACTIVE,
            newTeeId
        );
        ITeeAvailabilityCheck.ResponseBody memory respBody = ITeeAvailabilityCheck.ResponseBody(
            ITeeAvailabilityCheck.AvailabilityCheckStatus.OK,
            uint64(block.timestamp),
            codeHash2,
            platforms2[1],
            2,
            3,
            ITeeAvailabilityCheck.TeeState(abi.encode(systemState), bytes32("v1"), new bytes(0), bytes32(0))
        );

        bytes32 messageHash = SignedPayload.messageHash(
            FDC2,
            keccak256(abi.encode(header, reqBody, respBody))
        );
        bytes32 cosignersMessageHash = keccak256(bytes.concat(hex"010000000000", messageHash));

        IFdc2Verification.Fdc2Signatures memory sigs;
        sigs.cosignerSignatures = new Signature[](cosignersThreshold);
        for (uint256 i = 0; i < cosignersThreshold; i++) {
            sigs.cosignerSignatures[i] =
                SignatureHelper.createSignature(vm, cosignersMessageHash, cosigners[i].privateKey);
        }

        ITeeAvailabilityCheck.Proof memory proof = ITeeAvailabilityCheck.Proof(
            sigs,
            header,
            reqBody,
            respBody
        );

        vm.warp(block.timestamp + 1);
        vm.prank(teeMachineOwner);
        vm.expectEmit();
        emit IReplication.TeeMachineReplicationTriggered(teeId, newTeeId, listNonce);
        flareTeeManager.replicateFrom{value: 600}(teeId, proof, address(0));
        assert(flareTeeManager.getTeeMachineStatus(newTeeId) == IMachineManager.TeeStatus.REPLICATING);
    }

    function testRequestTeeAttestation() public {
        testReplicateFromTeeMachine();
        bytes32 challenge = keccak256(abi.encode(teeId, block.timestamp, randomNumber));
        vm.expectEmit();
        emit IVerification.TeeAttestationRequested(teeId, challenge);
        flareTeeManager.requestTeeAttestation{value: 150}(teeId, address(0));
    }

    function testConfirmReplicate() public {
        testRequestTeeAttestation();

        IFdc2Hub.Fdc2ResponseHeader memory header = IFdc2Hub.Fdc2ResponseHeader(
            TEE_AVAILABILITY_CHECK_ATTESTATION_TYPE,
            TEE_SOURCE_ID,
            0,
            address(0),
            _getSignersAddresses(cosigners),
            cosignersThreshold,
            uint64(block.timestamp)
        );
        ITeeAvailabilityCheck.RequestBody memory reqBody = ITeeAvailabilityCheck.RequestBody(
            teeId,
            newTeeProxyId,
            newTeeUrl,
            keccak256(abi.encode(teeId, block.timestamp, randomNumber)),
            bytes32("newInstructionId")
        );
        // Post-replication: chain has copied initialTeeId = newTeeId into the old slot, and the
        // new TEE software (which is actually answering) reports its own provisioning identity.
        ISystemStateVerifier.TeeSystemState memory systemState = ISystemStateVerifier.TeeSystemState(
            ISystemStateVerifier.TeeMachineStatus.ACTIVE,
            newTeeId
        );
        ITeeAvailabilityCheck.ResponseBody memory respBody = ITeeAvailabilityCheck.ResponseBody(
            ITeeAvailabilityCheck.AvailabilityCheckStatus.OK,
            uint64(block.timestamp),
            codeHash2,
            platforms2[1],
            2,
            3,
            ITeeAvailabilityCheck.TeeState(abi.encode(systemState), bytes32("v1"), new bytes(0), bytes32(0))
        );

        bytes32 messageHash = SignedPayload.messageHash(
            FDC2,
            keccak256(abi.encode(header, reqBody, respBody))
        );
        bytes32 cosignersMessageHash = keccak256(bytes.concat(hex"010000000000", messageHash));

        IFdc2Verification.Fdc2Signatures memory sigs;
        sigs.cosignerSignatures = new Signature[](cosignersThreshold);
        for (uint256 i = 0; i < cosignersThreshold; i++) {
            sigs.cosignerSignatures[i] =
                SignatureHelper.createSignature(vm, cosignersMessageHash, cosigners[i].privateKey);
        }

        ITeeAvailabilityCheck.Proof memory proof = ITeeAvailabilityCheck.Proof(
            sigs,
            header,
            reqBody,
            respBody
        );

        vm.warp(block.timestamp + 1);
        vm.prank(teeMachineOwner);
        vm.expectEmit();
        emit IReplication.TeeMachineReplicationConfirmed(teeId, newTeeId);
        flareTeeManager.confirmReplicate(newTeeId, proof);
        assert(flareTeeManager.getTeeMachineStatus(teeId) == IMachineManager.TeeStatus.PRODUCTION);
        vm.expectRevert(IMachineManager.TeeNotFound.selector);
        flareTeeManager.getTeeMachineStatus(newTeeId);
    }

    function _setGovernanceHash(bytes32 _governanceHash, Signer[] memory _signers, uint64 _threshold) internal {
        address[] memory signers = _getSignersAddresses(_signers);
        vm.prank(extensionOwner);
        vm.expectEmit();
        emit IExtensionGovernance.NewTeeGovernanceSet(extensionId, _governanceHash, signers, _threshold);
        flareTeeManager.setNewTeeGovernance(extensionId, signers, _threshold);
        assertEq(flareTeeManager.getLatestTeeGovernanceHash(extensionId), _governanceHash);
        assertEq(_governanceHash, keccak256(abi.encode(signers, _threshold)));
        assertEq(flareTeeManager.getTeeGovernanceThreshold(extensionId, _governanceHash), _threshold);
    }

    function _addTeeVersion(
        bytes32 _version,
        bytes32 _codeHash,
        bytes32[] memory _platforms
    ) internal {
        vm.prank(extensionOwner);
        vm.expectEmit();
        emit IExtensionManager.TeeVersionAdded(extensionId, _version, _codeHash, _platforms);
        flareTeeManager.addTeeVersion(extensionId, _version, _codeHash, _platforms);
        for (uint256 i = 0; i < _platforms.length; i++) {
            assertTrue(flareTeeManager.isCodeHashPlatformSupported(extensionId, _codeHash, _platforms[i]));
        }
        (bytes32 version, bytes32[] memory platformsResult) =
            flareTeeManager.getCodeHashInfo(extensionId, _codeHash);
        assertEq(version, _version);
        assertEq(platformsResult.length, _platforms.length);
        for (uint256 i = 0; i < _platforms.length; i++) {
            assertEq(platformsResult[i], _platforms[i]);
        }
    }

    function _getSignersAddresses(Signer[] memory _signers) internal pure returns (address[] memory) {
        address[] memory addresses = new address[](_signers.length);
        for (uint256 i = 0; i < _signers.length; i++) {
            addresses[i] = _signers[i].addr;
        }
        return addresses;
    }
}
