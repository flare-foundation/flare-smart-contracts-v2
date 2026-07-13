# Flare Data Connector (FDC + FDC2)

FDC attests to data outside Flare's EVM state — Bitcoin transactions, EVM transactions on other chains, address validity, balance changes, and so on — by having data providers vote on the validity of attestation requests. Confirmed attestations are delivered as Merkle roots that consumer contracts on Flare prove against.

This section covers both the legacy [`contracts/fdc/`](../../../contracts/fdc/) module and the newer [`contracts/fdc2/`](../../../contracts/fdc2/) module.

## Documents

- [Overview](./Overview.md) — request → bitvote → finalize → consume, end-to-end
- [Making a request](./MakingARequest.md) — `FdcHub`, request encoding, fee configuration
- [BitVote and consensus](./BitVoteAndConsensus.md) — how providers converge on a bitmap of valid requests
- [Verification](./Verification.md) — `FdcVerification` and how consumer contracts prove attestation data
- [Rewarding](./Rewarding.md) — FDC reward offers and inflation configurations
- [Attestation types](./AttestationTypes.md) — per-type encoding and verification (AddressValidity, BalanceDecreasingTransaction, ConfirmedBlockHeightExists, EVMTransaction, Payment, ReferencedPaymentNonexistence, Web2Json)
- [FDC2](./Fdc2.md) — what FDC2 is, how it differs from FDC, where TEE-backed verification fits in (`Fdc2Hub`, `Fdc2Verification`, `Fdc2RequestFeeConfigurations`)

## Key contracts

- Legacy FDC: contracts under [`contracts/fdc/implementation/`](../../../contracts/fdc/implementation/)
- FDC2: contracts under [`contracts/fdc2/implementation/`](../../../contracts/fdc2/implementation/)
