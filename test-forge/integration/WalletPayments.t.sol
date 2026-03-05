// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test, console2 } from "forge-std/Test.sol";
import { TeeExtensionRegistry } from "../../contracts/tee/implementation/TeeExtensionRegistry.sol";
import { TeeWalletProjectManager } from "../../contracts/tee/implementation/TeeWalletProjectManager.sol";
import { TeeWalletKeyManager } from "../../contracts/tee/implementation/TeeWalletKeyManager.sol";
import { TeeWalletManager } from "../../contracts/tee/implementation/TeeWalletManager.sol";
import { TeeExtensionRegistryProxy } from "../../contracts/tee/proxy/TeeExtensionRegistryProxy.sol";
import { TeeWalletProjectManagerProxy } from "../../contracts/tee/proxy/TeeWalletProjectManagerProxy.sol";
import { TeeWalletKeyManagerProxy } from "../../contracts/tee/proxy/TeeWalletKeyManagerProxy.sol";
import { TeeWalletManagerProxy } from "../../contracts/tee/proxy/TeeWalletManagerProxy.sol";
import { TeeOwnerAllowlist } from "../../contracts/tee/implementation/TeeOwnerAllowlist.sol";
import { TeeOwnerAllowlistProxy } from "../../contracts/tee/proxy/TeeOwnerAllowlistProxy.sol";
import { TeeFeeCalculator } from "../../contracts/tee/implementation/TeeFeeCalculator.sol";
import { TeeFeeCalculatorProxy } from "../../contracts/tee/proxy/TeeFeeCalculatorProxy.sol";
import { TeePayments } from "../../contracts/tee/implementation/TeePayments.sol";
import { TeePaymentsProxy } from "../../contracts/tee/proxy/TeePaymentsProxy.sol";
import { IIRewardManager } from "../../contracts/protocol/interface/IIRewardManager.sol";
import { IPMWMultisigAccountConfigured } from "../../contracts/userInterfaces/ftdc/IPMWMultisigAccountConfigured.sol";
import { ITeeExtensionStateVerifier } from "../../contracts/userInterfaces/tee/ITeeExtensionStateVerifier.sol";
import { ITeeWalletKeyManager } from "../../contracts/userInterfaces/tee/ITeeWalletKeyManager.sol";
import { ITeeWalletBackupManager } from "../../contracts/userInterfaces/tee/ITeeWalletBackupManager.sol";
import { PublicKey } from "../../contracts/userInterfaces/IPublicKey.sol";
import { Signature } from "../../contracts/userInterfaces/ISignature.sol";
import { ITeeMachineRegistry } from "../../contracts/userInterfaces/tee/ITeeMachineRegistry.sol";
import { ProtocolsV2Interface } from "../../contracts/userInterfaces/LTS/ProtocolsV2Interface.sol";
import { ITeeVerification } from "../../contracts/userInterfaces/tee/ITeeVerification.sol";
import { IFtdcVerification } from "../../contracts/userInterfaces/ftdc/IFtdcVerification.sol";
import { IFtdcHub } from "../../contracts/userInterfaces/ftdc/IFtdcHub.sol";
import { ITeePayments } from "../../contracts/userInterfaces/tee/ITeePayments.sol";
import { ITeeExtensionRegistry } from "../../contracts/userInterfaces/tee/ITeeExtensionRegistry.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

