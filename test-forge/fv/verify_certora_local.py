#!/usr/bin/env python3
"""Fail-closed local compilation and CVL type-check gate for Relay Certora specs."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any


HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
DEFAULT_MANIFEST = HERE / "verification-manifest.json"


def command(args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, cwd=REPO, capture_output=True, text=True, check=False)


def git_commit() -> str:
    result = command(["git", "rev-parse", "HEAD"])
    return result.stdout.strip() if result.returncode == 0 else "unknown"


def certora_version(output: str) -> str:
    match = re.search(r"\bcertora-cli\s+(\S+)", output)
    return match.group(1) if match else "unavailable"


def java_major(output: str) -> int | None:
    match = re.search(r'(?:version\s+")?(\d+)(?:[._][^"\s]+)?', output)
    return int(match.group(1)) if match else None


def solc_long_version(output: str) -> str:
    match = re.search(r"^Version:\s*(\S+)", output, re.MULTILINE)
    if not match:
        return "unavailable"
    return match.group(1).removesuffix(".Darwin.appleclang").removesuffix(".Linux.g++")


def output_hash(result: subprocess.CompletedProcess[str]) -> dict[str, Any]:
    return {
        "exitcode": result.returncode,
        "stdout_sha256": hashlib.sha256(result.stdout.encode()).hexdigest(),
        "stderr_sha256": hashlib.sha256(result.stderr.encode()).hexdigest(),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--certora-run", default=os.environ.get("CERTORA_RUN", "certoraRun"))
    parser.add_argument("--solc", default=os.environ.get("SOLC", "solc0.8.27"))
    parser.add_argument("--report-output", type=Path)
    args = parser.parse_args()

    manifest_bytes = args.manifest.read_bytes()
    manifest = json.loads(manifest_bytes)
    settings = manifest["certora_local"]
    violations: list[str] = []

    certora_result = command([args.certora_run, "--version"])
    actual_certora = certora_version(certora_result.stdout + certora_result.stderr)
    if certora_result.returncode or actual_certora != settings["certora_cli"]:
        violations.append(
            f"Certora CLI is {actual_certora!r}; expected {settings['certora_cli']!r}"
        )

    java_result = command(["java", "-version"])
    actual_java = java_major(java_result.stdout + java_result.stderr)
    if java_result.returncode or actual_java is None or actual_java < settings["minimum_java_major"]:
        violations.append(
            f"Java major is {actual_java!r}; expected at least {settings['minimum_java_major']}"
        )

    solc_result = command([args.solc, "--version"])
    actual_solc = solc_long_version(solc_result.stdout + solc_result.stderr)
    if solc_result.returncode or actual_solc != settings["solc_long_version"]:
        violations.append(
            f"solc is {actual_solc!r}; expected {settings['solc_long_version']!r}"
        )

    munge_result = command(["bash", "certora/munge.sh"])
    if munge_result.returncode:
        violations.append("certora/munge.sh failed its exact two-keyword faithfulness audit")

    config_results: list[dict[str, Any]] = []
    if not violations:
        for config in settings["configs"]:
            result = command(
                [
                    args.certora_run,
                    config,
                    "--compilation_steps_only",
                    "--solc",
                    args.solc,
                ]
            )
            record = {"config": config, **output_hash(result)}
            config_results.append(record)
            if result.returncode:
                violations.append(f"{config}: local Certora compilation/type-check failed")

    report = {
        "schema_version": 1,
        "gate": "relay-certora-local",
        "status": "pass" if not violations else "fail",
        "git_commit": git_commit(),
        "manifest_sha256": hashlib.sha256(manifest_bytes).hexdigest(),
        "toolchain": {
            "certora_cli": actual_certora,
            "java_major": actual_java,
            "solc": actual_solc,
        },
        "munge": output_hash(munge_result),
        "configs": config_results,
        "summary": {
            "configs_expected": len(settings["configs"]),
            "configs_checked": len(config_results),
            "violations": len(violations),
        },
        "violations": violations,
    }
    if args.report_output:
        output = args.report_output if args.report_output.is_absolute() else REPO / args.report_output
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
        print(f"[certora-local] report: {output}")

    summary = report["summary"]
    print(
        f"[certora-local] {summary['configs_checked']}/{summary['configs_expected']} configs "
        f"compiled and type-checked; {summary['violations']} violation(s)."
    )
    for violation in violations:
        print(f"  - {violation}")
    if violations:
        return 1
    print("[certora-local] OK - local preparation passes; this is not a cloud proof verdict.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
