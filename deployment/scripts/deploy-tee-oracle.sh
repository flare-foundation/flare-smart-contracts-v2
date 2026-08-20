#!/usr/bin/env bash
set -euo pipefail

# Usage: deployment/scripts/deploy-tee-oracle.sh <network> [--dry-run]
# Example: deployment/scripts/deploy-tee-oracle.sh coston2
# Example: deployment/scripts/deploy-tee-oracle.sh coston2 --dry-run
#
# Deploys the TEE oracle extension: one TeeOracleInstructionsSender UUPS proxy plus
# one TeeOracleFeedStore UUPS proxy per feed configured in `teeOracleFeeds` (chain
# config), wires them via the AddressUpdater and switches them to production mode.
# The governance-only follow-up steps (registerReserved, setExtensionContracts,
# operation fee rows, FtsoV2.addCustomFeeds, setEndpoints/setAdmins) are printed by
# the script.
# Use --dry-run to simulate against a forked network without broadcasting.

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <network> [--dry-run]" >&2
  exit 2
fi

NETWORK="$1"
DRY_RUN="${2:-}"

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

# Build forge command
FORGE_CMD=(forge script deployment/scripts/DeployTeeOracle.s.sol:DeployTeeOracle
  --rpc-url "${!RPC_ENV_VAR}"
  --private-key "$DEPLOYER_PRIVATE_KEY"
  --sig "run()")

if [[ "$DRY_RUN" == "--dry-run" ]]; then
  echo "Running in dry-run mode (no broadcast)"
  "${FORGE_CMD[@]}"
else
  "${FORGE_CMD[@]}" --broadcast | tee forge-deploy-output.txt
  npx tsx deployment/scripts/save-deployed-addresses.ts
fi
