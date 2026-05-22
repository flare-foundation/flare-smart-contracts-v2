#!/usr/bin/env bash
# Smoke test for the Hardhat simulation (`pnpm sim-run`).
#
# Starts `pnpm sim-node` and `pnpm sim-run`, watches sim-run stdout for three
# success markers (startup + voting round finished + signing policy signed),
# then kills both processes. Exits 0 on success, nonzero on failure.
# Runs in bash (on Windows use Git Bash / WSL).
#
# Usage (from repo root):
#   .claude/skills/check-all/scripts/smoke-sim.sh
#   TIMEOUT_START=180 TIMEOUT_VOTING=90 TIMEOUT_POLICY=240 \
#     .claude/skills/check-all/scripts/smoke-sim.sh
#
# Exit codes:
#   0  all markers seen — simulation is healthy
#   1  node failed to come up on RPC
#   2  [Starting simulation] not seen within TIMEOUT_START
#   3  'Voting round N finished' not seen within TIMEOUT_VOTING after startup
#   4  'Event RewardEpochStarted emitted' not seen within TIMEOUT_POLICY after startup
#   5  error line detected in log before all markers
#   6  sim-node or sim-run died mid-run

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
cd "$ROOT_DIR"

LOG_DIR="${LOG_DIR:-/tmp}"
NODE_LOG="$LOG_DIR/sim-node.log"
RUN_LOG="$LOG_DIR/sim-run.log"

TIMEOUT_NODE="${TIMEOUT_NODE:-60}"       # seconds to wait for RPC
TIMEOUT_START="${TIMEOUT_START:-120}"    # seconds for "[Starting simulation]"
TIMEOUT_VOTING="${TIMEOUT_VOTING:-60}"   # seconds after startup for "Voting round N finished"
TIMEOUT_POLICY="${TIMEOUT_POLICY:-180}"  # seconds after startup for RewardEpochStarted

MARKER_START='\[Starting simulation\]'
# Voting round finished: main loop + finalization pipeline are progressing.
# Fires ~30-40s after startup with default voting epoch durations.
MARKER_VOTING='Voting round [0-9]+ finished'
# Reward epoch started: proves the full signing-policy pipeline completed
# end-to-end (policy initialized → signed by threshold → reward epoch advanced).
# Fires at the first reward-epoch boundary; typically ~40-60s after startup
# with default sim parameters, but depends on rewardEpochDurationSec and
# newSigningPolicyInitializationStartSeconds — keep TIMEOUT_POLICY generous.
MARKER_POLICY='Event RewardEpochStarted emitted'
ERROR_PATTERN='(Error:|revert|Uncaught|stack trace)'

node_pid=""
run_pid=""

is_windows() {
  [[ "${OSTYPE:-}" == "msys" || "${OSTYPE:-}" == "cygwin" || "${OSTYPE:-}" == "win32" ]]
}

# Kill a process and its entire descendant tree.
# On Git Bash / MSYS / Cygwin, `taskkill //F //T //PID` kills the full tree
# including node.exe grandchildren spawned by pnpm; `pkill -P` alone only
# kills direct children, leaving hardhat running and bound to 8545.
kill_tree() {
  local pid=$1
  [[ -z "$pid" ]] && return 0
  if is_windows; then
    taskkill //F //T //PID "$pid" >/dev/null 2>&1 || true
  else
    pkill -9 -P "$pid" 2>/dev/null || true
    kill -9 "$pid" 2>/dev/null || true
  fi
}

port_in_use() {
  curl -s -o /dev/null --max-time 2 -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' \
    http://127.0.0.1:8545 2>/dev/null
}

# Kill any process currently bound to 127.0.0.1:8545 (zombies from prior runs).
# Returns 0 if port was free or cleared, 1 if it could not be freed.
free_port_8545() {
  if ! port_in_use; then
    return 0
  fi
  echo "      warning: something is already listening on 8545, attempting to free it..."
  if is_windows; then
    # netstat -aon on Windows lists "... 127.0.0.1:8545 ... LISTENING  <pid>"
    local pids
    pids=$(netstat -aon 2>/dev/null | awk '/:8545[[:space:]]/ && /LISTENING/ {print $NF}' | sort -u)
    for p in $pids; do
      echo "      killing stale pid $p"
      taskkill //F //T //PID "$p" >/dev/null 2>&1 || true
    done
  else
    fuser -k 8545/tcp 2>/dev/null || true
  fi
  sleep 2
  if port_in_use; then
    return 1
  fi
  return 0
}

cleanup() {
  local exit_code=$?
  echo
  echo "=== Cleanup ==="
  if [[ -n "$run_pid" ]]; then
    echo "Killing sim-run tree (pid $run_pid)..."
    kill_tree "$run_pid"
  fi
  if [[ -n "$node_pid" ]]; then
    echo "Killing sim-node tree (pid $node_pid)..."
    kill_tree "$node_pid"
  fi
  # Final safety net: ensure nothing is left on 8545
  sleep 1
  if port_in_use; then
    echo "      port 8545 still in use after tree-kill, force-freeing..."
    free_port_8545 || echo "      (still stuck — may need manual cleanup)"
  fi
  exit $exit_code
}
trap cleanup EXIT INT TERM

fail() {
  local code=$1
  local msg=$2
  echo
  echo "FAIL ($code): $msg"
  echo
  echo "--- last 40 lines of sim-run.log ---"
  tail -n 40 "$RUN_LOG" 2>/dev/null || echo "(no log)"
  exit "$code"
}

