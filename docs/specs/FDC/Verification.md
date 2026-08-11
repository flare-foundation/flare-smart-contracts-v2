# Verification

After a round's Merkle root is finalized on `Relay`, consumer contracts on Flare prove individual attestation responses against it through [`FdcVerification`](../../../contracts/fdc/implementation/FdcVerification.sol).

`FdcVerification` is a **UUPS-upgradeable** contract with one external view function per attestation type. Each takes a `Proof` struct (response data + Merkle proof) and returns a `bool`. The contract trusts the threshold-signed Merkle root in `Relay` — it does not re-verify external-chain data; it only verifies that the response is one of the leaves in the round's tree.

## The `Proof` shape

Every attestation type defines a `Response` struct and a `Proof` struct in [`contracts/userInterfaces/fdc/`](../../../contracts/userInterfaces/fdc/). The shapes are uniform:

```solidity
// example: IPayment
interface IPayment {
    struct RequestBody { ... }       // type-specific
    struct ResponseBody { ... }      // type-specific
    struct Response {
        bytes32 attestationType;     // == bytes32("Payment") (or whichever)
        bytes32 sourceId;            // e.g. bytes32("BTC")
        uint64  votingRound;         // round in which the attestation was confirmed
        uint64  lowestUsedTimestamp;
        RequestBody requestBody;     // copied from the request
        ResponseBody responseBody;   // computed by the provider
    }
    struct Proof {
        bytes32[] merkleProof;
        Response  data;
    }
}
```

`keccak256(abi.encode(response))` is what the provider hashed into the Merkle tree, so verification is:

```solidity
bytes32 leaf       = keccak256(abi.encode(_proof.data));
bytes32 merkleRoot = relay.merkleRoots(fdcProtocolId, _proof.data.votingRound);
return _proof.merkleProof.verifyCalldata(merkleRoot, leaf);
```

…plus an `attestationType` sanity check (`_proof.data.attestationType == bytes32("Payment")` etc.) so a `Payment` proof can't be wedged into a `Web2Json` verifier.

## The seven verifier methods

[`FdcVerification`](../../../contracts/fdc/implementation/FdcVerification.sol) exposes one method per attestation type:

| Method | Type byte string | Interface |
|--------|------------------|-----------|
| `verifyAddressValidity(IAddressValidity.Proof)` | `"AddressValidity"` | [`IAddressValidity`](../../../contracts/userInterfaces/fdc/IAddressValidity.sol) |
| `verifyBalanceDecreasingTransaction(IBalanceDecreasingTransaction.Proof)` | `"BalanceDecreasingTransaction"` | [`IBalanceDecreasingTransaction`](../../../contracts/userInterfaces/fdc/IBalanceDecreasingTransaction.sol) |
| `verifyConfirmedBlockHeightExists(IConfirmedBlockHeightExists.Proof)` | `"ConfirmedBlockHeightExists"` | [`IConfirmedBlockHeightExists`](../../../contracts/userInterfaces/fdc/IConfirmedBlockHeightExists.sol) |
| `verifyEVMTransaction(IEVMTransaction.Proof)` | `"EVMTransaction"` | [`IEVMTransaction`](../../../contracts/userInterfaces/fdc/IEVMTransaction.sol) |
| `verifyPayment(IPayment.Proof)` | `"Payment"` | [`IPayment`](../../../contracts/userInterfaces/fdc/IPayment.sol) |
| `verifyReferencedPaymentNonexistence(IReferencedPaymentNonexistence.Proof)` | `"ReferencedPaymentNonexistence"` | [`IReferencedPaymentNonexistence`](../../../contracts/userInterfaces/fdc/IReferencedPaymentNonexistence.sol) |
| `verifyWeb2Json(IWeb2Json.Proof)` | `"Web2Json"` | [`IWeb2Json`](../../../contracts/userInterfaces/fdc/IWeb2Json.sol) |

All seven follow the identical pattern shown above. The protocol ID used (`fdcProtocolId`) is a `uint8` set at proxy initialization (`initialize(governanceSettings, governance, addressUpdater, fdcProtocolId)`).

