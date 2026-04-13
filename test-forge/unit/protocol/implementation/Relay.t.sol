// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, Vm} from "forge-std/Test.sol";
import {Relay} from "../../../../contracts/protocol/implementation/Relay.sol";
import {IRelay} from "../../../../contracts/userInterfaces/IRelay.sol";
import {IIRelay} from "../../../../contracts/protocol/interface/IIRelay.sol";
/* solhint-disable avoid-low-level-calls */
contract RelayTest is Test {

    Relay private relay;
    Relay private relayWithSetter; // Relay with signingPolicySetter != 0

    // Test constants matching the TS tests
    uint256 private constant N = 100;              // Number of voters
    uint16 private constant SINGLE_WEIGHT = 500;
    uint16 private constant THRESHOLD = 25000;     // ceil(N/2 * SINGLE_WEIGHT)
    uint24 private constant REWARD_EPOCH_ID = 1;
    uint32 private constant FIRST_REWARD_EPOCH_VOTING_ROUND_ID = 1000;
    uint16 private constant REWARD_EPOCH_DURATION = 3360;
    uint8 private constant RANDOM_NUMBER_PROTOCOL_ID = 15;
    uint32 private constant FIRST_VOTING_ROUND_START_TS = 1636070400;
    uint8 private constant VOTING_EPOCH_DURATION_SEC = 90;
    uint16 private constant THRESHOLD_INCREASE_BIPS = 12000;
    uint32 private constant MSG_FINALIZATION_WINDOW = 3;
    uint32 private constant VOTING_ROUND_ID = 4411;

    // Voter private keys and sorted addresses
    uint256[] private voterPKs;
    address[] private voterAddrs;
    // Mapping from sorted address back to private key
    mapping(address => uint256) private addrToPK;

    // Signing policy data
    bytes private signingPolicyEncoded;
    bytes32 private signingPolicyHash;

    // ── Setup ────────────────────────────────────────────────────────────────

    function setUp() public {
        // Generate N voter key-pairs
        for (uint256 i = 0; i < N; i++) {
            uint256 pk = uint256(keccak256(abi.encodePacked("voter", i)));
            address addr = vm.addr(pk);
            voterPKs.push(pk);
            voterAddrs.push(addr);
        }
        // Sort addresses (bubble sort, fine for N=100 in tests)
        for (uint256 i = 0; i < N; i++) {
            for (uint256 j = i + 1; j < N; j++) {
                if (voterAddrs[i] > voterAddrs[j]) {
                    (voterAddrs[i], voterAddrs[j]) = (voterAddrs[j], voterAddrs[i]);
                    (voterPKs[i], voterPKs[j]) = (voterPKs[j], voterPKs[i]);
                }
            }
        }
        for (uint256 i = 0; i < N; i++) {
            addrToPK[voterAddrs[i]] = voterPKs[i];
        }

        // Build the initial signing policy
        uint32 startVotingRound = _firstVotingRoundInEpoch(REWARD_EPOCH_ID);
        signingPolicyEncoded = _encodeSigningPolicy(
            REWARD_EPOCH_ID, startVotingRound, THRESHOLD,
            bytes32(uint256(12345)), voterAddrs, SINGLE_WEIGHT
        );
        signingPolicyHash = _hashEncodedSigningPolicy(signingPolicyEncoded);

        // Deploy relay (no signing policy setter)
        IRelay.FeeConfig[] memory feeConfigs = new IRelay.FeeConfig[](0);
        IRelay.RelayInitialConfig memory cfg = IRelay.RelayInitialConfig({
            initialRewardEpochId: REWARD_EPOCH_ID,
            startingVotingRoundIdForInitialRewardEpochId: startVotingRound,
            initialSigningPolicyHash: signingPolicyHash,
            randomNumberProtocolId: RANDOM_NUMBER_PROTOCOL_ID,
            firstVotingRoundStartTs: FIRST_VOTING_ROUND_START_TS,
            votingEpochDurationSeconds: VOTING_EPOCH_DURATION_SEC,
            firstRewardEpochStartVotingRoundId: FIRST_REWARD_EPOCH_VOTING_ROUND_ID,
            rewardEpochDurationInVotingEpochs: REWARD_EPOCH_DURATION,
            thresholdIncreaseBIPS: THRESHOLD_INCREASE_BIPS,
            messageFinalizationWindowInRewardEpochs: MSG_FINALIZATION_WINDOW,
            feeCollectionAddress: payable(address(0)),
            feeConfigs: feeConfigs
        });
        relay = new Relay(cfg, address(0), IRelay(address(0)));

        // Deploy relay with signing policy setter
        relayWithSetter = new Relay(cfg, address(this), IRelay(address(0)));
    }

    // ── Signing policy initialization ────────────────────────────────────────

    function testInitialSigningPolicyIsSet() public {
        (uint32 lastEpoch, uint32 startVR) = relay.lastInitializedRewardEpochData();
        assertEq(lastEpoch, REWARD_EPOCH_ID);
        assertEq(startVR, _firstVotingRoundInEpoch(REWARD_EPOCH_ID));
    }

    // ── Relay protocol message (random number protocol) ──────────────────────

    function testRelayMessageForRandomNumberProtocol() public {
        bytes32 merkleRoot = keccak256("randomRoot");
        bytes memory callData = _buildRelayCalldata(
            signingPolicyEncoded,
            RANDOM_NUMBER_PROTOCOL_ID,
            VOTING_ROUND_ID,
            true,
            merkleRoot,
            N / 2 + 1 // majority
        );

        vm.recordLogs();
        (bool success, ) = address(relay).call(callData);
        assertTrue(success);
        _assertProtocolMessageRelayed(
            RANDOM_NUMBER_PROTOCOL_ID, VOTING_ROUND_ID, true, merkleRoot
        );

        assertTrue(relay.isFinalized(RANDOM_NUMBER_PROTOCOL_ID, VOTING_ROUND_ID));

        (uint256 randomNumber, bool isSecure,) = relay.getRandomNumber();
        assertEq(randomNumber, uint256(keccak256(abi.encode(merkleRoot))));
        assertTrue(isSecure);
    }

    // ── Relay protocol message (non random number protocol) ──────────────────

    function testRelayMessageForNonRandomNumberProtocol() public {
        bytes32 merkleRoot = keccak256("otherRoot");
        uint8 protocolId = 3;
        bytes memory callData = _buildRelayCalldata(
            signingPolicyEncoded,
            protocolId,
            VOTING_ROUND_ID,
            false,
            merkleRoot,
            N / 2 + 1
        );

        vm.recordLogs();
        (bool success, ) = address(relay).call(callData);
        assertTrue(success);
        _assertProtocolMessageRelayed(
            protocolId, VOTING_ROUND_ID, false, merkleRoot
        );

        assertTrue(relay.isFinalized(protocolId, VOTING_ROUND_ID));
    }

    // ── Fail: low weight ─────────────────────────────────────────────────────

    function testRevertRelayNotEnoughWeight() public {
        bytes32 merkleRoot = keccak256("root");
        bytes memory callData = _buildRelayCalldata(
            signingPolicyEncoded,
            RANDOM_NUMBER_PROTOCOL_ID,
            VOTING_ROUND_ID,
            true,
            merkleRoot,
            N / 2 // not enough, need N/2+1
        );

        (bool success, bytes memory retData) = address(relay).call(callData);
        assertFalse(success);
        _assertRevertMsg(retData, "Not enough weight");
    }

    // ── Fail: non increasing signature indices ───────────────────────────────

    function testRevertRelayIndexOutOfOrder() public {
        bytes32 merkleRoot = keccak256("root");
        bytes memory message = _encodeProtocolMessage(
            RANDOM_NUMBER_PROTOCOL_ID, VOTING_ROUND_ID, true, merkleRoot
        );
        bytes32 msgHash = _hashProtocolMessage(message);

        // Build signatures with non-increasing indices: [0,1,2,2,1]
        uint256[] memory indices = new uint256[](5);
        indices[0] = 0; indices[1] = 1; indices[2] = 2; indices[3] = 2; indices[4] = 1;
        bytes memory sigs = _signWithIndices(msgHash, indices);

        bytes memory callData = abi.encodePacked(
            bytes4(keccak256("relay()")),
            signingPolicyEncoded,
            message,
            sigs
        );

        (bool success, bytes memory retData) = address(relay).call(callData);
        assertFalse(success);
        _assertRevertMsg(retData, "Index out of order");
    }

    // ── Fail: signature index out of range ───────────────────────────────────

    function testRevertRelayIndexOutOfRange() public {
        bytes32 merkleRoot = keccak256("root");
        bytes memory message = _encodeProtocolMessage(
            RANDOM_NUMBER_PROTOCOL_ID, VOTING_ROUND_ID, true, merkleRoot
        );
        bytes32 msgHash = _hashProtocolMessage(message);

        uint256[] memory indices = new uint256[](1);
        indices[0] = 101; // out of range for 100 voters
        bytes memory sigs = _signWithIndices(msgHash, indices);

        bytes memory callData = abi.encodePacked(
            bytes4(keccak256("relay()")),
            signingPolicyEncoded,
            message,
            sigs
        );

        (bool success, bytes memory retData) = address(relay).call(callData);
        assertFalse(success);
        _assertRevertMsg(retData, "Index out of range");
    }

    // ── Fail: too short metadata ─────────────────────────────────────────────

    function testRevertRelayInvalidSignPolicyMetadata() public {
        // Send too-short signing policy (< 11 bytes metadata)
        bytes memory callData = abi.encodePacked(
            bytes4(keccak256("relay()")),
            bytes10(0) // 10 bytes, too short
        );

        (bool success, bytes memory retData) = address(relay).call(callData);
        assertFalse(success);
        _assertRevertMsg(retData, "Invalid sign policy metadata");
    }

    // ── Fail: signing policy length mismatch ─────────────────────────────────

    function testRevertRelayInvalidSignPolicyLength() public {
        // Alter the numberOfVoters in the encoded signing policy to a LARGER value
        // so the expected length exceeds calldatasize → "Invalid sign policy length"
        bytes memory alteredPolicy = new bytes(signingPolicyEncoded.length);
        for (uint256 i = 0; i < signingPolicyEncoded.length; i++) {
            alteredPolicy[i] = signingPolicyEncoded[i];
        }
        // Change numberOfVoters to 200 (bytes 0-1, big-endian) so the relay
        // expects 43+200*22=4443 bytes but only gets 43+100*22=2243
        alteredPolicy[0] = bytes1(0x00);
        alteredPolicy[1] = bytes1(0xC8); // 200

        bytes memory message = _encodeProtocolMessage(
            RANDOM_NUMBER_PROTOCOL_ID, VOTING_ROUND_ID, true, keccak256("root")
        );

        bytes memory callData = abi.encodePacked(
            bytes4(keccak256("relay()")),
            alteredPolicy,
            message,
            uint16(0) // 0 signatures
        );

        (bool success, bytes memory retData) = address(relay).call(callData);
        assertFalse(success);
        _assertRevertMsg(retData, "Invalid sign policy length");
    }

    // ── Fail: signing policy hash mismatch ───────────────────────────────────

    function testRevertRelaySigningPolicyHashMismatch() public {
        // Alter last byte of the signing policy to change the hash
        bytes memory alteredPolicy = new bytes(signingPolicyEncoded.length);
        for (uint256 i = 0; i < signingPolicyEncoded.length; i++) {
            alteredPolicy[i] = signingPolicyEncoded[i];
        }
        alteredPolicy[alteredPolicy.length - 1] = bytes1(
            uint8(alteredPolicy[alteredPolicy.length - 1]) ^ 0xff
        );

        bytes memory message = _encodeProtocolMessage(
            RANDOM_NUMBER_PROTOCOL_ID, VOTING_ROUND_ID, true, keccak256("root")
        );

        bytes memory callData = abi.encodePacked(
            bytes4(keccak256("relay()")),
            alteredPolicy,
            message,
            uint16(0) // 0 signatures
        );

        (bool success, bytes memory retData) = address(relay).call(callData);
        assertFalse(success);
        _assertRevertMsg(retData, "Signing policy hash mismatch");
    }

    // ── Fail: too short message ──────────────────────────────────────────────

    function testRevertRelayTooShortMessage() public {
        // protocolId > 0 (1 byte) + only 4 more bytes = 5 bytes total, need 38
        bytes memory callData = abi.encodePacked(
            bytes4(keccak256("relay()")),
            signingPolicyEncoded,
            uint8(5), // protocolId = 5 (non-zero to avoid "new signing policy" path)
            bytes4(0)
        );

        (bool success, bytes memory retData) = address(relay).call(callData);
        assertFalse(success);
        _assertRevertMsg(retData, "Too short message");
    }

    // ── Fail: delayed signing policy ─────────────────────────────────────────

    function testRevertRelayDelayedSignPolicy() public {
        // Create a signing policy with startVotingRoundId AFTER the message votingRoundId
        uint32 futureStart = VOTING_ROUND_ID + 100;
        bytes memory futurePolicy = _encodeSigningPolicy(
            REWARD_EPOCH_ID, futureStart, THRESHOLD,
            bytes32(uint256(12345)), voterAddrs, SINGLE_WEIGHT
        );
        bytes32 futureHash = _hashEncodedSigningPolicy(futurePolicy);

        // Deploy a new relay with this future policy
        IRelay.FeeConfig[] memory feeConfigs = new IRelay.FeeConfig[](0);
        IRelay.RelayInitialConfig memory cfg = IRelay.RelayInitialConfig({
            initialRewardEpochId: REWARD_EPOCH_ID,
            startingVotingRoundIdForInitialRewardEpochId: futureStart,
            initialSigningPolicyHash: futureHash,
            randomNumberProtocolId: RANDOM_NUMBER_PROTOCOL_ID,
            firstVotingRoundStartTs: FIRST_VOTING_ROUND_START_TS,
            votingEpochDurationSeconds: VOTING_EPOCH_DURATION_SEC,
            firstRewardEpochStartVotingRoundId: FIRST_REWARD_EPOCH_VOTING_ROUND_ID,
            rewardEpochDurationInVotingEpochs: REWARD_EPOCH_DURATION,
            thresholdIncreaseBIPS: THRESHOLD_INCREASE_BIPS,
            messageFinalizationWindowInRewardEpochs: MSG_FINALIZATION_WINDOW,
            feeCollectionAddress: payable(address(0)),
            feeConfigs: feeConfigs
        });
        Relay relayFuture = new Relay(cfg, address(0), IRelay(address(0)));

        bytes memory callData = _buildRelayCalldata(
            futurePolicy,
            RANDOM_NUMBER_PROTOCOL_ID,
            VOTING_ROUND_ID,
            true,
            keccak256("root"),
            N / 2 + 1
        );

        (bool success, bytes memory retData) = address(relayFuture).call(callData);
        assertFalse(success);
        _assertRevertMsg(retData, "Delayed sign policy");
    }

    // ── Fail: already relayed ────────────────────────────────────────────────

    function testRevertRelayAlreadyRelayed() public {
        bytes32 merkleRoot = keccak256("root");
        bytes memory callData = _buildRelayCalldata(
            signingPolicyEncoded,
            RANDOM_NUMBER_PROTOCOL_ID,
            VOTING_ROUND_ID,
            true,
            merkleRoot,
            N / 2 + 1
        );

        (bool success1, ) = address(relay).call(callData);
        assertTrue(success1);

        // Second relay should fail
        (bool success2, bytes memory retData) = address(relay).call(callData);
        assertFalse(success2);
        _assertRevertMsg(retData, "Already relayed");
    }

    // ── Relay new signing policy ─────────────────────────────────────────────

    function testRelayNewSigningPolicy() public {
        // Build new signing policy for next reward epoch
        uint24 newEpochId = REWARD_EPOCH_ID + 1;
        uint32 newStart = _firstVotingRoundInEpoch(newEpochId) + 10; // slight delay

        // Use fewer voters for the new policy
        address[] memory newVoters = new address[](50);
        uint256[] memory newPKs = new uint256[](50);
        for (uint256 i = 0; i < 50; i++) {
            newVoters[i] = voterAddrs[i];
            newPKs[i] = voterPKs[i];
        }
        uint16 newThreshold = 12500; // 50 * 500 / 2
        bytes memory newPolicyEncoded = _encodeSigningPolicy(
            newEpochId, newStart, newThreshold,
            bytes32(uint256(99999)), newVoters, SINGLE_WEIGHT
        );

        bytes memory callData = _buildRelayNewPolicyCalldata(
            signingPolicyEncoded,
            newPolicyEncoded,
            N / 2 + 1
        );

        vm.recordLogs();
        (bool success, ) = address(relay).call(callData);
        assertTrue(success);
        _assertSigningPolicyRelayed(newEpochId);

        // Verify the new epoch data
        (uint32 lastEpoch, uint32 startVR) = relay.lastInitializedRewardEpochData();
        assertEq(lastEpoch, newEpochId);
        assertEq(startVR, newStart);
    }

    // ── Fail: relay new signing policy disabled when setter is set ────────────

    function testRevertRelayNewPolicyDisabledWithSetter() public {
        uint24 newEpochId = REWARD_EPOCH_ID + 1;
        uint32 newStart = _firstVotingRoundInEpoch(newEpochId);

        bytes memory newPolicyEncoded = _encodeSigningPolicy(
            newEpochId, newStart, THRESHOLD,
            bytes32(uint256(99999)), voterAddrs, SINGLE_WEIGHT
        );

        bytes memory callData = _buildRelayNewPolicyCalldata(
            signingPolicyEncoded,
            newPolicyEncoded,
            N / 2 + 1
        );

        (bool success, bytes memory retData) = address(relayWithSetter).call(callData);
        assertFalse(success);
        _assertRevertMsg(retData, "Sign policy relay disabled");
    }

    // ── Relay with old signing policy + 20% more weight ──────────────────────

    function testRelayMessageWithOldPolicyAndMoreWeight() public {
        // First relay a new signing policy
        uint24 newEpochId = REWARD_EPOCH_ID + 1;
        uint32 newStart = _firstVotingRoundInEpoch(newEpochId) + 100; // delayed

        address[] memory newVoters = new address[](50);
        for (uint256 i = 0; i < 50; i++) {
            newVoters[i] = voterAddrs[i];
        }
        bytes memory newPolicyEncoded = _encodeSigningPolicy(
            newEpochId, newStart, 12500,
            bytes32(uint256(99999)), newVoters, SINGLE_WEIGHT
        );

        bytes memory policyCallData = _buildRelayNewPolicyCalldata(
            signingPolicyEncoded, newPolicyEncoded, N / 2 + 1
        );
        (bool s1, ) = address(relay).call(policyCallData);
        assertTrue(s1);

        // Now relay a message from the new epoch using the OLD signing policy
        // Need 60% signatures (50% + 20% = 60% of N = 61 sigs)
        // The voting round is in new epoch but before newStart
        uint32 msgVotingRound = _firstVotingRoundInEpoch(newEpochId) + 5;
        require(msgVotingRound < newStart, "msg should be before new start");

        bytes memory callData = _buildRelayCalldata(
            signingPolicyEncoded,
            RANDOM_NUMBER_PROTOCOL_ID,
            msgVotingRound,
            true,
            keccak256("oldPolicyRoot"),
            61 // 61% > 60% needed
        );

        (bool success, ) = address(relay).call(callData);
        assertTrue(success);
    }

    // ── Fail: old signing policy not enough extra weight ─────────────────────

    function testRevertRelayOldPolicyNotEnoughExtraWeight() public {
        // Do NOT relay a new signing policy. The threshold increase only applies when
        // lastInitializedRewardEpoch == rewardEpochId (no new policy initialized).
        // Message is in next epoch (epoch 2), using old policy (epoch 1).
        // Threshold increase: 25000 * 12000 / 10000 = 30000
        // 60 sigs × 500 = 30000, gt(30000, 30000) = false → "Not enough weight"
        uint32 msgVotingRound = _firstVotingRoundInEpoch(REWARD_EPOCH_ID + 1) + 5;
        bytes memory callData = _buildRelayCalldata(
            signingPolicyEncoded,
            RANDOM_NUMBER_PROTOCOL_ID,
            msgVotingRound,
            true,
            keccak256("oldPolicyRoot2"),
            60 // 60*500=30000, exactly at adjusted threshold, not strictly greater
        );

        (bool success, bytes memory retData) = address(relay).call(callData);
        assertFalse(success);
        _assertRevertMsg(retData, "Not enough weight");
    }

    // ── Relay message with new signing policy ────────────────────────────────

    function testRelayMessageWithNewPolicy() public {
        // Relay new signing policy
        uint24 newEpochId = REWARD_EPOCH_ID + 1;
        uint32 newStart = _firstVotingRoundInEpoch(newEpochId);

        address[] memory newVoters = new address[](50);
        uint256[] memory newPKs = new uint256[](50);
        for (uint256 i = 0; i < 50; i++) {
            newVoters[i] = voterAddrs[i];
            newPKs[i] = voterPKs[i];
        }
        uint16 newThreshold = 12500;
        bytes memory newPolicyEncoded = _encodeSigningPolicy(
            newEpochId, newStart, newThreshold,
            bytes32(uint256(99999)), newVoters, SINGLE_WEIGHT
        );

        bytes memory policyCallData = _buildRelayNewPolicyCalldata(
            signingPolicyEncoded, newPolicyEncoded, N / 2 + 1
        );
        (bool s1, ) = address(relay).call(policyCallData);
        assertTrue(s1);

        // Relay a message using the new signing policy
        uint32 msgVotingRound = newStart + 10;
        bytes memory callData = _buildRelayCalldataWithKeys(
            newPolicyEncoded,
            RANDOM_NUMBER_PROTOCOL_ID,
            msgVotingRound,
            true,
            keccak256("newPolicyRoot"),
            26, // 26 of 50 = majority
            newVoters,
            newPKs
        );

        (bool success, ) = address(relay).call(callData);
        assertTrue(success);
    }

    // ── Direct signing policy setup tests ────────────────────────────────────

    function testDirectSetSigningPolicy() public {
        IIRelay.SigningPolicy memory sp = IIRelay.SigningPolicy({
            rewardEpochId: REWARD_EPOCH_ID + 1,
            startVotingRoundId: _firstVotingRoundInEpoch(REWARD_EPOCH_ID + 1),
            threshold: THRESHOLD,
            seed: 12345,
            voters: voterAddrs,
            weights: _uniformWeights(N, SINGLE_WEIGHT)
        });

        bytes32 hash = relayWithSetter.setSigningPolicy(sp);
        assertTrue(hash != bytes32(0));

        (uint32 lastEpoch, uint32 startVR) = relayWithSetter.lastInitializedRewardEpochData();
        assertEq(lastEpoch, REWARD_EPOCH_ID + 1);
        assertEq(startVR, _firstVotingRoundInEpoch(REWARD_EPOCH_ID + 1));
    }

    function testRevertDirectSetSigningPolicyWrongEpoch() public {
        IIRelay.SigningPolicy memory sp = IIRelay.SigningPolicy({
            rewardEpochId: REWARD_EPOCH_ID + 5, // wrong, should be +1
            startVotingRoundId: _firstVotingRoundInEpoch(REWARD_EPOCH_ID + 5),
            threshold: THRESHOLD,
            seed: 12345,
            voters: voterAddrs,
            weights: _uniformWeights(N, SINGLE_WEIGHT)
        });

        vm.expectRevert("not next reward epoch");
        relayWithSetter.setSigningPolicy(sp);
    }

    function testRevertDirectSetSigningPolicyTrivial() public {
        address[] memory emptyVoters = new address[](0);
        uint16[] memory emptyWeights = new uint16[](0);

        IIRelay.SigningPolicy memory sp = IIRelay.SigningPolicy({
            rewardEpochId: REWARD_EPOCH_ID + 1,
            startVotingRoundId: _firstVotingRoundInEpoch(REWARD_EPOCH_ID + 1),
            threshold: 0,
            seed: 12345,
            voters: emptyVoters,
            weights: emptyWeights
        });

        vm.expectRevert("must be non-trivial");
        relayWithSetter.setSigningPolicy(sp);
    }

    function testRevertDirectSetSigningPolicySizeMismatch() public {
        uint16[] memory shortWeights = new uint16[](N - 1);
        for (uint256 i = 0; i < N - 1; i++) {
            shortWeights[i] = SINGLE_WEIGHT;
        }

        IIRelay.SigningPolicy memory sp = IIRelay.SigningPolicy({
            rewardEpochId: REWARD_EPOCH_ID + 1,
            startVotingRoundId: _firstVotingRoundInEpoch(REWARD_EPOCH_ID + 1),
            threshold: THRESHOLD,
            seed: 12345,
            voters: voterAddrs,
            weights: shortWeights
        });

        vm.expectRevert("size mismatch");
        relayWithSetter.setSigningPolicy(sp);
    }

    function testRevertDirectSetSigningPolicyWrongSetter() public {
        IIRelay.SigningPolicy memory sp = IIRelay.SigningPolicy({
            rewardEpochId: REWARD_EPOCH_ID + 1,
            startVotingRoundId: _firstVotingRoundInEpoch(REWARD_EPOCH_ID + 1),
            threshold: THRESHOLD,
            seed: 12345,
            voters: voterAddrs,
            weights: _uniformWeights(N, SINGLE_WEIGHT)
        });

        vm.prank(makeAddr("wrongSetter"));
        vm.expectRevert("only sign policy setter");
        relayWithSetter.setSigningPolicy(sp);
    }

    function testRevertDirectSetSigningPolicyTooBigThreshold() public {
        // threshold * 10000 > totalWeight * 6600 → too big
        uint16 tooBigThreshold = 40000; // 40000 * 10000 = 400M > 50000 * 6600 = 330M

        IIRelay.SigningPolicy memory sp = IIRelay.SigningPolicy({
            rewardEpochId: REWARD_EPOCH_ID + 1,
            startVotingRoundId: _firstVotingRoundInEpoch(REWARD_EPOCH_ID + 1),
            threshold: tooBigThreshold,
            seed: 12345,
            voters: voterAddrs,
            weights: _uniformWeights(N, SINGLE_WEIGHT)
        });

        vm.expectRevert("too big threshold");
        relayWithSetter.setSigningPolicy(sp);
    }

    function testRevertDirectSetSigningPolicyTooSmallThreshold() public {
        // threshold * 10000 < totalWeight * 5000 → too small
        uint16 tooSmallThreshold = 1000; // 1000 * 10000 = 10M < 50000 * 5000 = 250M

        IIRelay.SigningPolicy memory sp = IIRelay.SigningPolicy({
            rewardEpochId: REWARD_EPOCH_ID + 1,
            startVotingRoundId: _firstVotingRoundInEpoch(REWARD_EPOCH_ID + 1),
            threshold: tooSmallThreshold,
            seed: 12345,
            voters: voterAddrs,
            weights: _uniformWeights(N, SINGLE_WEIGHT)
        });

        vm.expectRevert("too small threshold");
        relayWithSetter.setSigningPolicy(sp);
    }

    function testRevertDirectSetSigningPolicyTooManyVoters() public {
        // MAX_VOTERS = 300, try 301
        address[] memory manyVoters = new address[](301);
        uint16[] memory manyWeights = new uint16[](301);
        for (uint256 i = 0; i < 301; i++) {
            manyVoters[i] = address(uint160(i + 1));
            manyWeights[i] = 1;
        }
        // totalWeight = 301, threshold ~ 50-66% of 301 = 151-199
        uint16 threshold = 165;

        IIRelay.SigningPolicy memory sp = IIRelay.SigningPolicy({
            rewardEpochId: REWARD_EPOCH_ID + 1,
            startVotingRoundId: _firstVotingRoundInEpoch(REWARD_EPOCH_ID + 1),
            threshold: threshold,
            seed: 12345,
            voters: manyVoters,
            weights: manyWeights
        });

        vm.expectRevert("too many voters");
        relayWithSetter.setSigningPolicy(sp);
    }

    function testRevertDirectSetSigningPolicyTotalWeightTooBig() public {
        // Make weights such that totalWeight >= 2^16
        address[] memory voters2 = new address[](2);
        voters2[0] = voterAddrs[0];
        voters2[1] = voterAddrs[1];
        uint16[] memory bigWeights = new uint16[](2);
        bigWeights[0] = 40000;
        bigWeights[1] = 30000; // total = 70000 > 2^16-1 = 65535

        IIRelay.SigningPolicy memory sp = IIRelay.SigningPolicy({
            rewardEpochId: REWARD_EPOCH_ID + 1,
            startVotingRoundId: _firstVotingRoundInEpoch(REWARD_EPOCH_ID + 1),
            threshold: 40000,
            seed: 12345,
            voters: voters2,
            weights: bigWeights
        });

        vm.expectRevert("total weight too big");
        relayWithSetter.setSigningPolicy(sp);
    }

    // ── Merkle proof verification ────────────────────────────────────────────

    function testVerifyMerkleProof() public {
        // Build a merkle tree with 4 leaves
        bytes32[] memory leaves = new bytes32[](4);
        leaves[0] = keccak256(abi.encodePacked("leaf0"));
        leaves[1] = keccak256(abi.encodePacked("leaf1"));
        leaves[2] = keccak256(abi.encodePacked("leaf2"));
        leaves[3] = keccak256(abi.encodePacked("leaf3"));

        // Build tree (sorted pairs)
        bytes32 node01 = _sortedHash(leaves[0], leaves[1]);
        bytes32 node23 = _sortedHash(leaves[2], leaves[3]);
        bytes32 root = _sortedHash(node01, node23);

        // Relay a message with this merkle root
        uint8 protocolId = 5;
        bytes memory callData = _buildRelayCalldata(
            signingPolicyEncoded,
            protocolId,
            VOTING_ROUND_ID,
            false,
            root,
            N / 2 + 1
        );
        (bool success, ) = address(relay).call(callData);
        assertTrue(success);

        // Verify leaf0 with proof [leaf1, node23]
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = leaves[1];
        proof[1] = node23;

        bool verified = relay.verify(protocolId, VOTING_ROUND_ID, leaves[0], proof);
        assertTrue(verified);
    }

    function testRevertVerifyTooLowFee() public {
        // Deploy relay with fee
        IRelay.FeeConfig[] memory feeConfigs = new IRelay.FeeConfig[](1);
        feeConfigs[0] = IRelay.FeeConfig({protocolId: 17, feeInWei: 1000});

        uint32 startVR = _firstVotingRoundInEpoch(REWARD_EPOCH_ID);
        IRelay.RelayInitialConfig memory cfg = IRelay.RelayInitialConfig({
            initialRewardEpochId: REWARD_EPOCH_ID,
            startingVotingRoundIdForInitialRewardEpochId: startVR,
            initialSigningPolicyHash: signingPolicyHash,
            randomNumberProtocolId: RANDOM_NUMBER_PROTOCOL_ID,
            firstVotingRoundStartTs: FIRST_VOTING_ROUND_START_TS,
            votingEpochDurationSeconds: VOTING_EPOCH_DURATION_SEC,
            firstRewardEpochStartVotingRoundId: FIRST_REWARD_EPOCH_VOTING_ROUND_ID,
            rewardEpochDurationInVotingEpochs: REWARD_EPOCH_DURATION,
            thresholdIncreaseBIPS: THRESHOLD_INCREASE_BIPS,
            messageFinalizationWindowInRewardEpochs: MSG_FINALIZATION_WINDOW,
            feeCollectionAddress: payable(address(0xdead)),
            feeConfigs: feeConfigs
        });
        Relay relayFee = new Relay(cfg, address(0), IRelay(address(0)));

        // Relay a message
        bytes32 root = keccak256("feeRoot");
        bytes memory callData = _buildRelayCalldata(
            signingPolicyEncoded, 17, VOTING_ROUND_ID, false, root, N / 2 + 1
        );
        (bool s, ) = address(relayFee).call(callData);
        assertTrue(s);

        // Verify with insufficient fee
        bytes32[] memory proof = new bytes32[](0);
        vm.expectRevert("too low fee");
        relayFee.verify{value: 999}(17, VOTING_ROUND_ID, root, proof);
    }

    function testVerifyWithFee() public {
        // Deploy relay with fee
        address payable burnAddr = payable(address(0xdead));
        IRelay.FeeConfig[] memory feeConfigs = new IRelay.FeeConfig[](1);
        feeConfigs[0] = IRelay.FeeConfig({protocolId: 17, feeInWei: 1000});

        uint32 startVR = _firstVotingRoundInEpoch(REWARD_EPOCH_ID);
        IRelay.RelayInitialConfig memory cfg = IRelay.RelayInitialConfig({
            initialRewardEpochId: REWARD_EPOCH_ID,
            startingVotingRoundIdForInitialRewardEpochId: startVR,
            initialSigningPolicyHash: signingPolicyHash,
            randomNumberProtocolId: RANDOM_NUMBER_PROTOCOL_ID,
            firstVotingRoundStartTs: FIRST_VOTING_ROUND_START_TS,
            votingEpochDurationSeconds: VOTING_EPOCH_DURATION_SEC,
            firstRewardEpochStartVotingRoundId: FIRST_REWARD_EPOCH_VOTING_ROUND_ID,
            rewardEpochDurationInVotingEpochs: REWARD_EPOCH_DURATION,
            thresholdIncreaseBIPS: THRESHOLD_INCREASE_BIPS,
            messageFinalizationWindowInRewardEpochs: MSG_FINALIZATION_WINDOW,
            feeCollectionAddress: burnAddr,
            feeConfigs: feeConfigs
        });
        Relay relayFee = new Relay(cfg, address(0), IRelay(address(0)));

        // Relay a message
        bytes32 root = keccak256("feeRoot2");
        bytes memory callData = _buildRelayCalldata(
            signingPolicyEncoded, 17, VOTING_ROUND_ID, false, root, N / 2 + 1
        );
        (bool s, ) = address(relayFee).call(callData);
        assertTrue(s);

        // Verify with fee
        uint256 balBefore = burnAddr.balance;
        bytes32[] memory proof = new bytes32[](0);
        relayFee.verify{value: 1000}(17, VOTING_ROUND_ID, root, proof);
        assertEq(burnAddr.balance - balBefore, 1000);
    }

    // ── Random number tests ──────────────────────────────────────────────────

    function testRandomNumberHistorical() public {
        // Relay two random number messages
        bytes32 root1 = keccak256("random1");
        bytes32 root2 = keccak256("random2");
        uint32 vr1 = VOTING_ROUND_ID;
        uint32 vr2 = VOTING_ROUND_ID + 39;

        bytes memory cd1 = _buildRelayCalldata(
            signingPolicyEncoded, RANDOM_NUMBER_PROTOCOL_ID, vr1, true, root1, N / 2 + 1
        );
        (bool s1, ) = address(relay).call(cd1);
        assertTrue(s1);

        bytes memory cd2 = _buildRelayCalldata(
            signingPolicyEncoded, RANDOM_NUMBER_PROTOCOL_ID, vr2, false, root2, N / 2 + 1
        );
        (bool s2, ) = address(relay).call(cd2);
        assertTrue(s2);

        // Latest should be vr2 (non-secure)
        (uint256 latestRandom, bool latestSecure,) = relay.getRandomNumber();
        assertEq(latestRandom, uint256(keccak256(abi.encode(root2))));
        assertFalse(latestSecure);

        // Historical for vr1
        (uint256 histRandom, bool histSecure,) = relay.getRandomNumberHistorical(vr1);
        assertEq(histRandom, uint256(keccak256(abi.encode(root1))));
        assertTrue(histSecure);

        // Non-existent should revert
        vm.expectRevert("no random number");
        relay.getRandomNumberHistorical(VOTING_ROUND_ID + 1);
    }

    // ── Voting round id calculation ──────────────────────────────────────────

    function testGetVotingRoundId() public {
        uint256 ts = FIRST_VOTING_ROUND_START_TS + 90 * 10;
        assertEq(relay.getVotingRoundId(ts), 10);
    }

    function testRevertGetVotingRoundIdBeforeStart() public {
        vm.expectRevert("before the start");
        relay.getVotingRoundId(FIRST_VOTING_ROUND_START_TS - 1);
    }

    // ── Access restriction tests for relay with setter ───────────────────────

    function testMerkleRootsAccessibleWithSetter() public {
        // Should not revert (signingPolicySetter is set)
        relayWithSetter.merkleRoots(1, 1);
    }

    function testRevertMerkleRootsNoAccessWithoutSetter() public {
        vm.expectRevert("no access to merkle roots");
        relay.merkleRoots(1, 1);
    }

    function testToSigningPolicyHashAccessibleWithSetter() public {
        relayWithSetter.toSigningPolicyHash(REWARD_EPOCH_ID);
    }

    function testRevertToSigningPolicyHashNoAccessWithoutSetter() public {
        vm.expectRevert("no access to signing policy hashes");
        relay.toSigningPolicyHash(REWARD_EPOCH_ID);
    }

    // ── State data ───────────────────────────────────────────────────────────

    function testStateData() public {
        (
            uint8 rnpId,
            uint32 fvrsts,
            uint8 veds,
            uint32 fresvri,
            uint16 redive,
            uint16 tibips,
            ,
            ,
            ,
            ,
            uint32 mfwire
        ) = relay.stateData();

        assertEq(rnpId, RANDOM_NUMBER_PROTOCOL_ID);
        assertEq(fvrsts, FIRST_VOTING_ROUND_START_TS);
        assertEq(veds, VOTING_EPOCH_DURATION_SEC);
        assertEq(fresvri, FIRST_REWARD_EPOCH_VOTING_ROUND_ID);
        assertEq(redive, REWARD_EPOCH_DURATION);
        assertEq(tibips, THRESHOLD_INCREASE_BIPS);
        assertEq(mfwire, MSG_FINALIZATION_WINDOW);
    }

    // ── Constructor reverts ──────────────────────────────────────────────────

    function testRevertConstructorThresholdIncreaseTooSmall() public {
        IRelay.FeeConfig[] memory feeConfigs = new IRelay.FeeConfig[](0);
        IRelay.RelayInitialConfig memory cfg = IRelay.RelayInitialConfig({
            initialRewardEpochId: REWARD_EPOCH_ID,
            startingVotingRoundIdForInitialRewardEpochId: _firstVotingRoundInEpoch(REWARD_EPOCH_ID),
            initialSigningPolicyHash: signingPolicyHash,
            randomNumberProtocolId: RANDOM_NUMBER_PROTOCOL_ID,
            firstVotingRoundStartTs: FIRST_VOTING_ROUND_START_TS,
            votingEpochDurationSeconds: VOTING_EPOCH_DURATION_SEC,
            firstRewardEpochStartVotingRoundId: FIRST_REWARD_EPOCH_VOTING_ROUND_ID,
            rewardEpochDurationInVotingEpochs: REWARD_EPOCH_DURATION,
            thresholdIncreaseBIPS: 5000, // too small, must be >= 10000
            messageFinalizationWindowInRewardEpochs: MSG_FINALIZATION_WINDOW,
            feeCollectionAddress: payable(address(0)),
            feeConfigs: feeConfigs
        });

        vm.expectRevert("threshold increase too small");
        new Relay(cfg, address(0), IRelay(address(0)));
    }

    function testRevertConstructorRandomNumberProtocolIdTooLow() public {
        IRelay.FeeConfig[] memory feeConfigs = new IRelay.FeeConfig[](0);
        IRelay.RelayInitialConfig memory cfg = IRelay.RelayInitialConfig({
            initialRewardEpochId: REWARD_EPOCH_ID,
            startingVotingRoundIdForInitialRewardEpochId: _firstVotingRoundInEpoch(REWARD_EPOCH_ID),
            initialSigningPolicyHash: signingPolicyHash,
            randomNumberProtocolId: 1, // must be > 1
            firstVotingRoundStartTs: FIRST_VOTING_ROUND_START_TS,
            votingEpochDurationSeconds: VOTING_EPOCH_DURATION_SEC,
            firstRewardEpochStartVotingRoundId: FIRST_REWARD_EPOCH_VOTING_ROUND_ID,
            rewardEpochDurationInVotingEpochs: REWARD_EPOCH_DURATION,
            thresholdIncreaseBIPS: THRESHOLD_INCREASE_BIPS,
            messageFinalizationWindowInRewardEpochs: MSG_FINALIZATION_WINDOW,
            feeCollectionAddress: payable(address(0)),
            feeConfigs: feeConfigs
        });

        vm.expectRevert("random number protocol id must be > 1");
        new Relay(cfg, address(0), IRelay(address(0)));
    }

    function testRevertConstructorFeeCannotBeSetWithSetter() public {
        IRelay.FeeConfig[] memory feeConfigs = new IRelay.FeeConfig[](1);
        feeConfigs[0] = IRelay.FeeConfig({protocolId: 5, feeInWei: 1000});

        IRelay.RelayInitialConfig memory cfg = IRelay.RelayInitialConfig({
            initialRewardEpochId: REWARD_EPOCH_ID,
            startingVotingRoundIdForInitialRewardEpochId: _firstVotingRoundInEpoch(REWARD_EPOCH_ID),
            initialSigningPolicyHash: signingPolicyHash,
            randomNumberProtocolId: RANDOM_NUMBER_PROTOCOL_ID,
            firstVotingRoundStartTs: FIRST_VOTING_ROUND_START_TS,
            votingEpochDurationSeconds: VOTING_EPOCH_DURATION_SEC,
            firstRewardEpochStartVotingRoundId: FIRST_REWARD_EPOCH_VOTING_ROUND_ID,
            rewardEpochDurationInVotingEpochs: REWARD_EPOCH_DURATION,
            thresholdIncreaseBIPS: THRESHOLD_INCREASE_BIPS,
            messageFinalizationWindowInRewardEpochs: MSG_FINALIZATION_WINDOW,
            feeCollectionAddress: payable(address(0)),
            feeConfigs: feeConfigs
        });

        vm.expectRevert("fee cannot be set");
        new Relay(cfg, address(this), IRelay(address(0)));
    }

    // ── Wrong signing policy reward epoch id ────────────────────────────────

    function testRevertRelayInvalidVotingRoundId() public {
        // votingRoundId = 1 is before any valid epoch
        bytes memory message = _encodeProtocolMessage(
            RANDOM_NUMBER_PROTOCOL_ID, 1, true, keccak256("root")
        );
        bytes memory callData = abi.encodePacked(
            bytes4(keccak256("relay()")),
            signingPolicyEncoded,
            message
        );
        (bool success, bytes memory retData) = address(relay).call(callData);
        assertFalse(success);
        _assertRevertMsg(retData, "Invalid voting round id");
    }

    function testRevertRelayWrongSignPolicyRewardEpoch() public {
        // votingRoundId one epoch BEFORE the signing policy's epoch
        uint32 earlyVR = VOTING_ROUND_ID - REWARD_EPOCH_DURATION;
        bytes memory message = _encodeProtocolMessage(
            RANDOM_NUMBER_PROTOCOL_ID, earlyVR, true, keccak256("root")
        );
        bytes memory callData = abi.encodePacked(
            bytes4(keccak256("relay()")),
            signingPolicyEncoded,
            message
        );
        (bool success, bytes memory retData) = address(relay).call(callData);
        assertFalse(success);
        _assertRevertMsg(retData, "Wrong sign policy reward epoch");
    }

    function testRevertRelayNoSignatureCount() public {
        // votingRoundId one epoch AFTER the signing policy → needs new policy
        // but no signature count provided
        uint32 futureVR = VOTING_ROUND_ID + REWARD_EPOCH_DURATION;
        bytes memory message = _encodeProtocolMessage(
            RANDOM_NUMBER_PROTOCOL_ID, futureVR, true, keccak256("root")
        );
        bytes memory callData = abi.encodePacked(
            bytes4(keccak256("relay()")),
            signingPolicyEncoded,
            message
        );
        (bool success, bytes memory retData) = address(relay).call(callData);
        assertFalse(success);
        _assertRevertMsg(retData, "No signature count");
    }

    // ── Old policy after delayed epoch init ──────────────────────────────────

    function testRelayOldPolicyAfterDelayedEpochInit() public {
        // Relay new signing policy with delayed start (+10)
        uint24 newEpochId = REWARD_EPOCH_ID + 1;
        uint32 newStart = _firstVotingRoundInEpoch(newEpochId) + 10;

        address[] memory newVoters = new address[](50);
        for (uint256 i = 0; i < 50; i++) {
            newVoters[i] = voterAddrs[i];
        }
        bytes memory newPolicyEncoded = _encodeSigningPolicy(
            newEpochId, newStart, 12500,
            bytes32(uint256(99999)), newVoters, SINGLE_WEIGHT
        );
        bytes memory policyCallData = _buildRelayNewPolicyCalldata(
            signingPolicyEncoded, newPolicyEncoded, N / 2 + 1
        );
        (bool s1, ) = address(relay).call(policyCallData);
        assertTrue(s1);

        // Relay message at newStart - 1 (before new policy kicks in) using old policy
        // Needs 60% weight since new policy is initialized
        uint32 msgVR = newStart - 1;
        bytes memory callData = _buildRelayCalldata(
            signingPolicyEncoded,
            RANDOM_NUMBER_PROTOCOL_ID,
            msgVR,
            true,
            keccak256("delayedRoot"),
            61 // 61 * 500 = 30500 > 25000 * 1.2 = 30000
        );

        vm.recordLogs();
        (bool success, ) = address(relay).call(callData);
        assertTrue(success);
        _assertProtocolMessageRelayed(
            RANDOM_NUMBER_PROTOCOL_ID, msgVR, true, keccak256("delayedRoot")
        );
    }

    function testRevertRelayMustUseNewSignPolicy() public {
        // Relay new signing policy with delayed start (+10)
        uint24 newEpochId = REWARD_EPOCH_ID + 1;
        uint32 newStart = _firstVotingRoundInEpoch(newEpochId) + 10;

        address[] memory newVoters = new address[](50);
        for (uint256 i = 0; i < 50; i++) {
            newVoters[i] = voterAddrs[i];
        }
        bytes memory newPolicyEncoded = _encodeSigningPolicy(
            newEpochId, newStart, 12500,
            bytes32(uint256(99999)), newVoters, SINGLE_WEIGHT
        );
        bytes memory policyCallData = _buildRelayNewPolicyCalldata(
            signingPolicyEncoded, newPolicyEncoded, N / 2 + 1
        );
        (bool s1, ) = address(relay).call(policyCallData);
        assertTrue(s1);

        // Try to relay at exactly newStart using old policy → must use new
        bytes memory callData = _buildRelayCalldata(
            signingPolicyEncoded,
            RANDOM_NUMBER_PROTOCOL_ID,
            newStart,
            true,
            keccak256("mustNewRoot"),
            61
        );
        (bool success, bytes memory retData) = address(relay).call(callData);
        assertFalse(success);
        _assertRevertMsg(retData, "Must use new sign policy");
    }

    // ── New signing policy relay errors ──────────────────────────────────────

    function testRevertRelayNewPolicyNoSize() public {
        // Old signing policy + protocolId=0 (new policy) + nothing else
        bytes memory callData = abi.encodePacked(
            bytes4(keccak256("relay()")),
            signingPolicyEncoded,
            uint8(0) // protocolId = 0 means new signing policy, but no policy data
        );
        (bool success, bytes memory retData) = address(relay).call(callData);
        assertFalse(success);
        _assertRevertMsg(retData, "No new sign policy size");
    }

    function testRevertRelayNewPolicyWrongSize() public {
        uint24 newEpochId = REWARD_EPOCH_ID + 1;
        uint32 newStart = _firstVotingRoundInEpoch(newEpochId);

        address[] memory newVoters = new address[](50);
        for (uint256 i = 0; i < 50; i++) {
            newVoters[i] = voterAddrs[i];
        }
        bytes memory newPolicyEncoded = _encodeSigningPolicy(
            newEpochId, newStart, 12500,
            bytes32(uint256(99999)), newVoters, SINGLE_WEIGHT
        );

        // Tamper with size: increment numberOfVoters by 1
        bytes memory tampered = newPolicyEncoded;
        uint16 origSize = uint16(uint8(tampered[0])) * 256 + uint16(uint8(tampered[1]));
        tampered[0] = bytes1(uint8((origSize + 1) >> 8));
        tampered[1] = bytes1(uint8(origSize + 1));

        bytes memory callData = abi.encodePacked(
            bytes4(keccak256("relay()")),
            signingPolicyEncoded,
            uint8(0),
            tampered
        );
        (bool success, bytes memory retData) = address(relay).call(callData);
        assertFalse(success);
        _assertRevertMsg(retData, "Wrong size for new sign policy");
    }

    function testRevertRelayNewPolicyNotNextRewardEpoch() public {
        // First relay epoch+1 so that lastInitialized = epoch+1
        uint24 newEpochId = REWARD_EPOCH_ID + 1;
        uint32 newStart = _firstVotingRoundInEpoch(newEpochId);
        address[] memory newVoters = new address[](50);
        for (uint256 i = 0; i < 50; i++) {
            newVoters[i] = voterAddrs[i];
        }
        bytes memory policy1 = _encodeSigningPolicy(
            newEpochId, newStart, 12500,
            bytes32(uint256(99999)), newVoters, SINGLE_WEIGHT
        );
        bytes memory cd1 = _buildRelayNewPolicyCalldata(
            signingPolicyEncoded, policy1, N / 2 + 1
        );
        (bool s1, ) = address(relay).call(cd1);
        assertTrue(s1);

        // Try to relay epoch+3 (skipping epoch+2)
        uint24 skipEpochId = newEpochId + 2;
        bytes memory policy3 = _encodeSigningPolicy(
            skipEpochId, _firstVotingRoundInEpoch(skipEpochId), 12500,
            bytes32(uint256(11111)), newVoters, SINGLE_WEIGHT
        );
        bytes memory cd3 = _buildRelayNewPolicyCalldata(
            policy1, policy3, 26
        );
        (bool success, bytes memory retData) = address(relay).call(cd3);
        assertFalse(success);
        _assertRevertMsg(retData, "Not next reward epoch");
    }

    function testRevertRelayNewPolicyNotWithLastInitialized() public {
        // First relay epoch+1
        uint24 newEpochId = REWARD_EPOCH_ID + 1;
        uint32 newStart = _firstVotingRoundInEpoch(newEpochId);
        address[] memory newVoters = new address[](50);
        for (uint256 i = 0; i < 50; i++) {
            newVoters[i] = voterAddrs[i];
        }
        bytes memory policy1 = _encodeSigningPolicy(
            newEpochId, newStart, 12500,
            bytes32(uint256(99999)), newVoters, SINGLE_WEIGHT
        );
        bytes memory cd1 = _buildRelayNewPolicyCalldata(
            signingPolicyEncoded, policy1, N / 2 + 1
        );
        (bool s1, ) = address(relay).call(cd1);
        assertTrue(s1);

        // Try to relay epoch+2 but use the ORIGINAL signing policy (not the last initialized)
        uint24 nextEpochId = newEpochId + 1;
        bytes memory policy2 = _encodeSigningPolicy(
            nextEpochId, _firstVotingRoundInEpoch(nextEpochId), 12500,
            bytes32(uint256(22222)), newVoters, SINGLE_WEIGHT
        );
        bytes memory cd2 = _buildRelayNewPolicyCalldata(
            signingPolicyEncoded, policy2, N / 2 + 1
        );
        (bool success, bytes memory retData) = address(relay).call(cd2);
        assertFalse(success);
        _assertRevertMsg(retData, "Not with last intialized");
    }

    function testRevertRelayNewPolicyNotEnoughSignatures() public {
        uint24 newEpochId = REWARD_EPOCH_ID + 1;
        uint32 newStart = _firstVotingRoundInEpoch(newEpochId);
        address[] memory newVoters = new address[](50);
        for (uint256 i = 0; i < 50; i++) {
            newVoters[i] = voterAddrs[i];
        }
        bytes memory newPolicyEncoded = _encodeSigningPolicy(
            newEpochId, newStart, 12500,
            bytes32(uint256(99999)), newVoters, SINGLE_WEIGHT
        );

        // Build calldata manually, truncating signature data
        bytes32 newPolicyHash = _hashEncodedSigningPolicy(newPolicyEncoded);
        bytes32 prefixedHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", newPolicyHash)
        );
        bytes memory sigs = _signSequential(prefixedHash, N / 4 + 1);
        // Truncate last byte from sigs
        bytes memory truncatedSigs = new bytes(sigs.length - 1);
        for (uint256 i = 0; i < truncatedSigs.length; i++) {
            truncatedSigs[i] = sigs[i];
        }

        bytes memory callData = abi.encodePacked(
            bytes4(keccak256("relay()")),
            signingPolicyEncoded,
            uint8(0),
            newPolicyEncoded,
            truncatedSigs
        );
        (bool success, bytes memory retData) = address(relay).call(callData);
        assertFalse(success);
        _assertRevertMsg(retData, "Not enough signatures");
    }

    function testRevertRelayNewPolicyWrongSignature() public {
        uint24 newEpochId = REWARD_EPOCH_ID + 1;
        uint32 newStart = _firstVotingRoundInEpoch(newEpochId);
        address[] memory newVoters = new address[](50);
        for (uint256 i = 0; i < 50; i++) {
            newVoters[i] = voterAddrs[i];
        }
        bytes memory newPolicyEncoded = _encodeSigningPolicy(
            newEpochId, newStart, 12500,
            bytes32(uint256(99999)), newVoters, SINGLE_WEIGHT
        );

        // Build calldata with tampered signature
        bytes32 newPolicyHash = _hashEncodedSigningPolicy(newPolicyEncoded);
        bytes32 prefixedHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", newPolicyHash)
        );
        bytes memory sigs = _signSequential(prefixedHash, N / 4 + 1);
        // Tamper: flip a byte in the last signature's r value
        sigs[sigs.length - 3] = bytes1(uint8(sigs[sigs.length - 3]) ^ 0x01);

        bytes memory callData = abi.encodePacked(
            bytes4(keccak256("relay()")),
            signingPolicyEncoded,
            uint8(0),
            newPolicyEncoded,
            sigs
        );
        (bool success, bytes memory retData) = address(relay).call(callData);
        assertFalse(success);
        _assertRevertMsg(retData, "Wrong signature");
    }

    // ── Fail: already relayed by old policy, re-attempt with new policy ─────

    function testRevertRelayAlreadyRelayedByOldPolicyWithNewPolicy() public {
        // Step 1: Relay a message at a voting round in epoch 2 using old policy
        uint32 msgVotingRound = _firstVotingRoundInEpoch(REWARD_EPOCH_ID + 1) + 5;
        bytes32 merkleRoot = keccak256("oldPolicyMsg");
        bytes memory callData1 = _buildRelayCalldata(
            signingPolicyEncoded,
            RANDOM_NUMBER_PROTOCOL_ID,
            msgVotingRound,
            true,
            merkleRoot,
            61 // 61 * 500 = 30500 > 25000 * 1.2 = 30000
        );
        (bool s1, ) = address(relay).call(callData1);
        assertTrue(s1);

        // Step 2: Relay new signing policy for epoch 2
        uint24 newEpochId = REWARD_EPOCH_ID + 1;
        uint32 newStart = _firstVotingRoundInEpoch(newEpochId) + 10;
        address[] memory newVoters = new address[](50);
        uint256[] memory newPKs = new uint256[](50);
        for (uint256 i = 0; i < 50; i++) {
            newVoters[i] = voterAddrs[i];
            newPKs[i] = voterPKs[i];
        }
        bytes memory newPolicyEncoded = _encodeSigningPolicy(
            newEpochId, newStart, 12500,
            bytes32(uint256(99999)), newVoters, SINGLE_WEIGHT
        );
        bytes memory policyCallData = _buildRelayNewPolicyCalldata(
            signingPolicyEncoded, newPolicyEncoded, N / 2 + 1
        );
        (bool s2, ) = address(relay).call(policyCallData);
        assertTrue(s2);

        // Step 3: Try to relay SAME (protocolId, votingRoundId) with new policy
        bytes memory callData2 = _buildRelayCalldataWithKeys(
            newPolicyEncoded,
            RANDOM_NUMBER_PROTOCOL_ID,
            msgVotingRound,
            true,
            merkleRoot,
            26,
            newVoters,
            newPKs
        );
        (bool success, bytes memory retData) = address(relay).call(callData2);
        assertFalse(success);
        _assertRevertMsg(retData, "Already relayed");
    }

    // ── Protocol id 1 message format checks ──────────────────────────────────

    function testRevertRelayProtocol1WrongMessageFormat() public {
        // protocolId=1 but votingRoundId != 0
        bytes memory callData = _buildRelayCalldata(
            signingPolicyEncoded,
            1,
            100, // votingRoundId should be 0 for protocolId=1
            false,
            keccak256("root"),
            N / 2 + 1
        );
        (bool success, bytes memory retData) = address(relay).call(callData);
        assertFalse(success);
        _assertRevertMsg(retData, "Wrong message format");
    }

    function testRevertRelayProtocol1WrongMessageFormat2() public {
        // protocolId=1 but isSecureRandom = true
        bytes memory callData = _buildRelayCalldata(
            signingPolicyEncoded,
            1,
            0,
            true, // isSecureRandom should be false for protocolId=1
            keccak256("root"),
            N / 2 + 1
        );
        (bool success, bytes memory retData) = address(relay).call(callData);
        assertFalse(success);
        _assertRevertMsg(retData, "Wrong message format2");
    }

    // ── Custom signature verification ────────────────────────────────────────

    function testVerifyCustomSignature() public {
        bytes32 messageHash = keccak256("customMsg");
        bytes memory relayCalldata = _buildRelayCalldata(
            signingPolicyEncoded,
            1, // protocolId = 1 (verification)
            0, // votingRoundId = 0
            false, // isSecureRandom = false
            messageHash,
            N / 2 + 1
        );
        uint256 epochId = relay.verifyCustomSignature(relayCalldata, messageHash);
        assertEq(epochId, REWARD_EPOCH_ID);
    }

    function testRevertVerifyCustomSignatureWrongHash() public {
        bytes32 messageHash = keccak256("customMsg");
        bytes memory relayCalldata = _buildRelayCalldata(
            signingPolicyEncoded,
            1, 0, false,
            messageHash,
            N / 2 + 1
        );
        vm.expectRevert("Invalid config hash");
        relay.verifyCustomSignature(relayCalldata, keccak256("wrongHash"));
    }

    // ── Governance fee setup ─────────────────────────────────────────────────

    function testGovernanceFeeSetup() public {
        IRelay.FeeConfig[] memory feeConfigs = new IRelay.FeeConfig[](1);
        feeConfigs[0] = IRelay.FeeConfig({protocolId: 5, feeInWei: 2000});
        IRelay.RelayGovernanceConfig memory config = IRelay.RelayGovernanceConfig({
            descriptionHash: keccak256("RelayGovernance"),
            chainId: block.chainid,
            newFeeConfigs: feeConfigs
        });
        bytes32 configHash = keccak256(abi.encode(config));

        bytes memory relayCalldata = _buildRelayCalldata(
            signingPolicyEncoded,
            1, 0, false,
            configHash,
            N / 2 + 1
        );
        relay.governanceFeeSetup(relayCalldata, config);
    }

    function testRevertGovernanceFeeSetupWithSetter() public {
        IRelay.FeeConfig[] memory feeConfigs = new IRelay.FeeConfig[](0);
        IRelay.RelayGovernanceConfig memory config = IRelay.RelayGovernanceConfig({
            descriptionHash: keccak256("RelayGovernance"),
            chainId: block.chainid,
            newFeeConfigs: feeConfigs
        });
        vm.expectRevert("fee cannot be set");
        relayWithSetter.governanceFeeSetup("", config);
    }

    function testRevertGovernanceFeeSetupWrongChainId() public {
        IRelay.FeeConfig[] memory feeConfigs = new IRelay.FeeConfig[](0);
        IRelay.RelayGovernanceConfig memory config = IRelay.RelayGovernanceConfig({
            descriptionHash: keccak256("RelayGovernance"),
            chainId: 999,
            newFeeConfigs: feeConfigs
        });
        vm.expectRevert("wrong chain id");
        relay.governanceFeeSetup("", config);
    }

    function testRevertGovernanceFeeSetupWrongDescriptionHash() public {
        IRelay.FeeConfig[] memory feeConfigs = new IRelay.FeeConfig[](0);
        IRelay.RelayGovernanceConfig memory config = IRelay.RelayGovernanceConfig({
            descriptionHash: keccak256("Wrong"),
            chainId: block.chainid,
            newFeeConfigs: feeConfigs
        });
        vm.expectRevert("wrong description hash");
        relay.governanceFeeSetup("", config);
    }

    function testRevertGovernanceFeeSetupInvalidProtocolId() public {
        IRelay.FeeConfig[] memory feeConfigs = new IRelay.FeeConfig[](1);
        feeConfigs[0] = IRelay.FeeConfig({protocolId: 1, feeInWei: 1000});
        IRelay.RelayGovernanceConfig memory config = IRelay.RelayGovernanceConfig({
            descriptionHash: keccak256("RelayGovernance"),
            chainId: block.chainid,
            newFeeConfigs: feeConfigs
        });
        vm.expectRevert("invalid protocol id");
        relay.governanceFeeSetup("", config);
    }

    function testRevertGovernanceFeeSetupTooOldPolicy() public {
        // Advance to epoch 3 so epoch 1 policy is too old for governance
        bytes memory lastPolicy = signingPolicyEncoded;
        for (uint24 i = REWARD_EPOCH_ID + 1; i <= REWARD_EPOCH_ID + 2; i++) {
            bytes memory newPolicy = _encodeSigningPolicy(
                i, _firstVotingRoundInEpoch(i), THRESHOLD,
                bytes32(uint256(i * 111)), voterAddrs, SINGLE_WEIGHT
            );
            bytes memory cd = _buildRelayNewPolicyCalldata(lastPolicy, newPolicy, N / 2 + 1);
            (bool s, ) = address(relay).call(cd);
            assertTrue(s);
            lastPolicy = newPolicy;
        }

        IRelay.FeeConfig[] memory feeConfigs = new IRelay.FeeConfig[](1);
        feeConfigs[0] = IRelay.FeeConfig({protocolId: 5, feeInWei: 2000});
        IRelay.RelayGovernanceConfig memory config = IRelay.RelayGovernanceConfig({
            descriptionHash: keccak256("RelayGovernance"),
            chainId: block.chainid,
            newFeeConfigs: feeConfigs
        });
        bytes32 configHash = keccak256(abi.encode(config));

        // Use original epoch 1 policy — now too old (epoch 3 - 1 = 2 != 1)
        bytes memory relayCalldata = _buildRelayCalldata(
            signingPolicyEncoded, 1, 0, false, configHash, N / 2 + 1
        );
        vm.expectRevert("too old signing policy");
        relay.governanceFeeSetup(relayCalldata, config);
    }

    // ── Multiple signing policies and message too old ────────────────────────

    function testRevertRelayMessageTooOld() public {
        // Deploy a fresh relay for this test
        IRelay.FeeConfig[] memory feeConfigs = new IRelay.FeeConfig[](0);
        IRelay.RelayInitialConfig memory cfg = IRelay.RelayInitialConfig({
            initialRewardEpochId: REWARD_EPOCH_ID,
            startingVotingRoundIdForInitialRewardEpochId: _firstVotingRoundInEpoch(REWARD_EPOCH_ID),
            initialSigningPolicyHash: signingPolicyHash,
            randomNumberProtocolId: RANDOM_NUMBER_PROTOCOL_ID,
            firstVotingRoundStartTs: FIRST_VOTING_ROUND_START_TS,
            votingEpochDurationSeconds: VOTING_EPOCH_DURATION_SEC,
            firstRewardEpochStartVotingRoundId: FIRST_REWARD_EPOCH_VOTING_ROUND_ID,
            rewardEpochDurationInVotingEpochs: REWARD_EPOCH_DURATION,
            thresholdIncreaseBIPS: THRESHOLD_INCREASE_BIPS,
            messageFinalizationWindowInRewardEpochs: MSG_FINALIZATION_WINDOW,
            feeCollectionAddress: payable(address(0)),
            feeConfigs: feeConfigs
        });
        Relay relay2 = new Relay(cfg, address(0), IRelay(address(0)));

        // Relay signing policies up to epoch REWARD_EPOCH_ID + MSG_FINALIZATION_WINDOW + 2
        bytes memory lastPolicy = signingPolicyEncoded;
        for (uint24 i = REWARD_EPOCH_ID + 1;
             i <= REWARD_EPOCH_ID + MSG_FINALIZATION_WINDOW + 2; i++)
        {
            bytes memory newPolicy = _encodeSigningPolicy(
                i, _firstVotingRoundInEpoch(i), THRESHOLD,
                bytes32(uint256(i * 111)), voterAddrs, SINGLE_WEIGHT
            );
            bytes memory cd = _buildRelayNewPolicyCalldata(lastPolicy, newPolicy, N / 2 + 1);
            (bool s, ) = address(relay2).call(cd);
            assertTrue(s);
            lastPolicy = newPolicy;
        }

        // Try to relay a message from the original epoch using original policy
        bytes memory callData = _buildRelayCalldata(
            signingPolicyEncoded,
            RANDOM_NUMBER_PROTOCOL_ID,
            VOTING_ROUND_ID + 1,
            true,
            keccak256("tooOldRoot"),
            N / 2 + 1
        );
        (bool success, bytes memory retData) = address(relay2).call(callData);
        assertFalse(success);
        _assertRevertMsg(retData, "Message too old");
    }

    // ── Old relay constructor compatibility tests ─────────────────────────────

    function _makeDefaultConfig(
        IRelay.FeeConfig[] memory feeConfigs
    ) internal view returns (IRelay.RelayInitialConfig memory) {
        return IRelay.RelayInitialConfig({
            initialRewardEpochId: REWARD_EPOCH_ID,
            startingVotingRoundIdForInitialRewardEpochId: _firstVotingRoundInEpoch(REWARD_EPOCH_ID),
            initialSigningPolicyHash: signingPolicyHash,
            randomNumberProtocolId: RANDOM_NUMBER_PROTOCOL_ID,
            firstVotingRoundStartTs: FIRST_VOTING_ROUND_START_TS,
            votingEpochDurationSeconds: VOTING_EPOCH_DURATION_SEC,
            firstRewardEpochStartVotingRoundId: FIRST_REWARD_EPOCH_VOTING_ROUND_ID,
            rewardEpochDurationInVotingEpochs: REWARD_EPOCH_DURATION,
            thresholdIncreaseBIPS: THRESHOLD_INCREASE_BIPS,
            messageFinalizationWindowInRewardEpochs: MSG_FINALIZATION_WINDOW,
            feeCollectionAddress: payable(address(0)),
            feeConfigs: feeConfigs
        });
    }

    function testRevertConstructorOldRelayIncompatibleNoSetterToSetter() public {
        // relay1 has no setter
        IRelay.FeeConfig[] memory feeConfigs = new IRelay.FeeConfig[](0);
        IRelay.RelayInitialConfig memory cfg = _makeDefaultConfig(feeConfigs);
        Relay relay1 = new Relay(cfg, address(0), IRelay(address(0)));

        // relay2 has setter but oldRelay has no setter → incompatible
        vm.expectRevert("old relay incompatible");
        new Relay(cfg, address(this), IRelay(address(relay1)));
    }

    function testRevertConstructorOldRelayIncompatibleSetterToNoSetter() public {
        // relay1 has setter
        IRelay.FeeConfig[] memory feeConfigs = new IRelay.FeeConfig[](0);
        IRelay.RelayInitialConfig memory cfg = _makeDefaultConfig(feeConfigs);
        Relay relay1 = new Relay(cfg, address(this), IRelay(address(0)));

        // relay2 has no setter but oldRelay has setter → incompatible
        vm.expectRevert("old relay incompatible");
        new Relay(cfg, address(0), IRelay(address(relay1)));
    }

    function testRevertConstructorOldRelayWrongStartTs() public {
        IRelay.FeeConfig[] memory feeConfigs = new IRelay.FeeConfig[](0);
        IRelay.RelayInitialConfig memory cfg = _makeDefaultConfig(feeConfigs);
        Relay relay1 = new Relay(cfg, address(this), IRelay(address(0)));

        IRelay.RelayInitialConfig memory cfg2 = _makeDefaultConfig(feeConfigs);
        cfg2.firstVotingRoundStartTs = FIRST_VOTING_ROUND_START_TS + 1;

        vm.expectRevert("wrong start ts");
        new Relay(cfg2, address(this), IRelay(address(relay1)));
    }

    function testRevertConstructorOldRelayWrongRewardEpochDuration() public {
        IRelay.FeeConfig[] memory feeConfigs = new IRelay.FeeConfig[](0);
        IRelay.RelayInitialConfig memory cfg = _makeDefaultConfig(feeConfigs);
        Relay relay1 = new Relay(cfg, address(this), IRelay(address(0)));

        IRelay.RelayInitialConfig memory cfg2 = _makeDefaultConfig(feeConfigs);
        cfg2.rewardEpochDurationInVotingEpochs = REWARD_EPOCH_DURATION + 1;
        // Bump startingVotingRoundId to satisfy the "invalid initial starting voting round id" check
        cfg2.startingVotingRoundIdForInitialRewardEpochId =
            cfg2.firstRewardEpochStartVotingRoundId +
            cfg2.initialRewardEpochId * cfg2.rewardEpochDurationInVotingEpochs;

        vm.expectRevert("wrong reward epoch duration");
        new Relay(cfg2, address(this), IRelay(address(relay1)));
    }

    function testRevertConstructorOldRelayWrongFirstRewardEpochStart() public {
        IRelay.FeeConfig[] memory feeConfigs = new IRelay.FeeConfig[](0);
        IRelay.RelayInitialConfig memory cfg = _makeDefaultConfig(feeConfigs);
        Relay relay1 = new Relay(cfg, address(this), IRelay(address(0)));

        IRelay.RelayInitialConfig memory cfg2 = _makeDefaultConfig(feeConfigs);
        cfg2.firstRewardEpochStartVotingRoundId = FIRST_REWARD_EPOCH_VOTING_ROUND_ID + 1;
        // Bump startingVotingRoundId to satisfy the "invalid initial starting voting round id" check
        cfg2.startingVotingRoundIdForInitialRewardEpochId =
            cfg2.firstRewardEpochStartVotingRoundId +
            cfg2.initialRewardEpochId * cfg2.rewardEpochDurationInVotingEpochs;

        vm.expectRevert("wrong first reward epoch start");
        new Relay(cfg2, address(this), IRelay(address(relay1)));
    }

    function testRevertConstructorOldRelayWrongVotingEpochDuration() public {
        IRelay.FeeConfig[] memory feeConfigs = new IRelay.FeeConfig[](0);
        IRelay.RelayInitialConfig memory cfg = _makeDefaultConfig(feeConfigs);
        Relay relay1 = new Relay(cfg, address(this), IRelay(address(0)));

        IRelay.RelayInitialConfig memory cfg2 = _makeDefaultConfig(feeConfigs);
        cfg2.votingEpochDurationSeconds = VOTING_EPOCH_DURATION_SEC + 1;

        vm.expectRevert("wrong voting epoch duration");
        new Relay(cfg2, address(this), IRelay(address(relay1)));
    }

    function testRevertConstructorOldRelayInvalidInitialStartingVotingRoundId() public {
        // Deploy relay1 with setter
        IRelay.FeeConfig[] memory feeConfigs = new IRelay.FeeConfig[](0);
        IRelay.RelayInitialConfig memory cfg = _makeDefaultConfig(feeConfigs);
        Relay relay1 = new Relay(cfg, address(this), IRelay(address(0)));

        // relay2 with oldRelay but invalid startingVotingRoundIdForInitialRewardEpochId
        // The check: firstRewardEpochStartVotingRoundId + initialRewardEpochId * rewardEpochDurationInVotingEpochs
        //            <= startingVotingRoundIdForInitialRewardEpochId
        // So set startingVotingRoundIdForInitialRewardEpochId too low
        IRelay.RelayInitialConfig memory cfg2 = _makeDefaultConfig(feeConfigs);
        cfg2.startingVotingRoundIdForInitialRewardEpochId = 0;

        vm.expectRevert("invalid initial starting voting round id");
        new Relay(cfg2, address(this), IRelay(address(relay1)));
    }

    function testConstructorOldRelayCompatible() public {
        // Both relays with setter → compatible
        IRelay.FeeConfig[] memory feeConfigs = new IRelay.FeeConfig[](0);
        IRelay.RelayInitialConfig memory cfg = _makeDefaultConfig(feeConfigs);
        Relay relay1 = new Relay(cfg, address(this), IRelay(address(0)));

        // This should succeed
        Relay relay2 = new Relay(cfg, address(this), IRelay(address(relay1)));
        assertTrue(address(relay2) != address(0));
    }

    // ── Forged signature tests ──────────────────────────────────────────────

    function _buildForgedSignatureCalldata(
        bytes memory _signingPolicy,
        uint8 _protocolId,
        uint32 _votingRoundId,
        bool _isSecureRandom,
        bytes32 _merkleRoot,
        uint256 _sigCount,
        bool _useCorrectAddress
    ) internal view returns (bytes memory) {
        bytes memory message = _encodeProtocolMessage(
            _protocolId, _votingRoundId, _isSecureRandom, _merkleRoot
        );

        // Build forged signatures
        bytes memory sigs = abi.encodePacked(uint16(_sigCount));
        for (uint256 i = 0; i < _sigCount; i++) {
            address addrForR = _useCorrectAddress
                ? voterAddrs[i]
                : address(uint160(0xdeadbeef));
            sigs = abi.encodePacked(
                sigs,
                uint8(0),                              // v = 0 (invalid)
                bytes32(uint256(uint160(addrForR))),    // r = left-padded address
                bytes32(uint256(1)),                    // s = 1
                uint16(i)                               // index
            );
        }

        return abi.encodePacked(
            bytes4(keccak256("relay()")),
            _signingPolicy,
            message,
            sigs
        );
    }

    function testRevertForgedSignaturesRandomProtocol() public {
        bytes32 merkleRoot = keccak256("forgedRoot");
        bytes memory callData = _buildForgedSignatureCalldata(
            signingPolicyEncoded,
            RANDOM_NUMBER_PROTOCOL_ID,
            VOTING_ROUND_ID,
            true,
            merkleRoot,
            N / 2 + 1,
            true // use correct voter addresses in r
        );

        (bool success, bytes memory retData) = address(relay).call(callData);
        assertFalse(success);
        _assertRevertMsg(retData, "ecrecover returned bad data");
    }

    function testRevertForgedSignaturesNonRandomProtocol() public {
        bytes32 merkleRoot = keccak256("forgedRoot2");
        uint8 protocolId = 3;
        bytes memory callData = _buildForgedSignatureCalldata(
            signingPolicyEncoded,
            protocolId,
            VOTING_ROUND_ID,
            false,
            merkleRoot,
            N / 2 + 1,
            true // use correct voter addresses in r
        );

        (bool success, bytes memory retData) = address(relay).call(callData);
        assertFalse(success);
        _assertRevertMsg(retData, "ecrecover returned bad data");
    }

    function testRevertForgedSignaturesWrongAddress() public {
        bytes32 merkleRoot = keccak256("forgedRoot3");
        bytes memory callData = _buildForgedSignatureCalldata(
            signingPolicyEncoded,
            RANDOM_NUMBER_PROTOCOL_ID,
            VOTING_ROUND_ID,
            true,
            merkleRoot,
            N / 2 + 1,
            false // use wrong address in r
        );

        (bool success, bytes memory retData) = address(relay).call(callData);
        assertFalse(success);
        _assertRevertMsg(retData, "ecrecover returned bad data");
    }

    // ══════════════════════════════════════════════════════════════════════════
    // ── Helper functions ─────────────────────────────────────────────────────
    // ══════════════════════════════════════════════════════════════════════════

    /// @dev Assert ProtocolMessageRelayed event was emitted in recorded logs.
    function _assertProtocolMessageRelayed(
        uint8 _protocolId,
        uint32 _votingRoundId,
        bool _isSecureRandom,
        bytes32 _merkleRoot
    ) internal {
        bytes32 eventSig = keccak256(
            "ProtocolMessageRelayed(uint8,uint32,bool,bytes32)"
        );
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bool found = false;
        for (uint256 i = 0; i < entries.length; i++) {
            if (
                entries[i].topics.length > 0 &&
                entries[i].topics[0] == eventSig
            ) {
                assertEq(
                    entries[i].topics[1],
                    bytes32(uint256(_protocolId))
                );
                assertEq(
                    entries[i].topics[2],
                    bytes32(uint256(_votingRoundId))
                );
                (bool secure, bytes32 root) = abi.decode(
                    entries[i].data, (bool, bytes32)
                );
                assertEq(secure, _isSecureRandom);
                assertEq(root, _merkleRoot);
                found = true;
                break;
            }
        }
        assertTrue(found, "ProtocolMessageRelayed not emitted");
    }

    /// @dev Assert SigningPolicyRelayed event was emitted in recorded logs.
    function _assertSigningPolicyRelayed(uint256 _rewardEpochId) internal {
        bytes32 eventSig = keccak256(
            "SigningPolicyRelayed(uint256)"
        );
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bool found = false;
        for (uint256 i = 0; i < entries.length; i++) {
            if (
                entries[i].topics.length > 0 &&
                entries[i].topics[0] == eventSig
            ) {
                assertEq(
                    entries[i].topics[1],
                    bytes32(_rewardEpochId)
                );
                found = true;
                break;
            }
        }
        assertTrue(found, "SigningPolicyRelayed not emitted");
    }

    // ── internal view helpers ───────────────────────────────────────────────

    /// @dev Sign a message hash and encode signatures with sequential indices.
    function _signSequential(
        bytes32 _prefixedHash,
        uint256 _count
    ) internal view returns (bytes memory) {
        bytes memory result = abi.encodePacked(uint16(_count));
        for (uint256 i = 0; i < _count; i++) {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(voterPKs[i], _prefixedHash);
            result = abi.encodePacked(result, v, r, s, uint16(i));
        }
        return result;
    }

    /// @dev Sign with specific indices (for testing out-of-order etc.)
    function _signWithIndices(
        bytes32 _prefixedHash,
        uint256[] memory _indices
    ) internal view returns (bytes memory) {
        bytes memory result = abi.encodePacked(uint16(_indices.length));
        for (uint256 i = 0; i < _indices.length; i++) {
            uint256 idx = _indices[i];
            uint256 pk = idx < N ? voterPKs[idx] : voterPKs[0]; // fallback for OOB
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, _prefixedHash);
            result = abi.encodePacked(result, v, r, s, uint16(idx));
        }
        return result;
    }

    /// @dev Sign with custom voter arrays (for new signing policy testing).
    function _signSequentialWithKeys(
        bytes32 _prefixedHash,
        uint256 _count,
        uint256[] memory _pks
    ) internal view returns (bytes memory) {
        bytes memory result = abi.encodePacked(uint16(_count));
        for (uint256 i = 0; i < _count; i++) {
            (uint8 v, bytes32 r, bytes32 s) = _vmSign(_pks[i], _prefixedHash);
            result = abi.encodePacked(result, v, r, s, uint16(i));
        }
        return result;
    }

    /// @dev Wrapper for vm.sign.
    function _vmSign(uint256 _pk, bytes32 _hash) internal view returns (uint8, bytes32, bytes32) {
        return vm.sign(_pk, _hash);
    }

    /// @dev Build full relay calldata for a protocol message.
    function _buildRelayCalldata(
        bytes memory _signingPolicy,
        uint8 _protocolId,
        uint32 _votingRoundId,
        bool _isSecureRandom,
        bytes32 _merkleRoot,
        uint256 _sigCount
    ) internal view returns (bytes memory) {
        bytes memory message = _encodeProtocolMessage(
            _protocolId, _votingRoundId, _isSecureRandom, _merkleRoot
        );
        bytes32 prefixedHash = _hashProtocolMessage(message);
        bytes memory sigs = _signSequential(prefixedHash, _sigCount);

        return abi.encodePacked(
            bytes4(keccak256("relay()")),
            _signingPolicy,
            message,
            sigs
        );
    }

    /// @dev Build full relay calldata using custom keys for a protocol message.
    function _buildRelayCalldataWithKeys(
        bytes memory _signingPolicy,
        uint8 _protocolId,
        uint32 _votingRoundId,
        bool _isSecureRandom,
        bytes32 _merkleRoot,
        uint256 _sigCount,
        address[] memory,
        uint256[] memory _pks
    ) internal view returns (bytes memory) {
        bytes memory message = _encodeProtocolMessage(
            _protocolId, _votingRoundId, _isSecureRandom, _merkleRoot
        );
        bytes32 prefixedHash = _hashProtocolMessage(message);

        bytes memory sigs = abi.encodePacked(uint16(_sigCount));
        for (uint256 i = 0; i < _sigCount; i++) {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(_pks[i], prefixedHash);
            sigs = abi.encodePacked(sigs, v, r, s, uint16(i));
        }

        return abi.encodePacked(
            bytes4(keccak256("relay()")),
            _signingPolicy,
            message,
            sigs
        );
    }

    /// @dev Build relay calldata for relaying a new signing policy.
    function _buildRelayNewPolicyCalldata(
        bytes memory _currentPolicy,
        bytes memory _newPolicy,
        uint256 _sigCount
    ) internal view returns (bytes memory) {
        bytes32 newPolicyHash = _hashEncodedSigningPolicy(_newPolicy);
        bytes32 prefixedHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", newPolicyHash)
        );
        bytes memory sigs = _signSequential(prefixedHash, _sigCount);

        return abi.encodePacked(
            bytes4(keccak256("relay()")),
            _currentPolicy,
            uint8(0), // protocolId = 0 means new signing policy
            _newPolicy,
            sigs
        );
    }

    // ── internal pure helpers ───────────────────────────────────────────────

    function _firstVotingRoundInEpoch(uint256 _epochId) internal pure returns (uint32) {
        return uint32(
            FIRST_REWARD_EPOCH_VOTING_ROUND_ID +
            REWARD_EPOCH_DURATION * _epochId
        );
    }

    /// @dev Encode a signing policy into raw bytes matching the TS format.
    function _encodeSigningPolicy(
        uint24 _rewardEpochId,
        uint32 _startVotingRoundId,
        uint16 _threshold,
        bytes32 _seed,
        address[] memory _voters,
        uint16 _weight
    ) internal pure returns (bytes memory) {
        uint16 numVoters = uint16(_voters.length);
        bytes memory result = abi.encodePacked(
            numVoters,
            _rewardEpochId,
            _startVotingRoundId,
            _threshold,
            _seed
        );
        for (uint256 i = 0; i < _voters.length; i++) {
            result = abi.encodePacked(result, _voters[i], _weight);
        }
        return result;
    }

    /// @dev Hash an encoded signing policy the same way the Relay contract does:
    ///      split into 32-byte chunks, sequential keccak256 hashing.
    function _hashEncodedSigningPolicy(
        bytes memory _policy
    ) internal pure returns (bytes32) {
        require(_policy.length >= 64, "policy too short");

        bytes32 chunk0 = _readBytes32(_policy, 0);
        bytes32 chunk1 = _readBytes32(_policy, 32);
        bytes32 hash = keccak256(abi.encodePacked(chunk0, chunk1));

        uint256 offset = 64;
        while (offset < _policy.length) {
            bytes32 chunk = _readBytes32(_policy, offset);
            if (offset + 32 > _policy.length) {
                uint256 validBytes = _policy.length - offset;
                uint256 mask = ~(type(uint256).max >> (validBytes * 8));
                chunk = bytes32(uint256(chunk) & mask);
            }
            hash = keccak256(abi.encodePacked(hash, chunk));
            offset += 32;
        }
        return hash;
    }

    /// @dev Read 32 bytes from a bytes array at a given offset.
    function _readBytes32(
        bytes memory _data,
        uint256 _offset
    ) internal pure returns (bytes32 result) {
        // solhint-disable-next-line no-inline-assembly
        assembly { result := mload(add(add(_data, 32), _offset)) }
    }

    /// @dev Encode a protocol message merkle root (38 bytes).
    function _encodeProtocolMessage(
        uint8 _protocolId,
        uint32 _votingRoundId,
        bool _isSecureRandom,
        bytes32 _merkleRoot
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(
            _protocolId,
            _votingRoundId,
            _isSecureRandom ? bytes1(0x01) : bytes1(0x00),
            _merkleRoot
        );
    }

    /// @dev Hash a protocol message with Ethereum signed message prefix.
    function _hashProtocolMessage(bytes memory _message) internal pure returns (bytes32) {
        bytes32 rawHash = keccak256(_message);
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", rawHash));
    }

    /// @dev Create uniform weights array.
    function _uniformWeights(uint256 _n, uint16 _weight) internal pure returns (uint16[] memory) {
        uint16[] memory weights = new uint16[](_n);
        for (uint256 i = 0; i < _n; i++) {
            weights[i] = _weight;
        }
        return weights;
    }

    /// @dev Sorted hash for merkle tree (matches OpenZeppelin's MerkleProof).
    function _sortedHash(bytes32 _a, bytes32 _b) internal pure returns (bytes32) {
        if (_a < _b) {
            return keccak256(abi.encodePacked(_a, _b));
        } else {
            return keccak256(abi.encodePacked(_b, _a));
        }
    }

    /// @dev Extract revert message from low-level call return data.
    function _assertRevertMsg(
        bytes memory _retData,
        string memory _expected
    ) internal pure {
        require(_retData.length >= 68, "no revert message");
        bytes memory payload = new bytes(_retData.length - 4);
        for (uint256 i = 4; i < _retData.length; i++) {
            payload[i - 4] = _retData[i];
        }
        string memory msg_ = abi.decode(payload, (string));
        assertEq(msg_, _expected);
    }
}
