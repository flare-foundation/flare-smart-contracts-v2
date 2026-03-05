// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { TeeExtensionRegistry } from "../../contracts/tee/implementation/TeeExtensionRegistry.sol";
import { TeeOwnerAllowlist } from "../../contracts/tee/implementation/TeeOwnerAllowlist.sol";
import { TeeGovernance } from "../../contracts/tee/implementation/TeeGovernance.sol";
import { TeeFeeCalculator } from "../../contracts/tee/implementation/TeeFeeCalculator.sol";
import { TeeFeeCalculatorProxy } from "../../contracts/tee/proxy/TeeFeeCalculatorProxy.sol";
import { TeeMachineRegistry } from "../../contracts/tee/implementation/TeeMachineRegistry.sol";
import { TeeReplication } from "../../contracts/tee/implementation/TeeReplication.sol";
import { TeeVerification } from "../../contracts/tee/implementation/TeeVerification.sol";
import { TeeSystemStateVerifier } from "../../contracts/tee/implementation/TeeSystemStateVerifier.sol";
import { TeeVersionManager } from "../../contracts/tee/implementation/TeeVersionManager.sol";
import { FtdcVerification } from "../../contracts/ftdc/implementation/FtdcVerification.sol";
import { FtdcVerificationProxy } from "../../contracts/ftdc/proxy/FtdcVerificationProxy.sol";
import { FtdcHub } from "../../contracts/ftdc/implementation/FtdcHub.sol";
import { FtdcHubProxy } from "../../contracts/ftdc/proxy/FtdcHubProxy.sol";
import { FtdcRequestFeeConfigurations } from "../../contracts/ftdc/implementation/FtdcRequestFeeConfigurations.sol";
import { FtdcRequestFeeConfigurationsProxy } from "../../contracts/ftdc/proxy/FtdcRequestFeeConfigurationsProxy.sol";

import { TeeExtensionRegistryProxy } from "../../contracts/tee/proxy/TeeExtensionRegistryProxy.sol";
import { TeeOwnerAllowlistProxy } from "../../contracts/tee/proxy/TeeOwnerAllowlistProxy.sol";
import { TeeGovernanceProxy } from "../../contracts/tee/proxy/TeeGovernanceProxy.sol";
import { TeeMachineRegistryProxy } from "../../contracts/tee/proxy/TeeMachineRegistryProxy.sol";
import { TeeReplicationProxy } from "../../contracts/tee/proxy/TeeReplicationProxy.sol";
import { TeeVerificationProxy } from "../../contracts/tee/proxy/TeeVerificationProxy.sol";
import { TeeSystemStateVerifierProxy } from "../../contracts/tee/proxy/TeeSystemStateVerifierProxy.sol";
import { TeeVersionManagerProxy } from "../../contracts/tee/proxy/TeeVersionManagerProxy.sol";

import { ITeeExtensionRegistry } from "../../contracts/userInterfaces/tee/ITeeExtensionRegistry.sol";
import { ITeeOwnerAllowlist } from "../../contracts/userInterfaces/tee/ITeeOwnerAllowlist.sol";
import { ITeeGovernance } from "../../contracts/userInterfaces/tee/ITeeGovernance.sol";
import { ITeeMachineRegistry } from "../../contracts/userInterfaces/tee/ITeeMachineRegistry.sol";
import { ITeeReplication } from "../../contracts/userInterfaces/tee/ITeeReplication.sol";
import { ITeeVerification } from "../../contracts/userInterfaces/tee/ITeeVerification.sol";
import { IITeeSystemStateVerifier } from "../../contracts/tee/interface/IITeeSystemStateVerifier.sol";
import { ITeeExtensionStateVerifier } from "../../contracts/userInterfaces/tee/ITeeExtensionStateVerifier.sol";
import { ITeeVersionManager } from "../../contracts/userInterfaces/tee/ITeeVersionManager.sol";
import { IFtdcVerification } from "../../contracts/userInterfaces/ftdc/IFtdcVerification.sol";
import { IFtdcHub } from "../../contracts/userInterfaces/ftdc/IFtdcHub.sol";
import { ITeeAvailabilityCheck, TEE_AVAILABILITY_CHECK_ATTESTATION_TYPE }
    from "../../contracts/userInterfaces/ftdc/ITeeAvailabilityCheck.sol";

