from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).resolve().parents[1] / "verify_fv.py"
SPEC = importlib.util.spec_from_file_location("verify_fv", MODULE_PATH)
assert SPEC and SPEC.loader
verify_fv = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = verify_fv
SPEC.loader.exec_module(verify_fv)


PROOF = "test-forge/fv/Proof.t.sol:Proof.check_property"
REACH = "test-forge/fv/Proof.t.sol:Proof.check_reach_witness"


def manifest() -> dict:
    return {
        "halmos": {
            "proofs": [PROOF],
            "reachability": [REACH],
            "expected_process_exitcode": 1,
            "max_bounded_loops": 0,
        }
    }


def result(name: str, exitcode: int, *, valid: bool | None = None, bounded: int = 0) -> dict:
    models = [] if valid is None else [{"model": {}, "is_valid": valid}]
    return {
        "name": f"{name}()",
        "exitcode": exitcode,
        "num_models": len(models),
        "models": models,
        "num_paths": [1, 1 if exitcode == 0 else 0, 0],
        "num_bounded_loops": bounded,
    }


def payload(*checks: dict, exitcode: int = 1) -> dict:
    return {
        "exitcode": exitcode,
        "test_results": {"test-forge/fv/Proof.t.sol:Proof": list(checks)},
    }


class EvaluateResultsTest(unittest.TestCase):
    def test_accepts_exact_pass_and_valid_counterexample(self) -> None:
        report = verify_fv.evaluate_results(
            payload(
                result("check_property", verify_fv.PASS),
                result("check_reach_witness", verify_fv.COUNTEREXAMPLE, valid=True),
            ),
            manifest(),
            process_exitcode=1,
        )
        self.assertEqual("pass", report["status"])
        self.assertEqual(0, report["summary"]["violations"])

    def test_rejects_timeout_as_reachability_witness(self) -> None:
        report = verify_fv.evaluate_results(
            payload(
                result("check_property", verify_fv.PASS),
                result("check_reach_witness", 2),
                exitcode=2,
            ),
            manifest(),
            process_exitcode=2,
        )
        self.assertEqual("fail", report["status"])
        self.assertTrue(any("TIMEOUT" in problem for problem in report["violations"]))

    def test_rejects_invalid_counterexample_model(self) -> None:
        report = verify_fv.evaluate_results(
            payload(
                result("check_property", verify_fv.PASS),
                result("check_reach_witness", verify_fv.COUNTEREXAMPLE, valid=False),
            ),
            manifest(),
        )
        self.assertTrue(any("validated counterexample" in problem for problem in report["violations"]))

    def test_rejects_missing_and_unexpected_checks(self) -> None:
        report = verify_fv.evaluate_results(
            payload(result("check_other", verify_fv.PASS)),
            manifest(),
        )
        self.assertTrue(any("missing expected checks" in problem for problem in report["violations"]))
        self.assertTrue(any("unexpected checks" in problem for problem in report["violations"]))

    def test_rejects_truncated_loops(self) -> None:
        report = verify_fv.evaluate_results(
            payload(
                result("check_property", verify_fv.PASS, bounded=1),
                result("check_reach_witness", verify_fv.COUNTEREXAMPLE, valid=True),
            ),
            manifest(),
        )
        self.assertTrue(any("bounded loop" in problem for problem in report["violations"]))

    def test_rejects_process_json_exitcode_disagreement(self) -> None:
        report = verify_fv.evaluate_results(
            payload(
                result("check_property", verify_fv.PASS),
                result("check_reach_witness", verify_fv.COUNTEREXAMPLE, valid=True),
            ),
            manifest(),
            process_exitcode=5,
        )
        self.assertTrue(any("disagrees" in problem for problem in report["violations"]))


if __name__ == "__main__":
    unittest.main()
