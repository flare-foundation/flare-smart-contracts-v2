from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).resolve().parents[1] / "verify_relay_custom_error_abi.py"
SPEC = importlib.util.spec_from_file_location("verify_relay_custom_error_abi", MODULE_PATH)
assert SPEC and SPEC.loader
verify_errors = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = verify_errors
SPEC.loader.exec_module(verify_errors)


def config(*, selector: str = "0x8320c358", uses: int = 1) -> dict:
    return {
        "helper": "revertWithError",
        "encoding": "bytes4",
        "expected_call_count": uses,
        "errors": [
            {
                "constant": "ERR_BAD_V",
                "signature": "BadV()",
                "selector": selector,
                "expected_uses": uses,
            }
        ],
    }


def implementation(
    *,
    selector: str = "0x8320c358",
    body: str | None = None,
    call: str = "ERR_BAD_V",
    extra: str = "",
) -> str:
    helper_body = body or "mstore(_memPtr, shl(224, _selector)) revert(_memPtr, 4)"
    return f"""
contract Relay {{
    uint32 private constant ERR_BAD_V = {selector};
    function relay() external {{
        assembly {{
            function revertWithError(_memPtr, _selector) {{ {helper_body} }}
            // revertWithError(0, ERR_IGNORED)
            revertWithError(mload(0x40), {call})
            {extra}
        }}
    }}
}}
"""


INTERFACE = "interface IRelay { error BadV(); }"


class RelayCustomErrorAbiTest(unittest.TestCase):
    def test_source_overrides_are_diagnostic_only(self) -> None:
        self.assertEqual("generated-in-process", verify_errors.source_input_mode(None, None))
        self.assertEqual(
            "diagnostic-overrides",
            verify_errors.source_input_mode(Path("alternate.sol"), None),
        )

    def test_keccak_uses_ethereum_padding(self) -> None:
        self.assertEqual(
            "c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470",
            verify_errors.keccak256(b"").hex(),
        )
        self.assertEqual("0x8320c358", verify_errors.selector("BadV()"))

    def test_accepts_exact_selector_interface_and_use_inventory(self) -> None:
        report = verify_errors.audit_sources(implementation(), INTERFACE, config())
        self.assertEqual("pass", report["status"])
        self.assertEqual(1, report["summary"]["observed_calls"])

    def test_rejects_noncanonical_four_byte_encoding(self) -> None:
        report = verify_errors.audit_sources(
            implementation(body="mstore(_memPtr, _selector) revert(_memPtr, 32)"),
            INTERFACE,
            config(),
        )
        self.assertTrue(any("exactly 4 bytes" in item for item in report["violations"]))

    def test_rejects_source_selector_drift(self) -> None:
        report = verify_errors.audit_sources(
            implementation(selector="0x00000000"), INTERFACE, config()
        )
        self.assertTrue(any("source selector" in item for item in report["violations"]))

    def test_rejects_manifest_keccak_mismatch(self) -> None:
        report = verify_errors.audit_sources(
            implementation(), INTERFACE, config(selector="0x00000000")
        )
        self.assertTrue(any("Keccak-256" in item for item in report["violations"]))

    def test_rejects_missing_interface_declaration(self) -> None:
        report = verify_errors.audit_sources(implementation(), "interface IRelay {}", config())
        self.assertTrue(any("not declared" in item for item in report["violations"]))

    def test_rejects_nonconstant_selector_use(self) -> None:
        report = verify_errors.audit_sources(
            implementation(call="or(ERR_BAD_V, 1)"), INTERFACE, config()
        )
        self.assertTrue(any("ERR_* identifier" in item for item in report["violations"]))

    def test_rejects_raw_revert_bypassing_helper(self) -> None:
        report = verify_errors.audit_sources(
            implementation(extra="revert(0, 0)"), INTERFACE, config()
        )
        self.assertTrue(any("raw revert" in item for item in report["violations"]))

    def test_rejects_use_count_drift(self) -> None:
        report = verify_errors.audit_sources(implementation(), INTERFACE, config(uses=2))
        self.assertTrue(any("observed 1 use" in item for item in report["violations"]))

    def test_rejects_boolean_manifest_counts(self) -> None:
        malformed = config()
        malformed["expected_call_count"] = True
        with self.assertRaisesRegex(ValueError, "must be positive"):
            verify_errors.audit_sources(implementation(), INTERFACE, malformed)
        malformed = config()
        malformed["errors"][0]["expected_uses"] = True
        report = verify_errors.audit_sources(implementation(), INTERFACE, malformed)
        self.assertEqual("fail", report["status"])
        self.assertTrue(any("invalid fields" in item for item in report["violations"]))


if __name__ == "__main__":
    unittest.main()
