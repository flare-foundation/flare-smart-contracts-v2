#!/usr/bin/env python3
"""Fail-closed Halmos gate for the Relay formal-verification suite.

The raw Halmos exit code cannot be used directly because reachability controls
are expected to produce counterexamples. This gate instead checks every result
against the committed verification manifest. A healthy run has exactly the
declared checks, proofs exit with PASS, reachability controls exit with a real
validated COUNTEREXAMPLE, and no check reports a truncated loop.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any


PASS = 0
COUNTEREXAMPLE = 1
EXIT_NAMES = {
    0: "PASS",
    1: "COUNTEREXAMPLE",
    2: "TIMEOUT",
    3: "STUCK",
    4: "REVERT_ALL",
    5: "EXCEPTION",
}

FV_DIR = Path(__file__).resolve().parent
REPO_ROOT = FV_DIR.parents[1]
DEFAULT_MANIFEST = FV_DIR / "verification-manifest.json"


def canonical_check(suite: str, function_signature: str) -> str:
    """Return the stable manifest identifier for one Halmos result."""
    function_name = function_signature.split("(", 1)[0]
    return f"{suite.replace(os.sep, '/')}.{function_name}"


def load_manifest(path: Path) -> tuple[dict[str, Any], str]:
    raw = path.read_bytes()
    manifest = json.loads(raw)
    if manifest.get("schema_version") != 1:
        raise ValueError("verification manifest schema_version must be 1")

    halmos = manifest.get("halmos")
    if not isinstance(halmos, dict):
        raise ValueError("verification manifest is missing the halmos object")

    proofs = halmos.get("proofs")
    reachability = halmos.get("reachability")
    if not isinstance(proofs, list) or not proofs:
        raise ValueError("halmos.proofs must be a non-empty list")
    if not isinstance(reachability, list) or not reachability:
        raise ValueError("halmos.reachability must be a non-empty list")
    if not all(isinstance(item, str) and item for item in proofs + reachability):
        raise ValueError("every Halmos manifest check must be a non-empty string")

    declared = proofs + reachability
    duplicates = sorted({item for item in declared if declared.count(item) > 1})
    if duplicates:
        raise ValueError(f"duplicate Halmos manifest checks: {duplicates}")

    expected_count = halmos.get("expected_check_count")
    if expected_count != len(declared):
        raise ValueError(
            f"halmos.expected_check_count is {expected_count}, but {len(declared)} checks are declared"
        )

    return manifest, hashlib.sha256(raw).hexdigest()


def _valid_model_count(result: dict[str, Any]) -> tuple[int, list[str]]:
    problems: list[str] = []
    num_models = result.get("num_models")
    models = result.get("models")
    if not isinstance(num_models, int) or num_models < 0:
        problems.append("num_models is missing or invalid")
        num_models = 0
    if not isinstance(models, list):
        problems.append("models is missing or is not a list")
        models = []
    if len(models) != num_models:
        problems.append(f"num_models={num_models}, but models contains {len(models)} entries")

    valid = 0
    for index, model in enumerate(models):
        if not isinstance(model, dict) or not isinstance(model.get("is_valid"), bool):
            problems.append(f"models[{index}] has no boolean is_valid field")
        elif model["is_valid"]:
            valid += 1
    return valid, problems


def _check_execution_metadata(result: dict[str, Any], max_bounded_loops: int) -> list[str]:
    problems: list[str] = []
    paths = result.get("num_paths")
    if (
        not isinstance(paths, list)
        or len(paths) != 3
        or not all(isinstance(value, int) and value >= 0 for value in paths)
    ):
        problems.append("num_paths must be [total, success, blocked] with non-negative integers")
    elif paths[0] == 0:
        problems.append("Halmos explored zero paths")

    bounded = result.get("num_bounded_loops")
    if not isinstance(bounded, int) or bounded < 0:
        problems.append("num_bounded_loops is missing or invalid")
    elif bounded > max_bounded_loops:
        problems.append(
            f"reported {bounded} bounded loop(s), exceeding the allowed maximum {max_bounded_loops}"
        )
    return problems


def evaluate_results(
    data: dict[str, Any],
    manifest: dict[str, Any],
    *,
    process_exitcode: int | None = None,
) -> dict[str, Any]:
    """Evaluate parsed Halmos JSON and return a deterministic normalized report."""
    halmos_manifest = manifest["halmos"]
    proof_ids = set(halmos_manifest["proofs"])
    reach_ids = set(halmos_manifest["reachability"])
    expected_ids = proof_ids | reach_ids
    expected_process_exitcode = halmos_manifest["expected_process_exitcode"]
    max_bounded_loops = halmos_manifest.get("max_bounded_loops", 0)

    violations: list[str] = []
    top_exitcode = data.get("exitcode")
    if top_exitcode != expected_process_exitcode:
        violations.append(
            f"Halmos JSON exitcode is {top_exitcode!r}; expected {expected_process_exitcode}"
        )
    if process_exitcode is not None and process_exitcode != top_exitcode:
        violations.append(
            f"Halmos process exitcode {process_exitcode} disagrees with JSON exitcode {top_exitcode!r}"
        )

    test_results = data.get("test_results")
    if not isinstance(test_results, dict) or not test_results:
        violations.append("no FV test results were emitted")
        test_results = {}

    actual: dict[str, dict[str, Any]] = {}
    for suite, checks in sorted(test_results.items()):
        if not isinstance(suite, str) or not isinstance(checks, list):
            violations.append(f"malformed test_results entry for {suite!r}")
            continue
        for result in checks:
            if not isinstance(result, dict) or not isinstance(result.get("name"), str):
                violations.append(f"{suite}: malformed check result")
                continue
            check_id = canonical_check(suite, result["name"])
            if check_id in actual:
                violations.append(f"duplicate Halmos result: {check_id}")
                continue
            actual[check_id] = result

    missing = sorted(expected_ids - actual.keys())
    unexpected = sorted(actual.keys() - expected_ids)
    if missing:
        violations.append("missing expected checks: " + ", ".join(missing))
    if unexpected:
        violations.append("unexpected checks (update the manifest deliberately): " + ", ".join(unexpected))

    rows: list[dict[str, Any]] = []
    proofs_ok = 0
    reachability_ok = 0
    for check_id in sorted(expected_ids & actual.keys()):
        result = actual[check_id]
        expectation = "proof" if check_id in proof_ids else "reachability"
        expected_exitcode = PASS if expectation == "proof" else COUNTEREXAMPLE
        exitcode = result.get("exitcode")
        check_problems = _check_execution_metadata(result, max_bounded_loops)
        valid_models, model_problems = _valid_model_count(result)
        check_problems.extend(model_problems)

        if exitcode != expected_exitcode:
            check_problems.append(
                f"exitcode {exitcode!r} ({EXIT_NAMES.get(exitcode, 'UNKNOWN')}) != "
                f"expected {expected_exitcode} ({EXIT_NAMES[expected_exitcode]})"
            )
        if expectation == "proof":
            if result.get("num_models") != 0:
                check_problems.append("a passing proof must not contain counterexample models")
        elif valid_models == 0:
            check_problems.append("reachability requires at least one validated counterexample model")

        healthy = not check_problems
        if healthy and expectation == "proof":
            proofs_ok += 1
        if healthy and expectation == "reachability":
            reachability_ok += 1
        for problem in check_problems:
            violations.append(f"{check_id}: {problem}")

        rows.append(
            {
                "id": check_id,
                "expectation": expectation,
                "outcome": "pass" if healthy else "fail",
                "exitcode": exitcode,
                "exit_name": EXIT_NAMES.get(exitcode, "UNKNOWN"),
                "num_models": result.get("num_models"),
                "valid_models": valid_models,
                "num_paths": result.get("num_paths"),
                "num_bounded_loops": result.get("num_bounded_loops"),
                "problems": check_problems,
            }
        )

    return {
        "schema_version": 1,
        "gate": "relay-halmos",
        "status": "pass" if not violations else "fail",
        "summary": {
            "expected_checks": len(expected_ids),
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


def _command_output(command: list[str]) -> str:
    try:
        completed = subprocess.run(command, capture_output=True, text=True, check=False)
    except OSError as error:
        return f"unavailable: {error}"
    return (completed.stdout or completed.stderr).strip()


def _toolchain_problems(halmos_binary: str, manifest: dict[str, Any]) -> tuple[dict[str, str], list[str]]:
    expected = manifest["toolchain"]
    halmos_version = _command_output([halmos_binary, "--version"])
    try:
        z3_version = importlib.metadata.version("z3-solver")
    except importlib.metadata.PackageNotFoundError:
        z3_version = "unavailable"

    problems: list[str] = []
    if halmos_version != f"halmos {expected['halmos']}":
        problems.append(
            f"Halmos version is {halmos_version!r}; expected 'halmos {expected['halmos']}'"
        )
    if z3_version != expected["z3"]:
        problems.append(f"z3-solver version is {z3_version!r}; expected {expected['z3']!r}")
    return {"halmos": halmos_version, "z3_solver": z3_version}, problems


def _git_commit() -> str:
    completed = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=REPO_ROOT, capture_output=True, text=True, check=False
    )
    return completed.stdout.strip() if completed.returncode == 0 else "unknown"


def _write_report(path: Path, report: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")


def _parse_args() -> tuple[argparse.Namespace, list[str]]:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--report-output", type=Path)
    parser.add_argument(
        "--results-input",
        type=Path,
        help="validate an existing Halmos JSON file instead of running Halmos",
    )
    return parser.parse_known_args()


def main() -> int:
    args, halmos_args = _parse_args()
    try:
        manifest, manifest_hash = load_manifest(args.manifest)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"[fv] FAIL: could not load verification manifest ({error}).")
        return 1

    halmos_binary = os.environ.get("HALMOS", "halmos")
    toolchain, toolchain_problems = _toolchain_problems(halmos_binary, manifest)
    process_exitcode: int | None = None
    temporary_output: Path | None = None

    try:
        if args.results_input:
            output_path = args.results_input
            print(f"[fv] validating existing results: {output_path}")
        else:
            with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as output:
                temporary_output = Path(output.name)
            output_path = temporary_output
            prefix = manifest["halmos"].get("function_prefix", "check_")
            command = [
                halmos_binary,
                "--function",
                prefix,
                "--json-output",
                str(output_path),
                *halmos_args,
            ]
            print("[fv] running:", " ".join(command), flush=True)
            try:
                completed = subprocess.run(command, check=False)
            except OSError as error:
                print(f"[fv] FAIL: could not execute Halmos ({error}).")
                return 1
            process_exitcode = completed.returncode

        try:
            data = json.loads(output_path.read_text())
        except (OSError, json.JSONDecodeError) as error:
            print(f"[fv] FAIL: could not read Halmos JSON output ({error}).")
            return 1

        report = evaluate_results(data, manifest, process_exitcode=process_exitcode)
        report["manifest_sha256"] = manifest_hash
        report["git_commit"] = _git_commit()
        report["toolchain"] = toolchain
        if toolchain_problems:
            report["violations"] = toolchain_problems + report["violations"]
            report["summary"]["violations"] = len(report["violations"])
            report["status"] = "fail"

        for row in report["checks"]:
            expected = "PASS" if row["expectation"] == "proof" else "VALID CEX"
            marker = "OK" if row["outcome"] == "pass" else "FAIL"
            print(f"  {marker:4} {expected:9} {row['id']}")

        summary = report["summary"]
        print(
            f"\n[fv] {summary['observed_checks']}/{summary['expected_checks']} checks observed: "
            f"{summary['proofs_ok']}/{summary['proofs_expected']} proofs hold, "
            f"{summary['reachability_ok']}/{summary['reachability_expected']} reachability controls "
            f"have validated counterexamples. {summary['violations']} violation(s)."
        )
        if args.report_output:
            _write_report(args.report_output, report)
            print(f"[fv] report: {args.report_output}")

        if report["violations"]:
            print("\n[fv] FAIL:")
            for violation in report["violations"]:
                print("   -", violation)
            return 1

        print("[fv] OK - exact proof inventory holds and every reachability control has a valid witness.")
        return 0
    finally:
        if temporary_output:
            temporary_output.unlink(missing_ok=True)


if __name__ == "__main__":
    sys.exit(main())
