# GSS Governance for Relay

Status: implementation specification

This document describes the Gnosis Safe Smart contract (GSS) governance path implemented
by:

- `contracts/protocol/implementation/Relay.sol`
- `contracts/governance/GnosisSafeTx.sol`
- `contracts/governance/GSSGovernance.sol`
- `contracts/governance/GSSOwnerConfigurationChecker.sol`
- `contracts/userInterfaces/IRelayGovernance.sol`

The Solidity sources are authoritative. This document records their intended security
semantics, deployment assumptions, test boundary, and remaining verification work.

## 1. Scope

GSS governance is used by remote Relay deployments in relay mode:

```text
signingPolicySetter == address(0)
oldRelay == address(0)
```

The implemented governance actions are:

1. install a new admitted GSS owner configuration;
2. update protocol verification fees for one or more target chains.

The following are outside this path:

- legacy `governanceFeeSetup`;
- signing-policy quorum authorization of fee changes;
- migration of a relay-mode `oldRelay`;
- arbitrary Safe calls;
- oracle price updates;
- direct Safe owner management by Relay;
- proof on a target chain that a signed Safe transaction executed on Flare.

`Relay.relay()` remains the protocol-message and signing-policy finalization entry point.
It is not used to authorize GSS governance.

The term `fee` is intentional. These values are charged by `Relay.verify()` and are not
oracle prices.

## 2. Components and trust

### 2.1 GSS

The governance authority is a Safe v1.3.0 `GnosisSafeL2` proxy on Flare. The test fixture
uses the official Safe v1.3.0 source at commit:

```text
186a21a74b327f17fc41217a927dea7064f74604
```

The Relay pins the Safe v1.3.0 EIP-712 transaction hash, the Flare source chain ID, the
Safe proxy address, and an admitted owner configuration.

### 2.2 Source helper

`GSSOwnerConfigurationChecker` is an operational helper on Flare. A Safe transaction may
call it to validate nonce, owner configuration, and fee-action structure against live
Safe state.

`activeOwnerConfigurationIsLive()` reports whether the admitted generation currently
matches `Safe.getOwners()` and `Safe.getThreshold()`. Deployment tooling must require
`true`; `false` means bootstrap has not completed or an owner rotation is staged.

The helper address is not stored by Relay and is not a Relay trust anchor. A correctly
signed governance transaction may target another compatible helper. The signed `to`
field remains part of the Safe digest, so a relayer cannot change the target after
signing.

### 2.3 Target Relay

Each target Relay verifies the Safe transaction and signatures independently. It applies
only fee entries whose `targetChainId` equals its current `block.chainid`.

Each target tracks a fee high-water mark, an owner-generation nonce, and consumed
relevant Safe nonces. Delivery and progress are therefore independent across chains.

### 2.4 Relayer and execution evidence

The relayer is untrusted transport. It cannot modify any signed Safe transaction field,
action byte, or signature without invalidating authorization.

Relay verifies threshold authorization. It does not verify a Flare receipt or checker
event, and therefore cannot prove that the Safe transaction executed or succeeded on
Flare. A signed transaction that was never submitted, failed, or was superseded on the
Safe can still authorize Relay if its signatures and action are otherwise valid.

