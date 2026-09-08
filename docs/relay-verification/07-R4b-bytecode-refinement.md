# R4b — EVM/Yul refinement

The refinement development under
[`test-forge/fv/lean/bytecode-refinement/`](../../test-forge/fv/lean/bytecode-refinement/)
connects the abstract accounting theorem to execution in EVMYulLean, a Lean
formalization of EVM and Yul semantics.

## Modeled components

The current files cover:

- big-endian byte decoding and memory round trips;
- masked memory reads for voter weights and addresses;
- loop-window and bounds conditions;
- the literal signature-loop body and its accumulator update;
- storage/transient-storage component semantics;
- protocol-1 threshold selection and strict comparison; and
- conditional dispatch, acceptance, storage composition, and local native-fee
  balance lemmas.

The exact file and exported-theorem inventory is declared by the verification
manifest and checked by `verify_lean.py`.

## Refinement claim

The normal-completion accounting results relate the accumulator to the selected
policy weights. Acceptance is a different outcome: the literal body returns
immediately when weight exceeds the threshold, rather than completing normally.
The early-return composition results reason about actual reachable intermediate
states and separate continuing iterations from the accepting iteration.

These are conditional composition statements. A kernel-checked implication does
not establish that its execution or cryptographic-call premises are satisfiable.
The abstract unbounded threshold theorem is independent of those execution
premises; the literal accepting-execution bridge is not established.
The early capstones also require the selected prefix to cross the threshold;
they do not derive that fact by extracting an arbitrary accepted execution.
An exact natural-number tally additionally needs the stated no-wrap bound, not
only equality after conversion into a 256-bit word.

## Open gap RLY-FV-GAP-01: recovery-call execution

Status: open. This gap concerns the literal recovery-call execution bridge in
the pinned Lean model, not a demonstrated vulnerability in Relay bytecode.

The pinned EVMYulLean **Yul** `STATICCALL` handler looks up an ordinary account
and calls its dispatcher; it does not invoke Ethereum's address-1 precompile.
An absent account returns empty data. On return from a present account, the
handler sets the caller's calldata to empty instead of restoring it. Relay's
literal body reads its policy voter record after that call, so a supplied
recovery outcome preserving caller calldata is not a proved instance of this
handler.

Consequently, the recovery premises in the literal-body component theorems are
an unresolved semantic interface, not a verified ECDSA abstraction or evidence
that the complete literal loop can accept. Prefix/suffix or abstract-model
witnesses establish only their named modeled executions; they do not discharge
the actual `STATICCALL` bridge. Closing that bridge requires reviewed call
semantics with explicit caller-frame preservation and a coherent recovery
model. The current package does not modify the pinned dependency.

The constructive
[`RelayBodyEff.recovery_oracle_acceptance_witness`](../../test-forge/fv/lean/bytecode-refinement/RelayBodyEff.lean#L2563)
executes the actual nine-statement prefix and seven-statement suffix around an
explicit caller-preserving recovery oracle. Its concrete loop inputs start at
weight 0 and accept at weight 2 with threshold 1, without execution-success
hypotheses. This establishes satisfiability of that slice model only: the bytes
are not a full-parser acceptance witness or a real ECDSA test vector.

This is a verification-model limitation, not evidence of a Relay runtime defect.
Halmos checks and the concrete precompile ABI tests exercise compiled bytecode
through their respective EVM models and do not rely on this Lean call handler.

### Effect on verification results

The Lean gate and aggregate bundle can pass while this gap remains open. They
check the declared conditional theorems, scoped witnesses, axiom inventory, and
source/tool provenance. `release_eligible = true` does not establish faithful
precompile execution or close this gap. Neither that flag nor the oracle witness
supports a claim of unconditional end-to-end Relay verification.

### Closure criteria

Closing RLY-FV-GAP-01 requires all of the following:

1. Review and pin call semantics that preserve the caller frame, including its
   calldata, and specify address-1 recovery success/failure, return data, and
   output-memory behavior. Cryptographic security may remain an explicit
   assumption; caller-frame correctness must not be hidden in that assumption.
2. Derive the literal-body recovery interface (`recHypothesis`) from that pinned
   call handler, rather than substituting a separate recovery oracle.
3. Kernel-check a concrete, nonempty accepting execution of the complete literal
   body through that handler without an execution-success premise, and add
   caller-frame and recovery-failure regression checks.
4. Regenerate the affected theorem, axiom, artifact/provenance, and aggregate
   evidence against the reviewed pin and one clean committed source tree.

These criteria close this call bridge only. The other composition boundaries
below, cryptographic assumptions, and compiler trust remain separate obligations.

## Remaining composition boundary

This is not a proof that the complete optimized Relay program was extracted into
Lean and simulated instruction for instruction. The following remain explicit
premises or external bindings unless a current theorem says otherwise:

- derivation of every setup/local value from one accepted compiled execution;
- ecrecover behavior and the relationship between recovered addresses and
  policy admission;
- complete self-call composition for protocol-1 transient threshold setup;
- complete control-flow linkage from dispatch through state write and return;
- pre-boundary `oldRelay` zero-value delegation and full-refund behavior;
- ERC-20 fee transfer, allowance, token return behavior, SafeERC20, and the
  EnumerableSet-backed fee table;
- solc's transformation from optimized Yul to bytecode; and
- equivalence of a future implementation after UUPS upgrade.

The artifact-parity gate byte-compares the committed optimized-Yul snapshot with
the current compiler output, compares metadata-stripped bytecode across the FV
and deployment builds, and compares the compiler-normalized sequential Solidity
storage layout with the current first-deployment baseline. ERC-7201 namespaces
and transient slots are outside that snapshot. Halmos supplies bounded behavioral
evidence on the compiled bytecode. Together these narrow the seam but do not
turn the conditional refinement into whole-contract extraction or prove future
upgrade compatibility.

## Trust in the semantics

The manifest pins the EVMYulLean revision and Lean toolchain. The Lean gate
checks the allowed axiom set for every declared theorem. Local declarations used
to specify unavailable upstream data/window facts must be named and allowlisted;
they are assumptions until discharged by the pinned upstream semantics.

The precise list belongs in the claims ledger rather than prose comments inside
the contract.
