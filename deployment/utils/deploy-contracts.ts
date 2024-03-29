import fs from "fs";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ISigningPolicy } from "../../scripts/libs/protocol/SigningPolicy";
import {
  AddressBinderContract,
  AddressBinderInstance,
  CChainStakeContract,
  CChainStakeInstance,
  CleanupBlockNumberManagerContract,
  CleanupBlockNumberManagerInstance,
  EntityManagerContract,
  EntityManagerInstance,
  FlareSystemsCalculatorContract,
  FlareSystemsCalculatorInstance,
  FlareSystemsManagerContract,
  FlareSystemsManagerInstance,
  FtsoFeedDecimalsContract,
  FtsoFeedDecimalsInstance,
  FtsoFeedPublisherContract,
  FtsoFeedPublisherInstance,
  FtsoInflationConfigurationsContract,
  FtsoInflationConfigurationsInstance,
  FtsoRewardOffersManagerContract,
  FtsoRewardOffersManagerInstance,
  GovernanceVotePowerContract,
  GovernanceVotePowerInstance,
  MockContractContract,
  MockContractInstance,
  PChainStakeMirrorContract,
  PChainStakeMirrorInstance,
  PChainStakeMirrorVerifierContract,
  PChainStakeMirrorVerifierInstance,
  RelayContract,
  RelayInstance,
  RewardManagerContract,
  RewardManagerInstance,
  SubmissionContract,
  SubmissionInstance,
  VPContractContract,
  VPContractInstance,
  VoterRegistryContract,
  VoterRegistryInstance,
  WNatContract,
  WNatDelegationFeeContract,
  WNatDelegationFeeInstance,
  WNatInstance,
} from "../../typechain-truffle";

import { time } from "@nomicfoundation/hardhat-network-helpers";
import { Contracts } from "../scripts/Contracts";
import { Account } from "web3-core";
import {
  TIMELOCK_SEC,
  encodeContractNames,
  REWARD_EPOCH_DURATION_IN_SEC,
  FIRST_REWARD_EPOCH_VOTING_ROUND_ID,
  systemSettings,
  getSigningPolicyHash,
  FTSO_PROTOCOL_ID,
} from "../tasks/run-simulation";
import { getLogger } from "./logger";
import { executeTimelockedGovernanceCall, testDeployGovernanceSettings } from "./contract-helpers";
import { FtsoConfigurations } from "../../scripts/libs/protocol/FtsoConfigurations";

export interface DeployedContracts {
  readonly pChainStakeMirror: PChainStakeMirrorInstance;
  readonly cChainStake: CChainStakeInstance;
  readonly vp: VPContractInstance;
  readonly wNat: WNatInstance;
  readonly governanceVotePower: GovernanceVotePowerInstance;
  readonly addressBinder: AddressBinderInstance;
  readonly pChainVerifier: PChainStakeMirrorVerifierInstance;
  readonly verifierMock: MockContractInstance;
  readonly entityManager: EntityManagerInstance;
  readonly voterRegistry: VoterRegistryInstance;
  readonly flareSystemsCalculator: FlareSystemsCalculatorInstance;
  readonly flareSystemsManager: FlareSystemsManagerInstance;
  readonly rewardManager: RewardManagerInstance;
  readonly submission: SubmissionInstance;
  readonly relay: RelayInstance;
  readonly wNatDelegationFee: WNatDelegationFeeInstance;
  readonly ftsoInflationConfigurations: FtsoInflationConfigurationsInstance;
  readonly ftsoRewardOffersManager: FtsoRewardOffersManagerInstance;
  readonly ftsoFeedDecimals: FtsoFeedDecimalsInstance;
  readonly ftsoFeedPublisher: FtsoFeedPublisherInstance;
  readonly cleanupBlockNumberManager: CleanupBlockNumberManagerInstance;
}

const logger = getLogger("contracts");

