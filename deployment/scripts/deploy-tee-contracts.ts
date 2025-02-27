/**
 * This script will deploy TEE contracts.
 */

import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ChainParameters } from "../chain-config/chain-parameters";
import { Contracts } from "./Contracts";
import { spewNewContractInfo } from "./deploy-utils";
import { TeeRegistryContract } from "../../typechain-truffle/contracts/tee/implementation/TeeRegistry";
import { TeeWalletManagerContract } from "../../typechain-truffle/contracts/tee/implementation/TeeWalletManager";
import { TeePaymentsContract } from "../../typechain-truffle/contracts/tee/implementation/TeePayments";
import { TeeInstructionsContract } from "../../typechain-truffle/contracts/tee/implementation/TeeInstructions";
import { TeeFeeCalculatorContract } from "../../typechain-truffle/contracts/tee/implementation/TeeFeeCalculator";
import { TeeRewardOffersManagerContract } from "../../typechain-truffle/contracts/tee/implementation/TeeRewardOffersManager";

export async function deployTeeContracts(
  hre: HardhatRuntimeEnvironment,
  oldContracts: Contracts,
  contracts: Contracts,
  parameters: ChainParameters,
  quiet: boolean = false
) {
  const web3 = hre.web3;
  const artifacts = hre.artifacts;

  const TeeRegistry: TeeRegistryContract = artifacts.require("TeeRegistry");
  const TeeWalletManager: TeeWalletManagerContract = artifacts.require("TeeWalletManager");
  const TeeFeeCalculator: TeeFeeCalculatorContract = artifacts.require("TeeFeeCalculator");
  const TeeInstructions: TeeInstructionsContract = artifacts.require("TeeInstructions");
  const TeeRewardOffersManager: TeeRewardOffersManagerContract = artifacts.require("TeeRewardOffersManager");
  const TeePayments: TeePaymentsContract = artifacts.require("TeePayments");

  // Define accounts in play for the deployment process
  let deployerAccount: any;

  try {
    deployerAccount = web3.eth.accounts.privateKeyToAccount(parameters.deployerPrivateKey);
  } catch (e) {
    throw Error("Check .env file, if the private keys are correct and are prefixed by '0x'.\n" + e);
  }

  // Wire up the default account that will do the deployment
  web3.eth.defaultAccount = deployerAccount.address;

  const governanceSettings = oldContracts.getContractAddress(Contracts.GOVERNANCE_SETTINGS);
  const addressUpdater = oldContracts.getContractAddress(Contracts.ADDRESS_UPDATER);
  const inflation = oldContracts.getContractAddress(Contracts.INFLATION);
  const flareSystemsManager = contracts.getContractAddress(Contracts.FLARE_SYSTEMS_MANAGER);
  const relay = contracts.getContractAddress(Contracts.RELAY);
  const rewardManager = contracts.getContractAddress(Contracts.REWARD_MANAGER);

  // deploy contracts
  const teeRegistry = await TeeRegistry.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address,
    parameters.teePauseBeforeUpgradeMinDurationSeconds,
    parameters.teeAvailabilityCheckValidityDurationSeconds,
    parameters.teeMinSupportedVersion
  );
  spewNewContractInfo(contracts, null, TeeRegistry.contractName, `TeeRegistry.sol`, teeRegistry.address, quiet);

  const teeWalletManager = await TeeWalletManager.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address
  );
  spewNewContractInfo(contracts, null, TeeWalletManager.contractName, `TeeWalletManager.sol`, teeWalletManager.address, quiet);

  const teeFeeCalculator = await TeeFeeCalculator.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address
  );
  spewNewContractInfo(contracts, null, TeeFeeCalculator.contractName, `TeeFeeCalculator.sol`, teeFeeCalculator.address, quiet);

  const teeRewardOffersManager = await TeeRewardOffersManager.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address,
    parameters.teeOwnersPPM
  );
  spewNewContractInfo(contracts, null, TeeRewardOffersManager.contractName, `TeeRewardOffersManager.sol`, teeRewardOffersManager.address, quiet);

  const operationTypes = [];
  const operationCommands = [];
  const operationFees = [];
  for (const teeOperationFee of parameters.teeOperationFees) {
    operationTypes.push(web3.utils.utf8ToHex(teeOperationFee.opType).padEnd(66, "0"));
    operationCommands.push(web3.utils.utf8ToHex(teeOperationFee.opCommand).padEnd(66, "0"));
    operationFees.push(teeOperationFee.feeWei);
  }
  await teeFeeCalculator.setOperationFees(operationTypes, operationCommands, operationFees);

  const teeInstructions = await TeeInstructions.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address
  );
  spewNewContractInfo(contracts, null, TeeInstructions.contractName, `TeeInstructions.sol`, teeInstructions.address, quiet);

  const teePaymentsList = [];
  for (const teePaymentConfig of parameters.teePaymentConfigurations) {
    const teePayments = await TeePayments.new(
      governanceSettings,
      deployerAccount.address,
      deployerAccount.address,
      teePaymentConfig.maxBatchSize,
      teePaymentConfig.maxBatchDurationSeconds,
      web3.utils.utf8ToHex(teePaymentConfig.opType).padEnd(66, "0"));
      teePaymentsList.push(teePayments);
    spewNewContractInfo(contracts, null, TeePayments.contractName + "_" + teePaymentConfig.opType, `TeePayments.sol`, teePayments.address, quiet);
  }

  // update contract addresses
  await teeRegistry.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_FEE_CALCULATOR, Contracts.TEE_INSTRUCTIONS, Contracts.FLARE_SYSTEMS_MANAGER, Contracts.RELAY]),
    [addressUpdater, teeFeeCalculator.address, teeInstructions.address, flareSystemsManager, relay]);

  await teeWalletManager.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_REGISTRY, Contracts.TEE_FEE_CALCULATOR, Contracts.TEE_INSTRUCTIONS, Contracts.FLARE_SYSTEMS_MANAGER]),
    [addressUpdater, teeRegistry.address, teeFeeCalculator.address, teeInstructions.address, flareSystemsManager]);

  await teeFeeCalculator.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_WALLET_MANAGER]),
    [addressUpdater, teeWalletManager.address]);

  await teeInstructions.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.REWARD_MANAGER]),
    [addressUpdater, rewardManager]);

  await teeRewardOffersManager.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.REWARD_MANAGER, Contracts.FLARE_SYSTEMS_MANAGER, Contracts.INFLATION]),
    [addressUpdater, rewardManager, flareSystemsManager, inflation]);

  for (const teePayments of teePaymentsList) {
    await teePayments.updateContractAddresses(
      encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_WALLET_MANAGER, Contracts.TEE_FEE_CALCULATOR, Contracts.FLARE_SYSTEMS_MANAGER]),
      [addressUpdater, teeWalletManager.address, teeFeeCalculator.address, flareSystemsManager]);
  }

  await teeInstructions.registerInstructionInitiators([teeRegistry.address, teeWalletManager.address, ...teePaymentsList.map(teePayments => teePayments.address)]);

  // switch to production mode
  await teeRegistry.switchToProductionMode();
  await teeWalletManager.switchToProductionMode();
  await teeFeeCalculator.switchToProductionMode();
  await teeInstructions.switchToProductionMode();
  await teeRewardOffersManager.switchToProductionMode();
  for (const teePayments of teePaymentsList) {
    await teePayments.switchToProductionMode();
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
