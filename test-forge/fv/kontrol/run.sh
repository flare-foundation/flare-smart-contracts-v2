#!/bin/sh
set -e
export PATH=/kontrol/.venv/bin:$HOME/.nix-profile/bin:$HOME/.local/bin:$PATH
export JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
# solc provisioning: the pinned image *should* ship solc 0.8.33, but if it did not land (observed on some
# rebuilds), self-provision it from the same pinned nixpkgs the Dockerfile uses. Idempotent, exact version.
command -v solc >/dev/null 2>&1 || \
  nix profile install github:NixOS/nixpkgs/9eac87a12312b8f60dd52e1c6e1a265f6fc7f5fc#solc --accept-flake-config
SOLC="$(command -v solc)"
KONTROL_VERSION="$(kontrol version 2>&1)"
K_VERSION="$(kompile --version 2>&1)"
SOLC_VERSION="$($SOLC --version 2>&1 | sed -n 's/^Version: \([0-9.]*\).*/\1/p')"
case "$KONTROL_VERSION" in *"1.0.248"*) ;; *) echo "unexpected Kontrol version: $KONTROL_VERSION"; exit 1;; esac
case "$K_VERSION" in *"7.1.334"*) ;; *) echo "unexpected K version: $K_VERSION"; exit 1;; esac
[ "$SOLC_VERSION" = "0.8.33" ] || { echo "unexpected solc version: $SOLC_VERSION"; exit 1; }
echo "### versions: $KONTROL_VERSION ; $K_VERSION ; solc $SOLC_VERSION"

# Build in a CLEAN, container-internal Foundry project using the STANDARD test/ sub-directory layout.
# Two reasons this matters (both learned by running the recipe end-to-end):
#   1. kontrol's JUnit writer (foundry_to_xml, 1.0.248) requires a `label%Contract` proof id. Harnesses at
#      the project ROOT get a bare `Contract` id and crash the writer (contract.rsplit('%') -> ValueError);
#      the test/ sub-dir yields `test%Contract`, which the writer handles.
#   2. Building under /proj keeps all forge/Kontrol artifacts out of the mounted host directory.
# The harnesses are mounted read-side at /work; copy them into the standard location.
rm -rf /proj; mkdir -p /proj/test /proj/src
cp /work/*.t.sol /proj/test/
cd /proj
cat > /proj/foundry.toml <<EOF
[profile.default]
src = 'src'
out = 'out'
test = 'test'
libs = ['lib']
solc = '$SOLC'
EOF

t0=$(date +%s)
echo "### [1/3] forge build"; forge build --use "$SOLC"
t1=$(date +%s); echo "### forge build took $((t1-t0))s"
echo "### [2/3] kontrol build"; kontrol build
t2=$(date +%s); echo "### kontrol build took $((t2-t1))s"
echo "### [3/3] kontrol prove"
# Prove ALL THREE documented harnesses in one invocation: the signature loop at N=3 (RelaySigLoopFV) and
# N=5 (RelaySigLoopFV_N5), plus random monotonicity (RelayRandomMonoFV). NOTE: kontrol --match-test
# supports top-level `|` alternation but NOT `(...)` grouping (it escapes the parens and matches nothing),
# so each alternative is spelled out in full. `RelaySigLoopFV\.` (literal dot) matches N=3 only, never the
# N=5 contract. Drop an alternative to reproduce a subset; RelayRandomMonoFV is the heaviest.
set +e
kontrol prove --no-fail-fast --force-sequential --smt-timeout 120000 --smt-retry-limit 4 \
  --match-test 'RelaySigLoopFV\.prove_|RelaySigLoopFV_N5\.prove_|RelayRandomMonoFV\.prove_' \
  --xml-test-report --xml-test-report-name /work/kontrol_prove_report.xml
prove_exit=$?
set -e
t3=$(date +%s); echo "### kontrol prove took $((t3-t2))s"
echo "### TIMING: forge=$((t1-t0))s kontrol_build=$((t2-t1))s kontrol_prove=$((t3-t2))s"
python3 /work/verify_kontrol.py \
  --junit-report /work/kontrol_prove_report.xml \
  --process-exitcode "$prove_exit" \
  --report-output /work/kontrol-verification-report.json
echo "### ALL EXPECTED RESULTS VERIFIED"
