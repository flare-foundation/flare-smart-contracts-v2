from __future__ import annotations

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
        self.reports: list[Path] = []
        self.data: dict[str, dict] = {}
        for index, gate in enumerate(verify_bundle.EXPECTED_GATES):
            report = {
                "schema_version": 1,
                "gate": gate,
                "status": "pass",
                "manifest_sha256": self.manifest_sha256,
                "git_commit": self.git_commit,
            }
            self.data[gate] = report
            self.reports.append(root / f"{index}.json")
        self.data["relay-artifact-parity"]["deployment"] = self.data[
            "relay-deployment-artifact"
        ]
        self._write()

    def tearDown(self) -> None:
        self.directory.cleanup()

    def _write(self) -> None:
        for path, gate in zip(self.reports, verify_bundle.EXPECTED_GATES, strict=True):
            path.write_text(json.dumps(self.data[gate]))

    def collect(self) -> list[dict]:
        return verify_bundle.collect_evidence(
            self.reports, self.manifest_sha256, self.git_commit
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
        self.data["relay-gss-governance"]["git_commit"] = "c" * 40
        self._write()
        with self.assertRaisesRegex(ValueError, "different Git commit"):
            self.collect()

    def test_rejects_missing_gate(self) -> None:
        with self.assertRaisesRegex(ValueError, "missing required evidence gates"):
            verify_bundle.collect_evidence(
                self.reports[:-1], self.manifest_sha256, self.git_commit
            )

    def test_rejects_deployment_report_substitution(self) -> None:
        self.data["relay-artifact-parity"]["deployment"] = {"status": "pass"}
        self._write()
        with self.assertRaisesRegex(ValueError, "not bound"):
            self.collect()


if __name__ == "__main__":
    unittest.main()
