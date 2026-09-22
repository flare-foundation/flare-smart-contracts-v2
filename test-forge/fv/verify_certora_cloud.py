#!/usr/bin/env python3
"""Normalize imported Certora cloud results without promoting incomplete evidence.

The Certora CLI's human-readable output interleaves aggregate rule results with
progress messages and sanity-check witness queries.  In particular, a raw
``Violated: ...-rule_not_vacuous`` line is normally evidence that a rule is
*not* vacuous, not a property failure.  This gate therefore consumes only the
authoritative ``Result for ...`` blocks and binds them to the exact submission
archive produced by the CLI.

Cloud logs are imported evidence: even a complete successful report is never
release-eligible merely because this parser ran in a clean checkout.  A
SANITY_FAIL yields ``partial``, and every missing, unknown, failed, timed-out,
stale, or structurally ambiguous result yields ``fail``.
"""

from __future__ import annotations

import argparse
import hashlib
import hmac
import json
import re
import subprocess
import sys
import tarfile
import zipfile
from collections import Counter
from pathlib import Path, PurePosixPath
from typing import Any, Iterable
from urllib.parse import urlsplit


HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
DEFAULT_MANIFEST = HERE / "verification-manifest.json"
DEFAULT_REPORT = REPO / "verification-reports/relay-certora-cloud.json"
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))
from report_provenance import (  # noqa: E402
    IMPORTED_MODE,
    capture_git_state,
    finalize_generation_provenance,
    report_commit,
)


