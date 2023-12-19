// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// import {Test, console2} from "forge-std/Test.sol";
import "forge-std/Test.sol";
import "../../../contracts/protocol/implementation/EntityManager.sol";

contract EntityManagerTest is Test {

    EntityManager private entityManager;
    address private user1;
    bytes20 private nodeId1;

    event NodeIdRegistered(address indexed voter, bytes20 indexed nodeId);
    event NodeIdUnregistered(address indexed voter, bytes20 indexed nodeId);
    event DataProviderAddressRegistered(address indexed voter, address indexed dataProviderAddress);
    event DataProviderAddressRegistrationConfirmed(address indexed voter, address indexed signingAddress);
    event MaxNodeIdsPerEntitySet(uint256 maxNodeIdsPerEntity);
    event SigningAddressRegistered(address indexed voter, address indexed signingAddress);
    event SigningAddressRegistrationConfirmed(address indexed voter, address indexed signingAddress);

    function setUp() public {
        entityManager = new EntityManager(IGovernanceSettings(makeAddr("contract")), makeAddr("user0"), 4);
        user1 = makeAddr("user1");
        nodeId1 = bytes20(keccak256("nodeId1"));
    }

    function testRevertConstructorZeroNodesPerEntity() public {
        vm.expectRevert("max node ids per entity zero");
        new EntityManager(IGovernanceSettings(makeAddr("contract")), makeAddr("user0"), 0);
    }

    function testRegisterNodeId() public {
        assertEq(entityManager.getNodeIdsOfAt(user1, 100).length, 0);

        vm.prank(user1);
        vm.expectEmit();
        emit NodeIdRegistered(user1, nodeId1);
        vm.roll(101);
        entityManager.registerNodeId(nodeId1);
        bytes20[] memory nodeIds = entityManager.getNodeIdsOfAt(user1, 101);
        assertEq(nodeIds.length, 1);
        assertEq(nodeIds[0], nodeId1);
        assertEq(entityManager.getNodeIdsOfAt(user1, 100).length, 0);

        // should revert if trying to register the same node id again
        vm.expectRevert("node id already registered");
        entityManager.registerNodeId(nodeId1);
    }

    function testRevertSettingTooManyNodesPerEntity() public {
        bytes20 nodeId2 = bytes20(keccak256("nodeId2"));
        bytes20 nodeId3 = bytes20(keccak256("nodeId3"));
        bytes20 nodeId4 = bytes20(keccak256("nodeId4"));
        bytes20 nodeId5 = bytes20(keccak256("nodeId5"));

        vm.startPrank(user1);
        entityManager.registerNodeId(nodeId1);
        entityManager.registerNodeId(nodeId2);
        entityManager.registerNodeId(nodeId3);
        entityManager.registerNodeId(nodeId4);
        vm.expectRevert("Max nodes exceeded");
        entityManager.registerNodeId(nodeId5);
    }

    function testSetMaxNodePerEntity() public {
        assertEq(entityManager.maxNodeIdsPerEntity(), 4);
        // only governance
        vm.prank(makeAddr("user0"));
        vm.expectEmit();
        emit MaxNodeIdsPerEntitySet(5);
        entityManager.setMaxNodeIdsPerEntity(5);
        assertEq(entityManager.maxNodeIdsPerEntity(), 5);
    }

    function testRevertSetMaxNodePerEntityOnlyGovernance() public {
        vm.expectRevert("only governance");
        entityManager.setMaxNodeIdsPerEntity(5);
    }

    function testRevertDecreaseMaxNodePerEntity() public {
        vm.startPrank(makeAddr("user0"));
        vm.expectRevert("can increase only");
        entityManager.setMaxNodeIdsPerEntity(3);
    }

    function testUnregisterNodeId() public {
        vm.startPrank(user1);

        // should revert if trying to unregister a node id that is not registered
        vm.expectRevert("node id not registered with msg.sender");
        entityManager.unregisterNodeId(nodeId1);

        // register
        entityManager.registerNodeId(nodeId1);
        bytes20[] memory nodeIds = entityManager.getNodeIdsOfAt(user1, block.number);
        assertEq(nodeIds.length, 1);
        assertEq(nodeIds[0], nodeId1);

        // unregister
        vm.expectEmit();
        emit NodeIdUnregistered(user1, nodeId1);
        entityManager.unregisterNodeId(nodeId1);
        nodeIds = entityManager.getNodeIdsOfAt(user1, block.number);
        assertEq(nodeIds.length, 0);
    }

    function testRegisterDataProviderAddress() public {
        address dataProvider1 = makeAddr("dataProvider1");
        vm.prank(user1);
        vm.expectEmit();
        emit DataProviderAddressRegistered(user1, dataProvider1);
        entityManager.registerDataProviderAddress(dataProvider1);
    }

    function testConfirmDataProviderRegistration() public {
        address dataProvider1 = makeAddr("dataProvider1");

        // should not confirm if not in queue
        vm.prank(dataProvider1);
        vm.expectRevert("data provider address not in registration queue");
        entityManager.confirmDataProviderAddressRegistration(user1);

        // register data provider
        vm.prank(user1);
        entityManager.registerDataProviderAddress(dataProvider1);

        // confirm registration
        assertEq(entityManager.getDataProviderAddress(user1), user1);
        vm.prank(dataProvider1);
        vm.expectEmit();
        emit DataProviderAddressRegistrationConfirmed(user1, dataProvider1);
        entityManager.confirmDataProviderAddressRegistration(user1);
        assertEq(entityManager.getDataProviderAddress(user1), dataProvider1);

        // should not register if already registered
        vm.prank(user1);
        vm.expectRevert("data provider address already registered");
        entityManager.registerDataProviderAddress(dataProvider1);

        // should not confirm if already registered
        vm.prank(dataProvider1);
        vm.expectRevert("data provider address already registered");
        entityManager.confirmDataProviderAddressRegistration(user1);
    }

    function testRegisterSigningAddress() public {
        address signer1 = makeAddr("signer1");
        vm.prank(user1);
        vm.expectEmit();
        emit SigningAddressRegistered(user1, signer1);
        entityManager.registerSigningAddress(signer1);
    }

    function testConfirmSigningAddressRegistration() public {
        address signer1 = makeAddr("signer1");

        // should not confirm if not in queue
        vm.prank(signer1);
        vm.expectRevert("signing address not in registration queue");
        entityManager.confirmSigningAddressRegistration(user1);

        // register signing address
        vm.prank(user1);
        entityManager.registerSigningAddress(signer1);

        // confirm registration
        assertEq(entityManager.getSigningAddress(user1), user1);
        vm.prank(signer1);
        vm.expectEmit();
        emit SigningAddressRegistrationConfirmed(user1, signer1);
        entityManager.confirmSigningAddressRegistration(user1);
        assertEq(entityManager.getSigningAddress(user1), signer1);

        // should not register if already registered
        vm.prank(user1);
        vm.expectRevert("signing address already registered");
        entityManager.registerSigningAddress(signer1);

        // should not confirm if already registered
        vm.prank(signer1);
        vm.expectRevert("signing address already registered");
        entityManager.confirmSigningAddressRegistration(user1);
    }

}
