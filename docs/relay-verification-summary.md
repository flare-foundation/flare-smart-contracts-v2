# Relay formal-verification summary

> **Current evidence:**
> [`relay-verification/CURRENT-STATUS.md`](relay-verification/CURRENT-STATUS.md)
> is the sole current-results page. The complete methodology, claims ledger,
> assumptions, and reproducibility guide begin at
> [`relay-verification/00-README.md`](relay-verification/00-README.md).

> **Latest-source status (2026-08-12):** HEAD is `d5af7136…`, manifest
> `7ae2208f…`. All six local constituent gates pass after the threshold/FV
> rebaseline. They are development-only solely because they were generated in
> a dirty worktree. The aggregate bundle also passes as development-only;
> supplemental Certora cloud evidence is PARTIAL (threshold PASS; scalar and
> write-once PARTIAL because of sanity failures). See the current-status page
> before interpreting either evidence set.

This summary describes the owner/timelock/UUPS re-baseline on
`relay-owner-timelock`. Historical Safe/GSS results, older compiler runs, and
old proof counts do not apply to this architecture.

## Current verification map

| Layer                       | Current scope                                                                                   | Current evidence boundary                                                                                                                                              |
| --------------------------- | ----------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Foundry                     | Concrete/fuzz Relay, owner/timelock, proxy, upgrade, and exact-BIPS behavior                    | Current full tree passes 2,079/2,079; exact-BIPS suite 11/11, FDC2 53/53, governance 39/39, and Hardhat Relay 53/53                                                    |
| Halmos                      | 123 checks across 27 harness contracts: 86 proofs and 37 validated reachability controls        | **PASS 123/123, 0 violations; development-only.** Bounded symbolic evidence. Report `f591eb78…`                                                                        |
| Certora local               | Three configs and 15 current scalar, threshold, write-once, and owner/timelock rules            | **PASS 3/3 configs, 15 rules, 0 local violations; development-only.** Front-end/typecheck evidence only. Report `9d3ce039…`                                            |
| Certora cloud               | Supplemental scalar, threshold, and write-once jobs                                             | **PARTIAL.** Threshold PASS; scalar/write-once PARTIAL. Totals: 308 `SUCCESS`, 2 `SATISFIED`, 24 `SANITY_FAIL`, 0 semantic CEX/`UNKNOWN`/`TIMEOUT`. Report `93d09d86…` |
| Lean/EVMYulLean             | Nine files and 183 declared axiom audits for Relay accounting/refinement and the threshold seam | **PASS 9/9, 183 audits; development-only.** Protocol-1 composition retains explicit `hsetupThreshold`. Report `82fff1ff…`                                              |
| Artifact/custom-error gates | solc 0.8.35 deployment/FV bytecode and optimized-Yul parity; 37 assembly custom errors          | **All PASS, development-only.** Deployment `44468783…`, ABI `1fb2ca10…`, artifact `0b2a7518…`                                                                          |
| Kontrol                     | Historical fixed-model induction experiments                                                    | Not rerun for the current governance architecture                                                                                                                      |

## What the accounting theorem actually says

Strictly increasing signature indices ensure that one **policy slot** is not
used twice. They do not ensure that different slots contain different voter
addresses. Every distinct-voter interpretation is conditional on unique voter
addresses at policy admission, which the current contract does not enforce.
This is a live security finding, not wording trivia; see
[`relay-verification/13-residual-weaknesses.md`](relay-verification/13-residual-weaknesses.md).

Cryptographic unforgeability and hash collision resistance remain assumptions.
The Lean refinement is conditional on its explicit execution, acceptance, data,
and model-fidelity premises. UUPS authorization is checked only for the current
implementation; arbitrary replacement semantics and storage compatibility are a
trusted-upgrade boundary.

## Owner/timelock/UUPS coverage added in this re-baseline

The current Halmos manifest includes checks for:

