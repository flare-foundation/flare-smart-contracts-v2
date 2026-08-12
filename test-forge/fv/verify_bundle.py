#!/usr/bin/env python3
"""Create a tamper-evident manifest for one Relay FV run.

The individual gates prove different properties. This command does not reinterpret
their results; it refuses to bundle missing/failed reports and records the exact
inputs and evidence files used for the hand-off.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any


HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
DEFAULT_MANIFEST = HERE / "verification-manifest.json"
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))
from report_provenance import (  # noqa: E402
    DIAGNOSTIC_MODE,
    GENERATED_MODE,
    IMPORTED_MODE,
    build_generation_provenance,
    capture_git_state,
    finalize_generation_provenance,
    report_commit,
)
EXPECTED_REPORTS = (
    ("verification-reports/relay-deployment.json", "relay-deployment-artifact"),
    ("verification-reports/relay-custom-error-abi.json", "relay-custom-error-abi"),
    ("verification-reports/relay-artifact-parity.json", "relay-artifact-parity"),
    ("verification-reports/relay-halmos.json", "relay-halmos"),
    ("verification-reports/relay-lean.json", "relay-lean"),
    ("verification-reports/relay-certora-local.json", "relay-certora-local"),
)
DEFAULT_REPORTS = tuple(path for path, _ in EXPECTED_REPORTS)
EXPECTED_GATES = tuple(gate for _, gate in EXPECTED_REPORTS)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _validate_git_state(state: Any, label: str) -> None:
    if not isinstance(state, dict):
        raise ValueError(f"{label} is not an object")
    if type(state.get("available")) is not bool or type(state.get("clean")) is not bool:
        raise ValueError(f"{label} has invalid availability/cleanliness flags")
    head = state.get("head")
    if not isinstance(head, str):
        raise ValueError(f"{label} has no HEAD string")
    if state["available"] and re.fullmatch(r"[0-9a-f]{40}", head) is None:
        raise ValueError(f"{label} has no canonical Git HEAD")
    if not state["available"] and state["clean"]:
        raise ValueError(f"{label} cannot be clean when Git state is unavailable")
    status_hash = state.get("status_sha256")
    if status_hash is not None and (
        not isinstance(status_hash, str) or re.fullmatch(r"[0-9a-f]{64}", status_hash) is None
    ):
        raise ValueError(f"{label} has no canonical status SHA-256")
    entries = state.get("status_entries")
    if entries is not None and (type(entries) is not int or entries < 0):
        raise ValueError(f"{label} has an invalid status entry count")
    empty_status_hash = hashlib.sha256(b"").hexdigest()
    if state["clean"] and (entries != 0 or status_hash != empty_status_hash):
        raise ValueError(f"{label} clean state has nonempty status evidence")
    if state["available"] and not state["clean"] and (
        type(entries) is not int or entries == 0 or status_hash == empty_status_hash
    ):
        raise ValueError(f"{label} dirty state has empty status evidence")


def validate_report_provenance(report: dict[str, Any], gate: str) -> bool:
    provenance = report.get("generation_provenance")
    if not isinstance(provenance, dict) or type(provenance.get("schema_version")) is not int or provenance.get("schema_version") != 1:
        raise ValueError(f"{gate}: missing generation provenance")
    mode = provenance.get("mode")
    if mode not in {GENERATED_MODE, IMPORTED_MODE, DIAGNOSTIC_MODE}:
        raise ValueError(f"{gate}: unsupported generation mode {mode!r}")
    start = provenance.get("start")
    end = provenance.get("end")
    _validate_git_state(start, f"{gate} provenance start")
    _validate_git_state(end, f"{gate} provenance end")
    expected = build_generation_provenance(start, end, mode=mode)
    if provenance.get("release_eligible") is not expected["release_eligible"]:
        raise ValueError(f"{gate}: generation eligibility does not match recorded Git states")
    if provenance.get("development_reasons") != expected["development_reasons"]:
        raise ValueError(f"{gate}: generation development reasons are inconsistent")
    inputs = report.get("inputs")
    input_eligible = True
    if inputs is not None:
        if not isinstance(inputs, dict) or type(inputs.get("release_eligible")) is not bool:
            raise ValueError(f"{gate}: malformed input provenance")
        if not isinstance(inputs.get("problems"), list) or not all(
            isinstance(problem, str) and problem for problem in inputs["problems"]
        ):
            raise ValueError(f"{gate}: malformed input-provenance problems")
        input_eligible = inputs["release_eligible"]
        if input_eligible and inputs["problems"]:
            raise ValueError(f"{gate}: eligible input provenance contains problems")
    expected_report_eligible = expected["release_eligible"] and input_eligible
    report_eligible = report.get("release_eligible")
    if type(report_eligible) is not bool or report_eligible is not expected_report_eligible:
        raise ValueError(f"{gate}: report eligibility is inconsistent with generation/input provenance")
    if report.get("git_commit") != report_commit(provenance):
        raise ValueError(f"{gate}: report commit is inconsistent with generation provenance")
    return report_eligible


def _validate_release_halmos_inputs(report: dict[str, Any], command: list[str]) -> None:
    inputs = report.get("inputs")
    if not isinstance(inputs, dict) or inputs.get("release_eligible") is not True:
        raise ValueError("Halmos release evidence has no eligible input provenance")
    config = inputs.get("halmos_config")
    if not isinstance(config, dict) or not isinstance(config.get("effective"), dict):
        raise ValueError("Halmos release evidence has no audited effective config")
    effective = config["effective"]
    expected = [
        "--root",
        None,
        "--config",
        None,
        "--function",
        "check_",
        "--forge-build-out",
        effective.get("forge_build_out"),
        "--loop",
        str(effective.get("loop")),
        "--solver",
        effective.get("solver"),
        "--solver-timeout-assertion",
        str(effective.get("solver_timeout_assertion")),
        "--json-output",
        None,
    ]
    if len(command) != 1 + len(expected):
        raise ValueError("Halmos release command contains overrides or unexpected arguments")
    for index, wanted in enumerate(expected, start=1):
        if wanted is not None and command[index] != wanted:
            raise ValueError("Halmos release command differs from the audited exact configuration")
    if not all(command[index] for index in (0, 2, 4, 16)):
        raise ValueError("Halmos release command has an empty binary/root/config/output path")
    if inputs.get("artifacts_before_halmos") != inputs.get("artifacts_after_halmos"):
        raise ValueError("Halmos artifact provenance is not stable across symbolic execution")
    artifacts = inputs.get("artifacts_before_halmos")
    expected_artifacts = {
        "contracts/protocol/implementation/Relay.sol:Relay",
        "contracts/protocol/implementation/RelayProxy.sol:RelayProxy",
    }
    checks = report.get("checks")
    if not isinstance(checks, list):
        raise ValueError("Halmos release evidence has no normalized check inventory")
    for row in checks:
        check_id = row.get("id") if isinstance(row, dict) else None
        match = re.fullmatch(
            r"([^:]+):([A-Za-z_$][A-Za-z0-9_$]*)\.check_[A-Za-z0-9_]+",
            check_id or "",
        )
        if match is None:
            raise ValueError("Halmos normalized check inventory contains a malformed identifier")
        expected_artifacts.add(f"{match.group(1)}:{match.group(2)}")
    if not isinstance(artifacts, dict) or set(artifacts) != expected_artifacts:
        raise ValueError("Halmos release evidence lacks the exact production/harness artifact bindings")
    for name, artifact in artifacts.items():
        if not isinstance(artifact, dict) or artifact.get("available") is not True:
            raise ValueError(f"Halmos {name} artifact binding is unavailable")
        for field in (
            "artifact_sha256",
            "creation_semantic_sha256",
            "runtime_semantic_sha256",
        ):
            value = artifact.get(field)
            if not isinstance(value, str) or re.fullmatch(r"[0-9a-f]{64}", value) is None:
                raise ValueError(f"Halmos {name} artifact has no canonical {field}")
    soldeer = inputs.get("soldeer")
    _validate_soldeer(soldeer, "Halmos")


def _validate_dependency_tree(tree: Any, label: str) -> None:
    if not isinstance(tree, dict) or tree.get("available") is not True:
        raise ValueError(f"{label}: dependency tree is unavailable")
    digest_value = tree.get("tree_sha256")
    if not isinstance(digest_value, str) or re.fullmatch(r"[0-9a-f]{64}", digest_value) is None:
        raise ValueError(f"{label}: dependency tree has no canonical digest")
    for field in ("files", "directories", "symlinks"):
        if type(tree.get(field)) is not int or tree[field] < 0:
            raise ValueError(f"{label}: dependency tree has an invalid {field} count")


def _validate_soldeer(record: Any, label: str) -> None:
    if not isinstance(record, dict) or record.get("release_eligible") is not True:
        raise ValueError(f"{label}: no clean Soldeer provenance")
    command = record.get("command")
    if (
        record.get("mode") != "clean-install-in-process"
        or not isinstance(command, list)
        or len(command) != 4
        or not isinstance(command[0], str)
        or not command[0]
        or command[1:] != ["soldeer", "install", "--clean"]
    ):
        raise ValueError(f"{label}: Soldeer was not installed in clean mode")
    if type(record.get("exitcode")) is not int or record["exitcode"] != 0:
        raise ValueError(f"{label}: clean Soldeer install did not succeed")
    before = record.get("lock_sha256_before")
    after = record.get("lock_sha256_after")
    if not isinstance(before, str) or re.fullmatch(r"[0-9a-f]{64}", before) is None or before != after:
        raise ValueError(f"{label}: soldeer.lock was not stable")
    start_tree = record.get("tree_after_install")
    end_tree = record.get("tree_at_end")
    _validate_dependency_tree(start_tree, label)
    _validate_dependency_tree(end_tree, label)
    if record.get("stable_during_gate") is not True or start_tree != end_tree:
        raise ValueError(f"{label}: installed dependency tree changed during the gate")
    if record.get("problems") != []:
        raise ValueError(f"{label}: eligible Soldeer provenance contains problems")


def _validate_lean_inputs(report: dict[str, Any]) -> None:
    inputs = report.get("inputs")
    external = inputs.get("evmyullean") if isinstance(inputs, dict) else None
    if not isinstance(external, dict) or external.get("release_eligible") is not True:
        raise ValueError("Lean release evidence has no eligible external-checkout provenance")
    if external.get("problems") != []:
        raise ValueError("Lean eligible external provenance contains problems")
    for phase in ("source_start", "source_after_build"):
        state = external.get(phase)
        _validate_git_state(state, f"Lean {phase}")
        if state.get("clean") is not True or state.get("head") != external.get("evmyullean_commit"):
            raise ValueError(f"Lean {phase} does not bind the pinned clean EVMYulLean checkout")
    packages = external.get("packages")
    if not isinstance(packages, list) or not packages:
        raise ValueError("Lean release evidence has no Lake package inventory")
    for package in packages:
        if not isinstance(package, dict) or package.get("release_eligible") is not True:
            raise ValueError("Lean release evidence has an ineligible Lake package")
        state = package.get("git")
        _validate_git_state(state, f"Lean package {package.get('name')}")
        if state.get("clean") is not True or state.get("head") != package.get("expected_revision"):
            raise ValueError("Lean Lake package does not match its manifest revision")
        if package.get("problems") != []:
            raise ValueError("Lean eligible Lake package contains problems")
    if external.get("packages_after_build") != packages:
        raise ValueError("Lean Lake package provenance changed during preparation")
    build = external.get("build")
    if not isinstance(build, dict) or build.get("mode") != "cache-refresh-clean-build-in-process":
        raise ValueError("Lean release evidence has no in-process clean build")
    commands = build.get("commands")
    expected = [
        ["lake", "exe", "cache", "get"],
        ["lake", "clean"],
        ["lake", "build", "EvmYul"],
    ]
    if not isinstance(commands, list) or len(commands) != len(expected):
        raise ValueError("Lean release evidence has incomplete build preparation")
    for record, command in zip(commands, expected):
        if (
            not isinstance(record, dict)
            or record.get("command") != command
            or type(record.get("exitcode")) is not int
            or record["exitcode"] != 0
        ):
            raise ValueError("Lean release evidence has a failed or alternate build command")
    _validate_dependency_tree(build.get("output_tree"), "Lean build output")


def _validate_node_inputs(report: dict[str, Any]) -> None:
    inputs = report.get("inputs")
    node = inputs.get("node") if isinstance(inputs, dict) else None
    if not isinstance(node, dict) or node.get("release_eligible") is not True:
        raise ValueError("deployment evidence has no eligible Node input provenance")
    package_manager = json.loads((REPO / "package.json").read_text())["packageManager"]
    expected_version = package_manager.split("@", 1)[1].split("+", 1)[0]
    if (
        node.get("mode") != "clean-install-and-compile-in-process"
        or node.get("pnpm_version") != expected_version
        or node.get("problems") != []
    ):
        raise ValueError("deployment evidence used an unpinned pnpm environment")
    commands = node.get("commands")
    if not isinstance(commands, list) or len(commands) != 3:
        raise ValueError("deployment evidence has incomplete Node preparation")
    expected_args = [
        ["install", "--frozen-lockfile", "--force"],
        ["hardhat", "clean"],
        ["compile"],
    ]
    binary: str | None = None
    for record, args in zip(commands, expected_args):
        command = record.get("command") if isinstance(record, dict) else None
        if (
            not isinstance(command, list)
            or len(command) != 1 + len(args)
            or not isinstance(command[0], str)
            or not command[0]
            or command[1:] != args
            or type(record.get("exitcode")) is not int
            or record["exitcode"] != 0
        ):
            raise ValueError("deployment evidence did not clean-install and compile in-process")
        if binary is None:
            binary = command[0]
        elif command[0] != binary:
            raise ValueError("deployment evidence changed pnpm executable during preparation")


def _validate_custom_error_sources(report: dict[str, Any]) -> None:
    manifest = json.loads(DEFAULT_MANIFEST.read_text())
    config = manifest["relay_custom_error_abi"]
    expected = [config["source"], config["interface_source"]]
    sources = report.get("sources")
    if not isinstance(sources, list) or len(sources) != len(expected):
        raise ValueError("custom-error evidence has no exact production source inventory")
    for record, path in zip(sources, expected):
        digest_value = record.get("sha256") if isinstance(record, dict) else None
        if (
            not isinstance(record, dict)
            or record.get("path") != path
            or not isinstance(digest_value, str)
            or re.fullmatch(r"[0-9a-f]{64}", digest_value) is None
        ):
            raise ValueError("custom-error evidence is not bound to the manifest production paths")


def _validate_gate_inputs(report: dict[str, Any], gate: str) -> None:
    if report.get("release_eligible") is not True:
        return
    if gate == "relay-deployment-artifact":
        _validate_node_inputs(report)
    elif gate == "relay-custom-error-abi":
        _validate_custom_error_sources(report)
    elif gate in {"relay-artifact-parity", "relay-certora-local"}:
        inputs = report.get("inputs")
        if not isinstance(inputs, dict):
            raise ValueError(f"{gate}: missing input provenance")
        _validate_soldeer(inputs.get("soldeer"), gate)
    elif gate == "relay-lean":
        _validate_lean_inputs(report)


def collect_evidence(
    reports: list[Path],
    manifest_sha256: str,
    repository_commit: str,
    *,
    allow_development: bool = False,
) -> list[dict[str, Any]]:
    evidence: list[dict[str, Any]] = []
    by_gate: dict[str, dict[str, Any]] = {}
    for report in reports:
        path = report if report.is_absolute() else REPO / report
        data = json.loads(path.read_text())
        gate = data.get("gate")
        if type(data.get("schema_version")) is not int or data.get("schema_version") != 1:
            raise ValueError(f"unsupported evidence schema: {path}")
        if data.get("status") != "pass":
            raise ValueError(f"evidence report is not passing: {path}")
        if gate not in EXPECTED_GATES:
            raise ValueError(f"unexpected evidence gate {gate!r}: {path}")
        if gate in by_gate:
            raise ValueError(f"duplicate evidence gate {gate!r}: {path}")
        if data.get("manifest_sha256") != manifest_sha256:
            raise ValueError(f"evidence report was produced from a different manifest: {path}")
        if data.get("git_commit") != repository_commit:
            raise ValueError(f"evidence report was produced from a different Git commit: {path}")
        release_eligible = validate_report_provenance(data, gate)
        _validate_gate_inputs(data, gate)
        if not release_eligible and not allow_development:
            raise ValueError(f"{gate}: evidence report is development-only")
        by_gate[gate] = data
        try:
            display_path = str(path.resolve().relative_to(REPO.resolve()))
        except ValueError:
            display_path = str(path.resolve())
        evidence.append(
            {
                "path": display_path,
                "gate": gate,
                "sha256": digest(path),
                "release_eligible": release_eligible,
                "generation_mode": data["generation_provenance"]["mode"],
            }
        )

    missing = sorted(set(EXPECTED_GATES) - set(by_gate))
    if missing:
        raise ValueError("missing required evidence gates: " + ", ".join(missing))
    deployment = by_gate["relay-deployment-artifact"]
    if by_gate["relay-artifact-parity"].get("deployment") != deployment:
        raise ValueError("artifact-parity report is not bound to the supplied deployment report")
    halmos = by_gate["relay-halmos"]
    execution = halmos.get("execution")
    if not isinstance(execution, dict):
        raise ValueError("Halmos evidence has no raw-results provenance")
    execution_mode = execution.get("mode")
    if execution_mode != halmos["generation_provenance"]["mode"]:
        raise ValueError("Halmos raw-results mode differs from generation provenance")
    raw_hash = execution.get("raw_results_sha256")
    if not isinstance(raw_hash, str) or not re.fullmatch(r"[0-9a-f]{64}", raw_hash):
        raise ValueError("Halmos evidence has no canonical raw-results SHA-256")
    if execution_mode == GENERATED_MODE:
        halmos_exitcode = execution.get("halmos_process_exitcode")
        halmos_command = execution.get("command")
        if type(halmos_exitcode) is not int or not isinstance(halmos_command, list) or not halmos_command:
            raise ValueError("Halmos evidence has incomplete in-process execution provenance")
        if not all(isinstance(argument, str) and argument for argument in halmos_command):
            raise ValueError("Halmos evidence has a malformed in-process command")
        _validate_release_halmos_inputs(halmos, halmos_command)
    elif execution_mode == IMPORTED_MODE:
        if (
            execution.get("halmos_process_exitcode") is not None
            or not isinstance(execution.get("input_path"), str)
            or not execution["input_path"]
            or "command" in execution
        ):
            raise ValueError("imported Halmos evidence has malformed development provenance")
    elif execution_mode == DIAGNOSTIC_MODE:
        halmos_exitcode = execution.get("halmos_process_exitcode")
        halmos_command = execution.get("command")
        if type(halmos_exitcode) is not int or not isinstance(halmos_command, list) or not halmos_command:
            raise ValueError("diagnostic Halmos evidence has incomplete execution provenance")
    else:
        raise ValueError(f"Halmos evidence has unsupported execution mode {execution_mode!r}")
    return evidence


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--report", type=Path, action="append", dest="reports")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument(
        "--allow-dirty",
        action="store_true",
        help="permit a development-only bundle from dirty or imported evidence",
    )
    args = parser.parse_args()
    generation_start = capture_git_state(REPO)
    reports = [Path(item) for item in (args.reports or DEFAULT_REPORTS)]
    try:
        manifest_bytes = args.manifest.read_bytes()
        manifest = json.loads(manifest_bytes)
        if type(manifest.get("schema_version")) is not int or manifest.get("schema_version") != 1:
            raise ValueError("unsupported verification manifest schema")
        manifest_sha256 = hashlib.sha256(manifest_bytes).hexdigest()
        repository_commit = generation_start.get("head", "unknown")
        if generation_start.get("clean") is not True and not args.allow_dirty:
            raise ValueError("working tree is dirty; commit the reviewed inputs or use --allow-dirty for development only")
        evidence = collect_evidence(
            reports,
            manifest_sha256,
            repository_commit,
            allow_development=args.allow_dirty,
        )
        generation = finalize_generation_provenance(REPO, generation_start)
        evidence_release_eligible = all(item["release_eligible"] for item in evidence)
        release_eligible = generation["release_eligible"] is True and evidence_release_eligible
        if not release_eligible and not args.allow_dirty:
            raise ValueError("bundle generation or constituent evidence is development-only")
        output = {
            "schema_version": 1,
            "gate": "relay-fv-bundle",
            "status": "pass",
            "release_eligible": release_eligible,
            "git_commit": repository_commit,
            "manifest_sha256": manifest_sha256,
            "generation_provenance": generation,
            "repository": {
                "commit": repository_commit,
                "start": generation["start"],
                "end": generation["end"],
            },
            "manifest": {"path": str(args.manifest), "sha256": manifest_sha256},
            "evidence": evidence,
        }
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n")
        qualifier = "release eligible" if release_eligible else "development only"
        print(f"[fv-bundle] PASS ({qualifier}): {len(evidence)} reports recorded in {args.output}")
        return 0
    except (OSError, ValueError, json.JSONDecodeError, RuntimeError) as error:
        print(f"[fv-bundle] FAIL: {error}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
