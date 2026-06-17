// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { FlareTeeManagerDeployer } from "../utils/FlareTeeManagerDeployer.sol";
import { TeePayments } from "../../contracts/tee/implementation/TeePayments.sol";
import {
    TeePaymentsFeeScheduleManager
} from "../../contracts/tee/implementation/TeePaymentsFeeScheduleManager.sol";
import {
    TeePaymentsFeeScheduleManagerProxy
} from "../../contracts/tee/proxy/TeePaymentsFeeScheduleManagerProxy.sol";
import { TeePaymentsRegistry } from "../../contracts/tee/implementation/TeePaymentsRegistry.sol";
import { TeePaymentsRegistryProxy } from "../../contracts/tee/proxy/TeePaymentsRegistryProxy.sol";
import { TeePaymentsProxy } from "../../contracts/tee/proxy/TeePaymentsProxy.sol";
import {
    ITeePaymentsFeeScheduleManager
} from "../../contracts/userInterfaces/tee/ITeePaymentsFeeScheduleManager.sol";
import { ITeePaymentsRegistry } from "../../contracts/userInterfaces/tee/ITeePaymentsRegistry.sol";
import { IDiamondCut } from "../../contracts/diamond/interfaces/IDiamondCut.sol";
import { IDiamond } from "../../contracts/diamond/interfaces/IDiamond.sol";
import { IIFlareTeeManager } from "../../contracts/tee/interface/IIFlareTeeManager.sol";
import { IInstructions } from "../../contracts/userInterfaces/tee/IInstructions.sol";
import { IWalletKeyManager, TEE_KEY_EXISTENCE } from "../../contracts/userInterfaces/tee/IWalletKeyManager.sol";
import { SignedPayload } from "../../contracts/utils/lib/SignedPayload.sol";
import { IWalletBackupManager } from "../../contracts/userInterfaces/tee/IWalletBackupManager.sol";
import { IMachineManager } from "../../contracts/userInterfaces/tee/IMachineManager.sol";
import { ITeePayments } from "../../contracts/userInterfaces/tee/ITeePayments.sol";
import { ITeePaymentsBase } from "../../contracts/userInterfaces/tee/ITeePaymentsBase.sol";
import {
    ITeePaymentsConfigVerifier
} from "../../contracts/userInterfaces/tee/ITeePaymentsConfigVerifier.sol";
import { ITeePaymentsModel, PaymentModel } from "../../contracts/userInterfaces/tee/ITeePaymentsModel.sol";
import { IIRewardManager } from "../../contracts/protocol/interface/IIRewardManager.sol";
import { IPMWMultisigAccountConfigured } from "../../contracts/userInterfaces/fdc2/IPMWMultisigAccountConfigured.sol";
import { PublicKey } from "../../contracts/userInterfaces/IPublicKey.sol";
import { Signature } from "../../contracts/userInterfaces/ISignature.sol";
import { ProtocolsV2Interface } from "../../contracts/userInterfaces/LTS/ProtocolsV2Interface.sol";
import { IFdc2Verification } from "../../contracts/userInterfaces/fdc2/IFdc2Verification.sol";
import { IFdc2Hub } from "../../contracts/userInterfaces/fdc2/IFdc2Hub.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { MachineManager } from "../../contracts/tee/library/MachineManager.sol";

/**
 * Helper init contract to inject TEE machine state directly into Diamond storage.
 * Used by the test to bypass the full registration/attestation flow.
 */
contract TestMachineInit {
    function initMachine(
        address _teeId,
        address _owner,
        address _teeProxyId,
        string calldata _url,
        uint256 _extensionId
    )
        external
    {
        MachineManager.State storage state = MachineManager.getState();
        MachineManager.TeeMachineState storage m = state.teeMachineStates[_teeId];
        m.owner = _owner;
        m.teeProxyId = _teeProxyId;
        m.url = _url;
        m.extensionId = _extensionId;
        m.status = IMachineManager.TeeStatus.PRODUCTION;
        m.initialTeeId = _teeId;
    }
}

