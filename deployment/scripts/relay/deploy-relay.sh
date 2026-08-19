#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   deploy-relay.sh factory          <source>              [--broadcast]
#   deploy-relay.sh home             <source>              [forge args...] [--broadcast]
#   deploy-relay.sh prepare-snapshot <source>              [forge args...]              # read-only, source RPC
#   deploy-relay.sh mirror           <source> <mirrorName> [forge args...] [--broadcast]  # after prepare-snapshot
#
#   <source>      flare | songbird | coston | coston2  (the config file basename)
#   <mirrorName>  a key under that source config's `mirrors` map (e.g. arbitrum). The mirror deploy
#                 names BOTH ends: <source> selects source-snapshot-<source>.json + <source>.json,
#                 and it asserts the snapshot's source + the entry's chainId — so you can never
#                 deploy against the wrong source's snapshot. The RPC is derived from <mirrorName>.
#
# SAFE BY DEFAULT: a run is a DRY RUN (simulation, no transactions) unless you pass an explicit
# --broadcast. `--resume` is rejected: it would skip the scripts' pre-flight checks and the
# address recorder — re-run the deployment instead.
#
# SIGNERS (factory/home/mirror): any forge signer works — pass its flag and it is forwarded
# verbatim:
#   deploy-relay.sh home coston2 --ledger --sender 0x... --broadcast          # Ledger
#   deploy-relay.sh home coston2 --trezor --sender 0x... --broadcast          # Trezor
#   deploy-relay.sh home coston2 --account mykey --sender 0x... --broadcast   # foundry keystore
#   deploy-relay.sh home coston2 --gcp --sender 0x... --broadcast             # Google Cloud KMS
# Keystores may also be selected via the ETH_KEYSTORE / ETH_KEYSTORE_ACCOUNT (+ ETH_PASSWORD)
# env vars; the GCP signer reads GCP_PROJECT_ID / GCP_LOCATION / GCP_KEY_RING / GCP_KEY_NAME /
# GCP_KEY_VERSION. Only when NO signer is supplied does the wrapper fall back to appending
# `--private-key "$DEPLOYER_PRIVATE_KEY"`.
# Always pair a hardware/keystore/KMS signer with --sender <expectedDeployer>: the scripts take
# msg.sender as the deployer and check it against the config's expectedDeployer and the pinned
# Relay address BEFORE anything signs. A DRY RUN needs no signing material at all — to simulate
# as the real deployer without the device attached, pass just `--sender <expectedDeployer>`
# (the key fallback is only mandatory for --broadcast).
#
# The `factory` step accepts the same signers, but note its checks differ: the Create3Factory is
# a keyless CREATE2 deployment (Arachnid deployer, frozen initcode), so its address is
# deployer-independent — any funded account works and no expectedDeployer/pin check applies there.
# `prepare-snapshot` is read-only and needs no signer at all.
#
# All other forge long options are passed through verbatim (e.g. --slow, -vvvv, --gas-estimate-
# multiplier). Unknown/misspelled flags fail loudly inside forge itself. --broadcast additionally
# passes --slow so transactions are sent serially and an on-chain revert stops the sequence.
#
# You only ever pass a network/mirror NAME; the RPC is derived from it. Keep the per-network RPC
# URLs in .env once (FLARE_RPC, COSTON2_RPC, ARBITRUM_RPC, ARBITRUM_SEPOLIA_RPC, …) — no
# per-invocation env vars. RPC resolution: ${NAME^^}_RPC (name uppercased, '-'→'_').
#
# Examples:
#   deploy-relay.sh home coston2                     # DRY RUN (simulate, key fallback)
#   deploy-relay.sh home coston2 --broadcast         # real deployment (key fallback)
#   deploy-relay.sh prepare-snapshot flare           # writes source-snapshot-flare.json (read-only)
#   deploy-relay.sh mirror flare arbitrum --ledger --sender 0x... --broadcast
#
# On --broadcast the DEPLOYED:/NETWORK: log lines are piped through save-deployed-addresses.ts,
# which records every deployed address (Create3Factory, Relay proxy, implementation, …) into
# deployment/deploys/<name>.json and deployment/deploys/all/<name>.json — where <name> is the
# source name (home) or the mirror name (mirror).

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <factory|home|prepare-snapshot> <source> [forge args...] [--broadcast]" >&2
  echo "       $0 mirror <source> <mirrorName> [forge args...] [--broadcast]" >&2
  exit 2
fi

STEP="$1"

