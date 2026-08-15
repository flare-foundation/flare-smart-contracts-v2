# Bytecode-level refinement over validated EVM/Yul semantics

This directory proves Relay signature-loop properties with NethermindEth's EVMYulLean operational
semantics. The exact EVMYulLean revision and Lean toolchain are pinned in
`../../verification-manifest.json`.

## Modules and current results

| File | Current role |
|---|---|
| `RelayBytecodeRefinement.lean` | Executes a memory-free `For` loop for arbitrary `N`; proves exact accumulation and strict-threshold soundness. |
| `DataLayer.lean` | Proves byte encoding/decoding, memory write/read, `mstore`/`mload`, and `& 0xffff` weight extraction under stated bounds. |
| `RelayLoopMemRead.lean` | Executes a masked-memory-read loop and connects it to abstract indexed-weight accounting. |
| `RelayLoopWindows.lean` | Proves the signature and voter calldata windows decoded by the literal body. |
| `RelayLoopLiteral.lean` | Defines a 17-statement hand transcription of the optimized-Yul signature-loop body and reusable interpreter lemmas. |
| `RelayBodyEff.lean` | Composes the literal body, window reads, structural guards, mode dispatch, and protocol-1 threshold selection. |
| `RelayStorageLayer.lean` | Proves persistent/transient storage round trips, clearing, account isolation, and accept-write effects. |
| `RelayFeeLayer.lean` | Proves local native-fee arithmetic and balance-transfer conservation under `feeToken == address(0)` with no `oldRelay` delegation. |

The proof sources contain no `sorry`, `admit`, or `native_decide`. `verify_lean.py` audits every
`#print axioms` result against the manifest.

## Strongest accounting statement

[`RelayBodyEff.relay_loop_sound_literal_derived_tight`](RelayBodyEff.lean#L1679) executes the hand-transliterated body for arbitrary
loop count and proves:

> if the modeled loop accepts under the theorem's explicit premises, the total indexed policy weight is
> strictly greater than the threshold.

Its structural index conditions are derived from `ValidRun`; the masked voter-weight read is derived from
the calldata/memory window model. The per-iteration cryptographic facts remain premises. Policy slots are
therefore counted at most once, while distinct-address weight additionally depends on unique voter
addresses at policy admission.

[`RelayBodyEff.protocolOne_tload_override_loop_sound`](RelayBodyEff.lean#L1718) composes a modeled transient-storage read with the
strict loop theorem. It proves the cross-product threshold predicate and absence of multiplication wrap
under the parser-wide total-weight bound and `0 < overrideBIPS < 10000`.

## Model boundary

The proof set establishes the following within its stated models:

- Yul loop execution and accumulation for arbitrary iteration counts;
- byte-window decoding for the signature and voter records;
- masked 16-bit voter-weight extraction;
- index range/order accounting under `ValidRun`;
- strict threshold comparison, including the protocol-1 BIPS arithmetic;
- dispatch isolation between the custom-signature and ordinary verification paths;
- persistent and transient storage primitives; and
- local native-fee and native-balance conservation primitives.

The following are explicit boundaries, not proved deployment-wide guarantees:

- `ecrecover` and `keccak` behavior is supplied by premises;
- [`RelayLoopLiteral.bodyL`](RelayLoopLiteral.lean#L78) is a hand transcription, not a mechanically extracted or AST-equivalent copy
  of the complete compiler output;
- loop-invariant setup values are parameters, and the protocol-1 theorem assumes the equality connecting
  the modeled `TLOAD` result to the loop-local threshold;
- self-call propagation, revert rollback, and transaction-end transient clearing are outside the current
  composition theorem;
- the accept write is a separate theorem because the loop model represents acceptance as an immediate
  halt; and
- local native-fee call arithmetic and balance transfer are proved, but the complete `.CALL` dispatcher
  path is not composed into a single `verify()` theorem;
- pre-boundary `oldRelay` zero-value delegation and full-refund behavior are outside this Lean model; and
- ERC-20 fee transfer, allowance, token return behavior, SafeERC20, and the enumerable fee table are not
  represented in the Lean model.

The committed optimized-Yul snapshot is checked separately by the artifact-provenance gate. That gate
binds compiler output to the deployment artifact; it does not prove semantic equivalence between the
snapshot and the hand-transliterated AST.

## Local semantic assumptions

The manifest allowlists three local axiom declarations:

- `RelayDataLayer.zeroes_data`;
- `RelayDataLayer.toByteArray_size`; and
- `RelayWindows.zeroes_data`.

They are semantic assumptions in the checked sources. The first and third specify the bytes produced by
EVMYulLean's opaque FFI zero constructor. The second specifies that `UInt256.toByteArray` has length 32.
[`AXIOM_DISCHARGE.md`](AXIOM_DISCHARGE.md) describes the upstream visibility/definition changes and Lean
proofs that replace these declarations with theorems in a patched EVMYulLean checkout.

## Reproduce

```bash
git clone https://github.com/NethermindEth/EVMYulLean /tmp/evmyul2
cd /tmp/evmyul2
git checkout 047f63070309f436b66c61e276ab3b6d1169265a
lake exe cache get
lake build
cd <repo>
EVMYUL_DIR=/tmp/evmyul2 python3 test-forge/fv/lean/verify_lean.py
```

The script verifies the pinned checkout and dependencies, builds EVMYulLean,
checks every manifest-listed Lean source, compiles the imported modules required
by `RelayBodyEff.lean`, audits all declared and emitted axioms, and writes the
configured verification report.
