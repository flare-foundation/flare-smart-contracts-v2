#!/bin/sh
set -e
export PATH=/kontrol/.venv/bin:$HOME/.nix-profile/bin:$HOME/.local/bin:$PATH
export JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
mkdir -p /work/src
cd /work
# wipe stale build artifacts (the host dir persists across runs -> kontrol would reuse an old kompile)
rm -rf /work/out /work/kout /work/.kontrol /work/cache /work/broadcast 2>/dev/null || true
nix profile install --priority 4 nixpkgs#solc >/dev/null 2>&1 || true
SOLC="$(command -v solc)"
echo "### versions: $(kontrol version 2>/dev/null) ; solc $($SOLC --version 2>&1 | tail -1)"
cat > /work/foundry.toml <<EOF
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
kontrol prove --no-fail-fast --force-sequential --smt-timeout 120000 --smt-retry-limit 4 --match-test 'RelaySigLoopFV\.prove_' || true
t3=$(date +%s); echo "### kontrol prove took $((t3-t2))s"
echo "### TIMING: forge=$((t1-t0))s kontrol_build=$((t2-t1))s kontrol_prove=$((t3-t2))s"
echo "### RESULTS:"
kontrol list 2>/dev/null | grep -iE "prove_|passed|failed" | head -40 || true
echo "### ALL DONE"
