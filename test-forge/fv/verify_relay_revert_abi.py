#!/usr/bin/env python3
"""Verify Relay.relay()'s legacy Error(string) assembly ABI."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from collections import Counter
from pathlib import Path
from typing import Any


HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
DEFAULT_MANIFEST = HERE / "verification-manifest.json"
IDENTIFIER = re.compile(r"\b[A-Za-z_$][A-Za-z0-9_$]*\b")


def mask_comments(source: str) -> str:
    """Replace comments with spaces while preserving byte offsets and strings."""
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
                index += 2
                continue
            if current == quote:
                state = "code"
        index += 1
    if state == "block-comment":
        raise ValueError("unterminated block comment")
    if state == "string":
        raise ValueError("unterminated string literal")
    return "".join(result)


def split_arguments(arguments: str) -> list[str]:
    parts: list[str] = []
    start = 0
    depth = 0
    quote = ""
    index = 0
    while index < len(arguments):
        current = arguments[index]
        if quote:
            if current == "\\":
                index += 2
                continue
            if current == quote:
                quote = ""
        elif current in {'"', "'"}:
            quote = current
        elif current in "([{":
            depth += 1
        elif current in ")]}":
            depth -= 1
            if depth < 0:
                raise ValueError("unbalanced delimiter in helper call")
        elif current == "," and depth == 0:
            parts.append(arguments[start:index].strip())
            start = index + 1
        index += 1
    if quote or depth:
        raise ValueError("unterminated literal or delimiter in helper call")
    parts.append(arguments[start:].strip())
    return parts


def call_end(source: str, opening: int) -> int:
    depth = 1
    quote = ""
    index = opening + 1
    while index < len(source):
        current = source[index]
        if quote:
            if current == "\\":
                index += 2
                continue
            if current == quote:
                quote = ""
        elif current in {'"', "'"}:
            quote = current
        elif current == "(":
            depth += 1
        elif current == ")":
            depth -= 1
            if depth == 0:
                return index
        index += 1
    raise ValueError("unterminated revertWithMessage call")


def decode_string_literal(token: str) -> bytes:
    if len(token) < 2 or token[0] != '"' or token[-1] != '"':
        raise ValueError("message must be one double-quoted literal")
    body = token[1:-1]
    output = bytearray()
    escapes = {
        '"': b'"',
        "'": b"'",
        "\\": b"\\",
        "n": b"\n",
        "r": b"\r",
        "t": b"\t",
    }
    index = 0
    while index < len(body):
        current = body[index]
        if current != "\\":
            output.extend(current.encode("utf-8"))
            index += 1
            continue
        if index + 1 >= len(body):
            raise ValueError("unterminated escape in message literal")
        escaped = body[index + 1]
        if escaped in escapes:
            output.extend(escapes[escaped])
            index += 2
            continue
        if escaped == "x" and index + 3 < len(body):
            output.append(int(body[index + 2:index + 4], 16))
            index += 4
            continue
        if escaped == "u" and index + 5 < len(body):
            output.extend(chr(int(body[index + 2:index + 6], 16)).encode("utf-8"))
            index += 6
            continue
        raise ValueError(f"unsupported escape \\{escaped}")
    return bytes(output)


def parse_helper_calls(source: str, helper: str) -> tuple[list[dict[str, Any]], list[str]]:
    masked = mask_comments(source)
    records: list[dict[str, Any]] = []
    violations: list[str] = []
    declarations = 0
    for match in re.finditer(rf"\b{re.escape(helper)}\b", masked):
        previous = list(IDENTIFIER.finditer(masked, 0, match.start()))
        if previous and previous[-1].group(0) == "function":
            declarations += 1
            continue
        opening = match.end()
        while opening < len(masked) and masked[opening].isspace():
            opening += 1
        line = source.count("\n", 0, match.start()) + 1
        if opening >= len(masked) or masked[opening] != "(":
            violations.append(f"line {line}: {helper} is not followed by a call")
            continue
        try:
            closing = call_end(masked, opening)
            arguments = split_arguments(masked[opening + 1:closing])
            if len(arguments) != 3:
                raise ValueError(f"expected 3 arguments, found {len(arguments)}")
            message_bytes = decode_string_literal(arguments[1])
            declared = int(arguments[2], 0)
        except (ValueError, UnicodeError) as error:
            violations.append(f"line {line}: {error}")
            continue
        records.append(
            {
                "line": line,
                "message": message_bytes.decode("utf-8", errors="replace"),
                "declared_bytes": declared,
                "actual_bytes": len(message_bytes),
            }
        )
    if declarations != 1:
        violations.append(f"expected exactly one {helper} declaration, found {declarations}")
    if not records:
        violations.append(f"no {helper} calls found")
    return records, violations


def audit_source(source: str, config: dict[str, Any]) -> dict[str, Any]:
    helper = config.get("helper")
    encoding = config.get("encoding")
    maximum = config.get("max_message_bytes")
    expected = config.get("messages")
    if not isinstance(helper, str) or not helper:
        raise ValueError("relay_revert_abi.helper must be a nonempty string")
    if encoding != "Error(string)":
        raise ValueError("relay_revert_abi.encoding must be Error(string)")
    if not isinstance(maximum, int) or maximum <= 0:
        raise ValueError("relay_revert_abi.max_message_bytes must be positive")
    if not isinstance(expected, list) or not expected:
        raise ValueError("relay_revert_abi.messages must be a nonempty list")

    records, violations = parse_helper_calls(source, helper)
    actual_inventory = [(item["message"], item["declared_bytes"]) for item in records]
    expected_inventory: list[tuple[str, int]] = []
    for index, item in enumerate(expected):
        if not isinstance(item, dict) or not isinstance(item.get("message"), str) or not isinstance(item.get("length"), int):
            violations.append(f"manifest message {index} must contain string message and integer length")
            continue
        message = item["message"]
        declared = item["length"]
        actual = len(message.encode("utf-8"))
        expected_inventory.append((message, declared))
        if actual != declared:
            violations.append(
                f"manifest message {message!r} declares {declared} bytes but encodes to {actual}"
            )
        if actual > maximum:
            violations.append(
                f"manifest message {message!r} is {actual} bytes, exceeding the {maximum}-byte helper limit"
            )

    for record in records:
        if record["actual_bytes"] != record["declared_bytes"]:
            violations.append(
                f"line {record['line']}: {record['message']!r} declares "
                f"{record['declared_bytes']} bytes but encodes to {record['actual_bytes']}"
            )
        if record["actual_bytes"] > maximum:
            violations.append(
                f"line {record['line']}: {record['message']!r} is {record['actual_bytes']} bytes, "
                f"exceeding the {maximum}-byte helper limit"
            )

    if actual_inventory != expected_inventory:
        missing = list((Counter(expected_inventory) - Counter(actual_inventory)).elements())
        unexpected = list((Counter(actual_inventory) - Counter(expected_inventory)).elements())
        details = []
        if missing:
            details.append(f"missing={missing}")
        if unexpected:
            details.append(f"unexpected={unexpected}")
        if not details:
            details.append("message order changed")
        violations.append("legacy relay revert inventory differs from manifest: " + "; ".join(details))

    max_observed = max((item["actual_bytes"] for item in records), default=0)
    return {
        "schema_version": 1,
        "gate": "relay-revert-abi",
        "status": "fail" if violations else "pass",
        "encoding": encoding,
        "max_message_bytes": maximum,
        "summary": {
            "expected_calls": len(expected_inventory),
            "observed_calls": len(records),
            "max_observed_message_bytes": max_observed,
            "violations": len(violations),
        },
        "messages": records,
        "violations": violations,
    }


def write_report(path: Path | None, report: dict[str, Any]) -> None:
    if path is None:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--source", type=Path)
    parser.add_argument("--report-output", type=Path)
    args = parser.parse_args()
    try:
        manifest = json.loads(args.manifest.read_text())
        config = manifest["relay_revert_abi"]
        configured_source = Path(config["source"])
        source_path = args.source or (REPO / configured_source)
        source_bytes = source_path.read_bytes()
        source = source_bytes.decode("utf-8")
        report = audit_source(source, config)
        report["source"] = {
            "path": str(source_path.resolve().relative_to(REPO.resolve())),
            "sha256": hashlib.sha256(source_bytes).hexdigest(),
        }
    except (KeyError, OSError, UnicodeError, ValueError, json.JSONDecodeError) as error:
        report = {
            "schema_version": 1,
            "gate": "relay-revert-abi",
            "status": "fail",
            "violations": [str(error)],
        }
    write_report(args.report_output, report)
    if report["status"] == "pass":
        summary = report["summary"]
        print(
            f"[relay-revert-abi] PASS: {summary['observed_calls']} legacy messages; "
            f"maximum {summary['max_observed_message_bytes']}/{report['max_message_bytes']} bytes"
        )
        return 0
    for violation in report["violations"]:
        print(f"[relay-revert-abi] FAIL: {violation}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
