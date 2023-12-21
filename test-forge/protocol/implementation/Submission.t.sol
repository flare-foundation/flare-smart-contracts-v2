// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../contracts/protocol/implementation/Submission.sol";

contract SubmissionTest is Test {
    Submission private submission;
    address private user1;
    address[] private users;

    bytes32[] private nameHashes;

    address[] private addresses;

    address[] private emptyAddresses;

    function setUp() public {
        submission = new Submission(
            IGovernanceSettings(makeAddr("contract")),
            makeAddr("governance"),
            makeAddr("updater"),
            false
        );
        user1 = makeAddr("user1");
        users.push(user1);

        nameHashes.push(keccak256("123"));
        addresses.push(makeAddr("randomAddresic"));
    }

    function test_initNewVotingRoundNonFinalisation() public {
        vm.expectRevert("only flareSystemManager");

        submission.initNewVotingRound(users, users, users);
    }

    function testFuzz_initNewVotingRoundFinalisation(
        address[] calldata usersGen
    ) public {
        vm.assume(usersGen.length > 0);
        vm.prank(address(submission.flareSystemManager()));
        submission.initNewVotingRound(usersGen, usersGen, usersGen);

        vm.prank(usersGen[0]);
        bool firstCallCom = submission.commit();
        assertEq(firstCallCom, true, "1");
        vm.prank(usersGen[0]);
        bool secondCallCom = submission.commit();
        assertEq(secondCallCom, false, "2");
        vm.prank(makeAddr("randomAddress12391234891"));
        bool radnomCallCom = submission.commit();
        assertEq(radnomCallCom, false, "3");

        vm.prank(usersGen[0]);
        bool firstCallSub = submission.submit();
        assertEq(firstCallSub, false, "4");
        vm.prank(usersGen[0]);
        bool secondCallSub = submission.submit();
        assertEq(secondCallSub, false, "5");
        vm.prank(makeAddr("randomAddress"));
        bool radnomCallSub = submission.submit();
        assertEq(radnomCallSub, false, "6");
    }

    function testFuzz_initNewVotingRoundFinalisationEmpty() public {
        vm.prank(address(submission.flareSystemManager()));
        submission.initNewVotingRound(
            emptyAddresses,
            emptyAddresses,
            emptyAddresses
        );

        vm.prank(makeAddr("randomAddressic12391234891"));
        bool radnomCallCom = submission.commit();
        assertEq(radnomCallCom, false, "3");

        vm.prank(makeAddr("randomAddress424"));
        bool radnomCallSub = submission.submit();
        assertEq(radnomCallSub, false, "6");
    }

    function test_getUpdater() public {
        //  vm.expectRevert("only address updater");
        address updater = submission.getAddressUpdater();
        assertEq(updater, makeAddr("updater"));
    }

    function test_updateContractAddressFail1() public {
        vm.expectRevert("only address updater");
        // vm.prank(makeAddr("updater"));
        submission.updateContractAddresses(nameHashes, addresses);
    }

    function test_updateContractAddressFail2() public {
        vm.expectRevert("address zero");
        vm.prank(makeAddr("updater"));
        submission.updateContractAddresses(nameHashes, addresses);
    }

    function test_updateContractAddress() public {
        nameHashes.push(keccak256(abi.encode("AddressUpdater")));
        addresses.push(makeAddr("AddressUpdater"));
        nameHashes.push(keccak256(abi.encode("FlareSystemManager")));
        addresses.push(makeAddr("FlareSystemManager"));
        nameHashes.push(keccak256(abi.encode("Relay")));
        addresses.push(makeAddr("Relay"));

        vm.startPrank(makeAddr("updater"));
        submission.updateContractAddresses(nameHashes, addresses);
        vm.stopPrank();

        assertEq(address(submission.relay()), makeAddr("Relay"));
        assertEq(
            address(submission.flareSystemManager()),
            makeAddr("FlareSystemManager")
        );
    }

    function test_setSubmitRev() public {
        vm.expectRevert("only governance");
        submission.setSubmitMethodEnabled(true);

        vm.prank(address(submission.flareSystemManager()));
    }

    function test_setSubmit() public {
        vm.prank(makeAddr("governance"));
        submission.setSubmitMethodEnabled(true);
        assertEq(submission.submitMethodEnabled(), true);
    }

    function testFuzz_initNewVotingRoundFinalisationAfterSubmitEn(
        address[] calldata usersGen
    ) public {
        vm.prank(makeAddr("governance"));
        submission.setSubmitMethodEnabled(true);

        vm.assume(usersGen.length > 0);

        vm.prank(address(submission.flareSystemManager()));
        submission.initNewVotingRound(usersGen, usersGen, usersGen);

        vm.prank(usersGen[0]);
        bool firstCallRev = submission.reveal();
        assertEq(firstCallRev, true, "12");
        vm.prank(usersGen[0]);
        bool secondCallRev = submission.reveal();
        assertEq(secondCallRev, false, "22");
        vm.prank(makeAddr("randomAddress12391234891"));
        bool randomCallRev = submission.reveal();
        assertEq(randomCallRev, false, "32");

        vm.prank(usersGen[0]);
        bool firstCallSub = submission.submit();
        assertEq(firstCallSub, true, "42");
        vm.prank(usersGen[0]);
        bool secondCallSub = submission.submit();
        assertEq(secondCallSub, false, "52");
        vm.prank(makeAddr("randomAddress"));
        bool randomCallSub = submission.submit();
        assertEq(randomCallSub, false, "62");

        vm.prank(usersGen[0]);
        bool firstCallSig = submission.sign();
        assertEq(firstCallSig, true, "72");
        vm.prank(usersGen[0]);
        bool secondCallSig = submission.sign();
        assertEq(secondCallSig, false, "73");
        vm.prank(makeAddr("randomAddress12391234891"));
        bool radnomCallSig = submission.sign();
        assertEq(radnomCallSig, false, "74");
    }
}
