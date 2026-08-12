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
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

try:
    import tomllib
except ImportError:  # pragma: no cover - Python 3.11+ is pinned for release runs
    tomllib = None  # type: ignore[assignment]


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
if str(FV_DIR) not in sys.path:
    sys.path.insert(0, str(FV_DIR))
from report_provenance import (  # noqa: E402
    DIAGNOSTIC_MODE,
    GENERATED_MODE,
    IMPORTED_MODE,
    capture_git_state,
    clean_install_soldeer,
    finalize_soldeer,
    finalize_generation_provenance,
    report_commit,
)
from verify_relay_artifact import summarize_bytecode  # noqa: E402
from verify_relay_custom_error_abi import keccak256  # noqa: E402


def canonical_check(suite: str, function_signature: str) -> str:
    """Return the stable manifest identifier for one Halmos result."""
    function_name = function_signature.split("(", 1)[0]
    return f"{suite.replace(os.sep, '/')}.{function_name}"


def load_manifest(path: Path) -> tuple[dict[str, Any], str]:
    raw = path.read_bytes()
    manifest = json.loads(raw)
    if type(manifest.get("schema_version")) is not int or manifest["schema_version"] != 1:
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
    if type(expected_count) is not int:
        raise ValueError("halmos.expected_check_count must be an integer")
    if expected_count != len(declared):
        raise ValueError(
            f"halmos.expected_check_count is {expected_count}, but {len(declared)} checks are declared"
        )

    for field in ("expected_process_exitcode", "max_bounded_loops"):
        value = halmos.get(field)
        if type(value) is not int or value < 0:
            raise ValueError(f"halmos.{field} must be a non-negative integer")

    configuration = halmos.get("configuration")
    if not isinstance(configuration, dict):
        raise ValueError("halmos.configuration must be an object")
    expected_config = {
        "path": str,
        "forge_build_out": str,
        "loop": int,
        "solver": str,
        "solver_timeout_assertion": int,
    }
    if set(configuration) != set(expected_config):
        raise ValueError("halmos.configuration has missing or unexpected fields")
    for field, expected_type in expected_config.items():
        value = configuration[field]
        if expected_type is int:
            valid = type(value) is int and value >= 0
        else:
            valid = isinstance(value, str) and bool(value)
        if not valid:
            raise ValueError(f"halmos.configuration.{field} has an invalid value")

    _halmos_foundry_build(manifest)

    return manifest, hashlib.sha256(raw).hexdigest()


def _valid_model_count(result: dict[str, Any]) -> tuple[int, list[str]]:
    problems: list[str] = []
    num_models = result.get("num_models")
    models = result.get("models")
    if type(num_models) is not int or num_models < 0:
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
        or not all(type(value) is int and value >= 0 for value in paths)
    ):
        problems.append("num_paths must be [total, success, blocked] with non-negative integers")
    elif paths[0] == 0:
        problems.append("Halmos explored zero paths")

    bounded = result.get("num_bounded_loops")
    if type(bounded) is not int or bounded < 0:
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
    if type(top_exitcode) is not int or top_exitcode != expected_process_exitcode:
        violations.append(
            f"Halmos JSON exitcode is {top_exitcode!r}; expected {expected_process_exitcode}"
        )
    if process_exitcode is not None and (
        type(process_exitcode) is not int or process_exitcode != top_exitcode
    ):
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

        if type(exitcode) is not int or exitcode != expected_exitcode:
            check_problems.append(
                f"exitcode {exitcode!r} ({EXIT_NAMES.get(exitcode, 'UNKNOWN')}) != "
                f"expected {expected_exitcode} ({EXIT_NAMES[expected_exitcode]})"
            )
        if expectation == "proof":
            if type(result.get("num_models")) is not int or result.get("num_models") != 0:
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


