#!/usr/bin/env python3
"""Fail-closed regression gate for all Relay Lean proofs."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any


LEAN_DIR = Path(__file__).resolve().parent
FV_DIR = LEAN_DIR.parent
MANIFEST_PATH = FV_DIR / "verification-manifest.json"
if str(FV_DIR) not in sys.path:
    sys.path.insert(0, str(FV_DIR))
from report_provenance import (  # noqa: E402
    capture_git_state,
    dependency_tree_state,
    finalize_generation_provenance,
    report_commit,
)

REFINEMENT_DIR = LEAN_DIR / "bytecode-refinement"
ABSTRACT = "RelaySigLoop.lean"
STANDALONE = [
    "RelayBytecodeRefinement.lean",
    "DataLayer.lean",
    "RelayLoopMemRead.lean",
    "RelayLoopWindows.lean",
    "RelayLoopLiteral.lean",
    "RelayStorageLayer.lean",
    "RelayFeeLayer.lean",
]
INTEGRATION = "RelayBodyEff.lean"
INTEGRATION_DEPS = ["DataLayer", "RelayLoopWindows", "RelayLoopLiteral", "RelayStorageLayer"]
FORBIDDEN_SOURCE_TOKENS = ("sorry", "admit", "native_decide")


def run(command: list[str], *, cwd: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, capture_output=True, text=True, check=False)


def strip_lean_comments(source: str) -> str:
    """Strip nested block and line comments while preserving line boundaries."""
    output: list[str] = []
    index = 0
    block_depth = 0
    while index < len(source):
        pair = source[index : index + 2]
        if block_depth:
            if pair == "/-":
                block_depth += 1
                index += 2
            elif pair == "-/":
                block_depth -= 1
                index += 2
            else:
                if source[index] == "\n":
                    output.append("\n")
                index += 1
            continue
        if pair == "/-":
            block_depth = 1
            index += 2
        elif pair == "--":
            newline = source.find("\n", index)
            if newline == -1:
                break
            output.append("\n")
            index = newline + 1
        else:
            output.append(source[index])
            index += 1
    if block_depth:
        raise ValueError("unterminated Lean block comment")
    return "".join(output)


def source_audit(path: Path, lean_manifest: dict[str, Any]) -> tuple[dict[str, Any], list[str]]:
    source = path.read_text()
    code = strip_lean_comments(source)
    problems: list[str] = []
    for token in FORBIDDEN_SOURCE_TOKENS:
        if re.search(rf"\b{re.escape(token)}\b", code):
            problems.append(f"{path.name}: forbidden source token '{token}'")

    declared = re.findall(r"^\s*axiom\s+([A-Za-z0-9_'.]+)", code, re.MULTILINE)
    expected_qualified = lean_manifest["declared_axioms"].get(path.name, [])
    expected_declared = [name.rsplit(".", 1)[-1] for name in expected_qualified]
    if sorted(declared) != sorted(expected_declared):
        problems.append(
            f"{path.name}: declared axioms {sorted(declared)} != manifest {sorted(expected_declared)}"
        )

    directives = re.findall(r"^#print axioms\s+([^\s]+)\s*$", code, re.MULTILINE)
    expected_count = lean_manifest["axiom_audit_counts"].get(path.name)
    if type(expected_count) is not int or expected_count != len(directives):
        problems.append(
            f"{path.name}: has {len(directives)} #print axioms directives; manifest requires {expected_count}"
        )
    for required in lean_manifest["required_results"].get(path.name, []):
        if not any(item == required or item.endswith(f".{required}") or required.endswith(f".{item}") for item in directives):
            problems.append(f"{path.name}: required axiom audit '{required}' is missing")

    return {
        "source_sha256": hashlib.sha256(source.encode()).hexdigest(),
        "declared_axioms": declared,
        "axiom_audits": directives,
    }, problems


def parsed_axiom_output(output: str) -> list[tuple[str, list[str]]]:
    matches = re.findall(
        r"^[ \t]*'(.*?)'[ \t]+(?:depends on axioms:[ \t]*\[([^\]]*)\]|does not depend on any axioms)",
        output,
        re.MULTILINE,
    )
    return [
        (name, [axiom.strip() for axiom in axioms.split(",") if axiom.strip()])
        for name, axioms in matches
    ]


def audit_lean_output(
    path: Path,
    completed: subprocess.CompletedProcess[str],
    source_record: dict[str, Any],
    allowed_axioms: set[str],
) -> tuple[dict[str, Any], list[str]]:
    output = completed.stdout + "\n" + completed.stderr
    problems: list[str] = []
    if completed.returncode != 0 or re.search(r"^.*error:", output, re.MULTILINE):
        errors = [line for line in output.splitlines() if "error:" in line][:5]
        problems.append(
            f"{path.name}: Lean reported errors (exit {completed.returncode}): "
            + " | ".join(errors or [output[-400:]])
        )
    for token in ("sorryAx", "native_decide", "Lean.ofReduceBool"):
        if token in output:
            problems.append(f"{path.name}: forbidden token '{token}' in Lean output")

    groups = parsed_axiom_output(output)
    directives = source_record["axiom_audits"]
    if len(groups) != len(directives):
        problems.append(
            f"{path.name}: Lean emitted {len(groups)} axiom audits for {len(directives)} directives"
        )

    emitted_names = [name for name, _ in groups]
    for directive in directives:
        if not any(name == directive or name.endswith(f".{directive}") for name in emitted_names):
            problems.append(f"{path.name}: no Lean axiom output for '{directive}'")
    for name, axioms in groups:
        disallowed = sorted(set(axioms) - allowed_axioms)
        if disallowed:
            problems.append(f"{path.name}: {name} depends on disallowed axioms {disallowed}")

    return {
        **source_record,
        "status": "pass" if not problems else "fail",
        "lean_exitcode": completed.returncode,
        "emitted_axiom_audits": [
            {"declaration": name, "axioms": axioms} for name, axioms in groups
        ],
        "problems": problems,
    }, problems


def _lake_package_provenance(evmyul: Path) -> tuple[list[dict[str, Any]], list[str]]:
    records: list[dict[str, Any]] = []
    problems: list[str] = []
    try:
        lake_manifest = json.loads((evmyul / "lake-manifest.json").read_text())
        packages = lake_manifest["packages"]
        if not isinstance(packages, list):
            raise ValueError("packages is not a list")
    except (OSError, KeyError, ValueError, json.JSONDecodeError) as error:
        return records, [f"could not audit lake-manifest.json ({error})"]
    for package in packages:
        if not isinstance(package, dict) or not isinstance(package.get("name"), str):
            problems.append("lake manifest has a malformed package entry")
            continue
        name = package["name"]
        package_path = evmyul / ".lake" / "packages" / name
        state = capture_git_state(package_path)
        expected_revision = package.get("rev")
        package_problems: list[str] = []
        if not isinstance(expected_revision, str) or re.fullmatch(r"[0-9a-f]{40}", expected_revision) is None:
            package_problems.append("manifest revision is not a full Git commit")
        if state.get("available") is not True:
            package_problems.append("package checkout Git state is unavailable")
        elif state.get("head") != expected_revision:
            package_problems.append(
                f"package HEAD {state.get('head')} differs from manifest revision {expected_revision}"
            )
        if state.get("clean") is not True:
            package_problems.append("package checkout has modified or untracked source inputs")
        records.append(
            {
                "name": name,
                "expected_revision": expected_revision,
                "git": state,
                "release_eligible": not package_problems,
                "problems": package_problems,
            }
        )
        problems.extend(f"Lake package {name}: {problem}" for problem in package_problems)
    return records, problems


def verify_evmyul_checkout(evmyul: Path, manifest: dict[str, Any]) -> tuple[dict[str, Any], list[str]]:
    problems: list[str] = []
    if not (evmyul / "lakefile.lean").exists() and not (evmyul / "lakefile.toml").exists():
        return {}, [f"EVMYUL_DIR={evmyul} is not a Lake project"]

    source_state = capture_git_state(evmyul)
    release_problems: list[str] = []
    if source_state.get("clean") is not True:
        release_problems.append("EVMYulLean checkout is not a clean source tree at gate start")

    commit_result = run(["git", "rev-parse", "HEAD"], cwd=evmyul)
    commit = commit_result.stdout.strip()
    expected_commit = manifest["toolchain"]["evmyullean_commit"]
    if commit_result.returncode != 0 or commit != expected_commit:
        problems.append(f"EVMYulLean HEAD is {commit or 'unavailable'}; expected {expected_commit}")

    toolchain_path = evmyul / "lean-toolchain"
    toolchain = toolchain_path.read_text().strip() if toolchain_path.exists() else "unavailable"
    expected_toolchain = manifest["toolchain"]["lean_toolchain"]
    if toolchain != expected_toolchain:
        problems.append(f"Lean toolchain is {toolchain!r}; expected {expected_toolchain!r}")

    lake_version = run(["lake", "--version"], cwd=evmyul)
    if lake_version.returncode != 0:
        problems.append(f"could not run lake --version: {lake_version.stderr.strip()}")
    packages, package_problems = _lake_package_provenance(evmyul)
    release_problems.extend(package_problems)
    return {
        "evmyullean_commit": commit,
        "lean_toolchain": toolchain,
        "lake": (lake_version.stdout or lake_version.stderr).strip(),
        "source_start": source_state,
        "packages": packages,
        "build": None,
        "release_eligible": not release_problems,
        "problems": release_problems,
    }, problems


def prepare_evmyul_build(evmyul: Path, provenance: dict[str, Any]) -> list[str]:
    """Refresh checked caches and rebuild EVMYul itself before importing any proof."""
    commands = [
        ["lake", "exe", "cache", "get"],
        ["lake", "clean"],
        ["lake", "build", "EvmYul"],
    ]
    command_records: list[dict[str, Any]] = []
    build_problems: list[str] = []
    for command in commands:
        completed = run(command, cwd=evmyul)
        command_records.append(
            {
                "command": command,
                "exitcode": completed.returncode,
                "stdout_sha256": hashlib.sha256(completed.stdout.encode()).hexdigest(),
                "stderr_sha256": hashlib.sha256(completed.stderr.encode()).hexdigest(),
            }
        )
        if completed.returncode != 0:
            build_problems.append(
                f"EVMYulLean preparation {' '.join(command)} failed with exit code {completed.returncode}"
            )
            break
    source_end = capture_git_state(evmyul)
    packages_end, package_end_problems = _lake_package_provenance(evmyul)
    output_tree = dependency_tree_state(evmyul / ".lake" / "build")
    if source_end.get("clean") is not True:
        build_problems.append("EVMYulLean source tree changed or became dirty during clean build")
    if package_end_problems:
        build_problems.extend(package_end_problems)
    if packages_end != provenance.get("packages"):
        build_problems.append("Lake package source provenance changed during preparation")
    if output_tree.get("available") is not True:
        build_problems.append("EVMYulLean build output tree could not be hashed")
    provenance["source_after_build"] = source_end
    provenance["packages_after_build"] = packages_end
    provenance["build"] = {
        "mode": "cache-refresh-clean-build-in-process",
        "commands": command_records,
        "output_tree": output_tree,
    }
    provenance["problems"].extend(build_problems)
    provenance["release_eligible"] = not provenance["problems"]
    return build_problems


def write_report(path: Path, report: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=MANIFEST_PATH)
    parser.add_argument("--report-output", type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    repo = FV_DIR.parents[1]
    generation_start = capture_git_state(repo)
    try:
        manifest_bytes = args.manifest.read_bytes()
        manifest = json.loads(manifest_bytes)
        if type(manifest.get("schema_version")) is not int or manifest.get("schema_version") != 1:
            raise ValueError("unsupported verification manifest schema")
        lean_manifest = manifest["lean"]
        allowed_axioms = set(lean_manifest["allowed_axioms"])
    except (OSError, KeyError, json.JSONDecodeError) as error:
        print(f"[lean-fv] FAIL: could not load verification manifest ({error})")
        return 1

    evmyul = Path(os.environ.get("EVMYUL_DIR", "/tmp/evmyul2")).resolve()
    toolchain, all_problems = verify_evmyul_checkout(evmyul, manifest)

    expected_refinement = set(STANDALONE + [INTEGRATION])
    actual_refinement = {path.name for path in REFINEMENT_DIR.glob("*.lean")}
    if actual_refinement != expected_refinement:
        all_problems.append(
            f"Lean file inventory differs: missing={sorted(expected_refinement - actual_refinement)}, "
            f"unexpected={sorted(actual_refinement - expected_refinement)}"
        )

    sources: dict[str, tuple[Path, dict[str, Any]]] = {}
    for name in [ABSTRACT] + STANDALONE + [INTEGRATION]:
        source_path = LEAN_DIR / name if name == ABSTRACT else REFINEMENT_DIR / name
        try:
            record, problems = source_audit(source_path, lean_manifest)
        except (OSError, ValueError) as error:
            record, problems = {}, [f"{name}: source audit failed ({error})"]
        sources[name] = (source_path, record)
        all_problems.extend(problems)

    report_files: dict[str, Any] = {}
    if not all_problems:
        build_problems = prepare_evmyul_build(evmyul, toolchain)
        all_problems.extend(build_problems)

    if not all_problems:
        for name, (source_path, _) in sources.items():
            shutil.copy(source_path, evmyul / name)

        for name in [ABSTRACT] + STANDALONE:
            print(f"[lean-fv] checking {name} ...", flush=True)
            source_path, source_record = sources[name]
            completed = run(["lake", "env", "lean", name], cwd=evmyul)
            record, problems = audit_lean_output(source_path, completed, source_record, allowed_axioms)
            report_files[name] = record
            all_problems.extend(problems)

        library = evmyul / ".lake" / "build" / "lib" / "lean"
        library.mkdir(parents=True, exist_ok=True)
        for dependency in INTEGRATION_DEPS:
            compiled = run(
                ["lake", "env", "lean", f"{dependency}.lean", "-o", str(library / f"{dependency}.olean")],
                cwd=evmyul,
            )
            if compiled.returncode != 0:
                all_problems.append(
                    f"{dependency}: integration dependency build failed (exit {compiled.returncode}): "
                    f"{compiled.stderr[-400:]}"
                )

        print(f"[lean-fv] checking {INTEGRATION} ...", flush=True)
        source_path, source_record = sources[INTEGRATION]
        completed = run(["lake", "env", "lean", INTEGRATION], cwd=evmyul)
        record, problems = audit_lean_output(source_path, completed, source_record, allowed_axioms)
        report_files[INTEGRATION] = record
        all_problems.extend(problems)

    generation = finalize_generation_provenance(repo, generation_start)
    report = {
        "schema_version": 1,
        "gate": "relay-lean",
        "status": "pass" if not all_problems else "fail",
        "release_eligible": (
            not all_problems
            and generation["release_eligible"] is True
            and toolchain.get("release_eligible") is True
        ),
        "git_commit": report_commit(generation),
        "manifest_sha256": hashlib.sha256(manifest_bytes).hexdigest(),
        "generation_provenance": generation,
        "inputs": {
            "evmyullean": toolchain,
            "release_eligible": toolchain.get("release_eligible") is True,
            "problems": toolchain.get("problems", []),
        },
        "toolchain": toolchain,
        "allowed_axioms": sorted(allowed_axioms),
        "files": report_files,
        "summary": {
            "files_expected": 1 + len(STANDALONE) + 1,
            "files_checked": len(report_files),
            "axiom_audits": sum(len(record.get("emitted_axiom_audits", [])) for record in report_files.values()),
            "violations": len(all_problems),
        },
        "violations": all_problems,
    }
    if args.report_output:
        write_report(args.report_output, report)

    if all_problems:
        print("\n[lean-fv] FAIL:")
        for problem in all_problems:
            print("  -", problem)
        return 1
    print(
        f"\n[lean-fv] PASS: {len(report_files)} files and {report['summary']['axiom_audits']} "
        "declared axiom audits checked against the pinned semantics."
    )
    if args.report_output:
        print(f"[lean-fv] report: {args.report_output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
