#!/usr/bin/env bash
set -euo pipefail

# Usage: deployment/scripts/deploy-tee-oracle.sh <network> [--broadcast]
# Example: deployment/scripts/deploy-tee-oracle.sh coston2               # DRY RUN (simulation only)
# Example: deployment/scripts/deploy-tee-oracle.sh coston2 --broadcast   # real deployment
#
# SAFE BY DEFAULT: a run is a DRY RUN (simulation against a fork of the network, no
# transactions) unless you pass an explicit --broadcast - same convention as deploy-tee-contracts.sh.
#
# Deploys the TEE oracle extension: one TeeOracleInstructionsSender UUPS proxy plus
# one TeeOracleFeedStore UUPS proxy per feed configured in `teeOracleFeeds` (chain
# config), wires them via the AddressUpdater and switches them to production mode. It also deploys
# a fresh FtsoV2 implementation (the feed stores need its signed read family); switching the FtsoV2
# proxy to it is a governance upgradeToAndCall, printed with its calldata.
# The follow-up steps that cannot be scripted are printed by the script, and they do NOT all have
# the same caller: registerReserved, the FtsoV2 upgrade followed by FtsoV2.addCustomFeeds, the
# zero FeeCalculator category fee for the feeds, and setEndpoints/setAdmins are Flare governance
# (timelocked); setExtensionContracts and addTeeVersion/addAllowedTeeMachineOwners are
# the extension owner (direct, no timelock); pushEndpoints/pushAdmins are permissionless. The
# TEE_ORACLE operation fee rows are NOT printed and are configured separately, with the rest of
# the payment configuration. Note that setEndpoints/setAdmins name no machines but DO dispatch to the
# extension's active set, so the governance executor must attach the fee reported by
# sender.getEndpointsPublicationFee()/getAdminsPublicationFee() to executeGovernanceCall.
# Read that view in the block the execution lands in. The sender forwards the whole msg.value and
# the diamond's own floor is the only fee gate: too little reverts there (FeeTooLow) and is
# retryable, while whatever IS attached reaches RewardManager.receiveRewards in full, in the same
# transaction. There is no per-instruction accounting and no claim method on these contracts: the claim-back
# address and the full value are only RECORDED in the TeeInstructionsSent event, for the off-chain
# reward calculation. Whether that returns a surplus, or keeps the fee of an instruction that never
# executed, is decided there and not by these contracts. A value quoted before a machine was
# paused therefore overpays rather than reverting.
# The publication version is derived when the call EXECUTES, as the feed's next consecutive one.
# Ordering between two pending publications is a governance responsibility: the one executed LAST
# wins, whichever was proposed first, so cancel a superseded pending call rather than leaving it
# queued.
# Both calls also take a non-zero claim-back address - the dispatched instruction's PAYER OF
# RECORD, emitted for the off-chain reward calculation; a refund, if that calculation grants one,
# is claimed later through the RewardManager like any other reward.
# For a production timelocked publication governance
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

# Build forge command
FORGE_CMD=(forge script deployment/scripts/DeployTeeOracle.s.sol:DeployTeeOracle
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
