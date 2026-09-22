from __future__ import annotations

import importlib.util
import io
import json
import sys
import tarfile
import tempfile
import unittest
import zipfile
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch


MODULE_PATH = Path(__file__).resolve().parents[1] / "verify_certora_cloud.py"
SPEC = importlib.util.spec_from_file_location("verify_certora_cloud", MODULE_PATH)
assert SPEC and SPEC.loader
verify_certora_cloud = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = verify_certora_cloud
SPEC.loader.exec_module(verify_certora_cloud)


JOB_ID = "1" * 32
USER_ID = "42"
HEAD = "a" * 40


def cloud_log(*blocks: str) -> str:
    return "\n".join(
        [
            f"Follow your job at https://prover.certora.com/output/{USER_ID}/{JOB_ID}"
            "?anonymousKey=must-not-be-copied",
            f"[INFO]: Command: java -DjobId={JOB_ID} -DuserId={USER_ID} -jar emv.jar",
            *blocks,
            "Results for human-readable tables follow",
        ]
    )


class AggregateResultParserTest(unittest.TestCase):
    def test_parses_only_authoritative_aggregate_blocks(self) -> None:
        text = cloud_log(
            "Violated: invariant-f()-rule_not_vacuous",
            "invariant-f()-rule_not_vacuous: A property is violated",
            "Result for invariant: invariant: f(uint256): SUCCESS",
            "g(): SANITY_FAIL",
        )
        results, problems = verify_certora_cloud.parse_result_blocks(text)
        self.assertEqual([], problems)
        self.assertEqual(["invariant"], list(results))
        self.assertEqual(
            ["SUCCESS", "SANITY_FAIL"], [row["status"] for row in results["invariant"]]
        )
        self.assertEqual(
            "partial", verify_certora_cloud.classify_entries(results["invariant"])
        )

    def test_failure_unknown_timeout_and_skip_are_fail_closed(self) -> None:
        for status in ("FAIL", "UNKNOWN", "TIMEOUT", "SKIPPED", "FUTURE_STATUS"):
            with self.subTest(status=status):
                results, problems = verify_certora_cloud.parse_result_blocks(
                    cloud_log(f"Result for invariant: invariant: {status}")
                )
                self.assertEqual(
                    "fail", verify_certora_cloud.classify_entries(results["invariant"])
                )
                self.assertEqual(status == "FUTURE_STATUS", bool(problems))

    def test_duplicate_result_cannot_overwrite_adverse_first_block(self) -> None:
        results, problems = verify_certora_cloud.parse_result_blocks(
            cloud_log(
                "Result for invariant: invariant: FAIL: counterexample",
                "Result for invariant: invariant: SUCCESS",
            )
        )
        self.assertTrue(any("duplicate" in problem for problem in problems))
        self.assertEqual("FAIL", results["invariant"][0]["status"])

    def test_truncated_aggregate_block_at_eof_is_rejected(self) -> None:
        _, problems = verify_certora_cloud.parse_result_blocks(
            "Result for invariant: invariant: SUCCESS"
        )
        self.assertTrue(any("reaches EOF" in problem for problem in problems))

    def test_requires_one_url_bound_to_remote_command(self) -> None:
        identity = verify_certora_cloud.parse_job_identity(cloud_log())
        self.assertEqual(JOB_ID, identity["job_id"])
        self.assertNotIn("anonymousKey", identity["url"])
        with self.assertRaises(verify_certora_cloud.EvidenceError):
            verify_certora_cloud.parse_job_identity(
                f"https://prover.certora.com/output/{USER_ID}/{JOB_ID}"
            )

    def test_log_evidence_digest_excludes_anonymous_key_value(self) -> None:
        first = cloud_log().replace("must-not-be-copied", "first-secret")
        second = cloud_log().replace("must-not-be-copied", "second-secret")
        self.assertEqual(
            verify_certora_cloud.sanitized_log_sha256(first),
            verify_certora_cloud.sanitized_log_sha256(second),
        )


