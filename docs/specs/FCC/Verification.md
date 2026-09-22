# Verification

A TEE machine's signed responses are only useful if you can **verify** them — confirm that the signing TEE is currently a trusted member of the system, that its software hasn't been replaced under your nose, and that the message it signed corresponds to the correct system state at the correct time.

Three FCC facets provide the on-chain verification layer:

- [`VerificationFacet`](../../../contracts/tee/facets/VerificationFacet.sol) + [`library/Verification`](../../../contracts/tee/library/Verification.sol) — the central verification logic for TEE attestation proofs and availability checks. State stored in `Verification.State` includes the per-machine challenge, challenge timestamp, and the per-machine validity window.
- [`library/SystemStateVerifier`](../../../contracts/tee/library/SystemStateVerifier.sol) — validates the TEE-attested system-state payload, which must now be **empty**, and requires the machine's stored `initialTeeId` to be zero. Consumed library-internally by `Verification._validateResponseBody`; not exposed as a diamond facet. See [System state verification](#system-state-verification).
- [`VrfFacet`](../../../contracts/tee/facets/VrfFacet.sol) + [`library/Vrf`](../../../contracts/tee/library/Vrf.sol) — VRF proof verification, plus a stand-alone [`VrfVerifier`](../../../contracts/tee/implementation/VrfVerifier.sol) contract (deployed directly, no proxy) for verification outside the diamond.

## The TEE attestation flow

