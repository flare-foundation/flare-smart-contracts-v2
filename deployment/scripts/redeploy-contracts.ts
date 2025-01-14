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
import { PChainStakeMirrorVerifierContract, PChainStakeMirrorVerifierInstance } from '../../typechain-truffle/contracts/mock/PChainStakeMirrorVerifier';
import { FtsoConfigurations } from '../../scripts/libs/protocol/FtsoConfigurations';
import { RNatContract } from '../../typechain-truffle/contracts/rNat/implementation/RNat';
import { RNatAccountContract } from '../../typechain-truffle/contracts/rNat/implementation/RNatAccount';
import { WNatContract } from '../../typechain-truffle/flattened/FlareSmartContracts.sol/WNat';
import { RelayInitialConfig } from '../utils/RelayInitialConfig';
import { RelayContract, RelayInstance } from '../../typechain-truffle/contracts/protocol/implementation/Relay';
import { RewardManagerContract, RewardManagerInstance } from '../../typechain-truffle/contracts/protocol/implementation/RewardManager';
import { FlareSystemsManagerContract, FlareSystemsManagerInstance } from '../../typechain-truffle/contracts/protocol/implementation/FlareSystemsManager';
import { PollingFoundationContract } from '../../typechain-truffle/contracts/governance/implementation/PollingFoundation';
import { PollingManagementGroupContract } from '../../typechain-truffle/contracts/governance/implementation/PollingManagementGroup';
import { ValidatorRewardOffersManagerContract, ValidatorRewardOffersManagerInstance } from '../../typechain-truffle/contracts/staking/implementation/ValidatorRewardOffersManager';
import { FastUpdateIncentiveManagerContract, FastUpdateIncentiveManagerInstance } from '../../typechain-truffle/contracts/fastUpdates/implementation/FastUpdateIncentiveManager';
import { FastUpdaterContract } from '../../typechain-truffle/contracts/fastUpdates/implementation/FastUpdater';
import { FastUpdatesConfigurationContract, FastUpdatesConfigurationInstance } from '../../typechain-truffle/contracts/fastUpdates/implementation/FastUpdatesConfiguration';
import { FeeCalculatorContract } from '../../typechain-truffle/contracts/fastUpdates/implementation/FeeCalculator';
import { FtsoManagerProxyContract } from '../../typechain-truffle/contracts/fscV1/implementation/FtsoManagerProxy';
import { FtsoProxyContract } from '../../typechain-truffle/contracts/fscV1/implementation/FtsoProxy';
import { FtsoV2Contract } from '../../typechain-truffle/contracts/protocol/implementation/FtsoV2';
import { PriceSubmitterProxyContract } from '../../typechain-truffle/contracts/fscV1/implementation/PriceSubmitterProxy';
import { VoterWhitelisterProxyContract } from '../../typechain-truffle/contracts/fscV1/implementation/VoterWhitelisterProxy';
import { FtsoRewardManagerProxyContract, FtsoRewardManagerProxyInstance } from '../../typechain-truffle/contracts/fscV1/implementation/FtsoRewardManagerProxy';
import { EntityManagerContract } from '../../typechain-truffle/contracts/protocol/implementation/EntityManager';
import { VoterRegistryContract } from '../../typechain-truffle/contracts/protocol/implementation/VoterRegistry';
import { VoterPreRegistryContract } from '../../typechain-truffle/contracts/protocol/implementation/VoterPreRegistry';