# `mirror` names BOTH ends (source + mirror); the RPC comes from the mirror (target) name. Every
# other step takes a single <source>/network name that also supplies the RPC.
if [[ "$STEP" == "mirror" ]]; then
  if [[ $# -lt 3 || "$3" == -* ]]; then
    echo "Usage: $0 mirror <source> <mirrorName> [forge args...] [--broadcast]" >&2
    exit 2
  fi
  export RELAY_SOURCE="$2"
  export RELAY_MIRROR="$3"
  RPC_NAME="$3"
  LABEL="$STEP $2 $3"
  CONTRACT="DeployRelayMirror"
  CAN_BROADCAST=1
  shift 3
else
  if [[ "$2" == -* ]]; then
    echo "expected a <source>/network name before any flags" >&2
    exit 2
  fi
  RPC_NAME="$2"
  LABEL="$STEP $2"
  case "$STEP" in
    factory)          CONTRACT="DeployCreate3Factory";        CAN_BROADCAST=1 ;;
    home)             CONTRACT="DeployRelayHome";             CAN_BROADCAST=1 ;;
    prepare-snapshot) CONTRACT="PrepareRelaySourceSnapshot";  CAN_BROADCAST=0 ;;
    *) echo "Unknown step: $STEP (expected factory|home|prepare-snapshot|mirror)" >&2; exit 2 ;;
  esac
  shift 2
fi
SCRIPT="deployment/scripts/relay/${CONTRACT}.s.sol:${CONTRACT}"

# Classify the remaining args. The wrapper owns exactly two flags: --broadcast (dry run by
# default) and --resume (rejected). Signer flags are DETECTED — never handled — solely to decide
# whether to append the fallback --private-key; every spelling forge accepts must be listed here
# (long flags prefix-matched to cover --flag=value and variants; short clusters may hide -i/-l/-t).
# --sender deliberately does not count: it names an address without supplying signing material.
# Ambiguity fails in the loud direction: the raw key is withheld and forge errors, it is never
# silently appended next to another signer.
BROADCAST=0
SIGNER_SUPPLIED=0
EXTRA_ARGS=()
for arg in "$@"; do
  case "$arg" in
    --broadcast)
      BROADCAST=1
      continue
      ;;
    --resume|--resume=*)
      echo "--resume is not supported: it skips the scripts' pre-flight checks and the address recorder." >&2
      echo "Re-run the deployment instead — the scripts abort by themselves if the Relay already has code." >&2
      exit 2
      ;;
    --private-key*|--account*|--keystore*|--mnemonic*|--interactive*|--froms*|\
    --ledger|--trezor|--aws|--gcp|--turnkey|--unlocked)
      SIGNER_SUPPLIED=1
      ;;
    -[!-]*)
      case "$arg" in *[ilt]*) SIGNER_SUPPLIED=1 ;; esac
      ;;
  esac
  EXTRA_ARGS+=("$arg")
done

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

# Signer policy (uniform for every broadcasting step — factory, home, mirror): any forge signer
# works; the raw key is only the fallback, and only a broadcast requires signing material at all.
# prepare-snapshot is read-only and needs no signer.
if [[ "$STEP" != "prepare-snapshot" ]]; then
  # A keystore selected via env vars counts as a supplied signer too.
  if [[ -n "${ETH_KEYSTORE:-}" || -n "${ETH_KEYSTORE_ACCOUNT:-}" ]]; then
    SIGNER_SUPPLIED=1
  fi
  if [[ "$SIGNER_SUPPLIED" == "0" ]]; then
    if [[ -n "${DEPLOYER_PRIVATE_KEY:-}" ]]; then
      EXTRA_ARGS+=(--private-key "$DEPLOYER_PRIVATE_KEY")
    elif [[ "$BROADCAST" == "1" ]]; then
      echo "DEPLOYER_PRIVATE_KEY is required unless a signer is supplied" >&2
      echo "  e.g. $0 $STEP $RPC_NAME --account <name> --sender <address> --broadcast" >&2
      echo "  or:  $0 $STEP $RPC_NAME --ledger --sender <address> --broadcast" >&2
      exit 2
    fi
    # else: a dry run needs no signing material — simulate with --sender <expectedDeployer>.
  fi
fi

# Keep a dry run side-effect-free: tell the scripts to skip writing the audit manifest
# (deployment/deploys/relay/) when not broadcasting, so a simulation never overwrites a
# committed record with simulated data. (PrepareRelaySourceSnapshot still writes its snapshot —
# that is its purpose, and it never broadcasts.)
if [[ "$BROADCAST" == "1" ]]; then export RELAY_DRY_RUN=false; else export RELAY_DRY_RUN=true; fi

FORGE_CMD=(forge script "$SCRIPT" --rpc-url "$RPC" --sig "run()" ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"})

if [[ "$BROADCAST" == "1" ]]; then
  echo ">>> BROADCASTING [$LABEL] — real deployment"
  # --slow sends the transactions serially: an on-chain revert stops the rest of the sequence.
  "${FORGE_CMD[@]}" --broadcast --slow | tee forge-deploy-output.txt
  # The key was only needed to sign the broadcast; drop it so post-processing never inherits it.
  # Harmless when a signer flag was used instead and the variable was never set.
  unset DEPLOYER_PRIVATE_KEY
  npx tsx deployment/scripts/save-deployed-addresses.ts
else
  echo ">>> DRY RUN [$LABEL] (simulation, no transactions). Pass --broadcast to deploy for real."
  "${FORGE_CMD[@]}"
fi
