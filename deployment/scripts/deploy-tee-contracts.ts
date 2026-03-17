/**
 * This script will deploy TEE contracts.
 */

import { HardhatRuntimeEnvironment } from "hardhat/types";
import {
  Fdc2HubContract,
  Fdc2HubProxyContract,
  Fdc2RequestFeeConfigurationsContract,
  Fdc2RequestFeeConfigurationsProxyContract,
  Fdc2VerificationContract,
  Fdc2VerificationProxyContract,
  PMWPaymentStatusVerifierMockContract,
  TeeExtensionInstructionsSenderMockContract,
  TeeExtensionRegistryContract,
  TeeExtensionRegistryProxyContract,
  TeeFeeCalculatorContract,
  TeeFeeCalculatorProxyContract,
  TeeGovernanceContract,
  TeeGovernanceProxyContract,
  TeeMachineRegistryContract,
  TeeMachineRegistryProxyContract,
  TeeOwnerAllowlistContract,
  TeeOwnerAllowlistProxyContract,
  TeePaymentsContract,
  TeePaymentsProxyContract,
  TeeReplicationContract,
  TeeReplicationProxyContract,
  TeeRewardOffersManagerContract,
  TeeSystemStateVerifierContract,
  TeeSystemStateVerifierProxyContract,
  TeeVerificationContract,
  TeeVerificationProxyContract,
  TeeVersionManagerContract,
  TeeVersionManagerProxyContract,
  TeeVrfContract,
  TeeVrfProxyContract,
  TeeWalletBackupManagerContract,
  TeeWalletBackupManagerProxyContract,
  TeeWalletKeyManagerContract,
  TeeWalletKeyManagerProxyContract,
  TeeWalletManagerContract,
  TeeWalletManagerProxyContract,
  TeeWalletProjectManagerContract,
  TeeWalletProjectManagerProxyContract,
  VrfVerifierContract,
} from "../../typechain-truffle";
import { ChainParameters } from "../chain-config/chain-parameters";
import { Contracts } from "./Contracts";
import { spewNewContractInfo } from "./deploy-utils";
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
  const TeeExtensionRegistry = artifacts.require("TeeExtensionRegistry") as TeeExtensionRegistryContract;
  const TeeExtensionRegistryProxy = artifacts.require("TeeExtensionRegistryProxy") as TeeExtensionRegistryProxyContract;
  const TeeGovernance = artifacts.require("TeeGovernance") as TeeGovernanceContract;
  const TeeGovernanceProxy = artifacts.require("TeeGovernanceProxy") as TeeGovernanceProxyContract;
  const TeeFeeCalculator = artifacts.require("TeeFeeCalculator") as TeeFeeCalculatorContract;
  const TeeFeeCalculatorProxy = artifacts.require("TeeFeeCalculatorProxy") as TeeFeeCalculatorProxyContract;
  const TeeMachineRegistry = artifacts.require("TeeMachineRegistry") as TeeMachineRegistryContract;
  const TeeMachineRegistryProxy = artifacts.require("TeeMachineRegistryProxy") as TeeMachineRegistryProxyContract;
  const TeeOwnerAllowlist = artifacts.require("TeeOwnerAllowlist") as TeeOwnerAllowlistContract;
  const TeeOwnerAllowlistProxy = artifacts.require("TeeOwnerAllowlistProxy") as TeeOwnerAllowlistProxyContract;
  const TeePayments = artifacts.require("TeePayments") as TeePaymentsContract;
  const TeePaymentsProxy = artifacts.require("TeePaymentsProxy") as TeePaymentsProxyContract;
  const TeeReplication = artifacts.require("TeeReplication") as TeeReplicationContract;
  const TeeReplicationProxy = artifacts.require("TeeReplicationProxy") as TeeReplicationProxyContract;
  const TeeRewardOffersManager = artifacts.require("TeeRewardOffersManager") as TeeRewardOffersManagerContract;
  const TeeSystemStateVerifier = artifacts.require("TeeSystemStateVerifier") as TeeSystemStateVerifierContract;
  const TeeSystemStateVerifierProxy = artifacts.require("TeeSystemStateVerifierProxy") as TeeSystemStateVerifierProxyContract;
  const TeeVerification = artifacts.require("TeeVerification") as TeeVerificationContract;
  const TeeVerificationProxy = artifacts.require("TeeVerificationProxy") as TeeVerificationProxyContract;
  const TeeVersionManager = artifacts.require("TeeVersionManager") as TeeVersionManagerContract;
  const TeeVersionManagerProxy = artifacts.require("TeeVersionManagerProxy") as TeeVersionManagerProxyContract;
  const TeeWalletBackupManager = artifacts.require("TeeWalletBackupManager") as TeeWalletBackupManagerContract;
  const TeeWalletBackupManagerProxy = artifacts.require("TeeWalletBackupManagerProxy") as TeeWalletBackupManagerProxyContract;
  const TeeWalletKeyManager = artifacts.require("TeeWalletKeyManager") as TeeWalletKeyManagerContract;
  const TeeWalletKeyManagerProxy = artifacts.require("TeeWalletKeyManagerProxy") as TeeWalletKeyManagerProxyContract;
  const TeeWalletManager = artifacts.require("TeeWalletManager") as TeeWalletManagerContract;
  const TeeWalletManagerProxy = artifacts.require("TeeWalletManagerProxy") as TeeWalletManagerProxyContract;
  const TeeWalletProjectManager = artifacts.require("TeeWalletProjectManager") as TeeWalletProjectManagerContract;
  const TeeWalletProjectManagerProxy = artifacts.require("TeeWalletProjectManagerProxy") as TeeWalletProjectManagerProxyContract;
  const TeeVrf = artifacts.require("TeeVrf") as TeeVrfContract;
  const TeeVrfProxy = artifacts.require("TeeVrfProxy") as TeeVrfProxyContract;
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

  // deploy contracts
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
  const teeFeeCalculatorImpl = await TeeFeeCalculator.new();
  spewNewContractInfo(contracts, null, "TeeFeeCalculatorImplementation", `TeeFeeCalculator.sol`, teeFeeCalculatorImpl.address, quiet);
  const teeFeeCalculatorProxy = await TeeFeeCalculatorProxy.new(
    governanceSettings,
    deployerAccount.address,
    parameters.teeDefaultFeeWei,
    teeFeeCalculatorImpl.address
  );
  const teeFeeCalculator = await TeeFeeCalculator.at(teeFeeCalculatorProxy.address);
  spewNewContractInfo(contracts, null, TeeFeeCalculator.contractName, `TeeFeeCalculatorProxy.sol`, teeFeeCalculatorProxy.address, quiet);

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

  // TeePayments
  const teePaymentsList = [];
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
      teePaymentConfig.sourceIds.map(sourceId => web3.utils.utf8ToHex(sourceId).padEnd(66, "0")),
      teePaymentsImpl.address
    );
    const teePayments = await TeePayments.at(teePaymentsProxy.address);
    teePaymentsList.push(teePayments);
    spewNewContractInfo(contracts, null, "TeePayments_" + teePaymentConfig.opType, `TeePaymentsProxy.sol`, teePaymentsProxy.address, quiet);
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

  // TeeVrf
  const teeVrfImpl = await TeeVrf.new();
  spewNewContractInfo(contracts, null, "TeeVrfImplementation", `TeeVrf.sol`, teeVrfImpl.address, quiet);
  const teeVrfProxy = await TeeVrfProxy.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address,
    teeVrfImpl.address
  );
  const teeVrf = await TeeVrf.at(teeVrfProxy.address);
  spewNewContractInfo(contracts, null, TeeVrf.contractName, `TeeVrfProxy.sol`, teeVrfProxy.address, quiet);

  // VrfVerifier
  const vrfVerifier = await VrfVerifier.new();
  spewNewContractInfo(contracts, null, VrfVerifier.contractName, `VrfVerifier.sol`, vrfVerifier.address, quiet);

  // set contract addresses
  await fdc2Hub.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_MACHINE_REGISTRY, Contracts.TEE_EXTENSION_REGISTRY, Contracts.TEE_REPLICATION, Contracts.FLARE_SYSTEMS_MANAGER, Contracts.REWARD_MANAGER, Contracts.FDC2_REQUEST_FEE_CONFIGURATIONS]),
    [addressUpdater, teeMachineRegistry.address, teeExtensionRegistry.address, teeReplication.address, flareSystemsManager, rewardManager, fdc2RequestFeeConfigurations.address],
  );

  await fdc2Verification.updateContractAddresses(
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
      encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_WALLET_PROJECT_MANAGER, Contracts.TEE_WALLET_MANAGER, Contracts.TEE_WALLET_KEY_MANAGER, Contracts.TEE_VERIFICATION, Contracts.TEE_EXTENSION_REGISTRY, Contracts.FLARE_SYSTEMS_MANAGER]),
      [addressUpdater, teeWalletProjectManager.address, teeWalletManager.address, teeWalletKeyManager.address, teeVerification.address, teeExtensionRegistry.address, flareSystemsManager]
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
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_EXTENSION_REGISTRY, Contracts.TEE_MACHINE_REGISTRY, Contracts.TEE_WALLET_PROJECT_MANAGER, Contracts.TEE_WALLET_MANAGER, Contracts.TEE_WALLET_KEY_MANAGER, Contracts.TEE_SYSTEM_STATE_VERIFIER, Contracts.TEE_REPLICATION, Contracts.FDC2_HUB, Contracts.FDC2_VERIFICATION, Contracts.FLARE_SYSTEMS_MANAGER, Contracts.RELAY]),
    [addressUpdater, teeExtensionRegistry.address, teeMachineRegistry.address, teeWalletProjectManager.address, teeWalletManager.address, teeWalletKeyManager.address, teeSystemStateVerifier.address, teeReplication.address, fdc2Hub.address, fdc2Verification.address, flareSystemsManager, relay]
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

  await teeVrf.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_EXTENSION_REGISTRY, Contracts.TEE_MACHINE_REGISTRY, Contracts.TEE_WALLET_PROJECT_MANAGER, Contracts.TEE_WALLET_MANAGER, Contracts.TEE_WALLET_KEY_MANAGER]),
    [addressUpdater, teeExtensionRegistry.address, teeMachineRegistry.address, teeWalletProjectManager.address, teeWalletManager.address, teeWalletKeyManager.address]
  );

  // set FDC2 request fee configurations
  for (const fdc2RequestFee of parameters.fdc2RequestFees) {
    await fdc2RequestFeeConfigurations.setTypeAndSourceFee(
      web3.utils.utf8ToHex(fdc2RequestFee.attestationType).padEnd(66, "0"),
      web3.utils.utf8ToHex(fdc2RequestFee.source).padEnd(66, "0"),
      fdc2RequestFee.feeWei
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

  // add system supported platforms
  await teeExtensionRegistry.addSystemSupportedPlatforms(
    parameters.teeSupportedPlatforms.map(platform => web3.utils.utf8ToHex(platform).padEnd(66, "0"))
  );

  // add system supported key types and signing algorithms
  await teeExtensionRegistry.addSystemSupportedKeyTypesAndSigningAlgos(
    parameters.teeSupportedKeyTypesWithSigningAlgos.map(teeKeyConfig => web3.utils.utf8ToHex(teeKeyConfig.keyType).padEnd(66, "0")),
    parameters.teeSupportedKeyTypesWithSigningAlgos.map(teeKeyConfig => teeKeyConfig.signingAlgos.map(alg => web3.utils.utf8ToHex(alg).padEnd(66, "0"))),
  );

  // add system extension supported key types
  await teeExtensionRegistry.addSupportedKeyTypes(
    0, // system extension id
    [...new Set(parameters.teePaymentConfigurations.map(teePaymentConfig => web3.utils.utf8ToHex(teePaymentConfig.keyType).padEnd(66, "0")))]
  );

  // register system instructions senders
  await teeExtensionRegistry.registerSystemInstructionsSenders([
    teeReplication.address,
    teeVerification.address,
    teeWalletBackupManager.address,
    teeWalletKeyManager.address,
    teeWalletManager.address,
    ...teePaymentsList.map(teePayments => teePayments.address),
    teeVrf.address,
    fdc2Hub.address
  ]);

  // TODO add allowed tee and project owners

  // TODO add tee versions

  // TODO remove mock deploys

  const TeeExtensionInstructionsSenderMock = artifacts.require("TeeExtensionInstructionsSenderMock") as TeeExtensionInstructionsSenderMockContract;
  const teeExtensionInstructionsSenderMock = await TeeExtensionInstructionsSenderMock.new(
    teeExtensionRegistry.address,
    teeWalletProjectManager.address,
    teeWalletManager.address,
    teeWalletKeyManager.address
  );
  spewNewContractInfo(contracts, null, TeeExtensionInstructionsSenderMock.contractName, `TeeExtensionInstructionsSenderMock.sol`, teeExtensionInstructionsSenderMock.address, quiet);

  const PMWPaymentStatusVerifierMock = artifacts.require("PMWPaymentStatusVerifierMock") as PMWPaymentStatusVerifierMockContract;
  const pmwPaymentStatusVerifierMock = await PMWPaymentStatusVerifierMock.new(
    deployerAccount.address, // tmp address updater
    [],
    0,
    1
  );
  await pmwPaymentStatusVerifierMock.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.TEE_EXTENSION_REGISTRY, Contracts.TEE_WALLET_MANAGER, Contracts.TEE_WALLET_PROJECT_MANAGER, Contracts.FDC2_VERIFICATION, Contracts.FLARE_SYSTEMS_MANAGER]),
    [addressUpdater, teeExtensionRegistry.address, teeWalletManager.address, teeWalletProjectManager.address, fdc2Verification.address, flareSystemsManager]
  );
  spewNewContractInfo(contracts, null, PMWPaymentStatusVerifierMock.contractName, `PMWPaymentStatusVerifierMock.sol`, pmwPaymentStatusVerifierMock.address, quiet);

  // switch to production mode TODO
  // await fdc2Hub.switchToProductionMode();
  // await fdc2RequestFeeConfigurations.switchToProductionMode();

  // await teeExtensionRegistry.switchToProductionMode();
  // await teeFeeCalculator.switchToProductionMode();
  // await teeGovernance.switchToProductionMode();
  // await teeMachineRegistry.switchToProductionMode();
  // await teeOwnerAllowlist.switchToProductionMode();
  // for (const teePayments of teePaymentsList) {
  //   await teePayments.switchToProductionMode();
  // }
  // await teeReplication.switchToProductionMode();
  // await teeRewardOffersManager.switchToProductionMode();
  // await teeSystemStateVerifier.switchToProductionMode();
  // await teeVerification.switchToProductionMode();
  // await teeVersionManager.switchToProductionMode();
  // await teeWalletBackupManager.switchToProductionMode();
  // await teeWalletKeyManager.switchToProductionMode();
  // await teeWalletManager.switchToProductionMode();
  // await teeWalletProjectManager.switchToProductionMode();
  // await teeVrf.switchToProductionMode();

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
