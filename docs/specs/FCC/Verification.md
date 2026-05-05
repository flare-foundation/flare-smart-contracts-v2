# Verification

A TEE machine's signed responses are only useful if you can **verify** them — confirm that the signing TEE is currently a trusted member of the system, that its software hasn't been replaced under your nose, and that the message it signed corresponds to the correct system state at the correct time.

Three FCC facets provide the on-chain verification layer:

- [`VerificationFacet`](../../../contracts/tee/facets/VerificationFacet.sol) + [`library/Verification`](../../../contracts/tee/library/Verification.sol) — the central verification logic for TEE attestation proofs and availability checks. State stored in `Verification.State` includes the per-machine challenge, challenge timestamp, and the per-machine validity window.
- [`SystemStateVerifierFacet`](../../../contracts/tee/facets/SystemStateVerifierFacet.sol) + [`library/SystemStateVerifier`](../../../contracts/tee/library/SystemStateVerifier.sol) — verifies that a TEE-signed message is *consistent with the on-chain system state* at the time the TEE signed it (signing policy, FCC parameters).
- [`VrfFacet`](../../../contracts/tee/facets/VrfFacet.sol) + [`library/Vrf`](../../../contracts/tee/library/Vrf.sol) — VRF proof verification, plus an external [`VrfVerifier`](../../../contracts/tee/implementation/VrfVerifier.sol) UUPS contract for stand-alone verification outside the diamond.

## The TEE attestation flow

