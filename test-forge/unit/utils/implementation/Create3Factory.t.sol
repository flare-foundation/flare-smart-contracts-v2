// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// solhint-disable func-name-mixedcase

import {Test} from "forge-std/Test.sol";
import {Create3Factory} from "../../../../contracts/utils/implementation/Create3Factory.sol";

contract Create3Probe {
    uint256 public immutable value;
    constructor(uint256 _value) payable {
        value = _value;
    }
}

contract Create3FactoryTest is Test {
    bytes32 internal constant SALT = keccak256("relay.proxy.v1");
    Create3Factory internal factory;

    function setUp() public {
        factory = new Create3Factory();
    }

    function test_deployMatchesComputedAddress() public {
        address predicted = factory.computeAddress(address(this), SALT);
        address deployed =
            factory.deploy(SALT, abi.encodePacked(type(Create3Probe).creationCode, abi.encode(uint256(7))));
        assertEq(deployed, predicted);
        assertEq(Create3Probe(deployed).value(), 7);
    }

    function test_addressIndependentOfInitCodeAndArguments() public view {
        // The prediction is a pure function of (deployer, salt); different payloads/constructor
        // arguments cannot change it — the property that gives one address on every chain.
        address predicted = factory.computeAddress(address(this), SALT);
        assertTrue(predicted != address(0));
        assertEq(factory.computeAddress(address(this), SALT), predicted);
    }

    function test_saltIsDeployerScoped() public {
        address mine = factory.computeAddress(address(this), SALT);
        address other = factory.computeAddress(makeAddr("someoneElse"), SALT);
        assertTrue(mine != other);

        // A different sender deploying with the SAME salt cannot squat this test's address.
        vm.prank(makeAddr("someoneElse"));
        address deployed =
            factory.deploy(SALT, abi.encodePacked(type(Create3Probe).creationCode, abi.encode(uint256(1))));
        assertEq(deployed, other);
        assertTrue(deployed != mine);
    }

    function test_duplicateDeployReverts() public {
        factory.deploy(SALT, abi.encodePacked(type(Create3Probe).creationCode, abi.encode(uint256(1))));
        vm.expectRevert(abi.encodeWithSelector(Create3Factory.SaltAlreadyUsed.selector, SALT));
        factory.deploy(SALT, abi.encodePacked(type(Create3Probe).creationCode, abi.encode(uint256(2))));
    }

    function test_emptyRuntimeRevertsAndKeepsSaltUsable() public {
        // PUSH1 0 PUSH1 0 RETURN: init code that succeeds while returning no runtime code.
        vm.expectRevert(Create3Factory.EmptyRuntimeCode.selector);
        factory.deploy(SALT, hex"60006000f3");

        // The revert rolled the inner proxy back too, so the salt still works.
        address deployed =
            factory.deploy(SALT, abi.encodePacked(type(Create3Probe).creationCode, abi.encode(uint256(9))));
        assertEq(Create3Probe(deployed).value(), 9);
    }

    function test_valueForwarding() public {
        address deployed = factory.deploy{value: 1 ether}(
            SALT, abi.encodePacked(type(Create3Probe).creationCode, abi.encode(uint256(3)))
        );
        assertEq(deployed.balance, 1 ether);
    }
}
