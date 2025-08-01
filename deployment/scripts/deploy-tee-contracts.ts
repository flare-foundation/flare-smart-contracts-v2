/**
 * This script will deploy TEE contracts.
 */

import { HardhatRuntimeEnvironment } from "hardhat/types";
import { FtdcHubContract } from "../../typechain-truffle/contracts/ftdc/implementation/FtdcHub";
import { FtdcRequestFeeConfigurationsContract } from "../../typechain-truffle/contracts/ftdc/implementation/FtdcRequestFeeConfigurations";
import { FtdcVerificationContract } from "../../typechain-truffle/contracts/ftdc/implementation/FtdcVerification";
import { TeeExtensionRegistryContract } from "../../typechain-truffle/contracts/tee/implementation/TeeExtensionRegistry";
import { TeeExtensionRegistryProxyContract } from "../../typechain-truffle/contracts/tee/proxy/TeeExtensionRegistryProxy";
import { TeeFeeCalculatorContract } from "../../typechain-truffle/contracts/tee/implementation/TeeFeeCalculator";
import { TeeGovernanceContract } from "../../typechain-truffle/contracts/tee/implementation/TeeGovernance";
import { TeeGovernanceProxyContract } from "../../typechain-truffle/contracts/tee/proxy/TeeGovernanceProxy";
import { TeeInstructionsContract } from "../../typechain-truffle/contracts/tee/implementation/TeeInstructions";
import { TeeInstructionsProxyContract } from "../../typechain-truffle/contracts/tee/proxy/TeeInstructionsProxy";
import { TeeMachineRegistryContract } from "../../typechain-truffle/contracts/tee/implementation/TeeMachineRegistry";
import { TeeMachineRegistryProxyContract } from "../../typechain-truffle/contracts/tee/proxy/TeeMachineRegistryProxy";
import { TeeOwnerAllowlistContract } from "../../typechain-truffle/contracts/tee/implementation/TeeOwnerAllowlist";
import { TeeOwnerAllowlistProxyContract } from "../../typechain-truffle/contracts/tee/proxy/TeeOwnerAllowlistProxy";
import { TeePaymentsContract } from "../../typechain-truffle/contracts/tee/implementation/TeePayments";
import { TeePaymentsEVMContract } from "../../typechain-truffle/contracts/tee/implementation/TeePaymentsEVM";
import { TeePaymentsProxyContract } from "../../typechain-truffle/contracts/tee/proxy/TeePaymentsProxy";
import { TeeReplicationContract } from "../../typechain-truffle/contracts/tee/implementation/TeeReplication";
import { TeeReplicationProxyContract } from "../../typechain-truffle/contracts/tee/proxy/TeeReplicationProxy";
import { TeeRewardOffersManagerContract } from "../../typechain-truffle/contracts/tee/implementation/TeeRewardOffersManager";
import { TeeSystemStateVerifierContract } from "../../typechain-truffle/contracts/tee/implementation/TeeSystemStateVerifier";
import { TeeSystemStateVerifierProxyContract } from "../../typechain-truffle/contracts/tee/proxy/TeeSystemStateVerifierProxy";
import { TeeVerificationContract } from "../../typechain-truffle/contracts/tee/implementation/TeeVerification";
import { TeeVerificationProxyContract } from "../../typechain-truffle/contracts/tee/proxy/TeeVerificationProxy";
import { TeeVersionManagerContract } from "../../typechain-truffle/contracts/tee/implementation/TeeVersionManager";
import { TeeVersionManagerProxyContract } from "../../typechain-truffle/contracts/tee/proxy/TeeVersionManagerProxy";
import { TeeWalletBackupManagerContract } from "../../typechain-truffle/contracts/tee/implementation/TeeWalletBackupManager";
import { TeeWalletBackupManagerProxyContract } from "../../typechain-truffle/contracts/tee/proxy/TeeWalletBackupManagerProxy";
import { TeeWalletKeyManagerContract } from "../../typechain-truffle/contracts/tee/implementation/TeeWalletKeyManager";
import { TeeWalletKeyManagerProxyContract } from "../../typechain-truffle/contracts/tee/proxy/TeeWalletKeyManagerProxy";
import { TeeWalletManagerContract } from "../../typechain-truffle/contracts/tee/implementation/TeeWalletManager";
import { TeeWalletManagerProxyContract } from "../../typechain-truffle/contracts/tee/proxy/TeeWalletManagerProxy";
import { TeeWalletProjectManagerContract } from "../../typechain-truffle/contracts/tee/implementation/TeeWalletProjectManager";
import { TeeWalletProjectManagerProxyContract } from "../../typechain-truffle/contracts/tee/proxy/TeeWalletProjectManagerProxy";
import { ChainParameters } from "../chain-config/chain-parameters";
import { Contracts } from "./Contracts";
import { spewNewContractInfo } from "./deploy-utils";