When a TEE machine registers ([Machine Lifecycle / Registration](./MachineLifecycle.md#registration)) or transitions back to PRODUCTION, the contracts request an **availability check**:

1. `MachineManagerFacet._requestTeeAttestation` generates a fresh challenge:
   ```solidity
   bytes32 challenge = keccak256(abi.encode(_teeId, block.timestamp, randomNumber));
   vs.challenges[_teeId] = challenge;
   vs.challengeTs[_teeId] = block.timestamp;
   ```
   `randomNumber` comes from `Relay.getRandomNumber()` — the FSP secure random.
2. It emits an `F_REG / TEE_ATTESTATION` system instruction directed at the TEE, with the `TeeAttestation` message body containing the machine's data and the challenge.
3. **Off-chain**: the TEE proxy forwards the instruction to the TEE machine, which:
   - Confirms the challenge is fresh (within the configured availability-check validity window).
   - Computes a self-attestation report (TEE platform-attested measurement, code hash, ID).
   - Signs the response message — the standard `ITeeAvailabilityCheck.Response` shape — with its TEE identity key.
4. The signed proof comes back through the off-chain layer and is presented to `MachineManagerFacet.toProduction(proof)` (the registration path) or `MachineManagerFacet.pauseWithProof(proof)` (the negative-attestation path).

`Verification.verifyAvailabilityCheckProof(teeMachine, status, proof)` does the on-chain verification:

- **Recover the signer** from `proof.signature` and confirm it's the machine's `teeId` (or, for some statuses, the signer is allowed to be a machine in the same replication group).
- **Match the challenge** — `proof.requestBody.challenge == vs.challenges[teeId]`. A reused or wrong challenge fails.
- **Match the request body** to the on-chain machine data (`teeId`, `initialTeeId`, `url`, `codeHash`, `platform`).
- **Validate timestamps** — the proof's `header.timestamp` must be ≥ the on-chain machine's `lastStatusChangeTs` (rejects stale proofs from before a recent status change).
- **Apply transition-specific rules** — e.g. for `INITIALIZED → PRODUCTION`, the proof's `responseBody.initialSigningPolicyId` is recorded as the machine's permanent anchor.

If everything checks, `Verification.extendAvailability(proof)` updates the validity window:

- `endTs = proof.header.timestamp + availabilityCheckValidityDurationSeconds` — typically a few hours.
- `endRewardEpoch = currentRewardEpoch + signingPolicyValidityDurationInRewardEpochs` — typically a few reward epochs.

A machine with an expired availability check (`endTs < block.timestamp` or `currentRewardEpoch > endRewardEpoch`) can be permissionlessly suspended by anyone via `MachineManagerFacet.pause(teeId)` (see [Machine Lifecycle / Pausing](./MachineLifecycle.md#pausing)) — this is what keeps the network of attested machines fresh: TEE owners must re-attest periodically or risk being suspended.

## System state verification

A TEE-signed message that references on-chain state must *correctly* reference that state. `SystemStateVerifierFacet` checks that:

- The signing policy hash referenced in the message matches the on-chain hash for the cited reward epoch.
- The reward epoch in the message is one the machine was registered for (the message's `signingPolicyId ≥ machine.initialSigningPolicyId`).
- Any extension-specific state references (FCC parameters, fee schedules) match the on-chain values at the cited timestamp.

Used internally by `Verification` (the availability-check flow uses `SystemStateVerifier` to cross-check that the TEE knows about the right signing policy) and externally exposed for consumer contracts that need to verify TEE-signed messages without going through the standard FDC2 / wallet flow.

## VRF

`VrfFacet` exposes the VRF request side (see [Key Management / VRF](./KeyManagement.md#vrf)). The verification side has two paths:

- **Inside the diamond**: `VrfFacet` itself can verify a returned VRF proof against the wallet's public key and the original seed.
- **Stand-alone**: [`VrfVerifier`](../../../contracts/tee/implementation/VrfVerifier.sol) is a separate UUPS contract that consumers can call directly. It reads the relevant TEE machine's public key from the diamond and verifies the supplied VRF proof — useful for application contracts that want to verify VRF outputs without depending on a specific facet selector.

VRF verification follows standard ECVRF: given `(publicKey, seed, output, proof)`, check that the proof is a valid Schnorr-style demonstration that `output = VRF(privateKey, seed)`. Failed verification returns `false` (or reverts with `InvalidVrfProof()` depending on entry point).

## Verification settings

Three governance-tunable durations live in `Verification.State`:

| Setting | Default | What it bounds |
|---------|---------|----------------|
| `availabilityCheckValidityDurationSeconds` | A few hours | How long an availability-check proof keeps the machine valid before re-attestation is needed. |
| `signingPolicyValidityDurationInRewardEpochs` | A few reward epochs | How many reward epochs after attestation a machine remains valid (independent of the seconds-based bound). |
| `challengeValidityDurationSeconds` | Short (minutes) | How long a fresh challenge can be answered before it expires and a new one must be requested. |

Set at diamond init (`FlareTeeManagerInit.init`) and updatable by governance via `VerificationFacet`.

## What the verification layer does *not* do

- **Does not verify TEE platform-vendor attestation.** The TEE's hardware attestation report (e.g. Intel SGX quotes, AMD SEV-SNP attestation) is verified *off-chain* by the TEE proxy and the relay clients before they sign a relay client signature. The on-chain layer trusts the threshold of relay clients to have done that work — the on-chain check is on the *combined* system attestation, not the raw vendor attestation.
- **Does not verify the operation result itself.** When a TEE signs an XRPL transaction, the on-chain side doesn't check the transaction was correct — it just confirms the signing TEE is currently a trusted member. Whether the transaction does what the application wanted is a consumer-side check (and for FDC2 attestations, the final per-attestation-type verification happens in `Fdc2Verification.verifyTeeSignatures` plus application-layer checks of the response body).
- **Does not handle key custody.** Private keys never appear in any verification path — only public keys, addresses, and signatures.

## How `Fdc2Verification` plugs in

[`Fdc2Verification`](../../../contracts/fdc2/implementation/Fdc2Verification.sol) is a thin wrapper that checks "is this `signingTeeId` a `PRODUCTION` member of the system extension?" It calls into the diamond:

```solidity
flareTeeManager.getExtensionId(signingTeeId) == 0   // system extension
flareTeeManager.getTeeMachineStatus(signingTeeId) == PRODUCTION
```

It does *not* call into `Verification` because the FDC2 message format already carries its own protocol-specific signing scheme (see [FDC / FDC2](../FDC/Fdc2.md#fdc2verification-verifying-responses)). The diamond's verification layer is for the more elaborate availability-check / system-state flows internal to FCC.

## Reading the live state

For each TEE:

- `MachineManagerFacet.getTeeMachineWithAttestationData(teeId)` — `codeHash`, `platform`, `url`, `initialTeeId`.
- `Verification.getAvailabilityCheckValidity(teeId)` — `(endTs, endRewardEpoch)`.
- The current `Verification.State.challenges[teeId]` (queryable via a view method on `VerificationFacet` — see source).

Off-chain monitoring tools build dashboards from these to show "next availability check due at X", "machine valid until reward epoch Y", "current pending challenge: Z".
