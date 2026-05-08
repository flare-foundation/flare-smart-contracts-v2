# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

* Chainlink adapter for sFLR/USD
* stXRP custom feed (`StXrpCustomFeed`)
* ECDSA (P-256) signature support in `NodePossessionVerifier` (alongside existing RSA/PKCS1-v1.5)
* Chain id included in Voter(Pre)Registry registration message (cross-chain replay protection)
* `IVoterPreRegistry.getVoterSignature` view to retrieve a pre-registered voter's signature

### Changed

* Reward epoch id widened from `uint24` to `uint32` in `VoterRegistry`, `VoterPreRegistry`,
  and `FlareSystemsCalculator` events and view methods (ABI-breaking for indexers/clients)
* `VoterRegistered` event now emits `PublicKey` and `Signature` structs in place of
  `bytes32 publicKeyPart1/publicKeyPart2`
* `Signature` and `PublicKey` structs moved to shared interfaces `ISignature.sol` / `IPublicKey.sol`
* Solidity pragma relaxed from `0.8.20` to `^0.8.20` across the contracts
  (`NodePossessionVerifier` requires `^0.8.24` for the OpenZeppelin P-256 lib)
* Adopted named imports across all Solidity files

### Fixed

* Removed `unchecked` block in `SafePct.mulDivRoundUp` to prevent a potential overflow


## [[v1.2.0]((https://github.com/flare-foundation/flare-smart-contracts-v2/releases/tag/v1.2.0)])] - 2026-04-17

### Added

* XRPPayment and XRPPaymentNonexistence attestation types and verification

### Added

* Chainlink adapter for stFLR/USD

### Changed

* JOULE/USD feed delisted

## [[v1.1.0]((https://github.com/flare-foundation/flare-smart-contracts-v2/releases/tag/v1.1.0)])] - 2026-02-24

### Added

* Chainlink adapters
* Web2Json attestation type and verification

### Changed

* FdcVerification contract is now proxy based


## [[v1.0.3]((https://github.com/flare-foundation/flare-smart-contracts-v2/releases/tag/v1.0.3)])] - 2026-02-23

### Fixed

* Relay contract


## [[v1.0.2]((https://github.com/flare-foundation/flare-smart-contracts-v2/releases/tag/v1.0.2)])] - 2026-01-19

### Added

* NIGHT/USD feed integration


## [[v1.0.1]((https://github.com/flare-foundation/flare-smart-contracts-v2/releases/tag/v1.0.1)])] - 2026-01-08

### Added

* MON/USD feed integration

### Changed

* Updated PCT bands