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


def bytecode_bytes(value: str, label: str) -> bytes:
    if not isinstance(value, str) or not re.fullmatch(r"0x[0-9a-fA-F]*", value) or len(value) % 2:
        raise ValueError(f"{label} is not canonical 0x-prefixed bytecode")
    return bytes.fromhex(value[2:])


def strip_cbor_metadata(value: str, label: str = "bytecode") -> tuple[bytes, int]:
    raw = bytecode_bytes(value, label)
    if len(raw) < 2:
        raise ValueError(f"{label} is too short to contain a CBOR length suffix")
    metadata_length = int.from_bytes(raw[-2:], "big")
    suffix_length = metadata_length + 2
    if suffix_length >= len(raw):
        raise ValueError(f"{label} has invalid CBOR metadata length {metadata_length}")
    metadata = raw[-suffix_length:-2]
    if not metadata or metadata[0] & 0xE0 != 0xA0:
        raise ValueError(f"{label} suffix is not a CBOR map")
    return raw[:-suffix_length], suffix_length


def sha256(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def summarize_bytecode(value: str, label: str) -> dict[str, Any]:
    raw = bytecode_bytes(value, label)
    semantic, metadata_bytes = strip_cbor_metadata(value, label)
    return {
        "bytes": len(raw),
        "metadata_bytes": metadata_bytes,
        "full_sha256": sha256(raw),
        "semantic_bytes": len(semantic),
        "semantic_sha256": sha256(semantic),
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
    return {
        "source_sha256": sha256(source_path.read_bytes()),
        "compiler": foundry_compiler(metadata),
        "abi_sha256": canonical_abi_hash(artifact["abi"]),
        "creation": summarize_bytecode(artifact["bytecode"]["object"], "FV creation bytecode"),
        "runtime": summarize_bytecode(artifact["deployedBytecode"]["object"], "FV runtime bytecode"),
    }


def compare_artifacts(
    deployment: dict[str, Any],
    verification: dict[str, Any],
    manifest: dict[str, Any],
) -> list[str]:
    problems: list[str] = []
    target = manifest["target"]
    if deployment.get("schema_version") != 1 or deployment.get("status") != "pass":
        problems.append("deployment provenance report is not a passing schema-version-1 report")
    if deployment.get("source") != target["source"] or deployment.get("contract") != target["contract"]:
        problems.append("deployment provenance report identifies the wrong source or contract")

    for side, actual, expected in (
        ("deployment", deployment.get("compiler", {}), target["deployment_compiler"]),
        ("verification", verification.get("compiler", {}), target["verification_compiler"]),
    ):
        for key, value in expected.items():
            if key == "short_version":
                continue
            if actual.get(key) != value:
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


def forge_version(forge: str) -> str:
    completed = subprocess.run([forge, "--version"], capture_output=True, text=True, check=False)
    if completed.returncode != 0:
        raise RuntimeError(f"could not run {forge} --version: {completed.stderr.strip()}")
    match = re.search(r"forge Version: ([0-9]+\.[0-9]+\.[0-9]+)", completed.stdout)
    if not match:
        raise RuntimeError(f"could not parse Forge version from: {completed.stdout.strip()}")
    return match.group(1)


def build_verification_artifact(manifest: dict[str, Any], forge: str, work: Path) -> tuple[Path, Path]:
    target = manifest["target"]
    compiler = target["verification_compiler"]
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
        "--extra-output-files",
        "irOptimized",
    ]
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
    try:
        manifest = json.loads(args.manifest.read_text())
        deployment = json.loads(args.deployment_report.read_text())
        version = forge_version(args.forge)
        expected_foundry = manifest["toolchain"]["foundry"]
        if version != expected_foundry:
            raise RuntimeError(f"Forge version is {version}; expected pinned {expected_foundry}")

        with tempfile.TemporaryDirectory(prefix="relay-fv-artifact-") as directory:
            if bool(args.verification_artifact) != bool(args.verification_ir):
                raise RuntimeError("--verification-artifact and --verification-ir must be supplied together")
            if args.verification_artifact:
                artifact_path, generated_ir_path = args.verification_artifact, args.verification_ir
            else:
                artifact_path, generated_ir_path = build_verification_artifact(
                    manifest, args.forge, Path(directory)
                )
            source_path = REPO_ROOT / manifest["target"]["source"]
            verification = analyze_foundry_artifact(artifact_path, source_path)
            problems = compare_artifacts(deployment, verification, manifest)
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
            report = {
                "schema_version": 1,
                "gate": "relay-artifact-parity",
                "status": "pass" if not problems else "fail",
                "foundry_version": version,
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
            if args.report_output:
                print(f"[relay-artifact] report: {args.report_output}")
            return 0
    except (OSError, ValueError, KeyError, json.JSONDecodeError, RuntimeError) as error:
        print(f"[relay-artifact] FAIL: {error}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