import { ProtocolsV2Interface } from "../../contracts/userInterfaces/LTS/ProtocolsV2Interface.sol";
import { RandomNumberV2Interface } from "../../contracts/userInterfaces/LTS/RandomNumberV2Interface.sol";
import { IIRewardManager } from "../../contracts/protocol/interface/IIRewardManager.sol";
import { IRelay } from "../../contracts/userInterfaces/IRelay.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

import { PublicKey } from "../../contracts/userInterfaces/IPublicKey.sol";
import { SignatureHelper } from "../utils/SignatureHelper.sol";
import { Signature } from "../../contracts/userInterfaces/ISignature.sol";

// solhint-disable-next-line max-states-count
contract TeeMachineReplicationTest is Test {

    struct Signer {
        address addr;
        uint256 privateKey;
    }

    TeeExtensionRegistry private teeExtensionRegistry;
    TeeOwnerAllowlist private teeOwnerAllowlist;
    TeeGovernance private teeGovernance;
    TeeFeeCalculator private teeFeeCalculatorImpl;
    TeeFeeCalculator private teeFeeCalculator;
    TeeFeeCalculatorProxy private teeFeeCalculatorProxy;
    TeeMachineRegistry private teeMachineRegistry;
    TeeReplication private teeReplication;
    TeeVerification private teeVerification;
    TeeSystemStateVerifier private teeSystemStateVerifier;
    TeeVersionManager private teeVersionManager;
    FtdcHub private ftdcHub;
    FtdcHub private ftdcHubImpl;
    FtdcHubProxy private ftdcHubProxy;
    FtdcVerification private ftdcVerification;
    FtdcVerification private ftdcVerificationImpl;
    FtdcVerificationProxy private ftdcVerificationProxy;
    FtdcRequestFeeConfigurations private ftdcRequestFeeConfigurations;
    FtdcRequestFeeConfigurations private ftdcRequestFeeConfigurationsImpl;
    FtdcRequestFeeConfigurationsProxy private ftdcRequestFeeConfigurationsProxy;

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

        // deploy contracts
        TeeExtensionRegistry teeExtensionRegistryImpl = new TeeExtensionRegistry();
        TeeExtensionRegistryProxy teeExtensionRegistryProxy = new TeeExtensionRegistryProxy(
            governanceSettings,
            initialGovernance,
            addressUpdater,
            address(teeExtensionRegistryImpl)
        );
        teeExtensionRegistry = TeeExtensionRegistry(address(teeExtensionRegistryProxy));

        TeeOwnerAllowlist teeOwnerAllowlistImpl = new TeeOwnerAllowlist();
        TeeOwnerAllowlistProxy teeOwnerAllowlistProxy = new TeeOwnerAllowlistProxy(
            governanceSettings,
            initialGovernance,
            addressUpdater,
            address(teeOwnerAllowlistImpl)
        );
        teeOwnerAllowlist = TeeOwnerAllowlist(address(teeOwnerAllowlistProxy));

        TeeGovernance teeGovernanceImpl = new TeeGovernance();
        TeeGovernanceProxy teeGovernanceProxy = new TeeGovernanceProxy(
            governanceSettings,
            initialGovernance,
            addressUpdater,
            address(teeGovernanceImpl)
        );
        teeGovernance = TeeGovernance(address(teeGovernanceProxy));

        teeFeeCalculatorImpl = new TeeFeeCalculator();
        teeFeeCalculatorProxy = new TeeFeeCalculatorProxy(
            governanceSettings,
            initialGovernance,
            1000,
            address(teeFeeCalculatorImpl)
        );
        teeFeeCalculator = TeeFeeCalculator(address(teeFeeCalculatorProxy));

        TeeMachineRegistry teeMachineRegistryImpl = new TeeMachineRegistry();
        TeeMachineRegistryProxy teeMachineRegistryProxy = new TeeMachineRegistryProxy(
            governanceSettings,
            initialGovernance,
            addressUpdater,
            address(teeMachineRegistryImpl)
        );
        teeMachineRegistry = TeeMachineRegistry(address(teeMachineRegistryProxy));

        TeeReplication teeReplicationImpl = new TeeReplication();
        TeeReplicationProxy teeReplicationProxy = new TeeReplicationProxy(
            governanceSettings,
            initialGovernance,
            addressUpdater,
            600, // 10 minutes
            address(teeReplicationImpl)
        );
        teeReplication = TeeReplication(address(teeReplicationProxy));

        TeeVerification teeVerificationImpl = new TeeVerification();
        TeeVerificationProxy teeVerificationProxy = new TeeVerificationProxy(
            governanceSettings,
            initialGovernance,
            addressUpdater,
            3600,     // 1 hour
            6,      // 6 reward epochs
            600,    // 10 minutes
            address(teeVerificationImpl)
        );
        teeVerification = TeeVerification(address(teeVerificationProxy));

        TeeSystemStateVerifier teeSystemStateVerifierImpl = new TeeSystemStateVerifier();
        TeeSystemStateVerifierProxy teeSystemStateVerifierProxy = new TeeSystemStateVerifierProxy(
            governanceSettings,
            initialGovernance,
            addressUpdater,
            address(teeSystemStateVerifierImpl)
        );
        teeSystemStateVerifier = TeeSystemStateVerifier(address(teeSystemStateVerifierProxy));

        TeeVersionManager teeVersionManagerImpl = new TeeVersionManager();
        TeeVersionManagerProxy teeVersionManagerProxy = new TeeVersionManagerProxy(
            governanceSettings,
            initialGovernance,
            addressUpdater,
            address(teeVersionManagerImpl)
        );
        teeVersionManager = TeeVersionManager(address(teeVersionManagerProxy));

        ftdcHubImpl = new FtdcHub();
        ftdcHubProxy = new FtdcHubProxy(
            IGovernanceSettings(address(this)),
            initialGovernance,
            addressUpdater,
            5000,
            1,
            address(ftdcHubImpl)
        );
        ftdcHub = FtdcHub(address(ftdcHubProxy));

        ftdcVerificationImpl = new FtdcVerification();
        ftdcVerificationProxy = new FtdcVerificationProxy(
            IGovernanceSettings(address(this)),
            initialGovernance,
            addressUpdater,
            address(ftdcVerificationImpl)
        );
        ftdcVerification = FtdcVerification(address(ftdcVerificationProxy));

        ftdcRequestFeeConfigurationsImpl = new FtdcRequestFeeConfigurations();
        ftdcRequestFeeConfigurationsProxy = new FtdcRequestFeeConfigurationsProxy(
            IGovernanceSettings(address(this)),
            initialGovernance,
            address(ftdcRequestFeeConfigurationsImpl)
        );
        ftdcRequestFeeConfigurations = FtdcRequestFeeConfigurations(address(ftdcRequestFeeConfigurationsProxy));

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

        // update contract addresses in all contracts
        bytes32[] memory contractNameHashes = new bytes32[](19);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[2] = keccak256(abi.encode("RewardManager"));
        contractNameHashes[3] = keccak256(abi.encode("Relay"));
        contractNameHashes[4] = keccak256(abi.encode("TeeExtensionRegistry"));
        contractNameHashes[5] = keccak256(abi.encode("TeeOwnerAllowlist"));
        contractNameHashes[6] = keccak256(abi.encode("TeeGovernance"));
        contractNameHashes[7] = keccak256(abi.encode("TeeFeeCalculator"));
        contractNameHashes[8] = keccak256(abi.encode("TeeMachineRegistry"));
        contractNameHashes[9] = keccak256(abi.encode("TeeReplication"));
        contractNameHashes[10] = keccak256(abi.encode("TeeVerification"));
        contractNameHashes[11] = keccak256(abi.encode("TeeSystemStateVerifier"));
        contractNameHashes[12] = keccak256(abi.encode("TeeVersionManager"));
        contractNameHashes[13] = keccak256(abi.encode("TeeWalletProjectManager"));
        contractNameHashes[14] = keccak256(abi.encode("TeeWalletManager"));
        contractNameHashes[15] = keccak256(abi.encode("TeeWalletKeyManager"));
        contractNameHashes[16] = keccak256(abi.encode("FtdcHub"));
        contractNameHashes[17] = keccak256(abi.encode("FtdcVerification"));
        contractNameHashes[18] = keccak256(abi.encode("FtdcRequestFeeConfigurations"));

        address[] memory contractAddresses = new address[](19);
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = flareSystemsManager;
        contractAddresses[2] = rewardManager;
        contractAddresses[3] = relay;
        contractAddresses[4] = address(teeExtensionRegistry);
        contractAddresses[5] = address(teeOwnerAllowlist);
        contractAddresses[6] = address(teeGovernance);
        contractAddresses[7] = address(teeFeeCalculator);
        contractAddresses[8] = address(teeMachineRegistry);
        contractAddresses[9] = address(teeReplication);
        contractAddresses[10] = address(teeVerification);
        contractAddresses[11] = address(teeSystemStateVerifier);
        contractAddresses[12] = address(teeVersionManager);
        contractAddresses[13] = makeAddr("TeeWalletProjectManager");
        contractAddresses[14] = makeAddr("TeeWalletManager");
        contractAddresses[15] = makeAddr("TeeWalletKeyManager");
        contractAddresses[16] = address(ftdcHub);
        contractAddresses[17] = address(ftdcVerification);
        contractAddresses[18] = address(ftdcRequestFeeConfigurations);

        vm.startPrank(addressUpdater);
        teeExtensionRegistry.updateContractAddresses(contractNameHashes, contractAddresses);
        teeOwnerAllowlist.updateContractAddresses(contractNameHashes, contractAddresses);
        teeGovernance.updateContractAddresses(contractNameHashes, contractAddresses);
        teeMachineRegistry.updateContractAddresses(contractNameHashes, contractAddresses);
        teeReplication.updateContractAddresses(contractNameHashes, contractAddresses);
        teeVerification.updateContractAddresses(contractNameHashes, contractAddresses);
        teeSystemStateVerifier.updateContractAddresses(contractNameHashes, contractAddresses);
        teeVersionManager.updateContractAddresses(contractNameHashes, contractAddresses);
        ftdcVerification.updateContractAddresses(contractNameHashes, contractAddresses);
        ftdcHub.updateContractAddresses(contractNameHashes, contractAddresses);
        vm.stopPrank();

        vm.startPrank(initialGovernance);
        // register system instructions senders
        address[] memory systemInstructionsSenders = new address[](3);
        systemInstructionsSenders[0] = address(teeReplication);
        systemInstructionsSenders[1] = address(teeVerification);
        systemInstructionsSenders[2] = address(ftdcHub);
        teeExtensionRegistry.registerSystemInstructionsSenders(systemInstructionsSenders);

        // add supported platforms
        teeExtensionRegistry.addSystemSupportedPlatforms(platforms2);

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
        teeFeeCalculator.setOperationFees(opTypes, opCommands, fees);

        // set ftdc fees
        ftdcRequestFeeConfigurations.setTypeAndSourceFee(
            TEE_AVAILABILITY_CHECK_ATTESTATION_TYPE,
            teeVerification.TEE_SOURCE_ID(),
            50
        );

        // set cosigners
        teeVerification.setCosigners(_getSignersAddresses(cosigners), cosignersThreshold);
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
        vm.prank(extensionOwner);
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeExtensionRegistered(1, extensionOwner);
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeExtensionContractsSet(
            1,
            verifier,
            instructionsSender
        );
        extensionId = teeExtensionRegistry.register(verifier, instructionsSender);
        assertEq(extensionId, 1);
        assertEq(teeExtensionRegistry.getExtensionOwner(extensionId), extensionOwner);
        assertEq(address(teeExtensionRegistry.getTeeExtensionStateVerifier(extensionId)), address(0));
        assertEq(teeExtensionRegistry.getTeeExtensionInstructionsSender(extensionId), instructionsSender);
    }

    function testSetGovernanceHash() public {
        testRegisterNewTeeExtension();
        _setGovernanceHash(governanceHash1, governanceSigners1, governanceSignersThreshold1);
    }

    function testAddTeeVersion() public {
        testSetGovernanceHash();
        _addTeeVersion("v1.0.0", codeHash1, platforms1, governanceHash1);
    }

    function testAddAllowedTeeMachineOwners() public {
        testAddTeeVersion();
        address[] memory teeMachineOwners = new address[](1);
        teeMachineOwners[0] = teeMachineOwner;
        vm.prank(extensionOwner);
        vm.expectEmit();
        emit ITeeOwnerAllowlist.AllowedTeeMachineOwnersAdded(extensionId, teeMachineOwners);
        teeOwnerAllowlist.addAllowedTeeMachineOwners(extensionId, teeMachineOwners);
        assertTrue(teeOwnerAllowlist.isAllowedTeeMachineOwner(extensionId, teeMachineOwner));
        address[] memory owners = teeOwnerAllowlist.getAllowedTeeMachineOwners(extensionId);
        assertEq(owners.length, 1);
        assertEq(owners[0], teeMachineOwner);
    }

    function testRegisterTeeMachine() public {
        testAddAllowedTeeMachineOwners();
        vm.prank(teeMachineOwner);
        vm.expectEmit();
        emit ITeeMachineRegistry.TeeMachineRegistered(
            teeId, teeProxyId, teeMachineOwner, extensionId, teeUrl, codeHash1, platforms1[0]
        );

        ITeeMachineRegistry.TeeMachineData memory teeMachineData = ITeeMachineRegistry.TeeMachineData({
            extensionId: extensionId,
            publicKey: teePublicKey,
            initialOwner: teeMachineOwner,
            codeHash: codeHash1,
            platform: platforms1[0]
        });
        Signature memory signature = SignatureHelper.createSignature(
            vm,
            keccak256(abi.encode(teeMachineData)),
            teePrivateKey
        );
        teeMachineRegistry.register{value: 150}(
            teeMachineData,
            signature,
            teeProxyId,
            teeUrl
        );
    }

    function testPutTeeMachineToProduction() public {
        testRegisterTeeMachine();

        IFtdcHub.FtdcResponseHeader memory header = IFtdcHub.FtdcResponseHeader(
            TEE_AVAILABILITY_CHECK_ATTESTATION_TYPE,
            teeVerification.TEE_SOURCE_ID(),
            0,
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
        IITeeSystemStateVerifier.TeeSystemState memory systemState = IITeeSystemStateVerifier.TeeSystemState(
            IITeeSystemStateVerifier.TeeMachineStatus.ACTIVE,
            teeId,
            governanceHash1
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

        bytes32 messageHash = keccak256(abi.encode(
            keccak256(abi.encode(header)),
            keccak256(abi.encode(reqBody)),
            keccak256(abi.encode(respBody))
        ));
        bytes32 cosignersMessageHash = keccak256(bytes.concat(hex"010000000000", messageHash));

        IFtdcVerification.FtdcSignatures memory sigs;
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
        emit ITeeMachineRegistry.TeeMachineStatusChanged(teeId, ITeeMachineRegistry.TeeStatus.PRODUCTION);
        teeMachineRegistry.toProduction(proof);
        assert(teeMachineRegistry.getTeeMachineStatus(teeId) == ITeeMachineRegistry.TeeStatus.PRODUCTION);
    }

    function testAddNewTeeVersion() public {
        testPutTeeMachineToProduction();
        _setGovernanceHash(governanceHash2, governanceSigners2, governanceSignersThreshold2);
        _addTeeVersion("v2.0.0", codeHash2, platforms2, governanceHash2);
    }

    function testCreateNewTeeUpgrade() public {
        testAddNewTeeVersion();
        vm.prank(extensionOwner);
        vm.expectEmit();
        emit ITeeVersionManager.TeeUpgradeStarted(extensionId, 0, governanceHash1, governanceHash2);
        teeVersionManager.createNewTeeUpgrade(extensionId, governanceHash1, governanceHash2);
        assertEq(teeVersionManager.getTeeUpgradesCount(), 1);
        assertFalse(teeVersionManager.isTeeUpgradeFinalized(0));
        assertFalse(teeVersionManager.isTeeUpgradeSigned(0));
    }

    function testAddTeeUpgradePaths() public {
        testCreateNewTeeUpgrade();
        ITeeVersionManager.TeeUpgradePath[] memory upgradePaths = new ITeeVersionManager.TeeUpgradePath[](1);
        ITeeVersionManager.TeeNodeVersion[] memory sourceVersions = new ITeeVersionManager.TeeNodeVersion[](2);
        sourceVersions[0] = ITeeVersionManager.TeeNodeVersion(codeHash1, platforms1[0]);
        sourceVersions[1] = ITeeVersionManager.TeeNodeVersion(codeHash1, platforms1[1]);
        ITeeVersionManager.TeeNodeVersion[] memory targetVersions = new ITeeVersionManager.TeeNodeVersion[](2);
        targetVersions[0] = ITeeVersionManager.TeeNodeVersion(codeHash2, platforms2[0]);
        targetVersions[1] = ITeeVersionManager.TeeNodeVersion(codeHash2, platforms2[1]);
        upgradePaths[0] = ITeeVersionManager.TeeUpgradePath(sourceVersions, targetVersions);
        vm.prank(extensionOwner);
        vm.expectEmit();
        emit ITeeVersionManager.TeeUpgradePathsAdded(0, upgradePaths);
        teeVersionManager.addTeeUpgradePaths(0, upgradePaths);
    }

    function testFinalizeTeeUpgrade() public {
        testAddTeeUpgradePaths();
        vm.prank(extensionOwner);
        vm.expectEmit();
        emit ITeeVersionManager.TeeUpgradeFinalized(0);
        teeVersionManager.finalizeTeeUpgrade(0);
        assertTrue(teeVersionManager.isTeeUpgradeFinalized(0));
        assertFalse(teeVersionManager.isTeeUpgradeSigned(0));
    }

    function testSignTeeUpgrade() public {
        testFinalizeTeeUpgrade();
        bytes32 messageHash = keccak256(abi.encode(teeVersionManager.getTeeUpgradePaths(0)));
        for (uint256 i = 0; i < governanceSignersThreshold1; i++) {
            Signature memory signature =
                SignatureHelper.createSignature(vm, messageHash, governanceSigners1[i].privateKey);
            teeVersionManager.signTeeUpgrade(0, signature);
        }
        for (uint256 i = 0; i < governanceSignersThreshold2; i++) {
            Signature memory signature =
                SignatureHelper.createSignature(vm, messageHash, governanceSigners2[i].privateKey);
            if (i == governanceSignersThreshold2 - 1) {
                vm.expectEmit();
                emit ITeeVersionManager.TeeUpgradeSigned(0);
            }
            teeVersionManager.signTeeUpgrade(0, signature);
        }
        assertTrue(teeVersionManager.isTeeUpgradeSigned(0));
    }

    function testPauseTeeMachine() public {
        testSignTeeUpgrade();
        vm.prank(teeMachineOwner);
        vm.expectEmit();
        emit ITeeMachineRegistry.TeeMachineStatusChanged(teeId, ITeeMachineRegistry.TeeStatus.PAUSED);
        teeMachineRegistry.pause(teeId);
        assert(teeMachineRegistry.getTeeMachineStatus(teeId) == ITeeMachineRegistry.TeeStatus.PAUSED);
    }

    function testPutTeeMachineToPauseForUpgrade() public {
        testPauseTeeMachine();
        vm.warp(block.timestamp + 1000);
        vm.prank(teeMachineOwner);
        vm.expectEmit();
        emit ITeeMachineRegistry.TeeMachineStatusChanged(teeId, ITeeMachineRegistry.TeeStatus.PAUSED_FOR_UPGRADE);
        teeReplication.toPauseForUpgrade{value: 200}(teeId);
        assert(teeMachineRegistry.getTeeMachineStatus(teeId) == ITeeMachineRegistry.TeeStatus.PAUSED_FOR_UPGRADE);
    }

    function testRegisterNewTeeMachine() public {
        testPutTeeMachineToPauseForUpgrade();
        vm.prank(teeMachineOwner);
        vm.expectEmit();
        emit ITeeMachineRegistry.TeeMachineRegistered(
            newTeeId, newTeeProxyId, teeMachineOwner, extensionId, newTeeUrl, codeHash2, platforms2[1]
        );

        ITeeMachineRegistry.TeeMachineData memory newTeeMachineData = ITeeMachineRegistry.TeeMachineData({
            extensionId: extensionId,
            publicKey: newTeePublicKey,
            initialOwner: teeMachineOwner,
            codeHash: codeHash2,
            platform: platforms2[1]
        });
        Signature memory signature = SignatureHelper.createSignature(
            vm,
            keccak256(abi.encode(newTeeMachineData)),
            newTeePrivateKey
        );
        teeMachineRegistry.register{value: 150}(
            newTeeMachineData,
            signature,
            newTeeProxyId,
            newTeeUrl
        );
    }

    function testReplicateFromTeeMachine() public {
        testRegisterNewTeeMachine();

        // update current reward epoch id
        vm.mockCall(
            flareSystemsManager,
            abi.encodeWithSelector(ProtocolsV2Interface.getCurrentRewardEpochId.selector),
            abi.encode(2)
        );

        IFtdcHub.FtdcResponseHeader memory header = IFtdcHub.FtdcResponseHeader(
            TEE_AVAILABILITY_CHECK_ATTESTATION_TYPE,
            teeVerification.TEE_SOURCE_ID(),
            0,
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
        IITeeSystemStateVerifier.TeeSystemState memory systemState = IITeeSystemStateVerifier.TeeSystemState(
            IITeeSystemStateVerifier.TeeMachineStatus.ACTIVE,
            newTeeId,
            governanceHash2
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

        bytes32 messageHash = keccak256(abi.encode(
            keccak256(abi.encode(header)),
            keccak256(abi.encode(reqBody)),
            keccak256(abi.encode(respBody))
        ));
        bytes32 cosignersMessageHash = keccak256(bytes.concat(hex"010000000000", messageHash));

        IFtdcVerification.FtdcSignatures memory sigs;
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
        emit ITeeReplication.TeeMachineReplicationTriggered(teeId, newTeeId, 0);
        teeReplication.replicateFrom{value: 600}(teeId, proof, 0);
        assert(teeMachineRegistry.getTeeMachineStatus(newTeeId) == ITeeMachineRegistry.TeeStatus.REPLICATING);
    }

    function testRequestTeeAttestation() public {
        testReplicateFromTeeMachine();
        bytes32 challenge = keccak256(abi.encode(teeId, block.timestamp, randomNumber));
        vm.expectEmit();
        emit ITeeVerification.TeeAttestationRequested(teeId, challenge);
        teeVerification.requestTeeAttestation{value: 150}(teeId);
    }

    function testConfirmReplicate() public {
        testRequestTeeAttestation();

        IFtdcHub.FtdcResponseHeader memory header = IFtdcHub.FtdcResponseHeader(
            TEE_AVAILABILITY_CHECK_ATTESTATION_TYPE,
            teeVerification.TEE_SOURCE_ID(),
            0,
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
        IITeeSystemStateVerifier.TeeSystemState memory systemState = IITeeSystemStateVerifier.TeeSystemState(
            IITeeSystemStateVerifier.TeeMachineStatus.ACTIVE,
            newTeeId,
            governanceHash2
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

        bytes32 messageHash = keccak256(abi.encode(
            keccak256(abi.encode(header)),
            keccak256(abi.encode(reqBody)),
            keccak256(abi.encode(respBody))
        ));
        bytes32 cosignersMessageHash = keccak256(bytes.concat(hex"010000000000", messageHash));

        IFtdcVerification.FtdcSignatures memory sigs;
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
        emit ITeeReplication.TeeMachineReplicationConfirmed(teeId, newTeeId);
        teeReplication.confirmReplicate(newTeeId, proof);
        assert(teeMachineRegistry.getTeeMachineStatus(teeId) == ITeeMachineRegistry.TeeStatus.PRODUCTION);
        vm.expectRevert(ITeeMachineRegistry.TeeNotFound.selector);
        teeMachineRegistry.getTeeMachineStatus(newTeeId);
    }

    function _setGovernanceHash(bytes32 _governanceHash, Signer[] memory _signers, uint64 _threshold) internal {
        address[] memory signers = _getSignersAddresses(_signers);
        vm.prank(extensionOwner);
        vm.expectEmit();
        emit ITeeGovernance.NewTeeGovernanceSet(extensionId, _governanceHash, signers, _threshold);
        teeGovernance.setNewTeeGovernance(extensionId, signers, _threshold);
        assertEq(teeGovernance.getLatestTeeGovernanceHash(extensionId), _governanceHash);
        assertEq(_governanceHash, keccak256(abi.encode(signers, _threshold)));
        assertEq(teeGovernance.getTeeGovernanceThreshold(extensionId, _governanceHash), _threshold);
    }

    function _addTeeVersion(
        string memory _version,
        bytes32 _codeHash,
        bytes32[] memory _platforms,
        bytes32 _governanceHash
    ) internal {
        vm.prank(extensionOwner);
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeVersionAdded(extensionId, _version, _codeHash, _platforms, _governanceHash);
        teeExtensionRegistry.addTeeVersion(extensionId, _version, _codeHash, _platforms, _governanceHash);
        for (uint256 i = 0; i < _platforms.length; i++) {
            assertTrue(teeExtensionRegistry.isCodeHashPlatformSupported(extensionId, _codeHash, _platforms[i]));
        }
        assertEq(teeExtensionRegistry.getTeeGovernanceHash(extensionId, _codeHash), _governanceHash);
        (bytes32 governanceHash, string memory version, bytes32[] memory platforms) =
            teeExtensionRegistry.getCodeHashInfo(extensionId, _codeHash);
        assertEq(governanceHash, _governanceHash);
        assertEq(keccak256(abi.encodePacked(version)), keccak256(abi.encodePacked(_version)));
        assertEq(platforms.length, _platforms.length);
        for (uint256 i = 0; i < _platforms.length; i++) {
            assertEq(platforms[i], _platforms[i]);
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