# Claims ledger, trust boundary, and residual obligations

This ledger defines the current formal-verification contract for `Relay.sol`.
Each row states the verified object and limitation. Local-gate claims are
release-backed only when their required normalized reports are accepted by a
release-eligible aggregate bundle for the same source and manifest. Any cloud
portion of a claim additionally needs current, complete normalized Certora
evidence; cloud results are supplemental to the local bundle.

## Evidence standards

| Evidence type | Acceptance standard |
| --- | --- |
| Foundry | supplementary evidence: selected test passes, or no counterexample within the configured fuzz budget; current bundle does not normalize Foundry output |
| Halmos proof | manifest-listed check returns `PASS` and required accepting paths have validated reachability witnesses |
| Lean | manifest-listed file checks; declared axiom audits contain only the allowlisted set; no proof holes or undeclared shortcuts |
| Certora local | exact Solidity/CVL/config/toolchain inputs compile and typecheck; this is not a prover verdict |
| Certora cloud | every required rule has an accepted prover/sanity outcome and the downloaded evidence is normalized against its exact config |
| Artifact/ABI gate | exact source, compiler, encoding, bytecode, optimized-Yul, normalized sequential storage layout, selector, and provenance comparisons pass |

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
| C-08 | Accepted random security bytes are canonical `0` or `1`, and their value agrees with the modeled Merkle leaf, historical bit, and live security field; other protocols require a zero byte | Compiled bytecode, bounded | `RelayIsSecureNormFV` and manifest-listed canonicality checks | Acceptance controls distinguish `0` and `1`; noncanonical bytes are rejection obligations, not successful normalization cases. Live-state fixtures use a positive round, so first-round-zero presence remains outside this claim |
| C-09 | For a non-exempt caller, native-mode `verify()` enforces the configured fee, forwards that amount, refunds excess, and conserves native value on the modeled local path | Compiled bytecode bounded; native balance arithmetic in Lean | `RelayVerifyFeeFV`, `RelayFeeConservationFV`, [`RelayFeeLayer`](../../test-forge/fv/lean/bytecode-refinement/RelayFeeLayer.lean) | Conditional on `feeToken == address(0)` and local (non-`oldRelay`) verification; fee exemptions intentionally reduce the charge to zero. The compiled-bytecode balance fixture caps fee and `msg.value` below 2^128; Lean proves its stated arithmetic theorem without that fixture bound. Recipient/refund availability and the full exec-level Lean `.CALL` composition remain explicit seams |
| C-09M | On the modeled pre-boundary path, Relay requires source finalization, does not consult the source fee getter, delegates verification with zero value, and after a true result refunds the caller's full attached value; a modeled source requiring a positive fee fails closed even when the caller supplied enough value | Compiled production Relay bytecode against compatible observable sources, bounded; CVL external-call value/target observations | `RelayOldRelayFeeFV`; `oldRelayDelegationForwardsNoValueAndRefundsOnSuccess` when backed by a current complete cloud report | Attached value is bounded to `uint128` in Halmos; CVL uses an empty proof and requires the sender's modeled native balance to fund the attached value so the payable call can enter Relay. A successful refund requires a receptive caller. Source finalization and verification responses remain trusted; these checks establish Relay's guard and call/value behavior, not source bytecode identity or delegated proof integrity. The configured source must satisfy A-MIGRATION |
| C-09T | Token-mode `verify()` rejects nonzero `msg.value`; the modeled valid charged empty-proof path pulls exactly the configured fee from payer to collector; modeled invalid/unfinalized, exempt, and free paths do not call the token; the native-wei getter reverts exactly when token mode is active | Compiled production Relay plus deterministic exact-transfer token, bounded; CVL external-call ordering/target rules | `RelayFeeTokenFV`; `tokenModeRejectsNativeValueBeforeExternalCall`, `tokenModeUnfinalizedVerificationDoesNotCallToken`, `tokenModeInvalidEmptyProofDoesNotCallToken`, `tokenModeValidEmptyProofCallsConfiguredToken`, `protocolFeeInWeiMatchesNativeFee`, and `protocolFeeInWeiRejectsTokenMode` when backed by a current complete cloud report | Standard exact-transfer ERC-20 semantics, balance, and allowance are premises; exact balance and valid/invalid proof fixtures use an empty proof and quantify fees through `uint96`. The CVL call rule proves target/order/native value, not token balance delta; adversarial callbacks, fee-on-transfer, rebasing, and token upgrades are outside the claim; Lean does not model this branch |
| C-09F | Fee configuration is a mode-restricted atomic full replacement: enumeration matches nonzero mapping entries, omitted IDs clear, denomination switches carry no amounts, and duplicate/zero/reserved entries revert without partial state | Compiled bytecode, bounded; CVL transition invariants | `RelayFeeTokenFV`, `RelayConstructorFV`, `RelayOwnerTimelockFV`; `feeTokenZeroInSetterMode`, `protocolFeeZeroInSetterMode`, `feeTableMappingSetLockstepPreserved`, `reservedProtocolFeesRemainUnset`, `immediateSetterModeProtocolFeeUpdateReverts`, `immediateProtocolFeeUpdateCanApply`, and `successfulNonUpgradeExecutionPreservesRelayInvariants` when backed by a current complete cloud report | Halmos uses fixed small table shapes and `uint96` fees; Certora local preparation alone is not a prover verdict |
| C-10 | Owner-only operations, exact-calldata queue identity, delayed ownership transfer, duplicate-queue ETA replacement, permissionless one-shot execution, cancellation, guarded UUPS entry, and survival of unrelated queued calls across `transferOwnership` behave as modeled; relay mode rejects `oldRelay`, while setter mode admits the modeled compatible home Relay | Compiled bytecode, bounded | `RelayAccessControlFV`, `RelayOwnerTimelockFV`, `RelayConstructorFV`, concrete tests; manifest-listed ownership CVL rules when backed by a current complete cloud report | A zero delay permits immediate transfer; a positive delay queues it and preserves the owner until execution. The namespaced execution flag is persistent storage, separate from Relay's transient threshold slot. Constructor compatibility checks mode and voting/reward timing fields, not implementation identity, code provenance, fees, or policy-boundary equality. Queued operations are not proposer-bound, owner-generation-bound, implementation-generation-bound, expiring, or invalidated by ownership transfer |
| C-11 | Protocol-1 threshold selection uses exact BIPS floor/strict arithmetic and is isolated from other protocol modes | Compiled bytecode bounded; Lean arithmetic unbounded | `RelayThresholdOverrideFV`, `RelayThresholdScalingFV`, `RelaySigLoop` | Complete self-call `TSTORE`→`TLOAD` composition remains a declared refinement seam |
| C-12 | Canonical source-domain policy hashing agrees with the implementation for the modeled one-, two-, and three-voter policy shapes | Compiled bytecode/encoding fixtures at 65, 87, and 109 policy bytes with source fixed to `block.chainid` | `RelayPolicyHashFV` | Arbitrary policy lengths and mirror source IDs are outside this Halmos property; keccak collision resistance is assumed. Message-digest agreement is covered only by supplementary Foundry tests |
| C-12W | Both custom-signature wrappers reject modeled short or non-`relay()` calldata with `NotRelayCall`; the permitted selector reaches the inner Relay parser, and a rejected wrapper call leaves the modeled transient threshold slot clear | Compiled production bytecode through the proxy, bounded | `RelayThresholdOverrideFV` selector/length checks and accepting quorum controls; `RelayReturnDiscriminatorFV` | Short inputs range over lengths 0–3 and symbolic contents; non-Relay selectors use a fixed symbolic 32-byte tail; override BIPS range below 10000. Selector-only calldata exercises an inner rejection, not successful authentication. Arbitrary-length payloads and consumer freshness are outside this property |
| C-13 | Custom assembly reverts use the interface-declared four-byte selectors exactly | Static source/interface gate | `relay-custom-error-abi.json` | Only manifest-listed errors/use counts are covered |
| C-14 | FV compilation matches the production deployment artifact, committed optimized-Yul snapshot, and compiler-normalized first-deployment sequential Solidity storage layout | Exact generated artifacts | deployment and artifact-parity reports; `relay_storage_layout.json` | Applies only to the pinned compiler/settings and current clean source; the layout snapshot excludes ERC-7201 namespaces and transient slots, and drift detection is not compatibility proof for future code |
| C-15 | The abstract loop refines the modeled EVM/Yul components | Unbounded conditional Lean development | bytecode-refinement files declared by the manifest | Setup, accepted-run extraction, cryptography, whole-control-flow composition, and Yul→bytecode compilation remain explicit seams |

