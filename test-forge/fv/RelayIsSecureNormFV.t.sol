// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// solhint-disable func-name-mixedcase

import {Relay} from "../../contracts/protocol/implementation/Relay.sol";
import {IRelay} from "../../contracts/userInterfaces/IRelay.sol";
import {RelayTestBase} from "../unit/protocol/implementation/Relay.t.sol";
// solhint-disable-next-line no-unused-import
import {deployRelay, RELAY_TEST_GOVERNANCE} from "../utils/RelayDeploy.sol";

// Canonical security-byte properties over the real Relay bytecode.
//
// Random-protocol messages admit only bytes 0 and 1; every other byte must revert
// with WrongMessageFormat2. Other nonzero protocol IDs admit only byte 0. The
// success implications keep the raw byte symbolic over 0..255 and establish both
// canonicality and agreement with the historical/live security bits. An independent
// symbolic leaf bit checks Merkle binding under the keccak injectivity model.
//
// Separate accepting witnesses for bytes 0 and 1 prevent the success implications
// from passing merely because no signature set can finalize. High-byte rejection
// checks the exact error, so invalid symbolic signatures cannot be its reason.
// Events are covered by concrete tests, not asserted by this harness.
//
// The concrete policy has three distinct voters of weight 100, threshold 260,
// and same-epoch round START_VOTING_ROUND_ID > 0. Only signature fields, the
// message byte and (where requested) the leaf bit are symbolic; ECDSA recovery
// is uninterpreted. Acceptance takes three signature iterations and one Merkle
// fold, within the configured loop bound. Round-zero behavior is outside this shape.
contract RelayIsSecureNormFV is RelayTestBase {
    bytes internal policy;
    uint256 internal constant NV = 3;

    // Concrete random-relay parameters (only isSecure byte + signatures are symbolic).
    uint32 internal constant VRID = START_VOTING_ROUND_ID; // same-epoch -> reward epoch 1, first random round
    uint256 internal constant VALUE = 0xCAFE;              // concrete relayed random value
    bytes32 internal constant SIBLING = keccak256("fv-sibling"); // concrete proof sibling

    struct Sig { uint8 v; bytes32 r; bytes32 s; }

    // Fully-concrete setUp (no vm.addr/vm.sign/sorting) so the deploy is a single deterministic path.
    // N=3 voters, weight 100 each (total 300) > threshold 260: three distinct signatures can finalize.
    function setUp() public override {
        for (uint256 i = 0; i < NV; i++) {
            voters.push(address(uint160(0x1001 + i)));
            weights.push(WEIGHT); // 100 each
            pks.push(0); // unused (ecrecover uninterpreted)
        }
        policy = _buildSigningPolicy(REWARD_EPOCH_ID, START_VOTING_ROUND_ID, THRESHOLD, SEED);
        relay = deployRelay(_initialConfig(_signingPolicyHash(policy)), address(0), IRelay(address(0)));
    }

    // ---- Merkle helpers mirroring the contract (RelayRandomTest._sortedPair/_randomLeaf), kept local
    //      because they live on RelayRandomTest, not RelayTestBase. ----

    // OpenZeppelin sorted-pair parent hash (matches processRandomMerkleProof).
    function _sortedPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }

    // leaf = keccak256(abi.encode(votingRoundId, value, isSecure)) — mirrors processRandomMerkleProof
    // (abi.encode left-pads each field to 32 bytes; isSecure encoded as 1/0).
    function _randomLeaf(uint32 vrid, uint256 value, bool isSecure) internal pure returns (bytes32) {
        return keccak256(abi.encode(uint256(vrid), value, uint256(isSecure ? 1 : 0)));
    }

    function _sig(Sig calldata x, uint16 index) internal pure returns (bytes memory) {
        return abi.encodePacked(x.v, x.r, x.s, index);
    }

    // Three signatures at strictly-increasing indices 0,1,2 (so the strict-index guard
    // passes and all three weights are counted -> 300 > 260 -> accept on the third signature).
    function _threeSigs(Sig calldata a, Sig calldata b, Sig calldata c) internal pure returns (bytes memory) {
        return abi.encodePacked(uint16(3), _sig(a, 0), _sig(b, 1), _sig(c, 2));
    }

    // Build the full relay() calldata for a random-protocol message with raw isSecure byte `isSecureByte`,
    // whose signed merkleRoot is the 2-leaf tree over randomLeaf(VRID, VALUE, leafBit). Decoupling the
    // LEAF bit from the message byte checks that an accepting message is canonical and
    // agrees with the Merkle-committed bit (check_leafCanonical_machineChecked).
    // Layout: selector || policy || message(38) || sigs || trailer(value||sibling).
    function _randomCalldataLeaf(uint8 isSecureByte, bool leafBit, bytes memory sigs)
        internal view
        returns (bytes memory)
    {
        bytes32 root = _sortedPair(_randomLeaf(VRID, VALUE, leafBit), SIBLING);
        bytes memory message = abi.encodePacked(RANDOM_PROTOCOL_ID, VRID, isSecureByte, root); // 38 bytes
        bytes memory trailer = abi.encodePacked(VALUE, SIBLING); // randomNumber(32) || proof(1 node)
        return abi.encodePacked(Relay.relay.selector, policy, message, sigs, trailer);
    }

    // The default leaf uses true only for the canonical secure byte 1. Invalid
    // message bytes remain in the input domain and must fail at the parser guard.
    function _randomCalldata(uint8 isSecureByte, bytes memory sigs) internal view returns (bytes memory) {
        return _randomCalldataLeaf(isSecureByte, isSecureByte == 1, sigs);
    }

    function _relay(uint8 isSecureByte, Sig calldata a, Sig calldata b, Sig calldata c) internal returns (bool ok) {
        (ok, ) = address(relay).call(_randomCalldata(isSecureByte, _threeSigs(a, b, c)));
    }

    function _relayLeaf(uint8 isSecureByte, bool leafBit, Sig calldata a, Sig calldata b, Sig calldata c)
        internal returns (bool ok)
    {
        (ok, ) = address(relay).call(_randomCalldataLeaf(isSecureByte, leafBit, _threeSigs(a, b, c)));
    }

    // Historical stored bit: acceptance implies a canonical byte and the matching stored bit.
    // Reads the persisted isSecureRandomMap bit, which is set iff isSecure.
    // EXPECT: PASS.
    function check_historicalSecure_eq_canonicalByte(
        uint8 isSecureByte, Sig calldata a, Sig calldata b, Sig calldata c
    ) external {
        bool ok = _relay(isSecureByte, a, b, c);
        if (ok) {
            (, bool sec, ) = relay.getRandomNumberHistorical(VRID);
            assert(isSecureByte <= 1);
            assert(sec == (isSecureByte == 1));
        }
    }

    // Live flag: acceptance implies a canonical byte and the matching stored bit.
    // Reads stateData.isSecureRandom, written from isSecure in the first-round branch
    // (VRID > 0 = initial randomVotingRoundId, so the branch fires). EXPECT: PASS.
    function check_liveSecure_eq_canonicalByte(
        uint8 isSecureByte, Sig calldata a, Sig calldata b, Sig calldata c
    ) external {
        bool ok = _relay(isSecureByte, a, b, c);
        if (ok) {
            (, bool sec, ) = relay.getRandomNumber();
            assert(isSecureByte <= 1);
            assert(sec == (isSecureByte == 1));
        }
    }

    // Cross-sink consistency: the two persisted sinks agree on every accepting run (no path stores the
    // historical bit and the live flag inconsistently). EXPECT: PASS.
    function check_liveAndHistorical_agree(
        uint8 isSecureByte, Sig calldata a, Sig calldata b, Sig calldata c
    ) external {
        bool ok = _relay(isSecureByte, a, b, c);
        if (ok) {
            (, bool live, ) = relay.getRandomNumber();
            (, bool hist, ) = relay.getRandomNumberHistorical(VRID);
            assert(live == hist);
        }
    }

    // The independent leaf bit is Merkle-bound to the canonical message byte on
    // acceptance. Both values of the leaf are possible; no message-byte assumption
    // removes noncanonical inputs from this property. EXPECT: PASS.
    function check_leafCanonical_machineChecked(
        uint8 isSecureByte, uint8 lb, Sig calldata a, Sig calldata b, Sig calldata c
    ) external {
        vm.assume(lb <= 1); // lb is an independent leaf bit in {0,1}
        bool ok = _relayLeaf(isSecureByte, lb == 1, a, b, c);
        assert(!ok || (isSecureByte <= 1 && isSecureByte == lb));
    }

    // Noncanonical random bytes fail with the exact parser error, regardless of
    // the symbolic signature fields or independent leaf bit. EXPECT: PASS.
    function check_nonCanonicalByte_revertsExactly(
        uint8 isSecureByte, bool leafBit, Sig calldata a, Sig calldata b, Sig calldata c
    ) external {
        vm.assume(isSecureByte > 1);
        (bool ok, bytes memory data) =
            address(relay).call(_randomCalldataLeaf(isSecureByte, leafBit, _threeSigs(a, b, c)));
        assert(!ok);
        assert(data.length == 4);
        assert(bytes4(data) == IRelay.WrongMessageFormat2.selector);
        assert(!relay.isFinalized(RANDOM_PROTOCOL_ID, VRID));
    }

    // Protocol 1 and every non-random protocol reject all nonzero security bytes.
    // The payload includes a valid policy and full message; the exact error shows
    // that neither a short message nor missing signatures explains rejection.
    // EXPECT: PASS.
    function check_nonRandomProtocol_nonzeroByte_revertsExactly(uint8 protocolId, uint8 isSecureByte) external {
        vm.assume(protocolId > 0 && protocolId != RANDOM_PROTOCOL_ID);
        vm.assume(isSecureByte > 0);
        uint32 round = protocolId == 1 ? 0 : VRID;
        bytes memory message = abi.encodePacked(protocolId, round, isSecureByte, SIBLING);
        (bool ok, bytes memory data) =
            address(relay).call(abi.encodePacked(Relay.relay.selector, policy, message, uint16(0)));
        assert(!ok);
        assert(data.length == 4);
        assert(bytes4(data) == IRelay.WrongMessageFormat2.selector);
        assert(!relay.isFinalized(protocolId, round));
    }

    // Both legal bytes must have accepting witnesses; otherwise the implications
    // above are vacuous and the required reachability result must fail the gate.
    // EXPECT: COUNTEREXAMPLE.
    function check_reach_insecure_canAccept(Sig calldata a, Sig calldata b, Sig calldata c) external {
        bool ok = _relay(0, a, b, c);
        assert(!ok);
    }

    // EXPECT: COUNTEREXAMPLE (canonical secure byte 1).
    function check_reach_secure_canAccept(Sig calldata a, Sig calldata b, Sig calldata c) external {
        bool ok = _relay(1, a, b, c);
        assert(!ok);
    }

}
