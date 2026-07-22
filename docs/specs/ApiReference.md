# API Reference

A pointer index from each module to its public `userInterfaces/I*.sol` files. Consumer contracts and integrators should code against these `I*` interfaces, not the implementation contracts directly — the interfaces are the stability surface; implementations may be upgraded behind their proxies.

The internal `II*` interfaces (under `contracts/protocol/interface/`, `contracts/tee/interface/`, etc.) are *not* part of the integration surface and are subject to change without notice.

## Cross-cutting

| Interface | What it exposes |
|-----------|-----------------|
| [`IAddressUpdatable`](../../contracts/userInterfaces/IAddressUpdatable.sol) | The `_updateContractAddresses` callback shape used by every contract that takes addresses from the AddressUpdater. |
| [`IGovernor`](../../contracts/userInterfaces/IGovernor.sol) | On-chain proposal lifecycle — `castVote`, `castVoteWithReason`, `castVoteBySig`, `cancel`, `state`, `execute`. See [Governance](./Governance.md). |
| [`IPollingManagementGroup`](../../contracts/userInterfaces/IPollingManagementGroup.sol) | The management-group polling variant. |
| [`IPublicKey`](../../contracts/userInterfaces/IPublicKey.sol) | The `PublicKey` struct used across signing-policy snapshots, voter registration, TEE machine identities. |
| [`ISignature`](../../contracts/userInterfaces/ISignature.sol) | The `(v, r, s)` signature struct used in submission, signing, and verification methods system-wide. |
| [`IRandomProvider`](../../contracts/userInterfaces/IRandomProvider.sol) | `getCurrentRandom`, `getCurrentRandomWithQuality`, `getCurrentRandomWithQualityAndTimestamp`. Implemented by `Submission` and (transitively) `Relay`. See [FSP / RandomNumber](./FSP/RandomNumber.md). |
| [`ISortition`](../../contracts/userInterfaces/ISortition.sol) | Helpers for sortition-credential verification (used by FTSO fast updates). |
| [`IFixedPointArithmetic`](../../contracts/userInterfaces/IFixedPointArithmetic.sol) | Type wrappers (`Scale`, `SampleSize`, `Range`, `Fee`, etc.) used by the fast-updates incentive layer. |

## FSP (Flare Systems Protocol)

| Interface | Role |
|-----------|------|
| [`IFlareSystemsManager`](../../contracts/userInterfaces/IFlareSystemsManager.sol) | Reward-epoch lifecycle, signing-policy/uptime/rewards signing, view methods. |
| [`IFlareSystemsCalculator`](../../contracts/userInterfaces/IFlareSystemsCalculator.sol) | `wNatCapPPM`, signing-policy-signing duration getters, `VoterRegistrationInfo` event. |
| [`IEntityManager`](../../contracts/userInterfaces/IEntityManager.sol) | Entity / address propose-confirm flow, node ID and public key registration, history-aware lookups. |
| [`IVoterRegistry`](../../contracts/userInterfaces/IVoterRegistry.sol) | `registerVoter`, slot enumeration, normalized weights, chilling. |
| [`IVoterPreRegistry`](../../contracts/userInterfaces/IVoterPreRegistry.sol) | `preRegisterVoter`, status views. |
| [`ISubmission`](../../contracts/userInterfaces/ISubmission.sol) | `submit1`, `submit2`, `submit3`, `submitSignatures`, `submitAndPass`. |
| [`IRelay`](../../contracts/userInterfaces/IRelay.sol) | `relay`, `verify`, `merkleRoots`, `getRandomNumber`, `getRandomNumberHistorical`, `toSigningPolicyHash`. |
| [`IRewardManager`](../../contracts/userInterfaces/IRewardManager.sol) | `autoClaim`, `initialiseWeightBasedClaims`, `getStateOfRewardsAt`, `getUnclaimedRewardState`, reward-epoch totals/views. |
| [`IWNat`](../../contracts/userInterfaces/IWNat.sol) | The wrapped-native-token interface (the WNat contract itself lives in the v1 repo). |
| [`IWNatDelegationFee`](../../contracts/userInterfaces/IWNatDelegationFee.sol) | Voter delegation-fee schedule. |

The legacy / long-term-support compatibility interfaces are under [`userInterfaces/LTS/`](../../contracts/userInterfaces/LTS/) — `RewardsV2Interface`, `ProtocolsV2Interface`, `RandomNumberV2Interface`, `FtsoV2Interface`. Consumers needing legacy ABIs should look there.

## FTSO