class SatisfyWitnessNormalizationTest(unittest.TestCase):
    SPEC_PATH = "certora/specs/Witness.spec"
    SPEC_SOURCE = (
        "rule witnessRule(env e) {\n"
        '    satisfy e.msg.value == 7, "a concrete witness";\n'
        "    assert true;\n"
        "}\n"
    )

    def setUp(self) -> None:
        self.expectations = verify_certora_cloud.satisfy_expectations(
            self.SPEC_SOURCE, self.SPEC_PATH
        )
        self.name = self.expectations[0]["name"]

    def aggregate(self, *, subject: str | None = None, status: str = "FAIL") -> dict:
        return {
            "witnessRule": [
                {
                    "subject": subject or self.name,
                    "status": status,
                    "detail": "a concrete witness",
                    "recognized_status": True,
                },
                {
                    "subject": "Assertions",
                    "status": "SUCCESS",
                    "detail": None,
                    "recognized_status": True,
                },
            ]
        }

    def table(
        self,
        *,
        parent: str = "witnessRule",
        name: str | None = None,
        marker: str = "(sat)",
        model: str = "e.msg.value=7",
        close_record: bool = True,
        close_border: bool = True,
    ) -> dict:
        lines = [
            f"Results for {parent}:",
            "*---*",
            "|Rule name|Verified|Time (sec)|Description|Local vars|",
            "|---|---|---|---|---|",
            f"|{name or self.name}|Not violated|1|Assert message: a concrete witness|{model}|",
            f"||{marker}||||",
        ]
        if close_record:
            lines.extend(
                [
                    "|Assertions|Not violated|1||no local variables|",
                    "||(unsat)||||",
                ]
            )
        if close_border:
            lines.append("*---*")
        return verify_certora_cloud.parse_detailed_tables("\n".join(lines))

    def test_satisfied_fail_has_exact_sat_model_corroboration(self) -> None:
        aggregate = self.aggregate()
        problems = verify_certora_cloud.corroborate_satisfy_results(
            aggregate, self.table(), self.expectations
        )
        self.assertEqual([], problems)
        entry = aggregate["witnessRule"][0]
        self.assertEqual("SATISFIED", entry["semantic_status"])
        self.assertEqual(
            "pass", verify_certora_cloud.classify_entries(aggregate["witnessRule"])
        )
        self.assertEqual(1, entry["satisfy_witness"]["concrete_assignments"])

    def test_comprehensive_all_table_is_not_a_second_semantic_parent(self) -> None:
        aggregate = self.aggregate()
        tables = self.table()
        tables["all"] = self.table()["witnessRule"]
        problems = verify_certora_cloud.corroborate_satisfy_results(
            aggregate, tables, self.expectations
        )
        self.assertEqual([], problems)
        self.assertEqual("SATISFIED", aggregate["witnessRule"][0]["semantic_status"])

    def test_unsatisfied_marker_remains_fatal(self) -> None:
        aggregate = self.aggregate()
        problems = verify_certora_cloud.corroborate_satisfy_results(
            aggregate, self.table(marker="(unsat)"), self.expectations
        )
        self.assertTrue(any("not semantically SAT" in problem for problem in problems))
        self.assertEqual(
            "fail", verify_certora_cloud.classify_entries(aggregate["witnessRule"])
        )

    def test_ordinary_aggregate_fail_remains_fatal(self) -> None:
        aggregate = {
            "ordinaryRule": [
                {
                    "subject": "Assertions",
                    "status": "FAIL",
                    "detail": "counterexample",
                    "recognized_status": True,
                }
            ]
        }
        problems = verify_certora_cloud.corroborate_satisfy_results(aggregate, {}, [])
        self.assertEqual([], problems)
        self.assertEqual(
            "fail", verify_certora_cloud.classify_entries(aggregate["ordinaryRule"])
        )

    def test_mismatched_spoofed_model_free_and_truncated_tables_fail(self) -> None:
        cases = {
            "wrong-parent": self.table(parent="otherRule"),
            "model-free": self.table(model="no local variables"),
            "nonconcrete-model": self.table(model="witness="),
            "truncated-record": self.table(close_record=False, close_border=False),
            "truncated-after-assertions": self.table(close_border=False),
            "wrong-name": self.table(name=self.name.replace("_2_5)", "_3_5)")),
        }
        duplicate = self.table()
        duplicate["witnessRule"] *= 2
        cases["duplicate-identical-occurrence"] = duplicate
        for label, tables in cases.items():
            with self.subTest(case=label):
                aggregate = self.aggregate()
                problems = verify_certora_cloud.corroborate_satisfy_results(
                    aggregate, tables, self.expectations
                )
                self.assertTrue(problems)
                self.assertEqual(
                    "fail",
                    verify_certora_cloud.classify_entries(aggregate["witnessRule"]),
                )


