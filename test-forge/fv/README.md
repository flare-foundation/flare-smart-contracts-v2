# `test-forge/fv/` — the Relay formal-verification suite (a reader's guide)

This directory holds the machine-checked proofs about `Relay.sol` — rungs **R2–R4** of the fidelity ladder.
The narrative, audit-facing companion is [`docs/relay-verification/`](../../docs/relay-verification/) (start at
[`00-README.md`](../../docs/relay-verification/00-README.md)); the working notes are
[`docs/relay-fv.md`](../../docs/relay-fv.md). This file is the **tooling primer**: it assumes you are a
mathematician / computer scientist but *not* yet fluent in the verification tools, and tells you how to read,
run, and trust everything here.

---

## 1. The one-paragraph mental model

We prove the same accounting property at increasing fidelity. Foundry runs the **real compiled bytecode** on
concrete and random inputs (R0/R1). **Halmos** runs that *same* Solidity harness **symbolically** — every
function argument becomes a logical variable and the SMT solver either proves the assertion for *all* inputs
(in a bounded region) or returns a concrete counterexample (R2). **Kontrol** does symbolic execution at a
fixed signer count on KEVM (R3). **Lean + EVMYulLean** lifts the argument to a `∀N` theorem against a
*validated* model of the EVM (R4). Cryptography (`ecrecover`, `keccak`) is never *proved* — it is modeled as
an **uninterpreted function**, which is the sound, conservative choice (see §5).

If you read only one thing next, read a small proof end to end:
[`RelaySigFV.t.sol`](RelaySigFV.t.sol) (Halmos) and [`lean/RelaySigLoop.lean`](lean/RelaySigLoop.lean) (Lean).

---

## 2. Reading a Halmos proof (`*FV.t.sol`)

A Halmos harness is an ordinary Foundry test contract, but functions named **`check_…`** are read by Halmos
as **proof obligations**, not example runs. The translation to logic:

| Solidity in a `check_` function | Logical meaning |
|---|---|
| the function's **parameters** (`uint8 v, bytes32 r, …`) | **universally quantified** symbolic inputs (∀) |
| `vm.assume(P);` | a **hypothesis** — restrict the ∀ to states where `P` holds |
| `assert(Q);` | the **goal** — Halmos proves `Q` on every path, or prints a counterexample |
| a call into `Relay` | symbolic execution of the **real compiled bytecode** |
| `ecrecover` / precompile `0x01` | an **uninterpreted function** (see §5) |

So `check_threshold_twoVoters_cannotAccept(...)` reads: *for all signatures, two voters carrying weight
≤ threshold can never make `relay()` accept.* Halmos discharges it by symbolic execution + SMT (z3 / cvc5 /
bitwuzla). A **pass** means "no counterexample exists in the bounded region"; a **fail** prints the exact
calldata that breaks the property.

**Two non-obvious things a newcomer must know:**

1. **Loop unrolling (`--loop`).** Halmos unrolls loops a fixed number of times (default **2**). `relay()`'s
   signature loop runs once per signature, so at the default bound a proof about 3+ signatures silently has
   its accepting iteration *truncated* — the accept path looks unreachable and negative properties pass
   **vacuously** (true, but for the wrong reason). This project sets `loop = 6` in
   [`../../halmos.toml`](../../halmos.toml). It is a real hazard: it bit this suite once at the default.

2. **The anti-vacuity control.** Because a vacuous pass is worthless, every harness carries a **reachability
   control** that asserts the *negation* of a reachable event, so Halmos **must refute it with a witness**.
   The gate script
   [`verify_fv.py`](verify_fv.py) enforces both halves: every `check_` proof must PASS **and** every
   declared control must produce a **validated counterexample model**. A timeout, stuck path, exception,
   all-revert result, invalid model, or truncated loop is never accepted as a witness.

### 2.1 The proof inventory (normative)

[`verification-manifest.json`](verification-manifest.json) is the source of truth for expected behavior:

| Rule | Where established | Effect |
|---|---|---|
| name starts with **`check_`** | the manifest's `function_prefix` is passed to Halmos | Halmos discovers the symbolic obligation |
| identifier is in `halmos.proofs` | explicit manifest entry | only Halmos exit code `PASS` is healthy |
| identifier is in `halmos.reachability` | explicit manifest entry | only exit code `COUNTEREXAMPLE` with a validated model is healthy |
| result is missing or undeclared | exact set comparison in `verify_fv.py` | hard failure; deleting or silently adding a check cannot leave CI green |

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
HALMOS=$PWD/.venv-halmos/bin/halmos .venv-halmos/bin/python test-forge/fv/verify_fv.py \
  --report-output verification-reports/relay-halmos.json
