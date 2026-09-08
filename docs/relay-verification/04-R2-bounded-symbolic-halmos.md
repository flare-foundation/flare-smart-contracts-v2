# R2 — bounded symbolic execution with Halmos

Halmos executes the compiled FV harness bytecode with symbolic inputs. A
`check_*` function parameter represents an arbitrary value, `vm.assume` defines
the premise, and `assert` defines the property. The SMT solver searches every
feasible path within the configured loop and resource bounds.

## Normative inventory

[`verification-manifest.json`](../../test-forge/fv/verification-manifest.json)
contains the exact lists of:

- proof checks, which must return `PASS`;
- reachability checks, which must return a validated `COUNTEREXAMPLE` witness;
- declaring harness contracts;
- compiler, EVM, optimizer, Foundry, Halmos, and solver pins; and
- the target source, optimized-Yul snapshot, and normalized sequential-storage-layout
  baseline used by the evidence gates.

The gate fails if source discovery and the manifest differ. Adding, renaming, or
deleting a `check_*` function therefore requires an explicit manifest change.

## Coverage groups

The current harness tree covers these implementation surfaces:

| Group | Representative harnesses |
| --- | --- |
| Signature parsing and accounting | `RelaySigFV`, `RelaySigParamFV`, `RelayCanonicalityFV`, `RelayModelBridgeFV`, `RelayParserGuardsFV`, `RelaySignatureGuardsFV` |
| Ecrecover return ABI | `RelayEcrecoverABI`, `RelayEcrecoverSymbolicFV` |
| Policy/epoch selection | `RelayWrongEpochFV`, `RelayDelayedPolicyFV`, `RelayFinalizationWindowFV`, `RelayCrossEpochFV`, `RelayMustUseNewPolicyFV` |
| Policy rotation and thresholds | `RelayModeOneFV`, `RelayEpochAdvanceFV`, `RelayThresholdScalingFV`, `RelayThresholdConsistencyFV`, `RelayThresholdOverrideFV` |
| Randomness and Merkle binding | `RelayRandomBindingFV`, `RelayRandomMonotonicityFV`, `RelayIsSecureNormFV`, `RelayMerkleProofFV`, `RelayMerkleFoldFV` |
| Successful raw-relay storage preservation | `RelayStateFrameFV` ordinary/random accepting paths and sampled unrelated state |
| Fees, fee-table replacement, delegation, and return values | `RelayVerifyFeeFV`, `RelayFeeConservationFV`, `RelayOldRelayFeeFV`, `RelayFeeTokenFV`, `RelayReturnDiscriminatorFV` |
| Initialization, access, owner/timelock/UUPS | `RelayConstructorFV`, `RelayAccessControlFV`, `RelayOwnerTimelockFV`, including delayed ownership transfer, duplicate-queue replacement, and unrelated queue survival across ownership transfer |
| Policy digest encoding | `RelayPolicyHashFV`; message source-domain fixtures are supplementary Foundry tests |
| Custom-signature call boundary | `RelayThresholdOverrideFV` short-input and non-Relay-selector rejection, inner-parser reachability, and accepting quorum controls; `RelayReturnDiscriminatorFV` return shape |

The manifest, not this table, is authoritative for the exact inventory.

## Bounded meaning

A Halmos pass means no violating input exists within the shape constructed by
the harness and the manifest's loop-unrolling bound. Typical harnesses use small
numbers of voters/signatures and shallow Merkle paths selected to exercise the
branches relevant to each stated property.

It does not generalize automatically to:

- all voter counts up to the contract maximum;
- all signature-list lengths;
- arbitrarily deep Merkle proofs;
- arbitrary transaction sequences; or
- inputs excluded by `vm.assume` or fixed fixture construction.

The token-fee harness executes SafeERC20 against a deterministic standard
exact-transfer ERC-20 fixture. Its claims do not generalize to fee-on-transfer,
rebasing, callback-capable, adversarial, or independently upgradeable token
semantics.

Direct Mode-1 rotation checks use a three-voter current policy and one/two-voter
replacement policies. They cover symbolic below/above-band thresholds and
wrong next epochs, selected count/length/total-weight rejection edges, rollback
of tentative policy writes in the zero-signature insufficient-quorum case, and
asserted successful policy/epoch effects. Acceptance controls cover the inclusive threshold-band
edges and total weight 65535. Rejection of a count of 301 does not establish
acceptance or arbitrary execution with the maximum 300 voters.

