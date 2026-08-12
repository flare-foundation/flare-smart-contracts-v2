# Reproducing the Relay verification evidence

Run release evidence from a clean checkout. The report wrappers deliberately
record the Git state at start and finish and reject mutable or imported inputs as
release evidence.

## 1. Read the manifest

[`test-forge/fv/verification-manifest.json`](../../test-forge/fv/verification-manifest.json)
is authoritative for compiler settings, tool versions, proof inventories,
Certora configs, Lean files, and expected ABI selectors. Do not substitute a
newer local tool with the same executable name.

## 2. Bootstrap deployment artifact, ABI, artifact parity, and Halmos

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

## 3. Certora local front-end gate

Install the manifest-pinned Certora CLI, Java, solc, and Foundry versions, then:

```bash
FORGE=/path/to/manifest-pinned-forge \
SOLC=/path/to/manifest-pinned-solc \
CERTORA_RUN=/path/to/certoraRun \
  python3 test-forge/fv/verify_certora_local.py \
  --report-output verification-reports/relay-certora-local.json
```

This command proves that the exact configs compile and typecheck against the
expected source transformation. It does not execute the Certora cloud prover.

## 4. Certora cloud evidence

Submit every config declared by the manifest with the pinned toolchain and
capture both the console log and the exact submission archive produced by the
CLI. An API key is required for submission, but it must never be committed or
written into a report.

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

## 5. Aggregate bundle

After every mandatory constituent was generated on the same clean commit:

```bash
python3 test-forge/fv/verify_bundle.py \
  --output verification-reports/relay-fv-bundle.json
```

`--allow-dirty` is only for development diagnostics. A bundle created with it
must retain `release_eligible: false` and cannot support a release claim.

## 6. Documentation and verifier self-tests

```bash
python3 -m unittest discover -s test-forge/fv/tests -v
python3 docs/relay-verification/verify_links.py --check
```

## 7. Review the result

Check every normalized report for:

- `status` and `release_eligible`;
- repository commit and clean start/end state;
- manifest SHA-256;
- execution mode and tool version;
- expected versus observed inventory;
- violation, timeout, unknown, and sanity counts; and
- hashes of compiled artifacts and raw external evidence.

The aggregate bundle must reject a stale or development-only constituent. Do not
copy mutable report hashes or counts into prose; retain them in the normalized
JSON where they can be checked mechanically.
