#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   deploy-relay.sh factory          <source>              [--broadcast]
#   deploy-relay.sh home             <source>              [--broadcast]
#   deploy-relay.sh prepare-snapshot <source>                              # read-only, source RPC
#   deploy-relay.sh mirror           <source> <mirrorName> [--broadcast]   # after prepare-snapshot
#
#   <source>      flare | songbird | coston | coston2  (the config file basename)
#   <mirrorName>  a key under that source config's `mirrors` map (e.g. arbitrum). The mirror deploy
#                 names BOTH ends: <source> selects source-snapshot-<source>.json + <source>.json,
#                 and it asserts the snapshot's source + the entry's chainId — so you can never
#                 deploy against the wrong source's snapshot. The RPC is derived from <mirrorName>.
#
# SAFE BY DEFAULT: a run is a DRY RUN (simulation, no transactions) unless you pass an explicit
# --broadcast. Any other/misspelled flag is a hard error — a typo can never silently deploy.
#
# You only ever pass a network/mirror NAME; the RPC is derived from it. Keep the per-network RPC
# URLs in .env once (FLARE_RPC, COSTON2_RPC, ARBITRUM_RPC, ARBITRUM_SEPOLIA_RPC, …) — no
# per-invocation env vars. RPC resolution: ${NAME^^}_RPC (name uppercased, '-'→'_').
#
# Examples:
#   deploy-relay.sh home coston2                     # DRY RUN (simulate)
#   deploy-relay.sh home coston2 --broadcast         # real deployment
#   deploy-relay.sh prepare-snapshot flare           # writes source-snapshot-flare.json (read-only)
#   deploy-relay.sh mirror flare arbitrum --broadcast  # deploy the flare mirror on arbitrum
#
# On --broadcast the DEPLOYED:/NETWORK: log lines are piped through save-deployed-addresses.ts,
# which records every deployed address (Create3Factory, Relay proxy, implementation, …) into
# deployment/deploys/<name>.json and deployment/deploys/all/<name>.json — where <name> is the
# source name (home) or the mirror name (mirror).

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <factory|home|prepare-snapshot> <source> [--broadcast]" >&2
  echo "       $0 mirror <source> <mirrorName> [--broadcast]" >&2
  exit 2
fi

STEP="$1"

# `mirror` names BOTH ends (source + mirror); the RPC comes from the mirror (target) name. Every
# other step takes a single <source>/network name that also supplies the RPC.
if [[ "$STEP" == "mirror" ]]; then
  if [[ $# -lt 3 ]]; then
    echo "Usage: $0 mirror <source> <mirrorName> [--broadcast]" >&2
    exit 2
  fi
  export RELAY_SOURCE="$2"
  export RELAY_MIRROR="$3"
  RPC_NAME="$3"
  FLAG="${4:-}"
  CONTRACT="DeployRelayMirror"
  CAN_BROADCAST=1
else
  RPC_NAME="$2"
  FLAG="${3:-}"
  case "$STEP" in
    factory)          CONTRACT="DeployCreate3Factory";        CAN_BROADCAST=1 ;;
    home)             CONTRACT="DeployRelayHome";             CAN_BROADCAST=1 ;;
    prepare-snapshot) CONTRACT="PrepareRelaySourceSnapshot";  CAN_BROADCAST=0 ;;
    *) echo "Unknown step: $STEP (expected factory|home|prepare-snapshot|mirror)" >&2; exit 2 ;;
  esac
fi
SCRIPT="deployment/scripts/relay/${CONTRACT}.s.sol:${CONTRACT}"

# Broadcast is strictly opt-in. No flag -> dry run. Exactly --broadcast -> broadcast. Anything
# else is a typo and must NOT proceed.
BROADCAST=0
case "$FLAG" in
  "")           ;;
  --broadcast)  BROADCAST=1 ;;
  *) echo "Unknown flag: $FLAG (expected --broadcast, or omit for a dry run)" >&2; exit 2 ;;
esac
if [[ "$CAN_BROADCAST" == "0" && "$BROADCAST" == "1" ]]; then
  echo "$STEP is read-only and does not broadcast; omit --broadcast" >&2
  exit 2
fi

# Load env
if [[ -f .env ]]; then
  set -a
  # shellcheck source=/dev/null
  source .env
  set +a
fi

# Resolve the RPC from the network/mirror name (the target chain): <NAME>_RPC in .env
# (uppercased, '-' -> '_').
RPC_UPPER=$(echo "$RPC_NAME" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
RPC_ENV_VAR="${RPC_UPPER}_RPC"
RPC="${!RPC_ENV_VAR:-}"
if [[ -z "$RPC" ]]; then
  echo "${RPC_ENV_VAR} is required in .env" >&2
  exit 2
fi

if [[ -z "${DEPLOYER_PRIVATE_KEY:-}" ]]; then
  echo "DEPLOYER_PRIVATE_KEY is required" >&2
  exit 2
fi

# Keep a dry run side-effect-free: tell the scripts to skip writing the audit manifest
# (deployment/deploys/relay/) when not broadcasting, so a simulation never overwrites a
# committed record with simulated data. (PrepareRelaySourceSnapshot still writes its snapshot —
# that is its purpose, and it never broadcasts.)
if [[ "$BROADCAST" == "1" ]]; then export RELAY_DRY_RUN=false; else export RELAY_DRY_RUN=true; fi

LABEL="$STEP ${2:-}${3:+ $3}"
FORGE_CMD=(forge script "$SCRIPT" --rpc-url "$RPC" --private-key "$DEPLOYER_PRIVATE_KEY" --sig "run()")

if [[ "$BROADCAST" == "1" ]]; then
  echo ">>> BROADCASTING [$LABEL] — real deployment"
  "${FORGE_CMD[@]}" --broadcast | tee forge-deploy-output.txt
  npx tsx deployment/scripts/save-deployed-addresses.ts
else
  echo ">>> DRY RUN [$LABEL] (simulation, no transactions). Pass --broadcast to deploy for real."
  "${FORGE_CMD[@]}"
fi
