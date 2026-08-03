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
| Python orchestration | **3.11.6** | CI image `python:3.11.6-bookworm@sha256:ba7a…` |
| Foundry (`forge`) | **1.7.1** | immutable release archive, SHA-256 `cf7e688e…`; no moving `stable`/`foundryup` in FV CI |
| `solc` | FV **0.8.27+commit.40a35a09**; deployment **0.8.30+commit.73712a01** | both checked from artifact metadata; semantic bytecode parity is mandatory |
| Halmos | **0.3.3** (Python 3.11.6) | full pinned closure in [`test-forge/fv/requirements-halmos.lock`](../../test-forge/fv/requirements-halmos.lock) |
| z3 (SMT solver) | **4.12.6.0** | pinned in the same lock (CI installs `halmos==0.3.3 z3-solver==4.12.6.0`) |
| Kontrol / KEVM | Kontrol **v1.0.248**, K **v7.1.334** | pinned Docker image (§11.5) |
| Certora CLI / Java | **8.16.1 / JDK 21+** | pinned local front-end gate; `CERTORAKEY` only for cloud proof |
| Lean (the abstract proof) | Lean 4 core | `elan` (no mathlib needed) |
| Lean (the bytecode refinement) | Lean **4.22.0** + mathlib 4.22.0 + FFI | `elan` + EVMYulLean (§11.7) |
| EVMYulLean | NethermindEth/EVMYulLean **pinned @ `047f6307`** (2025-09-24) | `git clone` + `git checkout` (§11.7) |

Repo build config: [`foundry.toml`](../../foundry.toml) sets `src=contracts`, `test=test-forge`, `out=artifacts-forge`,
`evm_version=cancun`, `optimizer=true/200`, and `skip=['*.yul']` (so reference IR artifacts aren't
compiled). FV config: [`halmos.toml`](../../halmos.toml) sets `loop=6`, `solver-timeout-assertion=0`, `forge-build-out=artifacts-forge`.

The normative machine-readable record is
[`test-forge/fv/verification-manifest.json`](../../test-forge/fv/verification-manifest.json). It owns the
compiler settings, 102-check Halmos inventory, exact 36-test GSS inventory, fixed-block Safe snapshot,
Certora local toolchain/configs, EVMYulLean pin, allowed Lean axioms, exact axiom-audit counts,
required capstones, and the 37-message legacy `relay()` assembly revert ABI. Changes to proof inventory,
trust settings, or that compatibility surface therefore appear as explicit manifest diffs.

---

## 11.2 R0/R1 — Foundry tests

```bash
forge build --force --ast --extra-output storageLayout metadata
forge test -vvv --match-path 'test-forge/unit/protocol/implementation/Relay.t.sol'
forge test -vvv --match-path 'test-forge/unit/protocol/implementation/RelayChainDomain.t.sol'
forge test -vvv --match-path 'test-forge/unit/governance/GSSGovernance.t.sol'
forge test -vvv --match-path 'test-forge/unit/governance/GSSGovernanceProductionRehearsal.t.sol'
forge test -vvv --match-path 'test-forge/invariant/governance/GSSGovernanceInvariant.t.sol'
forge coverage --match-path 'test-forge/unit/protocol/implementation/Relay.t.sol'
```

Expect: the full Forge tree passes (967 tests in the recorded run). The exact
GSS gate below requires 36/36 tests: 30 unit/differential tests, 3
production-rehearsal tests, and 3 state-machine tests, including 128 invariant
runs at depth 128 (16,384 calls). **CI:** `test-unit-forge` (`forge test -vvv`),
`coverage-forge` (+ `coverage-forge-reports`).

---

## 11.3 R2 — Halmos suite (the FV gate)

```bash
# ONE-COMMAND form (fresh clone): node deps + forge build + ./.venv-halmos + this gate:
./scripts/bootstrap-fv.sh
# ...or manually — recreate the REFERENCE toolchain (the venv every green run + doc-quoted output comes
# from; lives at the REPO ROOT, gitignored):
python3.11 -m venv .venv-halmos
.venv-halmos/bin/pip install -r test-forge/fv/requirements-halmos.lock
forge build
# create deployment provenance after Hardhat compilation:
node scripts/relay-artifact-provenance.js --output verification-reports/relay-deployment.json
# pin every legacy relay() assembly Error(string) payload:
python3 test-forge/fv/verify_relay_revert_abi.py \
  --report-output verification-reports/relay-revert-abi.json
# bind FV solc output + optimized Yul to the deployment artifact:
.venv-halmos/bin/python test-forge/fv/verify_relay_artifact.py \
  --deployment-report verification-reports/relay-deployment.json \
  --report-output verification-reports/relay-artifact-parity.json
# exact real-Safe, production-rehearsal, fuzz, and stateful GSS gate:
python3 test-forge/fv/verify_gss_governance.py \
  --report-output verification-reports/relay-gss-governance.json
# fixed-block production source-Safe identity/configuration/code-hash gate:
node scripts/verify-gss-source-safe.js
# exact CI gate (checks Foundry 1.7.1, force-rebuilds AST-complete artifacts,
# and loads loop=6 plus the unlimited assertion timeout from halmos.toml):
HALMOS=.venv-halmos/bin/halmos .venv-halmos/bin/python test-forge/fv/verify_fv.py \
  --report-output verification-reports/relay-halmos.json
# a single harness:
halmos --contract RelaySigParamFV
# tripwire demo — too-small bound must FAIL with vacuity alarms:
python3 test-forge/fv/verify_fv.py --loop 2
```