// solhint-disable-next-line max-states-count
contract WalletPaymentsTest is Test {

    TeeExtensionRegistry private teeExtensionRegistry;
    TeeWalletProjectManager private teeWalletProjectManager;
    TeeWalletKeyManager private teeWalletKeyManager;
    TeeWalletManager private teeWalletManager;
    TeeOwnerAllowlist private teeOwnerAllowlist;
    TeePayments private teePayments;
    TeeFeeCalculator private teeFeeCalculatorImpl;

    TeeExtensionRegistry private teeExtensionRegistryImpl;
    TeeWalletProjectManager private teeWalletProjectManagerImpl;
    TeeWalletKeyManager private teeWalletKeyManagerImpl;
    TeeWalletManager private teeWalletManagerImpl;
    TeeOwnerAllowlist private teeOwnerAllowlistImpl;
    TeePayments private teePaymentsImpl;
    TeeFeeCalculator private teeFeeCalculator;

    TeeExtensionRegistryProxy private teeExtensionRegistryProxy;
    TeeWalletProjectManagerProxy private teeWalletProjectManagerProxy;
    TeeWalletKeyManagerProxy private teeWalletKeyManagerProxy;
    TeeWalletManagerProxy private teeWalletManagerProxy;
    TeeOwnerAllowlistProxy private teeOwnerAllowlistProxy;
    TeePaymentsProxy private teePaymentsProxy;
    TeeFeeCalculatorProxy private teeFeeCalculatorProxy;

    address private teeVerification = makeAddr("TeeVerification"); // TODO deploy the actual contract?

    address private governance;
    address private addressUpdater;
    address private teeGovernanceMock;
    address private teeMachineRegistryMock;
    address private flareSystemsManagerMock;
    address private rewardManagerMock;
    address private teeWalletBackupManagerMock;

    bytes32 private projectId;
    bytes32 private opType;
    address private authorizationAddress;
    address private teeId1;
    address private teeId2;
    ITeeMachineRegistry.TeeMachine private teeMachine1;
    ITeeMachineRegistry.TeeMachine private teeMachine2;
    uint256 private privateKey1;
    uint256 private privateKey2;
    bytes32 private walletId;
    address private projectOwner;
    bytes private opTypeConstants;
    uint64 private keyId;
    ITeeWalletKeyManager.KeyExistence private keyExistenceProof;
    address[] private pausingAddresses;
    address[] private cosigners;
    ITeeWalletBackupManager.BackupId private backupId;
    uint256 private defaultFee;

    // tee payments
    bytes32 constant private XRP_OP_TYPE = bytes32("F_XRP");
    bytes32 constant private XRP_KEY_TYPE = bytes32("XRP_KEY");
    bytes32 constant private XRP_SIGNING_ALGO = bytes32("XRP_SIGNING_ALGO");
    bytes32 constant private XRP_SOURCE_ID = bytes32("XRP");
    string private accountAddress = "rPT1Sjq2YGrBMTttX4GZHjKu9dyfzbpAYe";
    ITeePayments.PMWMultisigAccount private account1;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    function setUp() public {
        opType = keccak256("OP_TYPE");
        authorizationAddress = makeAddr("authorizationAddress");
        pausingAddresses = new address[](1);
        pausingAddresses[0] = makeAddr("pausingAddresses1");
        cosigners = new address[](1);
        cosigners[0] = makeAddr("cosigner1");
        projectOwner = makeAddr("projectOwner");

        governance = makeAddr("governance");
        addressUpdater = makeAddr("AddressUpdater");
        IGovernanceSettings governanceSettings = IGovernanceSettings(makeAddr("governanceSettings"));
        teeGovernanceMock = makeAddr("TeeGovernance");
        teeMachineRegistryMock = makeAddr("TeeMachineRegistry");
        teeWalletBackupManagerMock = makeAddr("TeeWalletBackupManager");
        flareSystemsManagerMock = makeAddr("FlareSystemsManager");
        rewardManagerMock = makeAddr("RewardManager");

        PublicKey[] memory publicKeys = new PublicKey[](1);
        publicKeys[0] = PublicKey(keccak256("1"), keccak256("1"));

        // tee machines
        (teeId1, privateKey1) = makeAddrAndKey("teeId1");
        (teeId2, privateKey2) = makeAddrAndKey("teeId2");
        teeMachine1 = ITeeMachineRegistry.TeeMachine(teeId1, makeAddr("teeProxyId1"), "url1");
        teeMachine2 = ITeeMachineRegistry.TeeMachine(teeId2, makeAddr("teeProxyId2"), "url2");

        account1 = ITeePayments.PMWMultisigAccount({
            sourceId: XRP_SOURCE_ID,
            accountAddress: accountAddress
        });

        teeExtensionRegistryImpl = new TeeExtensionRegistry();
        teeExtensionRegistryProxy = new TeeExtensionRegistryProxy(
            governanceSettings,
            governance,
            addressUpdater,
            address(teeExtensionRegistryImpl)
        );
        teeExtensionRegistry = TeeExtensionRegistry(address(teeExtensionRegistryProxy));

        teeWalletProjectManagerImpl = new TeeWalletProjectManager();
        teeWalletProjectManagerProxy = new TeeWalletProjectManagerProxy(
            governanceSettings,
            governance,
            addressUpdater,
            address(teeWalletProjectManagerImpl)
        );
        teeWalletProjectManager = TeeWalletProjectManager(address(teeWalletProjectManagerProxy));

        teeWalletKeyManagerImpl = new TeeWalletKeyManager();
        teeWalletKeyManagerProxy = new TeeWalletKeyManagerProxy(
            governanceSettings,
            governance,
            addressUpdater,
            address(teeWalletKeyManagerImpl)
        );
        teeWalletKeyManager = TeeWalletKeyManager(address(teeWalletKeyManagerProxy));

        teeWalletManagerImpl = new TeeWalletManager();
        teeWalletManagerProxy = new TeeWalletManagerProxy(
            governanceSettings,
            governance,
            addressUpdater,
            address(teeWalletManagerImpl)
        );
        teeWalletManager = TeeWalletManager(address(teeWalletManagerProxy));

        teeOwnerAllowlistImpl = new TeeOwnerAllowlist();
        teeOwnerAllowlistProxy = new TeeOwnerAllowlistProxy(
            governanceSettings,
            governance,
            addressUpdater,
            address(teeOwnerAllowlistImpl)
        );
        teeOwnerAllowlist = TeeOwnerAllowlist(address(teeOwnerAllowlistProxy));

        defaultFee = 3;
        teeFeeCalculatorImpl = new TeeFeeCalculator();
        teeFeeCalculatorProxy = new TeeFeeCalculatorProxy(
            governanceSettings,
            governance,
            defaultFee,
            address(teeFeeCalculatorImpl)
        );
        teeFeeCalculator = TeeFeeCalculator(address(teeFeeCalculatorProxy));

        bytes32[] memory supportedSourceIds = new bytes32[](1);
        supportedSourceIds[0] = XRP_SOURCE_ID;
        teePaymentsImpl = new TeePayments();
        teePaymentsProxy = new TeePaymentsProxy(
            governanceSettings,
            governance,
            addressUpdater,
            1,
            1,
            XRP_OP_TYPE,
            XRP_KEY_TYPE,
            supportedSourceIds,
            address(teePaymentsImpl)
        );
        teePayments = TeePayments(address(teePaymentsProxy));

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
        contractAddresses[1] = teeGovernanceMock;
        contractAddresses[2] = teeMachineRegistryMock;
        contractAddresses[3] = address(teeFeeCalculator);
        contractAddresses[4] = flareSystemsManagerMock;
        contractAddresses[5] = rewardManagerMock;
        teeExtensionRegistry.updateContractAddresses(contractNameHashes, contractAddresses);

        contractNameHashes = new bytes32[](4);
        contractAddresses = new address[](4);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("TeeExtensionRegistry"));
        contractNameHashes[2] = keccak256(abi.encode("TeeOwnerAllowlist"));
        contractNameHashes[3] = keccak256(abi.encode("TeeWalletManager"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = address(teeExtensionRegistry);
        contractAddresses[2] = address(teeOwnerAllowlist);
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
        contractAddresses[2] = teeMachineRegistryMock;
        contractAddresses[3] = address(teeWalletProjectManager);
        contractAddresses[4] = address(teeWalletKeyManager);
        contractAddresses[5] = flareSystemsManagerMock;
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
        contractAddresses[2] = teeMachineRegistryMock;
        contractAddresses[3] = address(teeWalletProjectManager);
        contractAddresses[4] = address(teeWalletManager);
        contractAddresses[5] = teeWalletBackupManagerMock;
        contractAddresses[6] = flareSystemsManagerMock;
        teeWalletKeyManager.updateContractAddresses(contractNameHashes, contractAddresses);

        contractNameHashes = new bytes32[](2);
        contractAddresses = new address[](2);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("TeeExtensionRegistry"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = address(teeExtensionRegistry);
        teeOwnerAllowlist.updateContractAddresses(contractNameHashes, contractAddresses);


        contractNameHashes = new bytes32[](7);
        contractAddresses = new address[](7);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("TeeWalletProjectManager"));
        contractNameHashes[2] = keccak256(abi.encode("TeeWalletManager"));
        contractNameHashes[3] = keccak256(abi.encode("TeeWalletKeyManager"));
        contractNameHashes[4] = keccak256(abi.encode("TeeVerification"));
        contractNameHashes[5] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[6] = keccak256(abi.encode("TeeExtensionRegistry"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = address(teeWalletProjectManager);
        contractAddresses[2] = address(teeWalletManager);
        contractAddresses[3] = address(teeWalletKeyManager);
        contractAddresses[4] = teeVerification;
        contractAddresses[5] = flareSystemsManagerMock;
        contractAddresses[6] = address(teeExtensionRegistry);
        teePayments.updateContractAddresses(contractNameHashes, contractAddresses);
        vm.stopPrank();

        vm.mockCall(
            teeMachineRegistryMock,
            abi.encodeWithSelector(ITeeMachineRegistry.getTeeMachineStatus.selector),
            abi.encode(ITeeMachineRegistry.TeeStatus.PRODUCTION)
        );

        vm.mockCall(
            teeMachineRegistryMock,
            abi.encodeWithSelector(ITeeMachineRegistry.getExtensionId.selector),
            abi.encode(0)
        );

        vm.mockCall(
            teeMachineRegistryMock,
            abi.encodeWithSelector(ITeeMachineRegistry.getTeeMachine.selector, teeId1),
            abi.encode(teeMachine1)
        );

        vm.mockCall(
            teeMachineRegistryMock,
            abi.encodeWithSelector(ITeeMachineRegistry.getTeeMachine.selector, teeId2),
            abi.encode(teeMachine2)
        );

        vm.mockCall(
            flareSystemsManagerMock,
            abi.encodeWithSelector(ProtocolsV2Interface.getCurrentRewardEpochId.selector),
            abi.encode(13)
        );

        vm.mockCall(
            rewardManagerMock,
            abi.encodeWithSelector(IIRewardManager.receiveRewards.selector),
            abi.encode(1)
        );

        vm.mockCall(
            teeMachineRegistryMock,
            abi.encodeWithSelector(ITeeMachineRegistry.getInitialSigningPolicyId.selector),
            abi.encode(1)
        );

        // fund addresses
        vm.deal(projectOwner, 1 ether);
        vm.deal(authorizationAddress, 1 ether);
    }

    function testExtensionCreation() public {
        // extensionId = 0 is system extension; owner is governance
        vm.startPrank(governance);
        address[] memory systemInstructionsSenders = new address[](4);
        systemInstructionsSenders[0] = address(teeWalletKeyManager);
        systemInstructionsSenders[1] = address(teeWalletManager);
        systemInstructionsSenders[2] = address(teeVerification);
        systemInstructionsSenders[3] = address(teePayments);
        teeExtensionRegistry.registerSystemInstructionsSenders(systemInstructionsSenders);

        // add key types and signing algos
        bytes32[] memory keyTypes = new bytes32[](1);
        keyTypes[0] = XRP_KEY_TYPE;
        bytes32[] memory xrpSigningAlgos = new bytes32[](1);
        xrpSigningAlgos[0] = XRP_SIGNING_ALGO;
        bytes32[][] memory signingAlgos = new bytes32[][](1);
        signingAlgos[0] = xrpSigningAlgos;
        teeExtensionRegistry.addSystemSupportedKeyTypesAndSigningAlgos(keyTypes, signingAlgos);

        // add supported key types for extension 0
        teeExtensionRegistry.addSupportedKeyTypes(0, keyTypes);

        // allowlist project owners
        address[] memory owners = new address[](1);
        owners[0] = projectOwner;
        teeOwnerAllowlist.addAllowedTeeWalletProjectOwners(0, owners);
        vm.stopPrank();

    }

    function testWalletCreation() public {
        testExtensionCreation();
        // create project
        vm.prank(projectOwner);
        projectId = teeWalletProjectManager.createProject(0, XRP_KEY_TYPE, XRP_SIGNING_ALGO);

        // create wallet
        vm.prank(projectOwner);
        walletId = teeWalletManager.createWallet(projectId);

        PublicKey[] memory adminsPublicKeys = new PublicKey[](2);
        adminsPublicKeys[0] = _getRandomPublicKey();
        address admin1 = _getAddress(adminsPublicKeys[0]);
        adminsPublicKeys[1] = _getRandomPublicKey();
        address admin2 = _getAddress(adminsPublicKeys[1]);
        vm.prank(projectOwner);
        teeWalletManager.setAdmins(walletId, adminsPublicKeys, 2);
        vm.prank(admin1);
        teeWalletManager.confirmAdmin(walletId);
        vm.prank(admin2);
        teeWalletManager.confirmAdmin(walletId);

        vm.prank(projectOwner);
        teeWalletManager.setCosigners(walletId, cosigners, 1);
        vm.prank(cosigners[0]);
        teeWalletManager.confirmCosigner(walletId);


        vm.startPrank(projectOwner);
        teeWalletManager.closeWalletInitialization(walletId);
        uint64 keyId1 = teeWalletKeyManager.addKey{value: defaultFee} (teeId1, walletId);
        vm.stopPrank();

        keyExistenceProof.teeId = teeId1;
        keyExistenceProof.walletId = walletId;
        keyExistenceProof.keyId = keyId1;
        keyExistenceProof.nonce = 0;
        keyExistenceProof.keyType = XRP_KEY_TYPE;
        keyExistenceProof.signingAlgo = XRP_SIGNING_ALGO;
        keyExistenceProof.configConstants.adminsPublicKeys.push(adminsPublicKeys[0]);
        keyExistenceProof.configConstants.adminsPublicKeys.push(adminsPublicKeys[1]);
        keyExistenceProof.configConstants.adminsThreshold = 2;
        keyExistenceProof.configConstants.cosigners.push(cosigners[0]);
        keyExistenceProof.configConstants.cosignersThreshold = 1;
        keyExistenceProof.publicKey = abi.encode("publicKey");
        keyExistenceProof.restored = false;
        keyExistenceProof.keyId = keyId;
        keyExistenceProof.settingsVersion = bytes32(0);
        keyExistenceProof.settings = bytes("");
        vm.prank(projectOwner);
        teeWalletKeyManager.confirmKey(keyExistenceProof, _createSignature(privateKey1));

        // add second key
        vm.prank(projectOwner);
        uint64 keyId2 = teeWalletKeyManager.addKey{value: defaultFee}(teeId2, walletId);

        vm.startPrank(projectOwner);
        keyExistenceProof.teeId = teeId2;
        keyExistenceProof.keyId = keyId2;
        keyExistenceProof.nonce = 0;
        teeWalletKeyManager.confirmKey(keyExistenceProof, _createSignature(privateKey2));

        (, uint64[] memory keyIds ,) = teeWalletKeyManager.getWalletKeysInfo(walletId);
        assertEq(keyIds.length, 2, "wrong number of keys");


        teeWalletKeyManager.setMultisigThreshold(walletId, 2);
        teeWalletManager.enableWallet(walletId);
        vm.stopPrank();

        // teeWalletManager.setPausingAddresses(walletId, pausingAddresses);
    }

    function testAddPMWMultisigAccount() public {
        testWalletCreation();

        vm.mockCall(
            teeVerification,
            abi.encodeWithSelector(
                ITeeVerification.verifyPMWMultisigAccountConfiguredProof.selector,
                walletId
            ),
            abi.encode(true)
        );
        bytes[] memory publicKeys = new bytes[](1);
        publicKeys[0] = hex"03D11FBF992FCC3C7326E323687C234866E400229EA81C73EE4D0DBC1AB5DB22D3";
        IPMWMultisigAccountConfigured.Proof memory pmwAccountProof = IPMWMultisigAccountConfigured.Proof({
            signatures: IFtdcVerification.FtdcSignatures({
                signingPolicySignatures: "",
                teeSignatures: new Signature[](0),
                cosignerSignatures: new Signature[](0)
            }),
            header: IFtdcHub.FtdcResponseHeader({
                attestationType: bytes32("PMWMultisigAccountConfigured"),
                sourceId: XRP_SOURCE_ID,
                thresholdBIPS: 0,
                timestamp: uint64(block.timestamp),
                cosigners: new address[](0),
                cosignersThreshold: 0
        }),
            requestBody: IPMWMultisigAccountConfigured.RequestBody({
                accountAddress: accountAddress,
                publicKeys: publicKeys,
                threshold: 2
            }),
            responseBody: IPMWMultisigAccountConfigured.ResponseBody({
                status: IPMWMultisigAccountConfigured.PMWMultisigAccountStatus.OK,
                sequence: 2
            })
        });


        // only wallet owner can add PMW account
        vm.expectRevert(ITeePayments.OnlyWalletOwner.selector);
        teePayments.addPMWMultisigAccount(walletId, pmwAccountProof, authorizationAddress);

        vm.prank(projectOwner);
        teePayments.addPMWMultisigAccount(walletId, pmwAccountProof, authorizationAddress);
        ITeePayments.PMWMultisigAccount[] memory accounts = teePayments.getWalletAccounts(walletId);
        assertEq(accounts.length, 1, "wrong number of accounts");
        assertEq(accounts[0].accountAddress, accountAddress, "wrong account address");
        assertEq(accounts[0].sourceId, XRP_SOURCE_ID, "wrong sourceId");
        assertEq(teePayments.getWalletId(account1), walletId, "wrong walletId");
        // set account settings
        vm.prank(projectOwner);
        teePayments.setBatchSettings(account1, 1, 0);
        (uint64 batchSize, uint64 batchDurationSeconds) = teePayments.getBatchSettings(account1);
        assertEq(batchSize, 1, "wrong batch size");
        assertEq(batchDurationSeconds, 0, "wrong batch duration");

        // sourceId needs to be supported
        pmwAccountProof.header.sourceId = bytes32("NOT_XRP");
        vm.expectRevert(ITeePayments.UnsupportedSourceId.selector);
        vm.prank(projectOwner);
        teePayments.addPMWMultisigAccount(walletId, pmwAccountProof, authorizationAddress);
    }

    function testPay() public {
        testAddPMWMultisigAccount();
        vm.warp(123);
        // set fee for payment
        bytes32[] memory opTypes = new bytes32[](1);
        opTypes[0] = XRP_OP_TYPE;
        bytes32[] memory opCommands = new bytes32[](1);
        opCommands[0] = bytes32("PAY");
        uint256[] memory fees = new uint256[](1);
        fees[0] = 25;
        vm.prank(governance);
        teeFeeCalculator.setOperationFees(opTypes, opCommands, fees);
        string memory recipient = "rJcBbUCtPg7b4Pfou23SgF18yMihWueK5B";
        bytes32 paymentReference = bytes32("paymentReference");
        ITeePayments.PaymentInstruction memory instruction = ITeePayments.PaymentInstruction({
            recipientAddress: recipient,
            tokenId: bytes(""),
            amount: 1000,
            maxFee: 15,
            paymentReference: paymentReference
        });

        // only submit address can submit payment instructions
        vm.expectRevert(ITeePayments.OnlyAuthorizationAddress.selector);
        teePayments.pay(account1, instruction);

        bytes32 instructionId = keccak256(abi.encode(
            XRP_OP_TYPE, bytes32("PAY"), XRP_SOURCE_ID, account1.accountAddress, 2
        ));
        ITeeMachineRegistry.TeeMachine[] memory teeMachines = new ITeeMachineRegistry.TeeMachine[](2);
        teeMachines[0] = teeMachine1;
        teeMachines[1] = teeMachine2;
        ITeePayments.PaymentInstructionMessage memory message = ITeePayments.PaymentInstructionMessage({
            walletId: walletId,
            teeIdKeyIdPairs: teeWalletKeyManager.receivingTeesAndKeys(walletId),
            sourceId: XRP_SOURCE_ID,
            senderAddress: account1.accountAddress,
            recipientAddress: instruction.recipientAddress,
            tokenId: instruction.tokenId,
            amount: instruction.amount,
            maxFee: instruction.maxFee,
            feeSchedule: abi.encodePacked(int16(10000), uint16(0)),
            paymentReference: instruction.paymentReference,
            nonce: 2,
            subNonce: 2,
            batchEndTs: uint64(block.timestamp)
        });

        // if fee too low revert
        vm.expectRevert(ITeeExtensionRegistry.FeeTooLow.selector);
        vm.prank(authorizationAddress);
        teePayments.pay(account1, instruction);

        vm.prank(authorizationAddress);
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            0,
            instructionId,
            13,
            teeMachines,
            XRP_OP_TYPE,
            bytes32("PAY"),
            abi.encode(message),
            cosigners,
            1,
            2 * 25
        );
        teePayments.pay{value: 50} (account1, instruction);
    }

    // payment was not issued
    function testReissueRevert() public {
        testAddPMWMultisigAccount();
        string memory recipient = "rJcBbUCtPg7b4Pfou23SgF18yMihWueK5B";
        bytes32 paymentReference = bytes32("paymentReference");
        ITeePayments.PaymentInstruction memory instruction = ITeePayments.PaymentInstruction({
            recipientAddress: recipient,
            tokenId: bytes(""),
            amount: 1000,
            maxFee: 15,
            paymentReference: paymentReference
        });
        ITeePayments.PaymentInstruction[] memory instructions = new ITeePayments.PaymentInstruction[](1);
        instructions[0] = instruction;
        uint256[] memory fees = new uint256[](1);
        fees[0] = 30;
        int16[][] memory feeFactorScheduleBIPS = new int16[][](1);
        feeFactorScheduleBIPS[0] = new int16[](0);
        uint16[] memory feeDelayScheduleSeconds = new uint16[](0);
        vm.prank(authorizationAddress);
        vm.expectRevert(ITeePayments.BatchHashMismatch.selector);
        teePayments.reissue{value: 50}(
            account1, 0, 0, instructions, fees,
            feeFactorScheduleBIPS, feeDelayScheduleSeconds
        );
    }

    function testReissue() public {
        testPay();
        string memory recipient = "rJcBbUCtPg7b4Pfou23SgF18yMihWueK5B";
        bytes32 paymentReference = bytes32("paymentReference");
        ITeePayments.PaymentInstruction memory instruction = ITeePayments.PaymentInstruction({
            recipientAddress: recipient,
            tokenId: bytes(""),
            amount: 1000,
            maxFee: 15,
            paymentReference: paymentReference
        });
        ITeePayments.PaymentInstruction[] memory instructions = new ITeePayments.PaymentInstruction[](1);
        instructions[0] = instruction;
        uint256[] memory fees = new uint256[](1);
        fees[0] = 30;
        int16[][] memory feeFactorScheduleBIPS = new int16[][](1);
        feeFactorScheduleBIPS[0] = new int16[](0);
        uint16[] memory feeDelayScheduleSeconds = new uint16[](0);

        uint256 reissueNumber = 0;
        bytes32 instructionId = keccak256(abi.encode(
            XRP_OP_TYPE, bytes32("REISSUE"), XRP_SOURCE_ID, account1.accountAddress, 2, reissueNumber
        ));
        ITeeMachineRegistry.TeeMachine[] memory teeMachines = new ITeeMachineRegistry.TeeMachine[](2);
        teeMachines[0] = teeMachine1;
        teeMachines[1] = teeMachine2;
        // move to the end of batch
        vm.warp(block.timestamp + 1);
        ITeePayments.PaymentInstructionMessage memory message = ITeePayments.PaymentInstructionMessage({
            walletId: walletId,
            teeIdKeyIdPairs: teeWalletKeyManager.receivingTeesAndKeys(walletId),
            sourceId: XRP_SOURCE_ID,
            senderAddress: account1.accountAddress,
            recipientAddress: instruction.recipientAddress,
            tokenId: instruction.tokenId,
            amount: instruction.amount,
            maxFee: fees[0],
            feeSchedule: abi.encodePacked(int16(10000), uint16(0)),
            paymentReference: instruction.paymentReference,
            nonce: 2,
            subNonce: 2,
            batchEndTs: uint64(block.timestamp)
        });

        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            0,
            instructionId,
            13,
            teeMachines,
            XRP_OP_TYPE,
            bytes32("REISSUE"),
            abi.encode(message),
            cosigners,
            1,
            60
        );
        vm.prank(authorizationAddress);
        teePayments.reissue{value: 60}(
            account1, 2, 2, instructions, fees,
            feeFactorScheduleBIPS, feeDelayScheduleSeconds
        );
    }

    function _getRandomPublicKey() internal returns (PublicKey memory) {
        // call external script to get random public key coordinates
        string[] memory command1 = new string[](4);
        string[] memory command2 = new string[](5);
        command1[0] = "cast";
        command1[1] = "wallet";
        command1[2] = "new";
        command1[3] = "--json";
        bytes memory result = vm.ffi(command1);
        string memory prKey = vm.parseJsonString(string(result), "[0].private_key");
        command2[0] = "cast";
        command2[1] = "wallet";
        command2[2] = "public-key";
        command2[3] = "--raw-private-key";
        command2[4] = prKey;
        result = vm.ffi(command2);

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
            MessageHashUtils.toEthSignedMessageHash(keccak256(abi.encode(keyExistenceProof)));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_privateKey, signedMessageHash);
        return Signature(v, r, s);
    }
}