SCHEMA_VERSION = 1
SUPPORTED_CERTORA_CLI = "8.16.1"
MINIMUM_JAVA_MAJOR = 21
ANSI_ESCAPE = re.compile(r"\x1b(?:\[[0-?]*[ -/]*[@-~]|\][^\x07]*(?:\x07|\x1b\\))")
JOB_URL = re.compile(
    r"https://prover\.certora\.com/output/(?P<user>[0-9]+)/(?P<job>[0-9a-f]{32})"
    r"(?:\?[^\s\x1b]*)?"
)
RESULT_HEADER = re.compile(
    r"^Result for (?P<rule>[A-Za-z_$][A-Za-z0-9_$.-]*):\s*(?P<body>.*)$"
)
DETAIL_HEADER = re.compile(r"^Results for (?P<rule>[A-Za-z_$][A-Za-z0-9_$.-]*):$")
TABLE_BORDER = re.compile(r"^\*[-*]+\*$")
TERMINAL_RESULT = re.compile(
    r"^(?:(?P<subject>.+):\s+)?(?P<status>[A-Z][A-Z0-9_]*)"
    r"(?::\s*(?P<detail>.*))?$"
)
KNOWN_STATUSES = {
    "SUCCESS",
    "SANITY_FAIL",
    "FAIL",
    "UNKNOWN",
    "TIMEOUT",
    "SKIPPED",
}
ALLOWED_AUXILIARY_RULES = {"envfreeFuncsStaticCheck"}
PROOF_SEMANTIC_FIELDS = {
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
NUMERIC_CONFIG_FIELDS = {"solc_optimize", "loop_iter", "hashing_length_bound"}
NON_SEMANTIC_CONFIG_FIELDS = {"msg", "short_output"}
MAX_ARCHIVE_BYTES = 128 * 1024 * 1024
MAX_MEMBER_BYTES = 16 * 1024 * 1024
MAX_BACKEND_ARCHIVE_BYTES = 128 * 1024 * 1024
MAX_BACKEND_MEMBER_BYTES = 64 * 1024 * 1024
MAX_BACKEND_TOTAL_BYTES = 1024 * 1024 * 1024
MAX_BACKEND_MEMBERS = 10_000
MAX_JOB_DATA_BYTES = 1024 * 1024
BACKEND_RESULTS_MEMBER = "TarName/Reports/Results.txt"
BACKEND_VERSION_MEMBER = "TarName/Reports/cvt_version.json"


class EvidenceError(ValueError):
    """Malformed or ambiguous imported evidence."""


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        while block := source.read(1024 * 1024):
            digest.update(block)
    return digest.hexdigest()


def canonical_relative_path(value: str, *, label: str) -> str:
    if not isinstance(value, str) or not value or "\\" in value:
        raise EvidenceError(f"{label} must be a nonempty POSIX repository path")
    path = PurePosixPath(value)
    if (
        path.is_absolute()
        or path.as_posix() != value
        or any(part in {"", ".", ".."} for part in path.parts)
    ):
        raise EvidenceError(
            f"{label} is not a canonical repository-relative path: {value!r}"
        )
    return path.as_posix()


def _clean_lines(log_text: str) -> list[str]:
    # splitlines handles the CLI's carriage-return progress spinner.  ANSI is
    # stripped before recognizing result lines and URLs.
    return [ANSI_ESCAPE.sub("", line).strip() for line in log_text.splitlines()]


def sanitized_log_sha256(log_text: str) -> str:
    tokens = re.findall(r"(?<=anonymousKey=)[^&\s\x1b]+", log_text)
    sanitized = log_text
    for token in set(tokens):
        sanitized = sanitized.replace(token, "<redacted>")
    return sha256_bytes(sanitized.encode())


def parse_job_identity(log_text: str) -> dict[str, str]:
    clean = ANSI_ESCAPE.sub("", log_text)
    identities = {
        (match.group("user"), match.group("job")) for match in JOB_URL.finditer(clean)
    }
    if len(identities) != 1:
        raise EvidenceError(
            "log must contain exactly one distinct Certora output user/job identity; "
            f"found {len(identities)}"
        )
    user_id, job_id = next(iter(identities))
    command_job_ids = set(re.findall(r"(?:^|\s)-DjobId=([0-9a-f]{32})(?:\s|$)", clean))
    command_user_ids = set(re.findall(r"(?:^|\s)-DuserId=([0-9]+)(?:\s|$)", clean))
    if command_job_ids != {job_id} or command_user_ids != {user_id}:
        raise EvidenceError(
            "log output URL is not bound to one matching remote prover command identity"
        )
    return {
        "user_id": user_id,
        "job_id": job_id,
        "url": f"https://prover.certora.com/output/{user_id}/{job_id}",
    }


def _load_unique_json(raw: bytes, *, label: str) -> dict[str, Any]:
    def unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
        result: dict[str, Any] = {}
        for key, value in pairs:
            if key in result:
                raise EvidenceError(f"{label} contains duplicate JSON key {key!r}")
            result[key] = value
        return result

    try:
        value = json.loads(raw, object_pairs_hook=unique_object)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise EvidenceError(f"{label} is not valid UTF-8 JSON") from error
    if not isinstance(value, dict):
        raise EvidenceError(f"{label} JSON root is not an object")
    return value


def _anonymous_key_from_log(log_text: str, job: dict[str, str]) -> str:
    clean = ANSI_ESCAPE.sub("", log_text)
    pattern = re.compile(
        r"https://prover\.certora\.com/output/"
        + re.escape(job["user_id"])
        + r"/"
        + re.escape(job["job_id"])
        + r"\?anonymousKey=([A-Za-z0-9._~-]{1,256})(?=\s|$)"
    )
    matches = pattern.findall(clean)
    if len(matches) != 1:
        raise EvidenceError(
            "cloud log must contain exactly one canonical anonymous report URL "
            "for backend-evidence binding"
        )
    return matches[0]


def _require_certora_url(value: Any, *, path: str, label: str) -> None:
    if not isinstance(value, str):
        raise EvidenceError(f"backend jobData {label} is not a string")
    try:
        parsed = urlsplit(value)
        port = parsed.port
    except ValueError as error:
        raise EvidenceError(f"backend jobData {label} is malformed") from error
    allowed_paths = {path, path + "/"} if label == "outputUrl" else {path}
    if (
        parsed.scheme != "https"
        or parsed.netloc != "prover.certora.com"
        or parsed.hostname != "prover.certora.com"
        or port is not None
        or parsed.path not in allowed_paths
        or parsed.query
        or parsed.fragment
    ):
        raise EvidenceError(
            f"backend jobData {label} is not the canonical URL for the cloud job"
        )


def _canonical_tar_name(value: str) -> str:
    if not value or "\\" in value or len(value) > 4096:
        raise EvidenceError("backend output archive has a malformed member path")
    path = PurePosixPath(value)
    if (
        path.is_absolute()
        or path.as_posix() != value
        or any(part in {"", ".", ".."} for part in path.parts)
        or (path.parts[0] if path.parts else None) != "TarName"
    ):
        raise EvidenceError(
            f"backend output archive has a noncanonical member path: {value!r}"
        )
    return path.as_posix()


def _read_backend_members(path: Path) -> tuple[bytes, bytes, str]:
    try:
        archive_size = path.stat().st_size
    except OSError as error:
        raise EvidenceError(f"could not stat backend output archive {path}") from error
    if archive_size <= 0 or archive_size > MAX_BACKEND_ARCHIVE_BYTES:
        raise EvidenceError("backend output archive has an invalid compressed size")

    selected: dict[str, bytes] = {}
    names: set[str] = set()
    directories: set[str] = set()
    total_size = 0
    member_count = 0
    archive_digest = hashlib.sha256()
    bytes_hashed = 0
    try:
        with path.open("rb") as compressed:
            while block := compressed.read(1024 * 1024):
                bytes_hashed += len(block)
                if bytes_hashed > MAX_BACKEND_ARCHIVE_BYTES:
                    raise EvidenceError(
                        "backend output archive exceeds the compressed size limit"
                    )
                archive_digest.update(block)
            if bytes_hashed != archive_size:
                raise EvidenceError(
                    "backend output archive changed while it was being bound"
                )
            compressed.seek(0)
            archive = tarfile.open(fileobj=compressed, mode="r|gz")
            for member in archive:
                member_count += 1
                if member_count > MAX_BACKEND_MEMBERS:
                    raise EvidenceError("backend output archive has too many members")
                name = _canonical_tar_name(member.name)
                if name in names:
                    raise EvidenceError(
                        f"backend output archive repeats member name: {name}"
                    )
                names.add(name)
                if not member.isfile() and not member.isdir():
                    raise EvidenceError(
                        f"backend output archive has a non-regular member: {name}"
                    )
                if member.isdir():
                    if member.size != 0:
                        raise EvidenceError(
                            f"backend output archive directory has data: {name}"
                        )
                    directories.add(name)
                    continue
                if member.size < 0 or member.size > MAX_BACKEND_MEMBER_BYTES:
                    raise EvidenceError(
                        f"backend output archive member is too large: {name}"
                    )
                total_size += member.size
                if total_size > MAX_BACKEND_TOTAL_BYTES:
                    raise EvidenceError(
                        "backend output archive expands beyond the audited size limit"
                    )
                if name not in {BACKEND_RESULTS_MEMBER, BACKEND_VERSION_MEMBER}:
                    continue
                if member.size > MAX_MEMBER_BYTES:
                    raise EvidenceError(f"backend evidence member is too large: {name}")
                stream = archive.extractfile(member)
                if stream is None:
                    raise EvidenceError(
                        f"could not read backend evidence member: {name}"
                    )
                data = stream.read(member.size + 1)
                if len(data) != member.size:
                    raise EvidenceError(
                        f"backend evidence member has a truncated payload: {name}"
                    )
                selected[name] = data
            archive.close()
    except (OSError, tarfile.TarError) as error:
        raise EvidenceError(f"could not read backend output archive {path}") from error

    if not {"TarName", "TarName/Reports"}.issubset(directories):
        raise EvidenceError("backend output archive is missing its canonical layout")
    missing = {BACKEND_RESULTS_MEMBER, BACKEND_VERSION_MEMBER} - selected.keys()
    if missing:
        raise EvidenceError(
            "backend output archive is missing required members: "
            + ", ".join(sorted(missing))
        )
    return (
        selected[BACKEND_RESULTS_MEMBER],
        selected[BACKEND_VERSION_MEMBER],
        archive_digest.hexdigest(),
    )


def audit_backend_detailed_tables(
    tables: dict[str, list[dict[str, Any]]],
    aggregate: dict[str, list[dict[str, Any]]],
) -> list[str]:
    problems: list[str] = []
    if set(tables) - set(aggregate) - {"all"}:
        problems.append(
            "backend Results has detailed tables for unknown rules: "
            + ", ".join(sorted(set(tables) - set(aggregate) - {"all"}))
        )
    if "all" not in tables:
        problems.append("backend Results is missing the comprehensive detailed table")
    for rule, occurrences in tables.items():
        if len(occurrences) != 1:
            problems.append(
                f"backend Results must contain exactly one detailed table for {rule}; "
                f"found {len(occurrences)}"
            )
            continue
        occurrence = occurrences[0]
        if not occurrence.get("complete"):
            problems.append(f"backend Results detailed table is truncated for {rule}")
        if not occurrence.get("records"):
            problems.append(f"backend Results detailed table is empty for {rule}")
    return problems


def load_backend_evidence(
    output_archive_path: Path,
    job_data_path: Path,
    *,
    job: dict[str, str],
    log_text: str,
    log_aggregate: dict[str, list[dict[str, Any]]],
) -> tuple[dict[str, list[dict[str, Any]]], dict[str, Any]]:
    """Load a backend artifact without ever persisting its anonymous token."""
    try:
        job_data_size = job_data_path.stat().st_size
        if job_data_size <= 0 or job_data_size > MAX_JOB_DATA_BYTES:
            raise EvidenceError("backend jobData has an invalid size")
        job_data_raw = job_data_path.read_bytes()
        if len(job_data_raw) != job_data_size or len(job_data_raw) > MAX_JOB_DATA_BYTES:
            raise EvidenceError("backend jobData changed while it was being bound")
    except OSError as error:
        raise EvidenceError(
            f"could not read backend jobData {job_data_path}"
        ) from error
    job_data = _load_unique_json(job_data_raw, label="backend jobData")

    if job_data.get("jobId") != job["job_id"]:
        raise EvidenceError("backend jobData jobId does not match the cloud log")
    if job_data.get("jobStatus") != "SUCCEEDED":
        raise EvidenceError("backend jobData status is not SUCCEEDED")
    sidecar_key = job_data.get("anonymousKey")
    if (
        not isinstance(sidecar_key, str)
        or re.fullmatch(r"[A-Za-z0-9._~-]{1,256}", sidecar_key) is None
    ):
        raise EvidenceError("backend jobData anonymous key is malformed")
    log_key = _anonymous_key_from_log(log_text, job)
    if not hmac.compare_digest(sidecar_key, log_key):
        raise EvidenceError(
            "backend jobData anonymous key does not match the original cloud log"
        )
    output_path = f"/output/{job['user_id']}/{job['job_id']}"
    zip_output_path = f"/v1/domain/jobs/{job['job_id']}/f/outputs"
    _require_certora_url(job_data.get("outputUrl"), path=output_path, label="outputUrl")
    _require_certora_url(
        job_data.get("zipOutputUrl"), path=zip_output_path, label="zipOutputUrl"
    )

    results_bytes, version_bytes, output_archive_sha256 = _read_backend_members(
        output_archive_path
    )
    try:
        results_text = results_bytes.decode("utf-8")
    except UnicodeDecodeError as error:
        raise EvidenceError("backend Results.txt is not UTF-8") from error
    version = _load_unique_json(version_bytes, label="backend cvt_version.json")
    version_tag = version.get("gitLastTag")
    if version_tag != SUPPORTED_CERTORA_CLI:
        raise EvidenceError(
            f"backend prover version tag must be exactly {SUPPORTED_CERTORA_CLI}"
        )

    backend_aggregate, aggregate_problems = parse_result_blocks(results_text)
    if aggregate_problems:
        raise EvidenceError(
            "backend Results has malformed aggregate outcomes: "
            + "; ".join(aggregate_problems)
        )
    if not _exact_json(backend_aggregate, log_aggregate):
        raise EvidenceError(
            "backend Results aggregate outcomes do not exactly match the original cloud log"
        )
    tables = parse_detailed_tables(results_text)
    table_problems = audit_backend_detailed_tables(tables, backend_aggregate)
    if table_problems:
        raise EvidenceError("; ".join(table_problems))

    sanitized_job_metadata = {
        "job_id": job["job_id"],
        "job_status": "SUCCEEDED",
        "output_path": output_path,
        "zip_output_path": zip_output_path,
        "anonymous_key_matches_log": True,
    }
    sanitized_bytes = json.dumps(
        sanitized_job_metadata, sort_keys=True, separators=(",", ":")
    ).encode()
    evidence = {
        "output_archive_path": str(output_archive_path),
        "output_archive_sha256": output_archive_sha256,
        "results_member": BACKEND_RESULTS_MEMBER,
        "results_sha256": sha256_bytes(results_bytes),
        "cvt_version_member": BACKEND_VERSION_MEMBER,
        "cvt_version_sha256": sha256_bytes(version_bytes),
        "certora_cli_tag": version_tag,
        "job_data_path": str(job_data_path),
        "sanitized_job_metadata": sanitized_job_metadata,
        "sanitized_job_metadata_sha256": sha256_bytes(sanitized_bytes),
        "aggregate_matches_log": True,
        "detailed_tables_complete": True,
    }
    return tables, evidence


def _parse_terminal(rule: str, body: str) -> dict[str, Any] | None:
    if body.startswith(f"{rule}: "):
        body = body[len(rule) + 2 :]
    match = TERMINAL_RESULT.fullmatch(body)
    if match is None:
        return None
    status = match.group("status")
    if status not in KNOWN_STATUSES:
        # Preserve it as an adverse result.  The caller reports the unrecognized
        # status explicitly and can never classify it as success.
        known = False
    else:
        known = True
    subject = match.group("subject")
    detail = match.group("detail")
    return {
        "subject": subject if subject else None,
        "status": status,
        "detail": detail if detail else None,
        "recognized_status": known,
    }


def parse_result_blocks(
    log_text: str,
) -> tuple[dict[str, list[dict[str, Any]]], list[str]]:
    """Parse only aggregate ``Result for`` blocks from Certora CLI output."""
    lines = _clean_lines(log_text)
    results: dict[str, list[dict[str, Any]]] = {}
    problems: list[str] = []
    index = 0
    while index < len(lines):
        header = RESULT_HEADER.fullmatch(lines[index])
        if header is None:
            index += 1
            continue
        rule = header.group("rule")
        if rule in results:
            problems.append(f"duplicate aggregate result block for rule {rule}")
        entries: list[dict[str, Any]] = []
        first = _parse_terminal(rule, header.group("body"))
        if first is not None:
            entries.append(first)
        index += 1
        terminated = False
        while index < len(lines):
            if RESULT_HEADER.fullmatch(lines[index]) is not None:
                terminated = True
                break
            entry = _parse_terminal(rule, lines[index])
            if entry is None:
                terminated = True
                break
            entries.append(entry)
            index += 1
        if not terminated:
            problems.append(
                f"aggregate result block for rule {rule} reaches EOF without a terminator"
            )
        if not entries:
            problems.append(
                f"aggregate result block for rule {rule} has no terminal outcomes"
            )
        subjects = [entry["subject"] for entry in entries]
        duplicates = sorted(
            "<standalone>" if subject is None else subject
            for subject, count in Counter(subjects).items()
            if count > 1
        )
        if duplicates:
            problems.append(
                f"aggregate result block for rule {rule} repeats subjects: "
                + ", ".join(duplicates)
            )
        for entry in entries:
            if not entry["recognized_status"]:
                problems.append(
                    f"rule {rule} has unrecognized terminal status {entry['status']!r}"
                )
        # Keep the first block so a later duplicate cannot overwrite adverse
        # evidence with a forged success block.
        results.setdefault(rule, entries)
    return results, problems


def _parse_table_records(
    rows: list[str], *, table_complete: bool
) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None
    terminal_labels = {
        "Not violated",
        "Violated",
        "Timeout",
        "Unknown",
        "Skipped",
    }
    for line in rows:
        if not line.startswith("|") or not line.endswith("|"):
            continue
        parts = line.split("|")
        if len(parts) != 7:
            continue
        name, verified, _time, description, local_vars = (
            part.strip() for part in parts[1:-1]
        )
        if verified in terminal_labels:
            if current is not None:
                current["complete"] = True
                records.append(current)
            current = {
                "name_parts": [name] if name else [],
                "verified": verified,
                "markers": [],
                "description_parts": [description] if description else [],
                "model_cells": [local_vars] if local_vars else [],
            }
            continue
        if current is None:
            continue
        if name:
            current["name_parts"].append(name)
        if verified:
            current["markers"].append(verified)
        if description:
            current["description_parts"].append(description)
        if local_vars:
            current["model_cells"].append(local_vars)
    if current is not None:
        current["complete"] = table_complete
        records.append(current)
    return [
        {
            "name": "".join(record["name_parts"]),
            "verified": record["verified"],
            "markers": record["markers"],
            "description": "".join(record["description_parts"]),
            "model_cells": record["model_cells"],
            "complete": record["complete"],
        }
        for record in records
    ]


def parse_detailed_tables(log_text: str) -> dict[str, list[dict[str, Any]]]:
    """Parse detailed CLI result tables, preserving completeness per occurrence."""
    lines = _clean_lines(log_text)
    tables: dict[str, list[dict[str, Any]]] = {}
    index = 0
    while index < len(lines):
        header = DETAIL_HEADER.fullmatch(lines[index])
        if header is None:
            index += 1
            continue
        rule = header.group("rule")
        index += 1
        while index < len(lines) and not lines[index]:
            index += 1
        if index >= len(lines) or TABLE_BORDER.fullmatch(lines[index]) is None:
            tables.setdefault(rule, []).append(
                {"complete": False, "records": [], "reason": "missing opening border"}
            )
            continue
        index += 1
        rows: list[str] = []
        complete = False
        while index < len(lines):
            if TABLE_BORDER.fullmatch(lines[index]) is not None:
                complete = True
                index += 1
                break
            if DETAIL_HEADER.fullmatch(lines[index]) is not None:
                break
            rows.append(lines[index])
            index += 1
        tables.setdefault(rule, []).append(
            {
                "complete": complete,
                "records": _parse_table_records(rows, table_complete=complete),
                "table_sha256": sha256_bytes("\n".join(rows).encode()),
                "reason": None if complete else "missing closing border",
            }
        )
    return tables


def _mask_cvl_comments(source: str) -> str:
    result = list(source)
    index = 0
    state = "code"
    while index < len(source):
        current = source[index]
        following = source[index + 1] if index + 1 < len(source) else ""
        if state == "code":
            if current == '"':
                state = "string"
            elif current == "/" and following == "/":
                result[index] = result[index + 1] = " "
                state = "line-comment"
                index += 1
            elif current == "/" and following == "*":
                result[index] = result[index + 1] = " "
                state = "block-comment"
                index += 1
        elif state == "string":
            if current == "\\":
                index += 1
            elif current == '"':
                state = "code"
        elif state == "line-comment":
            if current == "\n":
                state = "code"
            else:
                result[index] = " "
        else:
            if current == "*" and following == "/":
                result[index] = result[index + 1] = " "
                state = "code"
                index += 1
            elif current != "\n":
                result[index] = " "
        index += 1
    if state == "block-comment":
        raise EvidenceError("unterminated CVL block comment")
    return "".join(result)


def _cvl_brace_depth(source: str, start: int, end: int) -> int:
    depth = 0
    state = "code"
    index = start
    while index < end:
        current = source[index]
        if state == "code":
            if current == '"':
                state = "string"
            elif current == "{":
                depth += 1
            elif current == "}":
                depth -= 1
                if depth < 0:
                    raise EvidenceError("CVL rule has unbalanced braces")
        elif current == "\\":
            index += 1
        elif current == '"':
            state = "code"
        index += 1
    return depth


def _cvl_statement_end(source: str, start: int, limit: int) -> int | None:
    state = "code"
    index = start
    while index < limit:
        current = source[index]
        if state == "code":
            if current == '"':
                state = "string"
            elif current == ";":
                return index
        elif current == "\\":
            index += 1
        elif current == '"':
            state = "code"
        index += 1
    return None


def satisfy_expectations(spec_source: str, spec_path: str) -> list[dict[str, Any]]:
    """Derive Certora 8.16.1 satisfy subrule names from the submitted CVL source."""
    masked = _mask_cvl_comments(spec_source)
    rule_headers = list(
        re.finditer(r"(?m)^\s*rule\s+([A-Za-z_$][A-Za-z0-9_$]*)\b", masked)
    )
    spec_token = PurePosixPath(spec_path).name.replace(".", "_")
    expectations: list[dict[str, Any]] = []
    for satisfy in re.finditer(r"\bsatisfy\b", masked):
        parents = [
            header for header in rule_headers if header.start() < satisfy.start()
        ]
        if not parents:
            raise EvidenceError("CVL satisfy statement is not enclosed by a rule")
        parent = parents[-1]
        next_headers = [
            header for header in rule_headers if header.start() > satisfy.start()
        ]
        section_end = next_headers[0].start() if next_headers else len(masked)
        if _cvl_brace_depth(masked, parent.end(), satisfy.start()) <= 0:
            raise EvidenceError(
                "CVL satisfy statement is outside its associated rule body"
            )
        statement_end = _cvl_statement_end(masked, satisfy.end(), section_end)
        if statement_end is None:
            raise EvidenceError("CVL satisfy statement is unterminated within its rule")
        tail = masked[satisfy.end() : statement_end + 1]
        message_match = re.search(r',\s*("(?:\\.|[^"\\])*")\s*;$', tail, re.DOTALL)
        if message_match is None:
            raise EvidenceError(
                "CVL satisfy statement has no canonical message terminator"
            )
        try:
            message = json.loads(message_match.group(1))
        except json.JSONDecodeError as error:
            raise EvidenceError(
                "CVL satisfy message is not a valid string literal"
            ) from error
        line = masked.count("\n", 0, satisfy.start()) + 1
        previous_newline = masked.rfind("\n", 0, satisfy.start())
        column = satisfy.start() - previous_newline
        slug = re.sub(r"[^A-Za-z0-9_$]", "", re.sub(r"\s", "_", message))
        canonical = f"Satisfy_{slug}_({spec_token}_{line}_{column})"
        expectations.append(
            {
                "rule": parent.group(1),
                "name": canonical,
                "message": message,
                "line": line,
                "column": column,
            }
        )
    names = [expectation["name"] for expectation in expectations]
    if len(names) != len(set(names)):
        raise EvidenceError(
            "submitted CVL has duplicate canonical satisfy subrule names"
        )
    return expectations


def corroborate_satisfy_results(
    aggregate: dict[str, list[dict[str, Any]]],
    tables: dict[str, list[dict[str, Any]]],
    expectations: list[dict[str, Any]],
) -> list[str]:
    """Mark only exact, concretely witnessed satisfy FAILs as semantic success."""
    problems: list[str] = []
    expected = {(item["rule"], item["name"]): item for item in expectations}
    expected_names = {item["name"] for item in expectations}

    for rule, entries in aggregate.items():
        for entry in entries:
            subject = entry.get("subject")
            if isinstance(subject, str) and subject.startswith("Satisfy_"):
                if (rule, subject) not in expected:
                    problems.append(
                        f"aggregate has unconfigured or misassociated satisfy subrule {rule}:{subject}"
                    )
    table_parents: dict[str, set[str]] = {}
    for rule, occurrences in tables.items():
        # Certora's comprehensive presentation table repeats every row under
        # ``all``.  It is completeness-audited as backend evidence, but it is
        # not a semantic parent and cannot corroborate a satisfy witness.
        if rule == "all":
            continue
        for occurrence in occurrences:
            for record in occurrence["records"]:
                if record["name"].startswith("Satisfy_"):
                    table_parents.setdefault(record["name"], set()).add(rule)
                    if record["name"] not in expected_names:
                        problems.append(
                            f"detailed table has unconfigured satisfy subrule {rule}:{record['name']}"
                        )

    for key, expectation in expected.items():
        rule, name = key
        entries = [
            entry for entry in aggregate.get(rule, []) if entry.get("subject") == name
        ]
        if len(entries) != 1:
            problems.append(
                f"configured satisfy subrule {rule}:{name} has {len(entries)} aggregate outcomes"
            )
            continue
        entry = entries[0]
        if entry.get("status") != "FAIL":
            problems.append(
                f"configured satisfy subrule {rule}:{name} must have aggregate FAIL in Certora 8.16.1, "
                f"found {entry.get('status')!r}"
            )
            continue
        parents = table_parents.get(name, set())
        if parents != {rule}:
            problems.append(
                f"configured satisfy subrule {name} has ambiguous detailed-table parents: "
                + repr(sorted(parents))
            )
            continue
        occurrences = tables.get(rule, [])
        matching: list[dict[str, Any]] = []
        occurrence_problem = False
        for occurrence in occurrences:
            records = [
                record for record in occurrence["records"] if record["name"] == name
            ]
            if records:
                if not occurrence["complete"]:
                    problems.append(
                        f"detailed satisfy table occurrence is truncated for {rule}:{name}"
                    )
                    occurrence_problem = True
                if any(not record["complete"] for record in records):
                    problems.append(
                        f"detailed satisfy record is truncated for {rule}:{name}"
                    )
                    occurrence_problem = True
                if len(records) != 1:
                    problems.append(
                        f"detailed table repeats satisfy subrule within one occurrence: {rule}:{name}"
                    )
                    occurrence_problem = True
                matching.extend(records)
        if occurrence_problem:
            continue
        if not matching:
            problems.append(
                f"missing detailed satisfy table evidence for {rule}:{name}"
            )
            continue
        if len(matching) != 1:
            problems.append(
                f"detailed satisfy witness must occur exactly once for {rule}:{name}; "
                f"found {len(matching)}"
            )
            continue
        record = matching[0]
        if record["verified"] != "Not violated" or record["markers"] != ["(sat)"]:
            problems.append(
                f"detailed satisfy witness is not semantically SAT for {rule}:{name}"
            )
            continue
        assignments: list[str] = []
        for cell in record["model_cells"]:
            variable, separator, value = cell.partition("=")
            normalized_value = value.strip().lower()
            if (
                separator
                and variable.strip()
                and value.strip()
                and normalized_value not in {"?", "unknown", "<unknown>"}
            ):
                assignments.append(cell)
        if not assignments:
            problems.append(
                f"detailed satisfy witness has no concrete model for {rule}:{name}"
            )
            continue
        model_sha256 = sha256_bytes("\n".join(record["model_cells"]).encode())
        entry["semantic_status"] = "SATISFIED"
        entry["satisfy_witness"] = {
            "source": {
                "message": expectation["message"],
                "line": expectation["line"],
                "column": expectation["column"],
            },
            "detailed_marker": "sat",
            "concrete_assignments": len(assignments),
            "model_sha256": model_sha256,
            "table_occurrences": 1,
        }
    return problems


def classify_entries(entries: Iterable[dict[str, Any]]) -> str:
    statuses = [entry.get("semantic_status", entry.get("status")) for entry in entries]
    if not statuses or any(
        status not in KNOWN_STATUSES | {"SATISFIED"} for status in statuses
    ):
        return "fail"
    if any(status in {"FAIL", "UNKNOWN", "TIMEOUT", "SKIPPED"} for status in statuses):
        return "fail"
    if any(status == "SANITY_FAIL" for status in statuses):
        return "partial"
    return (
        "pass"
        if all(status in {"SUCCESS", "SATISFIED"} for status in statuses)
        else "fail"
    )


def combine_statuses(statuses: Iterable[str]) -> str:
    values = list(statuses)
    if not values or any(value == "fail" for value in values):
        return "fail"
    if any(value == "partial" for value in values):
        return "partial"
    return "pass" if all(value == "pass" for value in values) else "fail"


def _read_member(archive: zipfile.ZipFile, name: str) -> bytes:
    try:
        info = archive.getinfo(name)
    except KeyError as error:
        raise EvidenceError(f"submission archive is missing {name}") from error
    if info.file_size > MAX_MEMBER_BYTES:
        raise EvidenceError(f"submission archive member is too large: {name}")
    return archive.read(info)


def _read_json_member(
    archive: zipfile.ZipFile, name: str
) -> tuple[dict[str, Any], bytes]:
    raw = _read_member(archive, name)
    try:
        value = json.loads(raw)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise EvidenceError(
            f"submission archive member is not valid JSON: {name}"
        ) from error
    if not isinstance(value, dict):
        raise EvidenceError(f"submission archive JSON root is not an object: {name}")
    return value, raw


def _tree_digest(rows: Iterable[tuple[str, bytes]]) -> str:
    digest = hashlib.sha256()
    for name, data in sorted(rows):
        encoded = name.encode("utf-8")
        digest.update(len(encoded).to_bytes(8, "big"))
        digest.update(encoded)
        digest.update(len(data).to_bytes(8, "big"))
        digest.update(data)
    return digest.hexdigest()


def _current_binding(repo: Path, relative: str, submitted: bytes) -> dict[str, Any]:
    current_path = repo / relative
    try:
        current = current_path.read_bytes()
    except OSError:
        current = None
    return {
        "path": relative,
        "submitted_sha256": sha256_bytes(submitted),
        "current_sha256": sha256_bytes(current) if current is not None else None,
        "matches_current": current == submitted if current is not None else False,
    }


def _source_closure(
    archive: zipfile.ZipFile, repo: Path
) -> tuple[dict[str, Any], list[str]]:
    prefix = ".certora_sources/"
    rows: list[tuple[str, bytes]] = []
    mismatches: list[dict[str, Any]] = []
    problems: list[str] = []
    total = 0
    for info in archive.infolist():
        name = info.filename
        if info.is_dir() or not name.startswith(prefix):
            continue
        relative = name[len(prefix) :]
        if not relative or relative.startswith(
            (".pre_autofinders.", ".post_autofinders.", ".")
        ):
            continue
        first = PurePosixPath(relative).parts[0]
        if first not in {"certora", "contracts", "dependencies"} and relative not in {
            "foundry.toml",
            "package.json",
            "remappings.txt",
        }:
            continue
        canonical_relative_path(relative, label="archived source path")
        if info.file_size > MAX_MEMBER_BYTES:
            raise EvidenceError(f"submission source member is too large: {relative}")
        total += info.file_size
        if total > MAX_ARCHIVE_BYTES:
            raise EvidenceError("submission source closure is too large")
        data = archive.read(info)
        rows.append((relative, data))
        binding = _current_binding(repo, relative, data)
        if not binding["matches_current"]:
            mismatches.append(binding)
    if not rows:
        problems.append("submission archive has no repository source closure")
    if mismatches:
        problems.append(
            "submitted source closure differs from current checkout at: "
            + ", ".join(row["path"] for row in mismatches)
        )
    return {
        "files": len(rows),
        "submitted_tree_sha256": _tree_digest(rows),
        "matches_current": bool(rows) and not mismatches,
        "mismatches": mismatches,
    }, problems


def _integer(value: Any) -> int | None:
    if type(value) is int and value >= 0:
        return value
    if isinstance(value, str) and value.isdigit():
        return int(value)
    return None


def _exact_json(left: Any, right: Any) -> bool:
    if type(left) is not type(right):
        return False
    if isinstance(left, list):
        return len(left) == len(right) and all(
            _exact_json(first, second) for first, second in zip(left, right)
        )
    if isinstance(left, dict):
        return left.keys() == right.keys() and all(
            _exact_json(left[key], right[key]) for key in left
        )
    return left == right


def _semantic_value(field: str, value: Any) -> Any:
    if field not in NUMERIC_CONFIG_FIELDS:
        return value
    normalized = _integer(value)
    if normalized is None:
        return {"invalid_numeric_type": type(value).__name__, "value": repr(value)}
    return normalized


def _compiler_versions(value: Any) -> set[str]:
    versions: set[str] = set()
    if isinstance(value, dict):
        for key, child in value.items():
            if key == "compilerVersion" and isinstance(child, str):
                versions.add(child)
            else:
                versions.update(_compiler_versions(child))
    elif isinstance(value, list):
        for child in value:
            versions.update(_compiler_versions(child))
    return versions


def _solc_short_version(value: Any) -> str | None:
    if not isinstance(value, str):
        return None
    versions = set(re.findall(r"(?<![0-9])([0-9]+\.[0-9]+\.[0-9]+)(?![0-9])", value))
    return next(iter(versions)) if len(versions) == 1 else None


def audit_effective_config(
    source: dict[str, Any],
    effective: dict[str, Any],
    metadata: dict[str, Any],
    config_path: str,
    build: dict[str, Any],
) -> tuple[list[str], dict[str, Any]]:
    """Allow presentation flags and one validated solc-path substitution only."""
    problems: list[str] = []
    source_unknown = sorted(
        set(source) - PROOF_SEMANTIC_FIELDS - NON_SEMANTIC_CONFIG_FIELDS
    )
    effective_unknown = sorted(
        set(effective) - PROOF_SEMANTIC_FIELDS - NON_SEMANTIC_CONFIG_FIELDS
    )
    if source_unknown:
        problems.append(
            "source config has unaudited fields: " + ", ".join(source_unknown)
        )
    if effective_unknown:
        problems.append(
            "effective run config has unaudited fields: " + ", ".join(effective_unknown)
        )

    for field in sorted(PROOF_SEMANTIC_FIELDS - {"solc"}):
        source_value = _semantic_value(field, source.get(field))
        effective_value = _semantic_value(field, effective.get(field))
        if not _exact_json(source_value, effective_value):
            problems.append(
                f"CLI/effective proof-semantic override at {field}: "
                f"source={source.get(field)!r}, effective={effective.get(field)!r}"
            )

    raw_args = metadata.get("raw_args")
    solc_override: str | None = None
    short_output = False
    if (
        not isinstance(raw_args, list)
        or len(raw_args) < 2
        or not all(isinstance(argument, str) and argument for argument in raw_args)
        or Path(raw_args[0]).name != "certoraRun"
        or raw_args[1] != config_path
    ):
        problems.append(
            "submission metadata has malformed or mismatched raw CLI arguments"
        )
    else:
        index = 2
        while index < len(raw_args):
            argument = raw_args[index]
            if (
                argument == "--solc"
                and solc_override is None
                and index + 1 < len(raw_args)
            ):
                solc_override = raw_args[index + 1]
                index += 2
            elif argument == "--short_output" and not short_output:
                short_output = True
                index += 1
            else:
                problems.append(f"unaudited Certora CLI override: {argument}")
                index += 1
    if solc_override is None:
        if not _exact_json(source.get("solc"), effective.get("solc")):
            problems.append(
                "effective solc differs without an explicit --solc override"
            )
    elif effective.get("solc") != solc_override:
        problems.append("effective solc does not match the explicit --solc override")
    if short_output != (effective.get("short_output") is True):
        problems.append(
            "effective short_output does not match the presentation-only CLI flag"
        )
    if "short_output" in effective and type(effective.get("short_output")) is not bool:
        problems.append("effective short_output flag is not boolean")

    configured_version = _solc_short_version(source.get("solc"))
    effective_version = _solc_short_version(effective.get("solc"))
    compiled_versions = _compiler_versions(build)
    if configured_version is None:
        problems.append("source config solc has no unambiguous semantic version")
    if effective_version != configured_version:
        problems.append(
            f"effective solc version {effective_version!r} differs from configured "
            f"version {configured_version!r}"
        )
    if configured_version is None or compiled_versions != {configured_version}:
        problems.append(
            "submitted build compiler versions do not exactly match the configured solc: "
            + repr(sorted(compiled_versions))
        )
    compiler = {
        "configured": source.get("solc")
        if isinstance(source.get("solc"), str)
        else "unknown",
        "effective": effective.get("solc")
        if isinstance(effective.get("solc"), str)
        else "unknown",
        "compiled_versions": sorted(compiled_versions),
        "binary_sha256": None,
        "binary_hash_evidence": (
            "unavailable: the Certora submission archive records compiler output and "
            "short version, but does not embed the solc executable"
        ),
    }
    return problems, compiler


def _java_major(value: Any) -> int | None:
    if not isinstance(value, str):
        return None
    match = re.match(r"^([0-9]+)(?:[._+-]|$)", value)
    return int(match.group(1)) if match else None


def audit_manifest_binding(
    manifest: dict[str, Any], runs: list[dict[str, Any]]
) -> tuple[list[str], dict[str, Any]]:
    problems: list[str] = []
    settings = manifest.get("certora_local")
    if not isinstance(settings, dict):
        return ["manifest certora_local must be an object"], {}
    expected_cli = settings.get("certora_cli")
    if expected_cli != SUPPORTED_CERTORA_CLI:
        problems.append(
            f"manifest Certora CLI must be exactly {SUPPORTED_CERTORA_CLI}, "
            f"found {expected_cli!r}"
        )
    minimum_java = settings.get("minimum_java_major")
    if type(minimum_java) is not int or minimum_java < MINIMUM_JAVA_MAJOR:
        problems.append(
            f"manifest minimum_java_major must be an integer >= {MINIMUM_JAVA_MAJOR}"
        )
        minimum_java = MINIMUM_JAVA_MAJOR
    configs = settings.get("configs")
    actual_configs = [run.get("config") for run in runs]
    if (
        not isinstance(configs, list)
        or not configs
        or not all(isinstance(config, str) and config for config in configs)
        or len(configs) != len(set(configs))
        or configs != actual_configs
    ):
        problems.append(
            "cloud run config inventory/order differs from manifest: "
            f"manifest={configs!r}, runs={actual_configs!r}"
        )
        configs = configs if isinstance(configs, list) else []
    expectations = settings.get("config_expectations")
    if not isinstance(expectations, dict) or set(expectations) != set(configs):
        problems.append(
            "manifest config_expectations keys do not exactly match its config inventory"
        )
        expectations = expectations if isinstance(expectations, dict) else {}

    for run in runs:
        config = run.get("config")
        toolchain = run.get("toolchain")
        actual_cli = (
            toolchain.get("certora_cli") if isinstance(toolchain, dict) else None
        )
        if actual_cli != SUPPORTED_CERTORA_CLI or actual_cli != expected_cli:
            problems.append(
                f"{config}: submitted Certora CLI {actual_cli!r} does not match "
                f"required {SUPPORTED_CERTORA_CLI}"
            )
        evidence = run.get("evidence")
        backend = evidence.get("backend") if isinstance(evidence, dict) else None
        if isinstance(backend, dict) and backend.get("certora_cli_tag") != expected_cli:
            problems.append(
                f"{config}: backend prover version tag "
                f"{backend.get('certora_cli_tag')!r} does not match manifest CLI "
                f"{expected_cli!r}"
            )
        java = toolchain.get("java") if isinstance(toolchain, dict) else None
        java_major = _java_major(java)
        if java_major is None or java_major < minimum_java:
            problems.append(
                f"{config}: submitted Java {java!r} does not meet major >= {minimum_java}"
            )
        inputs = run.get("inputs")
        config_record = inputs.get("config") if isinstance(inputs, dict) else None
        submitted = (
            config_record.get("proof_semantics")
            if isinstance(config_record, dict)
            else None
        )
        expected = expectations.get(config)
        if not isinstance(expected, dict) or not _exact_json(submitted, expected):
            problems.append(
                f"{config}: submitted source config does not exactly match manifest expectation"
            )
    return problems, {
        "certora_cli": expected_cli,
        "minimum_java_major": minimum_java,
        "configs": configs,
    }


def model_bounds(effective: dict[str, Any], log_text: str) -> dict[str, Any]:
    explicit_hash_bound = _integer(effective.get("hashing_length_bound"))
    observed = {
        int(value)
        for value in re.findall(
            r'hashing_length_bound", current value is ([0-9]+)', log_text
        )
    }
    observed_hash_bound = next(iter(observed)) if len(observed) == 1 else None
    storage_values: list[bool] = []
    args = effective.get("prover_args")
    if isinstance(args, list):
        for arg in args:
            match = re.fullmatch(r"-enableStorageSplitting\s+(true|false)", str(arg))
            if match:
                storage_values.append(match.group(1) == "true")
    storage_splitting = storage_values[0] if len(storage_values) == 1 else None
    return {
        "loop_iterations": _integer(effective.get("loop_iter")),
        "optimistic_loop": effective.get("optimistic_loop")
        if type(effective.get("optimistic_loop")) is bool
        else None,
        "optimistic_hashing": effective.get("optimistic_hashing")
        if type(effective.get("optimistic_hashing")) is bool
        else False,
        "hashing_length_bound": explicit_hash_bound,
        "observed_implicit_hashing_length_bound": observed_hash_bound
        if explicit_hash_bound is None
        else None,
        "storage_splitting": storage_splitting,
        "solc_via_ir": effective.get("solc_via_ir")
        if type(effective.get("solc_via_ir")) is bool
        else None,
        "solc_optimize": _integer(effective.get("solc_optimize")),
        "solc_evm_version": effective.get("solc_evm_version")
        if isinstance(effective.get("solc_evm_version"), str)
        else None,
        "scope": (
            "loop paths assume the unwind condition after the configured iteration bound"
            if effective.get("optimistic_loop") is True
            else "loop unwinding is not marked optimistic"
        ),
        "hashing_scope": (
            f"optimistic hashing is sound only for hashed values of length at most "
            f"{explicit_hash_bound} bytes"
            if effective.get("optimistic_hashing") is True
            and explicit_hash_bound is not None
            else "optimistic unbounded hashing is disabled or has no explicit audited length bound"
        ),
    }


def prover_diagnostics(log_text: str) -> dict[str, Any]:
    """Retain fidelity-relevant warnings without mistaking them for rule outcomes."""
    lines = _clean_lines(log_text)
    unresolved = [
        line
        for line in lines
        if "Failed to locate an internal function called from" in line
    ]
    mismatched = [
        line
        for line in lines
        if "Detected an internal function but it's not matching" in line
    ]
    pointer = [
        line for line in lines if "Pointer analysis" in line and "failed" in line
    ]
    storage = [
        line for line in lines if "Storage analysis" in line and "failed" in line
    ]
    callers: set[str] = set()
    for line in unresolved:
        match = re.search(r"called from ([^:]+):", line)
        if match:
            callers.add(match.group(1))
    return {
        "internal_function_resolution_warning_lines": len(unresolved),
        "internal_function_mismatch_lines": len(mismatched),
        "affected_external_calls": sorted(callers),
        "pointer_analysis_failure_lines": len(pointer),
        "storage_analysis_failure_lines": len(storage),
        "interpretation": (
            "These are proof-fidelity diagnostics, not aggregate property outcomes; "
            "they require review alongside the normalized rule results."
        ),
    }


def _normalized_rule(rule: str, entries: list[dict[str, Any]]) -> dict[str, Any]:
    ordered = sorted(
        entries,
        key=lambda entry: (
            entry["subject"] is not None,
            entry["subject"] or "",
            entry["status"],
            entry["detail"] or "",
        ),
    )
    counts = Counter(entry["status"] for entry in ordered)
    semantic_counts = Counter(
        entry.get("semantic_status", entry["status"]) for entry in ordered
    )
    return {
        "rule": rule,
        "status": classify_entries(ordered),
        "entries": ordered,
        "summary": {
            "entries": len(ordered),
            "by_terminal_status": dict(sorted(counts.items())),
            "by_semantic_status": dict(sorted(semantic_counts.items())),
        },
    }


def _safe_archive(path: Path) -> zipfile.ZipFile:
    try:
        size = path.stat().st_size
    except OSError as error:
        raise EvidenceError(
            f"could not stat submission archive {path}: {error}"
        ) from error
    if size > MAX_ARCHIVE_BYTES:
        raise EvidenceError(f"submission archive is too large: {path}")
    try:
        archive = zipfile.ZipFile(path)
    except (OSError, zipfile.BadZipFile) as error:
        raise EvidenceError(
            f"could not read submission archive {path}: {error}"
        ) from error
    names = archive.namelist()
    if len(names) != len(set(names)):
        archive.close()
        raise EvidenceError("submission archive contains duplicate member names")
    return archive


def build_run(
    repo: Path,
    config_path: str,
    log_path: Path,
    archive_path: Path | None = None,
    backend_output_path: Path | None = None,
    backend_job_data_path: Path | None = None,
) -> dict[str, Any]:
    config_path = canonical_relative_path(config_path, label="config path")
    problems: list[str] = []
    try:
        log_bytes = log_path.read_bytes()
        log_text = log_bytes.decode("utf-8")
    except (OSError, UnicodeDecodeError) as error:
        raise EvidenceError(
            f"could not read UTF-8 cloud log {log_path}: {error}"
        ) from error
    job = parse_job_identity(log_text)
    if archive_path is None:
        archive_path = repo / ".certora_internal" / f"{job['job_id']}.zip"
    if archive_path.name != f"{job['job_id']}.zip":
        problems.append("submission archive filename does not match the log job id")

    parsed, parse_problems = parse_result_blocks(log_text)
    problems.extend(parse_problems)
    if (backend_output_path is None) != (backend_job_data_path is None):
        raise EvidenceError(
            "backend output archive and jobData sidecar must be supplied together"
        )
    backend_evidence: dict[str, Any] | None = None
    if backend_output_path is not None and backend_job_data_path is not None:
        detailed_tables, backend_evidence = load_backend_evidence(
            backend_output_path,
            backend_job_data_path,
            job=job,
            log_text=log_text,
            log_aggregate=parsed,
        )
    else:
        detailed_tables = parse_detailed_tables(log_text)

    with _safe_archive(archive_path) as archive:
        packaged_job_ids = {
            match.group(1)
            for name in archive.namelist()
            if (match := re.fullmatch(r"\.\./([0-9a-f]{32})_cli_debug_log\.zip", name))
        }
        if packaged_job_ids != {job["job_id"]}:
            problems.append(
                "submission archive does not contain exactly one matching packaged job id"
            )
        source_config_member = f".certora_sources/{config_path}"
        source_config, source_config_bytes = _read_json_member(
            archive, source_config_member
        )
        effective, effective_bytes = _read_json_member(
            archive, ".certora_sources/run.conf"
        )
        metadata, metadata_bytes = _read_json_member(archive, ".certora_metadata.json")
        build, build_bytes = _read_json_member(archive, ".certora_build.json")
        if not _exact_json(metadata.get("conf"), effective):
            problems.append("archive metadata.conf differs from the effective run.conf")
        if metadata.get("conf_path") != PurePosixPath(config_path).name:
            problems.append(
                "archive metadata conf_path differs from the requested config"
            )
        config_problems, compiler = audit_effective_config(
            source_config, effective, metadata, config_path, build
        )
        problems.extend(config_problems)

        verify = effective.get("verify")
        if not isinstance(verify, str) or verify.count(":") != 1:
            raise EvidenceError("effective Certora verify target is malformed")
        contract, spec_path = verify.split(":", 1)
        if not contract:
            raise EvidenceError("effective Certora verify target has no contract")
        spec_path = canonical_relative_path(spec_path, label="spec path")
        spec_bytes = _read_member(archive, f".certora_sources/{spec_path}")
        try:
            spec_source = spec_bytes.decode("utf-8")
        except UnicodeDecodeError as error:
            raise EvidenceError("submitted CVL spec is not UTF-8") from error
        if metadata.get("main_spec") != spec_path:
            problems.append(
                "archive metadata main_spec differs from the effective verify target"
            )

        expected_rules = effective.get("rule")
        if (
            not isinstance(expected_rules, list)
            or not expected_rules
            or not all(
                isinstance(rule, str)
                and re.fullmatch(r"[A-Za-z_$][A-Za-z0-9_$.-]*", rule)
                for rule in expected_rules
            )
            or len(expected_rules) != len(set(expected_rules))
        ):
            raise EvidenceError(
                "effective Certora rule inventory is not a unique nonempty list"
            )
        expected_set = set(expected_rules)
        missing = sorted(expected_set - parsed.keys())
        unexpected = sorted(parsed.keys() - expected_set - ALLOWED_AUXILIARY_RULES)
        if missing:
            problems.append(
                "cloud log is missing aggregate results for: " + ", ".join(missing)
            )
        if unexpected:
            problems.append(
                "cloud log has unexpected aggregate results for: "
                + ", ".join(unexpected)
            )

        satisfies = satisfy_expectations(spec_source, spec_path)
        satisfy_problems = corroborate_satisfy_results(
            parsed, detailed_tables, satisfies
        )
        problems.extend(satisfy_problems)

        rules = [
            _normalized_rule(rule, parsed[rule])
            for rule in expected_rules
            if rule in parsed
        ]
        auxiliary = [
            _normalized_rule(rule, parsed[rule])
            for rule in sorted(parsed.keys() & ALLOWED_AUXILIARY_RULES)
        ]
        closure, closure_problems = _source_closure(archive, repo)
        problems.extend(closure_problems)
        config_binding = _current_binding(repo, config_path, source_config_bytes)
        config_binding["proof_semantics"] = {
            field: source_config[field]
            for field in sorted(PROOF_SEMANTIC_FIELDS)
            if field in source_config
        }
        spec_binding = _current_binding(repo, spec_path, spec_bytes)

        revision = metadata.get("revision")
        if (
            not isinstance(revision, str)
            or re.fullmatch(r"[0-9a-f]{40}", revision) is None
        ):
            problems.append("submission metadata has no canonical Git revision")
            revision = "unknown"
        try:
            current_head = subprocess.run(
                ["git", "rev-parse", "HEAD"],
                cwd=repo,
                capture_output=True,
                text=True,
                check=False,
            ).stdout.strip()
        except OSError:
            current_head = "unknown"
        if revision != current_head:
            problems.append(
                f"submission revision {revision} differs from current HEAD {current_head}"
            )
        submission_dirty = metadata.get("dirty")
        if type(submission_dirty) is not bool:
            problems.append("submission metadata dirty flag is malformed")

        toolchain = {
            "certora_cli": metadata.get("CLI_version")
            if isinstance(metadata.get("CLI_version"), str)
            else "unknown",
            "java": metadata.get("java_version")
            if isinstance(metadata.get("java_version"), str)
            else "unknown",
            "solc": compiler,
        }
        source_closure_eligible = closure["matches_current"]
        input_problems = [
            problem
            for problem in problems
            if "result" not in problem
            and "terminal status" not in problem
            and "cloud log" not in problem
        ]
        if submission_dirty is True:
            input_problems.append(
                "Certora submission metadata records a dirty worktree"
            )
        inputs = {
            "release_eligible": not input_problems,
            "problems": input_problems,
            "submission": {
                "branch": metadata.get("branch")
                if isinstance(metadata.get("branch"), str)
                else "unknown",
                "revision": revision,
                "dirty": submission_dirty,
                "archive_path": str(archive_path),
                "archive_sha256": sha256_file(archive_path),
                "metadata_sha256": sha256_bytes(metadata_bytes),
                "effective_run_config_sha256": sha256_bytes(effective_bytes),
                "certora_build_sha256": sha256_bytes(build_bytes),
            },
            "config": config_binding,
            "spec": spec_binding,
            "source_closure": closure,
        }

    rule_statuses = [rule["status"] for rule in rules + auxiliary]
    proof_status = combine_statuses(rule_statuses)
    status = "fail" if problems else proof_status
    status_counts = Counter(
        entry["status"] for rule in rules + auxiliary for entry in rule["entries"]
    )
    semantic_counts = Counter(
        entry.get("semantic_status", entry["status"])
        for rule in rules + auxiliary
        for entry in rule["entries"]
    )
    return {
        "config": config_path,
        "contract": contract,
        "spec": spec_path,
        "status": status,
        "proof_status": proof_status,
        "job": job,
        "evidence": {
            "log_path": str(log_path),
            "sanitized_log_sha256": sanitized_log_sha256(log_text),
            "log_hash_scope": "UTF-8 cloud log with anonymousKey values redacted",
            "backend": backend_evidence,
            "aggregate_results_complete": not missing
            and not unexpected
            and not parse_problems
            and not satisfy_problems,
        },
        "toolchain": toolchain,
        "model_bounds": model_bounds(effective, log_text),
        "prover_diagnostics": prover_diagnostics(log_text),
        "inputs": inputs,
        "expected_rules": expected_rules,
        "rules": rules,
        "auxiliary_rules": auxiliary,
        "summary": {
            "rules_expected": len(expected_rules),
            "rules_reported": len(rules),
            "auxiliary_rules_reported": len(auxiliary),
            "terminal_entries": sum(status_counts.values()),
            "by_terminal_status": dict(sorted(status_counts.items())),
            "by_semantic_status": dict(sorted(semantic_counts.items())),
            "satisfy_witnesses": semantic_counts.get("SATISFIED", 0),
        },
        "problems": problems,
        "source_closure_matches_current": source_closure_eligible,
    }


def _failed_run(config_path: str, log_path: Path, error: Exception) -> dict[str, Any]:
    return {
        "config": config_path,
        "status": "fail",
        "proof_status": "fail",
        "evidence": {"log_path": str(log_path), "aggregate_results_complete": False},
        "rules": [],
        "auxiliary_rules": [],
        "problems": [str(error)],
    }


def digest_or_none(path: Path) -> str | None:
    try:
        return sha256_file(path)
    except OSError:
        return None


def build_report(
    repo: Path,
    runs: list[tuple[str, Path, Path | None]],
    manifest_path: Path,
    backend_evidence: dict[str, tuple[Path, Path]] | None = None,
) -> dict[str, Any]:
    start = capture_git_state(repo)
    normalized: list[dict[str, Any]] = []
    backend_evidence = backend_evidence or {}
    for config_path, log_path, archive_path in runs:
        try:
            backend_output, backend_job_data = backend_evidence.get(
                config_path, (None, None)
            )
            normalized.append(
                build_run(
                    repo,
                    config_path,
                    log_path,
                    archive_path,
                    backend_output,
                    backend_job_data,
                )
            )
        except (EvidenceError, OSError, tarfile.TarError, zipfile.BadZipFile) as error:
            normalized.append(_failed_run(config_path, log_path, error))
    provenance = finalize_generation_provenance(repo, start, mode=IMPORTED_MODE)
    status = combine_statuses(run["status"] for run in normalized)
    counts = Counter(
        entry["status"]
        for run in normalized
        for rule in run.get("rules", []) + run.get("auxiliary_rules", [])
        for entry in rule["entries"]
    )
    semantic_counts = Counter(
        entry.get("semantic_status", entry["status"])
        for run in normalized
        for rule in run.get("rules", []) + run.get("auxiliary_rules", [])
        for entry in rule["entries"]
    )
    input_problems = [
        f"{run['config']}: {problem}"
        for run in normalized
        for problem in run.get("inputs", {}).get("problems", [])
    ]
    inputs_eligible = bool(normalized) and all(
        run.get("inputs", {}).get("release_eligible") is True for run in normalized
    )
    top_problems = [
        f"{run['config']}: {problem}"
        for run in normalized
        for problem in run.get("problems", [])
    ]
    manifest_sha256 = digest_or_none(manifest_path)
    manifest_audit: dict[str, Any] = {
        "status": "fail",
        "expected": {},
        "problems": [],
    }
    if manifest_sha256 is None:
        manifest_problems = [f"verification manifest is unavailable: {manifest_path}"]
    else:
        try:
            manifest = json.loads(manifest_path.read_bytes())
            if not isinstance(manifest, dict):
                raise EvidenceError("verification manifest root must be an object")
            manifest_problems, manifest_expected = audit_manifest_binding(
                manifest, normalized
            )
            manifest_audit["expected"] = manifest_expected
        except (
            OSError,
            UnicodeDecodeError,
            json.JSONDecodeError,
            EvidenceError,
        ) as error:
            manifest_problems = [f"could not audit verification manifest: {error}"]
    manifest_audit["problems"] = manifest_problems
    manifest_audit["status"] = "pass" if not manifest_problems else "fail"
    if manifest_problems:
        input_problems.extend(manifest_problems)
        inputs_eligible = False
        top_problems.extend(manifest_problems)
        status = "fail"
    return {
        "schema_version": SCHEMA_VERSION,
        "gate": "relay-certora-cloud",
        "status": status,
        "release_eligible": provenance["release_eligible"] and inputs_eligible,
        "git_commit": report_commit(provenance),
        "manifest_sha256": manifest_sha256,
        "manifest_audit": manifest_audit,
        "generation_provenance": provenance,
        "inputs": {
            "release_eligible": inputs_eligible,
            "problems": input_problems,
        },
        "runs": normalized,
        "summary": {
            "runs_expected": len(runs),
            "runs_reported": len(normalized),
            "runs_pass": sum(run["status"] == "pass" for run in normalized),
            "runs_partial": sum(run["status"] == "partial" for run in normalized),
            "runs_fail": sum(run["status"] == "fail" for run in normalized),
            "terminal_entries": sum(counts.values()),
            "by_terminal_status": dict(sorted(counts.items())),
            "by_semantic_status": dict(sorted(semantic_counts.items())),
            "satisfy_witnesses": semantic_counts.get("SATISFIED", 0),
        },
        "problems": top_problems,
    }


def parse_run_argument(value: str) -> tuple[str, Path, Path | None]:
    parts = value.split("=")
    if len(parts) not in {2, 3} or any(not part for part in parts):
        raise argparse.ArgumentTypeError("run must be CONFIG=LOG or CONFIG=LOG=ARCHIVE")
    try:
        config = canonical_relative_path(parts[0], label="config path")
    except EvidenceError as error:
        raise argparse.ArgumentTypeError(str(error)) from error
    return config, Path(parts[1]), Path(parts[2]) if len(parts) == 3 else None


def parse_backend_argument(value: str) -> tuple[str, Path, Path]:
    parts = value.split("=")
    if len(parts) != 3 or any(not part for part in parts):
        raise argparse.ArgumentTypeError(
            "backend evidence must be CONFIG=OUTPUT_ARCHIVE=JOB_DATA"
        )
    try:
        config = canonical_relative_path(parts[0], label="config path")
    except EvidenceError as error:
        raise argparse.ArgumentTypeError(str(error)) from error
    return config, Path(parts[1]), Path(parts[2])


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--run",
        action="append",
        type=parse_run_argument,
        required=True,
        metavar="CONFIG=LOG[=ARCHIVE]",
        help="bind one cloud log to its submitted Certora config and optional job ZIP",
    )
    parser.add_argument(
        "--backend-evidence",
        action="append",
        type=parse_backend_argument,
        default=[],
        metavar="CONFIG=OUTPUT_ARCHIVE=JOB_DATA",
        help=(
            "optionally bind a run to a downloaded backend output archive and its "
            "jobData sidecar"
        ),
    )
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--report", type=Path, default=DEFAULT_REPORT)
    args = parser.parse_args(argv)
    configs = [config for config, _, _ in args.run]
    if len(configs) != len(set(configs)):
        parser.error("each Certora config may be supplied only once")
    backend_configs = [config for config, _, _ in args.backend_evidence]
    if len(backend_configs) != len(set(backend_configs)):
        parser.error("each Certora config may have only one backend evidence pair")
    unknown_backend_configs = sorted(set(backend_configs) - set(configs))
    if unknown_backend_configs:
        parser.error(
            "backend evidence has no matching --run for: "
            + ", ".join(unknown_backend_configs)
        )
    backend_by_config = {
        config: (output_archive, job_data)
        for config, output_archive, job_data in args.backend_evidence
    }
    report = build_report(
        REPO, args.run, args.manifest, backend_evidence=backend_by_config
    )
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    print(
        f"Certora cloud report: {report['status'].upper()} "
        f"({report['summary']['runs_pass']} pass, "
        f"{report['summary']['runs_partial']} partial, "
        f"{report['summary']['runs_fail']} fail)"
    )
    for run in report["runs"]:
        job = run.get("job", {})
        suffix = f" [{job.get('url')}]" if job.get("url") else ""
        print(f"  {run['config']}: {run['status'].upper()}{suffix}")
        for problem in run.get("problems", []):
            print(f"    - {problem}")
    print(f"Wrote {args.report}")
    return 0 if report["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
