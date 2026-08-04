// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// solhint-disable func-name-mixedcase

import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { Relay } from "../../../../contracts/protocol/implementation/Relay.sol";
import { RelayProxy } from "../../../../contracts/protocol/implementation/RelayProxy.sol";
import { ISafeGovernance } from "../../../../contracts/userInterfaces/ISafeGovernance.sol";
import { SafeGovernance } from "../../../../contracts/governance/lib/SafeGovernance.sol";
// solhint-disable-next-line no-unused-import
import { deployRelay, testGovernanceConfig, RELAY_TEST_GOVERNANCE } from "../../../utils/RelayDeploy.sol";
import { IRelay } from "../../../../contracts/userInterfaces/IRelay.sol";
import { IIRelay } from "../../../../contracts/protocol/interface/IIRelay.sol";

/**
 * Foundry harness + tests for Relay.sol.
 *
 * Reusable base that reconstructs the custom relay() calldata layout in Solidity:
 *  - signing policy encoding (43 + n*22 bytes) and its chunked hash (mirrors calculateSigningPolicyHash),
 *  - 38-byte protocol message,
 *  - EIP-191 prefixed message hash,
 *  - 67-byte (v,r,s,index) signatures with a 2-byte count prefix.
 *
 * This base is intended to be reused by later fixes (e.g. RLY-03 random redesign) and as the
 * substrate for formal verification (Halmos/Kontrol).
 */
contract RelayTestBase is Test {
    // ---- signing-policy parameters ----
    uint256 internal constant N = 5;
    uint16 internal constant WEIGHT = 100;          // per-voter weight
    uint16 internal constant THRESHOLD = 260;       // > 50% and < 66% of total (500)
    uint24 internal constant REWARD_EPOCH_ID = 1;
    uint32 internal constant START_VOTING_ROUND_ID = 3360;
    uint256 internal constant SEED = 0x1234;

    // ---- relay config ----
    uint8 internal constant RANDOM_PROTOCOL_ID = 2;
    uint32 internal constant FIRST_VOTING_ROUND_TS = 1_700_000_000;
    uint8 internal constant VOTING_EPOCH_DURATION = 90;
    uint32 internal constant FIRST_REWARD_EPOCH_START_VOTING_ROUND_ID = 0;
    uint16 internal constant REWARD_EPOCH_DURATION = 3360;
    uint16 internal constant THRESHOLD_INCREASE_BIPS = 12000;
    uint32 internal constant MESSAGE_FINALIZATION_WINDOW = 5;

    Relay internal relay;
    address internal feeCollection = address(0xFEE);

    // voters sorted ascending by address, with aligned private keys/weights
    uint256[] internal pks;
    address[] internal voters;
    uint16[] internal weights;

    function setUp() public virtual {
        _setupVoters();
        bytes memory policy = _buildSigningPolicy(REWARD_EPOCH_ID, START_VOTING_ROUND_ID, THRESHOLD, SEED);

        IRelay.RelayInitialConfig memory cfg = _initialConfig(_signingPolicyHash(policy));
        relay = deployRelay(cfg, address(0), IRelay(address(0)));
    }

    function _initialConfig(bytes32 spHash) internal view returns (IRelay.RelayInitialConfig memory cfg) {
        cfg.initialRewardEpochId = uint32(REWARD_EPOCH_ID);
        cfg.startingVotingRoundIdForInitialRewardEpochId = START_VOTING_ROUND_ID;
        cfg.initialSigningPolicyHash = spHash;
        cfg.randomNumberProtocolId = RANDOM_PROTOCOL_ID;
        cfg.firstVotingRoundStartTs = FIRST_VOTING_ROUND_TS;
        cfg.votingEpochDurationSeconds = VOTING_EPOCH_DURATION;
        cfg.firstRewardEpochStartVotingRoundId = FIRST_REWARD_EPOCH_START_VOTING_ROUND_ID;
        cfg.rewardEpochDurationInVotingEpochs = REWARD_EPOCH_DURATION;
        cfg.thresholdIncreaseBIPS = THRESHOLD_INCREASE_BIPS;
        cfg.messageFinalizationWindowInRewardEpochs = MESSAGE_FINALIZATION_WINDOW;
        cfg.feeCollectionAddress = payable(feeCollection);
        // Safe governance is mandatory on every deployment (and the source must be explicit),
        // so the default fixture carries the inert placeholder block.
        cfg.governance = testGovernanceConfig(block.chainid);
        // cfg.feeConfigs left empty
    }

    function _setupVoters() internal {
        // deterministic keys 1..N, then sort (pk, addr) by ascending address
        uint256[] memory p = new uint256[](N);
        address[] memory a = new address[](N);
        for (uint256 i = 0; i < N; i++) {
            p[i] = i + 1;
            a[i] = vm.addr(p[i]);
        }
        for (uint256 i = 1; i < N; i++) {
            uint256 kp = p[i];
            address ka = a[i];
            uint256 j = i;
            while (j > 0 && a[j - 1] > ka) {
                a[j] = a[j - 1];
                p[j] = p[j - 1];
                j--;
            }
            a[j] = ka;
            p[j] = kp;
        }
        for (uint256 i = 0; i < N; i++) {
            pks.push(p[i]);
            voters.push(a[i]);
            weights.push(WEIGHT);
        }
    }

    // ---- encoding helpers ----

    function _buildSigningPolicy(uint24 rewardEpochId, uint32 startVotingRoundId, uint16 threshold, uint256 seed)
        internal view returns (bytes memory p)
    {
        p = abi.encodePacked(uint16(voters.length), rewardEpochId, startVotingRoundId, threshold, bytes32(seed));
        for (uint256 i = 0; i < voters.length; i++) {
            p = abi.encodePacked(p, voters[i], weights[i]);
        }
    }

    // RLY-23: chain-domain binding — keccak256(chainid ‖ hash); mirrors the wrap the contract
    // applies to both stored signing-policy hashes and signed message digests.
    function _chainBound(bytes32 h) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(block.chainid, h));
    }

    // Mirrors Relay.calculateSigningPolicyHash: h = policy[0:32], fold each subsequent 32-byte
    // chunk (h = keccak(h || chunk)); fold the final partial chunk zero-padded on the right;
    // RLY-23: then bind to this chain (keccak(chainid ‖ contentHash)).
    function _signingPolicyHash(bytes memory p) internal view returns (bytes32 h) {
        h = _chainBound(_signingPolicyContentHash(p));
    }

    // The pre-RLY-23 content hash (the chunked keccak fold alone, no chain binding).
    function _signingPolicyContentHash(bytes memory p) internal pure returns (bytes32 h) {
        uint256 L = p.length;
        uint256 full = (L / 32) * 32;
        assembly { h := mload(add(p, 0x20)) }
        for (uint256 pos = 32; pos < full; pos += 32) {
            bytes32 chunk;
            assembly { chunk := mload(add(add(p, 0x20), pos)) }
            h = keccak256(abi.encodePacked(h, chunk));
        }
        uint256 rem = L - full;
        if (rem > 0) {
            bytes32 chunk;
            assembly { chunk := mload(add(add(p, 0x20), full)) }
            uint256 shiftBits = (32 - rem) * 8;
            chunk = bytes32((uint256(chunk) >> shiftBits) << shiftBits);
            h = keccak256(abi.encodePacked(h, chunk));
        }
    }

    function _protocolMessage(uint8 protocolId, uint32 votingRoundId, bool isSecureRandom, bytes32 merkleRoot)
        internal pure returns (bytes memory)
    {
        return abi.encodePacked(protocolId, votingRoundId, isSecureRandom ? uint8(1) : uint8(0), merkleRoot);
    }

    // RLY-23: what voters sign for a protocol message is prefixed(keccak(chainid ‖ keccak(message))).
    function _ethSignedHash(bytes memory message) internal view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _chainBound(keccak256(message))));
    }

    // Sign with the voters at `indices` (must be strictly ascending); returns count(2) || (v,r,s,index)*.
    function _signatures(bytes32 signedHash, uint256[] memory indices) internal view returns (bytes memory sigs) {
        sigs = abi.encodePacked(uint16(indices.length));
        for (uint256 k = 0; k < indices.length; k++) {
            uint256 idx = indices[k];
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(pks[idx], signedHash);
            sigs = abi.encodePacked(sigs, v, r, s, uint16(idx));
        }
    }

    function _firstK(uint256 k) internal pure returns (uint256[] memory idx) {
        idx = new uint256[](k);
        for (uint256 i = 0; i < k; i++) idx[i] = i;
    }

    // Full relay() calldata for a custom-signature (protocolId == 1) message over `merkleRoot`.
    function _customSigRelayMessage(bytes memory policy, bytes32 merkleRoot, uint256 numSigners)
        internal view returns (bytes memory)
    {
        bytes memory message = _protocolMessage(1, 0, false, merkleRoot);
        bytes32 signedHash = _ethSignedHash(message);
        bytes memory sigs = _signatures(signedHash, _firstK(numSigners));
        return abi.encodePacked(Relay.relay.selector, policy, message, sigs);
    }

}

