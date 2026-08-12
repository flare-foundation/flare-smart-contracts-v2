// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;
// solhint-disable no-console

import {console2} from "forge-std/Script.sol";
import {RelayDeployBase} from "./RelayDeployBase.s.sol";
import {IRelay} from "../../../contracts/userInterfaces/IRelay.sol";
import {Relay} from "../../../contracts/protocol/implementation/Relay.sol";

// Captures the live Flare source stack into deployment/deploys/relay/source-snapshot-<source>.json
// for the mirror deployment. Run READ-ONLY against a Flare RPC (no --broadcast):
//
//   forge script deployment/scripts/relay/PrepareRelaySourceSnapshot.s.sol:PrepareRelaySourceSnapshot \
//     --rpc-url $FLARE_RPC
//
// It reads the home Relay's source id, epoch anchors and stored source-bound
// signing-policy hash for the last initialized reward epoch — every mirror binds to the SAME
// source (Flare), so that wrapped hash is valid unchanged on every target.
//
// The home Relay address is a deploy OUTPUT, read from the committed, persistent
// deployment/deploys/<source>.json (the repo's deployed-address registry, written by
// save-deployed-addresses.ts and carrying the latest addresses even before governance cuts the
// FlareContractRegistry over). The registry may not yet point to the implementation whose
// source-bound policy hash is required by the mirror.
contract PrepareRelaySourceSnapshot is RelayDeployBase {

    function run() external {
        string memory network = _configLabel();
        console2.log(string.concat("SOURCE NETWORK: ", network));

        address homeRelay = _resolveSourceAddress(network);
        console2.log("Home Relay:", homeRelay);

        uint256 sourceChainId = Relay(homeRelay).sourceChainId();
        require(
            sourceChainId == block.chainid,
            "prepare: home Relay source chain id != the chain being snapshotted"
        );

        SourceSnapshot memory snapshot = _buildSnapshot(sourceChainId, homeRelay);
        _writeSourceSnapshot(snapshot);

        console2.log("sourceChainId:", snapshot.sourceChainId);
        console2.log("initialRewardEpochId:", snapshot.initialRewardEpochId);
    }

    function _buildSnapshot(
        uint256 _sourceChainId,
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

        _snapshot.sourceChainId = _sourceChainId;
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
     * The home Relay address is a deploy output, read from the committed, persistent
     * deployment/deploys/<network>.json (the latest `Relay`).
     */
    function _resolveSourceAddress(
        string memory _network
    )
        internal view
        returns (address _homeRelay)
    {
        _homeRelay = _readDeployedAddress(_network, "Relay");
        require(
            _homeRelay != address(0),
            "Relay not in deployment/deploys/<network>.json (deploy home + save-deployed-addresses first)"
        );
    }
}