// solhint-disable-next-line max-states-count
contract WalletPaymentsTest is Test {

    // tee payments
    bytes32 constant private XRP_OP_TYPE = bytes32("F_XRP");
    bytes32 constant private XRP_KEY_TYPE = bytes32("XRP_KEY");
    bytes32 constant private XRP_SIGNING_ALGO = bytes32("XRP_SIGNING_ALGO");
    bytes32 constant private XRP_SOURCE_ID = bytes32("XRP");

    IIFlareTeeManager private flareTeeManager;

    TeePayments private teePayments;
    TeePaymentsFeeScheduleManager private teePaymentsFeeScheduleManager;
    TeePaymentsRegistry private teePaymentsRegistry;

    address private governance;
    address private addressUpdater;
    address private flareSystemsManagerMock;
    address private rewardManagerMock;
    address private relayMock;
    address private fdc2HubMock;
    address private fdc2VerificationMock;
    address private teePaymentsConfigVerifierMock;

    bytes32 private projectId;
    bytes32 private opType;
    address private authorizationAddress;
    address private teeId1;
    address private teeId2;
    IMachineManager.TeeMachine private teeMachine1;
    IMachineManager.TeeMachine private teeMachine2;
    uint256 private privateKey1;
    uint256 private privateKey2;
    bytes32 private walletId;
    address private projectOwner;
    bytes private opTypeConstants;
    uint64 private keyId;
    IWalletKeyManager.KeyExistence private keyExistenceProof;
    address[] private pausingAddresses;
    address[] private cosigners;
    IWalletBackupManager.BackupId private backupId;
    uint256 private defaultFee;

    string private accountAddress = "rPT1Sjq2YGrBMTttX4GZHjKu9dyfzbpAYe";
    ITeePaymentsBase.PMWMultisigAccount private account1;

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
        flareSystemsManagerMock = makeAddr("FlareSystemsManager");
        rewardManagerMock = makeAddr("RewardManager");
        relayMock = makeAddr("Relay");
        fdc2HubMock = makeAddr("Fdc2Hub");
        fdc2VerificationMock = makeAddr("Fdc2Verification");
        teePaymentsConfigVerifierMock = makeAddr("TeePaymentsConfigVerifier");

        PublicKey[] memory publicKeys = new PublicKey[](1);
        publicKeys[0] = PublicKey(keccak256("1"), keccak256("1"));

        // tee machines
        (teeId1, privateKey1) = makeAddrAndKey("teeId1");
        (teeId2, privateKey2) = makeAddrAndKey("teeId2");
        teeMachine1 = IMachineManager.TeeMachine(teeId1, makeAddr("teeProxyId1"), "url1");
        teeMachine2 = IMachineManager.TeeMachine(teeId2, makeAddr("teeProxyId2"), "url2");

        account1 = ITeePaymentsBase.PMWMultisigAccount({
            sourceId: XRP_SOURCE_ID,
            accountAddress: accountAddress
        });

        defaultFee = 3;
        flareTeeManager = FlareTeeManagerDeployer.deployDay1Facets(FlareTeeManagerDeployer.Day1DeployParams({
            governanceSettings: governanceSettings,
            initialGovernance: governance,
            addressUpdater: addressUpdater,
            availabilityCheckValidityDurationSeconds: 3600,
            signingPolicyValidityDurationInRewardEpochs: 10,
            challengeValidityDurationSeconds: 600,
            defaultFee: defaultFee,
            publicExtensionCreationEnabled: true,
            emergencyUnpauseGracePeriodSeconds: 7200
        }));
        vm.startPrank(governance);
        FlareTeeManagerDeployer.deployLaterFacets(flareTeeManager, FlareTeeManagerDeployer.LaterDeployParams({
            pauseBeforeUpgradeMinDurationSeconds: 600
        }));
        vm.stopPrank();

        // =====================================================================
        // Deploy TeePayments (separate UUPS proxy)
        // =====================================================================

        // Deploy shared fee schedule registry first (resolved by TeePayments via AddressUpdater)
        TeePaymentsFeeScheduleManager feeMgrImpl = new TeePaymentsFeeScheduleManager();
        TeePaymentsFeeScheduleManagerProxy feeMgrProxy = new TeePaymentsFeeScheduleManagerProxy(
            governanceSettings,
            governance,
            addressUpdater,
            address(feeMgrImpl)
        );
        teePaymentsFeeScheduleManager = TeePaymentsFeeScheduleManager(address(feeMgrProxy));

        // Deploy TeePaymentsRegistry (resolved by TeePayments via AddressUpdater)
        TeePaymentsRegistry registryImpl = new TeePaymentsRegistry();
        TeePaymentsRegistryProxy registryProxy = new TeePaymentsRegistryProxy(
            governanceSettings,
            governance,
            addressUpdater,
            address(registryImpl)
        );
        teePaymentsRegistry = TeePaymentsRegistry(address(registryProxy));

        TeePayments teePaymentsImpl = new TeePayments();
        TeePaymentsProxy teePaymentsProxy = new TeePaymentsProxy(
            governanceSettings,
            governance,
            addressUpdater,
            address(teePaymentsImpl)
        );
        teePayments = TeePayments(address(teePaymentsProxy));

        // Register sourceId -> TeePayments (account model) in the registry
        ITeePaymentsRegistry.SourceRegistration[] memory regs =
            new ITeePaymentsRegistry.SourceRegistration[](1);
        regs[0] = ITeePaymentsRegistry.SourceRegistration({
            keyType: XRP_KEY_TYPE,
            opType: XRP_OP_TYPE,
            paymentModel: PaymentModel.ACCOUNT,
            sourceId: XRP_SOURCE_ID,
            teePayments: address(teePayments)
        });
        vm.prank(governance);
        teePaymentsRegistry.registerSources(regs);

        // =====================================================================
        // Update contract addresses
        // =====================================================================

        // FlareTeeManager Diamond: ExternalAddressesFacet resolves
        //   FlareSystemsManager, RewardManager, Relay, Fdc2Hub, Fdc2Verification
        vm.startPrank(addressUpdater);
        contractNameHashes = new bytes32[](6);
        contractAddresses = new address[](6);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[2] = keccak256(abi.encode("RewardManager"));
        contractNameHashes[3] = keccak256(abi.encode("Relay"));
        contractNameHashes[4] = keccak256(abi.encode("Fdc2Hub"));
        contractNameHashes[5] = keccak256(abi.encode("Fdc2Verification"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = flareSystemsManagerMock;
        contractAddresses[2] = rewardManagerMock;
        contractAddresses[3] = relayMock;
        contractAddresses[4] = fdc2HubMock;
        contractAddresses[5] = fdc2VerificationMock;
        flareTeeManager.updateContractAddresses(
            contractNameHashes, contractAddresses
        );

        // TeePayments resolves: AddressUpdater, FlareTeeManager, FlareSystemsManager,
        // TeePaymentsFeeScheduleManager, TeePaymentsRegistry, TeePaymentsConfigVerifier
        contractNameHashes = new bytes32[](6);
        contractAddresses = new address[](6);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("FlareTeeManager"));
        contractNameHashes[2] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[3] = keccak256(abi.encode("TeePaymentsFeeScheduleManager"));
        contractNameHashes[4] = keccak256(abi.encode("TeePaymentsRegistry"));
        contractNameHashes[5] = keccak256(abi.encode("TeePaymentsConfigVerifier"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = address(flareTeeManager);
        contractAddresses[2] = flareSystemsManagerMock;
        contractAddresses[3] = address(teePaymentsFeeScheduleManager);
        contractAddresses[4] = address(teePaymentsRegistry);
        contractAddresses[5] = teePaymentsConfigVerifierMock;
        teePayments.updateContractAddresses(contractNameHashes, contractAddresses);

        // TeePaymentsFeeScheduleManager resolves: AddressUpdater, FlareTeeManager, TeePaymentsRegistry
        contractNameHashes = new bytes32[](3);
        contractAddresses = new address[](3);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("FlareTeeManager"));
        contractNameHashes[2] = keccak256(abi.encode("TeePaymentsRegistry"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = address(flareTeeManager);
        contractAddresses[2] = address(teePaymentsRegistry);
        teePaymentsFeeScheduleManager.updateContractAddresses(contractNameHashes, contractAddresses);
        vm.stopPrank();

        // Configure source limits so custom fee schedules can be validated if used
        ITeePaymentsFeeScheduleManager.FeeScheduleConfigInput[] memory feeConfigInputs =
            new ITeePaymentsFeeScheduleManager.FeeScheduleConfigInput[](1);
        feeConfigInputs[0] = ITeePaymentsFeeScheduleManager.FeeScheduleConfigInput(65535, 10, XRP_SOURCE_ID);
        vm.prank(governance);
        teePaymentsFeeScheduleManager.setFeeScheduleConfigs(feeConfigInputs);

        // =====================================================================
        // Inject TEE machine state directly into Diamond storage
        // (vm.mockCall can't intercept internal library calls within the Diamond)
        // =====================================================================
        {
            TestMachineInit machineInit = new TestMachineInit();
            IDiamond.FacetCut[] memory emptyCuts = new IDiamond.FacetCut[](0);
            vm.prank(governance);
            IDiamondCut(address(flareTeeManager)).diamondCut(
                emptyCuts,
                address(machineInit),
                abi.encodeCall(TestMachineInit.initMachine, (
                    teeId1, makeAddr("teeOwner1"), teeMachine1.teeProxyId, teeMachine1.url, 0
                ))
            );
            vm.prank(governance);
            IDiamondCut(address(flareTeeManager)).diamondCut(
                emptyCuts,
                address(machineInit),
                abi.encodeCall(TestMachineInit.initMachine, (
                    teeId2, makeAddr("teeOwner2"), teeMachine2.teeProxyId, teeMachine2.url, 0
                ))
            );
        }

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

        // fund addresses
        vm.deal(projectOwner, 1 ether);
        vm.deal(authorizationAddress, 1 ether);
    }

    function testExtensionCreation() public {
        // extensionId = 0 is system extension; owner is governance
        vm.startPrank(governance);
        // Only TeePayments needs registering — Diamond facets use internal library calls
        address[] memory systemInstructionsSenders = new address[](1);
        systemInstructionsSenders[0] = address(teePayments);
        flareTeeManager.registerSystemInstructionsSenders(systemInstructionsSenders);

        // add key types and signing algos
        bytes32[] memory keyTypes = new bytes32[](1);
        keyTypes[0] = XRP_KEY_TYPE;
        bytes32[] memory xrpSigningAlgos = new bytes32[](1);
        xrpSigningAlgos[0] = XRP_SIGNING_ALGO;
        bytes32[][] memory signingAlgos = new bytes32[][](1);
        signingAlgos[0] = xrpSigningAlgos;
        flareTeeManager.addSystemSupportedKeyTypesAndSigningAlgos(keyTypes, signingAlgos);

        // add supported key types for extension 0
        flareTeeManager.addSupportedKeyTypes(0, keyTypes);

        // allowlist project owners
        address[] memory owners = new address[](1);
        owners[0] = projectOwner;
        flareTeeManager.addAllowedTeeWalletProjectOwners(0, owners);
        vm.stopPrank();

    }

    function testWalletCreation() public {
        testExtensionCreation();
        // create project
        vm.prank(projectOwner);
        projectId = flareTeeManager.createProject(0, XRP_KEY_TYPE, XRP_SIGNING_ALGO);

        // create wallet
        vm.prank(projectOwner);
        walletId = flareTeeManager.createWallet(projectId);

        PublicKey[] memory adminsPublicKeys = new PublicKey[](2);
        adminsPublicKeys[0] = _getRandomPublicKey();
        address admin1 = _getAddress(adminsPublicKeys[0]);
        adminsPublicKeys[1] = _getRandomPublicKey();
        address admin2 = _getAddress(adminsPublicKeys[1]);
        vm.prank(projectOwner);
        flareTeeManager.setAdmins(walletId, adminsPublicKeys, 2);
        vm.prank(admin1);
        flareTeeManager.confirmAdmin(walletId);
        vm.prank(admin2);
        flareTeeManager.confirmAdmin(walletId);

        vm.prank(projectOwner);
        flareTeeManager.setCosigners(walletId, cosigners, 1);
        vm.prank(cosigners[0]);
        flareTeeManager.confirmCosigner(walletId);

        vm.startPrank(projectOwner);
        flareTeeManager.closeWalletInitialization(walletId);
        uint64 keyId1 = flareTeeManager.addKey{value: defaultFee} (teeId1, walletId, address(0));
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
        flareTeeManager.confirmKey(keyExistenceProof, _createSignature(privateKey1));

        // add second key
        vm.prank(projectOwner);
        uint64 keyId2 = flareTeeManager.addKey{value: defaultFee}(teeId2, walletId, address(0));

        vm.startPrank(projectOwner);
        keyExistenceProof.teeId = teeId2;
        keyExistenceProof.keyId = keyId2;
        keyExistenceProof.nonce = 0;
        flareTeeManager.confirmKey(keyExistenceProof, _createSignature(privateKey2));

        (, uint64[] memory keyIds ,) = flareTeeManager.getWalletKeysInfo(walletId);
        assertEq(keyIds.length, 2, "wrong number of keys");

        flareTeeManager.setMultisigThreshold(walletId, 2);
        flareTeeManager.enableWallet(walletId);
        vm.stopPrank();

        // flareTeeManager.setPausingAddresses(walletId, pausingAddresses);
    }

    function testAddPMWMultisigAccount() public {
        testWalletCreation();

        // Proof verification now lives in the shared TeePaymentsConfigVerifier; the payment contract calls
        // verifyAccountConfiguredProof (validate-only, returns void) and then reads the verified fields straight
        // from the calldata proof. Mock it to pass; the proof below carries sourceId/accountAddress/sequence.
        _mockVerifyAccountConfiguredProof();
        // Wallet was created with two confirmed keys (publicKey == abi.encode("publicKey")) and threshold 2.
        bytes[] memory pmwPublicKeys = new bytes[](2);
        pmwPublicKeys[0] = abi.encode("publicKey");
        pmwPublicKeys[1] = abi.encode("publicKey");
        IPMWMultisigAccountConfigured.Proof memory pmwAccountProof = IPMWMultisigAccountConfigured.Proof({
            signatures: IFdc2Verification.Fdc2Signatures({
                signingPolicySignatures: "",
                teeSignatures: new Signature[](0),
                cosignerSignatures: new Signature[](0)
            }),
            header: IFdc2Hub.Fdc2ResponseHeader({
                attestationType: bytes32("PMWMultisigAccountConfigured"),
                sourceId: XRP_SOURCE_ID,
                thresholdBIPS: 0,
                proofOwner: address(0),
                cosigners: new address[](0),
                cosignersThreshold: 0,
                timestamp: uint64(vm.getBlockTimestamp())
        }),
            requestBody: IPMWMultisigAccountConfigured.RequestBody({
                accountAddress: accountAddress,
                publicKeys: pmwPublicKeys,
                threshold: 2
            }),
            responseBody: IPMWMultisigAccountConfigured.ResponseBody({
                status: IPMWMultisigAccountConfigured.PMWMultisigAccountStatus.OK,
                sequence: 2
            })
        });

        // only wallet owner can add PMW account
        vm.expectRevert(ITeePaymentsBase.OnlyWalletOwner.selector);
        teePayments.addPMWMultisigAccount(walletId, pmwAccountProof, authorizationAddress);

        vm.prank(projectOwner);
        teePayments.addPMWMultisigAccount(walletId, pmwAccountProof, authorizationAddress);
        ITeePaymentsBase.PMWMultisigAccount[] memory accounts = teePayments.getWalletAccounts(walletId);
        assertEq(accounts.length, 1, "wrong number of accounts");
        assertEq(accounts[0].accountAddress, accountAddress, "wrong account address");
        assertEq(accounts[0].sourceId, XRP_SOURCE_ID, "wrong sourceId");
        assertEq(teePayments.getWalletId(account1), walletId, "wrong walletId");

        // sourceId needs to be supported: if the proof's sourceId resolves to an unregistered source,
        // _checkAccountRegistration reverts UnsupportedSourceId.
        pmwAccountProof.header.sourceId = bytes32("NOT_XRP");
        vm.expectRevert(ITeePaymentsBase.UnsupportedSourceId.selector);
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
        flareTeeManager.setOperationFees(opTypes, opCommands, fees);
        string memory recipient = "rJcBbUCtPg7b4Pfou23SgF18yMihWueK5B";
        bytes32 paymentReference = bytes32("paymentReference");
        ITeePaymentsBase.PaymentInstruction memory instruction = ITeePaymentsBase.PaymentInstruction({
            recipientAddress: recipient,
            tokenId: bytes(""),
            amount: 1000,
            maxFee: 15,
            paymentReference: paymentReference
        });

        // only authorization address can submit payment instructions
        vm.expectRevert(ITeePaymentsBase.OnlyAuthorizationAddress.selector);
        teePayments.pay(account1, instruction, address(0));

        // first payment: paymentId 1, native nonce = sequence (2) + paymentId (1) - 1 = 2.
        // The instruction id binds the native nonce, not the paymentId.
        bytes32 instructionId = keccak256(abi.encode(
            XRP_OP_TYPE, bytes32("PAY"), XRP_SOURCE_ID, account1.accountAddress, uint64(2)
        ));
        IMachineManager.TeeMachine[] memory teeMachines = new IMachineManager.TeeMachine[](2);
        teeMachines[0] = teeMachine1;
        teeMachines[1] = teeMachine2;
        ITeePayments.PaymentInstructionMessage memory message = ITeePayments.PaymentInstructionMessage({
            walletId: walletId,
            teeIdKeyIdPairs: flareTeeManager.receivingTeesAndKeys(walletId),
            sourceId: XRP_SOURCE_ID,
            senderAddress: account1.accountAddress,
            recipientAddress: instruction.recipientAddress,
            tokenId: instruction.tokenId,
            amount: instruction.amount,
            maxFee: instruction.maxFee,
            feeSchedule: abi.encodePacked(int16(10000), uint16(0)),
            paymentReference: instruction.paymentReference,
            nonce: 2,
            paymentId: 1
        });

        // if fee too low revert
        vm.expectRevert(IInstructions.FeeTooLow.selector);
        vm.prank(authorizationAddress);
        teePayments.pay(account1, instruction, address(0));

        vm.prank(authorizationAddress);
        vm.expectEmit();
        emit IInstructions.TeeInstructionsSent(
            0,
            instructionId,
            13,
            teeMachines,
            XRP_OP_TYPE,
            bytes32("PAY"),
            abi.encode(message),
            cosigners,
            1,
            address(0),
            2 * 25
        );
        teePayments.pay{value: 50} (account1, instruction, address(0));
    }

    // payment was not issued
    function testReissueRevert() public {
        testAddPMWMultisigAccount();
        string memory recipient = "rJcBbUCtPg7b4Pfou23SgF18yMihWueK5B";
        bytes32 paymentReference = bytes32("paymentReference");
        ITeePaymentsBase.PaymentInstruction memory instruction = ITeePaymentsBase.PaymentInstruction({
            recipientAddress: recipient,
            tokenId: bytes(""),
            amount: 1000,
            maxFee: 15,
            paymentReference: paymentReference
        });
        ITeePaymentsBase.PaymentInstruction[] memory instructions = new ITeePaymentsBase.PaymentInstruction[](1);
        instructions[0] = instruction;
        uint256[] memory reissueFees = new uint256[](1);
        reissueFees[0] = 30;
        int16[][] memory factorsBIPSPerPayment = new int16[][](1);
        factorsBIPSPerPayment[0] = new int16[](0);
        uint16[] memory delaysSeconds = new uint16[](0);
        // batchPaymentId 5 was never issued for this account -> the stored payment hash is empty,
        // so the submitted instruction's hash cannot match. (Use a non-zero id: id 0 would trip the
        // _nativeNonce paymentId>0 guard first.)
        vm.prank(authorizationAddress);
        vm.expectRevert(ITeePaymentsBase.PaymentHashMismatch.selector);
        teePayments.reissue{value: 50}(
            account1, 5, instructions,
            ITeePaymentsBase.ReissueFeeParams(reissueFees, factorsBIPSPerPayment, delaysSeconds),
            address(0)
        );
    }

    function testReissue() public {
        testPay();
        string memory recipient = "rJcBbUCtPg7b4Pfou23SgF18yMihWueK5B";
        bytes32 paymentReference = bytes32("paymentReference");
        ITeePaymentsBase.PaymentInstruction memory instruction = ITeePaymentsBase.PaymentInstruction({
            recipientAddress: recipient,
            tokenId: bytes(""),
            amount: 1000,
            maxFee: 15,
            paymentReference: paymentReference
        });
        ITeePaymentsBase.PaymentInstruction[] memory instructions = new ITeePaymentsBase.PaymentInstruction[](1);
        instructions[0] = instruction;
        uint256[] memory reissueFees = new uint256[](1);
        reissueFees[0] = 30;
        int16[][] memory factorsBIPSPerPayment = new int16[][](1);
        factorsBIPSPerPayment[0] = new int16[](0);
        uint16[] memory delaysSeconds = new uint16[](0);

        // reissue the payment created in testPay (paymentId 1, native nonce 2); reissueNumber starts at 0.
        // The instruction id binds the native nonce, not the paymentId.
        uint256 reissueNumber = 0;
        bytes32 instructionId = keccak256(abi.encode(
            XRP_OP_TYPE, bytes32("REISSUE"), XRP_SOURCE_ID, account1.accountAddress, uint64(2), reissueNumber
        ));
        IMachineManager.TeeMachine[] memory teeMachines = new IMachineManager.TeeMachine[](2);
        teeMachines[0] = teeMachine1;
        teeMachines[1] = teeMachine2;
        vm.warp(vm.getBlockTimestamp() + 1);
        ITeePayments.PaymentInstructionMessage memory message = ITeePayments.PaymentInstructionMessage({
            walletId: walletId,
            teeIdKeyIdPairs: flareTeeManager.receivingTeesAndKeys(walletId),
            sourceId: XRP_SOURCE_ID,
            senderAddress: account1.accountAddress,
            recipientAddress: instruction.recipientAddress,
            tokenId: instruction.tokenId,
            amount: instruction.amount,
            maxFee: reissueFees[0],
            feeSchedule: abi.encodePacked(int16(10000), uint16(0)),
            paymentReference: instruction.paymentReference,
            nonce: 2,
            paymentId: 1
        });

        vm.expectEmit();
        emit IInstructions.TeeInstructionsSent(
            0,
            instructionId,
            13,
            teeMachines,
            XRP_OP_TYPE,
            bytes32("REISSUE"),
            abi.encode(message),
            cosigners,
            1,
            address(0),
            60
        );
        vm.prank(authorizationAddress);
        teePayments.reissue{value: 60}(
            account1, 1, instructions,
            ITeePaymentsBase.ReissueFeeParams(reissueFees, factorsBIPSPerPayment, delaysSeconds),
            address(0)
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

    function _mockVerifyAccountConfiguredProof() internal {
        vm.mockCall(
            teePaymentsConfigVerifierMock,
            abi.encodeWithSelector(ITeePaymentsConfigVerifier.verifyAccountConfiguredProof.selector),
            ""
        );
    }

    function _createSignature(
        uint256 _privateKey
    )
        private view
        returns (Signature memory)
    {
        bytes32 signedMessageHash = SignedPayload.ethSignedHash(
            TEE_KEY_EXISTENCE, keccak256(abi.encode(keyExistenceProof))
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_privateKey, signedMessageHash);
        return Signature(v, r, s);
    }

}