// RLY-03: true Merkle-proven random + monotonicity.
contract RelayRandomTest is RelayTestBase {
    bytes internal policy;

    function setUp() public override {
        super.setUp();
        policy = _buildSigningPolicy(REWARD_EPOCH_ID, START_VOTING_ROUND_ID, THRESHOLD, SEED);
    }

    function _sortedPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }

    // leaf = keccak256(abi.encode(votingRoundId, value, isSecure)) — mirrors the contract.
    function _randomLeaf(uint32 vrid, uint256 value, bool isSecure) internal pure returns (bytes32) {
        return keccak256(abi.encode(uint256(vrid), value, uint256(isSecure ? 1 : 0)));
    }

    // 2-leaf tree [randomLeaf, sibling]; proof for the random leaf is [sibling].
    function _treeFor(uint32 vrid, uint256 value, bool isSecure) internal pure returns (bytes32 root, bytes32 sibling) {
        sibling = keccak256("sibling");
        root = _sortedPair(_randomLeaf(vrid, value, isSecure), sibling);
    }

    function _randomRelayMessage(uint32 vrid, uint256 value, bool isSecure, uint256 numSigners)
        internal view returns (bytes memory)
    {
        (bytes32 root, bytes32 sibling) = _treeFor(vrid, value, isSecure);
        bytes memory message = _protocolMessage(RANDOM_PROTOCOL_ID, vrid, isSecure, root);
        bytes memory sigs = _signatures(_ethSignedHash(message), _firstK(numSigners));
        bytes memory trailer = abi.encodePacked(value, sibling); // randomNumber(32) || proof(1 node)
        return abi.encodePacked(Relay.relay.selector, policy, message, sigs, trailer);
    }

    function test_random_happyPath_storesProvenValue() public {
        uint32 vrid = START_VOTING_ROUND_ID; // -> reward epoch 1
        uint256 value = 0xCAFE;
        (bool ok,) = address(relay).call(_randomRelayMessage(vrid, value, true, 3));
        assertTrue(ok, "relay failed");

        (uint256 rnd, bool sec,) = relay.getRandomNumber();
        assertEq(rnd, value, "getRandomNumber value");
        assertTrue(sec, "secure flag");

        (uint256 rndH, bool secH,) = relay.getRandomNumberHistorical(vrid);
        assertEq(rndH, value, "historical value");
        assertTrue(secH, "historical secure");
    }

    // Core RLY-03 fix: relaying a stale (older) round after a newer one must NOT regress the live pointer.
    function test_random_monotonicity_staleRoundDoesNotRegress() public {
        uint32 v1 = START_VOTING_ROUND_ID;       // older
        uint32 v2 = START_VOTING_ROUND_ID + 1;   // newer, same reward epoch

        (bool ok2,) = address(relay).call(_randomRelayMessage(v2, 0x2222, true, 3));
        assertTrue(ok2, "v2 relay failed");
        (bool ok1,) = address(relay).call(_randomRelayMessage(v1, 0x1111, true, 3));
        assertTrue(ok1, "v1 relay failed");

        // live "current" random stays at the newer round...
        (uint256 rnd,,) = relay.getRandomNumber();
        assertEq(rnd, 0x2222, "live pointer regressed to stale round");
        // ...but the older round is still stored for historical lookups
        (uint256 rndH,,) = relay.getRandomNumberHistorical(v1);
        assertEq(rndH, 0x1111, "historical not stored for stale round");
    }

    function test_random_invalidProof_reverts() public {
        uint32 vrid = START_VOTING_ROUND_ID;
        (bytes32 root, bytes32 sibling) = _treeFor(vrid, 0xAAAA, true);
        bytes memory message = _protocolMessage(RANDOM_PROTOCOL_ID, vrid, true, root);
        bytes memory sigs = _signatures(_ethSignedHash(message), _firstK(3));
        // trailer carries a value that does not hash into `root` -> proof must fail
        bytes memory trailer = abi.encodePacked(uint256(0xBBBB), sibling);
        bytes memory rm = abi.encodePacked(Relay.relay.selector, policy, message, sigs, trailer);
        (bool ok,) = address(relay).call(rm);
        assertFalse(ok, "invalid proof should revert");
    }

    function test_random_missingTrailer_reverts() public {
        uint32 vrid = START_VOTING_ROUND_ID;
        (bytes32 root,) = _treeFor(vrid, 0xAAAA, true);
        bytes memory message = _protocolMessage(RANDOM_PROTOCOL_ID, vrid, true, root);
        bytes memory sigs = _signatures(_ethSignedHash(message), _firstK(3));
        bytes memory rm = abi.encodePacked(Relay.relay.selector, policy, message, sigs); // no trailer
        (bool ok,) = address(relay).call(rm);
        assertFalse(ok, "missing trailer should revert");
    }

    // RLY-22: the hardcoded event-signature strings in relay() assembly must stay in sync with the ABI.
    function test_event_signatures_match_canonical() public {
        // ProtocolMessageRelayed (non-random protocol)
        bytes memory m1 = _protocolMessage(3, START_VOTING_ROUND_ID, false, keccak256("a"));
        vm.recordLogs();
        (bool ok1,) = address(relay).call(
            abi.encodePacked(Relay.relay.selector, policy, m1, _signatures(_ethSignedHash(m1), _firstK(3)))
        );
        assertTrue(ok1, "non-random relay failed");
        Vm.Log[] memory l1 = vm.getRecordedLogs();
        assertEq(
            l1[0].topics[0],
            keccak256("ProtocolMessageRelayed(uint8,uint32,bool,bytes32)"),
            "ProtocolMessageRelayed signature drift"
        );

        // RandomNumberRelayed (random protocol; emitted alongside ProtocolMessageRelayed)
        vm.recordLogs();
        (bool ok2,) = address(relay).call(_randomRelayMessage(START_VOTING_ROUND_ID + 1, 0x99, true, 3));
        assertTrue(ok2, "random relay failed");
        Vm.Log[] memory l2 = vm.getRecordedLogs();
        bytes32 rnrSig = keccak256("RandomNumberRelayed(uint32,uint256,bool)");
        bool found;
        for (uint256 k = 0; k < l2.length; k++) {
            if (l2[k].topics[0] == rnrSig) found = true;
        }
        assertTrue(found, "RandomNumberRelayed signature drift");
    }

    // L-1: a legitimately-relayed random value of 0 is returned, not mis-read as "absent".
    function test_random_zeroValue_isReturnedNotAbsent() public {
        uint32 vrid = START_VOTING_ROUND_ID;
        (bool ok,) = address(relay).call(_randomRelayMessage(vrid, 0, true, 3));
        assertTrue(ok, "zero-value random relay failed");
        (uint256 rndH,,) = relay.getRandomNumberHistorical(vrid);
        assertEq(rndH, 0, "zero random must be returned, not treated as absent");
        // an un-relayed round still reverts
        vm.expectRevert(IRelay.NoRandomNumber.selector);
        relay.getRandomNumberHistorical(vrid + 99);
    }

    // Coverage (High): random monotonicity ACROSS reward epochs (also exercises the threshold-increase branch).
    function test_random_monotonicity_acrossRewardEpochs() public {
        uint32 vEpoch2 = START_VOTING_ROUND_ID + REWARD_EPOCH_DURATION; // reward epoch 2
        uint32 vEpoch1 = START_VOTING_ROUND_ID + 1;                     // reward epoch 1 (older)
        // an epoch-2 message finalized by the epoch-1 policy needs the increased threshold (260*1.2=312 -> 4 signers)
        (bool ok2,) = address(relay).call(_randomRelayMessage(vEpoch2, 0xE2, true, 4));
        assertTrue(ok2, "epoch-2 random relay failed");
        (bool ok1,) = address(relay).call(_randomRelayMessage(vEpoch1, 0xE1, true, 3));
        assertTrue(ok1, "epoch-1 random relay failed");
        // the live pointer stays at the newer (epoch-2) round
        (uint256 rnd,,) = relay.getRandomNumber();
        assertEq(rnd, 0xE2, "live pointer regressed across reward epochs");
        (uint256 rndH,,) = relay.getRandomNumberHistorical(vEpoch1);
        assertEq(rndH, 0xE1, "older-epoch historical value not stored");
    }

    // Coverage (Med): a trailer whose length is not a multiple of 32 reverts ("Incorrect merkle proof").
    function test_random_malformedTrailerLength_reverts() public {
        uint32 vrid = START_VOTING_ROUND_ID;
        (bytes32 root, bytes32 sibling) = _treeFor(vrid, 0xAAAA, true);
        bytes memory message = _protocolMessage(RANDOM_PROTOCOL_ID, vrid, true, root);
        bytes memory sigs = _signatures(_ethSignedHash(message), _firstK(3));
        bytes memory trailer = abi.encodePacked(uint256(0xAAAA), sibling, bytes1(0x01)); // 65 bytes (not %32)
        (bool ok,) = address(relay).call(abi.encodePacked(Relay.relay.selector, policy, message, sigs, trailer));
        assertFalse(ok, "non-multiple-of-32 trailer should revert");
    }

    // Coverage (Med): a deep (multi-node) Merkle proof exercises the fold loop more than once.
    function test_random_deepMerkleProof() public {
        uint32 vrid = START_VOTING_ROUND_ID;
        uint256 value = 0xD;
        bytes32 leaf = _randomLeaf(vrid, value, true);
        bytes32 p01 = _sortedPair(leaf, keccak256("l1"));
        bytes32 p23 = _sortedPair(keccak256("l2"), keccak256("l3"));
        bytes32 root = _sortedPair(p01, p23);
        bytes memory message = _protocolMessage(RANDOM_PROTOCOL_ID, vrid, true, root);
        bytes memory sigs = _signatures(_ethSignedHash(message), _firstK(3));
        bytes memory trailer = abi.encodePacked(value, keccak256("l1"), p23); // value + 2-node proof
        (bool ok,) = address(relay).call(abi.encodePacked(Relay.relay.selector, policy, message, sigs, trailer));
        assertTrue(ok, "deep (2-node) merkle proof should verify");
        (uint256 rnd,,) = relay.getRandomNumber();
        assertEq(rnd, value);
    }

    // Coverage (Med): a message isSecure byte != {0,1} is normalized to 1 (RLY-14); the leaf uses 1.
    function test_random_isSecureNormalization() public {
        uint32 vrid = START_VOTING_ROUND_ID;
        uint256 value = 0x5;
        bytes32 leaf = _randomLeaf(vrid, value, true); // leaf uses isSecure = 1
        bytes32 sibling = keccak256("sibling");
        bytes32 root = _sortedPair(leaf, sibling);
        bytes memory message = abi.encodePacked(RANDOM_PROTOCOL_ID, vrid, uint8(2), root); // isSecure byte = 2
        bytes memory sigs = _signatures(_ethSignedHash(message), _firstK(3));
        bytes memory trailer = abi.encodePacked(value, sibling);
        (bool ok,) = address(relay).call(abi.encodePacked(Relay.relay.selector, policy, message, sigs, trailer));
        assertTrue(ok, "isSecure byte 2 should normalize to 1 and verify");
        (uint256 rnd, bool sec,) = relay.getRandomNumber();
        assertEq(rnd, value);
        assertTrue(sec, "isSecure must be normalized to true");
    }

    // bubbles the inner relay() revert data so vm.expectRevert can match the exact reason
    function relayRaw(bytes calldata rm) external {
        (bool ok, bytes memory ret) = address(relay).call(rm);
        if (!ok) {
            assembly { revert(add(ret, 0x20), mload(ret)) }
        }
    }

    // Coverage (Med): a trailer shorter than the 32-byte random word hits the distinct "No random number"
    // guard (calldatasize < proofStart+32), separate from the non-multiple-of-32 "Incorrect merkle proof".
    function test_random_shortTrailer_revertsNoRandomNumber() public {
        uint32 vrid = START_VOTING_ROUND_ID;
        (bytes32 root,) = _treeFor(vrid, 0xAAAA, true);
        bytes memory message = _protocolMessage(RANDOM_PROTOCOL_ID, vrid, true, root);
        bytes memory sigs = _signatures(_ethSignedHash(message), _firstK(3));
        bytes memory trailer = new bytes(16); // < 32: partial random-number word
        bytes memory rm = abi.encodePacked(Relay.relay.selector, policy, message, sigs, trailer);
        vm.expectRevert(IRelay.NoRandomNumber.selector);
        this.relayRaw(rm);
    }
}