- owner-only queue and cancel;
- exact-calldata queue identity and recorded ETA;
- permissionless one-shot execution and rollback after target failure;
- relay-mode fee setters and immutable relay/setter mode separation;
- one-shot proxy initialization and implementation lock;
- exact queued UUPS implementation/migration data;
- selected storage preservation and nested-guard rollback; and
- ERC-7201 timelock namespace separation from ERC-1967 slots;
- exact floor-plus-strict BIPS boundaries, zero/non-protocol fallback, and
  protocol-1 reachability; and
- transient-slot success cleanup, caught-revert rollback, and address scope.

Current Certora rules complement those checks with current-implementation
scalar/write-once properties, owner/timelock transitions, and a dedicated
threshold harness/spec. All three configurations compile and CVL-typecheck
locally; that local pass is not a prover verdict. The supplemental cloud report
is PARTIAL: the threshold job passes, while scalar and write-once retain 24
sanity exclusions for `relay`, `setSigningPolicy`, and
`renounceOwnership` for all six scalar rules and both mapping rules. The two
loop-heavy methods are not shown nonvacuous under `viaIR`, `loop_iter=3`, and
`optimistic_loop=true`; `renounceOwnership` always reverts, while its dedicated
`ownershipRenounceAlwaysReverts` rule passes. Both `satisfy` witnesses have
concrete models: a queued duration update consumes the ETA, clears the flag, and
changes the duration, and a zero-delay owner call applies a duration update.
The normalized cloud evidence contains 308 `SUCCESS`, 2 validated `SATISFIED`,
24 `SANITY_FAIL`, and no semantic assertion counterexample, `UNKNOWN`, or
`TIMEOUT`.

The threshold cloud job's scope is narrower than the complete transient-flow
claim. It proves a pure exact floor/cross-product arithmetic lemma and that
`_thresholdBIPS >= 10000` fails before any `SSTORE`, `TSTORE`, or external
`CALL`. Successful forwarding, cleanup, rollback, and mode isolation are
covered by Halmos and Lean instead; Certora does not link the pure lemma to the
successful Yul-local path. Lean's refinement retains the explicit
`hsetupThreshold` call-frame seam.

The cloud evidence remains bounded by optimistic hashing at 512 bytes, `viaIR`
internal-resolution diagnostics, and a direct-implementation scene.
Initialization, direct upgrade, and queued-upgrade dispatch remain outside the
old-implementation preservation rules because authorized UUPS replacement can
invalidate them. The results are not unrestricted all-input or proxy/UUPS
correctness claims.

## Reproduce and release

Use
[`relay-verification/11-reproducibility.md`](relay-verification/11-reproducibility.md)
for exact tools and commands. The manifest pins solc 0.8.35, Cancun,
optimizer 200, `viaIR=true`, the exact Foundry/Halmos/Lean toolchains, the
Halmos inventory, and the complete proof-semantic Certora configs at manifest
`7ae2208f96a520f477b528ee808909f87e9402247bacab00e04052fa02ec2cb1`.

A release claim requires all normalized reports to pass for the same clean Git
commit and manifest hash, followed by a successful evidence bundle. The six
current local constituents pass for reviewed source revision `d5af7136…` and manifest `7ae2208f…`,
but each has `release_eligible=false` solely because generation began and ended
in a dirty worktree. Their aggregate bundle passes, validates all six reports,
and has SHA-256
`be386d63acdd336b99ab84c64cb0f32ba9c3bafbba02b17164ebd176b7e4f64a`; it is
also development-only solely because the worktree was dirty at start and end.
Cloud evidence is not a constituent of that bundle. The supplemental cloud
report is SHA-256
`93d09d86d1acbf3b3ffdb0f6d9f8145b094722b9b7de94e131ef8e8e97ca4821`
and remains PARTIAL. A local Certora front-end pass, a partial cloud result, an
old green pipeline, or a dirty development bundle is not release evidence; a
clean commit-bound rerun remains required.
