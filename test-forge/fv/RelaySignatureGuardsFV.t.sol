// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// solhint-disable func-name-mixedcase

import {IRelay} from "../../contracts/userInterfaces/IRelay.sol";
import {RelayGuardFVBase} from "./RelayParserGuardsFV.t.sol";

// The first valid record has weight 100 <= 180, so every second-record rejection
// below is actually reached. Indices range over uint16; valid indices are 0..2.
// Matching-recovery hypotheses expose the desired guard without changing the
// precompile model. Separate accepting controls check that these premises are satisfiable.
contract RelaySignatureGuardsFV is RelayGuardFVBase {
    // EXPECT: PASS (proof).
    function check_signature_firstIndexOutOfRange_revertsExactly(uint16 index, Sig calldata a) external {
        vm.assume(index >= 3);
        _reject(_payload(abi.encodePacked(uint16(1), _record(a, index))), IRelay.IndexOutOfRange.selector);
    }

    // EXPECT: PASS (proof).
    function check_signature_reachedIndexOutOfRange_revertsExactly(
        uint16 previous, uint16 index, Sig calldata a, Sig calldata b
    ) external {
        vm.assume(previous < 3);
        vm.assume(index >= 3);
        // Exhaustive valid-prefix partition: Halmos requires a concrete CALLDATACOPY
        // voter offset. The invalid index remains symbolic across its full uint16 domain.
        if (previous == 0) _reachedOutOfRange(0, index, a, b);
        else if (previous == 1) _reachedOutOfRange(1, index, a, b);
        else _reachedOutOfRange(2, index, a, b);
    }

    function _reachedOutOfRange(uint16 previous, uint16 index, Sig memory a, Sig memory b) internal {
        _valid(a, previous);
        _reject(_payload(abi.encodePacked(uint16(2), _record(a, previous), _record(b, index))),
            IRelay.IndexOutOfRange.selector);
    }

    // EXPECT: PASS (proof).
    function check_signature_reachedIndexDecreases_revertsExactly(
        uint16 previous, uint16 index, Sig calldata a, Sig calldata b
    ) external {
        vm.assume(previous < 3 && index < previous);
        // These are all three decreasing pairs in the three-voter policy; no pair is excluded.
        if (previous == 1) _reachedDecreasing(1, 0, a, b);
        else if (index == 0) _reachedDecreasing(2, 0, a, b);
        else _reachedDecreasing(2, 1, a, b);
    }

    function _reachedDecreasing(uint16 previous, uint16 index, Sig memory a, Sig memory b) internal {
        _valid(a, previous);
        _reject(_payload(abi.encodePacked(uint16(2), _record(a, previous), _record(b, index))),
            IRelay.IndexOutOfOrder.selector);
    }

    // EXPECT: PASS (proof).
    function check_signature_reachedWrongSigner_revertsExactly(uint16 index, Sig calldata a, Sig calldata b)
        external
    {
        vm.assume(index > 0 && index < 3);
        if (index == 1) _reachedWrongSigner(1, a, b);
        else _reachedWrongSigner(2, a, b);
    }

    function _reachedWrongSigner(uint16 index, Sig memory a, Sig memory b) internal {
        _valid(a, 0);
        _canonical(b);
        address recovered = ecrecover(_ethSignedHash(message), b.v, b.r, b.s);
        vm.assume(recovered != address(0) && recovered != voters[index]);
        _reject(_payload(abi.encodePacked(uint16(2), _record(a, 0), _record(b, index))),
            IRelay.WrongSignature.selector);
    }

    // Complete declared layout is checked up front, but the third record is not
    // authenticated after the first two valid records already supply weight 200 > 180.
    // EXPECT: PASS (proof).
    function check_signature_earlyQuorumIgnoresTrailingIndex(
        uint16 index, Sig calldata a, Sig calldata b, Sig calldata trailing
    ) external {
        vm.assume(index >= 3);
        _valid(a, 0);
        _valid(b, 1);
        assert(_accept(_payload(abi.encodePacked(
            uint16(3), _record(a, 0), _record(b, 1), _record(trailing, index)
        ))));
    }

    // Identical matching-recovery premises permit quorum.
    // EXPECT: COUNTEREXAMPLE (reachability control).
    function check_reach_signature_validQuorumAccepts(Sig calldata a, Sig calldata b) external {
        _valid(a, 0);
        _valid(b, 1);
        assert(!_accept(_payload(abi.encodePacked(uint16(2), _record(a, 0), _record(b, 1)))));
    }

    // The complete three-record early-return path is reachable.
    // EXPECT: COUNTEREXAMPLE (reachability control).
    function check_reach_signature_earlyQuorumAccepts(Sig calldata a, Sig calldata b, Sig calldata trailing) external {
        _valid(a, 0);
        _valid(b, 1);
        assert(!_accept(_payload(abi.encodePacked(
            uint16(3), _record(a, 0), _record(b, 1), _record(trailing, 3)
        ))));
    }

    function test_fv_signatureReachedGuardsAndEarlyReturn() external {
        Sig memory a = _signed(1);
        Sig memory b = _signed(2);
        _reject(_payload(abi.encodePacked(uint16(1), _record(a, 3))), IRelay.IndexOutOfRange.selector);
        _reject(_payload(abi.encodePacked(uint16(2), _record(a, 0), _record(b, 65535))),
            IRelay.IndexOutOfRange.selector);
        _reject(_payload(abi.encodePacked(uint16(2), _record(b, 1), _record(a, 0))),
            IRelay.IndexOutOfOrder.selector);
        _reject(_payload(abi.encodePacked(uint16(2), _record(a, 0), _record(a, 1))),
            IRelay.WrongSignature.selector);
        assert(_accept(_payload(abi.encodePacked(uint16(3), _record(a, 0), _record(b, 1), _record(a, 65535)))));
    }
}
