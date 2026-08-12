# `test-forge/fv/` — the Relay formal-verification suite (a reader's guide)

This directory holds the machine-checked proofs about `Relay.sol` — rungs **R2–R4** of the fidelity ladder.
The narrative, audit-facing companion is [`docs/relay-verification/`](../../docs/relay-verification/) (start at
[`00-README.md`](../../docs/relay-verification/00-README.md)); the working notes are
[`docs/relay-fv.md`](../../docs/relay-fv.md). This file is the **tooling primer**: it assumes you are a
mathematician / computer scientist but _not_ yet fluent in the verification tools, and tells you how to read,
run, and trust everything here.

> **Current scope (2026-08-12):** the exact manifest contains 123 Halmos checks
> (86 proofs and 37 reachability controls) across 27 harness contracts. It covers
> the signing-policy, `relay()`, Merkle, randomness, fees, and 16
> owner/timelock/UUPS checks plus the protocol-1 threshold/transient path. The
> retired cross-chain Safe-governance inventory is absent. Counts are inventory;
> the current local verdict is PASS 123/123 with 0 violations. See
> [`CURRENT-STATUS.md`](../../docs/relay-verification/CURRENT-STATUS.md) for
> actual current development and cloud verdicts.
>
> **Latest-source status:** the local deployment/ABI/artifact, Halmos, Lean, and
> Certora-front-end reports bind reviewed source revision `d5af7136…` and manifest `7ae2208f…` and
> all pass. They are development-only solely because generation occurred in a
> dirty worktree. The aggregate bundle also passes as development-only and
> validates all six reports (SHA-256 `be386d63…`). Supplemental Certora cloud
> evidence is PARTIAL: threshold passes, while scalar and write-once retain
> sanity failures.

---

## 1. The one-paragraph mental model

