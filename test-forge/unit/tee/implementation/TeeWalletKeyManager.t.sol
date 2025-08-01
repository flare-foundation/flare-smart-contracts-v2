// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.27;

// import "forge-std/Test.sol";
// import "../../../../contracts/tee/implementation/TeeWalletKeyManager.sol";
// import "../../../../contracts/tee/proxy/TeeWalletKeyManagerProxy.sol";
// import "../../../../contracts/tee/implementation/TeeInstructions.sol";
// import "../../../../contracts/tee/proxy/TeeInstructionsProxy.sol";
// import "../../../../contracts/protocol/interface/IIRewardManager.sol";
// import "../../../../contracts/userInterfaces/tee/ITeeFeeCalculator.sol";

// // solhint-disable-next-line max-states-count
// contract TeeWalletKeyManagerTest is Test {

//     uint256 constant private P = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F;

//     bytes32 public constant WALLET_OP_TYPE = bytes32("WALLET");
//     bytes32 public constant KEY_GENERATE = bytes32("KEY_GENERATE");
//     bytes32 public constant KEY_DELETE = bytes32("KEY_DELETE");

//     TeeWalletKeyManager private teeWalletKeyManager;
//     TeeWalletKeyManager private teeWalletKeyManagerImpl;
//     TeeWalletKeyManagerProxy private teeWalletKeyManagerProxy;

//     TeeInstructions private teeInstructions;
//     TeeInstructions private teeInstructionsImpl;
//     TeeInstructionsProxy private teeInstructionsProxy;

//     address private mockTeeRegistry;
//     address private mockTeeWalletProjectManager;
//     address private mockTeeWalletManager;
//     address private mockFSM;
//     address private mockTeeWalletBackupManager;
//     address private mockTeeFeeCalculator;
//     address private mockRewardManager;

//     address private governance;
//     address private addressUpdater;

//     bytes32[] private contractNameHashes;
//     address[] private contractAddresses;

//     bytes32 private walletId;
//     bytes32 private projectId;
//     address private projectOwner;
//     address private teeId;

//     event TeeInstructionsSent(
//         bytes32 indexed instructionId,
//         uint24 indexed rewardEpochId,
//         ITeeMachineRegistry.TeeMachine[] teeMachines,
//         bytes32 opType,
//         bytes32 opCommand,
//         bytes message,
//         uint256 fee
//     );

//     function setUp() public {
//         governance = makeAddr("governance");
//         addressUpdater = makeAddr("addressUpdater");
//         mockTeeWalletProjectManager = makeAddr("teeWalletProjectManager");
//         mockTeeWalletManager = makeAddr("teeWalletManager");
//         mockFSM = makeAddr("flareSystemsManager");
//         mockTeeRegistry = makeAddr("teeRegistry");
//         mockRewardManager = makeAddr("rewardManager");
//         mockTeeFeeCalculator = makeAddr("teeFeeCalculator");
//         mockTeeWalletBackupManager = makeAddr("teeWalletBackupManager");
//         teeInstructionsImpl = new TeeInstructions();
//         teeInstructionsProxy = new TeeInstructionsProxy(
//             IGovernanceSettings(makeAddr("governanceSettings")),
//             governance,
//             addressUpdater,
//             address(teeInstructionsImpl)
//         );
//         teeInstructions = TeeInstructions(address(teeInstructionsProxy));

//         teeWalletKeyManagerImpl = new TeeWalletKeyManager();
//         teeWalletKeyManagerProxy = new TeeWalletKeyManagerProxy(
//             IGovernanceSettings(makeAddr("governanceSettings")),
//             governance,
//             addressUpdater,
//             address(teeWalletKeyManagerImpl)
//         );
//         teeWalletKeyManager = TeeWalletKeyManager(address(teeWalletKeyManagerProxy));

//         vm.prank(addressUpdater);
//         contractNameHashes = new bytes32[](8);
//         contractAddresses = new address[](8);
//         contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
//         contractNameHashes[1] = keccak256(abi.encode("TeeRegistry"));
//         contractNameHashes[2] = keccak256(abi.encode("FlareSystemsManager"));
//         contractNameHashes[3] = keccak256(abi.encode("TeeFeeCalculator"));
//         contractNameHashes[4] = keccak256(abi.encode("TeeInstructions"));
//         contractNameHashes[5] = keccak256(abi.encode("TeeWalletProjectManager"));
//         contractNameHashes[6] = keccak256(abi.encode("TeeWalletManager"));
//         contractNameHashes[7] = keccak256(abi.encode("TeeWalletBackupManager"));
//         contractAddresses[0] = addressUpdater;
//         contractAddresses[1] = mockTeeRegistry;
//         contractAddresses[2] = mockFSM;
//         contractAddresses[3] = mockTeeFeeCalculator;
//         contractAddresses[4] = address(teeInstructions);
//         contractAddresses[5] = mockTeeWalletProjectManager;
//         contractAddresses[6] = mockTeeWalletManager;
//         contractAddresses[7] = mockTeeWalletBackupManager;
//         teeWalletKeyManager.updateContractAddresses(contractNameHashes, contractAddresses);