## Assumption register

| ID | Assumption | Consequence if false |
| --- | --- | --- |
| A-CRYPTO | ECDSA is unforgeable and keccak is collision/second-preimage resistant for the relevant encodings | Authentication and Merkle/digest binding can fail |
| A-POLICY-ID | Active policies contain unique nonzero voter addresses | Without it, one key can count at multiple indices; this is not currently enforced on every admission path |
| A-POLICY-WEIGHT | Active policies have positive bounded total weight and acceptable per-voter weights | Without it, an admitted policy can be unusable or violate proof fixtures |
| A-POLICY-ORDER | Policy start rounds are nondecreasing | Without it, policy-authority intervals can overlap unexpectedly |
| A-MIGRATION | Initial policy start equals the read-delegation boundary and every source reachable through the configured `oldRelay` chain is an intended trusted supported setter-mode Relay deployment | Without it, roots can be shadowed, gaps can form, delegated values can be malicious, and the fee-free delegation premise need not hold |
| A-RANDOM-DOMAIN | Accepted future rounds remain within a readable and supersedable range | Without it, a quorum can poison the live pointer with a terminal round |
| A-OZ | Imported OpenZeppelin proxy, ownership, Merkle, and utility semantics match their reviewed versions | Proxy, access, or proof behavior can differ from the model |
| A-EVM | EVMYulLean correctly models the EVM/Yul fragment used by the refinement | R4b no longer transfers to actual machine semantics |
| A-COMPILER | solc faithfully lowers the checked optimized Yul to deployed EVM bytecode outside bounded artifact behavior | Unbounded Yul-level claims may not hold for deployed bytecode |
| A-UPGRADE | Any future implementation preserves required storage and security invariants | Current implementation proofs do not constrain upgraded code |
| A-CONSUMER | Custom-message consumers bind destination, purpose, request/nonce, and expiry as required by their protocol | The returned reward epoch identifies the policy under which the signature set is accepted, not when the signatures were produced; valid attestations can otherwise be replayed or misinterpreted |
| A-FEE-TOKEN | A configured fee token is a reviewed standard exact-transfer ERC-20 and its implementation/upgrade authority preserves that behavior | The collector may receive a different amount, or token callbacks/availability behavior may invalidate the modeled transfer claim |

