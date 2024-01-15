// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// import {Test, console2} from "forge-std/Test.sol";
import "forge-std/Test.sol";
import "../../../contracts/protocol/implementation/EntityManager.sol";

import "forge-std/console2.sol";

contract EntityManagerTest is Test {

    EntityManager private entityManager;
    address private user1;
    bytes20 private nodeId1;

    event NodeIdRegistered(address indexed voter, bytes20 indexed nodeId);
    event NodeIdUnregistered(address indexed voter, bytes20 indexed nodeId);
    event SubmitAddressRegistered(address indexed voter, address indexed submitAddress);
    event SubmitAddressRegistrationConfirmed(address indexed voter, address indexed signingAddress);
    event MaxNodeIdsPerEntitySet(uint256 maxNodeIdsPerEntity);
    event SubmitSignaturesAddressRegistered(
        address indexed voter, address indexed submitSignaturesAddress);
    event SubmitSignaturesAddressRegistrationConfirmed(
        address indexed voter, address indexed submitSignaturesAddress);
    event SigningPolicyAddressRegistered(
        address indexed voter, address indexed signingPolicyAddress);
    event SigningPolicyAddressRegistrationConfirmed(
        address indexed voter, address indexed signingPolicyAddress);
    event DelegationAddressRegistered(
        address indexed voter, address indexed delegationAddress);
    event DelegationAddressRegistrationConfirmed(
        address indexed voter, address indexed delegationAddress);
    event PublicKeyRegistered(
        address indexed voter, bytes32 indexed part1, bytes32 indexed part2);
    event PublicKeyUnregistered(
        address indexed voter, bytes32 indexed part1, bytes32 indexed part2);

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

    function testRegisterSubmitAddress() public {
        address dataProvider1 = makeAddr("dataProvider1");
        vm.prank(user1);
        vm.expectEmit();
        emit SubmitAddressRegistered(user1, dataProvider1);
        entityManager.registerSubmitAddress(dataProvider1);
    }

    function testConfirmSubmitAddressRegistration() public {
        vm.roll(100);
        address dataProvider1 = makeAddr("dataProvider1");
        address[] memory voters = new address[](1);
        voters[0] = user1;
        assertEq(entityManager.getSubmitAddresses(voters, 100)[0], user1);

        // should not confirm if not in queue
        vm.prank(dataProvider1);
        vm.expectRevert("submit address not in registration queue");
        entityManager.confirmSubmitAddressRegistration(user1);

        // register submit address
        vm.prank(user1);
        entityManager.registerSubmitAddress(dataProvider1);

        // confirm registration
        assertEq(entityManager.getSubmitAddresses(voters, 100)[0], user1);
        vm.roll(200);
        vm.prank(dataProvider1);
        vm.expectEmit();
        emit SubmitAddressRegistrationConfirmed(user1, dataProvider1);
        entityManager.confirmSubmitAddressRegistration(user1);
        assertEq(entityManager.getSubmitAddresses(voters, 200)[0], dataProvider1);

        // should not register if already registered
        vm.prank(user1);
        vm.expectRevert("submit address already registered");
        entityManager.registerSubmitAddress(dataProvider1);

        // should not confirm if already registered
        vm.prank(dataProvider1);
        vm.expectRevert("submit address already registered");
        entityManager.confirmSubmitAddressRegistration(user1);
    }

    function testChangeSubmitAddress() public {
        vm.roll(100);
        address dataProvider1 = makeAddr("dataProvider1");
        address dataProvider2 = makeAddr("dataProvider2");
        address[] memory voters = new address[](1);
        voters[0] = user1;

        // register data provider
        vm.prank(user1);
        entityManager.registerSubmitAddress(dataProvider1);
        assertEq(entityManager.getSubmitAddresses(voters, 100)[0], user1);
        assertEq(entityManager.getVoterForSubmitAddress(dataProvider1, 100), dataProvider1);

        // confirm registration
        vm.prank(dataProvider1);
        entityManager.confirmSubmitAddressRegistration(user1);
        assertEq(entityManager.getSubmitAddresses(voters, 100)[0], dataProvider1);
        assertEq(entityManager.getVoterForSubmitAddress(dataProvider1, 100), user1);

        // register another data provider
        vm.prank(user1);
        entityManager.registerSubmitAddress(dataProvider2);
        assertEq(entityManager.getSubmitAddresses(voters, 100)[0], dataProvider1);

        // confirm registration and replace first data provider
        vm.roll(200);
        vm.prank(dataProvider2);
        entityManager.confirmSubmitAddressRegistration(user1);
        assertEq(entityManager.getSubmitAddresses(voters, 100)[0], dataProvider1);
        assertEq(entityManager.getSubmitAddresses(voters, 200)[0], dataProvider2);
    }

    function testRegisterSubmitSignaturesAddress() public {
        address submitSignaturesAddr1 = makeAddr("submitSignaturesAddr1");
        vm.prank(user1);
        vm.expectEmit();
        emit SubmitSignaturesAddressRegistered(user1, submitSignaturesAddr1);
        entityManager.registerSubmitSignaturesAddress(submitSignaturesAddr1);
    }

    function testConfirmSubmitSignaturesAddressRegistration() public {
        vm.roll(100);
        address submitSignaturesAddr1 = makeAddr("submitSignaturesAddr1");
        address[] memory voters = new address[](1);
        voters[0] = user1;
        assertEq(entityManager.getSubmitSignaturesAddresses(voters, 100)[0], user1);


        // should not confirm if not in queue
        vm.prank(submitSignaturesAddr1);
        vm.expectRevert("submit signatures address not in registration queue");
        entityManager.confirmSubmitSignaturesAddressRegistration(user1);

        // register submit signatures address
        vm.prank(user1);
        entityManager.registerSubmitSignaturesAddress(submitSignaturesAddr1);

        // confirm registration
        assertEq(entityManager.getSubmitSignaturesAddresses(voters, 100)[0], user1);
        vm.roll(200);
        vm.prank(submitSignaturesAddr1);
        vm.expectEmit();
        emit SubmitSignaturesAddressRegistrationConfirmed(user1, submitSignaturesAddr1);
        entityManager.confirmSubmitSignaturesAddressRegistration(user1);
        assertEq(entityManager.getSubmitSignaturesAddresses(voters, 200)[0], submitSignaturesAddr1);

        // should not register if already registered
        vm.prank(user1);
        vm.expectRevert("submit signatures address already registered");
        entityManager.registerSubmitSignaturesAddress(submitSignaturesAddr1);

        // should not confirm if already registered
        vm.prank(submitSignaturesAddr1);
        vm.expectRevert("submit signatures address already registered");
        entityManager.confirmSubmitSignaturesAddressRegistration(user1);
    }

    function testChangeSubmitSignaturesAddress() public {
        vm.roll(100);
        address submitSignaturesAddr1 = makeAddr("submitSignaturesAddr1");
        address submitSignaturesAddr2 = makeAddr("submitSignaturesAddr2");
        address[] memory voters = new address[](1);
        voters[0] = user1;

        // register data provider
        vm.prank(user1);
        entityManager.registerSubmitSignaturesAddress(submitSignaturesAddr1);
        assertEq(entityManager.getSubmitSignaturesAddresses(voters, 100)[0], user1);
        assertEq(entityManager.getVoterForSubmitSignaturesAddress(
            submitSignaturesAddr1, 100), submitSignaturesAddr1);

        // confirm registration
        vm.prank(submitSignaturesAddr1);
        entityManager.confirmSubmitSignaturesAddressRegistration(user1);
        assertEq(entityManager.getSubmitSignaturesAddresses(voters, 100)[0], submitSignaturesAddr1);
        assertEq(entityManager.getVoterForSubmitSignaturesAddress(submitSignaturesAddr1, 100), user1);

        // register another data provider
        vm.prank(user1);
        entityManager.registerSubmitSignaturesAddress(submitSignaturesAddr2);
        assertEq(entityManager.getSubmitSignaturesAddresses(voters, 100)[0], submitSignaturesAddr1);

        // confirm registration and replace first data provider
        vm.roll(200);
        vm.prank(submitSignaturesAddr2);
        entityManager.confirmSubmitSignaturesAddressRegistration(user1);
        assertEq(entityManager.getSubmitSignaturesAddresses(voters, 100)[0], submitSignaturesAddr1);
        assertEq(entityManager.getSubmitSignaturesAddresses(voters, 200)[0], submitSignaturesAddr2);
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

    function testRegisterDelegationAddress() public {
        address delegationAddr1 = makeAddr("delegationAddr1");
        vm.prank(user1);
        vm.expectEmit();
        emit SigningPolicyAddressRegistered(user1, delegationAddr1);
        entityManager.registerSigningPolicyAddress(delegationAddr1);
    }

    function testConfirmDelegationAddressRegistration() public {
        vm.roll(100);
        address delegationAddr1 = makeAddr("delegationAddr1");
        address[] memory voters = new address[](1);
        voters[0] = user1;
        assertEq(entityManager.getDelegationAddresses(voters, 100)[0], user1);

        // should not confirm if not in queue
        vm.prank(delegationAddr1);
        vm.expectRevert("delegation address not in registration queue");
        entityManager.confirmDelegationAddressRegistration(user1);

        // register data provider
        vm.prank(user1);
        entityManager.registerDelegationAddress(delegationAddr1);

        // confirm registration
        assertEq(entityManager.getDelegationAddresses(voters, 100)[0], user1);
        vm.roll(200);
        vm.prank(delegationAddr1);
        vm.expectEmit();
        emit DelegationAddressRegistrationConfirmed(user1, delegationAddr1);
        entityManager.confirmDelegationAddressRegistration(user1);
        assertEq(entityManager.getDelegationAddresses(voters, 200)[0], delegationAddr1);

        // should not register if already registered
        vm.prank(user1);
        vm.expectRevert("delegation address already registered");
        entityManager.registerDelegationAddress(delegationAddr1);

        // should not confirm if already registered
        vm.prank(delegationAddr1);
        vm.expectRevert("delegation address already registered");
        entityManager.confirmDelegationAddressRegistration(user1);
    }

    function testChangeDelegationAddress() public {
        vm.roll(100);
        address delegationAddr1 = makeAddr("delegationAddr1");
        address delegationAddr2 = makeAddr("delegationAddr2");
        address[] memory voters = new address[](1);
        voters[0] = user1;

        // register data provider
        vm.prank(user1);
        entityManager.registerDelegationAddress(delegationAddr1);
        assertEq(entityManager.getDelegationAddresses(voters, 100)[0], user1);
        assertEq(entityManager.getVoterForDelegationAddress(delegationAddr1, 100), delegationAddr1);

        // confirm registration
        vm.prank(delegationAddr1);
        entityManager.confirmDelegationAddressRegistration(user1);
        assertEq(entityManager.getDelegationAddresses(voters, 100)[0], delegationAddr1);
        assertEq(entityManager.getVoterForDelegationAddress(delegationAddr1, 100), user1);

        // register another data provider
        vm.prank(user1);
        entityManager.registerDelegationAddress(delegationAddr2);
        assertEq(entityManager.getDelegationAddresses(voters, 100)[0], delegationAddr1);

        // confirm registration and replace first data provider
        vm.roll(200);
        vm.prank(delegationAddr2);
        entityManager.confirmDelegationAddressRegistration(user1);
        assertEq(entityManager.getDelegationAddresses(voters, 100)[0], delegationAddr1);
        assertEq(entityManager.getDelegationAddresses(voters, 200)[0], delegationAddr2);
    }

    function testGetVoterAddresses() public {
        vm.roll(100);
        EntityManager.VoterAddresses memory voterAddresses = entityManager.getVoterAddresses(user1, block.number);
        assertEq(voterAddresses.submitAddress, user1);
        assertEq(voterAddresses.submitSignaturesAddress, user1);
        assertEq(voterAddresses.signingPolicyAddress, user1);
        assertEq(voterAddresses.delegationAddress, user1);

        address dataProvider1 = makeAddr("dataProvider1");
        address submitSignaturesAddr1 = makeAddr("submitSignaturesAddr1");
        address signingPolicyAddr1 = makeAddr("signingPolicyAddr1");
        address delegationAddr1 = makeAddr("delegationAddr1");

        // register addresses
        vm.startPrank(user1);
        entityManager.registerSubmitAddress(dataProvider1);
        entityManager.registerSubmitSignaturesAddress(submitSignaturesAddr1);
        entityManager.registerSigningPolicyAddress(signingPolicyAddr1);
        entityManager.registerDelegationAddress(delegationAddr1);
        vm.stopPrank();

        // confirm registrations
        vm.roll(200);
        vm.prank(dataProvider1);
        entityManager.confirmSubmitAddressRegistration(user1);
        vm.prank(submitSignaturesAddr1);
        entityManager.confirmSubmitSignaturesAddressRegistration(user1);
        vm.prank(signingPolicyAddr1);
        entityManager.confirmSigningPolicyAddressRegistration(user1);
        vm.prank(delegationAddr1);
        entityManager.confirmDelegationAddressRegistration(user1);

        EntityManager.VoterAddresses memory voterAddressesAtBlock100 = entityManager.getVoterAddresses(user1, 100);
        assertEq(voterAddressesAtBlock100.submitAddress, user1);
        assertEq(voterAddressesAtBlock100.submitSignaturesAddress, user1);
        assertEq(voterAddressesAtBlock100.signingPolicyAddress, user1);
        assertEq(voterAddressesAtBlock100.delegationAddress, user1);

        EntityManager.VoterAddresses memory voterAddressesAtBlock200 = entityManager.getVoterAddresses(
            user1, block.number);
        assertEq(voterAddressesAtBlock200.submitAddress, dataProvider1);
        assertEq(voterAddressesAtBlock200.submitSignaturesAddress, submitSignaturesAddr1);
        assertEq(voterAddressesAtBlock200.signingPolicyAddress, signingPolicyAddr1);
        assertEq(voterAddressesAtBlock200.delegationAddress, delegationAddr1);
    }

    // public key tests
    function testRegisterPublicKeyRevertKeyInvalid() public {
        bytes32 publicKey1 = bytes32(0);
        bytes32 publicKey2 = bytes32(0);
        vm.expectRevert("public key invalid");
        entityManager.registerPublicKey(publicKey1, publicKey2);
    }

    function testRegisterPublicKey() public {
        bytes32 publicKey1 = bytes32("publicKey1");
        bytes32 publicKey2 = bytes32("publicKey2");
        vm.roll(100);
        vm.prank(user1);
        vm.expectEmit();
        emit PublicKeyRegistered(user1, publicKey1, publicKey2);
        entityManager.registerPublicKey(publicKey1, publicKey2);
        (bytes32 publicKey1_, bytes32 publicKey2_) = entityManager.getPublicKeyOf(user1);
        assertEq(publicKey1_, publicKey1);
        assertEq(publicKey2_, publicKey2);
        assertEq(entityManager.getVoterForPublicKey(publicKey1, publicKey2, 100), user1);

        // block number at the beginning was 1
        (bytes32 oldPublicKey1, bytes32 oldPublicKey2) = entityManager.getPublicKeyOfAt(user1, 1);
        assertEq(oldPublicKey1, bytes32(0));
        assertEq(oldPublicKey2, bytes32(0));
    }

    function testRegisterPublicKeyRevertAlreadyRegistered() public {
        bytes32 publicKey1 = bytes32("publicKey1");
        bytes32 publicKey2 = bytes32("publicKey2");

        vm.prank(user1);
        entityManager.registerPublicKey(publicKey1, publicKey2);

        // can't register the same key twice
        vm.prank(makeAddr("user2"));
        vm.expectRevert("public key already registered");
        entityManager.registerPublicKey(publicKey1, publicKey2);
    }

    function testReplacePublicKey() public {
        bytes32 publicKey11 = bytes32("publicKey11");
        bytes32 publicKey12 = bytes32("publicKey12");
        vm.prank(user1);
        entityManager.registerPublicKey(publicKey11, publicKey12);
        (bytes32 pk1, bytes32 pk2) = entityManager.getPublicKeyOf(user1);
        assertEq(pk1, publicKey11);
        assertEq(pk2, publicKey12);

        bytes32 publicKey21 = bytes32("publicKey21");
        bytes32 publicKey22 = bytes32("publicKey22");
        vm.prank(user1);
        vm.expectEmit();
        emit PublicKeyUnregistered(user1, publicKey11, publicKey12);
        emit PublicKeyRegistered(user1, publicKey21, publicKey22);
        entityManager.registerPublicKey(publicKey21, publicKey22);
        (pk1, pk2) = entityManager.getPublicKeyOf(user1);
        assertEq(pk1, publicKey21);
        assertEq(pk2, publicKey22);
    }

    function testUnregisterPublicKey() public {
        bytes32 publicKey1 = bytes32("publicKey1");
        bytes32 publicKey2 = bytes32("publicKey2");
        vm.recordLogs();
        vm.startPrank(user1);
        entityManager.unregisterPublicKey();
        Vm.Log[] memory entries = vm.getRecordedLogs();
        // nothing to unregister yet -> no event emitted
        assertEq(entries.length, 0);

        entityManager.registerPublicKey(publicKey1, publicKey2);

        vm.expectEmit();
        emit PublicKeyUnregistered(user1, publicKey1, publicKey2);
        entityManager.unregisterPublicKey();
        vm.stopPrank();
    }

}