//         vm.prank(addressUpdater);
//         contractNameHashes = new bytes32[](2);
//         contractAddresses = new address[](2);
//         contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
//         contractNameHashes[1] = keccak256(abi.encode("RewardManager"));
//         contractAddresses[0] = addressUpdater;
//         contractAddresses[1] = mockRewardManager;
//         teeInstructions.updateContractAddresses(contractNameHashes, contractAddresses);

//         vm.prank(governance);
//         address[] memory instructionInitiators = new address[](1);
//         instructionInitiators[0] = address(teeWalletKeyManager);
//         teeInstructions.registerInstructionInitiators(instructionInitiators);

//         walletId = bytes32("walletId");
//         projectId = bytes32("projectId");
//         projectOwner = makeAddr("projectOwner");
//         teeId = makeAddr("teeId");

//         // fund project owner
//         vm.deal(projectOwner, 10 ether);
//         _mockReceiveRewards();
//     }

//     function testSetMultisigThreshold() public {
//         _mockGetWalletProjectId(walletId, projectId);
//         _mockGetOwner(projectId, projectOwner);
//         _mockGetWalletStatus(walletId, ITeeWalletManager.WalletStatus.INITIALIZED);

//         (uint64 multisigThreshold, , ) = teeWalletKeyManager.getWalletKeysInfo(walletId);
//         assertEq(multisigThreshold, 0);
//         vm.prank(projectOwner);
//         teeWalletKeyManager.setMultisigThreshold(walletId, 2);
//         (multisigThreshold, , ) = teeWalletKeyManager.getWalletKeysInfo(walletId);
//         assertEq(multisigThreshold, 2);
//     }

//     function testSetMultisigThresholdRevert1() public {
//         _mockGetWalletProjectId(walletId, projectId);
//         _mockGetOwner(projectId, projectOwner);

//         vm.prank(projectOwner);
//         vm.expectRevert("invalid threshold");
//         teeWalletKeyManager.setMultisigThreshold(walletId, 0);
//     }

//     function testSetMultisigThresholdRevert2() public {
//         _mockGetWalletProjectId(walletId, projectId);
//         _mockGetOwner(projectId, projectOwner);
//         _mockGetWalletStatus(walletId, ITeeWalletManager.WalletStatus.CREATED);

//         vm.prank(projectOwner);
//         vm.expectRevert("invalid wallet status");
//         teeWalletKeyManager.setMultisigThreshold(walletId, 2);
//     }

//     function testAddKey() public {
//         _mockGetWalletProjectId(walletId, projectId);
//         _mockGetOwner(projectId, projectOwner);
//         _mockGetWalletStatus(walletId, ITeeWalletManager.WalletStatus.INITIALIZED);
//         _mockCalculateFeeByTeeIds(KEY_GENERATE, teeId, 1000);
//         _mockGetTeeMachineStatus(teeId, ITeeMachineRegistry.TeeStatus.PRODUCTION);

//         PublicKey[] memory adminsPublicKeys = new PublicKey[](2);
//         adminsPublicKeys[0] = _getRandomPublicKey();
//         adminsPublicKeys[1] = _getRandomPublicKey();
//         _mockGetWalletAdminsAndThreshold(walletId, adminsPublicKeys, 2);

//         address[] memory cosigners = new address[](2);
//         cosigners[0] = makeAddr("cosigner1");
//         cosigners[1] = makeAddr("cosigner2");
//         _mockGetWalletCosignersAndThreshold(walletId, cosigners, 1);

//         bytes32 opType = bytes32("XRP");
//         _mockGetOpType(projectId, opType);

//         bytes memory opTypeConstants = bytes("opTypeConstants");
//         _mockGetOpTypeConstants(walletId, opTypeConstants);

