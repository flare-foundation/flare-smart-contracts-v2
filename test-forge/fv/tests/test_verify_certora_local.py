from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).resolve().parents[1] / "verify_certora_local.py"
SPEC = importlib.util.spec_from_file_location("verify_certora_local", MODULE_PATH)
assert SPEC and SPEC.loader
verify_certora_local = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = verify_certora_local
SPEC.loader.exec_module(verify_certora_local)


class ToolVersionParsingTest(unittest.TestCase):
    def test_parses_and_rejects_drifted_foundry_build(self) -> None:
        expected = {
            "version": "1.7.2-nightly",
            "commit": "160b60260db63ce6204f2ee15764aca3e9ef04fe",
        }
        output = (
            "forge Version: 1.7.2-nightly\n"
            "Commit SHA: 160b60260db63ce6204f2ee15764aca3e9ef04fe\n"
        )
        self.assertEqual(expected, verify_certora_local.foundry_build(output))
        self.assertEqual([], verify_certora_local.foundry_problems(expected, expected, 0))
        drifted = verify_certora_local.foundry_build(output.replace("1.7.2", "1.7.1"))
        self.assertTrue(
            any("Foundry version" in problem for problem in verify_certora_local.foundry_problems(drifted, expected, 0))
        )
        self.assertTrue(verify_certora_local.foundry_problems(expected, expected, True))

    def test_parses_certora_cli_version(self) -> None:
        self.assertEqual("8.16.1", verify_certora_local.certora_version("certora-cli 8.16.1"))

    def test_parses_java_21_version(self) -> None:
        output = 'openjdk version "21.0.11" 2026-04-21 LTS'
        self.assertEqual(21, verify_certora_local.java_major(output))

    def test_normalizes_native_solc_platform_suffixes(self) -> None:
        self.assertEqual(
            "0.8.35+commit.47b9dedd",
            verify_certora_local.solc_long_version(
                "Version: 0.8.35+commit.47b9dedd.Darwin.appleclang\n"
            ),
        )
        self.assertEqual(
            "0.8.35+commit.47b9dedd",
            verify_certora_local.solc_long_version(
                "Version: 0.8.35+commit.47b9dedd.Linux.g++\n"
            ),
        )


class ConfigAuditTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.repo = Path(self.temporary.name)
        (self.repo / "certora/specs").mkdir(parents=True)
        self.config_name = "certora/Relay.conf"
        self.spec_name = "certora/specs/Test.spec"
        self.rules = ["firstRule", "secondRule"]
        self.config = {
            "files": ["contracts/protocol/implementation/Relay.sol"],
            "verify": f"Relay:{self.spec_name}",
            "solc": "solc0.8.35",
            "solc_via_ir": True,
            "solc_optimize": "200",
            "solc_evm_version": "cancun",
            "packages": ["example/=dependencies/example-1.0.0/"],
            "loop_iter": "3",
            "optimistic_loop": True,
            "optimistic_hashing": True,
            "hashing_length_bound": "512",
            "rule_sanity": "basic",
            "wait_for_results": "all",
            "prover_args": ["-enableStorageSplitting false"],
            "rule": self.rules,
            "msg": "an unaudited descriptive field",
        }
        self.expectation = {
            key: self.config[key]
            for key in verify_certora_local.AUDITED_CONFIG_FIELDS
            if key in self.config
        }
        self.settings = {
            "config_glob": "certora/Relay*.conf",
            "configs": [self.config_name],
            "config_expectations": {self.config_name: self.expectation},
        }
        (self.repo / self.spec_name).write_text(
            "rule firstRule() { assert true; }\nrule secondRule() { assert true; }\n"
        )
        self._write_config()

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def _write_config(self) -> None:
        (self.repo / self.config_name).write_text(json.dumps(self.config))

    def test_accepts_exact_config_and_spec_inventory(self) -> None:
        records, violations = verify_certora_local.audit_configs(self.settings, self.repo)
        self.assertEqual([], violations)
        self.assertEqual("pass", records[0]["status"])
        self.assertEqual(self.rules, records[0]["rules"])

    def test_rejects_every_security_relevant_config_drift(self) -> None:
        mutations = {
            "files": ["contracts/protocol/implementation/Other.sol"],
            "verify": f"Other:{self.spec_name}",
            "solc": "solc0.8.34",
            "solc_via_ir": False,
            "solc_optimize": "199",
            "solc_evm_version": "paris",
            "packages": ["wrong/=dependencies/wrong/"],
            "loop_iter": "2",
            "optimistic_loop": False,
            "optimistic_hashing": False,
            "hashing_length_bound": "256",
            "rule_sanity": "none",
            "wait_for_results": "none",
            "prover_args": [],
            "rule": ["firstRule"],
        }
        for field, value in mutations.items():
            with self.subTest(field=field):
                original = self.config[field]
                self.config[field] = value
                self._write_config()
                _, violations = verify_certora_local.audit_configs(self.settings, self.repo)
                self.assertTrue(any(f"{field} is" in item for item in violations), violations)
                self.config[field] = original
        self._write_config()

    def test_rejects_source_config_missing_from_manifest(self) -> None:
        (self.repo / "certora/Relay-extra.conf").write_text(json.dumps(self.config))
        _, violations = verify_certora_local.audit_configs(self.settings, self.repo)
        self.assertTrue(any("source configs missing from manifest" in item for item in violations))

    def test_rejects_and_records_non_object_expectations(self) -> None:
        original = self.settings["config_expectations"][self.config_name]
        for label, malformed in (("null", None), ("list", []), ("scalar", "invalid")):
            with self.subTest(kind=label):
                self.settings["config_expectations"][self.config_name] = malformed
                records, violations = verify_certora_local.audit_configs(self.settings, self.repo)
                self.assertTrue(any("expectation must be an object" in item for item in violations))
                self.assertEqual(1, len(records))
                self.assertEqual("fail", records[0]["status"])
                self.assertEqual(
                    "null" if malformed is None else type(malformed).__name__,
                    records[0]["expectation_type"],
                )
        self.settings["config_expectations"][self.config_name] = original

    def test_rejects_unconfigured_spec_rule(self) -> None:
        (self.repo / self.spec_name).write_text(
            "rule firstRule() { assert true; }\n"
            "rule secondRule() { assert true; }\n"
            "rule unconfiguredRule() { assert true; }\n"
        )
        _, violations = verify_certora_local.audit_configs(self.settings, self.repo)
        self.assertTrue(any("do not exactly match" in item for item in violations))

    def test_rejects_storage_splitting_drift(self) -> None:
        self.config["prover_args"] = ["-enableStorageSplitting true"]
        self._write_config()
        _, violations = verify_certora_local.audit_configs(self.settings, self.repo)
        self.assertTrue(any("prover_args is" in item for item in violations))

    def test_rejects_optimistic_model_drift(self) -> None:
        self.config["optimistic_loop"] = False
        self.config["optimistic_hashing"] = False
        self._write_config()
        _, violations = verify_certora_local.audit_configs(self.settings, self.repo)
        self.assertTrue(any("optimistic_loop is" in item for item in violations))
        self.assertTrue(any("optimistic_hashing is" in item for item in violations))

    def test_requires_hashing_fields_in_config_and_manifest(self) -> None:
        for field in ("optimistic_hashing", "hashing_length_bound"):
            with self.subTest(field=field):
                config_value = self.config.pop(field)
                self._write_config()
                _, violations = verify_certora_local.audit_configs(self.settings, self.repo)
                self.assertTrue(
                    any(
                        "proof-semantic field inventory differs" in item and field in item
                        for item in violations
                    ),
                    violations,
                )
                self.config[field] = config_value

                expectation_value = self.expectation.pop(field)
                self._write_config()
                _, violations = verify_certora_local.audit_configs(self.settings, self.repo)
                self.assertTrue(
                    any(
                        "invalid expectation fields" in item and field in item
                        for item in violations
                    ),
                    violations,
                )
                self.expectation[field] = expectation_value
        self._write_config()

    def test_rejects_wrong_hashing_field_types_even_when_manifest_matches(self) -> None:
        malformed_values = {
            "optimistic_hashing": 1,
            "hashing_length_bound": 512,
        }
        for field, malformed in malformed_values.items():
            with self.subTest(field=field):
                config_value = self.config[field]
                expectation_value = self.expectation[field]
                self.config[field] = malformed
                self.expectation[field] = malformed
                self._write_config()
                _, violations = verify_certora_local.audit_configs(self.settings, self.repo)
                self.assertTrue(
                    any(
                        f"manifest expectation {field} must be exactly" in item
                        for item in violations
                    ),
                    violations,
                )
                self.config[field] = config_value
                self.expectation[field] = expectation_value
        self._write_config()

    def test_rejects_unmanifested_config_field(self) -> None:
        self.config["future_prover_switch"] = True
        self._write_config()
        _, violations = verify_certora_local.audit_configs(self.settings, self.repo)
        self.assertTrue(any("field inventory differs" in item for item in violations))


if __name__ == "__main__":
    unittest.main()
