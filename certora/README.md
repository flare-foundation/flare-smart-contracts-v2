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

## Cloud run result (executed) — the inline-assembly wall

Two cloud runs were executed (with a valid `CERTORAKEY`):
- run 1: https://prover.certora.com/output/3798318/a9a6c094009f4711852a166db63ac06f
- run 2 (with `HAVOC_ECF` external-call summary + uint32-wrap guard): https://prover.certora.com/output/3798318/93ef4cf514274eac9f089c3ac3533be9

**Outcome (both runs identical):** `nonceMonotonic`, `lastInitializedMonotonic`, `signingPolicySetterImmutable`
all reported "violations" on `relay()`, `governanceFeeSetup`, and `setSigningPolicy`; `policyHashWriteOnce`
and `merkleRootWriteOnce` returned `UNKNOWN`.

**These are spurious — a tool limitation, not contract bugs.** The decisive tell: `setSigningPolicy`
"violates" `signingPolicySetterImmutable`, but `setSigningPolicy` has **no external call** and **never
writes the `signingPolicySetter` slot** — so it cannot logically change it. And `HAVOC_ECF` (which removes
external-call havoc; sound here since Relay has no delegatecall) changed **nothing** between runs. The
cause is therefore **storage-slot havoc from inline assembly**: Relay builds mapping slots in scratch
memory (`keccak256(mload(0x40), 64)`) and writes the bit-packed `StateData` as a whole slot via assembly
`assignStruct`/`sstore`. When Certora's storage analysis cannot resolve an `sstore` target, it
conservatively **havocs all storage**, so every storage invariant breaks on every assembly-writing
function — including slots that function never touches.

**This is the same wall Kontrol hit** (N=10 ran 12h with 0 proofs): Relay is ~90% hand-rolled inline
assembly with bit-packed storage, which defeats automated provers' storage models. A genuine
tool-vs-contract-style mismatch.

### What it would take to make Certora discharge these
Re-model the storage layout in CVL with `ghost` variables + raw-slot `hook Sstore`/`hook Sload` that mirror
every assembly write (decoding the packed `StateData` bit-offsets and the computed mapping slots), then
state the invariants over the ghosts. This is substantial effort **and re-introduces the faithfulness risk
the whole engagement avoids** (a wrong bit-offset = a meaningless proof). Not recommended unless an audit
specifically requires all-functions/all-sequences *storage* invariants — the per-sequence forms are already
proven (`RelayGovernanceNonceFV` for the nonce, `RelayEpochAdvanceFV` for the epoch pointer, etc.), and the
∀N∀K signature-loop soundness is the Lean proof.

### Status of these specs
**Correct and locally typechecked** (they compile + typecheck against the real contract), **cloud-run
executed**, but **not dischargeable by Certora on this assembly-heavy contract** without the ghost/hook
re-modeling above. The rules are documented as a ready scaffold for that effort, not as passing proofs.
