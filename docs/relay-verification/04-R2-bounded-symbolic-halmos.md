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
| Signature parsing and accounting | `RelaySigFV`, `RelaySigParamFV`, `RelayCanonicalityFV`, `RelayModelBridgeFV` |
| Ecrecover return ABI | `RelayEcrecoverABI`, `RelayEcrecoverSymbolicFV` |
| Policy/epoch selection | `RelayWrongEpochFV`, `RelayDelayedPolicyFV`, `RelayFinalizationWindowFV`, `RelayCrossEpochFV`, `RelayMustUseNewPolicyFV` |
| Policy rotation and thresholds | `RelayModeOneFV`, `RelayEpochAdvanceFV`, `RelayThresholdScalingFV`, `RelayThresholdConsistencyFV`, `RelayThresholdOverrideFV` |
| Randomness and Merkle binding | `RelayRandomBindingFV`, `RelayRandomMonotonicityFV`, `RelayIsSecureNormFV`, `RelayMerkleProofFV`, `RelayMerkleFoldFV` |
| Fees, fee-table replacement, delegation, and return values | `RelayVerifyFeeFV`, `RelayFeeConservationFV`, `RelayOldRelayFeeFV`, `RelayFeeTokenFV`, `RelayReturnDiscriminatorFV` |
| Initialization, access, owner/timelock/UUPS | `RelayConstructorFV`, `RelayAccessControlFV`, `RelayOwnerTimelockFV`, including duplicate-queue replacement and queue survival across ownership transfer |
| Policy digest encoding | `RelayPolicyHashFV`; message source-domain fixtures are supplementary Foundry tests |

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

The `oldRelay` value-flow harness bounds attached value to `uint128` and uses
compatible observable source fixtures. It proves how the current Relay calls
those fixtures; it does not establish the bytecode identity or proof integrity
of an arbitrary configured migration source.

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
