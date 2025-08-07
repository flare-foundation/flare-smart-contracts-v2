// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../../../../contracts/tee/implementation/TeeWalletBackupManager.sol";
import "../../../../contracts/tee/proxy/TeeWalletBackupManagerProxy.sol";

//solhint-disable-next-line max-states-count
contract TeeWalletBackupManagerTest is Test {

    TeeWalletBackupManager private teeWalletBackupManager;
    TeeWalletBackupManager private teeWalletBackupManagerImpl;
    TeeWalletBackupManagerProxy private teeWalletBackupManagerProxy;

    address private owner;
    address private backupManager;

    address private initialGovernance;
    address private addressUpdater;
    address private teeExtensionRegistry;
    address private teeWalletProjectManager;
    address private teeWalletManager;
    address private teeMachineRegistry;
    address private teeWalletKeyManager;
    address private flareSystemsManager;

    address private teeId;
    address private backupTeeId;
    bytes32 private projectId;
    ITeeWalletBackupManager.BackupId private backupId;
    string private backupUrl;
    uint64 private keyId;
    bytes private publicKey;
    address private keyHolderTeeId;
    uint24 private rewardEpochId;
    bytes32 private opType;
    uint256 private extensionId;
    uint256 private nonce;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    function setUp() public {
        initialGovernance = makeAddr("initialGovernance");
        addressUpdater = makeAddr("addressUpdater");

        owner = makeAddr("owner");
        backupManager = makeAddr("backupManager");
        teeId = makeAddr("teeId");
        backupTeeId = makeAddr("backupTeeId");
        projectId = keccak256("projectId");
        keyId = 1;
        publicKey = bytes("publicKey");
        rewardEpochId = 1;
        opType = keccak256("OP_TYPE");
        keyHolderTeeId = makeAddr("keyHolderTeeId");
        nonce = 1;
        backupId = ITeeWalletBackupManager.BackupId(
            backupTeeId,
            keccak256("walletId"),
            keyId,
            opType,
            publicKey,
            rewardEpochId,
            nonce
        );
        backupUrl = "backupUrl";
        extensionId = 10;

        teeWalletBackupManagerImpl = new TeeWalletBackupManager();
        teeWalletBackupManagerProxy = new TeeWalletBackupManagerProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            initialGovernance,
            addressUpdater,
            address(teeWalletBackupManagerImpl)
        );
        teeWalletBackupManager = TeeWalletBackupManager(address(teeWalletBackupManagerProxy));

        contractNameHashes = new bytes32[](7);
        contractAddresses = new address[](7);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("TeeExtensionRegistry"));
        contractNameHashes[2] = keccak256(abi.encode("TeeMachineRegistry"));
        contractNameHashes[3] = keccak256(abi.encode("TeeWalletProjectManager"));
        contractNameHashes[4] = keccak256(abi.encode("TeeWalletManager"));
        contractNameHashes[5] = keccak256(abi.encode("TeeWalletKeyManager"));
        contractNameHashes[6] = keccak256(abi.encode("FlareSystemsManager"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = makeAddr("TeeExtensionRegistry");
        contractAddresses[2] = makeAddr("TeeOwnerAllowlist");
        contractAddresses[3] = makeAddr("TeeWalletProjectManager");
        contractAddresses[4] = makeAddr("TeeWalletManager");
        contractAddresses[5] = makeAddr("TeeWalletKeyManager");
        contractAddresses[6] = makeAddr("FlareSystemsManager");

        vm.prank(addressUpdater);
        teeWalletBackupManager.updateContractAddresses(contractNameHashes, contractAddresses);

        teeExtensionRegistry = address(teeWalletBackupManager.teeExtensionRegistry());
        teeWalletProjectManager = address(teeWalletBackupManager.teeWalletProjectManager());
        teeWalletManager = address(teeWalletBackupManager.teeWalletManager());
        teeMachineRegistry = address(teeWalletBackupManager.teeMachineRegistry());
        teeWalletKeyManager = address(teeWalletBackupManager.teeWalletKeyManager());
        flareSystemsManager = address(teeWalletBackupManager.flareSystemsManager());

        _mockGetTeeMachineStatus(teeId, ITeeMachineRegistry.TeeStatus.PRODUCTION);
        _mockGetTeeMachineStatus(backupTeeId, ITeeMachineRegistry.TeeStatus.PRODUCTION);
        _mockGetWalletKeyTeeIds(keyHolderTeeId);
        _mockGetWalletKeyPublicKey(publicKey);
        _mockGetExtensionId(backupTeeId, extensionId);
        _mockGetExtensionId(teeId, extensionId);

        vm.mockCall(
            teeWalletProjectManager,
            abi.encodeWithSelector(
                ITeeWalletProjectManager.getOwner.selector,
                projectId
            ),
            abi.encode(owner)
        );

        vm.mockCall(
            teeWalletProjectManager,
            abi.encodeWithSelector(
                ITeeWalletProjectManager.getBackupManager.selector,
                projectId
            ),
            abi.encode(backupManager)
        );

        vm.mockCall(
            teeWalletManager,
            abi.encodeWithSelector(
                ITeeWalletManager.getWalletProjectId.selector
            ),
            abi.encode(projectId)
        );

        vm.mockCall(
            teeMachineRegistry,
            abi.encodeWithSelector(
                ITeeMachineRegistry.getInitialSigningPolicyId.selector
            ),
            abi.encode(uint32(1))
        );

        vm.mockCall(
            flareSystemsManager,
            abi.encodeWithSelector(
                ProtocolsV2Interface.getCurrentRewardEpochId.selector
            ),
            abi.encode(uint24(15))
        );

        vm.mockCall(
            teeWalletProjectManager,
            abi.encodeWithSelector(
                ITeeWalletProjectManager.getOpType.selector
            ),
            abi.encode(opType)
        );

        vm.mockCall(
            teeWalletProjectManager,
            abi.encodeWithSelector(
                ITeeWalletProjectManager.getExtensionId.selector
            ),
            abi.encode(extensionId)
        );

        vm.mockCall(
            teeWalletKeyManager,
            abi.encodeWithSelector(
                IITeeWalletKeyManager.increaseKeyNonce.selector
            ),
            abi.encode(nonce + 1)
        );

        vm.mockCall(
            teeExtensionRegistry,
            abi.encodeWithSelector(
                ITeeExtensionRegistry.sendInstructions.selector
            ),
            abi.encode("")
        );
    }


    // backupRestore
    function testBackupRestoreRevertOnlyOwnerOrBackupManager() public {
        vm.expectRevert(ITeeWalletBackupManager.OnlyOwnerOrBackupManager.selector);
        teeWalletBackupManager.backupRestore(teeId, backupId, backupUrl, true);
    }


    function testBackupRestoreRevertTeeMachineNotAvailable() public {
        _mockGetTeeMachineStatus(teeId, ITeeMachineRegistry.TeeStatus.INITIALIZED);
        vm.expectRevert(ITeeWalletBackupManager.TeeMachineNotAvailable.selector);
        vm.prank(owner);
        teeWalletBackupManager.backupRestore(teeId, backupId, backupUrl, true);
    }


    function testBackupRestoreRevertInvalidTeeMachine() public {
        _mockGetTeeMachineStatus(backupTeeId, ITeeMachineRegistry.TeeStatus.INITIALIZED);
        vm.expectRevert(ITeeWalletBackupManager.InvalidTeeMachine.selector);
        vm.prank(owner);
        teeWalletBackupManager.backupRestore(teeId, backupId, backupUrl, true);
    }


    function testBackupRestoreRevertKeyAlreadyAvailable() public {
        _mockGetWalletKeyTeeIds(teeId);
        vm.prank(owner);
        vm.expectRevert(ITeeWalletBackupManager.KeyAlreadyAvailable.selector);
        teeWalletBackupManager.backupRestore(teeId, backupId, backupUrl, true);
    }


    function testBackupRestoreRevertKeyNotConfirmed() public {
        _mockGetWalletKeyPublicKey(bytes(""));
        vm.prank(owner);
        vm.expectRevert(ITeeWalletBackupManager.KeyNotConfirmed.selector);
        teeWalletBackupManager.backupRestore(teeId, backupId, backupUrl, true);
    }


    function testBackupRestoreRevertInvalidPublicKey() public {
        _mockGetWalletKeyPublicKey(bytes("invalidKey"));
        vm.prank(owner);
        vm.expectRevert(ITeeWalletBackupManager.InvalidPublicKey.selector);
        teeWalletBackupManager.backupRestore(teeId, backupId, backupUrl, true);
    }


    function testBackupRestoreRevertUnsupportedRewardEpochId() public {
        backupId.rewardEpochId = 0;
        vm.prank(owner);
        vm.expectRevert(ITeeWalletBackupManager.UnsupportedRewardEpochId.selector);
        teeWalletBackupManager.backupRestore(teeId, backupId, backupUrl, true);
    }


    function testBackupRestoreRevertInvalidRewardEpochId() public {
        backupId.rewardEpochId = 20;
        vm.prank(owner);
        vm.expectRevert(ITeeWalletBackupManager.InvalidRewardEpochId.selector);
        teeWalletBackupManager.backupRestore(teeId, backupId, backupUrl, true);
    }


    function testBackupRestoreRevertInvalidOpType() public {
        backupId.opType = keccak256("invalidOpType");
        vm.prank(owner);
        vm.expectRevert(ITeeWalletBackupManager.InvalidOpType.selector);
        teeWalletBackupManager.backupRestore(teeId, backupId, backupUrl, true);
    }


    function testBackupRestoreRevertExtensionIdMismatch() public {
        _mockGetExtensionId(backupTeeId, extensionId + 1);
        vm.prank(owner);
        vm.expectRevert(ITeeWalletBackupManager.ExtensionIdMismatch.selector);
        teeWalletBackupManager.backupRestore(teeId, backupId, backupUrl, true);

        _mockGetExtensionId(backupTeeId, extensionId);
        _mockGetExtensionId(teeId, extensionId + 1);
        vm.prank(owner);
        vm.expectRevert(ITeeWalletBackupManager.ExtensionIdMismatch.selector);
        teeWalletBackupManager.backupRestore(teeId, backupId, backupUrl, true);
    }


    function testBackupRestore() public {
        vm.startPrank(owner);
        teeWalletBackupManager.backupRestore(teeId, backupId, backupUrl, true);
        teeWalletBackupManager.backupRestore(teeId, backupId, backupUrl, false);
        vm.stopPrank();
    }


    function _mockGetTeeMachineStatus(
        address _teeId,
        ITeeMachineRegistry.TeeStatus _status
    )
        private
    {
        vm.mockCall(
            teeMachineRegistry,
            abi.encodeWithSelector(
                ITeeMachineRegistry.getTeeMachineStatus.selector,
                _teeId
            ),
            abi.encode(_status)
        );
    }


    function _mockGetWalletKeyTeeIds(address _teeId) private {
        address[] memory teeIds = new address[](1);
        teeIds[0] = _teeId;
        vm.mockCall(
            teeWalletKeyManager,
            abi.encodeWithSelector(
                ITeeWalletKeyManager.getWalletKeyTeeIds.selector
            ),
            abi.encode(teeIds)
        );
    }


    function _mockGetWalletKeyPublicKey(bytes memory _publicKey) private {
        vm.mockCall(
            teeWalletKeyManager,
            abi.encodeWithSelector(
                ITeeWalletKeyManager.getWalletKeyPublicKey.selector
            ),
            abi.encode(_publicKey)
        );
    }


    function _mockGetExtensionId(address _teeId, uint256 _extensionId) private {
        vm.mockCall(
            teeMachineRegistry,
            abi.encodeWithSelector(
                ITeeMachineRegistry.getExtensionId.selector,
                _teeId
            ),
            abi.encode(_extensionId)
        );
    }
}