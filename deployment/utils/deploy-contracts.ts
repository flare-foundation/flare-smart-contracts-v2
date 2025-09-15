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
  FastUpdateIncentiveManagerContract,
  FastUpdateIncentiveManagerInstance,
  FastUpdaterContract,
  FastUpdaterInstance,
  FastUpdatesConfigurationContract,
  FastUpdatesConfigurationInstance,
  FdcHubContract,
  FdcHubInstance,
  FdcInflationConfigurationsContract,
  FdcRequestFeeConfigurationsContract,
  FeeCalculatorContract,
  FeeCalculatorInstance,
  FlareSystemsCalculatorContract,
  FlareSystemsCalculatorInstance,
  FlareSystemsManagerContract,
  FlareSystemsManagerInstance,
  FtsoFeedDecimalsContract,
  FtsoFeedDecimalsInstance,
  FtsoFeedIdConverterContract,
  FtsoFeedIdConverterInstance,
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
  NodePossessionVerifierContract,
  NodePossessionVerifierInstance,
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
  TeePaymentsProxyContract,
  TeeVersionManagerProxyContract,
  TeeWalletBackupManagerProxyContract,
  TeeWalletKeyManagerProxyContract,
  TeeWalletManagerProxyContract,
  TeeWalletProjectManagerProxyContract,
  TestableFlareDaemonContract,
  TestableFlareDaemonInstance,
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
  systemSettings,
  getSigningPolicyHash,
  FTSO_PROTOCOL_ID,
  TEE_PAYMENT_CONFIGURATIONS,
  TEE_OPERATION_FEES,
  rewardEpochDurationSeconds,
  FTDC_FEE_CONFIGURATIONS,
} from "../tasks/run-simulation";
import { getLogger } from "./logger";
import { testDeployGovernanceSettings } from "./contract-helpers";
import { FtsoConfigurations } from "../../scripts/libs/protocol/FtsoConfigurations";
import { RelayInitialConfig } from "./RelayInitialConfig";
import { TeeMachineRegistryContract, TeeMachineRegistryInstance } from "../../typechain-truffle/contracts/tee/implementation/TeeMachineRegistry";
import { TeeWalletManagerContract, TeeWalletManagerInstance } from "../../typechain-truffle/contracts/tee/implementation/TeeWalletManager";
import { TeeFeeCalculatorContract, TeeFeeCalculatorInstance } from "../../typechain-truffle/contracts/tee/implementation/TeeFeeCalculator";
import { TeeRewardOffersManagerContract, TeeRewardOffersManagerInstance } from "../../typechain-truffle/contracts/tee/implementation/TeeRewardOffersManager";
import { TeePaymentsContract, TeePaymentsInstance } from "../../typechain-truffle/contracts/tee/implementation/TeePayments";
import { TeeWalletBackupManagerContract, TeeWalletBackupManagerInstance } from "../../typechain-truffle/contracts/tee/implementation/TeeWalletBackupManager";
import { TeeWalletProjectManagerContract, TeeWalletProjectManagerInstance } from "../../typechain-truffle/contracts/tee/implementation/TeeWalletProjectManager";
import { TeeVersionManagerContract, TeeVersionManagerInstance } from "../../typechain-truffle/contracts/tee/implementation/TeeVersionManager";
import { TeeGovernanceContract, TeeGovernanceInstance } from "../../typechain-truffle/contracts/tee/implementation/TeeGovernance";
import { TeeWalletKeyManagerContract, TeeWalletKeyManagerInstance } from "../../typechain-truffle/contracts/tee/implementation/TeeWalletKeyManager";
import { FtdcHubContract, FtdcHubInstance } from "../../typechain-truffle/contracts/ftdc/implementation/FtdcHub";
import { FtdcRequestFeeConfigurationsInstance } from "../../typechain-truffle/contracts/ftdc/implementation/FtdcRequestFeeConfigurations";
import { TeeGovernanceProxyContract } from "../../typechain-truffle/contracts/tee/proxy/TeeGovernanceProxy";
import { TeeMachineRegistryProxyContract } from "../../typechain-truffle/contracts/tee/proxy/TeeMachineRegistryProxy";
import { FtdcVerificationContract, FtdcVerificationInstance } from "../../typechain-truffle/contracts/ftdc/implementation/FtdcVerification";
import { TeeVerificationContract, TeeVerificationInstance } from "../../typechain-truffle/contracts/tee/implementation/TeeVerification";
import { TeeVerificationProxyContract } from "../../typechain-truffle/contracts/tee/proxy/TeeVerificationProxy";
import { TeeOwnerAllowlistContract, TeeOwnerAllowlistInstance } from "../../typechain-truffle/contracts/tee/implementation/TeeOwnerAllowlist";
import { TeeSystemStateVerifierProxyContract } from "../../typechain-truffle/contracts/tee/proxy/TeeSystemStateVerifierProxy";
import { TeeSystemStateVerifierContract, TeeSystemStateVerifierInstance } from "../../typechain-truffle/contracts/tee/implementation/TeeSystemStateVerifier";
import { AddressUpdaterContract, AddressUpdaterInstance } from "../../typechain-truffle/flattened/FlareSmartContracts.sol/AddressUpdater";
import { TeeOwnerAllowlistProxyContract } from "../../typechain-truffle/contracts/tee/proxy/TeeOwnerAllowlistProxy";
import { TeeExtensionRegistryContract, TeeExtensionRegistryInstance } from "../../typechain-truffle/contracts/tee/implementation/TeeExtensionRegistry";
import { TeeExtensionRegistryProxyContract } from "../../typechain-truffle/contracts/tee/proxy/TeeExtensionRegistryProxy";
import { TeeReplicationContract, TeeReplicationInstance } from "../../typechain-truffle/contracts/tee/implementation/TeeReplication";
import { TeeReplicationProxyContract } from "../../typechain-truffle/contracts/tee/proxy/TeeReplicationProxy";

