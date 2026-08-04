# Safe Governance for Relay

Status: implementation specification

This document describes the Safe governance path — governance authorized by a Safe
(formerly Gnosis Safe) multisig on Flare — implemented by:

- `contracts/governance/implementation/SafeGoverned.sol` — the reusable abstract base any
  governed contract inherits (digest + signature verification, owner mirror, replay rules,
  generic owner rotation, one app-action hook)
- `contracts/protocol/implementation/Relay.sol` — the first `SafeGoverned` consumer
  (+ `RelayProxy.sol`, UUPS; the fee/exemption action bodies are inlined — the typed-error
  conversion freed enough bytecode to stay under the EIP-170 size limit in one contract)
- `contracts/governance/lib/SafeGovernance.sol` — the shared action grammar (hashes,
  selectors, limits, validators)
- `contracts/governance/implementation/SafeInstructions.sol` — the source-chain instruction
  contract (+ `SafeInstructionsProxy.sol`, UUPS)
- `contracts/utils/implementation/Create3Factory.sol` — chain-invariant proxy addresses
- `contracts/userInterfaces/ISafeGovernance.sol`, `contracts/userInterfaces/IRelayGovernance.sol`

The Solidity sources are authoritative. This document records their intended security
semantics, deployment assumptions, test boundary, and remaining verification work.

## 1. Scope

Safe governance is carried by EVERY Relay deployment: relay-mode mirrors, the
source-chain (signing-policy-setter) deployment on Flare, and old-relay migration
redeployments alike — the same governed artifact ships to every chain, and the old-relay
handshake (a Flare-only concern) is orthogonal to governance.

The implemented governance actions are:

1. install a new admitted Safe owner configuration;
2. update protocol verification fees for one or more addressed deployments
   (never applied on setter-mode deployments, which do not charge fees);
3. grant/revoke verify() fee exemptions (e.g. DVN adapters) per addressed deployment —
   applied on ALL deployment modes, including the Flare setter-mode Relay;
4. update the fee-collection address (where collected verify() fees are sent) per
   addressed deployment — like fee updates, never applied on setter-mode deployments.

Every fee-family entry is addressed to one deployment by the
`(targetChainId, targetAddress)` pair, so several contracts on one chain are governed
independently and an entry can never apply anywhere its signers did not spell out.

The following are outside this path:

- legacy `governanceFeeSetup`;
- signing-policy quorum authorization of fee changes;
- arbitrary Safe calls;
- oracle price updates;
- direct Safe owner management by Relay;
- proof on a target chain that a signed Safe transaction executed on Flare.

`Relay.relay()` remains the protocol-message and signing-policy finalization entry point.
It is not used to authorize Safe governance.

The term `fee` is intentional. These values are charged by `Relay.verify()` and are not
oracle prices.

## 2. Components and trust

### 2.1 Safe

The governance authority is a Safe v1.3.0 `GnosisSafeL2` proxy on Flare. The test fixture
uses the official Safe v1.3.0 source at commit:

```text
186a21a74b327f17fc41217a927dea7064f74604
```

The Relay pins the Safe v1.3.0 EIP-712 transaction hash, the Flare source chain ID, the
Safe proxy address, and an admitted owner configuration.

### 2.2 Source instruction contract

`SafeInstructions` is the operational contract on Flare that Safe instructions are created
against. A Safe transaction calls it to validate nonce, owner configuration, and fee-action
structure against live Safe state. It is UUPS-upgradeable under Flare governance
(`FlareUpgradeableBase` house pattern): supporting a new instruction type for a future
`SafeGoverned` consumer means upgrading it with the matching validation method — target-chain
consumers never call or depend on it.

Its `initialize` admits the Safe's LIVE owner configuration (`Safe.getOwners()` /
`Safe.getThreshold()`, canonically sorted and validated) as **generation 0** — the
deployment generation — and samples the source chain id from `block.chainid`. There is no
bootstrap ceremony: instructions are issuable immediately after deployment, and the live
Safe read makes a wrong-network deployment revert at initialization (the Safe only has
code on the source chain).

`activeOwnerConfigurationIsLive()` reports whether the admitted generation currently
matches `Safe.getOwners()` and `Safe.getThreshold()`. Deployment tooling must require
`true`; `false` means the Safe has rotated natively and the rotation attestation is still
pending.

The instruction contract's address is not stored by Relay and is not a Relay trust anchor.
A correctly signed governance transaction may target another compatible helper. The signed
`to` field remains part of the Safe digest, so a relayer cannot change the target after
signing.

### 2.3 Target Relay

Each target Relay verifies the Safe transaction and signatures independently. It applies
only fee entries whose `targetChainId` equals its current `block.chainid`.

Each target tracks a fee high-water mark, an owner-generation nonce, and consumed
relevant Safe nonces. Delivery and progress are therefore independent across chains.

### 2.4 Relayer and execution evidence

The relayer is untrusted transport. It cannot modify any signed Safe transaction field,
action byte, or signature without invalidating authorization.

Relay verifies threshold authorization. It does not verify a Flare receipt or instruction contract
event, and therefore cannot prove that the Safe transaction executed or succeeded on
Flare. A signed transaction that was never submitted, failed, or was superseded on the
Safe can still authorize Relay if its signatures and action are otherwise valid.

