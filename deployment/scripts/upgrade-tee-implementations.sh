#!/usr/bin/env bash
set -euo pipefail

# Usage: deployment/scripts/upgrade-tee-implementations.sh <network> [--broadcast]
# Example: deployment/scripts/upgrade-tee-implementations.sh coston            # DRY RUN
# Example: deployment/scripts/upgrade-tee-implementations.sh coston --broadcast
#
# Upgrades every non-diamond TEE / FDC2 UUPS proxy to a freshly deployed implementation and
# redeploys the standalone VrfVerifier (see UpgradeTeeImplementations.s.sol). Diamond facets
# are NOT handled here — use the diamond-cut mechanism for those.
#
# SAFE BY DEFAULT: a run is a DRY RUN (simulation, no transactions) unless you pass an
# explicit --broadcast. On --broadcast the DEPLOYED: log lines are piped through
# save-deployed-addresses.ts, which REPLACES the *Implementation entries in
# deployment/deploys/<network>.json and appends to deployment/deploys/all/<network>.json.
#
# Requires in .env: <NETWORK>_RPC and DEPLOYER_PRIVATE_KEY (the key must be the proxies'
# pre-production governance address — the script refuses to run otherwise).

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <network> [--broadcast]" >&2
  exit 2
fi

NETWORK="$1"
MODE="${2:-}"

NETWORK_UPPER=$(echo "$NETWORK" | tr '[:lower:]' '[:upper:]')
RPC_ENV_VAR="${NETWORK_UPPER}_RPC"

if [[ -f .env ]]; then
  set -a
  # shellcheck source=/dev/null
  source .env
  set +a
fi

if [[ -z "${!RPC_ENV_VAR:-}" ]]; then
  echo "${RPC_ENV_VAR} is required in .env" >&2
  exit 2
fi
if [[ -z "${DEPLOYER_PRIVATE_KEY:-}" ]]; then
  echo "DEPLOYER_PRIVATE_KEY is required in .env" >&2
  exit 2
fi

FORGE_CMD=(forge script deployment/scripts/UpgradeTeeImplementations.s.sol:UpgradeTeeImplementations
  --rpc-url "${!RPC_ENV_VAR}"
  --private-key "$DEPLOYER_PRIVATE_KEY"
  --sig "run()")

if [[ "$MODE" == "--broadcast" ]]; then
  # --slow sends transactions serially so an on-chain revert stops the sequence.
  "${FORGE_CMD[@]}" --broadcast --slow | tee forge-deploy-output.txt
  npx tsx deployment/scripts/save-deployed-addresses.ts
elif [[ -z "$MODE" ]]; then
  echo "DRY RUN (no transactions; pass --broadcast to upgrade for real)"
  "${FORGE_CMD[@]}"
else
  echo "Unknown option: $MODE (expected --broadcast)" >&2
  exit 2
fi