// RLY-01: verify() must reject an uninitialized (zero) Merkle root.
contract RelayVerifyTest is RelayTestBase {
    bytes internal policy;

    function setUp() public override {
        super.setUp();
        policy = _buildSigningPolicy(REWARD_EPOCH_ID, START_VOTING_ROUND_ID, THRESHOLD, SEED);
    }

    function _sortedPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }

    // finalize a (protocolId, votingRoundId) root via a non-random Mode-2 relay (no trailer)
    function _relayNonRandom(uint8 protocolId, uint32 vrid, bytes32 root, uint256 numSigners) internal {
        bytes memory message = _protocolMessage(protocolId, vrid, false, root);
        bytes memory sigs = _signatures(_ethSignedHash(message), _firstK(numSigners));
        bytes memory rm = abi.encodePacked(Relay.relay.selector, policy, message, sigs);
        (bool ok,) = address(relay).call(rm);
        require(ok, "relay failed");
    }

    function test_verify_unfinalizedZeroRoot_reverts() public {
        // protocol 3 / round START not relayed -> stored root is zero; a zero leaf + empty proof must revert
        vm.expectRevert(IRelay.NotFinalized.selector);
        relay.verify(3, START_VOTING_ROUND_ID, bytes32(0), new bytes32[](0));
    }

    function test_verify_finalizedRoot_passes() public {
        uint8 pid = 3; // non-random, > 1
        uint32 vrid = START_VOTING_ROUND_ID;
        bytes32 leaf = keccak256("claim-leaf");
        bytes32 sibling = keccak256("sibling");
        _relayNonRandom(pid, vrid, _sortedPair(leaf, sibling), 3);
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = sibling;
        assertTrue(relay.verify(pid, vrid, leaf, proof), "valid proof against finalized root should pass");
    }

    // RLY-13: oldRelay fallback must fail closed if oldRelay.verify returns false (fee already forwarded).
    function _deployWithOldRelay(bool oldReturns) internal returns (Relay r) {
        MockOldRelay mock = new MockOldRelay(
            oldReturns, FIRST_VOTING_ROUND_TS, VOTING_EPOCH_DURATION,
            FIRST_REWARD_EPOCH_START_VOTING_ROUND_ID, REWARD_EPOCH_DURATION, 0
        );
        r = deployRelay(_initialConfig(_signingPolicyHash(policy)), address(0), IRelay(address(mock)));
    }

    function test_verify_oldRelayFallback_revertsOnFalse() public {
        Relay r = _deployWithOldRelay(false);
        // votingRoundId < startingVotingRoundIdForInitialRewardEpochId routes to the oldRelay fallback
        vm.expectRevert(IRelay.OldRelayVerificationFailed.selector);
        r.verify(3, 100, keccak256("x"), new bytes32[](0));
    }

    function test_verify_oldRelayFallback_passesOnTrue() public {
        Relay r = _deployWithOldRelay(true);
        assertTrue(r.verify(3, 100, keccak256("x"), new bytes32[](0)));
    }

    // RLY-21: verify() forwards only the protocol fee and refunds the overpayment to the caller.
    function test_verify_refundsOverpayment() public {
        uint8 pid = 3;
        uint32 vrid = START_VOTING_ROUND_ID;
        uint256 fee = 1000;
        IRelay.RelayInitialConfig memory cfg = _initialConfig(_signingPolicyHash(policy));
        cfg.feeConfigs = new IRelay.FeeConfig[](1);
        cfg.feeConfigs[0] = IRelay.FeeConfig(pid, fee);
        Relay r = deployRelay(cfg, address(0), IRelay(address(0)));

        bytes32 leaf = keccak256("claim");
        bytes32 sibling = keccak256("sib");
        bytes memory message = _protocolMessage(pid, vrid, false, _sortedPair(leaf, sibling));
        bytes memory sigs = _signatures(_ethSignedHash(message), _firstK(3));
        (bool ok,) = address(r).call(abi.encodePacked(Relay.relay.selector, policy, message, sigs));
        require(ok, "relay failed");

        bytes32[] memory proof = new bytes32[](1);
        proof[0] = sibling;

        vm.deal(address(this), 1 ether);
        uint256 feeCollBefore = feeCollection.balance;
        uint256 selfBefore = address(this).balance;
        r.verify{value: 5000}(pid, vrid, leaf, proof);
        assertEq(feeCollection.balance - feeCollBefore, fee, "feeCollection received exactly the fee");
        assertEq(selfBefore - address(this).balance, fee, "caller net cost is the fee (overpayment refunded)");
    }

    // Safe fee-exemption allowlist: an exempt caller (e.g. a DVN adapter) verifies for free,
    // everyone else keeps paying; the exemption is installed via a signed Safe action.
    function test_verify_feeExemptAddressPaysNothing() public {
        (Relay r, bytes32 leaf, bytes32[] memory proof) = _deployFeeExemptionFixture();

        // non-exempt caller pays the fee
        vm.deal(address(this), 1 ether);
        uint256 feeCollBefore = feeCollection.balance;
        r.verify{value: 1000}(3, START_VOTING_ROUND_ID, leaf, proof);
        assertEq(feeCollection.balance - feeCollBefore, 1000, "non-exempt caller pays");

        _installFeeExemption(r);
        assertTrue(r.feeExemptAddress(address(this)), "exemption installed");

        // exempt caller verifies for free — and any attached value is fully refunded
        uint256 selfBefore = address(this).balance;
        uint256 feeCollAfterExempt = feeCollection.balance;
        assertTrue(r.verify{value: 0}(3, START_VOTING_ROUND_ID, leaf, proof), "free verification");
        assertTrue(r.verify{value: 5000}(3, START_VOTING_ROUND_ID, leaf, proof), "overpayment fully refunded");
        assertEq(feeCollection.balance, feeCollAfterExempt, "no fee forwarded for exempt caller");
        assertEq(address(this).balance, selfBefore, "exempt caller net cost is zero");
    }

    function _deployFeeExemptionFixture() internal returns (Relay r, bytes32 leaf, bytes32[] memory proof) {
        IRelay.RelayInitialConfig memory cfg = _initialConfig(_signingPolicyHash(policy));
        cfg.feeConfigs = new IRelay.FeeConfig[](1);
        cfg.feeConfigs[0] = IRelay.FeeConfig(3, 1000);
        // Safe governance fixture: 2-of-3 owners, replay floor 5. Source stays this chain
        // (set explicitly by the base fixture; zero is illegal).
        cfg.governance.safe = address(0xCAFE);
        cfg.governance.threshold = 2;
        cfg.governance.owners = _sortedAddrs(_safeOwnerKeys());
        cfg.governance.ownerConfigSafeNonce = 5;
        cfg.governance.safeNonce = 5;
        r = deployRelay(cfg, address(0), IRelay(address(0)));

        // finalize a root so verify() has something to prove against
        leaf = keccak256("claim");
        bytes32 sibling = keccak256("sib");
        bytes memory message = _protocolMessage(3, START_VOTING_ROUND_ID, false, _sortedPair(leaf, sibling));
        bytes memory sigs = _signatures(_ethSignedHash(message), _firstK(3));
        (bool ok,) = address(r).call(abi.encodePacked(Relay.relay.selector, policy, message, sigs));
        require(ok, "relay failed");
        proof = new bytes32[](1);
        proof[0] = sibling;
    }

    function _installFeeExemption(Relay r) internal {
        uint256[] memory safeOwnerKeys = _safeOwnerKeys();
        address[] memory safeOwners = _sortedAddrs(safeOwnerKeys);
        bytes32 ownerHash = SafeGovernance.ownerConfigHash(block.chainid, address(0xCAFE), 5, 2, safeOwners);
        SafeGovernance.GovernanceFeeExemption[] memory updates = new SafeGovernance.GovernanceFeeExemption[](1);
        updates[0] = SafeGovernance.GovernanceFeeExemption(block.chainid, address(r), address(this), true);
        ISafeGovernance.SafeTx memory txData;
        txData.to = address(0xFEED);
        txData.data =
            abi.encodeWithSelector(SafeGovernance.CHANGE_FEE_EXEMPTIONS_SELECTOR, uint256(6), ownerHash, updates);
        txData.nonce = 6;
        r.processSafeMessage(txData, _safeSign(txData, safeOwnerKeys, 2));
    }

    function _safeOwnerKeys() internal pure returns (uint256[] memory safeOwnerKeys) {
        safeOwnerKeys = new uint256[](3);
        safeOwnerKeys[0] = 501;
        safeOwnerKeys[1] = 502;
        safeOwnerKeys[2] = 503;
    }

    function _sortedAddrs(uint256[] memory _keys) internal pure returns (address[] memory a) {
        a = new address[](_keys.length);
        for (uint256 i; i < _keys.length; ++i) {
            a[i] = vm.addr(_keys[i]);
        }
        for (uint256 i = 1; i < a.length; ++i) {
            address v = a[i];
            uint256 k = _keys[i];
            uint256 j = i;
            while (j > 0 && a[j - 1] > v) {
                a[j] = a[j - 1];
                _keys[j] = _keys[j - 1];
                --j;
            }
            a[j] = v;
            _keys[j] = k;
        }
    }

    // Safe v1.3.0 digest replica (differentially pinned in SafeGoverned.t.sol) + sorted signing.
    function _safeSign(ISafeGovernance.SafeTx memory t, uint256[] memory signingKeys, uint256 count)
        internal
        view
        returns (bytes memory out)
    {
        bytes32 domain = keccak256(abi.encode(
            keccak256("EIP712Domain(uint256 chainId,address verifyingContract)"), block.chainid, address(0xCAFE)
        ));
        bytes32 structHash = keccak256(abi.encode(
            // solhint-disable-next-line max-line-length
            keccak256("SafeTx(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 nonce)"),
            t.to, t.value, keccak256(t.data), t.operation,
            t.safeTxGas, t.baseGas, t.gasPrice, t.gasToken, t.refundReceiver, t.nonce
        ));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domain, structHash));
        for (uint256 i; i < count; ++i) {
            (uint8 v, bytes32 r_, bytes32 s_) = vm.sign(signingKeys[i], digest);
            out = bytes.concat(out, abi.encodePacked(r_, s_, v));
        }
    }

    // RLY-04: a Mode-2 relay with a zero merkle root must revert (else isFinalized / already-relayed break).
    function test_relay_zeroMerkleRoot_reverts() public {
        // identical setup differing only in the root: non-zero finalizes, zero reverts
        bytes memory okMsg = _protocolMessage(3, START_VOTING_ROUND_ID, false, keccak256("root"));
        bytes memory okSigs = _signatures(_ethSignedHash(okMsg), _firstK(3));
        (bool okPass,) = address(relay).call(abi.encodePacked(Relay.relay.selector, policy, okMsg, okSigs));
        assertTrue(okPass, "non-zero root should finalize");

        bytes memory zMsg = _protocolMessage(3, START_VOTING_ROUND_ID + 1, false, bytes32(0));
        bytes memory zSigs = _signatures(_ethSignedHash(zMsg), _firstK(3));
        (bool okZero,) = address(relay).call(abi.encodePacked(Relay.relay.selector, policy, zMsg, zSigs));
        assertFalse(okZero, "zero root should revert");
    }

    // bubbles the inner relay() revert data so vm.expectRevert can match the exact reason
    function relayRaw(bytes calldata rm) external {
        (bool ok, bytes memory ret) = address(relay).call(rm);
        if (!ok) {
            assembly { revert(add(ret, 0x20), mload(ret)) }
        }
    }

    // RLY-16: a non-canonical v is rejected with "Bad v" (before ecrecover).
    function test_relay_badV_reverts() public {
        bytes memory message = _protocolMessage(3, START_VOTING_ROUND_ID, false, keccak256("r"));
        (, bytes32 r, bytes32 s) = vm.sign(pks[0], _ethSignedHash(message));
        bytes memory sigs = abi.encodePacked(uint16(1), uint8(0), r, s, uint16(0)); // v = 0
        bytes memory rm = abi.encodePacked(Relay.relay.selector, policy, message, sigs);
        vm.expectRevert(abi.encodeWithSelector(IRelay.BadV.selector));
        this.relayRaw(rm);
    }

    // RLY-16: a high-s (non-canonical) signature is rejected with "Bad s" (before ecrecover).
    function test_relay_highS_reverts() public {
        bytes memory message = _protocolMessage(3, START_VOTING_ROUND_ID, false, keccak256("r"));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pks[0], _ethSignedHash(message));
        uint256 n = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141; // secp256k1n
        bytes32 highS = bytes32(n - uint256(s));
        bytes memory sigs = abi.encodePacked(uint16(1), v, r, highS, uint16(0)); // s > n/2
        bytes memory rm = abi.encodePacked(Relay.relay.selector, policy, message, sigs);
        vm.expectRevert(abi.encodeWithSelector(IRelay.BadS.selector));
        this.relayRaw(rm);
    }

    // M-1: oldRelay fallback forwards only the old relay's fee and refunds the overpayment.
    function test_verify_oldRelayFallback_refundsOverpayment() public {
        MockOldRelay mock = new MockOldRelay(
            true, FIRST_VOTING_ROUND_TS, VOTING_EPOCH_DURATION,
            FIRST_REWARD_EPOCH_START_VOTING_ROUND_ID, REWARD_EPOCH_DURATION, 700
        );
        Relay r = deployRelay(_initialConfig(_signingPolicyHash(policy)), address(0), IRelay(address(mock)));
        vm.deal(address(this), 1 ether);
        uint256 mockBefore = address(mock).balance;
        uint256 selfBefore = address(this).balance;
        // votingRoundId 100 < START -> oldRelay fallback; oldFee = 700
        r.verify{value: 5000}(3, 100, keccak256("x"), new bytes32[](0));
        assertEq(address(mock).balance - mockBefore, 700, "old relay received only its fee");
        assertEq(selfBefore - address(this).balance, 700, "caller net cost is the old fee (overpayment refunded)");
    }

    // Coverage (Med): weight == threshold must FAIL (strict '>'); weight > threshold passes.
    function test_threshold_exactBoundary_strictGreater() public {
        uint16 thr = 300; // 3 voters * 100 == 300 (the boundary)
        bytes memory pol = _buildSigningPolicy(REWARD_EPOCH_ID, START_VOTING_ROUND_ID, thr, SEED);
        Relay r = deployRelay(_initialConfig(_signingPolicyHash(pol)), address(0), IRelay(address(0)));

        bytes memory m = _protocolMessage(3, START_VOTING_ROUND_ID, false, keccak256("rt"));
        // 3 signers -> weight 300 == threshold -> must fail
        (bool ok3,) = address(r).call(
            abi.encodePacked(Relay.relay.selector, pol, m, _signatures(_ethSignedHash(m), _firstK(3)))
        );
        assertFalse(ok3, "weight == threshold must fail (strict >)");
        // 4 signers -> weight 400 > threshold -> must pass
        (bool ok4,) = address(r).call(
            abi.encodePacked(Relay.relay.selector, pol, m, _signatures(_ethSignedHash(m), _firstK(4)))
        );
        assertTrue(ok4, "weight > threshold must pass");
    }

    // Coverage (Med): if the fee-collection address rejects ETH, verify() reverts "Transfer failed".
    function test_verify_feeReceiverReverts() public {
        RevertingReceiver rr = new RevertingReceiver();
        IRelay.RelayInitialConfig memory cfg = _initialConfig(_signingPolicyHash(policy));
        cfg.feeCollectionAddress = payable(address(rr));
        cfg.feeConfigs = new IRelay.FeeConfig[](1);
        cfg.feeConfigs[0] = IRelay.FeeConfig(3, 500);
        Relay r = deployRelay(cfg, address(0), IRelay(address(0)));

        bytes32 leaf = keccak256("l");
        bytes32 sibling = keccak256("s");
        bytes memory message = _protocolMessage(3, START_VOTING_ROUND_ID, false, _sortedPair(leaf, sibling));
        bytes memory sigs = _signatures(_ethSignedHash(message), _firstK(3));
        (bool ok,) = address(r).call(abi.encodePacked(Relay.relay.selector, policy, message, sigs));
        require(ok, "relay failed");

        bytes32[] memory proof = new bytes32[](1);
        proof[0] = sibling;
        vm.deal(address(this), 1 ether);
        vm.expectRevert(IRelay.FeeTransferFailed.selector);
        r.verify{value: 500}(3, START_VOTING_ROUND_ID, leaf, proof);
    }

    // Coverage (Med): if the caller (refund recipient) rejects ETH, the overpayment refund reverts "Refund failed".
    function test_verify_refundReceiverReverts() public {
        RevertingReceiver rr = new RevertingReceiver();
        IRelay.RelayInitialConfig memory cfg = _initialConfig(_signingPolicyHash(policy)); // feeCollection accepts ETH
        cfg.feeConfigs = new IRelay.FeeConfig[](1);
        cfg.feeConfigs[0] = IRelay.FeeConfig(3, 500);
        Relay r = deployRelay(cfg, address(0), IRelay(address(0)));

        bytes32 leaf = keccak256("l");
        bytes32 sibling = keccak256("s");
        bytes memory message = _protocolMessage(3, START_VOTING_ROUND_ID, false, _sortedPair(leaf, sibling));
        bytes memory sigs = _signatures(_ethSignedHash(message), _firstK(3));
        (bool ok,) = address(r).call(abi.encodePacked(Relay.relay.selector, policy, message, sigs));
        require(ok, "relay failed");

        bytes32[] memory proof = new bytes32[](1);
        proof[0] = sibling;
        vm.deal(address(rr), 1 ether);
        vm.expectRevert(IRelay.RefundFailed.selector);
        rr.callVerify{value: 5000}(r, 3, START_VOTING_ROUND_ID, leaf, proof); // overpays -> refund to rr reverts
    }

    // Coverage (Med): a valid proof for the WRONG leaf against a finalized root reverts "merkle proof invalid".
    function test_verify_merkleProofInvalid_reverts() public {
        uint8 pid = 3;
        uint32 vrid = START_VOTING_ROUND_ID;
        bytes32 leaf = keccak256("claim-leaf");
        bytes32 sibling = keccak256("sibling");
        _relayNonRandom(pid, vrid, _sortedPair(leaf, sibling), 3);
        bytes32[] memory badProof = new bytes32[](1);
        badProof[0] = keccak256("wrong-sibling");
        vm.expectRevert(IRelay.MerkleProofInvalid.selector);
        relay.verify(pid, vrid, leaf, badProof);
    }

    // Coverage (Med): verify() on the new-relay path rejects a reserved protocol id (<= 1).
    function test_verify_invalidProtocolId_reverts() public {
        vm.expectRevert(IRelay.InvalidProtocolId.selector);
        relay.verify(1, START_VOTING_ROUND_ID, keccak256("x"), new bytes32[](0));
    }

    // Coverage (Med): in relay mode (signingPolicySetter == 0) merkleRoots() is locked out.
    function test_merkleRoots_relayMode_reverts() public {
        vm.expectRevert(IRelay.NoAccessToMerkleRoots.selector);
        relay.merkleRoots(3, START_VOTING_ROUND_ID);
    }

    // Coverage (Med): in relay mode toSigningPolicyHash() is locked out.
    function test_toSigningPolicyHash_relayMode_reverts() public {
        vm.expectRevert(IRelay.NoAccessToSigningPolicyHashes.selector);
        relay.toSigningPolicyHash(REWARD_EPOCH_ID);
    }

    // Coverage (Med): getVotingRoundId underflow guard.
    function test_getVotingRoundId_beforeStart_reverts() public {
        vm.expectRevert(IRelay.HistoryBeforeStart.selector);
        relay.getVotingRoundId(uint256(FIRST_VOTING_ROUND_TS) - 1);
    }

    // Coverage (Low, RLY-20): getRandomNumber() before any random relay returns (0, false, ts), no revert.
    function test_getRandomNumber_beforeAnyRelay_returnsDefault() public {
        (uint256 rnd, bool sec, uint256 tsv) = relay.getRandomNumber();
        assertEq(rnd, 0, "no random yet");
        assertFalse(sec, "not secure before any relay");
        assertEq(tsv, uint256(FIRST_VOTING_ROUND_TS) + uint256(1) * VOTING_EPOCH_DURATION, "ts for round 0+1");
    }

    // ---- M-1 oldRelay fallback fee edges ----

    function _oldRelayWithFee(uint256 feeWei) internal returns (MockOldRelay mock, Relay r) {
        mock = new MockOldRelay(
            true, FIRST_VOTING_ROUND_TS, VOTING_EPOCH_DURATION,
            FIRST_REWARD_EPOCH_START_VOTING_ROUND_ID, REWARD_EPOCH_DURATION, feeWei
        );
        r = deployRelay(_initialConfig(_signingPolicyHash(policy)), address(0), IRelay(address(mock)));
    }

    // M-1: msg.value below the old relay's fee reverts "too low fee".
    function test_verify_oldRelayFallback_tooLowFee_reverts() public {
        (, Relay r) = _oldRelayWithFee(700);
        vm.deal(address(this), 1 ether);
        vm.expectRevert(IRelay.TooLowFee.selector);
        r.verify{value: 699}(3, 100, keccak256("x"), new bytes32[](0)); // round 100 < START -> fallback
    }

    // M-1: exact fee -> oldRefund == 0 -> the refund call is SKIPPED. A refund-rejecting caller paying
    // the exact fee must therefore NOT revert (proves the if(oldRefund > 0) false-branch).
    function test_verify_oldRelayFallback_exactFee_skipsRefund() public {
        (MockOldRelay mock, Relay r) = _oldRelayWithFee(700);
        RevertingReceiver rr = new RevertingReceiver();
        vm.deal(address(rr), 1 ether);
        uint256 mockBefore = address(mock).balance;
        rr.callVerify{value: 700}(r, 3, 100, keccak256("x"), new bytes32[](0));
        assertEq(address(mock).balance - mockBefore, 700, "old relay received exactly its fee, no refund attempted");
    }

    // M-1: oldFee == 0 with overpayment -> full refund to caller.
    function test_verify_oldRelayFallback_zeroFee_fullRefund() public {
        (MockOldRelay mock, Relay r) = _oldRelayWithFee(0);
        vm.deal(address(this), 1 ether);
        uint256 mockBefore = address(mock).balance;
        uint256 selfBefore = address(this).balance;
        bool ok = r.verify{value: 1234}(3, 100, keccak256("x"), new bytes32[](0));
        assertTrue(ok);
        assertEq(address(mock).balance - mockBefore, 0, "old relay forwarded zero fee");
        assertEq(selfBefore - address(this).balance, 0, "caller fully refunded");
    }

    // Coverage (Med): the four read paths delegate to the old relay below the switchover boundary.
    function test_oldRelay_readDelegation_belowBoundary() public {
        (, Relay r) = _oldRelayWithFee(0);
        assertEq(r.merkleRoots(3, 100), bytes32(uint256(0xABCDEF)), "merkleRoots delegated");
        assertTrue(r.isFinalized(3, 100), "isFinalized delegated");
        assertEq(r.toSigningPolicyHash(0), bytes32(uint256(0xCAFE)), "toSigningPolicyHash delegated (epoch 0 < initial)");
        (uint256 rn, bool sec,) = r.getRandomNumberHistorical(100);
        assertEq(rn, 0xBEEF, "historical random delegated");
        assertTrue(sec, "historical isSecure delegated");
    }

    // Coverage (Low, DiD): a caller that re-enters a verify()-path read during the refund callback.
    // verify() does no state writes, so this is benign: reentrancy observes consistent state and
    // feeCollection receives exactly one fee.
    function test_verify_reentrantReceiver_consistentNoExtraEth() public {
        uint8 pid = 3;
        uint32 vrid = START_VOTING_ROUND_ID;
        uint256 fee = 500;
        IRelay.RelayInitialConfig memory cfg = _initialConfig(_signingPolicyHash(policy));
        cfg.feeConfigs = new IRelay.FeeConfig[](1);
        cfg.feeConfigs[0] = IRelay.FeeConfig(pid, fee);
        Relay r = deployRelay(cfg, address(0), IRelay(address(0)));

        bytes32 leaf = keccak256("l");
        bytes32 sibling = keccak256("s");
        bytes memory message = _protocolMessage(pid, vrid, false, _sortedPair(leaf, sibling));
        bytes memory sigs = _signatures(_ethSignedHash(message), _firstK(3));
        (bool ok,) = address(r).call(abi.encodePacked(Relay.relay.selector, policy, message, sigs));
        require(ok, "relay failed");
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = sibling;

        ReentrantReceiver rr = new ReentrantReceiver(r, pid, vrid, leaf, proof);
        vm.deal(address(this), 1 ether);
        uint256 feeBefore = feeCollection.balance;
        rr.fire{value: 5000}(); // overpays -> refund 4500 to rr -> receive() re-enters isFinalized
        assertTrue(rr.reentered(), "refund callback re-entered verify() read");
        assertEq(feeCollection.balance - feeBefore, fee, "exactly one fee collected despite reentrancy");
    }

    // ---- signature-loop index / count edges ----

    // Coverage (Low): a signature index == numberOfVoters is out of range.
    function test_relay_indexOutOfRange_reverts() public {
        bytes memory message = _protocolMessage(3, START_VOTING_ROUND_ID, false, keccak256("r"));
        (uint8 v, bytes32 rr, bytes32 s) = vm.sign(pks[0], _ethSignedHash(message));
        bytes memory sigs = abi.encodePacked(uint16(1), v, rr, s, uint16(uint256(N))); // index N (valid 0..N-1)
        bytes memory rm = abi.encodePacked(Relay.relay.selector, policy, message, sigs);
        vm.expectRevert(IRelay.IndexOutOfRange.selector);
        this.relayRaw(rm);
    }

    // Coverage (Low): signature indices must be strictly increasing.
    function test_relay_indexOutOfOrder_reverts() public {
        bytes memory message = _protocolMessage(3, START_VOTING_ROUND_ID, false, keccak256("r"));
        bytes32 sh = _ethSignedHash(message);
        (uint8 v0, bytes32 r0, bytes32 s0) = vm.sign(pks[1], sh);
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(pks[0], sh);
        bytes memory sigs = abi.encodePacked(uint16(2), v0, r0, s0, uint16(1), v1, r1, s1, uint16(0)); // 1 then 0
        bytes memory rm = abi.encodePacked(Relay.relay.selector, policy, message, sigs);
        vm.expectRevert(IRelay.IndexOutOfOrder.selector);
        this.relayRaw(rm);
    }

    // Coverage (Low): a zero-signature message falls through to "Not enough weight".
    function test_relay_zeroSignatures_notEnoughWeight() public {
        bytes memory message = _protocolMessage(3, START_VOTING_ROUND_ID, false, keccak256("r"));
        bytes memory sigs = abi.encodePacked(uint16(0)); // declared count 0, no signature bytes
        bytes memory rm = abi.encodePacked(Relay.relay.selector, policy, message, sigs);
        vm.expectRevert("Not enough weight");
        this.relayRaw(rm);
    }

    receive() external payable {}
}

