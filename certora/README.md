# Certora — Relay cross-transaction storage invariants

> **Current-status boundary (2026-07-26).** The linked cloud runs below were
> made against the pre-GSS `relay-fix-3` contract. They remain useful historical
> evidence for the unchanged relay/signing-policy core, but they are not current
> proofs of `processGSSMessage` or its state. The checked-in CVL now replaces the
> removed `governanceFeeNonce` rule with four GSS state-machine rules covering
> the global high-water mark, owner-generation nonce, hash/generation coupling,
> and consumed-nonce permanence. The current rule set must be rerun before any
> result is claimed for `relay-fix-3-gss`. The current sources pass the pinned
> local front-end gate for both configs (CLI 8.16.1, Java 21, solc 0.8.27,
> compile + CVL typecheck + exact munge). That is not a cloud proof verdict.

CVL specs for the properties where **Certora genuinely beats the Halmos/Kontrol proofs in this repo**:
*parametric* storage invariants that hold over **every function and every call sequence**, not just the
specific sequences those tools could enumerate.

## Current rule inventory (`specs/RelayInvariants.spec`)

| Rule | Property | Current GSS status |
|------|----------|---------------------------|
| `governanceSafeNonceMonotonic` | `lastGovernanceSafeNonce` never decreases, ∀ function | local typecheck pass; cloud proof pending |
| `governanceOwnerConfigSafeNonceMonotonic` | owner-configuration generations never regress, ∀ function | local typecheck pass; cloud proof pending |
| `governanceOwnerHashChangeAdvancesGeneration` | a changed owner hash strictly advances its generation | local typecheck pass; cloud proof pending |
| `governanceConsumedNonceWriteOnce` | a consumed Safe nonce can never become reusable | local typecheck pass; cloud proof pending |
| `lastInitializedMonotonic` | `lastInitializedRewardEpoch` never regresses, ∀ function | historical cloud baseline; current local typecheck pass; cloud proof pending |
| `signingPolicySetterImmutable` | the setter authority is immutable after construction | historical cloud baseline; current local typecheck pass; cloud proof pending |
| `policyHashWriteOnce` | a finalized signing-policy hash is never overwritten/cleared (under the documented reachable-state link) | historical cloud baseline; current local typecheck pass; cloud proof pending |
| `merkleRootWriteOnce` | a finalized Merkle root is write-once per `(protocolId, votingRoundId)` | historical cloud baseline; current local typecheck pass; cloud proof pending |

(The first six run against the production contract as-is — [`Relay.conf`](Relay.conf) historically,
[`Relay-rawstorage.conf`](Relay-rawstorage.conf) for the discharged runs. The write-once pair runs against
[`harness/RelayHarness.sol`](harness/RelayHarness.sol) over the munged tree — see *The write-once route*
below — via [`Relay-writeonce.conf`](Relay-writeonce.conf).)

Each is a `rule … (method f)` — Certora checks it for **all** external/public methods and arbitrary args
(quantifying over all callers and sequences). ecrecover is left NONDET (modeling contract A2): the storage
invariants hold regardless of which signatures the prover admits.

## Honest scope

- Certora, like Halmos and Kontrol, **unrolls the within-call signature loop** (`loop_iter`), so it does
  **not** close the ∀N within-call signature-loop gap better than Kontrol. The ∀N∀K signature-loop
  soundness remains the Lean proof (`../test-forge/fv/lean/RelaySigLoop.lean`). Certora's value here is the
  cross-transaction **storage** invariants above.
- **Historical baseline status:** cloud-proven for every then-present function except
  `relay()` (and, under the deployment `via-ir` codegen only,
  `setSigningPolicy`) — see the run matrix below. Those runs passed
  `rule_sanity basic`, so their SUCCESS verdicts were non-vacuous. They do not
  cover the current GSS functions.
- **Two codegens, two fidelity levels.** The `via-ir` runs match the deployment compilation pipeline; the
  `legacy`-codegen runs compile the same source the classic way and achieve strictly wider function
  coverage (they additionally prove `setSigningPolicy`). A legacy-codegen proof is evidence about the
  *source semantics* rather than the deployed bytes — corroborating, one notch below deployment-grade.

## How to run (with a Certora account)

```bash
pip install certora-cli            # tested: certora-cli 8.16.1
export CERTORAKEY=<your key>
# from the repo root, with dependencies/ present (soldeer) and a solc 0.8.27 binary:
certoraRun certora/Relay.conf --solc /path/to/solc-0.8.27

# Local fail-closed front-end gate (no key/cloud; needs JDK 21+):
python3 test-forge/fv/verify_certora_local.py \
  --solc /path/to/solc-0.8.27 \
  --report-output verification-reports/relay-certora-local.json
```

