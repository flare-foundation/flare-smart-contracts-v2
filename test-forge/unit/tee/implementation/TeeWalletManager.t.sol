// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../../contracts/tee/implementation/TeeWalletManager.sol";
import "../../../../contracts/tee/implementation/TeeWalletManagerProxy.sol";
import "../../../../contracts/tee/implementation/TeeInstructions.sol";
import "../../../../contracts/tee/implementation/TeeInstructionsProxy.sol";

contract TeeWalletManagerTest is Test {

    uint256 constant private P = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F;
    bytes32 constant private SET_PAUSING_ADDRESSES = bytes32("SET_PAUSING_ADDRESSES");
    bytes32 public constant WALLET_OP_TYPE = bytes32("WALLET");
    bytes32 public constant RESUME = bytes32("RESUME");

    TeeWalletManager private teeWalletManager;
    TeeWalletManager private teeWalletManagerImpl;
    TeeWalletManagerProxy private teeWalletManagerProxy;

    TeeInstructions private teeInstructions;
    TeeInstructions private teeInstructionsImpl;
    TeeInstructionsProxy private teeInstructionsProxy;

    address private mockTeeRegistry;
    address private mockTeeWalletProjectManager;
    address private mockTeeWalletKeyManager;
    address private mockFSM;
    address private mockTeeFeeCalculator;
    address private mockRewardManager;

    address private governance;
    address private addressUpdater;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    address private projectOwner;
    bytes32 private projectId;
    bytes32 private walletId;

    event TeeInstructionsSent(
        bytes32 indexed instructionId,
        uint32 indexed rewardEpochId,
        ITeeRegistry.TeeMachine[] teeMachines,
        bytes32 opType,
        bytes32 opCommand,
        bytes message,
        uint256 fee
    );

    event WalletCreated(
        bytes32 indexed projectId,
        bytes32 indexed walletId
    );

    event WalletAdminConfirmed(
        bytes32 indexed walletId,
        address indexed admin
    );

    event WalletCosignerConfirmed(
        bytes32 indexed walletId,
        address indexed cosigner
    );

    function setUp() public {
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");
        mockTeeWalletProjectManager = makeAddr("teeWalletProjectManager");
        mockTeeWalletKeyManager = makeAddr("teeWalletKeyManager");
        mockFSM = makeAddr("flareSystemsManager");
        mockTeeRegistry = makeAddr("teeRegistry");
        mockRewardManager = makeAddr("rewardManager");
        mockTeeFeeCalculator = makeAddr("teeFeeCalculator");
        teeInstructionsImpl = new TeeInstructions();
        teeInstructionsProxy = new TeeInstructionsProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            address(teeInstructionsImpl)
        );
        teeInstructions = TeeInstructions(address(teeInstructionsProxy));

        teeWalletManagerImpl = new TeeWalletManager();
        teeWalletManagerProxy = new TeeWalletManagerProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            address(teeWalletManagerImpl)
        );
        teeWalletManager = TeeWalletManager(address(teeWalletManagerProxy));

        vm.prank(addressUpdater);
        contractNameHashes = new bytes32[](7);
        contractAddresses = new address[](7);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("TeeRegistry"));
        contractNameHashes[2] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[3] = keccak256(abi.encode("TeeFeeCalculator"));
        contractNameHashes[4] = keccak256(abi.encode("TeeInstructions"));
        contractNameHashes[5] = keccak256(abi.encode("TeeWalletProjectManager"));
        contractNameHashes[6] = keccak256(abi.encode("TeeWalletKeyManager"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = mockTeeRegistry;
        contractAddresses[2] = mockFSM;
        contractAddresses[3] = mockTeeFeeCalculator;
        contractAddresses[4] = address(teeInstructions);
        contractAddresses[5] = mockTeeWalletProjectManager;
        contractAddresses[6] = mockTeeWalletKeyManager;
        teeWalletManager.updateContractAddresses(contractNameHashes, contractAddresses);

        vm.prank(addressUpdater);
        contractNameHashes = new bytes32[](2);
        contractAddresses = new address[](2);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("RewardManager"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = mockRewardManager;
        teeInstructions.updateContractAddresses(contractNameHashes, contractAddresses);

        vm.prank(governance);
        address[] memory instructionInitiators = new address[](1);
        instructionInitiators[0] = address(teeWalletManager);
        teeInstructions.registerInstructionInitiators(instructionInitiators);

        projectOwner = makeAddr("projectOwner");
        projectId = bytes32("project1");
        walletId = keccak256(abi.encode("WALLET", projectOwner, 1));
        _mockGetProjectOwner(projectId, projectOwner);
        // fund project owner
        vm.deal(projectOwner, 1 ether);

        _mockGetCurrentRewardEpochId(10);
        _mockReceiveRewards();
    }

    function testCreateWallet() public{
        vm.prank(projectOwner);
        vm.expectEmit();
        emit WalletCreated(projectId, walletId);
        teeWalletManager.createWallet(projectId);

        assertEq(teeWalletManager.getWalletProjectId(walletId), projectId);
        assertEq(uint8(teeWalletManager.getWalletStatus(walletId)), uint8(ITeeWalletManager.WalletStatus.CREATED));
        assertEq(teeWalletManager.getProjectWalletIds(projectId).length, 1);
        assertEq(teeWalletManager.getProjectWalletIds(projectId)[0], walletId);
    }

    function testCreateWalletRevert() public {
        vm.expectRevert("only owner");
        teeWalletManager.createWallet(projectId);
    }

    // not enough admins
    function testSetAdminsRevert1() public {
        testCreateWallet();
        PublicKey[] memory admins =  new PublicKey[](2);
        admins[0] = _getRandomPublicKey();
        admins[1] = _getRandomPublicKey();

        vm.prank(projectOwner);
        vm.expectRevert("not enough admins");
        teeWalletManager.setAdmins(walletId, admins, 3);
    }

    // invalid admins threshold
    function testSetAdminsRevert2() public {
        testCreateWallet();
        PublicKey[] memory admins =  new PublicKey[](2);
        admins[0] = _getRandomPublicKey();
        admins[1] = _getRandomPublicKey();

        vm.prank(projectOwner);
        vm.expectRevert("invalid admins threshold");
        teeWalletManager.setAdmins(walletId, admins, 0);
    }

    // invalid public key
    function testSetAdminsRevert3() public {
        testCreateWallet();
        PublicKey[] memory admins =  new PublicKey[](2);
        admins[0] = _getRandomPublicKey();

        vm.prank(projectOwner);
        vm.expectRevert("invalid public key");
        teeWalletManager.setAdmins(walletId, admins, 1);
    }

    // duplicated public key
    function testSetAdminsRevert4() public {
        testCreateWallet();
        PublicKey[] memory admins =  new PublicKey[](2);
        admins[0] = _getRandomPublicKey();
        admins[1] = admins[0]; // duplicate

        vm.prank(projectOwner);
        vm.expectRevert("duplicated public key");
        teeWalletManager.setAdmins(walletId, admins, 1);
    }

    // only owner
    function testSetAdminsRevert5() public {
        testCreateWallet();
        PublicKey[] memory admins =  new PublicKey[](2);
        admins[0] = _getRandomPublicKey();
        admins[1] = _getRandomPublicKey();

        vm.expectRevert("only owner");
        teeWalletManager.setAdmins(walletId, admins, 1);
    }

    function testSetAdmins() public returns (PublicKey[] memory) {
        testCreateWallet();
        PublicKey[] memory admins =  new PublicKey[](2);
        admins[0] = _getRandomPublicKey();
        admins[1] = _getRandomPublicKey();

        vm.prank(projectOwner);
        teeWalletManager.setAdmins(walletId, admins, 1);
        (PublicKey[] memory _adminsPublicKeys, uint64 _adminsThreshold) =
            teeWalletManager.getWalletAdminsAndThreshold(walletId);
        assertEq(_adminsPublicKeys.length, 2);
        assertEq(_adminsPublicKeys[0].x, admins[0].x);
        assertEq(_adminsPublicKeys[0].y, admins[0].y);
        assertEq(_adminsPublicKeys[1].x, admins[1].x);
        assertEq(_adminsPublicKeys[1].y, admins[1].y);
        assertEq(_adminsThreshold, 1);
        return admins;
    }

    function testSetAdminsAgain() public {
        testSetAdmins();
        PublicKey[] memory admins =  new PublicKey[](1);
        admins[0] = _getRandomPublicKey();
        vm.prank(projectOwner);
        teeWalletManager.setAdmins(walletId, admins, 1);
        // old admins should be removed
        (PublicKey[] memory _adminsPublicKeys, uint64 _adminsThreshold) =
            teeWalletManager.getWalletAdminsAndThreshold(walletId);
        assertEq(_adminsPublicKeys.length, 1);
        assertEq(_adminsPublicKeys[0].x, admins[0].x);
        assertEq(_adminsPublicKeys[0].y, admins[0].y);
        assertEq(_adminsThreshold, 1);
    }

    function testConfirmAdmins() public {
        PublicKey[] memory admins = testSetAdmins();
        // confirm first admin
        address admin1 = _getAddress(admins[0]);
        vm.prank(admin1);
        vm.expectEmit();
        emit WalletAdminConfirmed(walletId, admin1);
        teeWalletManager.confirmAdmin(walletId);

        // confirm second admin
        address admin2 = _getAddress(admins[1]);
        vm.prank(admin2);
        vm.expectEmit();
        emit WalletAdminConfirmed(walletId, admin2);
        teeWalletManager.confirmAdmin(walletId);
    }


    // invalid admin
    function testConfirmAdminsRevert1() public {
        vm.expectRevert("invalid admin");
        teeWalletManager.confirmAdmin(walletId);
    }

    // invalid threshold
    function testSetCosignersRevert1() public {
        testCreateWallet();
        address[] memory cosigners =  new address[](2);
        cosigners[0] = makeAddr("cosigner1");
        cosigners[1] = makeAddr("cosigner2");

        vm.prank(projectOwner);
        vm.expectRevert("invalid threshold");
        teeWalletManager.setCosigners(walletId, cosigners, 0);
    }

    // invalid address
    function testSetCosignersRevert2() public {
        testCreateWallet();
        address[] memory cosigners =  new address[](2);
        cosigners[0] = makeAddr("cosigner1");
        cosigners[1] = address(0);

        vm.prank(projectOwner);
        vm.expectRevert("invalid cosigner");
        teeWalletManager.setCosigners(walletId, cosigners, 1);
    }

    // duplicated cosigner
    function testSetCosignersRevert3() public {
        testCreateWallet();
        address[] memory cosigners =  new address[](2);
        cosigners[0] = makeAddr("cosigner1");
        cosigners[1] = cosigners[0]; // duplicate

        vm.prank(projectOwner);
        vm.expectRevert("duplicated cosigner");
        teeWalletManager.setCosigners(walletId, cosigners, 1);
    }

    // only owner
    function testSetCosignersRevert4() public {
        testCreateWallet();
        address[] memory cosigners =  new address[](2);
        cosigners[0] = makeAddr("cosigner1");
        cosigners[1] = makeAddr("cosigner2");

        vm.expectRevert("only owner");
        teeWalletManager.setCosigners(walletId, cosigners, 1);
    }

    function testSetCosigners() public returns (address[] memory) {
        testConfirmAdmins();
        address[] memory cosigners =  new address[](2);
        cosigners[0] = makeAddr("cosigner1");
        cosigners[1] = makeAddr("cosigner2");

        vm.prank(projectOwner);
        teeWalletManager.setCosigners(walletId, cosigners, 1);
        (address[] memory _cosigners, uint64 _cosignersThreshold) =
            teeWalletManager.getWalletCosignersAndThreshold(walletId);
        assertEq(_cosigners.length, 2);
        assertEq(_cosigners[0], cosigners[0]);
        assertEq(_cosigners[1], cosigners[1]);
        assertEq(_cosignersThreshold, 1);

        return cosigners;
    }

    function testConfirmCosigner() public {
        address[] memory cosigners = testSetCosigners();
        cosigners[0] = makeAddr("cosigner1");
        cosigners[1] = makeAddr("cosigner2");

        // confirm first cosigner
        vm.prank(cosigners[0]);
        vm.expectEmit();
        emit WalletCosignerConfirmed(walletId, cosigners[0]);
        teeWalletManager.confirmCosigner(walletId);
        // confirm second cosigner
        vm.prank(cosigners[1]);
        vm.expectEmit();
        emit WalletCosignerConfirmed(walletId, cosigners[1]);
        teeWalletManager.confirmCosigner(walletId);
    }

    function testConfirmCosignerRevert() public {
        vm.expectRevert("invalid cosigner");
        teeWalletManager.confirmCosigner(walletId);
    }

    // only owner
    function testCloseWalletInitializationRevert1() public {
        testCreateWallet();
        vm.expectRevert("only owner");
        teeWalletManager.closeWalletInitialization(walletId);
    }

    // admins not set
    function testCloseWalletInitializationRevert2() public {
        testCreateWallet();
        vm.prank(projectOwner);
        vm.expectRevert("admins not set");
        teeWalletManager.closeWalletInitialization(walletId);
    }

    // not all admins confirmed
    function testCloseWalletInitializationRevert3() public {
        testSetAdmins();
        vm.prank(projectOwner);
        vm.expectRevert("not all admins confirmed");
        teeWalletManager.closeWalletInitialization(walletId);
    }

    // not all cosigners confirmed
    function testCloseWalletInitializationRevert4() public {
        testSetCosigners();
        vm.prank(projectOwner);
        vm.expectRevert("not all cosigners confirmed");
        teeWalletManager.closeWalletInitialization(walletId);
    }

    function testCloseWalletInitialization() public {
        testConfirmCosigner();
        vm.prank(projectOwner);
        teeWalletManager.closeWalletInitialization(walletId);
        assertEq(uint8(teeWalletManager.getWalletStatus(walletId)), uint8(ITeeWalletManager.WalletStatus.INITIALIZED));
    }

    // wrong status
    function testSetAdminsRevert6() public {
        testCloseWalletInitialization();
        PublicKey[] memory admins =  new PublicKey[](2);
        admins[0] = _getRandomPublicKey();
        admins[1] = _getRandomPublicKey();

        vm.prank(projectOwner);
        vm.expectRevert("invalid wallet status");
        teeWalletManager.setAdmins(walletId, admins, 1);
    }

    function testSetCosignersRevert5() public {
        testCloseWalletInitialization();
        address[] memory cosigners =  new address[](2);
        cosigners[0] = makeAddr("cosigner1");
        cosigners[1] = makeAddr("cosigner2");

        vm.prank(projectOwner);
        vm.expectRevert("invalid wallet status");
        teeWalletManager.setCosigners(walletId, cosigners, 1);
    }

    function testConfirmAdminsRevert2() public {
        testCloseWalletInitialization();
        vm.expectRevert("invalid wallet status");
        teeWalletManager.confirmAdmin(walletId);
    }

    function testEnableWalletRevert1() public {
        testCloseWalletInitialization();
        vm.expectRevert("only owner");
        teeWalletManager.enableWallet(walletId);
    }

    // invalid wallet status
    function testEnableWalletRevert2() public {
        testCreateWallet();
        vm.prank(projectOwner);
        vm.expectRevert("invalid wallet status");
        teeWalletManager.enableWallet(walletId);
    }

    // multisig threshold not set
    function testEnableWalletRevert3() public {
        testCloseWalletInitialization();
        _mockGetWalletKeysInfo(walletId, 0, new uint64[](0));
        vm.prank(projectOwner);
        vm.expectRevert("multisig threshold not set");
        teeWalletManager.enableWallet(walletId);
    }

    // not enough keys
    function testEnableWalletRevert4() public {
        testCloseWalletInitialization();
        uint64[] memory keyIds = new uint64[](1);
        keyIds[0] = 1;
        _mockGetWalletKeysInfo(walletId, 2, keyIds);
        vm.prank(projectOwner);
        vm.expectRevert("not enough keys");
        teeWalletManager.enableWallet(walletId);
    }

    function testEnableWallet() public {
        testCloseWalletInitialization();
        uint64[] memory keyIds = new uint64[](2);
        keyIds[0] = 1;
        keyIds[1] = 2;
        _mockGetWalletKeysInfo(walletId, 1, keyIds);
        vm.prank(projectOwner);
        teeWalletManager.enableWallet(walletId);
        assertEq(uint8(teeWalletManager.getWalletStatus(walletId)), uint8(ITeeWalletManager.WalletStatus.PRODUCTION));
    }

    function testPauseWallet() public {
        testEnableWallet();
        vm.prank(projectOwner);
        teeWalletManager.pauseWallet(walletId);
        assertEq(uint8(teeWalletManager.getWalletStatus(walletId)), uint8(ITeeWalletManager.WalletStatus.PAUSED));
    }

    function testPauseWalletRevert() public {
        testCloseWalletInitialization();
        vm.prank(projectOwner);
        vm.expectRevert("invalid wallet status"); // only production
        teeWalletManager.pauseWallet(walletId);
    }

    function testAddSupportedOpTypes() public {
        testEnableWallet();
        bytes32 opType = keccak256(abi.encode("XRP"));
        bytes32 opType2 = keccak256(abi.encode("BTC"));
        address constantProvider1 = makeAddr("constantProvider1");
        address constantProvider2 = makeAddr("constantProvider2");
        IITeeWalletOpTypeConstants[] memory opTypeConstantsProviders = new IITeeWalletOpTypeConstants[](2);
        opTypeConstantsProviders[0] = IITeeWalletOpTypeConstants(constantProvider1);
        opTypeConstantsProviders[1] = IITeeWalletOpTypeConstants(constantProvider2);
        vm.mockCall(
            constantProvider1,
            abi.encodeWithSelector(IITeeWalletOpTypeConstants.getOpType.selector),
            abi.encode(opType)
        );
        vm.mockCall(
            constantProvider2,
            abi.encodeWithSelector(IITeeWalletOpTypeConstants.getOpType.selector),
            abi.encode(opType2)
        );
        vm.prank(governance);
        teeWalletManager.addSupportedOpTypes(opTypeConstantsProviders);
        assertTrue(teeWalletManager.isOpTypeSupported(opType));
        assertTrue(teeWalletManager.isOpTypeSupported(opType2));
        bytes32[] memory supportedOpTypes = teeWalletManager.getSupportedOpTypes();
        assertEq(supportedOpTypes.length, 2);
        assertEq(supportedOpTypes[0], opType);
        assertEq(supportedOpTypes[1], opType2);
    }

    function testRemoveSupportedOpTypes() public {
        testAddSupportedOpTypes();
        bytes32 opType = keccak256(abi.encode("XRP"));
        bytes32 opType2 = keccak256(abi.encode("BTC"));
        bytes32[] memory opTypes = new bytes32[](1);
        opTypes[0] = opType;
        vm.prank(governance);
        teeWalletManager.removeSupportedOpTypes(opTypes);
        assertFalse(teeWalletManager.isOpTypeSupported(opType));
        assertTrue(teeWalletManager.isOpTypeSupported(opType2));
        bytes32[] memory supportedOpTypes = teeWalletManager.getSupportedOpTypes();
        assertEq(supportedOpTypes.length, 1);
        assertEq(supportedOpTypes[0], opType2);
    }

    function testSetPausingAddresses() public {
        testEnableWallet();
        _mockCalculateFeeByWalletId(walletId, WALLET_OP_TYPE, SET_PAUSING_ADDRESSES, 1234);
        (ITeeRegistry.TeeMachine[] memory receivingTees,
            TeeIdKeyIdPair[] memory teeIdKeyIdPairs) = _mockReceivingTeesAndKeys();
        address[] memory pausingAddresses = new address[](2);
        pausingAddresses[0] = makeAddr("pausingAddress1");
        pausingAddresses[1] = makeAddr("pausingAddress2");
        uint256 counter = 0;
        bytes32 instructionId = keccak256(abi.encode(WALLET_OP_TYPE, SET_PAUSING_ADDRESSES, walletId, counter));
        ITeeWalletManager.SetPausingAddresses memory message = ITeeWalletManager.SetPausingAddresses(
            walletId,
            counter,
            teeIdKeyIdPairs,
            pausingAddresses
        );
        vm.prank(projectOwner);
        vm.expectEmit();
        emit TeeInstructionsSent(
            instructionId,
            10,
            receivingTees,
            WALLET_OP_TYPE,
            SET_PAUSING_ADDRESSES,
            abi.encode(message),
            12345
        );
        teeWalletManager.setPausingAddresses{value: 12345}(walletId, pausingAddresses);
    }

    function testSetPausingAddressesRevertOnlyWalletOwner() public {
        testEnableWallet();
        vm.expectRevert("only owner");
        teeWalletManager.setPausingAddresses(walletId, new address[](2));
    }

    function testSetPausingAddressesRevertWrongStatus() public {
        testCreateWallet();
        vm.prank(projectOwner);
        vm.expectRevert("only production or paused status");
        teeWalletManager.setPausingAddresses(walletId, new address[](2));
    }

    function testSetPausingAddressesRevertFeeTooLow() public {
        testEnableWallet();
        _mockCalculateFeeByWalletId(walletId, WALLET_OP_TYPE, SET_PAUSING_ADDRESSES, 1234);
        vm.prank(projectOwner);
        vm.expectRevert("fee too low");
        teeWalletManager.setPausingAddresses{value: 1232}(walletId, new address[](2));
    }

    function testGetOpTypeConstants() public {
        testAddSupportedOpTypes();
        bytes32 opType = keccak256(abi.encode("XRP"));
        address constantProvider1 = makeAddr("constantProvider1");
        vm.mockCall(
            mockTeeWalletProjectManager,
            abi.encodeWithSelector(ITeeWalletProjectManager.getOpType.selector, projectId),
            abi.encode(opType)
        );
        vm.mockCall(
            constantProvider1,
            abi.encodeWithSelector(IITeeWalletOpTypeConstants.getOpTypeConstants.selector, walletId),
            abi.encode(bytes("opTypeConstants"))
        );
        assertEq(teeWalletManager.getOpTypeConstants(walletId), bytes("opTypeConstants"));
    }

    // wallet not found
    function testGetOpTypeConstantsRevert1() public {
        testAddSupportedOpTypes();
        vm.expectRevert("wallet not found");
        teeWalletManager.getOpTypeConstants(bytes32("nonExistentWalletId"));
    }

    // op type not supported
    function testGetOpTypeConstantsRevert2() public {
        testAddSupportedOpTypes();
        bytes32 opType = keccak256(abi.encode("DOGE"));
        vm.mockCall(
            mockTeeWalletProjectManager,
            abi.encodeWithSelector(ITeeWalletProjectManager.getOpType.selector, projectId),
            abi.encode(opType)
        );
        vm.expectRevert("operation type not supported");
        teeWalletManager.getOpTypeConstants(walletId);
    }

    function testResume() public {
        testPauseWallet();

        ITeeWalletManager.ResumeKeyData [] memory keysData = new ITeeWalletManager.ResumeKeyData[](2);
        keysData[0] = ITeeWalletManager.ResumeKeyData({
            keyId: 1,
            teeId: makeAddr("tee1"),
            nonce: 0
        });
        keysData[1] = ITeeWalletManager.ResumeKeyData({
            keyId: 2,
            teeId: makeAddr("tee2"),
            nonce: 1
        });
        address[] memory teeIds = new address[](2);
        teeIds[0] = keysData[0].teeId;
        teeIds[1] = keysData[1].teeId;

        uint64[] memory keyIds = new uint64[](2);
        keyIds[0] = 1;
        keyIds[1] = 2;
        _mockGetWalletKeysInfo(walletId, 2, keyIds);
        _mockGetTeeMachineStatus(ITeeRegistry.TeeStatus.PRODUCTION);
        bytes32 instructionId = keccak256(abi.encode(
            WALLET_OP_TYPE, RESUME, walletId, 0
        ));
        _mockCalculateFeeByTeeIds(teeIds, WALLET_OP_TYPE, RESUME, 1234);
        ITeeWalletManager.Resume memory message = ITeeWalletManager.Resume(
            walletId,
            keysData
        );
        ITeeRegistry.TeeMachine[] memory teeMachines = new ITeeRegistry.TeeMachine[](keysData.length);
        teeMachines[0] = _mockGetTeeMachine(makeAddr("tee1"));
        teeMachines[1] = _mockGetTeeMachine(makeAddr("tee2"));
        vm.prank(projectOwner);
        vm.expectEmit();
        emit TeeInstructionsSent(
            instructionId,
            10,
            teeMachines,
            WALLET_OP_TYPE,
            RESUME,
            abi.encode(message),
            1234
        );
        teeWalletManager.resume{value: 1234}(walletId, keysData);
    }

    // wrong status
    function testResumeRevert1() public {
        testCreateWallet();
        vm.expectRevert("only production or paused status");
        vm.prank(projectOwner);
        teeWalletManager.resume(walletId, new ITeeWalletManager.ResumeKeyData[](0));
    }

    // only owner
    function testResumeRevert2() public {
        testPauseWallet();
        vm.expectRevert("only owner");
        teeWalletManager.resume(walletId, new ITeeWalletManager.ResumeKeyData[](0));
    }

    // fee too low
    function testResumeRevert3() public {
        testPauseWallet();
        ITeeWalletManager.ResumeKeyData [] memory keysData = new ITeeWalletManager.ResumeKeyData[](2);
        keysData[0] = ITeeWalletManager.ResumeKeyData({
            keyId: 1,
            teeId: makeAddr("tee1"),
            nonce: 0
        });
        keysData[1] = ITeeWalletManager.ResumeKeyData({
            keyId: 2,
            teeId: makeAddr("tee2"),
            nonce: 1
        });
        address[] memory teeIds = new address[](2);
        teeIds[0] = keysData[0].teeId;
        teeIds[1] = keysData[1].teeId;

        uint64[] memory keyIds = new uint64[](2);
        keyIds[0] = 1;
        keyIds[1] = 2;
        _mockGetWalletKeysInfo(walletId, 2, keyIds);
        _mockGetTeeMachineStatus(ITeeRegistry.TeeStatus.PRODUCTION);
        _mockCalculateFeeByTeeIds(teeIds, WALLET_OP_TYPE, RESUME, 1234);
        ITeeRegistry.TeeMachine[] memory teeMachines = new ITeeRegistry.TeeMachine[](keysData.length);
        teeMachines[0] = _mockGetTeeMachine(makeAddr("tee1"));
        teeMachines[1] = _mockGetTeeMachine(makeAddr("tee2"));
        vm.prank(projectOwner);
        vm.expectRevert("fee too low");
        teeWalletManager.resume{value: 1233}(walletId, keysData);
    }

    // wrong key id
    function testResumeRevert4() public {
        testPauseWallet();
        ITeeWalletManager.ResumeKeyData [] memory keysData = new ITeeWalletManager.ResumeKeyData[](2);
        keysData[0] = ITeeWalletManager.ResumeKeyData({
            keyId: 1,
            teeId: makeAddr("tee1"),
            nonce: 0
        });
        keysData[1] = ITeeWalletManager.ResumeKeyData({
            keyId: 2,
            teeId: makeAddr("tee2"),
            nonce: 1
        });
        address[] memory teeIds = new address[](2);
        teeIds[0] = keysData[0].teeId;
        teeIds[1] = keysData[1].teeId;

        uint64[] memory keyIds = new uint64[](2);
        keyIds[0] = 1;
        keyIds[1] = 3;
        _mockGetWalletKeysInfo(walletId, 2, keyIds);
        _mockGetTeeMachineStatus(ITeeRegistry.TeeStatus.PRODUCTION);
        _mockCalculateFeeByTeeIds(teeIds, WALLET_OP_TYPE, RESUME, 1234);
        ITeeRegistry.TeeMachine[] memory teeMachines = new ITeeRegistry.TeeMachine[](keysData.length);
        teeMachines[0] = _mockGetTeeMachine(makeAddr("tee1"));
        teeMachines[1] = _mockGetTeeMachine(makeAddr("tee2"));
        vm.prank(projectOwner);
        vm.expectRevert("wrong key id");
        teeWalletManager.resume{value: 1234}(walletId, keysData);
    }

    // tee machine not available
    function testResumeRevert5() public {
                testPauseWallet();
        ITeeWalletManager.ResumeKeyData [] memory keysData = new ITeeWalletManager.ResumeKeyData[](2);
        keysData[0] = ITeeWalletManager.ResumeKeyData({
            keyId: 1,
            teeId: makeAddr("tee1"),
            nonce: 0
        });
        keysData[1] = ITeeWalletManager.ResumeKeyData({
            keyId: 2,
            teeId: makeAddr("tee2"),
            nonce: 1
        });
        address[] memory teeIds = new address[](2);
        teeIds[0] = keysData[0].teeId;
        teeIds[1] = keysData[1].teeId;

        uint64[] memory keyIds = new uint64[](2);
        keyIds[0] = 1;
        keyIds[1] = 2;
        _mockGetWalletKeysInfo(walletId, 2, keyIds);
        _mockGetTeeMachineStatus(ITeeRegistry.TeeStatus.PAUSED);
        _mockCalculateFeeByTeeIds(teeIds, WALLET_OP_TYPE, RESUME, 1234);
        ITeeRegistry.TeeMachine[] memory teeMachines = new ITeeRegistry.TeeMachine[](keysData.length);
        teeMachines[0] = _mockGetTeeMachine(makeAddr("tee1"));
        teeMachines[1] = _mockGetTeeMachine(makeAddr("tee2"));
        vm.prank(projectOwner);
        vm.expectRevert("tee machine not available");
        teeWalletManager.resume{value: 1234}(walletId, keysData);
    }

    //// helper functions
    function _mockGetProjectOwner(bytes32 _projectId, address _projectOwner) internal {
        vm.mockCall(
            mockTeeWalletProjectManager,
            abi.encodeWithSelector(ITeeWalletProjectManager.getOwner.selector, _projectId),
            abi.encode(_projectOwner)
        );
    }

    function _mockGetWalletKeysInfo(bytes32 _walletId, uint64 _threshold, uint64[] memory _keyIds) internal {
        vm.mockCall(
            mockTeeWalletKeyManager,
            abi.encodeWithSelector(ITeeWalletKeyManager.getWalletKeysInfo.selector, _walletId),
            abi.encode(_threshold, _keyIds, 1)
        );
    }

    function _mockCalculateFeeByWalletId(
        bytes32 _walletId,
        bytes32 _opType,
        bytes32 _opCommand,
        uint256 _fee
    )
        internal
    {
        vm.mockCall(
            mockTeeFeeCalculator,
            abi.encodeWithSelector(
                ITeeFeeCalculator.calculateFeeByWalletId.selector,
                _opType,
                _opCommand,
                _walletId
            ),
            abi.encode(_fee)
        );
    }

    function _mockCalculateFeeByTeeIds(
        address[] memory _teeIds,
        bytes32 _opType,
        bytes32 _opCommand,
        uint256 _fee
    )
        internal
    {
        vm.mockCall(
            mockTeeFeeCalculator,
            abi.encodeWithSelector(
                ITeeFeeCalculator.calculateFeeByTeeIds.selector,
                _opType,
                _opCommand,
                _teeIds
            ),
            abi.encode(_fee)
        );
    }

    function _mockReceivingTeesAndKeys() internal returns (
        ITeeRegistry.TeeMachine[] memory,
        TeeIdKeyIdPair[] memory _teeIdKeyIdPairs
    ) {
        ITeeRegistry.TeeMachine[] memory receivingTees = new ITeeRegistry.TeeMachine[](1);
        TeeIdKeyIdPair[] memory teeIdKeyIdPairs =
            new TeeIdKeyIdPair[](1);
        receivingTees[0] = ITeeRegistry.TeeMachine({
            teeId: makeAddr("teeId"),
            teeProxyId: makeAddr("teeProxyId"),
            url: "teeUrl"
        });
        teeIdKeyIdPairs[0] = TeeIdKeyIdPair({
            teeId: receivingTees[0].teeId,
            keyId: 1
        });
        vm.mockCall(
            mockTeeWalletKeyManager,
            abi.encodeWithSelector(ITeeWalletKeyManager.receivingTeesAndKeys.selector),
            abi.encode(receivingTees, teeIdKeyIdPairs)
        );
        return (receivingTees, teeIdKeyIdPairs);
    }

    function _mockReceiveRewards() internal {
        vm.mockCall(
            mockRewardManager,
            abi.encodeWithSelector(IIRewardManager.receiveRewards.selector),
            abi.encode()
        );
    }

    function _mockGetCurrentRewardEpochId(uint24 _rewardEpochId) internal {
        vm.mockCall(
            mockFSM,
            abi.encodeWithSelector(ProtocolsV2Interface.getCurrentRewardEpochId.selector),
            abi.encode(_rewardEpochId)
        );
    }

    function _mockGetTeeMachineStatus(ITeeRegistry.TeeStatus _status) internal {
        vm.mockCall(
            mockTeeRegistry,
            abi.encodeWithSelector(ITeeRegistry.getTeeMachineStatus.selector),
            abi.encode(_status)
        );
    }

    function _mockGetTeeMachine(
        address _teeId
    ) internal  returns (ITeeRegistry.TeeMachine memory) {
        ITeeRegistry.TeeMachine memory teeMachine = ITeeRegistry.TeeMachine({
            teeId: _teeId,
            teeProxyId: makeAddr("teeProxyId"),
            url: "url"
        });
        vm.mockCall(
            mockTeeRegistry,
            abi.encodeWithSelector(ITeeRegistry.getTeeMachine.selector, _teeId),
            abi.encode(teeMachine)
        );
        return teeMachine;
    }

    function _getRandomPublicKey() private returns (PublicKey memory) {
        // call external script to get random public key coordinates
        string[] memory command = new string[](2);
        command[0] = "node";
        command[1] = "scripts/generate-key.js";
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
        // test that the coordinates are valid
        _checkPublicKeyValidity(pk);

        return pk;
    }

    function _checkPublicKeyValidity(PublicKey memory _pk) internal pure {
        uint256 x = uint256(_pk.x);
        uint256 y = uint256(_pk.y);
        require(
            x < P && x > 0 && y < P && y > 0 && mulmod(y, y, P) == addmod(mulmod(mulmod(x, x, P), x, P), 7, P),
            "invalid public key"
        );
    }

    function _getAddress(PublicKey memory _pk) internal view returns (address) {
        uint256[2] memory publicKeyPair = [uint256(_pk.x), uint256(_pk.y)];
        bytes32 hash = keccak256(abi.encodePacked(publicKeyPair));
        return address(uint160(uint256(hash)));
    }

}