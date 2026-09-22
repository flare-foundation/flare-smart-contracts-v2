#!/usr/bin/env bash
# Bootstrap the Relay formal-verification toolchain from a fresh clone. Idempotent.
#
#   ./scripts/bootstrap-fv.sh            # core: exact artifacts, ABI gate, .venv-halmos, Halmos gate
#   ./scripts/bootstrap-fv.sh --no-gate  # core without the final ~5-10 min Halmos gate run
#   ./scripts/bootstrap-fv.sh --lean     # additionally clone+build the pinned EVMYulLean (/tmp/evmyul2,
#                                        #   ~30-60 min first time) and run the 9-file Lean gate
#
# What "done" looks like: every gate prints PASS/OK and Halmos reports the exact manifest inventory.
# The evidence and reproduction rules: docs/relay-verification/11-reproducibility.md.
#
# Certora cloud runs require CERTORAKEY; Java is needed only for Certora's local typecheck.
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root

RUN_GATE=1
RUN_LEAN=0
for arg in "$@"; do
  case "$arg" in
    --no-gate) RUN_GATE=0 ;;
    --lean)    RUN_LEAN=1 ;;
    *) echo "unknown flag: $arg (known: --no-gate --lean)" >&2; exit 2 ;;
  esac
done

step() { printf '\n\033[1m== %s\033[0m\n' "$*"; }

# --- 0. exact Foundry build -----------------------------------------------------------------------
FORGE_BIN="${FORGE:-forge}"
command -v "$FORGE_BIN" >/dev/null 2>&1 || { echo "ERROR: forge not installed (https://getfoundry.sh)." >&2; exit 1; }
EXPECTED_FOUNDRY_VERSION=$(python3 -c 'import json; print(json.load(open("test-forge/fv/verification-manifest.json"))["toolchain"]["foundry"]["version"])')
EXPECTED_FOUNDRY_COMMIT=$(python3 -c 'import json; print(json.load(open("test-forge/fv/verification-manifest.json"))["toolchain"]["foundry"]["commit"])')
EXPECTED_FOUNDRY_IMAGE=$(python3 -c 'import json; print(json.load(open("test-forge/fv/verification-manifest.json"))["toolchain"]["foundry"]["image"])')
ACTUAL_FOUNDRY_VERSION=$("$FORGE_BIN" --version | sed -n 's/^forge Version:[[:space:]]*//p')
ACTUAL_FOUNDRY_COMMIT=$("$FORGE_BIN" --version | sed -n 's/^Commit SHA:[[:space:]]*//p')
if [ "$ACTUAL_FOUNDRY_VERSION" != "$EXPECTED_FOUNDRY_VERSION" ] || [ "$ACTUAL_FOUNDRY_COMMIT" != "$EXPECTED_FOUNDRY_COMMIT" ]; then
  echo "ERROR: forge is ${ACTUAL_FOUNDRY_VERSION}@${ACTUAL_FOUNDRY_COMMIT}; expected ${EXPECTED_FOUNDRY_VERSION}@${EXPECTED_FOUNDRY_COMMIT}." >&2
  echo "       Reproduce in the immutable CI image: ${EXPECTED_FOUNDRY_IMAGE}" >&2
  exit 1
fi

# --- 1. node deps (Forge remappings and the production Hardhat artifact) ---------------------------
step "node deps (needed by Forge remappings and Hardhat)"
command -v node >/dev/null 2>&1 || { echo "ERROR: Node.js is required." >&2; exit 1; }
NODE_MAJOR=$(node -p 'process.versions.node.split(".")[0]')
if [ "$NODE_MAJOR" -lt 24 ]; then
  echo "ERROR: Node.js $(node --version) does not satisfy package.json's >=24 engine." >&2
  exit 1
fi
if ! command -v pnpm >/dev/null 2>&1; then
  command -v corepack >/dev/null 2>&1 || { echo "ERROR: need pnpm or Node.js corepack." >&2; exit 1; }
  corepack enable
fi
EXPECTED_PNPM_VERSION=$(python3 -c 'import json; print(json.load(open("package.json"))["packageManager"].split("@", 1)[1].split("+", 1)[0])')
ACTUAL_PNPM_VERSION=$(pnpm --version)
if [ "$ACTUAL_PNPM_VERSION" != "$EXPECTED_PNPM_VERSION" ]; then
  echo "ERROR: pnpm is ${ACTUAL_PNPM_VERSION}; expected ${EXPECTED_PNPM_VERSION} from package.json." >&2
  exit 1
