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

Under the development's explicit setup, valid-run, memory-correlation,
successful-execution, and acceptance premises, execution of the modeled loop
refines the abstract prefix-sum algorithm. The abstract unbounded threshold
theorem can then be transferred to the modeled EVM/Yul execution.

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
