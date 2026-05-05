# FDC Overview

The Flare Data Connector (FDC) brings external data — Bitcoin transactions, EVM-chain transactions, address validity, balance changes, JSON from arbitrary Web2 endpoints — onto Flare's EVM state, as confirmed attestations that consumer contracts can prove against.

This repo hosts **two** generations of FDC, both currently active:

| Module | Folder | Confirmation mechanism | Headline contract |
|--------|--------|------------------------|-------------------|
| **FDC** (legacy, "FDCv1" in some sources) | [`contracts/fdc/`](../../../contracts/fdc/) | Data-provider voting + bit-voting consensus + threshold-signed Merkle root | [`FdcHub`](../../../contracts/fdc/implementation/FdcHub.sol) |
| **FDC2** | [`contracts/fdc2/`](../../../contracts/fdc2/) | Direct routing to a set of TEE machines (FCC system extension) that sign the response | [`Fdc2Hub`](../../../contracts/fdc2/implementation/Fdc2Hub.sol) |

Both expose the same attestation-types catalog (`AddressValidity`, `BalanceDecreasingTransaction`, `ConfirmedBlockHeightExists`, `EVMTransaction`, `Payment`, `ReferencedPaymentNonexistence`, `Web2Json`) and use the same `(attestationType, sourceId)` keying. They differ in how a confirmation is produced and what the consumer verifies against.

## How FDC works (legacy)

Each voting epoch is one round of FDC. The lifecycle is shown in [Making a Request](./MakingARequest.md), [BitVote and Consensus](./BitVoteAndConsensus.md), and [Verification](./Verification.md). In one paragraph:

1. **Collect** — users call `FdcHub.requestAttestation(data)` with FLR ≥ the per-`(type, source)` minimum fee. The hub forwards the FLR to `RewardManager` and emits `AttestationRequest(data, fee)`.
2. **Choose** — providers verify each request off-chain (e.g. running a Bitcoin or EVM RPC), then submit a **bit-vote** through `Submission.submit2`: a packed bit-vector with one bit per request indicating "I can confirm this".
3. **Resolve** — providers run the consensus bit-vote algorithm (a deterministic branch-and-bound search) to converge on a single set of confirmed requests, build a Merkle tree of `keccak(abi.encode(response))` hashes, and threshold-sign the root. `Relay.relay()` writes the root.
4. **Consume** — consumer contracts call [`FdcVerification.verifyX`](../../../contracts/fdc/implementation/FdcVerification.sol) with `(response, merkleProof)` and trust the data once verification succeeds.

FDC has its own `protocolId` (typically `200`, but the value is settable in `FdcVerification` initialization) on `Relay`, distinct from FTSO's `100`.

## How FDC2 works

FDC2 skips the voting layer for the round and instead routes each request directly to a small set of **TEE machines** running an FCC system extension. The TEE machines each verify the request independently and return a signed response. Consumers verify either the FSP signing policy's signature over the response (cross-chain compatible — the response can come back through any chain that has access to the policy hash) or directly the TEE machines' signatures (Flare-only, but lighter weight).

The key contracts are [`Fdc2Hub`](../../../contracts/fdc2/implementation/Fdc2Hub.sol), [`Fdc2Verification`](../../../contracts/fdc2/implementation/Fdc2Verification.sol), and [`Fdc2RequestFeeConfigurations`](../../../contracts/fdc2/implementation/Fdc2RequestFeeConfigurations.sol). FDC2 leans heavily on FCC primitives — it sends the request as an FCC `Instruction` of operation type `FDC2` and lets the TEE management layer pick which machines participate. See [Fdc2](./Fdc2.md) for the full architecture.

## Code layout

```
contracts/fdc/
├── README.md                          # short FDC governance note
├── implementation/
│   ├── FdcHub.sol                     # request entry + inflation receiver
│   ├── FdcVerification.sol            # per-type Merkle proof verifiers (UUPS)
│   ├── FdcVerificationProxy.sol       # UUPS proxy
│   ├── FdcRequestFeeConfigurations.sol# per-(type, source) min-fee table
│   └── FdcInflationConfigurations.sol # which attestation types qualify for inflation
└── interface/                         # II* internal interfaces

contracts/fdc2/
├── implementation/
│   ├── Fdc2Hub.sol                    # request entry, routes to TEE machines (UUPS)
│   ├── Fdc2Verification.sol           # signing-policy + TEE signature verifiers (UUPS)
│   └── Fdc2RequestFeeConfigurations.sol  # per-(type, source) min-fee table (UUPS)
├── proxy/                             # UUPS proxies for the three above
├── structs/                           # shared FDC2 request/response structs
└── mock/                              # test mocks
```

Public interfaces for both modules live under [`contracts/userInterfaces/`](../../../contracts/userInterfaces/) — `IFdcHub`, `IFdcVerification`, `IFdcRequestFeeConfigurations`, `IFdcInflationConfigurations` for FDC; `IFdc2Hub`, `IFdc2Verification`, `IFdc2RequestFeeConfigurations` plus per-attestation-type interfaces under `userInterfaces/fdc/` and `userInterfaces/fdc2/` for both.

## When to use which

| Need | Choose |
|------|--------|
| Anyone-can-request attestations finalized once per voting epoch (90 s), with broadest provider participation | FDC |
| Latest attestation types (anything available in FCC system extension), faster turnaround when TEE machines are available, ability to require specific TEE machines or cosigners | FDC2 |
| Cross-chain bridging where attestation data must be verifiable on a different chain | FDC2 (signing-policy signatures verifiable anywhere the policy hash is known) |
| Low-trust legacy use cases written against the previous FDC interface | FDC (kept stable for compatibility) |

The two systems can run side-by-side; they share the [`(attestationType, sourceId)` taxonomy](./AttestationTypes.md) and the inflation accounting (`FdcHub` is the inflation receiver for **both** legacy FDC and FDC2 user-paid fees, since `Fdc2Hub` forwards fees to `RewardManager.receiveRewards` directly under the current reward epoch — there is no separate FDC2 inflation pool yet).