class ManifestBindingTest(unittest.TestCase):
    def setUp(self) -> None:
        self.config = "certora/Relay.conf"
        self.semantics = {"files": ["contracts/Relay.sol"]}
        self.manifest = {
            "certora_local": {
                "certora_cli": "8.16.1",
                "minimum_java_major": 21,
                "configs": [self.config],
                "config_expectations": {self.config: self.semantics},
            }
        }
        self.runs = [
            {
                "config": self.config,
                "toolchain": {"certora_cli": "8.16.1", "java": "21.0.12"},
                "inputs": {"config": {"proof_semantics": self.semantics}},
            }
        ]

    def test_accepts_exact_manifest_toolchain_and_config_binding(self) -> None:
        problems, _ = verify_certora_cloud.audit_manifest_binding(
            self.manifest, self.runs
        )
        self.assertEqual([], problems)

    def test_rejects_wrong_certora_cli(self) -> None:
        self.runs[0]["toolchain"]["certora_cli"] = "8.18.0"
        problems, _ = verify_certora_cloud.audit_manifest_binding(
            self.manifest, self.runs
        )
        self.assertTrue(any("submitted Certora CLI" in problem for problem in problems))

    def test_rejects_backend_version_different_from_manifest_cli(self) -> None:
        self.runs[0]["evidence"] = {"backend": {"certora_cli_tag": "8.18.0"}}
        problems, _ = verify_certora_cloud.audit_manifest_binding(
            self.manifest, self.runs
        )
        self.assertTrue(
            any("backend prover version" in problem for problem in problems)
        )

    def test_rejects_java_below_manifest_minimum(self) -> None:
        self.runs[0]["toolchain"]["java"] = "17.0.1"
        problems, _ = verify_certora_cloud.audit_manifest_binding(
            self.manifest, self.runs
        )
        self.assertTrue(any("submitted Java" in problem for problem in problems))

    def test_rejects_wrong_config_inventory_and_expectation(self) -> None:
        self.manifest["certora_local"]["configs"] = ["certora/Other.conf"]
        self.manifest["certora_local"]["config_expectations"] = {
            "certora/Other.conf": self.semantics
        }
        problems, _ = verify_certora_cloud.audit_manifest_binding(
            self.manifest, self.runs
        )
        self.assertTrue(any("config inventory" in problem for problem in problems))
        self.assertTrue(any("source config" in problem for problem in problems))