The dedicated parser/signature-guard fixtures use protocol 3, a 109-byte
three-voter policy with weights 100 each, and threshold 180. Selected truncations
and oversized declared counts fail before signature inspection. Reached-record
checks require a valid first signature, which cannot alone reach quorum, then
assert the exact range/order/wrong-signer error and sampled persistent rollback.
Literal branches enumerate each property's small valid-index domain so the
symbolic executor can resolve voter-record copy offsets: reached out-of-range
checks allow first index 0/1/2 and second index 3–65535; decreasing checks cover
(1,0), (2,0), and (2,1); wrong-signer checks fix the first index at 0 and allow
second index 1/2. Invalid uint16 indices remain symbolic.
A positive early-return property and accepting control establish that
two valid records can finish without authenticating a complete trailing invalid
record. These properties do not require exact total calldata length after quorum.

Storage-preservation checks execute raw ordinary and secure-random messages with
three signatures, and one Merkle sibling for random finalization. They assert
the target root/value effects and preserve sampled unrelated state; the random
path also masks out only the permitted live-random fields in packed `stateData`.
The private-slot observations are coupled to the artifact-gated sequential
layout. These fixed fixtures do not prove preservation of every mapping key in
an arbitrary state or across arbitrary transaction sequences.
Sampled unrelated mappings contain nonzero sentinels, including another bit in
the random-security word. Fee, exemption, and queued-call samples are initialized
through owner entry points, so clearing those samples cannot pass as preservation.
The implementation slot is checked directly before any post-call proxy getters;
the queued-call observation captures success and raw return data without reverting.
Those boundaries prevent a corrupted implementation or missing queue record from
silently removing the accepting path from the proof.

The `oldRelay` value-flow harness bounds attached value to `uint128` and uses
compatible observable source fixtures that implement `isFinalized()` and
`verify()`. Acceptance requires the finalized response before the zero-value
verification call. The harness proves how the current Relay calls those
fixtures; it does not establish the bytecode identity or proof integrity of an
arbitrary configured migration source.

Security-byte checks cover canonical `0` and `1` random messages and rejection
of bytes above `1`; nonrandom protocols require `0`. Accepting witnesses must
exercise the two permitted random values separately. A fixture treating all
nonzero bytes as an accepted true value does not model the current parser.

The custom-signature selector checks exercise both wrappers with every input
length below four and symbolic short contents, and every non-Relay selector
with a fixed symbolic 32-byte tail. They require the exact `NotRelayCall`
rejection and a clear threshold-override slot after rollback. The valid-selector
control reaches the inner parser with selector-only calldata; the separate
quorum controls establish successful authentication. These shapes do not claim
arbitrary-length payload coverage.

For example, a harness that constructs distinct addresses proves a theorem under
address uniqueness. It cannot detect duplicate-identity weight amplification.

## Cryptographic modeling

Halmos treats keccak and ecrecover according to its symbolic execution model.
Accounting claims do not prove collision resistance or ECDSA unforgeability.
Giving the solver freedom over a recovered signer is conservative for
slot-accounting properties, but consumer authentication still relies on the
real cryptographic assumptions.

The raw ecrecover precompile has a load-bearing ABI detail: an invalid signature
may return success with empty return data, leaving the output word stale. Relay's
success, exact-returndata-size, and nonzero-address checks are covered by a
concrete EVM ABI test and a symbolic stale-buffer harness.

## Running the gate

```bash
FORGE=/path/to/manifest-pinned-forge
HALMOS=$PWD/.venv-halmos/bin/halmos

FORGE=$FORGE HALMOS=$HALMOS \
  .venv-halmos/bin/python test-forge/fv/verify_fv.py \
  --report-output verification-reports/relay-halmos.json
```

Do not pass extra diagnostic arguments when producing release evidence. The
wrapper sanitizes the environment, rebuilds the exact harness tree, validates
the toolchain and artifacts, runs the manifest inventory, validates reachability
models, and records generation provenance.

## Review checklist for each harness

Before accepting a proof result, verify:

1. the asserted property is the intended security claim;
2. every `vm.assume` is listed in the claims ledger;
3. the fixture does not construct away the adversarial input;
4. the accepting path has a paired validated reachability witness;
5. loop unrolling reaches the relevant iteration; and
6. the result report binds the current manifest and source.
