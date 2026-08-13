import fs from "fs";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ISigningPolicy } from "../../scripts/libs/protocol/SigningPolicy";
import {
  AddressBinderContract,
  AddressBinderInstance,
  AddressUpdaterContract,
  AddressUpdaterInstance,
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
  Fdc2HubContract,
  Fdc2HubInstance,
  Fdc2HubProxyContract,
  Fdc2InflationConfigurationsContract,
  Fdc2InflationConfigurationsInstance,
  Fdc2InflationConfigurationsProxyContract,
  Fdc2RequestFeeConfigurationsContract,
  Fdc2RequestFeeConfigurationsInstance,
  Fdc2RequestFeeConfigurationsProxyContract,
  Fdc2RewardOffersManagerContract,
  Fdc2RewardOffersManagerInstance,
  Fdc2RewardOffersManagerProxyContract,
  Fdc2VerificationContract,
  Fdc2VerificationInstance,
  Fdc2VerificationProxyContract,
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
  FlareTeeManagerContract,
  FlareTeeManagerInitContract,
  FlareTeeManagerInstance,
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
  PMWPaymentStatusVerifierMockContract,
  PMWPaymentStatusVerifierMockInstance,
  RelayContract,
  RelayInstance,
  RewardManagerContract,
  RewardManagerInstance,
  SubmissionContract,
  SubmissionInstance,
  TeeExtensionInstructionsSenderMockContract,
  TeeExtensionInstructionsSenderMockInstance,
  ExtensionManagerFacetContract,
  InstructionsFacetContract,
  OperationFeesFacetContract,
  OwnerAllowlistFacetContract,
  TeePaymentsContract,
  TeePaymentsConfigVerifierContract,
  TeePaymentsConfigVerifierInstance,
  TeePaymentsConfigVerifierProxyContract,
  AddressValidatorContract,
  AddressValidatorInstance,
  AddressValidatorProxyContract,
  TeePaymentsFeeScheduleManagerContract,
  TeePaymentsFeeScheduleManagerInstance,
  TeePaymentsFeeScheduleManagerProxyContract,
  TeePaymentsInstance,
  TeePaymentsProxyContract,
  TeePaymentsRegistryContract,
  TeePaymentsRegistryInstance,
  TeePaymentsRegistryProxyContract,
  TeePaymentsUtxoContract,
  TeePaymentsUtxoInstance,
  TeeRewardOffersManagerContract,
  TeeRewardOffersManagerInstance,
  TeeRewardOffersManagerProxyContract,
  TestableFlareDaemonContract,
  TestableFlareDaemonInstance,
  VPContractContract,
  VPContractInstance,
  VoterRegistryContract,
  VoterRegistryInstance,
  VrfVerifierContract,
  VrfVerifierInstance,
  WNatContract,
  WNatDelegationFeeContract,
  WNatDelegationFeeInstance,
  WNatInstance,
  RelayProxyContract,
} from "../../typechain-truffle";

import { AbiItem } from "web3-utils";
import { time } from "@nomicfoundation/hardhat-network-helpers";
import { Contracts } from "../scripts/Contracts";
import { Account } from "web3-core";
import { FACETS, deployFacetsAndBuildCuts } from "../scripts/deploy-flare-tee-manager";
import {
  TIMELOCK_SEC,
  systemSettings,
  getSigningPolicyHash,
  FTSO_PROTOCOL_ID,
  TEE_PAYMENTS_CONFIGURATIONS,
  TEE_PAYMENTS_UTXO_CONFIGURATIONS,
  TEE_OPERATION_FEES,
  rewardEpochDurationSeconds,
  FDC2_FEE_CONFIGURATIONS,
  TEE_KEY_CONFIGURATIONS,
  TEE_PLATFORMS,
  TEE_CODE_HASH,
  TEE_EXTENSION_CODE_HASH,
} from "../tasks/run-simulation";
import { getLogger } from "./logger";
import { testDeployGovernanceSettings } from "./contract-helpers";
import { FtsoConfigurations } from "../../scripts/libs/protocol/FtsoConfigurations";
import { RelayInitialConfig } from "./RelayInitialConfig";

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
  readonly flareTeeManager: FlareTeeManagerInstance; // FlareTeeManager Diamond instance
  readonly teeRewardOffersManager: TeeRewardOffersManagerInstance;
  readonly teePaymentsFeeScheduleManager: TeePaymentsFeeScheduleManagerInstance;
  readonly teePaymentsRegistry: TeePaymentsRegistryInstance;
  readonly teePaymentsConfigVerifier: TeePaymentsConfigVerifierInstance;
  readonly addressValidator: AddressValidatorInstance;
  readonly teePayments: (TeePaymentsInstance | TeePaymentsUtxoInstance)[];
  readonly fdc2Hub: Fdc2HubInstance;
  readonly fdc2InflationConfigurations: Fdc2InflationConfigurationsInstance;
  readonly fdc2RequestFeeConfigurations: Fdc2RequestFeeConfigurationsInstance;
  readonly fdc2RewardOffersManager: Fdc2RewardOffersManagerInstance;
  readonly fdc2Verification: Fdc2VerificationInstance;
  readonly pmwPaymentStatusVerifierMock: PMWPaymentStatusVerifierMockInstance;
  readonly teeExtensionInstructionsSenderMock: TeeExtensionInstructionsSenderMockInstance;
  readonly vrfVerifier: VrfVerifierInstance;
}