//         _mockGetCurrentRewardEpochId(15);
//         ITeeMachineRegistry.TeeMachine memory _teeMachine = ITeeMachineRegistry.TeeMachine({
//             teeId: teeId,
//             teeProxyId: makeAddr("teeProxyId"),
//             url: "http://tee-machine-url.com"
//         });
//         _mockGetTeeMachine(teeId, _teeMachine);
//         ITeeMachineRegistry.TeeMachine[] memory teeMachines = new ITeeMachineRegistry.TeeMachine[](1);
//         teeMachines[0] = _teeMachine;

//         uint64 keyId = 0;

//         ITeeWalletKeyManager.KeyGenerate memory message = ITeeWalletKeyManager.KeyGenerate({
//             teeId: teeId,
//             walletId: walletId,
//             keyId: keyId,
//             opType: opType,
//             configConstants: ITeeWalletKeyManager.KeyConfigConstants({
//                 adminsPublicKeys: adminsPublicKeys,
//                 adminsThreshold: 2,
//                 cosigners: cosigners,
//                 cosignersThreshold: 1,
//                 opTypeConstants: opTypeConstants
//             })
//         });
//         bytes32 instructionId = keccak256(abi.encode(
//             WALLET_OP_TYPE, KEY_GENERATE, walletId, keyId
//         ));

//         vm.prank(projectOwner);
//         vm.expectEmit();
//         emit TeeInstructionsSent(
//             instructionId,
//             15,
//             teeMachines,
//             WALLET_OP_TYPE,
//             KEY_GENERATE,
//             abi.encode(message),
//             1001
//         );
//         teeWalletKeyManager.addKey{value: 1001} (teeId, walletId);
//     }

//     function testAddKeyRevert1() public {
//         _mockGetWalletProjectId(walletId, projectId);
//         _mockGetOwner(projectId, projectOwner);
//         _mockGetTeeMachineStatus(teeId, ITeeMachineRegistry.TeeStatus.PAUSED);

//         vm.prank(projectOwner);
//         vm.expectRevert("tee machine not available");
//         teeWalletKeyManager.addKey(teeId, walletId);
//     }

//     function testAddKeyRevert2() public {
//         _mockGetWalletProjectId(walletId, projectId);
//         _mockGetOwner(projectId, projectOwner);
//         _mockGetWalletStatus(walletId, ITeeWalletManager.WalletStatus.CREATED);
//         _mockGetTeeMachineStatus(teeId, ITeeMachineRegistry.TeeStatus.PRODUCTION);

//         vm.prank(projectOwner);
//         vm.expectRevert("invalid wallet status");
//         teeWalletKeyManager.addKey(teeId, walletId);
//     }

//     function testAddKeyRevert3() public {
//         _mockGetWalletProjectId(walletId, projectId);
//         _mockGetOwner(projectId, projectOwner);
//         _mockGetWalletStatus(walletId, ITeeWalletManager.WalletStatus.INITIALIZED);
//         _mockGetTeeMachineStatus(teeId, ITeeMachineRegistry.TeeStatus.PRODUCTION);
//         _mockCalculateFeeByTeeIds(KEY_GENERATE, teeId, 1000);

//         vm.prank(projectOwner);
//         vm.expectRevert("fee too low");
//         teeWalletKeyManager.addKey{value: 999} (teeId, walletId);
//     }

//     function testConfirmKey() public {

//     }


//     //// helper functions ////
//     function _getRandomPublicKey() private returns (PublicKey memory) {
//         // call external script to get random public key coordinates
//         string[] memory command = new string[](2);
//         command[0] = "node";
//         command[1] = "test-forge/utils/generate-key.js";
//         bytes memory result = vm.ffi(command);

//         // check if result is 64 bytes
//         require(result.length == 64, "invalid output length");

//         // extract x and y as bytes32
//         bytes32 x;
//         bytes32 y;
//         // solhint-disable-next-line no-inline-assembly
//         assembly {
//             x := mload(add(result, 32)) // first 32 bytes (hex-decoded)
//             y := mload(add(result, 64)) // second 32 bytes
//         }

//         PublicKey memory pk = PublicKey(x, y);
//         // test that the coordinates are valid
//         _checkPublicKeyValidity(pk);

//         return pk;
//     }

//     function _checkPublicKeyValidity(PublicKey memory _pk) internal pure {
//         uint256 x = uint256(_pk.x);
//         uint256 y = uint256(_pk.y);
//         require(
//             x < P && x > 0 && y < P && y > 0 && mulmod(y, y, P) == addmod(mulmod(mulmod(x, x, P), x, P), 7, P),
//             "invalid public key"
//         );
//     }

//     function _mockGetWalletProjectId(bytes32 _walletId, bytes32 _projectId) internal {
//         vm.mockCall(
//             mockTeeWalletManager,
//             abi.encodeWithSelector(
//                 ITeeWalletManager.getWalletProjectId.selector,
//                 _walletId
//             ),
//             abi.encode(_projectId)
//         );
//     }

