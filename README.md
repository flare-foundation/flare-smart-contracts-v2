<p align="left">
  <a href="https://flare.network/" target="blank"><img src="https://content.flare.network/Flare-2.svg" width="300" alt="Flare Logo" /></a>
</p>

# Flare Systems Protocol - Smart Contracts

[About](#about) | [Contributing](./CONTRIBUTING.md) | [Security](./SECURITY.md) | [Changelog](./CHANGELOG.md)

## About

The Flare Systems Protocol (FSP) is a foundational infrastructure designed to support Flare's enshrined protocols (sub-protocols).

This repository implements solidity contracts for Flare Systems Protocol (FSP) and its sub-protocols, including Flare Time Series Oracle (FTSO), Flare Data Connector (FDC), and Trusted Execution Environment (TEE) management.

A comprehensive diagram of all V1 and V2 smart contracts is available [here](https://content.flare.network/flare-smart-contracts-v1-v2-all_with_background.svg).

## Documentation

In-tree protocol documentation lives under [`docs/specs/`](./docs/specs/) — start at the [index](./docs/specs/index.md) for navigation. The docs cover FSP, FTSO, FDC + FDC2, FCC, plus governance / staking / RNat / inflation, all written code-first against the contracts on this branch.

## Development and contribution

If you want to use FTSO or FDC in your project, start on [developer hub - FTSO](https://dev.flare.network/ftso/overview) or [developer hub - FDC](https://dev.flare.network/fdc/overview).

You can also reach out to us on [discord](https://discord.com/invite/flarenetwork).

If you're interested in contributing, please see [CONTRIBUTING.md](./CONTRIBUTING.md).

### Toolchain

Building and testing requires:

- **Node** >= 24
- **Solidity** 0.8.35 or newer — auto-downloaded by both toolchains; 0.8.35 is the floor, required for the built-in `erc7201(...)` storage-slot helper used by the TEE / diamond / governance contracts. Hardhat is pinned to 0.8.35; forge picks the newest compatible release it has, currently 0.8.36
- **Foundry** nightly `eb4bf9b4` or later — `stable` (v1.7.1) carries solc 0.8.35 but predates two things this repo needs: solar >= v0.2.0, without which `forge build` rejects the `erc7201(...)` builtin, and [foundry-rs/foundry#16100](https://github.com/foundry-rs/foundry/pull/16100), without which `forge coverage` silently drops sources on this repo's coverage profile and reports a wrong figure. Install with `foundryup --install nightly-eb4bf9b4a0ca13f5e3ed5b5be221f37bff56a4f9`
- **LCOV** >= 2.0 (2.3.1 tested) — `pnpm coverage-forge` uses the system `lcov` and `genhtml`; 1.x rejects the `--ignore-errors inconsistent` the script passes (`brew install lcov` / `apt install lcov`)
- **Hardhat** 2.28.6 (pinned) — earlier 2.x mis-resolves solc 0.8.35 to the `0.8.35-pre.1` prerelease listed first upstream; Hardhat 3.x is a breaking rewrite and is not supported

## Security

If you have found a possible vulnerability please see [SECURITY.md](./SECURITY.md).