## What a consumer contract does

A typical use:

```solidity
function unlockOnPaymentConfirmation(IPayment.Proof calldata _proof) external {
    require(fdcVerification.verifyPayment(_proof), "FDC verification failed");

    // Now we can trust _proof.data.responseBody fields.
    // Application logic: check the actual transaction details match what we required.
    require(_proof.data.responseBody.receivingAddressHash == expectedRecipient, "wrong recipient");
    require(_proof.data.responseBody.spentAmount >= expectedAmount, "amount too low");
    require(_proof.data.requestBody.standardPaymentReference == expectedRef, "wrong reference");
    require(_proof.data.requestBody.transactionId == expectedTxId, "wrong txid");

    // application action
    _unlock(msg.sender);
}
```

A few things worth noting:

- **The verifier doesn't enforce business semantics.** It only confirms "this `Response` was attested in this round". The consumer must check that the response actually says what they need (right amount, right recipient, right time window).
- **The `votingRound` field is part of the leaf.** A consumer that requires data from a specific round — e.g. "the payment must have been attested in round X" — must verify `_proof.data.votingRound == X`.
- **The `lowestUsedTimestamp` field is part of the leaf.** A consumer that needs the underlying chain data to be recent can require `_proof.data.lowestUsedTimestamp >= someMinimum`.
- **Replay protection is the consumer's job.** The verifier returns `true` for the same proof every time — it's idempotent. If the consumer is "first to claim wins", they need to track which `(transactionId, recipient, ...)` tuples they've already honored.

## Reading the Merkle root directly

A consumer that needs more flexibility (e.g. proving a leaf for an attestation type not yet wired up to `FdcVerification`, or doing batch proofs) can read the Merkle root directly:

```solidity
bytes32 root = relay.merkleRoots(fdcProtocolId, votingRoundId);
```

…and verify the proof itself with OpenZeppelin's `MerkleProof` library. Note that `Relay.merkleRoots` is gated on `signingPolicySetter != 0` (i.e. the Flare deployment, not test/dev), so this path won't work on stripped-down deployments.

## Upgradeability

`FdcVerification` is UUPS-upgradeable behind [`FdcVerificationProxy`](../../../contracts/fdc/implementation/FdcVerificationProxy.sol). New attestation types are added by **deploying a new implementation** that adds a verifier method, then governance calls `upgradeToAndCall(newImpl, "")`. The proxy address stays the same; existing consumers see the same address and get the new verifier methods. Since each `verifyX` is a thin Merkle-proof check, upgrades are low-risk — the only real change is to the supported `attestationType` set.

The set of types FDC supports is decided by:

1. Off-chain provider clients implementing the response shape (so they can produce verifiable attestations of that type).
2. `FdcInflationConfigurations` listing the type so it qualifies for inflation-funded reward shares (see [Rewarding](./Rewarding.md)).
3. `FdcRequestFeeConfigurations` having a fee set for the relevant `(type, source)` pairs.
4. `FdcVerification` having a `verifyX` method for the type.

Removing a type requires the inverse — providers stop honoring it, governance removes the fee and inflation entries, and a future upgrade can drop the verifier method.

## Why each type has a dedicated method

The seven methods all do the same thing — verify a Merkle proof. They could be collapsed into one `verify(bytes32 attestationType, bytes encodedResponse, bytes32[] merkleProof, uint256 votingRound)`. They're not, because:

- **Type safety.** Each method's signature names the exact `Proof` struct, so Solidity rejects mismatched input at compile time. Consumers can't accidentally pass a `Payment` proof to a `Web2Json` verifier.
- **Selector stability.** Each method has its own 4-byte selector; consumer ABIs can call by name without worrying about argument-encoding ambiguity.
- **NatSpec discoverability.** Tools that read the ABI see one method per type, with the exact `Response` struct documented inline. Easier to integrate against than a generic verifier.

