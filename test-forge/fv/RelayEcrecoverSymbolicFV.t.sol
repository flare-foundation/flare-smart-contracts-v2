// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// solhint-disable func-name-mixedcase

// OP-1 — symbolic internalization of the ecrecover-precompile failure ABI.
//
// Companion to RelayEcrecoverABI.t.sol (which pins the SAME failure ABI on the REAL EVM as a `forge test`).
// The gap this file closes: Halmos models the `0x01` precompile as a TOTAL function that always returns a
// well-formed 32-byte address (`returndatasize() == 32` always), so the symbolic suite could not itself
// reach the bad-signature failure mode — the precompile returns SUCCESS with EMPTY data
// (`returndatasize() == 0`) and leaves the caller's output buffer UNTOUCHED (stale). That is the behaviour a
// past bug wrongly assumed to revert. Relay's raw-assembly ecrecover is made safe by three guards
// (Relay.sol:1283-1302): staticcall success, `returndatasize() == 32`, and recovered-signer != 0.
//
// To reach the empty-return branch UNDER HALMOS we call a MOCK (`EcrecoverFailureABIMock`) that reproduces
// the precompile's exact return ABI — deployed as ordinary code, so Halmos executes both its branches,
// unlike the built-in `0x01`. We then prove, symbolically and over ALL stale-buffer contents / recovered
// words, that Relay's guard:
//   (i)   rejects an EMPTY return (bad signature), whatever stale bytes sit in the output slot;
//   (ii)  rejects a zero signer (a well-formed 32-byte zero return);
//   (iii) when it accepts, uses the precompile's FRESH return, never the stale buffer.
// This is the "symbolic-model internalization" of OP-1 (claims ledger L10 §10.5): the returndatasize/
// zero-signer guards are now proven load-bearing against the true precompile ABI, not only regression-tested.
//
// The harness mirrors the guard as the boolean conjunction of its three checks; the deployed contract
// reverts (fail-closed) on any failing check, which is at least as strong as "not accepted".
//
// RUN (CI gate auto-discovers `check_`): HALMOS=halmos python3 test-forge/fv/verify_fv.py
//
// New to Halmos? See test-forge/fv/README.md §2 — a `check_` function is a ∀-proof over its symbolic
// arguments; `vm.assume` is a hypothesis, `assert` is the goal, and `check_reach_*` is the anti-vacuity
// control that verify_fv.py requires to be REFUTED by a counterexample.

/// Reproduces the ecrecover precompile's return ABI. `mode == 0` => bad signature: SUCCESS + EMPTY return
/// (`returndatasize()` 0, output buffer left untouched). `mode != 0` => good: return the 32-byte `word`
/// (the recovered signer), overwriting the buffer.
contract EcrecoverFailureABIMock {
    fallback() external {
        assembly {
            // calldata layout: [mode(32) | word(32)]
            let mode := calldataload(0)
            if iszero(mode) {
                return(0, 0) // bad-sig ABI: success, EMPTY return -> caller's out buffer stays stale
            }
            mstore(0, calldataload(32))
            return(0, 0x20) // good: fresh 32-byte signer
        }
    }
}

contract RelayEcrecoverSymbolicFV {
    EcrecoverFailureABIMock internal prec;

    function setUp() public {
        prec = new EcrecoverFailureABIMock();
    }

    /// Relay's guarded recovery (Relay.sol:1283-1302): staticcall the precompile with the output slot
    /// pre-seeded to the (attacker-controlled) `stale` value, then accept only if the call SUCCEEDED and
    /// returned EXACTLY 32 bytes and the recovered word is NON-ZERO. Returns (accepted, word-read-from-slot).
    function _guardedRecover(uint256 mode, bytes32 word, bytes32 stale)
        internal
        returns (bool accepted, bytes32 got)
    {
        address p = address(prec);
        assembly {
            let m := mload(0x40)
            mstore(m, mode)
            mstore(add(m, 0x20), word)
            let outPtr := add(m, 0x40)
            mstore(outPtr, stale) // seed the stale output buffer
            let ok := staticcall(gas(), p, m, 0x40, outPtr, 0x20)
            accepted := and(and(ok, eq(returndatasize(), 0x20)), iszero(iszero(mload(outPtr))))
            got := mload(outPtr)
        }
    }

    // (i) PROOF: a bad signature (empty return) is NEVER accepted — for ANY stale buffer or would-be word.
    // EXPECT: PASS (proof).
    function check_emptyReturn_rejected(bytes32 word, bytes32 stale) external {
        (bool accepted,) = _guardedRecover(0, word, stale); // mode 0 => empty return
        assert(!accepted);
    }

    // (ii) PROOF: a zero signer (a well-formed 32-byte zero return) is rejected, for ANY stale buffer.
    // EXPECT: PASS (proof).
    function check_zeroSigner_rejected(bytes32 stale) external {
        (bool accepted,) = _guardedRecover(1, bytes32(0), stale); // mode 1, recovered word 0
        assert(!accepted);
    }

    // (iii) PROOF: when the guard accepts, it uses the precompile's FRESH return (never the stale buffer),
    //       and accepts iff that fresh signer is non-zero.
    // EXPECT: PASS (proof).
    function check_accepted_usesFreshReturn_notStale(bytes32 word, bytes32 stale) external {
        (bool accepted, bytes32 got) = _guardedRecover(1, word, stale); // mode 1 => fresh return `word`
        assert(got == word); // the fresh return overwrote the stale buffer
        assert(accepted == (word != bytes32(0)));
    }

    // REACHABILITY / non-vacuity control (verify_fv.py requires a `reach` check to be REFUTED by a CEX):
    // the accept path IS live — a genuine non-zero signer is accepted. Asserting !accepted must fail, so
    // Halmos returns a witness (word != 0), proving the proofs above are not vacuously true.
    // EXPECT: COUNTEREXAMPLE (reachability control).
    function check_reach_validSigner_accepted(bytes32 word, bytes32 stale) external {
        (bool accepted,) = _guardedRecover(1, word, stale);
        assert(!accepted); // EXPECT: refuted (CEX word != 0) -> accept path reachable
    }
}
