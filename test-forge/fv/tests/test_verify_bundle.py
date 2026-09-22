from __future__ import annotations

import hashlib
import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).resolve().parents[1] / "verify_bundle.py"
SPEC = importlib.util.spec_from_file_location("verify_bundle", MODULE_PATH)
assert SPEC and SPEC.loader
verify_bundle = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = verify_bundle
SPEC.loader.exec_module(verify_bundle)


class CollectEvidenceTest(unittest.TestCase):
    manifest_sha256 = "a" * 64
    git_commit = "b" * 40

    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory()
        root = Path(self.directory.name)
        self.manifest = json.loads(verify_bundle.DEFAULT_MANIFEST.read_text())
        self.reports: list[Path] = []
        self.data: dict[str, dict] = {}
        for index, gate in enumerate(verify_bundle.EXPECTED_GATES):
            state = {
                "available": True,
                "head": self.git_commit,
                "clean": True,
                "status_sha256": hashlib.sha256(b"").hexdigest(),
                "status_entries": 0,
                "head_exitcode": 0,
                "status_exitcode": 0,
            }
            provenance = verify_bundle.build_generation_provenance(state, dict(state))
            report = {
                "schema_version": 1,
                "gate": gate,
                "status": "pass",
                "release_eligible": True,
                "manifest_sha256": self.manifest_sha256,
                "git_commit": self.git_commit,
                "generation_provenance": provenance,
            }
            self.data[gate] = report
            self.reports.append(root / f"{index}.json")
        self.data["relay-artifact-parity"]["deployment"] = self.data[
            "relay-deployment-artifact"
        ]
        target = self.manifest["target"]
        optimized_ir_sha = verify_bundle.digest(
            verify_bundle.REPO / target["optimized_ir_snapshot"]
        )
        storage_value = json.loads(
            (verify_bundle.REPO / target["storage_layout_snapshot"]).read_text()
        )
        storage_sha = hashlib.sha256(
            (
                json.dumps(storage_value, separators=(",", ":"), sort_keys=True)
                + "\n"
            ).encode()
        ).hexdigest()
        self.data["relay-artifact-parity"]["optimized_ir"] = {
            "path": target["optimized_ir_snapshot"],
            "generated_sha256": optimized_ir_sha,
            "committed_sha256": optimized_ir_sha,
            "identical": True,
        }
        self.data["relay-artifact-parity"]["storage_layout"] = {
            "path": target["storage_layout_snapshot"],
            "generated_sha256": storage_sha,
            "committed_sha256": storage_sha,
            "identical": True,
        }
        self.data["relay-deployment-artifact"]["inputs"] = {
            "release_eligible": True,
            "problems": [],
            "node": {
                "mode": "clean-install-and-compile-in-process",
                "pnpm_version": "10.33.0",
                "release_eligible": True,
                "problems": [],
                "commands": [
                    {
                        "command": ["pnpm", "install", "--frozen-lockfile", "--force"],
                        "exitcode": 0,
                    },
                    {"command": ["pnpm", "hardhat", "clean"], "exitcode": 0},
                    {"command": ["pnpm", "compile"], "exitcode": 0},
                ],
            },
        }
        custom_config = self.manifest["relay_custom_error_abi"]
        self.data["relay-custom-error-abi"]["sources"] = [
            {"path": custom_config["source"], "sha256": "a" * 64},
            {"path": custom_config["interface_source"], "sha256": "b" * 64},
        ]
        tree = {
            "available": True,
            "root": "dependencies",
            "tree_sha256": "f" * 64,
            "files": 1,
            "directories": 1,
            "symlinks": 0,
            "error": None,
        }
        soldeer = {
            "mode": "clean-install-in-process",
            "command": ["forge", "soldeer", "install", "--clean"],
            "exitcode": 0,
            "lock_sha256_before": "e" * 64,
            "lock_sha256_after": "e" * 64,
            "tree_after_install": tree,
            "tree_at_end": dict(tree),
            "stable_during_gate": True,
            "release_eligible": True,
            "problems": [],
        }
        for gate in ("relay-artifact-parity", "relay-certora-local"):
            self.data[gate]["inputs"] = {
                "release_eligible": True,
                "problems": [],
                "soldeer": soldeer,
            }
        external_state = {
            "available": True,
            "head": "c" * 40,
            "clean": True,
            "status_sha256": hashlib.sha256(b"").hexdigest(),
            "status_entries": 0,
            "head_exitcode": 0,
            "status_exitcode": 0,
        }
        self.data["relay-lean"]["inputs"] = {
            "release_eligible": True,
            "problems": [],
            "evmyullean": {
                "release_eligible": True,
                "problems": [],
                "evmyullean_commit": "c" * 40,
                "source_start": external_state,
                "source_after_build": dict(external_state),
                "packages": [
                    {
                        "name": "mathlib",
                        "expected_revision": "d" * 40,
                        "git": {**external_state, "head": "d" * 40},
                        "release_eligible": True,
                        "problems": [],
                    }
                ],
                "packages_after_build": [
                    {
                        "name": "mathlib",
                        "expected_revision": "d" * 40,
                        "git": {**external_state, "head": "d" * 40},
                        "release_eligible": True,
                        "problems": [],
                    }
                ],
                "build": {
                    "mode": "cache-refresh-clean-build-in-process",
                    "commands": [
                        {"command": ["lake", "exe", "cache", "get"], "exitcode": 0},
                        {"command": ["lake", "clean"], "exitcode": 0},
                        {"command": ["lake", "build", "EvmYul"], "exitcode": 0},
                    ],
                    "output_tree": {**tree, "root": "build"},
                },
            },
        }
        self.data["relay-halmos"].update(
            {
                "release_eligible": True,
                "toolchain": {"halmos_forge": "/pinned/bin/forge"},
                "inputs": {
                    "release_eligible": True,
                    "problems": [],
                    "halmos_config": {
                        "effective": {
                            "forge_build_out": "artifacts-forge",
                            "loop": 6,
                            "solver": "z3",
                            "solver_timeout_assertion": 0,
                        }
                    },
                    "halmos_foundry_build": {
                        "command": ["/pinned/bin/forge", "config", "--json"],
                        "environment": {
                            "FOUNDRY_PROFILE": "default",
                            "FOUNDRY_SRC": "test-forge/fv",
                            "FOUNDRY_TEST": "test-forge/fv",
                            "FOUNDRY_OUT": "artifacts-forge",
                            "FOUNDRY_CACHE_PATH": "cache-forge",
                            "FOUNDRY_SOLC_VERSION": "0.8.35",
                            "FOUNDRY_AUTO_DETECT_SOLC": "false",
                            "FOUNDRY_EVM_VERSION": "cancun",
                            "FOUNDRY_OPTIMIZER": "true",
                            "FOUNDRY_OPTIMIZER_RUNS": "200",
                            "FOUNDRY_VIA_IR": "true",
                            "FOUNDRY_ADDITIONAL_COMPILER_PROFILES": "[]",
                            "FOUNDRY_COMPILATION_RESTRICTIONS": "[]",
                        },
                        "effective": {
                            "src": "test-forge/fv",
                            "test": "test-forge/fv",
                            "out": "artifacts-forge",
                            "cache_path": "cache-forge",
                            "solc": "0.8.35",
                            "auto_detect_solc": False,
                            "evm_version": "cancun",
                            "optimizer": True,
                            "optimizer_runs": 200,
                            "via_ir": True,
                            "additional_compiler_profiles": [],
                            "compilation_restrictions": [],
                        },
                    },
                    "soldeer": soldeer,
                    "artifacts_before_halmos": {
                        name: {
                            "available": True,
                            "artifact_sha256": character * 64,
                            "creation_semantic_sha256": "d" * 64,
                            "runtime_semantic_sha256": "e" * 64,
                        }
                        for name, character in (
                            ("contracts/protocol/implementation/Relay.sol:Relay", "a"),
                            ("contracts/protocol/implementation/RelayProxy.sol:RelayProxy", "b"),
                            ("test-forge/fv/Proof.t.sol:Proof", "c"),
                        )
                    },
                },
                "checks": [
                    {"id": "test-forge/fv/Proof.t.sol:Proof.check_property"}
                ],
                "execution": {
                    "mode": "generated-in-process",
                    "raw_results_sha256": "c" * 64,
                    "halmos_process_exitcode": 1,
                    "command": [
                        "halmos", "--root", "/repo", "--config", "/repo/halmos.toml",
                        "--function", "check_", "--forge-build-out", "artifacts-forge",
                        "--loop", "6", "--solver", "z3", "--solver-timeout-assertion", "0",
                        "--json-output", "/tmp/results.json",
                    ],
                },
            }
        )
        self.data["relay-halmos"]["inputs"]["artifacts_after_halmos"] = self.data[
            "relay-halmos"
        ]["inputs"]["artifacts_before_halmos"]
        self._write()

    def tearDown(self) -> None:
        self.directory.cleanup()

    def _write(self) -> None:
        for path, gate in zip(self.reports, verify_bundle.EXPECTED_GATES):
            path.write_text(json.dumps(self.data[gate]))

    def collect(self, *, allow_development: bool = False) -> list[dict]:
        return verify_bundle.collect_evidence(
            self.reports,
            self.manifest,
            self.manifest_sha256,
            self.git_commit,
            allow_development=allow_development,
        )

    def test_accepts_complete_commit_and_manifest_bound_inventory(self) -> None:
        evidence = self.collect()
        self.assertEqual(set(verify_bundle.EXPECTED_GATES), {item["gate"] for item in evidence})

    def test_rejects_stale_manifest(self) -> None:
        self.data["relay-halmos"]["manifest_sha256"] = "c" * 64
        self._write()
        with self.assertRaisesRegex(ValueError, "different manifest"):
            self.collect()

    def test_rejects_stale_commit(self) -> None:
        self.data["relay-certora-local"]["git_commit"] = "c" * 40
        self._write()
        with self.assertRaisesRegex(ValueError, "different Git commit"):
            self.collect()

    def test_rejects_missing_gate(self) -> None:
        with self.assertRaisesRegex(ValueError, "missing required evidence gates"):
            verify_bundle.collect_evidence(
                self.reports[:-1], self.manifest, self.manifest_sha256, self.git_commit
            )

    def test_rejects_deployment_report_substitution(self) -> None:
        self.data["relay-artifact-parity"]["deployment"] = {"status": "pass"}
        self._write()
        with self.assertRaisesRegex(ValueError, "not bound"):
            self.collect()

    def test_rejects_missing_artifact_baseline_evidence(self) -> None:
        del self.data["relay-artifact-parity"]["storage_layout"]
        self._write()
        with self.assertRaisesRegex(ValueError, "storage_layout evidence"):
            self.collect()

    def test_rejects_nonidentical_artifact_baseline(self) -> None:
        self.data["relay-artifact-parity"]["optimized_ir"]["identical"] = False
        self._write()
        with self.assertRaisesRegex(ValueError, "optimized_ir evidence"):
            self.collect()

    def test_rejects_artifact_baseline_path_drift(self) -> None:
        self.data["relay-artifact-parity"]["storage_layout"]["path"] = "other.json"
        self._write()
        with self.assertRaisesRegex(ValueError, "storage_layout evidence"):
            self.collect()

    def test_rejects_artifact_baseline_digest_drift(self) -> None:
        record = self.data["relay-artifact-parity"]["optimized_ir"]
        record["generated_sha256"] = "c" * 64
        record["committed_sha256"] = "c" * 64
        self._write()
        with self.assertRaisesRegex(ValueError, "optimized_ir evidence"):
            self.collect()

    def test_rejects_imported_halmos_results(self) -> None:
        provenance = self.data["relay-halmos"]["generation_provenance"]
        provenance["mode"] = verify_bundle.IMPORTED_MODE
        provenance["release_eligible"] = False
        provenance["development_reasons"] = ["results-were-not-generated-in-process"]
        self.data["relay-halmos"].update(
            {
                "release_eligible": False,
                "execution": {
                    "mode": "imported-results",
                    "raw_results_sha256": "c" * 64,
                    "halmos_process_exitcode": None,
                    "input_path": "/tmp/stale.json",
                },
            }
        )
        self._write()
        with self.assertRaisesRegex(ValueError, "development-only"):
            self.collect()
        evidence = self.collect(allow_development=True)
        halmos = next(item for item in evidence if item["gate"] == "relay-halmos")
        self.assertFalse(halmos["release_eligible"])
        self.assertEqual("imported-results", halmos["generation_mode"])

    def test_rejects_incomplete_generated_halmos_provenance(self) -> None:
        del self.data["relay-halmos"]["execution"]["raw_results_sha256"]
        self._write()
        with self.assertRaisesRegex(ValueError, "raw-results SHA-256"):
            self.collect()

    def test_rejects_release_halmos_command_override(self) -> None:
        self.data["relay-halmos"]["execution"]["command"].extend(
            ["--solver-command", "unreviewed-solver"]
        )
        self._write()
        with self.assertRaisesRegex(ValueError, "overrides or unexpected"):
            self.collect()

    def test_rejects_release_halmos_foundry_scope_drift(self) -> None:
        self.data["relay-halmos"]["inputs"]["halmos_foundry_build"]["effective"][
            "src"
        ] = "contracts"
        self._write()
        with self.assertRaisesRegex(ValueError, "exact audited Foundry build scope"):
            self.collect()

    def test_rejects_release_halmos_foundry_audit_command_drift(self) -> None:
        self.data["relay-halmos"]["inputs"]["halmos_foundry_build"]["command"] = [
            "other-forge",
            "config",
            "--json",
        ]
        self._write()
        with self.assertRaisesRegex(ValueError, "exact audited Foundry build scope"):
            self.collect()

    def test_rejects_boolean_schema_version(self) -> None:
        self.data["relay-certora-local"]["schema_version"] = True
        self._write()
        with self.assertRaisesRegex(ValueError, "unsupported evidence schema"):
            self.collect()

    def test_rejects_custom_error_source_override(self) -> None:
        self.data["relay-custom-error-abi"]["sources"][0]["path"] = "/tmp/alternate.sol"
        self._write()
        with self.assertRaisesRegex(ValueError, "manifest production paths"):
            self.collect()

    def test_selected_manifest_controls_release_input_validation(self) -> None:
        selected = json.loads(json.dumps(self.manifest))
        selected["relay_custom_error_abi"]["source"] = "contracts/SelectedRelay.sol"
        self.data["relay-custom-error-abi"]["sources"][0]["path"] = (
            "contracts/SelectedRelay.sol"
        )
        self._write()
        evidence = verify_bundle.collect_evidence(
            self.reports,
            selected,
            self.manifest_sha256,
            self.git_commit,
        )
        self.assertEqual(set(verify_bundle.EXPECTED_GATES), {item["gate"] for item in evidence})

    def test_dirty_generated_then_restored_cannot_be_promoted(self) -> None:
        report = self.data["relay-deployment-artifact"]
        provenance = report["generation_provenance"]
        provenance["start"]["clean"] = False
        provenance["start"]["status_sha256"] = "d" * 64
        provenance["start"]["status_entries"] = 1
        provenance["release_eligible"] = False
        provenance["development_reasons"] = ["worktree-dirty-at-start"]
        report["release_eligible"] = False
        self.data["relay-artifact-parity"]["deployment"] = report
        self._write()
        with self.assertRaisesRegex(ValueError, "development-only"):
            self.collect()
        evidence = self.collect(allow_development=True)
        deployment = next(item for item in evidence if item["gate"] == "relay-deployment-artifact")
        self.assertFalse(deployment["release_eligible"])


if __name__ == "__main__":
    unittest.main()
