#!/usr/bin/env python3
"""Enforce the Relay.sol formal-verification suite invariant (CI gate).

Runs Halmos over the FV proof harnesses in test-forge/fv and checks BOTH halves
of every proof:

  * every PROOF check passes (no counterexample), and
  * every REACHABILITY / non-vacuity control passes its OWN bar by producing a
    COUNTEREXAMPLE.

A reachability control is identified by 'reach' (case-insensitive) in its function
name; it asserts !accept on a configuration that SHOULD accept, so Halmos must
refute it with a witness. If such a control instead PASSES, the accept path is
unreachable (e.g. the --loop bound dropped below the signer count) and the proofs
it guards have gone VACUOUS — that is a hard CI failure ("VACUITY ALARM"), which is
the whole reason this gate exists (it already happened once at the default loop=2;
see docs/relay-fv.md).

Halmos exits non-zero whenever ANY check has a counterexample (our reachability
controls do, by design), so its raw exit code is NOT a usable CI signal — this
script judges each check from the JSON output instead.

Usage (run from the repo root; halmos.toml supplies loop=6 + forge-build-out):
    HALMOS=halmos python3 test-forge/fv/verify_fv.py [extra halmos args]
e.g. to demonstrate the tripwire firing on a too-small bound:
    python3 test-forge/fv/verify_fv.py --loop 2     # expect FAIL (vacuity alarms)
"""
import json
import os
import subprocess
import sys
import tempfile


def is_reachability(fn_name: str) -> bool:
    # naming convention across the FV harnesses: reachability/non-vacuity controls
    # contain 'reach' (e.g. check_reachability_*, check_reach_*, *_mismatchReachable_*)
    return "reach" in fn_name.lower()


def main() -> int:
    halmos = os.environ.get("HALMOS", "halmos")
    out = tempfile.NamedTemporaryFile(suffix=".json", delete=False).name
    cmd = [halmos, "--function", "check_", "--json-output", out] + sys.argv[1:]
    print("[fv] running:", " ".join(cmd), flush=True)
    subprocess.run(cmd, check=False)  # ignore exit code; judge via JSON

    try:
        with open(out) as f:
            data = json.load(f)
    except Exception as e:  # noqa: BLE001
        print(f"[fv] FAIL: could not read Halmos JSON output ({e}).")
        return 1

    results = data.get("test_results", {})
    if not results:
        print("[fv] FAIL: no FV test results (build error, or no check_ functions found).")
        return 1

    proofs_ok = reach_ok = 0
    violations = []
    rows = []
    for suite, checks in sorted(results.items()):
        short = suite.split("/")[-1]
        for c in checks:
            name = c["name"].split("(")[0]
            cex = c.get("exitcode", 1) != 0  # non-zero exitcode => counterexample found
            qualified = f"{short}.{name}"
            if is_reachability(name):
                if cex:
                    reach_ok += 1
                    rows.append(("CEX  (expected)", qualified))
                else:
                    rows.append(("PASS *** VACUITY ALARM ***", qualified))
                    violations.append(
                        f"{qualified}: reachability control PASSED — the accept path is "
                        f"unreachable, so the proofs it guards are VACUOUS "
                        f"(check that --loop >= signer count)."
                    )
            else:
                if not cex:
                    proofs_ok += 1
                    rows.append(("PASS (proof)", qualified))
                else:
                    rows.append(("CEX  *** PROOF FAILED ***", qualified))
                    violations.append(
                        f"{qualified}: proof produced a counterexample — a verified property regressed."
                    )

    for status, qualified in rows:
        print(f"  {status:30}  {qualified}")

    print(
        f"\n[fv] {len(rows)} checks: {proofs_ok} proofs hold, "
        f"{reach_ok} reachability controls live (CEX). "
        f"{len(violations)} violation(s)."
    )
    if violations:
        print("\n[fv] FAIL:")
        for v in violations:
            print("   -", v)
        return 1
    print("[fv] OK — all proofs hold and every reachability control is live (non-vacuous).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
