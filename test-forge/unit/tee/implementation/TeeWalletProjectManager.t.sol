pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../../contracts/tee/implementation/TeeWalletProjectManager.sol";
import "../../../../contracts/tee/implementation/TeeWalletProjectManagerProxy.sol";

contract TeeWalletProjectManagerTest is Test {

    TeeWalletProjectManager private teeWalletProjectManager;
    TeeWalletProjectManager private teeWalletProjectManagerImpl;
    TeeWalletProjectManagerProxy private teeWalletProjectManagerProxy;

    address private mockTeeOwnerAllowlist;
    address private mockTeeWalletManager;
    address private governance;
    address private addressUpdater;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    address private submitAddress1;
    address private submitAddress2;
    bytes32 private opType1;
    bytes32 private opType2;
    address private projectOwner1;
    address private projectOwner2;
    bytes32 private defaultWalletId;

    event BackupManagerSet(
        bytes32 indexed projectId,
        address indexed backupManager
    );

    event DefaultWalletSet(
        bytes32 indexed projectId,
        bytes32 indexed walletId
    );

    event NewOwnerProposed(
        bytes32 indexed projectId,
        address indexed newOwner
    );

    event OwnershipConfirmed(
        bytes32 indexed projectId,
        address indexed newOwner
    );

    function setUp() public {
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");
        mockTeeOwnerAllowlist = makeAddr("mockTeeOwnerAllowlist");
        mockTeeWalletManager = makeAddr("mockTeeWalletManager");

        teeWalletProjectManagerImpl = new TeeWalletProjectManager();
        teeWalletProjectManagerProxy = new TeeWalletProjectManagerProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            address(teeWalletProjectManagerImpl)
        );
        teeWalletProjectManager = TeeWalletProjectManager(address(teeWalletProjectManagerProxy));

        vm.prank(addressUpdater);
        contractNameHashes = new bytes32[](3);
        contractAddresses = new address[](3);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractAddresses[0] = address(addressUpdater);
        contractNameHashes[1] = keccak256(abi.encode("TeeOwnerAllowlist"));
        contractAddresses[1] = address(mockTeeOwnerAllowlist);
        contractNameHashes[2] = keccak256(abi.encode("TeeWalletManager"));
        contractAddresses[2] = address(mockTeeWalletManager);
        teeWalletProjectManager.updateContractAddresses(contractNameHashes, contractAddresses);

        submitAddress1 = makeAddr("submitAddress1");
        submitAddress2 = makeAddr("submitAddress2");
        opType1 = keccak256(abi.encode("opType1"));
        opType2 = keccak256(abi.encode("opType2"));
        projectOwner1 = makeAddr("projectOwner");
        projectOwner2 = makeAddr("projectOwner2");
        defaultWalletId = keccak256(abi.encode("defaultWalletId"));
        _mockIsTeeWalletProjectOwnerAllowed(projectOwner1, true);
        _mockIsTeeWalletProjectOwnerAllowed(projectOwner2, true);
    }

    function testCreateProjectRevertWrongOpType() public {
        bytes32 opType = keccak256(abi.encode("wrongOpType"));
        _mockIsOpTypeSupported(opType, false);
        vm.prank(projectOwner1);
        vm.expectRevert("op type not supported");
        teeWalletProjectManager.createProject(opType, submitAddress1);
    }

    function testCreateProjectRevertOwnerNotAllowed() public {
        _mockIsOpTypeSupported(opType1, true);
        _mockIsTeeWalletProjectOwnerAllowed(projectOwner1, false);
        vm.prank(projectOwner1);
        vm.expectRevert("owner not allowed");
        teeWalletProjectManager.createProject(opType1, submitAddress1);
    }

    function testCreateProjectRevertSubmitAddressZero() public {
        _mockIsOpTypeSupported(opType1, true);
        vm.prank(projectOwner1);
        vm.expectRevert("submit address zero");
        teeWalletProjectManager.createProject(opType1, address(0));
    }

    function testCreateProject() public {
        _mockIsOpTypeSupported(opType1, true);
        _mockIsOpTypeSupported(opType2, true);
        vm.prank(projectOwner1);
        bytes32 projectId = teeWalletProjectManager.createProject(opType1, submitAddress1);
        assertEq(projectId, keccak256(abi.encode("PROJECT", projectOwner1, 1)));

        vm.prank(projectOwner2);
        bytes32 projectId2 = teeWalletProjectManager.createProject(opType2, submitAddress2);
        assertEq(projectId2, keccak256(abi.encode("PROJECT", projectOwner2, 2)));
    }

    function testGetOwner() public {
        testCreateProject();
        bytes32 projectId1 = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        bytes32 projectId2 = keccak256(abi.encode("PROJECT", projectOwner2, 2));
        assertEq(projectOwner1, teeWalletProjectManager.getOwner(projectId1));
        assertEq(projectOwner2, teeWalletProjectManager.getOwner(projectId2));
    }

    function testGetOpType() public {
        testCreateProject();
        bytes32 projectId1 = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        bytes32 projectId2 = keccak256(abi.encode("PROJECT", projectOwner2, 2));
        assertEq(teeWalletProjectManager.getOpType(projectId1), opType1);
        assertEq(teeWalletProjectManager.getOpType(projectId2), opType2);
    }

    function testGetSubmitAddress() public {
        testCreateProject();
        bytes32 projectId1 = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        bytes32 projectId2 = keccak256(abi.encode("PROJECT", projectOwner2, 2));
        assertEq(submitAddress1, teeWalletProjectManager.getSubmitAddress(projectId1));
        assertEq(submitAddress2, teeWalletProjectManager.getSubmitAddress(projectId2));
    }

    function testSetBackupManager() public {
        testCreateProject();
        bytes32 projectId = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        address backupManager = makeAddr("backupManager");
        vm.prank(projectOwner1);
        vm.expectEmit();
        emit BackupManagerSet(projectId, backupManager);
        teeWalletProjectManager.setBackupManager(projectId, backupManager);
        assertEq(backupManager, teeWalletProjectManager.getBackupManager(projectId));
    }

    // revert if project doesn't exist
    function testSetBackupManagerRevert() public {
        address backupManager = makeAddr("backupManager");
        bytes32 projectId = keccak256(abi.encode("PROJECT", projectOwner1, 2));
        vm.expectRevert("only owner");
        teeWalletProjectManager.setBackupManager(projectId, backupManager);
    }

    function testSetBackupManagerRevert2() public {
        testCreateProject();
        bytes32 projectId = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        address backupManager = makeAddr("backupManager");
        vm.prank(projectOwner2);
        vm.expectRevert("only owner");
        teeWalletProjectManager.setBackupManager(projectId, backupManager);
    }

    function testSetDefaultWallet() public {
        testCreateProject();
        bytes32 projectId = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        _mockGetWalletProjectId(defaultWalletId, projectId);
        _mockGetWalletStatus(defaultWalletId, ITeeWalletManager.WalletStatus.PRODUCTION);
        vm.prank(projectOwner1);
        vm.expectEmit();
        emit DefaultWalletSet(projectId, defaultWalletId);
        teeWalletProjectManager.setDefaultWallet(projectId, defaultWalletId);
    }

    // wallet not part of the project
    function testSetDefaultWalletRevert1() public {
        testCreateProject();
        bytes32 projectId1 = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        bytes32 projectId2 = keccak256(abi.encode("PROJECT", projectOwner2, 2));
        _mockGetWalletProjectId(defaultWalletId, projectId2);
        _mockGetWalletStatus(defaultWalletId, ITeeWalletManager.WalletStatus.PRODUCTION);
        vm.prank(projectOwner1);
        vm.expectRevert("wallet not part of the project");
        teeWalletProjectManager.setDefaultWallet(projectId1, defaultWalletId);
    }

    // wallet not in production
    function testSetDefaultWalletRevert2() public {
        testCreateProject();
        bytes32 projectId = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        _mockGetWalletProjectId(defaultWalletId, projectId);
        _mockGetWalletStatus(defaultWalletId, ITeeWalletManager.WalletStatus.PAUSED);
        vm.prank(projectOwner1);
        vm.expectRevert("wallet not production ready");
        teeWalletProjectManager.setDefaultWallet(projectId, defaultWalletId);
    }

    function testGetDefaultWalletInfo() public {
        testSetDefaultWallet();
        bytes32 projectId = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        (bytes32 walletId, bytes32 opType, address submitAddress) =
            teeWalletProjectManager.getDefaultWalletInfo(projectId);
        assertEq(walletId, keccak256(abi.encode("defaultWalletId")));
        assertEq(opType, opType1);
        assertEq(submitAddress, submitAddress1);
    }

    function testProposeNewOwner() public {
        testCreateProject();
        bytes32 projectId1 = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        address newOwner = makeAddr("newOwner");
        _mockIsTeeWalletProjectOwnerAllowed(newOwner, true);
        vm.prank(projectOwner1);
        vm.expectEmit();
        emit NewOwnerProposed(projectId1, newOwner);
        teeWalletProjectManager.proposeNewOwner(projectId1, newOwner);
        assertEq(newOwner, teeWalletProjectManager.proposedProjectOwner(projectId1));
    }

    function testProposeNewOwnerRevertOwnerNotAllowed() public {
        testCreateProject();
        bytes32 projectId1 = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        address newOwner = makeAddr("newOwner");
        _mockIsTeeWalletProjectOwnerAllowed(newOwner, false);
        vm.prank(projectOwner1);
        vm.expectRevert("owner not allowed");
        teeWalletProjectManager.proposeNewOwner(projectId1, newOwner);
    }

    function testConfirmOwnership() public {
        testProposeNewOwner();
        bytes32 projectId1 = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        address newOwner = makeAddr("newOwner");
        vm.prank(newOwner);
        vm.expectEmit();
        emit OwnershipConfirmed(projectId1, newOwner);
        teeWalletProjectManager.confirmOwnership(projectId1);
        assertEq(newOwner, teeWalletProjectManager.getOwner(projectId1));
    }

    function testConfirmOwnershipRevertOnlyProposedOwner() public {
        testProposeNewOwner();
        bytes32 projectId1 = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        vm.prank(projectOwner2);
        vm.expectRevert("only proposed owner");
        teeWalletProjectManager.confirmOwnership(projectId1);
    }

    function testConfirmOwnershipRevertOwnerNotAllowed() public {
        testProposeNewOwner();
        bytes32 projectId1 = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        address newOwner = makeAddr("newOwner");
        _mockIsTeeWalletProjectOwnerAllowed(newOwner, false);
        vm.prank(newOwner);
        vm.expectRevert("owner not allowed");
        teeWalletProjectManager.confirmOwnership(projectId1);
    }

    //// Proxy upgrade
    function testUpgradeProxy() public {
        testCreateProject();
        bytes32 projectId1 = keccak256(abi.encode("PROJECT", projectOwner1, 1));
        assertEq(projectOwner1, teeWalletProjectManager.getOwner(projectId1));
        assertEq(teeWalletProjectManager.implementation(), address(teeWalletProjectManagerImpl));
        // upgrade
        TeeWalletProjectManager newImpl = new TeeWalletProjectManager();
        vm.prank(governance);
        teeWalletProjectManager.upgradeToAndCall(address(newImpl), bytes(""));
        // check
        assertEq(teeWalletProjectManager.implementation(), address(newImpl));
        assertEq(teeWalletProjectManager.governance(), governance);
        assertEq(projectOwner1, teeWalletProjectManager.getOwner(projectId1));
    }

    function testUpgradeProxyRevertOnlyGovernance() public {
        TeeWalletProjectManager newImpl = new TeeWalletProjectManager();
        vm.expectRevert("only governance");
        teeWalletProjectManager.upgradeToAndCall(address(newImpl), bytes(""));
    }

    // should revert if trying to initialize again
    // revert in GovernedBase.initialise
    function testUpgradeProxyAndInitializeRevert() public {
        TeeWalletProjectManager newImpl = new TeeWalletProjectManager();
        vm.prank(governance);
        vm.expectRevert("initialised != false");
        teeWalletProjectManager.upgradeToAndCall(address(newImpl), abi.encodeCall(
            TeeWalletProjectManager.initialize, (
                IGovernanceSettings(makeAddr("governanceSettings")),
                governance,
                addressUpdater
            )
        ));
    }

    function _mockIsTeeWalletProjectOwnerAllowed(address _owner, bool _isAllowed) internal {
        vm.mockCall(
            mockTeeOwnerAllowlist,
            abi.encodeWithSelector(
                ITeeOwnerAllowlist.isAllowedTeeWalletProjectOwner.selector,
                _owner
            ),
            abi.encode(_isAllowed)
        );
    }

    function _mockIsOpTypeSupported(bytes32 _opType, bool _isSupported) internal {
        vm.mockCall(
            mockTeeWalletManager,
            abi.encodeWithSelector(
                ITeeWalletManager.isOpTypeSupported.selector,
                _opType
            ),
            abi.encode(_isSupported)
        );
    }

    function _mockGetWalletProjectId(bytes32 _walletId, bytes32 _projectId) internal {
        vm.mockCall(
            mockTeeWalletManager,
            abi.encodeWithSelector(
                ITeeWalletManager.getWalletProjectId.selector,
                _walletId
            ),
            abi.encode(_projectId)
        );
    }

    function _mockGetWalletStatus(bytes32 _walletId, ITeeWalletManager.WalletStatus _status) internal {
        vm.mockCall(
            mockTeeWalletManager,
            abi.encodeWithSelector(
                ITeeWalletManager.getWalletStatus.selector,
                _walletId
            ),
            abi.encode(_status)
        );
    }


}