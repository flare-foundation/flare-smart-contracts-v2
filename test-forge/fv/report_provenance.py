#!/usr/bin/env python3
"""Shared fail-closed generation provenance for normalized FV reports."""

from __future__ import annotations

import hashlib
import os
import re
import stat
import subprocess
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
GENERATED_MODE = "generated-in-process"
IMPORTED_MODE = "imported-results"
DIAGNOSTIC_MODE = "diagnostic-overrides"


def capture_git_state(repo: Path) -> dict[str, Any]:
    """Capture whether the complete checkout is the clean committed HEAD."""
    try:
        head_result = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=repo,
            capture_output=True,
            check=False,
        )
        status_result = subprocess.run(
            ["git", "status", "--porcelain=v1", "--untracked-files=all"],
            cwd=repo,
            capture_output=True,
            check=False,
        )
    except OSError as error:
        return {
            "available": False,
            "head": "unknown",
            "clean": False,
            "status_sha256": None,
            "status_entries": None,
            "error": str(error),
        }

    head = head_result.stdout.decode("ascii", errors="replace").strip()
    status = status_result.stdout
    available = (
        head_result.returncode == 0
        and status_result.returncode == 0
        and re.fullmatch(r"[0-9a-f]{40}", head) is not None
    )
    return {
        "available": available,
        "head": head if head else "unknown",
        "clean": available and not status,
        "status_sha256": hashlib.sha256(status).hexdigest(),
        "status_entries": len(status.splitlines()),
        "head_exitcode": head_result.returncode,
        "status_exitcode": status_result.returncode,
    }


def build_generation_provenance(
    start: dict[str, Any],
    end: dict[str, Any],
    *,
    mode: str = GENERATED_MODE,
) -> dict[str, Any]:
    """Classify evidence without allowing dirty/imported inputs to be promoted later."""
    reasons: list[str] = []
    if mode != GENERATED_MODE:
        reasons.append("results-were-not-generated-in-process")
    for phase, state in (("start", start), ("end", end)):
        if state.get("available") is not True:
            reasons.append(f"git-state-unavailable-at-{phase}")
        elif state.get("clean") is not True:
            reasons.append(f"worktree-dirty-at-{phase}")
    if (
        start.get("available") is True
        and end.get("available") is True
        and start.get("head") != end.get("head")
    ):
        reasons.append("head-changed-during-generation")
    return {
        "schema_version": SCHEMA_VERSION,
        "mode": mode,
        "start": start,
        "end": end,
        "release_eligible": not reasons,
        "development_reasons": reasons,
    }


def finalize_generation_provenance(
    repo: Path,
    start: dict[str, Any],
    *,
    mode: str = GENERATED_MODE,
) -> dict[str, Any]:
    return build_generation_provenance(start, capture_git_state(repo), mode=mode)


def report_commit(provenance: dict[str, Any]) -> str:
    head = provenance.get("start", {}).get("head")
    return head if isinstance(head, str) and re.fullmatch(r"[0-9a-f]{40}", head) else "unknown"


def _hash_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        while block := source.read(1024 * 1024):
            digest.update(block)
    return digest.hexdigest()