const logger = getLogger("contracts");

export async function deployContracts(
  accounts: Account[],
  hre: HardhatRuntimeEnvironment,
  governanceAccount: Account,
  extensionOwnerAccount: Account
): Promise<[DeployedContracts, number, ISigningPolicy]> {
  const CLEANER_CONTRACT_ADDR = accounts[2].address;
  const MULTI_SIG_VOTING_ADDR = accounts[3].address;
  const RELAY_ADDR = accounts[4].address;
  const CLAIM_SETUP_MANAGER_ADDR = accounts[5].address;
  const FTSO_REWARD_MANAGER_ADDR = accounts[6].address;
  const INFLATION_ADDR = accounts[7].address;

  const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

  const MockContract = hre.artifacts.require("MockContract") as MockContractContract;
  const WNat = hre.artifacts.require("WNat") as WNatContract;
  const VPContract = hre.artifacts.require("VPContract") as VPContractContract;
  const PChainStakeMirror = hre.artifacts.require("PChainStakeMirror") as PChainStakeMirrorContract;
  const GovernanceVotePower = hre.artifacts.require("GovernanceVotePower") as GovernanceVotePowerContract;
  const AddressBinder = hre.artifacts.require("AddressBinder") as AddressBinderContract;
  const PChainStakeMirrorVerifier = hre.artifacts.require(
    "PChainStakeMirrorVerifier"
  ) as PChainStakeMirrorVerifierContract;
  const EntityManager = hre.artifacts.require("EntityManager") as EntityManagerContract;
  const VoterRegistry = hre.artifacts.require("VoterRegistry") as VoterRegistryContract;
  const FlareSystemsCalculator = hre.artifacts.require("FlareSystemsCalculator") as FlareSystemsCalculatorContract;
  const FlareSystemsManager = hre.artifacts.require("FlareSystemsManager") as FlareSystemsManagerContract;
  const RewardManager = hre.artifacts.require("RewardManager") as RewardManagerContract;
  const Submission = hre.artifacts.require("Submission") as SubmissionContract;
  const CChainStake = hre.artifacts.require("CChainStake") as CChainStakeContract;
  const WNatDelegationFee = hre.artifacts.require("WNatDelegationFee") as WNatDelegationFeeContract;
  const FtsoInflationConfigurations = hre.artifacts.require(
    "FtsoInflationConfigurations"
  ) as FtsoInflationConfigurationsContract;
  const FtsoRewardOffersManager: FtsoRewardOffersManagerContract = hre.artifacts.require(
    "FtsoRewardOffersManager"
  ) as FtsoRewardOffersManagerContract;
  const FtsoFeedDecimals = hre.artifacts.require("FtsoFeedDecimals") as FtsoFeedDecimalsContract;
  const FtsoFeedPublisher = hre.artifacts.require("FtsoFeedPublisher") as FtsoFeedPublisherContract;
  const FtsoFeedIdConverter = hre.artifacts.require("FtsoFeedIdConverter") as FtsoFeedIdConverterContract;
  const CleanupBlockNumberManager = hre.artifacts.require(
    "CleanupBlockNumberManager"
  ) as CleanupBlockNumberManagerContract;
  const Relay = hre.artifacts.require("Relay") as RelayContract;
  const TestableFlareDaemon = hre.artifacts.require("TestableFlareDaemon") as TestableFlareDaemonContract;
  const NodePossessionVerifier = hre.artifacts.require("NodePossessionVerifier") as NodePossessionVerifierContract;
  const FdcHub = hre.artifacts.require("FdcHub") as FdcHubContract;
  const FdcInflationConfigurations = hre.artifacts.require(
    "FdcInflationConfigurations"
  ) as FdcInflationConfigurationsContract;
  const FdcRequestFeeConfigurations = hre.artifacts.require(
    "FdcRequestFeeConfigurations"
  ) as FdcRequestFeeConfigurationsContract;
  const FastUpdateIncentiveManager = hre.artifacts.require(
    "FastUpdateIncentiveManager"
  ) as FastUpdateIncentiveManagerContract;
  const FastUpdater = hre.artifacts.require("FastUpdater") as FastUpdaterContract;
  const FastUpdatesConfiguration = hre.artifacts.require(
    "FastUpdatesConfiguration"
  ) as FastUpdatesConfigurationContract;
  const FeeCalculator = hre.artifacts.require("FeeCalculator") as FeeCalculatorContract;

  // Remaining separate UUPS proxy contracts
  const TeeRewardOffersManager = hre.artifacts.require("TeeRewardOffersManager") as TeeRewardOffersManagerContract;
  const TeeRewardOffersManagerProxy = hre.artifacts.require(
    "TeeRewardOffersManagerProxy"
  ) as TeeRewardOffersManagerProxyContract;
  const TeePayments = hre.artifacts.require("TeePayments") as TeePaymentsContract;
  const TeePaymentsUtxo = hre.artifacts.require("TeePaymentsUtxo") as TeePaymentsUtxoContract;
  const TeePaymentsProxy = hre.artifacts.require("TeePaymentsProxy") as TeePaymentsProxyContract;
  const TeePaymentsConfigVerifier = hre.artifacts.require(
    "TeePaymentsConfigVerifier"
  ) as TeePaymentsConfigVerifierContract;
  const TeePaymentsConfigVerifierProxy = hre.artifacts.require(
    "TeePaymentsConfigVerifierProxy"
  ) as TeePaymentsConfigVerifierProxyContract;
  const AddressValidator = hre.artifacts.require("AddressValidator") as AddressValidatorContract;
  const AddressValidatorProxy = hre.artifacts.require("AddressValidatorProxy") as AddressValidatorProxyContract;
  const TeePaymentsFeeScheduleManager = hre.artifacts.require(
    "TeePaymentsFeeScheduleManager"
  ) as TeePaymentsFeeScheduleManagerContract;
  const TeePaymentsFeeScheduleManagerProxy = hre.artifacts.require(
    "TeePaymentsFeeScheduleManagerProxy"
  ) as TeePaymentsFeeScheduleManagerProxyContract;
  const TeePaymentsRegistry = hre.artifacts.require("TeePaymentsRegistry") as TeePaymentsRegistryContract;
  const TeePaymentsRegistryProxy = hre.artifacts.require(
    "TeePaymentsRegistryProxy"
  ) as TeePaymentsRegistryProxyContract;
  const Fdc2Hub = hre.artifacts.require("Fdc2Hub") as Fdc2HubContract;
  const Fdc2HubProxy = hre.artifacts.require("Fdc2HubProxy") as Fdc2HubProxyContract;
  const Fdc2InflationConfigurations = hre.artifacts.require(
    "Fdc2InflationConfigurations"
  ) as Fdc2InflationConfigurationsContract;
  const Fdc2InflationConfigurationsProxy = hre.artifacts.require(
    "Fdc2InflationConfigurationsProxy"
  ) as Fdc2InflationConfigurationsProxyContract;
  const Fdc2RequestFeeConfigurations = hre.artifacts.require(
    "Fdc2RequestFeeConfigurations"
  ) as Fdc2RequestFeeConfigurationsContract;
  const Fdc2RequestFeeConfigurationsProxy = hre.artifacts.require(
    "Fdc2RequestFeeConfigurationsProxy"
  ) as Fdc2RequestFeeConfigurationsProxyContract;
  const Fdc2RewardOffersManager = hre.artifacts.require("Fdc2RewardOffersManager") as Fdc2RewardOffersManagerContract;
  const Fdc2RewardOffersManagerProxy = hre.artifacts.require(
    "Fdc2RewardOffersManagerProxy"
  ) as Fdc2RewardOffersManagerProxyContract;
  const Fdc2Verification = hre.artifacts.require("Fdc2Verification") as Fdc2VerificationContract;
  const Fdc2VerificationProxy = hre.artifacts.require("Fdc2VerificationProxy") as Fdc2VerificationProxyContract;
  const AddressUpdater = hre.artifacts.require("AddressUpdater") as AddressUpdaterContract;

  const PMWPaymentStatusVerifierMock = hre.artifacts.require(
    "PMWPaymentStatusVerifierMock"
  ) as PMWPaymentStatusVerifierMockContract;
  const TeeExtensionInstructionsSenderMock = hre.artifacts.require(
    "TeeExtensionInstructionsSenderMock"
  ) as TeeExtensionInstructionsSenderMockContract;
  const VrfVerifier = hre.artifacts.require("VrfVerifier") as VrfVerifierContract;

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
    100,
    5
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

  // The initial signing-policy hash is bound to this Relay's source chain.
  const relayChainId = await hre.web3.eth.getChainId();
  const relayInitialConfig: RelayInitialConfig = {
    initialRewardEpochId: initialSigningPolicy.rewardEpochId,
    startingVotingRoundIdForInitialRewardEpochId: initialSigningPolicy.startVotingRoundId,
    initialSigningPolicyHash: getSigningPolicyHash(initialSigningPolicy, relayChainId),
    randomNumberProtocolId: FTSO_PROTOCOL_ID,
    firstVotingRoundStartTs: settings.firstVotingRoundStartTs,
    votingEpochDurationSeconds: settings.votingEpochDurationSeconds,
    firstRewardEpochStartVotingRoundId: settings.firstRewardEpochStartVotingRoundId,
    rewardEpochDurationInVotingEpochs: settings.rewardEpochDurationInVotingEpochs,
    thresholdIncreaseBIPS: 12000,
    messageFinalizationWindowInRewardEpochs: 100,
    feeCollectionAddress: ZERO_ADDRESS,
    feeConfigs: [],
    // Test deploy: the source id is mandatory; owner-timelock off so the governance
    // account can act immediately.
    sourceChainId: relayChainId,
    timelockDurationSeconds: 0,
  };

  const RelayProxy = hre.artifacts.require("RelayProxy") as RelayProxyContract;
  const relayImplementation = await Relay.new();
  const relayProxy = await RelayProxy.new(
    relayImplementation.address,
    {
      ...relayInitialConfig,
      feeExemptAddresses: relayInitialConfig.feeExemptAddresses ?? [],
      feeToken: relayInitialConfig.feeToken ?? ZERO_ADDRESS,
    },
    flareSystemsManager.address,
    ZERO_ADDRESS,
    governanceAccount.address
  );
  const relay = await Relay.at(relayProxy.address);

  const submission = await Submission.new(
    governanceSettings.address,
    governanceAccount.address,
    addressUpdater.address,
    false
  );
  addressUpdatableContracts.push(submission.address);

  const wNatDelegationFee = await WNatDelegationFee.new(addressUpdater.address, 2, 2000, 2000);
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
  const fdcInflationConfigurations = await FdcInflationConfigurations.new(
    governanceSettings.address,
    governanceAccount.address,
    addressUpdater.address
  );
  addressUpdatableContracts.push(fdcInflationConfigurations.address);
  const fdcRequestFeeConfigurations = await FdcRequestFeeConfigurations.new(
    governanceSettings.address,
    governanceAccount.address
  );

  // =========================================================================
  // Deploy FlareTeeManager Diamond
  // =========================================================================

  // Deploy facets and build FacetCut array
  const { facetCuts } = await deployFacetsAndBuildCuts(hre, FACETS);

  // Deploy FlareTeeManagerInit and encode init calldata
  const FlareTeeManagerInit = hre.artifacts.require("FlareTeeManagerInit") as FlareTeeManagerInitContract;
  const flareTeeManagerInit = await FlareTeeManagerInit.new();
  const flareTeeManagerInitCalldata = hre.web3.eth.abi.encodeFunctionCall(
    (FlareTeeManagerInit as unknown as { abi: AbiItem[] }).abi.find((item: AbiItem) => item.name === "init")!,
    [
      governanceSettings.address,
      governanceAccount.address,
      addressUpdater.address,
      "3600", // availabilityCheckValidityDurationSeconds
      "10", // signingPolicyValidityDurationInRewardEpochs
      "600", // challengeValidityDurationSeconds
      "1", // defaultFee
      true as unknown as string, // publicExtensionCreationEnabled — open for local simulation
      "7200", // emergencyUnpauseGracePeriodSeconds (2h default)
    ]
  );

  // Deploy FlareTeeManager Diamond
  const FlareTeeManager = hre.artifacts.require("FlareTeeManager") as FlareTeeManagerContract;
  const flareTeeManager = await FlareTeeManager.new(facetCuts, {
    init: flareTeeManagerInit.address,
    initCalldata: flareTeeManagerInitCalldata,
  });
  addressUpdatableContracts.push(flareTeeManager.address);

  // Access Diamond facet interfaces for post-init configuration
  const extensionManager = await (hre.artifacts.require("ExtensionManagerFacet") as ExtensionManagerFacetContract).at(
    flareTeeManager.address
  );
  const operationFeesFacet = await (hre.artifacts.require("OperationFeesFacet") as OperationFeesFacetContract).at(
    flareTeeManager.address
  );
  const ownerAllowlist = await (hre.artifacts.require("OwnerAllowlistFacet") as OwnerAllowlistFacetContract).at(
    flareTeeManager.address
  );
  const instructionsFacet = await (hre.artifacts.require("InstructionsFacet") as InstructionsFacetContract).at(
    flareTeeManager.address
  );

  // Set operation fees
  const operationTypes: string[] = [];
  const operationCommands: string[] = [];
  const operationFees: string[] = [];
  for (const teeOperationFee of TEE_OPERATION_FEES) {
    operationTypes.push(web3.utils.utf8ToHex(teeOperationFee.opType).padEnd(66, "0"));
    operationCommands.push(web3.utils.utf8ToHex(teeOperationFee.opCommand).padEnd(66, "0"));
    operationFees.push(teeOperationFee.feeWei);
  }
  await operationFeesFacet.setOperationFees(operationTypes, operationCommands, operationFees, {
    from: governanceAccount.address,
  });

  // =========================================================================
  // Deploy remaining separate UUPS proxy contracts
  // =========================================================================
  const teeRewardOffersManagerImpl = await TeeRewardOffersManager.new();
  const teeRewardOffersManagerProxy = await TeeRewardOffersManagerProxy.new(
    governanceSettings.address,
    governanceAccount.address,
    addressUpdater.address,
    100000, // 10%
    teeRewardOffersManagerImpl.address
  );
  const teeRewardOffersManager = await TeeRewardOffersManager.at(teeRewardOffersManagerProxy.address);
  addressUpdatableContracts.push(teeRewardOffersManager.address);

  // Shared fee schedule manager — deployed before TeePayments so it can be injected via AddressUpdater
  const teePaymentsFeeScheduleManagerImpl = await TeePaymentsFeeScheduleManager.new();
  const teePaymentsFeeScheduleManagerProxy = await TeePaymentsFeeScheduleManagerProxy.new(
    governanceSettings.address,
    governanceAccount.address,
    addressUpdater.address,
    teePaymentsFeeScheduleManagerImpl.address
  );
  const teePaymentsFeeScheduleManager = await TeePaymentsFeeScheduleManager.at(
    teePaymentsFeeScheduleManagerProxy.address
  );
  addressUpdatableContracts.push(teePaymentsFeeScheduleManager.address);

  // Shared sourceId -> TeePayments registry
  const teePaymentsRegistryImpl = await TeePaymentsRegistry.new();
  const teePaymentsRegistryProxy = await TeePaymentsRegistryProxy.new(
    governanceSettings.address,
    governanceAccount.address,
    addressUpdater.address,
    teePaymentsRegistryImpl.address
  );
  const teePaymentsRegistry = await TeePaymentsRegistry.at(teePaymentsRegistryProxy.address);
  addressUpdatableContracts.push(teePaymentsRegistry.address);

  // Shared PMW configuration request + verify contract
  const teePaymentsConfigVerifierImpl = await TeePaymentsConfigVerifier.new();
  const teePaymentsConfigVerifierProxy = await TeePaymentsConfigVerifierProxy.new(
    governanceSettings.address,
    governanceAccount.address,
    addressUpdater.address,
    teePaymentsConfigVerifierImpl.address
  );
  const teePaymentsConfigVerifier = await TeePaymentsConfigVerifier.at(teePaymentsConfigVerifierProxy.address);
  addressUpdatableContracts.push(teePaymentsConfigVerifier.address);

  // Shared sourceId-aware recipient address validator
  const addressValidatorImpl = await AddressValidator.new();
  const addressValidatorProxy = await AddressValidatorProxy.new(
    governanceSettings.address,
    governanceAccount.address,
    addressUpdater.address,
    addressValidatorImpl.address
  );
  const addressValidator = await AddressValidator.at(addressValidatorProxy.address);
  addressUpdatableContracts.push(addressValidator.address);

  const teePaymentsList: (TeePaymentsInstance | TeePaymentsUtxoInstance)[] = [];
  const sourceRegistrations: {
    keyType: string;
    opType: string;
    paymentModel: number;
    sourceId: string;
    teePayments: string;
  }[] = [];

  // A single account proxy serves every account source and a single UTXO proxy serves every UTXO
  // source — each source carries its own keyType/opType in the registry, so one proxy per payment
  // model is enough. Implementations are deployed only when used.
  if (TEE_PAYMENTS_CONFIGURATIONS.length > 0) {
    const teePaymentsImpl = await TeePayments.new();
    const teePaymentsProxy = await TeePaymentsProxy.new(
      governanceSettings.address,
      governanceAccount.address,
      addressUpdater.address,
      teePaymentsImpl.address
    );
    const teePayments = await TeePayments.at(teePaymentsProxy.address);
    teePaymentsList.push(teePayments);
    addressUpdatableContracts.push(teePayments.address);
    for (const teePaymentConfig of TEE_PAYMENTS_CONFIGURATIONS) {
      for (const src of teePaymentConfig.sourceConfigs) {
        sourceRegistrations.push({
          keyType: web3.utils.utf8ToHex(teePaymentConfig.keyType).padEnd(66, "0"),
          opType: web3.utils.utf8ToHex(teePaymentConfig.opType).padEnd(66, "0"),
          paymentModel: 1,
          sourceId: web3.utils.utf8ToHex(src.sourceId).padEnd(66, "0"),
          teePayments: teePayments.address,
        });
      }
    }
  }

  let teePaymentsUtxoAddress: string | undefined;
  if (TEE_PAYMENTS_UTXO_CONFIGURATIONS.length > 0) {
    const teePaymentsUtxoImpl = await TeePaymentsUtxo.new();
    const teePaymentsProxy = await TeePaymentsProxy.new(
      governanceSettings.address,
      governanceAccount.address,
      addressUpdater.address,
      teePaymentsUtxoImpl.address
    );
    const teePayments = await TeePaymentsUtxo.at(teePaymentsProxy.address);
    teePaymentsUtxoAddress = teePayments.address;
    teePaymentsList.push(teePayments);
    addressUpdatableContracts.push(teePayments.address);
    for (const teePaymentConfig of TEE_PAYMENTS_UTXO_CONFIGURATIONS) {
      for (const src of teePaymentConfig.sourceConfigs) {
        sourceRegistrations.push({
          keyType: web3.utils.utf8ToHex(teePaymentConfig.keyType).padEnd(66, "0"),
          opType: web3.utils.utf8ToHex(teePaymentConfig.opType).padEnd(66, "0"),
          paymentModel: 2,
          sourceId: web3.utils.utf8ToHex(src.sourceId).padEnd(66, "0"),
          teePayments: teePayments.address,
        });
      }
    }
  }

  // FDC2
  const fdc2HubImpl = await Fdc2Hub.new();
  const fdc2HubProxy = await Fdc2HubProxy.new(
    governanceSettings.address,
    governanceAccount.address,
    addressUpdater.address,
    3000,
    1,
    fdc2HubImpl.address
  );
  const fdc2Hub = await Fdc2Hub.at(fdc2HubProxy.address);
  addressUpdatableContracts.push(fdc2Hub.address);

  const fdc2RequestFeeConfigurationsImpl = await Fdc2RequestFeeConfigurations.new();
  const fdc2RequestFeeConfigurationsProxy = await Fdc2RequestFeeConfigurationsProxy.new(
    governanceSettings.address,
    governanceAccount.address,
    addressUpdater.address,
    fdc2RequestFeeConfigurationsImpl.address
  );
  const fdc2RequestFeeConfigurations = await Fdc2RequestFeeConfigurations.at(fdc2RequestFeeConfigurationsProxy.address);

  const fdc2VerificationImpl = await Fdc2Verification.new();
  const fdc2VerificationProxy = await Fdc2VerificationProxy.new(
    governanceSettings.address,
    governanceAccount.address,
    addressUpdater.address,
    fdc2VerificationImpl.address
  );
  const fdc2Verification = await Fdc2Verification.at(fdc2VerificationProxy.address);
  addressUpdatableContracts.push(fdc2Verification.address);

  const fdc2InflationConfigurationsImpl = await Fdc2InflationConfigurations.new();
  const fdc2InflationConfigurationsProxy = await Fdc2InflationConfigurationsProxy.new(
    governanceSettings.address,
    governanceAccount.address,
    addressUpdater.address,
    fdc2InflationConfigurationsImpl.address
  );
  const fdc2InflationConfigurations = await Fdc2InflationConfigurations.at(fdc2InflationConfigurationsProxy.address);
  addressUpdatableContracts.push(fdc2InflationConfigurations.address);

  const fdc2RewardOffersManagerImpl = await Fdc2RewardOffersManager.new();
  const fdc2RewardOffersManagerProxy = await Fdc2RewardOffersManagerProxy.new(
    governanceSettings.address,
    governanceAccount.address,
    addressUpdater.address,
    fdc2RewardOffersManagerImpl.address
  );
  const fdc2RewardOffersManager = await Fdc2RewardOffersManager.at(fdc2RewardOffersManagerProxy.address);
  addressUpdatableContracts.push(fdc2RewardOffersManager.address);

  // MOCKS
  const pmwPaymentStatusVerifierMock = await PMWPaymentStatusVerifierMock.new(addressUpdater.address, [], 0, 1);
  addressUpdatableContracts.push(pmwPaymentStatusVerifierMock.address);

  const teeExtensionInstructionsSenderMock = await TeeExtensionInstructionsSenderMock.new(flareTeeManager.address);

  const vrfVerifier = await VrfVerifier.new();

  // Set the FDC2 request fee configurations
  for (const fdc2RequestFee of FDC2_FEE_CONFIGURATIONS) {
    await fdc2RequestFeeConfigurations.setTypeAndSourceFee(
      web3.utils.utf8ToHex(fdc2RequestFee.attestationType).padEnd(66, "0"),
      web3.utils.utf8ToHex(fdc2RequestFee.source).padEnd(66, "0"),
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
      Contracts.FLARE_TEE_MANAGER,
      Contracts.FDC2_HUB,
      Contracts.FDC2_VERIFICATION,
      Contracts.FDC2_REQUEST_FEE_CONFIGURATIONS,
      Contracts.FDC2_INFLATION_CONFIGURATIONS,
      Contracts.FDC2_REWARD_OFFERS_MANAGER,
      Contracts.TEE_REWARD_OFFERS_MANAGER,
      Contracts.TEE_PAYMENTS_FEE_SCHEDULE_MANAGER,
      Contracts.TEE_PAYMENTS_REGISTRY,
      Contracts.TEE_PAYMENTS_CONFIG_VERIFIER,
      Contracts.ADDRESS_VALIDATOR,
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
      flareTeeManager.address,
      fdc2Hub.address,
      fdc2Verification.address,
      fdc2RequestFeeConfigurations.address,
      fdc2InflationConfigurations.address,
      fdc2RewardOffersManager.address,
      teeRewardOffersManager.address,
      teePaymentsFeeScheduleManager.address,
      teePaymentsRegistry.address,
      teePaymentsConfigVerifier.address,
      addressValidator.address,
    ],
    addressUpdatableContracts,
    { from: governanceAccount.address }
  );

  // Register sourceId -> TeePayments bindings in the registry
  if (sourceRegistrations.length > 0) {
    await teePaymentsRegistry.registerSources(sourceRegistrations, { from: governanceAccount.address });
  }

  // Configure AddressValidator per-source {chainKind, network} profiles. chainKind is derived from
  // keyType. This is the local simulation deployment only: the Bitcoin source uses regtest (a local
  // sim runs a regtest node, so SegWit addresses are bcrt1...), and the others use testnet. Network is
  // only enforced for Bitcoin/Dogecoin and XRPL X-addresses; EVM and XRPL classic addresses are
  // network-agnostic by format.
  // ChainKind enum order: Bitcoin=0, Dogecoin=1, Xrpl=2, Evm=3. Network enum: Mainnet=0, Testnet=1, Regtest=2.
  const chainKindForKeyType = (keyType: string): number => {
    switch (keyType) {
      case "BTC":
        return 0; // Bitcoin
      case "DOGE":
        return 1; // Dogecoin
      case "XRP":
        return 2; // Xrpl
      case "EVM":
        return 3; // Evm
      default:
        throw new Error(`AddressValidator: unknown keyType '${keyType}'`);
    }
  };
  const networkForKeyType = (keyType: string): number => (keyType === "BTC" ? 2 : 1); // BTC regtest, else testnet
  const addressValidatorConfigs: { sourceId: string; chainKind: number; network: number }[] = [];
  for (const cfg of TEE_PAYMENTS_CONFIGURATIONS) {
    for (const src of cfg.sourceConfigs) {
      addressValidatorConfigs.push({
        sourceId: web3.utils.utf8ToHex(src.sourceId).padEnd(66, "0"),
        chainKind: chainKindForKeyType(cfg.keyType),
        network: networkForKeyType(cfg.keyType),
      });
    }
  }
  for (const cfg of TEE_PAYMENTS_UTXO_CONFIGURATIONS) {
    for (const src of cfg.sourceConfigs) {
      addressValidatorConfigs.push({
        sourceId: web3.utils.utf8ToHex(src.sourceId).padEnd(66, "0"),
        chainKind: chainKindForKeyType(cfg.keyType),
        network: networkForKeyType(cfg.keyType),
      });
    }
  }
  if (addressValidatorConfigs.length > 0) {
    await addressValidator.setSourceConfigs(addressValidatorConfigs, { from: governanceAccount.address });
  }

  if (teePaymentsUtxoAddress !== undefined) {
    const teePaymentsUtxo = await TeePaymentsUtxo.at(teePaymentsUtxoAddress);
    for (const teePaymentConfig of TEE_PAYMENTS_UTXO_CONFIGURATIONS) {
      for (const src of teePaymentConfig.sourceConfigs) {
        const sourceId = web3.utils.utf8ToHex(src.sourceId).padEnd(66, "0");
        await teePaymentsUtxo.setMaxBatchSettings(
          sourceId,
          teePaymentConfig.maxBatchSize,
          teePaymentConfig.maxBatchDurationSeconds,
          { from: governanceAccount.address }
        );
        await teePaymentsUtxo.setAnchorReuseDelay(sourceId, teePaymentConfig.anchorReuseDelaySeconds, {
          from: governanceAccount.address,
        });
      }
    }
  }

  await extensionManager.addSystemSupportedPlatforms(
    TEE_PLATFORMS.map((platform) => web3.utils.utf8ToHex(platform).padEnd(66, "0")),
    { from: governanceAccount.address }
  );

  await extensionManager.addSystemSupportedKeyTypesAndSigningAlgos(
    TEE_KEY_CONFIGURATIONS.map((teeKeyConfig) => web3.utils.utf8ToHex(teeKeyConfig.keyType).padEnd(66, "0")),
    TEE_KEY_CONFIGURATIONS.map((teeKeyConfig) =>
      teeKeyConfig.signingAlgos.map((alg) => web3.utils.utf8ToHex(alg).padEnd(66, "0"))
    ),
    { from: governanceAccount.address }
  );

  await extensionManager.addTeeVersion(
    0,
    web3.utils.utf8ToHex("v0.1.0").padEnd(66, "0"),
    TEE_CODE_HASH,
    TEE_PLATFORMS.map((platform) => web3.utils.utf8ToHex(platform).padEnd(66, "0")),
    { from: governanceAccount.address }
  );

  await extensionManager.addSupportedKeyTypes(
    0,
    TEE_KEY_CONFIGURATIONS.map((teeKeyConfig) => web3.utils.utf8ToHex(teeKeyConfig.keyType).padEnd(66, "0")),
    { from: governanceAccount.address }
  );

  // Only external contracts need to be registered as system instructions senders
  // (Diamond facets call libraries internally, not via sendSystemInstructions)
  await instructionsFacet.registerSystemInstructionsSenders(
    [...teePaymentsList.map((teePayments) => teePayments.address), fdc2Hub.address],
    { from: governanceAccount.address }
  );

  // Configure initial per-sourceId fee schedule limits (generous defaults for tests)
  const allSourceIds = new Set<string>();
  for (const cfg of TEE_PAYMENTS_CONFIGURATIONS) {
    for (const src of cfg.sourceConfigs) {
      allSourceIds.add(src.sourceId);
    }
  }
  const feeScheduleConfigInputs = Array.from(allSourceIds).map((srcId) => ({
    maxDelaySeconds: 65535, // uint16 max
    maxSchedules: 10,
    sourceId: web3.utils.utf8ToHex(srcId).padEnd(66, "0"),
  }));
  await teePaymentsFeeScheduleManager.setFeeScheduleConfigs(feeScheduleConfigInputs, {
    from: governanceAccount.address,
  });

  await ownerAllowlist.allowAllTeeMachineOwners(0, { from: governanceAccount.address });
  await ownerAllowlist.allowAllTeeWalletProjectOwners(0, { from: governanceAccount.address });

  // set reward offers manager list
  await rewardManager.setRewardOffersManagerList(
    [
      ftsoRewardOffersManager.address,
      fastUpdateIncentiveManager.address,
      fdcHub.address,
      teeRewardOffersManager.address,
      flareTeeManager.address,
      fdc2Hub.address,
      fdc2RewardOffersManager.address,
    ],
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
  await fdc2RewardOffersManager.setDailyAuthorizedInflation(inflationFunds, { from: INFLATION_ADDR });
  await fdc2RewardOffersManager.receiveInflation({ value: inflationFunds, from: INFLATION_ADDR });

  // set FDC types + sources + fees

  const EVMTransactionType = web3.utils.utf8ToHex("EVMTransaction").padEnd(66, "0");

  const testSGB = web3.utils.utf8ToHex("testSGB").padEnd(66, "0");

  await fdcRequestFeeConfigurations.setTypeAndSourceFee(EVMTransactionType, testSGB, "1", {
    from: governanceAccount.address,
  });

  await fdcInflationConfigurations.addFdcConfigurations(
    [
      {
        attestationType: EVMTransactionType,
        source: testSGB,
        inflationShare: 100,
        minRequestsThreshold: 2,
        mode: 0,
      },
    ],
    { from: governanceAccount.address }
  );

  // set FDC2 inflation configurations (one per registered request-fee pair)
  await fdc2InflationConfigurations.addFdc2Configurations(
    FDC2_FEE_CONFIGURATIONS.map((cfg) => ({
      attestationType: web3.utils.utf8ToHex(cfg.attestationType).padEnd(66, "0"),
      sourceId: web3.utils.utf8ToHex(cfg.source).padEnd(66, "0"),
      inflationShare: 100,
      minRequestsThreshold: 2,
      mode: 0,
    })),
    { from: governanceAccount.address }
  );

  // set rewards offer switchover trigger contracts
  await flareSystemsManager.setRewardEpochSwitchoverTriggerContracts(
    [
      ftsoRewardOffersManager.address,
      fastUpdateIncentiveManager.address,
      fdcHub.address,
      teeRewardOffersManager.address,
      fdc2RewardOffersManager.address,
    ],
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
  const submitUpdatesSelector = hre.web3.eth.abi.encodeFunctionSignature(
    "submitUpdates((uint256,(uint256,(uint256,uint256),uint256,uint256),bytes,(uint8,bytes32,bytes32)))"
  );

  await submission.setSubmitAndPassData(fastUpdater.address, submitUpdatesSelector, {
    from: governanceAccount.address,
  });

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

  // TEE EXTENSION
  const teeExtensionId = (await extensionManager.nextPublicExtensionId()).toString();
  await extensionManager.register(ZERO_ADDRESS, teeExtensionInstructionsSenderMock.address, {
    from: extensionOwnerAccount.address,
  });

  await extensionManager.addTeeVersion(
    teeExtensionId,
    web3.utils.utf8ToHex("v0.1.0").padEnd(66, "0"),
    TEE_EXTENSION_CODE_HASH,
    TEE_PLATFORMS.map((platform: string) => web3.utils.utf8ToHex(platform).padEnd(66, "0")),
    { from: extensionOwnerAccount.address }
  );

  await extensionManager.addSupportedKeyTypes(
    teeExtensionId,
    [await teeExtensionInstructionsSenderMock.KEY_TYPE()], // EVM
    { from: extensionOwnerAccount.address }
  );

  await ownerAllowlist.allowAllTeeMachineOwners(teeExtensionId, { from: extensionOwnerAccount.address });
  await ownerAllowlist.allowAllTeeWalletProjectOwners(teeExtensionId, { from: extensionOwnerAccount.address });

  logger.info(
    `Finished deploying contracts:\n` +
      `  FlareSystemsManager: ${flareSystemsManager.address},\n` +
      `  Submission: ${submission.address},\n` +
      `  Relay: ${relay.address},\n` +
      `  FastUpdater: ${fastUpdater.address},\n` +
      `  FdcHub: ${fdcHub.address},\n` +
      `  FlareTeeManager: ${flareTeeManager.address},\n` +
      `  Fdc2Hub: ${fdc2Hub.address},\n`
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
    flareTeeManager,
    teeRewardOffersManager,
    teePaymentsFeeScheduleManager,
    teePaymentsRegistry,
    teePaymentsConfigVerifier,
    addressValidator,
    teePayments: teePaymentsList,
    fdc2Hub,
    fdc2InflationConfigurations,
    fdc2RequestFeeConfigurations,
    fdc2RewardOffersManager,
    fdc2Verification,
    pmwPaymentStatusVerifierMock,
    teeExtensionInstructionsSenderMock,
    vrfVerifier,
  };

  return [contracts, rewardEpochStart, initialSigningPolicy];
}

export function serializeDeployedContractsAddresses(contracts: DeployedContracts, fname: string) {
  const result: Record<string, string> = {};
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
