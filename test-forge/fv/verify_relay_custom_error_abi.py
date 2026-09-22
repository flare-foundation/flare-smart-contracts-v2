#!/usr/bin/env python3
"""Fail-closed audit of Relay.relay()'s hand-written custom-error ABI.

The relay implementation writes error selectors in assembly, so Solidity cannot
type-check those call sites against IRelay. This gate binds four independently
reviewable facts: every ERR_* constant, its IRelay error signature, the Keccak-256
selector, and every assembly use site. It also checks that the helper returns
exactly four bytes in canonical ABI position.
"""

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
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))
from report_provenance import (  # noqa: E402
    DIAGNOSTIC_MODE,
    GENERATED_MODE,
    capture_git_state,
    finalize_generation_provenance,
    report_commit,
)
IDENTIFIER = re.compile(r"[A-Za-z_$][A-Za-z0-9_$]*")
MASK64 = (1 << 64) - 1
ROTATION = (
    0, 1, 62, 28, 27,
    36, 44, 6, 55, 20,
    3, 10, 43, 25, 39,
    41, 45, 15, 21, 8,
    18, 2, 61, 56, 14,
)
ROUND_CONSTANTS = (
    0x0000000000000001, 0x0000000000008082, 0x800000000000808A,
    0x8000000080008000, 0x000000000000808B, 0x0000000080000001,
    0x8000000080008081, 0x8000000000008009, 0x000000000000008A,
    0x0000000000000088, 0x0000000080008009, 0x000000008000000A,
    0x000000008000808B, 0x800000000000008B, 0x8000000000008089,
    0x8000000000008003, 0x8000000000008002, 0x8000000000000080,
    0x000000000000800A, 0x800000008000000A, 0x8000000080008081,
    0x8000000000008080, 0x0000000080000001, 0x8000000080008008,
)


def _rol64(value: int, shift: int) -> int:
    if shift == 0:
        return value & MASK64
    return ((value << shift) | (value >> (64 - shift))) & MASK64


def _keccak_f1600(state: list[int]) -> None:
    for round_constant in ROUND_CONSTANTS:
        columns = [
            state[x] ^ state[x + 5] ^ state[x + 10] ^ state[x + 15] ^ state[x + 20]
            for x in range(5)
        ]
        for x in range(5):
            delta = columns[(x - 1) % 5] ^ _rol64(columns[(x + 1) % 5], 1)
            for y in range(5):
                state[x + 5 * y] ^= delta

        rotated = [0] * 25
        for x in range(5):
            for y in range(5):
                rotated[y + 5 * ((2 * x + 3 * y) % 5)] = _rol64(
                    state[x + 5 * y], ROTATION[x + 5 * y]
                )

        for x in range(5):
            for y in range(5):
                state[x + 5 * y] = (
                    rotated[x + 5 * y]
                    ^ ((~rotated[(x + 1) % 5 + 5 * y]) & rotated[(x + 2) % 5 + 5 * y])
                ) & MASK64
        state[0] ^= round_constant