class BackendEvidenceBindingTest(unittest.TestCase):
    VERSION = {
        "gitLastTag": "8.16.1",
        "gitHashFull": "b" * 40,
        "gitIsClean": False,
    }

    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.output_path = self.root / "output.tar.gz"
        self.job_data_path = self.root / "jobData.json"
        self.log_text = cloud_log("Result for invariant: invariant: SUCCESS")
        self.job = verify_certora_cloud.parse_job_identity(self.log_text)
        self.aggregate, problems = verify_certora_cloud.parse_result_blocks(
            self.log_text
        )
        self.assertEqual([], problems)
        self.results = "\n".join(
            [
                "Result for invariant: invariant: SUCCESS",
                "Results for all:",
                "*---*",
                "|Rule name|Verified|Time (sec)|Description|Local vars|",
                "|---|---|---|---|---|",
                "|invariant|Not violated|1||no local variables|",
                "||(unsat)||||",
                "*---*",
            ]
        )
        self.write_job_data()
        self.write_archive()

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def write_job_data(self, **overrides: object) -> None:
        value = {
            "jobId": JOB_ID,
            "jobStatus": "SUCCEEDED",
            "anonymousKey": "must-not-be-copied",
            "outputUrl": f"https://prover.certora.com/output/{USER_ID}/{JOB_ID}/",
            "zipOutputUrl": (
                f"https://prover.certora.com/v1/domain/jobs/{JOB_ID}/f/outputs"
            ),
            "notifyMsg": "ignored and never persisted",
        }
        value.update(overrides)
        self.job_data_path.write_text(json.dumps(value))

    @staticmethod
    def _add_tar_bytes(archive: tarfile.TarFile, name: str, data: bytes) -> None:
        info = tarfile.TarInfo(name)
        info.size = len(data)
        archive.addfile(info, io.BytesIO(data))

    def write_archive(
        self,
        *,
        results: str | None = None,
        version: dict | None = None,
        extra_members: list[tuple[str, bytes]] | None = None,
        omit_results: bool = False,
    ) -> None:
        with tarfile.open(self.output_path, "w:gz") as archive:
            for name in ("TarName", "TarName/Reports"):
                info = tarfile.TarInfo(name)
                info.type = tarfile.DIRTYPE
                archive.addfile(info)
            if not omit_results:
                self._add_tar_bytes(
                    archive,
                    verify_certora_cloud.BACKEND_RESULTS_MEMBER,
                    (results if results is not None else self.results).encode(),
                )
            self._add_tar_bytes(
                archive,
                verify_certora_cloud.BACKEND_VERSION_MEMBER,
                json.dumps(version if version is not None else self.VERSION).encode(),
            )
            for name, data in extra_members or []:
                self._add_tar_bytes(archive, name, data)

    def load(self) -> tuple[dict, dict]:
        return verify_certora_cloud.load_backend_evidence(
            self.output_path,
            self.job_data_path,
            job=self.job,
            log_text=self.log_text,
            log_aggregate=self.aggregate,
        )

    def test_accepts_exact_backend_and_persists_only_sanitized_sidecar_data(
        self,
    ) -> None:
        tables, evidence = self.load()
        self.assertTrue(tables["all"][0]["complete"])
        self.assertEqual("8.16.1", evidence["certora_cli_tag"])
        self.assertTrue(evidence["aggregate_matches_log"])
        self.assertTrue(evidence["sanitized_job_metadata"]["anonymous_key_matches_log"])
        serialized = json.dumps(evidence)
        self.assertNotIn("must-not-be-copied", serialized)
        self.assertNotIn("notifyMsg", serialized)
        self.assertNotIn("job_data_sha256", serialized)

    def test_rejects_aggregate_mismatch_and_bad_version(self) -> None:
        self.write_archive(results=self.results.replace("SUCCESS", "FAIL"))
        with self.assertRaisesRegex(
            verify_certora_cloud.EvidenceError, "aggregate outcomes"
        ):
            self.load()
        self.write_archive(version={**self.VERSION, "gitLastTag": "8.18.0"})
        with self.assertRaisesRegex(verify_certora_cloud.EvidenceError, "version tag"):
            self.load()

    def test_rejects_bad_sidecar_job_status_urls_and_anonymous_binding(self) -> None:
        cases = {
            "job": {"jobId": "2" * 32},
            "status": {"jobStatus": "RUNNING"},
            "output-url": {
                "outputUrl": f"https://prover.certora.com/output/99/{JOB_ID}/"
            },
            "zip-url": {
                "zipOutputUrl": "https://prover.certora.com/v1/domain/jobs/"
                + "2" * 32
                + "/f/outputs"
            },
            "anonymous": {"anonymousKey": "different-key"},
        }
        for label, overrides in cases.items():
            with self.subTest(case=label):
                self.write_job_data(**overrides)
                with self.assertRaises(verify_certora_cloud.EvidenceError):
                    self.load()

    def test_rejects_missing_truncated_and_duplicate_detailed_tables(self) -> None:
        cases = {
            "missing": "Result for invariant: invariant: SUCCESS\nDone",
            "truncated": self.results.removesuffix("*---*"),
            "duplicate": self.results
            + "\n"
            + self.results[self.results.index("Results for all:") :],
        }
        for label, results in cases.items():
            with self.subTest(case=label):
                self.write_archive(results=results)
                with self.assertRaises(verify_certora_cloud.EvidenceError):
                    self.load()

    def test_rejects_bad_layout_traversal_missing_member_and_oversize(self) -> None:
        cases = {
            "layout": [("Other/file.txt", b"x")],
            "traversal": [("TarName/../escape", b"x")],
        }
        for label, members in cases.items():
            with self.subTest(case=label):
                self.write_archive(extra_members=members)
                with self.assertRaises(verify_certora_cloud.EvidenceError):
                    self.load()
        self.write_archive(omit_results=True)
        with self.assertRaisesRegex(
            verify_certora_cloud.EvidenceError, "missing required members"
        ):
            self.load()
        self.write_archive()
        with patch.object(verify_certora_cloud, "MAX_BACKEND_MEMBER_BYTES", 4):
            with self.assertRaisesRegex(
                verify_certora_cloud.EvidenceError, "too large"
            ):
                self.load()


class SubmittedEvidenceBindingTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.repo = Path(self.temporary.name)
        self.config_path = "certora/Test.conf"
        self.spec_path = "certora/specs/Test.spec"
        self.source_path = "contracts/Test.sol"
        self.config = {
            "files": [self.source_path],
            "verify": f"Test:{self.spec_path}",
            "rule": ["invariant"],
            "loop_iter": 3,
            "optimistic_loop": True,
            "optimistic_hashing": True,
            "hashing_length_bound": 512,
            "solc": "/pinned/solc-0.8.35",
            "solc_via_ir": True,
            "solc_optimize": 200,
            "solc_evm_version": "cancun",
            "prover_args": ["-enableStorageSplitting false"],
            "rule_sanity": "basic",
            "wait_for_results": "all",
        }
        self.spec_bytes = b"rule invariant() { assert true; }\n"
        self.source_bytes = b"contract Test {}\n"
        self.config_bytes = json.dumps(self.config, sort_keys=True).encode()
        for relative, data in (
            (self.config_path, self.config_bytes),
            (self.spec_path, self.spec_bytes),
            (self.source_path, self.source_bytes),
        ):
            path = self.repo / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
        self.log_path = self.repo / "cloud.log"
        self.archive_path = self.repo / f"{JOB_ID}.zip"

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def write_job(
        self,
        result: str = "SUCCESS",
        *,
        dirty: bool = False,
        effective_overrides: dict | None = None,
    ) -> None:
        self.log_path.write_text(
            cloud_log(f"Result for invariant: invariant: {result}")
        )
        effective = dict(self.config)
        effective.update(effective_overrides or {})
        metadata = {
            "CLI_version": "8.16.1",
            "java_version": "21.0.12",
            "branch": "relay-owner-timelock",
            "revision": HEAD,
            "dirty": dirty,
            "conf": effective,
            "conf_path": "Test.conf",
            "main_spec": self.spec_path,
            "raw_args": ["/venv/bin/certoraRun", self.config_path],
        }
        with zipfile.ZipFile(self.archive_path, "w") as archive:
            archive.writestr(f"../{JOB_ID}_cli_debug_log.zip", b"bound-to-job")
            archive.writestr(f".certora_sources/{self.config_path}", self.config_bytes)
            archive.writestr(".certora_sources/run.conf", json.dumps(effective))
            archive.writestr(".certora_metadata.json", json.dumps(metadata))
            archive.writestr(
                ".certora_build.json",
                json.dumps({"contracts": [{"compilerVersion": "0.8.35"}]}),
            )
            archive.writestr(f".certora_sources/{self.spec_path}", self.spec_bytes)
            archive.writestr(f".certora_sources/{self.source_path}", self.source_bytes)

    def build(self) -> dict:
        completed = SimpleNamespace(stdout=HEAD + "\n")
        with patch.object(
            verify_certora_cloud.subprocess, "run", return_value=completed
        ):
            return verify_certora_cloud.build_run(
                self.repo, self.config_path, self.log_path, self.archive_path
            )

    def test_exact_successful_submission_can_be_a_proof_pass(self) -> None:
        self.write_job()
        run = self.build()
        self.assertEqual("pass", run["proof_status"])
        self.assertEqual("pass", run["status"])
        self.assertTrue(run["evidence"]["aggregate_results_complete"])
        self.assertTrue(run["inputs"]["source_closure"]["matches_current"])
        self.assertEqual(512, run["model_bounds"]["hashing_length_bound"])
        self.assertFalse(run["model_bounds"]["storage_splitting"])

    def test_sanity_failure_is_partial_and_never_pass(self) -> None:
        self.write_job("SANITY_FAIL")
        run = self.build()
        self.assertEqual("partial", run["proof_status"])
        self.assertEqual("partial", run["status"])

    def test_cli_semantic_override_cannot_inherit_success(self) -> None:
        self.write_job(effective_overrides={"optimistic_hashing": False})
        run = self.build()
        self.assertEqual("pass", run["proof_status"])
        self.assertEqual("fail", run["status"])
        self.assertTrue(
            any("optimistic_hashing" in problem for problem in run["problems"])
        )

    def test_explicit_same_version_solc_path_is_the_only_semantic_exception(
        self,
    ) -> None:
        effective = dict(self.config)
        effective["solc"] = "/private/tmp/solc-0.8.35"
        metadata = {
            "raw_args": [
                "/venv/bin/certoraRun",
                self.config_path,
                "--solc",
                effective["solc"],
                "--short_output",
            ]
        }
        effective["short_output"] = True
        build = {"contracts": [{"compilerVersion": "0.8.35"}]}
        problems, compiler = verify_certora_cloud.audit_effective_config(
            self.config, effective, metadata, self.config_path, build
        )
        self.assertEqual([], problems)
        self.assertEqual(["0.8.35"], compiler["compiled_versions"])
        self.assertIsNone(compiler["binary_sha256"])

    def test_current_source_drift_makes_old_success_fail(self) -> None:
        self.write_job()
        (self.repo / self.spec_path).write_text("rule invariant() { assert false; }\n")
        run = self.build()
        self.assertEqual("pass", run["proof_status"])
        self.assertEqual("fail", run["status"])
        self.assertFalse(run["inputs"]["source_closure"]["matches_current"])
        self.assertTrue(any(self.spec_path in problem for problem in run["problems"]))

    def test_missing_expected_rule_is_incomplete_and_fails(self) -> None:
        self.write_job()
        self.log_path.write_text(
            cloud_log("Result for someOtherRule: someOtherRule: SUCCESS")
        )
        run = self.build()
        self.assertEqual("fail", run["status"])
        self.assertFalse(run["evidence"]["aggregate_results_complete"])
        self.assertTrue(
            any("missing aggregate" in problem for problem in run["problems"])
        )

    def test_dirty_submission_is_recorded_but_does_not_rewrite_proof_outcome(
        self,
    ) -> None:
        self.write_job(dirty=True)
        run = self.build()
        self.assertEqual("pass", run["status"])
        self.assertFalse(run["inputs"]["release_eligible"])
        self.assertTrue(
            any("dirty worktree" in problem for problem in run["inputs"]["problems"])
        )


if __name__ == "__main__":
    unittest.main()
