// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// solhint-disable func-name-mixedcase

import {Relay} from "../../contracts/protocol/implementation/Relay.sol";
import {IRelay} from "../../contracts/userInterfaces/IRelay.sol";
import {RelayTestBase} from "../unit/protocol/implementation/Relay.t.sol";
import {deployRelay} from "../utils/RelayDeploy.sol";

// Shared concrete same-epoch, protocol-3 fixture: three distinct voters of weight 100,
// threshold 180. One valid record cannot finalize; two distinct valid records can.
// ECDSA is Halmos's uninterpreted precompile boundary, not a cryptographic proof.
abstract contract RelayGuardFVBase is RelayTestBase {
    bytes32 internal constant ROOT = keccak256("fv-parser-signature-guards");
    uint256 internal constant HALF_N =
        0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0;
    bytes internal policy;
    bytes internal message;

    struct Sig { uint8 v; bytes32 r; bytes32 s; }

    function setUp() public override {
        // Public toy-key addresses (keys 1, 2, 3) also permit concrete smoke tests.
        voters.push(0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf);
        voters.push(0x2B5AD5c4795c026514f8317c7a215E218DcCD6cF);
        voters.push(0x6813Eb9362372EEF6200f3b1dbC3f819671cBA69);
        policy = abi.encodePacked(
            uint16(3), REWARD_EPOCH_ID, START_VOTING_ROUND_ID, uint16(180), bytes32(SEED),
            voters[0], uint16(100), voters[1], uint16(100), voters[2], uint16(100)
        );
        relay = deployRelay(_initialConfig(_signingPolicyHash(policy)), address(0), IRelay(address(0)));
        message = _protocolMessage(3, START_VOTING_ROUND_ID, false, ROOT);
    }

    function _record(Sig memory sig, uint16 index) internal pure returns (bytes memory) {
        return abi.encodePacked(sig.v, sig.r, sig.s, index);
    }

    function _payload(bytes memory records) internal view returns (bytes memory) {
        return abi.encodePacked(Relay.relay.selector, policy, message, records);
    }

    function _canonical(Sig memory sig) internal pure {
        vm.assume(sig.v == 27 || sig.v == 28);
        vm.assume(uint256(sig.s) <= HALF_N);
    }

    function _valid(Sig memory sig, uint16 index) internal view {
        _canonical(sig);
        vm.assume(ecrecover(_ethSignedHash(message), sig.v, sig.r, sig.s) == voters[index]);
    }

    function _signed(uint256 key) internal view returns (Sig memory sig) {
        (sig.v, sig.r, sig.s) = vm.sign(key, _ethSignedHash(message));
    }

    // Sampled persistent rollback frame, not an assertion over every storage slot:
    // packed StateData, current/next policy hashes, current/next start-round mappings,
    // and the target protocol/round root. Layout is separately artifact-gated.
    function _snapshot() internal view returns (bytes32[6] memory state) {
        state[0] = vm.load(address(relay), bytes32(uint256(11)));
        state[1] = vm.load(address(relay), keccak256(abi.encode(uint256(REWARD_EPOCH_ID), uint256(0))));
        state[2] = vm.load(address(relay), keccak256(abi.encode(uint256(REWARD_EPOCH_ID + 1), uint256(0))));
        state[3] = bytes32(uint256(relay.startingVotingRoundIds(REWARD_EPOCH_ID)));
        state[4] = bytes32(uint256(relay.startingVotingRoundIds(REWARD_EPOCH_ID + 1)));
        state[5] = _root();
    }

    function _root() internal view returns (bytes32) {
        bytes32 protocolSlot = keccak256(abi.encode(uint256(3), uint256(1)));
        return vm.load(address(relay), keccak256(abi.encode(uint256(START_VOTING_ROUND_ID), protocolSlot)));
    }

    function _reject(bytes memory data, bytes4 expected) internal {
        bytes32[6] memory beforeState = _snapshot();
        (bool ok, bytes memory result) = address(relay).call(data);
        assert(!ok && result.length == 4 && bytes4(result) == expected);
        bytes32[6] memory afterState = _snapshot();
        assert(beforeState[0] == afterState[0] && beforeState[1] == afterState[1]);
        assert(beforeState[2] == afterState[2] && beforeState[3] == afterState[3]);
        assert(beforeState[4] == afterState[4] && beforeState[5] == afterState[5]);
        assert(!relay.isFinalized(3, START_VOTING_ROUND_ID));
    }

    function _accept(bytes memory data) internal returns (bool ok) {
        (ok, ) = address(relay).call(data);
        if (ok) {
            assert(_root() == ROOT);
            // Observe both getter success and its raw boolean encoding: a reverting or malformed
            // post-success response must fail an assertion instead of pruning the accepting path.
            (bool observed, bytes memory result) = address(relay).staticcall(
                abi.encodeCall(relay.isFinalized, (3, START_VOTING_ROUND_ID))
            );
            assert(observed && result.length == 32 && bytes32(result) == bytes32(uint256(1)));
        }
    }

    // All callers use literal lengths on explicit branches: no symbolic allocation or copy size.
    function _prefix(bytes memory data, uint256 length) internal pure returns (bytes memory) {
        assert(length <= data.length);
        assembly ("memory-safe") { mstore(data, length) }
        return data;
    }
}

