from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).resolve().parents[1] / "verify_relay_revert_abi.py"
SPEC = importlib.util.spec_from_file_location("verify_relay_revert_abi", MODULE_PATH)
assert SPEC and SPEC.loader
verify_reverts = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = verify_reverts
SPEC.loader.exec_module(verify_reverts)


def config(message: str = "Bad input", length: int = 9) -> dict:
    return {
        "helper": "revertWithMessage",
        "encoding": "Error(string)",
        "max_message_bytes": 32,
        "messages": [{"message": message, "length": length}],
    }


def source(message: str = '"Bad input"', length: str = "9") -> str:
    return f"""
contract Relay {{
    function relay() external {{
        assembly {{
            function revertWithMessage(_memPtr, _message, _msgLength) {{
                revert(_memPtr, 0x64)
            }}
            // revertWithMessage(0, "Ignored comment", 15)
            revertWithMessage(mload(0x40), {message}, {length})
        }}
    }}
}}
"""


class RelayRevertAbiTest(unittest.TestCase):
    def test_accepts_exact_literal_inventory(self) -> None:
        report = verify_reverts.audit_source(source(), config())
        self.assertEqual("pass", report["status"])
        self.assertEqual(1, report["summary"]["observed_calls"])

    def test_rejects_declared_length_mismatch(self) -> None:
        report = verify_reverts.audit_source(source(length="8"), config())
        self.assertTrue(any("declares 8 bytes" in item for item in report["violations"]))

    def test_rejects_message_over_one_word(self) -> None:
        message = "x" * 33
        report = verify_reverts.audit_source(source(f'"{message}"', "33"), config(message, 33))
        self.assertTrue(any("exceeding the 32-byte" in item for item in report["violations"]))

    def test_rejects_nonliteral_message(self) -> None:
        report = verify_reverts.audit_source(source("_message"), config())
        self.assertTrue(any("double-quoted literal" in item for item in report["violations"]))

    def test_rejects_inventory_drift(self) -> None:
        report = verify_reverts.audit_source(source('"Changed"', "7"), config())
        self.assertTrue(any("inventory differs" in item for item in report["violations"]))


if __name__ == "__main__":
    unittest.main()
