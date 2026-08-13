#!/usr/bin/env bash
# Regenerates the Certora verification-only "munged" tree (certora/munged/) from the production sources.
#
# WHY THIS EXISTS. The write-once and fee-table rules (certora/specs/RelayWriteOnce.spec) must READ
# `toSigningPolicyHashPrivate`, `merkleRootsPrivate`, and `feeProtocolIdsPrivate` before and after method
# calls. Those values are private, so no harness can read them, and CVL direct storage access is unavailable
# for the mappings because Relay's raw-assembly stores are not tracked reliably by that analysis. The
# verification scene therefore uses a munged copy. The ONLY semantic-source changes made here are the visibility of
# those two mappings and the fee-protocol enumeration set: `private` -> `internal` (same storage layout, same slots,
# no behavior change), which lets certora/harness/RelayHarness.sol expose plain Solidity view getters over them.
#
# FAITHFULNESS IS MACHINE-CHECKED: this script re-derives the munged tree from the production files on
# every run and FAILS if the result differs from anything but the three visibility keywords. Run it (or CI
# runs it) before every Certora write-once run; a drifted production Relay.sol can therefore never be
# silently verified against a stale munged copy.
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root

SRC=contracts
DST=certora/munged/contracts

# This directory is generated output. Recreate it so unlisted files cannot
# remain in the Certora source graph unnoticed.
rm -rf "$DST"
mkdir -p \
  "$DST/protocol/implementation" \
  "$DST/protocol/interface" \
  "$DST/utils/implementation" \
  "$DST/userInterfaces" \
  "$DST/userInterfaces/LTS"

# 1. verbatim dependencies (byte-identical copies)
cp "$SRC/protocol/interface/IIRelay.sol"                  "$DST/protocol/interface/IIRelay.sol"
cp "$SRC/utils/implementation/OwnableWithTimelock.sol"    "$DST/utils/implementation/OwnableWithTimelock.sol"
cp "$SRC/userInterfaces/IOwnableWithTimelock.sol"         "$DST/userInterfaces/IOwnableWithTimelock.sol"
cp "$SRC/userInterfaces/IRelay.sol"                       "$DST/userInterfaces/IRelay.sol"
cp "$SRC/userInterfaces/LTS/RandomNumberV2Interface.sol" "$DST/userInterfaces/LTS/RandomNumberV2Interface.sol"

# 2. Relay.sol with EXACTLY three visibility changes
python3 - "$SRC/protocol/implementation/Relay.sol" "$DST/protocol/implementation/Relay.sol" <<'EOF'
import sys
src, dst = sys.argv[1], sys.argv[2]
s = open(src).read()
subs = [
    ("mapping(uint256 rewardEpochId => bytes32) private toSigningPolicyHashPrivate;",
     "mapping(uint256 rewardEpochId => bytes32) internal toSigningPolicyHashPrivate;"),
    ("mapping(uint256 protocolId => mapping(uint256 votingRoundId => bytes32)) private merkleRootsPrivate;",
     "mapping(uint256 protocolId => mapping(uint256 votingRoundId => bytes32)) internal merkleRootsPrivate;"),
    ("EnumerableSet.UintSet private feeProtocolIdsPrivate;",
     "EnumerableSet.UintSet internal feeProtocolIdsPrivate;"),
]
for old, new in subs:
    assert s.count(old) == 1, f"munge target not found exactly once: {old}"
    s = s.replace(old, new)
open(dst, "w").write(s)
EOF

# 3. verify: munged Relay differs from production by EXACTLY the three visibility lines
# (diff exits 1 when files differ — expected here — so shield it from set -o pipefail)
DIFFLINES=$( (diff "$SRC/protocol/implementation/Relay.sol" "$DST/protocol/implementation/Relay.sol" || true) | grep -c '^[<>]')
if [ "$DIFFLINES" != "6" ]; then   # 3 removed + 3 added
  echo "MUNGE VERIFICATION FAILED: expected exactly 3 changed lines (6 diff lines), got $DIFFLINES" >&2
  diff "$SRC/protocol/implementation/Relay.sol" "$DST/protocol/implementation/Relay.sol" >&2 || true
  exit 1
fi
if (diff "$SRC/protocol/implementation/Relay.sol" "$DST/protocol/implementation/Relay.sol" || true) | grep '^[<>]' | grep -qv 'toSigningPolicyHashPrivate;\|merkleRootsPrivate;\|feeProtocolIdsPrivate;'; then
  echo "MUNGE VERIFICATION FAILED: a changed line is not one of the three visibility declarations" >&2
  exit 1
fi
# 4. verify: the dependency copies are byte-identical
cmp -s "$SRC/protocol/interface/IIRelay.sol"                  "$DST/protocol/interface/IIRelay.sol"
cmp -s "$SRC/utils/implementation/OwnableWithTimelock.sol"    "$DST/utils/implementation/OwnableWithTimelock.sol"
cmp -s "$SRC/userInterfaces/IOwnableWithTimelock.sol"         "$DST/userInterfaces/IOwnableWithTimelock.sol"
cmp -s "$SRC/userInterfaces/IRelay.sol"                       "$DST/userInterfaces/IRelay.sol"
cmp -s "$SRC/userInterfaces/LTS/RandomNumberV2Interface.sol" "$DST/userInterfaces/LTS/RandomNumberV2Interface.sol"

echo "munge OK: certora/munged/ regenerated; Relay.sol differs by exactly the 3 visibility keywords."
