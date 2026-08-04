// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// solhint-disable func-name-mixedcase

import {Test} from "forge-std/Test.sol";
import {Relay} from "../../../contracts/protocol/implementation/Relay.sol";
import {RelayProxy} from "../../../contracts/protocol/implementation/RelayProxy.sol";
import {IRelay} from "../../../contracts/userInterfaces/IRelay.sol";
import {IRelayGovernance} from "../../../contracts/userInterfaces/IRelayGovernance.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {SafeInstructions} from "../../../contracts/governance/implementation/SafeInstructions.sol";
import {SafeInstructionsProxy} from "../../../contracts/governance/implementation/SafeInstructionsProxy.sol";
import {IFlareGovernance} from "../../../contracts/userInterfaces/IFlareGovernance.sol";
import {IGovernanceSettings} from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import { testGovernanceConfig } from "../../utils/RelayDeploy.sol";

/// Minimal live-Safe stand-in: SafeInstructions.initialize reads the live owner
/// configuration to admit generation 0.
contract TestSafeView {
    function getOwners() external pure returns (address[] memory owners) {
        owners = new address[](1);
        owners[0] = address(uint160(uint256(keccak256("safe.upgrade.test.owner"))));
    }

    function getThreshold() external pure returns (uint256) {
        return 1;
    }
}

/// Upgradeability of the two Safe-stack proxies: Relay (OZ Ownable per-chain owner)
/// and SafeInstructions (Flare governed-UUPS house pattern).
contract SafeUpgradeTest is Test {
    address internal relayOwner;
    address internal flareGovernance;
    address internal governanceSafe;
    Relay internal relay;
    Relay internal relayImplementation;
    SafeInstructions internal instructions;
    SafeInstructions internal instructionsImplementation;

    function setUp() public {
        relayOwner = makeAddr("relayOwner");
        flareGovernance = makeAddr("flareGovernance");
        governanceSafe = address(new TestSafeView());

        relayImplementation = new Relay();
        relay = Relay(
            address(
                new RelayProxy(
                    address(relayImplementation),
                    _relayConfig(),
                    address(0),
                    IRelay(address(0)),
                    relayOwner
                )
            )
        );

        instructionsImplementation = new SafeInstructions();
        instructions = SafeInstructions(
            address(
                new SafeInstructionsProxy(
                    IGovernanceSettings(makeAddr("governanceSettings")),
                    flareGovernance,
                    makeAddr("addressUpdater"),
                    address(instructionsImplementation),
                    governanceSafe
                )
            )
        );
    }

    //// Relay: per-chain owner (OZ Ownable) authorizes upgrades ////

    function test_relayUpgradeByOwnerPreservesState() public {
        assertEq(relay.implementation(), address(relayImplementation));
        assertEq(relay.owner(), relayOwner);
        uint256 startingVotingRoundBefore = relay.startingVotingRoundIds(1);
        (uint32 lastEpochBefore,) = relay.lastInitializedRewardEpochData();

        Relay newImplementation = new Relay();
        vm.prank(relayOwner);
        relay.upgradeToAndCall(address(newImplementation), bytes(""));

        assertEq(relay.implementation(), address(newImplementation));
        assertEq(relay.startingVotingRoundIds(1), startingVotingRoundBefore);
        (uint32 lastEpochAfter,) = relay.lastInitializedRewardEpochData();
        assertEq(lastEpochAfter, lastEpochBefore);
        assertEq(relay.owner(), relayOwner);
    }

    function test_relayUpgradeRevertsForNonOwner() public {
        Relay newImplementation = new Relay();
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(this))
        );
        relay.upgradeToAndCall(address(newImplementation), bytes(""));
    }

    function test_relayReinitializationReverts() public {
        vm.expectRevert();
        relay.initialize(_relayConfig(), address(0), IRelay(address(0)), relayOwner);
    }

    function test_relayImplementationCannotBeInitialized() public {
        vm.expectRevert();
        relayImplementation.initialize(_relayConfig(), address(0), IRelay(address(0)), relayOwner);
    }

    function test_relayOwnershipTransfer() public {
        address next = makeAddr("nextOwner");
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(this))
        );
        relay.transferOwnership(next);

        vm.prank(relayOwner);
        relay.transferOwnership(next);
        assertEq(relay.owner(), next);

        Relay newImplementation = new Relay();
        vm.prank(relayOwner);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, relayOwner)
        );
        relay.upgradeToAndCall(address(newImplementation), bytes(""));

        vm.prank(next);
        relay.upgradeToAndCall(address(newImplementation), bytes(""));
        assertEq(relay.implementation(), address(newImplementation));
    }

    function test_relayOwnershipTransferToZeroReverts() public {
        vm.prank(relayOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableInvalidOwner.selector, address(0)));
        relay.transferOwnership(address(0));
    }

    function test_relayRenounceOwnershipIsDisabled() public {
        // renounceOwnership would permanently freeze the implementation, so Relay
        // overrides it to revert for everyone; ownership only moves via transferOwnership.
        vm.prank(relayOwner);
        vm.expectRevert(IRelayGovernance.RenounceOwnershipDisabled.selector);
        relay.renounceOwnership();
        assertEq(relay.owner(), relayOwner);

        vm.expectRevert(IRelayGovernance.RenounceOwnershipDisabled.selector);
        relay.renounceOwnership();

        Relay newImplementation = new Relay();
        vm.prank(relayOwner);
        relay.upgradeToAndCall(address(newImplementation), bytes(""));
        assertEq(relay.implementation(), address(newImplementation));
    }

    //// SafeInstructions: Flare governance authorizes upgrades ////

    function test_instructionsUpgradeByFlareGovernance() public {
        assertEq(instructions.implementation(), address(instructionsImplementation));
        assertEq(instructions.sourceChainId(), block.chainid);
        assertTrue(instructions.activeOwnerConfigHash() != bytes32(0));

        SafeInstructions newImplementation = new SafeInstructions();
        vm.prank(flareGovernance);
        instructions.upgradeToAndCall(address(newImplementation), bytes(""));
        assertEq(instructions.implementation(), address(newImplementation));
        assertEq(instructions.sourceChainId(), block.chainid);
    }

    function test_instructionsUpgradeRevertsForNonGovernance() public {
        SafeInstructions newImplementation = new SafeInstructions();
        vm.expectRevert(IFlareGovernance.OnlyGovernance.selector);
        instructions.upgradeToAndCall(address(newImplementation), bytes(""));
    }

    function test_instructionsReinitializationReverts() public {
        vm.expectRevert();
        instructions.initialize(
            IGovernanceSettings(makeAddr("governanceSettings")),
            flareGovernance,
            makeAddr("addressUpdater"),
            governanceSafe
        );
    }

    function _relayConfig() internal view returns (IRelay.RelayInitialConfig memory c) {
        c.initialRewardEpochId = 1;
        c.startingVotingRoundIdForInitialRewardEpochId = 1;
        c.initialSigningPolicyHash = bytes32(uint256(1));
        c.randomNumberProtocolId = 2;
        c.firstVotingRoundStartTs = 1;
        c.votingEpochDurationSeconds = 1;
        c.firstRewardEpochStartVotingRoundId = 0;
        c.rewardEpochDurationInVotingEpochs = 1;
        c.thresholdIncreaseBIPS = 10000;
        c.messageFinalizationWindowInRewardEpochs = 1;
        c.feeCollectionAddress = payable(address(0xfee));
        c.feeConfigs = new IRelay.FeeConfig[](0);
        c.governance = testGovernanceConfig(block.chainid); // governance is mandatory
    }
}