| Interface | Role |
|-----------|------|
| [`IFtsoFeedPublisher`](../../contracts/userInterfaces/IFtsoFeedPublisher.sol) | `publish`, `getCurrentFeed`, `getFeed` for anchor-feed publication and lookup. |
| [`IFtsoFeedDecimals`](../../contracts/userInterfaces/IFtsoFeedDecimals.sol) | Per-feed decimals with reward-epoch-offset updates. |
| [`IFtsoFeedIdConverter`](../../contracts/userInterfaces/IFtsoFeedIdConverter.sol) | `(category, name)` ↔ `bytes21` conversion. |
| [`IFtsoInflationConfigurations`](../../contracts/userInterfaces/IFtsoInflationConfigurations.sol) | Per-reward-epoch FTSO config (default feeds, IQR shares, secondary band widths). |
| [`IFtsoRewardOffersManager`](../../contracts/userInterfaces/IFtsoRewardOffersManager.sol) | `offerRewards` for community offers; `minimalRewardsOfferValueWei` getter. |
| [`IFastUpdater`](../../contracts/userInterfaces/IFastUpdater.sol) | `submitUpdates`, `fetchCurrentFeeds`, `fetchAllCurrentFeeds`, sortition-data views. |
| [`IFastUpdatesConfiguration`](../../contracts/userInterfaces/IFastUpdatesConfiguration.sol) | Block-latency feed catalog management. |
| [`IFastUpdateIncentiveManager`](../../contracts/userInterfaces/IFastUpdateIncentiveManager.sol) | `offerIncentive`, sample-size / range / scale / precision views. |
| [`IIncreaseManager`](../../contracts/userInterfaces/IIncreaseManager.sol) | Base for sample-size and range increases. |
| [`IFeeCalculator`](../../contracts/userInterfaces/IFeeCalculator.sol) | Per-feed read fees used by `FastUpdater.fetchCurrentFeeds`. |

The public `FtsoV2` reader (UUPS proxy) at [`FtsoV2Interface`](../../contracts/userInterfaces/LTS/FtsoV2Interface.sol) is the recommended entry point for application contracts. See [FTSO / Overview](./FTSO/Overview.md).

## FDC

Public hub and verification:

| Interface | Role |
|-----------|------|
| [`IFdcHub`](../../contracts/userInterfaces/IFdcHub.sol) | `requestAttestation`. |
| [`IFdcVerification`](../../contracts/userInterfaces/IFdcVerification.sol) | Aggregate verification interface (see per-attestation interfaces below). |
| [`IFdcRequestFeeConfigurations`](../../contracts/userInterfaces/IFdcRequestFeeConfigurations.sol) | Per-(type, source) fee table. |
| [`IFdcInflationConfigurations`](../../contracts/userInterfaces/IFdcInflationConfigurations.sol) | Per-attestation-type inflation share configurations. |

Per-attestation-type interfaces under [`userInterfaces/fdc/`](../../contracts/userInterfaces/fdc/):

- `IAddressValidity` + `IAddressValidityVerification`
- `IBalanceDecreasingTransaction` + `IBalanceDecreasingTransactionVerification`
- `IConfirmedBlockHeightExists` + `IConfirmedBlockHeightExistsVerification`
- `IEVMTransaction` + `IEVMTransactionVerification`
- `IPayment` + `IPaymentVerification`
- `IReferencedPaymentNonexistence` + `IReferencedPaymentNonexistenceVerification`
- `IWeb2Json` + `IWeb2JsonVerification`

## FDC2

| Interface | Role |
|-----------|------|
| [`IFdc2Hub`](../../contracts/userInterfaces/fdc2/IFdc2Hub.sol) | `requestAttestation` with TEE selection, cosigner threshold, `claimBackAddress`. |
| [`IFdc2Verification`](../../contracts/userInterfaces/fdc2/IFdc2Verification.sol) | `verifySigningPolicySignatures`, `verifyTeeSignature(s)`, `recoverCosigners`. |
| [`IFdc2RequestFeeConfigurations`](../../contracts/userInterfaces/fdc2/IFdc2RequestFeeConfigurations.sol) | Per-(type, source) fee table for FDC2. |
| [`IFdc2InflationConfigurations`](../../contracts/userInterfaces/fdc2/IFdc2InflationConfigurations.sol) | Per-attestation-type inflation share configurations for FDC2. |
| [`IFdc2RewardOffersManager`](../../contracts/userInterfaces/fdc2/IFdc2RewardOffersManager.sol) | FDC2 inflation receiver and reward-offers emitter. |

Per-attestation-type interfaces under [`userInterfaces/fdc2/`](../../contracts/userInterfaces/fdc2/) — `ITeeAvailabilityCheck`, `IPMWFeeProof`, `IPMWMultisigAccountConfigured`, `IPMWMultisigUtxoConfigured`, `IPMWPaymentStatus`.