```

Before this gate, CI runs [`verify_relay_artifact.py`](verify_relay_artifact.py). It recompiles Relay with
the pinned FV compiler, proves that its metadata-stripped creation and runtime bytecode equal the Hardhat
deployment artifact, and byte-compares the generated optimized Yul with the committed Lean source snapshot.

---

## 3. Reading a Lean proof (`lean/…`)

The R4 proofs are in [Lean 4](lean/) and are checked against **EVMYulLean** (NethermindEth's Lean
formalization of EVM/Yul, itself validated against the Ethereum execution-spec tests). Two entry points:

- [`lean/RelaySigLoop.lean`](lean/RelaySigLoop.lean) — the abstract `∀N ∀K` accounting proof, pure `ℕ`/`List`,
  no EVM. Readable by any mathematician: `threshold_sound` says *accept ⟹ total registered weight > threshold*.
- [`lean/bytecode-refinement/`](lean/bytecode-refinement/) — the same soundness lifted onto a loop executed by
  the *validated EVM semantics*, for all N. See its [`README.md`](lean/bytecode-refinement/README.md).

**"Hole-free" is a precise claim, and you can check it yourself.** Every declared audited result has a
`#print axioms` directive. A proof is trusted when that list is a subset of
`[propext, Classical.choice, Quot.sound]` — Lean's three standard
axioms — with **no `sorryAx`** (no gaps) and **no `Lean.ofReduceBool`** (no `native_decide`). Two proofs add
`zeroes_data` / `toByteArray_size`: these are *documented, upstream-dischargeable specs* (an `opaque` FFI
symbol and a `private` bound), not semantic assumptions — the file headers explain each, and the exact
upstream patches + verified discharge proofs are archived in
[`lean/bytecode-refinement/AXIOM_DISCHARGE.md`](lean/bytecode-refinement/AXIOM_DISCHARGE.md). To re-check:

```bash
git clone https://github.com/NethermindEth/EVMYulLean /tmp/evmyul2
cd /tmp/evmyul2 && git checkout 047f63070309f436b66c61e276ab3b6d1169265a  # 2025-09-24 (pinned, not HEAD)
lake exe cache get && lake build                                # Lean 4.22.0
cp <repo>/test-forge/fv/lean/RelaySigLoop.lean . && lake env lean RelaySigLoop.lean   # exit 0
```

---

## 4. The other two tools (pointers)

- **Kontrol / KEVM** — [`kontrol/`](kontrol/): symbolic execution at a *fixed* signer count, `vm.assume`-driven,
  cryptography uninterpreted. See [`kontrol/README.md`](kontrol/README.md).
- **Certora** — [`../../certora/specs/RelayInvariants.spec`](../../certora/specs/RelayInvariants.spec): storage
  invariants in CVL; `ecrecover`/self-call/`oldRelay` left `NONDET` so they cannot havoc `Relay`'s storage.

---

## 5. Cryptography is assumed, not proved — and why that is sound

`ecrecover` and `keccak256` are modeled as **uninterpreted functions**: deterministic (same inputs → same
output) but otherwise unconstrained. For `ecrecover` this hands the *adversary more power than reality* — when
hunting a counterexample the solver may freely make the recovered signer equal any voter it likes. Any
accounting invariant that survives this (e.g. "cannot accept below the weight threshold", "no voter counted
twice") therefore holds *a fortiori* under real ECDSA. What is **not** proved is "a non-voter cannot forge a
signature" — that is ECDSA unforgeability, a cryptographic fact outside the EVM model.

One subtlety is load-bearing and easy to get wrong (it caused a past bug): the **precompile `0x01` does not
revert on a bad signature** — it returns *success with empty return data* (`returndatasize()==0`) and leaves
the caller's output buffer *stale*. This differs from Solidity's high-level `ecrecover`, which returns
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
[`RelayGovernanceNonceFV.t.sol`](RelayGovernanceNonceFV.t.sol) (RLY-02 replay) ·
[`RelayPolicyHashFV.t.sol`](RelayPolicyHashFV.t.sol) · [`RelaySigParamFV.t.sol`](RelaySigParamFV.t.sol) ·
[`RelayReturnDiscriminatorFV.t.sol`](RelayReturnDiscriminatorFV.t.sol) ·
[`RelayAccessControlFV.t.sol`](RelayAccessControlFV.t.sol) ·
[`RelayConstructorFV.t.sol`](RelayConstructorFV.t.sol).

**Harness base + gate + Lean.** [`../unit/protocol/implementation/Relay.t.sol`](../unit/protocol/implementation/Relay.t.sol)
(the shared `RelayTestBase` calldata encoders, reused by the Halmos harnesses) ·
[`verify_fv.py`](verify_fv.py) (the CI gate) · [`lean/`](lean/) (R4 Lean proofs) · [`kontrol/`](kontrol/).
