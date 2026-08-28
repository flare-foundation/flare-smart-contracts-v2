#!/usr/bin/env bash
set -euo pipefail

# Usage: scripts/execute-tee-manager-diamond-cut.sh <network> <cut-json-file-name-without-extension> [--broadcast]
# Example: scripts/execute-tee-manager-diamond-cut.sh coston2 2026-07-23               # DRY RUN
# Example: scripts/execute-tee-manager-diamond-cut.sh coston2 2026-07-23 --broadcast   # real cut
#
# SAFE BY DEFAULT: a run is a DRY RUN (simulation against a fork of the network — no facets
# deployed, no diamondCut sent) unless you pass an explicit --broadcast — same convention as
# deploy-relay.sh. Combine the dry run with "execute": false in the cut JSON to just compute and
# print the cut (the encoded calldata + decoded JSON are written to deployment/output-internal/<network>/).

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: $0 <network> <cut-json-file-name-without-extension> [--broadcast]" >&2
  exit 2
fi

NETWORK="$1"
CUT_JSON="$2"
MODE="${3:-}"

if [[ -n "$MODE" && "$MODE" != "--broadcast" ]]; then
  echo "Unknown argument '$MODE' (expected --broadcast)" >&2
  exit 2
fi

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

# Build forge command
FORGE_CMD=(forge script deployment/scripts/ExecuteTeeManagerDiamondCut.s.sol:ExecuteTeeManagerDiamondCut
  --rpc-url "${!RPC_ENV_VAR}"
  --private-key "$DEPLOYER_PRIVATE_KEY"
  --sig "run(string)" "$CUT_JSON")

if [[ "$MODE" == "--broadcast" ]]; then
  "${FORGE_CMD[@]}" --broadcast
else
  echo "DRY RUN (no transactions; pass --broadcast to execute the cut for real)"
  "${FORGE_CMD[@]}"
fi
