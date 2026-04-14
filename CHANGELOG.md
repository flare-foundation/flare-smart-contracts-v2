# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

* TEE Manager Diamond proxy (EIP-2535) with Forge deploy and diamond cut scripts
* FDC2, TeePayments, TeeRewardOffersManager, VrfVerifier contracts and deploy pipeline

### Changed

* JOULE/USD feed delisted
* Migrated package manager from yarn to pnpm
* Upgraded Node.js to v24, tsconfig target to ES2024, module to Node20
* Adopted `@flarenetwork/eslint-config-flare` and `@flarenetwork/prettier-config-flare`
* Upgraded solhint to v6 with updated config
* Added `lint:check`, `lint:fix`, `format:check`, `format:fix`, `build`, `test` scripts
* Converted all unnamed Solidity imports to named imports
* Removed unused imports across contracts and tests

## [v1.1.0](https://github.com/flare-foundation/flare-smart-contracts-v2/releases/tag/v1.1.0) - 2026-02-24

### Added

* Chainlink adapters
* Web2Json attestation type and verification

### Changed

* FdcVerification contract is now proxy based

## [v1.0.3](https://github.com/flare-foundation/flare-smart-contracts-v2/releases/tag/v1.0.3) - 2026-02-23

### Fixed

* Relay contract

## [v1.0.2](https://github.com/flare-foundation/flare-smart-contracts-v2/releases/tag/v1.0.2) - 2026-01-19

### Added

* NIGHT/USD feed integration

## [v1.0.1](https://github.com/flare-foundation/flare-smart-contracts-v2/releases/tag/v1.0.1) - 2026-01-08

### Added

* MON/USD feed integration

### Changed

* Updated PCT bands
