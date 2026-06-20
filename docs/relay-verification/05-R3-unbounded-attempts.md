# L5 — R3: unbounded attempts (Kontrol & Certora) and the assembly wall

> **What you get from this level.** The two attempts to cross the **induction barrier** — Kontrol/KEVM and
> Certora — told honestly: where they *succeeded*, where they hit the **assembly barrier**, and why the
> walls are a genuine finding rather than a tooling failure. This is the rung that motivated theorem
> proving (R4). It is deliberately candid: an audit deserves the negative results, not just the wins.

---

## 5.1 Kontrol/KEVM — ∀K by k-induction (a real success, on a model)

**Tool:** Kontrol `v1.0.248` over KEVM (`K v7.1.334`), fully pinned (see §5.4). **Artifacts:**
`test-forge/fv/kontrol/` — `RelaySigLoopFV.t.sol`, `RelayRandomMonoFV.t.sol`, `run.sh`, `Dockerfile`,
`foundry.toml`, `README.md`.

Kontrol proves properties by **k-induction** — it discharges a base case and an inductive step whose
pre-state is *fully symbolic*, so a single step covers every iteration count. This crosses the induction
barrier in the **K dimension** (the number of signatures / relays), which is the genuinely unbounded one.

**What it proved (verdicts, Kontrol 1.0.248):**

`RelaySigLoopFV` — the signature-loop **weight invariant** `weight ≤ prefixSum(nextUnusedIndex)`, via
k-induction over a grounded prefix sum (N=3 voter model; re-validated at N=5, ~2.25 h, identical verdicts):

- `prove_base_invariant` ✅
- `prove_step_preserves_invariant` ✅
- `prove_lemma_prefix_monotone` ✅
- `prove_accept_implies_threshold_exceeded` ✅
- `prove_insufficientWeight_cannotAccept` ✅
- `prove_reach_stepNeedsGuard` → counterexample (confirms the no-double-count guard is load-bearing)
- `prove_reach_acceptIsPossible` → counterexample (accept path live)

`RelayRandomMonoFV` — random-pointer **monotonicity** (a stale relay never regresses the live round):
`prove_base_monotone` ✅, `prove_step_monotone` ✅, `prove_step_staleDoesNotRegress` ✅,
`prove_step_advancesToNewer` ✅, plus two reachability controls that counterexample by design.

Each negative proof is paired with a reachability control that *must* counterexample — the same
anti-vacuity discipline as the Halmos suite.

**Honest caveats (stated in each harness header and the README):**

1. **N (voter count) is a concrete model bound**; the proof *structure* is parametric in N (hence the N=3
   and N=5 re-validation). **K is the unbounded dimension** and is genuinely covered: the inductive step's
   pre-state ranges over every invariant-state.
2. **The base + step compose to ∀K by the standard induction principle, applied at the meta level.**
   Kontrol 1.0.248 exposes no native Solidity loop-invariant / cut-point rule, so that final composition is
   not *itself* machine-checked — each piece is. (This is one motivation for the Lean proof at R4, where the
   induction *is* internal and machine-checked.)
3. **It checks a faithful Solidity *model* of the loop body, not Relay's inline-assembly bytecode.** The
   bytecode side at K≤3 is covered by Halmos (`RelaySigParamFV`), and `RelayModelBridgeFV` ties the model's
   `psAt` invariant to the real bytecode. A bmc-depth-1 model↔bytecode equivalence obligation would fully
   bridge the gap (future work; see [L10](10-claims-ledger-trust-and-residual.md) and `docs/relay-t1-bridge.md`).

**The wall — full symbolic-N.** Making N itself symbolic (rather than the {3,5} concrete models) is
empirically **state-explosive**: the N=10 attempt ran **~12 hours and produced 0 proofs**. This is the
assembly/scale barrier, and it is why the *truly* unbounded-N guarantee is carried by Lean (R4a), not
Kontrol.

So Kontrol is a **partial success, honestly bounded**: ∀K at N∈{3,5} on a faithful model — not a failure,
but not the whole ∀N∀K story either.

