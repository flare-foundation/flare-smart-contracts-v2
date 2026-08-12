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
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))
from report_provenance import (  # noqa: E402
    capture_git_state,
    clean_install_soldeer,
    finalize_soldeer,
    finalize_generation_provenance,
    report_commit,
)
AUDITED_CONFIG_FIELDS = (
    "files",
    "verify",
    "solc",
    "solc_via_ir",
    "solc_optimize",
    "solc_evm_version",
    "packages",
    "loop_iter",
    "optimistic_loop",
    "optimistic_hashing",
    "hashing_length_bound",
    "rule_sanity",
    "wait_for_results",
    "prover_args",
    "rule",
)
REQUIRED_CONFIG_FIELDS = {
    "files",
    "verify",
    "solc",
    "solc_via_ir",
    "solc_optimize",
    "solc_evm_version",
    "packages",
    "loop_iter",
    "optimistic_loop",
    "optimistic_hashing",
    "hashing_length_bound",
    "rule_sanity",
    "wait_for_results",
    "prover_args",
    "rule",
}
REQUIRED_CONFIG_VALUES = {
    "optimistic_hashing": True,
    "hashing_length_bound": "512",
}
NON_SEMANTIC_CONFIG_FIELDS = {"msg"}


def command(args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, cwd=REPO, capture_output=True, text=True, check=False)


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


def foundry_build(output: str) -> dict[str, str]:
    version = re.search(r"^forge Version:\s*(\S+)", output, re.MULTILINE)
    commit = re.search(r"^Commit SHA:\s*([0-9a-f]{40})", output, re.MULTILINE)
    return {
        "version": version.group(1) if version else "unavailable",
        "commit": commit.group(1) if commit else "unavailable",
    }


def foundry_problems(
    actual: dict[str, str], expected: dict[str, Any], exitcode: int
) -> list[str]:
    problems: list[str] = []
    if type(exitcode) is not int or exitcode != 0:
        problems.append(f"Foundry --version failed with exit code {exitcode!r}")
    for field in ("version", "commit"):
        if actual.get(field) != expected.get(field):
            problems.append(
                f"Foundry {field} is {actual.get(field)!r}; expected {expected.get(field)!r}"
            )
    return problems


def output_hash(result: subprocess.CompletedProcess[str]) -> dict[str, Any]:
    return {
        "exitcode": result.returncode,
        "stdout_sha256": hashlib.sha256(result.stdout.encode()).hexdigest(),
        "stderr_sha256": hashlib.sha256(result.stderr.encode()).hexdigest(),
    }


def _mask_comments(source: str) -> str:
    """Blank CVL comments while preserving newlines for declaration discovery."""
    result = list(source)
    index = 0
    state = "code"
    while index < len(source):
        current = source[index]
        following = source[index + 1] if index + 1 < len(source) else ""
        if state == "code":
            if current == "/" and following == "/":
                result[index] = result[index + 1] = " "
                index += 2
                state = "line-comment"
                continue
            if current == "/" and following == "*":
                result[index] = result[index + 1] = " "
                index += 2
                state = "block-comment"
                continue
        elif state == "line-comment":
            if current == "\n":
                state = "code"
            else:
                result[index] = " "
        else:
            if current == "*" and following == "/":
                result[index] = result[index + 1] = " "
                index += 2
                state = "code"
                continue
            if current != "\n":
                result[index] = " "
        index += 1
    if state == "block-comment":
        raise ValueError("unterminated CVL block comment")
    return "".join(result)


def spec_rules(source: str) -> list[str]:
    masked = _mask_comments(source)
    return re.findall(
        r"(?m)^\s*rule\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*\(",
        masked,
    )


def _exact_value(actual: Any, expected: Any) -> bool:
    """JSON equality that does not equate booleans with integers."""
    if type(actual) is not type(expected):
        return False
    if isinstance(expected, list):
        return len(actual) == len(expected) and all(
            _exact_value(left, right) for left, right in zip(actual, expected)
        )
    if isinstance(expected, dict):
        return actual.keys() == expected.keys() and all(
            _exact_value(actual[key], value) for key, value in expected.items()
        )
    return actual == expected


