// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// solhint-disable func-name-mixedcase

// ============================================================================================
//  Relay.sol random-pointer MONOTONICITY — UNBOUNDED (∀ sequence of relay() calls) proof for
//  Kontrol, via k-induction (base + single fully-symbolic relay step).
//
//  Relay tracks a "live" pointer = the latest voting round for which a random has been relayed
//  (cf. lastInitializedVotingRound / the latest-relayed round). A relay() for round R stores its
//  random and advances the pointer IFF R is newer; a relay for an older/equal round does NOT move
//  it. PROPERTY (unbounded over the relay sequence): the live pointer is monotone non-decreasing —
//  a stale relay can never regress it, and the pointer after K relays is the max of all relayed
//  rounds. This is the unbounded counterpart of the bounded Halmos RelayRandomMonotonicityFV
//  (which checked staleDoesNotRegress / advances / bothHistoricalRetained over a 2-call sequence).
//
//  INVARIANT (per step):  newLive >= live  AND  the update rule is exactly max(live, R).
//  k-INDUCTION: the step is over a fully-symbolic (live, R), so discharging it once covers every
//  position in any relay sequence => live is monotone for all K. (Same honest caveats as the
//  signature-loop harness: meta-level induction composition; faithful Solidity model of the rule;
//  bytecode side at small K covered by the Halmos suite.)
//
//  LIVENESS BOUNDARY: this model uses uint256 and proves only monotonicity. Production stores a uint32
//  pointer; accepting type(uint32).max makes the pointer terminal and the current getter's pre-cast +1
//  overflow. Monotonicity is therefore not a proof of current-random readability or future progress.
// ============================================================================================

interface IVm { function assume(bool) external; }

contract RelayRandomMonoFV {
    // solhint-disable-next-line const-name-snakecase
    IVm internal constant vm = IVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    // One relay()'s update rule for the live (latest-relayed) round pointer:
    // advance to r iff strictly newer, else keep (stale relay does not regress). == max(live, r).
    function _advance(uint256 live, uint256 r) internal pure returns (uint256) {
        return r > live ? r : live;
    }

    // ---- BASE: at sequence start the monotone-so-far invariant holds (pointer hasn't decreased). ----
    function prove_base_monotone(uint256 live0) external pure {
        assert(_advance(live0, live0) >= live0); // reflexive at init: no regress from the start
    }

    // ---- STEP: one relay preserves monotonicity for ANY current pointer and ANY relayed round. ----
    function prove_step_monotone(uint256 live, uint256 r) external pure {
        assert(_advance(live, r) >= live); // pointer never regresses => monotone for all K
    }

    // ---- STALE relay (older/equal round) does NOT move the pointer. ----
    function prove_step_staleDoesNotRegress(uint256 live, uint256 r) external {
        vm.assume(r <= live);
        assert(_advance(live, r) == live);
    }

    // ---- ADVANCE relay (strictly newer round) moves the pointer exactly to R. ----
    function prove_step_advancesToNewer(uint256 live, uint256 r) external {
        vm.assume(r > live);
        assert(_advance(live, r) == r);
    }

    // ================= ANTI-VACUITY CONTROLS (each MUST counterexample) =================

    // Advancing IS reachable (pointer can strictly increase) => "never advances" claim is false.
    function prove_reach_canAdvance(uint256 live, uint256 r) external {
        vm.assume(r > live);
        assert(_advance(live, r) <= live); // FALSE => CEX (advance path live)
    }

    // Staying IS reachable (a stale relay keeps the pointer) => "always advances" claim is false.
    function prove_reach_canStayStale(uint256 live, uint256 r) external {
        vm.assume(r <= live);
        assert(_advance(live, r) > live); // FALSE => CEX (stale path live)
    }
}
