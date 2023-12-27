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
    event DepositSignaturesAddressRegistered(
        address indexed voter, address indexed depositSignaturesAddress);
    event DepositSignaturesAddressRegistrationConfirmed(
        address indexed voter, address indexed depositSignaturesAddress);
    event SigningPolicyAddressRegistered(
        address indexed voter, address indexed signingPolicyAddress);
    event SigningPolicyAddressRegistrationConfirmed(
        address indexed voter, address indexed signingPolicyAddress);

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
        vm.roll(100);
        assertEq(entityManager.getNodeIdsOfAt(user1, block.number).length, 0);
        assertEq(entityManager.getNodeIdsOf(user1).length, 0);
        assertEq(entityManager.getVoterForNodeId(nodeId1, block.number), address(0));

        vm.prank(user1);
        vm.expectEmit();
        emit NodeIdRegistered(user1, nodeId1);
        vm.roll(101);
        entityManager.registerNodeId(nodeId1);
        bytes20[] memory nodeIds = entityManager.getNodeIdsOfAt(user1, 101);
        assertEq(nodeIds.length, 1);
        assertEq(nodeIds[0], nodeId1);
        assertEq(entityManager.getNodeIdsOfAt(user1, 100).length, 0);
        assertEq(entityManager.getNodeIdsOf(user1).length, 1);
        assertEq(entityManager.getVoterForNodeId(nodeId1, 100), address(0));
        assertEq(entityManager.getVoterForNodeId(nodeId1, block.number), user1);

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

    function testConfirmDataProviderAddressRegistration() public {
        vm.roll(100);
        address dataProvider1 = makeAddr("dataProvider1");
        address[] memory voters = new address[](1);
        voters[0] = user1;
        assertEq(entityManager.getDataProviderAddresses(voters, 100)[0], user1);

        // should not confirm if not in queue
        vm.prank(dataProvider1);
        vm.expectRevert("data provider address not in registration queue");
        entityManager.confirmDataProviderAddressRegistration(user1);

        // register data provider
        vm.prank(user1);
        entityManager.registerDataProviderAddress(dataProvider1);

        // confirm registration
        assertEq(entityManager.getDataProviderAddresses(voters, 100)[0], user1);
        vm.roll(200);
        vm.prank(dataProvider1);
        vm.expectEmit();
        emit DataProviderAddressRegistrationConfirmed(user1, dataProvider1);
        entityManager.confirmDataProviderAddressRegistration(user1);
        assertEq(entityManager.getDataProviderAddresses(voters, 200)[0], dataProvider1);

        // should not register if already registered
        vm.prank(user1);
        vm.expectRevert("data provider address already registered");
        entityManager.registerDataProviderAddress(dataProvider1);

        // should not confirm if already registered
        vm.prank(dataProvider1);
        vm.expectRevert("data provider address already registered");
        entityManager.confirmDataProviderAddressRegistration(user1);
    }

    function testChangeDataProviderAddress() public {
        vm.roll(100);
        address dataProvider1 = makeAddr("dataProvider1");
        address dataProvider2 = makeAddr("dataProvider2");
        address[] memory voters = new address[](1);
        voters[0] = user1;

        // register data provider
        vm.prank(user1);
        entityManager.registerDataProviderAddress(dataProvider1);
        assertEq(entityManager.getDataProviderAddresses(voters, 100)[0], user1);
        assertEq(entityManager.getVoterForDataProviderAddress(dataProvider1, 100), dataProvider1);

        // confirm registration
        vm.prank(dataProvider1);
        entityManager.confirmDataProviderAddressRegistration(user1);
        assertEq(entityManager.getDataProviderAddresses(voters, 100)[0], dataProvider1);
        assertEq(entityManager.getVoterForDataProviderAddress(dataProvider1, 100), user1);

        // register another data provider
        vm.prank(user1);
        entityManager.registerDataProviderAddress(dataProvider2);
        assertEq(entityManager.getDataProviderAddresses(voters, 100)[0], dataProvider1);

        // confirm registration and replace first data provider
        vm.roll(200);
        vm.prank(dataProvider2);
        entityManager.confirmDataProviderAddressRegistration(user1);
        assertEq(entityManager.getDataProviderAddresses(voters, 100)[0], dataProvider1);
        assertEq(entityManager.getDataProviderAddresses(voters, 200)[0], dataProvider2);
    }

    function testRegisterDepositSignatureAddress() public {
        address depositSignaturesAddr1 = makeAddr("depositSignaturesAddr1");
        vm.prank(user1);
        vm.expectEmit();
        emit DepositSignaturesAddressRegistered(user1, depositSignaturesAddr1);
        entityManager.registerDepositSignaturesAddress(depositSignaturesAddr1);
    }

    function testConfirmDepositSignaturesAddressRegistration() public {
        vm.roll(100);
        address depositSignaturesAddr1 = makeAddr("depositSignaturesAddr1");
        address[] memory voters = new address[](1);
        voters[0] = user1;
        assertEq(entityManager.getDepositSignaturesAddresses(voters, 100)[0], user1);


        // should not confirm if not in queue
        vm.prank(depositSignaturesAddr1);
        vm.expectRevert("deposit signatures address not in registration queue");
        entityManager.confirmDepositSignaturesAddressRegistration(user1);

        // register data provider
        vm.prank(user1);
        entityManager.registerDepositSignaturesAddress(depositSignaturesAddr1);

        // confirm registration
        assertEq(entityManager.getDepositSignaturesAddresses(voters, 100)[0], user1);
        vm.roll(200);
        vm.prank(depositSignaturesAddr1);
        vm.expectEmit();
        emit DepositSignaturesAddressRegistrationConfirmed(user1, depositSignaturesAddr1);
        entityManager.confirmDepositSignaturesAddressRegistration(user1);
        assertEq(entityManager.getDepositSignaturesAddresses(voters, 200)[0], depositSignaturesAddr1);

        // should not register if already registered
        vm.prank(user1);
        vm.expectRevert("deposit signatures address already registered");
        entityManager.registerDepositSignaturesAddress(depositSignaturesAddr1);

        // should not confirm if already registered
        vm.prank(depositSignaturesAddr1);
        vm.expectRevert("deposit signatures address already registered");
        entityManager.confirmDepositSignaturesAddressRegistration(user1);
    }

    function testChangeDepositSignaturesAddress() public {
        vm.roll(100);
        address depositSignaturesAddr1 = makeAddr("depositSignaturesAddr1");
        address depositSignaturesAddr2 = makeAddr("depositSignaturesAddr2");
        address[] memory voters = new address[](1);
        voters[0] = user1;

        // register data provider
        vm.prank(user1);
        entityManager.registerDepositSignaturesAddress(depositSignaturesAddr1);
        assertEq(entityManager.getDepositSignaturesAddresses(voters, 100)[0], user1);
        assertEq(entityManager.getVoterForDepositSignaturesAddress(
            depositSignaturesAddr1, 100), depositSignaturesAddr1);

        // confirm registration
        vm.prank(depositSignaturesAddr1);
        entityManager.confirmDepositSignaturesAddressRegistration(user1);
        assertEq(entityManager.getDepositSignaturesAddresses(voters, 100)[0], depositSignaturesAddr1);
        assertEq(entityManager.getVoterForDepositSignaturesAddress(depositSignaturesAddr1, 100), user1);

        // register another data provider
        vm.prank(user1);
        entityManager.registerDepositSignaturesAddress(depositSignaturesAddr2);
        assertEq(entityManager.getDepositSignaturesAddresses(voters, 100)[0], depositSignaturesAddr1);

        // confirm registration and replace first data provider
        vm.roll(200);
        vm.prank(depositSignaturesAddr2);
        entityManager.confirmDepositSignaturesAddressRegistration(user1);
        assertEq(entityManager.getDepositSignaturesAddresses(voters, 100)[0], depositSignaturesAddr1);
        assertEq(entityManager.getDepositSignaturesAddresses(voters, 200)[0], depositSignaturesAddr2);
    }

    function testRegisterSigningPolicyAddress() public {
        address signingPolicyAddr1 = makeAddr("signingPolicyAddr1");
        vm.prank(user1);
        vm.expectEmit();
        emit SigningPolicyAddressRegistered(user1, signingPolicyAddr1);
        entityManager.registerSigningPolicyAddress(signingPolicyAddr1);
    }

    function testConfirmSigningPolicyAddressRegistration() public {
        vm.roll(100);
        address signingPolicyAddr1 = makeAddr("signingPolicyAddr1");
        address[] memory voters = new address[](1);
        voters[0] = user1;
        assertEq(entityManager.getSigningPolicyAddresses(voters, 100)[0], user1);

        // should not confirm if not in queue
        vm.prank(signingPolicyAddr1);
        vm.expectRevert("signing policy address not in registration queue");
        entityManager.confirmSigningPolicyAddressRegistration(user1);

        // register data provider
        vm.prank(user1);
        entityManager.registerSigningPolicyAddress(signingPolicyAddr1);

        // confirm registration
        assertEq(entityManager.getSigningPolicyAddresses(voters, 100)[0], user1);
        vm.roll(200);
        vm.prank(signingPolicyAddr1);
        vm.expectEmit();
        emit SigningPolicyAddressRegistrationConfirmed(user1, signingPolicyAddr1);
        entityManager.confirmSigningPolicyAddressRegistration(user1);
        assertEq(entityManager.getSigningPolicyAddresses(voters, 200)[0], signingPolicyAddr1);

        // should not register if already registered
        vm.prank(user1);
        vm.expectRevert("signing policy address already registered");
        entityManager.registerSigningPolicyAddress(signingPolicyAddr1);

        // should not confirm if already registered
        vm.prank(signingPolicyAddr1);
        vm.expectRevert("signing policy address already registered");
        entityManager.confirmSigningPolicyAddressRegistration(user1);
    }

    function testChangeSigningPolicyAddress() public {
        vm.roll(100);
        address signingPolicyAddr1 = makeAddr("signingPolicyAddr1");
        address signingPolicyAddr2 = makeAddr("signingPolicyAddr2");
        address[] memory voters = new address[](1);
        voters[0] = user1;

        // register data provider
        vm.prank(user1);
        entityManager.registerSigningPolicyAddress(signingPolicyAddr1);
        assertEq(entityManager.getSigningPolicyAddresses(voters, 100)[0], user1);
        assertEq(entityManager.getVoterForSigningPolicyAddress(signingPolicyAddr1, 100), signingPolicyAddr1);

        // confirm registration
        vm.prank(signingPolicyAddr1);
        entityManager.confirmSigningPolicyAddressRegistration(user1);
        assertEq(entityManager.getSigningPolicyAddresses(voters, 100)[0], signingPolicyAddr1);
        assertEq(entityManager.getVoterForSigningPolicyAddress(signingPolicyAddr1, 100), user1);

        // register another data provider
        vm.prank(user1);
        entityManager.registerSigningPolicyAddress(signingPolicyAddr2);
        assertEq(entityManager.getSigningPolicyAddresses(voters, 100)[0], signingPolicyAddr1);

        // confirm registration and replace first data provider
        vm.roll(200);
        vm.prank(signingPolicyAddr2);
        entityManager.confirmSigningPolicyAddressRegistration(user1);
        assertEq(entityManager.getSigningPolicyAddresses(voters, 100)[0], signingPolicyAddr1);
        assertEq(entityManager.getSigningPolicyAddresses(voters, 200)[0], signingPolicyAddr2);
    }

    function testGetVoterAddresses() public {
        vm.roll(100);
        EntityManager.VoterAddresses memory voterAddresses = entityManager.getVoterAddresses(user1, block.number);
        assertEq(voterAddresses.dataProviderAddress, user1);
        assertEq(voterAddresses.depositSignaturesAddress, user1);
        assertEq(voterAddresses.signingPolicyAddress, user1);

        address dataProvider1 = makeAddr("dataProvider1");
        address depositSignaturesAddr1 = makeAddr("depositSignaturesAddr1");
        address signingPolicyAddr1 = makeAddr("signingPolicyAddr1");

        // register addresses
        vm.startPrank(user1);
        entityManager.registerDataProviderAddress(dataProvider1);
        entityManager.registerDepositSignaturesAddress(depositSignaturesAddr1);
        entityManager.registerSigningPolicyAddress(signingPolicyAddr1);
        vm.stopPrank();

        // confirm registrations
        vm.roll(200);
        vm.prank(dataProvider1);
        entityManager.confirmDataProviderAddressRegistration(user1);
        vm.prank(depositSignaturesAddr1);
        entityManager.confirmDepositSignaturesAddressRegistration(user1);
        vm.prank(signingPolicyAddr1);
        entityManager.confirmSigningPolicyAddressRegistration(user1);

        EntityManager.VoterAddresses memory voterAddressesAtBlock100 = entityManager.getVoterAddresses(user1, 100);
        assertEq(voterAddressesAtBlock100.dataProviderAddress, user1);
        assertEq(voterAddressesAtBlock100.depositSignaturesAddress, user1);
        assertEq(voterAddressesAtBlock100.signingPolicyAddress, user1);

        EntityManager.VoterAddresses memory voterAddressesAtBlock200 = entityManager.getVoterAddresses(
            user1, block.number);
        assertEq(voterAddressesAtBlock200.dataProviderAddress, dataProvider1);
        assertEq(voterAddressesAtBlock200.depositSignaturesAddress, depositSignaturesAddr1);
        assertEq(voterAddressesAtBlock200.signingPolicyAddress, signingPolicyAddr1);
    }

}
