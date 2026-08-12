from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


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
        semantic, suffix_length, offset, trailing = verify_artifact.strip_cbor_metadata(
            with_metadata(b"\x60\x00", b"\xa1\x01\x02")
        )
        self.assertEqual(b"\x60\x00", semantic)
        self.assertEqual(5, suffix_length)
        self.assertEqual(2, offset)
        self.assertEqual(0, trailing)

    def test_strips_embedded_creation_metadata_and_preserves_auxdata(self) -> None:
        metadata = b"\xa1\x64solc\x01"
        value = with_metadata(b"\x60\x00", metadata) + "aa" * 32
        semantic, metadata_bytes, offset, trailing = verify_artifact.strip_cbor_metadata(value)
        self.assertEqual(b"\x60\x00" + b"\xaa" * 32, semantic)
        self.assertEqual(len(metadata) + 2, metadata_bytes)
        self.assertEqual(2, offset)
        self.assertEqual(32, trailing)

    def test_strips_exact_runtime_suffix_from_via_ir_creation(self) -> None:
        runtime_suffix = b"\xa1\x64solc\x01\x00\x07"
        prefix = b"\x60\x00"
        constructor_tail = b"\xaa\xbb\xcc"
        value = "0x" + (prefix + runtime_suffix + constructor_tail).hex()
        semantic, metadata_bytes, offset, trailing = verify_artifact.strip_embedded_cbor_metadata(
            value, runtime_suffix, "creation"
        )
        self.assertEqual(prefix + constructor_tail, semantic)
        self.assertEqual(len(runtime_suffix), metadata_bytes)
        self.assertEqual(len(prefix), offset)
        self.assertEqual(len(constructor_tail), trailing)

    def test_embedded_metadata_strip_is_fail_closed(self) -> None:
        with self.assertRaisesRegex(ValueError, "empty runtime"):
            verify_artifact.strip_embedded_cbor_metadata("0x6000", b"", "creation")
        with self.assertRaisesRegex(ValueError, "does not embed"):
            verify_artifact.strip_embedded_cbor_metadata(
                "0x6000", b"\xa1\x64solc\x01\x00\x07", "creation"
            )

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

    def test_imported_artifact_and_ir_are_development_inputs(self) -> None:
        self.assertEqual(
            "imported-results",
            verify_artifact.verification_input_mode(Path("Relay.json"), Path("Relay.iropt")),
        )
        self.assertEqual("generated-in-process", verify_artifact.verification_input_mode(None, None))
        with self.assertRaisesRegex(ValueError, "supplied together"):
            verify_artifact.verification_input_mode(Path("Relay.json"), None)

    def test_artifact_metadata_must_bind_current_source(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "contracts" / "Relay.sol"
            source.parent.mkdir(parents=True)
            source.write_text("contract Relay {}\n")
            artifact = root / "Relay.json"
            artifact.write_text(
                json.dumps(
                    {
                        "metadata": {
                            "sources": {"contracts/Relay.sol": {"keccak256": "0x" + "0" * 64}},
                            "compiler": {"version": "0.8.35+commit.47b9dedd"},
                            "settings": {
                                "evmVersion": "cancun",
                                "optimizer": {"enabled": True, "runs": 200},
                                "viaIR": True,
                            },
                        },
                        "abi": [],
                        "bytecode": {"object": with_metadata(b"\x60", b"\xa1\x01")},
                        "deployedBytecode": {"object": with_metadata(b"\x60", b"\xa1\x01")},
                    }
                )
            )
            with patch.object(verify_artifact, "REPO_ROOT", root):
                with self.assertRaisesRegex(ValueError, "metadata source hash"):
                    verify_artifact.analyze_foundry_artifact(artifact, source)


if __name__ == "__main__":
    unittest.main()