When a TEE machine registers ([Machine Lifecycle / Registration](./MachineLifecycle.md#registration)) or transitions back to PRODUCTION, the contracts request an **availability check**:

1. `Verification.requestTeeAttestation` (called from `MachineManagerFacet.register` on registration, or from `VerificationFacet.requestTeeAttestation` for a re-attestation) generates a challenge:
   ```solidity
   bytes32 challenge = keccak256(abi.encode(_teeId, block.timestamp, randomNumber));
   s.challenges[_teeId] = challenge;
   s.challengeTs[_teeId] = block.timestamp;
   ```
   `randomNumber` comes from `Relay.getRandomNumber()` — the FSP secure random. The reuse branch requires an **outstanding** challenge (`challenges[teeId] != 0`) that is also still within `challengeValidityDurationSeconds`; otherwise a fresh one is minted. Both conditions matter: at registration, and after an invalidation, `challengeTs` is zero, and a zero `challengeTs` still reads as unexpired until `block.timestamp` grows past the validity duration — so testing the timestamp alone would re-issue the attestation instruction under a zero challenge, i.e. with no nonce at all.
2. It emits an `F_REG / TEE_ATTESTATION` system instruction directed at the TEE, with the `TeeAttestation` message body containing the machine's data and the challenge.
3. **Off-chain**: the TEE proxy forwards the instruction to the TEE machine, which:
   - Confirms the challenge is fresh (within the configured availability-check validity window).
   - Computes a self-attestation report (TEE platform-attested measurement, code hash, ID).
   - Signs the response message — the standard `ITeeAvailabilityCheck.Response` shape — with its TEE identity key.
4. The signed proof comes back through the off-chain layer and is presented to `MachineManagerFacet.toProduction(proof)` (the registration path) or `MachineManagerFacet.pauseWithProof(proof)` (the negative-attestation path).

`Verification.verifyAvailabilityCheckProof(teeMachine, status, proof)` does the on-chain verification:

- **Recover the signer** from `proof.signature` and confirm it's the machine's `teeId`.
- **Match the challenge** — `proof.requestBody.challenge == vs.challenges[teeId]`. A reused or wrong challenge fails.
- **Match the request body** to the on-chain machine data (`teeId`, `url`, `codeHash`, `platform`).
- **Validate timestamps** — the proof's `header.timestamp` must be ≥ the on-chain machine's `lastStatusChangeTs` (rejects stale proofs from before a recent status change).
- **Apply transition-specific rules** — e.g. for `INITIALIZED → PRODUCTION`, the proof's `responseBody.initialSigningPolicyId` is recorded as the machine's permanent anchor.

If everything checks, `Verification.extendAvailability(proof)` updates the validity window:

- `endTs = proof.header.timestamp + availabilityCheckValidityDurationSeconds` — typically a few hours.
- `lastSigningPolicyId = proof.responseBody.lastSigningPolicyId` — the signing policy the machine last attested to; its freshness is bounded by `signingPolicyValidityDurationInRewardEpochs` (see `Verification.isSigningPolicyValid`).

A machine whose availability check has expired (`endTs < block.timestamp`) can be permissionlessly suspended by anyone via `MachineManagerFacet.pause(teeId)` (see [Machine Lifecycle / Pausing](./MachineLifecycle.md#pausing)) — this is what keeps the network of attested machines fresh: TEE owners must re-attest periodically or risk being suspended. `pause` consults **only** `endTs`, not `lastSigningPolicyId`; a machine whose stored signing policy has gone stale can no longer re-attest (see the horizon below), so its `endTs` lapses on its own and it becomes suspendable through this same expiry path.

### Challenge invalidation

The challenge is a per-machine nonce, not a per-request one: `requestAvailabilityCheckAttestation` reuses whatever challenge is outstanding, so several FDC2 requests within one validity window all carry the same value. The freshness the contracts can check is therefore bounded by that window, and the proof's `header.timestamp` — which is the timestamp of the *request* block, a value every attester must agree on byte-for-byte to threshold-sign the same header — says when the check was asked for, not when the machine answered. (`ResponseBody.teeTimestamp` carries the enclave's own clock but is deliberately not consulted on chain, so validity never depends on a clock the contracts cannot bound.)

That combination means evidence gathered under one machine identity could otherwise be re-wrapped into a later request made under a different one: the owner rotates `teeProxyId` / `url`, the replacement proxy re-serves the older attestation result, and the new request's `header.timestamp` clears both `challengeTs` and `lastStatusChangeTs` — returning a machine to `PRODUCTION` without showing that the new endpoint is alive.

[`MachineManagerFacet.updateTeeMachineSettings`](../../../contracts/tee/facets/MachineManagerFacet.sol) therefore calls [`Verification.invalidateChallenge`](../../../contracts/tee/library/Verification.sol), which clears `challenges[teeId]` and `challengeTs[teeId]` together and emits `ChallengeInvalidated(teeId)`. Both fields go at once by necessity: `requestTeeAttestation` branches on `challengeTs` while `verifyAvailabilityCheckProof` matches `challenges`, so clearing only one would leave the two disagreeing — clearing just the challenge value would let the reuse branch hand out a zero nonce.

"No outstanding challenge" is then an explicit, checked state rather than something inferred from timestamp arithmetic. `requestAvailabilityCheckAttestation` and `verifyAvailabilityCheckProof` both require `challenges[teeId] != 0` and revert `NoOutstandingChallenge()` otherwise, ahead of the expiry checks. The machine recovers normally: a fresh `requestTeeAttestation` mints a new challenge whose `challengeTs` necessarily post-dates the settings change, so every subsequent proof is pinned to evidence requested under the new identity.

The residual, accepted: within a single challenge window and with no settings change, a cached response can still be re-submitted through a fresh request, because the nonce spans every request in that window. Closing that on chain would mean rotating the challenge per request, which anyone could use to grief an in-flight attestation — `requestAvailabilityCheckAttestation` is permissionless. The exposure is bounded by `challengeValidityDurationSeconds` (at most one hour, see [Verification settings](#verification-settings)) and only benefits the machine's own owner.

### Signing-policy freshness horizon

Every availability-check proof for a non-`INITIALIZED` machine is validated against the machine's **stored** `lastSigningPolicyId` (the value set by the last successful `extendAvailability`): `Verification._validateResponseBody` rejects the proof unless `storedLastSigningPolicyId + signingPolicyValidityDurationInRewardEpochs ≥ currentRewardEpochId`. This gate runs on both `confirmAvailability` (staying live) and `toProduction` (recovering from `PAUSED` / `SUSPENDED`), and the stored value is advanced only *after* a proof passes.

Consequence: **a machine that stays offline (`PAUSED` / `SUSPENDED`) longer than `signingPolicyValidityDurationInRewardEpochs` reward epochs can never return to `PRODUCTION`.** Once `currentRewardEpochId` passes `storedLastSigningPolicyId + signingPolicyValidityDurationInRewardEpochs`, the gate rejects every proof — including an otherwise-valid, freshly-signed one — and there is no path to advance the stored value (it is written only by a passing proof). The revert surfaces as the generic `InvalidResponseData`. The `teeId` is permanently retired — it cannot be reused, re-provisioned, or re-registered (`register` rejects an already-registered `teeId`, and `unban → PAUSED → toProduction` hits this same gate). The only way back into service is to **deploy an entirely new TEE machine** — a new instance with its own key, hence a new `teeId` — and register it fresh via the `INITIALIZED` path (which anchors to a current signing policy under the current cosigners).

This is intentional, not a liveness bug. While offline a machine is not relayed the intermediate signing policies; past the horizon the keys behind its last-known policies are assumed potentially compromised, so letting it "catch up" could allow a forged policy chain (signed with those compromised keys) to capture the TEE even though it presents a fresh, valid policy on-chain. `signingPolicyValidityDurationInRewardEpochs` is therefore also an operational signal: if TEEs are paused/offline beyond this window, wallet (PMW) owners should rotate keys off them rather than expect them to recover.

Enforcement is implicit — a stale machine simply fails to re-attest — so the point at which it actually drops out of the active views can lag the signing-policy staleness by up to one `availabilityCheckValidityDurationSeconds` (it keeps its last valid `endTs` until then). This holds only while that window is shorter than the horizon; see the configuration invariant under [Verification settings](#verification-settings).

## System state verification

`SystemStateVerifier.verifyTeeSystemState(teeId, systemStateVersion, systemState)` is invoked from `Verification._validateResponseBody` for every availability-check proof. The TEE-signed system-state payload must be **empty**, and the machine's stored `initialTeeId` must be zero:

```solidity
// library/SystemStateVerifier.sol
return _stateVersion == bytes32(0) &&
    _state.length == 0 &&
    MachineManager.getInitialTeeId(_teeId) == address(0);
```

Concretely:

- `systemStateVersion` must be `bytes32(0)`.
- `systemState` must be empty (`length == 0`).
- `MachineManager.getInitialTeeId(teeId)` must be `address(0)` — which it always is, because `initialTeeId` is a dormant field (see [Machine Lifecycle / Registration](./MachineLifecycle.md#registration)).

Any non-empty payload is rejected. The `systemState` / `systemStateVersion` fields are still carried on the [`ITeeAvailabilityCheck`](../../../contracts/userInterfaces/fdc2/ITeeAvailabilityCheck.sol) response (`TeeState`), but the TEE must leave them empty for the proof to validate.

The library is exposed only as a library (`SystemStateVerifier`), not as a diamond facet. No production contract calls the verifier through the diamond — `Verification._validateResponseBody` consumes it directly as a library call.

### Why `initialTeeId` is retained

`initialTeeId` is preserved on-chain (in `MachineManager.TeeMachineState`, `getInitialTeeId`, and `IMachineManager.TeeMachineWithAttestationData`) as a dormant field — it is `address(0)` for every machine. Keeping the slot in storage means functionality that depends on a per-machine provisioning identity can be re-introduced later without a storage-layout migration on the deployed diamond. Off-chain consumers of an availability-check proof can read it via `IMachineManager.getTeeMachineWithAttestationData(teeId).initialTeeId`; today it always reads zero.

## VRF

`VrfFacet` exposes the VRF request side (see [Key Management / VRF](./KeyManagement.md#vrf)). The verification side has two paths:

- **Inside the diamond**: `VrfFacet` itself can verify a returned VRF proof against the wallet's public key and the original seed.
- **Stand-alone**: [`VrfVerifier`](../../../contracts/tee/implementation/VrfVerifier.sol) is a separate, stateless contract — deployed directly, outside the diamond, with no proxy or upgrade path. Consumers call it directly, passing the VRF proof together with the prover's public key and the nonce; it verifies the proof and returns a boolean — useful for application contracts that want to verify VRF outputs without depending on a specific facet selector.

VRF verification follows standard ECVRF: given `(publicKey, seed, output, proof)`, check that the proof is a valid Schnorr-style demonstration that `output = VRF(privateKey, seed)`. Failed verification returns `false` (or reverts with `InvalidVrfProof()` depending on entry point).

## Verification settings

Three governance-tunable durations live in `Verification.State`:

| Setting | Default | What it bounds |
|---------|---------|----------------|
| `availabilityCheckValidityDurationSeconds` | A few hours | How long an availability-check proof keeps the machine valid before re-attestation is needed. |
| `signingPolicyValidityDurationInRewardEpochs` | A few reward epochs | How many reward epochs after attestation a machine remains valid — the [signing-policy horizon](#signing-policy-freshness-horizon) that gates re-attestation and recovery (independent of the seconds-based bound). |
| `challengeValidityDurationSeconds` | Short (minutes) | How long a fresh challenge can be answered before it expires and a new one must be requested. |

Set at diamond init (`FlareTeeManagerInit.init`) and updatable by governance via `VerificationFacet`.

**Configuration invariant.** Keep `availabilityCheckValidityDurationSeconds ≤ signingPolicyValidityDurationInRewardEpochs × (reward-epoch length)`. The time-based window (`endTs`) is what removes a stale machine from service; the signing-policy horizon is what blocks its recovery. The design relies on the time window lapsing *before* the epoch horizon, so a machine can never be simultaneously "still time-valid" and "signing-policy-stale". If `availabilityCheckValidityDurationSeconds` were set longer than the horizon, a machine could keep a valid `endTs` — staying in the active views and selectable — after it can no longer re-attest, and would be un-removable via `pause` until that `endTs` finally lapsed. This relationship is **not enforced on-chain**: `updateSettings` bounds the two independently (`availabilityCheckValidityDurationSeconds ∈ [1h, 365d]`, `signingPolicyValidityDurationInRewardEpochs ∈ [1, 100]`), and the reward-epoch length lives in `FlareSystemsManager` — so governance must preserve it. Production values honor it with margin: on Flare/Songbird `availabilityCheckValidityDurationSeconds` = one reward epoch (302400s) against a 10-epoch horizon; on Coston/Coston2 it is one reward epoch (6h) against a 100-epoch horizon.

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
- `Verification.getAvailabilityCheckValidity(teeId)` — `(endTs, lastSigningPolicyId)`.
- The current `Verification.State.challenges[teeId]` (queryable via a view method on `VerificationFacet` — see source).

Off-chain monitoring tools build dashboards from these to show "next availability check due at X", "machine valid until reward epoch Y", "current pending challenge: Z".
