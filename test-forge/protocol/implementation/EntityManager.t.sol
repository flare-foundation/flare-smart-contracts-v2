// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// import {Test, console2} from "forge-std/Test.sol";
import "forge-std/Test.sol";
import "../../../contracts/protocol/implementation/EntityManager.sol";

contract EntityManagerTest is Test {

    EntityManager private entityManager;
    address private user1;
    address private user2;
    bytes20 private nodeId1;
    bytes20 private nodeId2;
    bytes20 private nodeId3;
    address private delegationAddr1;
    address private delegationAddr2;
    address private governance;
    address private governanceSettings;
    MockPublicKeyVerification private mockPublicKeyVerification;
    bytes private validPublicKeyData = abi.encode(keccak256("test"), 1, 2, 3);

    event NodeIdRegistered(address indexed voter, bytes20 indexed nodeId);
    event NodeIdUnregistered(address indexed voter, bytes20 indexed nodeId);
    event SubmitAddressProposed(address indexed voter, address indexed submitAddress);
    event SubmitAddressRegistrationConfirmed(address indexed voter, address indexed signingAddress);
    event MaxNodeIdsPerEntitySet(uint256 maxNodeIdsPerEntity);
    event SubmitSignaturesAddressProposed(
        address indexed voter, address indexed submitSignaturesAddress);
    event SubmitSignaturesAddressRegistrationConfirmed(
        address indexed voter, address indexed submitSignaturesAddress);
    event SigningPolicyAddressProposed(
        address indexed voter, address indexed signingPolicyAddress);
    event SigningPolicyAddressRegistrationConfirmed(
        address indexed voter, address indexed signingPolicyAddress);
    event DelegationAddressProposed(
        address indexed voter, address indexed delegationAddress);
    event DelegationAddressRegistrationConfirmed(
        address indexed voter, address indexed delegationAddress);
    event PublicKeyRegistered(
        address indexed voter, bytes32 indexed part1, bytes32 indexed part2);
    event PublicKeyUnregistered(
        address indexed voter, bytes32 indexed part1, bytes32 indexed part2);

    function setUp() public {
        governance = makeAddr("governance");
        governanceSettings = makeAddr("governanceSettings");
        entityManager = new EntityManager(IGovernanceSettings(governanceSettings), governance, 4);
        mockPublicKeyVerification = new MockPublicKeyVerification();
        vm.prank(governance);
        entityManager.setPublicKeyVerificationData(
            address(mockPublicKeyVerification),
            MockPublicKeyVerification.verifyPublicKey.selector
        );

        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        nodeId1 = bytes20(keccak256("nodeId1"));
        nodeId2 = bytes20(keccak256("nodeId2"));
        nodeId3 = bytes20(keccak256("nodeId3"));
        delegationAddr1 = makeAddr("delegationAddr1");
        delegationAddr2 = makeAddr("delegationAddr2");
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

    function testGetNodeIds() public {
        vm.startPrank(user1);
        entityManager.registerNodeId(nodeId1);
        entityManager.registerNodeId(nodeId2);
        vm.stopPrank();

        vm.prank(user2);
        entityManager.registerNodeId(nodeId3);

        address[] memory voters = new address[](2);
        voters[0] = user1;
        voters[1] = user2;
        bytes20[][] memory nodeIds = entityManager.getNodeIds(voters, block.number);
        assertEq(nodeIds.length, 2);
        assertEq(nodeIds[0].length, 2);
        assertEq(nodeIds[0][0], nodeId1);
        assertEq(nodeIds[0][1], nodeId2);
        assertEq(nodeIds[1].length, 1);
        assertEq(nodeIds[1][0], nodeId3);
    }

    function testGetPublicKeys() public {
        vm.prank(user1);
        entityManager.registerPublicKey(bytes32("publicKey11"), bytes32("publicKey12"), validPublicKeyData);
        vm.prank(user2);
        entityManager.registerPublicKey(bytes32("publicKey21"), bytes32("publicKey22"), validPublicKeyData);

        address[] memory voters = new address[](2);
        voters[0] = user1;
        voters[1] = user2;

        (bytes32[] memory publicKey1, bytes32[] memory publicKey2) = entityManager.getPublicKeys(voters, block.number);
        assertEq(publicKey1.length, 2);
        assertEq(publicKey1[0], bytes32("publicKey11"));
        assertEq(publicKey1[1], bytes32("publicKey21"));
        assertEq(publicKey2.length, 2);
        assertEq(publicKey2[0], bytes32("publicKey12"));
        assertEq(publicKey2[1], bytes32("publicKey22"));
    }

    function testRevertSettingTooManyNodesPerEntity() public {
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

    function testSetMaxNodeIdsPerEntity() public {
        assertEq(entityManager.maxNodeIdsPerEntity(), 4);
        // only governance
        vm.prank(governance);
        vm.expectEmit();
        emit MaxNodeIdsPerEntitySet(5);
        entityManager.setMaxNodeIdsPerEntity(5);
        assertEq(entityManager.maxNodeIdsPerEntity(), 5);
    }

    // for songbird - maxNodeIdsPerEntity is set to 0
    function testSetMaxNodeIdsPerEntityZero() public {
        entityManager = new EntityManager(IGovernanceSettings(governanceSettings), governance, 0);
        assertEq(entityManager.maxNodeIdsPerEntity(), 0);

        vm.expectRevert("Max nodes exceeded");
        entityManager.registerNodeId(nodeId1);
    }

    function testRevertSetMaxNodePerEntityOnlyGovernance() public {
        vm.expectRevert("only governance");
        entityManager.setMaxNodeIdsPerEntity(5);
    }

    function testRevertDecreaseMaxNodePerEntity() public {
        vm.startPrank(governance);
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

    function testProposeSubmitAddress() public {
        address dataProvider1 = makeAddr("dataProvider1");
        vm.prank(user1);
        vm.expectEmit();
        emit SubmitAddressProposed(user1, dataProvider1);
        entityManager.proposeSubmitAddress(dataProvider1);
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
        entityManager.proposeSubmitAddress(dataProvider1);

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
        entityManager.proposeSubmitAddress(dataProvider1);

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
        entityManager.proposeSubmitAddress(dataProvider1);
        assertEq(entityManager.getSubmitAddresses(voters, 100)[0], user1);
        assertEq(entityManager.getVoterForSubmitAddress(dataProvider1, 100), dataProvider1);

        // confirm registration
        vm.prank(dataProvider1);
        entityManager.confirmSubmitAddressRegistration(user1);
        assertEq(entityManager.getSubmitAddresses(voters, 100)[0], dataProvider1);
        assertEq(entityManager.getVoterForSubmitAddress(dataProvider1, 100), user1);

        // register another data provider
        vm.prank(user1);
        entityManager.proposeSubmitAddress(dataProvider2);
        assertEq(entityManager.getSubmitAddresses(voters, 100)[0], dataProvider1);

        // confirm registration and replace first data provider
        vm.roll(200);
        vm.prank(dataProvider2);
        entityManager.confirmSubmitAddressRegistration(user1);
        assertEq(entityManager.getSubmitAddresses(voters, 100)[0], dataProvider1);
        assertEq(entityManager.getSubmitAddresses(voters, 200)[0], dataProvider2);
    }

    function testProposeSubmitSignaturesAddress() public {
        address submitSignaturesAddr1 = makeAddr("submitSignaturesAddr1");
        vm.prank(user1);
        vm.expectEmit();
        emit SubmitSignaturesAddressProposed(user1, submitSignaturesAddr1);
        entityManager.proposeSubmitSignaturesAddress(submitSignaturesAddr1);
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
        entityManager.proposeSubmitSignaturesAddress(submitSignaturesAddr1);

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
        entityManager.proposeSubmitSignaturesAddress(submitSignaturesAddr1);

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
        entityManager.proposeSubmitSignaturesAddress(submitSignaturesAddr1);
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
        entityManager.proposeSubmitSignaturesAddress(submitSignaturesAddr2);
        assertEq(entityManager.getSubmitSignaturesAddresses(voters, 100)[0], submitSignaturesAddr1);

        // confirm registration and replace first data provider
        vm.roll(200);
        vm.prank(submitSignaturesAddr2);
        entityManager.confirmSubmitSignaturesAddressRegistration(user1);
        assertEq(entityManager.getSubmitSignaturesAddresses(voters, 100)[0], submitSignaturesAddr1);
        assertEq(entityManager.getSubmitSignaturesAddresses(voters, 200)[0], submitSignaturesAddr2);
    }

    function testProposeSigningPolicyAddress() public {
        address signingPolicyAddr1 = makeAddr("signingPolicyAddr1");
        vm.prank(user1);
        vm.expectEmit();
        emit SigningPolicyAddressProposed(user1, signingPolicyAddr1);
        entityManager.proposeSigningPolicyAddress(signingPolicyAddr1);
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
        entityManager.proposeSigningPolicyAddress(signingPolicyAddr1);

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
        entityManager.proposeSigningPolicyAddress(signingPolicyAddr1);

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
        entityManager.proposeSigningPolicyAddress(signingPolicyAddr1);
        assertEq(entityManager.getSigningPolicyAddresses(voters, 100)[0], user1);
        assertEq(entityManager.getVoterForSigningPolicyAddress(signingPolicyAddr1, 100), signingPolicyAddr1);

        // confirm registration
        vm.prank(signingPolicyAddr1);
        entityManager.confirmSigningPolicyAddressRegistration(user1);
        assertEq(entityManager.getSigningPolicyAddresses(voters, 100)[0], signingPolicyAddr1);
        assertEq(entityManager.getVoterForSigningPolicyAddress(signingPolicyAddr1, 100), user1);

        // register another data provider
        vm.prank(user1);
        entityManager.proposeSigningPolicyAddress(signingPolicyAddr2);
        assertEq(entityManager.getSigningPolicyAddresses(voters, 100)[0], signingPolicyAddr1);

        // confirm registration and replace first data provider
        vm.roll(200);
        vm.prank(signingPolicyAddr2);
        entityManager.confirmSigningPolicyAddressRegistration(user1);
        assertEq(entityManager.getSigningPolicyAddresses(voters, 100)[0], signingPolicyAddr1);
        assertEq(entityManager.getSigningPolicyAddresses(voters, 200)[0], signingPolicyAddr2);
    }

    function testProposeDelegationAddress() public {
        vm.prank(user1);
        vm.expectEmit();
        emit DelegationAddressProposed(user1, delegationAddr1);
        entityManager.proposeDelegationAddress(delegationAddr1);
    }

    function testConfirmDelegationAddressRegistration() public {
        vm.roll(100);
        address[] memory voters = new address[](1);
        voters[0] = user1;
        assertEq(entityManager.getDelegationAddresses(voters, 100)[0], user1);

        // should not confirm if not in queue
        vm.prank(delegationAddr1);
        vm.expectRevert("delegation address not in registration queue");
        entityManager.confirmDelegationAddressRegistration(user1);

        // register data provider
        vm.prank(user1);
        entityManager.proposeDelegationAddress(delegationAddr1);

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
        entityManager.proposeDelegationAddress(delegationAddr1);

        // should not confirm if already registered
        vm.prank(delegationAddr1);
        vm.expectRevert("delegation address already registered");
        entityManager.confirmDelegationAddressRegistration(user1);
    }

    function testChangeDelegationAddress() public {
        vm.roll(100);
        address[] memory voters = new address[](1);
        voters[0] = user1;

        // register data provider
        vm.prank(user1);
        entityManager.proposeDelegationAddress(delegationAddr1);
        assertEq(entityManager.getDelegationAddressOfAt(user1, 100), user1);
        assertEq(entityManager.getDelegationAddressOf(user1), user1);
        assertEq(entityManager.getDelegationAddresses(voters, 100)[0], user1);
        assertEq(entityManager.getVoterForDelegationAddress(delegationAddr1, 100), delegationAddr1);

        // confirm registration
        vm.prank(delegationAddr1);
        entityManager.confirmDelegationAddressRegistration(user1);
        assertEq(entityManager.getDelegationAddressOfAt(user1, 100), delegationAddr1);
        assertEq(entityManager.getDelegationAddressOf(user1), delegationAddr1);
        assertEq(entityManager.getDelegationAddresses(voters, 100)[0], delegationAddr1);
        assertEq(entityManager.getVoterForDelegationAddress(delegationAddr1, 100), user1);

        // register another data provider
        vm.prank(user1);
        entityManager.proposeDelegationAddress(delegationAddr2);
        assertEq(entityManager.getDelegationAddressOfAt(user1, 100), delegationAddr1);
        assertEq(entityManager.getDelegationAddressOf(user1), delegationAddr1);
        assertEq(entityManager.getDelegationAddresses(voters, 100)[0], delegationAddr1);

        // confirm registration and replace first data provider
        vm.roll(200);
        vm.prank(delegationAddr2);
        entityManager.confirmDelegationAddressRegistration(user1);
        assertEq(entityManager.getDelegationAddressOfAt(user1, 100), delegationAddr1);
        assertEq(entityManager.getDelegationAddresses(voters, 100)[0], delegationAddr1);
        assertEq(entityManager.getDelegationAddressOfAt(user1, 200), delegationAddr2);
        assertEq(entityManager.getDelegationAddressOf(user1), delegationAddr2);
        assertEq(entityManager.getDelegationAddresses(voters, 200)[0], delegationAddr2);
    }

    function testGetVoterAddresses() public {
        vm.roll(100);
        EntityManager.VoterAddresses memory voterAddresses = entityManager.getVoterAddresses(user1);
        EntityManager.VoterAddresses memory voterAddressesAt = entityManager.getVoterAddressesAt(user1, block.number);
        assertEq(voterAddresses.submitAddress, user1);
        assertEq(voterAddresses.submitSignaturesAddress, user1);
        assertEq(voterAddresses.signingPolicyAddress, user1);
        assertEq(voterAddressesAt.submitAddress, user1);
        assertEq(voterAddressesAt.submitSignaturesAddress, user1);
        assertEq(voterAddressesAt.signingPolicyAddress, user1);

        address dataProvider1 = makeAddr("dataProvider1");
        address submitSignaturesAddr1 = makeAddr("submitSignaturesAddr1");
        address signingPolicyAddr1 = makeAddr("signingPolicyAddr1");

        // register addresses
        vm.startPrank(user1);
        entityManager.proposeSubmitAddress(dataProvider1);
        entityManager.proposeSubmitSignaturesAddress(submitSignaturesAddr1);
        entityManager.proposeSigningPolicyAddress(signingPolicyAddr1);
        entityManager.proposeDelegationAddress(delegationAddr1);
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

        EntityManager.VoterAddresses memory voterAddressesAtBlock100 = entityManager.getVoterAddressesAt(user1, 100);
        assertEq(voterAddressesAtBlock100.submitAddress, user1);
        assertEq(voterAddressesAtBlock100.submitSignaturesAddress, user1);
        assertEq(voterAddressesAtBlock100.signingPolicyAddress, user1);

        EntityManager.VoterAddresses memory voterAddressesAtNow = entityManager.getVoterAddresses(user1);
        EntityManager.VoterAddresses memory voterAddressesAtBlock200 = entityManager.getVoterAddressesAt(
            user1, block.number);
        assertEq(voterAddressesAtNow.submitAddress, dataProvider1);
        assertEq(voterAddressesAtNow.submitSignaturesAddress, submitSignaturesAddr1);
        assertEq(voterAddressesAtNow.signingPolicyAddress, signingPolicyAddr1);
        assertEq(voterAddressesAtBlock200.submitAddress, dataProvider1);
        assertEq(voterAddressesAtBlock200.submitSignaturesAddress, submitSignaturesAddr1);
        assertEq(voterAddressesAtBlock200.signingPolicyAddress, signingPolicyAddr1);
    }

    // public key tests
    function testRegisterPublicKeyRevertPublicKeyInvalid() public {
        bytes32 publicKey1 = bytes32(0);
        bytes32 publicKey2 = bytes32(0);
        vm.expectRevert("public key invalid");
        entityManager.registerPublicKey(publicKey1, publicKey2, validPublicKeyData);
    }

    function testRegisterPublicKeyRevertVerificationFailed() public {
        bytes32 publicKey1 = bytes32("publicKey1");
        bytes32 publicKey2 = bytes32("publicKey2");
        vm.expectRevert("Transaction reverted silently");
        entityManager.registerPublicKey(publicKey1, publicKey2, "test");
    }

    function testRegisterPublicKeyRevertVerificationFailed2() public {
        bytes32 publicKey1 = bytes32("publicKey1");
        bytes32 publicKey2 = bytes32("publicKey2");
        vm.expectRevert("public key verification failed");
        entityManager.registerPublicKey(publicKey1, publicKey2, abi.encode(keccak256("error"), 1, 2, 3));
    }

    function testRegisterPublicKeyRevertPublicKeyRegistrationNotEnabled() public {
        assertEq(entityManager.publicKeyVerificationContract(), address(mockPublicKeyVerification));
        assertEq(entityManager.publicKeyVerificationSelector(), MockPublicKeyVerification.verifyPublicKey.selector);

        vm.prank(governance);
        entityManager.setPublicKeyVerificationData(address(0), bytes4(0));
        assertEq(entityManager.publicKeyVerificationContract(), address(0));
        assertEq(entityManager.publicKeyVerificationSelector(), bytes4(0));

        bytes32 publicKey1 = bytes32("publicKey1");
        bytes32 publicKey2 = bytes32("publicKey2");
        vm.expectRevert("public key registration not enabled");
        entityManager.registerPublicKey(publicKey1, publicKey2, validPublicKeyData);
    }

    function testRegisterPublicKey() public {
        bytes32 publicKey1 = bytes32("publicKey1");
        bytes32 publicKey2 = bytes32("publicKey2");
        vm.roll(100);
        vm.prank(user1);
        vm.expectEmit();
        emit PublicKeyRegistered(user1, publicKey1, publicKey2);
        entityManager.registerPublicKey(publicKey1, publicKey2, validPublicKeyData);
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
        entityManager.registerPublicKey(publicKey1, publicKey2, validPublicKeyData);

        // can't register the same key twice
        vm.prank(makeAddr("user2"));
        vm.expectRevert("public key already registered");
        entityManager.registerPublicKey(publicKey1, publicKey2, validPublicKeyData);
    }

    function testReplacePublicKey() public {
        bytes32 publicKey11 = bytes32("publicKey11");
        bytes32 publicKey12 = bytes32("publicKey12");
        vm.prank(user1);
        entityManager.registerPublicKey(publicKey11, publicKey12, validPublicKeyData);
        (bytes32 pk1, bytes32 pk2) = entityManager.getPublicKeyOf(user1);
        assertEq(pk1, publicKey11);
        assertEq(pk2, publicKey12);

        bytes32 publicKey21 = bytes32("publicKey21");
        bytes32 publicKey22 = bytes32("publicKey22");
        vm.prank(user1);
        vm.expectEmit();
        emit PublicKeyUnregistered(user1, publicKey11, publicKey12);
        emit PublicKeyRegistered(user1, publicKey21, publicKey22);
        entityManager.registerPublicKey(publicKey21, publicKey22, validPublicKeyData);
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

        entityManager.registerPublicKey(publicKey1, publicKey2, validPublicKeyData);

        vm.expectEmit();
        emit PublicKeyUnregistered(user1, publicKey1, publicKey2);
        entityManager.unregisterPublicKey();
        vm.stopPrank();
    }

    //// set initial voter data
    function testSetInitialVoterDataRevertInProductionMode() public {
        vm.mockCall(
            address(governanceSettings),
            abi.encodeWithSelector(bytes4(keccak256("getGovernanceAddress()"))),
            abi.encode(governance)
        );
        vm.mockCall(
            address(governanceSettings),
            abi.encodeWithSelector(bytes4(keccak256("isExecutor(address)")), governance),
            abi.encode(true)
        );
        vm.mockCall(
            address(governanceSettings),
            abi.encodeWithSelector(bytes4(keccak256("getTimelock()"))),
            abi.encode(1)
        );

        vm.startPrank(governance);
        entityManager.switchToProductionMode();
        EntityManager.InitialVoterData[] memory initialVotersData = new EntityManager.InitialVoterData[](0);
        entityManager.setInitialVoterData(initialVotersData);
        vm.warp(block.timestamp + 2);
        vm.expectRevert("already in production mode");
        entityManager.executeGovernanceCall(EntityManager.setInitialVoterData.selector);
        vm.stopPrank();
    }

    function testSetInitialVoterDataRevertVoterZero() public {
        EntityManager.InitialVoterData[] memory initialVotersData = _setInitialVoterData();
        initialVotersData[0].voter = address(0);

        vm.prank(governance);
        vm.expectRevert("voter address zero");
        entityManager.setInitialVoterData(initialVotersData);
    }

    function testSetInitialVoterDataRevertDelegationAddressAlreadySet() public {
        EntityManager.InitialVoterData[] memory initialVotersData = _setInitialVoterData();
        // set delegation address for voter1
        testConfirmDelegationAddressRegistration();

        vm.prank(governance);
        vm.expectRevert("delegation address already set");
        entityManager.setInitialVoterData(initialVotersData);
    }

    function testSetInitialVoterDataRevertDelegationAddressAlreadyRegistered() public {
        EntityManager.InitialVoterData[] memory initialVotersData = _setInitialVoterData();
        // set delegation address (delegationAddr1) for voter1
        testConfirmDelegationAddressRegistration();
        initialVotersData[0].voter = makeAddr("user3");

        // should revert - delegationAddr1 is already registered as delegation address for another voter
        vm.prank(governance);
        vm.expectRevert("delegation address already registered");
        entityManager.setInitialVoterData(initialVotersData);
    }

    function testSetInitialVoterDataRevertNodeIdAlreadyRegistered() public {
        EntityManager.InitialVoterData[] memory initialVotersData = _setInitialVoterData();
        testRegisterNodeId();

        vm.prank(governance);
        vm.expectRevert("node id already registered");
        entityManager.setInitialVoterData(initialVotersData);
    }

    function testSetInitialVoterData() public {
        EntityManager.InitialVoterData[] memory initialVotersData = _setInitialVoterData();

        vm.prank(governance);
        vm.expectEmit();
        emit DelegationAddressProposed(user1, delegationAddr1);
        vm.expectEmit();
        emit DelegationAddressRegistrationConfirmed(user1, delegationAddr1);
        vm.expectEmit();
        emit NodeIdRegistered(user1, initialVotersData[0].nodeIds[0]);
        vm.expectEmit();
        emit DelegationAddressProposed(user2, delegationAddr2);
        vm.expectEmit();
        emit DelegationAddressRegistrationConfirmed(user2, delegationAddr2);
        vm.expectEmit();
        emit NodeIdRegistered(user2, initialVotersData[1].nodeIds[0]);
        vm.expectEmit();
        emit NodeIdRegistered(user2, initialVotersData[1].nodeIds[1]);

        entityManager.setInitialVoterData(initialVotersData);
    }

    function testSetInitialVoterDataOnlyNodeIds() public {
        EntityManager.InitialVoterData[] memory initialVotersData = _setInitialVoterData();
        initialVotersData[0].delegationAddress = address(0);
        initialVotersData[1].delegationAddress = address(0);

        vm.prank(governance);
        vm.expectEmit();
        emit NodeIdRegistered(user1, initialVotersData[0].nodeIds[0]);
        vm.expectEmit();
        emit NodeIdRegistered(user2, initialVotersData[1].nodeIds[0]);
        vm.expectEmit();
        emit NodeIdRegistered(user2, initialVotersData[1].nodeIds[1]);

        vm.recordLogs();
        entityManager.setInitialVoterData(initialVotersData);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        // should register 3 events
        assertEq(entries.length, 3);
    }

    function _setInitialVoterData() private view returns(EntityManager.InitialVoterData[] memory) {
        EntityManager.InitialVoterData[] memory initialVotersData =
            new EntityManager.InitialVoterData[](2);

        initialVotersData[0].voter = user1;
        bytes20[] memory nodes = new bytes20[](1);
        nodes[0] = nodeId1;
        initialVotersData[0].nodeIds = nodes;
        initialVotersData[0].delegationAddress = delegationAddr1;

        initialVotersData[1].voter = user2;
        nodes = new bytes20[](2);
        nodes[0] = nodeId2;
        nodes[1] = nodeId3;
        initialVotersData[1].nodeIds = nodes;
        initialVotersData[1].delegationAddress = delegationAddr2;

        return initialVotersData;
    }
}

contract MockPublicKeyVerification {

    function verifyPublicKey(
        bytes32 _part1,
        bytes32 _part2,
        bytes32 _message,
        uint256 signature,
        uint256 x,
        uint256 y
    )
        external view
    {
        require(
            _part1 != bytes32(0) &&_part2 != bytes32(0) &&
            _message == keccak256("test") && signature == 1 && x == 2 && y == 3,
            "public key verification failed");
    }
}
