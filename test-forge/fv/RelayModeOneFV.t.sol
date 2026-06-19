// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "../unit/protocol/implementation/Relay.t.sol"; // RelayTestBase

// Phase 3 (AC-6 FULL): Mode-1 (relay-only) new-signing-policy relay — threshold consistency on the REAL
// protocolId==0 path (Relay.sol:1004-1160), not just the setter-formula equivalent.
//
// Mode-1 installs a new signing policy by relaying it, signed by the CURRENT policy's voter quorum. The
// calldata layout (reverse-engineered from the parser) is:
//     selector(4) || oldPolicy(43+No*22) || protocolId(1, ==0) || newPolicy(43+Nn*22) || signatures
// where the "message" is protocolId(0) || newPolicy and the old voters sign the NEW policy hash. Before the
// signature loop, the contract runs checkThresholdConsistency on the NEW policy (Relay.sol:1109/621-668):
//     totalWeight <= 2**16-1                                  ("total weight too big")
//     threshold*THRESHOLD_BIPS >= totalWeight*MIN_THRESHOLD_BIPS   ("too small threshold")
// (Note: Mode-1 enforces only the MIN band, unlike setSigningPolicy which also checks MAX.) So a quorum
// cannot relay-install a new policy whose threshold is too small to be safe — AC-6, proven on the live path.
//
// Mode-1 is only enabled in RELAY-ONLY mode (signingPolicySetter==0; setter mode sets noSigningPolicyRelay,
// Relay.sol:267-269). Old policy: epoch 1, 3 voters weight 100, threshold 260 (the signing quorum, 300>260).
// New policy: epoch 2 (== lastInitialized+1), 1 voter weight 100, SYMBOLIC threshold T. Symbolic signatures,
// ecrecover uninterpreted (so the old voters can sign the new policy hash for any T).
contract RelayModeOneFV is RelayTestBase {
    bytes internal oldPolicy;
    uint256 internal constant NV = 3;
    uint24 internal constant NEW_EPOCH = uint24(REWARD_EPOCH_ID) + 1; // 2
    uint32 internal constant NEW_START = START_VOTING_ROUND_ID + REWARD_EPOCH_DURATION; // 6720
    address internal constant NEW_VOTER = address(uint160(0x2001));
    uint16 internal constant NEW_WEIGHT = 100;

    uint256 constant THRESHOLD_BIPS = 10000;
    uint256 constant MIN_THRESHOLD_BIPS = 5000;

    struct Sig { uint8 v; bytes32 r; bytes32 s; }

    function setUp() public override {
        for (uint256 i = 0; i < NV; i++) {
            voters.push(address(uint160(0x1001 + i)));
            weights.push(WEIGHT); // 100 each, 300 > 260
            pks.push(0);
        }
        oldPolicy = _buildSigningPolicy(REWARD_EPOCH_ID, START_VOTING_ROUND_ID, THRESHOLD, SEED);
        relay = new Relay(_initialConfig(_signingPolicyHash(oldPolicy)), address(0), IRelay(address(0))); // relay-only
    }

    // new policy bytes (1 voter), same packed layout as a signing policy:
    // numVoters(2) || rewardEpochId(3) || startVotingRoundId(4) || threshold(2) || seed(32) || voter(20)||weight(2)
    function _newPolicy(uint16 threshold) internal pure returns (bytes memory) {
        return abi.encodePacked(
            uint16(1), NEW_EPOCH, NEW_START, threshold, bytes32(SEED), NEW_VOTER, NEW_WEIGHT
        );
    }

    function _sig(Sig calldata x, uint16 i) internal pure returns (bytes memory) {
        return abi.encodePacked(x.v, x.r, x.s, i);
    }

    function _relayModeOne(uint16 threshold, Sig calldata a, Sig calldata b, Sig calldata c)
        internal returns (bool ok)
    {
        bytes memory sigs = abi.encodePacked(uint16(3), _sig(a, 0), _sig(b, 1), _sig(c, 2));
        // selector || oldPolicy || protocolId(0) || newPolicy || sigs
        bytes memory cd = abi.encodePacked(
            Relay.relay.selector, oldPolicy, uint8(0), _newPolicy(threshold), sigs
        );
        (ok, ) = address(relay).call(cd);
    }

    // AC-6 — a Mode-1 new policy whose threshold is below the MIN band cannot be installed (rejected at
    // checkThresholdConsistency, before signatures even matter).
    function check_modeOne_thresholdTooSmall_rejected(
        uint16 t, Sig calldata a, Sig calldata b, Sig calldata c
    ) external {
        vm.assume(uint256(t) * THRESHOLD_BIPS < uint256(NEW_WEIGHT) * MIN_THRESHOLD_BIPS); // t < 50
        assert(!_relayModeOne(t, a, b, c));
    }

    // Anti-vacuity: a Mode-1 new policy with an in-band threshold CAN be installed (the old quorum signs the
    // new policy hash; ecrecover uninterpreted). EXPECT: COUNTEREXAMPLE.
    function check_reach_modeOne_validInstalls(
        uint16 t, Sig calldata a, Sig calldata b, Sig calldata c
    ) external {
        vm.assume(uint256(t) * THRESHOLD_BIPS >= uint256(NEW_WEIGHT) * MIN_THRESHOLD_BIPS); // t >= 50
        assert(!_relayModeOne(t, a, b, c));
    }
}
