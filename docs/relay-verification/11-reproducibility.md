# L11 — Reproducibility

> **What you get from this level — the reproducibility core.** Exact toolchains, versions, commands, and
> expected outputs to independently re-check every claim in the ledger ([L10](10-claims-ledger-trust-and-residual.md)),
> rung by rung, plus the CI mapping that runs them automatically. Paired with L10, this is what makes the
> engagement an *audit*, not an assertion.

All commands are from the repo root unless noted: `flare-smart-contracts-v2/`.

---

## 11.1 Toolchain versions

| Tool | Version (verified) | Install / source |
|------|--------------------|------------------|
| Foundry (`forge`) | **1.7.1** (suite-verified); `foundry:stable` / `foundryup` in CI | `curl -L https://foundry.paradigm.xyz \| bash && foundryup` |
| `solc` | 0.8.27 (Relay pragma `^0.8.13`) | foundry-managed / system |
| Halmos | **0.3.3** (CI: `python:3.12`) | `pip install --user halmos` |
| z3 (SMT solver) | **4.12.6** | implicit Halmos dependency |
| Kontrol / KEVM | Kontrol **v1.0.248**, K **v7.1.334** | pinned Docker image (§11.5) |
| Certora CLI | **8.16.1** | `pip install certora-cli` (+ `CERTORAKEY` for cloud) |
| Lean (the abstract proof) | Lean 4 core | `elan` (no mathlib needed) |
| Lean (the bytecode refinement) | Lean **4.22.0** + mathlib 4.22.0 + FFI | `elan` + EVMYulLean (§11.7) |
| EVMYulLean | NethermindEth/EVMYulLean **pinned @ `047f6307`** (2025-09-24) | `git clone` + `git checkout` (§11.7) |

Repo build config: [`foundry.toml`](../../foundry.toml) sets `src=contracts`, `test=test-forge`, `out=artifacts-forge`,
`evm_version=cancun`, `optimizer=true/200`, and `skip=['*.yul']` (so reference IR artifacts aren't
compiled). FV config: [`halmos.toml`](../../halmos.toml) sets `loop=6`, `solver-timeout-assertion=0`, `forge-build-out=artifacts-forge`.

---

## 11.2 R0/R1 — Foundry tests

```bash
forge build
forge test -vvv --match-path 'test-forge/unit/protocol/implementation/Relay.t.sol'
forge coverage --match-path 'test-forge/unit/protocol/implementation/Relay.t.sol'
```

Expect: 59 tests pass. **CI:** `test-unit-forge` (`forge test -vvv`), `coverage-forge` (+ `coverage-forge-reports`).

---

## 11.3 R2 — Halmos suite (the FV gate)

```bash
pip install --user halmos
forge build
# the exact CI gate (reads halmos.toml: loop=6, solver-timeout-assertion=0):
HALMOS=halmos python3 test-forge/fv/verify_fv.py
# a single harness:
halmos --contract RelaySigParamFV
# tripwire demo — too-small bound must FAIL with vacuity alarms:
python3 test-forge/fv/verify_fv.py --loop 2
```

Expect from the gate:
```
[fv] 85 checks: 57 proofs hold, 28 reachability controls live (CEX). 0 violation(s).
[fv] OK — all proofs hold and every reachability control is live (non-vacuous).
```
**CI:** `test-fv-halmos` (`python:3.12` image; installs halmos + foundry, `forge build`, then the gate).
Triggered on changes to [`Relay.sol`](../../contracts/protocol/implementation/Relay.sol), the relay interfaces, `test-forge/fv/**`, or [`halmos.toml`](../../halmos.toml).

> Note: a Halmos "counterexample" on an obviously-true assertion is usually a **solver timeout**, not a
> bug. `solver-timeout-assertion=0` in `halmos.toml` is what lets the nonlinear `RelayThresholdScalingFV`
> proofs finish (see the CI-gate memory / commit `37a27851`).

---

## 11.4 R3 — Certora