wait_for_rpc() {
  local deadline=$((SECONDS + TIMEOUT_NODE))
  while (( SECONDS < deadline )); do
    if curl -s -o /dev/null -w "%{http_code}" \
         -H "Content-Type: application/json" \
         --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' \
         http://127.0.0.1:8545 2>/dev/null | grep -q "200"; then
      return 0
    fi
    if [[ -n "$node_pid" ]] && ! kill -0 "$node_pid" 2>/dev/null; then
      return 1
    fi
    sleep 1
  done
  return 1
}

# wait_for_marker <regex> <timeout> <label>
# Returns: 0 match, 1 timeout, 2 error in log, 3 sim-node died, 4 sim-run died
# Prints elapsed seconds to stdout on match.
wait_for_marker() {
  local marker=$1
  local timeout=$2
  local label=$3
  local start_ts=$SECONDS
  local deadline=$((start_ts + timeout))
  while (( SECONDS < deadline )); do
    if grep -Eq "$marker" "$RUN_LOG" 2>/dev/null; then
      echo "  [$label] marker seen after $((SECONDS - start_ts))s"
      return 0
    fi
    if grep -Eq "$ERROR_PATTERN" "$RUN_LOG" 2>/dev/null; then
      return 2
    fi
    if [[ -n "$node_pid" ]] && ! kill -0 "$node_pid" 2>/dev/null; then
      return 3
    fi
    if [[ -n "$run_pid" ]] && ! kill -0 "$run_pid" 2>/dev/null; then
      return 4
    fi
    sleep 2
  done
  return 1
}

echo "=== Simulation smoke test ==="
echo "Working dir: $ROOT_DIR"
echo "Logs:        $NODE_LOG, $RUN_LOG"
echo "Timeouts:    node=${TIMEOUT_NODE}s start=${TIMEOUT_START}s voting=${TIMEOUT_VOTING}s policy=${TIMEOUT_POLICY}s"
echo "Overall cap: ~$((TIMEOUT_NODE + TIMEOUT_START + TIMEOUT_POLICY))s"
echo

: > "$NODE_LOG"
: > "$RUN_LOG"

test_start=$SECONDS

echo "[0/5] Checking port 8545 is free..."
if ! free_port_8545; then
  echo
  echo "FAIL: port 8545 is in use and could not be freed. Kill the process manually and retry."
  exit 1
fi
echo "      port 8545 is free"

echo "[1/5] Starting sim-node..."
pnpm sim-node > "$NODE_LOG" 2>&1 &
node_pid=$!
echo "      pid=$node_pid"

echo "[2/5] Waiting for RPC on 127.0.0.1:8545 (up to ${TIMEOUT_NODE}s)..."
rpc_start=$SECONDS
if ! wait_for_rpc; then
  fail 1 "sim-node did not become reachable on 127.0.0.1:8545"
fi
rpc_time=$((SECONDS - rpc_start))
echo "      RPC up after ${rpc_time}s"

echo "[3/5] Starting sim-run..."
run_start=$SECONDS
pnpm sim-run > "$RUN_LOG" 2>&1 &
run_pid=$!
echo "      pid=$run_pid"

echo "[4/5] Waiting for '[Starting simulation]' (up to ${TIMEOUT_START}s)..."
wait_for_marker "$MARKER_START" "$TIMEOUT_START" "startup"
rc=$?
case $rc in
  0) ;;
  1) fail 2 "timeout waiting for '[Starting simulation]'" ;;
  2) fail 5 "error line appeared in sim-run.log before startup marker" ;;
  3) fail 6 "sim-node died before startup marker" ;;
  4) fail 6 "sim-run exited before startup marker" ;;
esac
startup_time=$((SECONDS - run_start))

# After startup, wait for voting round + signing policy from the same baseline.
# The two markers are expected in order (voting first, usually ~30s; policy later,
# ~120s+). We check voting first so a stuck loop fails fast.
echo "[5/5] Waiting for marker A: '$MARKER_VOTING' (up to ${TIMEOUT_VOTING}s)..."
wait_for_marker "$MARKER_VOTING" "$TIMEOUT_VOTING" "voting"
rc=$?
case $rc in
  0) ;;
  1) fail 3 "timeout waiting for '$MARKER_VOTING' — main loop not progressing" ;;
  2) fail 5 "error line appeared in sim-run.log before voting marker" ;;
  3) fail 6 "sim-node died before voting marker" ;;
  4) fail 6 "sim-run exited before voting marker" ;;
esac
voting_time=$((SECONDS - run_start))

# TIMEOUT_POLICY is measured from sim-run start, not from here — subtract elapsed.
remaining_policy=$((TIMEOUT_POLICY - (SECONDS - run_start)))
if (( remaining_policy <= 0 )); then
  fail 4 "already past TIMEOUT_POLICY (${TIMEOUT_POLICY}s) before checking policy marker"
fi
echo "      Waiting for marker B: '$MARKER_POLICY' (up to ${remaining_policy}s)..."
wait_for_marker "$MARKER_POLICY" "$remaining_policy" "policy"
rc=$?
case $rc in
  0) ;;
  1) fail 4 "timeout waiting for '$MARKER_POLICY' — reward-epoch transition not reached" ;;
  2) fail 5 "error line appeared in sim-run.log before policy marker" ;;
  3) fail 6 "sim-node died before policy marker" ;;
  4) fail 6 "sim-run exited before policy marker" ;;
esac
policy_time=$((SECONDS - run_start))

total_time=$((SECONDS - test_start))

echo
echo "PASS: simulation reached all three markers."
echo "  RPC up:                ${rpc_time}s"
echo "  [Starting simulation]: ${startup_time}s after sim-run start"
echo "  Voting round finished: ${voting_time}s after sim-run start"
echo "  RewardEpochStarted:    ${policy_time}s after sim-run start"
echo "  Total test duration:   ${total_time}s"
exit 0