from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).resolve().parents[1] / "verify_relay_artifact.py"
SPEC = importlib.util.spec_from_file_location("verify_relay_artifact", MODULE_PATH)
assert SPEC and SPEC.loader
verify_artifact = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = verify_artifact
SPEC.loader.exec_module(verify_artifact)


def with_metadata(code: bytes, metadata: bytes) -> str:
    return "0x" + (code + metadata + len(metadata).to_bytes(2, "big")).hex()


class ArtifactParityTest(unittest.TestCase):
    def test_strips_solidity_cbor_suffix(self) -> None:
        semantic, suffix_length = verify_artifact.strip_cbor_metadata(
            with_metadata(b"\x60\x00", b"\xa1\x01\x02")
        )
        self.assertEqual(b"\x60\x00", semantic)
        self.assertEqual(5, suffix_length)

    def test_rejects_invalid_metadata_length(self) -> None:
        with self.assertRaises(ValueError):
            verify_artifact.strip_cbor_metadata("0x6000ffff")

    def test_rejects_non_cbor_map_suffix(self) -> None:
        with self.assertRaises(ValueError):
            verify_artifact.strip_cbor_metadata(with_metadata(b"\x60\x00", b"\x01\x02"))

    def test_compiler_metadata_may_differ_when_semantic_hashes_match(self) -> None:
        semantic = b"\x60\x00\x56"
        deployment_code = verify_artifact.summarize_bytecode(
            with_metadata(semantic, b"\xa1\x01"), "deployment"
        )
        verification_code = verify_artifact.summarize_bytecode(
            with_metadata(semantic, b"\xa1\x02"), "verification"
        )
        self.assertNotEqual(deployment_code["full_sha256"], verification_code["full_sha256"])
        self.assertEqual(deployment_code["semantic_sha256"], verification_code["semantic_sha256"])


if __name__ == "__main__":
    unittest.main()
