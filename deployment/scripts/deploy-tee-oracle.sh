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
# the script. Note that setEndpoints/setAdmins name no machines but DO dispatch to the
# extension's active set, so the governance executor must attach the fee reported by
# sender.getEndpointsPublicationFee()/getAdminsPublicationFee() to executeGovernanceCall.
# Read that view in the block the execution lands in. The sender forwards the whole msg.value and
# the diamond's own floor is the only fee gate: too little reverts there (FeeTooLow), while a
# surplus is not refunded - the diamond hands the entire value to RewardManager.receiveRewards in
# the same transaction, so an overpayment is claimable to the claim-back address only if the
# instruction is never executed, and otherwise joins that epoch's rewards. A value quoted before a
# machine was paused therefore overpays rather than reverting.
# Both calls also take a governance-SIGNED version - exactly the feed's next consecutive one,
# endpointsVersion(feedId)+1 / adminsVersion(feedId)+1, else UnexpectedConfigVersion - which is
# what keeps a superseded pending call from executing after its replacement and restoring stale
# configuration; cancel a superseded pending call rather than leaving it queued.
# Both calls also take a non-zero claim-back address - the destination of the fee if the
# dispatched instruction is never executed. For a production timelocked publication governance
# should name the wallet that will fund the execution, since the payer cannot be identified on
# chain; pre-production, where the call executes immediately, that is the caller itself.
# A short fee reverts and is simply re-executable (the timelock entry survives). Dispatch
# is skipped, and the values published anyway, only when the extension is emergency paused
# or its active set is empty - attach no value in those cases. The permissionless
# pushEndpoints/pushAdmins step (pusher pays) then delivers it, and is also how machines
# registered later are brought current; that call dispatches the list it is given and
# reverts on a target it cannot deliver to, so build the list from get*PushTargets.
# A publication stores only the payload's HASH; the published EndpointGroup[]/AdminRole[] are
# emitted in EndpointsPublished/AdminsPublished. KEEP THAT LOG - pushEndpoints/pushAdmins take
# those same values as their third argument, re-encode them with the version held in storage and
# check the hash (WrongConfigPayload), so a keeper passes the event's groups/roles straight
# through. If no one kept the log, governance has to republish.
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