// RLY-10 / RLY-11: constructor input validation.
contract RelayConstructorTest is RelayTestBase {
    bytes internal policy;

    function setUp() public override {
        super.setUp();
        policy = _buildSigningPolicy(REWARD_EPOCH_ID, START_VOTING_ROUND_ID, THRESHOLD, SEED);
    }

    function _cfg() internal view returns (IRelay.RelayInitialConfig memory) {
        return _initialConfig(_signingPolicyHash(policy));
    }

    function test_ctor_rejects_zeroRewardEpochDuration() public {
        IRelay.RelayInitialConfig memory c = _cfg();
        c.rewardEpochDurationInVotingEpochs = 0;
        Relay implementation = new Relay();
        vm.expectRevert(IRelay.RewardEpochDurationZero.selector);
        new RelayProxy(address(implementation), c, address(0), IRelay(address(0)), RELAY_TEST_GOVERNANCE);
    }

    function test_ctor_rejects_zeroVotingEpochDuration() public {
        IRelay.RelayInitialConfig memory c = _cfg();
        c.votingEpochDurationSeconds = 0;
        Relay implementation = new Relay();
        vm.expectRevert(IRelay.VotingEpochDurationZero.selector);
        new RelayProxy(address(implementation), c, address(0), IRelay(address(0)), RELAY_TEST_GOVERNANCE);
    }

    function test_ctor_rejects_zeroFeeCollection_relayMode() public {
        IRelay.RelayInitialConfig memory c = _cfg();
        c.feeCollectionAddress = payable(address(0));
        Relay implementation = new Relay();
        vm.expectRevert(IRelay.FeeCollectionAddressZero.selector);
        new RelayProxy(address(implementation), c, address(0), IRelay(address(0)), RELAY_TEST_GOVERNANCE);
    }

    function test_ctor_allows_zeroFeeCollection_setterMode() public {
        IRelay.RelayInitialConfig memory c = _cfg();
        c.feeCollectionAddress = payable(address(0));
        // setter mode (signingPolicySetter != 0): no fees possible, zero fee-collection allowed
        Relay r = deployRelay(c, address(this), IRelay(address(0)));
        assertEq(r.signingPolicySetter(), address(this));
    }

    // L-4: a zero initialSigningPolicyHash bricks the initial epoch and is rejected.
    function test_ctor_rejects_zeroInitialSigningPolicyHash() public {
        IRelay.RelayInitialConfig memory c = _cfg();
        c.initialSigningPolicyHash = bytes32(0);
        Relay implementation = new Relay();
        vm.expectRevert(IRelay.InitialSigningPolicyHashZero.selector);
        new RelayProxy(address(implementation), c, address(0), IRelay(address(0)), RELAY_TEST_GOVERNANCE);
    }

    // Coverage (Med): a relay-mode new deployment against a SETTER-mode old relay is incompatible.
    function test_ctor_oldRelay_incompatibleSetterMode_reverts() public {
        MockOldRelaySetterMode mock = new MockOldRelaySetterMode();
        Relay implementation = new Relay();
        vm.expectRevert(IRelay.OldRelayIncompatible.selector);
        // new relay = relay mode, old = setter mode
        new RelayProxy(address(implementation), _cfg(), address(0), IRelay(address(mock)), RELAY_TEST_GOVERNANCE);
    }

    // Coverage (Med): a timing-field mismatch with the old relay is rejected ("wrong start ts").
    function test_ctor_oldRelay_wrongStartTs_reverts() public {
        MockOldRelay mock = new MockOldRelay(
            true, FIRST_VOTING_ROUND_TS + 1, VOTING_EPOCH_DURATION, // ts differs by 1
            FIRST_REWARD_EPOCH_START_VOTING_ROUND_ID, REWARD_EPOCH_DURATION, 0
        );
        Relay implementation = new Relay();
        vm.expectRevert(IRelay.OldRelayWrongStartTs.selector);
        new RelayProxy(address(implementation), _cfg(), address(0), IRelay(address(mock)), RELAY_TEST_GOVERNANCE);
    }

}