The cost is a separate code path per type (and a separate `bytes32` literal compared in each), which is negligible.

## What changes for FDC2

FDC2 uses [`Fdc2Verification`](../../../contracts/fdc2/implementation/Fdc2Verification.sol), which is structurally different:

- **Signing-policy verification.** `verifySigningPolicySignatures(signatures, messageHash)` delegates to `Relay.verifyCustomSignature` to verify a packed batch of FSP signing-policy signatures. Used for cross-chain delivery of FDC2 attestations. A `verifySigningPolicySignaturesWithThreshold` variant checks against a caller-chosen signature-weight threshold instead of the signing policy's own (see [Fdc2.md](./Fdc2.md)).
- **TEE-machine verification.** `verifyTeeSignature(sig, hash)` and `verifyTeeSignatures(sigs[], hash)` recover the TEE machine's address via ECDSA, then check `flareTeeManager.getExtensionId(teeId) == 0` (the system extension) and `flareTeeManager.getTeeMachineStatus(teeId) == PRODUCTION`. Used for direct on-Flare verification.
- **Cosigner recovery.** `recoverCosigners(sigs[], hash)` recovers cosigner addresses for caller-side authorization checks.

Every FDC2 verifier builds its `messageHash` via the canonical [`SignedPayload`](../../../contracts/utils/lib/SignedPayload.sol) envelope:

```solidity
bytes32 messageHash = SignedPayload.messageHash(
    FDC2,
    keccak256(abi.encode(
        keccak256(abi.encode(proof.header)),
        keccak256(abi.encode(proof.requestBody)),
        keccak256(abi.encode(proof.responseBody))
    ))
);
```

The outer envelope binds the `FDC2` domain prefix and `block.chainid`, preventing cross-chain and cross-protocol replay. The inner `dataHash` is the `keccak256` of the three per-struct hashes of `(header, requestBody, responseBody)` — including the header's `attestationType` and `sourceId` — so a signed proof cannot be replayed across attestation types, sources, or requests within FDC2. The three-hashes-of-structs layout is the shape the off-chain FDC2 components (tee-node, relay) produce; do not collapse it to a single `keccak256(abi.encode(header, requestBody, responseBody))`. The Diamond's availability-check flow ([`Verification.verifyAvailabilityCheckProof`](../../../contracts/tee/library/Verification.sol)) and the PMW account- and UTXO-configured proof flows ([`TeePaymentsConfigVerifier`](../../../contracts/tee/implementation/TeePaymentsConfigVerifier.sol)) both route the signing-policy / TEE-signature and cosigner checks through the shared stateless [`Fdc2ProofVerification`](../../../contracts/fdc2/library/Fdc2ProofVerification.sol) library (the cosigner set is passed in, so it is storage-agnostic); see also `PMWPaymentStatusVerifierMock.verify`. The verifier is a standalone contract: users call `request{Account,Utxo}ConfiguredAttestation` on it, and the [`TeePayments`](../../../contracts/tee/implementation/TeePayments.sol) / [`TeePaymentsUtxo`](../../../contracts/tee/implementation/TeePaymentsUtxo.sol) payment contracts call `verify{Account,Utxo}ConfiguredProof` (which validates the proof and reverts on failure, returning nothing) and then persist account/anchor state read directly from the calldata proof.

Cosigner signatures use a separate preimage wrap [`Fdc2ProofVerification.toCosignersMessageHash`](../../../contracts/fdc2/library/Fdc2ProofVerification.sol) — `keccak256(0x010000000000 || messageHash)`. The 6-byte prefix is the [`Relay`](../../../contracts/protocol/implementation/Relay.sol) protocol-message wire format for `(protocolId=1, votingRoundId=0, isSecureRandom=false)`; aligning cosigner signatures with that format lets a cosigner who is also a signing-policy data signer use the same off-chain signing infrastructure with no special handling.

There is **no Merkle proof** in FDC2 — each TEE machine signs its response directly, and the consumer checks the signature(s). See [Fdc2](./Fdc2.md).