```bash
pip install certora-cli            # 8.16.1
# Local typecheck (no key, no cloud) — compiles Relay under Certora + typechecks the spec; passes:
certoraRun certora/Relay.conf --compilation_steps_only --solc /path/to/solc-0.8.27
# Full cloud proof (needs an account):
export CERTORAKEY=<your key>
certoraRun certora/Relay.conf --solc /path/to/solc-0.8.27
```

Expect: local typecheck exits 0 (only benign OZ-`MerkleProof` summarization warnings). The cloud run
reproduces the **documented spurious violations** (the storage-havoc wall, [L5 §5.2](05-R3-unbounded-attempts.md));
prior runs: `prover.certora.com/output/3798318/{a9a6c094…, 93ef4cf5…}`.

---

## 11.5 R3 — Kontrol

```bash
# one-time toolchain image (~18.5 GB; best on native x86_64 Linux):
docker build -f test-forge/fv/kontrol/Dockerfile -t kontrol-local:ready .
# run a harness:
docker run --rm --platform linux/amd64 -v "$PWD/test-forge/fv/kontrol":/work kontrol-local:ready sh /work/run.sh
```

Per harness: `forge build` (~1 s) → `kontrol build` (~8–18 min, reuses the baked kdist) → `kontrol prove`.
**Judge from the per-test PASSED/FAILED list, not the exit code** (reachability controls FAIL by design).
Expect the verdicts in [L5 §5.1](05-R3-unbounded-attempts.md) (5 PROVE + 2 CEX for `RelaySigLoopFV`, etc.).
Pinned: Kontrol v1.0.248, K v7.1.334, `nixpkgs @ 9eac87a…`, base image by sha256 digest.

---

## 11.6 R4a — the abstract proof (Lean)

```bash
# Lean 4 core (elan auto-fetches the toolchain); no mathlib, no EVM:
lean test-forge/fv/lean/RelaySigLoop.lean
```

Expect: no errors; `#print axioms threshold_sound` = `[propext, Quot.sound]` (no `sorryAx`). Checks in
seconds.

---

## 11.7 R4b — the bytecode refinement (against validated EVM semantics)

```bash
# 1. build the validated semantics (one-time), PINNED to the commit these proofs were checked against:
cd /tmp && git clone https://github.com/NethermindEth/EVMYulLean evmyul2
cd evmyul2 && git checkout 047f63070309f436b66c61e276ab3b6d1169265a   # 2025-09-24; do NOT use HEAD
lake exe cache get && lake build                    # elan reads lean-toolchain → Lean 4.22.0
# 2. check the capstone (use the GIT-COMMITTED copy to prove you're checking what's in version control):
git -C <repo> show HEAD:test-forge/fv/lean/bytecode-refinement/RelayBytecodeRefinement.lean > /tmp/evmyul2/RelayBytecodeRefinement_verify.lean
cd /tmp/evmyul2
export PATH="$HOME/.elan/bin:/usr/local/opt/openjdk/bin:$PATH"
lake env lean RelayBytecodeRefinement_verify.lean
```

Expect exit 0 and, from the file's trailing `#print axioms`:
```
'RelayBytecodeRefinement.loop_acc' depends on axioms: [propext, Classical.choice, Quot.sound]
'RelayBytecodeRefinement.bytecode_loop_correct' depends on axioms: [propext, Classical.choice, Quot.sound]
'RelayBytecodeRefinement.bytecode_threshold_sound' depends on axioms: [propext, Classical.choice, Quot.sound]
'RelayBytecodeRefinement.absAcc_val' depends on axioms: [propext]
'RelayBytecodeRefinement.bytecode_threshold_sound_int' depends on axioms: [propext, Classical.choice, Quot.sound]
```
No `error:`, no `sorry`/`sorryAx`. The file is self-contained; its scope and assumptions are in
[`test-forge/fv/lean/bytecode-refinement/README.md`](../../test-forge/fv/lean/bytecode-refinement/README.md).

> Host notes: EVMYulLean's memory uses an FFI byte-array backend (keccak/sha2/`ByteArray.zeroes`).
> `#eval`/`native_decide` on standalone files cannot link the extern lib — which is why the bytecode-refinement proofs
> are symbolic and avoid `native_decide` entirely (this also keeps the axiom list clean).

### The whole Lean gate (all 8 files) — the `test-fv-lean` CI job

