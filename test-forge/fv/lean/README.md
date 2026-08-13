# Lean 4 signature-loop verification

The Lean development proves Relay's indexed-weight accounting for arbitrary voter and signature counts.
It contains an abstract proof and a refinement over EVMYulLean's validated Yul operational semantics.

| File | Current proof object | Quantification |
|---|---|---|
| `RelaySigLoop.lean` | abstract indexed-weight accounting | arbitrary voter and signature lists |
| `bytecode-refinement/RelayBytecodeRefinement.lean` | memory-free Yul loop mechanism | arbitrary loop count |
| `bytecode-refinement/DataLayer.lean` | byte, memory, value, and 16-bit mask lemmas | arbitrary values satisfying stated bounds |
| `bytecode-refinement/RelayLoopMemRead.lean` | masked-memory-read loop and accounting bridge | arbitrary loop count |
| `bytecode-refinement/RelayLoopWindows.lean` | calldata-to-scratch-memory window decoding | arbitrary buffers satisfying stated bounds |
| `bytecode-refinement/RelayLoopLiteral.lean` | hand-transliterated signature-loop body | statement-level semantics |
| `bytecode-refinement/RelayBodyEff.lean` | literal-body, dispatch, and protocol-1 threshold composition | arbitrary loop count under explicit premises |
| `bytecode-refinement/RelayStorageLayer.lean` | persistent and transient storage effects | arbitrary keys and values under stated account premises |
| `bytecode-refinement/RelayFeeLayer.lean` | native-fee arithmetic and balance conservation | arbitrary values under stated balance premises and `feeToken == address(0)` |

## Abstract accounting theorem

`RelaySigLoop.threshold_sound` states that, for a `ValidRun`, acceptance implies that the total indexed
policy weight exceeds the threshold. `ValidRun` requires in-range, monotonically increasing policy indices,
so a policy slot is not counted twice. The theorem does not model voter addresses; interpreting the sum as
weight from distinct identities requires unique voter addresses at policy admission.

The same file proves:

- the loop invariant and the insufficient-weight contrapositive;
- equivalence between the strict floor threshold and its cross-product form;
- absence of `UInt256` wrap in the protocol-1 threshold product under the parser bound and
  `overrideBIPS < 10000`; and
- isolation of the protocol-1 threshold override from other protocol IDs.

## EVMYulLean refinement scope

The refinement executes modeled Yul statements with EVMYulLean at the pinned commit recorded in
`../verification-manifest.json`. Its strongest composition theorem connects mode dispatch to the
hand-transliterated signature loop and proves the indexed-weight conclusion under its explicit setup,
cryptographic-call, validity, and no-overflow premises.

The model intentionally leaves these boundaries explicit:

- `ecrecover` and `keccak` behavior is supplied by theorem premises rather than implemented cryptography;
- the full compiler-generated program is provenance-gated, but equivalence between that program and the
  hand-transliterated loop body is not a proved AST refinement;
- the complete setup path around transient storage, self-call behavior, rollback, and transaction-end
  clearing is not extracted into the composition theorem; and
- the accept write and native-fee call interpreter wiring are proved as separate components; and
- ERC-20 fee transfer, allowance, token return behavior, and fee-table enumeration are outside Lean's model.

## Assumptions and proof audit

The source contains no `sorry`, `admit`, or `native_decide`. The manifest allowlists Lean's standard
logical axioms and these local declarations:

- `RelayDataLayer.zeroes_data`;
- `RelayDataLayer.toByteArray_size`; and
- `RelayWindows.zeroes_data`.

These declarations are explicit semantic assumptions in the current proof set. They specify the result of
EVMYulLean's opaque zero-filled `ByteArray` constructor and the fixed size of `UInt256.toByteArray`.
[`bytecode-refinement/AXIOM_DISCHARGE.md`](bytecode-refinement/AXIOM_DISCHARGE.md) gives a reproducible way
to convert them to theorems in a patched upstream checkout; that procedure does not change their status as
axioms in this repository.

`verify_lean.py` checks every declared axiom, every `#print axioms` directive, forbidden proof-hole tokens,
the exact EVMYulLean revision, its Lake dependencies, and the toolchain declared in the manifest.

## Reproduce

Prepare EVMYulLean at the manifest-pinned revision, then run:

```bash
EVMYUL_DIR=/tmp/evmyul2 python3 test-forge/fv/lean/verify_lean.py
```

For the abstract core alone:

```bash
cd test-forge/fv/lean
lean RelaySigLoop.lean
```

The generated verification report records source hashes, toolchain provenance, theorem audit output, and
whether the run is release-eligible.
