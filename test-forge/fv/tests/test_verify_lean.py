from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch


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

    def test_required_witness_audit_cannot_be_replaced_by_another_result(self) -> None:
        # Inventory enforcement, not a semantic non-vacuity detector: Lean checks the witness statement.
        lean_manifest = {
            "declared_axioms": {},
            "axiom_audit_counts": {"Witness.lean": 1},
            "required_results": {"Witness.lean": ["Scope.acceptance_witness"]},
        }
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "Witness.lean"
            path.write_text("theorem unrelated : True := by trivial\n#print axioms unrelated\n")
            _, problems = verify_lean.source_audit(path, lean_manifest)
        self.assertTrue(any("required axiom audit 'Scope.acceptance_witness' is missing" in p for p in problems))
        self.assertFalse(any("manifest requires" in p for p in problems))

    def test_axiom_output_ignores_quoted_linter_warnings(self) -> None:
        output = (
            "Proof.lean:7:3: warning: 'simp [h]' tactic does nothing\n"
            "Note: disable with `set_option linter.unusedTactic false`\n"
            "'Scope.result!' depends on axioms: [propext,\n Classical.choice]\n"
        )
        self.assertEqual(
            [("Scope.result!", ["propext", "Classical.choice"])],
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

    def test_source_audit_rejects_boolean_axiom_count(self) -> None:
        lean_manifest = {
            "declared_axioms": {},
            "axiom_audit_counts": {"Bad.lean": True},
            "required_results": {},
        }
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "Bad.lean"
            path.write_text("theorem ok : True := by trivial\n#print axioms ok\n")
            _, problems = verify_lean.source_audit(path, lean_manifest)
        self.assertTrue(any("manifest requires True" in problem for problem in problems))

    def test_dirty_lake_package_is_development_only(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "lake-manifest.json").write_text(
                '{"packages":[{"name":"mathlib","rev":"' + "a" * 40 + '"}]}'
            )
            dirty = {
                "available": True,
                "head": "a" * 40,
                "clean": False,
                "status_sha256": "b" * 64,
                "status_entries": 1,
            }
            with patch.object(verify_lean, "capture_git_state", return_value=dirty):
                records, problems = verify_lean._lake_package_provenance(root)
        self.assertFalse(records[0]["release_eligible"])
        self.assertTrue(any("modified or untracked" in problem for problem in problems))

    def test_repeated_gate_checks_absolute_sources_without_copying_into_dependency(self) -> None:
        names = [verify_lean.ABSTRACT] + verify_lean.STANDALONE + [verify_lean.INTEGRATION]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            lean = root / "proofs"
            refinement = lean / "bytecode-refinement"
            refinement.mkdir(parents=True)
            evmyul = root / "EVMYulLean"
            evmyul.mkdir()
            sources = {
                name: (lean if name == verify_lean.ABSTRACT else refinement) / name
                for name in names
            }
            for source in sources.values():
                source.write_text("theorem result : True := by trivial\n#print axioms result\n")
            originals = {source: source.read_bytes() for source in sources.values()}
            manifest = root / "manifest.json"
            manifest.write_text(json.dumps({
                "schema_version": 1,
                "lean": {
                    "allowed_axioms": [],
                    "declared_axioms": {},
                    "axiom_audit_counts": {name: 1 for name in names},
                    "required_results": {name: ["result"] for name in names},
                },
            }))
            commands = []

            def clean_checkout(path, _manifest):
                self.assertEqual(path, evmyul)
                self.assertEqual(list(evmyul.glob("*.lean")), [])
                return {"release_eligible": True, "problems": []}, []

            def checked_run(command, *, cwd):
                commands.append(command)
                self.assertEqual(cwd, evmyul)
                self.assertEqual(command[:3], ["lake", "env", "lean"])
                source = Path(command[4])
                self.assertTrue(source.is_absolute())
                self.assertEqual(command[3], f"--root={source.parent}")
                self.assertIn(source, originals)
                self.assertEqual(source.read_bytes(), originals[source])
                return subprocess.CompletedProcess(
                    command, 0, "'result' does not depend on any axioms\n", ""
                )

            with (
                patch.object(verify_lean, "LEAN_DIR", lean),
                patch.object(verify_lean, "REFINEMENT_DIR", refinement),
                patch.object(verify_lean, "parse_args", return_value=SimpleNamespace(
                    manifest=manifest, report_output=None,
                )),
                patch.dict(verify_lean.os.environ, {"EVMYUL_DIR": str(evmyul)}),
                patch.object(verify_lean, "verify_evmyul_checkout", side_effect=clean_checkout),
                patch.object(verify_lean, "prepare_evmyul_build", return_value=[]) as prepare,
                patch.object(verify_lean, "capture_git_state", return_value={"clean": True}),
                patch.object(verify_lean, "finalize_generation_provenance", return_value={
                    "release_eligible": True,
                }),
                patch.object(verify_lean, "report_commit", return_value="a" * 40),
                patch.object(verify_lean, "run", side_effect=checked_run),
                patch("builtins.print"),
            ):
                self.assertEqual(verify_lean.main(), 0)
                self.assertEqual(verify_lean.main(), 0)
                self.assertEqual(prepare.call_count, 2)

            expected = [
                ["lake", "env", "lean", f"--root={sources[name].parent}", str(sources[name])]
                for name in [verify_lean.ABSTRACT] + verify_lean.STANDALONE
            ]
            expected.extend([
                "lake", "env", "lean", f"--root={sources[f'{dependency}.lean'].parent}",
                str(sources[f"{dependency}.lean"]),
                "-o", str(evmyul / ".lake/build/lib/lean" / f"{dependency}.olean"),
            ] for dependency in verify_lean.INTEGRATION_DEPS)
            integration = sources[verify_lean.INTEGRATION]
            expected.append(["lake", "env", "lean", f"--root={integration.parent}", str(integration)])
            self.assertEqual(commands, expected * 2)
            self.assertEqual(list(evmyul.glob("*.lean")), [])
            self.assertEqual({source: source.read_bytes() for source in sources.values()}, originals)

    def test_clean_build_still_rejects_dirty_dependency_sources(self) -> None:
        provenance = {"packages": [], "problems": [], "release_eligible": True}
        completed = subprocess.CompletedProcess([], 0, "", "")
        with (
            patch.object(verify_lean, "run", return_value=completed),
            patch.object(verify_lean, "capture_git_state", return_value={"clean": False}),
            patch.object(verify_lean, "_lake_package_provenance", return_value=([], [])),
            patch.object(verify_lean, "dependency_tree_state", return_value={"available": True}),
        ):
            problems = verify_lean.prepare_evmyul_build(Path("/unused/EVMYulLean"), provenance)
        self.assertFalse(provenance["release_eligible"])
        self.assertTrue(any("source tree changed or became dirty" in problem for problem in problems))


if __name__ == "__main__":
    unittest.main()