## Admission, deployment, and integration obligations

The positive claim register does not establish the requirements below. Some are
trusted-input checks or operational choices rather than rejected on-chain inputs.
Release review must enforce the relevant condition, retain the explicit
assumption, or establish an alternative property. Boundary regressions should
assert the selected current behavior without implying an unrestricted theorem.

| Obligation | Condition to validate or document |
| --- | --- |
| O-01 Policy identity | Every admitted complete policy has pairwise-distinct nonzero voter addresses; accepted weight can be related to distinct identities |
| O-02 Policy viability | Every admitted policy has positive total weight and a reachable threshold under its configured rules |
| O-03 Policy ordering | Start rounds are monotonic, or the policy-selection algorithm remains unambiguous for all admitted sequences |
| O-04 Initial migration partition | The complete initial policy is validated and its encoded start equals the local/delegated read boundary |
| O-05 Random horizon | No accepted random can make the live pointer unreadable or impossible to supersede |
| O-06 Current-random initialization | Consumers tolerate the local live getter's uninitialized state after migration, or the deployment/integration provides continuity until a local current random exists |
| O-07 Round-zero presence | Per-round and live value/security state agree for the first accepted round, including zero |
| O-08 Timelock lifecycle | Handover and upgrade procedures enumerate emitted queued-call records and cancel unwanted operations; the current implementation intentionally preserves unrelated queued calls and provides no expiry or generation binding |

## Explicit non-claims

The verification package does not claim:

- whole-contract functional correctness;
- absence of every vulnerability;
- distinct-voter quorum without A-POLICY-ID;
- cryptographic correctness of ECDSA or keccak;
- safe semantics for arbitrary consumer-supplied custom digests;
- liveness under a malicious but valid quorum;
- correctness of deployment or migration inputs not bound by an artifact;
- exact fee delivery or callback behavior for a token outside A-FEE-TOKEN;
- correctness of any future UUPS implementation; or
- a Certora cloud proof when only the local front-end gate passed.