This is an intentional consequence of treating the signed message itself as governance
authorization. Requiring source execution would need a separate cross-chain execution
proof. The acceptance rationale, controls, and alternatives are recorded as
[DR-01](#162-accepted-design-risk-register).

### 2.5 The `SafeGoverned` base and consumer contracts

All generic mechanics live in ONE abstract contract, `SafeGoverned`
(`contracts/governance/implementation/SafeGoverned.sol`): Safe v1.3.0 digest reconstruction,
signature verification, the admitted owner mirror + threshold, replay protection, and the
generic `changeOwners` rotation. State is held in ERC-7201 namespaced storage
(`erc7201:flare.SafeGoverned.State`), so a consumer's own storage layout is never disturbed.

A consumer contract (today: Relay) simply inherits `SafeGoverned`, calls
`initializeSafeGoverned(config)` from its initializer (governance is mandatory — the full
configuration is validated; a consumer shipping without Safe simply never calls it), and
overrides one virtual hook:

```solidity
function _processGovernanceAction(bytes4 selector, bytes calldata action)
    internal virtual returns (bool relevant);
```

The hook is called for every VERIFIED action whose selector is not the generic
`changeOwners`; returning `false` means "nothing applied locally" and leaves the action
nonce unconsumed. Unknown selectors must revert `UnknownGovernanceAction(selector)`.
Every action binds `(safeNonce, activeOwnerConfigHash)` in its first two words — the base
enforces the binding before dispatching, so a hook can never forget it.

Adding a NEW governed contract therefore takes: a new `SafeGoverned` child with its own
action selector(s) and hook, plus a `SafeInstructions` upgrade that validates the new
instruction type at creation time. Scoping is a per-action-payload convention: global
(`changeOwners`) or per-deployment — the fee-family actions bind every entry to a
`(targetChainId, targetAddress)` pair checked against `(block.chainid, address(this))`.

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

Governance action calldata carries the SIGNED Safe nonce — the same value the owners see
in the transaction envelope when signing:

```text
action.safeNonce == txData.nonce
```

(Safe v1.3.0 increments its nonce before calling the target, so during source-chain
execution the live `Safe.nonce()` reads the signed value plus one; the source instruction
contract accounts for that with a `- 1`.)

## 4. Signature profile

The admitted owner list contains addresses with weight one. The `SafeGoverned` base accepts
65-byte chunks:

```text
r (32 bytes) || s (32 bytes) || v (1 byte)
```

Two ECDSA flavours are supported — exactly the EOA modes Safe v1.3.0 `checkNSignatures`
accepts:

- **direct EIP-712** (`v == 27/28`): recovered over the Safe transaction digest;
- **eth_sign** (`v == 31/32`): recovered over the EIP-191-prefixed digest with `v - 4`
  (the fallback wallets produce when they cannot sign typed data).

Verification requires:

- a whole, nonzero number of 65-byte signatures (`InvalidSignaturesLength`);
- `v == 0` (EIP-1271) and `v == 1` (pre-approved hash) revert
  `UnsupportedSignatureType(v)` — they are not verifiable cross-chain;
- low-`s` and valid-`v` ECDSA through OpenZeppelin `ECDSA.recover` (its typed errors,
  e.g. `ECDSAInvalidSignatureS`, surface directly);
- recovered signers in strictly increasing address order (`SignersNotSorted`, which also
  rejects duplicates);
- EVERY recovered signer to be an admitted owner (`UnknownSigner(signer)`) — stricter than
  Safe v1.3.0, which checks only the threshold prefix; relayers must strip non-owner,
  `v == 0` and `v == 1` chunks and canonicalize high-`s` values before submitting;
- at least `governanceThreshold` signatures (`ThresholdNotReached`).

More signatures than the threshold are accepted and all are validated. An explicit
signature-count cap is unnecessary: strict ordering (no duplicates) plus strict owner
membership bound the count by the owner-set size.

EIP-1271 contract-owner signatures remain unsupported remotely. If a configured Safe
relies on contract owners for its threshold, a separate remote-verification design is
required.

## 5. Owner configuration

Owners must be:

- nonempty;
- nonzero;
- unique;
- strictly increasing by address;
- no more than 256 entries.

The threshold must be nonzero and no greater than the owner count.

The owner configuration hash is shared by the instruction contract, Relay, tests, and off-chain
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
    address targetAddress;
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

struct FeeExemption {
    uint256 targetChainId;
    address targetAddress;
    address account;
    bool exempt;
}

function changeFeeExemptions(
    uint256 safeNonce,
    bytes32 ownerConfigHash,
    FeeExemption[] calldata updates
) external;

struct FeeCollection {
    uint256 targetChainId;
    address targetAddress;
    address feeCollectionAddress;
}

function changeFeeCollectionAddresses(
    uint256 safeNonce,
    bytes32 ownerConfigHash,
    FeeCollection[] calldata updates
) external;
```

The selectors are:

```solidity
bytes4 constant CHANGE_OWNERS_SELECTOR =
    bytes4(keccak256("changeOwners(uint256,bytes32,uint256,address[])"));

bytes4 constant CHANGE_PROTOCOL_FEES_SELECTOR =
    bytes4(keccak256(
        "changeProtocolFees(uint256,bytes32,(uint256,address,uint256,uint256)[])"
    ));

bytes4 constant CHANGE_FEE_EXEMPTIONS_SELECTOR =
    bytes4(keccak256(
        "changeFeeExemptions(uint256,bytes32,(uint256,address,address,bool)[])"
    ));

bytes4 constant CHANGE_FEE_COLLECTION_SELECTOR =
    bytes4(keccak256(
        "changeFeeCollectionAddresses(uint256,bytes32,(uint256,address,address)[])"
    ));
```

Every fee-family entry addresses ONE deployment: `targetAddress` must equal
`address(this)` on the applying target (in addition to `targetChainId == block.chainid`),
so several deployments on one chain are governed independently by the same signed message,
and an entry can never apply anywhere its signers did not spell out. Entries addressed to
other deployments are verified but foreign — nothing is applied and the nonce is not
consumed locally.

Fee-exemption lists follow the fee-update rules: nonempty, at most 256 entries, nonzero
target chain ids, addresses and accounts, canonical strictly-increasing
(targetChainId, targetAddress, account) ordering. An exempt account calls `verify()` free
of charge on the addressed deployment; the exemption does not extend to the old-relay
delegation path, which forwards the old relay's own fee schedule.

Fee-collection lists point the addressed deployment's collected `verify()` fees at a new
recipient: nonzero recipient (a zero recipient would burn fees), strictly increasing
(targetChainId, targetAddress) — exactly one recipient per addressed deployment.

Relay decodes an action and compares `keccak256(action)` with a canonical
`abi.encodeWithSelector(...)` reconstruction. This rejects:

- unknown selectors;
- malformed dynamic offsets;
- noncanonical encodings;
- truncated values;
- trailing bytes.

Fee updates must contain one to 256 entries and be strictly increasing by
`(targetChainId, targetAddress, protocolId)`. The canonical order eliminates duplicates,
gives the instruction contract and every target the same action grammar, and keeps
validation linear in the batch size.

## 7. Relay deployment and state

`IRelay.RelayInitialConfig` nests the shared governance block
(`ISafeGovernance.GovernanceConfig governance`):

```solidity
struct GovernanceConfig {
    uint256 sourceChainId;          // Network id the Safe lives on (must be explicit, nonzero)
    address safe;                   // The Safe proxy address on the source chain
    uint256 threshold;              // Admitted signature threshold
    address[] owners;               // Admitted owners, strictly ascending
    uint256 ownerConfigSafeNonce;   // Safe nonce of the admitted owner generation
    uint256 safeNonce;              // Safe.nonce() at deployment: first accepted signed nonce
}
```

`governance.sourceChainId` is the single source-network id, unified with the RLY-23 signing
binding. It MUST be explicit and nonzero on EVERY deployment (`InvalidGovernanceSource`); a
home deploy states its own chain id, a mirror the mirrored network's — there is no
`block.chainid` defaulting. Governance is mandatory: the full
configuration is validated at initialization, and an all-zero or partial configuration is
rejected (`InvalidGovernanceSource` / `InvalidGovernanceOwnerConfiguration`).

Deployment-mode rules enforced by `initialize`:

- Safe governance is MANDATORY on every deployment — home, mirror and old-relay migration
  alike (`InvalidGovernanceSource` rejects a zero source network id or Safe; the same
  artifact ships to every chain). The old-relay handshake is orthogonal to governance:
  Flare's home deployment carries a setter, an old relay AND governance, while other
  chains deploy governed mirrors without an old relay;
- signing-policy-setter (home) deployments additionally enforce RLY-23 home-force
  (`governance.sourceChainId == block.chainid`, `SourceChainIdMismatchOnHomeDeploy`).
  Fee actions never apply on setter-mode deployments, but chain-agnostic actions such as
  fee exemptions do.

The initializer validates and stores the canonical owners and threshold, computes
`activeOwnerConfigHash`, and initializes the nonce state. The two configured nonces are
both Safe nonces, but they have different roles:

- `governance.ownerConfigSafeNonce` identifies when the admitted owner generation was
  activated by `changeOwners`;
- `governance.safeNonce` is the deployment replay floor. It should be sampled from
  `Safe.nonce()` immediately before deployment so every action signed for an already
  consumed Safe nonce is rejected.

Initialization requires:

```text
governance.ownerConfigSafeNonce <= governance.safeNonce
```

This is not a second governance counter. Both values come from the same Safe nonce
sequence. They must be recorded separately because a Safe can execute many fee and
unrelated transactions without changing its owner generation.

The target chain must not check `governance.safe.code.length`. The configured Safe exists
on Flare, not necessarily at that address on the target chain.

Governance state lives in the `SafeGoverned` ERC-7201 namespace and is exposed through
grouped `ISafeGovernance` views (plus Relay's `sourceChainId()` view on `IRelayGovernance`,
implemented over the same state — the source id is stored exactly once):

```solidity
function governanceSourceChainId() external view returns (uint256); // 0 when disabled
function governanceSigners()
    external view returns (address safe, uint256 threshold, address[] memory owners);
function governanceOwnerConfig()
    external view returns (bytes32 activeOwnerConfigHash, uint256 activeOwnerConfigSafeNonce);
function governanceNonces()
    external view returns (uint256 replayFloor, uint256 lastGovernanceSafeNonce);
function governanceSafeNonceConsumed(uint256 nonce) external view returns (bool);
```

`lastGovernanceSafeNonce` is the target-local high-water mark for relevant app
actions and never decreases. A delayed owner update may carry a lower nonce,
but installing it never lowers this fee floor. Owner updates are separately
ordered by `activeOwnerConfigSafeNonce`. A consumed Safe nonce remains consumed
globally, even across owner generations.

The initializer emits `GovernanceInitialized`, including the owner hash, generation
nonce, replay floor, threshold, and owner list. Deployment tooling should compare this
event against the source SafeInstructions contract and deployment manifest before publishing the Relay.

## 8. Relay processing

The state transition implemented by the `SafeGoverned` base is equivalent to (`state` is the
ERC-7201 namespaced governance state):

```solidity
function processSafeMessage(
    ISafeGovernance.SafeTx calldata txData,
    bytes calldata signatures
) external {
    require(
        state.safe != address(0) && txData.operation == 0 && txData.value == 0,
        InvalidGovernanceTransaction()
    );
    _verifyGovernanceSignatures(state, txData, signatures);

    bytes4 selector = _governanceSelector(txData.data);       // reverts if data.length < 68
    uint256 actionNonce = _governanceActionNonce(txData.data);
    // The action carries the SIGNED Safe nonce and must match the envelope exactly.
    require(actionNonce == txData.nonce, InvalidGovernanceTransaction());
    // replayFloor is the FIRST signed nonce this deployment accepts (Safe.nonce() sampled
    // at deployment == the next nonce to be signed).
    require(
        actionNonce >= state.replayFloor,
        GovernanceNonceBeforeReplayFloor(actionNonce, state.replayFloor)
    );
    require(!state.consumedNonces[actionNonce], GovernanceNonceAlreadyConsumed(actionNonce));
    // Grammar rule: EVERY action binds the admitted owner configuration in its second
    // word, so signers always approve against a specific owner generation.
    bytes32 configHash = _governanceActionConfigHash(txData.data);
    require(
        configHash == state.activeOwnerConfigHash,
        GovernanceOwnerHashMismatch(configHash, state.activeOwnerConfigHash)
    );

    if (selector == CHANGE_OWNERS_SELECTOR) {
        // The one generic action, handled by the base itself.
        require(
            actionNonce > state.activeOwnerConfigSafeNonce,
            GovernanceOwnerConfigNonceNotIncreasing(actionNonce, state.activeOwnerConfigSafeNonce)
        );
        _applyGovernanceOwners(state, txData.data);
        state.consumedNonces[actionNonce] = true;
        if (actionNonce > state.lastSafeNonce) {
            state.lastSafeNonce = actionNonce;
        }
    } else {
        // App-specific actions go to the inheriting contract's hook. Relay handles
        // CHANGE_PROTOCOL_FEES and CHANGE_FEE_EXEMPTIONS and reverts
        // UnknownGovernanceAction for anything else; a verified-but-locally-irrelevant
        // action returns false and consumes nothing.
        // lastSafeNonce starts at the floor (first accepted, not yet consumed) and then
        // tracks consumed app nonces; equality is either the floor bootstrap (allowed)
        // or an already-consumed nonce (caught by the consumed check above).
        require(
            actionNonce >= state.lastSafeNonce,
            GovernanceNonceNotMonotonic(actionNonce, state.lastSafeNonce)
        );
        if (_processGovernanceAction(selector, txData.data)) {
            state.consumedNonces[actionNonce] = true;
            state.lastSafeNonce = actionNonce;
        }
    }
}
```

Checks and state changes occur in one EVM transaction. Any failure reverts all fee,
owner, event, and nonce changes.

Owner membership uses binary search over the canonical stored owner list.

### 8.1 Failure ABI

The Safe custom errors are declared by `IRelayGovernance` and inherited by
`Relay`. An integration built from the interface ABI alone can therefore decode
every intentionally defined Safe error:

| Error | Meaning |
|---|---|
| `InvalidGovernanceSource()` | source chain or Safe configuration is incomplete |
| `InvalidGovernanceOwnerConfiguration()` | owner ordering, count, addresses, or threshold are invalid |
| `InvalidGovernanceTransaction()` | the Safe envelope, action encoding, nonce relation, or action contents are invalid |
| `InvalidSignaturesLength()` | the signature blob is empty or not a multiple of 65 bytes |
| `UnsupportedSignatureType(uint8)` | a chunk carries v == 0 (EIP-1271) or v == 1 (pre-approved hash) |
| `SignersNotSorted()` | recovered signers are not in strictly increasing order (or duplicated) |
| `UnknownSigner(address)` | a recovered signer is not an admitted owner |
| `ThresholdNotReached(uint256,uint256)` | fewer valid signatures than the admitted threshold |
| `InvalidGovernanceSignatures()` | DEPRECATED — kept declared for FV compatibility; no longer raised |
| `UnknownGovernanceAction(bytes4)` | the signed action selector is unsupported |
| `GovernanceOwnerHashMismatch(bytes32,bytes32)` | the action does not reference the currently admitted owner configuration |
| `GovernanceNonceNotMonotonic(uint256,uint256)` | a relevant fee action does not advance the target's global fee high-water mark |
| `GovernanceNonceBeforeReplayFloor(uint256,uint256)` | the action predates the target's deployment snapshot |
| `GovernanceNonceAlreadyConsumed(uint256)` | another relevant action already consumed this Safe nonce on the target |
| `GovernanceOwnerConfigNonceNotIncreasing(uint256,uint256)` | an owner update does not advance the owner-generation nonce |

**Failure-ABI change (2026-08):** Relay's ENTIRE failure surface is now typed custom
errors — the 39 Solidity `require` strings AND the 37 hand-written `relay()` assembly
reasons were replaced by 4-byte error selectors declared on `IRelay` (each declaration
documents its legacy string). The assembly raises them through a `revertWithError`
helper using compile-time-pinned selector constants, verified against the compiler's
own selectors by `RelayErrorSelectors.t.sol`. Consequences: any off-chain consumer
matching legacy reason strings (notably for `verify()` and `relay()`) must switch to
selector matching; `Submission.submitAndPass` surfaces inner Relay failures only as its
generic `_getRevertMsg` fallback ("Transaction reverted silently") because it decodes
`Error(string)` payloads only; the legacy production relay (`RelayMainDeployed`) keeps
its string reasons. The split described below is
deliberate: Safe is a new typed interface, while changing `relay()` reasons would
break existing tests, formal checks, and potentially relayer diagnostics.

Callers that handle both entry points must inspect the first four revert-data
bytes and support standard `Error(string)`, `Panic(uint256)`, the Safe custom
selectors, and unknown raw revert data. In particular, severely malformed
dynamic action encoding may be rejected by Solidity's generated ABI decoder
before Relay reaches its canonical-reencoding check; that decoder failure is
not guaranteed to use `InvalidGovernanceTransaction()`.

## 9. SafeInstructions transitions

The instruction contract is called only by the configured Safe. It requires:

```text
safeNonce == Safe.nonce() - 1
safeNonce >= nextSafeNonce
```

`Safe.nonce()` reads the signed value plus one during execution (the Safe pre-increments),
so the supplied value is the SIGNED nonce — the same value target Relays check against the
transaction envelope. `nextSafeNonce` starts at 0 (a fresh Safe's first transaction can be
accepted) and advances to `safeNonce + 1` on every accepted instruction.

### 9.1 Initialization admits generation 0

`initialize` reads the live Safe (`getOwners()` / `getThreshold()`), sorts and validates
the configuration, and admits it as **generation 0**:

```text
activeOwnerConfigSafeNonce == 0
activeOwnerConfigHash == hash(block.chainid, safe, 0, live threshold, live owners)
```

The generation ordinal convention is therefore uniform: generation 0 is always the
deployment-admitted configuration (regardless of the Safe's prior history), and every
generation `N > 0` is a rotation signed at Safe nonce `N`. There is no bootstrap
instruction and no unset state — fee actions are issuable immediately. Initial target
Relay deployments are seeded with the same values (`ownerConfigSafeNonce = 0`, the
canonical owners and threshold); targets deployed after a rotation are seeded from the
instruction contract's then-current hash and generation nonce.

### 9.2 Rotation attestation

Rotations are attested AFTER the native Safe change: the Safe first becomes the new
configuration through its own owner-management transactions, then `changeOwners` admits
it. It requires:

```text
safeNonce > instructions.activeOwnerConfigSafeNonce
currentOwnerConfigHash == instructions.activeOwnerConfigHash
hash(safeNonce, proposed threshold, proposed owners)
    == hash(safeNonce, live Safe threshold, live Safe owners)
```

The last rule is the anti-typo core of the design: an attestation can only ever admit the
configuration the Safe actually has, so the cross-chain layer can never carry an owner
set that was never live. A hand-built wrong list reverts at issuance, consumes nothing,
and a mistaken native change is corrected natively before anything crosses chains.

The strict generation ordering mirrors the target-side rule, so a fresh Safe's first
transaction (signed nonce 0, colliding with generation 0) is rejected identically on both
sides — neither can fork the generation lineage of the other. The `currentOwnerConfigHash`
rule keeps the issuance record a single linear generation history.

Target Relays verify the attestation's signatures against their admitted OLD mirror while
the Safe verified the same bytes against the NEW owners — which is why the attestation
must be signed by the old ∩ new intersection (section 10).

### 9.3 Fee actions

`changeProtocolFees` requires both:

```text
ownerConfigHash == instructions.activeOwnerConfigHash
hash(live Safe threshold, live Safe owners) == instructions.activeOwnerConfigHash
```

Between a native Safe change and its attestation, fee actions therefore fail: the live
and admitted configurations differ until the rotation attestation is issued.

The instruction contract validates the complete fee list:

- one to 256 updates;
- nonzero target chain ID and target address;
- protocol ID greater than one;
- strict ascending `(targetChainId, targetAddress, protocolId)` order.

Zero fees are allowed and mean that verification for that protocol is free.

`changeFeeExemptions` and `changeFeeCollectionAddresses` run the same envelope checks and
validate their lists analogously: exemptions require nonzero accounts and strict
`(targetChainId, targetAddress, account)` order; fee-collection updates require a nonzero
recipient (a zero recipient would burn collected fees) and strict
`(targetChainId, targetAddress)` order — exactly one recipient per addressed deployment.

## 10. Owner rotation procedure

A complete rotation is:

1. The instruction contract and all target Relays admit configuration `C_old`.
2. The Safe executes its native owner and threshold changes to become `C_new` (each
   native transaction is signed by the then-current owners). Nothing crosses chains yet:
   a mistake at this step is corrected natively and no target ever observes it.
3. Owners in `C_old ∩ C_new` — at least `max(threshold(C_old), threshold(C_new))` of
   them — execute the `changeOwners` attestation through the Safe. The instruction
   contract admits it only if the attested configuration IS the live Safe configuration.
4. Every target Relay receives that exact signed transaction and installs `C_new`: the
   Safe verified the signatures against `C_new`, each target verifies the same bytes
   against its admitted `C_old`.
5. Between steps 2 and 3, the instruction contract rejects fee actions because its
   admitted hash and the live Safe hash differ.
6. `C_new` owners execute the next fee action.
7. A target that missed step 4 rejects the new action until it first installs the owner
   update.

Safe owner-management transactions are not Relay governance messages and are not passed to
`processSafeMessage`.

Operators should finish owner-update delivery before signing a fee action under the new
configuration. A target may accept a later owner update with a nonce gap, but it cannot
accept a fee action whose owner hash is not locally active.

**Attestation signature composition is the ceremony's critical rule.** The standard Safe
UI collects signatures from CURRENT (`C_new`) owners; the executed attestation must
instead contain ONLY chunks from `C_old ∩ C_new` signers — any non-`C_old` chunk makes
every target revert `UnknownSigner`. Tooling must verify the chunk set against `C_old`
before execution. An attestation executed with the wrong composition is issued on the
source but rejected by every target, desynchronizing the source lineage from the targets;
recovery is an old-threshold-signed replacement artifact for the targets plus a
Flare-governance upgrade of the instruction contract (single-chain surgery).

The intersection rule bounds each attested step: at most
`|C| − max(threshold(C_old), threshold(C_new))` owners can be replaced per step (5 of the
Flare Safe's 11 at threshold 6). Larger rotations decompose into several attested steps,
each delivered to every target in order. When fewer than a threshold of owners remain
controllable, the Safe itself is already lost — no ceremony ordering changes that.

A delayed owner update remains installable even if that target first received a
higher-nonce fee action signed by `C_old`. Installing the owner update does not
lower the fee high-water mark: the next relevant fee action under `C_new` must
still have a Safe nonce above every fee already applied on that target. The
globally consumed-nonce map prevents two relevant actions with the same Safe
nonce from both being applied.

## 11. Fee semantics

For each signed fee action, a target Relay:

1. validates the canonical action and active owner hash;
2. requires one to 256 entries in strict `(targetChainId, targetAddress, protocolId)`
   order;
3. rejects any zero target chain ID, zero target address, or protocol ID zero or one;
4. selects entries where `targetChainId == block.chainid` AND
   `targetAddress == address(this)`;
5. validates the complete list before writing storage;
6. applies all local fees atomically.

An action containing no local entry succeeds as a no-op and does not advance
the fee high-water mark and does not consume its Safe nonce. This prevents an
unrelated high-nonce action from blocking an older relevant action on that
target. An empty list is invalid rather than an irrelevant no-op.

On a setter-mode (source-chain) deployment, EVERY fee action is treated as foreign —
verified but never applied or consumed — because setter-mode Relays never charge
`verify()` fees (fee configurations are already rejected at initialization).

Fee-exemption actions follow the same relevance and consumption semantics, keyed on
`(targetChainId, targetAddress, account)`, and apply on all deployment modes. `verify()`
charges an exempt caller nothing (`fee = 0`; any attached value is fully refunded) while
all other callers keep paying the configured protocol fee. Exemptions are the intended
integration path for verifier infrastructure such as DVN adapter contracts that must call
`verify()` at high frequency.

Fee-collection actions (`changeFeeCollectionAddresses`) follow the fee-update semantics —
per-deployment addressing, foreign on setter-mode Relays — and atomically repoint
`feeCollectionAddress`, the recipient of collected `verify()` fees, for the addressed
deployment.

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

event GovernanceFeeExemptionUpdated(
    uint256 indexed targetChainId,
    address indexed account,
    bool exempt,
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

The instruction contract emits its owner transition and a compact fee-validation record. The original
Safe transaction remains the source of complete fee calldata.

## 12a. Upgradeability and deterministic deployment

Both sides of the pipeline are UUPS proxies:

- **`SafeInstructions`** (Flare only) follows the Flare governed-UUPS house pattern
  (`FlareUpgradeableBase`): `upgradeToAndCall` is guarded by `onlyGovernance` — Flare
  governance with its timelock. Deployed as `SafeInstructionsProxy` by plain CREATE.
- **`Relay`** is deployed on arbitrary chains where the Flare governance stack does not
  exist, so its upgrade authority is stock OpenZeppelin
  `OwnableUpgradeable` (`@openzeppelin/contracts-upgradeable@5.7.0`) with the canonical
  `_authorizeUpgrade ... onlyOwner` UUPS guard — audited off-the-shelf code, nothing
  bespoke in the upgrade path. The owner is a per-chain direct address (a multisig,
  `owner()`/`transferOwnership`, no timelock): on Flare it is Flare governance, on other
  chains the designated multisig. Stock Ownable's `renounceOwnership` is overridden to
  always revert (`RenounceOwnershipDisabled`) — accidentally burning the upgrade path is
  impossible; ownership only moves via `transferOwnership` (deliberate freezing remains
  possible by transferring to an unspendable address). **The owner is a full-control
  role on that chain** — whoever holds it can replace the implementation, above the Safe
  signature machinery — and is deliberately DISTINCT from Safe governance, which only
  authorizes parameter changes through `processSafeMessage`.

`Relay.initialize` configures everything in one atomic call (protocol config, Safe config,
per-chain owner) and runs inside the `RelayProxy` constructor, so the proxy address is
never observable uninitialized and no post-deploy setup or ownership transfer exists.
Future signing-policy migrations on proxied deployments are `upgradeToAndCall` operations;
the `oldRelay` handshake in `initialize` remains for migrating legacy non-proxy relays.

### Chain-invariant Relay address

The Relay proxy must live at the SAME address on every chain, including chains added later,
without a front-running or squatting window. Chain of custody:

1. the canonical keyless CREATE2 deployer (`0x4e59b44847b379578588920cA78FbF26c0B4956C`,
   verified live on Flare, Songbird, Coston, Coston2, Ethereum and Base) — anyone can fund
   and broadcast its presigned deployment on a new chain;
2. `Create3Factory` (ownerless, permissionless, wraps OpenZeppelin 5.7 `Create3`), deployed
   through (1) with a fixed salt ⇒ identical factory address everywhere; front-running it is
   harmless (byte-identical, no privileged state);
3. the Relay proxy, deployed through the factory under a **deployer-scoped salt**
   (`keccak256(msg.sender, salt)`): only the designated deployer account can ever mint the
   official address on a chain where it is not yet deployed. The address depends only on
   (factory, deployer, salt) — NOT on the implementation or per-chain initializer data.

The deployer account is therefore the permanent address authority and must be kept in cold
storage: compromise allows deploying arbitrary code at the official address on
NOT-yet-deployed chains only; loss forfeits address continuity for future chains. Existing
deployments are unaffected by either. No trustless scheme can reserve an address on chains
that do not exist yet.

### Formal-verification status of this refactor

The Safe-upgradeable refactor deliberately leaves the Relay FV gates (Halmos manifest pins,
Lean Yul snapshot, artifact parity, revert-ABI inventory, Certora munge, Kontrol) red
pending a dedicated re-baseline: compiler re-pins to solc 0.8.35, proxy-aware harness
setup, and the eth_sign branch + typed-error inventory in the signature-verification specs.
`check_gss_nonOwnerSigner_rejected` remains semantically valid.

## 13. Implemented tests

The exact Safe gate requires 43 tests across the unit, production-rehearsal, and
stateful-invariant suites. The 37-test
`test-forge/unit/governance/SafeGovernance.t.sol` suite deploys:

- the official Safe v1.3.0 `GnosisSafeL2` singleton;
- a `GnosisSafeProxy`;
- five EOA owners with threshold three;
- a Flare instruction contract at simulated source chain ID 14;
- two Relay instances at distinct simulated target chain IDs.

The suite currently covers:

- exact three-of-five Safe setup and generation-0 admission at initialization;
- identical source/target rejection of a fresh Safe's rotation signed at nonce 0
  (colliding with the initialize-admitted generation 0);
- differential Safe digest comparison using every transaction field;
- successful Safe execution and identical calldata delivery to two targets;
- deployment-addressed fee extraction (`targetChainId` AND `targetAddress` must match);
- fee-collection-address updates across chains from one instruction, with non-canonical
  list rejection on both sides;
- helper-target independence and post-signature `to` tampering;
- replay and modified-action rejection;
- action/Safe nonce consistency;
- nonce gaps;
- explicit higher-nonce-first suppression of a lower signed fee action;
- explicit exhaustion of the fee nonce sequence by a threshold-signed
  `uint256.max` future nonce that was never executed on the source Safe;
- irrelevant target no-op behavior;
- deployment replay-floor rejection;
- individual per-deployment addressing of two Relay deployments on the same target chain:
  one batch entry per deployment applies to both, while an action addressed to only one is
  verified-but-foreign (nonce unconsumed) on the other;
- conflicting threshold-signed transactions at one Safe nonce, including target-local
  first-delivery divergence and one-action-per-nonce enforcement;
- more signatures than the threshold;
- insufficient, duplicate, malformed, owner-count-exceeding, invalid-`v`, and high-`s`
  signatures, all normalized to the interface error;
- duplicate local fee rejection without partial state;
- empty, oversized, and noncanonically ordered fee-list rejection by the target,
  with SafeInstructions/target agreement for the ordering case;
- successful execution of the maximum 256-entry canonical fee batch;
- target deployment without source Safe bytecode;
- relay-mode and `oldRelay == 0` deployment restrictions;
- owner rotation through native Safe change, intersection-signed attestation, new-owner
  fee action, and target-local installation ordering;
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
- instruction contract rejection of fee actions while a rotation attestation is pending,
  including rollback of the Safe nonce, rejection of an attestation that does not match
  the live configuration, and live-state-view transitions before, during, and after
  rotation;
- standalone rejection of a threshold-signed attestation proposing a non-live owner set
  (the attest-after anti-typo rule).

`SafeGovernanceProductionRehearsal.t.sol` adds three production-shape tests. They
deploy the exact `@gnosis.pm/safe-contracts@1.3.0` release artifact bytecode,
reproduce the fixed-block Flare Safe shape (11 EOA owners, threshold 6, no
modules, zero guard, and the recorded fallback handler), execute fee/rotation/fee
calldata through that Safe, deliver the successful calldata to two target Relays,
and execute a 256-entry fee batch. The recorded worst-case test cost is 7,508,970
gas against the snapshot's 28,000,000 block gas limit.

`SafeGovernanceInvariant.t.sol` adds a model-based state machine over two target
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

Safe governance now has a dedicated Halmos harness in
`test-forge/fv/SafeGovernanceFV.t.sol`. The exact manifest contains 13 Safe proofs
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

Four parametric Safe storage invariants are specified in
`certora/specs/RelayInvariants.spec` (global high-water monotonicity,
owner-generation monotonicity, owner-hash/generation coupling, and consumed-nonce
permanence). The fail-closed local gate compiles and typechecks both current
Certora configurations with CLI 8.16.1, Java 21, and solc 0.8.27. This is front-end
evidence only: the current Safe source still requires a Certora cloud proof run
before any parametric all-functions result is claimed.

Kontrol and Lean continue to prove properties of the signing-policy `relay()`
core and do not cover Safe governance. The deleted legacy `governanceFeeSetup`
proof remains absent from the exact manifest; no legacy result is relabeled as a
Safe result.

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
- exact 41-test Safe gate and 102-check Halmos result;
- fixed-block source-Safe snapshot report, refreshed immediately before a
  production ceremony;
- local Certora compilation/typecheck report and the separate cloud-proof status;
- a clean-tree eight-report verification bundle. `--allow-dirty` is a development
  convenience and is explicitly not release eligible.

The deployed source-chain Safe proxy address, implementation address, source chain ID,
initial canonical owners, threshold, instruction contract `activeOwnerConfigSafeNonce`, instruction contract
`activeOwnerConfigHash`, and target deployment replay floor must be recorded in the
deployment manifest.

### 15.1 Deployment and migration timing

The safe sequence for a new target Relay is:

1. pause governance signing and inventory every outstanding signed Safe transaction;
2. rely on the generation admitted by the SafeInstructions deployment (generation 0), or
   execute a same-owner `changeOwners` action to create a fresh owner generation and
   invalidate messages referring to the prior hash;
3. deliver that generation update to every already deployed target;
4. require `instructions.activeOwnerConfigurationIsLive() == true`, independently recompute
   the live Safe hash, and record the instruction contract's active owner hash and generation nonce;
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
security boundary: `processSafeMessage` is permissionless, so any party can submit a valid
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
| **DR-03: rotation attestation window and composition** | Between the native Safe change and the `changeOwners` attestation, the instruction contract pauses fee actions; Relay cannot enforce that pause and continues to recognize its installed generation. An attestation executed with signature chunks outside `C_old ∩ C_new` is issued on the source but rejected by every target (`UnknownSigner`), desynchronizing the source lineage from the targets. | Nothing crosses chains before the attestation, so a mistaken native change is corrected natively and never observed remotely. The attested configuration must equal the live Safe, so no never-live owner set can ever be admitted. Ceremony tooling verifies the chunk set against `C_old` before execution; the intersection bound (section 10) is preflighted per step. | Store the previous owner mirror in the instruction contract and re-verify attestation signatures on-chain against it; or enforce instruction success through a source execution proof. Both add state and verification machinery to a contract that is deliberately not a trust anchor. |
| **DR-04: helper target is not an authorization domain** | Relay does not store or require one instruction contract address. Any compatible helper target can carry the same recognized action calldata. | The helper is a signing-time safety tool, not a Relay trust anchor. Every Safe envelope field is signed, and Relay independently validates the action, owner generation, and signatures. Signing tools must decode the action rather than infer meaning from `to`. | Bind an expected instruction contract address and code/version hash in Relay; include a helper-domain identifier in every action; or enforce approved target/selector combinations with a Safe guard. These reduce helper flexibility and require coordinated upgrades. |
| **DR-05: asynchronous owner revocation** | Removing an owner from the source Safe does not revoke the old generation on a lagging target. That target remains able to accept an old-generation threshold signature. | Independent chains cannot be assumed available simultaneously. The runbook installs and confirms the new Relay generation everywhere before changing native Safe owners; an unavailable target is explicitly treated as governed by the old set. | Deliver finalized owner updates through an authenticated bridge; give owner generations signed expiry times; require periodic source checkpoints; or suspend consumers on a target that misses the cutover. Immediate revocation requires authenticated source state. |
| **DR-06: same-nonce conflicts are first-delivery-wins** | If the threshold signs two different relevant actions at one Safe nonce, each target independently accepts the first one delivered and rejects the other. Different targets can select different winners. | This requires threshold equivocation or signing-process failure, not an unprivileged attacker. Consumed-nonce storage prevents double application on one target. Signing infrastructure must provide one canonical payload per Safe nonce. | Prove which transaction executed on Flare; publish the canonical nonce-to-digest mapping through a bridge; use a governance proposal registry before signing; or require owners and signing infrastructure to reject a second digest for an allocated nonce. |
| **DR-07: gap-tolerant fee ordering** | A higher-nonce fee action delivered first suppresses every lower-nonce fee action on that target, including an update for another protocol. | Non-sequential processing lets an unavailable target catch up without replaying every Safe transaction. Governance tooling must serialize intended updates or explicitly mark skipped lower actions as abandoned. | Enforce sequential fee nonces; keep a per-protocol high-water mark; attach an independent per-entry version; or relay canonical source execution logs. Per-protocol state preserves more out-of-order updates at additional storage and message complexity. |
| **DR-08: future-nonce and terminal-nonce authority** | The threshold may sign a future Safe nonce. An accepted fee action with action nonce `uint256.max` makes the global fee high-water mark terminal and permanently blocks later fee actions. | This is governance self-harm requiring the admitted threshold, not a threshold bypass. Gap tolerance is deliberate, and the regression suite makes the terminal behavior visible. Signing policy must reject implausible future nonces and `uint256.max`. | Reject the terminal value on-chain; impose a bounded forward gap; use a bounded independent governance sequence; add a generation-authorized recovery action; or require a source execution proof. A forward-gap bound reduces independent catch-up flexibility. |
| **DR-09: replay floor cannot reject pre-signed future actions** | Deployment rejects past Safe nonces but cannot detect a future-nonce transaction signed before deployment. | Migration pauses signing and creates a fresh same-owner generation before publishing the target, invalidating actions tied to the previous generation. | Sign a target deployment epoch or activation commitment; bind each action to a deployment identifier; cap accepted nonces relative to a proved source checkpoint; or require source execution evidence. |
| **DR-10: actions are not bound to a Relay deployment** | Two Relay contracts on the same target chain can accept the same action when their owner generation and replay floor match. | The design binds target-specific fee entries to chain ID and assumes one authoritative Relay per chain. Replacement uses a fresh owner generation, and consumer registries stop trusting the old address before the new one is published. | Include `targetRelay` and a deployment ID in each fee entry while retaining a multi-target list; maintain a signed source registry of authoritative deployments; or incorporate the target address into a per-target action digest. |
| **DR-11: fee values are policy-unbounded** | Governance may set any `uint256` fee, including zero or a value that makes normal use uneconomic. | Fee selection is a governance-policy decision, and the threshold already has authority to change it. Off-chain proposal validation and human-readable signing review enforce economic policy. | Add per-protocol min/max bounds; rate-limit changes; use a timelocked two-step fee update; or make bounds themselves governance-controlled with stricter delay and review rules. |
| **DR-12: maximum batch is not universally executable** | The protocol permits 256 fee entries, but a target with a lower gas limit may not fit the measured 7,508,970-gas production-shape transaction. | The cap bounds parsing work; deployment qualification chooses a lower operational batch size per target and preserves gas margin. | Lower the protocol-wide cap; sign several independently versioned batches; add per-target batch caps; or compress/aggregate fee entries. Chunking must preserve ordering and atomicity expectations. |
| **DR-13: Safe modules can alter SafeInstructions state** | A module can make the Safe call the instruction contract outside the normal owner `execTransaction` path and can make helper state misleading. | SafeInstructions state does not authorize Relay. A target still requires a valid owner-threshold signature over the complete transaction. Production snapshots and ceremonies review modules and guards. | Require a module-free Safe; use a Safe guard that restricts instruction contract selectors and targets; monitor module/guard changes; or make instruction contract attestations depend on a finalized Safe execution proof rather than caller identity alone. |
| **DR-14: mixed revert encodings** | Legacy `relay()` assembly uses short revert strings while Safe Solidity uses custom errors. Integrations need two decoders. | This preserves the established assembly ABI while giving the new path typed errors. It does not change authorization or state safety. | Normalize errors in a future breaking release; wrap Relay behind an adapter that maps both formats; or publish a shared decoder generated from the ABI and the registered legacy string inventory. |

### 16.3 Verification limitations are not protocol acceptance

The Safe Halmos proofs are bounded and begin after signer recovery; real-Safe differential
tests cover digest and ECDSA integration, while Lean and Kontrol cover the signing-policy
relay core rather than Safe. These are evidence-scope limitations, not protocol design
choices. They must stay explicit in every security claim. The current Certora rules pass
the local compile/typecheck gate, but the cloud verdict is still a release-evidence item,
not something made safe by the design-risk acceptance above.

Options for stronger assurance are the current Certora cloud run, a symbolic proof of the
complete Safe digest and signature parser, an end-to-end refinement from
`processSafeMessage` calldata to state changes, and a separate proof system for finalized
source-Safe execution. None should be described as already established by the present
bounded Safe proof set.

## 17. Alternative security and robustness review

The 2026-07-25 adversarial review re-derived the protocol from relayer ordering,
configuration reincarnation, source cancellation, and production migration rather than
from the existing test inventory.

| ID | Severity | Result |
|---|---|---|
| Safe-A1 | High liveness / medium integrity | **Fixed.** Owner hashes lacked a generation nonce. A higher old-config fee could strand a pending rotation, and rotating back to the same tuple could revive old future-nonce signatures. Owner hashes now include their activation Safe nonce; owner generations advance independently without lowering the global fee floor, and all relevant actions consume their Safe nonce globally. |
| Safe-A2 | Medium integrity | **Fixed.** Resetting a per-generation fee watermark after a delayed rotation allowed a newly admitted configuration to apply a fee action below a fee nonce already accepted by that target. Relevant fees now advance one global high-water mark across owner rotations; the adversarial sequence is tested. |
| Safe-A3 | Medium robustness | **Fixed.** Relay accepted empty lists, validated only local entries, and used quadratic duplicate scans while the instruction contract validated the full message. Both now require the same nonempty, strictly ordered, at-most-256-entry grammar in linear time; the maximum batch executes in the real-Safe test. |
| MIG-A1 | High liveness | **Fixed.** `redeploy-relay.ts` and the non-initial `redeploy-contracts.ts` path documented legacy policy-hash wrapping but passed the bare hash. Deployment now requires an explicit old hash scheme and tests wrap-once/passthrough/fail-closed behavior. |
| TIM-A1 | Medium operational | **Accepted design choice (DR-01).** Safe cancellation, failure, or non-execution does not revoke a copied threshold-signed message because the threshold signature itself is remote authority. The test suite demonstrates this behavior explicitly. |
| TIM-A2 | Medium operational | **Accepted design choice (DR-06).** Two signed actions at one Safe nonce are first-delivery-wins per target. Threshold non-equivocation is required; the consumed-nonce map prevents double application, while source execution proof would identify the canonical winner. |
| TIM-A3 | Medium operational | **Accepted design choice (DR-05).** Native Safe owner removal does not revoke that owner on a lagging target. The rotation runbook delivers and confirms the Relay owner update before the Safe mutation, and a real-Safe test demonstrates both the exposed and protected target states. |
| TIM-A4 | Medium migration | **Accepted with migration controls (DR-09).** The deployment replay floor rejects past, not already-signed future, Safe nonces. The migration runbook pauses signing and creates a fresh same-owner generation; stronger enforcement needs source execution proof or a signed deployment epoch. |
| MIG-A2 | Medium operational | **Fixed/documented.** Owner-generation nonce and deployment replay floor are now distinct Safe-derived inputs, validated on-chain and emitted at construction. |
| OPS-A1 | Low helper integrity | **Accepted design choice (DR-13).** Safe modules can alter SafeInstructions state, but cannot bypass Relay signature verification. Deployment review must include Safe modules and guards. |
| TIM-A5 | Medium operational | **Accepted design choice (DR-07).** Monotonic fee processing lets a higher-nonce valid action delivered first suppress lower-nonce signed fee actions on that target. Release tooling must serialize delivery or explicitly abandon the skipped actions. |
| MIG-A3 | Medium migration | **Accepted with replacement controls (DR-10).** Signatures are target-chain scoped through fee entries, but are not bound to one Relay address. Replacement uses a fresh owner generation and replay floor, and consumers must stop trusting the deprecated address. |
| TIM-A6 | High liveness | **Accepted with ceremony controls (DR-03).** Between a native Safe change and its attestation, fee issuance pauses; the attestation admits only the live configuration, so the pause ends exactly when the ceremony completes and no never-live proposal can wedge the flow. The instruction contract exposes an exact live/admitted-state view; deployment requires it to be true. Residual risk is attestation signature composition, preflighted by tooling. |
| TIM-A7 | High liveness / governance trust | **Accepted governance-authority risk (DR-08).** A threshold-signed extreme future nonce, including `uint256.max`, can exhaust a target's fee sequence without source execution. The test suite demonstrates this. Official-relayer policy must reject it as defense in depth; on-chain prevention needs a nonce bound, recovery action, or source execution proof. |

No unprivileged path was found that bypasses the configured owner threshold, changes a
signed transaction field, applies a nonlocal fee entry, or mutates fees partially on
failure. The dominant remaining security boundary is intentional: Relay proves owner
authorization, not canonical source-chain execution.
