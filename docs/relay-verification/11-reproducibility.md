# Reproducing the Relay verification evidence

Run release evidence from a clean checkout. The report wrappers deliberately
record the Git state at start and finish and reject mutable or imported inputs as
release evidence.

Confirm the intended branch and its remote tip before starting. Fetch and compare
the refs; if an update is needed, finish the fast-forward and resolve any local
work before generating evidence. Do not pull, edit source, regenerate tracked
inputs, or commit while a proof gate is running. A passing report for a different
commit is not evidence for the checkout being released.

## 1. Read the manifest

[`test-forge/fv/verification-manifest.json`](../../test-forge/fv/verification-manifest.json)
is authoritative for compiler settings, tool versions, proof inventories,
Certora configs, Lean files, and expected ABI selectors. Do not substitute a
newer local tool with the same executable name.

The manifest also selects two compiler-derived committed baselines:

- `test-forge/fv/lean/relay_ir_optimized.yul`; and
- `test-forge/fv/relay_storage_layout.json`.

The Yul file is the exact pinned compiler output. The storage file is a
compiler-ID-independent normalization retaining each slot, offset, order, and
type decision emitted in Solidity's sequential `storageLayout` output. It does not
enumerate state addressed through ERC-7201 namespace constants, including
OpenZeppelin `Initializable`, or EIP-1153 transient slots. This version is the
first-deployment sequential layout baseline; no proxy-storage migration is part
of it.

## 2. Rebaseline compiler-derived artifacts after an intentional source change

Do not hand-edit either baseline. Build the current source with the exact
manifest toolchain and settings:

```bash
FORGE=/path/to/manifest-pinned-forge
RELAY_REBASE_DIR=$(mktemp -d /private/tmp/relay-artifact-rebaseline.XXXXXX)

$FORGE build contracts/protocol/implementation/Relay.sol \
  --use 0.8.35 --no-auto-detect \
  --out "$RELAY_REBASE_DIR/out" --cache-path "$RELAY_REBASE_DIR/cache" --force --quiet \
  --evm-version cancun --optimize --optimizer-runs 200 --via-ir \
  --extra-output-files irOptimized --extra-output storageLayout

cmp "$RELAY_REBASE_DIR/out/Relay.sol/Relay.iropt" \
  test-forge/fv/lean/relay_ir_optimized.yul
```

For an intended Yul change, review the diff and replace the snapshot with that
exact `.iropt` file. Generate deployment provenance, then run the artifact gate
with a diagnostic report. On an intended layout change the gate fails closed but
records the normalized candidate at `.verification.storage_layout`:

```bash
FORGE="$FORGE" python3 test-forge/fv/verify_relay_artifact.py \
  --deployment-report verification-reports/relay-deployment.json \
  --report-output /private/tmp/relay-artifact-layout-review.json

jq '.verification.storage_layout' \
  /private/tmp/relay-artifact-layout-review.json \
  > /private/tmp/relay-storage-layout-candidate.json
```

Review the candidate against `test-forge/fv/relay_storage_layout.json`. Replace
the committed baseline only when the change is intentional and upgrade
compatibility has been reviewed. Rerun the gate and require both baseline
comparisons to pass. Passing sequential-layout parity detects drift only within
the compiler-emitted scope; it is not a formal compatibility proof for future
implementation code.

Regenerate the visibility-only Certora tree with `bash certora/munge.sh`, review
its exact transformation, and commit intended harness/spec/manifest/generated
baseline changes before the release run. The local gate regenerates that tree;
stale tracked dependencies can therefore cause a run to finish dirty even when
compilation succeeds. Do not change a proof expectation merely to accept a
failure: first reconcile the property with the current contract, preserve
accepting reachability controls, and validate rejection paths independently.

## 3. Bootstrap deployment artifact, ABI, artifact parity, and Halmos

The bootstrap script verifies prerequisites, recreates dependency inputs from
their locks, prepares the pinned Halmos environment, and runs the local gates:

```bash
FORGE=/path/to/manifest-pinned-forge \
  ./scripts/bootstrap-fv.sh
```

To include the pinned Lean/EVMYulLean build:

```bash
FORGE=/path/to/manifest-pinned-forge \
EVMYUL_DIR=/path/to/pinned/EVMYulLean \
  ./scripts/bootstrap-fv.sh --lean
```

The equivalent individual commands are:

```bash
node scripts/relay-artifact-provenance.js \
  --output verification-reports/relay-deployment.json

python3 test-forge/fv/verify_relay_custom_error_abi.py \
  --report-output verification-reports/relay-custom-error-abi.json

FORGE=/path/to/manifest-pinned-forge \
  .venv-halmos/bin/python test-forge/fv/verify_relay_artifact.py \
  --deployment-report verification-reports/relay-deployment.json \
  --report-output verification-reports/relay-artifact-parity.json

FORGE=/path/to/manifest-pinned-forge \
HALMOS=$PWD/.venv-halmos/bin/halmos \
  .venv-halmos/bin/python test-forge/fv/verify_fv.py \
  --report-output verification-reports/relay-halmos.json

EVMYUL_DIR=/path/to/pinned/EVMYulLean \
  python3 test-forge/fv/lean/verify_lean.py \
  --report-output verification-reports/relay-lean.json
```

## 4. Certora local front-end gate

Install the manifest-pinned Certora CLI, Java, solc, and Foundry versions, then:

```bash
FORGE=/path/to/manifest-pinned-forge \
SOLC=/path/to/manifest-pinned-solc \
CERTORA_RUN=/path/to/certoraRun \
  python3 test-forge/fv/verify_certora_local.py \
  --report-output verification-reports/relay-certora-local.json
```

This command establishes that the exact configs compile and typecheck against the
expected source transformation. It does not execute the Certora cloud prover.

## 5. Certora cloud evidence

Submit every config declared by the manifest with the pinned toolchain and
capture both the console log and the exact submission archive produced by the
CLI. An API key is required for submission, but it must never be committed or
written into a report. Load it from a restricted secret file or credential
manager without printing it; rotate a key disclosed in chat, terminal output,
or repository history.

Normalize the completed jobs:

```bash
python3 test-forge/fv/verify_certora_cloud.py \
  --run certora/Relay.conf=/path/to/relay.log=/path/to/relay-submission.zip \
  --run certora/Relay-threshold.conf=/path/to/threshold.log=/path/to/threshold-submission.zip \
  --run certora/Relay-writeonce.conf=/path/to/writeonce.log=/path/to/writeonce-submission.zip \
  --report verification-reports/relay-certora-cloud.json
```

If the normalizer reports a sanity failure, timeout, unknown result, missing
rule, mismatched config, or unvalidated satisfy witness, the cloud evidence is
not a complete pass.

A backend output archive downloaded separately is optional evidence. Bind it,
together with its `jobData` sidecar, through `--backend-evidence`; it does not
replace the CLI submission archive consumed by `--run`.

## 6. Aggregate bundle

After every mandatory constituent was generated on the same clean commit:

```bash
python3 test-forge/fv/verify_bundle.py \
  --output verification-reports/relay-fv-bundle.json
```

`--allow-dirty` is only for development diagnostics. A bundle created with it
must retain `release_eligible: false` and cannot support a release claim.

## 7. Documentation and verifier self-tests

```bash
python3 -m unittest discover -s test-forge/fv/tests -v
python3 docs/relay-verification/verify_links.py --check
```

## 8. Review the result

Check every normalized report for:

- `status` and `release_eligible`;
- repository commit and clean start/end state;
- manifest SHA-256;
- execution mode and tool version;
- expected versus observed inventory;
- optimized-Yul and normalized sequential-storage-layout baseline equality;
- violation, timeout, unknown, and sanity counts; and
- hashes of compiled artifacts and raw external evidence.

The aggregate bundle must reject a stale or development-only constituent. Do not
copy mutable report hashes or counts into prose; retain them in the normalized
JSON where they can be checked mechanically.