The check above verifies one file in isolation. The full R4b + R5 Lean development — **8 files**, hole-freeness
enforced — is checked in one command, exactly as CI does it:

```bash
# after the one-time EVMYulLean build above:
EVMYUL_DIR=/tmp/evmyul2 python3 test-forge/fv/lean/verify_lean.py   # exit 0 = all 8 files hole-free
```

`verify_lean.py` type-checks every file under `test-forge/fv/lean/bytecode-refinement/` against the pinned
semantics and asserts each `#print axioms` line stays within the allowed set (rejecting any `sorryAx` /
`native_decide`):

- **STANDALONE** (import `EvmYul` only): `RelayBytecodeRefinement`, `DataLayer`, `RelayLoopMemRead`,
  `RelayLoopWindows`, `RelayLoopLiteral`, `RelayStorageLayer` (R5.1/5.3 storage + accept-write),
  `RelayFeeLayer` (R5.4 fees).
- **INTEGRATION** (imports three siblings — compiled into the package lib first): `RelayBodyEff` (the literal
  loop-body model, the mode dispatch, and the end-to-end composition).

Allowed axioms: `⊆ {propext, Classical.choice, Quot.sound}` + the two documented data-layer specs
`zeroes_data`, `toByteArray_size` (see §11.8 and [`AXIOM_DISCHARGE.md`](../../test-forge/fv/lean/bytecode-refinement/AXIOM_DISCHARGE.md)).
The same job is wired into `.gitlab-ci.yml` as **`test-fv-lean`** (clones + builds EVMYulLean pinned, then runs
`verify_lean.py`), gated on changes under `test-forge/fv/lean/**`.

---

## 11.8 The axiom audit (how to certify "hole-free")

For any Lean theorem, the certificate is its `#print axioms` output. The bar (the engagement's definition
of "done"):

- **allowed:** `propext`, `Classical.choice`, `Quot.sound` (standard, consistent, domain-neutral) — plus the
  two documented, upstream-dischargeable data-layer specs `zeroes_data` / `toByteArray_size`, flagged only on
  the memory-*write* results (§L9 §G; [`AXIOM_DISCHARGE.md`](../../test-forge/fv/lean/bytecode-refinement/AXIOM_DISCHARGE.md));
- **forbidden:** `sorryAx` (any hole/incomplete proof in the dependency tree) and `Lean.ofReduceBool`
  (would appear if `native_decide` were used — enlarges the trusted base; deliberately avoided).

Grepping the build output for `sorryAx`/`error:` and auditing every `#print axioms` line is exactly what
[`test-forge/fv/lean/verify_lean.py`](../../test-forge/fv/lean/verify_lean.py) mechanizes — the `test-fv-lean`
CI gate (§11.7).

---

## 11.9 CI job map (what runs what, automatically)

| CI job | Rung | Command | Status |
|--------|------|---------|--------|
| `test-unit-forge` | R0/R1 | `forge test -vvv` | ✅ |
| `coverage-forge` (+ `-reports`) | R0/R1 | `forge build` + coverage | ✅ |
| `test-fv-halmos` | R2 | `python3 test-forge/fv/verify_fv.py` | ✅ |
| `build-smart-contracts`, `test-linter`, `test-linter-forge` | build/lint | `forge build` / solhint | ✅ |
| `test-fv-lean` | R4b/R5 | `python3 test-forge/fv/lean/verify_lean.py` (pinned EVMYulLean, all 8 files hole-free) | ✅ |
| (Kontrol) | R3 | Docker image; run offline (heavy) | manual/offline |
| (Certora) | R3 | `certoraRun` (needs key) | manual/offline |
| (Lean the abstract proof) | R4a | `lake env lean RelaySigLoop.lean` | manual/offline |

R0–R2 **and R4b/R5** run on every relevant push (the green pipeline — the latter via `test-fv-lean`, gated on
`test-forge/fv/lean/**`). R3 and R4a are heavyweight or key/toolchain-gated and are reproduced offline per the
sections above; their artifacts are committed so the results are re-checkable.

**Next:** [L12 — Lessons](12-lessons.md): the transferable method distilled from all of this.
