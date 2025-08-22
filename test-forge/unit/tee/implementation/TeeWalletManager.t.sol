// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../../../../contracts/tee/implementation/TeeWalletManager.sol";
import "../../../../contracts/tee/proxy/TeeWalletManagerProxy.sol";
import "../../../../contracts/userInterfaces/tee/ITeeFeeCalculator.sol";
import "../../../../contracts/protocol/interface/IIRewardManager.sol";
import "../../../../contracts/tee/proxy/TeeExtensionRegistryProxy.sol";
import "../../../../contracts/tee/implementation/TeeExtensionRegistry.sol";
import "../../../../contracts/userInterfaces/LTS/ProtocolsV2Interface.sol";

contract TeeWalletManagerTest is Test {

    uint256 constant private P = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F;
    bytes32 constant private SET_PAUSING_ADDRESSES = bytes32("SET_PAUSING_ADDRESSES");
    bytes32 public constant WALLET_OP_TYPE = bytes32("F_WALLET");
    bytes32 public constant RESUME = bytes32("RESUME");

    TeeWalletManager private teeWalletManager;
    TeeWalletManager private teeWalletManagerImpl;
    TeeWalletManagerProxy private teeWalletManagerProxy;

    TeeExtensionRegistry private teeExtensionRegistry;
    TeeExtensionRegistryProxy private teeExtensionRegistryProxy;
    TeeExtensionRegistry private teeExtensionRegistryImpl;

    address private mockTeeMachineRegistry;
    address private mockTeeWalletProjectManager;
    address private mockTeeWalletKeyManager;
    address private mockFSM;
    address private mockTeeFeeCalculator;
    address private mockRewardManager;
    address private teeGovernanceMock;

    address private governance;
    address private addressUpdater;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    address private projectOwner;
    bytes32 private projectId;
    bytes32 private walletId;

    function setUp() public {
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");
        mockTeeWalletProjectManager = makeAddr("teeWalletProjectManager");
        mockTeeWalletKeyManager = makeAddr("mockTeeWalletKeyManager");
        mockFSM = makeAddr("flareSystemsManager");
        mockTeeMachineRegistry = makeAddr("teeMachineRegistry");
        mockRewardManager = makeAddr("rewardManager");
        mockTeeFeeCalculator = makeAddr("teeFeeCalculator");
        teeGovernanceMock = makeAddr("teeGovernanceMock");

        teeWalletManagerImpl = new TeeWalletManager();
        teeWalletManagerProxy = new TeeWalletManagerProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            address(teeWalletManagerImpl)
        );
        teeWalletManager = TeeWalletManager(address(teeWalletManagerProxy));

        teeExtensionRegistryImpl = new TeeExtensionRegistry();
        teeExtensionRegistryProxy = new TeeExtensionRegistryProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            address(teeExtensionRegistryImpl)
        );
        teeExtensionRegistry = TeeExtensionRegistry(address(teeExtensionRegistryProxy));

        vm.startPrank(addressUpdater);
        contractNameHashes = new bytes32[](6);
        contractAddresses = new address[](6);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("TeeMachineRegistry"));
        contractNameHashes[2] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[3] = keccak256(abi.encode("TeeExtensionRegistry"));
        contractNameHashes[4] = keccak256(abi.encode("TeeWalletProjectManager"));
        contractNameHashes[5] = keccak256(abi.encode("TeeWalletKeyManager"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = mockTeeMachineRegistry;
        contractAddresses[2] = mockFSM;
        contractAddresses[3] = address(teeExtensionRegistry);
        contractAddresses[4] = mockTeeWalletProjectManager;
        contractAddresses[5] = mockTeeWalletKeyManager;
        teeWalletManager.updateContractAddresses(contractNameHashes, contractAddresses);

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
        contractAddresses[2] = mockTeeMachineRegistry;
        contractAddresses[3] = mockTeeFeeCalculator;
        contractAddresses[4] = mockFSM;
        contractAddresses[5] = mockRewardManager;
        teeExtensionRegistry.updateContractAddresses(contractNameHashes, contractAddresses);
        vm.stopPrank();

        projectOwner = makeAddr("projectOwner");
        projectId = bytes32("project1");
        walletId = keccak256(abi.encode("WALLET", projectOwner, 1));
        _mockGetProjectOwner(projectId, projectOwner);
        // fund project owner
        vm.deal(projectOwner, 1 ether);

        _mockGetCurrentRewardEpochId(10);
        _mockReceiveRewards();
        _mockGetExtensionId(0);

        // set TeeInstructions as system instruction initiator on TeeExtensionRegistry
        vm.prank(governance);
        address[] memory systemInstructionInitiator = new address[](1);
        systemInstructionInitiator[0] = address(teeWalletManager);
        teeExtensionRegistry.registerSystemInstructionInitiators(systemInstructionInitiator);
    }

    function testCreateWallet() public{
        vm.prank(projectOwner);
        vm.expectEmit();
        emit ITeeWalletManager.WalletCreated(projectId, walletId);
        teeWalletManager.createWallet(projectId);

        assertEq(teeWalletManager.getWalletProjectId(walletId), projectId);
        assertEq(uint8(teeWalletManager.getWalletStatus(walletId)), uint8(ITeeWalletManager.WalletStatus.CREATED));
        assertEq(teeWalletManager.getProjectWalletIds(projectId).length, 1);
        assertEq(teeWalletManager.getProjectWalletIds(projectId)[0], walletId);
    }

    function testCreateWalletRevert() public {
        vm.expectRevert(ITeeWalletManager.OnlyOwner.selector);
        teeWalletManager.createWallet(projectId);
    }

    // not enough admins
    function testSetAdminsRevert1() public {
        testCreateWallet();
        PublicKey[] memory admins =  new PublicKey[](2);
        admins[0] = _getRandomPublicKey();
        admins[1] = _getRandomPublicKey();

        vm.prank(projectOwner);
        vm.expectRevert(ITeeWalletManager.NotEnoughAdmins.selector);
        teeWalletManager.setAdmins(walletId, admins, 3);
    }

    // invalid admins threshold
    function testSetAdminsRevert2() public {
        testCreateWallet();
        PublicKey[] memory admins =  new PublicKey[](2);
        admins[0] = _getRandomPublicKey();
        admins[1] = _getRandomPublicKey();

        vm.prank(projectOwner);
        vm.expectRevert(ITeeWalletManager.InvalidAdminsThreshold.selector);
        teeWalletManager.setAdmins(walletId, admins, 0);
    }

    // invalid public key
    function testSetAdminsRevert3() public {
        testCreateWallet();
        PublicKey[] memory admins =  new PublicKey[](2);
        admins[0] = _getRandomPublicKey();

        vm.prank(projectOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeWalletManager.InvalidPublicKey.selector,
                admins[1]
            )
        );
        teeWalletManager.setAdmins(walletId, admins, 1);
    }

    // duplicated public key
    function testSetAdminsRevert4() public {
        testCreateWallet();
        PublicKey[] memory admins =  new PublicKey[](2);
        admins[0] = _getRandomPublicKey();
        admins[1] = admins[0]; // duplicate

        vm.prank(projectOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeWalletManager.DuplicatedPublicKey.selector,
                admins[0]
            )
        );
        teeWalletManager.setAdmins(walletId, admins, 1);
    }

    // only owner
    function testSetAdminsRevert5() public {
        testCreateWallet();
        PublicKey[] memory admins =  new PublicKey[](2);
        admins[0] = _getRandomPublicKey();
        admins[1] = _getRandomPublicKey();

        vm.expectRevert(ITeeWalletManager.OnlyOwner.selector);
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
            teeWalletManager.getWalletAdminsPublicKeysAndThreshold(walletId);
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
            teeWalletManager.getWalletAdminsPublicKeysAndThreshold(walletId);
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
        emit ITeeWalletManager.WalletAdminConfirmed(walletId, admin1);
        teeWalletManager.confirmAdmin(walletId);

        // confirm second admin
        address admin2 = _getAddress(admins[1]);
        vm.prank(admin2);
        vm.expectEmit();
        emit ITeeWalletManager.WalletAdminConfirmed(walletId, admin2);
        teeWalletManager.confirmAdmin(walletId);
    }


    // invalid admin
    function testConfirmAdminsRevert1() public {
        vm.expectRevert(ITeeWalletManager.InvalidAdmin.selector);
        teeWalletManager.confirmAdmin(walletId);
    }

    // invalid threshold
    function testSetCosignersRevert1() public {
        testCreateWallet();
        address[] memory cosigners =  new address[](2);
        cosigners[0] = makeAddr("cosigner1");
        cosigners[1] = makeAddr("cosigner2");

        vm.prank(projectOwner);
        vm.expectRevert(ITeeWalletManager.InvalidCosignersThreshold.selector);
        teeWalletManager.setCosigners(walletId, cosigners, 0);
    }

    // invalid address
    function testSetCosignersRevert2() public {
        testCreateWallet();
        address[] memory cosigners =  new address[](2);
        cosigners[0] = makeAddr("cosigner1");
        cosigners[1] = address(0);

        vm.prank(projectOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeWalletManager.InvalidCosigner.selector,
                cosigners[1]
            )
        );
        teeWalletManager.setCosigners(walletId, cosigners, 1);
    }

    // duplicated cosigner
    function testSetCosignersRevert3() public {
        testCreateWallet();
        address[] memory cosigners =  new address[](2);
        cosigners[0] = makeAddr("cosigner1");
        cosigners[1] = cosigners[0]; // duplicate

        vm.prank(projectOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeWalletManager.DuplicatedCosigner.selector,
                cosigners[1]
            )
        );
        teeWalletManager.setCosigners(walletId, cosigners, 1);
    }

    // only owner
    function testSetCosignersRevert4() public {
        testCreateWallet();
        address[] memory cosigners =  new address[](2);
        cosigners[0] = makeAddr("cosigner1");
        cosigners[1] = makeAddr("cosigner2");

        vm.expectRevert(ITeeWalletManager.OnlyOwner.selector);
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
        emit ITeeWalletManager.WalletCosignerConfirmed(walletId, cosigners[0]);
        teeWalletManager.confirmCosigner(walletId);
        // confirm second cosigner
        vm.prank(cosigners[1]);
        vm.expectEmit();
        emit ITeeWalletManager.WalletCosignerConfirmed(walletId, cosigners[1]);
        teeWalletManager.confirmCosigner(walletId);
    }

    function testConfirmCosignerRevert() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeWalletManager.InvalidCosigner.selector,
                address(this)
            )
        );
        teeWalletManager.confirmCosigner(walletId);
    }

    // only owner
    function testCloseWalletInitializationRevert1() public {
        testCreateWallet();
        vm.expectRevert(ITeeWalletManager.OnlyOwner.selector);
        teeWalletManager.closeWalletInitialization(walletId);
    }

    // admins not set
    function testCloseWalletInitializationRevert2() public {
        testCreateWallet();
        vm.prank(projectOwner);
        vm.expectRevert(ITeeWalletManager.AdminsNotSet.selector);
        teeWalletManager.closeWalletInitialization(walletId);
    }

    // not all admins confirmed
    function testCloseWalletInitializationRevert3() public {
        PublicKey[] memory adminsPublicKeys = testSetAdmins();
        vm.prank(projectOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeWalletManager.NotAllAdminsConfirmed.selector,
                _getAddress(adminsPublicKeys[0])
            )
        );
        teeWalletManager.closeWalletInitialization(walletId);
    }

    // not all cosigners confirmed
    function testCloseWalletInitializationRevert4() public {
        address[] memory cosigners = testSetCosigners();
        vm.prank(projectOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeWalletManager.NotAllCosignersConfirmed.selector,
                cosigners[0]
            )
        );
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
        vm.expectRevert(ITeeWalletManager.InvalidWalletStatus.selector);
        teeWalletManager.setAdmins(walletId, admins, 1);
    }

    function testSetCosignersRevert5() public {
        testCloseWalletInitialization();
        address[] memory cosigners =  new address[](2);
        cosigners[0] = makeAddr("cosigner1");
        cosigners[1] = makeAddr("cosigner2");

        vm.prank(projectOwner);
        vm.expectRevert(ITeeWalletManager.InvalidWalletStatus.selector);
        teeWalletManager.setCosigners(walletId, cosigners, 1);
    }

    function testConfirmAdminsRevert2() public {
        testCloseWalletInitialization();
        vm.expectRevert(ITeeWalletManager.InvalidWalletStatus.selector);
        teeWalletManager.confirmAdmin(walletId);
    }

    function testEnableWalletRevert1() public {
        testCloseWalletInitialization();
        vm.expectRevert(ITeeWalletManager.OnlyOwner.selector);
        teeWalletManager.enableWallet(walletId);
    }

    // invalid wallet status
    function testEnableWalletRevert2() public {
        testCreateWallet();
        vm.prank(projectOwner);
        vm.expectRevert(ITeeWalletManager.InvalidWalletStatus.selector);
        teeWalletManager.enableWallet(walletId);
    }

    // multisig threshold not set
    function testEnableWalletRevert3() public {
        testCloseWalletInitialization();
        _mockGetWalletKeysInfo(walletId, 0, new uint64[](0));
        vm.prank(projectOwner);
        vm.expectRevert(ITeeWalletManager.MultisigThresholdNotSet.selector);
        teeWalletManager.enableWallet(walletId);
    }

    // not enough keys
    function testEnableWalletRevert4() public {
        testCloseWalletInitialization();
        uint64[] memory keyIds = new uint64[](1);
        keyIds[0] = 1;
        _mockGetWalletKeysInfo(walletId, 2, keyIds);
        vm.prank(projectOwner);
        vm.expectRevert(ITeeWalletManager.NotEnoughKeys.selector);
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
        vm.expectRevert(ITeeWalletManager.InvalidWalletStatus.selector); // only production
        teeWalletManager.pauseWallet(walletId);
    }

    function testSetPausingAddresses() public {
        testEnableWallet();
        (ITeeMachineRegistry.TeeMachine[] memory receivingTees,
            TeeIdKeyIdPair[] memory teeIdKeyIdPairs) = _mockReceivingTeesAndKeys();
        address[] memory teeIds = new address[](1);
        teeIds[0] = teeIdKeyIdPairs[0].teeId;
        _mockCalculateFeeByTeeIds(teeIds, WALLET_OP_TYPE, SET_PAUSING_ADDRESSES, 1234);
        _mockGetTeeMachine(teeIds[0]);
        address[] memory pausingAddresses = new address[](2);
        pausingAddresses[0] = makeAddr("pausingAddress1");
        pausingAddresses[1] = makeAddr("pausingAddress2");
        uint256 counter = 0;
        bytes32 instructionId = keccak256(abi.encode(WALLET_OP_TYPE, SET_PAUSING_ADDRESSES, walletId, counter));
        (address[] memory admins, uint64 adminsThreshold) =
            teeWalletManager.getWalletAdminsAndThreshold(walletId);
        ITeeWalletManager.SetPausingAddresses memory message = ITeeWalletManager.SetPausingAddresses(
            walletId,
            counter,
            teeIdKeyIdPairs,
            pausingAddresses
        );
        vm.prank(projectOwner);
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            instructionId,
            10,
            receivingTees,
            WALLET_OP_TYPE,
            SET_PAUSING_ADDRESSES,
            abi.encode(message),
            admins,
            adminsThreshold,
            12345
        );
        teeWalletManager.setPausingAddresses{value: 12345}(walletId, pausingAddresses);
    }

    function testSetPausingAddressesRevertOnlyWalletOwner() public {
        testEnableWallet();
        vm.expectRevert(ITeeWalletManager.OnlyOwner.selector);
        teeWalletManager.setPausingAddresses(walletId, new address[](2));
    }

    function testSetPausingAddressesRevertWrongStatus() public {
        testCreateWallet();
        vm.prank(projectOwner);
        vm.expectRevert(ITeeWalletManager.OnlyProductionOrPausedStatus.selector);
        teeWalletManager.setPausingAddresses(walletId, new address[](2));
    }

    function testSetPausingAddressesRevertFeeTooLow() public {
        testEnableWallet();
        (, TeeIdKeyIdPair[] memory teeIdKeyIdPairs) = _mockReceivingTeesAndKeys();
        address[] memory teeIds = new address[](1);
        teeIds[0] = teeIdKeyIdPairs[0].teeId;
        _mockCalculateFeeByTeeIds(teeIds, WALLET_OP_TYPE, SET_PAUSING_ADDRESSES, 1234);
        vm.prank(projectOwner);
        vm.expectRevert(ITeeExtensionRegistry.FeeTooLow.selector);
        teeWalletManager.setPausingAddresses{value: 1232}(walletId, new address[](2));
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
        _mockGetTeeMachineStatus(ITeeMachineRegistry.TeeStatus.PRODUCTION);
        bytes32 instructionId = keccak256(abi.encode(
            WALLET_OP_TYPE, RESUME, walletId, 0
        ));
        _mockCalculateFeeByTeeIds(teeIds, WALLET_OP_TYPE, RESUME, 1234);
        ITeeWalletManager.Resume memory message = ITeeWalletManager.Resume(
            walletId,
            keysData
        );
        ITeeMachineRegistry.TeeMachine[] memory teeMachines = new ITeeMachineRegistry.TeeMachine[](keysData.length);
        teeMachines[0] = _mockGetTeeMachine(makeAddr("tee1"));
        teeMachines[1] = _mockGetTeeMachine(makeAddr("tee2"));
        vm.prank(projectOwner);
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            instructionId,
            10,
            teeMachines,
            WALLET_OP_TYPE,
            RESUME,
            abi.encode(message),
            new address[](0),
            0,
            1234
        );
        teeWalletManager.resume{value: 1234}(walletId, keysData);
    }

    function testResumeRevertWrongStatus() public {
        testCreateWallet();
        vm.expectRevert(ITeeWalletManager.OnlyProductionOrPausedStatus.selector);
        vm.prank(projectOwner);
        teeWalletManager.resume(walletId, new ITeeWalletManager.ResumeKeyData[](0));
    }

    function testResumeRevertOnlyOwner() public {
        testPauseWallet();
        vm.expectRevert(ITeeWalletManager.OnlyOwner.selector);
        teeWalletManager.resume(walletId, new ITeeWalletManager.ResumeKeyData[](0));
    }

    function testResumeRevertFeeTooLow() public {
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
        _mockGetTeeMachineStatus(ITeeMachineRegistry.TeeStatus.PRODUCTION);
        _mockCalculateFeeByTeeIds(teeIds, WALLET_OP_TYPE, RESUME, 1234);
        ITeeMachineRegistry.TeeMachine[] memory teeMachines = new ITeeMachineRegistry.TeeMachine[](keysData.length);
        teeMachines[0] = _mockGetTeeMachine(makeAddr("tee1"));
        teeMachines[1] = _mockGetTeeMachine(makeAddr("tee2"));
        vm.prank(projectOwner);
        vm.expectRevert(ITeeExtensionRegistry.FeeTooLow.selector);
        teeWalletManager.resume{value: 1233}(walletId, keysData);
    }

    function testResumeRevertWrongKeyId() public {
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
        _mockGetTeeMachineStatus(ITeeMachineRegistry.TeeStatus.PRODUCTION);
        _mockCalculateFeeByTeeIds(teeIds, WALLET_OP_TYPE, RESUME, 1234);
        ITeeMachineRegistry.TeeMachine[] memory teeMachines = new ITeeMachineRegistry.TeeMachine[](keysData.length);
        teeMachines[0] = _mockGetTeeMachine(makeAddr("tee1"));
        teeMachines[1] = _mockGetTeeMachine(makeAddr("tee2"));
        vm.prank(projectOwner);
        vm.expectRevert(ITeeWalletManager.WrongKeyId.selector);
        teeWalletManager.resume{value: 1234}(walletId, keysData);
    }

    function testResumeRevertTeeMachineNotAvailable() public {
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
        _mockGetTeeMachineStatus(ITeeMachineRegistry.TeeStatus.PAUSED);
        _mockCalculateFeeByTeeIds(teeIds, WALLET_OP_TYPE, RESUME, 1234);
        ITeeMachineRegistry.TeeMachine[] memory teeMachines = new ITeeMachineRegistry.TeeMachine[](keysData.length);
        teeMachines[0] = _mockGetTeeMachine(makeAddr("tee1"));
        teeMachines[1] = _mockGetTeeMachine(makeAddr("tee2"));
        vm.prank(projectOwner);
        vm.expectRevert(ITeeWalletManager.TeeMachineNotAvailable.selector);
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
        ITeeMachineRegistry.TeeMachine[] memory,
        TeeIdKeyIdPair[] memory _teeIdKeyIdPairs
    ) {
        ITeeMachineRegistry.TeeMachine[] memory receivingTees = new ITeeMachineRegistry.TeeMachine[](1);
        TeeIdKeyIdPair[] memory teeIdKeyIdPairs =
            new TeeIdKeyIdPair[](1);
        receivingTees[0] = ITeeMachineRegistry.TeeMachine({
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
            abi.encode(teeIdKeyIdPairs)
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

    function _mockGetTeeMachineStatus(ITeeMachineRegistry.TeeStatus _status) internal {
        vm.mockCall(
            mockTeeMachineRegistry,
            abi.encodeWithSelector(ITeeMachineRegistry.getTeeMachineStatus.selector),
            abi.encode(_status)
        );
    }

    function _mockGetTeeMachine(
        address _teeId
    ) internal  returns (ITeeMachineRegistry.TeeMachine memory) {
        ITeeMachineRegistry.TeeMachine memory teeMachine = ITeeMachineRegistry.TeeMachine({
            teeId: _teeId,
            teeProxyId: makeAddr("teeProxyId"),
            url: "teeUrl"
        });
        vm.mockCall(
            mockTeeMachineRegistry,
            abi.encodeWithSelector(ITeeMachineRegistry.getTeeMachine.selector, _teeId),
            abi.encode(teeMachine)
        );
        return teeMachine;
    }

    function _mockGetExtensionId(uint256 _extensionId) internal {
        vm.mockCall(
            mockTeeMachineRegistry,
            abi.encodeWithSelector(
                ITeeMachineRegistry.getExtensionId.selector
            ),
            abi.encode(_extensionId)
        );
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

    function _getAddress(PublicKey memory _pk) internal pure returns (address) {
        uint256[2] memory publicKeyPair = [uint256(_pk.x), uint256(_pk.y)];
        bytes32 hash = keccak256(abi.encodePacked(publicKeyPair));
        return address(uint160(uint256(hash)));
    }

}