Expect from the gate:
```
[fv] 102/102 checks observed: 72/72 proofs hold, 30/30 reachability controls have validated counterexamples. 0 violation(s).
[fv] OK - exact proof inventory holds and every reachability control has a valid witness.
```
**CI:** `test-fv-halmos` (digest-pinned Python; checksum-pinned Foundry; full Halmos lock; unit tests,
legacy revert-ABI inventory, artifact/IR parity, then the exact proof gate). The normalized JSON reports
are retained as CI artifacts. Triggered on changes to
[`Relay.sol`](../../contracts/protocol/implementation/Relay.sol), imported governance sources, the relay
interfaces, `test-forge/fv/**`, or [`halmos.toml`](../../halmos.toml).

The gate distinguishes Halmos's six result classes. Only exit `0` is a proof pass and only exit `1` with at
least one `is_valid=true` model is a reachability witness; a wrong Foundry/Halmos/Z3 version, failed
AST-complete rebuild, timeout, stuck, all-revert, exception, malformed JSON, missing/unexpected checks,
process/JSON disagreement, and bounded loops all fail closed. The forced rebuild matters because Halmos
0.3.3's own `forge build --ast` is incremental: if a preceding ordinary Forge command compiled a changed
source without AST output, Halmos would otherwise skip that artifact.

---

## 11.4 R3 — Certora

```bash
pip install certora-cli==8.16.1
# Local fail-closed front-end gate (no key/cloud): pinned versions, munge,
# Solidity compilation, and CVL typecheck for both current configs.
python3 test-forge/fv/verify_certora_local.py \
  --solc /path/to/solc-0.8.27 \
  --report-output verification-reports/relay-certora-local.json
# Current cloud rerun (needed before claiming the GSS-source rules):
export CERTORAKEY=<your key>
certoraRun certora/Relay-rawstorage.conf --solc /path/to/solc-0.8.27
certoraRun certora/Relay-rawstorage-A3.conf --solc /path/to/solc-0.8.27
./certora/munge.sh                                                        # regenerate + verify the munged tree
certoraRun certora/Relay-writeonce.conf --solc /path/to/solc-0.8.27
certoraRun certora/Relay-writeonce-B2.conf --solc /path/to/solc-0.8.27
# Historical diagnostic configuration:
certoraRun certora/Relay.conf --solc /path/to/solc-0.8.27
```

The local gate currently passes 2/2 configs. It is compilation/typecheck
evidence, not a prover verdict. The current cloud runs must complete before the
GSS-source rules are promoted to proven. The pre-GSS reports remain historical evidence;
judge cloud results from per-rule statuses (`SUCCESS`/`SANITY_FAIL`), not the
CLI exit banner ([L5 §5.2](05-R3-unbounded-attempts.md)).

---

## 11.5 R3 — Kontrol

```bash
# one-time toolchain image (~18.5 GB; best on native x86_64 Linux):
docker build -f test-forge/fv/kontrol/Dockerfile -t kontrol-local:ready .
# run a harness:
docker run --rm --platform linux/amd64 -v "$PWD/test-forge/fv/kontrol":/work kontrol-local:ready sh /work/run.sh
```

Per harness: `forge build` (~1 s) → `kontrol build` (~8–18 min, reuses the baked kdist) → `kontrol prove`.
`run.sh` requests Kontrol's JUnit report, preserves the expected nonzero prover exit, and passes both to
`verify_kontrol.py`. The exact manifest requires 14 proofs and 6 concrete-failure controls; errors, skips,
pending/incomplete proofs, missing checks, and unexpected checks fail the run.
Pinned: Kontrol v1.0.248, K v7.1.334, `nixpkgs @ 9eac87a…`, base image by sha256 digest.

---

## 11.6 R4a — the abstract proof (Lean)

```bash
# Lean 4 core (elan auto-fetches the toolchain); no mathlib, no EVM:
lean test-forge/fv/lean/RelaySigLoop.lean
```

