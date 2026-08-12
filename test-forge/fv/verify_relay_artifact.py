#!/usr/bin/env python3
"""Bind the pinned FV compiler output to the Hardhat deployment artifact."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any


FV_DIR = Path(__file__).resolve().parent
REPO_ROOT = FV_DIR.parents[1]
DEFAULT_MANIFEST = FV_DIR / "verification-manifest.json"
if str(FV_DIR) not in sys.path:
    sys.path.insert(0, str(FV_DIR))
from report_provenance import (  # noqa: E402
    GENERATED_MODE,
    IMPORTED_MODE,
    capture_git_state,
    clean_install_soldeer,
    finalize_soldeer,
    finalize_generation_provenance,
    report_commit,
)
from verify_relay_custom_error_abi import keccak256  # noqa: E402


def bytecode_bytes(value: str, label: str) -> bytes:
    if not isinstance(value, str) or not re.fullmatch(r"0x[0-9a-fA-F]*", value) or len(value) % 2:
        raise ValueError(f"{label} is not canonical 0x-prefixed bytecode")
    return bytes.fromhex(value[2:])


def strip_cbor_metadata(value: str, label: str = "bytecode") -> tuple[bytes, int, int, int]:
    raw = bytecode_bytes(value, label)
    if len(raw) < 2:
        raise ValueError(f"{label} is too short to contain a CBOR length suffix")
    for end in range(len(raw), 1, -1):
        metadata_length = int.from_bytes(raw[end - 2:end], "big")
        start = end - metadata_length - 2
        if start <= 0:
            continue
        metadata = raw[start:end - 2]
        if not metadata or metadata[0] & 0xE0 != 0xA0:
            continue
        if end != len(raw) and b"solc" not in metadata:
            continue
        semantic = raw[:start] + raw[end:]
        return semantic, metadata_length + 2, start, len(raw) - end
    raise ValueError(f"{label} has no valid Solidity CBOR metadata segment")


def strip_embedded_cbor_metadata(
    value: str, runtime_suffix: bytes, label: str
) -> tuple[bytes, int, int, int]:
    # The legacy codegen pipeline places the runtime object (and thus its CBOR metadata suffix)
    # at the very end of the creation bytecode; via_ir emits constructor code after the embedded
    # runtime, so the metadata sits mid-stream. Excise the runtime's exact suffix bytes wherever
    # they occur. Mirrors stripEmbeddedCborMetadata in scripts/relay-artifact-provenance.js.
    raw = bytecode_bytes(value, label)
    if not runtime_suffix:
        raise ValueError(f"{label} was given an empty runtime CBOR metadata suffix")
    count = raw.count(runtime_suffix)
    if count == 0:
        raise ValueError(f"{label} does not embed the runtime CBOR metadata suffix")
    first_offset = raw.find(runtime_suffix)
    last_end = raw.rfind(runtime_suffix) + len(runtime_suffix)
    return (
        raw.replace(runtime_suffix, b""),
        len(runtime_suffix) * count,
        first_offset,
        len(raw) - last_end,
    )


def sha256(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def summarize_bytecode(
    value: str, label: str, runtime_suffix: bytes | None = None
) -> dict[str, Any]:
    raw = bytecode_bytes(value, label)
    if runtime_suffix is None:
        semantic, metadata_bytes, metadata_offset, trailing_bytes = strip_cbor_metadata(value, label)
    else:
        semantic, metadata_bytes, metadata_offset, trailing_bytes = strip_embedded_cbor_metadata(
            value, runtime_suffix, label
        )
    return {
        "bytes": len(raw),
        "metadata_bytes": metadata_bytes,
        "full_sha256": sha256(raw),
        "semantic_bytes": len(semantic),
        "semantic_sha256": sha256(semantic),
        "metadata_offset": metadata_offset,
        "trailing_bytes": trailing_bytes,
    }


def canonical_abi_hash(value: list[dict[str, Any]]) -> str:
    entries = [json.dumps(entry, separators=(",", ":"), sort_keys=True) for entry in value]
    encoded = ("[" + ",".join(sorted(entries)) + "]").encode()
    return sha256(encoded)


def foundry_compiler(metadata: dict[str, Any]) -> dict[str, Any]:
    settings = metadata["settings"]
    optimizer = settings["optimizer"]
    return {
        "version": metadata["compiler"]["version"],
        "evm_version": settings["evmVersion"],
        "optimizer_enabled": optimizer["enabled"],
        "optimizer_runs": optimizer["runs"],
        "via_ir": settings.get("viaIR", False),
    }


def analyze_foundry_artifact(path: Path, source_path: Path) -> dict[str, Any]:
    artifact = json.loads(path.read_text())
    metadata = artifact.get("metadata")
    if not isinstance(metadata, dict):
        raise ValueError(f"{path}: Foundry metadata object is missing")
    source_key = source_path.resolve().relative_to(REPO_ROOT.resolve()).as_posix()
    source_bytes = source_path.read_bytes()
    metadata_source = metadata.get("sources", {}).get(source_key)
    expected_keccak = "0x" + keccak256(source_bytes).hex()
    if not isinstance(metadata_source, dict) or metadata_source.get("keccak256") != expected_keccak:
        actual = metadata_source.get("keccak256") if isinstance(metadata_source, dict) else None
        raise ValueError(
            f"{path}: compiler metadata source hash is {actual!r}; current {source_key} is {expected_keccak}"
        )
    runtime_object = artifact["deployedBytecode"]["object"]
    runtime_raw = bytecode_bytes(runtime_object, "FV runtime bytecode")
    _, runtime_suffix_length, runtime_offset, _ = strip_cbor_metadata(
        runtime_object, "FV runtime bytecode"
    )
    runtime_suffix = runtime_raw[runtime_offset : runtime_offset + runtime_suffix_length]
    return {
        "source_sha256": sha256(source_bytes),
        "source_keccak256": expected_keccak,
        "compiler": foundry_compiler(metadata),
        "abi_sha256": canonical_abi_hash(artifact["abi"]),
        "creation": summarize_bytecode(
            artifact["bytecode"]["object"],
            "FV creation bytecode",
            runtime_suffix=runtime_suffix,
        ),
        "runtime": summarize_bytecode(runtime_object, "FV runtime bytecode"),
    }


def compare_artifacts(
    deployment: dict[str, Any],
    verification: dict[str, Any],
    manifest: dict[str, Any],
) -> list[str]:
    problems: list[str] = []
    target = manifest["target"]
    if type(deployment.get("schema_version")) is not int or deployment.get("schema_version") != 1 or deployment.get("status") != "pass":
        problems.append("deployment provenance report is not a passing schema-version-1 report")
    if deployment.get("source") != target["source"] or deployment.get("contract") != target["contract"]:
        problems.append("deployment provenance report identifies the wrong source or contract")

    expected_compiler = target["production_compiler"]
    for side, actual in (
        ("deployment", deployment.get("compiler", {})),
        ("verification", verification.get("compiler", {})),
    ):
        for key, value in expected_compiler.items():
            if key == "short_version":
                continue
            if type(actual.get(key)) is not type(value) or actual.get(key) != value:
                problems.append(f"{side} compiler {key} is {actual.get(key)!r}; expected {value!r}")

    for field in ("source_sha256", "abi_sha256"):
        if deployment.get(field) != verification.get(field):
            problems.append(f"{field} differs between deployment and verification artifacts")
    for section in ("creation", "runtime"):
        deployed_hash = deployment.get(section, {}).get("semantic_sha256")
        verified_hash = verification.get(section, {}).get("semantic_sha256")
        if deployed_hash != verified_hash:
            problems.append(
                f"{section} semantic bytecode differs: deployment={deployed_hash}, verification={verified_hash}"
            )
    return problems


def forge_version(forge: str) -> dict[str, str]:
    completed = subprocess.run([forge, "--version"], capture_output=True, text=True, check=False)
    if completed.returncode != 0:
        raise RuntimeError(f"could not run {forge} --version: {completed.stderr.strip()}")
    version = re.search(r"^forge Version:\s*(\S+)", completed.stdout, re.MULTILINE)
    commit = re.search(r"^Commit SHA:\s*([0-9a-f]{40})", completed.stdout, re.MULTILINE)
    if not version or not commit:
        raise RuntimeError(f"could not parse Forge version from: {completed.stdout.strip()}")
    return {"version": version.group(1), "commit": commit.group(1)}


def build_verification_artifact(manifest: dict[str, Any], forge: str, work: Path) -> tuple[Path, Path]:
    target = manifest["target"]
    compiler = target["production_compiler"]
    out = work / "out"
    cache = work / "cache"
    command = [
        forge,
        "build",
        target["source"],
        "--use",
        compiler["short_version"],
        "--no-auto-detect",
        "--out",
        str(out),
        "--cache-path",
        str(cache),
        "--force",
        "--quiet",
        "--evm-version",
        compiler["evm_version"],
        "--extra-output-files",
        "irOptimized",
    ]
    if compiler["optimizer_enabled"]:
        command.extend(["--optimize", "--optimizer-runs", str(compiler["optimizer_runs"])])
    if compiler["via_ir"]:
        command.append("--via-ir")
    completed = subprocess.run(command, cwd=REPO_ROOT, capture_output=True, text=True, check=False)
    if completed.returncode != 0:
        raise RuntimeError(
            "pinned FV artifact build failed:\n" + (completed.stdout + "\n" + completed.stderr).strip()
        )
    artifact = out / Path(target["source"]).name / f"{target['contract']}.json"
    if not artifact.exists():
        raise RuntimeError(f"pinned FV build did not produce {artifact}")
    optimized_ir = out / Path(target["source"]).name / f"{target['contract']}.iropt"
    if not optimized_ir.exists():
        raise RuntimeError(f"pinned FV build did not produce {optimized_ir}")
    return artifact, optimized_ir


def write_report(path: Path, report: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")


def verification_input_mode(artifact: Path | None, optimized_ir: Path | None) -> str:
    if bool(artifact) != bool(optimized_ir):
        raise ValueError("--verification-artifact and --verification-ir must be supplied together")
    return IMPORTED_MODE if artifact is not None else GENERATED_MODE


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--deployment-report", type=Path, required=True)
    parser.add_argument("--verification-artifact", type=Path)
    parser.add_argument("--verification-ir", type=Path)
    parser.add_argument("--report-output", type=Path)
    parser.add_argument("--forge", default=os.environ.get("FORGE", "forge"))
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    generation_start = capture_git_state(REPO_ROOT)
    try:
        manifest_bytes = args.manifest.read_bytes()
        manifest = json.loads(manifest_bytes)
        deployment = json.loads(args.deployment_report.read_text())
        foundry = forge_version(args.forge)
        expected_foundry = manifest["toolchain"]["foundry"]
        for field in ("version", "commit"):
            if foundry[field] != expected_foundry[field]:
                raise RuntimeError(
                    f"Forge {field} is {foundry[field]!r}; expected {expected_foundry[field]!r}"
                )
        ci_image = os.environ.get("FV_FOUNDRY_IMAGE")
        if ci_image is not None and ci_image != expected_foundry["image"]:
            raise RuntimeError(
                f"FV_FOUNDRY_IMAGE is {ci_image!r}; expected {expected_foundry['image']!r}"
            )

        input_mode = verification_input_mode(args.verification_artifact, args.verification_ir)
        imported = input_mode == IMPORTED_MODE
        dependency_record: dict[str, Any] | None = None
        dependency_problems: list[str] = []
        if not imported:
            dependency_record, dependency_problems = clean_install_soldeer(REPO_ROOT, args.forge)
            if dependency_problems:
                raise RuntimeError("clean Soldeer preparation failed: " + "; ".join(dependency_problems))
        with tempfile.TemporaryDirectory(prefix="relay-fv-artifact-") as directory:
            if args.verification_artifact:
                artifact_path, generated_ir_path = args.verification_artifact, args.verification_ir
            else:
                artifact_path, generated_ir_path = build_verification_artifact(
                    manifest, args.forge, Path(directory)
                )
            source_path = REPO_ROOT / manifest["target"]["source"]
            verification = analyze_foundry_artifact(artifact_path, source_path)
            problems = compare_artifacts(deployment, verification, manifest)
            if dependency_record is not None:
                problems.extend(finalize_soldeer(REPO_ROOT, dependency_record))
            manifest_hash = hashlib.sha256(manifest_bytes).hexdigest()
            if deployment.get("manifest_sha256") != manifest_hash:
                problems.append("deployment provenance report was produced from a different manifest")
            repository_commit = generation_start.get("head", "unknown")
            if deployment.get("git_commit") != repository_commit:
                problems.append("deployment provenance report was produced from a different Git commit")
            committed_ir_path = REPO_ROOT / manifest["target"]["optimized_ir_snapshot"]
            generated_ir = generated_ir_path.read_bytes()
            committed_ir = committed_ir_path.read_bytes()
            if generated_ir != committed_ir:
                problems.append(
                    "committed optimized Yul snapshot differs from the pinned verification compiler output"
                )
            ir_record = {
                "path": manifest["target"]["optimized_ir_snapshot"],
                "generated_sha256": sha256(generated_ir),
                "committed_sha256": sha256(committed_ir),
                "identical": generated_ir == committed_ir,
            }
            generation = finalize_generation_provenance(
                REPO_ROOT,
                generation_start,
                mode=input_mode,
            )
            repository_commit = report_commit(generation)
            report = {
                "schema_version": 1,
                "gate": "relay-artifact-parity",
                "status": "pass" if not problems else "fail",
                "release_eligible": (
                    not problems
                    and generation["release_eligible"] is True
                    and dependency_record is not None
                    and dependency_record["release_eligible"] is True
                ),
                "git_commit": repository_commit,
                "manifest_sha256": manifest_hash,
                "generation_provenance": generation,
                "inputs": {
                    "mode": input_mode,
                    "soldeer": dependency_record,
                    "release_eligible": (
                        not imported
                        and dependency_record is not None
                        and dependency_record["release_eligible"] is True
                    ),
                    "problems": dependency_problems,
                },
                "foundry": {**foundry, "ci_image": ci_image},
                "deployment": deployment,
                "verification": verification,
                "optimized_ir": ir_record,
                "violations": problems,
            }
            if args.report_output:
                write_report(args.report_output, report)

            if problems:
                print("[relay-artifact] FAIL:")
                for problem in problems:
                    print("  -", problem)
                return 1
            print("[relay-artifact] PASS: deployment and FV semantic bytecode are identical")
            print(f"[relay-artifact] creation sha256 {verification['creation']['semantic_sha256']}")
            print(f"[relay-artifact] runtime sha256  {verification['runtime']['semantic_sha256']}")
            print(f"[relay-artifact] IR sha256       {ir_record['generated_sha256']}")
            if imported:
                print(
                    "[relay-artifact] DEVELOPMENT ONLY: imported artifact/IR inputs cannot enter "
                    "a release bundle"
                )
            if args.report_output:
                print(f"[relay-artifact] report: {args.report_output}")
            return 0
    except (OSError, ValueError, KeyError, json.JSONDecodeError, RuntimeError) as error:
        print(f"[relay-artifact] FAIL: {error}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
