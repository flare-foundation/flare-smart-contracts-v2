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
DEFAULT_REPORTS = (
    "verification-reports/relay-deployment.json",
    "verification-reports/relay-artifact-parity.json",
    "verification-reports/relay-halmos.json",
    "verification-reports/relay-lean.json",
)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git(args: list[str]) -> str:
    result = subprocess.run(["git", *args], cwd=REPO, capture_output=True, text=True, check=False)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "git command failed")
    return result.stdout.strip()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--report", type=Path, action="append", dest="reports")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    reports = [Path(item) for item in (args.reports or DEFAULT_REPORTS)]
    try:
        manifest_bytes = args.manifest.read_bytes()
        manifest = json.loads(manifest_bytes)
        if manifest.get("schema_version") != 1:
            raise ValueError("unsupported verification manifest schema")
        evidence: list[dict[str, Any]] = []
        for report in reports:
            path = report if report.is_absolute() else REPO / report
            data = json.loads(path.read_text())
            if data.get("status") != "pass":
                raise ValueError(f"evidence report is not passing: {path}")
            evidence.append({"path": str(path.relative_to(REPO)), "sha256": digest(path)})
        output = {
            "schema_version": 1,
            "gate": "relay-fv-bundle",
            "status": "pass",
            "repository": {
                "commit": git(["rev-parse", "HEAD"]),
                "worktree": git(["status", "--porcelain"]),
            },
            "manifest": {"path": str(args.manifest), "sha256": hashlib.sha256(manifest_bytes).hexdigest()},
            "evidence": evidence,
        }
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n")
        print(f"[fv-bundle] PASS: {len(evidence)} reports recorded in {args.output}")
        return 0
    except (OSError, ValueError, json.JSONDecodeError, RuntimeError) as error:
        print(f"[fv-bundle] FAIL: {error}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