Expect: no errors and two explicit `#print axioms` results with no `sorryAx`. This abstract file is also
part of the automated nine-file Lean gate below.

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

### The whole Lean gate (all 9 files) — the `test-fv-lean` CI job

The check above verifies one file in isolation. The full abstract + R4b + R5 development — **9 files**,
hole-freeness enforced — is checked in one command, exactly as CI does it:

```bash
# after the one-time EVMYulLean build above:
EVMYUL_DIR=/tmp/evmyul2 python3 test-forge/fv/lean/verify_lean.py   # exit 0 = all 9 files hole-free
```

`verify_lean.py` first verifies the checkout's actual Git commit and `lean-toolchain`, then scans the source
for proof holes and undeclared axioms. It checks the abstract file plus every refinement file and requires
exactly 165 declared `#print axioms` results, including the manifest's named capstones:

- **ABSTRACT:** `RelaySigLoop` (core Lean, checked under the same pinned toolchain).
- **STANDALONE** (import `EvmYul` only): `RelayBytecodeRefinement`, `DataLayer`, `RelayLoopMemRead`,
  `RelayLoopWindows`, `RelayLoopLiteral`, `RelayStorageLayer` (R5.1/5.3 storage + accept-write),
  `RelayFeeLayer` (R5.4 fees).
- **INTEGRATION** (imports three siblings — compiled into the package lib first): `RelayBodyEff` (the literal
  loop-body model, the mode dispatch, and the end-to-end composition).

Allowed axioms: `⊆ {propext, Classical.choice, Quot.sound}` plus three declarations implementing two
documented data/window spec shapes: `RelayDataLayer.zeroes_data`, `RelayWindows.zeroes_data`, and
`RelayDataLayer.toByteArray_size` (see §11.8 and
[`AXIOM_DISCHARGE.md`](../../test-forge/fv/lean/bytecode-refinement/AXIOM_DISCHARGE.md)).
The same job is wired into `.gitlab-ci.yml` as **`test-fv-lean`** and emits a normalized JSON report. It is
triggered by Relay/interface/compiler/artifact-provenance changes as well as every Lean/Yul change.

---

## 11.8 The axiom audit (how to certify "hole-free")

For any Lean theorem, the certificate is its `#print axioms` output. The bar (the engagement's definition
of "done"):

- **allowed:** `propext`, `Classical.choice`, `Quot.sound` (standard, consistent, domain-neutral), plus only
  the three named data/window declarations in the manifest;
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
| `test-fv-halmos` | compatibility ABI | exact-manifest `verify_relay_revert_abi.py` | ✅ |
| `build-smart-contracts` + `test-fv-halmos` | artifact provenance | deployment report + FV bytecode/IR parity | ✅ |
| `test-fv-halmos` | R2 | unit-test gates + exact-manifest `verify_fv.py` | ✅ |
| `test-fv-halmos` | GSS R0/R1 + source pin | exact 36-test gate + 20-check fixed-block Safe snapshot | ✅ |
| `build-smart-contracts`, `test-linter`, `test-linter-forge` | build/lint | `forge build` / solhint | ✅ |
| `test-fv-lean` | R4a/R4b/R5 | `verify_lean.py` (pinned commit/toolchain, all 9 files, 165 audits) | ✅ |
| `test-doc-links` | docs | `python3 docs/relay-verification/verify_links.py --check` (symbol-addressed code links stay current; fix with `--fix`) | ✅ |
| `test-fv-certora-local` | R3 front end | pinned compile/CVL typecheck for 2 configs | ✅, not a proof verdict |
| (Certora cloud) | R3 | `certoraRun` (needs key) | required before current parametric claims |
| (Kontrol) | R3 | Docker + JUnit manifest gate | manual/offline, fail-closed |

R0–R2, the GSS/source-Safe gates, the local Certora front end, and all Lean files run on every relevant
push. Kontrol remains heavyweight/manual but its runner has a machine verdict; only the Certora proof
verdict remains key/cloud-gated. A green pipeline retains the exact normalized
evidence reports rather than only human-oriented logs.

The final `test-fv-bundle` job runs `verify_bundle.py` after the Halmos, local Certora, and Lean jobs.
It refuses missing or non-passing reports and records the Git commit, the
verification-manifest hash, and a SHA-256 for every evidence report. This bundle is
the canonical hand-off artifact for a run. Its exact evidence set is eight reports:
deployment provenance, legacy revert ABI, artifact parity, GSS tests, fixed-block
source Safe, Halmos, Lean, and local Certora. It rejects dirty worktrees by
default; `--allow-dirty` marks a development bundle as not release eligible.
Raw tool output alone may be stale or incomplete.

**Next:** [L12 — Lessons](12-lessons.md): the transferable method distilled from all of this.
