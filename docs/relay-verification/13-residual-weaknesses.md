# L13 — Current residual weaknesses and verification gaps

This page is the verification-facing risk summary for the owner-timelock Relay.
The detailed security analysis and reproductions are in
[`relay-owner-timelock-security-review.md`](../relay-owner-timelock-security-review.md).
Executable proof status is in [`CURRENT-STATUS.md`](CURRENT-STATUS.md).

## 13.1 Current code findings

These are live source-level findings, not merely proof-model limitations:

| Finding                                                                           | Impact                                                                                                        | Verification consequence                                                                                                                   |
| --------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| duplicate voter addresses can occupy different policy indices                     | one ECDSA signature can be replayed at each duplicate index and receive each indexed weight                   | distinct-index proofs do not imply distinct-signer weight unless policy-address uniqueness is an explicit assumption or on-chain invariant |
| voting round `uint32.max` is a terminal random pointer                            | the contract can store the maximum round, after which the current-random getter's `+1` sentinel logic reverts | monotonicity alone is insufficient; the live-state invariant also needs `randomVotingRoundId < type(uint32).max`                           |
| a fresh migration starts with no current random                                   | callers can observe unavailable/insecure bootstrap randomness until a new random finalization                 | migration proofs need an explicit random-state handoff or a fail-closed availability contract                                              |
| initial policy metadata and the old-Relay read boundary are configured separately | a locally stored initial policy may be shadowed by delegation to `oldRelay`                                   | initialization proofs must relate policy epoch, start round, and delegation boundary                                                       |
| queued timelock calls survive ownership transfer and implementation upgrades      | an operation authorized by a former owner remains permissionlessly executable after its ETA                   | timelock specifications must state whether authorization is checked at queue time only or is invalidated by an ownership generation        |

The duplicate-voter issue is the most important correction to the historical
proof narrative. Strictly increasing **indices** prevent reusing one index; they
do not prevent one address from appearing at multiple indices. Any theorem that
concludes "distinct voter weight" therefore depends on a unique-address signing
policy. The trusted setter and relayed policy formats do not currently enforce
that condition on-chain.

## 13.2 Current formal-verification gaps

