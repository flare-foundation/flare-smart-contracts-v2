#!/usr/bin/env bash
# Bootstrap the Relay formal-verification toolchain from a fresh clone. Idempotent.
#
#   ./scripts/bootstrap-fv.sh            # core: node deps, forge build, .venv-halmos, Halmos gate
#   ./scripts/bootstrap-fv.sh --no-gate  # core without the final ~5-10 min Halmos gate run
#   ./scripts/bootstrap-fv.sh --lean     # additionally clone+build the pinned EVMYulLean (/tmp/evmyul2,
#                                        #   ~30-60 min first time) and run the 9-file Lean gate
#
# What "done" looks like: the Halmos gate prints
#   [fv] 86/86 checks observed: 58/58 proofs hold, 28/28 reachability controls have validated counterexamples.
# The reference interpretation of every verdict: docs/relay-verification/11-reproducibility.md.
#
# Not automated (deliberately): the Kontrol Docker image (~18.5 GB — see test-forge/fv/kontrol/README.md)
# and Certora cloud runs (need CERTORAKEY — see certora/README.md). Java (JDK) is only needed for
# Certora's local typecheck.
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

# --- 0. sanity: expected branch ------------------------------------------------------------------
BRANCH=$(git rev-parse --abbrev-ref HEAD)
case "$BRANCH" in
  relay-fix-3|relay-fix-3-gss) ;;
  *) echo "NOTE: you are on '$BRANCH'; the maintained Relay verification branches are relay-fix-3 and relay-fix-3-gss." ;;
esac

# --- 1. node deps (forge remappings reference node_modules/, e.g. @gnosis.pm) ---------------------
step "node deps (needed by forge remappings)"
if [ ! -d node_modules ]; then
  # this is a yarn.lock project — npm ci does NOT apply (no package-lock.json). Prefer a real yarn;
  # otherwise run yarn classic via npx (ships with npm), pinned for determinism.
  if command -v yarn >/dev/null 2>&1; then yarn install --frozen-lockfile;
  elif command -v npx >/dev/null 2>&1; then npx --yes yarn@1.22.22 install --frozen-lockfile;
  else echo "ERROR: need yarn (or node+npx) for node_modules (forge remappings depend on it)." >&2; exit 1; fi
else
  echo "node_modules present — skipping"
fi

# --- 2. forge deps + build -----------------------------------------------------------------------
step "forge deps + build"
command -v forge >/dev/null 2>&1 || { echo "ERROR: foundry not installed (https://getfoundry.sh)." >&2; exit 1; }
forge soldeer install
forge install
forge build

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
  step "Relay legacy revert ABI gate"
  python3 -m unittest discover -s test-forge/fv/tests -v
  python3 test-forge/fv/verify_relay_revert_abi.py \
    --report-output verification-reports/relay-revert-abi.json

  step "Halmos FV gate (verify_fv.py — judge from the [fv] summary lines)"
  HALMOS="$PWD/.venv-halmos/bin/halmos" .venv-halmos/bin/python test-forge/fv/verify_fv.py
else
  step "skipping the local gates (--no-gate); run later with:"
  echo '  python3 test-forge/fv/verify_relay_revert_abi.py'
  echo '  HALMOS=$PWD/.venv-halmos/bin/halmos .venv-halmos/bin/python test-forge/fv/verify_fv.py'
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
  EVMYUL_DIR="$EVMYUL_DIR" python3 test-forge/fv/lean/verify_lean.py
fi

step "bootstrap complete"
echo "Start reading at: CLAUDE.md -> docs/relay-verification/00-README.md -> docs/relay-verification/CHECKPOINT.md"
