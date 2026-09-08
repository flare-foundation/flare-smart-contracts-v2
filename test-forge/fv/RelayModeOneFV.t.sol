// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// solhint-disable func-name-mixedcase

import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {Relay} from "../../contracts/protocol/implementation/Relay.sol";
import {IRelay} from "../../contracts/userInterfaces/IRelay.sol";
import {RelayTestBase} from "../unit/protocol/implementation/Relay.t.sol";
// solhint-disable-next-line no-unused-import
import {deployRelay, RELAY_TEST_GOVERNANCE} from "../utils/RelayDeploy.sol";

/**
 * Mode-1 (protocolId == 0) signing-policy rotation through the production Relay bytecode.
 *
 * The old policy's quorum authorizes a new packed policy. Before checking those signatures, Relay
 * validates the new policy's voter count, byte length, sequential epoch, total weight, and both sides
 * of the 50%-66% threshold band. The policy hash and starting round are written before aggregate
 * acceptance, so the insufficient-quorum property below also checks transaction-level rollback of
 * those tentative writes.
 *
 * The fixture uses a three-voter current policy. Its signature loop therefore needs three iterations;
 * the largest new-policy weight-summing loop used here has two iterations, both within halmos.toml's
 * loop bound of six. Cryptographic recovery remains the standard uninterpreted Halmos boundary.
 */
