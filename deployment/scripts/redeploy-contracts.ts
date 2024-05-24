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
import { FastUpdateIncentiveManagerContract, FastUpdaterContract, FastUpdaterInstance, FastUpdatesConfigurationContract, PChainStakeMirrorVerifierContract, PollingFoundationContract, PollingFtsoContract, ValidatorRewardOffersManagerContract, ValidatorRewardOffersManagerInstance } from '../../typechain-truffle';
import { PChainStakeMirrorVerifierInstance } from '../../typechain-truffle/contracts/mock/PChainStakeMirrorVerifier';
import { FtsoConfigurations } from '../../scripts/libs/protocol/FtsoConfigurations';

let fs = require('fs');

export async function redeployContracts(hre: HardhatRuntimeEnvironment, oldContracts: Contracts, contracts: Contracts, parameters: ChainParameters, quiet: boolean = false) {
  const web3 = hre.web3;
  const artifacts = hre.artifacts;
  const BN = web3.utils.toBN;

  const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

  const PollingFoundation: PollingFoundationContract = artifacts.require("PollingFoundation");
  const PollingFtso: PollingFtsoContract = artifacts.require("PollingFtso");
  const ValidatorRewardOffersManager: ValidatorRewardOffersManagerContract = artifacts.require("ValidatorRewardOffersManager");
  const PChainStakeMirrorVerifier: PChainStakeMirrorVerifierContract = artifacts.require("PChainStakeMirrorVerifier");
  const FastUpdateIncentiveManager: FastUpdateIncentiveManagerContract = artifacts.require("FastUpdateIncentiveManager");
  const FastUpdater: FastUpdaterContract = artifacts.require("FastUpdater");
  const FastUpdatesConfiguration: FastUpdatesConfigurationContract = artifacts.require("FastUpdatesConfiguration");

  let validatorRewardOffersManager: ValidatorRewardOffersManagerInstance;
  let pChainStakeMirrorVerifier: PChainStakeMirrorVerifierInstance;

  // Define accounts in play for the deployment process
  let deployerAccount: any;

  try {
    deployerAccount = web3.eth.accounts.privateKeyToAccount(parameters.deployerPrivateKey);
  } catch (e) {
    throw Error("Check .env file, if the private keys are correct and are prefixed by '0x'.\n" + e)
  }

  // Wire up the default account that will do the deployment
  web3.eth.defaultAccount = deployerAccount.address;

  const governanceSettings = oldContracts.getContractAddress(Contracts.GOVERNANCE_SETTINGS);
  const addressUpdater = oldContracts.getContractAddress(Contracts.ADDRESS_UPDATER);
  const supply = oldContracts.getContractAddress(Contracts.SUPPLY);
  const governanceVotePower = oldContracts.getContractAddress(Contracts.GOVERNANCE_VOTE_POWER);
  const inflation = oldContracts.getContractAddress(Contracts.INFLATION);
  const pChainStakeMirrorMultiSigVoting = parameters.pChainStakeEnabled ? oldContracts.getContractAddress(Contracts.P_CHAIN_STAKE_MIRROR_MULTI_SIG_VOTING) : ZERO_ADDRESS;
  const flareDaemon = oldContracts.getContractAddress(Contracts.FLARE_DAEMON);

  const flareSystemsManager = contracts.getContractAddress(Contracts.FLARE_SYSTEMS_MANAGER);
  const submission = contracts.getContractAddress(Contracts.SUBMISSION);
  const voterRegistry = contracts.getContractAddress(Contracts.VOTER_REGISTRY);
  const rewardManager = contracts.getContractAddress(Contracts.REWARD_MANAGER);
  const relay = contracts.getContractAddress(Contracts.RELAY);
  const ftsoFeedPublisher = contracts.getContractAddress(Contracts.FTSO_FEED_PUBLISHER);

  // Deploy the contracts
  const pollingFoundation = await PollingFoundation.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address, // tmp address updater
    parameters.proposers
  );
  spewNewContractInfo(contracts, null, PollingFoundation.contractName, `PollingFoundation.sol`, pollingFoundation.address, quiet);

  const pollingFtso = await PollingFtso.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address // tmp address updater
  );
  await pollingFtso.setMaintainer(deployerAccount.address);
  await pollingFtso.setParameters( // can be called only from maintainer address
    parameters.votingDelaySeconds,
    parameters.votingPeriodSeconds,
    parameters.thresholdConditionBIPS,
    parameters.majorityConditionBIPS,
    BN(parameters.proposalFeeValueNAT).mul(BN(10).pow(BN(18)))
  );
  await pollingFtso.setMaintainer(parameters.maintainer);
  spewNewContractInfo(contracts, null, PollingFtso.contractName, `PollingFtso.sol`, pollingFtso.address, quiet);

  if (parameters.pChainStakeEnabled) {
    validatorRewardOffersManager = await ValidatorRewardOffersManager.new(
      governanceSettings,
      deployerAccount.address,
      deployerAccount.address // tmp address updater
    );
    spewNewContractInfo(contracts, null, ValidatorRewardOffersManager.contractName, `ValidatorRewardOffersManager.sol`, validatorRewardOffersManager.address, quiet);

    pChainStakeMirrorVerifier = await PChainStakeMirrorVerifier.new(
      pChainStakeMirrorMultiSigVoting,
      relay,
      parameters.pChainStakeMirrorMinDurationDays * 60 * 60 * 24,
      parameters.pChainStakeMirrorMaxDurationDays * 60 * 60 * 24,
      BN(parameters.pChainStakeMirrorMinAmountNAT).mul(BN(10).pow(BN(9))),
      BN(parameters.pChainStakeMirrorMaxAmountNAT).mul(BN(10).pow(BN(9)))
    );
    spewNewContractInfo(contracts, null, PChainStakeMirrorVerifier.contractName, `PChainStakeMirrorVerifier.sol`, pChainStakeMirrorVerifier.address, quiet);
  }

  const fastUpdateIncentiveManager = await FastUpdateIncentiveManager.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address, // tmp address updater
    parameters.baseSampleSize,
    parameters.baseRange,
    parameters.sampleIncreaseLimit,
    parameters.rangeIncreaseLimit,
    BN(parameters.sampleSizeIncreasePriceNAT).mul(BN(10).pow(BN(18))),
    BN(parameters.rangeIncreasePriceNAT).mul(BN(10).pow(BN(18))),
    parameters.incentiveOfferDurationBlocks
  );
  spewNewContractInfo(contracts, null, FastUpdateIncentiveManager.contractName, `FastUpdateIncentiveManager.sol`, fastUpdateIncentiveManager.address, quiet);

  const fastUpdater = await FastUpdater.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address, // tmp address updater
    flareDaemon,
    parameters.firstVotingRoundStartTs,
    parameters.votingEpochDurationSeconds,
    parameters.submissionWindowBlocks
  );
  spewNewContractInfo(contracts, null, FastUpdater.contractName, `FastUpdater.sol`, fastUpdater.address, quiet);

  const fastUpdatesConfiguration = await FastUpdatesConfiguration.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address, // tmp address updater
  );
  spewNewContractInfo(contracts, null, FastUpdatesConfiguration.contractName, `FastUpdatesConfiguration.sol`, fastUpdatesConfiguration.address, quiet);

  // Update contract addresses
  await pollingFoundation.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.FLARE_SYSTEMS_MANAGER, Contracts.SUPPLY, Contracts.SUBMISSION, Contracts.GOVERNANCE_VOTE_POWER]),
    [addressUpdater, flareSystemsManager, supply, submission, governanceVotePower]
  );

  await pollingFtso.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.FLARE_SYSTEMS_MANAGER, Contracts.VOTER_REGISTRY]),
    [addressUpdater, flareSystemsManager, voterRegistry]
  );

  if (parameters.pChainStakeEnabled) {
    await validatorRewardOffersManager!.updateContractAddresses(
      encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.FLARE_SYSTEMS_MANAGER, Contracts.REWARD_MANAGER, Contracts.INFLATION]),
      [addressUpdater, flareSystemsManager, rewardManager, inflation]
    );
  }

  await fastUpdateIncentiveManager!.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.FLARE_SYSTEMS_MANAGER, Contracts.FAST_UPDATER, Contracts.FAST_UPDATES_CONFIGURATION, Contracts.REWARD_MANAGER, Contracts.INFLATION]),
    [addressUpdater, flareSystemsManager, fastUpdater.address, fastUpdatesConfiguration.address, rewardManager, inflation]
  );

  await fastUpdater.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.FLARE_SYSTEMS_MANAGER, Contracts.FAST_UPDATE_INCENTIVE_MANAGER, Contracts.VOTER_REGISTRY, Contracts.FAST_UPDATES_CONFIGURATION, Contracts.FTSO_FEED_PUBLISHER]),
    [addressUpdater, flareSystemsManager, fastUpdateIncentiveManager.address, voterRegistry, fastUpdatesConfiguration.address, ftsoFeedPublisher]
  );

  await fastUpdatesConfiguration.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.FAST_UPDATER]),
    [addressUpdater, fastUpdater.address]
  );

  // Add feeds to FastUpdatesConfiguration
  await fastUpdatesConfiguration.addFeeds(
    parameters.feedConfigurations.map(fc => {
      return {
        feedId: FtsoConfigurations.encodeFeedId(fc.feedId),
        rewardBandValue: fc.rewardBandValue,
        inflationShare: fc.inflationShare
      }
    })
  );

  // Switch to production mode
  await pollingFoundation.switchToProductionMode();
  await pollingFtso.switchToProductionMode();
  if (parameters.pChainStakeEnabled) {
    await validatorRewardOffersManager!.switchToProductionMode();
  }
  await fastUpdateIncentiveManager.switchToProductionMode();
  await fastUpdater.switchToProductionMode();
  await fastUpdatesConfiguration.switchToProductionMode();

  if (!quiet) {
    console.error("Contracts in JSON:");
    console.log(contracts.serialize());
    console.error("Deploy complete.");
  }

  function encodeContractNames(names: string[]): string[] {
    return names.map(name => encodeString(name));
  }

  function encodeString(text: string): string {
    return web3.utils.keccak256(web3.eth.abi.encodeParameters(["string"], [text]));
  }
}

