#!/bin/sh
set -e
export PATH=/kontrol/.venv/bin:$HOME/.nix-profile/bin:$HOME/.local/bin:$PATH
export JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
mkdir -p /work/src
cd /work
# Wipe stale build artifacts (the host dir persists across runs -> Kontrol would reuse an old kompile).
rm -rf /work/out /work/kout /work/.kontrol /work/cache /work/broadcast 2>/dev/null || true
SOLC="$(command -v solc)"
KONTROL_VERSION="$(kontrol version 2>&1)"
K_VERSION="$(kompile --version 2>&1)"
SOLC_VERSION="$($SOLC --version 2>&1 | sed -n 's/^Version: \([0-9.]*\).*/\1/p')"
case "$KONTROL_VERSION" in *"1.0.248"*) ;; *) echo "unexpected Kontrol version: $KONTROL_VERSION"; exit 1;; esac
case "$K_VERSION" in *"7.1.334"*) ;; *) echo "unexpected K version: $K_VERSION"; exit 1;; esac
[ "$SOLC_VERSION" = "0.8.33" ] || { echo "unexpected solc version: $SOLC_VERSION"; exit 1; }
echo "### versions: $KONTROL_VERSION ; $K_VERSION ; solc $SOLC_VERSION"
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
# Prove BOTH documented harnesses (kontrol build above compiles all proofs; this filters which to run).
# RelayRandomMonoFV is heavier — comment it out of the alternation to reproduce only the signature loop.
set +e
kontrol prove --no-fail-fast --force-sequential --smt-timeout 120000 --smt-retry-limit 4 \
  --match-test '(RelaySigLoopFV|RelayRandomMonoFV)\.prove_' \
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