1. **The current Certora cloud verdict is PARTIAL.** The local Certora front end
   passes all 3 configs and 15 rules at `d5af7136…` (report SHA-256
   `9d3ce039…`), but compilation, exact munging, and CVL typechecking are not a
   prover verdict. The normalized supplemental cloud report (SHA-256
   `93d09d86…`) records 308 `SUCCESS`, 2 validated `SATISFIED`, 24
   `SANITY_FAIL`, and no semantic assertion counterexample, `UNKNOWN`, or
   `TIMEOUT`. The threshold configuration passes. The
   [scalar](https://prover.certora.com/output/3798318/96136f4b1ce349889963c722745f6d8a)
   and
   [write-once/timelock](https://prover.certora.com/output/3798318/5f29c9d404134b7aa3578484455bf424)
   configurations remain partial because of the exact sanity exclusions for
   `relay`, `setSigningPolicy`, and `renounceOwnership` across all six scalar
   and both mapping rules. Those configs use `loop_iter=3`, optimistic loops,
   and optimistic hashing up to 512 bytes. The passing
   [threshold job](https://prover.certora.com/output/3798318/a133698c16d54e7cb4a518a3251dd73a)
   proves exact arithmetic and fail-fast behavior for `_thresholdBIPS >= 10000`
   before any `SSTORE`, `TSTORE`, or external `CALL`; successful forwarding,
   cleanup, rollback, and mode isolation remain Halmos/Lean claims.
2. **UUPS is a trust boundary.** An authorized replacement can intentionally
   invalidate every invariant of the old implementation. Current Certora scalar
   and write-once rules exclude initialization, direct upgrade, and queued upgrade
   dispatch. They do not establish storage compatibility of a future implementation.
3. **Proxy context matters.** A rule that reaches `upgradeToAndCall` only against
   an implementation instance can be vacuous because UUPS requires a proxy call.
   Per-method sanity and a proxy-aware harness are required before making upgrade
   authorization claims.
4. **Lean/Yul and Kontrol artifacts are models.** The current Lean gate passes
   9/9 files and 183 declared-axiom audits against the regenerated optimized-Yul
   snapshot (report SHA-256 `82fff1ff…`). Its protocol-1 threshold capstone
   deliberately uses an explicit `hsetupThreshold` premise for the unextracted
   `TSTORE -> self-call -> TLOAD -> threshold-local` seam; it does not prove a
   full transient-storage interpreter. Kontrol remains historical/model-only.
5. **Bounded signature proofs need the uniqueness premise.** The current Halmos
   gate passes 123/123 checks (86 proofs and 37 reachability controls), including
   exact threshold boundaries and modeled transient cleanup/rollback/address
   scope. Those results are bounded, and they cannot turn duplicate policy
   addresses into distinct cryptographic principals.
6. **Cryptography remains assumed.** `keccak256` collision resistance and ECDSA
   unforgeability are outside the EVM proof. Dedicated checks can validate the
   precompile ABI and Relay's guard logic, not the cryptographic theorem itself.

## 13.3 Owner-timelock trust model

The per-chain owner is trusted to choose fees, exemptions, the signing-policy
setter, timelock duration, and implementation. With a nonzero duration, guarded
calls authorize exact calldata when queued; execution after the ETA is
permissionless. The current implementation does not bind a queued entry to the
owner that created it or to an ownership generation.

The timelock's transient `executing` bit is a single-use authorization for the
first guarded self-call. Migration calldata that invokes another guarded method
can fail because the nested call no longer sees that authorization. Tests and
specifications must distinguish:

- queue-time authorization;
- permissionless execution;
- exact-calldata consumption;
- ownership changes between queue and execution; and
- upgrade migrations executed as proxy self-calls.

## 13.4 Proof claims that are not made

The current evidence does not claim:

- that all signing policies contain unique, nonzero, canonically ordered voters;
- that current randomness is always available after migration;
- that the maximum `uint32` voting round is safe;
- that a new UUPS implementation preserves layout or semantics;
- that historical Safe/GSS proofs apply to owner-timelock governance;
- that a local Certora typecheck is a cloud proof;
- that Lean's explicit `hsetupThreshold` premise is a literal extraction of the
  transient-storage call-frame seam;
- that the PARTIAL Certora cloud result covers its 24 sanity-excluded
  method/rule pairs;
- that an optimistic-loop Certora verdict covers executions beyond its bound;
- that a bounded result covers arbitrary voter/signature counts; or
- that a mathematical/Lean model is mechanically extracted from current deployed bytecode.

## 13.5 Recommended closure order

1. Enforce unique, nonzero voter addresses when policies are created or accepted,
   and add negative exploit tests plus an explicit uniqueness premise to every
   accounting theorem.
2. Reject or redesign the `uint32.max` random round sentinel and prove the live
   current-random getter remains callable after every successful update.
3. Define and enforce migration invariants for random state and the policy/read
   boundary.
4. Decide whether ownership transfer cancels or generation-invalidates queued
   calls; encode the intended behavior in tests and CVL.
5. Resolve or explicitly scope the 24 current Certora sanity exclusions, retain
   the validated SAT witnesses, and add a proxy-aware UUPS harness before
   promoting affected scalar/write-once or upgrade claims.
6. Re-run the manifest, deployment/artifact/custom-error, Halmos, Lean, Certora
   local, link, and evidence-bundle gates on one clean commit; publish only that
   commit's reports. The six present local reports and their aggregate bundle
   pass but are development-only solely because their generation checkout was
   dirty. The bundle validates all six and has SHA-256 `be386d63…`; a clean
   release-eligible rerun is still required.

Historical Safe/GSS risks, old compiler results, and old proof counts remain
available through git history. They are intentionally not repeated as current
evidence here.
