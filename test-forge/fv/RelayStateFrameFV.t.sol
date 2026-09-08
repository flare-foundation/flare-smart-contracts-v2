// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// solhint-disable func-name-mixedcase

import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {Relay} from "../../contracts/protocol/implementation/Relay.sol";
import {IRelay} from "../../contracts/userInterfaces/IRelay.sol";
import {IIRelay} from "../../contracts/protocol/interface/IIRelay.sol";
import {RelayTestBase} from "../unit/protocol/implementation/Relay.t.sol";
// solhint-disable-next-line no-unused-import
import {deployRelay, RELAY_TEST_GOVERNANCE} from "../utils/RelayDeploy.sol";

/**
 * Bounded storage-frame properties for accepting raw relay() calls.
 *
 * These checks complement the existing write-once and random-binding properties: they assert the exact
 * target write while sampling unrelated policy/root/random storage and sampled governance fields. The
 * private-slot observations are deliberately tied to relay_storage_layout.json at this exact deployment
 * snapshot; the artifact/layout gate rejects a drift before these properties can be release evidence.
 *
 * Both paths use a concrete three-voter policy and three symbolic signatures. The random path additionally
 * folds one Merkle sibling, so every loop remains below halmos.toml's bound of six.
 */
contract RelayStateFrameFV is RelayTestBase {
    bytes internal policy;

    uint256 internal constant POLICY_HASH_MAPPING_SLOT = 0;
    uint256 internal constant MERKLE_ROOTS_MAPPING_SLOT = 1;
    uint256 internal constant STARTING_ROUND_MAPPING_SLOT = 2;
    uint256 internal constant SECURE_RANDOM_MAPPING_SLOT = 10;
    uint256 internal constant STATE_DATA_SLOT = 11;
    uint256 internal constant RANDOM_NUMBER_MAPPING_SLOT = 12;

    uint256 internal constant FRAME_VOTERS = 3;
    uint8 internal constant ORDINARY_PROTOCOL_ID = 3;
    uint8 internal constant UNRELATED_PROTOCOL_ID = 4;
    uint32 internal constant ORDINARY_ROUND = START_VOTING_ROUND_ID;
    uint32 internal constant RANDOM_ROUND = START_VOTING_ROUND_ID + 1;
    uint32 internal constant UNRELATED_ROUND = START_VOTING_ROUND_ID + 9;
    uint24 internal constant UNRELATED_EPOCH = 0;
    address internal constant SAMPLED_ACCOUNT = address(uint160(0xBEEF));
    bytes32 internal constant ORDINARY_ROOT = keccak256("frame-ordinary-root");
    bytes32 internal constant RANDOM_SIBLING = keccak256("frame-random-sibling");
    uint256 internal constant RANDOM_VALUE = 0xA11CE;
    bytes32 internal constant UNRELATED_POLICY_HASH = keccak256("frame-unrelated-policy");
    uint256 internal constant UNRELATED_POLICY_START = 111;
    bytes32 internal constant UNRELATED_ROOT = keccak256("frame-unrelated-root");
    bytes32 internal constant UNRELATED_RANDOM_ROOT = keccak256("frame-unrelated-random-root");
    uint256 internal constant UNRELATED_RANDOM_VALUE = 0xB0B;
    uint256 internal constant SAMPLED_PROTOCOL_FEE = 777;

    // stateData fields that the random success path is allowed to change.
    uint256 internal constant RANDOM_ROUND_MASK = uint256(type(uint32).max) << 112;
    uint256 internal constant LIVE_SECURE_MASK = uint256(0xff) << 144;
    uint256 internal constant RANDOM_STATE_MASK = RANDOM_ROUND_MASK | LIVE_SECURE_MASK;

    struct Sig {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    function setUp() public override {
        for (uint256 i = 0; i < FRAME_VOTERS; i++) {
            voters.push(address(uint160(0x1001 + i)));
            weights.push(WEIGHT); // 300 > threshold 260
            pks.push(0);
        }
        policy = _buildSigningPolicy(REWARD_EPOCH_ID, START_VOTING_ROUND_ID, THRESHOLD, SEED);
        relay = deployRelay(_initialConfig(_signingPolicyHash(policy)), address(0), IRelay(address(0)));

        // Populate sampled, unrelated state with nonzero sentinels. Mapping sentinels are written through
        // the layout-bound test observer; fee/exemption/timelock state is established through production
        // owner entry points so callback-independent governance preservation is checked from a live shape.
        vm.store(
            address(relay),
            _mapLocation(UNRELATED_EPOCH, POLICY_HASH_MAPPING_SLOT),
            UNRELATED_POLICY_HASH
        );
        vm.store(
            address(relay),
            _mapLocation(UNRELATED_EPOCH, STARTING_ROUND_MAPPING_SLOT),
            bytes32(UNRELATED_POLICY_START)
        );
        _storeMerkleRoot(UNRELATED_PROTOCOL_ID, UNRELATED_ROUND, UNRELATED_ROOT);
        _storeMerkleRoot(RANDOM_PROTOCOL_ID, UNRELATED_ROUND, UNRELATED_RANDOM_ROOT);
        vm.store(
            address(relay),
            _mapLocation(UNRELATED_ROUND, RANDOM_NUMBER_MAPPING_SLOT),
            bytes32(UNRELATED_RANDOM_VALUE)
        );
        uint256 unrelatedSecureBit = uint256(1) << (255 - (uint256(UNRELATED_ROUND) % 256));
        vm.store(
            address(relay),
            _mapLocation(uint256(UNRELATED_ROUND) / 256, SECURE_RANDOM_MAPPING_SLOT),
            bytes32(unrelatedSecureBit)
        );

        IRelay.FeeConfig[] memory fees = new IRelay.FeeConfig[](1);
        fees[0] = IRelay.FeeConfig({protocolId: 7, fee: SAMPLED_PROTOCOL_FEE});
        vm.prank(RELAY_TEST_GOVERNANCE);
        relay.setProtocolFees(address(0), fees);

        IIRelay.FeeExemption[] memory exemptions = new IIRelay.FeeExemption[](1);
        exemptions[0] = IIRelay.FeeExemption({account: SAMPLED_ACCOUNT, exempt: true});
        vm.prank(RELAY_TEST_GOVERNANCE);
        relay.setFeeExemptions(exemptions);

        // The first update is immediate at duration zero. The second queues a nonzero sampled entry.
        vm.prank(RELAY_TEST_GOVERNANCE);
        relay.setTimelockDuration(1 days);
        vm.prank(RELAY_TEST_GOVERNANCE);
        relay.setTimelockDuration(1);
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

    function _mapLocation(uint256 key, uint256 slot) internal pure returns (bytes32) {
        return keccak256(abi.encode(key, slot));
    }

    function _policyHashAt(uint256 epoch) internal view returns (bytes32) {
        return vm.load(address(relay), _mapLocation(epoch, POLICY_HASH_MAPPING_SLOT));
    }

    function _merkleRootAt(uint256 protocolId, uint256 votingRoundId) internal view returns (bytes32) {
        bytes32 protocolLocation = _mapLocation(protocolId, MERKLE_ROOTS_MAPPING_SLOT);
        return vm.load(address(relay), keccak256(abi.encode(votingRoundId, protocolLocation)));
    }

    function _storeMerkleRoot(uint256 protocolId, uint256 votingRoundId, bytes32 value) internal {
        bytes32 protocolLocation = _mapLocation(protocolId, MERKLE_ROOTS_MAPPING_SLOT);
        vm.store(address(relay), keccak256(abi.encode(votingRoundId, protocolLocation)), value);
    }

    function _randomNumberAt(uint256 votingRoundId) internal view returns (uint256) {
        return uint256(vm.load(address(relay), _mapLocation(votingRoundId, RANDOM_NUMBER_MAPPING_SLOT)));
    }

    function _secureRandomWord(uint256 votingRoundId) internal view returns (uint256) {
        uint256 wordIndex = votingRoundId / 256;
        return uint256(vm.load(address(relay), _mapLocation(wordIndex, SECURE_RANDOM_MAPPING_SLOT)));
    }

    function _stateDataWord() internal view returns (uint256) {
        return uint256(vm.load(address(relay), bytes32(STATE_DATA_SLOT)));
    }

    function _governanceFingerprint() internal view returns (bytes32) {
        bytes memory sampledQueuedCall = abi.encodeCall(relay.setTimelockDuration, (1));
        // Observe the getter through a non-reverting boundary. If a target relay accidentally deletes
        // the sampled queue entry, the getter returns TimelockInvalidSelector; hashing success and raw
        // returndata turns that into a frame mismatch instead of pruning the accepting test path.
        (bool queueObservationOk, bytes memory queueObservation) = address(relay).staticcall(
            abi.encodeCall(relay.getExecuteTimelockedCallTimestamp, (sampledQueuedCall))
        );
        return keccak256(
            abi.encode(
                relay.owner(),
                relay.implementation(),
                relay.signingPolicySetter(),
                relay.sourceChainId(),
                relay.feeCollectionAddress(),
                relay.feeToken(),
                relay.protocolFee(7),
                relay.feeExemptAddress(SAMPLED_ACCOUNT),
                address(relay.oldRelay()),
                relay.initialRewardEpochId(),
                relay.startingVotingRoundIdForInitialRewardEpochId(),
                relay.getTimelockDurationSeconds(),
                queueObservationOk,
                keccak256(queueObservation)
            )
        );
    }

    function _policyFingerprint() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                _policyHashAt(REWARD_EPOCH_ID),
                relay.startingVotingRoundIds(REWARD_EPOCH_ID),
                _policyHashAt(UNRELATED_EPOCH),
                relay.startingVotingRoundIds(UNRELATED_EPOCH)
            )
        );
    }

    function _ordinaryCall(bytes memory signatures) internal returns (bool ok) {
        bytes memory message = abi.encodePacked(
            ORDINARY_PROTOCOL_ID, ORDINARY_ROUND, uint8(0), ORDINARY_ROOT
        );
        (ok,) = address(relay).call(
            abi.encodePacked(Relay.relay.selector, policy, message, signatures)
        );
    }

    function _sortedPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }

    function _randomLeaf() internal pure returns (bytes32) {
        return keccak256(abi.encode(uint256(RANDOM_ROUND), RANDOM_VALUE, uint256(1)));
    }

    function _randomRoot() internal pure returns (bytes32) {
        return _sortedPair(_randomLeaf(), RANDOM_SIBLING);
    }

    function _randomCall(bytes memory signatures) internal returns (bool ok) {
        bytes memory message = abi.encodePacked(
            RANDOM_PROTOCOL_ID, RANDOM_ROUND, uint8(1), _randomRoot()
        );
        bytes memory trailer = abi.encodePacked(RANDOM_VALUE, RANDOM_SIBLING);
        (ok,) = address(relay).call(
            abi.encodePacked(Relay.relay.selector, policy, message, signatures, trailer)
        );
    }

    // A successful ordinary protocol relay writes its exact target root and preserves the sampled nonzero
    // unrelated roots, policy records, random storage, packed stateData, and governance/proxy fields.
    // EXPECT: PASS (proof).
    function check_stateFrame_ordinaryRelayPreservesUnrelatedState(
        Sig calldata a,
        Sig calldata b,
        Sig calldata c
    )
        external
    {
        bytes32 implementationBefore = vm.load(address(relay), ERC1967Utils.IMPLEMENTATION_SLOT);
        bytes32 governanceBefore = _governanceFingerprint();
        bytes32 policiesBefore = _policyFingerprint();
        uint256 stateBefore = _stateDataWord();
        bytes32 unrelatedRootBefore = _merkleRootAt(UNRELATED_PROTOCOL_ID, UNRELATED_ROUND);
        bytes32 unrelatedRandomRootBefore = _merkleRootAt(RANDOM_PROTOCOL_ID, UNRELATED_ROUND);
        uint256 randomValueBefore = _randomNumberAt(ORDINARY_ROUND);
        uint256 unrelatedRandomBefore = _randomNumberAt(UNRELATED_ROUND);
        uint256 secureWordBefore = _secureRandomWord(ORDINARY_ROUND);

        bool ok = _ordinaryCall(_threeSigs(a, b, c));
        if (ok) {
            // Check without calling the proxy: a corrupted implementation must fail this assertion,
            // not make a later getter revert and prune the accepting path from the symbolic proof.
            assert(vm.load(address(relay), ERC1967Utils.IMPLEMENTATION_SLOT) == implementationBefore);
            assert(_merkleRootAt(ORDINARY_PROTOCOL_ID, ORDINARY_ROUND) == ORDINARY_ROOT);
            assert(_merkleRootAt(UNRELATED_PROTOCOL_ID, UNRELATED_ROUND) == unrelatedRootBefore);
            assert(_merkleRootAt(RANDOM_PROTOCOL_ID, UNRELATED_ROUND) == unrelatedRandomRootBefore);
            assert(_randomNumberAt(ORDINARY_ROUND) == randomValueBefore);
            assert(_randomNumberAt(UNRELATED_ROUND) == unrelatedRandomBefore);
            assert(_secureRandomWord(ORDINARY_ROUND) == secureWordBefore);
            assert(_stateDataWord() == stateBefore);
            assert(_policyFingerprint() == policiesBefore);
            assert(_governanceFingerprint() == governanceBefore);
        }
    }

    // Anti-vacuity for the exact ordinary-path frame fixture. EXPECT: COUNTEREXAMPLE.
    function check_reach_stateFrame_ordinaryRelaySucceeds(
        Sig calldata a,
        Sig calldata b,
        Sig calldata c
    )
        external
    {
        assert(!_ordinaryCall(_threeSigs(a, b, c)));
    }

    // A successful secure-random relay updates its target root/value/quality bit and the two live random
    // fields inside stateData while every other packed field and each sampled unrelated item remains.
    // EXPECT: PASS (proof).
    function check_stateFrame_randomRelayPreservesUnrelatedState(
        Sig calldata a,
        Sig calldata b,
        Sig calldata c
    )
        external
    {
        bytes32 implementationBefore = vm.load(address(relay), ERC1967Utils.IMPLEMENTATION_SLOT);
        bytes32 governanceBefore = _governanceFingerprint();
        bytes32 policiesBefore = _policyFingerprint();
        uint256 stateBefore = _stateDataWord();
        bytes32 unrelatedRootBefore = _merkleRootAt(UNRELATED_PROTOCOL_ID, UNRELATED_ROUND);
        bytes32 unrelatedRandomRootBefore = _merkleRootAt(RANDOM_PROTOCOL_ID, UNRELATED_ROUND);
        uint256 unrelatedRandomBefore = _randomNumberAt(UNRELATED_ROUND);
        uint256 secureWordBefore = _secureRandomWord(RANDOM_ROUND);

        bool ok = _randomCall(_threeSigs(a, b, c));
        if (ok) {
            assert(vm.load(address(relay), ERC1967Utils.IMPLEMENTATION_SLOT) == implementationBefore);
            uint256 stateAfter = _stateDataWord();
            uint256 secureBit = uint256(1) << (255 - (uint256(RANDOM_ROUND) % 256));
            assert(_merkleRootAt(RANDOM_PROTOCOL_ID, RANDOM_ROUND) == _randomRoot());
            assert(_randomNumberAt(RANDOM_ROUND) == RANDOM_VALUE);
            assert(_secureRandomWord(RANDOM_ROUND) == (secureWordBefore | secureBit));
            assert(uint32(stateAfter >> 112) == RANDOM_ROUND);
            assert(uint8(stateAfter >> 144) == 1);
            assert((stateAfter & ~RANDOM_STATE_MASK) == (stateBefore & ~RANDOM_STATE_MASK));
            assert(_merkleRootAt(UNRELATED_PROTOCOL_ID, UNRELATED_ROUND) == unrelatedRootBefore);
            assert(_merkleRootAt(RANDOM_PROTOCOL_ID, UNRELATED_ROUND) == unrelatedRandomRootBefore);
            assert(_randomNumberAt(UNRELATED_ROUND) == unrelatedRandomBefore);
            assert(_policyFingerprint() == policiesBefore);
            assert(_governanceFingerprint() == governanceBefore);

            (uint256 liveValue, bool liveSecure, uint256 liveTimestamp) = relay.getRandomNumber();
            assert(liveValue == RANDOM_VALUE);
            assert(liveSecure);
            assert(
                liveTimestamp == uint256(FIRST_VOTING_ROUND_TS)
                    + (uint256(RANDOM_ROUND) + 1) * uint256(VOTING_EPOCH_DURATION)
            );
        }
    }

    // Anti-vacuity for the exact one-node secure-random frame fixture. EXPECT: COUNTEREXAMPLE.
    function check_reach_stateFrame_randomRelaySucceeds(
        Sig calldata a,
        Sig calldata b,
        Sig calldata c
    )
        external
    {
        assert(!_randomCall(_threeSigs(a, b, c)));
    }
}