// Signing-policy ROTATION lifecycle — the protocolId == 0 ("Mode 1") new-signing-policy relay and the
// message relays that span a rotation. This is the area the Hardhat suite (Relay.test.ts, "Verification")
// exercises extensively but the Foundry unit suite did not; ported here in the harness's own Solidity style
// (no TS encoders — the new-policy calldata layout is reconstructed directly).
contract RelayPolicyRotationTest is RelayTestBase {
    bytes internal policy;       // epoch-1 (initial / current) signing policy
    bytes internal policy2;      // epoch-2 (next) signing policy
    uint32 internal startVRID2;  // starting voting round id of epoch 2

    function setUp() public override {
        super.setUp();
        policy = _buildSigningPolicy(REWARD_EPOCH_ID, START_VOTING_ROUND_ID, THRESHOLD, SEED);
        startVRID2 = START_VOTING_ROUND_ID + REWARD_EPOCH_DURATION;
        policy2 = _buildSigningPolicy(uint24(REWARD_EPOCH_ID + 1), startVRID2, THRESHOLD, SEED);
    }

    // relay() calldata for a Mode-1 new-signing-policy relay:
    //   selector || signerPolicy || protocolId(0x00) || newPolicy || signatures.
    // The signers sign the EIP-191 prefix over the *signing-policy hash of the new policy*
    // (web3.eth.accounts.sign semantics in the TS suite), NOT keccak(message).
    function _newPolicyRelay(bytes memory signerPolicy, bytes memory newPolicy, uint256 numSigners)
        internal view returns (bytes memory)
    {
        bytes32 signedHash =
            keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _signingPolicyHash(newPolicy)));
        bytes memory sigs = _signatures(signedHash, _firstK(numSigners));
        return abi.encodePacked(Relay.relay.selector, signerPolicy, uint8(0), newPolicy, sigs);
    }

    // relay() calldata for a Mode-2 non-random message signed by `signerPolicy`.
    function _msgRelay(bytes memory signerPolicy, uint8 pid, uint32 vrid, bytes32 root, uint256 numSigners)
        internal view returns (bytes memory)
    {
        bytes memory message = _protocolMessage(pid, vrid, false, root);
        bytes memory sigs = _signatures(_ethSignedHash(message), _firstK(numSigners));
        return abi.encodePacked(Relay.relay.selector, signerPolicy, message, sigs);
    }

    // bubbles the inner relay() revert data so vm.expectRevert can match the exact reason
    function relayRaw(bytes calldata rm) external {
        (bool ok, bytes memory ret) = address(relay).call(rm);
        if (!ok) {
            assembly { revert(add(ret, 0x20), mload(ret)) }
        }
    }

    // HH "Should relay a new signing policy": Mode-1 relay signed by the current policy advances
    // lastInitializedRewardEpoch to the new epoch and records its starting voting round id.
    function test_relayNewSigningPolicy_happyPath() public {
        (uint32 le0,) = relay.lastInitializedRewardEpochData();
        assertEq(le0, REWARD_EPOCH_ID, "precondition: last initialized epoch == 1");

        (bool ok,) = address(relay).call(_newPolicyRelay(policy, policy2, 3)); // 3*100 = 300 > 260
        assertTrue(ok, "new signing policy relay should succeed");

        (uint32 le1, uint32 sv1) = relay.lastInitializedRewardEpochData();
        assertEq(le1, REWARD_EPOCH_ID + 1, "last initialized advanced to epoch 2");
        assertEq(sv1, startVRID2, "starting voting round id recorded for epoch 2");
    }

    // HH "Should relay a message with new signing policy": after the rotation, an epoch-2 message is
    // finalized by the NEW (epoch-2) policy at the base threshold.
    function test_relayNewSigningPolicy_thenRelayWithNewPolicy() public {
        (bool okRot,) = address(relay).call(_newPolicyRelay(policy, policy2, 3));
        require(okRot, "rotation failed");

        (bool ok,) = address(relay).call(_msgRelay(policy2, 3, startVRID2, keccak256("root2"), 3));
        assertTrue(ok, "epoch-2 message under epoch-2 policy should finalize");
        assertTrue(relay.isFinalized(3, startVRID2), "message finalized");
    }

    // HH "...wrong reward epoch": the relayed policy must be for lastInitialized + 1.
    function test_relayNewSigningPolicy_wrongRewardEpoch_reverts() public {
        bytes memory policy3 =
            _buildSigningPolicy(uint24(REWARD_EPOCH_ID + 2), startVRID2 + REWARD_EPOCH_DURATION, THRESHOLD, SEED);
        vm.expectRevert(IRelay.NotNextRewardEpoch.selector); // epoch 3 while lastInitialized == 1
        this.relayRaw(_newPolicyRelay(policy, policy3, 3));
    }

    // HH "...wrong signature / low weight": insufficient signer weight on the Mode-1 relay falls through
    // to "Not enough weight" (the new policy is not initialized).
    function test_relayNewSigningPolicy_lowWeight_reverts() public {
        vm.expectRevert("Not enough weight"); // 2*100 = 200 < 260
        this.relayRaw(_newPolicyRelay(policy, policy2, 2));
        (uint32 le,) = relay.lastInitializedRewardEpochData();
        assertEq(le, REWARD_EPOCH_ID, "failed relay must not advance the epoch");
    }

    // HH "...not provided new sign policy size": protocolId 0 with no new-policy metadata at all.
    function test_relayNewSigningPolicy_noNewPolicySize_reverts() public {
        bytes memory bad = abi.encodePacked(Relay.relay.selector, policy, uint8(0)); // nothing after protocolId
        vm.expectRevert(IRelay.NoNewSignPolicySize.selector);
        this.relayRaw(bad);
    }

    // HH "...when a new was initialized and votingRoundId is over startingVotingRoundId": once the epoch-2
    // policy exists, relaying an epoch-2 message with the OLD epoch-1 policy is rejected.
    function test_relay_mustUseNewSignPolicy_afterRotation_reverts() public {
        (bool okRot,) = address(relay).call(_newPolicyRelay(policy, policy2, 3));
        require(okRot, "rotation failed");

        // epoch-2 message (vrid == startVRID2) signed by the old epoch-1 policy
        vm.expectRevert(IRelay.MustUseNewSignPolicy.selector);
        this.relayRaw(_msgRelay(policy, 3, startVRID2, keccak256("r"), 3));
    }

    // HH "...old signing policy and 20% signatures more" / "...less then 20%+ more weight": relaying a
    // FUTURE-epoch message with the current policy (before a newer one exists) requires the increased
    // threshold (260 * 1.2 = 312): 3 signers (300) fail, 4 signers (400) pass.
    function test_relay_crossEpoch_oldPolicy_thresholdIncrease() public {
        bytes32 root = keccak256("xe");
        (bool ok3,) = address(relay).call(_msgRelay(policy, 3, startVRID2, root, 3)); // 300 < 312
        assertFalse(ok3, "3 signers (300) below the increased threshold (312) must fail");

        (bool ok4,) = address(relay).call(_msgRelay(policy, 3, startVRID2, root, 4)); // 400 > 312
        assertTrue(ok4, "4 signers (400) above the increased threshold (312) must pass");
        assertTrue(relay.isFinalized(3, startVRID2), "future-epoch message finalized with +20% weight");
    }
}

