#!/usr/bin/env bash
set -euo pipefail

# Usage: scripts/deploy-tee-contracts.sh <network> <fullDeploy:boolean> [--dry-run]
# Example: scripts/deploy-tee-contracts.sh coston2 true
# Example: scripts/deploy-tee-contracts.sh coston2 false --dry-run
#
# Deploys FlareTeeManager diamond, FDC2 contracts, TeePayments proxies,
# TeeRewardOffersManager, VrfVerifier, and wires them all up.
# The fullDeploy flag controls whether later facets (replication, governance,
# version manager) are added to the diamond.
# Use --dry-run to simulate against a forked network without broadcasting.

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <network> <fullDeploy:boolean> [--dry-run]" >&2
  exit 2
fi

NETWORK="$1"
FULL_DEPLOY="$2"
DRY_RUN="${3:-}"

# Convert network to uppercase and build env var name
NETWORK_UPPER=$(echo "$NETWORK" | tr '[:lower:]' '[:upper:]')
RPC_ENV_VAR="${NETWORK_UPPER}_RPC"

# Load env
if [[ -f .env ]]; then
  set -a
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
  --sig "run(bool)" "$FULL_DEPLOY")

if [[ "$DRY_RUN" == "--dry-run" ]]; then
  echo "Running in dry-run mode (no broadcast)"
  "${FORGE_CMD[@]}"
else
  "${FORGE_CMD[@]}" --broadcast | tee forge-deploy-output.txt
  npx tsx deployment/scripts/save-deployed-addresses.ts
fi
