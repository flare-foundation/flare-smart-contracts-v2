#!/usr/bin/env python3
"""Judge Kontrol's JUnit report against the exact Relay proof inventory."""

from __future__ import annotations

import argparse
import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any


HERE = Path(__file__).resolve().parent
DEFAULT_MANIFEST = HERE / "verification-manifest.json"


def load_manifest(path: Path) -> dict[str, Any]:
    manifest = json.loads(path.read_text())
    if manifest.get("schema_version") != 1:
        raise ValueError("Kontrol manifest schema_version must be 1")
    declared = manifest.get("proofs", []) + manifest.get("reachability", [])
    if len(declared) != manifest.get("expected_check_count"):
        raise ValueError("Kontrol expected_check_count does not match the declared inventory")
    if len(set(declared)) != len(declared):
        raise ValueError("Kontrol manifest contains duplicate checks")
    return manifest


def concrete_failure(failure: ET.Element) -> tuple[bool, str]:
    evidence = "\n".join(
        part for part in (failure.get("message", ""), failure.text or "") if part
    ).strip()
    if not evidence:
        return False, "failure has no counterexample/failure evidence"
    lowered = evidence.lower()
    bad_markers = ("smt timeout", "exception", "could not be completed", "incomplete proof", "stuck")
    if any(marker in lowered for marker in bad_markers) or re.search(r"\b[1-9][0-9]* pending\b", lowered):
        return False, "failure is incomplete or tool-generated, not a validated reachability witness"
    if not re.search(r"\b0 pending\b", lowered) or "model:" not in lowered:
        return False, "failure does not contain a complete zero-pending concrete model"
    witness_markers = ("failure", "failing", "assert", "evmc_revert", "statuscode", "counterexample", "model")
    if not any(marker in lowered for marker in witness_markers):
        return False, "failure output has no recognized concrete-proof-failure marker"
    return True, evidence


def evaluate_junit(root: ET.Element, manifest: dict[str, Any], process_exitcode: int) -> dict[str, Any]:
    proof_ids = set(manifest["proofs"])
    reach_ids = set(manifest["reachability"])
    expected = proof_ids | reach_ids
    violations: list[str] = []
    if process_exitcode != manifest["expected_process_exitcode"]:
        violations.append(
            f"kontrol prove exitcode is {process_exitcode}; expected {manifest['expected_process_exitcode']}"
        )

    actual: dict[str, ET.Element] = {}
    for suite in root.findall(".//testsuite"):
        suite_name = suite.get("name")
        if not suite_name:
            violations.append("JUnit testsuite has no name")
            continue
        for case in suite.findall("testcase"):
            case_name = case.get("name")
            if not case_name:
                violations.append(f"{suite_name}: JUnit testcase has no name")
                continue
            check_id = f"{suite_name}.{case_name.split('(', 1)[0]}"
            if check_id in actual:
                violations.append(f"duplicate Kontrol result: {check_id}")
            else:
                actual[check_id] = case

    missing = sorted(expected - actual.keys())
    unexpected = sorted(actual.keys() - expected)
    if missing:
        violations.append("missing expected Kontrol checks: " + ", ".join(missing))
    if unexpected:
        violations.append("unexpected Kontrol checks: " + ", ".join(unexpected))

    rows: list[dict[str, Any]] = []
    proofs_ok = 0
    reachability_ok = 0
    for check_id in sorted(expected & actual.keys()):
        case = actual[check_id]
        problems: list[str] = []
        error = case.find("error")
        skipped = case.find("skipped")
        failure = case.find("failure")
        expectation = "proof" if check_id in proof_ids else "reachability"

        if error is not None:
            problems.append("Kontrol reported a tool/proof error")
        if skipped is not None:
            problems.append("Kontrol skipped the check")
        if expectation == "proof":
            if failure is not None:
                problems.append("proof produced a counterexample")
        elif failure is None:
            problems.append("reachability control passed, so its witness was not demonstrated")
        else:
            valid_failure, reason = concrete_failure(failure)
            if not valid_failure:
                problems.append(reason)

        healthy = not problems
        if healthy and expectation == "proof":
            proofs_ok += 1
        if healthy and expectation == "reachability":
            reachability_ok += 1
        for problem in problems:
            violations.append(f"{check_id}: {problem}")
        rows.append(
            {
                "id": check_id,
                "expectation": expectation,
                "outcome": "pass" if healthy else "fail",
                "problems": problems,
            }
        )

    return {
        "schema_version": 1,
        "gate": "relay-kontrol",
        "status": "pass" if not violations else "fail",
        "toolchain": manifest["toolchain"],
        "summary": {
            "expected_checks": len(expected),
            "observed_checks": len(actual),
            "proofs_ok": proofs_ok,
            "proofs_expected": len(proof_ids),
            "reachability_ok": reachability_ok,
            "reachability_expected": len(reach_ids),
            "violations": len(violations),
        },
        "checks": rows,
        "violations": violations,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--junit-report", type=Path, required=True)
    parser.add_argument("--process-exitcode", type=int, required=True)
    parser.add_argument("--report-output", type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        manifest = load_manifest(args.manifest)
        root = ET.parse(args.junit_report).getroot()
        report = evaluate_junit(root, manifest, args.process_exitcode)
    except (OSError, ValueError, KeyError, json.JSONDecodeError, ET.ParseError) as error:
        print(f"[kontrol-fv] FAIL: could not evaluate evidence ({error})")
        return 1

    if args.report_output:
        args.report_output.parent.mkdir(parents=True, exist_ok=True)
        args.report_output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")

    for row in report["checks"]:
        marker = "OK" if row["outcome"] == "pass" else "FAIL"
        expected = "PROOF" if row["expectation"] == "proof" else "CEX"
        print(f"  {marker:4} {expected:5} {row['id']}")
    if report["violations"]:
        print("\n[kontrol-fv] FAIL:")
        for violation in report["violations"]:
            print("  -", violation)
        return 1
    summary = report["summary"]
    print(
        f"\n[kontrol-fv] PASS: {summary['proofs_ok']} proofs and "
        f"{summary['reachability_ok']} counterexample controls match the exact manifest."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
