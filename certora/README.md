# Certora — Relay cross-transaction storage invariants

CVL specs for the properties where **Certora genuinely beats the Halmos/Kontrol proofs in this repo**:
*parametric* storage invariants that hold over **every function and every call sequence**, not just the
specific sequences those tools could enumerate.

## What it proves (`specs/RelayInvariants.spec`)

| Rule | Property | Strengthens |
|------|----------|-------------|
| `nonceMonotonic` | `governanceFeeNonce` never decreases, ∀ function | RLY-02 / AC-10 (was a 2-call sequence in `RelayGovernanceNonceFV`) |
| `lastInitializedMonotonic` | `lastInitializedRewardEpoch` never regresses, ∀ function | L1 (was the single +1 step in `RelayEpochAdvanceFV`) — now global, incl. relay() Mode-1 |
| `signingPolicySetterImmutable` | the setter authority is immutable after construction | new — access-control anchor |
| `policyHashWriteOnce` | a finalized signing-policy hash is never overwritten/cleared | new — finalized policies can't be tampered |
| `merkleRootWriteOnce` | a finalized Merkle root is write-once per (protocolId, votingRoundId) | new — or documents that re-finalization is by-design if it fails |

Each is a `rule … (method f)` — Certora checks it for **all** external/public methods and arbitrary args
(quantifying over all callers and sequences). ecrecover is left NONDET (modeling contract A2): the storage
invariants hold regardless of which signatures the prover admits.

## Honest scope

- Certora, like Halmos and Kontrol, **unrolls the within-call signature loop** (`loop_iter`), so it does
  **not** close the ∀N within-call signature-loop gap better than Kontrol. The ∀N∀K signature-loop
  soundness remains the Lean proof (`../test-forge/fv/lean/RelaySigLoop.lean`). Certora's value here is the
  cross-transaction **storage** invariants above.
- **Status: locally typechecked, not cloud-proven.** The specs have been run through Certora's full LOCAL
  pipeline — `certoraRun certora/Relay.conf --compilation_steps_only` — which **compiles `Relay.sol` under
  Certora and typechecks `RelayInvariants.spec` against it. That step passes cleanly (exit 0, no spec
  errors;** only benign warnings that OZ `MerkleProof`'s function-type params can't be auto-summarized,
  irrelevant to these storage rules). So the specs are confirmed **well-formed against the real contract**.
  The actual *proof* runs on Certora's **cloud (requires `CERTORAKEY`)**, which is not available here — so
  the rules are *specified + locally typechecked, but not yet cloud-machine-checked* (unlike `test-forge/fv/`,
  which is fully checked). Treat them as ready-to-run.

## How to run (with a Certora account)

```bash
pip install certora-cli            # tested: certora-cli 8.16.1
export CERTORAKEY=<your key>
# from the repo root, with dependencies/ present (soldeer) and a solc 0.8.27 binary:
certoraRun certora/Relay.conf --solc /path/to/solc-0.8.27

# Local typecheck only (no key, no cloud) — what was run here, passes (needs solc 0.8.27 + a JDK):
certoraRun certora/Relay.conf --compilation_steps_only --solc /path/to/solc-0.8.27
```

If solc/import resolution differs in your setup, adjust `solc`, `packages`, and `solc_via_ir` in
`Relay.conf` to match the repo's foundry remappings (see `../remappings.txt`).

## Expected outcome / next step

`nonceMonotonic`, `lastInitializedMonotonic`, `signingPolicySetterImmutable`, `policyHashWriteOnce` are
expected to **verify** (they match the on-chain logic proven locally for specific sequences).
`merkleRootWriteOnce` is the genuinely-open question — if it fails, the counterexample documents that a
voting round can be re-finalized with a different root, which is a design point worth confirming.