export async function redeployContracts(
  hre: HardhatRuntimeEnvironment,
  oldContracts: Contracts,
  contracts: Contracts,
  parameters: ChainParameters,
  quiet: boolean = false
) {
  const web3 = hre.web3;
  const artifacts = hre.artifacts;
  const BN = web3.utils.toBN;

  const initialDeploy = true;
  const deployRNat = false;

  const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
  const BURN_ADDRESS = "0x000000000000000000000000000000000000dEaD";

  const Relay: RelayContract = artifacts.require("Relay");
  const FlareSystemsManager: FlareSystemsManagerContract = artifacts.require("FlareSystemsManager");
  const PollingFoundation: PollingFoundationContract = artifacts.require("PollingFoundation");
  const PollingManagementGroup: PollingManagementGroupContract = artifacts.require("PollingManagementGroup");
  const ValidatorRewardOffersManager: ValidatorRewardOffersManagerContract = artifacts.require("ValidatorRewardOffersManager");
  const PChainStakeMirrorVerifier: PChainStakeMirrorVerifierContract = artifacts.require("PChainStakeMirrorVerifier");
  const FastUpdateIncentiveManager: FastUpdateIncentiveManagerContract = artifacts.require("FastUpdateIncentiveManager");
  const FastUpdater: FastUpdaterContract = artifacts.require("FastUpdater");
  const FastUpdatesConfiguration: FastUpdatesConfigurationContract = artifacts.require("FastUpdatesConfiguration");
  const FeeCalculator: FeeCalculatorContract = artifacts.require("FeeCalculator");
  const WNat: WNatContract = artifacts.require("WNat");
  const RNat: RNatContract = artifacts.require("RNat");
  const RNatAccount: RNatAccountContract = artifacts.require("RNatAccount");
  const FtsoManagerProxy: FtsoManagerProxyContract = artifacts.require("FtsoManagerProxy");
  const FtsoProxy: FtsoProxyContract = artifacts.require("FtsoProxy");
  const FtsoV2: FtsoV2Contract = artifacts.require("FtsoV2");
  const PriceSubmitterProxy: PriceSubmitterProxyContract = artifacts.require("PriceSubmitterProxy");
  const VoterWhitelisterProxy: VoterWhitelisterProxyContract = artifacts.require("VoterWhitelisterProxy");
  const RewardManager: RewardManagerContract = artifacts.require("RewardManager");
  const FtsoRewardManagerProxy: FtsoRewardManagerProxyContract = artifacts.require("FtsoRewardManagerProxy");
  const EntityManager: EntityManagerContract = artifacts.require("EntityManager");
  const VoterRegistry: VoterRegistryContract = artifacts.require("VoterRegistry");
  const VoterPreRegistry: VoterPreRegistryContract = artifacts.require("VoterPreRegistry");

  let validatorRewardOffersManager: ValidatorRewardOffersManagerInstance;
  let pChainStakeMirrorVerifier: PChainStakeMirrorVerifierInstance;
  let relay: RelayInstance;
  let rewardManager: RewardManagerInstance;
  let ftsoRewardManagerProxy: FtsoRewardManagerProxyInstance;

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
  const wNat = await WNat.at(oldContracts.getContractAddress(Contracts.WNAT));
  const claimSetupManager = oldContracts.getContractAddress(Contracts.CLAIM_SETUP_MANAGER);

  const flareSystemsManager: FlareSystemsManagerInstance = await FlareSystemsManager.at(contracts.getContractAddress(Contracts.FLARE_SYSTEMS_MANAGER));
  const submission = contracts.getContractAddress(Contracts.SUBMISSION);
  const entityManager = contracts.getContractAddress(Contracts.ENTITY_MANAGER);
  const voterRegistry = contracts.getContractAddress(Contracts.VOTER_REGISTRY);
  const ftsoFeedPublisher = contracts.getContractAddress(Contracts.FTSO_FEED_PUBLISHER);
  const flareSystemsCalculator = contracts.getContractAddress(Contracts.FLARE_SYSTEMS_CALCULATOR);
  const wNatDelegationFee = contracts.getContractAddress(Contracts.WNAT_DELEGATION_FEE);
  const ftsoRewardOffersManager = contracts.getContractAddress(Contracts.FTSO_REWARD_OFFERS_MANAGER);

  // Deploy the contracts
  if (!initialDeploy) {
    const oldRelay = await Relay.at(contracts.getContractAddress(Contracts.RELAY));
    const currentRewardEpochId = await flareSystemsManager.getCurrentRewardEpochId();
    const startVotingRoundId = await flareSystemsManager.getStartVotingRoundId(currentRewardEpochId);
    const signingPolicyHash = await oldRelay.toSigningPolicyHash(currentRewardEpochId);
    const relayInitialConfig: RelayInitialConfig = {
      initialRewardEpochId: currentRewardEpochId.toNumber(),
      startingVotingRoundIdForInitialRewardEpochId: startVotingRoundId.toNumber(),
      initialSigningPolicyHash: signingPolicyHash,
      randomNumberProtocolId: parameters.ftsoProtocolId,
      firstVotingRoundStartTs: parameters.firstVotingRoundStartTs,
      votingEpochDurationSeconds: parameters.votingEpochDurationSeconds,
      firstRewardEpochStartVotingRoundId: parameters.firstRewardEpochStartVotingRoundId,
      rewardEpochDurationInVotingEpochs: parameters.rewardEpochDurationInVotingEpochs,
      thresholdIncreaseBIPS: parameters.relayThresholdIncreaseBIPS,
      messageFinalizationWindowInRewardEpochs: parameters.messageFinalizationWindowInRewardEpochs,
      feeCollectionAddress: ZERO_ADDRESS,
      feeConfigs: []
    }

    relay = await Relay.new(
      relayInitialConfig,
      flareSystemsManager.address
    );
    spewNewContractInfo(contracts, null, Relay.contractName, `Relay.sol`, relay.address, quiet);

    rewardManager = await RewardManager.new(
      governanceSettings,
      deployerAccount.address,
      deployerAccount.address, // tmp address updater
      contracts.getContractAddress(Contracts.REWARD_MANAGER), // old reward manager
      parameters.rewardManagerId
    );
    spewNewContractInfo(contracts, null, RewardManager.contractName, `RewardManager.sol`, rewardManager.address, quiet);

    if (parameters.pChainStakeEnabled) {
      await rewardManager.enablePChainStakeMirror();
    }

    ftsoRewardManagerProxy = await FtsoRewardManagerProxy.new(
      governanceSettings,
      deployerAccount.address,
      deployerAccount.address, // tmp address updater
      oldContracts.getContractAddress(Contracts.FTSO_REWARD_MANAGER) // old ftso reward manager
    );
    spewNewContractInfo(contracts, null, "FtsoRewardManager", `FtsoRewardManagerProxy.sol`, ftsoRewardManagerProxy.address, quiet);

  } else {
    relay = await Relay.at(contracts.getContractAddress(Contracts.RELAY));
    rewardManager = await RewardManager.at(contracts.getContractAddress(Contracts.REWARD_MANAGER));
    ftsoRewardManagerProxy = await FtsoRewardManagerProxy.at(contracts.getContractAddress(Contracts.FTSO_REWARD_MANAGER));
  }

  const pollingFoundation = await PollingFoundation.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address, // tmp address updater
    parameters.proposers
  );
  spewNewContractInfo(contracts, null, PollingFoundation.contractName, `PollingFoundation.sol`, pollingFoundation.address, quiet);

  const pollingManagementGroup = await PollingManagementGroup.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address // tmp address updater
  );
  await pollingManagementGroup.setMaintainer(deployerAccount.address); // tmp maintainer
  await pollingManagementGroup.setParameters( // can be called only from maintainer address
    parameters.votingDelaySeconds,
    parameters.votingPeriodSeconds,
    parameters.thresholdConditionBIPS,
    parameters.majorityConditionBIPS,
    BN(parameters.proposalFeeValueNAT).mul(BN(10).pow(BN(18))),
    parameters.addAfterRewardedEpochs,
    parameters.addAfterNotChilledEpochs,
    parameters.removeAfterNotRewardedEpochs,
    parameters.removeAfterEligibleProposals,
    parameters.removeAfterNonParticipatingProposals,
    parameters.removeForDays
  );
  await pollingManagementGroup.setMaintainer(parameters.maintainer);
  spewNewContractInfo(contracts, null, PollingManagementGroup.contractName, `PollingManagementGroup.sol`, pollingManagementGroup.address, quiet);

  const voterPreRegistry = await VoterPreRegistry.new(deployerAccount.address); // tmp address updater
  spewNewContractInfo(contracts, null, VoterPreRegistry.contractName, `VoterPreRegistry.sol`, voterPreRegistry.address, quiet);

  if (parameters.pChainStakeEnabled) {
    validatorRewardOffersManager = await ValidatorRewardOffersManager.new(
      governanceSettings,
      deployerAccount.address,
      deployerAccount.address // tmp address updater
    );
    spewNewContractInfo(contracts, null, ValidatorRewardOffersManager.contractName, `ValidatorRewardOffersManager.sol`, validatorRewardOffersManager.address, quiet);

    pChainStakeMirrorVerifier = await PChainStakeMirrorVerifier.new(
      pChainStakeMirrorMultiSigVoting,
      relay.address,
      parameters.pChainStakeMirrorMinDurationDays * 60 * 60 * 24,
      parameters.pChainStakeMirrorMaxDurationDays * 60 * 60 * 24,
      BN(parameters.pChainStakeMirrorMinAmountNAT).mul(BN(10).pow(BN(9))),
      BN(parameters.pChainStakeMirrorMaxAmountNAT).mul(BN(10).pow(BN(9)))
    );
    spewNewContractInfo(contracts, null, PChainStakeMirrorVerifier.contractName, `PChainStakeMirrorVerifier.sol`, pChainStakeMirrorVerifier.address, quiet);
  }

  let fastUpdateIncentiveManager: FastUpdateIncentiveManagerInstance;
  let fastUpdatesConfiguration: FastUpdatesConfigurationInstance;
  if (initialDeploy) {
    fastUpdateIncentiveManager = await FastUpdateIncentiveManager.new(
      governanceSettings,
      deployerAccount.address,
      deployerAccount.address, // tmp address updater
      parameters.baseSampleSize,
      parameters.baseRange,
      parameters.sampleIncreaseLimit,
      parameters.rangeIncreaseLimit,
      parameters.sampleSizeIncreasePriceWei,
      BN(parameters.rangeIncreasePriceNAT).mul(BN(10).pow(BN(18))),
      parameters.incentiveOfferDurationBlocks
    );
    spewNewContractInfo(contracts, null, FastUpdateIncentiveManager.contractName, `FastUpdateIncentiveManager.sol`, fastUpdateIncentiveManager.address, quiet);

    fastUpdatesConfiguration = await FastUpdatesConfiguration.new(
      governanceSettings,
      deployerAccount.address,
      deployerAccount.address // tmp address updater
    );
    spewNewContractInfo(contracts, null, FastUpdatesConfiguration.contractName, `FastUpdatesConfiguration.sol`, fastUpdatesConfiguration.address, quiet);
  } else {
    fastUpdateIncentiveManager = await FastUpdateIncentiveManager.at(contracts.getContractAddress(Contracts.FAST_UPDATE_INCENTIVE_MANAGER));
    fastUpdatesConfiguration = await FastUpdatesConfiguration.at(contracts.getContractAddress(Contracts.FAST_UPDATES_CONFIGURATION));
  }

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

  const feeCalculator = await FeeCalculator.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address, // tmp address updater
    parameters.defaultFeeWei
  );
  spewNewContractInfo(contracts, null, FeeCalculator.contractName, `FeeCalculator.sol`, feeCalculator.address, quiet);

  if (deployRNat) {
    const rNat = await RNat.new(
      governanceSettings,
      deployerAccount.address,
      deployerAccount.address, // tmp address updater
      parameters.rNatName,
      parameters.rNatSymbol,
      await wNat.decimals(),
      parameters.rNatManager,
      parameters.rNatFirstMonthStartTs);
    spewNewContractInfo(contracts, null, RNat.contractName, `RNat.sol`, rNat.address, quiet);

    const rNatAccount = await RNatAccount.new();
    await rNatAccount.initialize(rNat.address, rNat.address);
    spewNewContractInfo(contracts, null, RNatAccount.contractName, `RNatAccount.sol`, rNatAccount.address, quiet);

    await rNat.setLibraryAddress(rNatAccount.address);
    await rNat.setFundingAddress(parameters.rNatFundingAddress);
    if (parameters.rNatFundedByIncentivePool) {
      await rNat.enableIncentivePool();
    }

    if (parameters.rNatFundedByIncentivePool) {
      await rNat.updateContractAddresses(
        encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.CLAIM_SETUP_MANAGER, Contracts.WNAT, Contracts.INCENTIVE_POOL]),
        [addressUpdater, claimSetupManager, wNat.address, oldContracts.getContractAddress(Contracts.INCENTIVE_POOL)]
      );
    } else {
      await rNat.updateContractAddresses(
        encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.CLAIM_SETUP_MANAGER, Contracts.WNAT]),
        [addressUpdater, claimSetupManager, wNat.address]
      );
    }
    await rNat.switchToProductionMode();
  }

  const ftsoManagerProxy = await FtsoManagerProxy.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address, // tmp address updater
    oldContracts.getContractAddress(Contracts.FTSO_MANAGER) // old ftso manager
  );
  spewNewContractInfo(contracts, null, "FtsoManager", `FtsoManagerProxy.sol`, ftsoManagerProxy.address, quiet);

  const ftsoProxyAddresses: string[] = [];
  for (const ftso of parameters.ftsoProxies) {
    const ftsoProxy = await FtsoProxy.new(
      ftso.symbol,
      FtsoConfigurations.encodeFeedId(ftso.feedId),
      parameters.ftsoProtocolId,
      ftsoManagerProxy.address
    );
    ftsoProxyAddresses.push(ftsoProxy.address);
    spewNewContractInfo(contracts, null, `FTSO ${ftso.symbol}`, `FtsoProxy.sol`, ftsoProxy.address, quiet);
  }

  const ftsoV2 = await FtsoV2.new(
    governanceSettings,
    deployerAccount.address,
    deployerAccount.address // tmp address updater
  );
  spewNewContractInfo(contracts, null, FtsoV2.contractName, `FtsoV2.sol`, ftsoV2.address, quiet);

  const priceSubmitterProxy = await PriceSubmitterProxy.new(
    deployerAccount.address // tmp address updater
  );
  spewNewContractInfo(contracts, null, "PriceSubmitter", `PriceSubmitterProxy.sol`, priceSubmitterProxy.address, quiet);

  const voterWhitelisterProxy = await VoterWhitelisterProxy.new(
    oldContracts.getContractAddress(Contracts.PRICE_SUBMITTER)
  );
  spewNewContractInfo(contracts, null, "VoterWhitelister", `VoterWhitelisterProxy.sol`, voterWhitelisterProxy.address, quiet);

  // Update contract addresses
  await pollingFoundation.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.FLARE_SYSTEMS_MANAGER, Contracts.SUPPLY, Contracts.SUBMISSION, Contracts.GOVERNANCE_VOTE_POWER]),
    [addressUpdater, flareSystemsManager.address, supply, submission, governanceVotePower]
  );

  await pollingManagementGroup.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.FLARE_SYSTEMS_MANAGER, Contracts.VOTER_REGISTRY, Contracts.REWARD_MANAGER, Contracts.ENTITY_MANAGER]),
    [addressUpdater, flareSystemsManager.address, voterRegistry, rewardManager.address, entityManager]
  );

  await voterPreRegistry.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.FLARE_SYSTEMS_MANAGER, Contracts.VOTER_REGISTRY, Contracts.ENTITY_MANAGER]),
    [addressUpdater, flareSystemsManager.address, voterRegistry, entityManager]
  );

  if (parameters.pChainStakeEnabled) {
    await validatorRewardOffersManager!.updateContractAddresses(
      encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.FLARE_SYSTEMS_MANAGER, Contracts.REWARD_MANAGER, Contracts.INFLATION]),
      [addressUpdater, flareSystemsManager.address, rewardManager.address, inflation]
    );
  }

  if (initialDeploy) {
    await fastUpdateIncentiveManager.updateContractAddresses(
      encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.FLARE_SYSTEMS_MANAGER, Contracts.FAST_UPDATER, Contracts.FAST_UPDATES_CONFIGURATION, Contracts.REWARD_MANAGER, Contracts.INFLATION]),
      [addressUpdater, flareSystemsManager.address, fastUpdater.address, fastUpdatesConfiguration.address, rewardManager.address, inflation]
    );

    await fastUpdatesConfiguration.updateContractAddresses(
      encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.FAST_UPDATER]),
      [addressUpdater, fastUpdater.address]
    );
  } else {
    const pChainStakeMirror = parameters.pChainStakeEnabled ? oldContracts.getContractAddress(Contracts.P_CHAIN_STAKE_MIRROR) : ZERO_ADDRESS;
    await rewardManager.updateContractAddresses(
      encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.VOTER_REGISTRY, Contracts.CLAIM_SETUP_MANAGER, Contracts.FLARE_SYSTEMS_MANAGER, Contracts.FLARE_SYSTEMS_CALCULATOR, Contracts.P_CHAIN_STAKE_MIRROR, Contracts.WNAT, Contracts.FTSO_REWARD_MANAGER]),
      [addressUpdater, voterRegistry, claimSetupManager, flareSystemsManager.address, flareSystemsCalculator, pChainStakeMirror, wNat.address, ftsoRewardManagerProxy.address]
    );

    await ftsoRewardManagerProxy.updateContractAddresses(
      encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.REWARD_MANAGER, Contracts.FLARE_SYSTEMS_MANAGER, Contracts.WNAT_DELEGATION_FEE, Contracts.WNAT, Contracts.CLAIM_SETUP_MANAGER]),
      [addressUpdater, rewardManager.address, flareSystemsManager.address, wNatDelegationFee, wNat.address, claimSetupManager]
    );
  }

  await fastUpdater.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.FLARE_SYSTEMS_MANAGER, Contracts.FAST_UPDATE_INCENTIVE_MANAGER, Contracts.VOTER_REGISTRY, Contracts.FAST_UPDATES_CONFIGURATION, Contracts.FTSO_FEED_PUBLISHER, Contracts.FEE_CALCULATOR]),
    [addressUpdater, flareSystemsManager.address, fastUpdateIncentiveManager.address, voterRegistry, fastUpdatesConfiguration.address, ftsoFeedPublisher, feeCalculator.address]
  );

  await feeCalculator.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.FAST_UPDATES_CONFIGURATION]),
    [addressUpdater, fastUpdatesConfiguration.address]
  );

  await ftsoManagerProxy.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.FTSO_REWARD_MANAGER, Contracts.FTSO_REGISTRY, Contracts.REWARD_MANAGER, Contracts.FLARE_SYSTEMS_MANAGER, Contracts.FAST_UPDATER, Contracts.FAST_UPDATES_CONFIGURATION, Contracts.RELAY]),
    [addressUpdater, ftsoRewardManagerProxy.address, oldContracts.getContractAddress(Contracts.FTSO_REGISTRY), rewardManager.address, flareSystemsManager.address, fastUpdater.address, fastUpdatesConfiguration.address, relay.address]
  );

  await ftsoV2.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.FAST_UPDATER, Contracts.FAST_UPDATES_CONFIGURATION, Contracts.RELAY]),
    [addressUpdater, fastUpdater.address, fastUpdatesConfiguration.address, relay.address]
  );

  await priceSubmitterProxy.updateContractAddresses(
    encodeContractNames([Contracts.ADDRESS_UPDATER, Contracts.RELAY, Contracts.FTSO_REGISTRY, Contracts.FTSO_MANAGER, Contracts.VOTER_WHITELISTER]),
    [addressUpdater, relay.address, oldContracts.getContractAddress(Contracts.FTSO_REGISTRY), ftsoManagerProxy.address, voterWhitelisterProxy.address]
  );

  if (initialDeploy) {
    const entityManagerContract = await EntityManager.at(entityManager);
    await entityManagerContract.setPublicKeyVerifier(fastUpdater.address);
    await flareSystemsManager.setVoterRegistrationTriggerContract(voterPreRegistry.address);
    const voterRegistryContract = await VoterRegistry.at(voterRegistry);
    await voterRegistryContract.setSystemRegistrationContractAddress(voterPreRegistry.address);
    // cannot add feeds to fast updater, we need first finalizations
  } else {
    // reset feeds
    const numberOfFeeds = await fastUpdatesConfiguration.getNumberOfFeeds();
    await fastUpdater.resetFeeds([...Array(numberOfFeeds.toNumber()).keys()])
  }

  // set reward offers manager list
  if (parameters.pChainStakeEnabled) {
    await rewardManager.setRewardOffersManagerList([ftsoRewardOffersManager, fastUpdateIncentiveManager.address, validatorRewardOffersManager!.address]);
  } else {
    await rewardManager.setRewardOffersManagerList([ftsoRewardOffersManager, fastUpdateIncentiveManager.address]);
  }

  if (initialDeploy) {
    // set rewards offer switchover trigger contracts
    if (parameters.pChainStakeEnabled) {
      await flareSystemsManager.setRewardEpochSwitchoverTriggerContracts([ftsoRewardOffersManager, fastUpdateIncentiveManager.address, validatorRewardOffersManager!.address]);
    } else {
      await flareSystemsManager.setRewardEpochSwitchoverTriggerContracts([ftsoRewardOffersManager, fastUpdateIncentiveManager.address]);
    }
  } else {
    // set initial data on reward manager
    await rewardManager.setInitialRewardData();

    // activate reward manager
    await rewardManager.activate();

    // enable claims
    await rewardManager.enableClaims();
    await ftsoRewardManagerProxy.enable();
  }

  // set fee = 0 for crypto feeds (category 1)
  await feeCalculator.setCategoriesFees([1], [0]);

  // set ftso proxy addresses as free fetch addresses
  await fastUpdater.setFreeFetchAddresses(ftsoProxyAddresses);

  // set burn address as fee destination
  await fastUpdater.setFeeDestination(BURN_ADDRESS);

  // Switch to production mode
  await pollingFoundation.switchToProductionMode();
  await pollingManagementGroup.switchToProductionMode();
  if (parameters.pChainStakeEnabled) {
    await validatorRewardOffersManager!.switchToProductionMode();
  }
  if (initialDeploy) {
    await fastUpdateIncentiveManager.switchToProductionMode();
    await fastUpdatesConfiguration.switchToProductionMode();
  } else {
    await rewardManager.switchToProductionMode();
    await ftsoRewardManagerProxy.switchToProductionMode();
  }
  await fastUpdater.switchToProductionMode();
  await feeCalculator.switchToProductionMode();
  await ftsoManagerProxy.switchToProductionMode();

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

