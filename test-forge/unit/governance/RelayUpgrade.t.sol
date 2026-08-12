// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// solhint-disable func-name-mixedcase

import {Test} from "forge-std/Test.sol";
import {Relay} from "../../../contracts/protocol/implementation/Relay.sol";
import {RelayProxy} from "../../../contracts/protocol/implementation/RelayProxy.sol";
import {IRelay} from "../../../contracts/userInterfaces/IRelay.sol";
import {IOwnableWithTimelock} from "../../../contracts/userInterfaces/IOwnableWithTimelock.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/// Upgradeability of the Relay proxy: the per-chain owner authorizes upgrades through the
/// OwnableWithTimelock path — immediately at duration 0, via queue + permissionless
/// executeTimelockedCall at a nonzero duration.
contract RelayUpgradeTest is Test {
    address internal relayOwner;
    Relay internal relay;
    Relay internal relayImplementation;

    function setUp() public {
        relayOwner = makeAddr("relayOwner");

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
    }

    //// Immediate path (timelock duration 0) ////

    function test_relayUpgradeByOwnerPreservesState() public {
        assertEq(relay.implementation(), address(relayImplementation));
        assertEq(relay.owner(), relayOwner);
        assertEq(relay.getTimelockDurationSeconds(), 0);
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
        // renounceOwnership would permanently freeze the implementation, so the inherited
        // OwnableWithTimelock reverts for everyone; ownership only moves via transferOwnership.
        vm.prank(relayOwner);
        vm.expectRevert(IOwnableWithTimelock.RenounceDisabled.selector);
        relay.renounceOwnership();
        assertEq(relay.owner(), relayOwner);

        vm.expectRevert(IOwnableWithTimelock.RenounceDisabled.selector);
        relay.renounceOwnership();

        Relay newImplementation = new Relay();
        vm.prank(relayOwner);
        relay.upgradeToAndCall(address(newImplementation), bytes(""));
        assertEq(relay.implementation(), address(newImplementation));
    }

    //// Timelocked path (nonzero duration): queue -> ETA -> permissionless execute ////

    function test_relayUpgradeQueuedAndExecutedThroughTimelock() public {
        Relay timelocked = _deployTimelockedRelay(1 days);
        Relay newImplementation = new Relay();
        bytes memory encodedCall =
            abi.encodeCall(timelocked.upgradeToAndCall, (address(newImplementation), bytes("")));

        // The owner call queues the exact calldata and applies nothing yet.
        vm.prank(relayOwner);
        timelocked.upgradeToAndCall(address(newImplementation), bytes(""));
        assertEq(timelocked.implementation(), address(relayImplementation), "queued, not applied");
        assertEq(
            timelocked.getExecuteTimelockedCallTimestamp(encodedCall),
            block.timestamp + 1 days,
            "ETA recorded"
        );

        // Too early: execution reverts until the recorded ETA.
        vm.expectRevert(IOwnableWithTimelock.TimelockNotAllowedYet.selector);
        timelocked.executeTimelockedCall(encodedCall);

        // After the ETA anyone may execute the queued call.
        vm.warp(block.timestamp + 1 days);
        vm.prank(makeAddr("randomExecutor"));
        timelocked.executeTimelockedCall(encodedCall);
        assertEq(timelocked.implementation(), address(newImplementation), "upgrade applied");
        assertEq(timelocked.owner(), relayOwner, "owner preserved across upgrade");
    }

    function test_relayUpgradeQueueRevertsForNonOwner() public {
        Relay timelocked = _deployTimelockedRelay(1 days);
        Relay newImplementation = new Relay();
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(this))
        );
        timelocked.upgradeToAndCall(address(newImplementation), bytes(""));
    }

    function _deployTimelockedRelay(uint256 timelockDurationSeconds) internal returns (Relay) {
        IRelay.RelayInitialConfig memory c = _relayConfig();
        c.timelockDurationSeconds = timelockDurationSeconds;
        return Relay(
            address(
                new RelayProxy(
                    address(relayImplementation),
                    c,
                    address(0),
                    IRelay(address(0)),
                    relayOwner
                )
            )
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
        c.sourceChainId = block.chainid; // the source-network id is mandatory
        // timelockDurationSeconds defaults to 0: owner calls apply immediately
    }
}