export async function deployContracts(
  accounts: Account[],
  hre: HardhatRuntimeEnvironment,
  governanceAccount: Account
): Promise<[DeployedContracts, number, ISigningPolicy]> {
  const FLARE_DAEMON_ADDR = governanceAccount.address;
  const ADDRESS_UPDATER_ADDR = accounts[1].address;
  const CLEANER_CONTRACT_ADDR = accounts[2].address;
  const CLEANUP_BLOCK_NUMBER_MANAGER_ADDR = accounts[3].address;
  const MULTI_SIG_VOTING_ADDR = accounts[4].address;
  const RELAY_ADDR = accounts[5].address;
  const CLAIM_SETUP_MANAGER_ADDR = accounts[5].address;
  const INFLATION_ADDR = accounts[5].address;

  const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

  const MockContract: MockContractContract = hre.artifacts.require("MockContract");
  const WNat: WNatContract = hre.artifacts.require("WNat");
  const VPContract: VPContractContract = hre.artifacts.require("VPContract");
  const PChainStakeMirror: PChainStakeMirrorContract = hre.artifacts.require("PChainStakeMirror");
  const GovernanceVotePower: GovernanceVotePowerContract = hre.artifacts.require("GovernanceVotePower" as any);
  const AddressBinder: AddressBinderContract = hre.artifacts.require("AddressBinder");
  const PChainStakeMirrorVerifier: PChainStakeMirrorVerifierContract = hre.artifacts.require("PChainStakeMirrorVerifier");
  const EntityManager: EntityManagerContract = hre.artifacts.require("EntityManager");
  const VoterRegistry: VoterRegistryContract = hre.artifacts.require("VoterRegistry");
  const FlareSystemsCalculator: FlareSystemsCalculatorContract = hre.artifacts.require("FlareSystemsCalculator");
  const FlareSystemsManager: FlareSystemsManagerContract = hre.artifacts.require("FlareSystemsManager");
  const RewardManager: RewardManagerContract = hre.artifacts.require("RewardManager");
  const Submission: SubmissionContract = hre.artifacts.require("Submission");
  const CChainStake: CChainStakeContract = hre.artifacts.require("CChainStake");
  const WNatDelegationFee: WNatDelegationFeeContract = hre.artifacts.require("WNatDelegationFee");
  const FtsoInflationConfigurations: FtsoInflationConfigurationsContract = hre.artifacts.require("FtsoInflationConfigurations");
  const FtsoRewardOffersManager: FtsoRewardOffersManagerContract = hre.artifacts.require("FtsoRewardOffersManager");
  const FtsoFeedDecimals: FtsoFeedDecimalsContract = hre.artifacts.require("FtsoFeedDecimals");
  const FtsoFeedPublisher: FtsoFeedPublisherContract = hre.artifacts.require("FtsoFeedPublisher");
  const CleanupBlockNumberManager: CleanupBlockNumberManagerContract = hre.artifacts.require("CleanupBlockNumberManager");
  const Relay: RelayContract = hre.artifacts.require("Relay");

  logger.info(`Deploying contracts, initial network time: ${new Date((await time.latest()) * 1000).toISOString()}`);

  const pChainStakeMirror: PChainStakeMirrorInstance = await PChainStakeMirror.new(
    governanceAccount.address,
    governanceAccount.address,
    ADDRESS_UPDATER_ADDR,
    2
  );
  const cChainStake = await CChainStake.new(
    governanceAccount.address,
    governanceAccount.address,
    ADDRESS_UPDATER_ADDR,
    0,
    100,
    10000000000,
    50
  );

  const governanceSettings = await testDeployGovernanceSettings(
    hre.artifacts,
    governanceAccount.address,
    TIMELOCK_SEC,
    [governanceAccount.address],
    hre.network
  );

  const wNat = await WNat.new(governanceAccount.address, "Wrapped NAT", "WNAT");
  await wNat.switchToProductionMode({ from: governanceAccount.address });
  const switchToProdModeTime = await time.latest();

  const vpContract = await VPContract.new(wNat.address, false);
  await wNat.setWriteVpContract(vpContract.address);
  await wNat.setReadVpContract(vpContract.address);
  const governanceVotePower = await GovernanceVotePower.new(
    wNat.address,
    pChainStakeMirror.address,
    cChainStake.address
  );
  await wNat.setGovernanceVotePower(governanceVotePower.address);

  await time.increaseTo(switchToProdModeTime + TIMELOCK_SEC);
  await executeTimelockedGovernanceCall(hre.artifacts, wNat, governance =>
    wNat.setWriteVpContract(vpContract.address, { from: governance })
  );
  await executeTimelockedGovernanceCall(hre.artifacts, wNat, governance =>
    wNat.setReadVpContract(vpContract.address, { from: governance })
  );
  await executeTimelockedGovernanceCall(hre.artifacts, wNat, governance =>
    wNat.setGovernanceVotePower(governanceVotePower.address, { from: governance })
  );

  const addressBinder: AddressBinderInstance = await AddressBinder.new();
  const pChainVerifier = await PChainStakeMirrorVerifier.new(MULTI_SIG_VOTING_ADDR, RELAY_ADDR, 10, 1000, 5, 5000);

  const verifierMock = await MockContract.new();

  await pChainStakeMirror.updateContractAddresses(
    encodeContractNames(hre.web3, [
      Contracts.ADDRESS_UPDATER,
      Contracts.ADDRESS_BINDER,
      Contracts.GOVERNANCE_VOTE_POWER,
      Contracts.CLEANUP_BLOCK_NUMBER_MANAGER,
      Contracts.P_CHAIN_STAKE_MIRROR_VERIFIER,
    ]),
    [
      ADDRESS_UPDATER_ADDR,
      addressBinder.address,
      governanceVotePower.address,
      CLEANUP_BLOCK_NUMBER_MANAGER_ADDR,
      verifierMock.address,
    ],
    { from: ADDRESS_UPDATER_ADDR }
  );

  await pChainStakeMirror.setCleanerContract(CLEANER_CONTRACT_ADDR);
  await pChainStakeMirror.activate();

  // Set time to previous reward epoch start.
  await time.increaseTo(Math.floor(Date.now() / 1000) - REWARD_EPOCH_DURATION_IN_SEC + 1);

  const rewardEpochStart = await time.latest();

  const entityManager = await EntityManager.new(governanceSettings.address, governanceAccount.address, 4);

  const initialVoters = [governanceAccount.address];
  const initialWeights = [1000];
  const initialThreshold = 500;

  const voterRegistry = await VoterRegistry.new(
    governanceSettings.address,
    governanceAccount.address,
    ADDRESS_UPDATER_ADDR,
    100,
    0,
    initialVoters,
    initialWeights
  );

  const flareSystemsCalculator = await FlareSystemsCalculator.new(
    governanceSettings.address,
    governanceAccount.address,
    ADDRESS_UPDATER_ADDR,
    2500,
    200,
    100,
    100
  );

  const initialSigningPolicy: ISigningPolicy = {
    rewardEpochId: 0,
    startVotingRoundId: FIRST_REWARD_EPOCH_VOTING_ROUND_ID,
    threshold: initialThreshold,
    seed: web3.utils.keccak256("123"),
    voters: initialVoters,
    weights: initialWeights,
  };

  const initialSettings = {
    initialRandomVotePowerBlockSelectionSize: 1,
    initialRewardEpochId: 0,
    initialRewardEpochThreshold: initialThreshold
}

  const settings = systemSettings(rewardEpochStart);
  const flareSystemsManager: FlareSystemsManagerInstance = await FlareSystemsManager.new(
    governanceSettings.address,
    governanceAccount.address,
    ADDRESS_UPDATER_ADDR,
    FLARE_DAEMON_ADDR,
    settings.updatableSettings,
    settings.firstVotingRoundStartTs,
    settings.votingEpochDurationSeconds,
    settings.firstRewardEpochStartVotingRoundId,
    settings.rewardEpochDurationInVotingEpochs,
    initialSettings
  );

  const rewardManager = await RewardManager.new(
    governanceSettings.address,
    governanceAccount.address,
    ADDRESS_UPDATER_ADDR,
    ZERO_ADDRESS,
    0
  );

  const relay = await Relay.new(
    flareSystemsManager.address,
    initialSigningPolicy.rewardEpochId,
    initialSigningPolicy.startVotingRoundId,
    getSigningPolicyHash(initialSigningPolicy),
    FTSO_PROTOCOL_ID,
    settings.firstVotingRoundStartTs,
    settings.votingEpochDurationSeconds,
    settings.firstRewardEpochStartVotingRoundId,
    settings.rewardEpochDurationInVotingEpochs,
    12000,
    100
  );

  const submission = await Submission.new(
    governanceSettings.address,
    governanceAccount.address,
    ADDRESS_UPDATER_ADDR,
    false
  );

  const wNatDelegationFee = await WNatDelegationFee.new(
    ADDRESS_UPDATER_ADDR,
    2,
    2000
  );

  const ftsoInflationConfigurations = await FtsoInflationConfigurations.new(
    governanceSettings.address,
    governanceAccount.address
  );

  const ftsoRewardOffersManager = await FtsoRewardOffersManager.new(
    governanceSettings.address,
    governanceAccount.address,
    ADDRESS_UPDATER_ADDR,
    100
  );

  const ftsoFeedDecimals = await FtsoFeedDecimals.new(
    governanceSettings.address,
    governanceAccount.address,
    ADDRESS_UPDATER_ADDR,
    2,
    5,
    0,
    [
      { feedId: FtsoConfigurations.encodeFeedId({category: 1, name: "BTC/USD"}), decimals: 2 },
      { feedId: FtsoConfigurations.encodeFeedId({category: 1, name: "ETH/USD"}), decimals: 3 }
    ]
  );

  const ftsoFeedPublisher = await FtsoFeedPublisher.new(
    governanceSettings.address,
    governanceAccount.address,
    ADDRESS_UPDATER_ADDR,
    FTSO_PROTOCOL_ID,
    200
  );

  const cleanupBlockNumberManager = await CleanupBlockNumberManager.new(
    governanceAccount.address,
    ADDRESS_UPDATER_ADDR,
    "FlareSystemsManager"
  );

  await flareSystemsCalculator.enablePChainStakeMirror({ from: governanceAccount.address });
  await rewardManager.enablePChainStakeMirror({ from: governanceAccount.address });

  await pChainStakeMirror.updateContractAddresses(
    encodeContractNames(hre.web3, [
      Contracts.ADDRESS_UPDATER,
      Contracts.ADDRESS_BINDER,
      Contracts.GOVERNANCE_VOTE_POWER,
      Contracts.CLEANUP_BLOCK_NUMBER_MANAGER,
      Contracts.P_CHAIN_STAKE_MIRROR_VERIFIER,
    ]),
    [
      ADDRESS_UPDATER_ADDR,
      addressBinder.address,
      governanceVotePower.address,
      CLEANUP_BLOCK_NUMBER_MANAGER_ADDR,
      verifierMock.address,
    ],
    { from: ADDRESS_UPDATER_ADDR }
  );

  await cChainStake.updateContractAddresses(
    encodeContractNames(hre.web3, [
      Contracts.ADDRESS_UPDATER,
      Contracts.GOVERNANCE_VOTE_POWER,
      Contracts.CLEANUP_BLOCK_NUMBER_MANAGER,
    ]),
    [ADDRESS_UPDATER_ADDR, governanceVotePower.address, CLEANUP_BLOCK_NUMBER_MANAGER_ADDR],
    { from: ADDRESS_UPDATER_ADDR }
  );

  await voterRegistry.updateContractAddresses(
    encodeContractNames(hre.web3, [
      Contracts.ADDRESS_UPDATER,
      Contracts.FLARE_SYSTEMS_MANAGER,
      Contracts.ENTITY_MANAGER,
      Contracts.FLARE_SYSTEMS_CALCULATOR,
    ]),
    [ADDRESS_UPDATER_ADDR, flareSystemsManager.address, entityManager.address, flareSystemsCalculator.address],
    { from: ADDRESS_UPDATER_ADDR }
  );

  await flareSystemsCalculator.updateContractAddresses(
    encodeContractNames(hre.web3, [
      Contracts.ADDRESS_UPDATER,
      Contracts.FLARE_SYSTEMS_MANAGER,
      Contracts.ENTITY_MANAGER,
      Contracts.WNAT_DELEGATION_FEE,
      Contracts.VOTER_REGISTRY,
      Contracts.P_CHAIN_STAKE_MIRROR,
      Contracts.WNAT]),
    [ADDRESS_UPDATER_ADDR, flareSystemsManager.address, entityManager.address, wNatDelegationFee.address, voterRegistry.address, pChainStakeMirror.address, wNat.address],
    { from: ADDRESS_UPDATER_ADDR }
  );

  await flareSystemsManager.updateContractAddresses(
    encodeContractNames(hre.web3, [
      Contracts.ADDRESS_UPDATER,
      Contracts.VOTER_REGISTRY,
      Contracts.SUBMISSION,
      Contracts.RELAY,
      Contracts.REWARD_MANAGER,
      Contracts.CLEANUP_BLOCK_NUMBER_MANAGER,
    ]),
    [ADDRESS_UPDATER_ADDR, voterRegistry.address, submission.address, relay.address, rewardManager.address, cleanupBlockNumberManager.address],
    { from: ADDRESS_UPDATER_ADDR }
  );

  await rewardManager.updateContractAddresses(
    encodeContractNames(hre.web3, [
      Contracts.ADDRESS_UPDATER,
      Contracts.VOTER_REGISTRY,
      Contracts.CLAIM_SETUP_MANAGER,
      Contracts.FLARE_SYSTEMS_MANAGER,
      Contracts.FLARE_SYSTEMS_CALCULATOR,
      Contracts.P_CHAIN_STAKE_MIRROR,
      Contracts.WNAT]),
    [ADDRESS_UPDATER_ADDR, voterRegistry.address, CLAIM_SETUP_MANAGER_ADDR, flareSystemsManager.address, flareSystemsCalculator.address, pChainStakeMirror.address, wNat.address],
    { from: ADDRESS_UPDATER_ADDR }
  );

  await submission.updateContractAddresses(
    encodeContractNames(hre.web3, [
      Contracts.ADDRESS_UPDATER,
      Contracts.FLARE_SYSTEMS_MANAGER,
      Contracts.RELAY]),
    [ADDRESS_UPDATER_ADDR, flareSystemsManager.address, relay.address],
    { from: ADDRESS_UPDATER_ADDR }
  );

  await wNatDelegationFee.updateContractAddresses(
    encodeContractNames(hre.web3, [
      Contracts.ADDRESS_UPDATER,
      Contracts.FLARE_SYSTEMS_MANAGER]),
    [ADDRESS_UPDATER_ADDR, flareSystemsManager.address], { from: ADDRESS_UPDATER_ADDR });

  await ftsoRewardOffersManager.updateContractAddresses(
    encodeContractNames(hre.web3, [
      Contracts.ADDRESS_UPDATER,
      Contracts.FLARE_SYSTEMS_MANAGER,
      Contracts.REWARD_MANAGER,
      Contracts.FTSO_INFLATION_CONFIGURATIONS,
      Contracts.FTSO_FEED_DECIMALS,
      Contracts.INFLATION]),
    [ADDRESS_UPDATER_ADDR, flareSystemsManager.address, rewardManager.address, ftsoInflationConfigurations.address, ftsoFeedDecimals.address, INFLATION_ADDR], { from: ADDRESS_UPDATER_ADDR });

  await ftsoFeedDecimals.updateContractAddresses(
    encodeContractNames(hre.web3, [
      Contracts.ADDRESS_UPDATER,
      Contracts.FLARE_SYSTEMS_MANAGER]),
    [ADDRESS_UPDATER_ADDR, flareSystemsManager.address], { from: ADDRESS_UPDATER_ADDR });

  await ftsoFeedPublisher.updateContractAddresses(
    encodeContractNames(hre.web3, [
      Contracts.ADDRESS_UPDATER,
      Contracts.RELAY]),
    [ADDRESS_UPDATER_ADDR, relay.address], { from: ADDRESS_UPDATER_ADDR });

  await cleanupBlockNumberManager.updateContractAddresses(
    encodeContractNames(hre.web3, [
      Contracts.ADDRESS_UPDATER,
      Contracts.FLARE_SYSTEMS_MANAGER]),
    [ADDRESS_UPDATER_ADDR, flareSystemsManager.address], { from: ADDRESS_UPDATER_ADDR });

  // set reward offers manager list
  await rewardManager.setRewardOffersManagerList([ftsoRewardOffersManager.address]);

  // set initial reward data
  await rewardManager.setInitialRewardData();

  // send some inflation funds
  const inflationFunds = hre.web3.utils.toWei("200000");
  await ftsoRewardOffersManager.setDailyAuthorizedInflation(inflationFunds, { from: INFLATION_ADDR });
  await ftsoRewardOffersManager.receiveInflation({ value: inflationFunds, from: INFLATION_ADDR });

  // set rewards offer switchover trigger contracts
  await flareSystemsManager.setRewardEpochSwitchoverTriggerContracts([ftsoRewardOffersManager.address], { from: governanceAccount.address });

  // set ftso configurations
  await ftsoInflationConfigurations.addFtsoConfiguration(
    {
        feedIds: FtsoConfigurations.encodeFeedIds([{category: 1, name: "BTC/USD"}, {category: 1, name: "XRP/USD"}, {category: 1, name: "FLR/USD"}, {category: 1, name: "ETH/USD"}]),
        inflationShare: 200,
        minRewardedTurnoutBIPS: 5000,
        mode: 0,
        primaryBandRewardSharePPM: 700000,
        secondaryBandWidthPPMs: FtsoConfigurations.encodeSecondaryBandWidthPPMs([400, 800, 100, 250])
    },
    { from: governanceAccount.address }
  );
  await ftsoInflationConfigurations.addFtsoConfiguration(
    {
        feedIds: FtsoConfigurations.encodeFeedIds([{category: 1, name: "BTC/USD"}, {category: 1, name: "LTC/USD"}]),
        inflationShare: 100,
        minRewardedTurnoutBIPS: 5000,
        mode: 0,
        primaryBandRewardSharePPM: 600000,
        secondaryBandWidthPPMs: FtsoConfigurations.encodeSecondaryBandWidthPPMs([200, 1000])
    },
    { from: governanceAccount.address }
  );

  await entityManager.setNodePossessionVerifier(verifierMock.address); // mock verifier

  await pChainStakeMirror.setCleanerContract(CLEANER_CONTRACT_ADDR, { from: governanceAccount.address });
  await pChainStakeMirror.activate({ from: governanceAccount.address });
  await cChainStake.activate({ from: governanceAccount.address });

  logger.info(
    `Finished deploying contracts:\n  FlareSystemsManager: ${flareSystemsManager.address},\n  Submission: ${submission.address},\n  Relay: ${relay.address}`
  );

  logger.info(`Current network time: ${new Date((await time.latest()) * 1000).toISOString()}`);

  const contracts: DeployedContracts = {
    pChainStakeMirror,
    cChainStake,
    vp: vpContract,
    wNat,
    governanceVotePower,
    addressBinder,
    pChainVerifier,
    verifierMock,
    entityManager,
    voterRegistry,
    flareSystemsCalculator,
    flareSystemsManager,
    rewardManager,
    submission,
    relay,
    wNatDelegationFee,
    ftsoInflationConfigurations,
    ftsoRewardOffersManager,
    ftsoFeedDecimals,
    ftsoFeedPublisher,
    cleanupBlockNumberManager
  };

  return [contracts, rewardEpochStart, initialSigningPolicy];
}

export function serializeDeployedContractsAddresses(contracts: DeployedContracts, fname: string) {
  const result: any = {};
  Object.entries(contracts).forEach(([name, contract]) => {
    result[contract.constructor.contractName] = (contract as any).address;
  });
  fs.writeFileSync(fname, JSON.stringify(result, null, 2));
}

