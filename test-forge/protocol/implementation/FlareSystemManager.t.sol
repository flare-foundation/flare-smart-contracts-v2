// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// import {Test, console2} from "forge-std/Test.sol";
import "forge-std/Test.sol";
import "../../../contracts/protocol/implementation/FlareSystemManager.sol";

contract FlareSystemManagerTest is Test {

    FlareSystemManager private flareSystemManager;
    address private flareDaemon;
    address private governance;
    address private addressUpdater;
    FlareSystemManager.Settings private settings;
    uint64 private startTs;

    uint64 private constant REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS = 3360; // 3.5 days
    uint64 private constant VOTING_EPOCH_DURATION_SEC = 90;
    uint64 private constant REWARD_EPOCH_DURATION_IN_SEC =
    REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS * VOTING_EPOCH_DURATION_SEC;
    uint64 private constant PPM_MAX = 1e6;

    function setUp() public {
        flareDaemon = makeAddr("flareDaemon");
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");
        startTs = uint64(block.timestamp);
        settings = FlareSystemManager.Settings(
            uint64(block.timestamp), // 1
            VOTING_EPOCH_DURATION_SEC,
            0,
            REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS,
            3600 * 2,
            75 * 60,
            2250,
            30 * 60,
            20,
            20 * 60,
            600,
            500000,
            2
        );

        flareSystemManager = new FlareSystemManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            flareDaemon,
            settings,
            5,
            0
        );
    }

    // constructor tests
    function testRevertFlareDaemonZero() public {
        flareDaemon = address(0);
        vm.expectRevert("flare daemon zero");
        new FlareSystemManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            flareDaemon,
            settings,
            5,
            0
        );
    }

    function testRevertRewardEpochDurationZero() public {
        settings.rewardEpochDurationInVotingEpochs = 0;
        vm.expectRevert("reward epoch duration zero");
        new FlareSystemManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            flareDaemon,
            settings,
            5,
            0
        );
    }

    function testRevertVotingEpochDurationZero() public {
        settings.votingEpochDurationSeconds = 0;
        vm.expectRevert("voting epoch duration zero");
        new FlareSystemManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            flareDaemon,
            settings,
            5,
            0
        );
    }

    function testRevertThresholdTooHigh() public {
        settings.signingPolicyThresholdPPM = PPM_MAX + 1;
        vm.expectRevert("threshold too high");
        new FlareSystemManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            flareDaemon,
            settings,
            5,
            0
        );
    }

    function testRevertZeroVoters() public {
        settings.signingPolicyMinNumberOfVoters = 0;
        vm.expectRevert("zero voters");
        new FlareSystemManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            flareDaemon,
            settings,
            0,
            0
        );
    }

    function testRevertZeroRandomAcqBlocks() public {
        vm.expectRevert("zero blocks");
        new FlareSystemManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            flareDaemon,
            settings,
            0,
            0
        );
    }

    function testRevertRewardEpochEndInThePast() public {
        vm.warp(1641070800);
        vm.expectRevert("reward epoch end not in the future");
        new FlareSystemManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            flareDaemon,
            settings,
            5,
            0
        );
    }

    // changing settings tests
    function testChangeSigningPolicySettings() public {
        vm.prank(governance);
        flareSystemManager.changeSigningPolicySettings(600000, 3);
        assertEq(flareSystemManager.signingPolicyThresholdPPM(), 600000);
        assertEq(flareSystemManager.signingPolicyMinNumberOfVoters(), 3);
    }

    function testRevertThresholdTooHighChangeSettings() public {
        vm.prank(governance);
        vm.expectRevert("threshold too high");
        flareSystemManager.changeSigningPolicySettings(PPM_MAX + 1, 3);
    }

    function testRevertZeroVotersChangeSettings() public {
        vm.prank(governance);
        vm.expectRevert("zero voters");
        flareSystemManager.changeSigningPolicySettings(60000, 0);
    }

    function testChangeRandomProvider() public {
        assertEq(flareSystemManager.usePriceSubmitterAsRandomProvider(), false);
        vm.prank(governance);
        flareSystemManager.changeRandomProvider(true);
        assertEq(flareSystemManager.usePriceSubmitterAsRandomProvider(), true);
    }

    function testGetContractName() public {
        assertEq(flareSystemManager.getContractName(), "FlareSystemManager");
    }

    function testSwitchToFallbackMode() public {
        assertEq(flareSystemManager.switchToFallbackMode(), false);
    }


}