def keccak256(value: bytes) -> bytes:
    """Ethereum Keccak-256 (legacy Keccak padding, not FIPS SHA3-256)."""
    rate = 136
    padded = bytearray(value)
    padded.append(0x01)
    padded.extend(b"\x00" * ((rate - len(padded) % rate) % rate))
    padded[-1] ^= 0x80
    state = [0] * 25
    for offset in range(0, len(padded), rate):
        block = padded[offset:offset + rate]
        for lane in range(rate // 8):
            state[lane] ^= int.from_bytes(block[lane * 8:(lane + 1) * 8], "little")
        _keccak_f1600(state)
    return b"".join(lane.to_bytes(8, "little") for lane in state)[:32]


def selector(signature: str) -> str:
    return "0x" + keccak256(signature.encode("ascii"))[:4].hex()


def mask_comments(source: str) -> str:
    """Replace comments with spaces while preserving source offsets and strings."""
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
    for index, current in enumerate(arguments):
        if current in "([{":
            depth += 1
        elif current in ")]}":
            depth -= 1
            if depth < 0:
                raise ValueError("unbalanced helper-call delimiter")
        elif current == "," and depth == 0:
            parts.append(arguments[start:index].strip())
            start = index + 1
    if depth:
        raise ValueError("unterminated helper-call delimiter")
    parts.append(arguments[start:].strip())
    return parts


def matching_delimiter(source: str, opening: int, left: str, right: str) -> int:
    depth = 1
    for index in range(opening + 1, len(source)):
        if source[index] == left:
            depth += 1
        elif source[index] == right:
            depth -= 1
            if depth == 0:
                return index
    raise ValueError(f"unterminated {left}{right} block")


def parse_constants(source: str) -> tuple[dict[str, dict[str, Any]], list[str]]:
    masked = mask_comments(source)
    pattern = re.compile(
        r"\buint32\s+private\s+constant\s+(ERR_[A-Z0-9_]+)\s*=\s*(0x[0-9a-fA-F]{8})\s*;"
    )
    records: dict[str, dict[str, Any]] = {}
    violations: list[str] = []
    for match in pattern.finditer(masked):
        name = match.group(1)
        if name in records:
            violations.append(f"duplicate selector constant {name}")
            continue
        records[name] = {
            "constant": name,
            "selector": match.group(2).lower(),
            "line": source.count("\n", 0, match.start()) + 1,
        }
    all_error_constants = set(re.findall(r"\bERR_[A-Z0-9_]+\b", masked))
    undeclared_shape = sorted(all_error_constants - records.keys())
    if undeclared_shape:
        violations.append(
            "ERR_* identifiers missing canonical uint32 private constant declarations: "
            + ", ".join(undeclared_shape)
        )
    return records, violations


def parse_helper(source: str, helper: str) -> tuple[list[dict[str, Any]], list[str]]:
    masked = mask_comments(source)
    declaration = re.compile(
        rf"\bfunction\s+{re.escape(helper)}\s*\(\s*_memPtr\s*,\s*_selector\s*\)\s*\{{"
    )
    declarations = list(declaration.finditer(masked))
    violations: list[str] = []
    declaration_start = -1
    if len(declarations) != 1:
        violations.append(f"expected exactly one canonical {helper} declaration, found {len(declarations)}")
    else:
        match = declarations[0]
        declaration_start = match.start()
        opening = masked.find("{", match.start(), match.end())
        closing = matching_delimiter(masked, opening, "{", "}")
        compact_body = re.sub(r"\s+", "", masked[opening + 1:closing])
        expected_body = "mstore(_memPtr,shl(224,_selector))revert(_memPtr,4)"
        if compact_body != expected_body:
            violations.append(
                f"{helper} must left-align one selector and revert with exactly 4 bytes"
            )
        enclosing_assembly: list[tuple[int, int]] = []
        for assembly in re.finditer(r"\bassembly(?:\s*\([^)]*\))?\s*\{", masked):
            assembly_open = masked.find("{", assembly.start(), assembly.end())
            assembly_close = matching_delimiter(masked, assembly_open, "{", "}")
            if assembly_open < declaration_start < assembly_close:
                enclosing_assembly.append((assembly_open, assembly_close))
        if len(enclosing_assembly) != 1:
            violations.append(f"{helper} must be inside exactly one assembly block")
        else:
            assembly_open, assembly_close = enclosing_assembly[0]
            raw_reverts = re.findall(r"\brevert\s*\(", masked[assembly_open:assembly_close])
            if len(raw_reverts) != 1:
                violations.append(
                    f"relay assembly contains {len(raw_reverts)} raw revert(s); "
                    f"the canonical {helper} body must be the only one"
                )

    calls: list[dict[str, Any]] = []
    for match in re.finditer(rf"\b{re.escape(helper)}\b", masked):
        if match.start() == declaration_start + len("function "):
            continue
        prefix = masked[max(0, match.start() - 16):match.start()]
        if re.search(r"\bfunction\s*$", prefix):
            continue
        opening = match.end()
        while opening < len(masked) and masked[opening].isspace():
            opening += 1
        line = source.count("\n", 0, match.start()) + 1
        if opening >= len(masked) or masked[opening] != "(":
            violations.append(f"line {line}: {helper} is not followed by a call")
            continue
        try:
            closing = matching_delimiter(masked, opening, "(", ")")
            arguments = split_arguments(masked[opening + 1:closing])
            if len(arguments) != 2 or not arguments[0]:
                raise ValueError(f"expected 2 nonempty arguments, found {len(arguments)}")
            if not IDENTIFIER.fullmatch(arguments[1]):
                raise ValueError("selector argument must be one ERR_* identifier")
        except ValueError as error:
            violations.append(f"line {line}: {error}")
            continue
        calls.append({"line": line, "constant": arguments[1]})
    if not calls:
        violations.append(f"no {helper} calls found")
    return calls, violations


def interface_signatures(source: str) -> set[str]:
    masked = mask_comments(source)
    return {
        re.sub(r"\s+", "", match.group(1) + "(" + match.group(2) + ")")
        for match in re.finditer(r"\berror\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*\(([^;()]*)\)\s*;", masked)
    }


def audit_sources(implementation: str, interface: str, config: dict[str, Any]) -> dict[str, Any]:
    helper = config.get("helper")
    encoding = config.get("encoding")
    expected_count = config.get("expected_call_count")
    expected = config.get("errors")
    if helper != "revertWithError":
        raise ValueError("relay_custom_error_abi.helper must be revertWithError")
    if encoding != "bytes4":
        raise ValueError("relay_custom_error_abi.encoding must be bytes4")
    if type(expected_count) is not int or expected_count <= 0:
        raise ValueError("relay_custom_error_abi.expected_call_count must be positive")
    if not isinstance(expected, list) or not expected:
        raise ValueError("relay_custom_error_abi.errors must be a nonempty list")

    constants, violations = parse_constants(implementation)
    calls, helper_violations = parse_helper(implementation, helper)
    violations.extend(helper_violations)
    declared_signatures = interface_signatures(interface)
    expected_by_constant: dict[str, dict[str, Any]] = {}
    expected_selectors: set[str] = set()
    expected_signatures: set[str] = set()

    for index, item in enumerate(expected):
        if not isinstance(item, dict):
            violations.append(f"manifest error {index} must be an object")
            continue
        constant = item.get("constant")
        signature = item.get("signature")
        configured_selector = item.get("selector")
        expected_uses = item.get("expected_uses")
        if (
            not isinstance(constant, str)
            or not re.fullmatch(r"ERR_[A-Z0-9_]+", constant)
            or not isinstance(signature, str)
            or not re.fullmatch(r"[A-Za-z_$][A-Za-z0-9_$]*\([^()]*\)", signature)
            or not isinstance(configured_selector, str)
            or not re.fullmatch(r"0x[0-9a-f]{8}", configured_selector)
            or type(expected_uses) is not int
            or expected_uses <= 0
        ):
            violations.append(f"manifest error {index} has invalid fields")
            continue
        if constant in expected_by_constant:
            violations.append(f"duplicate manifest constant {constant}")
            continue
        computed = selector(signature)
        if configured_selector != computed:
            violations.append(
                f"{constant}: manifest selector {configured_selector} != Keccak-256({signature}) {computed}"
            )
        if configured_selector in expected_selectors:
            violations.append(f"duplicate manifest selector {configured_selector}")
        if signature in expected_signatures:
            violations.append(f"duplicate manifest signature {signature}")
        if signature not in declared_signatures:
            violations.append(f"{constant}: {signature} is not declared by the configured interface")
        expected_selectors.add(configured_selector)
        expected_signatures.add(signature)
        expected_by_constant[constant] = item

    missing_constants = sorted(expected_by_constant.keys() - constants.keys())
    unexpected_constants = sorted(constants.keys() - expected_by_constant.keys())
    if missing_constants:
        violations.append("missing selector constants: " + ", ".join(missing_constants))
    if unexpected_constants:
        violations.append("unexpected selector constants: " + ", ".join(unexpected_constants))

    call_counts = Counter(call["constant"] for call in calls)
    for constant, item in expected_by_constant.items():
        actual_constant = constants.get(constant)
        if actual_constant and actual_constant["selector"] != item["selector"]:
            violations.append(
                f"{constant}: source selector {actual_constant['selector']} != manifest {item['selector']}"
            )
        observed_uses = call_counts[constant]
        if observed_uses != item["expected_uses"]:
            violations.append(
                f"{constant}: observed {observed_uses} use(s), expected {item['expected_uses']}"
            )
    unexpected_calls = sorted(call_counts.keys() - expected_by_constant.keys())
    if unexpected_calls:
        violations.append("unexpected selector use sites: " + ", ".join(unexpected_calls))
    if len(calls) != expected_count:
        violations.append(f"observed {len(calls)} helper calls, expected {expected_count}")
    if sum(item.get("expected_uses", 0) for item in expected if isinstance(item, dict)) != expected_count:
        violations.append("manifest expected_uses total does not equal expected_call_count")

    records = []
    for constant in sorted(expected_by_constant):
        item = expected_by_constant[constant]
        records.append(
            {
                "constant": constant,
                "signature": item["signature"],
                "selector": item["selector"],
                "constant_line": constants.get(constant, {}).get("line"),
                "use_lines": [call["line"] for call in calls if call["constant"] == constant],
            }
        )
    return {
        "schema_version": 1,
        "gate": "relay-custom-error-abi",
        "status": "fail" if violations else "pass",
        "encoding": encoding,
        "summary": {
            "expected_errors": len(expected_by_constant),
            "observed_constants": len(constants),
            "expected_calls": expected_count,
            "observed_calls": len(calls),
            "violations": len(violations),
        },
        "errors": records,
        "violations": violations,
    }


def write_report(path: Path | None, report: dict[str, Any]) -> None:
    if path is None:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")


def source_input_mode(source: Path | None, interface: Path | None) -> str:
    return DIAGNOSTIC_MODE if source is not None or interface is not None else GENERATED_MODE


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--source", type=Path)
    parser.add_argument("--interface", type=Path)
    parser.add_argument("--report-output", type=Path)
    args = parser.parse_args()
    generation_start = capture_git_state(REPO)
    input_mode = source_input_mode(args.source, args.interface)
    try:
        manifest_bytes = args.manifest.read_bytes()
        manifest = json.loads(manifest_bytes)
        if type(manifest.get("schema_version")) is not int or manifest.get("schema_version") != 1:
            raise ValueError("verification manifest schema_version must be integer 1")
        config = manifest["relay_custom_error_abi"]
        source_path = args.source or (REPO / config["source"])
        interface_path = args.interface or (REPO / config["interface_source"])
        source_bytes = source_path.read_bytes()
        interface_bytes = interface_path.read_bytes()
        report = audit_sources(
            source_bytes.decode("utf-8"), interface_bytes.decode("utf-8"), config
        )
        report["manifest_sha256"] = hashlib.sha256(manifest_bytes).hexdigest()
        report["sources"] = [
            {
                "path": str(source_path.resolve().relative_to(REPO.resolve())),
                "sha256": hashlib.sha256(source_bytes).hexdigest(),
            },
            {
                "path": str(interface_path.resolve().relative_to(REPO.resolve())),
                "sha256": hashlib.sha256(interface_bytes).hexdigest(),
            },
        ]
    except (KeyError, OSError, UnicodeError, ValueError, json.JSONDecodeError) as error:
        report = {
            "schema_version": 1,
            "gate": "relay-custom-error-abi",
            "status": "fail",
            "violations": [str(error)],
        }
    generation = finalize_generation_provenance(REPO, generation_start, mode=input_mode)
    report["generation_provenance"] = generation
    report["release_eligible"] = (
        report["status"] == "pass" and generation["release_eligible"] is True
    )
    report["git_commit"] = report_commit(generation)
    write_report(args.report_output, report)
    if report["status"] == "pass":
        summary = report["summary"]
        print(
            f"[relay-custom-error-abi] PASS: {summary['observed_constants']} selectors, "
            f"{summary['observed_calls']} four-byte assembly reverts"
        )
        return 0
    for violation in report["violations"]:
        print(f"[relay-custom-error-abi] FAIL: {violation}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
