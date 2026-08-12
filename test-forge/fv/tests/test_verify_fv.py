from __future__ import annotations

import hashlib
import importlib.util
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch


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


def build_manifest() -> dict:
    return {
        "target": {
            "production_compiler": {
                "version": "0.8.35+commit.47b9dedd",
                "short_version": "0.8.35",
                "evm_version": "cancun",
                "optimizer_enabled": True,
                "optimizer_runs": 200,
                "via_ir": True,
            }
        },
        "halmos": {
            "configuration": {
                "path": "halmos.toml",
                "forge_build_out": "artifacts-forge",
                "loop": 6,
                "solver": "z3",
                "solver_timeout_assertion": 0,
            }
        },
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
    def test_imported_results_are_development_only_and_content_bound(self) -> None:
        raw = b'{"exitcode":1,"test_results":{}}'
        eligible, provenance = verify_fv._execution_provenance(
            raw,
            imported=True,
            input_path=Path("stale-halmos.json"),
        )
        self.assertFalse(eligible)
        self.assertEqual("imported-results", provenance["mode"])
        self.assertEqual(hashlib.sha256(raw).hexdigest(), provenance["raw_results_sha256"])
        self.assertIsNone(provenance["halmos_process_exitcode"])
        self.assertNotIn("command", provenance)

    def test_generated_results_are_release_eligible_with_process_provenance(self) -> None:
        raw = b'{"exitcode":1,"test_results":{}}'
        command = ["halmos", "--json-output", "/tmp/results.json"]
        eligible, provenance = verify_fv._execution_provenance(
            raw,
            imported=False,
            process_exitcode=1,
            command=command,
        )
        self.assertTrue(eligible)
        self.assertEqual("generated-in-process", provenance["mode"])
        self.assertEqual(1, provenance["halmos_process_exitcode"])
        self.assertEqual(command, provenance["command"])

    def test_halmos_overrides_are_diagnostic_only(self) -> None:
        eligible, provenance = verify_fv._execution_provenance(
            b"{}",
            imported=False,
            process_exitcode=1,
            command=["halmos", "--solver-command", "other"],
            diagnostic_overrides=True,
        )
        self.assertFalse(eligible)
        self.assertEqual("diagnostic-overrides", provenance["mode"])

    def test_extracts_pinned_foundry_build(self) -> None:
        output = """forge Version: 1.7.2-nightly
Commit SHA: 160b60260db63ce6204f2ee15764aca3e9ef04fe
Build Profile: dist
"""
        self.assertEqual(
            {
                "version": "1.7.2-nightly",
                "commit": "160b60260db63ce6204f2ee15764aca3e9ef04fe",
            },
            verify_fv._foundry_build(output),
        )
        self.assertEqual(
            {"version": "unavailable", "commit": "unavailable"},
            verify_fv._foundry_build("forge failed"),
        )

    def test_halmos_internal_build_uses_the_audited_forge(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            forge = Path(directory) / "forge"
            forge.write_text("#!/bin/sh\nexit 0\n")
            forge.chmod(0o755)
            with patch.dict(os.environ, {"PATH": "/usr/bin:/bin"}):
                environment, resolved = verify_fv._halmos_subprocess_environment(str(forge))
            self.assertEqual(str(forge.resolve()), resolved)
            first_path = Path(environment["PATH"].split(os.pathsep, 1)[0]) / "forge"
            self.assertEqual(str(forge.resolve()), str(first_path))

    def test_source_inventory_is_exact_and_contract_qualified(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            suite = root / "Proof.t.sol"
            suite.write_text(
                "contract Proof { function check_property() external {} }\n"
                "contract Other { function check_reach_witness() external {} }\n"
            )
            with patch.object(verify_fv, "REPO_ROOT", root):
                discovered = verify_fv.discover_source_checks(root)
            self.assertEqual(
                {
                    "Proof.t.sol:Proof.check_property",
                    "Proof.t.sol:Other.check_reach_witness",
                },
                discovered,
            )

    def test_halmos_prebuild_forces_ast_complete_artifacts(self) -> None:
        completed = Mock(returncode=0, stdout="", stderr="")
        with patch.object(verify_fv.subprocess, "run", return_value=completed) as run:
            exitcode, _ = verify_fv._prepare_halmos_artifacts(build_manifest())
            self.assertEqual(0, exitcode)
        command = run.call_args.args[0]
        self.assertEqual("forge", command[0])
        self.assertEqual("test-forge/fv", command[2])
        self.assertIn("--force", command)
        self.assertIn("--ast", command)
        self.assertEqual(["storageLayout", "metadata"], command[command.index("--extra-output") + 1:command.index("--optimize")])
        self.assertEqual("0.8.35", command[command.index("--use") + 1])
        self.assertIn("--no-auto-detect", command)
        self.assertEqual("cancun", command[command.index("--evm-version") + 1])
        self.assertEqual("200", command[command.index("--optimizer-runs") + 1])
        self.assertIn("--via-ir", command)

    def test_halmos_config_is_exact_and_solver_pinned(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "halmos.toml").write_text(
                '[global]\nforge-build-out="artifacts-forge"\nloop=6\nsolver="z3"\nsolver-timeout-assertion=0\n'
            )
            with patch.object(verify_fv, "REPO_ROOT", root):
                record, problems = verify_fv._audit_halmos_config(build_manifest())
            self.assertEqual([], problems)
            self.assertEqual("z3", record["effective"]["solver"])

            (root / "halmos.toml").write_text(
                '[global]\nforge-build-out="other"\nloop=6\nsolver="yices"\nsolver-timeout-assertion=0\n'
            )
            with patch.object(verify_fv, "REPO_ROOT", root):
                _, problems = verify_fv._audit_halmos_config(build_manifest())
            self.assertTrue(any("solver" in problem for problem in problems))
            self.assertTrue(any("forge_build_out" in problem for problem in problems))

    def test_rejects_boolean_numeric_result_fields(self) -> None:
        for field in ("exitcode", "num_models", "num_bounded_loops"):
            proof = result("check_property", verify_fv.PASS)
            proof[field] = True
            report = verify_fv.evaluate_results(
                payload(
                    proof,
                    result("check_reach_witness", verify_fv.COUNTEREXAMPLE, valid=True),
                ),
                manifest(),
            )
            self.assertEqual("fail", report["status"], field)
        proof = result("check_property", verify_fv.PASS)
        proof["num_paths"] = [True, 1, 0]
        report = verify_fv.evaluate_results(
            payload(proof, result("check_reach_witness", verify_fv.COUNTEREXAMPLE, valid=True)),
            manifest(),
        )
        self.assertEqual("fail", report["status"])

    def test_halmos_interpreter_must_share_verifier_environment(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            launcher = Path(directory) / "halmos"
            launcher.write_text("#!/different/venv/bin/python\n")
            interpreter, problems = verify_fv._halmos_interpreter(str(launcher))
        self.assertEqual("/different/venv/bin/python", interpreter)
        self.assertTrue(any("differs from verifier" in problem for problem in problems))

    def test_harness_artifact_compiler_drift_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source_name = "test-forge/fv/Proof.t.sol"
            source = root / source_name
            source.parent.mkdir(parents=True)
            source.write_text("contract Proof {}\n")
            artifact = root / "artifacts-forge" / "Proof.t.sol" / "Proof.json"
            artifact.parent.mkdir(parents=True)
            source_keccak = "0x" + verify_fv.keccak256(source.read_bytes()).hex()
            bytecode = "0x60a1010002"
            artifact.write_text(
                json.dumps(
                    {
                        "metadata": {
                            "compiler": {"version": "0.8.34+commit.deadbeef"},
                            "sources": {source_name: {"keccak256": source_keccak}},
                            "settings": {
                                "compilationTarget": {source_name: "Proof"},
                                "evmVersion": "cancun",
                                "optimizer": {"enabled": True, "runs": 200},
                                "viaIR": True,
                            },
                        },
                        "bytecode": {"object": bytecode},
                        "deployedBytecode": {"object": bytecode},
                    }
                )
            )
            with patch.object(verify_fv, "REPO_ROOT", root):
                _, problems = verify_fv._halmos_artifact_record(
                    artifact, source_name, "Proof", build_manifest()
                )
        self.assertTrue(any("compiler version" in problem for problem in problems))

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