export interface DeployedContracts {
  readonly addressUpdater: AddressUpdaterInstance;
  readonly flareDaemon: TestableFlareDaemonInstance;
  readonly pChainStakeMirror: PChainStakeMirrorInstance;
  readonly cChainStake: CChainStakeInstance;
  readonly vp: VPContractInstance;
  readonly wNat: WNatInstance;
  readonly governanceVotePower: GovernanceVotePowerInstance;
  readonly addressBinder: AddressBinderInstance;
  readonly pChainStakeMirrorVerifier: PChainStakeMirrorVerifierInstance;
  readonly mockContract: MockContractInstance;
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
  readonly ftsoFeedIdConverter: FtsoFeedIdConverterInstance;
  readonly cleanupBlockNumberManager: CleanupBlockNumberManagerInstance;
  readonly fastUpdateIncentiveManager: FastUpdateIncentiveManagerInstance;
  readonly fastUpdater: FastUpdaterInstance;
  readonly fastUpdatesConfiguration: FastUpdatesConfigurationInstance;
  readonly nodePossessionVerifier: NodePossessionVerifierInstance;
  readonly feeCalculator: FeeCalculatorInstance;
  readonly fdcHub: FdcHubInstance;
  readonly teeOwnerAllowlist: TeeOwnerAllowlistInstance;
  readonly teeGovernance: TeeGovernanceInstance;
  readonly teeVersionManager: TeeVersionManagerInstance;
  readonly teeReplication: TeeReplicationInstance;
  readonly teeExtensionRegistry: TeeExtensionRegistryInstance;
  readonly teeVerification: TeeVerificationInstance;
  readonly teeSystemStateVerifier: TeeSystemStateVerifierInstance;
  readonly teeMachineRegistry: TeeMachineRegistryInstance;
  readonly teeWalletProjectManager: TeeWalletProjectManagerInstance;
  readonly teeWalletManager: TeeWalletManagerInstance;
  readonly teeWalletKeyManager: TeeWalletKeyManagerInstance;
  readonly teeWalletBackupManager: TeeWalletBackupManagerInstance;
  readonly teeFeeCalculator: TeeFeeCalculatorInstance;
  readonly teeRewardOffersManager: TeeRewardOffersManagerInstance;
  readonly teePayments: TeePaymentsInstance[];
  readonly ftdcHub: FtdcHubInstance;
  readonly ftdcRequestFeeConfigurations: FtdcRequestFeeConfigurationsInstance;
  readonly ftdcVerification: FtdcVerificationInstance;
}

const logger = getLogger("contracts");

