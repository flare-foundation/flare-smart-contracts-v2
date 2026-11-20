#!/usr/bin/env bash
set -euo pipefail
# Usage: deployment/scripts/deploy-forbidden-address-list.sh <network> [--switch-to-production] [--broadcast]
# Example: deployment/scripts/deploy-forbidden-address-list.sh coston2               # DRY RUN (simulation only)
# Example: deployment/scripts/deploy-forbidden-address-list.sh coston2 --broadcast   # real deployment
# Example: deployment/scripts/deploy-forbidden-address-list.sh coston2 --switch-to-production --broadcast
# The network is checked: the script requires the RPC's chain id to belong to <network> (flare 14,
# songbird 19, coston 16, coston2 114; any other id only as scdev) and stops otherwise.
#
# SAFE BY DEFAULT: a run is a DRY RUN (simulation against a fork of the network, no
# transactions) unless you pass an explicit --broadcast - same convention as deploy-tee-contracts.sh.
#
# Deploys the ForbiddenAddressList UUPS proxy, adds the chain profile's maintainers
# (`forbiddenAddressListMaintainers`) and Personal Account providers
# (`forbiddenAddressListPersonalAccountProviders`) and loads, for each source the profile names
# (`forbiddenAddressListSources`), every address deployment/chain-config/forbidden-addresses.json
# lists for it, and the file's EVM addresses - 100 per transaction. The deployer is the list's initial
# governance, so these additions execute at once. It then hands the address updater role to the
# AddressUpdater and publishes the name ForbiddenAddressList on it (printed as governance calldata
# where the deployer does not govern the AddressUpdater).
# The AddressUpdater is a legacy Governed contract whose timelock keeps ONE pending call per function: execute
# the printed update before another update (e.g. the TEE stack's, from deploy-tee-contracts.sh) is recorded, or
# merge the two, else the later one silently replaces the earlier.
#
# --switch-to-production switches the list recorded in deployment/deploys/<network>.json to production
# mode instead: its governance becomes GovernanceSettings', removals are timelocked from then on, and
# additions go through a maintainer. Run it once the loaded contents are checked.

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <network> [--switch-to-production] [--broadcast]" >&2
  exit 2
fi
NETWORK="$1"
shift
SIG="run()"
MODE=""
for arg in "$@"; do
  case "$arg" in
    --switch-to-production) SIG="switchToProduction()" ;;
    --broadcast) MODE="--broadcast" ;;
    *)
      echo "Unknown option: $arg (expected --switch-to-production or --broadcast)" >&2
      exit 2
      ;;
  esac
done

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
# The script checks the RPC's chain id against this network (lib/DeployNetwork.sol) and stops on a
# mismatch; exported after .env, so the argument always wins.
export DEPLOY_NETWORK="$NETWORK"
FORGE_CMD=(forge script deployment/scripts/DeployForbiddenAddressList.s.sol:DeployForbiddenAddressList
  --rpc-url "${!RPC_ENV_VAR}"
  --private-key "$DEPLOYER_PRIVATE_KEY"
  --sig "$SIG")

if [[ "$MODE" == "--broadcast" && "$SIG" == "run()" ]]; then
  "${FORGE_CMD[@]}" --broadcast | tee forge-deploy-output.txt
  npx tsx deployment/scripts/save-deployed-addresses.ts
elif [[ "$MODE" == "--broadcast" ]]; then
  "${FORGE_CMD[@]}" --broadcast
else
  echo "DRY RUN (no transactions; pass --broadcast to run for real)"
  "${FORGE_CMD[@]}"
fi