## FCC

Around 30 public interfaces under [`userInterfaces/tee/`](../../contracts/userInterfaces/tee/), roughly one per facet:

| Interface | Role |
|-----------|------|
| [`IFlareTeeManager`](../../contracts/userInterfaces/tee/IFlareTeeManager.sol) | The diamond's combined external interface. |
| [`IDiamondGovernance`](../../contracts/userInterfaces/tee/IDiamondGovernance.sol) | The DiamondGovernanceFacet's public API; re-exports the Flare governance accessors via `IFlareGovernance` (`diamondCut` lives in the internal interface). |
| [`IFlareGovernance`](../../contracts/userInterfaces/IFlareGovernance.sol) | `Governed` accessors — implemented by `FlareGovernedBase` (used by `FlareUpgradeableBase`) and by the TEE diamond's `DiamondGovernanceFacet`. |
| [`IExtensionManager`](../../contracts/userInterfaces/tee/IExtensionManager.sol) | Extension registration (public `register` and governance-only `registerReserved`), `nextPublicExtensionId` getter, version management, two-step ownership transfer gated by the global extension-owner allowlist, and the optional `setExtensionOperator` / `getExtensionOperator` prep-helper role. |
| [`IExtensionGovernance`](../../contracts/userInterfaces/tee/IExtensionGovernance.sol) | Per-extension governance signer-set + threshold management (plain signer sets or Safe-backed snapshots read live from a Safe multisig); signer / threshold / hash / Safe-address getters. |
| [`IExternalAddresses`](../../contracts/userInterfaces/tee/IExternalAddresses.sol) | The diamond's `AddressUpdatable` view. |
| [`IInstructions`](../../contracts/userInterfaces/tee/IInstructions.sol) | `sendInstructions`, `getSystemInstructionsSenders` registry view. |
| [`IMachineManager`](../../contracts/userInterfaces/tee/IMachineManager.sol) | Machine registration, status changes, ownership transfer. |
| [`IMachineEmergencyPause`](../../contracts/userInterfaces/tee/IMachineEmergencyPause.sol) | Per-extension emergency pause overlay + pauser/unpauser delegation lists + governance-tunable post-unpause grace window for the third-party expired-availability `pause()` branch. |
| [`IOperationFees`](../../contracts/userInterfaces/tee/IOperationFees.sol) | Per-`(opType, opCommand)` fees, default fee, and the `calculateFeeByTeeIds` / `calculateFeeByWalletId` fee estimators (the latter resolves a wallet's deduplicated receiving TEEs). |
| [`IOwnerAllowlist`](../../contracts/userInterfaces/tee/IOwnerAllowlist.sol) | Global extension-owner allowlist (governance-gated; gates `register()` and ownership transfer); per-extension TEE machine owner and wallet project owner allowlists (extension-owner-gated). |
| [`IMachinePathManager`](../../contracts/userInterfaces/tee/IMachinePathManager.sol) | Per-extension governance-signed allow-list of `(sourceTeeIds[], destinationTeeIds[])` paths — the generic primitive that gates [`IWalletBackupManager.directBackup` / `directRestore`](../../contracts/userInterfaces/tee/IWalletBackupManager.sol). Approved by EOA signatures (`signMachinePathList`) or by a registered Safe multisig calling `approveMachinePathList`. |
| [`IVerification`](../../contracts/userInterfaces/tee/IVerification.sol) | TEE attestation / availability-check verification. |
| [`IVrf`](../../contracts/userInterfaces/tee/IVrf.sol), [`IVrfVerifier`](../../contracts/userInterfaces/tee/IVrfVerifier.sol) | VRF request and verification. |
| [`IWalletManager`](../../contracts/userInterfaces/tee/IWalletManager.sol), [`IWalletKeyManager`](../../contracts/userInterfaces/tee/IWalletKeyManager.sol), [`IWalletBackupManager`](../../contracts/userInterfaces/tee/IWalletBackupManager.sol), [`IWalletProjectManager`](../../contracts/userInterfaces/tee/IWalletProjectManager.sol), [`IWalletProjectPause`](../../contracts/userInterfaces/tee/IWalletProjectPause.sol) | Wallet / key / project lifecycle. `IWalletProjectPause` exposes per-project pauser/unpauser delegation lists and the batch `pauseWallets` / `unpauseWallets` actions. |
| [`IOwnerAllowlist`](../../contracts/userInterfaces/tee/IOwnerAllowlist.sol), [`ITeeIdKeyIdPair`](../../contracts/userInterfaces/tee/ITeeIdKeyIdPair.sol), [`ITeeCommonErrors`](../../contracts/userInterfaces/tee/ITeeCommonErrors.sol) | Auxiliary types and error catalogs. |
| [`ITeePaymentsBase`](../../contracts/userInterfaces/tee/ITeePaymentsBase.sol), [`ITeePayments`](../../contracts/userInterfaces/tee/ITeePayments.sol), [`ITeePaymentsUtxo`](../../contracts/userInterfaces/tee/ITeePaymentsUtxo.sol), [`ITeePaymentsModel`](../../contracts/userInterfaces/tee/ITeePaymentsModel.sol) | Payment-stream accounting (outside the diamond). `ITeePaymentsBase` holds the shared `pay`/`reissue` surface, the read-only `getPaymentFee(account, opCommand)` fee pre-flight, plus the common structs and errors; `ITeePayments` (account model) and `ITeePaymentsUtxo` (UTXO/anchor) add their model-specific structs, events and errors (`ITeePaymentsModel.paymentModel()` discriminates). |
| [`ITeePaymentsConfigVerifier`](../../contracts/userInterfaces/tee/ITeePaymentsConfigVerifier.sol) | Shared contract that **requests and verifies** PMW multisig configuration attestations for both the account and UTXO models. Users call `request{Account,Utxo}ConfiguredAttestation` here directly; the payment contracts call `verify{Account,Utxo}ConfiguredProof` (validate-only — it reverts on an invalid proof and returns nothing) and write account/anchor state read directly from the calldata proof. |
| [`ITeePaymentsFeeScheduleManager`](../../contracts/userInterfaces/tee/ITeePaymentsFeeScheduleManager.sol), [`ITeePaymentsRegistry`](../../contracts/userInterfaces/tee/ITeePaymentsRegistry.sol) | Shared fee-schedule registry and the `sourceId → TeePayments` registry. |
| [`IAddressValidator`](../../contracts/userInterfaces/tee/IAddressValidator.sol) | Validates a payment's recipient address against the chain/network configured (by governance) for its `sourceId`. `isValidAddress(sourceId, address)` is called from `TeePayments`/`TeePaymentsUtxo` `pay`; fail-closed for unconfigured sources. Backed by stateless per-chain validation libraries (Bitcoin Base58Check + Bech32/Bech32m, Dogecoin Base58Check, XRPL classic/X-address, EVM EIP-55). |
| [`ITeeRewardOffersManager`](../../contracts/userInterfaces/tee/ITeeRewardOffersManager.sol) | FCC inflation receiver. |
| [`ITeeExtensionStateVerifier`](../../contracts/userInterfaces/tee/ITeeExtensionStateVerifier.sol) | Extension-specific state verification interface. |

## Staking, RNat, Inflation

| Interface | Role |
|-----------|------|
| [`IValidatorRewardOffersManager`](../../contracts/userInterfaces/IValidatorRewardOffersManager.sol) | Validator-staking inflation receiver. |
| [`IRNat`](../../contracts/userInterfaces/IRNat.sol) | RNat manager — projects, monthly assignment, claim flow. |
| [`IRNatAccount`](../../contracts/userInterfaces/IRNatAccount.sol) | Per-recipient personal account: vesting state, withdrawal. |

Inflation receivers and incentive-pool receivers don't expose their own `I*` user interface — they implement the v1 `IIInflationReceiver` / `IIIncentivePoolReceiver` from the v1 repo. The integration surface for "is this contract an inflation receiver?" is checking whether the contract responds to those interfaces.

## Adapters and custom feeds

| Interface | Role |
|-----------|------|
| [`AggregatorV3Interface`](../../contracts/adapters/interface/AggregatorV3Interface.sol) | Chainlink-compatible price-feed wrapper. Implemented by `ChainlinkAdapter`. |
| [`IICustomFeed`](../../contracts/customFeeds/interface/IICustomFeed.sol) | The internal interface a custom feed contract must implement to be registered with `FtsoV2`. |

## What's *not* part of the API

- The internal `II*` interfaces under `contracts/*/interface/`. Those are reserved for cross-contract calls within this repo.
- The implementation contracts directly. Implementations may be replaced by governance UUPS upgrades; only the proxy address (which exposes the `I*` interface) is stable.
- Storage-layout details. ERC-7201 namespaced storage in FCC means the Solidity-level field names are stable, but there is no commitment to specific slot positions.
- Library functions. The `library/*.sol` files are linked at compile time into facets; they have no addresses and no ABI surface.

If you need to call something not covered by an `I*` interface, you're probably depending on an implementation detail. Open an issue describing the use case before integrating against it.