// Minimal old-relay mock: satisfies the Relay constructor compatibility checks
// (signingPolicySetter()==0 and matching stateData() timing fields) and returns a configurable verify().
contract MockOldRelay {
    bool public verifyReturn;
    uint32 internal immutable ts;
    uint8 internal immutable vd;
    uint32 internal immutable fre;
    uint16 internal immutable red;
    uint256 internal immutable feeWei;

    constructor(bool _verifyReturn, uint32 _ts, uint8 _vd, uint32 _fre, uint16 _red, uint256 _feeWei) {
        verifyReturn = _verifyReturn;
        ts = _ts; vd = _vd; fre = _fre; red = _red; feeWei = _feeWei;
    }

    function signingPolicySetter() external pure returns (address) {
        return address(0);
    }

    function protocolFeeInWei(uint256) external view returns (uint256) {
        return feeWei;
    }

    // tuple positions 1..4 (firstVotingRoundStartTs, votingEpochDurationSeconds,
    // firstRewardEpochStartVotingRoundId, rewardEpochDurationInVotingEpochs) must match the new relay's config
    function stateData() external view returns (uint8, uint32, uint8, uint32, uint16, uint16, uint32, bool, uint32, bool, uint32) {
        return (0, ts, vd, fre, red, 0, 0, false, 0, false, 0);
    }

    function verify(uint256, uint256, bytes32, bytes32[] calldata) external payable returns (bool) {
        return verifyReturn;
    }

    // Read-delegation sentinels (distinct constants) so the new relay's pre-boundary fallbacks can be asserted.
    function merkleRoots(uint256, uint256) external pure returns (bytes32) {
        return bytes32(uint256(0xABCDEF));
    }
    function isFinalized(uint256, uint256) external pure returns (bool) {
        return true;
    }
    function toSigningPolicyHash(uint256) external pure returns (bytes32) {
        return bytes32(uint256(0xCAFE));
    }
    function getRandomNumberHistorical(uint256) external pure returns (uint256, bool, uint256) {
        return (0xBEEF, true, 0xD00D);
    }
}