We prove the same accounting property at increasing fidelity. Foundry runs the **real compiled bytecode** on
concrete and random inputs (R0/R1). **Halmos** runs that _same_ Solidity harness **symbolically** — every
function argument becomes a logical variable and the [SMT solver](../../docs/relay-verification/CONCEPTS.md#1-what-is-an-smt-solver) either proves the assertion for _all_ inputs
(in a bounded region) or returns a concrete counterexample (R2). **Kontrol** does symbolic execution at a
fixed signer count on KEVM (R3). **Lean + EVMYulLean** lifts the argument to a `∀N` theorem against a
_validated_ model of the EVM (R4). Cryptography (`ecrecover`, `keccak`) is never _proved_ — it is modeled as
an **uninterpreted function**, which is the sound, conservative choice (see §5).

New to the vocabulary (SMT, k-induction, CEX, psAt, KEVM)? The plain-words FAQ is
[`docs/relay-verification/CONCEPTS.md`](../../docs/relay-verification/CONCEPTS.md).

If you read only one thing next, read a small proof end to end:
[`RelaySigFV.t.sol`](RelaySigFV.t.sol) (Halmos) and [`lean/RelaySigLoop.lean`](lean/RelaySigLoop.lean) (Lean).

---

## 2. Reading a Halmos proof (`*FV.t.sol`)

A Halmos harness is an ordinary Foundry test contract, but functions named **`check_…`** are read by Halmos
as **proof obligations**, not example runs. The translation to logic:

| Solidity in a `check_` function                         | Logical meaning                                                            |
| ------------------------------------------------------- | -------------------------------------------------------------------------- |
| the function's **parameters** (`uint8 v, bytes32 r, …`) | **universally quantified** symbolic inputs (∀)                             |
| `vm.assume(P);`                                         | a **hypothesis** — restrict the ∀ to states where `P` holds                |
| `assert(Q);`                                            | the **goal** — Halmos proves `Q` on every path, or prints a counterexample |
| a call into `Relay`                                     | symbolic execution of the **real compiled bytecode**                       |
| `ecrecover` / precompile `0x01`                         | an **uninterpreted function** (see §5)                                     |

So `check_threshold_twoVoters_cannotAccept(...)` reads: _for all signatures, two voters carrying weight
≤ threshold can never make `relay()` accept._ Halmos discharges it by symbolic execution + SMT (z3 / cvc5 /
bitwuzla). A **pass** means "no counterexample exists in the bounded region"; a **fail** prints the exact
calldata that breaks the property.

**Two non-obvious things a newcomer must know:**

1. **Loop unrolling (`--loop`).** Halmos unrolls loops a fixed number of times (default **2**). `relay()`'s
   signature loop runs once per signature, so at the default bound a proof about 3+ signatures silently has
   its accepting iteration _truncated_ — the accept path looks unreachable and negative properties pass
   **vacuously** (true, but for the wrong reason). This project sets `loop = 6` in
   [`../../halmos.toml`](../../halmos.toml). It is a real hazard: it bit this suite once at the default.

2. **The anti-vacuity control.** Because a vacuous pass is worthless, every harness carries a **reachability
   control** that asserts the _negation_ of a reachable event, so Halmos **must refute it with a [witness](../../docs/relay-verification/CONCEPTS.md#7-what-is-a-cex-counterexamples-and-why-half-the-suite-celebrates-them)**.
   The gate script
   [`verify_fv.py`](verify_fv.py) enforces both halves: every `check_` proof must PASS **and** every
   declared control must produce a **validated counterexample model**. A timeout, stuck path, exception,
   all-revert result, invalid model, or truncated loop is never accepted as a witness.

### 2.1 The proof and compatibility inventories (normative)

[`verification-manifest.json`](verification-manifest.json) is the source of truth for expected behavior:

| Rule                                                 | Where established                                    | Effect                                                                                                          |
| ---------------------------------------------------- | ---------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| name starts with **`check_`**                        | the manifest's `function_prefix` is passed to Halmos | Halmos discovers the symbolic obligation                                                                        |
| identifier is in `halmos.proofs`                     | explicit manifest entry                              | only Halmos exit code `PASS` is healthy                                                                         |
| identifier is in `halmos.reachability`               | explicit manifest entry                              | only exit code `COUNTEREXAMPLE` with a validated model is healthy                                               |
| result is missing or undeclared                      | exact set comparison in `verify_fv.py`               | hard failure; deleting or silently adding a check cannot leave CI green                                         |
| assembly error is in `relay_custom_error_abi.errors` | explicit signature, selector, and use count          | `verify_relay_custom_error_abi.py` rejects selector/interface/use-site drift or non-canonical four-byte reverts |

Consequences to respect when adding checks:

- Add the fully-qualified identifier to exactly one manifest list. The `reach` naming convention remains
  useful to readers but no longer controls the machine verdict.
- **Every `check_` function carries a matching `EXPECT:` line** in the comment block directly above it, so
  the intent is readable at the function and greppable against the convention:
  - proofs end with `EXPECT: PASS` (canonical dedicated line: `// EXPECT: PASS (proof).`),
  - reachability controls with `EXPECT: COUNTEREXAMPLE` (canonical:
    `// EXPECT: COUNTEREXAMPLE (reachability control).`).

(The Kontrol harnesses under [`kontrol/`](kontrol/) follow the same idea with the `prove_` prefix and
`prove_reach_*` controls. Their JUnit output is checked against a separate exact manifest by
`kontrol/verify_kontrol.py`.)

Run the whole gate the way CI does (`test-fv-halmos`). Fresh clone? `./scripts/bootstrap-fv.sh` sets up
everything (node deps, forge build, the reference venv `./.venv-halmos`) and ends by running this gate:

```bash
python3 test-forge/fv/verify_relay_custom_error_abi.py \
  --report-output verification-reports/relay-custom-error-abi.json
FORGE=/path/to/manifest-pinned-forge HALMOS=$PWD/.venv-halmos/bin/halmos \
  .venv-halmos/bin/python test-forge/fv/verify_fv.py \
  --report-output verification-reports/relay-halmos.json
```

The first command enforces the current `relay()` assembly custom-error ABI. The
exact manifest pins 37 constants, error signatures, selectors, use counts, and
canonical four-byte revert encoding.

Before invoking Halmos, the proof gate clean-installs the checksummed Soldeer tree,
checks the pinned Foundry version/commit, and force-rebuilds the complete FV harness
tree with solc 0.8.35, Cancun, optimizer 200, and viaIR. Both that build and Halmos's
internal Forge build are confined to the manifest-derived `test-forge/fv` source/test
root under a sanitized, audited Foundry environment; unrelated mixed-version repository
sources cannot enter the proof build. The gate pins the tracked config, loop bound,
artifact directory, and Z3 solver on the child command, then hashes and audits the exact
compiler settings, source binding, and semantic bytecode of Relay,
RelayProxy, and all 28 declaring harness contracts before and after symbolic
execution. Any extra Halmos CLI arguments are diagnostic-only and can never mint
release evidence.

CI also runs [`verify_relay_artifact.py`](verify_relay_artifact.py). It recompiles Relay with the pinned FV
compiler, proves that its metadata-stripped creation and runtime bytecode equal the Hardhat deployment
artifact, and byte-compares the generated optimized Yul with the committed Lean source snapshot. Both
checks emit normalized JSON evidence consumed by the final bundle gate.

Every normalized report captures HEAD plus a hash/count of the complete Git
porcelain state at gate start and end. Only a passing in-process run that starts
and ends on the same clean HEAD is release eligible. Imported Halmos JSON
(`--results-input`) is explicitly development-only and content-bound by its raw
SHA-256; imported Forge artifact/IR inputs and custom-error source overrides receive
the same diagnostic-only treatment. Release evidence must come from each verifier's
in-process build/tool child. The Forge gates replace and hash ignored Soldeer inputs;
the deployment gate force-recreates lock-pinned node modules and Hardhat outputs;
and the Lean gate requires clean pinned EVMYulLean/package checkouts, refreshes the
pinned Lake caches, and clean-rebuilds EVMYul before importing it. Restoring a dirty checkout after a run cannot promote
that report. The
bundle rejects any development-only constituent unless `--allow-dirty` is used,
in which case the bundle itself remains development-only.

---

## 3. Reading a Lean proof (`lean/…`)

The R4 proofs are in [Lean 4](lean/) (a [theorem prover](../../docs/relay-verification/CONCEPTS.md#12-theorem-prover-lean-4)) and are checked against **EVMYulLean** (NethermindEth's Lean
formalization of EVM/Yul, itself validated against the standard `ethereum/tests` EVM conformance suite, incl. EEST-generated fixtures). Two entry points:

- [`lean/RelaySigLoop.lean`](lean/RelaySigLoop.lean) — the abstract `∀N ∀K` accounting proof, pure `ℕ`/`List`,
  no EVM. Readable by any mathematician: `threshold_sound` says _accept ⟹ total registered policy-slot weight > threshold_, conditional on unique voter addresses at admission.
- [`lean/bytecode-refinement/`](lean/bytecode-refinement/) — the same soundness lifted onto a loop executed by
  the _validated EVM semantics_, for all N. See its [`README.md`](lean/bytecode-refinement/README.md).

**"[Hole-free](../../docs/relay-verification/CONCEPTS.md#13-hole-free-and-print-axioms)" is a precise claim, and you can check it yourself.** Every declared audited result has a
`#print axioms` directive. A proof is trusted when that list is a subset of
`[propext, Classical.choice, Quot.sound]` — Lean's three standard
axioms — with **no `sorryAx`** (no gaps) and **no `Lean.ofReduceBool`** (no `native_decide`). Two proofs add
`zeroes_data` / `toByteArray_size`: these are _[documented, upstream-dischargeable specs](../../docs/relay-verification/CONCEPTS.md#14-the-two-extra-axioms-zeroes_data-tobytearray_size)_ (an `opaque` FFI
symbol and a `private` bound), not semantic assumptions — the file headers explain each, and the exact
upstream patches + verified discharge proofs are archived in
[`lean/bytecode-refinement/AXIOM_DISCHARGE.md`](lean/bytecode-refinement/AXIOM_DISCHARGE.md). To re-check:

```bash
git clone https://github.com/NethermindEth/EVMYulLean /tmp/evmyul2
cd /tmp/evmyul2 && git checkout 047f63070309f436b66c61e276ab3b6d1169265a  # 2025-09-24 (pinned, not HEAD)
lake exe cache get && lake clean && lake build EvmYul           # Lean 4.22.0
cp <repo>/test-forge/fv/lean/RelaySigLoop.lean . && lake env lean RelaySigLoop.lean   # exit 0
```

---

## 4. The other two tools (pointers)

- **Kontrol / KEVM** — [`kontrol/`](kontrol/): symbolic execution at a _fixed_ signer count, `vm.assume`-driven,
  cryptography uninterpreted. See [`kontrol/README.md`](kontrol/README.md).
- **Certora** — [`../../certora/specs/RelayInvariants.spec`](../../certora/specs/RelayInvariants.spec): storage
  invariants in CVL; `ecrecover`/self-call/`oldRelay` left `NONDET` so they cannot havoc `Relay`'s storage.
  [`verify_certora_local.py`](verify_certora_local.py) fail-closes on compiler,
  CVL typecheck, config, toolchain, and munge drift. It is not a cloud-proof
  substitute.

---

## 5. Cryptography is assumed, not proved — and why that is sound

`ecrecover` and `keccak256` are modeled as **uninterpreted functions**: deterministic (same inputs → same
output) but otherwise unconstrained. For `ecrecover` this hands the _adversary more power than reality_ — when
hunting a counterexample the solver may freely make the recovered signer equal any voter it likes. Any
accounting invariant that survives this (e.g. "cannot accept below total policy-slot weight" or "no slot index
is reused") therefore holds _a fortiori_ under real ECDSA. Distinct voter addresses
are a separate policy-admission premise and are not currently enforced on-chain.
What is **not** proved is "a non-voter cannot forge a signature" — that is ECDSA
unforgeability, a cryptographic fact outside the EVM model.

One subtlety is load-bearing and easy to get wrong (it caused a past bug): the **precompile `0x01` does not
revert on a bad signature** — it returns _success with empty return data_ (`returndatasize()==0`) and leaves
the caller's output buffer _stale_. This differs from Solidity's high-level `ecrecover`, which returns
`address(0)`. `Relay.sol` calls the precompile in raw assembly, so it must guard with `staticcall` success +
`returndatasize()==32` + non-zero signer. That failure ABI is pinned concretely by
[`RelayEcrecoverABI.t.sol`](RelayEcrecoverABI.t.sol) (real EVM) and proved symbolically by
[`RelayEcrecoverSymbolicFV.t.sol`](RelayEcrecoverSymbolicFV.t.sol) (obligation **OP-1** in the claims ledger,
[`docs/relay-verification/10-…`](../../docs/relay-verification/10-claims-ledger-trust-and-residual.md)).

The full trust base — every assumption, where it lives, and how it is discharged — is the claims ledger:
[`docs/relay-verification/10-claims-ledger-trust-and-residual.md`](../../docs/relay-verification/10-claims-ledger-trust-and-residual.md).

---

## 6. File map

**Signature loop / threshold accounting (the core property).**
[`RelaySigFV.t.sol`](RelaySigFV.t.sol) · [`RelaySigParamFV.t.sol`](RelaySigParamFV.t.sol) ·
[`RelayCanonicalityFV.t.sol`](RelayCanonicalityFV.t.sol) (bad-`v`/high-`s`/zero-signer gates) ·
[`RelayModelBridgeFV.t.sol`](RelayModelBridgeFV.t.sol) (bytecode ↔ prefix-sum model).

**ecrecover failure ABI (OP-1).** [`RelayEcrecoverABI.t.sol`](RelayEcrecoverABI.t.sol) (concrete) ·
[`RelayEcrecoverSymbolicFV.t.sol`](RelayEcrecoverSymbolicFV.t.sol) (symbolic).

**Epoch / policy-rotation decision matrix.** [`RelayWrongEpochFV.t.sol`](RelayWrongEpochFV.t.sol) ·
[`RelayDelayedPolicyFV.t.sol`](RelayDelayedPolicyFV.t.sol) ·
[`RelayFinalizationWindowFV.t.sol`](RelayFinalizationWindowFV.t.sol) ·
[`RelayCrossEpochFV.t.sol`](RelayCrossEpochFV.t.sol) ·
[`RelayMustUseNewPolicyFV.t.sol`](RelayMustUseNewPolicyFV.t.sol) ·
[`RelayThresholdScalingFV.t.sol`](RelayThresholdScalingFV.t.sol) ·
[`RelayThresholdConsistencyFV.t.sol`](RelayThresholdConsistencyFV.t.sol) ·
[`RelayModeOneFV.t.sol`](RelayModeOneFV.t.sol) · [`RelayEpochAdvanceFV.t.sol`](RelayEpochAdvanceFV.t.sol).

**Randomness / Merkle / fees / misc.** [`RelayRandomMonotonicityFV.t.sol`](RelayRandomMonotonicityFV.t.sol) ·
[`RelayRandomBindingFV.t.sol`](RelayRandomBindingFV.t.sol) ·
[`RelayIsSecureNormFV.t.sol`](RelayIsSecureNormFV.t.sol) ·
[`RelayMerkleProofFV.t.sol`](RelayMerkleProofFV.t.sol) · [`RelayMerkleFoldFV.t.sol`](RelayMerkleFoldFV.t.sol) ·
[`RelayVerifyFeeFV.t.sol`](RelayVerifyFeeFV.t.sol) ·
[`RelayFeeConservationFV.t.sol`](RelayFeeConservationFV.t.sol) ·
[`RelayPolicyHashFV.t.sol`](RelayPolicyHashFV.t.sol) · [`RelaySigParamFV.t.sol`](RelaySigParamFV.t.sol) ·
[`RelayReturnDiscriminatorFV.t.sol`](RelayReturnDiscriminatorFV.t.sol) ·
[`RelayAccessControlFV.t.sol`](RelayAccessControlFV.t.sol) ·
[`RelayConstructorFV.t.sol`](RelayConstructorFV.t.sol) ·
[`RelayOwnerTimelockFV.t.sol`](RelayOwnerTimelockFV.t.sol).

**Harness base + gate + Lean.** [`../unit/protocol/implementation/Relay.t.sol`](../unit/protocol/implementation/Relay.t.sol)
(the shared `RelayTestBase` calldata encoders, reused by the Halmos harnesses) ·
[`verify_fv.py`](verify_fv.py) (the CI gate) · [`lean/`](lean/) (R4 Lean proofs) · [`kontrol/`](kontrol/).

**Safe governance (retired).** The `SafeGovernanceFV` harness, the
`verify_gss_governance.py` gate and the fixed-block source-Safe checker were
removed with the retired Safe-governance design (git history); their inventories
are absent from the current manifest.

Do not cite the Halmos inventory as a proof of ECDSA. Kontrol remains historical;
Lean covers indexed accounting plus the supported protocol-1 threshold seam,
not cryptography or the complete self-call call frame. The Certora rules under
`certora/` have been re-baselined to owner/timelock and threshold inputs, and
their local front end passes 3/3 configs and 15 rules on `d5af7136…`. This is
compilation/munging/CVL-typecheck evidence, not a prover verdict. The normalized
supplemental cloud report is PARTIAL: the
[threshold job](https://prover.certora.com/output/3798318/a133698c16d54e7cb4a518a3251dd73a)
passes, while the
[scalar](https://prover.certora.com/output/3798318/96136f4b1ce349889963c722745f6d8a)
and
[write-once](https://prover.certora.com/output/3798318/5f29c9d404134b7aa3578484455bf424)
jobs retain sanity failures. The threshold job proves exact arithmetic and
fail-fast behavior for `_thresholdBIPS >= 10000` before any `SSTORE`, `TSTORE`,
or external `CALL`; successful forwarding, cleanup, rollback, and mode
isolation remain Halmos/Lean claims. See the current status page for report
hashes and the complete evidence boundary.