---

## 5.2 Certora — all-functions storage invariants (specified, blocked by the wall)

**Tool:** `certora-cli 8.16.1`. **Artifacts:** `certora/Relay.conf`, `certora/specs/RelayInvariants.spec`,
`certora/README.md`.

Certora's distinctive strength is **parametric** invariants: a `rule … (method f)` is checked for **every**
external/public method and arbitrary arguments — i.e., over all callers and all call sequences, not just
the specific sequences Halmos/Kontrol enumerate. The spec targets exactly the cross-transaction **storage**
properties where that would beat the other tools:

| Rule | Property |
|------|----------|
| `nonceMonotonic` | `governanceFeeNonce` never decreases, ∀ function (globalizes RLY-02 / the 2-call `RelayGovernanceNonceFV`) |
| `lastInitializedMonotonic` | `lastInitializedRewardEpoch` never regresses, ∀ function incl. `relay()` Mode-1 (globalizes the +1 step of `RelayEpochAdvanceFV`) |
| `signingPolicySetterImmutable` | the setter authority is immutable after construction |
| `policyHashWriteOnce` | a finalized signing-policy hash is never overwritten/cleared |
| `merkleRootWriteOnce` | a finalized Merkle root is write-once per (protocolId, votingRoundId) |

`ecrecover` is left NONDET (modeling-contract A2): the storage invariants must hold regardless of which
signatures the prover admits.

**Status: specified + locally typechecked, cloud-run executed, not cloud-dischargeable.**

- The specs pass Certora's **local** pipeline — `certoraRun certora/Relay.conf --compilation_steps_only` —
  which compiles `Relay.sol` under Certora and **typechecks the spec against the real contract** (exit 0,
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

**What it would take to discharge them:** re-model the storage layout in CVL with `ghost` variables + raw
`hook Sstore`/`hook Sload` that mirror every assembly write (decoding the packed `StateData` bit-offsets and
the computed mapping slots), then state the invariants over the ghosts. This is substantial **and
re-introduces the faithfulness risk the engagement avoids** (a wrong bit-offset = a meaningless proof). Not
recommended unless an audit specifically requires all-functions storage invariants — the **per-sequence**
forms are already proven (Halmos `RelayGovernanceNonceFV`, `RelayEpochAdvanceFV`, …) and the ∀N∀K
signature-loop soundness is the Lean proof.

---

## 5.3 The convergent finding

Two independent, state-of-the-art unbounded provers fail on the **same** obstacle:

- **Kontrol** at full symbolic-N — state-explosive (12 h / 0 proofs).
- **Certora** at all-functions storage invariants — storage-slot havoc from inline assembly.

The root cause is identical: Relay is **~90% hand-rolled inline assembly with bit-packed storage written to
scratch-memory-computed slots**, which defeats automated provers' storage models. That two different tools
fail the *same way* is the signal, not a coincidence — it is the **assembly barrier (R3→R4)** appearing
twice, a real property of the contract.

This is exactly why the stack escalates to **R4 (Lean + validated EVM semantics)**, which does not
reconstruct a storage model at all: the abstract proof reasons at the algorithm level (no EVM), and the bytecode refinement reasons
against a *validated* operational semantics of the bytecode. The convergent wall both justifies the
strategy and bounds the residual: what remains unverified after the stack is "all-functions storage
invariants *over raw assembly storage*", whose **per-sequence** forms are already proven elsewhere.

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
certoraRun certora/Relay.conf --solc /path/to/solc-0.8.27                 # cloud proof
certoraRun certora/Relay.conf --compilation_steps_only --solc /path/to/solc-0.8.27   # local typecheck (no key)
```

The cloud run reproduces the spurious violations above (the documented wall); the local typecheck passes.

**Next:** [L6 — R4a: the abstract proof](06-R4a-abstract-proof.md), where the ∀N∀K soundness that Kontrol
could only approach at fixed N is proven outright, hole-free, in Lean.
