# L5 — R3: unbounded attempts (Kontrol & Certora) and the assembly wall

> **Evidence note.** §5.2 documents the regenerated current Certora inputs. Kontrol results elsewhere in
> this chapter are historical until a current manifest run is recorded in
> [`CURRENT-STATUS.md`](CURRENT-STATUS.md).

> **What you get from this level.** The two attempts to cross the **induction barrier** — Kontrol/KEVM and
> Certora — told honestly: where they _succeeded_, where they hit the **assembly barrier**, and why the
> walls are a genuine finding rather than a tooling failure. This is the rung that motivated theorem
> proving (R4). It is deliberately candid: an audit deserves the negative results, not just the wins.

---

## 5.1 Kontrol/KEVM — historical ∀K model result

**Tool:** Kontrol `v1.0.248` over KEVM (`K v7.1.334`), fully pinned (see §5.4). **Artifacts:**
`test-forge/fv/kontrol/` — [`RelaySigLoopFV.t.sol`](../../test-forge/fv/kontrol/RelaySigLoopFV.t.sol), [`RelayRandomMonoFV.t.sol`](../../test-forge/fv/kontrol/RelayRandomMonoFV.t.sol), `run.sh`, `Dockerfile`,
`foundry.toml`, `README.md`.

Kontrol proves properties by **[k-induction](CONCEPTS.md#5-what-is-k-induction)** — it discharges a base case and an inductive step whose
pre-state is _fully symbolic_, so a single step covers every iteration count. This crosses the induction
barrier in the **K dimension** (the number of signatures / relays), which is the genuinely unbounded one.

**What the recorded historical run established (Kontrol 1.0.248)** — the two
primary harnesses below contain **13 `prove_` functions** (7 in
`RelaySigLoopFV` + 6 in `RelayRandomMonoFV`), of which 9 are proofs and 4 are `reach` anti-vacuity
controls that must _counterexample_ (the same `reach` naming idea as the Halmos suite).

`RelaySigLoopFV` — the signature-loop **weight invariant** `weight ≤ prefixSum(nextUnusedIndex)`, via
k-induction over a grounded prefix sum ([`psAt`](CONCEPTS.md#6-what-is-psat-the-prefix-sum-at-the-heart-of-the-proofs); N=3 voter model; re-validated at N=5 as the committed `RelaySigLoopFV_N5.t.sol` harness, ~2.25 h, identical verdicts):

| `prove_` function                                                                                 | Kind · verdict                           | What it establishes                                                                                                              |
| ------------------------------------------------------------------------------------------------- | ---------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| [`prove_base_invariant`](../../test-forge/fv/kontrol/RelaySigLoopFV.t.sol#L64)                    | historical proof                         | base case: the invariant holds at loop entry (`weight = 0`, `nextUnusedIndex = 0`)                                               |
| [`prove_step_preserves_invariant`](../../test-forge/fv/kontrol/RelaySigLoopFV.t.sol#L72)          | historical proof                         | inductive step: one signature preserves the invariant from a _fully-symbolic_ pre-state — the ∀K discharge                       |
| [`prove_lemma_prefix_monotone`](../../test-forge/fv/kontrol/RelaySigLoopFV.t.sol#L57)             | historical proof                         | grounded lemma: prefix sums of non-negative weights are monotone (derived, not assumed)                                          |
| [`prove_accept_implies_threshold_exceeded`](../../test-forge/fv/kontrol/RelaySigLoopFV.t.sol#L88) | historical model proof                   | accept (`weight > threshold`) ⟹ total registered policy-slot weight exceeds the threshold, conditional on unique voter addresses |
| [`prove_insufficientWeight_cannotAccept`](../../test-forge/fv/kontrol/RelaySigLoopFV.t.sol#L99)   | historical model proof                   | contrapositive over policy slots: insufficient total slot weight can never accept, for any K                                     |
| [`prove_reach_stepNeedsGuard`](../../test-forge/fv/kontrol/RelaySigLoopFV.t.sol#L112)             | historical reach control · CEX by design | the step _without_ the order guard reuses a policy slot and breaks the invariant                                                 |
| [`prove_reach_acceptIsPossible`](../../test-forge/fv/kontrol/RelaySigLoopFV.t.sol#L126)           | historical reach control · CEX by design | acceptance is reachable with enough modeled slot weight — the model proofs above were not vacuous                                |

`RelayRandomMonoFV` — random-pointer **monotonicity** (a stale relay never regresses the live round; the
modeled update rule is exactly `max(live, round)`):

| `prove_` function                                                                           | Kind · verdict                           | What it establishes                                                                        |
| ------------------------------------------------------------------------------------------- | ---------------------------------------- | ------------------------------------------------------------------------------------------ |
| [`prove_base_monotone`](../../test-forge/fv/kontrol/RelayRandomMonoFV.t.sol#L42)            | historical proof                         | base: at sequence start the pointer has not decreased                                      |
| [`prove_step_monotone`](../../test-forge/fv/kontrol/RelayRandomMonoFV.t.sol#L47)            | historical proof                         | one relay never regresses the pointer, for a fully-symbolic (pointer, round) — monotone ∀K |
| [`prove_step_staleDoesNotRegress`](../../test-forge/fv/kontrol/RelayRandomMonoFV.t.sol#L52) | historical proof                         | a stale (older-or-equal) round leaves the pointer unchanged                                |
| [`prove_step_advancesToNewer`](../../test-forge/fv/kontrol/RelayRandomMonoFV.t.sol#L58)     | historical proof                         | a strictly newer round moves the pointer exactly to it                                     |
| [`prove_reach_canAdvance`](../../test-forge/fv/kontrol/RelayRandomMonoFV.t.sol#L66)         | historical reach control · CEX by design | the advance path was live: the pointer could strictly increase                             |
| [`prove_reach_canStayStale`](../../test-forge/fv/kontrol/RelayRandomMonoFV.t.sol#L72)       | historical reach control · CEX by design | the stale path was live: a stale relay could leave the pointer in place                    |

Each negative proof is paired with a reachability control that _must_ counterexample — the same
anti-vacuity discipline as the Halmos suite. Verdicts are judged from the per-test PASSED/FAILED list
printed by `run.sh`'s `kontrol prove` step. The broader historical runner recorded
14 proofs and 6 controls; those results were not rerun for the current
architecture and are never inferred from the process exit code (§5.4).

**Honest caveats (stated in each harness header and the README):**

1. **N (voter count) is a concrete model bound**; the proof _structure_ is parametric in N (hence the N=3
   and N=5 re-validation). **K is the unbounded dimension** and is genuinely covered: the inductive step's
   pre-state ranges over every invariant-state.
2. **The base + step compose to ∀K by the standard induction principle, applied at the meta level.**
   Kontrol 1.0.248 exposes no native Solidity loop-invariant / cut-point rule, so that final composition is
   not _itself_ machine-checked — each piece is. (This is one motivation for the Lean proof at R4, where the
   induction _is_ internal and machine-checked.)
3. **It checks a faithful Solidity _model_ of the loop body, not Relay's inline-assembly bytecode.** The
   bytecode side at K≤3 is covered by Halmos ([`RelaySigParamFV`](../../test-forge/fv/RelaySigParamFV.t.sol#L29)), and [`RelayModelBridgeFV`](../../test-forge/fv/RelayModelBridgeFV.t.sol#L37) ties the model's
   `psAt` invariant to the real bytecode. A bmc-depth-1 model↔bytecode equivalence obligation would fully
   bridge the gap (future work; see [L10](10-claims-ledger-trust-and-residual.md) and [`docs/relay-t1-bridge.md`](../../docs/relay-t1-bridge.md)).

**The wall — full symbolic-N.** Making N itself symbolic (rather than the {3,5} concrete models) is
empirically **state-explosive**: the N=10 attempt ran **~12 hours and produced 0 proofs**. This is the
assembly/scale barrier, and it is why the _truly_ unbounded-N guarantee is carried by Lean (R4a), not
Kontrol.

So Kontrol is a **partial success, honestly bounded**: ∀K at N∈{3,5} on a faithful model — not a failure,
but not the whole ∀N∀K story either.

---

## 5.2 Certora — current owner-timelock specifications

**Tool:** `certora-cli 8.16.1`. **Artifacts:** [`certora/Relay.conf`](../../certora/Relay.conf),
[`Relay-threshold.conf`](../../certora/Relay-threshold.conf),
[`Relay-writeonce.conf`](../../certora/Relay-writeonce.conf),
[`RelayInvariants.spec`](../../certora/specs/RelayInvariants.spec),
[`RelayThreshold.spec`](../../certora/specs/RelayThreshold.spec),
[`RelayWriteOnce.spec`](../../certora/specs/RelayWriteOnce.spec), and
[`certora/README.md`](../../certora/README.md).

The retired Safe/GSS source and rules have been removed. The current suite has
15 rules: six scalar current-implementation invariants, two dedicated threshold
rules, two raw mapping write-once rules, and five owner/timelock transition
rules. They cover source
domain immutability, signing-policy mode stability, epoch monotonicity,
nonzero owner/fee recipient, the seven-day delay cap, policy/root write-once,
guarded-surface authorization, queue-not-apply behavior, queue consumption,
execution-flag cleanup, disabled renunciation, fail-fast rejection of thresholds
at or above 100% before any Relay `SSTORE`, `TSTORE`, or `CALL`, and the exact
floor/cross-product arithmetic lemma.

All three configurations set `loop_iter=3` and `optimistic_loop=true`. Certora may
therefore abstract paths that continue beyond the configured loop bound. A
cloud `SUCCESS` is conditional on that under-approximating loop model; it does
not prove unrestricted voter, signature, or array-loop behavior. All configs
also use optimistic hashing with a 512-byte bound. Per-method sanity and
reachability results remain mandatory, and the unbounded loop obligations belong
to the higher-rung abstract proofs.

The production contract is upgradeable, so the scalar and write-once rules
explicitly exclude `initialize`, `upgradeToAndCall`, and
`executeTimelockedCall` (which can dispatch an upgrade). This is a necessary
trust boundary: an authorized UUPS replacement may deliberately change any
old-implementation invariant. The suite checks the current owner/timelock
mechanics but does not claim storage compatibility or semantic equivalence for
an arbitrary future implementation.

The two private mappings are observed through a verification-only harness.
[`munge.sh`](../../certora/munge.sh) rebuilds its source tree from scratch,
copies every current owner-timelock dependency byte-for-byte, changes exactly
two `private` declarations to `internal`, and fails on any other Relay diff.
Deleting the generated tree first also prevents retired architecture files from
surviving regeneration.

**Evidence status (2026-08-12):** for reviewed source revision
`d5af7136c03d6bab83307b0f4bd49101b8792e40`, manifest SHA-256
`7ae2208f96a520f477b528ee808909f87e9402247bacab00e04052fa02ec2cb1`
binds all three configurations and 15 rules. They compile and CVL-typecheck
locally with Certora CLI 8.16.1, Java 26, solc
`0.8.35+commit.47b9dedd`, Cancun, optimizer 200, and `viaIR=true`. Normalized
local report SHA-256
`9d3ce0394ebcfadb2b415021a077a0a29761814a11a510d90d23364f97185067`
is **PASS** (3/3 configs, 15 rules, 0 local violations). This is a front-end
result, not a prover verdict. Aggregate local bundle SHA-256
`be386d63acdd336b99ab84c64cb0f32ba9c3bafbba02b17164ebd176b7e4f64a`
is also **PASS**. Both local artifacts are development-only solely because the
worktree was dirty; a clean committed rerun is required for release eligibility.

Normalized supplemental cloud report SHA-256
`93d09d86d1acbf3b3ffdb0f6d9f8145b094722b9b7de94e131ef8e8e97ca4821`
is **PARTIAL**. The
[threshold job](https://prover.certora.com/output/3798318/a133698c16d54e7cb4a518a3251dd73a)
is **PASS** with two `SUCCESS` results. The
[scalar job](https://prover.certora.com/output/3798318/96136f4b1ce349889963c722745f6d8a)
and
[write-once/timelock job](https://prover.certora.com/output/3798318/5f29c9d404134b7aa3578484455bf424)
are **PARTIAL**. Across all three, the normalized semantic totals are 308
`SUCCESS`, 2 `SATISFIED`, and 24 `SANITY_FAIL`, with no semantic assertion
counterexample, `UNKNOWN`, or `TIMEOUT`.

The 24 sanity exclusions are the exact cross-product of the six scalar rules
with `relay`, `setSigningPolicy`, and `renounceOwnership` (18), plus the two
mapping rules with those same methods (6). The loop-heavy methods are not shown
nonvacuous under the bounded optimistic-loop scene. Renunciation always reverts,
so its generic normal-call sanity check is expected to fail; the dedicated
`ownershipRenounceAlwaysReverts` rule passes. The two `satisfy` witnesses exhibit
(1) queued duration execution consuming the ETA, clearing the flag, and mutating
duration, and (2) a zero-delay owner duration mutation. Certora CLI 8.16.1 calls
those SAT subnodes `FAIL` because of assertion polarity; the normalizer validates
the detailed witness tables and records them as `SATISFIED` reachability results.

The threshold Certora result has a narrower, explicit scope. It proves that
`thresholdBIPS >= 10000` fails before any Relay `SSTORE`, `TSTORE`, or `CALL`,
and separately proves the exact floor/cross-product arithmetic identity. It does
not prove successful override forwarding, transient setup and cleanup, rollback
after a caught revert, address scope, or protocol-mode isolation. Those obligations
are covered by the bounded Halmos checks and the Lean refinement; Lean keeps the
implementation connection explicit as the `hsetupThreshold` hypothesis.

The `viaIR` internal-resolution diagnostics, direct-implementation/UUPS boundary,
three-iteration optimistic loop, and 512-byte optimistic hashing bound remain
explicit limitations. The supplemental cloud report is not a constituent of the
local aggregate bundle, and its PARTIAL result must not be promoted to a blanket
rule, proxy-level, or release claim.

---

## 5.3 What the R3 evidence means now

Kontrol remains historical evidence about a fixed Solidity model and pinned
toolchain. Certora has a current local source/typecheck pass and a current
supplemental cloud result: the threshold configuration passes, while scalar and
write-once remain partial because of 24 disclosed sanity exclusions. The local
front end and bounded/direct-implementation cloud model may not be used as a
blanket claim over the proxy or a future implementation. Relay's assembly-heavy
`relay()` remains the reason this stack also uses bounded execution and explicit
mathematical models.

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
pip install certora-cli==8.16.1
# no key/cloud; JDK 21+ and exact solc 0.8.35 required:
python3 test-forge/fv/verify_certora_local.py --solc /path/to/solc-0.8.35
export CERTORAKEY=<your key>
./certora/munge.sh
certoraRun certora/Relay.conf --solc /path/to/solc-0.8.35
certoraRun certora/Relay-threshold.conf --solc /path/to/solc-0.8.35
certoraRun certora/Relay-writeonce.conf --solc /path/to/solc-0.8.35
python3 test-forge/fv/verify_certora_cloud.py \
  --run certora/Relay.conf=/path/to/scalar.log=/path/to/scalar-submission.zip \
  --run certora/Relay-threshold.conf=/path/to/threshold.log=/path/to/threshold-submission.zip \
  --run certora/Relay-writeonce.conf=/path/to/writeonce.log=/path/to/writeonce-submission.zip \
  --report verification-reports/relay-certora-cloud.json
```

Judge cloud evidence per rule and per method: `SUCCESS` is usable only with a
non-vacuous sanity result. A concrete SAT `satisfy` witness is successful
reachability evidence even though CLI 8.16.1 renders that subnode as `FAIL` in
aggregate text. Preserve unknowns, timeouts, and sanity failures as failures or
explicit coverage gaps.

**Next:** [L6 — R4a: the abstract proof](06-R4a-abstract-proof.md), where the ∀N∀K soundness that Kontrol
could only approach at fixed N is proven outright, hole-free, in Lean.
