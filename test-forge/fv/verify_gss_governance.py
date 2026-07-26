#!/usr/bin/env python3
"""Fail-closed runner for the Relay GSS governance test and invariant inventory."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any


HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
DEFAULT_MANIFEST = HERE / "verification-manifest.json"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def command(args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, cwd=REPO, capture_output=True, text=True, check=False)


def forge_version() -> str:
    result = command(["forge", "--version"])
    match = re.search(r"^forge Version:\s*(\S+)", result.stdout, re.MULTILINE)
    return match.group(1) if result.returncode == 0 and match else "unavailable"


def git_commit() -> str:
    result = command(["git", "rev-parse", "HEAD"])
    return result.stdout.strip() if result.returncode == 0 else "unknown"


def normalized_test_name(signature: str) -> str:
    return signature.split("(", 1)[0]


def load_json_output(args: list[str]) -> dict[str, Any]:
    result = command(args)
    if result.returncode:
        raise RuntimeError(
            f"{' '.join(args)} exited {result.returncode}: "
            f"{(result.stderr or result.stdout).strip()}"
        )
    try:
        value = json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise RuntimeError(f"{' '.join(args)} did not emit valid JSON: {error}") from error
    if not isinstance(value, dict):
        raise RuntimeError(f"{' '.join(args)} emitted a non-object JSON result")
    return value


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--report-output", type=Path)
    args = parser.parse_args()

    violations: list[str] = []
    rows: list[dict[str, Any]] = []
    source_hashes: dict[str, str] = {}
    manifest_bytes = args.manifest.read_bytes()
    manifest = json.loads(manifest_bytes)
    settings = manifest["gss_governance_tests"]

    actual_forge = forge_version()
    if actual_forge != settings["foundry"]:
        violations.append(f"Foundry version is {actual_forge!r}; expected {settings['foundry']!r}")

    safe_package_path = REPO / "node_modules" / "@gnosis.pm" / "safe-contracts" / "package.json"
    try:
        safe_package = json.loads(safe_package_path.read_text())
        safe_version = safe_package.get("version")
    except (OSError, json.JSONDecodeError) as error:
        safe_version = "unavailable"
        violations.append(f"could not read the pinned Safe package: {error}")
    if safe_version != settings["safe_contracts"]:
        violations.append(f"Safe contracts version is {safe_version!r}; expected {settings['safe_contracts']!r}")

    expected_suites = settings["suites"]
    for suite in expected_suites:
        path = suite["path"]
        contract = suite["contract"]
        suite_id = f"{path}:{contract}"
        source_hashes[path] = sha256(REPO / path)
        try:
            output = load_json_output(["forge", "test", "--json", "--match-path", path])
        except RuntimeError as error:
            violations.append(str(error))
            continue

        if set(output) != {suite_id}:
            violations.append(
                f"{path}: observed suites {sorted(output)}, expected only {suite_id}"
            )
            continue
        test_results = output[suite_id].get("test_results")
        if not isinstance(test_results, dict):
            violations.append(f"{suite_id}: missing test_results object")
            continue

        by_name = {normalized_test_name(signature): result for signature, result in test_results.items()}
        expected_tests = set(suite["tests"])
        actual_tests = set(by_name)
        if actual_tests != expected_tests:
            missing = sorted(expected_tests - actual_tests)
            unexpected = sorted(actual_tests - expected_tests)
            if missing:
                violations.append(f"{suite_id}: missing tests: {', '.join(missing)}")
            if unexpected:
                violations.append(f"{suite_id}: unexpected tests: {', '.join(unexpected)}")

        for test_name in sorted(expected_tests & actual_tests):
            result = by_name[test_name]
            problems: list[str] = []
            if result.get("status") != "Success":
                problems.append(f"status is {result.get('status')!r}: {result.get('reason')!r}")
            kind = result.get("kind")
            if not isinstance(kind, dict) or len(kind) != 1:
                problems.append("missing or ambiguous test kind")
                kind_name = "unknown"
                details: dict[str, Any] = {}
            else:
                kind_name, details = next(iter(kind.items()))
                if not isinstance(details, dict):
                    details = {}

            if test_name.startswith("testFuzz_"):
                if kind_name != "Fuzz":
                    problems.append(f"expected Fuzz result, got {kind_name}")
                elif details.get("runs", 0) < settings["minimum_fuzz_runs"]:
                    problems.append(
                        f"only {details.get('runs')} fuzz runs; expected at least {settings['minimum_fuzz_runs']}"
                    )

            if test_name.startswith("invariant_"):
                if kind_name != "Invariant":
                    problems.append(f"expected Invariant result, got {kind_name}")
                else:
                    runs = details.get("runs")
                    calls = details.get("calls")
                    reverts = details.get("reverts")
                    expected_calls = settings["invariant_runs"] * settings["invariant_depth"]
                    if runs != settings["invariant_runs"]:
                        problems.append(f"invariant runs are {runs}; expected {settings['invariant_runs']}")
                    if calls != expected_calls:
                        problems.append(f"invariant calls are {calls}; expected {expected_calls}")
                    if reverts != 0:
                        problems.append(f"invariant handler reported {reverts} revert(s)")
                    metrics = details.get("metrics", {})
                    called = {
                        key.rsplit(".", 1)[-1]
                        for key, metric in metrics.items()
                        if isinstance(metric, dict) and metric.get("calls", 0) > 0
                    }
                    missing_handlers = set(settings["invariant_handler_functions"]) - called
                    if missing_handlers:
                        problems.append(
                            "invariant did not exercise handlers: " + ", ".join(sorted(missing_handlers))
                        )

            for problem in problems:
                violations.append(f"{suite_id}.{test_name}: {problem}")
            rows.append(
                {
                    "id": f"{suite_id}.{test_name}",
                    "kind": kind_name,
                    "outcome": "pass" if not problems else "fail",
                    "gas": details.get("gas"),
                    "runs": details.get("runs"),
                    "calls": details.get("calls"),
                    "reverts": details.get("reverts"),
                    "problems": problems,
                }
            )

    report = {
        "schema_version": 1,
        "gate": "relay-gss-governance",
        "status": "pass" if not violations else "fail",
        "git_commit": git_commit(),
        "manifest_sha256": hashlib.sha256(manifest_bytes).hexdigest(),
        "toolchain": {
            "foundry": actual_forge,
            "safe_contracts": safe_version,
        },
        "source_sha256": source_hashes,
        "summary": {
            "expected_tests": sum(len(suite["tests"]) for suite in expected_suites),
            "observed_tests": len(rows),
            "passing_tests": sum(row["outcome"] == "pass" for row in rows),
            "violations": len(violations),
        },
        "tests": rows,
        "violations": violations,
    }
    if args.report_output:
        output_path = args.report_output if args.report_output.is_absolute() else REPO / args.report_output
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
        print(f"[gss-governance] report: {output_path}")

    summary = report["summary"]
    print(
        f"[gss-governance] {summary['passing_tests']}/{summary['expected_tests']} tests pass; "
        f"{summary['violations']} violation(s)."
    )
    if violations:
        for violation in violations:
            print(f"  - {violation}")
        return 1
    print("[gss-governance] OK - exact real-Safe, rehearsal, fuzz, and invariant inventory holds.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
