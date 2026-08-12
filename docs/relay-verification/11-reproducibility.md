# L11 — Reproducibility

> **Current-results rule (updated 2026-08-12).** Commands in this chapter are the
> supported reproduction paths. Expected verdicts belong in
> [`CURRENT-STATUS.md`](CURRENT-STATUS.md) and must come from reports generated
> for the same commit; an old green CI label is not evidence for current code.

> **What you get from this level — the reproducibility core.** Exact toolchains, versions, commands, and
> expected outputs to independently re-check every claim in the ledger ([L10](10-claims-ledger-trust-and-residual.md)),
> rung by rung, plus the CI mapping that runs them automatically. Paired with L10, this is what makes the
> engagement an _audit_, not an assertion.

All commands are from the repo root unless noted: `flare-smart-contracts-v2/`.

---

## 11.1 Toolchain versions

| Tool                           | Version (verified)                                             | Install / source                                                                                                                                                  |
| ------------------------------ | -------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Python orchestration           | **3.11**                                                       | local lock generated with 3.11.6; the Halmos CI job installs Debian bookworm's Python 3.11 and records the exact patch version at runtime                         |
| Foundry (`forge`)              | **1.7.2-nightly @ `160b60260db63ce6204f2ee15764aca3e9ef04fe`** | digest-pinned `flarefoundation/foundry-custom:forge-nightly-160b6026`; the manifest is normative                                                                  |
| `solc`                         | **0.8.35+commit.47b9dedd**                                     | shared deployment/FV compiler pin; exact settings and artifact parity are mandatory                                                                               |
| Halmos                         | **0.3.3** (Python 3.11)                                        | full dependency closure in [`test-forge/fv/requirements-halmos.lock`](../../test-forge/fv/requirements-halmos.lock); the Python patch itself is not a release pin |
| z3 (SMT solver)                | **4.12.6.0**                                                   | pinned in the same lock (CI installs `halmos==0.3.3 z3-solver==4.12.6.0`)                                                                                         |
| Kontrol / KEVM                 | Kontrol **v1.0.248**, K **v7.1.334**                           | pinned Docker image (§11.5)                                                                                                                                       |
| Certora CLI / Java             | **8.16.1 / JDK 21+**                                           | pinned local front-end gate; `CERTORAKEY` only for cloud proof                                                                                                    |
| Lean (the abstract proof)      | Lean 4 core                                                    | `elan` (no mathlib needed)                                                                                                                                        |
| Lean (the bytecode refinement) | Lean **4.22.0** + mathlib 4.22.0 + FFI                         | `elan` + EVMYulLean (§11.7)                                                                                                                                       |
| EVMYulLean                     | NethermindEth/EVMYulLean **pinned @ `047f6307`** (2025-09-24)  | `git clone` + `git checkout` (§11.7)                                                                                                                              |

Repo build config: [`foundry.toml`](../../foundry.toml) sets `src=contracts`, `test=test-forge`, `out=artifacts-forge`,
`evm_version=cancun`, `optimizer=true/200`, `via_ir=true` for Relay, and `skip=['*.yul']` (so reference IR artifacts aren't
compiled). FV config: [`halmos.toml`](../../halmos.toml) pins `solver=z3`, `loop=6`,
`solver-timeout-assertion=0`, and `forge-build-out=artifacts-forge`.

The normative machine-readable record is
[`test-forge/fv/verification-manifest.json`](../../test-forge/fv/verification-manifest.json). It owns the
compiler settings, the Halmos check inventory, Certora local toolchain/configs, EVMYulLean pin,
allowed Lean axioms, exact axiom-audit counts, required capstones, and the custom-error selector inventory
used by `relay()` assembly. Changes to proof inventory, trust settings, or that compatibility surface
therefore appear as explicit manifest diffs. Retired Safe/GSS inventories are not part of the current manifest.

---

## 11.2 R0/R1 — Foundry tests

```bash
forge build --force --ast --extra-output storageLayout metadata
forge test -vvv --match-path 'test-forge/unit/protocol/implementation/Relay.t.sol'
forge test -vvv --match-path 'test-forge/unit/protocol/implementation/RelayChainDomain.t.sol'
forge test -vvv --match-path 'test-forge/unit/governance/RelayOwnableWithTimelock.t.sol'
forge test -vvv --match-path 'test-forge/unit/governance/RelayUpgrade.t.sol'
forge coverage --match-path 'test-forge/unit/protocol/implementation/Relay.t.sol'
```

