# Claims ledger, trust boundary, and residual obligations

This ledger defines the current formal-verification contract for `Relay.sol`.
Each row states the verified object and limitation. A row is evidence-backed only
when its required normalized report is accepted by a release-eligible aggregate
bundle for the same source and manifest.

## Evidence standards

| Evidence type | Acceptance standard |
| --- | --- |
| Foundry | supplementary evidence: selected test passes, or no counterexample within the configured fuzz budget; current bundle does not normalize Foundry output |
| Halmos proof | manifest-listed check returns `PASS` and required accepting paths have validated reachability witnesses |
| Lean | manifest-listed file checks; declared axiom audits contain only the allowlisted set; no proof holes or undeclared shortcuts |
| Certora local | exact Solidity/CVL/config/toolchain inputs compile and typecheck; this is not a prover verdict |
| Certora cloud | every required rule has an accepted prover/sanity outcome and the downloaded evidence is normalized against its exact config |
| Artifact/ABI gate | exact source, compiler, encoding, bytecode, optimized-Yul, selector, and provenance comparisons pass |

## Current claim register

| ID | Claim | Object and coverage | Evidence | Important premises/limits |
| --- | --- | --- | --- | --- |
| C-01 | Accepted signature indices do not reuse a policy slot | Compiled bytecode, bounded | `RelaySigFV`, `RelaySigParamFV`, `RelayModelBridgeFV` | Harness shape and loop bound |
| C-02 | Acceptance implies sufficient indexed policy-slot weight | Compiled bytecode bounded; abstract model unbounded | C-01 harnesses; [`RelaySigLoop.threshold_sound`](../../test-forge/fv/lean/RelaySigLoop.lean#L104) | Distinct signer identities require a separate unique-address premise |
| C-03 | Bad `v` and high `s` cannot accept in the modeled Relay path; the modeled repeated-index layouts cannot inflate accepted weight; the modeled recovery ABI rejects empty return data and a zero signer | Compiled bytecode, bounded; recovery guard model plus concrete precompile ABI | `RelayCanonicalityFV`, signature-accounting harnesses, `RelayEcrecoverSymbolicFV`, `RelayEcrecoverABI` | ECDSA security is assumed. General decreasing/out-of-order and out-of-range index rejection, plus wrong-recovered-signer rejection, have supplementary concrete tests rather than dedicated manifest-listed symbolic properties |
| C-04 | Reward-epoch, delay, finalization-window, and new-policy selection gates reject their modeled invalid cases | Compiled bytecode, bounded | epoch/policy Halmos harnesses in the manifest | Does not prove policy start metadata is monotonic |
| C-05 | Mode-1 rejects the modeled below-minimum threshold and reaches one fixed valid rotation shape; the setter path enforces modeled sequential-epoch and threshold-band conditions | Compiled bytecode, bounded | `RelayModeOneFV`, `RelayEpochAdvanceFV`, `RelayThresholdConsistencyFV` | General Mode-1 length, epoch, and total-weight validation across symbolic policy shapes is not established; unique/nonzero voters and positive total weight must be separately proved or enforced |
| C-06 | Stored random value is bound to the signed Merkle root for the modeled proof shape | Compiled bytecode, bounded | `RelayRandomBindingFV`, `RelayMerkleProofFV`, `RelayMerkleFoldFV` | Keccak collision resistance and deeper/unbounded proofs are assumed/out of scope |
| C-07 | The live random pointer does not regress over modeled ordinary-round sequences | Compiled bytecode, bounded sequence | `RelayRandomMonotonicityFV` | Does not establish a future horizon, terminal-round liveness, migration continuity, or round-zero presence |
| C-08 | Random security byte normalization agrees with modeled stored sinks | Compiled bytecode, bounded | `RelayIsSecureNormFV` | First-round-zero live-state behavior must be covered separately |
| C-09 | `verify()` fee arithmetic and modeled value transfers conserve the expected amount | Compiled bytecode, bounded | `RelayVerifyFeeFV`, `RelayFeeConservationFV` | Recipient/refund availability and trusted `oldRelay` behavior remain environmental; the ERC-20 fee-token path (`feeToken` set: exact `safeTransferFrom` pull, `MsgValueNotAllowed` guard) and the EnumerableSet-backed fee table (set ⟺ nonzero-fee invariant, clear-on-token-switch) are NOT yet modeled — they join the pending re-baseline scope, and the fee-layer claims currently cover the native branch only |
| C-10 | Owner-only operations, timelock delay, execution, and guarded UUPS entry behave as modeled; relay mode rejects `oldRelay`, while setter mode admits the modeled compatible home Relay | Compiled bytecode, bounded | `RelayAccessControlFV`, `RelayOwnerTimelockFV`, `RelayConstructorFV`, concrete tests | Constructor compatibility checks mode and voting/reward timing fields, but not implementation identity, code provenance, fees, or policy-boundary equality; queued operations are not generation-bound or expiring |
| C-11 | Protocol-1 threshold selection uses exact BIPS floor/strict arithmetic and is isolated from other protocol modes | Compiled bytecode bounded; Lean arithmetic unbounded | `RelayThresholdOverrideFV`, `RelayThresholdScalingFV`, `RelaySigLoop` | Complete self-call `TSTORE`→`TLOAD` composition remains a declared refinement seam |
| C-12 | Canonical source-domain policy hashing agrees with the implementation for the modeled one-, two-, and three-voter policy shapes | Compiled bytecode/encoding fixtures at 65, 87, and 109 policy bytes with source fixed to `block.chainid` | `RelayPolicyHashFV` | Arbitrary policy lengths and mirror source IDs are outside this Halmos property; keccak collision resistance is assumed. Message-digest agreement is covered only by supplementary Foundry tests |
| C-13 | Custom assembly reverts use the interface-declared four-byte selectors exactly | Static source/interface gate | `relay-custom-error-abi.json` | Only manifest-listed errors/use counts are covered |
| C-14 | FV compilation matches the production deployment artifact and committed optimized-Yul snapshot | Exact generated artifacts | deployment and artifact-parity reports | Applies only to the pinned compiler/settings and current clean source |
| C-15 | The abstract loop refines the modeled EVM/Yul components | Unbounded conditional Lean development | bytecode-refinement files declared by the manifest | Setup, accepted-run extraction, cryptography, whole-control-flow composition, and Yul→bytecode compilation remain explicit seams |

## Assumption register

| ID | Assumption | Consequence if false |
| --- | --- | --- |
| A-CRYPTO | ECDSA is unforgeable and keccak is collision/second-preimage resistant for the relevant encodings | Authentication and Merkle/digest binding can fail |
| A-POLICY-ID | Active policies contain unique nonzero voter addresses | Without it, one key can count at multiple indices; this is not currently enforced on every admission path |
| A-POLICY-WEIGHT | Active policies have positive bounded total weight and acceptable per-voter weights | Without it, an admitted policy can be unusable or violate proof fixtures |
| A-POLICY-ORDER | Policy start rounds are nondecreasing | Without it, policy-authority intervals can overlap unexpectedly |
| A-MIGRATION | Initial policy start equals the read-delegation boundary and `oldRelay` is the intended trusted deployment | Without it, roots can be shadowed, gaps can form, or delegated values can be malicious |
| A-RANDOM-DOMAIN | Accepted future rounds remain within a readable and supersedable range | Without it, a quorum can poison the live pointer with a terminal round |
| A-OZ | Imported OpenZeppelin proxy, ownership, Merkle, and utility semantics match their reviewed versions | Proxy, access, or proof behavior can differ from the model |
| A-EVM | EVMYulLean correctly models the EVM/Yul fragment used by the refinement | R4b no longer transfers to actual machine semantics |
| A-COMPILER | solc faithfully lowers the checked optimized Yul to deployed EVM bytecode outside bounded artifact behavior | Unbounded Yul-level claims may not hold for deployed bytecode |
| A-UPGRADE | Any future implementation preserves required storage and security invariants | Current implementation proofs do not constrain upgraded code |
| A-CONSUMER | Custom-message consumers domain-separate and enforce nonce/freshness semantics | Valid Relay attestations can be replayed or misinterpreted |

## Current open obligations

These obligations remain open and are not established by the positive claim
register. The current suite does not yet contain complete regressions for them;
future work must add an explicit counterexample regression for each behavior that
remains vulnerable, or a rejection/invariant regression after remediation:

| Obligation | Required property |
| --- | --- |
| O-01 Policy identity | Every admitted complete policy has pairwise-distinct nonzero voter addresses; accepted weight can be related to distinct identities |
| O-02 Policy viability | Every admitted policy has positive total weight and a reachable threshold under its configured rules |
| O-03 Policy ordering | Start rounds are monotonic, or the policy-selection algorithm remains unambiguous for all admitted sequences |
| O-04 Initial migration partition | The complete initial policy is validated and its encoded start equals the local/delegated read boundary |
| O-05 Random horizon | No accepted random can make the live pointer unreadable or impossible to supersede |
| O-06 Current-random continuity | A migrated Relay reports the trusted current random until a local current random exists |
| O-07 Round-zero presence | Per-round and live value/security state agree for the first accepted round, including zero |
| O-08 Timelock lifecycle | Ownership transfer and implementation upgrade invalidate prior generations' queued calls, and queued calls expire |

## Explicit non-claims

The verification package does not claim:

- whole-contract functional correctness;
- absence of every vulnerability;
- distinct-voter quorum without A-POLICY-ID;
- cryptographic correctness of ECDSA or keccak;
- safe semantics for arbitrary consumer-supplied custom digests;
- liveness under a malicious but valid quorum;
- correctness of deployment or migration inputs not bound by an artifact;
- correctness of any future UUPS implementation; or
- a Certora cloud proof when only the local front-end gate passed.
