// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { Relay } from "../../../../contracts/protocol/implementation/Relay.sol";
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
        relay = new Relay(cfg, address(0), IRelay(address(0)));
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

    // Mirrors Relay.calculateSigningPolicyHash: h = policy[0:32], fold each subsequent 32-byte
    // chunk (h = keccak(h || chunk)); fold the final partial chunk zero-padded on the right.
    function _signingPolicyHash(bytes memory p) internal pure returns (bytes32 h) {
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

    function _ethSignedHash(bytes memory message) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", keccak256(message)));
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

    function _governanceConfig(uint256 nonce, uint8 protocolId, uint256 feeInWei)
        internal view returns (IRelay.RelayGovernanceConfig memory c)
    {
        c.descriptionHash = keccak256("RelayGovernance");
        c.chainId = block.chainid;
        c.nonce = nonce;
        c.newFeeConfigs = new IRelay.FeeConfig[](1);
        c.newFeeConfigs[0] = IRelay.FeeConfig(protocolId, feeInWei);
    }
}

contract RelayGovernanceFeeReplayTest is RelayTestBase {
    bytes internal policy;

    function setUp() public override {
        super.setUp();
        policy = _buildSigningPolicy(REWARD_EPOCH_ID, START_VOTING_ROUND_ID, THRESHOLD, SEED);
    }

    // Sanity: the Solidity reimplementation of the signing-policy hash matches the contract's,
    // checked against a setter-mode Relay's setSigningPolicy return value.
    function test_signingPolicyHash_matchesContract() public {
        // setter-mode relay so we can call setSigningPolicy and read back the contract's hash
        IRelay.RelayInitialConfig memory cfg = _initialConfig(bytes32(0));
        cfg.initialRewardEpochId = 0; // setSigningPolicy requires lastInitialized + 1 == rewardEpochId
        Relay setterRelay = new Relay(cfg, address(this), IRelay(address(0)));

        IIRelay.SigningPolicy memory sp;
        sp.rewardEpochId = REWARD_EPOCH_ID;
        sp.startVotingRoundId = START_VOTING_ROUND_ID;
        sp.threshold = THRESHOLD;
        sp.seed = SEED;
        sp.voters = voters;
        sp.weights = weights;

        bytes32 contractHash = setterRelay.setSigningPolicy(sp);
        assertEq(contractHash, _signingPolicyHash(policy), "policy hash mismatch");
    }

    function test_governanceFeeSetup_happyPath_then_replayRejected() public {
        IRelay.RelayGovernanceConfig memory c = _governanceConfig(1, 2, 1000);
        bytes32 mh = keccak256(abi.encode(c, address(relay)));
        bytes memory rm = _customSigRelayMessage(policy, mh, 3); // 3*100 = 300 > 260

        relay.governanceFeeSetup(rm, c);
        assertEq(relay.protocolFeeInWei(2), 1000, "fee not applied");
        assertEq(relay.governanceFeeNonce(), 1, "nonce not set");

        // RLY-02: replay of the same accepted message is rejected
        vm.expectRevert("nonce too low");
        relay.governanceFeeSetup(rm, c);
    }

    function test_governanceFeeSetup_strictlyIncreasing_nonSequential_nonce() public {
        IRelay.RelayGovernanceConfig memory c1 = _governanceConfig(1, 2, 1000);
        relay.governanceFeeSetup(_customSigRelayMessage(policy, keccak256(abi.encode(c1, address(relay))), 3), c1);

        // jump nonce 1 -> 5 (non-sequential) is accepted
        IRelay.RelayGovernanceConfig memory c5 = _governanceConfig(5, 2, 2000);
        relay.governanceFeeSetup(_customSigRelayMessage(policy, keccak256(abi.encode(c5, address(relay))), 3), c5);
        assertEq(relay.protocolFeeInWei(2), 2000);
        assertEq(relay.governanceFeeNonce(), 5);

        // nonce 3 (< 5) is rejected even though > original
        IRelay.RelayGovernanceConfig memory c3 = _governanceConfig(3, 2, 3000);
        vm.expectRevert("nonce too low");
        relay.governanceFeeSetup(_customSigRelayMessage(policy, keccak256(abi.encode(c3, address(relay))), 3), c3);
        assertEq(relay.protocolFeeInWei(2), 2000);
    }

    // RLY-02: digest is bound to address(this); a message signed for a different relay address fails.
    function test_governanceFeeSetup_addressBinding() public {
        IRelay.RelayGovernanceConfig memory c = _governanceConfig(1, 2, 1000);
        bytes32 wrongMh = keccak256(abi.encode(c, address(0xdead))); // bound to wrong address
        bytes memory rm = _customSigRelayMessage(policy, wrongMh, 3);
        vm.expectRevert("Invalid config hash");
        relay.governanceFeeSetup(rm, c);
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
        vm.expectRevert("not finalized");
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
            FIRST_REWARD_EPOCH_START_VOTING_ROUND_ID, REWARD_EPOCH_DURATION
        );
        r = new Relay(_initialConfig(_signingPolicyHash(policy)), address(0), IRelay(address(mock)));
    }

    function test_verify_oldRelayFallback_revertsOnFalse() public {
        Relay r = _deployWithOldRelay(false);
        // votingRoundId < startingVotingRoundIdForInitialRewardEpochId routes to the oldRelay fallback
        vm.expectRevert("old relay verification failed");
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
        Relay r = new Relay(cfg, address(0), IRelay(address(0)));

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
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "Bad v"));
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
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "Bad s"));
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
        vm.expectRevert("reward epoch duration zero");
        new Relay(c, address(0), IRelay(address(0)));
    }

    function test_ctor_rejects_zeroVotingEpochDuration() public {
        IRelay.RelayInitialConfig memory c = _cfg();
        c.votingEpochDurationSeconds = 0;
        vm.expectRevert("voting epoch duration zero");
        new Relay(c, address(0), IRelay(address(0)));
    }

    function test_ctor_rejects_zeroFeeCollection_relayMode() public {
        IRelay.RelayInitialConfig memory c = _cfg();
        c.feeCollectionAddress = payable(address(0));
        vm.expectRevert("fee collection address zero");
        new Relay(c, address(0), IRelay(address(0)));
    }

    function test_ctor_allows_zeroFeeCollection_setterMode() public {
        IRelay.RelayInitialConfig memory c = _cfg();
        c.feeCollectionAddress = payable(address(0));
        // setter mode (signingPolicySetter != 0): no fees possible, zero fee-collection allowed
        Relay r = new Relay(c, address(this), IRelay(address(0)));
        assertEq(r.signingPolicySetter(), address(this));
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

    constructor(bool _verifyReturn, uint32 _ts, uint8 _vd, uint32 _fre, uint16 _red) {
        verifyReturn = _verifyReturn;
        ts = _ts; vd = _vd; fre = _fre; red = _red;
    }

    function signingPolicySetter() external pure returns (address) {
        return address(0);
    }

    // tuple positions 1..4 (firstVotingRoundStartTs, votingEpochDurationSeconds,
    // firstRewardEpochStartVotingRoundId, rewardEpochDurationInVotingEpochs) must match the new relay's config
    function stateData() external view returns (uint8, uint32, uint8, uint32, uint16, uint16, uint32, bool, uint32, bool, uint32) {
        return (0, ts, vd, fre, red, 0, 0, false, 0, false, 0);
    }

    function verify(uint256, uint256, bytes32, bytes32[] calldata) external payable returns (bool) {
        return verifyReturn;
    }
}
