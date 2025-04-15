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
import { TeeWalletBackupManagerContract } from "../../typechain-truffle/contracts/tee/implementation/TeeWalletBackupManager";
import { TeePaymentsEVMContract } from "../../typechain-truffle/contracts/tee/implementation/TeePaymentsEVM";
import { TeeWalletProjectManagerContract } from "../../typechain-truffle/contracts/tee/implementation/TeeWalletProjectManager";
import { TeeVersionManagerContract } from "../../typechain-truffle/contracts/tee/implementation/TeeVersionManager";
import { TeeGovernanceContract } from "../../typechain-truffle/contracts/tee/implementation/TeeGovernance";
import { TeeWalletKeyManagerContract } from "../../typechain-truffle/contracts/tee/implementation/TeeWalletKeyManager";
import { FtdcHubContract } from "../../typechain-truffle/contracts/ftdc/implementation/FtdcHub";
import { FtdcRequestFeeConfigurationsContract } from "../../typechain-truffle/contracts/ftdc/implementation/FtdcRequestFeeConfigurations";
import { FtdcVerificationContract } from "../../typechain-truffle/contracts/ftdc/implementation/FtdcVerification";

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
  const TeeGovernance: TeeGovernanceContract = artifacts.require("TeeGovernance");
  const TeeVersionManager: TeeVersionManagerContract = artifacts.require("TeeVersionManager");
  const TeeRegistry: TeeRegistryContract = artifacts.require("TeeRegistry");
  const TeeWalletProjectManager: TeeWalletProjectManagerContract = artifacts.require("TeeWalletProjectManager");
  const TeeWalletManager: TeeWalletManagerContract = artifacts.require("TeeWalletManager");
  const TeeWalletKeyManager: TeeWalletKeyManagerContract = artifacts.require("TeeWalletKeyManager");
  const TeeWalletBackupManager: TeeWalletBackupManagerContract = artifacts.require("TeeWalletBackupManager");
  const TeeFeeCalculator: TeeFeeCalculatorContract = artifacts.require("TeeFeeCalculator");
  const TeeInstructions: TeeInstructionsContract = artifacts.require("TeeInstructions");
  const TeeRewardOffersManager: TeeRewardOffersManagerContract = artifacts.require("TeeRewardOffersManager");
  const TeePayments: TeePaymentsContract = artifacts.require("TeePayments");
  const TeePaymentsEVM: TeePaymentsEVMContract = artifacts.require("TeePaymentsEVM");
  const FtdcHub: FtdcHubContract = artifacts.require("FtdcHub");
  const FtdcRequestFeeConfigurations: FtdcRequestFeeConfigurationsContract = artifacts.require("FtdcRequestFeeConfigurations");
  const FtdcVerification: FtdcVerificationContract = artifacts.require("FtdcVerification");

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
  const teeGovernance = await TeeGovernance.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address
  );
  spewNewContractInfo(contracts, null, TeeGovernance.contractName, `TeeGovernance.sol`, teeGovernance.address, quiet);

  const teeVersionManager = await TeeVersionManager.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address
  );
  spewNewContractInfo(contracts, null, TeeVersionManager.contractName, `TeeVersionManager.sol`, teeVersionManager.address, quiet);

  const teeRegistry = await TeeRegistry.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address,
    parameters.teePauseBeforeUpgradeMinDurationSeconds,
    parameters.teeAvailabilityCheckProofValiditySeconds,
    parameters.teeAvailabilityCheckValidityDurationSeconds
  );
  spewNewContractInfo(contracts, null, TeeRegistry.contractName, `TeeRegistry.sol`, teeRegistry.address, quiet);

  const teeWalletProjectManager = await TeeWalletProjectManager.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address
  );
  spewNewContractInfo(contracts, null, TeeWalletProjectManager.contractName, `TeeWalletProjectManager.sol`, teeWalletProjectManager.address, quiet);

  const teeWalletManager = await TeeWalletManager.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address
  );
  spewNewContractInfo(contracts, null, TeeWalletManager.contractName, `TeeWalletManager.sol`, teeWalletManager.address, quiet);

  const teeWalletKeyManager = await TeeWalletKeyManager.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address,
    parameters.teeKeyExistenceProofValiditySeconds
  );
  spewNewContractInfo(contracts, null, TeeWalletKeyManager.contractName, `TeeWalletKeyManager.sol`, teeWalletKeyManager.address, quiet);

  const teeWalletBackupManager = await TeeWalletBackupManager.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address
  );
  spewNewContractInfo(contracts, null, TeeWalletBackupManager.contractName, `TeeWalletBackupManager.sol`, teeWalletBackupManager.address, quiet);

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
    const isEVM = teePaymentConfig.opType === "EVM";
    const Contract = isEVM ? TeePaymentsEVM : TeePayments;
    const teePayments = await Contract.new(
      governanceSettings,
      deployerAccount.address,
      deployerAccount.address,
      teePaymentConfig.maxBatchSize,
      teePaymentConfig.maxBatchDurationSeconds,
      web3.utils.utf8ToHex(teePaymentConfig.opType).padEnd(66, "0")
    );
    teePaymentsList.push(teePayments);
    spewNewContractInfo(contracts, null, Contract.contractName + "_" + teePaymentConfig.opType, `TeePayments${isEVM ? "EVM" : ""}.sol`, teePayments.address, quiet);
  }

  const ftdcHub = await FtdcHub.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address,
    parameters.ftdcMinThresholdBIPS,
    parameters.ftdcDefaultNumberOfTees
  );
  spewNewContractInfo(contracts, null, FtdcHub.contractName, `FtdcHub.sol`, ftdcHub.address, quiet);

  const ftdcRequestFeeConfigurations = await FtdcRequestFeeConfigurations.new(
    governanceSettings,
    deployerAccount.address
  );
  spewNewContractInfo(contracts, null, FtdcRequestFeeConfigurations.contractName, `FtdcRequestFeeConfigurations.sol`, ftdcRequestFeeConfigurations.address, quiet);

  const ftdcVerification = await FtdcVerification.new(
    deployerAccount.address
  );
  spewNewContractInfo(contracts, null, FtdcVerification.contractName, `FtdcVerification.sol`, ftdcVerification.address, quiet);

  // update contract addresses
  await teeGovernance.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER]),
    [addressUpdater]);

  await teeVersionManager.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_GOVERNANCE]),
    [addressUpdater, teeGovernance.address]);

  await teeRegistry.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_VERSION_MANAGER, Contracts.TEE_FEE_CALCULATOR, Contracts.TEE_INSTRUCTIONS, Contracts.FTDC_HUB, Contracts.FTDC_VERIFICATION, Contracts.FLARE_SYSTEMS_MANAGER, Contracts.RELAY]),
    [addressUpdater, teeVersionManager.address, teeFeeCalculator.address, teeInstructions.address, ftdcHub.address, ftdcVerification.address, flareSystemsManager, relay]);

  await teeWalletProjectManager.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_WALLET_MANAGER]),
    [addressUpdater, teeWalletManager.address]);

  await teeWalletManager.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_WALLET_PROJECT_MANAGER, Contracts.TEE_WALLET_KEY_MANAGER]),
    [addressUpdater, teeWalletProjectManager.address, teeWalletKeyManager.address]);

  await teeWalletKeyManager.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_REGISTRY, Contracts.TEE_WALLET_PROJECT_MANAGER, Contracts.TEE_WALLET_MANAGER, Contracts.TEE_FEE_CALCULATOR, Contracts.TEE_INSTRUCTIONS, Contracts.FTDC_HUB, Contracts.FTDC_VERIFICATION, Contracts.FLARE_SYSTEMS_MANAGER]),
    [addressUpdater, teeRegistry.address, teeWalletProjectManager.address, teeWalletManager.address, teeFeeCalculator.address, teeInstructions.address, ftdcHub.address, ftdcVerification.address, flareSystemsManager]);

  await teeWalletBackupManager.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_REGISTRY, Contracts.TEE_WALLET_PROJECT_MANAGER, Contracts.TEE_WALLET_MANAGER, Contracts.TEE_WALLET_KEY_MANAGER, Contracts.TEE_FEE_CALCULATOR, Contracts.TEE_INSTRUCTIONS, Contracts.FLARE_SYSTEMS_MANAGER]),
    [addressUpdater, teeRegistry.address, teeWalletProjectManager.address, teeWalletManager.address, teeWalletKeyManager.address, teeFeeCalculator.address, teeInstructions.address, flareSystemsManager]);

  await teeFeeCalculator.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_WALLET_KEY_MANAGER]),
    [addressUpdater, teeWalletKeyManager.address]);

  await teeInstructions.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.REWARD_MANAGER]),
    [addressUpdater, rewardManager]);

  await teeRewardOffersManager.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.REWARD_MANAGER, Contracts.FLARE_SYSTEMS_MANAGER, Contracts.INFLATION]),
    [addressUpdater, rewardManager, flareSystemsManager, inflation]);

  for (const teePayments of teePaymentsList) {
    await teePayments.updateContractAddresses(
      encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_WALLET_PROJECT_MANAGER, Contracts.TEE_WALLET_MANAGER, Contracts.TEE_WALLET_KEY_MANAGER, Contracts.TEE_FEE_CALCULATOR, Contracts.TEE_INSTRUCTIONS, Contracts.FLARE_SYSTEMS_MANAGER]),
      [addressUpdater, teeWalletProjectManager.address, teeWalletManager.address, teeWalletKeyManager.address, teeFeeCalculator.address, teeInstructions.address, flareSystemsManager]);
  }

  await ftdcHub.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_REGISTRY, Contracts.TEE_FEE_CALCULATOR, Contracts.TEE_INSTRUCTIONS, Contracts.FLARE_SYSTEMS_MANAGER, Contracts.FTDC_REQUEST_FEE_CONFIGURATIONS]),
    [addressUpdater, teeRegistry.address, teeFeeCalculator.address, teeInstructions.address, flareSystemsManager, ftdcRequestFeeConfigurations.address],
  );

  await ftdcVerification.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_REGISTRY, Contracts.RELAY]),
    [addressUpdater, teeRegistry.address, relay],
  );

  // add supported operation types
  await teeWalletManager.addSupportedOpTypes(
    teePaymentsList.map(teePayments => teePayments.address)
  );

  // register instruction initiators
  await teeInstructions.registerInstructionInitiators([
    teeRegistry.address,
    teeWalletManager.address,
    teeWalletKeyManager.address,
    teeWalletBackupManager.address,
    ...teePaymentsList.map(teePayments => teePayments.address),
    ftdcHub.address,
  ]);

  // set FTDC request fee configurations
  for (const ftdcRequestFee of parameters.ftdcRequestFees) {
    await ftdcRequestFeeConfigurations.setTypeAndSourceFee(
      web3.utils.utf8ToHex(ftdcRequestFee.attestationType).padEnd(66, "0"),
      web3.utils.utf8ToHex(ftdcRequestFee.source).padEnd(66, "0"),
      ftdcRequestFee.feeWei
    );
  }

  // switch to production mode
  await teeGovernance.switchToProductionMode();
  await teeVersionManager.switchToProductionMode();
  await teeRegistry.switchToProductionMode();
  await teeWalletProjectManager.switchToProductionMode();
  await teeWalletManager.switchToProductionMode();
  await teeWalletBackupManager.switchToProductionMode();
  await teeFeeCalculator.switchToProductionMode();
  await teeInstructions.switchToProductionMode();
  await teeRewardOffersManager.switchToProductionMode();
  for (const teePayments of teePaymentsList) {
    await teePayments.switchToProductionMode();
  }
  await ftdcHub.switchToProductionMode();
  await ftdcRequestFeeConfigurations.switchToProductionMode();

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
