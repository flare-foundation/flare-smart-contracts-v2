from __future__ import annotations

import hashlib
import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch


MODULE_PATH = Path(__file__).resolve().parents[1] / "report_provenance.py"
SPEC = importlib.util.spec_from_file_location("report_provenance_test_module", MODULE_PATH)
assert SPEC and SPEC.loader
report_provenance = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = report_provenance
SPEC.loader.exec_module(report_provenance)


def state(*, clean: bool, head: str = "a" * 40) -> dict:
    status = b"" if clean else b" M contracts/protocol/implementation/Relay.sol\n"
    return {
        "available": True,
        "head": head,
        "clean": clean,
        "status_sha256": hashlib.sha256(status).hexdigest(),
        "status_entries": len(status.splitlines()),
        "head_exitcode": 0,
        "status_exitcode": 0,
    }


class GenerationProvenanceTest(unittest.TestCase):
    def test_clean_in_process_generation_is_release_eligible(self) -> None:
        provenance = report_provenance.build_generation_provenance(
            state(clean=True), state(clean=True)
        )
        self.assertTrue(provenance["release_eligible"])
        self.assertEqual([], provenance["development_reasons"])

    def test_dirty_generated_then_restored_stays_development_only(self) -> None:
        provenance = report_provenance.build_generation_provenance(
            state(clean=False), state(clean=True)
        )
        self.assertFalse(provenance["release_eligible"])
        self.assertIn("worktree-dirty-at-start", provenance["development_reasons"])

    def test_imported_results_are_never_release_eligible(self) -> None:
        provenance = report_provenance.build_generation_provenance(
            state(clean=True),
            state(clean=True),
            mode=report_provenance.IMPORTED_MODE,
        )
        self.assertFalse(provenance["release_eligible"])
        self.assertIn(
            "results-were-not-generated-in-process", provenance["development_reasons"]
        )

    def test_head_change_during_generation_is_development_only(self) -> None:
        provenance = report_provenance.build_generation_provenance(
            state(clean=True), state(clean=True, head="b" * 40)
        )
        self.assertFalse(provenance["release_eligible"])
        self.assertIn("head-changed-during-generation", provenance["development_reasons"])

    def test_dependency_tree_digest_detects_ignored_input_mutation(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "package").mkdir()
            source = root / "package" / "Source.sol"
            source.write_text("A")
            before = report_provenance.dependency_tree_state(root)
            source.write_text("B")
            after = report_provenance.dependency_tree_state(root)
        self.assertTrue(before["available"])
        self.assertNotEqual(before["tree_sha256"], after["tree_sha256"])

    def test_soldeer_preparation_uses_clean_mode(self) -> None:
        completed = Mock(returncode=0, stdout="ok", stderr="")
        with tempfile.TemporaryDirectory() as directory:
            repo = Path(directory)
            (repo / "soldeer.lock").write_text("lock")
            (repo / "dependencies").mkdir()
            with patch.object(report_provenance.subprocess, "run", return_value=completed) as run:
                record, problems = report_provenance.clean_install_soldeer(repo, "forge")
        self.assertEqual([], problems)
        self.assertEqual(["forge", "soldeer", "install", "--clean"], run.call_args.args[0])
        self.assertEqual("clean-install-in-process", record["mode"])


if __name__ == "__main__":
    unittest.main()