This is an intentional consequence of treating the signed message itself as governance
authorization. Requiring source execution would need a separate cross-chain execution
proof. The acceptance rationale, controls, and alternatives are recorded as
[DR-01](#162-accepted-design-risk-register).

## 3. Safe transaction envelope

The relayer supplies the complete Safe transaction:

```solidity
struct Transaction {
    address to;
    uint256 value;
    bytes data;
    uint8 operation;
    uint256 safeTxGas;
    uint256 baseGas;
    uint256 gasPrice;
    address gasToken;
    address refundReceiver;
    uint256 nonce;
}
```

The Safe v1.3.0 digest is:

```solidity
bytes32 constant DOMAIN_SEPARATOR_TYPEHASH = keccak256(
    "EIP712Domain(uint256 chainId,address verifyingContract)"
);

bytes32 constant SAFE_TX_TYPEHASH = keccak256(
    "SafeTx(address to,uint256 value,bytes data,uint8 operation,"
    "uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,"
    "address refundReceiver,uint256 nonce)"
);

bytes32 domain = keccak256(abi.encode(
    DOMAIN_SEPARATOR_TYPEHASH,
    sourceChainId,
    governanceSafe
));

bytes32 safeTxHash = keccak256(abi.encode(
    SAFE_TX_TYPEHASH,
    txData.to,
    txData.value,
    keccak256(txData.data),
    txData.operation,
    txData.safeTxGas,
    txData.baseGas,
    txData.gasPrice,
    txData.gasToken,
    txData.refundReceiver,
    txData.nonce
));

bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domain, safeTxHash));
```

Relay additionally requires:

```text
txData.operation == Call
txData.value == 0
```

The other envelope fields are not constrained by Relay policy, but every field is covered
by the signature digest.

Safe v1.3.0 increments its transaction nonce before calling the target. Governance action
calldata therefore carries the post-increment value:

```text
action.safeNonce == txData.nonce + 1
```

The `uint256.max` outer nonce is rejected to avoid overflow.

## 4. Signature profile

The admitted owner list contains addresses with weight one. Relay currently supports only
direct 65-byte EIP-712 ECDSA signatures:

```text
r (32 bytes) || s (32 bytes) || v (1 byte)
```

Relay requires:

- a whole, nonzero number of 65-byte signatures;
- at least `governanceThreshold` signatures;
- every supplied signature to recover successfully;
- low-`s` and valid-`v` ECDSA through OpenZeppelin `ECDSA`;
- every recovered signer to be an admitted owner;
- no more signatures than the admitted owner count;
- recovered owners in strictly increasing address order.

More signatures than the threshold are accepted, but Relay validates all of them. This is
stricter than Safe v1.3.0, which checks only the threshold prefix.

Relay uses OpenZeppelin's non-reverting `tryRecover` and maps every recovery error,
including high-`s` and invalid-`v`, to `InvalidGovernanceSignatures()`. Library-specific
ECDSA errors therefore do not leak through the governance interface.

The following Safe signature modes are not supported remotely:

- EIP-1271 contract-owner signatures;
- pre-approved hashes (`v == 1`);
- `eth_sign` signatures (`v > 30`).

Production tooling must therefore collect direct EIP-712 signatures from EOA owners. If a
configured Safe uses other owner or signature types, a separate remote-verification
design is required.

## 5. Owner configuration

Owners must be:

- nonempty;
- nonzero;
- unique;
- strictly increasing by address;
- no more than 256 entries.

The threshold must be nonzero and no greater than the owner count.

The owner configuration hash is shared by the checker, Relay, tests, and off-chain
tooling:

```solidity
bytes32 constant OWNER_CONFIG_TYPEHASH = keccak256(
    "FlareRelayOwnerConfiguration("
    "uint256 sourceChainId,address safe,uint256 safeNonce,"
    "uint256 threshold,address[] owners)"
);

bytes32 ownerConfigHash = keccak256(abi.encode(
    OWNER_CONFIG_TYPEHASH,
    sourceChainId,
    safe,
    ownerConfigSafeNonce,
    threshold,
    owners
));
```

The type discriminator prevents the same Safe and owner tuple from being reused
accidentally as another application's configuration hash. `ownerConfigSafeNonce` is the
post-increment Safe nonce of the `changeOwners` action that created this configuration.
For the same Safe, owners, and threshold, each later generation therefore has a distinct
hash. This prevents signatures queued under an earlier incarnation of an owner tuple from
becoming valid if the Safe later rotates back to that tuple.

The hash intentionally excludes:

- target chain ID;
- target Relay address;
- source helper address;

This lets one owner configuration and one signed action govern multiple target chains.

## 6. Governance action ABI

The exact `txData.data` bytes use one of these selectors:

```solidity
struct FeeUpdate {
    uint256 targetChainId;
    uint256 protocolId;
    uint256 feeInWei;
}

function changeOwners(
    uint256 safeNonce,
    bytes32 currentOwnerConfigHash,
    uint256 threshold,
    address[] calldata owners
) external;

function changeProtocolFees(
    uint256 safeNonce,
    bytes32 ownerConfigHash,
    FeeUpdate[] calldata updates
) external;
```

The selectors are:

```solidity
bytes4 constant CHANGE_OWNERS_SELECTOR =
    bytes4(keccak256("changeOwners(uint256,bytes32,uint256,address[])"));

bytes4 constant CHANGE_PROTOCOL_FEES_SELECTOR =
    bytes4(keccak256(
        "changeProtocolFees(uint256,bytes32,(uint256,uint256,uint256)[])"
    ));
```

Relay decodes an action and compares `keccak256(action)` with a canonical
`abi.encodeWithSelector(...)` reconstruction. This rejects:

- unknown selectors;
- malformed dynamic offsets;
- noncanonical encodings;
- truncated values;
- trailing bytes.

Fee updates must contain one to 256 entries and be strictly increasing by
`(targetChainId, protocolId)`. The canonical order eliminates duplicates,
gives the checker and every target the same action grammar, and keeps
validation linear in the batch size.

## 7. Relay deployment and state

`IRelay.RelayInitialConfig` contains:

```solidity
uint256 sourceChainId;   // RLY-23: shared with the signing path; the Safe's home network
address governanceSafe;
uint256 governanceThreshold;
address[] governanceOwners;
uint256 governanceOwnerConfigSafeNonce;
uint256 governanceSafeNonce;
```

`sourceChainId` is the single source-network id, unified with the RLY-23 signing binding (it was
formerly the governance-only `governanceSourceChainId`). It is always set (`0` ⇒ `block.chainid`), so it
no longer doubles as the GSS enable flag: **the GSS entry point is enabled iff any *governance* field
(`governanceSafe`, `governanceThreshold`, `governanceOwners`, either nonce) is nonzero**; all-zero
governance fields disable it, and any partial nonzero configuration is rejected.

When GSS governance is enabled, construction requires:

```text
governanceSafe != address(0)
signingPolicySetter == address(0)
oldRelay == address(0)
```

(Governance is thus mirror-only; `sourceChainId` names the Flare/Songbird network whose Safe and voter
consensus this mirror relays.)

The constructor validates and stores the canonical owners and threshold, computes
`activeOwnerConfigHash`, and initializes the nonce state. The two constructor nonces are
both Safe nonces, but they have different roles:

- `governanceOwnerConfigSafeNonce` identifies when the admitted owner generation was
  activated by `changeOwners`;
- `governanceSafeNonce` is the deployment replay floor. It should be sampled from
  `Safe.nonce()` immediately before deployment so every action signed for an already
  consumed Safe nonce is rejected.

Construction requires:

```text
governanceOwnerConfigSafeNonce <= governanceSafeNonce
```

This is not a second governance counter. Both values come from the same Safe nonce
sequence. They must be recorded separately because a Safe can execute many fee and
unrelated transactions without changing its owner generation.

The target chain must not check `governanceSafe.code.length`. The configured Safe exists
on Flare, not necessarily at that address on the target chain.

Governance state is exposed through `IRelayGovernance`:

```solidity
uint256 public immutable sourceChainId;
address public immutable governanceSafe;
bytes32 public activeOwnerConfigHash;
uint256 public activeOwnerConfigSafeNonce;
uint256 public lastGovernanceSafeNonce;
uint256 public immutable governanceReplayFloor;
uint256 public governanceThreshold;

function governanceSafeNonceConsumed(uint256 nonce) external view returns (bool);
function governanceOwnersLength() external view returns (uint256);
function governanceOwner(uint256 index) external view returns (address);
```

`lastGovernanceSafeNonce` is the target-local high-water mark for relevant fee
actions and never decreases. A delayed owner update may carry a lower nonce,
but installing it never lowers this fee floor. Owner updates are separately
ordered by `activeOwnerConfigSafeNonce`. A consumed Safe nonce remains consumed
globally, even across owner generations.

The constructor emits `GovernanceInitialized`, including the owner hash, generation
nonce, replay floor, threshold, and owner list. Deployment tooling should compare this
event against the source checker and deployment manifest before publishing the Relay.

## 8. Relay processing

The implemented state transition is equivalent to:

```solidity
function processGSSMessage(
    GnosisSafeTx.Transaction calldata txData,
    bytes calldata signatures
) external {
    if (
        governanceSafe == address(0) ||
        txData.operation != 0 ||
        txData.value != 0
    ) revert InvalidGovernanceTransaction();

    _verifyGovernanceSignatures(txData, signatures);

    bytes4 selector = _governanceSelector(txData.data);
    uint256 actionNonce = _governanceActionNonce(txData.data);
    if (
        txData.nonce == type(uint256).max ||
        actionNonce != txData.nonce + 1
    ) revert InvalidGovernanceTransaction();
    if (actionNonce <= governanceReplayFloor) {
        revert GovernanceNonceBeforeReplayFloor(
            actionNonce,
            governanceReplayFloor
        );
    }
    if (governanceSafeNonceConsumed[actionNonce]) {
        revert GovernanceNonceAlreadyConsumed(actionNonce);
    }

    if (selector == CHANGE_OWNERS_SELECTOR) {
        if (actionNonce <= activeOwnerConfigSafeNonce) {
            revert GovernanceOwnerConfigNonceNotIncreasing(
                actionNonce,
                activeOwnerConfigSafeNonce
            );
        }
        _applyGovernanceOwners(txData.data);
        governanceSafeNonceConsumed[actionNonce] = true;
        if (actionNonce > lastGovernanceSafeNonce) {
            lastGovernanceSafeNonce = actionNonce;
        }
    } else if (selector == CHANGE_PROTOCOL_FEES_SELECTOR) {
        if (actionNonce <= lastGovernanceSafeNonce) {
            revert GovernanceNonceNotMonotonic(
                actionNonce,
                lastGovernanceSafeNonce
            );
        }
        if (_applyGovernanceFees(txData.data)) {
            governanceSafeNonceConsumed[actionNonce] = true;
            lastGovernanceSafeNonce = actionNonce;
        }
    } else {
        revert UnknownGovernanceAction(selector);
    }
}
```

Checks and state changes occur in one EVM transaction. Any failure reverts all fee,
owner, event, and nonce changes.

Owner membership uses binary search over the canonical stored owner list.

### 8.1 Failure ABI

The GSS custom errors are declared by `IRelayGovernance` and inherited by
`Relay`. An integration built from the interface ABI alone can therefore decode
every intentionally defined GSS error:

| Error | Meaning |
|---|---|
| `InvalidGovernanceSource()` | source chain or Safe configuration is incomplete |
| `InvalidGovernanceDeployment()` | GSS was enabled outside an empty relay-mode deployment |
| `InvalidGovernanceOwnerConfiguration()` | owner ordering, count, addresses, or threshold are invalid |
| `InvalidGovernanceTransaction()` | the Safe envelope, action encoding, nonce relation, or action contents are invalid |
| `InvalidGovernanceSignatures()` | the signature encoding, count, ordering, recovery, or owner membership is invalid |
| `UnknownGovernanceAction(bytes4)` | the signed action selector is unsupported |
| `GovernanceOwnerHashMismatch(bytes32,bytes32)` | the action does not reference the currently admitted owner configuration |
| `GovernanceNonceNotMonotonic(uint256,uint256)` | a relevant fee action does not advance the target's global fee high-water mark |
| `GovernanceNonceBeforeReplayFloor(uint256,uint256)` | the action predates the target's deployment snapshot |
| `GovernanceNonceAlreadyConsumed(uint256)` | another relevant action already consumed this Safe nonce on the target |
| `GovernanceOwnerConfigNonceNotIncreasing(uint256,uint256)` | an owner update does not advance the owner-generation nonce |

This does not change the established failure ABI of `relay()`. Its assembly
paths continue to return standard `Error(string)` data, and the terminal
insufficient-weight failure remains a Solidity string revert. The split is
deliberate: GSS is a new typed interface, while changing `relay()` reasons would
break existing tests, formal checks, and potentially relayer diagnostics.

Callers that handle both entry points must inspect the first four revert-data
bytes and support standard `Error(string)`, `Panic(uint256)`, the GSS custom
selectors, and unknown raw revert data. In particular, severely malformed
dynamic action encoding may be rejected by Solidity's generated ABI decoder
before Relay reaches its canonical-reencoding check; that decoder failure is
not guaranteed to use `InvalidGovernanceTransaction()`.

## 9. Checker transitions

The checker is called only by the configured Safe and only on the configured source chain.
It requires:

```text
safeNonce == Safe.nonce()
safeNonce > latestSafeNonce
```

Because Safe increments before the target call, this is the same post-execution nonce used
by Relay actions.

### 9.1 Bootstrap

The checker begins with `activeOwnerConfigHash == 0`.

The first `changeOwners` action must supply:

```text
currentOwnerConfigHash == 0
hash(safeNonce, proposed threshold, proposed owners)
    == hash(safeNonce, live Safe threshold, live Safe owners)
```

Bootstrap therefore attests the Safe's actual configuration and establishes its first
configuration-generation nonce. New target Relays should normally be deployed after this
transaction and seeded from the checker's hash and generation nonce.

### 9.2 Rotation staging

After bootstrap, `changeOwners` requires:

```text
currentOwnerConfigHash == checker.activeOwnerConfigHash
hash(checker.activeOwnerConfigSafeNonce, live Safe threshold, live Safe owners)
    == checker.activeOwnerConfigHash
```

The currently live owners may then propose a different canonical owner configuration.
The checker stores the proposed hash as its new active configuration.

This staging order is necessary because target Relays must verify the owner-change action
with the old admitted owners. Requiring the proposed owners to already be live would make
an arbitrary rotation impossible unless old and new sets overlapped by at least the old
threshold.

### 9.3 Fee actions

`changeProtocolFees` requires both:

```text
ownerConfigHash == checker.activeOwnerConfigHash
hash(live Safe threshold, live Safe owners) == checker.activeOwnerConfigHash
```

After a new configuration is staged, fee actions therefore fail until the Safe itself has
adopted that configuration.

The checker validates the complete fee list:

- one to 256 updates;
- nonzero target chain ID;
- protocol ID greater than one;
- strict ascending `(targetChainId, protocolId)` order.

Zero fees are allowed and mean that verification for that protocol is free.

## 10. Owner rotation procedure

A complete rotation is:

1. The checker and all target Relays admit configuration `C_old`.
2. `C_old` owners execute `changeOwners(..., C_old, C_new)` through the Safe.
3. Every target Relay receives that exact signed transaction and installs `C_new`.
4. The Safe executes its native owner and threshold changes to become `C_new`.
5. During steps 2 through 4, the checker rejects fee actions because its active hash and
   the live Safe hash differ.
6. `C_new` owners execute the next fee action.
7. A target that missed step 3 rejects the new action until it first installs the owner
   update.

Safe owner-management transactions are not Relay governance messages and are not passed to
`processGSSMessage`.

Operators should finish owner-update delivery before signing a fee action under the new
configuration. A target may accept a later owner update with a nonce gap, but it cannot
accept a fee action whose owner hash is not locally active.

Under the current state machine, a staged checker rotation is one-way: while `C_new` is
admitted but the live Safe remains `C_old`, the checker rejects both fees and another
`changeOwners` restaging attempt. The Safe must first become exactly `C_new`. Before
staging, operators must therefore verify control of a `C_new` threshold, prepare and
simulate every native Safe owner-management transaction, confirm all targets are
reachable, and pause other governance delivery until the rotation completes.

A delayed owner update remains installable even if that target first received a
higher-nonce fee action signed by `C_old`. Installing the owner update does not
lower the fee high-water mark: the next relevant fee action under `C_new` must
still have a Safe nonce above every fee already applied on that target. The
globally consumed-nonce map prevents two relevant actions with the same Safe
nonce from both being applied.

## 11. Fee semantics

For each signed fee action, a target Relay:

1. validates the canonical action and active owner hash;
2. requires one to 256 entries in strict `(targetChainId, protocolId)` order;
3. rejects any zero target chain ID or protocol ID zero or one;
4. selects entries where `targetChainId == block.chainid`;
5. validates the complete list before writing storage;
6. applies all local fees atomically.

An action containing no local entry succeeds as a no-op and does not advance
the fee high-water mark and does not consume its Safe nonce. This prevents an
unrelated high-nonce action from blocking an older relevant action on that
target. An empty list is invalid rather than an irrelevant no-op.

Nonce gaps are allowed:

```text
relevantFeeAction.safeNonce > lastGovernanceSafeNonce
```

This is monotonic rather than sequential processing. Delivering a valid higher-nonce
relevant fee action first permanently suppresses lower-nonce fee actions on that target,
even when those actions were also validly signed. Signer and relayer procedures must
therefore treat signed fee actions as ordered target-local releases.

Sequential delivery is not required. Owner changes use their own strictly
increasing generation nonce and may be installed below the fee high-water mark
without lowering it, subject to the deployment replay floor and
one-action-per-Safe-nonce rule.

## 12. Events

Target Relay emits:

```solidity
event GovernanceInitialized(
    bytes32 indexed ownerConfigHash,
    uint256 ownerConfigSafeNonce,
    uint256 replayFloor,
    uint256 threshold,
    address[] owners
);

event GovernanceFeeUpdated(
    uint256 indexed targetChainId,
    uint256 indexed protocolId,
    uint256 feeInWei,
    uint256 safeNonce,
    bytes32 indexed ownerConfigHash
);

event GovernanceOwnerConfigUpdated(
    bytes32 indexed previousOwnerConfigHash,
    bytes32 indexed ownerConfigHash,
    uint256 safeNonce,
    uint256 threshold,
    address[] owners
);
```

The checker emits its owner transition and a compact fee-validation record. The original
Safe transaction remains the source of complete fee calldata.

## 13. Implemented tests

The exact GSS gate requires 36 tests across the unit, production-rehearsal, and
stateful-invariant suites. The 30-test
`test-forge/unit/governance/GSSGovernance.t.sol` suite deploys:

- the official Safe v1.3.0 `GnosisSafeL2` singleton;
- a `GnosisSafeProxy`;
- five EOA owners with threshold three;
- a Flare checker at simulated source chain ID 14;
- two Relay instances at distinct simulated target chain IDs.

The suite currently covers:

- exact three-of-five Safe setup and bootstrap attestation;
- differential Safe digest comparison using every transaction field;
- successful Safe execution and identical calldata delivery to two targets;
- chain-specific fee extraction;
- helper-target independence and post-signature `to` tampering;
- replay and modified-action rejection;
- action/Safe nonce consistency;
- nonce gaps;
- explicit higher-nonce-first suppression of a lower signed fee action;
- explicit exhaustion of the fee nonce sequence by a threshold-signed
  `uint256.max` future nonce that was never executed on the source Safe;
- irrelevant target no-op behavior;
- deployment replay-floor rejection;
- replay of one successful signed message into two Relay deployments on the same target
  chain when no fresh-generation cutover is used;
- conflicting threshold-signed transactions at one Safe nonce, including target-local
  first-delivery divergence and one-action-per-nonce enforcement;
- more signatures than the threshold;
- insufficient, duplicate, malformed, owner-count-exceeding, invalid-`v`, and high-`s`
  signatures, all normalized to the interface error;
- duplicate local fee rejection without partial state;
- empty, oversized, and noncanonically ordered fee-list rejection by the target,
  with checker/target agreement for the ordering case;
- successful execution of the maximum 256-entry canonical fee batch;
- target deployment without source Safe bytecode;
- relay-mode and `oldRelay == 0` deployment restrictions;
- owner rotation through old-owner staging, native Safe owner change, new-owner fee action,
  and target-local installation ordering;
- delayed owner rotation after a higher old-generation fee action, while
  rejecting a lower-nonce fee under the new generation;
- rotation away from and back to the same owners without reviving an old future-nonce
  message;
- constructor rejection when the owner-generation nonce exceeds the deployment replay
  floor;
- explicit demonstration that consuming a Safe nonce with a cancellation transaction
  does not revoke the separately signed remote authorization;
- explicit demonstration that a removed Safe owner remains authorized by a lagging target
  until that target installs the signed owner rotation;
- checker rejection of fee actions while a staged owner configuration is not yet live on
  the Safe, including rollback of the Safe nonce, rejection of a second restaging attempt,
  and live-state-view transitions before, during, and after rotation.

`GSSGovernanceProductionRehearsal.t.sol` adds three production-shape tests. They
deploy the exact `@gnosis.pm/safe-contracts@1.3.0` release artifact bytecode,
reproduce the fixed-block Flare Safe shape (11 EOA owners, threshold 6, no
modules, zero guard, and the recorded fallback handler), execute fee/rotation/fee
calldata through that Safe, deliver the successful calldata to two target Relays,
and execute a 256-entry fee batch. The recorded worst-case test cost is 7,508,970
gas against the snapshot's 28,000,000 block gas limit.

`GSSGovernanceInvariant.t.sol` adds a model-based state machine over two target
Relays. The exact gate requires 128 runs at depth 128 (16,384 handler calls) with
zero handler reverts, plus deterministic delayed-rotation and same-nonce-conflict
sequences. It compares both contracts against an independent model after every
randomized delivery, mutation, rotation, fee, and conflict action.

End-to-end happy paths use calldata that successfully executes through the real Safe
fixture. Adversarial ordering and negative Relay-only tests also use correctly signed
future or canceled Safe transactions that are deliberately non-executable in that order.
This isolates the target-side authorization model described in section 2.4.

The broader Forge and Hardhat suites remain regression gates for existing Relay behavior
and constructor callers.

## 14. Formal verification status

GSS governance now has a dedicated Halmos harness in
`test-forge/fv/GSSGovernanceFV.t.sol`. The exact manifest contains 13 GSS proofs
and 2 validated reachability controls, bringing the full Halmos gate to 101
checks (72 proofs and 30 controls). The harness executes production Relay
bytecode through two deliberately exposed internal boundaries and proves:

- distinct, ordered, admitted-owner threshold validation after signer recovery;
- rejection below threshold and of duplicate, unordered, or non-owner signers;
- Safe/action nonce equality at the verified-action boundary;
- generation-bound owner transitions authorized by the current configuration;
- consumed-nonce exclusion for conflicting same-nonce actions;
- canonical and atomic local fee application;
- irrelevant-target nonconsumption;
- global fee high-water monotonicity across delayed owner rotations.

This is a bounded, post-recovery state-machine proof. It does **not** prove ECDSA
unforgeability, symbolically derive recovered signers from arbitrary Safe
signatures, or prove the full Safe EIP-712 digest implementation. Those boundaries
are covered concretely and differentially against the real v1.3.0 Safe: two
256-run fuzz tests bind every Safe transaction field, and the production rehearsal
uses calldata that actually succeeds through the exact release artifacts.

Four parametric GSS storage invariants are specified in
`certora/specs/RelayInvariants.spec` (global high-water monotonicity,
owner-generation monotonicity, owner-hash/generation coupling, and consumed-nonce
permanence). The fail-closed local gate compiles and typechecks both current
Certora configurations with CLI 8.16.1, Java 21, and solc 0.8.27. This is front-end
evidence only: the current GSS source still requires a Certora cloud proof run
before any parametric all-functions result is claimed.

Kontrol and Lean continue to prove properties of the signing-policy `relay()`
core and do not cover GSS governance. The deleted legacy `governanceFeeSetup`
proof remains absent from the exact manifest; no legacy result is relabeled as a
GSS result.

## 15. Reproducibility

The Safe fixture dependency is locked as `@gnosis.pm/safe-contracts@1.3.0` in
`package.json` and `yarn.lock`. Its Solidity `contracts/` tree was compared byte-for-byte
with the v1.3.0 commit above. A release or merge request should record:

- Safe source revision;
- Solidity and Foundry versions;
- full Forge result;
- Hardhat compile and Relay unit result;
- passing legacy `relay()` revert-ABI report;
- updated optimized-Yul snapshot for the current Relay source;
- exact 36-test GSS gate and 102-check Halmos result;
- fixed-block source-Safe snapshot report, refreshed immediately before a
  production ceremony;
- local Certora compilation/typecheck report and the separate cloud-proof status;
- a clean-tree eight-report verification bundle. `--allow-dirty` is a development
  convenience and is explicitly not release eligible.

The deployed source-chain Safe proxy address, implementation address, source chain ID,
initial canonical owners, threshold, checker `activeOwnerConfigSafeNonce`, checker
`activeOwnerConfigHash`, and target deployment replay floor must be recorded in the
deployment manifest.

### 15.1 Deployment and migration timing

The safe sequence for a new target Relay is:

1. pause governance signing and inventory every outstanding signed Safe transaction;
2. bootstrap the source checker, or execute a same-owner `changeOwners` action to
   create a fresh owner generation and invalidate messages referring to the prior hash;
3. deliver that generation update to every already deployed target;
4. require `checker.activeOwnerConfigurationIsLive() == true`, independently recompute
   the live Safe hash, and record the checker's active owner hash and generation nonce;
5. immediately before target deployment, read `Safe.nonce()` as the replay floor;
6. require `ownerConfigSafeNonce <= replayFloor`;
7. deploy the target with the canonical owners, threshold, both nonce values, source
   chain ID, and Safe address;
8. compare the constructor's `GovernanceInitialized` event and public getters with the
   signed deployment manifest;
9. only then publish the Relay address to relayers and resume signing.

The replay floor rejects already consumed Safe nonces; it cannot detect a
future-nonce transaction signed before deployment. The signing pause plus fresh
owner-generation hash is therefore the migration boundary for outstanding
messages. If this operational guarantee is unacceptable, the protocol needs a
source execution proof or a signed target-deployment epoch.

For the separate pre-RLY-23 signing-policy migration, the deployment task now requires an
explicit old hash scheme:

```text
--old-relay-policy-hash-scheme legacy
--old-relay-policy-hash-scheme chain-bound
```

`legacy` wraps the old Relay's nonzero content hash exactly once with the target chain ID.
`chain-bound` passes an already wrapped hash through. Zero hashes, malformed hashes, and
unknown schemes fail before deployment. There is intentionally no automatic guess:
both legacy and chain-bound values are indistinguishable nonzero `bytes32` values.
The currently deployed main-branch Relay and its exact `RelayMainDeployed` test mock are
pre-RLY-23, so that migration must use `legacy`; `chain-bound` is only for a source Relay
whose deployment provenance confirms that it already stores the wrapped form.

## 16. Accepted design risks and alternatives

The items in this section are not unidentified defects. They are known consequences of
the current governance model and are accepted for this design under the conditions below.
"Accepted" does not mean impossible or harmless: it means that the remaining exposure is
inside the authority already granted to the Safe owner threshold, is required by
independent asynchronous targets, or is controlled by a documented deployment and
signing procedure.

### 16.1 Risk-acceptance model

The acceptance decision relies on four explicit principles:

1. A threshold-signed Safe EIP-712 transaction is itself remote authorization. Canonical
   execution by the Safe on Flare is not part of Relay's on-chain acceptance predicate.
2. Each target chain progresses independently. Temporary differences in owner generation,
   fee state, and delivered Safe nonces are expected during asynchronous delivery.
3. The Safe owner threshold is trusted for both integrity and liveness. A threshold that
   signs contradictory, destructive, or extreme values can already exercise governance;
   Relay prevents unprivileged mutation, not governance self-harm.
4. The production governance profile uses direct EIP-712 signatures from EOA owners. Other
   Safe signature modes are outside the admitted protocol.

The required policy for official relayers is to submit only transactions with a confirmed
Safe `ExecutionSuccess` on Flare. This is defense in depth and an audit trail, not a
security boundary: `processGSSMessage` is permissionless, so any party can submit a valid
signed transaction. Security therefore rests on the threshold-signature authorization
model, not on relayer filtering.

The design-risk acceptance must be revisited if canonical Flare execution becomes a
requirement, contract owners or Safe signature modes are introduced, targets can no
longer tolerate asynchronous governance, a replacement Relay may coexist on one chain,
or operational controls cannot enforce the signing and rotation procedures below.

### 16.2 Accepted design-risk register

| ID | Current design choice and accepted exposure | Why acceptable now / required controls | Options if stronger guarantees are required |
|---|---|---|---|
| **DR-01: authorization without source execution** | A signed transaction remains remotely valid if it is never executed, fails, or is canceled on Flare. There is no signed expiry or remote revocation. | The owner threshold, rather than source-chain execution, is the remote authority. Owners must sign only final governance actions; the official-relayer policy additionally requires confirmed `ExecutionSuccess`. | Prove a finalized Safe success event through a Flare light client or trusted bridge; add a source execution-attestation oracle as a new explicit trust root; or add signed expiry, revocation epoch, and action-cancellation fields. Expiry/revocation narrows exposure but does not by itself prove canonical execution. |
| **DR-02: EOA-only signatures** | EIP-1271 contract owners, Safe approved hashes, and `eth_sign` signatures cannot authorize a target Relay. | The fixed-block production Safe snapshot has EOA owners, and direct EIP-712 signing gives a small, deterministic parser. The snapshot must be refreshed and deployment must reject an incompatible owner profile. | Implement the complete Safe signature grammar. EIP-1271 and approved-hash support also need authenticated source-chain contract/storage state, normally through a source proof or an intentionally replicated verifier. A separate EOA-only satellite governance Safe is the simpler alternative. |
| **DR-03: staged owner rotation** | The checker and official source-execution flow pause fee actions while `C_new` is proposed but the Safe still exposes `C_old`. Relay cannot enforce that pause and continues to recognize its installed generation. The checker proposal cannot currently be canceled or superseded, so an unusable proposal can stall the helper flow and split targets. | The checker pause prevents official fee executions against an ambiguous owner generation; the threshold-signature trust model covers remote submission. The ceremony preflights native Safe changes, proves the new threshold's key availability, and completes within a maintenance window. | Allow the live old configuration to cancel or replace a proposal; add timeout-and-rollback; admit old and new generations during a bounded overlap; require an old-threshold plus new-threshold transition; or enforce checker success through source execution proof. These choices add recovery but enlarge state-machine and replay complexity. |
| **DR-04: helper target is not an authorization domain** | Relay does not store or require one checker address. Any compatible helper target can carry the same recognized action calldata. | The helper is a signing-time safety tool, not a Relay trust anchor. Every Safe envelope field is signed, and Relay independently validates the action, owner generation, and signatures. Signing tools must decode the action rather than infer meaning from `to`. | Bind an expected checker address and code/version hash in Relay; include a helper-domain identifier in every action; or enforce approved target/selector combinations with a Safe guard. These reduce helper flexibility and require coordinated upgrades. |
| **DR-05: asynchronous owner revocation** | Removing an owner from the source Safe does not revoke the old generation on a lagging target. That target remains able to accept an old-generation threshold signature. | Independent chains cannot be assumed available simultaneously. The runbook installs and confirms the new Relay generation everywhere before changing native Safe owners; an unavailable target is explicitly treated as governed by the old set. | Deliver finalized owner updates through an authenticated bridge; give owner generations signed expiry times; require periodic source checkpoints; or suspend consumers on a target that misses the cutover. Immediate revocation requires authenticated source state. |
| **DR-06: same-nonce conflicts are first-delivery-wins** | If the threshold signs two different relevant actions at one Safe nonce, each target independently accepts the first one delivered and rejects the other. Different targets can select different winners. | This requires threshold equivocation or signing-process failure, not an unprivileged attacker. Consumed-nonce storage prevents double application on one target. Signing infrastructure must provide one canonical payload per Safe nonce. | Prove which transaction executed on Flare; publish the canonical nonce-to-digest mapping through a bridge; use a governance proposal registry before signing; or require owners and signing infrastructure to reject a second digest for an allocated nonce. |
| **DR-07: gap-tolerant fee ordering** | A higher-nonce fee action delivered first suppresses every lower-nonce fee action on that target, including an update for another protocol. | Non-sequential processing lets an unavailable target catch up without replaying every Safe transaction. Governance tooling must serialize intended updates or explicitly mark skipped lower actions as abandoned. | Enforce sequential fee nonces; keep a per-protocol high-water mark; attach an independent per-entry version; or relay canonical source execution logs. Per-protocol state preserves more out-of-order updates at additional storage and message complexity. |
| **DR-08: future-nonce and terminal-nonce authority** | The threshold may sign a future Safe nonce. An accepted fee action with action nonce `uint256.max` makes the global fee high-water mark terminal and permanently blocks later fee actions. | This is governance self-harm requiring the admitted threshold, not a threshold bypass. Gap tolerance is deliberate, and the regression suite makes the terminal behavior visible. Signing policy must reject implausible future nonces and `uint256.max`. | Reject the terminal value on-chain; impose a bounded forward gap; use a bounded independent governance sequence; add a generation-authorized recovery action; or require a source execution proof. A forward-gap bound reduces independent catch-up flexibility. |
| **DR-09: replay floor cannot reject pre-signed future actions** | Deployment rejects past Safe nonces but cannot detect a future-nonce transaction signed before deployment. | Migration pauses signing and creates a fresh same-owner generation before publishing the target, invalidating actions tied to the previous generation. | Sign a target deployment epoch or activation commitment; bind each action to a deployment identifier; cap accepted nonces relative to a proved source checkpoint; or require source execution evidence. |
| **DR-10: actions are not bound to a Relay deployment** | Two Relay contracts on the same target chain can accept the same action when their owner generation and replay floor match. | The design binds target-specific fee entries to chain ID and assumes one authoritative Relay per chain. Replacement uses a fresh owner generation, and consumer registries stop trusting the old address before the new one is published. | Include `targetRelay` and a deployment ID in each fee entry while retaining a multi-target list; maintain a signed source registry of authoritative deployments; or incorporate the target address into a per-target action digest. |
| **DR-11: fee values are policy-unbounded** | Governance may set any `uint256` fee, including zero or a value that makes normal use uneconomic. | Fee selection is a governance-policy decision, and the threshold already has authority to change it. Off-chain proposal validation and human-readable signing review enforce economic policy. | Add per-protocol min/max bounds; rate-limit changes; use a timelocked two-step fee update; or make bounds themselves governance-controlled with stricter delay and review rules. |
| **DR-12: maximum batch is not universally executable** | The protocol permits 256 fee entries, but a target with a lower gas limit may not fit the measured 7,508,970-gas production-shape transaction. | The cap bounds parsing work; deployment qualification chooses a lower operational batch size per target and preserves gas margin. | Lower the protocol-wide cap; sign several independently versioned batches; add per-target batch caps; or compress/aggregate fee entries. Chunking must preserve ordering and atomicity expectations. |
| **DR-13: Safe modules can alter checker state** | A module can make the Safe call the checker outside the normal owner `execTransaction` path and can make helper state misleading. | Checker state does not authorize Relay. A target still requires a valid owner-threshold signature over the complete transaction. Production snapshots and ceremonies review modules and guards. | Require a module-free Safe; use a Safe guard that restricts checker selectors and targets; monitor module/guard changes; or make checker attestations depend on a finalized Safe execution proof rather than caller identity alone. |
| **DR-14: mixed revert encodings** | Legacy `relay()` assembly uses short revert strings while GSS Solidity uses custom errors. Integrations need two decoders. | This preserves the established assembly ABI while giving the new path typed errors. It does not change authorization or state safety. | Normalize errors in a future breaking release; wrap Relay behind an adapter that maps both formats; or publish a shared decoder generated from the ABI and the registered legacy string inventory. |

### 16.3 Verification limitations are not protocol acceptance

The GSS Halmos proofs are bounded and begin after signer recovery; real-Safe differential
tests cover digest and ECDSA integration, while Lean and Kontrol cover the signing-policy
relay core rather than GSS. These are evidence-scope limitations, not protocol design
choices. They must stay explicit in every security claim. The current Certora rules pass
the local compile/typecheck gate, but the cloud verdict is still a release-evidence item,
not something made safe by the design-risk acceptance above.

Options for stronger assurance are the current Certora cloud run, a symbolic proof of the
complete Safe digest and signature parser, an end-to-end refinement from
`processGSSMessage` calldata to state changes, and a separate proof system for finalized
source-Safe execution. None should be described as already established by the present
bounded GSS proof set.

## 17. Alternative security and robustness review

The 2026-07-25 adversarial review re-derived the protocol from relayer ordering,
configuration reincarnation, source cancellation, and production migration rather than
from the existing test inventory.

| ID | Severity | Result |
|---|---|---|
| GSS-A1 | High liveness / medium integrity | **Fixed.** Owner hashes lacked a generation nonce. A higher old-config fee could strand a pending rotation, and rotating back to the same tuple could revive old future-nonce signatures. Owner hashes now include their activation Safe nonce; owner generations advance independently without lowering the global fee floor, and all relevant actions consume their Safe nonce globally. |
| GSS-A2 | Medium integrity | **Fixed.** Resetting a per-generation fee watermark after a delayed rotation allowed a newly admitted configuration to apply a fee action below a fee nonce already accepted by that target. Relevant fees now advance one global high-water mark across owner rotations; the adversarial sequence is tested. |
| GSS-A3 | Medium robustness | **Fixed.** Relay accepted empty lists, validated only local entries, and used quadratic duplicate scans while the checker validated the full message. Both now require the same nonempty, strictly ordered, at-most-256-entry grammar in linear time; the maximum batch executes in the real-Safe test. |
| MIG-A1 | High liveness | **Fixed.** `redeploy-relay.ts` and the non-initial `redeploy-contracts.ts` path documented legacy policy-hash wrapping but passed the bare hash. Deployment now requires an explicit old hash scheme and tests wrap-once/passthrough/fail-closed behavior. |
| TIM-A1 | Medium operational | **Accepted design choice (DR-01).** Safe cancellation, failure, or non-execution does not revoke a copied threshold-signed message because the threshold signature itself is remote authority. The test suite demonstrates this behavior explicitly. |
| TIM-A2 | Medium operational | **Accepted design choice (DR-06).** Two signed actions at one Safe nonce are first-delivery-wins per target. Threshold non-equivocation is required; the consumed-nonce map prevents double application, while source execution proof would identify the canonical winner. |
| TIM-A3 | Medium operational | **Accepted design choice (DR-05).** Native Safe owner removal does not revoke that owner on a lagging target. The rotation runbook delivers and confirms the Relay owner update before the Safe mutation, and a real-Safe test demonstrates both the exposed and protected target states. |
| TIM-A4 | Medium migration | **Accepted with migration controls (DR-09).** The deployment replay floor rejects past, not already-signed future, Safe nonces. The migration runbook pauses signing and creates a fresh same-owner generation; stronger enforcement needs source execution proof or a signed deployment epoch. |
| MIG-A2 | Medium operational | **Fixed/documented.** Owner-generation nonce and deployment replay floor are now distinct Safe-derived inputs, validated on-chain and emitted at construction. |
| OPS-A1 | Low helper integrity | **Accepted design choice (DR-13).** Safe modules can alter checker state, but cannot bypass Relay signature verification. Deployment review must include Safe modules and guards. |
| TIM-A5 | Medium operational | **Accepted design choice (DR-07).** Monotonic fee processing lets a higher-nonce valid action delivered first suppress lower-nonce signed fee actions on that target. Release tooling must serialize delivery or explicitly abandon the skipped actions. |
| MIG-A3 | Medium migration | **Accepted with replacement controls (DR-10).** Signatures are target-chain scoped through fee entries, but are not bound to one Relay address. Replacement uses a fresh owner generation and replay floor, and consumers must stop trusting the deprecated address. |
| TIM-A6 | High liveness | **Accepted with ceremony controls (DR-03).** A staged owner rotation cannot be restaged until the Safe becomes the proposed configuration. The checker exposes an exact live/admitted-state view; deployment requires it to be true, and the rotation ceremony proves new-owner key availability and preflights the native Safe mutation. Full recovery needs a two-phase or dual-generation protocol. |
| TIM-A7 | High liveness / governance trust | **Accepted governance-authority risk (DR-08).** A threshold-signed extreme future nonce, including `uint256.max`, can exhaust a target's fee sequence without source execution. The test suite demonstrates this. Official-relayer policy must reject it as defense in depth; on-chain prevention needs a nonce bound, recovery action, or source execution proof. |

No unprivileged path was found that bypasses the configured owner threshold, changes a
signed transaction field, applies a nonlocal fee entry, or mutates fees partially on
failure. The dominant remaining security boundary is intentional: Relay proves owner
authorization, not canonical source-chain execution.
