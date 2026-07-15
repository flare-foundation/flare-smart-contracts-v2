from __future__ import annotations

import importlib.util
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).resolve().parents[1] / "lean" / "verify_lean.py"
SPEC = importlib.util.spec_from_file_location("verify_lean", MODULE_PATH)
assert SPEC and SPEC.loader
verify_lean = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = verify_lean
SPEC.loader.exec_module(verify_lean)


class LeanGateTest(unittest.TestCase):
    def test_comment_stripping_is_nested_and_preserves_code(self) -> None:
        source = "theorem ok : True := by trivial /- sorry /- admit -/ -/\n-- native_decide\n#check ok\n"
        stripped = verify_lean.strip_lean_comments(source)
        self.assertNotIn("sorry", stripped)
        self.assertNotIn("admit", stripped)
        self.assertNotIn("native_decide", stripped)
        self.assertIn("#check ok", stripped)

    def test_source_audit_rejects_real_proof_hole(self) -> None:
        lean_manifest = {
            "declared_axioms": {},
            "axiom_audit_counts": {"Bad.lean": 0},
            "required_results": {},
        }
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "Bad.lean"
            path.write_text("theorem bad : True := by sorry\n")
            _, problems = verify_lean.source_audit(path, lean_manifest)
        self.assertTrue(any("forbidden source token 'sorry'" in problem for problem in problems))

    def test_axiom_output_handles_prime_names_and_axiom_free_results(self) -> None:
        output = (
            "'Scope.fromBytes'_append' depends on axioms: [propext]\n"
            "'Scope.pure_result' does not depend on any axioms\n"
        )
        self.assertEqual(
            [("Scope.fromBytes'_append", ["propext"]), ("Scope.pure_result", [])],
            verify_lean.parsed_axiom_output(output),
        )

    def test_output_audit_requires_every_directive_and_rejects_new_axiom(self) -> None:
        completed = subprocess.CompletedProcess(
            args=[],
            returncode=0,
            stdout="'Scope.result' depends on axioms: [propext, New.axiom]\n",
            stderr="",
        )
        source_record = {"axiom_audits": ["result"], "declared_axioms": [], "source_sha256": "x"}
        _, problems = verify_lean.audit_lean_output(
            Path("Proof.lean"), completed, source_record, {"propext"}
        )
        self.assertTrue(any("disallowed axioms" in problem for problem in problems))


if __name__ == "__main__":
    unittest.main()
