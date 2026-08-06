// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;
// solhint-disable no-console

import {console2} from "forge-std/Script.sol";
import {RelayDeployBase} from "./RelayDeployBase.s.sol";
import {IRelay} from "../../../contracts/userInterfaces/IRelay.sol";

// Captures the live Flare source stack into deployment/deploys/relay/source-snapshot.json for
// the mirror deployment. Run READ-ONLY against a Flare RPC (no --broadcast):
//
//   forge script deployment/scripts/relay/PrepareRelaySourceSnapshot.s.sol:PrepareRelaySourceSnapshot \
//     --rpc-url $FLARE_RPC
//
// It reads:
//   - the SafeInstructions governance stack (source chain id, live Safe owners/threshold, admitted
//     owner generation, replay floor) and asserts the admitted generation is LIVE
//     (docs/safe-governance.md §15.1); if a rotation attestation is pending this fails loudly, so
//     late-joining mirrors always configure the then-current generation, not gen 0;
//   - the home Relay's epoch anchors and its stored, already source-bound signing-policy hash for
//     the last initialized reward epoch — every mirror binds to the SAME source (Flare), so that
//     wrapped hash is valid unchanged on every target.
//
// The SafeInstructions and home Relay addresses are deploy OUTPUTS, read from the committed,
// persistent deployment/deploys/<source>.json (the repo's deployed-address registry, written by
// save-deployed-addresses.ts and carrying the latest addresses even before governance cuts the
// FlareContractRegistry over). (Deliberately NOT the registry Relay: pre-cutover that is still
// the old pre-RLY-23 relay, which would seed a wrongly bound initial policy.)
contract PrepareRelaySourceSnapshot is RelayDeployBase {

    function run() external {
        string memory network = _configLabel();
        console2.log(string.concat("SOURCE NETWORK: ", network));

        (address safeInstructions, address homeRelay) = _resolveSourceAddresses(network);
        console2.log("SafeInstructions:", safeInstructions);
        console2.log("Home Relay:", homeRelay);

        GovernanceStackRead memory stack = _readGovernanceStack(safeInstructions);
        require(
            stack.sourceChainId == block.chainid,
            "prepare: SafeInstructions source chain id != the chain being snapshotted"
        );

        SourceSnapshot memory snapshot = _buildSnapshot(stack, homeRelay);
        _writeSourceSnapshot(snapshot);

        console2.log("sourceChainId:", snapshot.stack.sourceChainId);
        console2.log("initialRewardEpochId:", snapshot.initialRewardEpochId);
        console2.log("owners:", snapshot.stack.owners.length);
        console2.log("threshold:", snapshot.stack.threshold);
        console2.log("replayFloor:", snapshot.stack.replayFloor);
    }

    function _buildSnapshot(
        GovernanceStackRead memory _stack,
        address _homeRelay
    )
        internal view
        returns (SourceSnapshot memory _snapshot)
    {
        IRelay relay = IRelay(_homeRelay);
        (uint32 lastEpoch, uint32 startRound) = relay.lastInitializedRewardEpochData();
        bytes32 policyHash = relay.toSigningPolicyHash(lastEpoch);
        require(policyHash != bytes32(0), "home Relay has no signing policy for the last initialized epoch");

        (
            uint8 randomNumberProtocolId,
            uint32 firstVotingRoundStartTs,
            uint8 votingEpochDurationSeconds,
            uint32 firstRewardEpochStartVotingRoundId,
            uint16 rewardEpochDurationInVotingEpochs,
            uint16 thresholdIncreaseBIPS,
            , // randomVotingRoundId
            , // isSecureRandom
            , // lastInitializedRewardEpoch
            , // noSigningPolicyRelay
            uint32 messageFinalizationWindowInRewardEpochs
        ) = relay.stateData();

        _snapshot.stack = _stack;
        _snapshot.initialRewardEpochId = lastEpoch;
        _snapshot.startingVotingRoundId = startRound;
        _snapshot.initialSigningPolicyHash = policyHash; // already source-bound
        _snapshot.firstVotingRoundStartTs = firstVotingRoundStartTs;
        _snapshot.votingEpochDurationSeconds = votingEpochDurationSeconds;
        _snapshot.firstRewardEpochStartVotingRoundId = firstRewardEpochStartVotingRoundId;
        _snapshot.rewardEpochDurationInVotingEpochs = rewardEpochDurationInVotingEpochs;
        _snapshot.thresholdIncreaseBIPS = thresholdIncreaseBIPS;
        _snapshot.messageFinalizationWindowInRewardEpochs = messageFinalizationWindowInRewardEpochs;
        _snapshot.randomNumberProtocolId = randomNumberProtocolId;
    }

    /**
     * The source stack addresses are deploy outputs, read from the committed, persistent
     * deployment/deploys/<network>.json (`SafeInstructions` and the latest `Relay`).
     */
    function _resolveSourceAddresses(
        string memory _network
    )
        internal view
        returns (
            address _safeInstructions,
            address _homeRelay
        )
    {
        _safeInstructions = _readDeployedAddress(_network, "SafeInstructions");
        _homeRelay = _readDeployedAddress(_network, "Relay");
        require(
            _safeInstructions != address(0),
            "SafeInstructions not in deployment/deploys/<network>.json (deploy home + save-deployed-addresses first)"
        );
        require(_homeRelay != address(0), "Relay not in deployment/deploys/<network>.json");
    }
}