def _foundry_build(output: str) -> dict[str, str]:
    version = re.search(r"^forge Version:\s*(\S+)", output, re.MULTILINE)
    commit = re.search(r"^Commit SHA:\s*([0-9a-f]{40})", output, re.MULTILINE)
    return {
        "version": version.group(1) if version else "unavailable",
        "commit": commit.group(1) if commit else "unavailable",
    }


def _halmos_interpreter(halmos_binary: str) -> tuple[str, list[str]]:
    problems: list[str] = []
    resolved = shutil.which(halmos_binary) if os.sep not in halmos_binary else halmos_binary
    if not resolved:
        return "unavailable", [f"could not resolve Halmos executable {halmos_binary!r}"]
    try:
        first_line = Path(resolved).read_bytes().splitlines()[0].decode("utf-8")
    except (OSError, IndexError, UnicodeError) as error:
        return "unavailable", [f"could not read Halmos launcher ({error})"]
    if not first_line.startswith("#!"):
        return "unavailable", ["Halmos launcher has no interpreter shebang"]
    interpreter = first_line[2:].strip().split()[0]
    verifier_parent = Path(sys.executable).absolute().parent.resolve()
    halmos_parent = Path(interpreter).absolute().parent.resolve()
    if halmos_parent != verifier_parent:
        problems.append(
            f"Halmos interpreter directory {halmos_parent} differs from verifier {verifier_parent}"
        )
    return interpreter, problems


def _mask_non_code(source: str) -> str:
    """Blank comments and string literals while preserving offsets and newlines."""
    result = list(source)
    index = 0
    state = "code"
    quote = ""
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
            if current in {'"', "'"}:
                result[index] = " "
                quote = current
                state = "string"
        elif state == "line-comment":
            if current == "\n":
                state = "code"
            else:
                result[index] = " "
        elif state == "block-comment":
            if current == "*" and following == "/":
                result[index] = result[index + 1] = " "
                index += 2
                state = "code"
                continue
            if current != "\n":
                result[index] = " "
        else:
            if current == "\\":
                result[index] = " "
                if index + 1 < len(source):
                    result[index + 1] = " "
                index += 2
                continue
            if current == quote:
                state = "code"
            if current != "\n":
                result[index] = " "
        index += 1
    if state in {"block-comment", "string"}:
        raise ValueError(f"unterminated Solidity {state}")
    return "".join(result)


