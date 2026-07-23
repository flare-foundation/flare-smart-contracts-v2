#!/usr/bin/env bash
set -euo pipefail

# Usage: scripts/execute-tee-manager-diamond-cut.sh <network> <cut-json-file-name-without-extension> [--dry-run]
# Example: scripts/execute-tee-manager-diamond-cut.sh coston2 2026-07-23
# Example: scripts/execute-tee-manager-diamond-cut.sh coston2 2026-07-23 --dry-run
#
# Use --dry-run to simulate against a forked network without broadcasting: no facets are deployed
# and no diamondCut is sent. Combine with "execute": false in the cut JSON to just compute and print
# the cut (the encoded calldata + decoded JSON are written to deployment/output-internal/<network>/).

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: $0 <network> <cut-json-file-name-without-extension> [--dry-run]" >&2
  exit 2
fi

NETWORK="$1"
CUT_JSON="$2"
DRY_RUN="${3:-}"

if [[ -n "$DRY_RUN" && "$DRY_RUN" != "--dry-run" ]]; then
  echo "Unknown argument '$DRY_RUN' (expected --dry-run)" >&2
  exit 2
fi

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

if [[ "$DRY_RUN" == "--dry-run" ]]; then
  echo "Running in dry-run mode (no broadcast)"
  "${FORGE_CMD[@]}"
else
  "${FORGE_CMD[@]}" --broadcast
fi
