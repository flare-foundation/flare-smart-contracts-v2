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

The helper address is not stored by Relay and is not a Relay trust anchor. A correctly
signed governance transaction may target another compatible helper. The signed `to`
field remains part of the Safe digest, so a relayer cannot change the target after
signing.

### 2.3 Target Relay

Each target Relay verifies the Safe transaction and signatures independently. It applies
only fee entries whose `targetChainId` equals its current `block.chainid`.

Each target tracks its own highest accepted relevant governance nonce. Delivery and
progress are therefore independent across chains.

### 2.4 Relayer and execution evidence

The relayer is untrusted transport. It cannot modify any signed Safe transaction field,
action byte, or signature without invalidating authorization.

Relay verifies threshold authorization. It does not verify a Flare receipt or checker
event, and therefore cannot prove that the Safe transaction executed or succeeded on
Flare. A signed transaction that was never submitted, failed, or was superseded on the
Safe can still authorize Relay if its signatures and action are otherwise valid.

This is an intentional consequence of treating the signed message itself as governance
authorization. Requiring source execution would need a separate cross-chain execution
proof.

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
    governanceSourceChainId,
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
    "uint256 sourceChainId,address safe,uint256 threshold,address[] owners)"
);

bytes32 ownerConfigHash = keccak256(abi.encode(
    OWNER_CONFIG_TYPEHASH,
    sourceChainId,
    safe,
    threshold,
    owners
));
```

The type discriminator prevents the same Safe and owner tuple from being reused
accidentally as another application's configuration hash. The hash intentionally excludes:

- target chain ID;
- target Relay address;
- source helper address;
- Safe nonce.

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

## 7. Relay deployment and state

`IRelay.RelayInitialConfig` contains:

```solidity
uint256 governanceSourceChainId;
address governanceSafe;
uint256 governanceThreshold;
address[] governanceOwners;
uint256 governanceSafeNonce;
```

All-zero governance fields disable the GSS entry point. Any partial nonzero configuration
is rejected.

When GSS governance is enabled, construction requires:

```text
governanceSourceChainId != 0
governanceSafe != address(0)
signingPolicySetter == address(0)
oldRelay == address(0)
```

The constructor validates and stores the canonical owners and threshold, computes
`activeOwnerConfigHash`, and initializes `lastGovernanceSafeNonce`.

The target chain must not check `governanceSafe.code.length`. The configured Safe exists
on Flare, not necessarily at that address on the target chain.

Governance state is exposed through `IRelayGovernance`:

```solidity
uint256 public immutable governanceSourceChainId;
address public immutable governanceSafe;
bytes32 public activeOwnerConfigHash;
uint256 public lastGovernanceSafeNonce;
uint256 public governanceThreshold;

function governanceOwnersLength() external view returns (uint256);
function governanceOwner(uint256 index) external view returns (address);
```

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
    if (actionNonce <= lastGovernanceSafeNonce) {
        revert GovernanceNonceNotMonotonic(
            actionNonce,
            lastGovernanceSafeNonce
        );
    }

    bool relevant;
    if (selector == CHANGE_OWNERS_SELECTOR) {
        _applyGovernanceOwners(txData.data);
        relevant = true;
    } else if (selector == CHANGE_PROTOCOL_FEES_SELECTOR) {
        relevant = _applyGovernanceFees(txData.data);
    } else {
        revert UnknownGovernanceAction(selector);
    }

    if (relevant) {
        lastGovernanceSafeNonce = actionNonce;
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
| `GovernanceNonceNotMonotonic(uint256,uint256)` | a relevant action does not advance the target's accepted Safe nonce |

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
hash(proposed threshold, proposed owners) == hash(live Safe threshold, live Safe owners)
```

Bootstrap therefore attests the Safe's actual configuration.

### 9.2 Rotation staging

After bootstrap, `changeOwners` requires:

```text
currentOwnerConfigHash == checker.activeOwnerConfigHash
hash(live Safe threshold, live Safe owners) == checker.activeOwnerConfigHash
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
- no duplicate `(targetChainId, protocolId)` pair.

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

## 11. Fee semantics

For each signed fee action, a target Relay:

1. validates the canonical action and active owner hash;
2. selects entries where `targetChainId == block.chainid`;
3. rejects local protocol IDs zero and one;
4. rejects duplicate local protocol IDs;
5. validates every local entry before writing storage;
6. applies all local fees atomically.

An action containing no local entry succeeds as a no-op and does not advance
`lastGovernanceSafeNonce`. This prevents an unrelated high-nonce action from blocking an
older relevant action on that target.

Nonce gaps are allowed:

```text
relevantAction.safeNonce > lastGovernanceSafeNonce
```

Sequential delivery is not required.

## 12. Events

Target Relay emits:

```solidity
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

`test-forge/unit/governance/GSSGovernance.t.sol` deploys:

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
- irrelevant target no-op behavior;
- more signatures than the threshold;
- insufficient, duplicate, malformed, owner-count-exceeding, invalid-`v`, and high-`s`
  signatures, all normalized to the interface error;
- duplicate local fee rejection without partial state;
- target deployment without source Safe bytecode;
- relay-mode and `oldRelay == 0` deployment restrictions;
- owner rotation through old-owner staging, native Safe owner change, new-owner fee action,
  and target-local installation ordering.
- checker rejection of fee actions while a staged owner configuration is not yet live on
  the Safe, including rollback of the Safe nonce.

Positive governance actions use calldata that successfully executes through the real Safe
fixture. Negative Relay-only tests may use signed but deliberately non-executable calldata
to isolate target-side rejection.

The broader Forge and Hardhat suites remain regression gates for existing Relay behavior
and constructor callers.

## 14. Formal verification status

The existing Relay Halmos, Lean, and Kontrol inventory predates GSS governance. It covers
the protocol relay path and other recorded properties, but it does not prove:

- `processGSSMessage`;
- Safe digest reconstruction;
- GSS signature authorization;
- owner configuration transitions;
- target-specific fee updates;
- GSS nonce monotonicity.

The deleted legacy `governanceFeeSetup` nonce proof has been removed from the exact
verification manifest. The FV README explicitly excludes the GSS path from current proof
claims.

Before GSS governance is described as formally verified, dedicated checks must be added
for:

- checker bootstrap and rotation state machines;
- active/live owner hash agreement before fee actions;
- threshold distinct signer authorization;
- mutation of every signed Safe field;
- canonical action decoding;
- owner-update authorization by the old configuration;
- inability of a new configuration to install itself;
- relevant nonce monotonicity and irrelevant-action nonconsumption;
- local-only, atomic fee changes;
- helper-target independence;
- constructor mode restrictions.

Safe digest equivalence should remain a differential boundary against the pinned Safe
implementation, with the Relay state transitions proved around that boundary.

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
- exact FV manifest result;
- explicit statement that GSS formal properties are pending until implemented.

The deployed source-chain Safe proxy address, implementation address, source chain ID,
initial canonical owners, threshold, and initial accepted nonce must be recorded in the
deployment manifest.

## 16. Residual risks

1. No source execution proof. Threshold signatures remain valid for remote governance
   even if the Safe transaction never executes or is canceled on Flare.
2. EOA-only remote signatures. Safe contract owners, approved hashes, and `eth_sign`
   signatures are unsupported.
3. Owner rotation is staged. The checker intentionally pauses fee actions between staging
   `C_new` and making `C_new` live on the Safe.
4. Helper target is not an authorization domain. The action ABI and owner configuration
   hash carry the governance meaning; signer tooling must display them clearly.
5. GSS-specific formal verification is not yet implemented.
6. Fee values have no upper policy bound. Any `uint256` value, including zero, is valid if
   authorized.
7. The contract intentionally exposes two failure encodings. Integrations that aggregate
   `relay()` and GSS failures must decode both standard string reverts and custom errors.