def _closing_brace(source: str, opening: int) -> int:
    depth = 1
    for index in range(opening + 1, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return index
    raise ValueError("unterminated Solidity contract body")


def discover_source_checks(directory: Path, pattern: str = "*.t.sol") -> set[str]:
    """Discover every declared check_* function and bind it to its declaring contract."""
    discovered: set[str] = set()
    for path in sorted(directory.glob(pattern)):
        source = _mask_non_code(path.read_text())
        contracts: list[tuple[str, int, int]] = []
        for match in re.finditer(r"\b(?:abstract\s+)?contract\s+([A-Za-z_$][A-Za-z0-9_$]*)\b", source):
            opening = source.find("{", match.end())
            if opening == -1:
                raise ValueError(f"{path}: contract {match.group(1)} has no body")
            contracts.append((match.group(1), opening, _closing_brace(source, opening)))
        for match in re.finditer(r"\bfunction\s+(check_[A-Za-z0-9_]+)\s*\(", source):
            owners = [item for item in contracts if item[1] < match.start() < item[2]]
            if len(owners) != 1:
                raise ValueError(
                    f"{path}:{source.count(chr(10), 0, match.start()) + 1}: "
                    f"could not identify one declaring contract for {match.group(1)}"
                )
            contract = owners[0][0]
            relative = path.resolve().relative_to(REPO_ROOT.resolve()).as_posix()
            check_id = f"{relative}:{contract}.{match.group(1)}"
            if check_id in discovered:
                raise ValueError(f"duplicate source check declaration: {check_id}")
            discovered.add(check_id)
    return discovered


def source_inventory_problems(manifest: dict[str, Any], directory: Path = FV_DIR) -> list[str]:
    halmos = manifest["halmos"]
    discovered = discover_source_checks(directory, halmos.get("source_glob", "*.t.sol"))
    declared = set(halmos["proofs"]) | set(halmos["reachability"])
    problems: list[str] = []
    missing = sorted(declared - discovered)
    unexpected = sorted(discovered - declared)
    if missing:
        problems.append("manifest checks missing from source: " + ", ".join(missing))
    if unexpected:
        problems.append("source checks missing from manifest: " + ", ".join(unexpected))
    return problems


def _toolchain_problems(
    forge_binary: str, halmos_binary: str, manifest: dict[str, Any]
) -> tuple[dict[str, str], list[str]]:
    expected = manifest["toolchain"]
    foundry = _foundry_build(_command_output([forge_binary, "--version"]))
    halmos_version = _command_output([halmos_binary, "--version"])
    halmos_python, interpreter_problems = _halmos_interpreter(halmos_binary)
    if halmos_python == "unavailable":
        z3_version = "unavailable"
    else:
        z3_version = _command_output(
            [
                halmos_python,
                "-c",
                "import importlib.metadata; print(importlib.metadata.version('z3-solver'))",
            ]
        )

    problems: list[str] = []
    problems.extend(interpreter_problems)
    for field in ("version", "commit"):
        if foundry[field] != expected["foundry"][field]:
            problems.append(
                f"Foundry {field} is {foundry[field]!r}; expected {expected['foundry'][field]!r}"
            )
    ci_image = os.environ.get("FV_FOUNDRY_IMAGE")
    if ci_image is not None and ci_image != expected["foundry"]["image"]:
        problems.append(
            f"FV_FOUNDRY_IMAGE is {ci_image!r}; expected {expected['foundry']['image']!r}"
        )
    if halmos_version != f"halmos {expected['halmos']}":
        problems.append(
            f"Halmos version is {halmos_version!r}; expected 'halmos {expected['halmos']}'"
        )
    if z3_version != expected["z3"]:
        problems.append(f"z3-solver version is {z3_version!r}; expected {expected['z3']!r}")
    return {
        "foundry_version": foundry["version"],
        "foundry_commit": foundry["commit"],
        "foundry_ci_image": ci_image or "local-unset",
        "halmos": halmos_version,
        "halmos_python": halmos_python,
        "verifier_python": sys.executable,
        "z3_solver": z3_version,
    }, problems


def _audit_halmos_config(manifest: dict[str, Any]) -> tuple[dict[str, Any], list[str]]:
    expected = manifest["halmos"]["configuration"]
    path = REPO_ROOT / expected["path"]
    problems: list[str] = []
    if tomllib is None:
        return {"path": expected["path"], "sha256": None}, ["Python tomllib is unavailable"]
    try:
        raw = path.read_bytes()
        parsed = tomllib.loads(raw.decode())
    except (OSError, UnicodeError, ValueError) as error:
        return {"path": expected["path"], "sha256": None}, [
            f"could not load pinned Halmos config ({error})"
        ]
    global_config = parsed.get("global")
    if not isinstance(global_config, dict):
        problems.append("halmos.toml has no [global] object")
        global_config = {}
    actual = {
        "forge_build_out": global_config.get("forge-build-out"),
        "loop": global_config.get("loop"),
        "solver": global_config.get("solver"),
        "solver_timeout_assertion": global_config.get("solver-timeout-assertion"),
    }
    if set(parsed) != {"global"}:
        problems.append("halmos.toml has unexpected top-level sections")
    allowed_global = {
        "forge-build-out",
        "loop",
        "solver",
        "solver-timeout-assertion",
    }
    unexpected = sorted(set(global_config) - allowed_global)
    if unexpected:
        problems.append("halmos.toml has unexpected global keys: " + ", ".join(unexpected))
    for field, wanted in expected.items():
        if field == "path":
            continue
        if actual[field] != wanted or (
            isinstance(wanted, int) and type(actual[field]) is not int
        ):
            problems.append(
                f"halmos.toml {field} is {actual[field]!r}; expected {wanted!r}"
            )
    return {
        "path": expected["path"],
        "sha256": hashlib.sha256(raw).hexdigest(),
        "effective": actual,
    }, problems


def _prepare_halmos_artifacts(
    manifest: dict[str, Any],
    forge_binary: str | None = None,
    environment: dict[str, str] | None = None,
) -> tuple[int, list[str]]:
    """Force exact production artifacts so Halmos cannot reuse an alternate build."""
    compiler = manifest["target"]["production_compiler"]
    configuration = manifest["halmos"]["configuration"]
    command = [
        forge_binary or os.environ.get("FORGE", "forge"),
        "build",
        "--use",
        compiler["short_version"],
        "--no-auto-detect",
        "--out",
        configuration["forge_build_out"],
        "--force",
        "--ast",
        "--evm-version",
        compiler["evm_version"],
        "--extra-output",
        "storageLayout",
        "metadata",
    ]
    if compiler["optimizer_enabled"]:
        command.extend(["--optimize", "--optimizer-runs", str(compiler["optimizer_runs"])])
    if compiler["via_ir"]:
        command.append("--via-ir")
    print("[fv] preparing Halmos artifacts:", " ".join(command), flush=True)
    try:
        completed = subprocess.run(
            command,
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            check=False,
            env=environment,
        )
    except OSError as error:
        print(f"[fv] FAIL: could not execute Forge ({error}).")
        return 1, command
    if completed.returncode:
        print(completed.stdout, end="")
        print(completed.stderr, end="", file=sys.stderr)
    return completed.returncode, command


def _halmos_foundry_build(manifest: dict[str, Any]) -> dict[str, str]:
    """Derive the internal Forge scope from the exact manifest check inventory."""
    checks = manifest["halmos"]["proofs"] + manifest["halmos"]["reachability"]
    source_parents: list[str] = []
    for check_id in checks:
        source, separator, _ = check_id.partition(":")
        path = Path(source)
        if not separator or path.is_absolute() or ".." in path.parts:
            raise ValueError(f"invalid Halmos source path in manifest: {check_id!r}")
        source_parents.append(path.parent.as_posix())
    if not source_parents:
        raise ValueError("Halmos manifest has no source inventory")
    common_parent = Path(os.path.commonpath(source_parents))
    if (REPO_ROOT / common_parent).resolve() != FV_DIR.resolve():
        raise ValueError("Halmos manifest sources do not share the audited FV suite root")
    return {
        "profile": "default",
        "src": common_parent.as_posix(),
        "test": common_parent.as_posix(),
        "cache_path": "cache-forge",
    }


def _halmos_foundry_environment(manifest: dict[str, Any]) -> dict[str, str]:
    """Return the exact Foundry environment shared by artifact prep and Halmos."""
    foundry = _halmos_foundry_build(manifest)
    compiler = manifest["target"]["production_compiler"]
    configuration = manifest["halmos"]["configuration"]
    return {
        "FOUNDRY_PROFILE": foundry["profile"],
        "FOUNDRY_SRC": foundry["src"],
        "FOUNDRY_TEST": foundry["test"],
        "FOUNDRY_OUT": configuration["forge_build_out"],
        "FOUNDRY_CACHE_PATH": foundry["cache_path"],
        "FOUNDRY_SOLC_VERSION": compiler["short_version"],
        "FOUNDRY_AUTO_DETECT_SOLC": "false",
        "FOUNDRY_EVM_VERSION": compiler["evm_version"],
        "FOUNDRY_OPTIMIZER": "true" if compiler["optimizer_enabled"] else "false",
        "FOUNDRY_OPTIMIZER_RUNS": str(compiler["optimizer_runs"]),
        "FOUNDRY_VIA_IR": "true" if compiler["via_ir"] else "false",
    }


def _halmos_subprocess_environment(
    forge_binary: str, manifest: dict[str, Any]
) -> tuple[dict[str, str], str, dict[str, str]]:
    """Make both Halmos Forge phases use one audited binary and build scope."""
    resolved = shutil.which(forge_binary)
    if resolved is None:
        candidate = Path(forge_binary).expanduser()
        if candidate.is_file() and os.access(candidate, os.X_OK):
            resolved = str(candidate.resolve())
    if resolved is None:
        raise RuntimeError(f"could not resolve executable Forge binary {forge_binary!r}")
    resolved_path = Path(resolved).resolve()
    environment = {
        key: value
        for key, value in os.environ.items()
        if not key.startswith(("FOUNDRY_", "DAPP_"))
    }
    environment["PATH"] = str(resolved_path.parent) + os.pathsep + environment.get("PATH", "")
    pinned = _halmos_foundry_environment(manifest)
    environment.update(pinned)
    internal = shutil.which("forge", path=environment["PATH"])
    if internal is None or Path(internal).resolve() != resolved_path:
        raise RuntimeError(
            "Halmos invokes `forge` by name, but the audited Forge binary is not named `forge`"
        )
    return environment, str(resolved_path), pinned


def _audit_halmos_foundry_environment(
    forge_binary: str, environment: dict[str, str], pinned: dict[str, str]
) -> tuple[dict[str, Any], list[str]]:
    """Fail closed if Foundry does not honor the pinned internal-build environment."""
    command = [forge_binary, "config", "--json"]
    try:
        completed = subprocess.run(
            command,
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            check=False,
            env=environment,
        )
        parsed = json.loads(completed.stdout) if completed.returncode == 0 else {}
    except (OSError, json.JSONDecodeError) as error:
        return {"environment": pinned, "effective": None}, [
            f"could not audit Halmos Foundry environment ({error})"
        ]

    expected = {
        "src": pinned["FOUNDRY_SRC"],
        "test": pinned["FOUNDRY_TEST"],
        "out": pinned["FOUNDRY_OUT"],
        "cache_path": pinned["FOUNDRY_CACHE_PATH"],
        "solc": pinned["FOUNDRY_SOLC_VERSION"],
        "auto_detect_solc": False,
        "evm_version": pinned["FOUNDRY_EVM_VERSION"],
        "optimizer": pinned["FOUNDRY_OPTIMIZER"] == "true",
        "optimizer_runs": int(pinned["FOUNDRY_OPTIMIZER_RUNS"]),
        "via_ir": pinned["FOUNDRY_VIA_IR"] == "true",
    }
    actual = {field: parsed.get(field) for field in expected}
    problems: list[str] = []
    if completed.returncode != 0:
        problems.append(f"Halmos Foundry config audit exited {completed.returncode}")
    for field, wanted in expected.items():
        if type(actual[field]) is not type(wanted) or actual[field] != wanted:
            problems.append(
                f"Halmos Foundry {field} is {actual[field]!r}; expected {wanted!r}"
            )
    return {
        "command": command,
        "environment": pinned,
        "effective": actual,
    }, problems


def _halmos_artifact_record(
    path: Path,
    source: str,
    contract: str,
    manifest: dict[str, Any],
) -> tuple[dict[str, Any], list[str]]:
    problems: list[str] = []
    compiler = manifest["target"]["production_compiler"]
    try:
        raw = path.read_bytes()
        artifact = json.loads(raw)
        metadata = artifact["metadata"]
        settings = metadata["settings"]
        optimizer = settings["optimizer"]
        compilation_target = settings["compilationTarget"]
        actual_compiler = {
            "version": metadata["compiler"]["version"],
            "evm_version": settings["evmVersion"],
            "optimizer_enabled": optimizer["enabled"],
            "optimizer_runs": optimizer["runs"],
            "via_ir": settings.get("viaIR", False),
        }
        creation = summarize_bytecode(artifact["bytecode"]["object"], f"{path.name} creation")
        runtime = summarize_bytecode(
            artifact["deployedBytecode"]["object"], f"{path.name} runtime"
        )
    except (OSError, KeyError, TypeError, ValueError, json.JSONDecodeError) as error:
        return {"path": str(path), "available": False}, [f"invalid Halmos artifact {path} ({error})"]
    for field, wanted in compiler.items():
        if field == "short_version":
            continue
        if type(actual_compiler.get(field)) is not type(wanted) or actual_compiler.get(field) != wanted:
            problems.append(
                f"{path.name} compiler {field} is {actual_compiler.get(field)!r}; expected {wanted!r}"
            )
    if compilation_target != {source: contract}:
        problems.append(
            f"{path.name} compilation target is {compilation_target!r}; expected {source}:{contract}"
        )
    try:
        source_bytes = (REPO_ROOT / source).read_bytes()
    except OSError as error:
        problems.append(f"could not read artifact source {source} ({error})")
        source_sha256 = None
        source_keccak256 = None
    else:
        source_sha256 = hashlib.sha256(source_bytes).hexdigest()
        source_keccak256 = "0x" + keccak256(source_bytes).hex()
        metadata_source = metadata.get("sources", {}).get(source)
        actual_keccak = metadata_source.get("keccak256") if isinstance(metadata_source, dict) else None
        if actual_keccak != source_keccak256:
            problems.append(
                f"{path.name} metadata source hash is {actual_keccak!r}; current {source} is {source_keccak256}"
            )
    return {
        "path": str(path.relative_to(REPO_ROOT)),
        "source": source,
        "contract": contract,
        "available": True,
        "source_sha256": source_sha256,
        "source_keccak256": source_keccak256,
        "artifact_sha256": hashlib.sha256(raw).hexdigest(),
        "compiler": actual_compiler,
        "creation_semantic_sha256": creation["semantic_sha256"],
        "runtime_semantic_sha256": runtime["semantic_sha256"],
    }, problems


def _halmos_artifact_targets(manifest: dict[str, Any]) -> list[tuple[str, str]]:
    target = manifest["target"]
    targets = {(target["source"], target["contract"])}
    targets.add(("contracts/protocol/implementation/RelayProxy.sol", "RelayProxy"))
    for check_id in manifest["halmos"]["proofs"] + manifest["halmos"]["reachability"]:
        match = re.fullmatch(
            r"([^:]+):([A-Za-z_$][A-Za-z0-9_$]*)\.check_[A-Za-z0-9_]+",
            check_id,
        )
        if match is None:
            raise ValueError(f"malformed Halmos check identifier: {check_id}")
        targets.add((match.group(1), match.group(2)))
    return sorted(targets)


def _audit_halmos_artifacts(manifest: dict[str, Any]) -> tuple[dict[str, Any], list[str]]:
    out = REPO_ROOT / manifest["halmos"]["configuration"]["forge_build_out"]
    records: dict[str, Any] = {}
    problems: list[str] = []
    for source, contract in _halmos_artifact_targets(manifest):
        path = out / Path(source).name / f"{contract}.json"
        record, artifact_problems = _halmos_artifact_record(
            path, source, contract, manifest
        )
        records[f"{source}:{contract}"] = record
        problems.extend(artifact_problems)
    return records, problems


def _write_report(path: Path, report: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")


def _execution_provenance(
    raw_results: bytes,
    *,
    imported: bool,
    process_exitcode: int | None = None,
    command: list[str] | None = None,
    input_path: Path | None = None,
    diagnostic_overrides: bool = False,
) -> tuple[bool, dict[str, Any]]:
    """Describe how the raw Halmos JSON entered this process.

    Imported JSON is useful for diagnosis, but there is no trustworthy binding
    between that file and the current checkout/tool invocation. Only JSON emitted
    by the Halmos child process launched here is eligible for the release bundle.
    """
    record: dict[str, Any] = {
        "mode": (
            IMPORTED_MODE
            if imported
            else DIAGNOSTIC_MODE if diagnostic_overrides else GENERATED_MODE
        ),
        "raw_results_sha256": hashlib.sha256(raw_results).hexdigest(),
        "halmos_process_exitcode": process_exitcode,
    }
    if imported:
        if process_exitcode is not None or command is not None or input_path is None:
            raise ValueError("imported result provenance has inconsistent execution fields")
        record["input_path"] = str(input_path.resolve())
        return False, record
    if process_exitcode is None or not command or input_path is not None:
        raise ValueError("generated result provenance requires a command and process exit code")
    record["command"] = command
    return not diagnostic_overrides, record


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
    generation_start = capture_git_state(REPO_ROOT)
    try:
        manifest, manifest_hash = load_manifest(args.manifest)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"[fv] FAIL: could not load verification manifest ({error}).")
        return 1

    try:
        inventory_problems = source_inventory_problems(manifest)
    except (OSError, ValueError) as error:
        inventory_problems = [f"could not discover source checks ({error})"]
    if inventory_problems:
        generation = finalize_generation_provenance(REPO_ROOT, generation_start)
        report = {
            "schema_version": 1,
            "gate": "relay-halmos",
            "status": "fail",
            "release_eligible": False,
            "git_commit": report_commit(generation),
            "manifest_sha256": manifest_hash,
            "generation_provenance": generation,
            "execution": {
                "mode": "preflight-failed",
                "raw_results_sha256": None,
                "halmos_process_exitcode": None,
            },
            "summary": {
                "expected_checks": len(manifest["halmos"]["proofs"])
                + len(manifest["halmos"]["reachability"]),
                "observed_checks": 0,
                "proofs_ok": 0,
                "proofs_expected": len(manifest["halmos"]["proofs"]),
                "reachability_ok": 0,
                "reachability_expected": len(manifest["halmos"]["reachability"]),
                "violations": len(inventory_problems),
            },
            "checks": [],
            "violations": inventory_problems,
        }
        if args.report_output:
            _write_report(args.report_output, report)
        print("[fv] FAIL: source/manifest inventory mismatch:")
        for problem in inventory_problems:
            print("   -", problem)
        return 1

    forge_binary = os.environ.get("FORGE", "forge")
    halmos_binary = os.environ.get("HALMOS", "halmos")
    toolchain, toolchain_problems = _toolchain_problems(forge_binary, halmos_binary, manifest)
    config_record, config_problems = _audit_halmos_config(manifest)
    process_exitcode: int | None = None
    temporary_output: Path | None = None
    halmos_command: list[str] | None = None
    dependency_record: dict[str, Any] | None = None
    artifact_records: dict[str, Any] | None = None
    artifact_records_end: dict[str, Any] | None = None
    input_problems = list(config_problems)

    try:
        halmos_environment, halmos_forge, pinned_foundry_environment = (
            _halmos_subprocess_environment(forge_binary, manifest)
        )
        toolchain["halmos_forge"] = halmos_forge
        foundry_record, foundry_problems = _audit_halmos_foundry_environment(
            halmos_forge, halmos_environment, pinned_foundry_environment
        )
        input_problems.extend(foundry_problems)
    except RuntimeError as error:
        print(f"[fv] FAIL: could not prepare Halmos Foundry environment ({error}).")
        return 1

    try:
        if args.results_input:
            output_path = args.results_input
            print(f"[fv] validating existing results: {output_path}")
        else:
            dependency_record, dependency_problems = clean_install_soldeer(
                REPO_ROOT, forge_binary
            )
            input_problems.extend(dependency_problems)
            if dependency_problems:
                raise RuntimeError("clean Soldeer preparation failed: " + "; ".join(dependency_problems))
            build_exitcode, build_command = _prepare_halmos_artifacts(
                manifest, forge_binary, halmos_environment
            )
            if build_exitcode:
                raise RuntimeError("could not produce exact AST-complete Foundry artifacts")
            artifact_records, artifact_problems = _audit_halmos_artifacts(manifest)
            input_problems.extend(artifact_problems)
            if artifact_problems:
                raise RuntimeError("Halmos artifact audit failed: " + "; ".join(artifact_problems))
            with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as output:
                temporary_output = Path(output.name)
            output_path = temporary_output
            prefix = manifest["halmos"].get("function_prefix", "check_")
            configuration = manifest["halmos"]["configuration"]
            halmos_command = [
                halmos_binary,
                "--root",
                str(REPO_ROOT),
                "--config",
                str((REPO_ROOT / configuration["path"]).resolve()),
                "--function",
                prefix,
                "--forge-build-out",
                configuration["forge_build_out"],
                "--loop",
                str(configuration["loop"]),
                "--solver",
                configuration["solver"],
                "--solver-timeout-assertion",
                str(configuration["solver_timeout_assertion"]),
                "--json-output",
                str(output_path),
                *halmos_args,
            ]
            print("[fv] running:", " ".join(halmos_command), flush=True)
            try:
                completed = subprocess.run(
                    halmos_command,
                    check=False,
                    env=halmos_environment,
                )
            except (OSError, RuntimeError) as error:
                print(f"[fv] FAIL: could not execute Halmos ({error}).")
                return 1
            process_exitcode = completed.returncode

            artifact_records_end, artifact_end_problems = _audit_halmos_artifacts(manifest)
            input_problems.extend(artifact_end_problems)
            if artifact_records_end != artifact_records:
                input_problems.append("Halmos-consumed Relay/RelayProxy artifacts changed during execution")
            input_problems.extend(finalize_soldeer(REPO_ROOT, dependency_record))

        try:
            raw_results = output_path.read_bytes()
            data = json.loads(raw_results)
        except (OSError, json.JSONDecodeError) as error:
            print(f"[fv] FAIL: could not read Halmos JSON output ({error}).")
            return 1

        report = evaluate_results(data, manifest, process_exitcode=process_exitcode)
        _, execution = _execution_provenance(
            raw_results,
            imported=args.results_input is not None,
            process_exitcode=process_exitcode,
            command=halmos_command,
            input_path=args.results_input,
            diagnostic_overrides=bool(halmos_args),
        )
        report["execution"] = execution
        generation = finalize_generation_provenance(
            REPO_ROOT,
            generation_start,
            mode=execution["mode"],
        )
        report["generation_provenance"] = generation
        report["manifest_sha256"] = manifest_hash
        report["git_commit"] = report_commit(generation)
        report["toolchain"] = toolchain
        report["inputs"] = {
            "halmos_config": config_record,
            "halmos_foundry_build": foundry_record,
            "soldeer": dependency_record,
            "artifacts_before_halmos": artifact_records,
            "artifacts_after_halmos": artifact_records_end,
            "release_eligible": not input_problems and args.results_input is None,
            "problems": input_problems,
        }
        all_preflight_problems = toolchain_problems + input_problems
        if all_preflight_problems:
            report["violations"] = all_preflight_problems + report["violations"]
            report["summary"]["violations"] = len(report["violations"])
            report["status"] = "fail"
        report["release_eligible"] = (
            report["status"] == "pass"
            and generation["release_eligible"] is True
            and report["inputs"]["release_eligible"] is True
        )

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

        if execution["mode"] == IMPORTED_MODE:
            print(
                "[fv] DEVELOPMENT ONLY: --results-input evidence is imported and cannot enter "
                "a release bundle."
            )

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
