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
import { TeeGovernanceProxyContract, TeeInstructionsProxyContract, TeePaymentsProxyContract, TeeRegistryProxyContract, TeeVersionManagerProxyContract, TeeWalletBackupManagerProxyContract, TeeWalletKeyManagerProxyContract, TeeWalletManagerProxyContract, TeeWalletProjectManagerProxyContract } from "../../typechain-truffle";
import { TeeVerificationContract } from "../../typechain-truffle/contracts/tee/implementation/TeeVerification";
import { TeeVerificationProxyContract } from "../../typechain-truffle/contracts/tee/implementation/TeeVerificationProxy";
import { TeeOwnerAllowlistContract } from "../../typechain-truffle/contracts/tee/implementation/TeeOwnerAllowlist";
import { TeeStateVerifierContract } from "../../typechain-truffle/contracts/tee/implementation/TeeStateVerifier";
import { TeeStateVerifierProxyContract } from "../../typechain-truffle/contracts/tee/implementation/TeeStateVerifierProxy";

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
  const TeeOwnerAllowlist: TeeOwnerAllowlistContract = artifacts.require("TeeOwnerAllowlist");
  const TeeGovernance: TeeGovernanceContract = artifacts.require("TeeGovernance");
  const TeeGovernanceProxy: TeeGovernanceProxyContract = artifacts.require("TeeGovernanceProxy");
  const TeeVersionManager: TeeVersionManagerContract = artifacts.require("TeeVersionManager");
  const TeeVersionManagerProxy: TeeVersionManagerProxyContract = artifacts.require("TeeVersionManagerProxy");
  const TeeVerification: TeeVerificationContract = artifacts.require("TeeVerification");
  const TeeVerificationProxy: TeeVerificationProxyContract = artifacts.require("TeeVerificationProxy");
  const TeeStateVerifier: TeeStateVerifierContract = artifacts.require("TeeStateVerifier");
  const TeeStateVerifierProxy: TeeStateVerifierProxyContract = artifacts.require("TeeStateVerifierProxy");
  const TeeRegistry: TeeRegistryContract = artifacts.require("TeeRegistry");
  const TeeRegistryProxy: TeeRegistryProxyContract = artifacts.require("TeeRegistryProxy");
  const TeeWalletProjectManager: TeeWalletProjectManagerContract = artifacts.require("TeeWalletProjectManager");
  const TeeWalletProjectManagerProxy: TeeWalletProjectManagerProxyContract = artifacts.require("TeeWalletProjectManagerProxy");
  const TeeWalletManager: TeeWalletManagerContract = artifacts.require("TeeWalletManager");
  const TeeWalletManagerProxy: TeeWalletManagerProxyContract = artifacts.require("TeeWalletManagerProxy");
  const TeeWalletKeyManager: TeeWalletKeyManagerContract = artifacts.require("TeeWalletKeyManager");
  const TeeWalletKeyManagerProxy: TeeWalletKeyManagerProxyContract = artifacts.require("TeeWalletKeyManagerProxy");
  const TeeWalletBackupManager: TeeWalletBackupManagerContract = artifacts.require("TeeWalletBackupManager");
  const TeeWalletBackupManagerProxy: TeeWalletBackupManagerProxyContract = artifacts.require("TeeWalletBackupManagerProxy");
  const TeeFeeCalculator: TeeFeeCalculatorContract = artifacts.require("TeeFeeCalculator");
  const TeeInstructions: TeeInstructionsContract = artifacts.require("TeeInstructions");
  const TeeInstructionsProxy: TeeInstructionsProxyContract = artifacts.require("TeeInstructionsProxy");
  const TeeRewardOffersManager: TeeRewardOffersManagerContract = artifacts.require("TeeRewardOffersManager");
  const TeePayments: TeePaymentsContract = artifacts.require("TeePayments");
  const TeePaymentsProxy: TeePaymentsProxyContract = artifacts.require("TeePaymentsProxy");
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
  const teeOwnerAllowlist = await TeeOwnerAllowlist.new(
    governanceSettings,
    deployerAccount.address
  );
  spewNewContractInfo(contracts, null, "TeeOwnerAllowlist", `TeeOwnerAllowlist.sol`, teeOwnerAllowlist.address, quiet);

  const teeGovernanceImpl = await TeeGovernance.new();
  spewNewContractInfo(contracts, null, "TeeGovernanceImplementation", `TeeGovernance.sol`, teeGovernanceImpl.address, quiet);
  const teeGovernanceProxy = await TeeGovernanceProxy.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address,
    teeGovernanceImpl.address
  );
  const teeGovernance = await TeeGovernance.at(teeGovernanceProxy.address);
  spewNewContractInfo(contracts, null, TeeGovernance.contractName, `TeeGovernanceProxy.sol`, teeGovernanceProxy.address, quiet);

  const teeVersionManagerImpl = await TeeVersionManagerProxy.new();
  spewNewContractInfo(contracts, null, "TeeVersionManagerImplementation", `TeeVersionManager.sol`, teeVersionManagerImpl.address, quiet);
  const teeVersionManagerProxy = await TeeVersionManagerProxy.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address,
    teeVersionManagerImpl.address
  );
  const teeVersionManager = await TeeVersionManager.at(teeVersionManagerProxy.address);
  spewNewContractInfo(contracts, null, TeeVersionManager.contractName, `TeeVersionManagerProxy.sol`, teeVersionManagerProxy.address, quiet);

  const teeVerificationImpl = await TeeVerification.new();
  spewNewContractInfo(contracts, null, "TeeVerificationImplementation", `TeeVerification.sol`, teeVerificationImpl.address, quiet);
  const teeVerificationProxy = await TeeVerificationProxy.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address,
    parameters.teeAvailabilityCheckValidityDurationSeconds,
    parameters.teeSigningPolicyValidityDurationInRewardEpochs,
    parameters.teeChallengeValidityDurationSeconds,
    teeVerificationImpl.address
  );
  const teeVerification = await TeeVerification.at(teeVerificationProxy.address);
  spewNewContractInfo(contracts, null, TeeVerification.contractName, `TeeVerificationProxy.sol`, teeVerificationProxy.address, quiet);

  const teeStateVerifierImpl = await TeeStateVerifier.new();
  spewNewContractInfo(contracts, null, "TeeStateVerifierImplementation", `TeeStateVerifier.sol`, teeStateVerifierImpl.address, quiet);
  const teeStateVerifierProxy = await TeeStateVerifierProxy.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address,
    teeStateVerifierImpl.address
  );
  const teeStateVerifier = await TeeStateVerifier.at(teeStateVerifierProxy.address);
  spewNewContractInfo(contracts, null, TeeStateVerifier.contractName, `TeeStateVerifierProxy.sol`, teeStateVerifierProxy.address, quiet);

  const teeRegistryImpl = await TeeRegistryProxy.new();
  spewNewContractInfo(contracts, null, "TeeRegistryImplementation", `TeeRegistry.sol`, teeRegistryImpl.address, quiet);
  const teeRegistryProxy = await TeeRegistryProxy.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address,
    parameters.teePauseBeforeUpgradeMinDurationSeconds,
    teeRegistryImpl.address
  );
  const teeRegistry = await TeeRegistry.at(teeRegistryProxy.address);
  spewNewContractInfo(contracts, null, TeeRegistry.contractName, `TeeRegistryProxy.sol`, teeRegistryProxy.address, quiet);

  const teeWalletProjectManagerImpl = await TeeWalletProjectManager.new();
  spewNewContractInfo(contracts, null, "TeeWalletProjectManagerImplementation", `TeeWalletProjectManager.sol`, teeWalletProjectManagerImpl.address, quiet);
  const teeWalletProjectManagerProxy = await TeeWalletProjectManagerProxy.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address,
    teeWalletProjectManagerImpl.address
  );
  const teeWalletProjectManager = await TeeWalletProjectManager.at(teeWalletProjectManagerProxy.address);
  spewNewContractInfo(contracts, null, TeeWalletProjectManager.contractName, `TeeWalletProjectManagerProxy.sol`, teeWalletProjectManagerProxy.address, quiet);

  const teeWalletManagerImpl = await TeeWalletManagerProxy.new();
  spewNewContractInfo(contracts, null, "TeeWalletManagerImplementation", `TeeWalletManager.sol`, teeWalletManagerImpl.address, quiet);
  const teeWalletManagerProxy = await TeeWalletManagerProxy.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address,
    teeWalletManagerImpl.address
  );
  const teeWalletManager = await TeeWalletManager.at(teeWalletManagerProxy.address);
  spewNewContractInfo(contracts, null, TeeWalletManager.contractName, `TeeWalletManagerProxy.sol`, teeWalletManagerProxy.address, quiet);

  const teeWalletKeyManagerImpl = await TeeWalletKeyManagerProxy.new();
  spewNewContractInfo(contracts, null, "TeeWalletKeyManagerImplementation", `TeeWalletKeyManager.sol`, teeWalletKeyManagerImpl.address, quiet);
  const teeWalletKeyManagerProxy = await TeeWalletKeyManagerProxy.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address,
    teeWalletKeyManagerImpl.address
  );
  const teeWalletKeyManager = await TeeWalletKeyManager.at(teeWalletKeyManagerProxy.address);
  spewNewContractInfo(contracts, null, TeeWalletKeyManager.contractName, `TeeWalletKeyManagerProxy.sol`, teeWalletKeyManagerProxy.address, quiet);

  const teeWalletBackupManagerImpl = await TeeWalletBackupManagerProxy.new();
  spewNewContractInfo(contracts, null, "TeeWalletBackupManagerImplementation", `TeeWalletBackupManager.sol`, teeWalletBackupManagerImpl.address, quiet);
  const teeWalletBackupManagerProxy = await TeeWalletBackupManagerProxy.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address,
    teeWalletBackupManagerImpl.address
  );
  const teeWalletBackupManager = await TeeWalletBackupManager.at(teeWalletBackupManagerProxy.address);
  spewNewContractInfo(contracts, null, TeeWalletBackupManager.contractName, `TeeWalletBackupManagerProxy.sol`, teeWalletBackupManagerProxy.address, quiet);

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

  const teeInstructionsImpl = await TeeInstructionsProxy.new();
  spewNewContractInfo(contracts, null, "TeeInstructionsImplementation", `TeeInstructions.sol`, teeInstructionsImpl.address, quiet);
  const teeInstructionsProxy = await TeeInstructionsProxy.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address,
    teeInstructionsImpl.address
  );
  const teeInstructions = await TeeInstructions.at(teeInstructionsProxy.address);
  spewNewContractInfo(contracts, null, TeeInstructions.contractName, `TeeInstructionsProxy.sol`, teeInstructionsProxy.address, quiet);

  const teePaymentsList = [];
  for (const teePaymentConfig of parameters.teePaymentConfigurations) {
    const isEVM = teePaymentConfig.opType === "EVM";
    const Contract = isEVM ? TeePaymentsEVM : TeePayments;
    const teePaymentsImpl = await Contract.new();
    spewNewContractInfo(contracts, null, Contract.contractName + "_" + teePaymentConfig.opType + "Implementation", `TeePayments${isEVM ? "EVM" : ""}.sol`, teePaymentsImpl.address, quiet);
    const teePaymentsProxy = await TeePaymentsProxy.new(
      governanceSettings,
      deployerAccount.address,
      deployerAccount.address,
      teePaymentConfig.maxBatchSize,
      teePaymentConfig.maxBatchDurationSeconds,
      web3.utils.utf8ToHex(teePaymentConfig.opType).padEnd(66, "0"),
      teePaymentsImpl.address
    );
    const teePayments = await Contract.at(teePaymentsProxy.address);
    teePaymentsList.push(teePayments);
    spewNewContractInfo(contracts, null, Contract.contractName + "_" + teePaymentConfig.opType, `TeePayments${isEVM ? "EVM" : ""}Proxy.sol`, teePaymentsProxy.address, quiet);
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

  await teeVerification.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_VERSION_MANAGER, Contracts.TEE_REGISTRY, Contracts.TEE_FEE_CALCULATOR, Contracts.TEE_STATE_VERIFIER, Contracts.TEE_INSTRUCTIONS, Contracts.FTDC_HUB, Contracts.FTDC_VERIFICATION, Contracts.FLARE_SYSTEMS_MANAGER, Contracts.RELAY]),
    [addressUpdater, teeVersionManager.address, teeRegistry.address, teeFeeCalculator.address, teeStateVerifier.address, teeInstructions.address, ftdcHub.address, ftdcVerification.address, flareSystemsManager, relay]);

  await teeStateVerifier.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_VERSION_MANAGER, Contracts.TEE_REGISTRY]),
    [addressUpdater, teeVersionManager.address, teeRegistry.address]);

  await teeRegistry.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_OWNER_ALLOWLIST, Contracts.TEE_VERSION_MANAGER, Contracts.TEE_VERIFICATION, Contracts.TEE_FEE_CALCULATOR, Contracts.TEE_INSTRUCTIONS, Contracts.FLARE_SYSTEMS_MANAGER, Contracts.RELAY]),
    [addressUpdater, teeOwnerAllowlist.address, teeVersionManager.address, teeVerification.address, teeFeeCalculator.address, teeInstructions.address, flareSystemsManager, relay]);

  await teeWalletProjectManager.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_OWNER_ALLOWLIST, Contracts.TEE_WALLET_MANAGER]),
    [addressUpdater, teeOwnerAllowlist.address, teeWalletManager.address]);

  await teeWalletManager.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_WALLET_PROJECT_MANAGER, Contracts.TEE_WALLET_KEY_MANAGER, Contracts.TEE_FEE_CALCULATOR, Contracts.TEE_INSTRUCTIONS, Contracts.FLARE_SYSTEMS_MANAGER, Contracts.TEE_REGISTRY]),
    [addressUpdater, teeWalletProjectManager.address, teeWalletKeyManager.address, teeFeeCalculator.address, teeInstructions.address, flareSystemsManager, teeRegistry.address]);

  await teeWalletKeyManager.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_REGISTRY, Contracts.TEE_WALLET_PROJECT_MANAGER, Contracts.TEE_WALLET_MANAGER, Contracts.TEE_WALLET_BACKUP_MANAGER, Contracts.TEE_FEE_CALCULATOR, Contracts.TEE_INSTRUCTIONS, Contracts.FTDC_HUB, Contracts.FTDC_VERIFICATION, Contracts.FLARE_SYSTEMS_MANAGER]),
    [addressUpdater, teeRegistry.address, teeWalletProjectManager.address, teeWalletManager.address, teeWalletBackupManager.address, teeFeeCalculator.address, teeInstructions.address, ftdcHub.address, ftdcVerification.address, flareSystemsManager]);

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
    teeVerification.address,
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
  await teeOwnerAllowlist.switchToProductionMode();
  await teeVerification.switchToProductionMode();
  await teeStateVerifier.switchToProductionMode();
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