fi
# The deployment-provenance wrapper below recreates node_modules from this
# exact pnpm executable and the committed lock before compiling.

# --- 2. exact production artifact ----------------------------------------------------------------
step "production artifact provenance"
node scripts/relay-artifact-provenance.js --output verification-reports/relay-deployment.json
# Each release-capable Forge wrapper below independently performs a checksummed
# `forge soldeer install --clean`, hashes that tree, and builds its exact inputs.

# --- 3. the Halmos reference venv (./.venv-halmos, gitignored) ------------------------------------
step "Halmos reference venv (.venv-halmos from test-forge/fv/requirements-halmos.lock)"
PY="${BOOTSTRAP_PYTHON:-python3.11}"
if ! command -v "$PY" >/dev/null 2>&1; then
  echo "ERROR: $PY not found. The reference toolchain is pinned to Python 3.11 (lock frozen under 3.11.6)." >&2
  echo "       Install python3.11, or override with BOOTSTRAP_PYTHON=<python> (semantics then unverified)." >&2
  exit 1
fi
if [ ! -x .venv-halmos/bin/halmos ]; then
  "$PY" -m venv .venv-halmos
  .venv-halmos/bin/pip install --quiet --upgrade pip
  .venv-halmos/bin/pip install --quiet -r test-forge/fv/requirements-halmos.lock
else
  echo ".venv-halmos present — skipping creation"
fi
.venv-halmos/bin/halmos --version

# --- 4. the fail-closed local gates ----------------------------------------------------------------
if [ "$RUN_GATE" = 1 ]; then
  step "Relay custom-error ABI and production-artifact gates"
  python3 -m unittest discover -s test-forge/fv/tests -v
  python3 test-forge/fv/verify_relay_custom_error_abi.py \
    --report-output verification-reports/relay-custom-error-abi.json
  FORGE="$FORGE_BIN" .venv-halmos/bin/python test-forge/fv/verify_relay_artifact.py \
    --deployment-report verification-reports/relay-deployment.json \
    --report-output verification-reports/relay-artifact-parity.json

  step "Halmos FV gate (verify_fv.py — judge from the [fv] summary lines)"
  FORGE="$FORGE_BIN" HALMOS="$PWD/.venv-halmos/bin/halmos" .venv-halmos/bin/python test-forge/fv/verify_fv.py \
    --report-output verification-reports/relay-halmos.json
else
  step "skipping the local gates (--no-gate); run later with:"
  echo '  python3 test-forge/fv/verify_relay_custom_error_abi.py'
  echo '  FORGE=<pinned-forge> .venv-halmos/bin/python test-forge/fv/verify_relay_artifact.py --deployment-report verification-reports/relay-deployment.json'
  echo '  FORGE=<pinned-forge> HALMOS=$PWD/.venv-halmos/bin/halmos .venv-halmos/bin/python test-forge/fv/verify_fv.py'
fi

# --- 5. optional: the pinned EVMYulLean + Lean gate ------------------------------------------------
if [ "$RUN_LEAN" = 1 ]; then
  step "EVMYulLean (pinned) + Lean gate — first build takes ~30-60 min"
  EVMYUL_DIR="${EVMYUL_DIR:-/tmp/evmyul2}"
  PIN=047f63070309f436b66c61e276ab3b6d1169265a
  command -v lake >/dev/null 2>&1 || { echo "ERROR: elan/lake not installed (https://leanprover.github.io)." >&2; exit 1; }
  if [ ! -d "$EVMYUL_DIR" ]; then
    git clone https://github.com/NethermindEth/EVMYulLean "$EVMYUL_DIR"
  fi
  git -C "$EVMYUL_DIR" checkout "$PIN"
  (cd "$EVMYUL_DIR" && lake exe cache get && lake build)
  EVMYUL_DIR="$EVMYUL_DIR" python3 test-forge/fv/lean/verify_lean.py \
    --report-output verification-reports/relay-lean.json
fi

step "bootstrap complete"
echo "Start reading at: CLAUDE.md -> docs/relay-verification/00-README.md -> docs/relay-verification/AUDIT-TRAIL.md"