Expected behavior is defined by the tests; record an actual count only from a
report for the current commit. (The retired Safe-governance gate and its
36-test inventory went with that design — see
[`relay-governance.md`](../relay-governance.md); the owner-timelock suites
above are its successors.) **CI:** `test-unit-forge` (`forge test -vvv`),
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
pnpm compile
node scripts/relay-artifact-provenance.js --output verification-reports/relay-deployment.json
# pin every relay() assembly custom-error selector and call site:
python3 test-forge/fv/verify_relay_custom_error_abi.py \
  --report-output verification-reports/relay-custom-error-abi.json
# bind FV solc output + optimized Yul to the deployment artifact:
FORGE=/path/to/manifest-pinned-forge .venv-halmos/bin/python test-forge/fv/verify_relay_artifact.py \
  --deployment-report verification-reports/relay-deployment.json \
  --report-output verification-reports/relay-artifact-parity.json
# exact CI gate (checks the manifest-pinned Foundry version/commit, force-rebuilds AST-complete artifacts,
# and loads loop=6 plus the unlimited assertion timeout from halmos.toml):
FORGE=/path/to/manifest-pinned-forge HALMOS=.venv-halmos/bin/halmos \
  .venv-halmos/bin/python test-forge/fv/verify_fv.py \
  --report-output verification-reports/relay-halmos.json
# a single harness:
halmos --contract RelaySigParamFV
# tripwire demo — too-small bound must FAIL with vacuity alarms:
python3 test-forge/fv/verify_fv.py --loop 2
```

On a successful run of the current manifest, expect:

```
[fv] 123/123 checks observed: 86/86 proofs hold, 37/37 reachability controls have validated counterexamples. 0 violation(s).
[fv] OK - exact proof inventory holds and every reachability control has a valid witness.
```

**CI:** `test-fv-halmos` (digest-pinned Foundry/Node image; runtime-recorded Debian Python 3.11;
full Halmos lock; unit tests,
custom-error ABI inventory, artifact/IR parity, then the exact proof gate). The normalized JSON reports
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
# Local fail-closed front-end gate (no key/cloud): pinned versions, exact
# manifest-backed config/spec/settings/rule audit, munge, Solidity compilation,
# and CVL typecheck for all three current configs.
python3 test-forge/fv/verify_certora_local.py \
  --solc /path/to/solc-0.8.35 \
  --report-output verification-reports/relay-certora-local.json
# Submit cloud runs for the checked-out commit:
export CERTORAKEY=<your key>
./certora/munge.sh
certoraRun certora/Relay.conf --solc /path/to/solc-0.8.35
certoraRun certora/Relay-threshold.conf --solc /path/to/solc-0.8.35
certoraRun certora/Relay-writeonce.conf --solc /path/to/solc-0.8.35
# Normalize saved CLI logs against their exact submission archives:
python3 test-forge/fv/verify_certora_cloud.py \
  --run certora/Relay.conf=/path/to/scalar.log=/path/to/scalar-submission.zip \
  --run certora/Relay-threshold.conf=/path/to/threshold.log=/path/to/threshold-submission.zip \
  --run certora/Relay-writeonce.conf=/path/to/writeonce.log=/path/to/writeonce-submission.zip \
  --report verification-reports/relay-certora-cloud.json
```

The local gate checks 3/3 configs and 15 rules and is
compilation/munging/CVL-typecheck evidence, not a prover verdict. It passes on
`d5af7136…` with report SHA-256 `9d3ce039…` and is development-only solely
because the generation tree was dirty. The normalized supplemental cloud
report (SHA-256 `93d09d86…`) is PARTIAL: threshold passes; scalar and
write-once are partial. Across the three jobs it records 308 `SUCCESS`, 2
validated `SATISFIED`, 24 `SANITY_FAIL`, and no semantic counterexample,
`UNKNOWN`, or `TIMEOUT`. Judge every method/rule result and sanity node, not
only the CLI exit banner ([L5 §5.2](05-R3-unbounded-attempts.md)).

The normalizer binds each log to its job identity and submitted archive. Because
cloud logs are imported evidence, parsing them is never sufficient to make a
report release eligible. Current claims also retain `loop_iter=3`, optimistic
loops, optimistic hashing up to 512 bytes, `viaIR` internal-resolution limits,
and the direct-implementation/UUPS trusted boundary.

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
exactly 183 declared `#print axioms` results, including the manifest's named capstones:

- **ABSTRACT:** `RelaySigLoop` (core Lean, checked under the same pinned toolchain).
- **STANDALONE** (import `EvmYul` only): `RelayBytecodeRefinement`, `DataLayer`, `RelayLoopMemRead`,
  `RelayLoopWindows`, `RelayLoopLiteral`, `RelayStorageLayer` (R5.1/5.3 storage + accept-write and transient storage),
  `RelayFeeLayer` (R5.4 fees).
- **INTEGRATION** (imports four siblings — compiled into the package lib first): `RelayBodyEff` (the literal
  loop-body model, mode dispatch, end-to-end composition, and protocol-1 threshold seam).

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

| CI job                                                      | Rung                | Command                                                                                       |
| ----------------------------------------------------------- | ------------------- | --------------------------------------------------------------------------------------------- |
| `test-unit-forge`                                           | R0/R1               | `forge test -vvv`                                                                             |
| `coverage-forge` (+ `-reports`)                             | R0/R1               | `forge build` + coverage                                                                      |
| `test-fv-halmos`                                            | compatibility ABI   | exact-manifest `verify_relay_custom_error_abi.py`                                             |
| `build-smart-contracts` + `test-fv-halmos`                  | artifact provenance | deployment report + FV bytecode/IR parity                                                     |
| `test-fv-halmos`                                            | R2                  | unit-test gates + exact-manifest `verify_fv.py`                                               |
| `build-smart-contracts`, `test-linter`, `test-linter-forge` | build/lint          | `forge build` / solhint                                                                       |
| `test-fv-lean`                                              | R4a/R4b/R5          | `verify_lean.py` (pinned commit/toolchain and manifest inventory)                             |
| `test-doc-links`                                            | docs                | `python3 docs/relay-verification/verify_links.py --check`                                     |
| `test-fv-certora-local`                                     | R3 front end        | pinned compile/CVL typecheck for 3 configs / 15 rules; not a proof verdict                    |
| (Certora cloud)                                             | R3                  | manual keyed `certoraRun` + `verify_certora_cloud.py`; current supplemental report is PARTIAL |
| (Kontrol)                                                   | R3                  | Docker + JUnit manifest gate (manual/offline, fail-closed)                                    |

The listed CI jobs are intended to run on relevant pushes. Their presence is not
evidence that a particular commit passed: consult the pipeline and normalized
reports for that commit. Kontrol remains heavyweight/manual, and Certora runs
remain key/cloud-gated. The current normalized cloud report is supplemental
imported evidence: threshold passes, while scalar/write-once remain partial
because of sanity failures.

The final `test-fv-bundle` job runs `verify_bundle.py` after the Halmos, local
Certora, and Lean jobs. Every normalized gate records the full-checkout Git state
at generation start and end. Dirty or changing inputs permanently mark that
report development-only; later restoring the checkout cannot promote it. Halmos
also records the raw JSON hash, exact child command, and exit code. Supplying
`--results-input` remains useful for diagnosis, but its imported result is never
release eligible.

The bundle refuses missing, failing, malformed, or provenance-inconsistent
reports and records the Git commit, verification-manifest hash, and SHA-256 for
every evidence file. This is the canonical hand-off artifact for a run. The
in-process bundle set is deployment provenance, custom-error ABI, artifact
parity, Halmos, Lean, and local Certora. A normalized cloud report, when current,
is additional imported evidence and is not a bundle constituent. By default
every in-process constituent and the bundle itself
must have been generated from the same clean HEAD. `--allow-dirty` permits an
explicitly development-only bundle; it cannot turn a dirty, imported, or PARTIAL
report into release evidence. Raw tool output alone may be stale or incomplete.
The current manifest is
`7ae2208f96a520f477b528ee808909f87e9402247bacab00e04052fa02ec2cb1`.
All six local constituents pass on `d5af7136…`, but each is development-only
solely because the worktree was dirty at generation start and end. Their
aggregate bundle also passes, validates all six reports, and has SHA-256
`be386d63acdd336b99ab84c64cb0f32ba9c3bafbba02b17164ebd176b7e4f64a`; its
`release_eligible=false` status is attributable solely to the same dirty-tree
start/end condition. Reproduce every constituent and the bundle from a clean
commit for release evidence.

**Next:** [L12 — Lessons](12-lessons.md): the transferable method distilled from all of this.