// Old relay reporting SETTER mode (non-zero signingPolicySetter) -> triggers "old relay incompatible"
// against a relay-mode new deployment (the incompat check runs before any stateData read).
contract MockOldRelaySetterMode {
    function signingPolicySetter() external pure returns (address) {
        return address(0x5E77E5);
    }
}

// Re-enters a verify()-path read during the overpayment refund callback; proves verify() exposes
// consistent state mid-call and that reentrancy is harmless (verify() performs no state writes).
contract ReentrantReceiver {
    Relay internal r;
    uint256 internal pid;
    uint256 internal vrid;
    bytes32 internal leaf;
    bytes32[] internal proof;
    bool public reentered;

    constructor(Relay _r, uint256 _pid, uint256 _vrid, bytes32 _leaf, bytes32[] memory _proof) {
        r = _r; pid = _pid; vrid = _vrid; leaf = _leaf; proof = _proof;
    }

    function fire() external payable {
        r.verify{value: msg.value}(pid, vrid, leaf, proof);
    }

    receive() external payable {
        if (!reentered) {
            reentered = true;
            // mid-refund: finalized state must still read consistently
            require(r.isFinalized(pid, vrid), "state inconsistent during reentrancy");
        }
    }
}

// Rejects all incoming ETH; exercises verify()'s "Transfer failed" (fee) and "Refund failed" (overpayment) paths.
contract RevertingReceiver {
    function callVerify(Relay r, uint256 pid, uint256 vrid, bytes32 leaf, bytes32[] calldata proof) external payable {
        r.verify{value: msg.value}(pid, vrid, leaf, proof);
    }
    receive() external payable {
        revert("no eth");
    }
}
