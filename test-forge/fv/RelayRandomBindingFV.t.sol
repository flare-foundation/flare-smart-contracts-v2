// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// solhint-disable func-name-mixedcase

import {Relay} from "../../contracts/protocol/implementation/Relay.sol";
import {IRelay} from "../../contracts/userInterfaces/IRelay.sol";
import {RelayTestBase} from "../unit/protocol/implementation/Relay.t.sol";
// solhint-disable-next-line no-unused-import
import {deployRelay, RELAY_TEST_GOVERNANCE} from "../utils/RelayDeploy.sol";

// Symbolic proof of random-proof value binding (second-preimage / no-forgery).
//
// CLAIM. For the random-number protocol (Mode-2 relay with the trailer randomNumber||proof), the contract
// reads the random VALUE from the trailer, recomputes the Merkle leaf keccak256(abi.encode(vrid, value,
// isSecure)) in processRandomMerkleProof and reverts unless that leaf reproduces the SIGNED merkleRoot via
// the provided proof; only then does it store toRandomNumberPrivate[vrid] = value. Therefore that mapping
// can only hold a value committed as a leaf under the signed root — no off-tree value can be stored.
//
// HOW (decoupled oracle — machine-checked, NOT by-construction). We DECOUPLE the COMMITTED value `cv`
// (used to build the signed root) from the TRAILER value `tv` (the value the contract actually reads and
// stores). Under the keccak collision-resistance/injectivity model (with the same vrid and isSecure),
// the contract's recomputed leaf reproduces the
// signed root IFF tv == cv. Hence:
//   - tv != cv  =>  relay() cannot accept (a value not committed under the root cannot be stored), and
//   - accept    =>  stored value == cv (the stored random equals the committed value).
// A contract bug that stored a value other than the leaf-committed one, or skipped the leaf check, would be
// caught — the harness root is built from cv, independent of the tv the contract reads.
//
// CONFIG (mirrors RelayIsSecureNormFV). Concrete N=3/weight-100/threshold-260 policy (3 sigs accept),
// fully-concrete setUp, symbolic signatures at the uninterpreted ecrecover boundary, fixed 2-leaf tree
// (1-node proof), same-epoch VRID (no threshold-increase), and isSecure fixed true
// (RelayIsSecureNormFV covers isSecure; here VALUE is the variable). Loops: 3-signature loop + 1-node
// Merkle fold => depth 3 <= halmos.toml loop = 6.
contract RelayRandomBindingFV is RelayTestBase {
    bytes internal policy;
    uint256 internal constant NV = 3;
    uint32 internal constant VRID = START_VOTING_ROUND_ID; // same-epoch, first random round
    bytes32 internal constant SIBLING = keccak256("fv-sibling");
    bool internal constant SEC = true; // isSecure fixed true; message isSecure byte = 1

    struct Sig { uint8 v; bytes32 r; bytes32 s; }

    function setUp() public override {
        for (uint256 i = 0; i < NV; i++) {
            voters.push(address(uint160(0x1001 + i)));
            weights.push(WEIGHT); // 100 each (total 300 > 260)
            pks.push(0); // unused (ecrecover uninterpreted)
        }
        policy = _buildSigningPolicy(REWARD_EPOCH_ID, START_VOTING_ROUND_ID, THRESHOLD, SEED);
        relay = deployRelay(_initialConfig(_signingPolicyHash(policy)), address(0), IRelay(address(0)));
    }

    function _sortedPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }

    // leaf = keccak256(abi.encode(votingRoundId, value, isSecure)) — mirrors processRandomMerkleProof.
    function _randomLeaf(uint32 vrid, uint256 value, bool isSecure) internal pure returns (bytes32) {
        return keccak256(abi.encode(uint256(vrid), value, uint256(isSecure ? 1 : 0)));
    }

    function _sig(Sig calldata x, uint16 index) internal pure returns (bytes memory) {
        return abi.encodePacked(x.v, x.r, x.s, index);
    }

    function _threeSigs(Sig calldata a, Sig calldata b, Sig calldata c) internal pure returns (bytes memory) {
        return abi.encodePacked(uint16(3), _sig(a, 0), _sig(b, 1), _sig(c, 2));
    }

    // Signed root committed to `committedValue`; trailer carries the INDEPENDENT `trailerValue`.
    function _calldata(uint256 committedValue, uint256 trailerValue, bytes memory sigs)
        internal view
        returns (bytes memory)
    {
        bytes32 root = _sortedPair(_randomLeaf(VRID, committedValue, SEC), SIBLING);
        bytes memory message = abi.encodePacked(RANDOM_PROTOCOL_ID, VRID, uint8(1), root); // 38 bytes, isSecure=1
        bytes memory trailer = abi.encodePacked(trailerValue, SIBLING); // randomNumber(32) || 1-node proof
        return abi.encodePacked(Relay.relay.selector, policy, message, sigs, trailer);
    }

    function _relay(uint256 cv, uint256 tv, Sig calldata a, Sig calldata b, Sig calldata c)
        internal
        returns (bool ok)
    {
        (ok, ) = address(relay).call(_calldata(cv, tv, _threeSigs(a, b, c)));
    }

    // An uncommitted trailer value cannot finalize. EXPECT: PASS.
    // Establishes no-forgery: a random value not committed as a leaf under the signed root cannot be stored.
    function check_p4_uncommittedValue_cannotStore(
        uint256 cv, uint256 tv, Sig calldata a, Sig calldata b, Sig calldata c
    ) external {
        vm.assume(tv != cv);
        assert(!_relay(cv, tv, a, b, c));
    }

    // On any accepting run the STORED random (live + historical) equals the committed value cv.
    // EXPECT: PASS. Machine-checks the binding: getRandomNumber / getRandomNumberHistorical return exactly
    // the value committed under the signed Merkle root.
    function check_p4_storedEqualsCommitted(
        uint256 cv, uint256 tv, Sig calldata a, Sig calldata b, Sig calldata c
    ) external {
        bool ok = _relay(cv, tv, a, b, c);
        if (ok) {
            (uint256 liveVal, , ) = relay.getRandomNumber();
            (uint256 histVal, , ) = relay.getRandomNumberHistorical(VRID);
            assert(liveVal == cv && histVal == cv);
        }
    }

    // Non-vacuity control — the committed value (tv == cv) CAN finalize. EXPECT: COUNTEREXAMPLE.
    // If this PASSES, the accept path is unreachable (loop bound too small) and both binding checks are vacuous.
    function check_p4_reachability(uint256 cv, Sig calldata a, Sig calldata b, Sig calldata c) external {
        assert(!_relay(cv, cv, a, b, c));
    }
}
