/**
 * This script will deploy the FlareTeeManager Diamond and remaining TEE UUPS proxies.
 */

import { HardhatRuntimeEnvironment } from "hardhat/types";
import {
  Fdc2HubContract,
  Fdc2HubProxyContract,
  Fdc2RequestFeeConfigurationsContract,
  Fdc2RequestFeeConfigurationsProxyContract,
  Fdc2VerificationContract,
  Fdc2VerificationProxyContract,
  TeeAddressUpdatableFacetContract,
  TeeExtensionRegistryFacetContract,
  TeePaymentsContract,
  TeePaymentsInstance,
  TeePaymentsProxyContract,
  TeeRewardOffersManagerContract,
  VrfVerifierContract,
} from "../../typechain-truffle";
import { ChainParameters } from "../chain-config/chain-parameters";
import { Contracts } from "./Contracts";
import { spewNewContractInfo } from "./deploy-utils";
import { deployFlareTeeManager } from "./deploy-flare-tee-manager";
import { Account } from "web3-core";

export async function deployTeeContracts(
  hre: HardhatRuntimeEnvironment,
  oldContracts: Contracts,
  contracts: Contracts,
  parameters: ChainParameters,
  quiet: boolean = false
) {
  const web3 = hre.web3;
  const artifacts = hre.artifacts;

  // Import contract artifacts
  const Fdc2Hub = artifacts.require("Fdc2Hub") as Fdc2HubContract;
  const Fdc2HubProxy = artifacts.require("Fdc2HubProxy") as Fdc2HubProxyContract;
  const Fdc2RequestFeeConfigurations = artifacts.require("Fdc2RequestFeeConfigurations") as Fdc2RequestFeeConfigurationsContract;
  const Fdc2RequestFeeConfigurationsProxy = artifacts.require("Fdc2RequestFeeConfigurationsProxy") as Fdc2RequestFeeConfigurationsProxyContract;
  const Fdc2Verification = artifacts.require("Fdc2Verification") as Fdc2VerificationContract;
  const Fdc2VerificationProxy = artifacts.require("Fdc2VerificationProxy") as Fdc2VerificationProxyContract;

  const TeePayments = artifacts.require("TeePayments") as TeePaymentsContract;
  const TeePaymentsProxy = artifacts.require("TeePaymentsProxy") as TeePaymentsProxyContract;
  const TeeRewardOffersManager = artifacts.require("TeeRewardOffersManager") as TeeRewardOffersManagerContract;

  const VrfVerifier = artifacts.require("VrfVerifier") as VrfVerifierContract;

  // Define accounts in play for the deployment process
  let deployerAccount: Account;

  try {
    deployerAccount = web3.eth.accounts.privateKeyToAccount(parameters.deployerPrivateKey);
  } catch (e) {
    throw Error("Check .env file, if the private keys are correct and are prefixed by '0x'.\n" + String(e));
  }

  // Wire up the default account that will do the deployment
  web3.eth.defaultAccount = deployerAccount.address;

  const governanceSettings = oldContracts.getContractAddress(Contracts.GOVERNANCE_SETTINGS);
  const addressUpdater = oldContracts.getContractAddress(Contracts.ADDRESS_UPDATER);
  const inflation = oldContracts.getContractAddress(Contracts.INFLATION);
  const flareSystemsManager = contracts.getContractAddress(Contracts.FLARE_SYSTEMS_MANAGER);
  const relay = contracts.getContractAddress(Contracts.RELAY);
  const rewardManager = contracts.getContractAddress(Contracts.REWARD_MANAGER);

  // =========================================================================
  // 1. Deploy FlareTeeManager Diamond (all TEE functionality consolidated)
  // =========================================================================
  const flareTeeManagerAddress = await deployFlareTeeManager(
    hre, oldContracts, contracts, parameters, quiet
  );

  // =========================================================================
  // 2. Deploy FDC2 contracts (separate UUPS proxies)
  // =========================================================================

  // Fdc2Hub
  const fdc2HubImpl = await Fdc2Hub.new();
  spewNewContractInfo(contracts, null, "Fdc2HubImplementation", `Fdc2Hub.sol`, fdc2HubImpl.address, quiet);
  const fdc2HubProxy = await Fdc2HubProxy.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address,
    parameters.fdc2MinThresholdBIPS,
    parameters.fdc2DefaultNumberOfTees,
    fdc2HubImpl.address
  );
  const fdc2Hub = await Fdc2Hub.at(fdc2HubProxy.address);
  spewNewContractInfo(contracts, null, Fdc2Hub.contractName, `Fdc2HubProxy.sol`, fdc2HubProxy.address, quiet);

  // Fdc2RequestFeeConfigurations
  const fdc2RequestFeeConfigurationsImpl = await Fdc2RequestFeeConfigurations.new();
  spewNewContractInfo(contracts, null, "Fdc2RequestFeeConfigurationsImplementation", `Fdc2RequestFeeConfigurations.sol`, fdc2RequestFeeConfigurationsImpl.address, quiet);
  const fdc2RequestFeeConfigurationsProxy = await Fdc2RequestFeeConfigurationsProxy.new(
    governanceSettings,
    deployerAccount.address,
    fdc2RequestFeeConfigurationsImpl.address
  );
  const fdc2RequestFeeConfigurations = await Fdc2RequestFeeConfigurations.at(fdc2RequestFeeConfigurationsProxy.address);
  spewNewContractInfo(contracts, null, Fdc2RequestFeeConfigurations.contractName, `Fdc2RequestFeeConfigurationsProxy.sol`, fdc2RequestFeeConfigurationsProxy.address, quiet);

  // Fdc2Verification
  const fdc2VerificationImpl = await Fdc2Verification.new();
  spewNewContractInfo(contracts, null, "Fdc2VerificationImplementation", `Fdc2Verification.sol`, fdc2VerificationImpl.address, quiet);
  const fdc2VerificationProxy = await Fdc2VerificationProxy.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address,
    fdc2VerificationImpl.address
  );
  const fdc2Verification = await Fdc2Verification.at(fdc2VerificationProxy.address);
  spewNewContractInfo(contracts, null, Fdc2Verification.contractName, `Fdc2VerificationProxy.sol`, fdc2VerificationProxy.address, quiet);

  // =========================================================================
  // 3. Deploy remaining TEE UUPS proxies
  // =========================================================================

  // TeePayments (multiple instances per chain)
  const teePaymentsList: TeePaymentsInstance[] = [];
  const teePaymentsImpl = await TeePayments.new();
  spewNewContractInfo(contracts, null, "TeePaymentsImplementation", `TeePayments.sol`, teePaymentsImpl.address, quiet);
  for (const teePaymentConfig of parameters.teePaymentConfigurations) {
    const teePaymentsProxy = await TeePaymentsProxy.new(
      governanceSettings,
      deployerAccount.address,
      deployerAccount.address,
      teePaymentConfig.maxBatchSize,
      teePaymentConfig.maxBatchDurationSeconds,
      web3.utils.utf8ToHex(teePaymentConfig.opType).padEnd(66, "0"),
      web3.utils.utf8ToHex(teePaymentConfig.keyType).padEnd(66, "0"),
      teePaymentConfig.sourceIds.map((sourceId: string) => web3.utils.utf8ToHex(sourceId).padEnd(66, "0")),
      teePaymentsImpl.address
    );
    const teePayments = await TeePayments.at(teePaymentsProxy.address);
    teePaymentsList.push(teePayments);
    spewNewContractInfo(contracts, null, "TeePayments_" + teePaymentConfig.opType, `TeePaymentsProxy.sol`, teePaymentsProxy.address, quiet);
  }

  // TeeRewardOffersManager
  const teeRewardOffersManager = await TeeRewardOffersManager.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address,
    parameters.teeOwnersPPM
  );
  spewNewContractInfo(contracts, null, TeeRewardOffersManager.contractName, `TeeRewardOffersManager.sol`, teeRewardOffersManager.address, quiet);

  // VrfVerifier
  const vrfVerifier = await VrfVerifier.new();
  spewNewContractInfo(contracts, null, VrfVerifier.contractName, `VrfVerifier.sol`, vrfVerifier.address, quiet);

  // =========================================================================
  // 4. Wire up contract addresses
  // =========================================================================

  // FlareTeeManager gets ONE updateContractAddresses call resolving only external addresses
  const TeeAddressUpdatableFacet = artifacts.require("TeeAddressUpdatableFacet") as TeeAddressUpdatableFacetContract;
  const flareTeeManagerUpdatable = await TeeAddressUpdatableFacet.at(flareTeeManagerAddress);
  await flareTeeManagerUpdatable.updateContractAddresses(
    encodeContractNames([
      Contracts.ADDRESS_UPDATER,
      Contracts.FLARE_SYSTEMS_MANAGER,
      Contracts.REWARD_MANAGER,
      Contracts.RELAY,
      Contracts.FDC2_HUB,
      Contracts.FDC2_VERIFICATION,
    ]),
    [addressUpdater, flareSystemsManager, rewardManager, relay, fdc2Hub.address, fdc2Verification.address],
  );

  // Fdc2Hub references single FlareTeeManager
  await fdc2Hub.updateContractAddresses(
    encodeContractNames([
      Contracts.ADDRESS_UPDATER,
      Contracts.FLARE_TEE_MANAGER,
      Contracts.FLARE_SYSTEMS_MANAGER,
      Contracts.REWARD_MANAGER,
      Contracts.FDC2_REQUEST_FEE_CONFIGURATIONS,
    ]),
    [addressUpdater, flareTeeManagerAddress, flareSystemsManager, rewardManager, fdc2RequestFeeConfigurations.address],
  );

  // Fdc2Verification references single FlareTeeManager
  await fdc2Verification.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.FLARE_TEE_MANAGER, Contracts.RELAY]),
    [addressUpdater, flareTeeManagerAddress, relay],
  );

  // TeePayments references single FlareTeeManager
  for (const teePayments of teePaymentsList) {
    await teePayments.updateContractAddresses(
      encodeContractNames([
        Contracts.ADDRESS_UPDATER,
        Contracts.FLARE_TEE_MANAGER,
        Contracts.FLARE_SYSTEMS_MANAGER,
      ]),
      [addressUpdater, flareTeeManagerAddress, flareSystemsManager]
    );
  }

  // TeeRewardOffersManager
  await teeRewardOffersManager.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.REWARD_MANAGER, Contracts.FLARE_SYSTEMS_MANAGER, Contracts.INFLATION]),
    [addressUpdater, rewardManager, flareSystemsManager, inflation]
  );

  // Register system instructions senders on FlareTeeManager
  const TeeExtensionRegistryFacet = artifacts.require("TeeExtensionRegistryFacet") as TeeExtensionRegistryFacetContract;
  const teeExtensionRegistry = await TeeExtensionRegistryFacet.at(flareTeeManagerAddress);
  await teeExtensionRegistry.registerSystemInstructionsSenders([
    ...teePaymentsList.map((teePayments: TeePaymentsInstance) => teePayments.address),
    fdc2Hub.address,
  ]);

  // Set FDC2 request fee configurations
  for (const fdc2RequestFee of parameters.fdc2RequestFees) {
    await fdc2RequestFeeConfigurations.setTypeAndSourceFee(
      web3.utils.utf8ToHex(fdc2RequestFee.attestationType).padEnd(66, "0"),
      web3.utils.utf8ToHex(fdc2RequestFee.source).padEnd(66, "0"),
      fdc2RequestFee.feeWei
    );
  }

  contracts.serialize();
  if (!quiet) {
    console.error("Deploy complete.");
  }

  function encodeContractNames(names: string[]): string[] {
    return names.map(name => encodeString(name));
  }

  function encodeString(text: string): string {
    return web3.utils.keccak256(web3.eth.abi.encodeParameters(["string"], [text]));
  }
}
