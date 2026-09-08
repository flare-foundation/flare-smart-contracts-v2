# Conditional refinement over pinned EVM/Yul semantics

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

## Accounting and acceptance statements

[`RelayBodyEff.relay_loop_sound_literal_derived_tight`](RelayBodyEff.lean#L1674) establishes exact accumulation
and a registered-weight bound for normal completion under reachable-state continuation premises.
Normal completion is not acceptance: the literal body returns immediately at the first threshold crossing.
Structural index conditions come from `ValidRun`; voter weights come from the calldata-window model.
Distinct-address weight additionally requires unique policy addresses at admission.

`relay_loop_sound_literal_early` and `relay_dispatch_loop_accept` in the same file compose a continuing
prefix with a final accepting iteration. Continuing and accepting effects apply to disjoint reachable
states; the halted accumulator must equal the selected prefix weight. These are conditional execution
results, not a proof that their recovery or execution premises have a literal accepting instance.
Strict threshold crossing remains an explicit selected-prefix premise rather than a fact extracted
from an arbitrary successful run. Exact natural-number equality uses a no-wrap bound.

`protocolOne_tload_override_loop_sound` composes the modeled transient read with conditional
early-return accounting and BIPS arithmetic. It does not infer acceptance from an above-threshold
normally completed loop. The abstract strict-threshold theorem remains in `RelaySigLoop.lean`.

## Unresolved recovery-call interface

The pinned Yul `STATICCALL` handler uses an ordinary account dispatcher rather than the address-1
precompile. Its successful ordinary-account return clears caller calldata instead of restoring it.
Relay's voter-record read occurs after recovery, so the component premises supplying a recovery state
with preserved caller calldata are not a proved implementation of this handler. The exact literal
accepting-execution bridge is unverified. Any named recovery-seam witness concerns its explicitly
constructed model, not that bridge or Ethereum ECDSA correctness.

The dependency is kept at its manifest-pinned revision without a semantic patch. See the
[`refinement tutorial`](../../../../docs/relay-verification/07-R4b-bytecode-refinement.md) for the scope
and the distinction from bounded compiled-bytecode checks. An axiom audit checks proof dependencies,
not the existence of states satisfying theorem premises.

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
- [`RelayLoopLiteral.bodyL`](RelayLoopLiteral.lean#L86) is a hand transcription, not a mechanically extracted or AST-equivalent copy
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
