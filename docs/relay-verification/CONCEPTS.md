# Formal-verification concepts used by the Relay suite

## SMT solver

An SMT solver decides whether logical formulas over integers, bit-vectors,
arrays, and uninterpreted functions are satisfiable. Symbolic tools ask whether
there exists an input that reaches an assertion failure. `unsat` establishes the
property under the encoded premises; `sat` provides a candidate counterexample.

## Symbolic execution

Symbolic execution runs code on unknown values. When control flow depends on an
unknown, execution forks and records a path condition. Halmos applies this to
compiled EVM bytecode generated from Foundry harnesses.

Symbolic execution remains bounded when loops are unrolled only a fixed number
of times or fixtures fix list/tree shapes.

## Assumption

`vm.assume(P)` restricts a symbolic proof to states satisfying `P`. An assumption
is part of the theorem statement. It must be recorded whenever it excludes an
attacker-relevant state, such as duplicate voter addresses or a terminal voting
round.

## Reachability and vacuity

A statement of the form “no accepting execution violates `Q`” is trivially true
if the harness can never accept. A reachability control deliberately asks the
solver to refute an assertion on a valid accepting path. The gate validates the
resulting model so a truncated loop, all-revert fixture, timeout, or malformed
counterexample cannot masquerade as evidence.

## Bounded versus unbounded proof

A bounded proof quantifies over every value inside a fixed execution shape, for
example three signatures and five voters. An unbounded proof quantifies over
arbitrary list lengths, usually through induction. Neither automatically implies
the other: bounded execution has higher implementation fidelity; induction has
greater shape generality.

## Invariant and induction

An invariant is true before a loop, remains true after one iteration, and
therefore holds after any number of iterations. Relay's key invariant bounds the
accumulated signature weight by the prefix sum ending at the next unused policy
index.

## Uninterpreted function

An uninterpreted function is deterministic but otherwise unconstrained. It is
useful for treating cryptographic operations opaquely while proving accounting
properties. It does not prove the cryptographic security of the real function.

## Model, semantics, and refinement

A model represents selected implementation behavior in a form suitable for
proof. Semantics define how machine instructions or Yul statements execute.
Refinement proves that an implementation/model execution corresponds to a
simpler abstract algorithm so a theorem about the algorithm can transfer.

A refinement theorem is conditional when setup, memory correlation, accepted
control flow, or external-call behavior appears as a premise rather than being
derived from the complete compiled execution.

## Hole-free Lean proof and axiom audit

A Lean file can compile while relying on admitted facts or powerful evaluation
shortcuts. The Relay gate rejects `sorry`, `admit`, `native_decide`, and
undeclared axioms. `#print axioms` identifies the trusted declarations used by a
theorem; the gate compares them with an explicit allowlist.

## Artifact parity

Artifact parity checks that the formal-verification build and deployment build
refer to the same program. The Relay gate compares compiler/settings,
metadata-stripped creation/runtime bytecode, the optimized-Yul snapshot used by
the Lean development, and the compiler-normalized current sequential-storage-layout
baseline. The layout snapshot excludes ERC-7201 namespaces and transient slots.
The scoped comparison detects drift; it does not establish semantic compatibility
of unknown future implementation code.

## Provenance

Provenance binds a result to the source revision, manifest bytes, tool versions,
inputs, outputs, and clean Git state that produced it. A mathematically valid
result for a different program is not evidence about the current Relay.

## Release eligibility

`status: pass` describes a gate's technical verdict. `release_eligible: true`
additionally requires clean, in-process, current, consistently bound evidence.
Development runs can pass without being release eligible.
