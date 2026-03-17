/**
 * This script will deploy new or redeploy updated contracts.
 * It will output, on stdout, a json encoded list of contracts
 * that were deployed. It will write out to stderr, status info
 * as it executes.
 * @dev Do not send anything out via console.log unless it is
 * json defining the created contracts.
 */

import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { ChainParameters } from '../chain-config/chain-parameters';
import { Contracts } from "./Contracts";
import { spewNewContractInfo } from './deploy-utils';
import {
  FlareSystemsCalculatorContract,
  FlareSystemsManagerContract,
  FlareSystemsManagerInstance,
  VoterPreRegistryContract,
  VoterRegistryContract,
  VoterRegistryInstance,
} from '../../typechain-truffle';
import { Account } from 'web3-core';

export async function redeployContractsTee(
  hre: HardhatRuntimeEnvironment,
  oldContracts: Contracts,
  contracts: Contracts,
  parameters: ChainParameters,
  quiet: boolean = false
) {
  const web3 = hre.web3;
  const artifacts = hre.artifacts;

  const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

  const VoterRegistry = artifacts.require("VoterRegistry") as VoterRegistryContract;
  const VoterPreRegistry = artifacts.require("VoterPreRegistry") as VoterPreRegistryContract;
  const FlareSystemsCalculator = artifacts.require("FlareSystemsCalculator") as FlareSystemsCalculatorContract;
  const FlareSystemsManager = artifacts.require("FlareSystemsManager") as FlareSystemsManagerContract;

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
  const pChainStakeMirror = parameters.pChainStakeEnabled
    ? oldContracts.getContractAddress(Contracts.P_CHAIN_STAKE_MIRROR)
    : ZERO_ADDRESS;
  const wNat = oldContracts.getContractAddress(Contracts.WNAT);

  const flareSystemsManager: FlareSystemsManagerInstance = await FlareSystemsManager.at(contracts.getContractAddress(Contracts.FLARE_SYSTEMS_MANAGER));
  const voterRegistryOld: VoterRegistryInstance = await VoterRegistry.at(contracts.getContractAddress(Contracts.VOTER_REGISTRY));
  const entityManager = contracts.getContractAddress(Contracts.ENTITY_MANAGER);
  const wNatDelegationFee = contracts.getContractAddress(Contracts.WNAT_DELEGATION_FEE);

  // Read current state
  const currentRewardEpochId = await flareSystemsManager.getCurrentRewardEpochId();
  const {0: registeredVoters, 1: registrationWeights} = await voterRegistryOld.getRegisteredVotersAndRegistrationWeights(currentRewardEpochId);
  const newSigningPolicyInitializationStartBlockNumber = await voterRegistryOld.newSigningPolicyInitializationStartBlockNumber(currentRewardEpochId);
  const {0: _weightsSums, 1: _normalisedWeightsSum, 2: normalisedWeightsSumOfVotersWithPublicKeys} = await voterRegistryOld.getWeightsSums(currentRewardEpochId);

  // Deploy new contracts
  const voterRegistry = await VoterRegistry.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address, // tmp address updater
    parameters.maxVotersPerRewardEpoch,
    currentRewardEpochId,
    newSigningPolicyInitializationStartBlockNumber,
    normalisedWeightsSumOfVotersWithPublicKeys,
    registeredVoters,
    registrationWeights
  );
  spewNewContractInfo(contracts, null, VoterRegistry.contractName, `VoterRegistry.sol`, voterRegistry.address, quiet);

  const voterPreRegistry = await VoterPreRegistry.new(deployerAccount.address); // tmp address updater
  spewNewContractInfo(contracts, null, VoterPreRegistry.contractName, `VoterPreRegistry.sol`, voterPreRegistry.address, quiet);

  const flareSystemsCalculator = await FlareSystemsCalculator.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address, // tmp address updater
    parameters.wNatCapPPM,
    parameters.signingPolicySignNonPunishableDurationSeconds,
    parameters.signingPolicySignNonPunishableDurationBlocks,
    parameters.signingPolicySignNoRewardsDurationBlocks
  );
  spewNewContractInfo(contracts, null, FlareSystemsCalculator.contractName, `FlareSystemsCalculator.sol`, flareSystemsCalculator.address, quiet);

  // update contract addresses
  await voterRegistry.updateContractAddresses(
    encodeContractNames([
      Contracts.ADDRESS_UPDATER,
      Contracts.FLARE_SYSTEMS_MANAGER,
      Contracts.ENTITY_MANAGER,
      Contracts.FLARE_SYSTEMS_CALCULATOR,
    ]),
    [addressUpdater, flareSystemsManager.address, entityManager, flareSystemsCalculator.address]
  );

  await voterPreRegistry.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.FLARE_SYSTEMS_MANAGER, Contracts.VOTER_REGISTRY, Contracts.ENTITY_MANAGER]),
    [addressUpdater, flareSystemsManager.address, voterRegistry.address, entityManager]
  );

  await flareSystemsCalculator.updateContractAddresses(
    encodeContractNames([
      Contracts.ADDRESS_UPDATER,
      Contracts.FLARE_SYSTEMS_MANAGER,
      Contracts.ENTITY_MANAGER,
      Contracts.WNAT_DELEGATION_FEE,
      Contracts.VOTER_REGISTRY,
      Contracts.P_CHAIN_STAKE_MIRROR,
      Contracts.WNAT,
    ]),
    [
      addressUpdater,
      flareSystemsManager.address,
      entityManager,
      wNatDelegationFee,
      voterRegistry.address,
      pChainStakeMirror,
      wNat,
    ]
  );

  // switch to production mode
  await voterRegistry.switchToProductionMode();
  await flareSystemsCalculator.switchToProductionMode();

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