The local gate verifies exact tool versions, runs `munge.sh`, compiles and
typechecks `Relay.conf` and `Relay-writeonce.conf`, and emits normalized bundle
evidence. A local `compilation_steps_only` success means the current spec is
well-formed against the current contract; only a cloud run can establish a CVL
rule as proven.

If solc/import resolution differs in your setup, adjust `solc`, `packages`, and `solc_via_ir` in
`Relay.conf` to match the repo's foundry remappings (see `../remappings.txt`).

## Historical baseline: the inline-assembly wall and its 2026-07-15 discharge

**The wall.** The first two cloud runs
(https://prover.certora.com/output/3798318/a9a6c094009f4711852a166db63ac06f,
https://prover.certora.com/output/3798318/93ef4cf514274eac9f089c3ac3533be9) reported spurious "violations"
of all three scalar rules on every assembly-writing function, and `UNKNOWN` for the write-once pair. Cause:
Relay builds mapping slots in scratch memory (`keccak256(mload(0x40), 64)`) and writes the bit-packed
`StateData` whole-slot via assembly; when Certora's **storage-splitting analysis** cannot attribute an
`sstore`, it havocs all storage — so every invariant "broke" on every assembly writer, including slots the
function never touches (the tell: `setSigningPolicy` "violating" `signingPolicySetterImmutable`, a slot it
never writes). This was ledger item **C-1**.

**The discharge.** The fix was *not* the ghost/hook re-modeling this README previously prescribed — it was
removing the failing analysis from the loop entirely:

- **`-enableStorageSplitting false`**: storage becomes one SMT array, and aliasing is decided by the
  prover's **injective hashing model** (a keccak-derived location is guaranteed distinct from the scalar
  slots and from other keys' locations). The spurious cross-slot havoc vanishes with **zero spec changes**
  for the three getter-based rules.
- **`optimistic_hashing` + `hashing_length_bound 512`**: load-bearing on the
  historical source, not cosmetic — the discriminator run (A2 below) showed
  the then-present `governanceFeeSetup`, which hashed unbounded message bytes,
  failed under the default pessimistic 224-byte bound and passed with the flags.

### Historical run matrix (pre-GSS; all with `rule_sanity basic`)

| Run | Codegen | Rules | Verdict | Report |
|-----|---------|-------|---------|--------|
| A ([`Relay-rawstorage.conf`](Relay-rawstorage.conf)) | via-ir | 3 scalar | **19/21 fns proven**; `relay()`, `setSigningPolicy` vacuous | [8e14cd3b](https://prover.certora.com/output/3798318/8e14cd3b30c74af5a4dd234350208e63?anonymousKey=dafb962bd63b9c6ec63e383a02b5c70a7ff5b030) |
| A2 ([`Relay-rawstorage-A2.conf`](Relay-rawstorage-A2.conf)) | via-ir, default hashing | discriminator | hashing flags load-bearing; vacuity intrinsic to splitting-off | [bb56456c](https://prover.certora.com/output/3798318/bb56456c933f44959cf52e808b0282f9?anonymousKey=88093e9e238dc658a63b457cf8a4fc88afd1730e) |
| A3 ([`Relay-rawstorage-A3.conf`](Relay-rawstorage-A3.conf)) | **legacy** | 3 scalar | **20/21 proven** — `setSigningPolicy` included; only `relay()` vacuous | [757ee100](https://prover.certora.com/output/3798318/757ee100d32c4d02a56d628a048990ff?anonymousKey=56c92dbd7c6e5fc96201f48203f655c092d6400c) |
| B ([`Relay-writeonce.conf`](Relay-writeonce.conf)) | via-ir | 2 write-once | 21/23 proven (pre-link run) | [01afed2b](https://prover.certora.com/output/3798318/01afed2b1329420497645a5555a78ca0?anonymousKey=7a7ad1c1aa3cfae35c3ccf4db611d86b7986a122) |
| B2 ([`Relay-writeonce-B2.conf`](Relay-writeonce-B2.conf)) | legacy | 2 write-once | found the **unreachable-state counterexample** (below) | [f4777ba7](https://prover.certora.com/output/3798318/f4777ba7d0864b53afd6cc302f86bb1e?anonymousKey=4b7686a2ced0119a0aaddef5031537cbdd2e7a3f) |
| B3 (B2 conf, spec+link) | legacy | 2 write-once | **22/23 proven** — incl. `setSigningPolicy`, the policy-hash writer; only `relay()` vacuous | [d6877cf6](https://prover.certora.com/output/3798318/d6877cf6b08d4037a08c7ddc879b0de7?anonymousKey=ff471ce600844df6bbdaccb414b6f8e85716e688) |
| B1b (B conf, spec+link) | via-ir | 2 write-once | 21/23 proven; no regression | [9406f186](https://prover.certora.com/output/3798318/9406f186eda94a5dbd3c21f6690ef76b?anonymousKey=2e34180b0982ec0720535052c1b1caf47150d297) |

### The write-once route (munge + harness)

The write-once rules originally read the two private mappings via CVL *direct storage access*, which
depends on the same analysis the assembly defeats. They are restated over plain-Solidity view getters:

- [`munge.sh`](munge.sh) regenerates [`munged/`](munged/) from the production sources, changing **exactly
  two visibility keywords** (`private → internal` on the two mappings) — and **fails if the diff is
  anything else**. Faithfulness is machine-checked on every run, never hand-trusted.
- [`harness/RelayHarness.sol`](harness/RelayHarness.sol) adds `policyHashAt` / `merkleRootAt` raw readers
  (the production getters are unusable here: `toSigningPolicyHash()` delegates to `oldRelay`,
  `merkleRoots()` gates on protocol id).
- [`specs/RelayWriteOnce.spec`](specs/RelayWriteOnce.spec) restates the two rules over those getters.

### The B2 counterexample — the prover working correctly

Under legacy codegen (where `setSigningPolicy` has model coverage), the prover exhibited a real gap in the
*rule as stated*: parametric rules start from **arbitrary** storage, including the unreachable state
"`hash[E] ≠ 0` while `lastInitializedRewardEpoch = E−1`", from which `setSigningPolicy(E)` legitimately
rewrites epoch E (its guard only enforces `rewardEpochId == lastInitialized + 1`). On every *reachable*
state a non-zero hash exists only for epochs ≤ the initialized pointer (the constructor seeds the initial
epoch; both writers — the setter and `relay()` Mode-1 — write exactly `lastInitialized + 1`, then advance).
The rule now carries that **reachable-state link** as a documented `require`
(`epoch <= lastInitializedRewardEpoch`) — stated in the rule, visible to any auditor. Two useful
by-products: the write-once rules demonstrably exercise `setSigningPolicy`'s real write path, and the
epoch-sequencing gate is identified as the load-bearing mechanism behind policy-hash immutability.

### The honest residual — `relay()`

Under `-enableStorageSplitting false`, `relay()` (and under via-ir also `setSigningPolicy`) has **no
non-reverting path in the prover's model** (`SANITY_FAIL`): the rules hold for it only vacuously. This is
intrinsic to the no-splitting storage model on the ~930-line assembly body — **the ghost/hook route cannot
rescue it** (raw `ALL_SSTORE`/`ALL_SLOAD` hooks *require* splitting-off, so any ghost-restated rule
inherits the same vacuity). The failure mode is now *no coverage* (visible, flagged by `rule_sanity`)
rather than *false alarms* — and `relay()`'s storage behavior is exactly where the rest of the stack
concentrates: Halmos proves the epoch-decision matrix, nonce sequences, and write paths on the **real
bytecode** (`RelayEpochAdvanceFV` and the Mode-2 harnesses), Kontrol proves the ∀K
loop invariant, and the Lean literal model proves the accept-path storage write on validated EVM semantics.

### Reproduce

```bash
export CERTORAKEY=<your key>   # cloud account required
# three scalar rules (production contract, no munge needed):
certoraRun certora/Relay-rawstorage.conf --solc /path/to/solc-0.8.27      # via-ir, 19/21
certoraRun certora/Relay-rawstorage-A3.conf --solc /path/to/solc-0.8.27   # legacy, 20/21
# write-once rules (regenerate + verify the munged tree first):
./certora/munge.sh
certoraRun certora/Relay-writeonce.conf --solc /path/to/solc-0.8.27       # via-ir, 21/23
certoraRun certora/Relay-writeonce-B2.conf --solc /path/to/solc-0.8.27    # legacy, 22/23
# the historical wall (for comparison — spurious violations):
certoraRun certora/Relay.conf --solc /path/to/solc-0.8.27
```

Note the CLI's exit banner lumps `SANITY_FAIL` under "violations" — judge from the per-rule statuses in the
report (`output.json`): `SUCCESS` = proven non-vacuously, `SANITY_FAIL` = vacuous for that function (the
`relay()` residual), `FAIL` = a real counterexample.
