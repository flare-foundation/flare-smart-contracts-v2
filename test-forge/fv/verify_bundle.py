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
import subprocess
import sys
from pathlib import Path
from typing import Any


HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
DEFAULT_MANIFEST = HERE / "verification-manifest.json"
EXPECTED_REPORTS = (
    ("verification-reports/relay-deployment.json", "relay-deployment-artifact"),
    ("verification-reports/relay-revert-abi.json", "relay-revert-abi"),
    ("verification-reports/relay-artifact-parity.json", "relay-artifact-parity"),
    ("verification-reports/relay-gss-governance.json", "relay-gss-governance"),
    ("verification-reports/gss-source-safe.json", "gss-source-safe"),
    ("verification-reports/relay-halmos.json", "relay-halmos"),
    ("verification-reports/relay-lean.json", "relay-lean"),
    ("verification-reports/relay-certora-local.json", "relay-certora-local"),
)
DEFAULT_REPORTS = tuple(path for path, _ in EXPECTED_REPORTS)
EXPECTED_GATES = tuple(gate for _, gate in EXPECTED_REPORTS)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git(args: list[str]) -> str:
    result = subprocess.run(["git", *args], cwd=REPO, capture_output=True, text=True, check=False)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "git command failed")
    return result.stdout.strip()


def collect_evidence(
    reports: list[Path], manifest_sha256: str, repository_commit: str
) -> list[dict[str, Any]]:
    evidence: list[dict[str, Any]] = []
    by_gate: dict[str, dict[str, Any]] = {}
    for report in reports:
        path = report if report.is_absolute() else REPO / report
        data = json.loads(path.read_text())
        gate = data.get("gate")
        if data.get("schema_version") != 1:
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
        by_gate[gate] = data
        try:
            display_path = str(path.resolve().relative_to(REPO.resolve()))
        except ValueError:
            display_path = str(path.resolve())
        evidence.append({"path": display_path, "gate": gate, "sha256": digest(path)})

    missing = sorted(set(EXPECTED_GATES) - set(by_gate))
    if missing:
        raise ValueError("missing required evidence gates: " + ", ".join(missing))
    deployment = by_gate["relay-deployment-artifact"]
    if by_gate["relay-artifact-parity"].get("deployment") != deployment:
        raise ValueError("artifact-parity report is not bound to the supplied deployment report")
    return evidence


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--report", type=Path, action="append", dest="reports")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument(
        "--allow-dirty",
        action="store_true",
        help="permit a development bundle, marked release_eligible=false, from a dirty checkout",
    )
    args = parser.parse_args()
    reports = [Path(item) for item in (args.reports or DEFAULT_REPORTS)]
    try:
        manifest_bytes = args.manifest.read_bytes()
        manifest = json.loads(manifest_bytes)
        if manifest.get("schema_version") != 1:
            raise ValueError("unsupported verification manifest schema")
        manifest_sha256 = hashlib.sha256(manifest_bytes).hexdigest()
        repository_commit = git(["rev-parse", "HEAD"])
        worktree = git(["status", "--porcelain"])
        if worktree and not args.allow_dirty:
            raise ValueError("working tree is dirty; commit the reviewed inputs or use --allow-dirty for development only")
        evidence = collect_evidence(reports, manifest_sha256, repository_commit)
        output = {
            "schema_version": 1,
            "gate": "relay-fv-bundle",
            "status": "pass",
            "release_eligible": not bool(worktree),
            "repository": {
                "commit": repository_commit,
                "worktree": worktree,
            },
            "manifest": {"path": str(args.manifest), "sha256": manifest_sha256},
            "evidence": evidence,
        }
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n")
        qualifier = "release eligible" if not worktree else "development only; dirty checkout"
        print(f"[fv-bundle] PASS ({qualifier}): {len(evidence)} reports recorded in {args.output}")
        return 0
    except (OSError, ValueError, json.JSONDecodeError, RuntimeError) as error:
        print(f"[fv-bundle] FAIL: {error}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