//     function _mockGetOwner(bytes32 _projectId, address _projectOwner) internal {
//         vm.mockCall(
//             mockTeeWalletProjectManager,
//             abi.encodeWithSelector(
//                 ITeeWalletProjectManager.getOwner.selector,
//                 _projectId
//             ),
//             abi.encode(_projectOwner)
//         );
//     }

//     function _mockGetWalletStatus(
//         bytes32 _walletId,
//         ITeeWalletManager.WalletStatus _status
//     ) internal {
//         vm.mockCall(
//             mockTeeWalletManager,
//             abi.encodeWithSelector(
//                 ITeeWalletManager.getWalletStatus.selector,
//                 _walletId
//             ),
//             abi.encode(_status)
//         );
//     }

//     function _mockCalculateFeeByTeeIds(bytes32 _opCommand, address _teeId, uint256 _fee) internal {
//         address[] memory teeIds = new address[](1);
//         teeIds[0] = _teeId;
//         vm.mockCall(
//             mockTeeFeeCalculator,
//             abi.encodeWithSelector(
//                 ITeeFeeCalculator.calculateFeeByTeeIds.selector,
//                 WALLET_OP_TYPE,
//                 _opCommand,
//                 teeIds
//             ),
//             abi.encode(_fee)
//         );
//     }

//     function _mockGetTeeMachineStatus(address _teeId, ITeeMachineRegistry.TeeStatus _status) internal {
//         vm.mockCall(
//             mockTeeRegistry,
//             abi.encodeWithSelector(
//                 ITeeMachineRegistry.getTeeMachineStatus.selector,
//                 _teeId
//             ),
//             abi.encode(_status)
//         );
//     }

//     function _mockGetWalletAdminsAndThreshold(
//         bytes32 _walletId,
//         PublicKey[] memory _adminsPublicKeys,
//         uint64 _adminsThreshold
//     ) internal {
//         vm.mockCall(
//             mockTeeWalletManager,
//             abi.encodeWithSelector(
//                 ITeeWalletManager.getWalletAdminsAndThreshold.selector,
//                 _walletId
//             ),
//             abi.encode(_adminsPublicKeys, _adminsThreshold)
//         );
//     }

//     function _mockGetWalletCosignersAndThreshold(
//         bytes32 _walletId,
//         address[] memory _cosigners,
//         uint64 _cosignersThreshold
//     ) internal {
//         vm.mockCall(
//             mockTeeWalletManager,
//             abi.encodeWithSelector(
//                 ITeeWalletManager.getWalletCosignersAndThreshold.selector,
//                 _walletId
//             ),
//             abi.encode(_cosigners, _cosignersThreshold)
//         );
//     }

//     function _mockGetOpType(bytes32 _projectId, bytes32 _opType) internal {
//         vm.mockCall(
//             mockTeeWalletProjectManager,
//             abi.encodeWithSelector(
//                 ITeeWalletProjectManager.getOpType.selector,
//                 _projectId
//             ),
//             abi.encode(_opType)
//         );
//     }

//     function _mockGetOpTypeConstants(
//         bytes32 _walletId,
//         bytes memory _opTypeConstants
//     ) internal {
//         vm.mockCall(
//             mockTeeWalletManager,
//             abi.encodeWithSelector(
//                 ITeeWalletProjectManager.getOpTypeConstants.selector,
//                 _walletId
//             ),
//             abi.encode(_opTypeConstants)
//         );
//     }

//     function _mockGetCurrentRewardEpochId(uint24 _epochId) internal {
//         vm.mockCall(
//             mockFSM,
//             abi.encodeWithSelector(
//                 ProtocolsV2Interface.getCurrentRewardEpochId.selector
//             ),
//             abi.encode(_epochId)
//         );
//     }

//     function _mockGetTeeMachine(
//         address _teeId,
//         ITeeMachineRegistry.TeeMachine memory _teeMachine
//     ) internal {
//         vm.mockCall(
//             mockTeeRegistry,
//             abi.encodeWithSelector(
//                 ITeeMachineRegistry.getTeeMachine.selector,
//                 _teeId
//             ),
//             abi.encode(_teeMachine)
//         );
//     }

//     function _mockReceiveRewards() internal {
//         vm.mockCall(
//             mockRewardManager,
//             abi.encodeWithSelector(IIRewardManager.receiveRewards.selector),
//             abi.encode()
//         );
//     }

// }