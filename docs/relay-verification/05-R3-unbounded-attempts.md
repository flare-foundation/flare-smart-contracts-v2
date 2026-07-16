# L5 — R3: unbounded attempts (Kontrol & Certora) and the assembly wall

> **What you get from this level.** The two attempts to cross the **induction barrier** — Kontrol/KEVM and
> Certora — told honestly: where they *succeeded*, where they hit the **assembly barrier**, and why the
> walls are a genuine finding rather than a tooling failure. This is the rung that motivated theorem
> proving (R4). It is deliberately candid: an audit deserves the negative results, not just the wins.

---

## 5.1 Kontrol/KEVM — ∀K by k-induction (a real success, on a model)

**Tool:** Kontrol `v1.0.248` over KEVM (`K v7.1.334`), fully pinned (see §5.4). **Artifacts:**
`test-forge/fv/kontrol/` — [`RelaySigLoopFV.t.sol`](../../test-forge/fv/kontrol/RelaySigLoopFV.t.sol), [`RelayRandomMonoFV.t.sol`](../../test-forge/fv/kontrol/RelayRandomMonoFV.t.sol), `run.sh`, `Dockerfile`,
`foundry.toml`, `README.md`.

Kontrol proves properties by **[k-induction](CONCEPTS.md#5-what-is-k-induction)** — it discharges a base case and an inductive step whose
pre-state is *fully symbolic*, so a single step covers every iteration count. This crosses the induction
barrier in the **K dimension** (the number of signatures / relays), which is the genuinely unbounded one.

**What it proved (verdicts, Kontrol 1.0.248)** — the full inventory: **13 `prove_` functions** (7 in
`RelaySigLoopFV` + 6 in `RelayRandomMonoFV`), of which 9 are proofs and 4 are `reach` anti-vacuity
controls that must *counterexample* (the same `reach` naming idea as the Halmos suite).

`RelaySigLoopFV` — the signature-loop **weight invariant** `weight ≤ prefixSum(nextUnusedIndex)`, via
k-induction over a grounded prefix sum ([`psAt`](CONCEPTS.md#6-what-is-psat-the-prefix-sum-at-the-heart-of-the-proofs); N=3 voter model; re-validated at N=5, ~2.25 h, identical verdicts):

| `prove_` function | Kind · verdict | What it establishes |
|---|---|---|
| [`prove_base_invariant`](../../test-forge/fv/kontrol/RelaySigLoopFV.t.sol#L57) | proof ✅ | base case: the invariant holds at loop entry (`weight = 0`, `nextUnusedIndex = 0`) |
| [`prove_step_preserves_invariant`](../../test-forge/fv/kontrol/RelaySigLoopFV.t.sol#L65) | proof ✅ | inductive step: one signature preserves the invariant from a *fully-symbolic* pre-state — the ∀K discharge |
| [`prove_lemma_prefix_monotone`](../../test-forge/fv/kontrol/RelaySigLoopFV.t.sol#L50) | proof ✅ | grounded lemma: prefix sums of non-negative weights are monotone (derived, not assumed) |
| [`prove_accept_implies_threshold_exceeded`](../../test-forge/fv/kontrol/RelaySigLoopFV.t.sol#L81) | proof ✅ | accept (`weight > threshold`) ⟹ the total registered weight exceeds the threshold |
| [`prove_insufficientWeight_cannotAccept`](../../test-forge/fv/kontrol/RelaySigLoopFV.t.sol#L92) | proof ✅ | contrapositive: insufficient total registered weight can never accept, for any K |
| [`prove_reach_stepNeedsGuard`](../../test-forge/fv/kontrol/RelaySigLoopFV.t.sol#L105) | reach control · CEX by design | the step *without* the order guard re-counts a voter and breaks the invariant — the no-double-count guard is load-bearing |
| [`prove_reach_acceptIsPossible`](../../test-forge/fv/kontrol/RelaySigLoopFV.t.sol#L119) | reach control · CEX by design | acceptance is genuinely reachable with enough weight — the proofs above are not vacuous |

`RelayRandomMonoFV` — random-pointer **monotonicity** (a stale relay never regresses the live round; the
modeled update rule is exactly `max(live, round)`):

| `prove_` function | Kind · verdict | What it establishes |
|---|---|---|
| [`prove_base_monotone`](../../test-forge/fv/kontrol/RelayRandomMonoFV.t.sol#L35) | proof ✅ | base: at sequence start the pointer has not decreased |
| [`prove_step_monotone`](../../test-forge/fv/kontrol/RelayRandomMonoFV.t.sol#L40) | proof ✅ | one relay never regresses the pointer, for a fully-symbolic (pointer, round) — monotone ∀K |
| [`prove_step_staleDoesNotRegress`](../../test-forge/fv/kontrol/RelayRandomMonoFV.t.sol#L45) | proof ✅ | a stale (older-or-equal) round leaves the pointer unchanged |
| [`prove_step_advancesToNewer`](../../test-forge/fv/kontrol/RelayRandomMonoFV.t.sol#L51) | proof ✅ | a strictly newer round moves the pointer exactly to it |
| [`prove_reach_canAdvance`](../../test-forge/fv/kontrol/RelayRandomMonoFV.t.sol#L59) | reach control · CEX by design | the advance path is live: the pointer *can* strictly increase |
| [`prove_reach_canStayStale`](../../test-forge/fv/kontrol/RelayRandomMonoFV.t.sol#L65) | reach control · CEX by design | the stale path is live: a stale relay *can* leave the pointer in place |

Each negative proof is paired with a reachability control that *must* counterexample — the same
anti-vacuity discipline as the Halmos suite. Verdicts are judged from the per-test PASSED/FAILED list
printed by `run.sh`'s `kontrol prove` step — the 9 proofs pass, the 4 `reach` controls fail (produce
their counterexample) by design — never from the process exit code (§5.4).

**Honest caveats (stated in each harness header and the README):**

1. **N (voter count) is a concrete model bound**; the proof *structure* is parametric in N (hence the N=3
   and N=5 re-validation). **K is the unbounded dimension** and is genuinely covered: the inductive step's
   pre-state ranges over every invariant-state.
2. **The base + step compose to ∀K by the standard induction principle, applied at the meta level.**
   Kontrol 1.0.248 exposes no native Solidity loop-invariant / cut-point rule, so that final composition is
   not *itself* machine-checked — each piece is. (This is one motivation for the Lean proof at R4, where the
   induction *is* internal and machine-checked.)
3. **It checks a faithful Solidity *model* of the loop body, not Relay's inline-assembly bytecode.** The
   bytecode side at K≤3 is covered by Halmos ([`RelaySigParamFV`](../../test-forge/fv/RelaySigParamFV.t.sol#L23)), and [`RelayModelBridgeFV`](../../test-forge/fv/RelayModelBridgeFV.t.sol#L31) ties the model's
   `psAt` invariant to the real bytecode. A bmc-depth-1 model↔bytecode equivalence obligation would fully
   bridge the gap (future work; see [L10](10-claims-ledger-trust-and-residual.md) and [`docs/relay-t1-bridge.md`](../../docs/relay-t1-bridge.md)).

**The wall — full symbolic-N.** Making N itself symbolic (rather than the {3,5} concrete models) is
empirically **state-explosive**: the N=10 attempt ran **~12 hours and produced 0 proofs**. This is the
assembly/scale barrier, and it is why the *truly* unbounded-N guarantee is carried by Lean (R4a), not
Kontrol.

So Kontrol is a **partial success, honestly bounded**: ∀K at N∈{3,5} on a faithful model — not a failure,
but not the whole ∀N∀K story either.

---

## 5.2 Certora — all-functions storage invariants (specified, blocked by the wall)

**Tool:** `certora-cli 8.16.1`. **Artifacts:** [`certora/Relay.conf`](../../certora/Relay.conf), [`certora/specs/RelayInvariants.spec`](../../certora/specs/RelayInvariants.spec),
[`certora/README.md`](../../certora/README.md).

Certora's distinctive strength is **parametric** invariants: a `rule … (method f)` is checked for **every**
external/public method and arbitrary arguments — i.e., over all callers and all call sequences, not just
the specific sequences Halmos/Kontrol enumerate. The spec targets exactly the cross-transaction **storage**
properties where that would beat the other tools — **five invariants**, each now **cloud-proven for every
function except `relay()`** (2026-07; under the deployment via-ir codegen also excepting
`setSigningPolicy`). The assembly-storage wall (ledger item **C-1** in
[L10](10-claims-ledger-trust-and-residual.md)) is thereby narrowed to a single-function residual:

| Rule | Property | Status |
|------|----------|--------|
| `nonceMonotonic` | `governanceFeeNonce` never decreases, ∀ function (globalizes RLY-02 / the 2-call [`RelayGovernanceNonceFV`](../../test-forge/fv/RelayGovernanceNonceFV.t.sol#L18)) | ✅ proven **20/21 fns** (legacy) · 19/21 (via-ir), incl. `governanceFeeSetup`, the writer; `relay()` vacuous (residual) |
| `lastInitializedMonotonic` | `lastInitializedRewardEpoch` never regresses, ∀ function (globalizes the +1 step of [`RelayEpochAdvanceFV`](../../test-forge/fv/RelayEpochAdvanceFV.t.sol#L15)) | ✅ proven 20/21 (legacy) · 19/21 (via-ir); `relay()` (incl. its Mode-1 write) vacuous — covered per-sequence by Halmos |
| `signingPolicySetterImmutable` | the setter authority is immutable after construction | ✅ proven 20/21 (legacy) · 19/21 (via-ir); `relay()` vacuous |
| `policyHashWriteOnce` | a finalized signing-policy hash is never overwritten/cleared (under the in-spec reachable-state link) | ✅ proven **22/23** (legacy, incl. `setSigningPolicy` — its writer) · 21/23 (via-ir); `relay()` vacuous |
| `merkleRootWriteOnce` | a finalized Merkle root is write-once per (protocolId, votingRoundId) | ✅ proven 22/23 (legacy) · 21/23 (via-ir); `relay()` vacuous |

`ecrecover` is left NONDET (modeling-contract A2): the storage invariants must hold regardless of which
signatures the prover admits.

**Status: cloud-proven, non-vacuously (`rule_sanity basic`), for every function except `relay()`** — and
except `setSigningPolicy` under the deployment via-ir codegen (the legacy-codegen runs cover it). The
historical wall, for the record:

- The specs pass Certora's **local** pipeline — `certoraRun certora/Relay.conf --compilation_steps_only` —
  which compiles [`Relay.sol`](../../contracts/protocol/implementation/Relay.sol) under Certora and **typechecks the spec against the real contract** (exit 0,
  only benign OZ-`MerkleProof` summarization warnings). So the rules are confirmed **well-formed against the
  actual contract**, not just syntactically.
- The actual proof runs on Certora's **cloud** (needs `CERTORAKEY`). **Two cloud runs were executed**
  (run 2 added `HAVOC_ECF` + a uint32-wrap guard):
  - run 1: `https://prover.certora.com/output/3798318/a9a6c094009f4711852a166db63ac06f`
  - run 2: `https://prover.certora.com/output/3798318/93ef4cf514274eac9f089c3ac3533be9`

**Outcome (both identical):** `nonceMonotonic`, `lastInitializedMonotonic`, `signingPolicySetterImmutable`
reported "violations" on `relay()`, `governanceFeeSetup`, `setSigningPolicy`; `policyHashWriteOnce` and
`merkleRootWriteOnce` returned `UNKNOWN`.

**These "violations" are spurious — a tool limitation, not contract bugs. The decisive tell:**
`setSigningPolicy` "violates" `signingPolicySetterImmutable`, yet `setSigningPolicy` **makes no external
call** and **never writes the `signingPolicySetter` slot** — so it cannot logically change it. And
`HAVOC_ECF` (removing external-call havoc; sound here as Relay has no `delegatecall`) changed **nothing**
between runs. The cause is therefore **storage-slot havoc from inline assembly**: Relay builds mapping slots
in scratch memory (`keccak256(mload(0x40), 64)`) and writes the bit-packed `StateData` as a whole slot via
assembly `assignStruct`/`sstore`. When Certora's storage analysis cannot resolve an `sstore` target, it
conservatively **havocs all storage**, so every storage invariant breaks on every assembly-writing function
— including slots that function never touches.

**How they were discharged (2026-07-15).** Not by the ghost/hook re-modeling once contemplated (which
would have re-introduced hand-decoded bit-offsets), but by removing the failing analysis from the loop:
`-enableStorageSplitting false` makes storage one SMT array whose aliasing is decided by the prover's
**injective hashing model** (keccak-derived locations are guaranteed distinct from scalar slots and from
other keys' locations) — the three getter-based rules then verify with zero spec changes. The two
write-once rules (whose direct-storage-access formulation depends on the same analysis) are restated over
plain-Solidity view getters via a **faithfulness-machine-checked munged copy**
([`certora/munge.sh`](../../certora/munge.sh) regenerates it and fails unless the diff is exactly two
`private → internal` keywords) and a harness ([`certora/harness/RelayHarness.sol`](../../certora/harness/RelayHarness.sol)).
A legacy-codegen run also surfaced a genuine **unreachable-state counterexample** — parametric rules start
from arbitrary storage, including "hash set while the epoch pointer is below it", from which
`setSigningPolicy` may legitimately rewrite — now excluded by a documented in-spec reachable-state link
(`require epoch <= lastInitializedRewardEpoch`). Full run matrix, report links, and mechanics:
[`certora/README.md`](../../certora/README.md).

**The narrowed residual:** under the no-splitting model, `relay()` itself (and `setSigningPolicy` under
via-ir codegen) has no non-reverting path — the rules hold for it only vacuously (`SANITY_FAIL`, flagged by
`rule_sanity`). This is intrinsic path-modeling, not a spec gap: the ghost/hook route inherits it (raw
hooks *require* splitting-off). The failure mode is now visible no-coverage rather than false alarms, and
`relay()`'s storage behavior stays covered by the per-sequence Halmos proofs on the real bytecode, the
Kontrol ∀K invariant, and the Lean literal model.

---

## 5.3 The convergent finding

Two independent, state-of-the-art unbounded provers fail on the **same** obstacle:

- **Kontrol** at full symbolic-N — state-explosive (12 h / 0 proofs).
- **Certora** at all-functions storage invariants — storage-slot havoc from inline assembly (since
  narrowed to the `relay()`-only residual — §5.2).

The root cause is identical: Relay is **~90% hand-rolled inline assembly with bit-packed storage written to
scratch-memory-computed slots**, which defeats automated provers' storage models. That two different tools
fail the *same way* is the signal, not a coincidence — it is the **assembly barrier (R3→R4)** appearing
twice, a real property of the contract.

This is exactly why the stack escalates to **R4 (Lean + validated EVM semantics)**, which does not
reconstruct a storage model at all: the abstract proof reasons at the algorithm level (no EVM), and the bytecode refinement reasons
against a *validated* operational semantics of the bytecode. The convergent wall both justifies the
strategy and bounds the residual: after the stack (and the 2026-07 discharge) what remains unverified is
the all-functions storage invariants **on `relay()` alone**, whose per-sequence forms are proven on the
real bytecode and whose accept-path write is proven in the Lean literal model.

---

## 5.4 Reproduce

Full detail in [L11](11-reproducibility.md).

**Kontrol** (reproducible Docker image; best on native x86_64 Linux):

```bash
docker build -f test-forge/fv/kontrol/Dockerfile -t kontrol-local:ready .     # one-time, ~18.5 GB
docker run --rm --platform linux/amd64 -v "$PWD/test-forge/fv/kontrol":/work kontrol-local:ready sh /work/run.sh
# per harness: forge build → kontrol build (~8–18 min, reuses baked kdist) → kontrol prove
# judge from the per-test PASSED/FAILED list, NOT the exit code (reachability controls FAIL by design)
```

Pinned: Kontrol `v1.0.248`, K `v7.1.334`, toolchain `nixpkgs @ 9eac87a…`, base image by sha256 digest.

**Certora** (needs an account/key for the cloud proof):

```bash
pip install certora-cli            # tested: 8.16.1
export CERTORAKEY=<your key>
# the discharged runs (see certora/README.md for the full matrix + report links):
certoraRun certora/Relay-rawstorage.conf --solc /path/to/solc-0.8.27      # 3 scalar rules, via-ir: 19/21
certoraRun certora/Relay-rawstorage-A3.conf --solc /path/to/solc-0.8.27   # 3 scalar rules, legacy: 20/21
./certora/munge.sh                                                         # regenerate + verify munged tree
certoraRun certora/Relay-writeonce.conf --solc /path/to/solc-0.8.27       # write-once, via-ir: 21/23
certoraRun certora/Relay-writeonce-B2.conf --solc /path/to/solc-0.8.27    # write-once, legacy: 22/23
# the historical wall, for comparison (spurious violations):
certoraRun certora/Relay.conf --solc /path/to/solc-0.8.27
certoraRun certora/Relay.conf --compilation_steps_only --solc /path/to/solc-0.8.27   # local typecheck (no key)
```

Judge from the per-rule statuses in the report (`SUCCESS` = proven non-vacuously; `SANITY_FAIL` = the
`relay()` vacuity residual; the CLI's exit banner lumps the latter under "violations").

**Next:** [L6 — R4a: the abstract proof](06-R4a-abstract-proof.md), where the ∀N∀K soundness that Kontrol
could only approach at fixed N is proven outright, hole-free, in Lean.
