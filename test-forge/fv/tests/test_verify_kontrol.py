from __future__ import annotations

import importlib.util
import sys
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path


MODULE_PATH = Path(__file__).resolve().parents[1] / "kontrol" / "verify_kontrol.py"
SPEC = importlib.util.spec_from_file_location("verify_kontrol", MODULE_PATH)
assert SPEC and SPEC.loader
verify_kontrol = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = verify_kontrol
SPEC.loader.exec_module(verify_kontrol)


PROOF = "Suite.prove_property"
REACH = "Suite.prove_reach_witness"


def manifest() -> dict:
    return {
        "toolchain": {},
        "expected_process_exitcode": 1,
        "proofs": [PROOF],
        "reachability": [REACH],
    }


def junit(
    *,
    reach_failure: str | None = "1 Failure nodes (0 pending and 1 failing)\nModel:\n  x = 1",
    error: bool = False,
) -> ET.Element:
    root = ET.Element("testsuites")
    suite = ET.SubElement(root, "testsuite", name="Suite")
    ET.SubElement(suite, "testcase", name="prove_property(uint256)")
    reach = ET.SubElement(suite, "testcase", name="prove_reach_witness(uint256)")
    if error:
        ET.SubElement(reach, "error", message="Exception")
    elif reach_failure is not None:
        failure = ET.SubElement(reach, "failure", message="Proof failed")
        failure.text = reach_failure
    return root


class KontrolGateTest(unittest.TestCase):
    def test_accepts_exact_proof_and_concrete_failure(self) -> None:
        report = verify_kontrol.evaluate_junit(junit(), manifest(), 1)
        self.assertEqual("pass", report["status"])

    def test_rejects_reachability_pass(self) -> None:
        report = verify_kontrol.evaluate_junit(junit(reach_failure=None), manifest(), 1)
        self.assertTrue(any("witness was not demonstrated" in item for item in report["violations"]))

    def test_rejects_tool_error(self) -> None:
        report = verify_kontrol.evaluate_junit(junit(error=True), manifest(), 1)
        self.assertTrue(any("tool/proof error" in item for item in report["violations"]))

    def test_rejects_pending_failure_as_counterexample(self) -> None:
        report = verify_kontrol.evaluate_junit(
            junit(reach_failure="1 Failure nodes (2 pending and 1 failing)"), manifest(), 1
        )
        self.assertTrue(any("incomplete" in item for item in report["violations"]))

    def test_rejects_failure_without_concrete_model(self) -> None:
        report = verify_kontrol.evaluate_junit(
            junit(reach_failure="1 Failure nodes (0 pending and 1 failing)"), manifest(), 1
        )
        self.assertTrue(any("concrete model" in item for item in report["violations"]))

    def test_rejects_wrong_process_exitcode(self) -> None:
        report = verify_kontrol.evaluate_junit(junit(), manifest(), 5)
        self.assertTrue(any("exitcode" in item for item in report["violations"]))


if __name__ == "__main__":
    unittest.main()
