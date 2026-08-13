# Verification strategy and fidelity ladder

## Strategy

Each property is assigned to the smallest verified object that can express it
honestly:

- concrete interface and revert behavior belongs in Foundry tests;
- bounded paths through real compiled code belong in Halmos;
- unbounded list accounting belongs in Lean;
- the connection between the algorithm and EVM/Yul execution belongs in the
  refinement development;
- storage-oriented CVL rules belong in Certora; and
- provenance, compiler equivalence, optimized-Yul parity, and sequential-storage-layout
  drift belong in dedicated artifact gates.

The result is layered evidence, not a ranking in which a higher layer replaces a
lower one.

## Fidelity ladder

| Rung | Object | Input coverage | Primary limitation |
| --- | --- | --- | --- |
| R0 | compiled bytecode in unit tests | selected examples | examples are not exhaustive |
| R1 | compiled bytecode in fuzz tests | generated inputs within a budget | no completeness guarantee |
| R2 | compiled FV bytecode in Halmos | all symbolic values within fixed shapes and loop bounds | bounded signer/policy/proof sizes |
| R3 | CVL or executable model | rule/model dependent | model and front-end seams must be explicit |
| R4a | abstract Lean algorithm | unbounded lists and naturals | no direct implementation fidelity |
| R4b | Lean EVM/Yul semantics | unbounded modeled execution | conditional composition and compiler/refinement seams |

## Non-vacuity

A negative symbolic property can pass merely because its accepting path is
unreachable. Every Halmos proof that depends on an accepting configuration is
paired with a reachability control. The control is expected to produce a
validated counterexample witness. The gate rejects missing checks, all-revert
paths, invalid models, timeouts, and unexpected results.

## Proven/assumed boundary

Every claim is recorded as a tuple:

```text
(statement, verified object, input coverage, assumptions, evidence artifact)
```

Removing any field changes the meaning. In particular, “threshold soundness” is
ambiguous without stating whether weight refers to policy slots or unique
addresses and whether the policy is assumed well formed.

## Release composition

The bundle validator requires all mandatory normalized reports to bind:

- the same source revision;
- the exact manifest bytes;
- the production compiler and settings;
- the generated Relay runtime/creation bytecode and optimized Yul snapshot;
- the compiler-normalized current sequential-storage-layout baseline; and
- a clean, stable Git state throughout every evidence-producing run.

Certora cloud results are supplemental unless the manifest and bundle explicitly
make them mandatory. Local Certora success means compilation, configuration, and
CVL typechecking succeeded; it is not a cloud prover verdict.