def audit_configs(settings: dict[str, Any], repo: Path = REPO) -> tuple[list[dict[str, Any]], list[str]]:
    """Bind every local Certora run to the manifest's exact config and CVL rule inventory."""
    violations: list[str] = []
    records: list[dict[str, Any]] = []
    configs = settings.get("configs")
    expectations = settings.get("config_expectations")
    config_glob = settings.get("config_glob")
    if (
        not isinstance(configs, list)
        or not configs
        or not all(isinstance(item, str) and item for item in configs)
        or len(configs) != len(set(configs))
    ):
        return records, ["certora_local.configs must be a nonempty list of unique paths"]
    if not isinstance(expectations, dict):
        return records, ["certora_local.config_expectations must be an object"]
    if not isinstance(config_glob, str) or not config_glob:
        return records, ["certora_local.config_glob must be a nonempty string"]

    declared = set(configs)
    expected = set(expectations)
    if declared != expected:
        missing = sorted(declared - expected)
        unexpected = sorted(expected - declared)
        if missing:
            violations.append("configs missing expectations: " + ", ".join(missing))
        if unexpected:
            violations.append("unexpected config expectations: " + ", ".join(unexpected))

    repo_resolved = repo.resolve()
    discovered: set[str] = set()
    for path in repo.glob(config_glob):
        if not path.is_file():
            continue
        try:
            discovered.add(path.resolve().relative_to(repo_resolved).as_posix())
        except ValueError:
            violations.append(f"config glob resolves outside the repository: {path}")
    if discovered != declared:
        missing = sorted(declared - discovered)
        unexpected = sorted(discovered - declared)
        if missing:
            violations.append("manifest configs missing from source: " + ", ".join(missing))
        if unexpected:
            violations.append("source configs missing from manifest: " + ", ".join(unexpected))

    for config_name in configs:
        config_violation_start = len(violations)
        expectation = expectations.get(config_name)
        if not isinstance(expectation, dict):
            expectation_type = "null" if expectation is None else type(expectation).__name__
            violations.append(
                f"{config_name}: config expectation must be an object, found {expectation_type}"
            )
            records.append(
                {
                    "config": config_name,
                    "config_sha256": None,
                    "spec": None,
                    "spec_sha256": None,
                    "rules": [],
                    "expectation_type": expectation_type,
                    "status": "fail",
                }
            )
            continue
        expectation_fields = set(expectation)
        if not REQUIRED_CONFIG_FIELDS <= expectation_fields or not expectation_fields <= set(
            AUDITED_CONFIG_FIELDS
        ):
            missing = sorted(REQUIRED_CONFIG_FIELDS - expectation_fields)
            unexpected = sorted(expectation_fields - set(AUDITED_CONFIG_FIELDS))
            details = []
            if missing:
                details.append("missing=" + ",".join(missing))
            if unexpected:
                details.append("unexpected=" + ",".join(unexpected))
            violations.append(f"{config_name}: invalid expectation fields ({'; '.join(details)})")
        for field, required_value in REQUIRED_CONFIG_VALUES.items():
            if not _exact_value(expectation.get(field), required_value):
                violations.append(
                    f"{config_name}: manifest expectation {field} must be exactly "
                    f"{required_value!r}, found {expectation.get(field)!r}"
                )

        config_path = repo / config_name
        try:
            config_path = config_path.resolve()
            config_path.relative_to(repo_resolved)
            config_bytes = config_path.read_bytes()
            config = json.loads(config_bytes)
        except (OSError, UnicodeError, ValueError, json.JSONDecodeError) as error:
            violations.append(f"{config_name}: could not read config ({error})")
            continue
        if not isinstance(config, dict):
            violations.append(f"{config_name}: config root must be an object")
            continue

        field_problems: list[str] = []
        actual_semantic_fields = set(config) - NON_SEMANTIC_CONFIG_FIELDS
        if actual_semantic_fields != expectation_fields:
            missing = sorted(expectation_fields - actual_semantic_fields)
            unexpected = sorted(actual_semantic_fields - expectation_fields)
            details = []
            if missing:
                details.append("missing=" + ",".join(missing))
            if unexpected:
                details.append("unexpected=" + ",".join(unexpected))
            field_problems.append("proof-semantic field inventory differs (" + "; ".join(details) + ")")
        for field in expectation:
            if not _exact_value(config.get(field), expectation[field]):
                field_problems.append(
                    f"{field} is {config.get(field)!r}; expected {expectation[field]!r}"
                )
        violations.extend(f"{config_name}: {problem}" for problem in field_problems)

        configured_rules = config.get("rule")
        if not isinstance(configured_rules, list) or not all(
            isinstance(rule, str) and re.fullmatch(r"[A-Za-z_$][A-Za-z0-9_$]*", rule)
            for rule in configured_rules
        ):
            violations.append(f"{config_name}: rule must be a list of CVL identifiers")
            configured_rules = []
        elif len(configured_rules) != len(set(configured_rules)):
            violations.append(f"{config_name}: duplicate configured rules")

        verify = config.get("verify")
        spec_path: Path | None = None
        spec_display: str | None = None
        discovered_rules: list[str] = []
        spec_sha256: str | None = None
        if not isinstance(verify, str) or verify.count(":") != 1:
            violations.append(f"{config_name}: verify must be Contract:path/to/spec")
        else:
            _, spec_name = verify.split(":", 1)
            try:
                spec_path = (repo / spec_name).resolve()
                spec_relative = spec_path.relative_to(repo_resolved)
                spec_display = spec_relative.as_posix()
                spec_bytes = spec_path.read_bytes()
                discovered_rules = spec_rules(spec_bytes.decode())
                spec_sha256 = hashlib.sha256(spec_bytes).hexdigest()
            except (OSError, UnicodeError, ValueError) as error:
                violations.append(f"{config_name}: could not audit {spec_name} ({error})")
            else:
                if len(discovered_rules) != len(set(discovered_rules)):
                    violations.append(f"{config_name}: duplicate CVL rule declarations in {spec_name}")
                if discovered_rules != configured_rules:
                    violations.append(
                        f"{config_name}: configured rules do not exactly match declarations in {spec_name}"
                    )

        records.append(
            {
                "config": config_name,
                "config_sha256": hashlib.sha256(config_bytes).hexdigest(),
                "spec": spec_display,
                "spec_sha256": spec_sha256,
                "rules": discovered_rules,
                "status": "pass" if len(violations) == config_violation_start else "fail",
            }
        )
    return records, violations


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--certora-run", default=os.environ.get("CERTORA_RUN", "certoraRun"))
    parser.add_argument("--solc", default=os.environ.get("SOLC", "solc0.8.35"))
    parser.add_argument("--forge", default=os.environ.get("FORGE", "forge"))
    parser.add_argument("--report-output", type=Path)
    args = parser.parse_args()
    generation_start = capture_git_state(REPO)

    manifest_bytes = args.manifest.read_bytes()
    manifest = json.loads(manifest_bytes)
    if type(manifest.get("schema_version")) is not int or manifest.get("schema_version") != 1:
        print("[certora-local] FAIL: unsupported verification manifest schema")
        return 1
    settings = manifest["certora_local"]
    violations: list[str] = []

    minimum_java = settings.get("minimum_java_major")
    if type(minimum_java) is not int or minimum_java <= 0:
        print("[certora-local] FAIL: certora_local.minimum_java_major must be an integer")
        return 1

    forge_result = command([args.forge, "--version"])
    actual_foundry = foundry_build(forge_result.stdout + forge_result.stderr)
    expected_foundry = manifest["toolchain"]["foundry"]
    forge_problems = foundry_problems(actual_foundry, expected_foundry, forge_result.returncode)
    violations.extend(forge_problems)
    if forge_problems:
        dependency_record = {
            "mode": "not-run-unpinned-foundry",
            "release_eligible": False,
            "problems": list(forge_problems),
        }
    else:
        dependency_record, dependency_problems = clean_install_soldeer(REPO, args.forge)
        violations.extend(dependency_problems)

    config_audit, config_violations = audit_configs(settings)
    violations.extend(config_violations)

    certora_result = command([args.certora_run, "--version"])
    actual_certora = certora_version(certora_result.stdout + certora_result.stderr)
    if certora_result.returncode or actual_certora != settings["certora_cli"]:
        violations.append(
            f"Certora CLI is {actual_certora!r}; expected {settings['certora_cli']!r}"
        )

    java_result = command(["java", "-version"])
    actual_java = java_major(java_result.stdout + java_result.stderr)
    if java_result.returncode or actual_java is None or actual_java < minimum_java:
        violations.append(
            f"Java major is {actual_java!r}; expected at least {minimum_java}"
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

    if dependency_record["mode"] == "clean-install-in-process":
        violations.extend(finalize_soldeer(REPO, dependency_record))
    generation = finalize_generation_provenance(REPO, generation_start)
    report = {
        "schema_version": 1,
        "gate": "relay-certora-local",
        "status": "pass" if not violations else "fail",
        "release_eligible": (
            not violations
            and generation["release_eligible"] is True
            and dependency_record["release_eligible"] is True
        ),
        "git_commit": report_commit(generation),
        "manifest_sha256": hashlib.sha256(manifest_bytes).hexdigest(),
        "generation_provenance": generation,
        "inputs": {
            "soldeer": dependency_record,
            "release_eligible": dependency_record["release_eligible"],
            "problems": dependency_record["problems"],
        },
        "toolchain": {
            "foundry": actual_foundry,
            "certora_cli": actual_certora,
            "java_major": actual_java,
            "solc": actual_solc,
        },
        "munge": output_hash(munge_result),
        "config_audit": config_audit,
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
