#!/usr/bin/env bash
set -euo pipefail

# Usage: scripts/deploy-tee-contracts.sh <network> [--broadcast]
# Example: scripts/deploy-tee-contracts.sh coston2               # DRY RUN (simulation only)
# Example: scripts/deploy-tee-contracts.sh coston2 --broadcast   # real deployment
#
# Deploys FlareTeeManager diamond, FDC2 contracts, TeePayments proxies,
# TeeRewardOffersManager, VrfVerifier, and wires them all up.
#
# SAFE BY DEFAULT: a run is a DRY RUN (simulation against a fork of the network, no
# transactions) unless you pass an explicit --broadcast — same convention as deploy-relay.sh.

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <network> [--broadcast]" >&2
  exit 2
fi

NETWORK="$1"
MODE="${2:-}"

# Convert network to uppercase and build env var name
NETWORK_UPPER=$(echo "$NETWORK" | tr '[:lower:]' '[:upper:]')
RPC_ENV_VAR="${NETWORK_UPPER}_RPC"

# Load env
if [[ -f .env ]]; then
  set -a
  # shellcheck source=/dev/null
  source .env
  set +a
fi

# Validate required envs (bash indirect expansion)
if [[ -z "${!RPC_ENV_VAR:-}" ]]; then
  echo "${RPC_ENV_VAR} is required in .env" >&2
  exit 2
fi
if [[ -z "${DEPLOYER_PRIVATE_KEY:-}" ]]; then
  echo "DEPLOYER_PRIVATE_KEY is required" >&2
  exit 2
fi

# Create output directory if it doesn't exist
OUTPUT_DIR="deployment/output-internal/$NETWORK"
mkdir -p "$OUTPUT_DIR"

# Build forge command
FORGE_CMD=(forge script deployment/scripts/DeployTeeContracts.s.sol:DeployTeeContracts
  --rpc-url "${!RPC_ENV_VAR}"
  --private-key "$DEPLOYER_PRIVATE_KEY"
  --sig "run()")

if [[ "$MODE" == "--broadcast" ]]; then
  "${FORGE_CMD[@]}" --broadcast | tee forge-deploy-output.txt
  npx tsx deployment/scripts/save-deployed-addresses.ts
elif [[ -z "$MODE" ]]; then
  echo "DRY RUN (no transactions; pass --broadcast to deploy for real)"
  "${FORGE_CMD[@]}"
else
  echo "Unknown option: $MODE (expected --broadcast)" >&2
  exit 2
fi