// Fixed layout boundaries for the 109-byte admitted policy and 38-byte ordinary message.
// Checks deliberately do not impose an exact total length: complete trailing records/bytes
// need not be consumed after quorum. The signature fixture checks that early-return behavior.
contract RelayParserGuardsFV is RelayGuardFVBase {
    // EXPECT: PASS (proof).
    function check_parser_metadataTruncation_revertsExactly(bool lastByteMissing) external {
        bytes memory data = _payload(abi.encodePacked(uint16(0)));
        if (lastByteMissing) _reject(_prefix(data, 14), IRelay.InvalidSignPolicyMetadata.selector);
        else _reject(_prefix(data, 4), IRelay.InvalidSignPolicyMetadata.selector);
    }

    // EXPECT: PASS (proof).
    function check_parser_policyTruncation_revertsExactly(bool policyComplete) external {
        bytes memory data = _payload(abi.encodePacked(uint16(0)));
        if (policyComplete) _reject(_prefix(data, 113), IRelay.InvalidSignPolicyLength.selector);
        else _reject(_prefix(data, 112), IRelay.InvalidSignPolicyLength.selector);
    }

    // EXPECT: PASS (proof).
    function check_parser_messageTruncation_revertsExactly(bool lastByteMissing) external {
        bytes memory data = _payload(abi.encodePacked(uint16(0)));
        if (lastByteMissing) _reject(_prefix(data, 150), IRelay.TooShortMessage.selector);
        else _reject(_prefix(data, 114), IRelay.TooShortMessage.selector);
    }

    // EXPECT: PASS (proof).
    function check_parser_signatureCountTruncation_revertsExactly(bool oneBytePresent) external {
        bytes memory data = _payload(abi.encodePacked(uint16(0)));
        if (oneBytePresent) _reject(_prefix(data, 152), IRelay.NoSignatureCount.selector);
        else _reject(_prefix(data, 151), IRelay.NoSignatureCount.selector);
    }

    // All declared uint16 counts 3..65535 with exactly two complete records.
    // Length checking must precede any inspection of these arbitrary record fields.
    // EXPECT: PASS (proof).
    function check_parser_declaredCountExceedsRecords_revertsExactly(uint16 count, Sig calldata a, Sig calldata b)
        external
    {
        vm.assume(count > 2);
        _reject(_payload(abi.encodePacked(count, _record(a, 0), _record(b, 1))),
            IRelay.NotEnoughSignatures.selector);
    }

    // EXPECT: PASS (proof).
    function check_parser_recordTruncation_revertsExactly(bool twoRecords, Sig calldata a, Sig calldata b) external {
        if (twoRecords) {
            bytes memory data = _payload(abi.encodePacked(uint16(2), _record(a, 0), _record(b, 1)));
            _reject(_prefix(data, 286), IRelay.NotEnoughSignatures.selector);
        } else {
            bytes memory data = _payload(abi.encodePacked(uint16(1), _record(a, 0)));
            _reject(_prefix(data, 219), IRelay.NotEnoughSignatures.selector);
        }
    }

    // EXPECT: PASS (proof).
    function check_parser_zeroRecords_revertsExactly() external {
        _reject(_payload(abi.encodePacked(uint16(0))), IRelay.NotEnoughWeight.selector);
    }

    // Full layout and exactly two valid records can finalize.
    // EXPECT: COUNTEREXAMPLE (reachability control).
    function check_reach_parser_completeLayoutAccepts(Sig calldata a, Sig calldata b) external {
        _valid(a, 0);
        _valid(b, 1);
        assert(!_accept(_payload(abi.encodePacked(uint16(2), _record(a, 0), _record(b, 1)))));
    }

    function test_fv_parserBoundariesAndAcceptance() external {
        Sig memory a = _signed(1);
        Sig memory b = _signed(2);
        bytes memory full = _payload(abi.encodePacked(uint16(2), _record(a, 0), _record(b, 1)));
        _reject(_prefix(bytes.concat(full), 14), IRelay.InvalidSignPolicyMetadata.selector);
        _reject(_prefix(bytes.concat(full), 113), IRelay.InvalidSignPolicyLength.selector);
        _reject(_prefix(bytes.concat(full), 150), IRelay.TooShortMessage.selector);
        _reject(_prefix(bytes.concat(full), 152), IRelay.NoSignatureCount.selector);
        _reject(_prefix(bytes.concat(full), 286), IRelay.NotEnoughSignatures.selector);
        assert(_accept(full));
    }
}
