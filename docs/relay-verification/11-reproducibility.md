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
| Lean (Phase A) | Lean 4 core | `elan` (no mathlib needed) |
| Lean (Gap B) | Lean **4.22.0** + mathlib 4.22.0 + FFI | `elan` + EVMYulLean (§11.7) |
| EVMYulLean | NethermindEth/EVMYulLean @ HEAD | `git clone` (§11.7) |

Repo build config: `foundry.toml` sets `src=contracts`, `test=test-forge`, `out=artifacts-forge`,
`evm_version=cancun`, `optimizer=true/200`, and `skip=['*.yul']` (so reference IR artifacts aren't
compiled). FV config: `halmos.toml` sets `loop=6`, `solver-timeout-assertion=0`, `forge-build-out=artifacts-forge`.

---

## 11.2 R0/R1 — Foundry tests

```bash
forge build
forge test -vvv --match-path 'test-forge/unit/protocol/implementation/Relay.t.sol'
forge coverage --match-path 'test-forge/unit/protocol/implementation/Relay.t.sol'
```

Expect: 52 tests pass. **CI:** `test-unit-forge` (`forge test -vvv`), `coverage-forge` (+ `coverage-forge-reports`).

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
Triggered on changes to `Relay.sol`, the relay interfaces, `test-forge/fv/**`, or `halmos.toml`.

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

## 11.6 R4a — Lean Phase A

```bash
# Lean 4 core (elan auto-fetches the toolchain); no mathlib, no EVM:
lean test-forge/fv/lean/RelaySigLoop.lean
```

Expect: no errors; `#print axioms threshold_sound` = `[propext, Quot.sound]` (no `sorryAx`). Checks in
seconds.

---

## 11.7 R4b — Lean Gap B (against validated EVM semantics)

```bash
# 1. build the validated semantics (one-time):
cd /tmp && git clone --depth 1 https://github.com/NethermindEth/EVMYulLean evmyul2
cd evmyul2 && lake exe cache get && lake build      # elan reads lean-toolchain → Lean 4.22.0
# 2. check the capstone (use the GIT-COMMITTED copy to prove you're checking what's in version control):
git -C <repo> show HEAD:test-forge/fv/lean/gapB/GapB_close.lean > /tmp/evmyul2/GapB_verify.lean
cd /tmp/evmyul2
export PATH="$HOME/.elan/bin:/usr/local/opt/openjdk/bin:$PATH"
lake env lean GapB_verify.lean
```

Expect exit 0 and, from the file's trailing `#print axioms`:
```
'GapB.loop_acc' depends on axioms: [propext, Classical.choice, Quot.sound]
'GapB.bytecode_loop_correct' depends on axioms: [propext, Classical.choice, Quot.sound]
'GapB.bytecode_threshold_sound' depends on axioms: [propext, Classical.choice, Quot.sound]
```
No `error:`, no `sorry`/`sorryAx`. The staged bricks `gapB/GapB_*.lean` check the same way and are the
tutorial trail; the engineering log is `gapB/PROGRESS.md`.

> Host notes: EVMYulLean's memory uses an FFI byte-array backend (keccak/sha2/`ByteArray.zeroes`).
> `#eval`/`native_decide` on standalone files cannot link the extern lib — which is why the Gap-B proofs
> are symbolic and avoid `native_decide` entirely (this also keeps the axiom list clean).

---

## 11.8 The axiom audit (how to certify "hole-free")

For any Lean theorem, the certificate is its `#print axioms` output. The bar (the engagement's definition
of "done"):

- **allowed:** `propext`, `Classical.choice`, `Quot.sound` (standard, consistent, domain-neutral);
- **forbidden:** `sorryAx` (any hole/incomplete proof in the dependency tree) and `Lean.ofReduceBool`
  (would appear if `native_decide` were used — enlarges the trusted base; deliberately avoided).

Grep the build output for `sorryAx`/`error:` to mechanize the check in CI.

---

## 11.9 CI job map (what runs what, automatically)

| CI job | Rung | Command | Status |
|--------|------|---------|--------|
| `test-unit-forge` | R0/R1 | `forge test -vvv` | ✅ |
| `coverage-forge` (+ `-reports`) | R0/R1 | `forge build` + coverage | ✅ |
| `test-fv-halmos` | R2 | `python3 test-forge/fv/verify_fv.py` | ✅ |
| `build-smart-contracts`, `test-linter`, `test-linter-forge` | build/lint | `forge build` / solhint | ✅ |
| (Kontrol) | R3 | Docker image; run offline (heavy) | manual/offline |
| (Certora) | R3 | `certoraRun` (needs key) | manual/offline |
| (Lean Phase A / Gap B) | R4 | `lean` / `lake env lean` | manual/offline |

R0–R2 run on every relevant push (the green pipeline). R3/R4 are heavyweight or key/toolchain-gated and are
reproduced offline per the sections above; their artifacts are committed so the results are re-checkable.

**Next:** [L12 — Lessons](12-lessons.md): the transferable method distilled from all of this.