def dependency_tree_state(root: Path) -> dict[str, Any]:
    """Hash every installed dependency path, type, executable bit, link, and file byte."""
    digest = hashlib.sha256()
    counts = {"files": 0, "directories": 0, "symlinks": 0}

    def frame(kind: bytes, relative: str, payload: bytes = b"") -> None:
        path_bytes = relative.encode("utf-8")
        digest.update(kind)
        digest.update(len(path_bytes).to_bytes(8, "big"))
        digest.update(path_bytes)
        digest.update(len(payload).to_bytes(8, "big"))
        digest.update(payload)

    def visit(directory: Path, prefix: str) -> None:
        with os.scandir(directory) as entries:
            ordered = sorted(entries, key=lambda item: os.fsencode(item.name))
        for entry in ordered:
            relative = f"{prefix}/{entry.name}" if prefix else entry.name
            metadata = entry.stat(follow_symlinks=False)
            if stat.S_ISLNK(metadata.st_mode):
                counts["symlinks"] += 1
                frame(b"L", relative, os.fsencode(os.readlink(entry.path)))
            elif stat.S_ISDIR(metadata.st_mode):
                counts["directories"] += 1
                frame(b"D", relative)
                visit(Path(entry.path), relative)
            elif stat.S_ISREG(metadata.st_mode):
                counts["files"] += 1
                executable = b"1" if metadata.st_mode & 0o111 else b"0"
                path_bytes = relative.encode("utf-8")
                digest.update(b"F")
                digest.update(len(path_bytes).to_bytes(8, "big"))
                digest.update(path_bytes)
                digest.update(executable)
                digest.update(metadata.st_size.to_bytes(8, "big"))
                with open(entry.path, "rb") as source:
                    while block := source.read(1024 * 1024):
                        digest.update(block)
            else:
                raise ValueError(f"unsupported dependency filesystem entry: {entry.path}")

    try:
        if not root.is_dir():
            raise ValueError(f"dependency root is missing: {root}")
        visit(root, "")
        return {
            "available": True,
            "root": root.name,
            "tree_sha256": digest.hexdigest(),
            **counts,
            "error": None,
        }
    except (OSError, UnicodeError, ValueError) as error:
        return {
            "available": False,
            "root": root.name,
            "tree_sha256": None,
            **counts,
            "error": str(error),
        }


def clean_install_soldeer(repo: Path, forge: str) -> tuple[dict[str, Any], list[str]]:
    """Replace ignored dependencies from the checksummed lock before proof inputs are read."""
    lock_path = repo / "soldeer.lock"
    problems: list[str] = []
    try:
        lock_before = _hash_file(lock_path)
    except OSError as error:
        lock_before = None
        problems.append(f"could not hash soldeer.lock before install ({error})")
    command = [forge, "soldeer", "install", "--clean"]
    try:
        completed = subprocess.run(
            command,
            cwd=repo,
            capture_output=True,
            text=True,
            check=False,
        )
        exitcode: int | None = completed.returncode
        stdout_hash = hashlib.sha256(completed.stdout.encode()).hexdigest()
        stderr_hash = hashlib.sha256(completed.stderr.encode()).hexdigest()
    except OSError as error:
        exitcode = None
        stdout_hash = None
        stderr_hash = None
        problems.append(f"could not execute clean Soldeer install ({error})")
    else:
        if exitcode != 0:
            problems.append(f"clean Soldeer install failed with exit code {exitcode}")
    try:
        lock_after = _hash_file(lock_path)
    except OSError as error:
        lock_after = None
        problems.append(f"could not hash soldeer.lock after install ({error})")
    if lock_before != lock_after:
        problems.append("clean Soldeer install changed soldeer.lock")
    tree = dependency_tree_state(repo / "dependencies")
    if tree["available"] is not True:
        problems.append(f"could not hash clean dependency tree ({tree['error']})")
    record = {
        "mode": "clean-install-in-process",
        "command": command,
        "exitcode": exitcode,
        "stdout_sha256": stdout_hash,
        "stderr_sha256": stderr_hash,
        "lock_path": "soldeer.lock",
        "lock_sha256_before": lock_before,
        "lock_sha256_after": lock_after,
        "tree_after_install": tree,
        "tree_at_end": None,
        "stable_during_gate": None,
        "release_eligible": False,
        "problems": [],
    }
    record["problems"] = list(problems)
    return record, problems


def finalize_soldeer(repo: Path, record: dict[str, Any]) -> list[str]:
    end = dependency_tree_state(repo / "dependencies")
    record["tree_at_end"] = end
    start = record.get("tree_after_install")
    stable = (
        isinstance(start, dict)
        and start.get("available") is True
        and end.get("available") is True
        and start.get("tree_sha256") == end.get("tree_sha256")
        and start.get("files") == end.get("files")
        and start.get("directories") == end.get("directories")
        and start.get("symlinks") == end.get("symlinks")
    )
    record["stable_during_gate"] = stable
    problems = list(record.get("problems", []))
    if not stable:
        problems.append("installed Soldeer dependency tree changed during gate execution")
    record["problems"] = problems
    record["release_eligible"] = not problems
    return problems
