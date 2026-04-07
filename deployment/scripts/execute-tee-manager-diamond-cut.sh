#!/usr/bin/env bash
set -euo pipefail

# Usage: scripts/execute-tee-manager-diamond-cut.sh <network> <cut-json-file-name-without-extension>
# Example: scripts/execute-tee-manager-diamond-cut.sh coston2 cut-example

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <network> <cut-json-file-name-without-extension>" >&2
  exit 2
fi

NETWORK="$1"
CUT_JSON="$2"

# Convert network to uppercase and build env var name
NETWORK_UPPER=$(echo "$NETWORK" | tr '[:lower:]' '[:upper:]')
RPC_ENV_VAR="${NETWORK_UPPER}_RPC_URL"

# Load env
if [[ -f .env ]]; then
  set -a
  source .env
  set +a
fi

# Validate required envs (bash indirect expansion)
if [[ -z "${!RPC_ENV_VAR:-}" ]]; then
  echo "$RPC_ENV_VAR is required" >&2
  exit 2
fi
if [[ -z "${DEPLOYER_PRIVATE_KEY:-}" ]]; then
  echo "DEPLOYER_PRIVATE_KEY is required" >&2
  exit 2
fi

# Create output directory if it doesn't exist
OUTPUT_DIR="deployment/output-internal/$NETWORK"
mkdir -p "$OUTPUT_DIR"
# Run forge script
forge script deployment/scripts/ExecuteTeeManagerDiamondCut.s.sol:ExecuteTeeManagerDiamondCut \
  --rpc-url "${!RPC_ENV_VAR}" \
  --private-key "$DEPLOYER_PRIVATE_KEY" \
  --broadcast \
  --sig "run(string)" "$CUT_JSON"
