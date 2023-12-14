// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// import {Test, console2} from "forge-std/Test.sol";
import "forge-std/Test.sol";
import "../../../contracts/protocol/implementation/EntityManager.sol";

contract EntityManagerTest is Test {

    EntityManager private entityManager;

    function setUp() public {
        entityManager = new EntityManager(IGovernanceSettings(makeAddr("contract")), makeAddr("user0"), 4);
    }

    function testRegisterNodeId() public {
        address user1 = makeAddr("user1");
        bytes20 nodeId1 = bytes20(keccak256("nodeId1"));

        assertEq(entityManager.getNodeIdsOfAt(user1, block.number).length, 0);

        vm.prank(user1);
        entityManager.registerNodeId(nodeId1);
        bytes20[] memory nodeIds = entityManager.getNodeIdsOfAt(user1, block.number);
        assertEq(nodeIds.length, 1);
        assertEq(nodeIds[0], nodeId1);

        // should revert if trying to register the same node id again
        vm.expectRevert("node id already registered");
        entityManager.registerNodeId(nodeId1);
    }

}
