#!/usr/bin/env bash
# Regenerates the Certora verification-only "munged" tree (certora/munged/) from the production sources.
#
# WHY THIS EXISTS. The write-once rules (certora/specs/RelayWriteOnce.spec) must READ
# `toSigningPolicyHashPrivate` / `merkleRootsPrivate` before and after each method call. Both mappings are
# `private`, so no harness can read them, and CVL direct storage access is unavailable on this contract
# (Relay's raw-assembly stores defeat the prover's storage analysis — the documented C-1 wall). The
# standard Certora practice is a munged verification copy. The ONLY change made here is the visibility of
# those two mappings: `private` -> `internal` (same storage layout, same slots, no behavior change), which
# lets certora/harness/RelayHarness.sol expose plain Solidity view getters over them.
#
# FAITHFULNESS IS MACHINE-CHECKED: this script re-derives the munged tree from the production files on
# every run and FAILS if the result differs from anything but the two visibility keywords. Run it (or CI
# runs it) before every Certora write-once run; a drifted production Relay.sol can therefore never be
# silently verified against a stale munged copy.
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root

SRC=contracts
DST=certora/munged/contracts
mkdir -p "$DST/protocol/implementation" "$DST/protocol/interface" "$DST/userInterfaces/LTS"

# 1. verbatim dependencies (byte-identical copies)
cp "$SRC/protocol/interface/IIRelay.sol"                 "$DST/protocol/interface/IIRelay.sol"
cp "$SRC/userInterfaces/IRelay.sol"                      "$DST/userInterfaces/IRelay.sol"
cp "$SRC/userInterfaces/LTS/RandomNumberV2Interface.sol" "$DST/userInterfaces/LTS/RandomNumberV2Interface.sol"

# 2. Relay.sol with EXACTLY two visibility changes
python3 - "$SRC/protocol/implementation/Relay.sol" "$DST/protocol/implementation/Relay.sol" <<'EOF'
import sys
src, dst = sys.argv[1], sys.argv[2]
s = open(src).read()
subs = [
    ("mapping(uint256 rewardEpochId => bytes32) private toSigningPolicyHashPrivate;",
     "mapping(uint256 rewardEpochId => bytes32) internal toSigningPolicyHashPrivate;"),
    ("mapping(uint256 protocolId => mapping(uint256 votingRoundId => bytes32)) private merkleRootsPrivate;",
     "mapping(uint256 protocolId => mapping(uint256 votingRoundId => bytes32)) internal merkleRootsPrivate;"),
]
for old, new in subs:
    assert s.count(old) == 1, f"munge target not found exactly once: {old}"
    s = s.replace(old, new)
open(dst, "w").write(s)
EOF

# 3. verify: munged Relay differs from production by EXACTLY the two visibility lines
# (diff exits 1 when files differ — expected here — so shield it from set -o pipefail)
DIFFLINES=$( (diff "$SRC/protocol/implementation/Relay.sol" "$DST/protocol/implementation/Relay.sol" || true) | grep -c '^[<>]')
if [ "$DIFFLINES" != "4" ]; then   # 2 removed + 2 added
  echo "MUNGE VERIFICATION FAILED: expected exactly 2 changed lines (4 diff lines), got $DIFFLINES" >&2
  diff "$SRC/protocol/implementation/Relay.sol" "$DST/protocol/implementation/Relay.sol" >&2 || true
  exit 1
fi
if (diff "$SRC/protocol/implementation/Relay.sol" "$DST/protocol/implementation/Relay.sol" || true) | grep '^[<>]' | grep -qv 'toSigningPolicyHashPrivate;\|merkleRootsPrivate;'; then
  echo "MUNGE VERIFICATION FAILED: a changed line is not one of the two visibility declarations" >&2
  exit 1
fi
# 4. verify: the dependency copies are byte-identical
cmp -s "$SRC/protocol/interface/IIRelay.sol"                 "$DST/protocol/interface/IIRelay.sol"
cmp -s "$SRC/userInterfaces/IRelay.sol"                      "$DST/userInterfaces/IRelay.sol"
cmp -s "$SRC/userInterfaces/LTS/RandomNumberV2Interface.sol" "$DST/userInterfaces/LTS/RandomNumberV2Interface.sol"

echo "munge OK: certora/munged/ regenerated; Relay.sol differs by exactly the 2 visibility keywords."