export async function deployTeeContracts(
  hre: HardhatRuntimeEnvironment,
  oldContracts: Contracts,
  contracts: Contracts,
  parameters: ChainParameters,
  quiet: boolean = false
) {
  const web3 = hre.web3;
  const artifacts = hre.artifacts;

  const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

  // Import contract artifacts
  const FtdcHub: FtdcHubContract = artifacts.require("FtdcHub");
  const FtdcRequestFeeConfigurations: FtdcRequestFeeConfigurationsContract = artifacts.require("FtdcRequestFeeConfigurations");
  const FtdcVerification: FtdcVerificationContract = artifacts.require("FtdcVerification");
  const TeeExtensionRegistry: TeeExtensionRegistryContract = artifacts.require("TeeExtensionRegistry");
  const TeeExtensionRegistryProxy: TeeExtensionRegistryProxyContract = artifacts.require("TeeExtensionRegistryProxy");
  const TeeGovernance: TeeGovernanceContract = artifacts.require("TeeGovernance");
  const TeeGovernanceProxy: TeeGovernanceProxyContract = artifacts.require("TeeGovernanceProxy");
  const TeeFeeCalculator: TeeFeeCalculatorContract = artifacts.require("TeeFeeCalculator");
  const TeeInstructions: TeeInstructionsContract = artifacts.require("TeeInstructions");
  const TeeInstructionsProxy: TeeInstructionsProxyContract = artifacts.require("TeeInstructionsProxy");
  const TeeMachineRegistry: TeeMachineRegistryContract = artifacts.require("TeeMachineRegistry");
  const TeeMachineRegistryProxy: TeeMachineRegistryProxyContract = artifacts.require("TeeMachineRegistryProxy");
  const TeeOwnerAllowlist: TeeOwnerAllowlistContract = artifacts.require("TeeOwnerAllowlist");
  const TeeOwnerAllowlistProxy: TeeOwnerAllowlistProxyContract = artifacts.require("TeeOwnerAllowlistProxy");
  const TeePayments: TeePaymentsContract = artifacts.require("TeePayments");
  const TeePaymentsProxy: TeePaymentsProxyContract = artifacts.require("TeePaymentsProxy");
  const TeePaymentsEVM: TeePaymentsEVMContract = artifacts.require("TeePaymentsEVM");
  const TeeReplication: TeeReplicationContract = artifacts.require("TeeReplication");
  const TeeReplicationProxy: TeeReplicationProxyContract = artifacts.require("TeeReplicationProxy");
  const TeeRewardOffersManager: TeeRewardOffersManagerContract = artifacts.require("TeeRewardOffersManager");
  const TeeSystemStateVerifier: TeeSystemStateVerifierContract = artifacts.require("TeeSystemStateVerifier");
  const TeeSystemStateVerifierProxy: TeeSystemStateVerifierProxyContract = artifacts.require("TeeSystemStateVerifierProxy");
  const TeeVerification: TeeVerificationContract = artifacts.require("TeeVerification");
  const TeeVerificationProxy: TeeVerificationProxyContract = artifacts.require("TeeVerificationProxy");
  const TeeVersionManager: TeeVersionManagerContract = artifacts.require("TeeVersionManager");
  const TeeVersionManagerProxy: TeeVersionManagerProxyContract = artifacts.require("TeeVersionManagerProxy");
  const TeeWalletBackupManager: TeeWalletBackupManagerContract = artifacts.require("TeeWalletBackupManager");
  const TeeWalletBackupManagerProxy: TeeWalletBackupManagerProxyContract = artifacts.require("TeeWalletBackupManagerProxy");
  const TeeWalletKeyManager: TeeWalletKeyManagerContract = artifacts.require("TeeWalletKeyManager");
  const TeeWalletKeyManagerProxy: TeeWalletKeyManagerProxyContract = artifacts.require("TeeWalletKeyManagerProxy");
  const TeeWalletManager: TeeWalletManagerContract = artifacts.require("TeeWalletManager");
  const TeeWalletManagerProxy: TeeWalletManagerProxyContract = artifacts.require("TeeWalletManagerProxy");
  const TeeWalletProjectManager: TeeWalletProjectManagerContract = artifacts.require("TeeWalletProjectManager");
  const TeeWalletProjectManagerProxy: TeeWalletProjectManagerProxyContract = artifacts.require("TeeWalletProjectManagerProxy");

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
  // FtdcHub
  const ftdcHub = await FtdcHub.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address,
    parameters.ftdcMinThresholdBIPS,
    parameters.ftdcDefaultNumberOfTees
  );
  spewNewContractInfo(contracts, null, FtdcHub.contractName, `FtdcHub.sol`, ftdcHub.address, quiet);

  // FtdcRequestFeeConfigurations
  const ftdcRequestFeeConfigurations = await FtdcRequestFeeConfigurations.new(
    governanceSettings,
    deployerAccount.address
  );
  spewNewContractInfo(contracts, null, FtdcRequestFeeConfigurations.contractName, `FtdcRequestFeeConfigurations.sol`, ftdcRequestFeeConfigurations.address, quiet);

  // FtdcVerification
  const ftdcVerification = await FtdcVerification.new(
    deployerAccount.address
  );
  spewNewContractInfo(contracts, null, FtdcVerification.contractName, `FtdcVerification.sol`, ftdcVerification.address, quiet);

  // TeeExtensionRegistry
  const teeExtensionRegistryImpl = await TeeExtensionRegistry.new();
  spewNewContractInfo(contracts, null, "TeeExtensionRegistryImplementation", `TeeExtensionRegistry.sol`, teeExtensionRegistryImpl.address, quiet);
  const teeExtensionRegistryProxy = await TeeExtensionRegistryProxy.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address,
    teeExtensionRegistryImpl.address
  );
  const teeExtensionRegistry = await TeeExtensionRegistry.at(teeExtensionRegistryProxy.address);
  spewNewContractInfo(contracts, null, TeeExtensionRegistry.contractName, `TeeExtensionRegistryProxy.sol`, teeExtensionRegistryProxy.address, quiet);

  // TeeFeeCalculator
  const teeFeeCalculator = await TeeFeeCalculator.new(
    governanceSettings,
    deployerAccount.address,
    parameters.teeDefaultFeeWei
  );
  spewNewContractInfo(contracts, null, TeeFeeCalculator.contractName, `TeeFeeCalculator.sol`, teeFeeCalculator.address, quiet);

  // TeeGovernance
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

  // TeeInstructions
  const teeInstructionsImpl = await TeeInstructions.new();
  spewNewContractInfo(contracts, null, "TeeInstructionsImplementation", `TeeInstructions.sol`, teeInstructionsImpl.address, quiet);
  const teeInstructionsProxy = await TeeInstructionsProxy.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address,
    teeInstructionsImpl.address
  );
  const teeInstructions = await TeeInstructions.at(teeInstructionsProxy.address);
  spewNewContractInfo(contracts, null, TeeInstructions.contractName, `TeeInstructionsProxy.sol`, teeInstructionsProxy.address, quiet);

  // TeeMachineRegistry
  const teeMachineRegistryImpl = await TeeMachineRegistry.new();
  spewNewContractInfo(contracts, null, "TeeMachineRegistryImplementation", `TeeMachineRegistry.sol`, teeMachineRegistryImpl.address, quiet);
  const teeMachineRegistryProxy = await TeeMachineRegistryProxy.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address,
    teeMachineRegistryImpl.address
  );
  const teeMachineRegistry = await TeeMachineRegistry.at(teeMachineRegistryProxy.address);
  spewNewContractInfo(contracts, null, TeeMachineRegistry.contractName, `TeeMachineRegistryProxy.sol`, teeMachineRegistryProxy.address, quiet);

  // TeeOwnerAllowlist
  const teeOwnerAllowlistImpl = await TeeOwnerAllowlist.new();
  spewNewContractInfo(contracts, null, "TeeOwnerAllowlistImplementation", `TeeOwnerAllowlist.sol`, teeOwnerAllowlistImpl.address, quiet);
  const teeOwnerAllowlistProxy = await TeeOwnerAllowlistProxy.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address,
    teeOwnerAllowlistImpl.address
  );
  const teeOwnerAllowlist = await TeeOwnerAllowlist.at(teeOwnerAllowlistProxy.address);
  spewNewContractInfo(contracts, null, TeeOwnerAllowlist.contractName, `TeeOwnerAllowlistProxy.sol`, teeOwnerAllowlistProxy.address, quiet);

  // TeePayments, TeePaymentsEVM
  const teePaymentsList = [];
  for (const teePaymentConfig of parameters.teePaymentConfigurations) {
    const isEVM = teePaymentConfig.opType === "F_EVM";
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

  // TeeReplication
  const teeReplicationImpl = await TeeReplication.new();
  spewNewContractInfo(contracts, null, "TeeReplicationImplementation", `TeeReplication.sol`, teeReplicationImpl.address, quiet);
  const teeReplicationProxy = await TeeReplicationProxy.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address,
    parameters.teePauseBeforeUpgradeMinDurationSeconds,
    teeReplicationImpl.address);
  const teeReplication = await TeeReplication.at(teeReplicationProxy.address);
  spewNewContractInfo(contracts, null, TeeReplication.contractName, `TeeReplicationProxy.sol`, teeReplicationProxy.address, quiet);

  // TeeRewardOffersManager
  const teeRewardOffersManager = await TeeRewardOffersManager.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address,
    parameters.teeOwnersPPM
  );
  spewNewContractInfo(contracts, null, TeeRewardOffersManager.contractName, `TeeRewardOffersManager.sol`, teeRewardOffersManager.address, quiet);

  // TeeSystemStateVerifier
  const teeSystemStateVerifierImpl = await TeeSystemStateVerifier.new();
  spewNewContractInfo(contracts, null, "TeeSystemStateVerifierImplementation", `TeeSystemStateVerifier.sol`, teeSystemStateVerifierImpl.address, quiet);
  const teeSystemStateVerifierProxy = await TeeSystemStateVerifierProxy.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address,
    teeSystemStateVerifierImpl.address
  );
  const teeSystemStateVerifier = await TeeSystemStateVerifier.at(teeSystemStateVerifierProxy.address);
  spewNewContractInfo(contracts, null, TeeSystemStateVerifier.contractName, `TeeSystemStateVerifierProxy.sol`, teeSystemStateVerifierProxy.address, quiet);

  // TeeVerification
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

  // TeeVersionManager
  const teeVersionManagerImpl = await TeeVersionManager.new();
  spewNewContractInfo(contracts, null, "TeeVersionManagerImplementation", `TeeVersionManager.sol`, teeVersionManagerImpl.address, quiet);
  const teeVersionManagerProxy = await TeeVersionManagerProxy.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address,
    teeVersionManagerImpl.address
  );
  const teeVersionManager = await TeeVersionManager.at(teeVersionManagerProxy.address);
  spewNewContractInfo(contracts, null, TeeVersionManager.contractName, `TeeVersionManagerProxy.sol`, teeVersionManagerProxy.address, quiet);

  // TeeWalletBackupManager
  const teeWalletBackupManagerImpl = await TeeWalletBackupManager.new();
  spewNewContractInfo(contracts, null, "TeeWalletBackupManagerImplementation", `TeeWalletBackupManager.sol`, teeWalletBackupManagerImpl.address, quiet);
  const teeWalletBackupManagerProxy = await TeeWalletBackupManagerProxy.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address,
    teeWalletBackupManagerImpl.address
  );
  const teeWalletBackupManager = await TeeWalletBackupManager.at(teeWalletBackupManagerProxy.address);
  spewNewContractInfo(contracts, null, TeeWalletBackupManager.contractName, `TeeWalletBackupManagerProxy.sol`, teeWalletBackupManagerProxy.address, quiet);

  // TeeWalletKeyManager
  const teeWalletKeyManagerImpl = await TeeWalletKeyManager.new();
  spewNewContractInfo(contracts, null, "TeeWalletKeyManagerImplementation", `TeeWalletKeyManager.sol`, teeWalletKeyManagerImpl.address, quiet);
  const teeWalletKeyManagerProxy = await TeeWalletKeyManagerProxy.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address,
    teeWalletKeyManagerImpl.address
  );
  const teeWalletKeyManager = await TeeWalletKeyManager.at(teeWalletKeyManagerProxy.address);
  spewNewContractInfo(contracts, null, TeeWalletKeyManager.contractName, `TeeWalletKeyManagerProxy.sol`, teeWalletKeyManagerProxy.address, quiet);

  // TeeWalletManager
  const teeWalletManagerImpl = await TeeWalletManager.new();
  spewNewContractInfo(contracts, null, "TeeWalletManagerImplementation", `TeeWalletManager.sol`, teeWalletManagerImpl.address, quiet);
  const teeWalletManagerProxy = await TeeWalletManagerProxy.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address,
    teeWalletManagerImpl.address
  );
  const teeWalletManager = await TeeWalletManager.at(teeWalletManagerProxy.address);
  spewNewContractInfo(contracts, null, TeeWalletManager.contractName, `TeeWalletManagerProxy.sol`, teeWalletManagerProxy.address, quiet);

  // TeeWalletProjectManager
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

  // set contract addresses
  await ftdcHub.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_MACHINE_REGISTRY, Contracts.TEE_INSTRUCTIONS, Contracts.FLARE_SYSTEMS_MANAGER, Contracts.REWARD_MANAGER, Contracts.FTDC_REQUEST_FEE_CONFIGURATIONS]),
    [addressUpdater, teeMachineRegistry.address, teeInstructions.address, flareSystemsManager, rewardManager, ftdcRequestFeeConfigurations.address],
  );

  await ftdcVerification.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_MACHINE_REGISTRY, Contracts.RELAY]),
    [addressUpdater, teeMachineRegistry.address, relay],
  );

  await teeExtensionRegistry.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_GOVERNANCE, Contracts.TEE_MACHINE_REGISTRY, Contracts.TEE_FEE_CALCULATOR, Contracts.FLARE_SYSTEMS_MANAGER, Contracts.REWARD_MANAGER]),
    [addressUpdater, teeGovernance.address, teeMachineRegistry.address, teeFeeCalculator.address, flareSystemsManager, rewardManager],
  );

  await teeGovernance.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_EXTENSION_REGISTRY]),
    [addressUpdater, teeExtensionRegistry.address]
  );

  await teeInstructions.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_EXTENSION_REGISTRY]),
    [addressUpdater, teeExtensionRegistry.address]
  );

  await teeMachineRegistry.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_EXTENSION_REGISTRY, Contracts.TEE_OWNER_ALLOWLIST, Contracts.TEE_VERIFICATION, Contracts.TEE_REPLICATION, Contracts.RELAY]),
    [addressUpdater, teeExtensionRegistry.address, teeOwnerAllowlist.address, teeVerification.address, teeReplication.address, relay]
  );

  await teeOwnerAllowlist.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_EXTENSION_REGISTRY]),
    [addressUpdater, teeExtensionRegistry.address]
  );

  for (const teePayments of teePaymentsList) {
    await teePayments.updateContractAddresses(
      encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_WALLET_PROJECT_MANAGER, Contracts.TEE_WALLET_MANAGER, Contracts.TEE_WALLET_KEY_MANAGER, Contracts.TEE_VERIFICATION, Contracts.TEE_INSTRUCTIONS, Contracts.FLARE_SYSTEMS_MANAGER]),
      [addressUpdater, teeWalletProjectManager.address, teeWalletManager.address, teeWalletKeyManager.address, teeVerification.address, teeInstructions.address, flareSystemsManager]
    );
  }

  await teeReplication.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_EXTENSION_REGISTRY, Contracts.TEE_VERSION_MANAGER, Contracts.TEE_MACHINE_REGISTRY, Contracts.TEE_VERIFICATION]),
    [addressUpdater, teeExtensionRegistry.address, teeVersionManager.address, teeMachineRegistry.address, teeVerification.address]
  );

  await teeRewardOffersManager.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.REWARD_MANAGER, Contracts.FLARE_SYSTEMS_MANAGER, Contracts.INFLATION]),
    [addressUpdater, rewardManager, flareSystemsManager, inflation]
  );

  await teeSystemStateVerifier.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_EXTENSION_REGISTRY, Contracts.TEE_MACHINE_REGISTRY]),
    [addressUpdater, teeExtensionRegistry.address, teeMachineRegistry.address]
  );

  await teeVerification.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_EXTENSION_REGISTRY, Contracts.TEE_MACHINE_REGISTRY, Contracts.TEE_WALLET_PROJECT_MANAGER, Contracts.TEE_WALLET_MANAGER, Contracts.TEE_WALLET_KEY_MANAGER, Contracts.TEE_SYSTEM_STATE_VERIFIER, Contracts.TEE_REPLICATION, Contracts.FTDC_HUB, Contracts.FTDC_VERIFICATION, Contracts.FLARE_SYSTEMS_MANAGER, Contracts.RELAY]),
    [addressUpdater, teeExtensionRegistry.address, teeMachineRegistry.address, teeWalletProjectManager.address, teeWalletManager.address, teeWalletKeyManager.address, teeSystemStateVerifier.address, teeReplication.address, ftdcHub.address, ftdcVerification.address, flareSystemsManager, relay]
  );

  await teeVersionManager.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_EXTENSION_REGISTRY, Contracts.TEE_GOVERNANCE]),
    [addressUpdater, teeExtensionRegistry.address, teeGovernance.address]
  );

  await teeWalletBackupManager.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_EXTENSION_REGISTRY, Contracts.TEE_MACHINE_REGISTRY, Contracts.TEE_WALLET_PROJECT_MANAGER, Contracts.TEE_WALLET_MANAGER, Contracts.TEE_WALLET_KEY_MANAGER, Contracts.FLARE_SYSTEMS_MANAGER]),
    [addressUpdater, teeExtensionRegistry.address, teeMachineRegistry.address, teeWalletProjectManager.address, teeWalletManager.address, teeWalletKeyManager.address, flareSystemsManager]
  );

  await teeWalletKeyManager.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_EXTENSION_REGISTRY, Contracts.TEE_MACHINE_REGISTRY, Contracts.TEE_WALLET_PROJECT_MANAGER, Contracts.TEE_WALLET_MANAGER, Contracts.TEE_WALLET_BACKUP_MANAGER, Contracts.FLARE_SYSTEMS_MANAGER]),
    [addressUpdater, teeExtensionRegistry.address, teeMachineRegistry.address, teeWalletProjectManager.address, teeWalletManager.address, teeWalletBackupManager.address, flareSystemsManager]
  );

  await teeWalletManager.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_EXTENSION_REGISTRY, Contracts.TEE_MACHINE_REGISTRY, Contracts.TEE_WALLET_PROJECT_MANAGER, Contracts.TEE_WALLET_KEY_MANAGER, Contracts.FLARE_SYSTEMS_MANAGER]),
    [addressUpdater, teeExtensionRegistry.address, teeMachineRegistry.address, teeWalletProjectManager.address, teeWalletKeyManager.address, flareSystemsManager]
  );

  await teeWalletProjectManager.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_EXTENSION_REGISTRY, Contracts.TEE_OWNER_ALLOWLIST, Contracts.TEE_WALLET_MANAGER]),
    [addressUpdater, teeExtensionRegistry.address, teeOwnerAllowlist.address, teeWalletManager.address]
  );

  // set FTDC request fee configurations
  for (const ftdcRequestFee of parameters.ftdcRequestFees) {
    await ftdcRequestFeeConfigurations.setTypeAndSourceFee(
      web3.utils.utf8ToHex(ftdcRequestFee.attestationType).padEnd(66, "0"),
      web3.utils.utf8ToHex(ftdcRequestFee.source).padEnd(66, "0"),
      ftdcRequestFee.feeWei
    );
  }

  // set TEE operation fees
  const operationTypes = [];
  const operationCommands = [];
  const operationFees = [];
  for (const teeOperationFee of parameters.teeOperationFees) {
    operationTypes.push(web3.utils.utf8ToHex(teeOperationFee.opType).padEnd(66, "0"));
    operationCommands.push(web3.utils.utf8ToHex(teeOperationFee.opCommand).padEnd(66, "0"));
    operationFees.push(teeOperationFee.feeWei);
  }
  await teeFeeCalculator.setOperationFees(operationTypes, operationCommands, operationFees);

  // add supported platforms
  await teeExtensionRegistry.addSupportedPlatforms(
    parameters.teeSupportedPlatforms.map(platform => web3.utils.utf8ToHex(platform).padEnd(66, "0"))
  );

  // add supported operation types
  await teeExtensionRegistry.addOrUpdateSupportedWalletProjectOpTypes(
    0, // system extension id
    teePaymentsList.map(teePayments => teePayments.address)
  );

  // set extension contracts
  await teeExtensionRegistry.setExtensionContracts(0, ZERO_ADDRESS, teeInstructions.address);

  // register system instruction initiators
  await teeExtensionRegistry.registerSystemInstructionInitiators([
    teeReplication.address,
    teeVerification.address,
    teeWalletBackupManager.address,
    teeWalletKeyManager.address,
    teeWalletManager.address
  ]);

  // register instruction initiators
  await teeInstructions.registerInstructionInitiators([
    ...teePaymentsList.map(teePayments => teePayments.address),
    ftdcHub.address
  ]);

  // TODO add allowed tee and project owners
  await teeOwnerAllowlist.allowAllTeeMachineOwners(0);
  await teeOwnerAllowlist.allowAllTeeWalletProjectOwners(0);

  // TODO add tee versions

  // switch to production mode
  await ftdcHub.switchToProductionMode();
  await ftdcRequestFeeConfigurations.switchToProductionMode();

  await teeExtensionRegistry.switchToProductionMode();
  await teeFeeCalculator.switchToProductionMode();
  await teeGovernance.switchToProductionMode();
  await teeInstructions.switchToProductionMode();
  await teeMachineRegistry.switchToProductionMode();
  await teeOwnerAllowlist.switchToProductionMode();
  for (const teePayments of teePaymentsList) {
    await teePayments.switchToProductionMode();
  }
  await teeReplication.switchToProductionMode();
  await teeRewardOffersManager.switchToProductionMode();
  await teeSystemStateVerifier.switchToProductionMode();
  await teeVerification.switchToProductionMode();
  await teeVersionManager.switchToProductionMode();
  await teeWalletBackupManager.switchToProductionMode();
  await teeWalletKeyManager.switchToProductionMode();
  await teeWalletManager.switchToProductionMode();
  await teeWalletProjectManager.switchToProductionMode();

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