export async function deployContracts(
  accounts: Account[],
  hre: HardhatRuntimeEnvironment,
  governanceAccount: Account
): Promise<[DeployedContracts, number, ISigningPolicy]> {
  const CLEANER_CONTRACT_ADDR = accounts[1].address;
  const MULTI_SIG_VOTING_ADDR = accounts[2].address;
  const RELAY_ADDR = accounts[3].address;
  const CLAIM_SETUP_MANAGER_ADDR = accounts[4].address;
  const FTSO_REWARD_MANAGER_ADDR = accounts[5].address;
  const INFLATION_ADDR = accounts[5].address;

  const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
  const _ZERO_BYTES32 = "0x0000000000000000000000000000000000000000000000000000000000000000";

  const MockContract = hre.artifacts.require("MockContract") as MockContractContract;
  const WNat = hre.artifacts.require("WNat") as WNatContract;
  const VPContract = hre.artifacts.require("VPContract") as VPContractContract;
  const PChainStakeMirror = hre.artifacts.require("PChainStakeMirror") as PChainStakeMirrorContract;
  const GovernanceVotePower = hre.artifacts.require("GovernanceVotePower") as GovernanceVotePowerContract;
  const AddressBinder = hre.artifacts.require("AddressBinder") as AddressBinderContract;
  const PChainStakeMirrorVerifier = hre.artifacts.require("PChainStakeMirrorVerifier") as PChainStakeMirrorVerifierContract;
  const EntityManager = hre.artifacts.require("EntityManager") as EntityManagerContract;
  const VoterRegistry = hre.artifacts.require("VoterRegistry") as VoterRegistryContract;
  const FlareSystemsCalculator = hre.artifacts.require("FlareSystemsCalculator") as FlareSystemsCalculatorContract;
  const FlareSystemsManager = hre.artifacts.require("FlareSystemsManager") as FlareSystemsManagerContract;
  const RewardManager = hre.artifacts.require("RewardManager") as RewardManagerContract;
  const Submission = hre.artifacts.require("Submission") as SubmissionContract;
  const CChainStake = hre.artifacts.require("CChainStake") as CChainStakeContract;
  const WNatDelegationFee = hre.artifacts.require("WNatDelegationFee") as WNatDelegationFeeContract;
  const FtsoInflationConfigurations = hre.artifacts.require("FtsoInflationConfigurations") as FtsoInflationConfigurationsContract;
  hre.artifacts.require("FtsoInflationConfigurations");
  const FtsoRewardOffersManager: FtsoRewardOffersManagerContract = hre.artifacts.require("FtsoRewardOffersManager") as FtsoRewardOffersManagerContract;
  const FtsoFeedDecimals = hre.artifacts.require("FtsoFeedDecimals") as FtsoFeedDecimalsContract;
  const FtsoFeedPublisher = hre.artifacts.require("FtsoFeedPublisher") as FtsoFeedPublisherContract;
  const FtsoFeedIdConverter = hre.artifacts.require("FtsoFeedIdConverter") as FtsoFeedIdConverterContract;
  const CleanupBlockNumberManager = hre.artifacts.require("CleanupBlockNumberManager") as CleanupBlockNumberManagerContract;
  const Relay = hre.artifacts.require("Relay") as RelayContract;
  const TestableFlareDaemon = hre.artifacts.require("TestableFlareDaemon") as TestableFlareDaemonContract;
  const NodePossessionVerifier = hre.artifacts.require("NodePossessionVerifier") as NodePossessionVerifierContract;
  const FdcHub = hre.artifacts.require("FdcHub") as FdcHubContract;
  const FdcInflationConfigurations = hre.artifacts.require("FdcInflationConfigurations") as FdcInflationConfigurationsContract;
  const FdcRequestFeeConfigurations = hre.artifacts.require("FdcRequestFeeConfigurations") as FdcRequestFeeConfigurationsContract;
  const FastUpdateIncentiveManager = hre.artifacts.require("FastUpdateIncentiveManager") as FastUpdateIncentiveManagerContract;
  const FastUpdater = hre.artifacts.require("FastUpdater") as FastUpdaterContract;
  const FastUpdatesConfiguration = hre.artifacts.require("FastUpdatesConfiguration") as FastUpdatesConfigurationContract;
  const FeeCalculator = hre.artifacts.require("FeeCalculator") as FeeCalculatorContract;


  const TeeOwnerAllowlist: TeeOwnerAllowlistContract = artifacts.require("TeeOwnerAllowlist");
  const TeeOwnerAllowlistProxy: TeeOwnerAllowlistProxyContract = artifacts.require("TeeOwnerAllowlistProxy");
  const TeeGovernance: TeeGovernanceContract = artifacts.require("TeeGovernance");
  const TeeGovernanceProxy: TeeGovernanceProxyContract = artifacts.require("TeeGovernanceProxy");
  const TeeVersionManager: TeeVersionManagerContract = artifacts.require("TeeVersionManager");
  const TeeVersionManagerProxy: TeeVersionManagerProxyContract = artifacts.require("TeeVersionManagerProxy");
  const TeeReplication: TeeReplicationContract = artifacts.require("TeeReplication");
  const TeeReplicationProxy: TeeReplicationProxyContract = artifacts.require("TeeReplicationProxy");
  const TeeExtensionRegistry: TeeExtensionRegistryContract = artifacts.require("TeeExtensionRegistry");
  const TeeExtensionRegistryProxy: TeeExtensionRegistryProxyContract = artifacts.require("TeeExtensionRegistryProxy");
  const TeeVerification: TeeVerificationContract = artifacts.require("TeeVerification");
  const TeeVerificationProxy: TeeVerificationProxyContract = artifacts.require("TeeVerificationProxy");
  const TeeSystemStateVerifier: TeeSystemStateVerifierContract = artifacts.require("TeeSystemStateVerifier");
  const TeeSystemStateVerifierProxy: TeeSystemStateVerifierProxyContract = artifacts.require("TeeSystemStateVerifierProxy");
  const TeeMachineRegistry: TeeMachineRegistryContract = artifacts.require("TeeMachineRegistry");
  const TeeMachineRegistryProxy: TeeMachineRegistryProxyContract = artifacts.require("TeeMachineRegistryProxy");
  const TeeWalletProjectManager: TeeWalletProjectManagerContract = artifacts.require("TeeWalletProjectManager");
  const TeeWalletProjectManagerProxy: TeeWalletProjectManagerProxyContract = artifacts.require("TeeWalletProjectManagerProxy");
  const TeeWalletManager: TeeWalletManagerContract = artifacts.require("TeeWalletManager");
  const TeeWalletManagerProxy: TeeWalletManagerProxyContract = artifacts.require("TeeWalletManagerProxy");
  const TeeWalletKeyManager: TeeWalletKeyManagerContract = artifacts.require("TeeWalletKeyManager");
  const TeeWalletKeyManagerProxy: TeeWalletKeyManagerProxyContract = artifacts.require("TeeWalletKeyManagerProxy");
  const TeeWalletBackupManager: TeeWalletBackupManagerContract = artifacts.require("TeeWalletBackupManager");
  const TeeWalletBackupManagerProxy: TeeWalletBackupManagerProxyContract = artifacts.require("TeeWalletBackupManagerProxy");
  const TeeFeeCalculator: TeeFeeCalculatorContract = artifacts.require("TeeFeeCalculator");
  const TeeRewardOffersManager: TeeRewardOffersManagerContract = artifacts.require("TeeRewardOffersManager");
  const TeePayments: TeePaymentsContract = artifacts.require("TeePayments");
  const TeePaymentsProxy: TeePaymentsProxyContract = artifacts.require("TeePaymentsProxy");
  const FtdcHub: FtdcHubContract = artifacts.require("FtdcHub");
  const FtdcRequestFeeConfigurations: FdcRequestFeeConfigurationsContract = artifacts.require("FtdcRequestFeeConfigurations");
  const FtdcVerification: FtdcVerificationContract = artifacts.require("FtdcVerification");

  logger.info(`Deploying contracts, initial network time: ${new Date((await time.latest()) * 1000).toISOString()}`);

  const governanceSettings = await testDeployGovernanceSettings(
    hre.artifacts,
    governanceAccount.address,
    TIMELOCK_SEC,
    [governanceAccount.address],
    hre.network
  );

  const addressUpdatableContracts = [];
  const addressUpdater: AddressUpdaterInstance = await AddressUpdater.new(governanceAccount.address);

  const pChainStakeMirror: PChainStakeMirrorInstance = await PChainStakeMirror.new(
    governanceAccount.address,
    governanceAccount.address,
    addressUpdater.address,
    2
  );
  addressUpdatableContracts.push(pChainStakeMirror.address);

  const cChainStake = await CChainStake.new(
    governanceAccount.address,
    governanceAccount.address,
    addressUpdater.address,
    0,
    100,
    10000000000,
    50
  );
  addressUpdatableContracts.push(cChainStake.address);

  const wNat = await WNat.new(governanceAccount.address, "Wrapped NAT", "WNAT");
  const ftsoFeedIdConverter = await FtsoFeedIdConverter.new();

  const vpContract = await VPContract.new(wNat.address, false);
  await wNat.setWriteVpContract(vpContract.address);
  await wNat.setReadVpContract(vpContract.address);
  const governanceVotePower = await GovernanceVotePower.new(
    wNat.address,
    pChainStakeMirror.address,
    cChainStake.address
  );
  await wNat.setGovernanceVotePower(governanceVotePower.address);

  const flareDaemon = await TestableFlareDaemon.new();
  await flareDaemon.initialiseFixedAddress();
  const genesisGovernance = await flareDaemon.governance();
  await flareDaemon.setAddressUpdater(addressUpdater.address, { from: genesisGovernance });
  const nodePossessionVerifier = await NodePossessionVerifier.new();
  await cChainStake.setCleanerContract(CLEANER_CONTRACT_ADDR, { from: governanceAccount.address });
  await cChainStake.activate();
  addressUpdatableContracts.push(flareDaemon.address);

  const addressBinder: AddressBinderInstance = await AddressBinder.new();
  const pChainStakeMirrorVerifier = await PChainStakeMirrorVerifier.new(
    MULTI_SIG_VOTING_ADDR,
    RELAY_ADDR,
    10,
    1000,
    5,
    5000
  );

  const mockContract = await MockContract.new();

  await pChainStakeMirror.setCleanerContract(CLEANER_CONTRACT_ADDR);
  await pChainStakeMirror.activate();

  // Set time to previous reward epoch start.
  await time.increaseTo(Math.floor(Date.now() / 1000) - rewardEpochDurationSeconds() + 1);

  const rewardEpochStart = await time.latest();

  const entityManager = await EntityManager.new(governanceSettings.address, governanceAccount.address, 4);

  const initialVoters = [governanceAccount.address];
  const initialWeights = [1000];
  const initialThreshold = 500;

  const voterRegistry = await VoterRegistry.new(
    governanceSettings.address,
    governanceAccount.address,
    addressUpdater.address,
    100,
    0,
    0,
    0,
    initialVoters,
    initialWeights
  );
  addressUpdatableContracts.push(voterRegistry.address);

  const flareSystemsCalculator = await FlareSystemsCalculator.new(
    governanceSettings.address,
    governanceAccount.address,
    addressUpdater.address,
    2500,
    200,
    100,
    100
  );
  addressUpdatableContracts.push(flareSystemsCalculator.address);

  const settings = systemSettings(rewardEpochStart);
  const initialSigningPolicy: ISigningPolicy = {
    rewardEpochId: 0,
    startVotingRoundId: settings.firstRewardEpochStartVotingRoundId,
    threshold: initialThreshold,
    seed: web3.utils.keccak256("123"),
    voters: initialVoters,
    weights: initialWeights,
  };

  const initialSettings = {
    initialRandomVotePowerBlockSelectionSize: 1,
    initialRewardEpochId: 0,
    initialRewardEpochThreshold: initialThreshold,
  };

  const flareSystemsManager: FlareSystemsManagerInstance = await FlareSystemsManager.new(
    governanceSettings.address,
    governanceAccount.address,
    addressUpdater.address,
    flareDaemon.address,
    settings.updatableSettings,
    settings.firstVotingRoundStartTs,
    settings.votingEpochDurationSeconds,
    settings.firstRewardEpochStartVotingRoundId,
    settings.rewardEpochDurationInVotingEpochs,
    initialSettings
  );
  addressUpdatableContracts.push(flareSystemsManager.address);

  const rewardManager = await RewardManager.new(
    governanceSettings.address,
    governanceAccount.address,
    addressUpdater.address,
    ZERO_ADDRESS,
    0
  );
  addressUpdatableContracts.push(rewardManager.address);

  const relayInitialConfig: RelayInitialConfig = {
    initialRewardEpochId: initialSigningPolicy.rewardEpochId,
    startingVotingRoundIdForInitialRewardEpochId: initialSigningPolicy.startVotingRoundId,
    initialSigningPolicyHash: getSigningPolicyHash(initialSigningPolicy),
    randomNumberProtocolId: FTSO_PROTOCOL_ID,
    firstVotingRoundStartTs: settings.firstVotingRoundStartTs,
    votingEpochDurationSeconds: settings.votingEpochDurationSeconds,
    firstRewardEpochStartVotingRoundId: settings.firstRewardEpochStartVotingRoundId,
    rewardEpochDurationInVotingEpochs: settings.rewardEpochDurationInVotingEpochs,
    thresholdIncreaseBIPS: 12000,
    messageFinalizationWindowInRewardEpochs: 100,
    feeCollectionAddress: ZERO_ADDRESS,
    feeConfigs: []
  }

  const relay = await Relay.new(
    relayInitialConfig,
    flareSystemsManager.address,
    ZERO_ADDRESS
  );

  const submission = await Submission.new(
    governanceSettings.address,
    governanceAccount.address,
    addressUpdater.address,
    false
  );
  addressUpdatableContracts.push(submission.address);

  const wNatDelegationFee = await WNatDelegationFee.new(addressUpdater.address, 2, 2000);
  addressUpdatableContracts.push(wNatDelegationFee.address);

  const ftsoInflationConfigurations = await FtsoInflationConfigurations.new(
    governanceSettings.address,
    governanceAccount.address
  );

  const ftsoRewardOffersManager = await FtsoRewardOffersManager.new(
    governanceSettings.address,
    governanceAccount.address,
    addressUpdater.address,
    100
  );
  addressUpdatableContracts.push(ftsoRewardOffersManager.address);

  const ftsoFeedDecimals = await FtsoFeedDecimals.new(
    governanceSettings.address,
    governanceAccount.address,
    addressUpdater.address,
    2,
    5,
    0,
    [
      { feedId: FtsoConfigurations.encodeFeedId({ category: 1, name: "BTC/USD" }), decimals: 2 },
      { feedId: FtsoConfigurations.encodeFeedId({ category: 1, name: "ETH/USD" }), decimals: 3 },
    ]
  );
  addressUpdatableContracts.push(ftsoFeedDecimals.address);

  const ftsoFeedPublisher = await FtsoFeedPublisher.new(
    governanceSettings.address,
    governanceAccount.address,
    addressUpdater.address,
    FTSO_PROTOCOL_ID,
    200
  );
  addressUpdatableContracts.push(ftsoFeedPublisher.address);

  const cleanupBlockNumberManager = await CleanupBlockNumberManager.new(
    governanceAccount.address,
    addressUpdater.address,
    "FlareSystemsManager"
  );
  addressUpdatableContracts.push(cleanupBlockNumberManager.address);

  // FAST UPDATES
  const fastUpdateIncentiveManager = await FastUpdateIncentiveManager.new(
    governanceSettings.address,
    governanceAccount.address,
    addressUpdater.address,
    "0x01000000000000000000000000000000",
    "0x00000800000000000000000000000000",
    "0x00100000000000000000000000000000",
    "0x00008000000000000000000000000000",
    1425,
    (10n ** 24n).toString(),
    8
  );
  addressUpdatableContracts.push(fastUpdateIncentiveManager.address);

  const fastUpdater = await FastUpdater.new(
    governanceSettings.address,
    governanceAccount.address,
    addressUpdater.address,
    flareDaemon.address,
    settings.firstVotingRoundStartTs,
    settings.votingEpochDurationSeconds,
    10
  );
  addressUpdatableContracts.push(fastUpdater.address);

  const fastUpdatesConfiguration = await FastUpdatesConfiguration.new(
    governanceSettings.address,
    governanceAccount.address,
    addressUpdater.address
  );
  addressUpdatableContracts.push(fastUpdatesConfiguration.address);

  const feeCalculator = await FeeCalculator.new(
    governanceSettings.address,
    governanceAccount.address,
    addressUpdater.address,
    "1"
  );
  addressUpdatableContracts.push(feeCalculator.address);

  // FDC
  const fdcHub = await FdcHub.new(governanceSettings.address, governanceAccount.address, addressUpdater.address, 30);
  addressUpdatableContracts.push(fdcHub.address);
  const fdcInflationConfigurations = await FdcInflationConfigurations.new(governanceSettings.address, governanceAccount.address, addressUpdater.address);
  addressUpdatableContracts.push(fdcInflationConfigurations.address);
  const fdcRequestFeeConfigurations = await FdcRequestFeeConfigurations.new(governanceSettings.address, governanceAccount.address);

  const teeOwnerAllowlistImpl = await TeeOwnerAllowlist.new();
  const teeOwnerAllowlistProxy = await TeeOwnerAllowlistProxy.new(
    governanceSettings.address,
    governanceAccount.address,
    addressUpdater.address,
    teeOwnerAllowlistImpl.address
  );
  const teeOwnerAllowlist = await TeeOwnerAllowlist.at(teeOwnerAllowlistProxy.address);
  addressUpdatableContracts.push(teeOwnerAllowlist.address);

  const teeGovernanceImpl = await TeeGovernance.new();
  const teeGovernanceProxy = await TeeGovernanceProxy.new(
    governanceSettings.address,
    governanceAccount.address,
    addressUpdater.address,
    teeGovernanceImpl.address
  )
  const teeGovernance = await TeeGovernance.at(teeGovernanceProxy.address);
  addressUpdatableContracts.push(teeGovernance.address);

  const teeVersionManagerImpl = await TeeVersionManager.new();
  const teeVersionManagerProxy = await TeeVersionManagerProxy.new(
    governanceSettings.address,
    governanceAccount.address,
    addressUpdater.address,
    teeVersionManagerImpl.address
  );
  const teeVersionManager = await TeeVersionManager.at(teeVersionManagerProxy.address);
  addressUpdatableContracts.push(teeVersionManager.address);

  const teeReplicationImpl = await TeeReplication.new();
  const teeReplicationProxy = await TeeReplicationProxy.new(
    governanceSettings.address,
    governanceAccount.address,
    addressUpdater.address,
    60,
    teeReplicationImpl.address
  );
  const teeReplication = await TeeReplication.at(teeReplicationProxy.address);
  addressUpdatableContracts.push(teeReplication.address);

  const teeExtensionRegistryImpl = await TeeExtensionRegistry.new();
  const teeExtensionRegistryProxy = await TeeExtensionRegistryProxy.new(
    governanceSettings.address,
    governanceAccount.address,
    addressUpdater.address,
    teeExtensionRegistryImpl.address
  );
  const teeExtensionRegistry = await TeeExtensionRegistry.at(teeExtensionRegistryProxy.address);
  addressUpdatableContracts.push(teeExtensionRegistry.address);

  const teeVerificationImpl = await TeeVerification.new();
  const teeVerificationProxy = await TeeVerificationProxy.new(
    governanceSettings.address,
    governanceAccount.address,
    addressUpdater.address,
    3600,
    10,
    600,
    teeVerificationImpl.address
  );
  const teeVerification = await TeeVerification.at(teeVerificationProxy.address);
  addressUpdatableContracts.push(teeVerification.address);

  const teeSystemStateVerifierImpl = await TeeSystemStateVerifier.new();
  const teeSystemStateVerifierProxy = await TeeSystemStateVerifierProxy.new(
   governanceSettings.address,
    governanceAccount.address,
    addressUpdater.address,
    teeSystemStateVerifierImpl.address
  );
  const teeSystemStateVerifier = await TeeSystemStateVerifier.at(teeSystemStateVerifierProxy.address);
  addressUpdatableContracts.push(teeSystemStateVerifier.address);

  const teeMachineRegistryImpl = await TeeMachineRegistry.new();
  const teeMachineRegistryProxy = await TeeMachineRegistryProxy.new(
    governanceSettings.address,
    governanceAccount.address,
    addressUpdater.address,
    teeMachineRegistryImpl.address
  );
  const teeMachineRegistry = await TeeMachineRegistry.at(teeMachineRegistryProxy.address);
  addressUpdatableContracts.push(teeMachineRegistry.address);

  const teeWalletProjectManagerImpl = await TeeWalletProjectManager.new();
  const teeWalletProjectManagerProxy = await TeeWalletProjectManagerProxy.new(
    governanceSettings.address,
    governanceAccount.address,
    addressUpdater.address,
    teeWalletProjectManagerImpl.address
  );
  const teeWalletProjectManager = await TeeWalletProjectManager.at(teeWalletProjectManagerProxy.address);
  addressUpdatableContracts.push(teeWalletProjectManager.address);

  const teeWalletManagerImpl = await TeeWalletManager.new();
  const teeWalletManagerProxy = await TeeWalletManagerProxy.new(
    governanceSettings.address,
    governanceAccount.address,
    addressUpdater.address,
    teeWalletManagerImpl.address
  );
  const teeWalletManager = await TeeWalletManager.at(teeWalletManagerProxy.address);
  addressUpdatableContracts.push(teeWalletManager.address);

  const teeWalletKeyManagerImpl = await TeeWalletKeyManager.new();
  const teeWalletKeyManagerProxy = await TeeWalletKeyManagerProxy.new(
    governanceSettings.address,
    governanceAccount.address,
    addressUpdater.address,
    teeWalletKeyManagerImpl.address
  );
  const teeWalletKeyManager = await TeeWalletKeyManager.at(teeWalletKeyManagerProxy.address);
  addressUpdatableContracts.push(teeWalletKeyManager.address);

  const teeWalletBackupManagerImpl = await TeeWalletBackupManager.new();
  const teeWalletBackupManagerProxy = await TeeWalletBackupManagerProxy.new(
    governanceSettings.address,
    governanceAccount.address,
    addressUpdater.address,
    teeWalletBackupManagerImpl.address
  );
  const teeWalletBackupManager = await TeeWalletBackupManager.at(teeWalletBackupManagerProxy.address);
  addressUpdatableContracts.push(teeWalletBackupManager.address);

  const teeFeeCalculator = await TeeFeeCalculator.new(
    governanceSettings.address,
    governanceAccount.address,
    1
  );

  const teeRewardOffersManager = await TeeRewardOffersManager.new(
    governanceSettings.address,
    governanceAccount.address,
    addressUpdater.address,
    100000 // 10%
  );
  addressUpdatableContracts.push(teeRewardOffersManager.address);

  const operationTypes = [];
  const operationCommands = [];
  const operationFees = [];
  for (const teeOperationFee of TEE_OPERATION_FEES) {
    operationTypes.push(web3.utils.utf8ToHex(teeOperationFee.opType).padEnd(66, "0"));
    operationCommands.push(web3.utils.utf8ToHex(teeOperationFee.opCommand).padEnd(66, "0"));
    operationFees.push(teeOperationFee.feeWei);
  }
  await teeFeeCalculator.setOperationFees(operationTypes, operationCommands, operationFees, { from: governanceAccount.address });

  const teePaymentsList = [];
  const teePaymentsImpl = await TeePayments.new();
  for (const teePaymentConfig of TEE_PAYMENT_CONFIGURATIONS) {
    const teePaymentsProxy = await TeePaymentsProxy.new(
      governanceSettings.address,
      governanceAccount.address,
      addressUpdater.address,
      teePaymentConfig.maxBatchSize,
      teePaymentConfig.maxBatchDurationSeconds,
      web3.utils.utf8ToHex(teePaymentConfig.opType).padEnd(66, "0"),
      teePaymentConfig.sourceIds.map(sourceId => web3.utils.utf8ToHex(sourceId).padEnd(66, "0")),
      teePaymentsImpl.address
    );
    const teePayments = await TeePayments.at(teePaymentsProxy.address);
    teePaymentsList.push(teePayments);
    addressUpdatableContracts.push(teePayments.address);
  }

  // FTDC
  const ftdcHub = await FtdcHub.new(
    governanceSettings.address,
    governanceAccount.address,
    addressUpdater.address,
    3000,
    1
  );
  addressUpdatableContracts.push(ftdcHub.address);
  const ftdcRequestFeeConfigurations = await FtdcRequestFeeConfigurations.new(
    governanceSettings.address,
    governanceAccount.address
  );

  const ftdcVerification = await FtdcVerification.new(addressUpdater.address);
  addressUpdatableContracts.push(ftdcVerification.address);

  // Set the FTDC request fee configurations
  for (const ftdcRequestFee of FTDC_FEE_CONFIGURATIONS) {
    await ftdcRequestFeeConfigurations.setTypeAndSourceFee(
      web3.utils.utf8ToHex(ftdcRequestFee.attestationType).padEnd(66, "0"),
      web3.utils.utf8ToHex(ftdcRequestFee.source).padEnd(66, "0"),
      "1"
    );
  }

  // ENABLE P-CHAIN STAKE MIRROR
  await flareSystemsCalculator.enablePChainStakeMirror({ from: governanceAccount.address });
  await rewardManager.enablePChainStakeMirror({ from: governanceAccount.address });

  // SET CONTRACT ADDRESSES
  await addressUpdater.update(
    [
      Contracts.ADDRESS_UPDATER,
      Contracts.INFLATION,
      Contracts.ADDRESS_BINDER,
      Contracts.GOVERNANCE_VOTE_POWER,
      Contracts.CLEANUP_BLOCK_NUMBER_MANAGER,
      Contracts.P_CHAIN_STAKE_MIRROR_VERIFIER,
      Contracts.FLARE_SYSTEMS_MANAGER,
      Contracts.ENTITY_MANAGER,
      Contracts.FLARE_SYSTEMS_CALCULATOR,
      Contracts.WNAT_DELEGATION_FEE,
      Contracts.VOTER_REGISTRY,
      Contracts.P_CHAIN_STAKE_MIRROR,
      Contracts.WNAT,
      Contracts.SUBMISSION,
      Contracts.RELAY,
      Contracts.REWARD_MANAGER,
      Contracts.CLAIM_SETUP_MANAGER,
      Contracts.FTSO_REWARD_MANAGER,
      Contracts.FTSO_INFLATION_CONFIGURATIONS,
      Contracts.FTSO_FEED_DECIMALS,
      Contracts.FAST_UPDATER,
      Contracts.FAST_UPDATES_CONFIGURATION,
      Contracts.FAST_UPDATE_INCENTIVE_MANAGER,
      Contracts.FTSO_FEED_PUBLISHER,
      Contracts.FEE_CALCULATOR,
      Contracts.FDC_INFLATION_CONFIGURATIONS,
      Contracts.FDC_REQUEST_FEE_CONFIGURATIONS,
      Contracts.TEE_GOVERNANCE,
      Contracts.TEE_VERSION_MANAGER,
      Contracts.TEE_EXTENSION_REGISTRY,
      Contracts.TEE_MACHINE_REGISTRY,
      Contracts.TEE_FEE_CALCULATOR,
      Contracts.TEE_SYSTEM_STATE_VERIFIER,
      Contracts.FTDC_HUB,
      Contracts.FTDC_VERIFICATION,
      Contracts.FTDC_REQUEST_FEE_CONFIGURATIONS,
      Contracts.TEE_REWARD_OFFERS_MANAGER,
      Contracts.TEE_VERIFICATION,
      Contracts.TEE_OWNER_ALLOWLIST,
      Contracts.TEE_WALLET_MANAGER,
      Contracts.TEE_WALLET_PROJECT_MANAGER,
      Contracts.TEE_WALLET_KEY_MANAGER,
      Contracts.TEE_WALLET_BACKUP_MANAGER,
      Contracts.TEE_REPLICATION
    ],
    [
      addressUpdater.address,
      INFLATION_ADDR,
      addressBinder.address,
      governanceVotePower.address,
      cleanupBlockNumberManager.address,
      mockContract.address,
      flareSystemsManager.address,
      entityManager.address,
      flareSystemsCalculator.address,
      wNatDelegationFee.address,
      voterRegistry.address,
      pChainStakeMirror.address,
      wNat.address,
      submission.address,
      relay.address,
      rewardManager.address,
      CLAIM_SETUP_MANAGER_ADDR,
      FTSO_REWARD_MANAGER_ADDR,
      ftsoInflationConfigurations.address,
      ftsoFeedDecimals.address,
      fastUpdater.address,
      fastUpdatesConfiguration.address,
      fastUpdateIncentiveManager.address,
      mockContract.address,
      feeCalculator.address,
      fdcInflationConfigurations.address,
      fdcRequestFeeConfigurations.address,
      teeGovernance.address,
      teeVersionManager.address,
      teeExtensionRegistry.address,
      teeMachineRegistry.address,
      teeFeeCalculator.address,
      teeSystemStateVerifier.address,
      ftdcHub.address,
      ftdcVerification.address,
      ftdcRequestFeeConfigurations.address,
      teeRewardOffersManager.address,
      teeVerification.address,
      teeOwnerAllowlist.address,
      teeWalletManager.address,
      teeWalletProjectManager.address,
      teeWalletKeyManager.address,
      teeWalletBackupManager.address,
      teeReplication.address
    ],
    addressUpdatableContracts,
    { from: governanceAccount.address }
  );

  await teeExtensionRegistry.addOrUpdateSupportedWalletProjectOpTypes(
    0, teePaymentsList.map(teePayments => teePayments.address),
    { from: governanceAccount.address }
  );

  await teeExtensionRegistry.registerSystemInstructionInitiators(
    [
      teeVerification.address,
      teeWalletManager.address,
      teeWalletKeyManager.address,
      teeWalletBackupManager.address,
      teeReplication.address,
      ...teePaymentsList.map(teePayments => teePayments.address),
      ftdcHub.address
    ],
    { from: governanceAccount.address }
  )

  await teeOwnerAllowlist.allowAllTeeMachineOwners(0, { from: governanceAccount.address });
  await teeOwnerAllowlist.allowAllTeeWalletProjectOwners(0, { from: governanceAccount.address });

  // set reward offers manager list
  await rewardManager.setRewardOffersManagerList([
    ftsoRewardOffersManager.address,
    fastUpdateIncentiveManager.address,
    fdcHub.address,
    teeRewardOffersManager.address,
    teeExtensionRegistry.address,
    ftdcHub.address],
    { from: governanceAccount.address }
  );

  // set initial reward data
  await rewardManager.setInitialRewardData({ from: governanceAccount.address });

  // send some inflation funds
  const inflationFunds = hre.web3.utils.toWei("200000");
  await ftsoRewardOffersManager.setDailyAuthorizedInflation(inflationFunds, { from: INFLATION_ADDR });
  await ftsoRewardOffersManager.receiveInflation({ value: inflationFunds, from: INFLATION_ADDR });
  await fastUpdateIncentiveManager.setDailyAuthorizedInflation(inflationFunds, { from: INFLATION_ADDR });
  await fastUpdateIncentiveManager.receiveInflation({ value: inflationFunds, from: INFLATION_ADDR });
  await fdcHub.setDailyAuthorizedInflation(inflationFunds, { from: INFLATION_ADDR });
  await fdcHub.receiveInflation({ value: inflationFunds, from: INFLATION_ADDR });
  await teeRewardOffersManager.setDailyAuthorizedInflation(inflationFunds, { from: INFLATION_ADDR });
  await teeRewardOffersManager.receiveInflation({ value: inflationFunds, from: INFLATION_ADDR });

  // set FDC types + sources + fees

  const EVMTransactionType = web3.utils.utf8ToHex("EVMTransaction").padEnd(66, "0");

  const testSGB = web3.utils.utf8ToHex("testSGB").padEnd(66, "0");

  await fdcRequestFeeConfigurations.setTypeAndSourceFee(EVMTransactionType, testSGB, "1", { from: governanceAccount.address });

  await fdcInflationConfigurations.addFdcConfigurations(
    [{
      attestationType: EVMTransactionType,
      source: testSGB,
      inflationShare: 100,
      minRequestsThreshold: 2,
      mode: 0
    }],
    { from: governanceAccount.address }
  );

  // set rewards offer switchover trigger contracts
  await flareSystemsManager.setRewardEpochSwitchoverTriggerContracts(
    [ftsoRewardOffersManager.address, fastUpdateIncentiveManager.address, fdcHub.address, teeRewardOffersManager.address],
    { from: governanceAccount.address }
  );

  // set ftso configurations
  await ftsoInflationConfigurations.addFtsoConfiguration(
    {
      feedIds: FtsoConfigurations.encodeFeedIds([
        { category: 1, name: "BTC/USD" },
        { category: 1, name: "XRP/USD" },
        { category: 1, name: "FLR/USD" },
        { category: 1, name: "ETH/USD" },
      ]),
      inflationShare: 200,
      minRewardedTurnoutBIPS: 5000,
      mode: 0,
      primaryBandRewardSharePPM: 700000,
      secondaryBandWidthPPMs: FtsoConfigurations.encodeSecondaryBandWidthPPMs([400, 800, 100, 250]),
    },
    { from: governanceAccount.address }
  );
  await ftsoInflationConfigurations.addFtsoConfiguration(
    {
      feedIds: FtsoConfigurations.encodeFeedIds([
        { category: 1, name: "BTC/USD" },
        { category: 1, name: "LTC/USD" },
      ]),
      inflationShare: 100,
      minRewardedTurnoutBIPS: 5000,
      mode: 0,
      primaryBandRewardSharePPM: 600000,
      secondaryBandWidthPPMs: FtsoConfigurations.encodeSecondaryBandWidthPPMs([200, 1000]),
    },
    { from: governanceAccount.address }
  );

  const FEED_IDS = [
    FtsoConfigurations.encodeFeedId({ category: 1, name: "BTC/USD" }),
    FtsoConfigurations.encodeFeedId({ category: 1, name: "XRP/USD" }),
    FtsoConfigurations.encodeFeedId({ category: 1, name: "FLR/USD" }),
    FtsoConfigurations.encodeFeedId({ category: 1, name: "ETH/USD" }),
    FtsoConfigurations.encodeFeedId({ category: 1, name: "LTC/USD" }),
  ];
  const ANCHOR_FEEDS = [6971622, 5296, 2813, 3813387, 863218];
  const DECIMALS = [2, 4, 5, 3, 4];

  for (let i = 0; i < 5; i++) {
    const getCurrentFeedSelector = hre.web3.eth.abi.encodeFunctionSignature("getCurrentFeed(bytes21)");
    const encodedFeedId = web3.eth.abi.encodeParameter("bytes21", FEED_IDS[i]);
    const getCurrentFeed = getCurrentFeedSelector + encodedFeedId.slice(2);
    const feed = web3.eth.abi.encodeParameters(
      ["tuple(uint32,bytes21,int32,uint16,int8)"], // IFtsoFeedPublisher.Feed (uint32 votingRoundId, bytes21 id, int32 value, uint16 turnoutBIPS, int8 decimals)
      [[settings.firstRewardEpochStartVotingRoundId, FEED_IDS[i], ANCHOR_FEEDS[i], 6000, DECIMALS[i]]]
    );
    await mockContract.givenCalldataReturn(getCurrentFeed, feed);
  }

  // Add feeds to FastUpdatesConfiguration
  await fastUpdatesConfiguration.addFeeds([
    { feedId: FEED_IDS[0], rewardBandValue: 2000, inflationShare: 200 },
    { feedId: FEED_IDS[1], rewardBandValue: 4000, inflationShare: 100 },
    { feedId: FEED_IDS[2], rewardBandValue: 3000, inflationShare: 200 },
    { feedId: FEED_IDS[3], rewardBandValue: 3000, inflationShare: 100 },
    { feedId: FEED_IDS[4], rewardBandValue: 3000, inflationShare: 100 },
  ]);

  // Register FastUpdater on Submission contract
  const submitUpdatesSelector = hre.web3.eth.abi.encodeFunctionSignature("submitUpdates((uint256,(uint256,(uint256,uint256),uint256,uint256),bytes,(uint8,bytes32,bytes32)))");

  await submission.setSubmitAndPassData(
    fastUpdater.address,
    submitUpdatesSelector,
    { from: governanceAccount.address }
  );

  await entityManager.setNodePossessionVerifier(mockContract.address, { from: governanceAccount.address }); // mock verifier
  await entityManager.setPublicKeyVerifier(fastUpdater.address, { from: governanceAccount.address });

  await pChainStakeMirror.setCleanerContract(CLEANER_CONTRACT_ADDR, { from: governanceAccount.address });
  await pChainStakeMirror.activate({ from: governanceAccount.address });
  await cChainStake.activate({ from: governanceAccount.address });

  // register flare daemonized contracts
  const registrations = [
    { daemonizedContract: flareSystemsManager.address, gasLimit: 40000000 },
    { daemonizedContract: fastUpdater.address, gasLimit: 20000000 },
  ];
  await flareDaemon.registerToDaemonize(registrations, { from: genesisGovernance });

  logger.info(
    `Finished deploying contracts:\n` +
    `  FlareSystemsManager: ${flareSystemsManager.address},\n` +
    `  Submission: ${submission.address},\n` +
    `  Relay: ${relay.address},\n` +
    `  FastUpdater: ${fastUpdater.address},\n` +
    `  FdcHub: ${fdcHub.address},\n` +
    `  TeeExtensionRegistry: ${teeExtensionRegistry.address},\n` +
    `  TeeMachineRegistry: ${teeMachineRegistry.address},\n` +
    `  TeeWalletProjectManager: ${teeWalletProjectManager.address},\n` +
    `  TeeWalletManager: ${teeWalletManager.address},\n` +
    `  TeeWalletKeyManager: ${teeWalletKeyManager.address},\n` +
    `  TeeWalletBackupManager: ${teeWalletBackupManager.address},\n` +
    `  FtdcHub: ${ftdcHub.address},\n`
  );

  logger.info(`Current network time: ${new Date((await time.latest()) * 1000).toISOString()}`);

  const contracts: DeployedContracts = {
    addressUpdater,
    flareDaemon,
    pChainStakeMirror,
    cChainStake,
    vp: vpContract,
    wNat,
    governanceVotePower,
    addressBinder,
    pChainStakeMirrorVerifier,
    mockContract,
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
    ftsoFeedIdConverter,
    cleanupBlockNumberManager,
    fastUpdateIncentiveManager,
    fastUpdater,
    fastUpdatesConfiguration,
    nodePossessionVerifier,
    feeCalculator,
    fdcHub,
    teeOwnerAllowlist,
    teeGovernance,
    teeVersionManager,
    teeVerification,
    teeReplication,
    teeExtensionRegistry,
    teeSystemStateVerifier,
    teeMachineRegistry,
    teeWalletProjectManager,
    teeWalletManager,
    teeWalletKeyManager,
    teeWalletBackupManager,
    teeFeeCalculator,
    teeRewardOffersManager,
    teePayments: teePaymentsList,
    ftdcHub,
    ftdcRequestFeeConfigurations,
    ftdcVerification
  };

  return [contracts, rewardEpochStart, initialSigningPolicy];
}

export function serializeDeployedContractsAddresses(contracts: DeployedContracts, fname: string) {
  const result: any = {};
  Object.entries(contracts).forEach(([name, data]) => {
    if (data instanceof Array) {
      for (let i = 0; i < data.length; i++) {
        result[`${data[i].constructor.contractName}_${i}`] = data[i].address;
      }
    } else {
      result[data.constructor.contractName] = data.address;
    }
  });
  fs.writeFileSync(fname, JSON.stringify(result, null, 2));
}
