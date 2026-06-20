# Bytecode-level ∀N refinement (validated EVM/Yul semantics)

`RelayBytecodeRefinement.lean` lifts the abstract signature-loop threshold soundness
(`../RelaySigLoop.lean`, ∀N ∀K) onto a loop executed by NethermindEth's **validated** EVMYulLean
operational semantics, for all N. It is self-contained — every supporting lemma is proved locally, so one
`lake env lean` checks the whole development.

## What is proved (all hole-free)

`#print axioms` for each is exactly `[propext, Classical.choice, Quot.sound]` (no `sorry`/`sorryAx`, no
`native_decide`, no extra axiom):

- `loop_acc` — induction on the iteration count: the validated `exec` drives the encoded `for` loop and
  accumulates `absAcc`.
- `bytecode_loop_correct` — ∀N < 2²⁵⁶: the interpreter runs the loop to completion with exact fuel
  `3N+10` (no `OutOfFuel`, no exception) and the final accumulator equals `absAcc 0 N ⟨0⟩`.
- `bytecode_threshold_sound` — ∀N: on that validated execution, accept (final weight > `thr`) ⟹ total
  accumulated weight > `thr`.

## Scope and assumptions

The encoded loop is **memory-free**: its body adds the loop index, not a value loaded from memory. This
establishes the loop *mechanism* — that the validated semantics iterates ∀N and faithfully folds a
per-step quantity, and that threshold soundness transfers — on the real-machine semantics. The remaining
facts are stated assumptions, discharged by other evidence and registered in the claims ledger
(`../../../../docs/relay-verification/10-claims-ledger-trust-and-residual.md`):

- the **data layer** — each addend is the registered weight `mload(weights[i])`;
- the **overflow bound** — sums stay below 2²⁵⁶ (so the `𝕌` result equals the integer result);
- **encoding fidelity** — the `for` node mirrors the deployed loop's iterate-and-accumulate skeleton;
- **EVMYulLean is the EVM** — validated against the Ethereum execution-spec test suites.

## Checking it

```bash
# build the validated semantics once:
git clone --depth 1 https://github.com/NethermindEth/EVMYulLean /tmp/evmyul2
cd /tmp/evmyul2 && lake exe cache get && lake build      # Lean 4.22.0 (from lean-toolchain)
# check this file against it:
cp <repo>/test-forge/fv/lean/bytecode-refinement/RelayBytecodeRefinement.lean /tmp/evmyul2/
lake env lean RelayBytecodeRefinement.lean               # exit 0; prints the three clean axiom lists
```

Full narrative, the fuel-genericity technique, and the verbatim walk-through:
`../../../../docs/relay-verification/` (levels 07–09).
