from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).resolve().parents[1] / "verify_certora_local.py"
SPEC = importlib.util.spec_from_file_location("verify_certora_local", MODULE_PATH)
assert SPEC and SPEC.loader
verify_certora_local = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = verify_certora_local
SPEC.loader.exec_module(verify_certora_local)


class ToolVersionParsingTest(unittest.TestCase):
    def test_parses_certora_cli_version(self) -> None:
        self.assertEqual("8.16.1", verify_certora_local.certora_version("certora-cli 8.16.1"))

    def test_parses_java_21_version(self) -> None:
        output = 'openjdk version "21.0.11" 2026-04-21 LTS'
        self.assertEqual(21, verify_certora_local.java_major(output))

    def test_normalizes_native_solc_platform_suffixes(self) -> None:
        self.assertEqual(
            "0.8.27+commit.40a35a09",
            verify_certora_local.solc_long_version(
                "Version: 0.8.27+commit.40a35a09.Darwin.appleclang\n"
            ),
        )
        self.assertEqual(
            "0.8.27+commit.40a35a09",
            verify_certora_local.solc_long_version(
                "Version: 0.8.27+commit.40a35a09.Linux.g++\n"
            ),
        )


if __name__ == "__main__":
    unittest.main()