contract RelayModeOneFV is RelayTestBase {
    bytes internal oldPolicy;

    uint256 internal constant CURRENT_VOTERS = 3;
    uint24 internal constant NEW_EPOCH = uint24(REWARD_EPOCH_ID) + 1;
    uint32 internal constant NEW_START = START_VOTING_ROUND_ID + REWARD_EPOCH_DURATION;
    address internal constant NEW_VOTER_0 = address(uint160(0x2001));
    address internal constant NEW_VOTER_1 = address(uint160(0x2002));
    uint16 internal constant NEW_WEIGHT = 100;

    uint256 internal constant THRESHOLD_BIPS = 10000;
    uint256 internal constant MIN_THRESHOLD_BIPS = 5000;
    uint256 internal constant MAX_THRESHOLD_BIPS = 6600;
    uint16 internal constant MAX_VOTERS = 300;

    // The attested sequential layout places toSigningPolicyHashPrivate at slot zero.
    uint256 private constant POLICY_HASH_MAPPING_SLOT = 0;

    struct Sig {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    function setUp() public override {
        for (uint256 i = 0; i < CURRENT_VOTERS; i++) {
            voters.push(address(uint160(0x1001 + i)));
            weights.push(WEIGHT); // current total 300 > current threshold 260
            pks.push(0);
        }
        oldPolicy = _buildSigningPolicy(REWARD_EPOCH_ID, START_VOTING_ROUND_ID, THRESHOLD, SEED);
        relay = deployRelay(_initialConfig(_signingPolicyHash(oldPolicy)), address(0), IRelay(address(0)));
    }

    function _metadata(uint16 numberOfVoters, uint24 epoch, uint16 threshold)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(numberOfVoters, epoch, NEW_START, threshold, bytes32(SEED));
    }

    function _singleVoterPolicy(uint24 epoch, uint16 threshold) internal pure returns (bytes memory) {
        return abi.encodePacked(_metadata(1, epoch, threshold), NEW_VOTER_0, NEW_WEIGHT);
    }

    function _twoVoterPolicy(uint16 threshold, uint16 weight0, uint16 weight1)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            _metadata(2, NEW_EPOCH, threshold), NEW_VOTER_0, weight0, NEW_VOTER_1, weight1
        );
    }

    function _sig(Sig calldata x, uint16 index) internal pure returns (bytes memory) {
        return abi.encodePacked(x.v, x.r, x.s, index);
    }

    function _threeSigs(Sig calldata a, Sig calldata b, Sig calldata c)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(uint16(3), _sig(a, 0), _sig(b, 1), _sig(c, 2));
    }

    function _modeOneCall(bytes memory newPolicy, bytes memory signatures)
        internal
        returns (bool ok, bytes memory returnData)
    {
        bytes memory encoded = abi.encodePacked(
            Relay.relay.selector, oldPolicy, uint8(0), newPolicy, signatures
        );
        (ok, returnData) = address(relay).call(encoded);
    }

    function _policyHashAt(uint256 epoch) internal view returns (bytes32) {
        bytes32 location = keccak256(abi.encode(epoch, POLICY_HASH_MAPPING_SLOT));
        return vm.load(address(relay), location);
    }

    function _assertInitialPolicyState() internal view {
        (uint32 lastEpoch, uint32 lastStart) = relay.lastInitializedRewardEpochData();
        assert(lastEpoch == REWARD_EPOCH_ID);
        assert(lastStart == START_VOTING_ROUND_ID);
        assert(relay.startingVotingRoundIds(REWARD_EPOCH_ID) == START_VOTING_ROUND_ID);
        assert(relay.startingVotingRoundIds(NEW_EPOCH) == 0);
        assert(_policyHashAt(REWARD_EPOCH_ID) == _signingPolicyHash(oldPolicy));
        assert(_policyHashAt(NEW_EPOCH) == bytes32(0));
        assert(!relay.isFinalized(3, START_VOTING_ROUND_ID));
        assert(relay.owner() == RELAY_TEST_GOVERNANCE);
        assert(relay.signingPolicySetter() == address(0));
    }

    function _assertRejectedAndRolledBack(
        bytes memory newPolicy,
        bytes memory signatures,
        bytes4 expectedError
    )
        internal
    {
        _assertInitialPolicyState();
        (bool ok, bytes memory returnData) = _modeOneCall(newPolicy, signatures);
        assert(!ok);
        assert(returnData.length == 4);
        assert(bytes4(returnData) == expectedError);
        _assertInitialPolicyState();
    }

    // Any threshold strictly below the lower band is rejected by the Mode-1 path itself.
    // EXPECT: PASS (proof).
    function check_modeOne_thresholdTooSmall_rejected(uint16 threshold) external {
        vm.assume(
            uint256(threshold) * THRESHOLD_BIPS < uint256(NEW_WEIGHT) * MIN_THRESHOLD_BIPS
        );
        _assertRejectedAndRolledBack(
            _singleVoterPolicy(NEW_EPOCH, threshold), bytes(""), IRelay.ThresholdTooLow.selector
        );
    }

    // Any threshold strictly above the upper band is rejected by the Mode-1 path itself.
    // EXPECT: PASS (proof).
    function check_modeOne_thresholdTooHigh_rejected(uint16 threshold) external {
        vm.assume(
            uint256(threshold) * THRESHOLD_BIPS > uint256(NEW_WEIGHT) * MAX_THRESHOLD_BIPS
        );
        _assertRejectedAndRolledBack(
            _singleVoterPolicy(NEW_EPOCH, threshold), bytes(""), IRelay.ThresholdTooHigh.selector
        );
    }

    // The relayed policy must advance exactly one epoch; replay, regression, and skipping all reject.
    // EXPECT: PASS (proof).
    function check_modeOne_wrongNextEpoch_rejected(uint24 epoch) external {
        vm.assume(epoch != NEW_EPOCH);
        _assertRejectedAndRolledBack(
            _singleVoterPolicy(epoch, 60), bytes(""), IRelay.NotNextRewardEpoch.selector
        );
    }

    // The lower voter-count boundary is exclusive: zero voters is rejected before any weight scan.
    // EXPECT: PASS (proof).
    function check_modeOne_zeroVoters_rejected() external {
        _assertRejectedAndRolledBack(
            _metadata(0, NEW_EPOCH, 0), bytes(""), IRelay.SigningPolicyEmpty.selector
        );
    }

    // The upper voter-count boundary is inclusive at 300 and rejects 301 before scanning records.
    // This bounded property covers the rejecting edge; a 300-record success is outside this fixture's loop bound.
    // EXPECT: PASS (proof).
    function check_modeOne_tooManyVoters_rejected() external {
        _assertRejectedAndRolledBack(
            _metadata(MAX_VOTERS + 1, NEW_EPOCH, 0), bytes(""), IRelay.TooManyVoters.selector
        );
    }

    // A complete metadata prefix claiming one voter but containing a 21-byte voter record is exactly
    // one byte short of the required 65-byte policy and must fail the new-policy length check.
    // EXPECT: PASS (proof).
    function check_modeOne_shortNewPolicy_rejected() external {
        bytes memory shortPolicy = abi.encodePacked(
            _metadata(1, NEW_EPOCH, 60), NEW_VOTER_0, bytes1(0)
        );
        assert(shortPolicy.length == 64);
        _assertRejectedAndRolledBack(
            shortPolicy, bytes(""), IRelay.WrongSizeForNewSignPolicy.selector
        );
    }

    // The encoded uint16 weights can sum above uint16 max; 65535 + 1 is rejected before threshold use.
    // EXPECT: PASS (proof).
    function check_modeOne_totalWeightTooBig_rejected() external {
        _assertRejectedAndRolledBack(
            _twoVoterPolicy(32768, type(uint16).max, 1),
            bytes(""),
            IRelay.TotalWeightTooBig.selector
        );
    }

    // Mode-1 writes the new start/hash before checking aggregate weight. Zero signatures therefore reaches
    // the post-write NotEnoughWeight exit; transaction rollback must restore both tentative mapping writes.
    // EXPECT: PASS (proof).
    function check_modeOne_insufficientWeight_rollsBackWrites() external {
        _assertRejectedAndRolledBack(
            _singleVoterPolicy(NEW_EPOCH, 60),
            abi.encodePacked(uint16(0)),
            IRelay.NotEnoughWeight.selector
        );
    }

    // Every accepting in-band rotation has the exact new hash/start/epoch effects and preserves the
    // current policy plus governance identity. Paired reachability checks below make success non-vacuous.
    // EXPECT: PASS (proof).
    function check_modeOne_validRotationExactStateEffects(
        uint16 threshold,
        Sig calldata a,
        Sig calldata b,
        Sig calldata c
    )
        external
    {
        vm.assume(
            uint256(threshold) * THRESHOLD_BIPS >= uint256(NEW_WEIGHT) * MIN_THRESHOLD_BIPS
        );
        vm.assume(
            uint256(threshold) * THRESHOLD_BIPS <= uint256(NEW_WEIGHT) * MAX_THRESHOLD_BIPS
        );
        bytes memory newPolicy = _singleVoterPolicy(NEW_EPOCH, threshold);
        bytes32 oldHash = _policyHashAt(REWARD_EPOCH_ID);
        bytes32 implementationBefore = vm.load(address(relay), ERC1967Utils.IMPLEMENTATION_SLOT);
        (bool ok,) = _modeOneCall(newPolicy, _threeSigs(a, b, c));
        if (ok) {
            // Observe this slot before proxy getters so implementation corruption cannot prune success.
            assert(vm.load(address(relay), ERC1967Utils.IMPLEMENTATION_SLOT) == implementationBefore);
            (uint32 lastEpoch, uint32 lastStart) = relay.lastInitializedRewardEpochData();
            assert(lastEpoch == NEW_EPOCH);
            assert(lastStart == NEW_START);
            assert(relay.startingVotingRoundIds(NEW_EPOCH) == NEW_START);
            assert(_policyHashAt(NEW_EPOCH) == _signingPolicyHash(newPolicy));
            assert(_policyHashAt(REWARD_EPOCH_ID) == oldHash);
            assert(relay.startingVotingRoundIds(REWARD_EPOCH_ID) == START_VOTING_ROUND_ID);
            assert(relay.owner() == RELAY_TEST_GOVERNANCE);
            assert(relay.signingPolicySetter() == address(0));
        }
    }

    // Anti-vacuity at the inclusive 50% threshold boundary. EXPECT: COUNTEREXAMPLE.
    function check_reach_modeOne_validInstalls(Sig calldata a, Sig calldata b, Sig calldata c) external {
        (bool ok,) = _modeOneCall(_singleVoterPolicy(NEW_EPOCH, 50), _threeSigs(a, b, c));
        assert(!ok);
    }

    // Anti-vacuity at the inclusive 66% threshold boundary. EXPECT: COUNTEREXAMPLE.
    function check_reach_modeOne_maxThresholdInstalls(Sig calldata a, Sig calldata b, Sig calldata c)
        external
    {
        (bool ok,) = _modeOneCall(_singleVoterPolicy(NEW_EPOCH, 66), _threeSigs(a, b, c));
        assert(!ok);
    }

    // Anti-vacuity at the largest admitted total weight. Two positive weights sum exactly to 65535.
    // EXPECT: COUNTEREXAMPLE.
    function check_reach_modeOne_maxTotalWeightInstalls(
        Sig calldata a,
        Sig calldata b,
        Sig calldata c
    )
        external
    {
        bytes memory maxTotalPolicy = _twoVoterPolicy(32768, type(uint16).max - 1, 1);
        (bool ok,) = _modeOneCall(maxTotalPolicy, _threeSigs(a, b, c));
        assert(!ok);
    }
}
