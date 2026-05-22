import { globSync } from "glob";
import { readFileSync } from "node:fs";
import { constants, expectEvent, expectRevert, time } from "@openzeppelin/test-helpers";
import { toChecksumAddress } from "ethereumjs-util";
import { Contracts } from "../../deployment/scripts/Contracts";
import privateKeys from "../../deployment/test-1020-accounts.json";
import { RelayInitialConfig } from "../../deployment/utils/RelayInitialConfig";
import { ECDSASignatureWithIndex } from "../../scripts/libs/protocol/ECDSASignatureWithIndex";
import { FtsoConfigurations } from "../../scripts/libs/protocol/FtsoConfigurations";
import {
  IProtocolMessageMerkleRoot,
  ProtocolMessageMerkleRoot,
} from "../../scripts/libs/protocol/ProtocolMessageMerkleRoot";
import { RelayMessage } from "../../scripts/libs/protocol/RelayMessage";
import { ISigningPolicy, SigningPolicy } from "../../scripts/libs/protocol/SigningPolicy";
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
  Fdc2HubContract,
  Fdc2HubInstance,
  Fdc2HubProxyContract,
  Fdc2RequestFeeConfigurationsContract,
  Fdc2RequestFeeConfigurationsInstance,
  Fdc2RequestFeeConfigurationsProxyContract,
  Fdc2VerificationContract,
  Fdc2VerificationInstance,
  Fdc2VerificationProxyContract,
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
  GovernanceSettingsInstance,
  GovernanceVotePowerContract,
  GovernanceVotePowerInstance,
  MockContractContract,
  MockContractInstance,
  PChainStakeMirrorContract,
  PChainStakeMirrorInstance,
  PChainStakeMirrorVerifierContract,
  PChainStakeMirrorVerifierInstance,
  PollingFoundationContract,
  PollingFoundationInstance,
  PollingManagementGroupContract,
  PollingManagementGroupInstance,
  RelayContract,
  RelayInstance,
  RewardManagerContract,
  RewardManagerInstance,
  SubmissionContract,
  SubmissionInstance,
  TeePaymentsContract,
  TeePaymentsFeeScheduleManagerContract,
  TeePaymentsFeeScheduleManagerInstance,
  TeePaymentsFeeScheduleManagerProxyContract,
  TeePaymentsInstance,
  TeePaymentsLimitsManagerContract,
  TeePaymentsLimitsManagerInstance,
  TeePaymentsLimitsManagerProxyContract,
  TeePaymentsRegistryContract,
  TeePaymentsRegistryInstance,
  TeePaymentsRegistryProxyContract,
  TeePaymentsProxyContract,
  TeeRewardOffersManagerContract,
  TeeRewardOffersManagerInstance,
  TeeRewardOffersManagerProxyContract,
  ValidatorRewardOffersManagerContract,
  ValidatorRewardOffersManagerInstance,
  VoterRegistryContract,
  VoterRegistryInstance,
  VPContractContract,
  WNatContract,
  WNatInstance,
  WNatDelegationFeeContract,
  WNatDelegationFeeInstance,
} from "../../typechain-truffle";
import { generateSignatures } from "../unit/protocol/coding/coding-helpers";
import { getTestFile } from "../utils/constants";
import { executeTimelockedGovernanceCall, testDeployGovernanceSettings } from "../utils/contract-test-helpers";
import * as util from "../utils/key-to-address";
import { encodeContractNames, findRequiredEvent, toBN } from "../utils/test-helpers";
import { TEE_OPERATION_FEES } from "../../deployment/tasks/run-simulation";
import { requiredEventArgsFrom } from "../utils/Web3EventDecoder";
import { ECDSASignature } from "../../scripts/libs/protocol/ECDSASignature";

const MockContract: MockContractContract = artifacts.require("MockContract");
const AddressUpdater: AddressUpdaterContract = artifacts.require("AddressUpdater");
const WNat: WNatContract = artifacts.require("WNat");
const VPContract: VPContractContract = artifacts.require("VPContract");
const PChainStakeMirror: PChainStakeMirrorContract = artifacts.require("PChainStakeMirror");
const GovernanceVotePower: GovernanceVotePowerContract = artifacts.require("GovernanceVotePower");
const AddressBinder: AddressBinderContract = artifacts.require("AddressBinder");
const PChainStakeMirrorVerifier: PChainStakeMirrorVerifierContract = artifacts.require("PChainStakeMirrorVerifier");
const EntityManager: EntityManagerContract = artifacts.require("EntityManager");
const VoterRegistry: VoterRegistryContract = artifacts.require("VoterRegistry");
const FlareSystemsCalculator: FlareSystemsCalculatorContract = artifacts.require("FlareSystemsCalculator");
const FlareSystemsManager: FlareSystemsManagerContract = artifacts.require("FlareSystemsManager");
const RewardManager: RewardManagerContract = artifacts.require("RewardManager");
const Submission: SubmissionContract = artifacts.require("Submission");
const Relay: RelayContract = artifacts.require("Relay");
const CChainStake: CChainStakeContract = artifacts.require("CChainStake");
const WNatDelegationFee: WNatDelegationFeeContract = artifacts.require("WNatDelegationFee");
const FtsoInflationConfigurations: FtsoInflationConfigurationsContract =
  artifacts.require("FtsoInflationConfigurations");
const FtsoRewardOffersManager: FtsoRewardOffersManagerContract = artifacts.require("FtsoRewardOffersManager");
const FtsoFeedDecimals: FtsoFeedDecimalsContract = artifacts.require("FtsoFeedDecimals");
const FtsoFeedPublisher: FtsoFeedPublisherContract = artifacts.require("FtsoFeedPublisher");
const FtsoFeedIdConverter: FtsoFeedIdConverterContract = artifacts.require("FtsoFeedIdConverter");
const CleanupBlockNumberManager: CleanupBlockNumberManagerContract = artifacts.require("CleanupBlockNumberManager");
const ValidatorRewardOffersManager: ValidatorRewardOffersManagerContract =
  artifacts.require("ValidatorRewardOffersManager");
const PollingFoundation: PollingFoundationContract = artifacts.require("PollingFoundation");
const PollingManagementGroup: PollingManagementGroupContract = artifacts.require("PollingManagementGroup");
const FlareTeeManager = artifacts.require("FlareTeeManager");
const FlareTeeManagerInit = artifacts.require("FlareTeeManagerInit");
const ReplicationInit = artifacts.require("ReplicationInit");
const IDiamondCut = artifacts.require("IDiamondCut");
const IIFlareTeeManager = artifacts.require("IIFlareTeeManager");
const TeeRewardOffersManager: TeeRewardOffersManagerContract = artifacts.require("TeeRewardOffersManager");
const TeeRewardOffersManagerProxy: TeeRewardOffersManagerProxyContract =
  artifacts.require("TeeRewardOffersManagerProxy");
const TeePayments: TeePaymentsContract = artifacts.require("TeePayments");
const TeePaymentsProxy: TeePaymentsProxyContract = artifacts.require("TeePaymentsProxy");
const TeePaymentsFeeScheduleManager: TeePaymentsFeeScheduleManagerContract = artifacts.require(
  "TeePaymentsFeeScheduleManager"
);
const TeePaymentsFeeScheduleManagerProxy: TeePaymentsFeeScheduleManagerProxyContract = artifacts.require(
  "TeePaymentsFeeScheduleManagerProxy"
);
const TeePaymentsLimitsManager: TeePaymentsLimitsManagerContract = artifacts.require("TeePaymentsLimitsManager");
const TeePaymentsLimitsManagerProxy: TeePaymentsLimitsManagerProxyContract = artifacts.require(
  "TeePaymentsLimitsManagerProxy"
);
const TeePaymentsRegistry: TeePaymentsRegistryContract = artifacts.require("TeePaymentsRegistry");
const TeePaymentsRegistryProxy: TeePaymentsRegistryProxyContract = artifacts.require("TeePaymentsRegistryProxy");
const Fdc2Hub: Fdc2HubContract = artifacts.require("Fdc2Hub");
const Fdc2HubProxy: Fdc2HubProxyContract = artifacts.require("Fdc2HubProxy");
const Fdc2RequestFeeConfigurations: Fdc2RequestFeeConfigurationsContract =
  artifacts.require("Fdc2RequestFeeConfigurations");
const Fdc2RequestFeeConfigurationsProxy: Fdc2RequestFeeConfigurationsProxyContract = artifacts.require(
  "Fdc2RequestFeeConfigurationsProxy"
);
const Fdc2Verification: Fdc2VerificationContract = artifacts.require("Fdc2Verification");
const Fdc2VerificationProxy: Fdc2VerificationProxyContract = artifacts.require("Fdc2VerificationProxy");

type PChainStake = {
  txId: string;
  stakingType: number;
  inputAddress: string;
  nodeId: string;
  startTime: number;
  endTime: number;
  weight: number;
};

async function setMockStakingData(
  verifierMock: MockContractInstance,
  pChainStakeMirrorVerifierInterface: PChainStakeMirrorVerifierInstance,
  txId: string,
  stakingType: number,
  inputAddress: string,
  nodeId: string,
  startTime: BN,
  endTime: BN,
  weight: number,
  stakingProved: boolean = true
): Promise<PChainStake> {
  const data = {
    txId: txId,
    stakingType: stakingType,
    inputAddress: inputAddress,
    nodeId: nodeId,
    startTime: startTime.toNumber(),
    endTime: endTime.toNumber(),
    weight: weight,
  };

  // eslint-disable-next-line @typescript-eslint/no-unsafe-call, @typescript-eslint/no-unsafe-member-access
  const verifyPChainStakingMethod = pChainStakeMirrorVerifierInterface.contract.methods
    .verifyStake(data, [])
    .encodeABI();
  await verifierMock.givenCalldataReturnBool(verifyPChainStakingMethod, stakingProved);
  return data;
}

function getSigningPolicyHash(signingPolicy: ISigningPolicy): string {
  return SigningPolicy.hash(signingPolicy);
}

function getHash(type: any, parameter: any): string {
  return web3.utils.keccak256(web3.eth.abi.encodeParameter(type, parameter));
}

function getFdc2Message(headerHash: string, requestBodyHash: string, responseBodyHash: string): string {
  return web3.utils.keccak256(
    web3.eth.abi.encodeParameters(["bytes32", "bytes32", "bytes32"], [headerHash, requestBodyHash, responseBodyHash])
  );
}

function getStruct(contractName: string, functionName: string) {
  const files = globSync(`artifacts/!(build-info)/**/structs/${contractName}.sol/${contractName}.json`);
  if (files.length !== 1) {
    throw new Error(`Expected one file for ${contractName}, found ${files.length}.`);
  }
  const contract = JSON.parse(readFileSync(files[0], "utf8"));
  const struct = contract.abi.find((item: any) => item.type === "function" && item.name === functionName);
  if (!struct) {
    throw new Error(`Expected function ${functionName} in ${contractName} not found.`);
  }
  if (struct.inputs.length !== 1) {
    throw new Error(`Expected function ${functionName} in ${contractName} to have exactly one input.`);
  }
  return struct.inputs[0];
}

function getSelectors(abi: any[]): string[] {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { Interface } = require("ethers");
  const iface = new Interface(abi.filter((item: any) => item.type === "function"));
  return iface.fragments.filter((f: any) => f.type === "function").map((f: any) => f.selector);
}

contract(`End to end test; ${getTestFile(__filename)}`, (accounts) => {
  async function getNewSigningPolicySignatures(message: string): Promise<string> {
    const messageData: IProtocolMessageMerkleRoot = {
      protocolId: 1,
      votingRoundId: 0,
      isSecureRandom: false,
      merkleRoot: message,
    };
    const messageHash = ProtocolMessageMerkleRoot.hash(messageData);

    const signatures = await generateSignatures(
      privateKeys.slice(30, 34).map((x) => x.privateKey),
      messageHash,
      4
    );

    const relayMessage = {
      signingPolicy: newSigningPolicy,
      signatures,
      protocolMessageMerkleRoot: messageData,
    };

    const fullData = RelayMessage.encode(relayMessage);
    return RELAY_SELECTOR + fullData.slice(2);
  }

  const FTSO_PROTOCOL_ID = 100;
  const REWARD_MANAGER_ID = 0;
  const TEE_CODE_HASH = "0x194844cf417dde867073e5ab7199fa4d21fd82b5dbe2bdea8b3d7fc18d10fdc2";
  const TEE_PLATFORMS = ["GCP_INTEL_TDX", "GCP_AMD_SEV"];
  const TEE_KEY_CONFIGURATIONS = [
    web3.utils.utf8ToHex("XRP").padEnd(66, "0"),
    web3.utils.utf8ToHex("EVM").padEnd(66, "0"),
  ];
  const TEE_SIGNING_ALGOS = [
    [web3.utils.utf8ToHex("sha512half-secp256k1-ecdsa").padEnd(66, "0")],
    [
      web3.utils.utf8ToHex("keccak256-secp256k1-ecdsa").padEnd(66, "0"),
      web3.utils.utf8ToHex("keccak256-secp256k1-vrf").padEnd(66, "0"),
    ],
  ];
  const TEE_OWNERS = [accounts[101], accounts[102]];
  const TEE_IDS = [accounts[20], accounts[21]];
  let [x1, y1] = util.privateKeyToPublicKeyPairString(privateKeys[20].privateKey.slice(2));
  let [x2, y2] = util.privateKeyToPublicKeyPairString(privateKeys[21].privateKey.slice(2));
  const TEE_PUBLIC_KEYS = [
    { x: x1, y: y1 },
    { x: x2, y: y2 },
  ];
  const TEE_PROXY_IDS = [accounts[22], accounts[23]];
  const TEE_URLS = ["127.0.0.1:1234", "127.0.0.1:1235"];
  const TEE_WALLET_OWNERS = [accounts[103], accounts[104]];
  const TEE_WALLET_AUTHORIZATION_ADDRESSES = [accounts[105], accounts[106]];

  const TEE_SOURCE_ID = web3.utils.utf8ToHex("TEE").padEnd(66, "0");
  const XRP_SOURCE_ID = web3.utils.utf8ToHex("XRP").padEnd(66, "0");
  const FLR_SOURCE_ID = web3.utils.utf8ToHex("FLR").padEnd(66, "0");

  const PROJECT1_ID = web3.utils.keccak256(
    web3.eth.abi.encodeParameters(["string", "address", "uint256"], ["PROJECT", TEE_WALLET_OWNERS[0], 1])
  );
  const WALLET1_ID = web3.utils.keccak256(
    web3.eth.abi.encodeParameters(["string", "address", "uint256"], ["WALLET", TEE_WALLET_OWNERS[0], 1])
  );
  const PROJECT2_ID = web3.utils.keccak256(
    web3.eth.abi.encodeParameters(["string", "address", "uint256"], ["PROJECT", TEE_WALLET_OWNERS[1], 2])
  );
  const WALLET2_ID = web3.utils.keccak256(
    web3.eth.abi.encodeParameters(["string", "address", "uint256"], ["WALLET", TEE_WALLET_OWNERS[1], 2])
  );

  const xrpPublicKeys = [
    "0x03D11FBF992FCC3C7326E323687C234866E400229EA81C73EE4D0DBC1AB5DB22D3",
    "0x03FE12E21F5B2298FFC9A260A95F5031071E9E0778257276E47BB9A0C27CF6C5AD",
    "0x03353D8A544503E0F4D6686379B82D64ED1537CB2961FA1193F57B3E8E17F82980",
  ];
  const evmPublicKeys: string[] = [];

  let addressUpdater: AddressUpdaterInstance;
  let wNat: WNatInstance;
  let pChainStakeMirror: PChainStakeMirrorInstance;
  let governanceVotePower: GovernanceVotePowerInstance;
  let addressBinder: AddressBinderInstance;
  let pChainStakeMirrorVerifierInterface: PChainStakeMirrorVerifierInstance;
  let verifierMock: MockContractInstance;

  let governanceSettings: GovernanceSettingsInstance;
  let entityManager: EntityManagerInstance;
  let voterRegistry: VoterRegistryInstance;
  let flareSystemsCalculator: FlareSystemsCalculatorInstance;
  let flareSystemsManager: FlareSystemsManagerInstance;
  let rewardManager: RewardManagerInstance;
  let submission: SubmissionInstance;
  let relay: RelayInstance;
  let relay2: RelayInstance;
  let cChainStake: CChainStakeInstance;
  let wNatDelegationFee: WNatDelegationFeeInstance;
  let ftsoInflationConfigurations: FtsoInflationConfigurationsInstance;
  let ftsoRewardOffersManager: FtsoRewardOffersManagerInstance;
  let ftsoFeedDecimals: FtsoFeedDecimalsInstance;
  let ftsoFeedPublisher: FtsoFeedPublisherInstance;
  let ftsoFeedIdConverter: FtsoFeedIdConverterInstance;
  let validatorRewardOffersManager: ValidatorRewardOffersManagerInstance;
  let cleanupBlockNumberManager: CleanupBlockNumberManagerInstance;
  let pollingFoundation: PollingFoundationInstance;
  let supplyMock: MockContractInstance;
  let pollingManagementGroup: PollingManagementGroupInstance;
  let flareTeeManager: any;
  let teeRewardOffersManager: TeeRewardOffersManagerInstance;
  let teePaymentsXRP: TeePaymentsInstance;
  let teePaymentsEVM: TeePaymentsInstance;
  let teePaymentsFeeScheduleManager: TeePaymentsFeeScheduleManagerInstance;
  let teePaymentsLimitsManager: TeePaymentsLimitsManagerInstance;
  let teePaymentsRegistry: TeePaymentsRegistryInstance;
  let fdc2Hub: Fdc2HubInstance;
  let fdc2RequestFeeConfigurations: Fdc2RequestFeeConfigurationsInstance;
  let fdc2Verification: Fdc2VerificationInstance;

  const teeGovernanceSigners: string[] = [
    accounts[50],
    accounts[51],
    accounts[52],
    accounts[53],
    accounts[54],
    accounts[55],
  ];
  const teeGovernanceSignersThreshold = 3;

  let initialSigningPolicy: ISigningPolicy;
  let newSigningPolicy: ISigningPolicy;

  const registeredPAddresses: string[] = [];
  const registeredCAddresses: string[] = [];
  let now: BN;
  let nodeIds: string[] = [];
  let weightsGwei: number[] = [];
  let stakeIds: string[] = [];
  let rewardClaim: {
    rewardEpochId: number;
    beneficiary: string;
    amount: number;
    claimType: number;
  };
  let feed: {
    votingRoundId: number;
    id: string;
    value: number;
    turnoutBIPS: number;
    decimals: number;
  };
  const challenges: string[] = [];
  const instructionIds: string[] = [];

  // Direct backup / restore — populated by the machine-path-list creation step and reused by the
  // subsequent directBackup + directRestore steps.
  let machinePathListNonce: string;
  let machinePaths: { sourceTeeIds: string[]; destinationTeeIds: string[] }[];
  let directBackupInstructionId: string;

  [x1, y1] = util.privateKeyToPublicKeyPairString(privateKeys[10].privateKey.slice(2));
  [x2, y2] = util.privateKeyToPublicKeyPairString(privateKeys[11].privateKey.slice(2));
  const adminsPublicKeys1 = [
    { x: x1, y: y1 },
    { x: x2, y: y2 },
  ];
  [x1, y1] = util.privateKeyToPublicKeyPairString(privateKeys[12].privateKey.slice(2));
  [x2, y2] = util.privateKeyToPublicKeyPairString(privateKeys[13].privateKey.slice(2));
  const adminsPublicKeys2 = [
    { x: x1, y: y1 },
    { x: x2, y: y2 },
  ];

  const RANDOM_ROOT = web3.utils.keccak256("root");
  const RANDOM_ROOT2 = web3.utils.keccak256("root2");

  // same as in relay and Flare system manager contracts
  const REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS = 3360; // 3.5 days
  const FIRST_REWARD_EPOCH_START_VOTING_ROUND_ID = 1000;
  const NEW_SIGNING_POLICY_INITIALIZATION_START_SEC = 3600 * 2; // 2 hours
  const RELAY_SELECTOR = web3.utils.sha3("relay()")!.slice(0, 10); // first 4 bytes is function selector

  const MESSAGE_FINALIZATION_WINDOW_IN_REWARD_EPOCHS = 100;
  const GWEI = 1e9;
  const VOTING_EPOCH_DURATION_SEC = 90;
  const REWARD_EPOCH_DURATION_IN_SEC = REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS * VOTING_EPOCH_DURATION_SEC;

  const CLAIM_SETUP_MANAGER = accounts[17];
  const FTSO_REWARD_MANAGER = accounts[18];
  const INFLATION = accounts[19];

  const INITIAL_NUMBER_OF_VOTERS = 100;

  before(async () => {
    const addressUpdatableContracts = [];
    addressUpdater = await AddressUpdater.new(accounts[0]);
    pChainStakeMirror = await PChainStakeMirror.new(accounts[0], accounts[0], addressUpdater.address, 50);
    addressUpdatableContracts.push(pChainStakeMirror.address);

    cChainStake = await CChainStake.new(accounts[0], accounts[0], addressUpdater.address, 0, 100, 1e10, 50);
    addressUpdatableContracts.push(cChainStake.address);

    governanceSettings = await testDeployGovernanceSettings(accounts[0], 3600, [accounts[0]]);
    wNat = await WNat.new(accounts[0], "Wrapped NAT", "WNAT");
    await wNat.switchToProductionMode({ from: accounts[0] });
    const switchToProdModeTime = await time.latest();
    const vpContract = await VPContract.new(wNat.address, false);
    await wNat.setWriteVpContract(vpContract.address);
    await wNat.setReadVpContract(vpContract.address);
    governanceVotePower = await GovernanceVotePower.new(wNat.address, pChainStakeMirror.address, cChainStake.address);
    await wNat.setGovernanceVotePower(governanceVotePower.address);

    await time.increaseTo(switchToProdModeTime.addn(3600)); // 1 hour after switching to production mode
    await executeTimelockedGovernanceCall(wNat, (governance) =>
      wNat.setWriteVpContract(vpContract.address, { from: governance })
    );
    await executeTimelockedGovernanceCall(wNat, (governance) =>
      wNat.setReadVpContract(vpContract.address, { from: governance })
    );
    await executeTimelockedGovernanceCall(wNat, (governance) =>
      wNat.setGovernanceVotePower(governanceVotePower.address, { from: governance })
    );

    addressBinder = await AddressBinder.new();
    pChainStakeMirrorVerifierInterface = await PChainStakeMirrorVerifier.new(
      accounts[5],
      accounts[6],
      10,
      1000,
      5,
      5000
    );
    verifierMock = await MockContract.new();

    // set values
    weightsGwei = [1000, 500, 100, 50];
    nodeIds = [
      "0x0123456789012345678901234567890123456789",
      "0x0123456789012345678901234567890123456788",
      "0x0123456789012345678901234567890123456787",
      "0x0123456789012345678901234567890123456786",
    ];
    stakeIds = [
      web3.utils.keccak256("stake1"),
      web3.utils.keccak256("stake2"),
      web3.utils.keccak256("stake3"),
      web3.utils.keccak256("stake4"),
    ];
    now = await time.latest();

    const initialThreshold = 65500 / 2;
    const initialVoters = accounts.slice(0, INITIAL_NUMBER_OF_VOTERS);
    const initialSigningPolicyVoters = accounts.slice(
      INITIAL_NUMBER_OF_VOTERS,
      INITIAL_NUMBER_OF_VOTERS + INITIAL_NUMBER_OF_VOTERS
    );
    const initialWeights: number[] = Array(100).fill(655);

    entityManager = await EntityManager.new(governanceSettings.address, accounts[0], 4);
    await entityManager.setNodePossessionVerifier(verifierMock.address); // mock verifier

    for (let i = 0; i < INITIAL_NUMBER_OF_VOTERS; i++) {
      await entityManager.proposeSigningPolicyAddress(accounts[INITIAL_NUMBER_OF_VOTERS + i], {
        from: initialVoters[i],
      });
      await entityManager.confirmSigningPolicyAddressRegistration(initialVoters[i], {
        from: accounts[INITIAL_NUMBER_OF_VOTERS + i],
      });
    }

    await time.advanceBlock();

    voterRegistry = await VoterRegistry.new(
      governanceSettings.address,
      accounts[0],
      addressUpdater.address,
      100,
      0,
      (await time.latestBlock()).toNumber() - 1,
      0,
      initialVoters,
      initialWeights
    );
    addressUpdatableContracts.push(voterRegistry.address);
    flareSystemsCalculator = await FlareSystemsCalculator.new(
      governanceSettings.address,
      accounts[0],
      addressUpdater.address,
      2500,
      20 * 60,
      600,
      600
    );
    addressUpdatableContracts.push(flareSystemsCalculator.address);

    initialSigningPolicy = {
      rewardEpochId: 0,
      startVotingRoundId: FIRST_REWARD_EPOCH_START_VOTING_ROUND_ID,
      threshold: initialThreshold,
      seed: web3.utils.keccak256("123"),
      voters: initialSigningPolicyVoters,
      weights: initialWeights,
    };

    const settings = {
      newSigningPolicyInitializationStartSeconds: NEW_SIGNING_POLICY_INITIALIZATION_START_SEC,
      randomAcquisitionMaxDurationSeconds: 8 * 3600,
      randomAcquisitionMaxDurationBlocks: 15000,
      newSigningPolicyMinNumberOfVotingRoundsDelay: 1,
      voterRegistrationMinDurationSeconds: 30 * 60,
      voterRegistrationMinDurationBlocks: 20, // default 900,
      submitUptimeVoteMinDurationSeconds: 10 * 60,
      submitUptimeVoteMinDurationBlocks: 20, // default 300,
      signingPolicyThresholdPPM: 500000,
      signingPolicyMinNumberOfVoters: 2,
      rewardExpiryOffsetSeconds: 90 * 24 * 3600,
    };

    const initialSettings = {
      initialRandomVotePowerBlockSelectionSize: 1,
      initialRewardEpochId: 0,
      initialRewardEpochThreshold: initialThreshold,
    };

    const firstVotingRoundStartTs =
      now.toNumber() - FIRST_REWARD_EPOCH_START_VOTING_ROUND_ID * VOTING_EPOCH_DURATION_SEC;

    flareSystemsManager = await FlareSystemsManager.new(
      governanceSettings.address,
      accounts[0],
      addressUpdater.address,
      accounts[0],
      settings,
      firstVotingRoundStartTs,
      VOTING_EPOCH_DURATION_SEC,
      FIRST_REWARD_EPOCH_START_VOTING_ROUND_ID,
      REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS,
      initialSettings
    );
    addressUpdatableContracts.push(flareSystemsManager.address);

    rewardManager = await RewardManager.new(
      governanceSettings.address,
      accounts[0],
      addressUpdater.address,
      constants.ZERO_ADDRESS,
      REWARD_MANAGER_ID
    );
    addressUpdatableContracts.push(rewardManager.address);

    const relayInitialConfig: RelayInitialConfig = {
      initialRewardEpochId: initialSigningPolicy.rewardEpochId,
      startingVotingRoundIdForInitialRewardEpochId: initialSigningPolicy.startVotingRoundId,
      initialSigningPolicyHash: getSigningPolicyHash(initialSigningPolicy),
      randomNumberProtocolId: FTSO_PROTOCOL_ID,
      firstVotingRoundStartTs: firstVotingRoundStartTs,
      votingEpochDurationSeconds: VOTING_EPOCH_DURATION_SEC,
      firstRewardEpochStartVotingRoundId: FIRST_REWARD_EPOCH_START_VOTING_ROUND_ID,
      rewardEpochDurationInVotingEpochs: REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS,
      thresholdIncreaseBIPS: 12000,
      messageFinalizationWindowInRewardEpochs: MESSAGE_FINALIZATION_WINDOW_IN_REWARD_EPOCHS,
      feeCollectionAddress: constants.ZERO_ADDRESS,
      feeConfigs: [],
    };

    relay = await Relay.new(relayInitialConfig, flareSystemsManager.address, constants.ZERO_ADDRESS);

    const relayInitialConfig2: RelayInitialConfig = {
      initialRewardEpochId: initialSigningPolicy.rewardEpochId,
      startingVotingRoundIdForInitialRewardEpochId: initialSigningPolicy.startVotingRoundId,
      initialSigningPolicyHash: getSigningPolicyHash(initialSigningPolicy),
      randomNumberProtocolId: FTSO_PROTOCOL_ID,
      firstVotingRoundStartTs: firstVotingRoundStartTs,
      votingEpochDurationSeconds: VOTING_EPOCH_DURATION_SEC,
      firstRewardEpochStartVotingRoundId: FIRST_REWARD_EPOCH_START_VOTING_ROUND_ID,
      rewardEpochDurationInVotingEpochs: REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS,
      thresholdIncreaseBIPS: 12000,
      messageFinalizationWindowInRewardEpochs: MESSAGE_FINALIZATION_WINDOW_IN_REWARD_EPOCHS,
      feeCollectionAddress: constants.ZERO_ADDRESS,
      feeConfigs: [],
    };

    relay2 = await Relay.new(relayInitialConfig2, constants.ZERO_ADDRESS, constants.ZERO_ADDRESS);

    submission = await Submission.new(governanceSettings.address, accounts[0], addressUpdater.address, false);
    addressUpdatableContracts.push(submission.address);

    wNatDelegationFee = await WNatDelegationFee.new(addressUpdater.address, 2, 2000);
    addressUpdatableContracts.push(wNatDelegationFee.address);

    ftsoInflationConfigurations = await FtsoInflationConfigurations.new(governanceSettings.address, accounts[0]);

    ftsoRewardOffersManager = await FtsoRewardOffersManager.new(
      governanceSettings.address,
      accounts[0],
      addressUpdater.address,
      100
    );
    addressUpdatableContracts.push(ftsoRewardOffersManager.address);

    ftsoFeedDecimals = await FtsoFeedDecimals.new(
      governanceSettings.address,
      accounts[0],
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

    ftsoFeedPublisher = await FtsoFeedPublisher.new(
      governanceSettings.address,
      accounts[0],
      addressUpdater.address,
      FTSO_PROTOCOL_ID,
      200
    );
    addressUpdatableContracts.push(ftsoFeedPublisher.address);

    ftsoFeedIdConverter = await FtsoFeedIdConverter.new();

    validatorRewardOffersManager = await ValidatorRewardOffersManager.new(
      governanceSettings.address,
      accounts[0],
      addressUpdater.address
    );
    addressUpdatableContracts.push(validatorRewardOffersManager.address);

    cleanupBlockNumberManager = await CleanupBlockNumberManager.new(
      accounts[0],
      addressUpdater.address,
      "FlareSystemsManager"
    );
    addressUpdatableContracts.push(cleanupBlockNumberManager.address);

    pollingFoundation = await PollingFoundation.new(governanceSettings.address, accounts[0], addressUpdater.address, [
      accounts[10],
      accounts[11],
    ]);
    addressUpdatableContracts.push(pollingFoundation.address);
    supplyMock = await MockContract.new();

    pollingManagementGroup = await PollingManagementGroup.new(
      governanceSettings.address,
      accounts[0],
      addressUpdater.address
    );
    addressUpdatableContracts.push(pollingManagementGroup.address);

    // Deploy FlareTeeManager Diamond
    const DAY1_FACET_NAMES = [
      "DiamondGovernanceFacet",
      "DiamondLoupeFacet",
      "ExtensionManagerFacet",
      "ExtensionGovernanceFacet",
      "InstructionsFacet",
      "MachineManagerFacet",
      "VerificationFacet",
      "OperationFeesFacet",
      "OwnerAllowlistFacet",
      "SystemStateVerifierFacet",
      "WalletManagerFacet",
      "WalletKeyManagerFacet",
      "WalletProjectManagerFacet",
      "WalletBackupManagerFacet",
      "VrfFacet",
      "ExternalAddressesFacet",
      "MachinePathManagerFacet",
    ];
    const LATER_FACET_NAMES = ["ReplicationFacet", "ExtensionPausingFacet", "UpgradeManagerFacet", "WalletResumeFacet"];

    const facetCuts = [];
    const usedSelectors = new Set<string>();
    for (const facetName of DAY1_FACET_NAMES) {
      const FacetArtifact = artifacts.require(facetName as any);
      const facetInstance = await FacetArtifact.new();
      const selectors = getSelectors(FacetArtifact.abi).filter((s) => !usedSelectors.has(s));
      selectors.forEach((s) => usedSelectors.add(s));
      facetCuts.push({
        facetAddress: facetInstance.address,
        action: 0,
        functionSelectors: selectors,
      });
    }

    const flareTeeManagerInit = await FlareTeeManagerInit.new();
    const flareTeeManagerInitCalldata = web3.eth.abi.encodeFunctionCall(
      FlareTeeManagerInit.abi.find((item: any) => item.name === "init"),
      [governanceSettings.address, accounts[0], addressUpdater.address, "3600", "10", "600", "1", true]
    );

    const flareTeeManagerDiamond = await FlareTeeManager.new(facetCuts, {
      init: flareTeeManagerInit.address,
      initCalldata: flareTeeManagerInitCalldata,
    });

    // Add later facets
    const laterFacetCuts = [];
    for (const facetName of LATER_FACET_NAMES) {
      const FacetArtifact = artifacts.require(facetName as any);
      const facetInstance = await FacetArtifact.new();
      const selectors = getSelectors(FacetArtifact.abi).filter((s) => !usedSelectors.has(s));
      selectors.forEach((s) => usedSelectors.add(s));
      laterFacetCuts.push({
        facetAddress: facetInstance.address,
        action: 0,
        functionSelectors: selectors,
      });
    }
    const replicationInit = await ReplicationInit.new();
    const replicationInitCalldata = web3.eth.abi.encodeFunctionCall(
      ReplicationInit.abi.find((item: any) => item.name === "init"),
      ["60"]
    );
    const flareTeeManagerDiamondCut = await IDiamondCut.at(flareTeeManagerDiamond.address);
    await flareTeeManagerDiamondCut.diamondCut(laterFacetCuts, replicationInit.address, replicationInitCalldata);

    // Test-only facet: lets us retrofit a non-zero governance hash onto an existing codeHash
    // binding so MachinePathManager flows can be exercised without going through the full TEE
    // node-version upgrade dance.
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const MockTeeGovernanceHashSetterArtifact = artifacts.require("MockTeeGovernanceHashSetter" as any);
    const mockSetterInstance = await MockTeeGovernanceHashSetterArtifact.new();
    const mockSetterSelectors = getSelectors(MockTeeGovernanceHashSetterArtifact.abi).filter(
      (s) => !usedSelectors.has(s)
    );
    mockSetterSelectors.forEach((s) => usedSelectors.add(s));
    await flareTeeManagerDiamondCut.diamondCut(
      [{ facetAddress: mockSetterInstance.address, action: 0, functionSelectors: mockSetterSelectors }],
      constants.ZERO_ADDRESS,
      "0x"
    );

    // Get IIFlareTeeManager view at Diamond address (single interface covering all facets)
    flareTeeManager = await IIFlareTeeManager.at(flareTeeManagerDiamond.address);
    addressUpdatableContracts.push(flareTeeManager.address);

    const teeRewardOffersManagerImpl = await TeeRewardOffersManager.new();
    const teeRewardOffersManagerProxy = await TeeRewardOffersManagerProxy.new(
      governanceSettings.address,
      accounts[0],
      addressUpdater.address,
      100000, // 10%
      teeRewardOffersManagerImpl.address
    );
    teeRewardOffersManager = await TeeRewardOffersManager.at(teeRewardOffersManagerProxy.address);
    addressUpdatableContracts.push(teeRewardOffersManager.address);

    const operationTypes = [];
    const operationCommands = [];
    const operationFees = [];
    for (const teeOperationFee of TEE_OPERATION_FEES) {
      operationTypes.push(web3.utils.utf8ToHex(teeOperationFee.opType).padEnd(66, "0"));
      operationCommands.push(web3.utils.utf8ToHex(teeOperationFee.opCommand).padEnd(66, "0"));
      operationFees.push(teeOperationFee.feeWei);
    }
    await flareTeeManager.setOperationFees(operationTypes, operationCommands, operationFees);

    // Deploy shared fee schedule manager BEFORE TeePayments proxies (so it can be resolved via AddressUpdater)
    const teePaymentsFeeScheduleManagerImpl = await TeePaymentsFeeScheduleManager.new();
    const teePaymentsFeeScheduleManagerProxy = await TeePaymentsFeeScheduleManagerProxy.new(
      governanceSettings.address,
      accounts[0],
      addressUpdater.address,
      teePaymentsFeeScheduleManagerImpl.address
    );
    teePaymentsFeeScheduleManager = await TeePaymentsFeeScheduleManager.at(teePaymentsFeeScheduleManagerProxy.address);
    addressUpdatableContracts.push(teePaymentsFeeScheduleManager.address);

    // Deploy TeePaymentsLimitsManager (code available; not yet registered as system instructions sender in this test)
    const teePaymentsLimitsManagerImpl = await TeePaymentsLimitsManager.new();
    const teePaymentsLimitsManagerProxy = await TeePaymentsLimitsManagerProxy.new(
      governanceSettings.address,
      accounts[0],
      addressUpdater.address,
      teePaymentsLimitsManagerImpl.address
    );
    teePaymentsLimitsManager = await TeePaymentsLimitsManager.at(teePaymentsLimitsManagerProxy.address);
    addressUpdatableContracts.push(teePaymentsLimitsManager.address);

    // Deploy TeePaymentsRegistry (shared source-of-truth for sourceId -> TeePayments)
    const teePaymentsRegistryImpl = await TeePaymentsRegistry.new();
    const teePaymentsRegistryProxy = await TeePaymentsRegistryProxy.new(
      governanceSettings.address,
      accounts[0],
      addressUpdater.address,
      teePaymentsRegistryImpl.address
    );
    teePaymentsRegistry = await TeePaymentsRegistry.at(teePaymentsRegistryProxy.address);
    addressUpdatableContracts.push(teePaymentsRegistry.address);

    const teePaymentsImpl: TeePaymentsInstance = await TeePayments.new();
    let teePaymentsProxy = await TeePaymentsProxy.new(
      governanceSettings.address,
      accounts[0],
      addressUpdater.address,
      1,
      0,
      web3.utils.utf8ToHex("F_XRP").padEnd(66, "0"),
      web3.utils.utf8ToHex("XRP").padEnd(66, "0"),
      teePaymentsImpl.address
    );
    teePaymentsXRP = await TeePayments.at(teePaymentsProxy.address);
    addressUpdatableContracts.push(teePaymentsXRP.address);

    teePaymentsProxy = await TeePaymentsProxy.new(
      governanceSettings.address,
      accounts[0],
      addressUpdater.address,
      1,
      0,
      web3.utils.utf8ToHex("F_EVM").padEnd(66, "0"),
      web3.utils.utf8ToHex("EVM").padEnd(66, "0"),
      teePaymentsImpl.address
    );
    teePaymentsEVM = await TeePayments.at(teePaymentsProxy.address);
    addressUpdatableContracts.push(teePaymentsEVM.address);

    const fdc2HubImpl: Fdc2HubInstance = await Fdc2Hub.new();
    const fdc2HubProxy = await Fdc2HubProxy.new(
      governanceSettings.address,
      accounts[0],
      addressUpdater.address,
      3000,
      1,
      fdc2HubImpl.address
    );
    fdc2Hub = await Fdc2Hub.at(fdc2HubProxy.address);
    addressUpdatableContracts.push(fdc2Hub.address);

    const fdc2RequestFeeConfigurationsImpl: Fdc2RequestFeeConfigurationsInstance =
      await Fdc2RequestFeeConfigurations.new();
    const fdc2RequestFeeConfigurationsProxy = await Fdc2RequestFeeConfigurationsProxy.new(
      governanceSettings.address,
      accounts[0],
      addressUpdater.address,
      fdc2RequestFeeConfigurationsImpl.address
    );
    fdc2RequestFeeConfigurations = await Fdc2RequestFeeConfigurations.at(fdc2RequestFeeConfigurationsProxy.address);

    const fdc2VerificationImpl: Fdc2VerificationInstance = await Fdc2Verification.new();
    const fdc2VerificationProxy = await Fdc2VerificationProxy.new(
      governanceSettings.address,
      accounts[0],
      addressUpdater.address,
      fdc2VerificationImpl.address
    );
    fdc2Verification = await Fdc2Verification.at(fdc2VerificationProxy.address);
    addressUpdatableContracts.push(fdc2Verification.address);
    // Set the FDC2 request fee configurations
    const fdc2RequestFees = [
      { attestationType: "TeeAvailabilityCheck", source: "TEE" },
      { attestationType: "PMWMultisigAccountConfigured", source: "XRP" },
      { attestationType: "PMWPaymentStatus", source: "XRP" },
      { attestationType: "PMWMultisigAccountConfigured", source: "FLR" },
      { attestationType: "PMWPaymentStatus", source: "FLR" },
    ];
    for (const fdtcRequestFee of fdc2RequestFees) {
      await fdc2RequestFeeConfigurations.setTypeAndSourceFee(
        web3.utils.utf8ToHex(fdtcRequestFee.attestationType).padEnd(66, "0"),
        web3.utils.utf8ToHex(fdtcRequestFee.source).padEnd(66, "0"),
        "1"
      );
    }

    await flareSystemsCalculator.enablePChainStakeMirror();
    await rewardManager.enablePChainStakeMirror();

    // update contract addresses
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
        Contracts.SUPPLY,
        Contracts.RELAY,
        Contracts.REWARD_MANAGER,
        Contracts.CLAIM_SETUP_MANAGER,
        Contracts.FTSO_REWARD_MANAGER,
        Contracts.FTSO_INFLATION_CONFIGURATIONS,
        Contracts.FTSO_FEED_DECIMALS,
        Contracts.FLARE_TEE_MANAGER,
        Contracts.FDC2_HUB,
        Contracts.FDC2_VERIFICATION,
        Contracts.FDC2_REQUEST_FEE_CONFIGURATIONS,
        Contracts.TEE_REWARD_OFFERS_MANAGER,
        Contracts.TEE_PAYMENTS_FEE_SCHEDULE_MANAGER,
        Contracts.TEE_PAYMENTS_LIMITS_MANAGER,
        Contracts.TEE_PAYMENTS_REGISTRY,
      ],
      [
        addressUpdater.address,
        INFLATION,
        addressBinder.address,
        governanceVotePower.address,
        cleanupBlockNumberManager.address,
        verifierMock.address,
        flareSystemsManager.address,
        entityManager.address,
        flareSystemsCalculator.address,
        wNatDelegationFee.address,
        voterRegistry.address,
        pChainStakeMirror.address,
        wNat.address,
        submission.address,
        supplyMock.address,
        relay.address,
        rewardManager.address,
        CLAIM_SETUP_MANAGER,
        FTSO_REWARD_MANAGER,
        ftsoInflationConfigurations.address,
        ftsoFeedDecimals.address,
        flareTeeManager.address,
        fdc2Hub.address,
        fdc2Verification.address,
        fdc2RequestFeeConfigurations.address,
        teeRewardOffersManager.address,
        teePaymentsFeeScheduleManager.address,
        teePaymentsLimitsManager.address,
        teePaymentsRegistry.address,
      ],
      addressUpdatableContracts,
      { from: accounts[0] }
    );
    // Register sourceId -> TeePayments bindings in the registry
    await teePaymentsRegistry.registerSources([
      { sourceId: XRP_SOURCE_ID, teePayments: teePaymentsXRP.address },
      { sourceId: FLR_SOURCE_ID, teePayments: teePaymentsEVM.address },
    ]);
    // set system supported platforms
    await flareTeeManager.addSystemSupportedPlatforms(
      TEE_PLATFORMS.map((platform) => web3.utils.utf8ToHex(platform).padEnd(66, "0"))
    );
    // set system supported key types and algos
    await flareTeeManager.addSystemSupportedKeyTypesAndSigningAlgos(TEE_KEY_CONFIGURATIONS, TEE_SIGNING_ALGOS);
    // set system extension supported key types
    await flareTeeManager.addSupportedKeyTypes(0, TEE_KEY_CONFIGURATIONS);
    // register system instructions senders
    await flareTeeManager.registerSystemInstructionsSenders([
      teePaymentsXRP.address,
      teePaymentsEVM.address,
      teePaymentsLimitsManager.address,
      fdc2Hub.address,
    ]);
    // configure initial per-sourceId fee schedule config
    await teePaymentsFeeScheduleManager.setFeeScheduleConfigs([
      { maxDelaySeconds: 600, maxSchedules: 10, sourceId: XRP_SOURCE_ID },
      { maxDelaySeconds: 60, maxSchedules: 10, sourceId: FLR_SOURCE_ID },
    ]);
    await flareTeeManager.allowAllTeeMachineOwners(0);
    await flareTeeManager.allowAllTeeWalletProjectOwners(0);
    // set reward offers manager list
    await rewardManager.setRewardOffersManagerList([
      ftsoRewardOffersManager.address,
      validatorRewardOffersManager.address,
      teeRewardOffersManager.address,
      flareTeeManager.address,
      fdc2Hub.address,
    ]);

    // set initial reward data
    await rewardManager.setInitialRewardData();

    // send some inflation funds
    const inflationFunds = web3.utils.toWei("200000");
    await ftsoRewardOffersManager.setDailyAuthorizedInflation(inflationFunds, { from: INFLATION });
    await ftsoRewardOffersManager.receiveInflation({ value: inflationFunds, from: INFLATION });

    await validatorRewardOffersManager.setDailyAuthorizedInflation(inflationFunds, { from: INFLATION });
    await validatorRewardOffersManager.receiveInflation({ value: inflationFunds, from: INFLATION });

    await teeRewardOffersManager.setDailyAuthorizedInflation(inflationFunds, { from: INFLATION });
    await teeRewardOffersManager.receiveInflation({ value: inflationFunds, from: INFLATION });

    // set reward epoch switchover trigger contracts
    await flareSystemsManager.setRewardEpochSwitchoverTriggerContracts([
      ftsoRewardOffersManager.address,
      validatorRewardOffersManager.address,
      teeRewardOffersManager.address,
    ]);

    // set ftso configurations
    await ftsoInflationConfigurations.addFtsoConfiguration({
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
    });
    await ftsoInflationConfigurations.addFtsoConfiguration({
      feedIds: FtsoConfigurations.encodeFeedIds([
        { category: 1, name: "BTC/USD" },
        { category: 1, name: "LTC/USD" },
      ]),
      inflationShare: 100,
      minRewardedTurnoutBIPS: 5000,
      mode: 0,
      primaryBandRewardSharePPM: 600000,
      secondaryBandWidthPPMs: FtsoConfigurations.encodeSecondaryBandWidthPPMs([200, 1000]),
    });

    // set polling management group maintainer and parameters
    await pollingManagementGroup.setMaintainer(accounts[10]);
    await pollingManagementGroup.setParameters(3600, 3600, 5000, 5000, 100, 20, 20, 2, 4, 2, 7, { from: accounts[10] });

    // offer some rewards
    await ftsoRewardOffersManager.offerRewards(
      1,
      [
        {
          amount: 25000000,
          feedId: FtsoConfigurations.encodeFeedId({ category: 1, name: "BTC/USD" }),
          minRewardedTurnoutBIPS: 5000,
          primaryBandRewardSharePPM: 450000,
          secondaryBandWidthPPM: 50000,
          claimBackAddress: constants.ZERO_ADDRESS,
        },
      ],
      { value: "25000000" }
    );

    // enable claims
    await rewardManager.enableClaims();

    // activate contracts
    await pChainStakeMirror.activate();
    await cChainStake.activate();
    await rewardManager.activate();
  });

  it("Should register addresses", async () => {
    for (let i = 0; i < 4; i++) {
      const prvKey = privateKeys[i].privateKey.slice(2);
      const prvkeyBuffer = Buffer.from(prvKey, "hex");
      const [x, y] = util.privateKeyToPublicKeyPair(prvkeyBuffer);
      const pubKey = "0x" + util.encodePublicKey(x, y, false).toString("hex");
      const pAddr = "0x" + util.publicKeyToAvalancheAddress(x, y).toString("hex");
      const cAddr = toChecksumAddress("0x" + util.publicKeyToEthereumAddress(x, y).toString("hex"));
      await addressBinder.registerAddresses(pubKey, pAddr, cAddr);
      registeredPAddresses.push(pAddr);
      registeredCAddresses.push(cAddr);
    }
  });

  it("Should verify stakes", async () => {
    for (let i = 0; i < 4; i++) {
      const data = await setMockStakingData(
        verifierMock,
        pChainStakeMirrorVerifierInterface,
        stakeIds[i],
        0,
        registeredPAddresses[i],
        nodeIds[i],
        now.subn(10),
        now.addn(10000),
        weightsGwei[i]
      );
      await pChainStakeMirror.mirrorStake(data, []);
    }
  });

  it("Should register and confirm delegation addresses", async () => {
    for (let i = 0; i < 4; i++) {
      await entityManager.proposeDelegationAddress(accounts[50 + i], { from: registeredCAddresses[i] });
      await entityManager.confirmDelegationAddressRegistration(registeredCAddresses[i], { from: accounts[50 + i] });
    }
  });

  it("Should wrap some funds", async () => {
    for (let i = 0; i < 4; i++) {
      await wNat.deposit({ value: toBN(weightsGwei[i] * GWEI), from: accounts[50 + i] });
    }
  });

  it("Should register nodes", async () => {
    for (let i = 0; i < 4; i++) {
      await entityManager.registerNodeId(nodeIds[i], "0x", "0x", { from: registeredCAddresses[i] });
    }
  });

  it("Should register and confirm data provider addresses", async () => {
    for (let i = 0; i < 4; i++) {
      await entityManager.proposeSubmitAddress(accounts[10 + i], { from: registeredCAddresses[i] });
      await entityManager.confirmSubmitAddressRegistration(registeredCAddresses[i], { from: accounts[10 + i] });
    }
  });

  it("Should register and confirm deposit signatures addresses", async () => {
    for (let i = 0; i < 4; i++) {
      await entityManager.proposeSubmitSignaturesAddress(accounts[20 + i], { from: registeredCAddresses[i] });
      await entityManager.confirmSubmitSignaturesAddressRegistration(registeredCAddresses[i], {
        from: accounts[20 + i],
      });
    }
  });

  it("Should register and confirm signing policy addresses", async () => {
    for (let i = 0; i < 4; i++) {
      await entityManager.proposeSigningPolicyAddress(accounts[30 + i], { from: registeredCAddresses[i] });
      await entityManager.confirmSigningPolicyAddressRegistration(registeredCAddresses[i], { from: accounts[30 + i] });
    }
  });

  it("Should start random acquisition", async () => {
    await time.increaseTo(now.addn(REWARD_EPOCH_DURATION_IN_SEC - NEW_SIGNING_POLICY_INITIALIZATION_START_SEC)); // 2 hours before new reward epoch
    expectEvent(await flareSystemsManager.daemonize(), "RandomAcquisitionStarted", { rewardEpochId: toBN(1) });
  });

  it("Should get good random", async () => {
    const votingRoundId =
      FIRST_REWARD_EPOCH_START_VOTING_ROUND_ID +
      REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS -
      NEW_SIGNING_POLICY_INITIALIZATION_START_SEC / VOTING_EPOCH_DURATION_SEC +
      1;
    const quality = true;

    const messageData: IProtocolMessageMerkleRoot = {
      protocolId: FTSO_PROTOCOL_ID,
      votingRoundId: votingRoundId,
      isSecureRandom: quality,
      merkleRoot: RANDOM_ROOT,
    };
    const messageHash = ProtocolMessageMerkleRoot.hash(messageData);
    const signatures = await generateSignatures(
      privateKeys.slice(INITIAL_NUMBER_OF_VOTERS, INITIAL_NUMBER_OF_VOTERS + 51).map((x) => x.privateKey),
      messageHash,
      51
    );

    const relayMessage = {
      signingPolicy: initialSigningPolicy,
      signatures,
      protocolMessageMerkleRoot: messageData,
    };

    const fullData = RelayMessage.encode(relayMessage);

    const tx = await web3.eth.sendTransaction({
      from: accounts[0],
      to: relay.address,
      data: RELAY_SELECTOR + fullData.slice(2),
    });
    console.log(tx.gasUsed);
    expect((await submission.getCurrentRandomWithQuality())[1]).to.be.true;
  });

  it("Should select vote power block", async () => {
    await time.increase(1); // new random is later than random acquisition start
    expectEvent(await flareSystemsManager.daemonize(), "VotePowerBlockSelected", { rewardEpochId: toBN(1) });
  });

  it("Should register a few voters", async () => {
    const rewardEpochId = 1;
    for (let i = 0; i < 4; i++) {
      const chainId = await web3.eth.getChainId();
      const hash = web3.utils.keccak256(
        web3.eth.abi.encodeParameters(
          ["uint256", "uint32", "address"],
          [chainId, rewardEpochId, registeredCAddresses[i]]
        )
      );

      const signature = web3.eth.accounts.sign(hash, privateKeys[30 + i].privateKey);
      expectEvent(await voterRegistry.registerVoter(registeredCAddresses[i], signature), "VoterRegistered", {
        voter: registeredCAddresses[i],
        rewardEpochId: toBN(1),
        signingPolicyAddress: accounts[30 + i],
        submitAddress: accounts[10 + i],
        submitSignaturesAddress: accounts[20 + i],
      });
    }
  });

  it("Should initialise new signing policy", async () => {
    for (let i = 0; i < 20; i++) {
      await time.advanceBlock(); // create required number of blocks to proceed
    }
    await time.increaseTo(now.addn(REWARD_EPOCH_DURATION_IN_SEC - 3600)); // at least 30 minutes from the vote power block selection
    const startVotingRoundId = FIRST_REWARD_EPOCH_START_VOTING_ROUND_ID + REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS;
    newSigningPolicy = {
      rewardEpochId: 1,
      startVotingRoundId: startVotingRoundId,
      threshold: Math.floor(65535 / 2),
      seed: web3.utils.keccak256(RANDOM_ROOT),
      voters: accounts.slice(30, 34),
      weights: [34664, 20660, 6334, 3875],
    };

    const receipt = await flareSystemsManager.daemonize();
    await expectEvent.inTransaction(receipt.tx, relay, "SigningPolicyInitialized", {
      rewardEpochId: toBN(1),
      startVotingRoundId: toBN(startVotingRoundId),
      voters: newSigningPolicy.voters,
      seed: toBN(web3.utils.keccak256(RANDOM_ROOT)),
      threshold: toBN(32767),
      weights: newSigningPolicy.weights.map((x) => toBN(x)),
    });
    const result = await relay.lastInitializedRewardEpochData();
    const _lastInitializedRewardEpoch = result[0];
    const _startingVotingRoundIdForLastInitializedRewardEpoch = result[1];
    expect(_lastInitializedRewardEpoch.toString()).to.equal("1");
    expect(_startingVotingRoundIdForLastInitializedRewardEpoch.toString()).to.equal(startVotingRoundId.toString());
    expect(await relay.toSigningPolicyHash(1)).to.be.equal(getSigningPolicyHash(newSigningPolicy));
  });

  it("Should sign new signing policy and relay it", async () => {
    const rewardEpochId = 1;
    // const newSigningPolicyHash = getSigningPolicyHash(newSigningPolicy)
    const newSigningPolicyHash = await relay.toSigningPolicyHash(rewardEpochId);

    let signatures = (51).toString(16).padStart(4, "0");
    for (let i = 0; i < 50; i++) {
      const signature = web3.eth.accounts.sign(
        newSigningPolicyHash,
        privateKeys[INITIAL_NUMBER_OF_VOTERS + i].privateKey
      );
      expectEvent(
        await flareSystemsManager.signNewSigningPolicy(rewardEpochId, newSigningPolicyHash, signature),
        "SigningPolicySigned",
        {
          rewardEpochId: toBN(rewardEpochId),
          signingPolicyAddress: accounts[INITIAL_NUMBER_OF_VOTERS + i],
          voter: accounts[i],
          thresholdReached: false,
        }
      );
      signatures += ECDSASignatureWithIndex.encode({
        v: parseInt(signature.v.slice(2), 16),
        r: signature.r,
        s: signature.s,
        index: i,
      }).slice(2);
    }
    const signature = web3.eth.accounts.sign(
      newSigningPolicyHash,
      privateKeys[INITIAL_NUMBER_OF_VOTERS + 50].privateKey
    );
    expectEvent(
      await flareSystemsManager.signNewSigningPolicy(rewardEpochId, newSigningPolicyHash, signature),
      "SigningPolicySigned",
      {
        rewardEpochId: toBN(rewardEpochId),
        signingPolicyAddress: accounts[INITIAL_NUMBER_OF_VOTERS + 50],
        voter: accounts[50],
        thresholdReached: true,
      }
    );
    signatures += ECDSASignatureWithIndex.encode({
      v: parseInt(signature.v.slice(2), 16),
      r: signature.r,
      s: signature.s,
      index: 50,
    }).slice(2);

    const signingPolicyEncoded = SigningPolicy.encode(initialSigningPolicy).slice(2);
    const newSigningPolicyEncoded = SigningPolicy.encode(newSigningPolicy).slice(2);
    const fullData = RELAY_SELECTOR + signingPolicyEncoded + "00" + newSigningPolicyEncoded + signatures;

    let result = await relay2.lastInitializedRewardEpochData();
    let _lastInitializedRewardEpoch = result[0];
    expect(_lastInitializedRewardEpoch.toString()).to.equal("0");

    const txReceipt = await web3.eth.sendTransaction({
      from: accounts[0],
      to: relay2.address,
      data: fullData,
    });

    await expectEvent.inTransaction(txReceipt.transactionHash, relay2, "SigningPolicyRelayed", {
      rewardEpochId: toBN(rewardEpochId),
    });
    result = await relay2.lastInitializedRewardEpochData();
    _lastInitializedRewardEpoch = result[0];
    expect(_lastInitializedRewardEpoch.toString()).to.equal(rewardEpochId.toString());
  });

  it("Should start new reward epoch, initiate new voting round and offer rewards for the next reward epoch", async () => {
    await time.increaseTo(now.addn(REWARD_EPOCH_DURATION_IN_SEC));
    expect((await flareSystemsManager.getCurrentRewardEpochId()).toNumber()).to.be.equal(0);
    const tx = await flareSystemsManager.daemonize();
    expectEvent(tx, "RewardEpochStarted");
    await expectEvent.inTransaction(tx.tx, submission, "NewVotingRoundInitiated");
    await expectEvent.inTransaction(tx.tx, ftsoRewardOffersManager, "InflationRewardsOffered", {
      rewardEpochId: toBN(2),
      amount: toBN("133333333333333333333333"),
    });
    await expectEvent.inTransaction(tx.tx, ftsoRewardOffersManager, "InflationRewardsOffered", {
      rewardEpochId: toBN(2),
      amount: toBN("66666666666666666666667"),
    });
    await expectEvent.inTransaction(tx.tx, validatorRewardOffersManager, "InflationRewardsOffered", {
      rewardEpochId: toBN(2),
      amount: toBN("200000000000000000000000"),
    });
    expect((await flareSystemsManager.getCurrentRewardEpochId()).toNumber()).to.be.equal(1);
  });

  it("Should commit", async () => {
    for (let i = 0; i < 4; i++) {
      expect(await submission.submit1.call({ from: accounts[10 + i] })).to.be.true;
      await submission.submit1({ from: accounts[10 + i] });
      expect(await submission.submit1.call({ from: accounts[10 + i] })).to.be.false;
    }
  });

  it("Should initiate new voting round", async () => {
    await time.increaseTo(now.addn(REWARD_EPOCH_DURATION_IN_SEC + VOTING_EPOCH_DURATION_SEC));
    const tx = await flareSystemsManager.daemonize();
    await expectEvent.inTransaction(tx.tx, submission, "NewVotingRoundInitiated");
  });

  it("Should reveal", async () => {
    for (let i = 0; i < 4; i++) {
      expect(await submission.submit2.call({ from: accounts[10 + i] })).to.be.true;
    }
  });

  it("Should deposit signature", async () => {
    for (let i = 0; i < 4; i++) {
      expect(await submission.submitSignatures.call({ from: accounts[20 + i] })).to.be.true;
    }
  });

  it("Should finalise and relay", async () => {
    const votingRoundId = FIRST_REWARD_EPOCH_START_VOTING_ROUND_ID + REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS;
    const quality = true;

    feed = {
      votingRoundId: votingRoundId,
      id: FtsoConfigurations.encodeFeedId({ category: 1, name: "BTC/USD" }),
      value: 12345,
      turnoutBIPS: 6500,
      decimals: 1,
    };

    const root = web3.utils.keccak256(
      web3.eth.abi.encodeParameters(
        ["uint32", "bytes21", "int32", "uint16", "int8"],
        [feed.votingRoundId, feed.id, feed.value, feed.turnoutBIPS, feed.decimals]
      )
    );

    const messageData: IProtocolMessageMerkleRoot = {
      protocolId: FTSO_PROTOCOL_ID,
      votingRoundId: votingRoundId,
      isSecureRandom: quality,
      merkleRoot: root,
    };
    const messageHash = ProtocolMessageMerkleRoot.hash(messageData);

    const signatures = await generateSignatures(
      privateKeys.slice(30, 34).map((x) => x.privateKey),
      messageHash,
      4
    );

    const relayMessage = {
      signingPolicy: newSigningPolicy,
      signatures,
      protocolMessageMerkleRoot: messageData,
    };

    const fullData = RelayMessage.encode(relayMessage);

    await web3.eth.sendTransaction({
      from: accounts[0],
      to: relay.address,
      data: RELAY_SELECTOR + fullData.slice(2),
    });
    expect(await relay.merkleRoots(FTSO_PROTOCOL_ID, votingRoundId)).to.be.equal(root);
    expect((await submission.getCurrentRandom()).eq(toBN(web3.utils.keccak256(root)))).to.be.true;
    expect((await submission.getCurrentRandomWithQuality())[1]).to.be.true;

    expect(await relay2.isFinalized(FTSO_PROTOCOL_ID, votingRoundId)).to.be.false;
    await web3.eth.sendTransaction({
      from: accounts[0],
      to: relay2.address,
      data: RELAY_SELECTOR + fullData.slice(2),
    });
    expect(await relay2.isFinalized(FTSO_PROTOCOL_ID, votingRoundId)).to.be.true;
  });

  it("Should publish ftso feed", async () => {
    const feedWithProof = { body: feed, merkleProof: [] };
    const tx = await ftsoFeedPublisher.publish([feedWithProof]);
    expectEvent(tx, "FtsoFeedPublished", {
      votingRoundId: toBN(feed.votingRoundId),
      id: feed.id.padEnd(66, "0"),
      value: toBN(feed.value),
      turnoutBIPS: toBN(feed.turnoutBIPS),
      decimals: toBN(feed.decimals),
    });
    const feedReturn = await ftsoFeedPublisher.getCurrentFeed(feed.id);
    expect(feedReturn.votingRoundId).to.be.equal(feed.votingRoundId.toString());
    expect(feedReturn.id).to.be.equal(feed.id);
    expect(feedReturn.value).to.be.equal(feed.value.toString());
    expect(feedReturn.turnoutBIPS).to.be.equal(feed.turnoutBIPS.toString());
    expect(feedReturn.decimals).to.be.equal(feed.decimals.toString());
  });

  it("Should convert feed id", async () => {
    const category = 1;
    const name = "BTC/USD";
    const encodedFeedId = FtsoConfigurations.encodeFeedId({ category, name });
    const feedId = FtsoConfigurations.decodeFeedIds(encodedFeedId)[0];
    const encodedFeedId2 = await ftsoFeedIdConverter.getFeedId(category, name);
    expect(encodedFeedId2).to.be.equal(encodedFeedId);
    const feedId2 = await ftsoFeedIdConverter.getFeedCategoryAndName(encodedFeedId);
    expect(category).to.be.equal(feedId.category);
    expect(name).to.be.equal(feedId.name);
    expect(category).to.be.equal(feedId2[0]);
    expect(name).to.be.equal(feedId2[1]);
  });

  it("Should commit 2", async () => {
    for (let i = 0; i < 4; i++) {
      expect(await submission.submit1.call({ from: accounts[10 + i] })).to.be.true;
    }
  });

  it("Should start random acquisition for reward epoch 2", async () => {
    await time.increaseTo(now.addn(2 * REWARD_EPOCH_DURATION_IN_SEC - NEW_SIGNING_POLICY_INITIALIZATION_START_SEC)); // 2 hours before new reward epoch
    expectEvent(await flareSystemsManager.daemonize(), "RandomAcquisitionStarted", { rewardEpochId: toBN(2) });
  });

  it("Should get good random for reward epoch 2", async () => {
    const votingRoundId =
      FIRST_REWARD_EPOCH_START_VOTING_ROUND_ID +
      2 * REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS -
      NEW_SIGNING_POLICY_INITIALIZATION_START_SEC / VOTING_EPOCH_DURATION_SEC +
      1;
    const quality = true;

    const messageData: IProtocolMessageMerkleRoot = {
      protocolId: FTSO_PROTOCOL_ID,
      votingRoundId: votingRoundId,
      isSecureRandom: quality,
      merkleRoot: RANDOM_ROOT2,
    };
    const messageHash = ProtocolMessageMerkleRoot.hash(messageData);

    const signatures = await generateSignatures(
      privateKeys.slice(30, 34).map((x) => x.privateKey),
      messageHash,
      4
    );

    const relayMessage = {
      signingPolicy: newSigningPolicy,
      signatures,
      protocolMessageMerkleRoot: messageData,
    };

    const fullData = RelayMessage.encode(relayMessage);

    await web3.eth.sendTransaction({
      from: accounts[0],
      to: relay.address,
      data: RELAY_SELECTOR + fullData.slice(2),
    });
    expect((await submission.getCurrentRandomWithQuality())[1]).to.be.true;
  });

  it("Should select vote power block for reward epoch 2", async () => {
    expectEvent(await flareSystemsManager.daemonize(), "VotePowerBlockSelected", { rewardEpochId: toBN(2) });
  });

  it("Should register a few voters for reward epoch 2", async () => {
    const rewardEpochId = 2;
    for (let i = 0; i < 4; i++) {
      const chainId = await web3.eth.getChainId();
      const hash = web3.utils.keccak256(
        web3.eth.abi.encodeParameters(
          ["uint256", "uint32", "address"],
          [chainId, rewardEpochId, registeredCAddresses[i]]
        )
      );

      const signature = web3.eth.accounts.sign(hash, privateKeys[30 + i].privateKey);
      expectEvent(await voterRegistry.registerVoter(registeredCAddresses[i], signature), "VoterRegistered", {
        voter: registeredCAddresses[i],
        rewardEpochId: toBN(2),
        signingPolicyAddress: accounts[30 + i],
        submitAddress: accounts[10 + i],
        submitSignaturesAddress: accounts[20 + i],
      });
    }
  });

  it("Should initialise new signing policy for reward epoch 2", async () => {
    for (let i = 0; i < 20; i++) {
      await time.advanceBlock(); // create required number of blocks to proceed
    }
    await time.increaseTo(now.addn(2 * REWARD_EPOCH_DURATION_IN_SEC - 3600)); // at least 30 minutes from the vote power block selection
    const votingRoundId = FIRST_REWARD_EPOCH_START_VOTING_ROUND_ID + 2 * REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS;
    const receipt = await flareSystemsManager.daemonize();
    await expectEvent.inTransaction(receipt.tx, relay, "SigningPolicyInitialized", {
      rewardEpochId: toBN(2),
      startVotingRoundId: toBN(votingRoundId),
      voters: accounts.slice(30, 34),
      seed: toBN(web3.utils.keccak256(RANDOM_ROOT2)),
      threshold: toBN(32767),
      weights: [toBN(34664), toBN(20660), toBN(6334), toBN(3875)],
    });
    // tempSigningPolicyEncoded = SigningPolicy.encode({
    //     rewardEpochId: 2,
    //     startVotingRoundId: votingRoundId,
    //     voters: accounts.slice(30, 34),
    //     seed: web3.utils.keccak256(RANDOM_ROOT2),
    //     threshold: 32767,
    //     weights: [34664, 20660, 6334, 3875]
    // })
  });

  it("Should sign new signing policy for reward epoch 2", async () => {
    const rewardEpochId = 2;
    // const newSigningPolicyHash = SigningPolicy.hashEncoded(tempSigningPolicyEncoded)
    const newSigningPolicyHash = await relay.toSigningPolicyHash(rewardEpochId);

    const signature = web3.eth.accounts.sign(newSigningPolicyHash, privateKeys[31].privateKey);
    expectEvent(
      await flareSystemsManager.signNewSigningPolicy(rewardEpochId, newSigningPolicyHash, signature),
      "SigningPolicySigned",
      {
        rewardEpochId: toBN(rewardEpochId),
        signingPolicyAddress: accounts[31],
        voter: registeredCAddresses[1],
        thresholdReached: false,
      }
    );
    const signature2 = web3.eth.accounts.sign(newSigningPolicyHash, privateKeys[30].privateKey);
    expectEvent(
      await flareSystemsManager.signNewSigningPolicy(rewardEpochId, newSigningPolicyHash, signature2),
      "SigningPolicySigned",
      {
        rewardEpochId: toBN(rewardEpochId),
        signingPolicyAddress: accounts[30],
        voter: registeredCAddresses[0],
        thresholdReached: true,
      }
    );
    const signature3 = web3.eth.accounts.sign(newSigningPolicyHash, privateKeys[32].privateKey);
    await expectRevert(
      flareSystemsManager.signNewSigningPolicy(rewardEpochId, newSigningPolicyHash, signature3),
      "new signing policy already signed"
    );
  });

  it("Should start new reward epoch (2) and initiate new voting round", async () => {
    await time.increaseTo(now.addn(2 * REWARD_EPOCH_DURATION_IN_SEC));
    expect((await flareSystemsManager.getCurrentRewardEpochId()).toNumber()).to.be.equal(1);
    const tx = await flareSystemsManager.daemonize();
    expectEvent(tx, "RewardEpochStarted");
    await expectEvent.inTransaction(tx.tx, submission, "NewVotingRoundInitiated");
    expect((await flareSystemsManager.getCurrentRewardEpochId()).toNumber()).to.be.equal(2);
  });

  it("Should submit some uptime votes for reward epoch 1", async () => {
    const rewardEpochId = 1;
    for (let i = 0; i < 4; i++) {
      const hash = web3.utils.keccak256(
        web3.eth.abi.encodeParameters(["uint24", "bytes20[]"], [rewardEpochId, nodeIds])
      );

      const signature = web3.eth.accounts.sign(hash, privateKeys[30 + i].privateKey);
      expectEvent(
        await flareSystemsManager.submitUptimeVote(rewardEpochId, nodeIds, signature),
        "UptimeVoteSubmitted",
        {
          voter: registeredCAddresses[i],
          rewardEpochId: toBN(1),
          signingPolicyAddress: accounts[30 + i],
          nodeIds: nodeIds,
        }
      );
    }
  });

  it("Should sign uptime vote for reward epoch 1", async () => {
    for (let i = 0; i < 20; i++) {
      await time.advanceBlock(); // create required number of blocks to proceed
    }
    await time.increaseTo(now.addn(2 * REWARD_EPOCH_DURATION_IN_SEC + 3600)); // at least 10 minutes from the new reward epoch start
    const tx = await flareSystemsManager.daemonize();
    expectEvent(tx, "SignUptimeVoteEnabled", { rewardEpochId: toBN(1) });
    const rewardEpochId = 1;
    const uptimeVoteHash = web3.utils.keccak256("uptime");
    const hash = web3.utils.keccak256(
      web3.eth.abi.encodeParameters(["uint24", "bytes32"], [rewardEpochId, uptimeVoteHash])
    );

    const signature = web3.eth.accounts.sign(hash, privateKeys[31].privateKey);
    expectEvent(
      await flareSystemsManager.signUptimeVote(rewardEpochId, uptimeVoteHash, signature),
      "UptimeVoteSigned",
      {
        rewardEpochId: toBN(1),
        signingPolicyAddress: accounts[31],
        voter: registeredCAddresses[1],
        thresholdReached: false,
      }
    );
    const signature2 = web3.eth.accounts.sign(hash, privateKeys[30].privateKey);
    expectEvent(
      await flareSystemsManager.signUptimeVote(rewardEpochId, uptimeVoteHash, signature2),
      "UptimeVoteSigned",
      {
        rewardEpochId: toBN(1),
        signingPolicyAddress: accounts[30],
        voter: registeredCAddresses[0],
        thresholdReached: true,
      }
    );
    const signature3 = web3.eth.accounts.sign(hash, privateKeys[32].privateKey);
    await expectRevert(
      flareSystemsManager.signUptimeVote(rewardEpochId, uptimeVoteHash, signature3),
      "uptime vote hash already signed"
    );
    expect(await flareSystemsManager.uptimeVoteHash(rewardEpochId)).to.be.equal(uptimeVoteHash);
  });

  it("Should sign rewards for reward epoch 1", async () => {
    const rewardEpochId = 1;
    const noOfWeightBasedClaims = [{ rewardManagerId: REWARD_MANAGER_ID, noOfWeightBasedClaims: 1 }];

    rewardClaim = {
      rewardEpochId: 1,
      beneficiary: accounts[50],
      amount: 500,
      claimType: 2, //RewardsV2Interface.ClaimType.WNAT
    };

    const rewardsVoteHash = web3.utils.keccak256(
      web3.eth.abi.encodeParameters(
        ["uint24", "bytes20", "uint120", "uint8"],
        [rewardClaim.rewardEpochId, rewardClaim.beneficiary, rewardClaim.amount, rewardClaim.claimType]
      )
    );
    const noOfWeightBasedClaimsHash = web3.utils.keccak256(
      web3.eth.abi.encodeParameters(
        ["tuple(uint256,uint256)[]"],
        [noOfWeightBasedClaims.map((value) => [value.rewardManagerId, value.noOfWeightBasedClaims])]
      )
    );
    const hash = web3.utils.keccak256(
      web3.eth.abi.encodeParameters(
        ["uint24", "bytes32", "bytes32"],
        [rewardEpochId, noOfWeightBasedClaimsHash, rewardsVoteHash]
      )
    );

    const signature = web3.eth.accounts.sign(hash, privateKeys[31].privateKey);
    expectEvent(
      await flareSystemsManager.signRewards(rewardEpochId, noOfWeightBasedClaims, rewardsVoteHash, signature),
      "RewardsSigned",
      {
        rewardEpochId: toBN(1),
        signingPolicyAddress: accounts[31],
        voter: registeredCAddresses[1],
        thresholdReached: false,
      }
    );
    const signature2 = web3.eth.accounts.sign(hash, privateKeys[30].privateKey);
    expectEvent(
      await flareSystemsManager.signRewards(rewardEpochId, noOfWeightBasedClaims, rewardsVoteHash, signature2),
      "RewardsSigned",
      {
        rewardEpochId: toBN(1),
        signingPolicyAddress: accounts[30],
        voter: registeredCAddresses[0],
        thresholdReached: true,
      }
    );
    const signature3 = web3.eth.accounts.sign(hash, privateKeys[32].privateKey);
    await expectRevert(
      flareSystemsManager.signRewards(rewardEpochId, noOfWeightBasedClaims, rewardsVoteHash, signature3),
      "rewards hash already signed"
    );
    expect(await flareSystemsManager.rewardsHash(rewardEpochId)).to.be.equal(rewardsVoteHash);
    expect((await flareSystemsManager.noOfWeightBasedClaims(rewardEpochId, REWARD_MANAGER_ID)).toNumber()).to.be.equal(
      noOfWeightBasedClaims[0].noOfWeightBasedClaims
    );
  });

  it("Should claim the reward for reward epoch 1", async () => {
    const balanceBefore = await wNat.balanceOf(accounts[200]);
    const tx = await rewardManager.claim(
      accounts[50],
      accounts[200],
      1,
      true,
      [{ body: rewardClaim, merkleProof: [] }],
      { from: accounts[50] }
    );
    const balanceAfter = await wNat.balanceOf(accounts[200]);

    expectEvent(tx, "RewardClaimed", {
      beneficiary: accounts[50],
      rewardOwner: accounts[50],
      recipient: accounts[200],
      rewardEpochId: toBN(1),
      claimType: toBN(2),
      amount: toBN(500),
    });
    expect(balanceAfter.sub(balanceBefore).toNumber()).to.be.equal(500);
  });

  it("Should create new PollingFoundation proposal and vote on it", async () => {
    type ProposalCreatedEvent = { name: "ProposalCreated"; args: { proposalId: string } };

    const tx = (await pollingFoundation.methods[
      "propose(string,(bool,uint256,uint256,uint256,uint256,uint256))"
    ].sendTransaction(
      "Proposal",
      {
        accept: false,
        votingStartTs: (await time.latest()).addn(3600).toNumber(),
        votingPeriodSeconds: 7200,
        vpBlockPeriodSeconds: 259200,
        thresholdConditionBIPS: 7500,
        majorityConditionBIPS: 5000,
      },
      { from: accounts[10] }
    )) as unknown as Truffle.TransactionResponse<ProposalCreatedEvent>;
    const event = findRequiredEvent(tx, "ProposalCreated");
    const eventArgs = event.args;
    const proposalId: string = eventArgs.proposalId.toString();

    // advance one hour to the voting period
    await time.increase(3600);

    // voting
    await pollingFoundation.castVote(proposalId, 0, { from: registeredCAddresses[0] });
    await pollingFoundation.castVote(proposalId, 1, { from: registeredCAddresses[1] });
    await pollingFoundation.castVote(proposalId, 0, { from: registeredCAddresses[2] });

    // advance to the end of the voting period
    await time.increase(7200);

    const state = await pollingFoundation.state(proposalId);
    expect(state.toString()).to.equals("2");
  });

  it("Should create new PollingManagementGroup proposal and vote on it", async () => {
    // change management group members
    await pollingManagementGroup.changeManagementGroupMembers(registeredCAddresses, [], { from: accounts[10] });
    const proposalId = toBN(1);
    const tx = await pollingManagementGroup.propose("Proposal", { value: toBN(100), from: registeredCAddresses[0] });
    expectEvent(tx, "ManagementGroupProposalCreated", { proposalId: proposalId, proposer: registeredCAddresses[0] });

    // advance one hour to the voting period
    await time.increase(3600);

    // voting
    await pollingManagementGroup.castVote(proposalId, 1, { from: registeredCAddresses[0] });
    await pollingManagementGroup.castVote(proposalId, 1, { from: registeredCAddresses[1] });
    await pollingManagementGroup.castVote(proposalId, 0, { from: registeredCAddresses[2] });

    // advance to the end of the voting period
    await time.increase(3600);

    const state = await pollingManagementGroup.state(proposalId);
    expect(state.toString()).to.equals("4");
  });

  it("Should set new TEE governance", async () => {
    await flareTeeManager.setNewTeeGovernance(0, teeGovernanceSigners, teeGovernanceSignersThreshold);

    const governanceHash = web3.utils.keccak256(
      web3.eth.abi.encodeParameters(["address[]", "uint256"], [teeGovernanceSigners, teeGovernanceSignersThreshold])
    );

    expect(await flareTeeManager.getLatestTeeGovernanceHash(0)).to.be.equal(governanceHash);
    const governance = await flareTeeManager.getTeeGovernance(0, governanceHash);
    expect(governance[0]).to.be.deep.equal(teeGovernanceSigners);
    expect(governance[1].toNumber()).to.be.equal(teeGovernanceSignersThreshold);
    expect(await flareTeeManager.getTeeGovernanceThreshold(0, governanceHash)).to.be.equal(
      teeGovernanceSignersThreshold
    );
  });

  it("Should add new TEE node version", async () => {
    const supportedPlatforms = TEE_PLATFORMS.map((platform) => web3.utils.utf8ToHex(platform).padEnd(66, "0"));
    await flareTeeManager.addTeeVersion(0, "v0.1.0", TEE_CODE_HASH, supportedPlatforms, constants.ZERO_BYTES32);

    const codeHashInfo = await flareTeeManager.getCodeHashInfo(0, TEE_CODE_HASH);
    expect(codeHashInfo[0]).to.be.equal(constants.ZERO_BYTES32);
    expect(codeHashInfo[1]).to.be.equal("v0.1.0");
    expect(codeHashInfo[2]).to.be.deep.equal(supportedPlatforms);
  });

  it("Should register new TEE machines", async () => {
    const teeAttestationStruct = getStruct("TeeVerificationStructs", "teeAttestationStruct");

    assert(
      TEE_URLS.length === TEE_IDS.length &&
        TEE_URLS.length === TEE_PUBLIC_KEYS.length &&
        TEE_URLS.length === TEE_PROXY_IDS.length &&
        TEE_URLS.length === TEE_PLATFORMS.length &&
        TEE_URLS.length === TEE_OWNERS.length,
      "Arrays must be of the same length"
    );
    for (let i = 0; i < TEE_URLS.length; i++) {
      const teeMachineData = {
        extensionId: 0,
        initialOwner: TEE_OWNERS[i],
        codeHash: TEE_CODE_HASH,
        platform: web3.utils.utf8ToHex(TEE_PLATFORMS[i]).padEnd(66, "0"),
        publicKey: TEE_PUBLIC_KEYS[i],
      };

      const msg = getHash(getStruct("TeeMachineStructs", "teeMachineDataStruct"), teeMachineData);
      const signature = await ECDSASignature.signMessageHash(msg, privateKeys[20 + (i % 2)].privateKey);

      const tx = await flareTeeManager.register(
        teeMachineData,
        signature,
        TEE_PROXY_IDS[i],
        TEE_URLS[i],
        constants.ZERO_ADDRESS,
        { value: "2", from: TEE_OWNERS[i] }
      );
      expectEvent(tx, "TeeMachineRegistered", {
        teeId: TEE_IDS[i],
        teeProxyId: TEE_PROXY_IDS[i],
        extensionId: "0",
        owner: TEE_OWNERS[i],
        url: TEE_URLS[i],
        codeHash: TEE_CODE_HASH,
        platform: web3.utils.utf8ToHex(TEE_PLATFORMS[i]).padEnd(66, "0"),
      });

      const event2 = requiredEventArgsFrom(tx, flareTeeManager, "TeeAttestationRequested") as any;
      expect(event2.teeId).to.be.equal(TEE_IDS[i]);
      challenges.push(event2.challenge);

      const message = {
        teeMachine: {
          teeId: TEE_IDS[i],
          initialTeeId: TEE_IDS[i],
          url: TEE_URLS[i],
          codeHash: TEE_CODE_HASH,
          platform: web3.utils.utf8ToHex(TEE_PLATFORMS[i]).padEnd(66, "0"),
        },
        challenge: event2.challenge,
      };
      const event3 = requiredEventArgsFrom(tx, flareTeeManager, "TeeInstructionsSent") as any;
      expect(event3.rewardEpochId).to.be.equal("2");
      expect(event3.opType).to.be.equal(web3.utils.utf8ToHex("F_REG").padEnd(66, "0"));
      expect(event3.opCommand).to.be.equal(web3.utils.utf8ToHex("TEE_ATTESTATION").padEnd(66, "0"));
      expect(event3.message).to.be.equal(web3.eth.abi.encodeParameter(teeAttestationStruct, message));
      instructionIds.push(event3.instructionId);
    }
  });

  it("Should trigger TEE machine availability check", async () => {
    assert(
      TEE_URLS.length === challenges.length &&
        TEE_URLS.length === instructionIds.length &&
        TEE_URLS.length === TEE_IDS.length &&
        TEE_URLS.length === TEE_PROXY_IDS.length,
      "Arrays must be of the same length"
    );

    const fdc2AttestationRequestStruct = getStruct("Fdc2Structs", "fdc2AttestationRequestStruct");
    const availabilityCheckRequestBodyStruct = getStruct("Fdc2Structs", "availabilityCheckRequestBodyStruct");

    for (let i = 0; i < TEE_IDS.length; i++) {
      const requestBody = {
        teeId: TEE_IDS[i],
        teeProxyId: TEE_PROXY_IDS[i],
        url: TEE_URLS[i],
        challenge: challenges[i],
        instructionId: instructionIds[i],
      };
      const message = {
        header: {
          attestationType: web3.utils.utf8ToHex("TeeAvailabilityCheck").padEnd(66, "0"),
          sourceId: TEE_SOURCE_ID,
          thresholdBIPS: "0",
          proofOwner: constants.ZERO_ADDRESS,
        },
        requestBody: web3.eth.abi.encodeParameter(availabilityCheckRequestBodyStruct, requestBody),
      };
      const tx = await flareTeeManager.requestAvailabilityCheckAttestation(
        TEE_IDS[i],
        instructionIds[i],
        TEE_IDS[i],
        constants.ZERO_ADDRESS,
        constants.ZERO_ADDRESS,
        { value: "2" }
      );
      const event = requiredEventArgsFrom(tx, flareTeeManager, "TeeInstructionsSent") as any;
      expect(event.rewardEpochId).to.be.equal("2");
      expect(event.opType).to.be.equal(web3.utils.utf8ToHex("F_FDC2").padEnd(66, "0"));
      expect(event.opCommand).to.be.equal(web3.utils.utf8ToHex("PROVE").padEnd(66, "0"));
      expect(event.message).to.be.equal(web3.eth.abi.encodeParameter(fdc2AttestationRequestStruct, message));
    }
  });

  it("Should put new TEE machines in production", async () => {
    const rewardEpochId = 2;

    assert(
      TEE_URLS.length === challenges.length &&
        TEE_URLS.length === instructionIds.length &&
        TEE_URLS.length === TEE_IDS.length &&
        TEE_URLS.length === TEE_PROXY_IDS.length &&
        TEE_URLS.length === TEE_PLATFORMS.length &&
        TEE_URLS.length === TEE_OWNERS.length,
      "Arrays must be of the same length"
    );
    for (let i = 0; i < TEE_URLS.length; i++) {
      const teeState = {
        systemState: "0x",
        systemStateVersion: constants.ZERO_BYTES32,
        state: "0x",
        stateVersion: constants.ZERO_BYTES32,
      };
      const proof = {
        signatures: {
          signingPolicySignatures: "",
          teeSignatures: [],
          cosignerSignatures: [],
        },
        header: {
          attestationType: web3.utils.utf8ToHex("TeeAvailabilityCheck").padEnd(66, "0"),
          sourceId: TEE_SOURCE_ID,
          thresholdBIPS: "0",
          proofOwner: constants.ZERO_ADDRESS,
          timestamp: (await time.latest()).toString(),
          cosigners: [],
          cosignersThreshold: "0",
        },
        requestBody: {
          teeId: TEE_IDS[i],
          teeProxyId: TEE_PROXY_IDS[i],
          url: TEE_URLS[i],
          challenge: challenges[i],
          instructionId: instructionIds[i],
        },
        responseBody: {
          status: "0",
          teeTimestamp: (await time.latest()).toString(),
          initialTeeId: TEE_IDS[i],
          codeHash: TEE_CODE_HASH,
          platform: web3.utils.utf8ToHex(TEE_PLATFORMS[i]).padEnd(66, "0"),
          initialSigningPolicyId: rewardEpochId,
          lastSigningPolicyId: rewardEpochId,
          state: teeState,
        },
      };

      // sign message
      const headerHash = getHash(getStruct("Fdc2Structs", "fdc2ResponseHeaderStruct"), proof.header);
      const requestBodyHash = getHash(
        getStruct("Fdc2Structs", "availabilityCheckRequestBodyStruct"),
        proof.requestBody
      );
      const responseBodyHash = getHash(
        getStruct("Fdc2Structs", "availabilityCheckResponseBodyStruct"),
        proof.responseBody
      );
      const message = getFdc2Message(headerHash, requestBodyHash, responseBodyHash);
      proof.signatures.signingPolicySignatures = await getNewSigningPolicySignatures(message);

      await time.increase(1);
      const tx = await flareTeeManager.toProduction(proof, { from: TEE_OWNERS[i] });
      expectEvent(tx, "TeeMachineStatusChanged", {
        teeId: TEE_IDS[i],
        newStatus: "1", // TEE_MACHINE_STATUS.PRODUCTION
      });
    }
  });

  it("Should create new TEE projects", async () => {
    assert(
      TEE_WALLET_AUTHORIZATION_ADDRESSES.length >= 2 &&
        TEE_WALLET_OWNERS.length >= 2 &&
        TEE_KEY_CONFIGURATIONS.length >= 2 &&
        TEE_SIGNING_ALGOS.length >= 2 &&
        TEE_SIGNING_ALGOS[0].length >= 1 &&
        TEE_SIGNING_ALGOS[1].length >= 1,
      "At least 2 owners, submit addresses, key configurations and signing algos are required"
    );

    let tx = await flareTeeManager.createProject(0, TEE_KEY_CONFIGURATIONS[0], TEE_SIGNING_ALGOS[0][0], {
      from: TEE_WALLET_OWNERS[0],
    });
    expectEvent(tx, "ProjectCreated", {
      extensionId: "0",
      projectId: PROJECT1_ID,
      keyType: TEE_KEY_CONFIGURATIONS[0],
      signingAlgo: TEE_SIGNING_ALGOS[0][0],
      owner: TEE_WALLET_OWNERS[0],
    });

    tx = await flareTeeManager.createProject(0, TEE_KEY_CONFIGURATIONS[1], TEE_SIGNING_ALGOS[1][0], {
      from: TEE_WALLET_OWNERS[1],
    });
    expectEvent(tx, "ProjectCreated", {
      extensionId: "0",
      projectId: PROJECT2_ID,
      keyType: TEE_KEY_CONFIGURATIONS[1],
      signingAlgo: TEE_SIGNING_ALGOS[1][0],
      owner: TEE_WALLET_OWNERS[1],
    });
  });

  it("Should create TEE wallets and initialize them", async () => {
    // create wallet for project 1
    let tx = await flareTeeManager.createWallet(PROJECT1_ID, { from: TEE_WALLET_OWNERS[0] });
    expectEvent(tx, "WalletCreated", {
      walletId: WALLET1_ID,
      projectId: PROJECT1_ID,
    });

    tx = await flareTeeManager.setAdmins(WALLET1_ID, adminsPublicKeys1, 2, { from: TEE_WALLET_OWNERS[0] });
    expectEvent(tx, "WalletAdminsSet", {
      walletId: WALLET1_ID,
      adminsThreshold: "2",
    });
    expectEvent(await flareTeeManager.confirmAdmin(WALLET1_ID, { from: accounts[10] }), "WalletAdminConfirmed", {
      walletId: WALLET1_ID,
      admin: accounts[10],
    });
    expectEvent(await flareTeeManager.confirmAdmin(WALLET1_ID, { from: accounts[11] }), "WalletAdminConfirmed", {
      walletId: WALLET1_ID,
      admin: accounts[11],
    });
    tx = await flareTeeManager.closeWalletInitialization(WALLET1_ID, { from: TEE_WALLET_OWNERS[0] });
    expectEvent(tx, "WalletInitialized", {
      walletId: WALLET1_ID,
    });

    // create wallet for project 2
    tx = await flareTeeManager.createWallet(PROJECT2_ID, { from: TEE_WALLET_OWNERS[1] });
    expectEvent(tx, "WalletCreated", {
      walletId: WALLET2_ID,
      projectId: PROJECT2_ID,
    });

    tx = await flareTeeManager.setAdmins(WALLET2_ID, adminsPublicKeys2, 1, { from: TEE_WALLET_OWNERS[1] });
    expectEvent(tx, "WalletAdminsSet", {
      walletId: WALLET2_ID,
      adminsThreshold: "1",
    });
    expectEvent(await flareTeeManager.confirmAdmin(WALLET2_ID, { from: accounts[12] }), "WalletAdminConfirmed", {
      walletId: WALLET2_ID,
      admin: accounts[12],
    });
    expectEvent(await flareTeeManager.confirmAdmin(WALLET2_ID, { from: accounts[13] }), "WalletAdminConfirmed", {
      walletId: WALLET2_ID,
      admin: accounts[13],
    });
    tx = await flareTeeManager.setCosigners(WALLET2_ID, [accounts[14]], 1, { from: TEE_WALLET_OWNERS[1] });
    expectEvent(tx, "WalletCosignersSet", {
      walletId: WALLET2_ID,
      cosignersThreshold: "1",
    });
    expectEvent(await flareTeeManager.confirmCosigner(WALLET2_ID, { from: accounts[14] }), "WalletCosignerConfirmed", {
      walletId: WALLET2_ID,
      cosigner: accounts[14],
    });
    tx = await flareTeeManager.closeWalletInitialization(WALLET2_ID, { from: TEE_WALLET_OWNERS[1] });
    expectEvent(tx, "WalletInitialized", {
      walletId: WALLET2_ID,
    });
  });

  it("Should set wallet multisig threshold", async () => {
    let tx = await flareTeeManager.setMultisigThreshold(WALLET1_ID, 2, { from: TEE_WALLET_OWNERS[0] });
    expectEvent(tx, "WalletMultisigThresholdSet", {
      walletId: WALLET1_ID,
      multisigThreshold: "2",
    });
    tx = await flareTeeManager.setMultisigThreshold(WALLET2_ID, 1, { from: TEE_WALLET_OWNERS[1] });
    expectEvent(tx, "WalletMultisigThresholdSet", {
      walletId: WALLET2_ID,
      multisigThreshold: "1",
    });
  });

  it("Should add keys to TEE wallets and confirm them", async () => {
    const keyGenerateStruct = getStruct("TeeWalletStructs", "keyGenerateStruct");
    for (let i = 0; i < xrpPublicKeys.length; i++) {
      let tx = await flareTeeManager.addKey(TEE_IDS[i % 2], WALLET1_ID, constants.ZERO_ADDRESS, {
        value: "10",
        from: TEE_WALLET_OWNERS[0],
      });
      const message = {
        teeId: TEE_IDS[i % 2],
        walletId: WALLET1_ID,
        keyId: i.toString(),
        keyType: TEE_KEY_CONFIGURATIONS[0],
        signingAlgo: TEE_SIGNING_ALGOS[0][0],
        configConstants: {
          adminsPublicKeys: adminsPublicKeys1,
          adminsThreshold: "2",
          cosigners: [],
          cosignersThreshold: "0",
          opTypeConstants: "0x",
        },
      };
      const event = requiredEventArgsFrom(tx, flareTeeManager, "TeeInstructionsSent") as any;
      expect(event.rewardEpochId).to.be.equal("2");
      expect(event.opType).to.be.equal(web3.utils.utf8ToHex("F_WALLET").padEnd(66, "0"));
      expect(event.opCommand).to.be.equal(web3.utils.utf8ToHex("KEY_GENERATE").padEnd(66, "0"));
      expect(event.message).to.be.equal(web3.eth.abi.encodeParameter(keyGenerateStruct, message));

      const proof = {
        teeId: TEE_IDS[i % 2],
        walletId: WALLET1_ID,
        keyId: i.toString(),
        keyType: TEE_KEY_CONFIGURATIONS[0],
        signingAlgo: TEE_SIGNING_ALGOS[0][0],
        publicKey: xrpPublicKeys[i],
        nonce: "0",
        restored: false,
        configConstants: {
          adminsPublicKeys: adminsPublicKeys1,
          adminsThreshold: "2",
          cosigners: [],
          cosignersThreshold: "0",
        },
        settingsVersion: constants.ZERO_BYTES32,
        settings: "0x",
      };

      const msg = getHash(getStruct("TeeWalletStructs", "keyExistenceStruct"), proof);
      const signature = await ECDSASignature.signMessageHash(msg, privateKeys[20 + (i % 2)].privateKey);

      await time.increase(1);
      tx = await flareTeeManager.confirmKey(proof, signature, { from: TEE_WALLET_OWNERS[0] });
      expectEvent(tx, "WalletKeyConfirmed", {
        teeId: TEE_IDS[i % 2],
        walletId: WALLET1_ID,
        keyId: i.toString(),
        publicKey: xrpPublicKeys[i],
      });
    }

    for (let i = 0; i < 4; i++) {
      let tx = await flareTeeManager.addKey(TEE_IDS[i % 2], WALLET2_ID, constants.ZERO_ADDRESS, {
        value: "10",
        from: TEE_WALLET_OWNERS[1],
      });
      const message = {
        teeId: TEE_IDS[i % 2],
        walletId: WALLET2_ID,
        keyId: i.toString(),
        keyType: TEE_KEY_CONFIGURATIONS[1],
        signingAlgo: TEE_SIGNING_ALGOS[1][0],
        configConstants: {
          adminsPublicKeys: adminsPublicKeys2,
          adminsThreshold: "1",
          cosigners: [accounts[14]],
          cosignersThreshold: "1",
          opTypeConstants: "0x",
        },
      };
      const event = requiredEventArgsFrom(tx, flareTeeManager, "TeeInstructionsSent") as any;
      expect(event.rewardEpochId).to.be.equal("2");
      expect(event.opType).to.be.equal(web3.utils.utf8ToHex("F_WALLET").padEnd(66, "0"));
      expect(event.opCommand).to.be.equal(web3.utils.utf8ToHex("KEY_GENERATE").padEnd(66, "0"));
      expect(event.message).to.be.equal(web3.eth.abi.encodeParameter(keyGenerateStruct, message));

      const prvKey = privateKeys[50 + i].privateKey.slice(2);
      const prvkeyBuffer = Buffer.from(prvKey, "hex");
      const [x, y] = util.privateKeyToPublicKeyPair(prvkeyBuffer);
      const publicKey = "0x" + util.encodePublicKey(x, y, false).toString("hex");
      evmPublicKeys.push(publicKey);

      const proof = {
        teeId: TEE_IDS[i % 2],
        walletId: WALLET2_ID,
        keyId: i.toString(),
        keyType: TEE_KEY_CONFIGURATIONS[1],
        signingAlgo: TEE_SIGNING_ALGOS[1][0],
        publicKey: publicKey,
        nonce: "0",
        restored: false,
        configConstants: {
          adminsPublicKeys: adminsPublicKeys2,
          adminsThreshold: "1",
          cosigners: [accounts[14]],
          cosignersThreshold: "1",
        },
        settingsVersion: constants.ZERO_BYTES32,
        settings: "0x",
      };

      const msg = getHash(getStruct("TeeWalletStructs", "keyExistenceStruct"), proof);
      const signature = await ECDSASignature.signMessageHash(msg, privateKeys[20 + (i % 2)].privateKey);

      await time.increase(1);
      tx = await flareTeeManager.confirmKey(proof, signature, { from: TEE_WALLET_OWNERS[1] });
      expectEvent(tx, "WalletKeyConfirmed", {
        teeId: TEE_IDS[i % 2],
        walletId: WALLET2_ID,
        keyId: i.toString(),
        publicKey: publicKey,
      });
    }
  });

  it("Should enable TEE wallets", async () => {
    let tx = await flareTeeManager.enableWallet(WALLET1_ID, { from: TEE_WALLET_OWNERS[0] });
    expectEvent(tx, "WalletEnabled", {
      walletId: WALLET1_ID,
    });

    tx = await flareTeeManager.enableWallet(WALLET2_ID, { from: TEE_WALLET_OWNERS[1] });
    expectEvent(tx, "WalletEnabled", {
      walletId: WALLET2_ID,
    });
  });

  // ===========================================================================================
  // Direct backup / restore — exercise the MachinePathManager-gated key migration flow.
  // Key 0 of WALLET1 currently lives on TEE_IDS[0]. We authorize a path TEE_IDS[0] → TEE_IDS[1]
  // via a governance-signed list, then trigger directBackup and directRestore for that key.
  // ===========================================================================================

  it("Should create + sign a machine-path list authorizing TEE0 → TEE1", async () => {
    // Retrofit a non-zero governance hash onto TEE_CODE_HASH for the MachinePathManager flow.
    // The earlier `addTeeVersion(... ZERO_BYTES32)` call leaves the binding zero, which is fine
    // for the legacy TEE production / availability-check path but means `getTeeGovernanceHash`
    // returns zero — making no signer recognisable to MachinePathManager. Use the test-only
    // mock setter (added during diamond construction above) to wire the actual governance hash in.
    const teeGovernanceHash = await flareTeeManager.getLatestTeeGovernanceHash(0);
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const mockSetter = (await artifacts.require("MockTeeGovernanceHashSetter" as any).at(
      flareTeeManager.address
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
    )) as any;
    // eslint-disable-next-line @typescript-eslint/no-unsafe-call, @typescript-eslint/no-unsafe-member-access
    await mockSetter.mockSetTeeGovernanceHash(0, TEE_CODE_HASH, teeGovernanceHash);

    let tx = await flareTeeManager.createNewMachinePathList(0);
    expectEvent(tx, "MachinePathListStarted", { extensionId: "0", nonce: "1" });
    machinePathListNonce = "1";

    machinePaths = [
      {
        sourceTeeIds: [TEE_IDS[0]],
        destinationTeeIds: [TEE_IDS[1]],
      },
    ];
    tx = await flareTeeManager.addMachinePaths(0, machinePathListNonce, machinePaths);
    expectEvent(tx, "MachinePathsAdded", { extensionId: "0", nonce: machinePathListNonce });

    tx = await flareTeeManager.finalizeMachinePathList(0, machinePathListNonce);
    expectEvent(tx, "MachinePathListFinalized", { extensionId: "0", nonce: machinePathListNonce });

    // Read the canonical messageHash from the contract — the value off-chain signers must sign.
    // (Computing it independently in JS is brittle because Solidity's `abi.encode` of string
    // literals + struct arrays has subtle interactions with web3 / ethers ABI coders.)
    const messageHash = await flareTeeManager.getMachinePathListMessageHash(0, machinePathListNonce);

    // teeGovernanceSignersThreshold = 3. Sign with the first 3 of the 6 governance signers.
    for (let i = 0; i < teeGovernanceSignersThreshold; i++) {
      const sig = await ECDSASignature.signMessageHash(messageHash, privateKeys[50 + i].privateKey);
      tx = await flareTeeManager.signMachinePathList(0, machinePathListNonce, sig);
    }
    expectEvent(tx, "MachinePathListSigned", { extensionId: "0", nonce: machinePathListNonce });

    const activeNonce = await flareTeeManager.getActiveMachinePathListNonce(0);
    expect(activeNonce.toString()).to.equal(machinePathListNonce);
  });

  it("Should trigger direct backup of key 0 from TEE0 to TEE1", async () => {
    const keyDirectBackupStruct = getStruct("TeeWalletStructs", "keyDirectBackupStruct");

    // Pre-condition: destination's per-key nonce is 0 and TEE1 does not currently hold the key.
    const nonceInfoBefore = await flareTeeManager.getKeyNonce(TEE_IDS[1], WALLET1_ID, 0);
    expect(nonceInfoBefore[0].toString()).to.equal("0");
    expect(nonceInfoBefore[1]).to.equal(false);

    const tx = await flareTeeManager.directBackup(TEE_IDS[0], TEE_IDS[1], WALLET1_ID, 0, constants.ZERO_ADDRESS, {
      value: "10",
      from: TEE_WALLET_OWNERS[0],
    });

    const event = requiredEventArgsFrom(tx, flareTeeManager, "DirectBackupTriggered") as any;
    expect(event.sourceTeeId).to.equal(TEE_IDS[0]);
    expect(event.destinationTeeId).to.equal(TEE_IDS[1]);
    expect(event.walletId).to.equal(WALLET1_ID);
    expect(event.keyId.toString()).to.equal("0");
    expect(event.destinationNonce.toString()).to.equal("1");
    directBackupInstructionId = event.backupInstructionId;

    // Verify the on-chain instruction payload is the KeyDirectBackup struct, op = KEY_DIRECT_BACKUP.
    const ev = requiredEventArgsFrom(tx, flareTeeManager, "TeeInstructionsSent") as any;
    expect(ev.opType).to.equal(web3.utils.utf8ToHex("F_WALLET").padEnd(66, "0"));
    expect(ev.opCommand).to.equal(web3.utils.utf8ToHex("KEY_DIRECT_BACKUP").padEnd(66, "0"));

    const expectedPayload = {
      sourceTeeId: TEE_IDS[0],
      walletId: WALLET1_ID,
      keyId: "0",
      destinationTeePublicKey: { x: TEE_PUBLIC_KEYS[1].x, y: TEE_PUBLIC_KEYS[1].y },
      destinationNonce: "1",
      machinePathListNonce: machinePathListNonce,
    };
    expect(ev.message).to.equal(web3.eth.abi.encodeParameter(keyDirectBackupStruct, expectedPayload));

    // directBackup must NOT mutate the destination's per-key nonce.
    const nonceInfoAfter = await flareTeeManager.getKeyNonce(TEE_IDS[1], WALLET1_ID, 0);
    expect(nonceInfoAfter[0].toString()).to.equal("0");
    expect(nonceInfoAfter[1]).to.equal(false);
  });

  it("Should trigger direct restore of key 0 onto TEE1", async () => {
    const backupId = {
      teeId: TEE_IDS[0],
      walletId: WALLET1_ID,
      keyId: "0",
      keyType: TEE_KEY_CONFIGURATIONS[0],
      signingAlgo: TEE_SIGNING_ALGOS[0][0],
      publicKey: xrpPublicKeys[0],
      rewardEpochId: "2",
      randomNonce: web3.utils.keccak256("rn"),
    };

    const tx = await flareTeeManager.directRestore(
      TEE_IDS[1],
      backupId,
      directBackupInstructionId,
      constants.ZERO_ADDRESS,
      { value: "10", from: TEE_WALLET_OWNERS[0] }
    );
    expectEvent(tx, "DirectRestoreTriggered", {
      destinationTeeId: TEE_IDS[1],
      walletId: WALLET1_ID,
      keyId: "0",
      destinationNonce: "1",
      backupInstructionId: directBackupInstructionId,
    });

    const ev = requiredEventArgsFrom(tx, flareTeeManager, "TeeInstructionsSent") as any;
    expect(ev.opType).to.equal(web3.utils.utf8ToHex("F_WALLET").padEnd(66, "0"));
    expect(ev.opCommand).to.equal(web3.utils.utf8ToHex("KEY_DIRECT_RESTORE").padEnd(66, "0"));

    // directRestore must bump the destination's per-key nonce by exactly +1.
    const nonceInfoAfter = await flareTeeManager.getKeyNonce(TEE_IDS[1], WALLET1_ID, 0);
    expect(nonceInfoAfter[0].toString()).to.equal("1");
  });

  it("Should trigger PMW Multisig account configured attestations", async () => {
    const fdc2AttestationRequestStruct = getStruct("Fdc2Structs", "fdc2AttestationRequestStruct");
    const pmwMultisigAccountConfiguredRequestBodyStruct = getStruct(
      "Fdc2Structs",
      "pmwMultisigAccountConfiguredRequestBodyStruct"
    );

    const requestBody = {
      accountAddress: "rUzM4ovjNkjSZ2jVJfZQ9321ikeNM6ASzh",
      publicKeys: xrpPublicKeys,
      threshold: "2",
    };
    const message = {
      header: {
        attestationType: web3.utils.utf8ToHex("PMWMultisigAccountConfigured").padEnd(66, "0"),
        sourceId: XRP_SOURCE_ID,
        thresholdBIPS: "0",
        proofOwner: constants.ZERO_ADDRESS,
      },
      requestBody: web3.eth.abi.encodeParameter(pmwMultisigAccountConfiguredRequestBodyStruct, requestBody),
    };
    const tx = await flareTeeManager.requestPMWMultisigAccountConfiguredAttestation(
      WALLET1_ID,
      XRP_SOURCE_ID,
      "rUzM4ovjNkjSZ2jVJfZQ9321ikeNM6ASzh",
      TEE_IDS[0],
      constants.ZERO_ADDRESS,
      constants.ZERO_ADDRESS,
      { value: "2" }
    );
    const event = requiredEventArgsFrom(tx, flareTeeManager, "TeeInstructionsSent") as any;
    expect(event.rewardEpochId).to.be.equal("2");
    expect(event.opType).to.be.equal(web3.utils.utf8ToHex("F_FDC2").padEnd(66, "0"));
    expect(event.opCommand).to.be.equal(web3.utils.utf8ToHex("PROVE").padEnd(66, "0"));
    expect(event.message).to.be.equal(web3.eth.abi.encodeParameter(fdc2AttestationRequestStruct, message));

    const requestBody2 = {
      accountAddress: accounts[200],
      publicKeys: evmPublicKeys,
      threshold: "1",
    };
    const message2 = {
      header: {
        attestationType: web3.utils.utf8ToHex("PMWMultisigAccountConfigured").padEnd(66, "0"),
        sourceId: FLR_SOURCE_ID,
        thresholdBIPS: "0",
        proofOwner: constants.ZERO_ADDRESS,
      },
      requestBody: web3.eth.abi.encodeParameter(pmwMultisigAccountConfiguredRequestBodyStruct, requestBody2),
    };
    const tx2 = await flareTeeManager.requestPMWMultisigAccountConfiguredAttestation(
      WALLET2_ID,
      FLR_SOURCE_ID,
      accounts[200],
      TEE_IDS[0],
      constants.ZERO_ADDRESS,
      constants.ZERO_ADDRESS,
      { value: "2" }
    );
    const event2 = requiredEventArgsFrom(tx2, flareTeeManager, "TeeInstructionsSent") as any;
    expect(event2.rewardEpochId).to.be.equal("2");
    expect(event2.opType).to.be.equal(web3.utils.utf8ToHex("F_FDC2").padEnd(66, "0"));
    expect(event2.opCommand).to.be.equal(web3.utils.utf8ToHex("PROVE").padEnd(66, "0"));
    expect(event2.message).to.be.equal(web3.eth.abi.encodeParameter(fdc2AttestationRequestStruct, message2));
  });

  it("Should add PMW multisig accounts", async () => {
    const proof = {
      signatures: {
        signingPolicySignatures: "",
        teeSignatures: [],
        cosignerSignatures: [],
      },
      header: {
        attestationType: web3.utils.utf8ToHex("PMWMultisigAccountConfigured").padEnd(66, "0"),
        sourceId: XRP_SOURCE_ID,
        thresholdBIPS: "0",
        proofOwner: constants.ZERO_ADDRESS,
        timestamp: (await time.latest()).toString(),
        cosigners: [],
        cosignersThreshold: "0",
      },
      requestBody: {
        accountAddress: "rUzM4ovjNkjSZ2jVJfZQ9321ikeNM6ASzh",
        publicKeys: xrpPublicKeys,
        threshold: "2",
      },
      responseBody: {
        status: "0",
        sequence: 2,
      },
    };

    // sign message
    const headerHash = getHash(getStruct("Fdc2Structs", "fdc2ResponseHeaderStruct"), proof.header);
    const requestBodyHash = getHash(
      getStruct("Fdc2Structs", "pmwMultisigAccountConfiguredRequestBodyStruct"),
      proof.requestBody
    );
    const responseBodyHash = getHash(
      getStruct("Fdc2Structs", "pmwMultisigAccountConfiguredResponseBodyStruct"),
      proof.responseBody
    );
    const message = getFdc2Message(headerHash, requestBodyHash, responseBodyHash);
    proof.signatures.signingPolicySignatures = await getNewSigningPolicySignatures(message);

    const tx = await teePaymentsXRP.addPMWMultisigAccount(WALLET1_ID, proof, TEE_WALLET_AUTHORIZATION_ADDRESSES[0], {
      from: TEE_WALLET_OWNERS[0],
    });
    expectEvent(tx, "PMWMultisigAccountAdded", {
      walletId: WALLET1_ID,
      sourceId: XRP_SOURCE_ID,
      accountAddress: "rUzM4ovjNkjSZ2jVJfZQ9321ikeNM6ASzh",
      initialNonce: "2",
      authorizationAddress: TEE_WALLET_AUTHORIZATION_ADDRESSES[0],
      batchSize: "1",
      batchDurationSeconds: "0",
    });

    const proof2 = {
      signatures: {
        signingPolicySignatures: "",
        teeSignatures: [],
        cosignerSignatures: [],
      },
      header: {
        attestationType: web3.utils.utf8ToHex("PMWMultisigAccountConfigured").padEnd(66, "0"),
        sourceId: FLR_SOURCE_ID,
        thresholdBIPS: "0",
        proofOwner: constants.ZERO_ADDRESS,
        timestamp: (await time.latest()).toString(),
        cosigners: [],
        cosignersThreshold: "0",
      },
      requestBody: {
        accountAddress: accounts[200],
        publicKeys: evmPublicKeys,
        threshold: "1",
      },
      responseBody: {
        status: "0",
        sequence: 1,
      },
    };
    // sign message
    const headerHash2 = getHash(getStruct("Fdc2Structs", "fdc2ResponseHeaderStruct"), proof2.header);
    const requestBodyHash2 = getHash(
      getStruct("Fdc2Structs", "pmwMultisigAccountConfiguredRequestBodyStruct"),
      proof2.requestBody
    );
    const responseBodyHash2 = getHash(
      getStruct("Fdc2Structs", "pmwMultisigAccountConfiguredResponseBodyStruct"),
      proof2.responseBody
    );
    const message2 = getFdc2Message(headerHash2, requestBodyHash2, responseBodyHash2);
    proof2.signatures.signingPolicySignatures = await getNewSigningPolicySignatures(message2);

    const tx2 = await teePaymentsEVM.addPMWMultisigAccount(WALLET2_ID, proof2, TEE_WALLET_AUTHORIZATION_ADDRESSES[1], {
      from: TEE_WALLET_OWNERS[1],
    });
    expectEvent(tx2, "PMWMultisigAccountAdded", {
      walletId: WALLET2_ID,
      sourceId: FLR_SOURCE_ID,
      accountAddress: accounts[200],
      initialNonce: "1",
      authorizationAddress: TEE_WALLET_AUTHORIZATION_ADDRESSES[1],
      batchSize: "1",
      batchDurationSeconds: "0",
    });
  });

  it("Should set TEE payment wallet settings", async () => {
    // set wallet 1 settings
    const tx = await teePaymentsXRP.setBatchSettings(
      { sourceId: XRP_SOURCE_ID, accountAddress: "rUzM4ovjNkjSZ2jVJfZQ9321ikeNM6ASzh" },
      1,
      0,
      { from: TEE_WALLET_OWNERS[0] }
    );
    expectEvent(tx, "BatchSettingsSet", {
      walletId: WALLET1_ID,
      sourceId: XRP_SOURCE_ID,
      accountAddress: "rUzM4ovjNkjSZ2jVJfZQ9321ikeNM6ASzh",
      batchSize: "1",
      batchDurationSeconds: "0",
    });

    const tx2 = await teePaymentsEVM.setBatchSettings(
      { sourceId: FLR_SOURCE_ID, accountAddress: accounts[200] },
      1,
      0,
      { from: TEE_WALLET_OWNERS[1] }
    );
    expectEvent(tx2, "BatchSettingsSet", {
      walletId: WALLET2_ID,
      sourceId: FLR_SOURCE_ID,
      accountAddress: accounts[200],
      batchSize: "1",
      batchDurationSeconds: "0",
    });
  });

  it("Should trigger TEE wallet payments", async () => {
    const paymentInstructionMessageStruct = getStruct("TeePaymentsStructs", "paymentInstructionMessageStruct");
    // DEFAULT_FEE_SCHEDULE = abi.encodePacked(int16(10000), uint16(0))
    // int16(10000) = 0x2710 (2 bytes), uint16(0) = 0x00 (2 bytes)
    const factorBIPS = 10000; // 100%
    const delaySeconds = 0;
    const defaultFeeSchedule =
      "0x" + factorBIPS.toString(16).padStart(4, "0") + delaySeconds.toString(16).padStart(4, "0");
    const tx = await teePaymentsXRP.pay(
      { sourceId: XRP_SOURCE_ID, accountAddress: "rUzM4ovjNkjSZ2jVJfZQ9321ikeNM6ASzh" },
      {
        recipientAddress: "rJcBbUCtPg7b4Pfou23SgF18yMihWueK5B",
        tokenId: constants.ZERO_BYTES32,
        amount: "500",
        maxFee: 150,
        paymentReference: "0xa586ed066db13d66ebe984e1898a2c5fdd74927b21fe92d3b9913725cdaee75a",
      },
      constants.ZERO_ADDRESS,
      { value: "10", from: TEE_WALLET_AUTHORIZATION_ADDRESSES[0] }
    );
    const message = {
      walletId: WALLET1_ID,
      teeIdKeyIdPairs: [
        { teeId: TEE_IDS[0], keyId: "0" },
        { teeId: TEE_IDS[1], keyId: "1" },
        { teeId: TEE_IDS[0], keyId: "2" },
      ],
      sourceId: XRP_SOURCE_ID,
      senderAddress: "rUzM4ovjNkjSZ2jVJfZQ9321ikeNM6ASzh",
      recipientAddress: "rJcBbUCtPg7b4Pfou23SgF18yMihWueK5B",
      tokenId: constants.ZERO_BYTES32,
      amount: "500",
      maxFee: 150,
      feeSchedule: defaultFeeSchedule,
      paymentReference: "0xa586ed066db13d66ebe984e1898a2c5fdd74927b21fe92d3b9913725cdaee75a",
      nonce: 2,
      subNonce: 2,
      batchEndTs: (await time.latest()).toString(),
    };
    const event = requiredEventArgsFrom(tx, flareTeeManager, "TeeInstructionsSent") as any;
    expect(event.rewardEpochId).to.be.equal("2");
    expect(event.opType).to.be.equal(web3.utils.utf8ToHex("F_XRP").padEnd(66, "0"));
    expect(event.opCommand).to.be.equal(web3.utils.utf8ToHex("PAY").padEnd(66, "0"));
    expect(event.message).to.be.equal(web3.eth.abi.encodeParameter(paymentInstructionMessageStruct, message));

    const tx2 = await teePaymentsEVM.pay(
      { sourceId: FLR_SOURCE_ID, accountAddress: accounts[200] },
      {
        recipientAddress: accounts[150],
        tokenId: constants.ZERO_BYTES32,
        amount: "1500",
        maxFee: 1000,
        paymentReference: "0xa7ed203289b636afb50dfc134afdcf844e495ec686cda5fb958e5a0ddd039797",
      },
      constants.ZERO_ADDRESS,
      { value: "10", from: TEE_WALLET_AUTHORIZATION_ADDRESSES[1] }
    );
    const message2 = {
      walletId: WALLET2_ID,
      teeIdKeyIdPairs: [
        { teeId: TEE_IDS[0], keyId: "0" },
        { teeId: TEE_IDS[1], keyId: "1" },
        { teeId: TEE_IDS[0], keyId: "2" },
        { teeId: TEE_IDS[1], keyId: "3" },
      ],
      sourceId: FLR_SOURCE_ID,
      senderAddress: accounts[200],
      recipientAddress: accounts[150],
      tokenId: constants.ZERO_BYTES32,
      amount: "1500",
      maxFee: 1000,
      feeSchedule: defaultFeeSchedule,
      paymentReference: "0xa7ed203289b636afb50dfc134afdcf844e495ec686cda5fb958e5a0ddd039797",
      nonce: 1,
      subNonce: 1,
      batchEndTs: (await time.latest()).toString(),
    };
    const event2 = requiredEventArgsFrom(tx2, flareTeeManager, "TeeInstructionsSent") as any;
    expect(event2.rewardEpochId).to.be.equal("2");
    expect(event2.opType).to.be.equal(web3.utils.utf8ToHex("F_EVM").padEnd(66, "0"));
    expect(event2.opCommand).to.be.equal(web3.utils.utf8ToHex("PAY").padEnd(66, "0"));
    expect(event2.message).to.be.equal(web3.eth.abi.encodeParameter(paymentInstructionMessageStruct, message2));
  });

  it("Should trigger TEE wallet reissue payments", async () => {
    const paymentInstructionMessageStruct = getStruct("TeePaymentsStructs", "paymentInstructionMessageStruct");
    // DEFAULT_FEE_SCHEDULE = abi.encodePacked(int16(10000), uint16(0))
    const factorBIPS = 10000;
    const delaySeconds = 0;
    const defaultFeeSchedule =
      "0x" + factorBIPS.toString(16).padStart(4, "0") + delaySeconds.toString(16).padStart(4, "0");
    await time.increase(1);
    const tx = await teePaymentsXRP.reissue(
      { sourceId: XRP_SOURCE_ID, accountAddress: "rUzM4ovjNkjSZ2jVJfZQ9321ikeNM6ASzh" },
      2,
      2,
      [
        {
          recipientAddress: "rJcBbUCtPg7b4Pfou23SgF18yMihWueK5B",
          tokenId: constants.ZERO_BYTES32,
          amount: "500",
          maxFee: 150,
          paymentReference: "0xa586ed066db13d66ebe984e1898a2c5fdd74927b21fe92d3b9913725cdaee75a",
        },
      ],
      { maxFeePerPayment: [10000], factorsBIPSPerPayment: [[]], delaysSeconds: [] },
      constants.ZERO_ADDRESS,
      { value: "10", from: TEE_WALLET_AUTHORIZATION_ADDRESSES[0] }
    );
    const message = {
      walletId: WALLET1_ID,
      teeIdKeyIdPairs: [
        { teeId: TEE_IDS[0], keyId: "0" },
        { teeId: TEE_IDS[1], keyId: "1" },
        { teeId: TEE_IDS[0], keyId: "2" },
      ],
      sourceId: XRP_SOURCE_ID,
      senderAddress: "rUzM4ovjNkjSZ2jVJfZQ9321ikeNM6ASzh",
      recipientAddress: "rJcBbUCtPg7b4Pfou23SgF18yMihWueK5B",
      tokenId: constants.ZERO_BYTES32,
      amount: "500",
      maxFee: 10000,
      feeSchedule: defaultFeeSchedule,
      paymentReference: "0xa586ed066db13d66ebe984e1898a2c5fdd74927b21fe92d3b9913725cdaee75a",
      nonce: 2,
      subNonce: 2,
      batchEndTs: (await time.latest()).toString(),
    };
    const event = requiredEventArgsFrom(tx, flareTeeManager, "TeeInstructionsSent") as any;
    expect(event.rewardEpochId).to.be.equal("2");
    expect(event.opType).to.be.equal(web3.utils.utf8ToHex("F_XRP").padEnd(66, "0"));
    expect(event.opCommand).to.be.equal(web3.utils.utf8ToHex("REISSUE").padEnd(66, "0"));
    expect(event.message).to.be.equal(web3.eth.abi.encodeParameter(paymentInstructionMessageStruct, message));

    const tx2 = await teePaymentsEVM.reissue(
      { sourceId: FLR_SOURCE_ID, accountAddress: accounts[200] },
      1,
      1,
      [
        {
          recipientAddress: accounts[150],
          tokenId: constants.ZERO_BYTES32,
          amount: "1500",
          maxFee: 1000,
          paymentReference: "0xa7ed203289b636afb50dfc134afdcf844e495ec686cda5fb958e5a0ddd039797",
        },
      ],
      { maxFeePerPayment: [5000000], factorsBIPSPerPayment: [[]], delaysSeconds: [] },
      constants.ZERO_ADDRESS,
      { value: "10", from: TEE_WALLET_AUTHORIZATION_ADDRESSES[1] }
    );
    const message2 = {
      walletId: WALLET2_ID,
      teeIdKeyIdPairs: [
        { teeId: TEE_IDS[0], keyId: "0" },
        { teeId: TEE_IDS[1], keyId: "1" },
        { teeId: TEE_IDS[0], keyId: "2" },
        { teeId: TEE_IDS[1], keyId: "3" },
      ],
      sourceId: FLR_SOURCE_ID,
      senderAddress: accounts[200],
      recipientAddress: accounts[150],
      tokenId: constants.ZERO_BYTES32,
      amount: "1500",
      maxFee: 5000000,
      feeSchedule: defaultFeeSchedule,
      paymentReference: "0xa7ed203289b636afb50dfc134afdcf844e495ec686cda5fb958e5a0ddd039797",
      nonce: 1,
      subNonce: 1,
      batchEndTs: (await time.latest()).toString(),
    };
    const event2 = requiredEventArgsFrom(tx2, flareTeeManager, "TeeInstructionsSent") as any;
    expect(event2.rewardEpochId).to.be.equal("2");
    expect(event2.opType).to.be.equal(web3.utils.utf8ToHex("F_EVM").padEnd(66, "0"));
    expect(event2.opCommand).to.be.equal(web3.utils.utf8ToHex("REISSUE").padEnd(66, "0"));
    expect(event2.message).to.be.equal(web3.eth.abi.encodeParameter(paymentInstructionMessageStruct, message2));
  });

  it("Should set payment limits via TeePaymentsLimitsManager", async () => {
    const setPaymentLimitsStruct = getStruct("TeePaymentsStructs", "setPaymentLimitsStruct");
    const account = { sourceId: XRP_SOURCE_ID, accountAddress: "rUzM4ovjNkjSZ2jVJfZQ9321ikeNM6ASzh" };
    const transactionLimit = "100";
    const dailyLimit = "1000";

    expect((await teePaymentsLimitsManager.getPaymentLimitsNonce(account)).toString()).to.be.equal("0");

    const tx = await teePaymentsLimitsManager.setPaymentLimits(
      account,
      transactionLimit,
      dailyLimit,
      constants.ZERO_ADDRESS,
      { value: "10", from: TEE_WALLET_OWNERS[0] }
    );

    expectEvent(tx, "PaymentLimitsSet", {
      walletId: WALLET1_ID,
      sourceId: XRP_SOURCE_ID,
      accountAddress: account.accountAddress,
      transactionLimit: transactionLimit,
      dailyLimit: dailyLimit,
    });

    const message = {
      walletId: WALLET1_ID,
      sourceId: XRP_SOURCE_ID,
      accountAddress: account.accountAddress,
      nonce: "0",
      teeIdKeyIdPairs: [
        { teeId: TEE_IDS[0], keyId: "0" },
        { teeId: TEE_IDS[1], keyId: "1" },
        { teeId: TEE_IDS[0], keyId: "2" },
      ],
      transactionLimit: transactionLimit,
      dailyLimit: dailyLimit,
    };
    const event = requiredEventArgsFrom(tx, flareTeeManager, "TeeInstructionsSent") as any;
    expect(event.opType).to.be.equal(web3.utils.utf8ToHex("F_XRP").padEnd(66, "0"));
    expect(event.opCommand).to.be.equal(web3.utils.utf8ToHex("SET_PAYMENT_LIMITS").padEnd(66, "0"));
    expect(event.message).to.be.equal(web3.eth.abi.encodeParameter(setPaymentLimitsStruct, message));

    expect((await teePaymentsLimitsManager.getPaymentLimitsNonce(account)).toString()).to.be.equal("1");
  });

  it("Should revert when non-owner calls setPaymentLimits", async () => {
    const account = { sourceId: XRP_SOURCE_ID, accountAddress: "rUzM4ovjNkjSZ2jVJfZQ9321ikeNM6ASzh" };
    await expectRevert.unspecified(
      teePaymentsLimitsManager.setPaymentLimits(account, "100", "1000", constants.ZERO_ADDRESS, {
        value: "1",
        from: TEE_WALLET_OWNERS[1],
      })
    );
  });

  it("Should request VRF", async () => {
    const keyId = 0;
    const nonce = "0x" + Buffer.from("test-vrf-nonce").toString("hex");

    const vrfInstructionMessageStruct = getStruct("TeeVrfStructs", "vrfInstructionMessageStruct");

    await flareTeeManager.setVrfAuthorizationAddress(WALLET1_ID, TEE_WALLET_AUTHORIZATION_ADDRESSES[0], {
      from: TEE_WALLET_OWNERS[0],
    });

    const tx = await flareTeeManager.requestVrf(WALLET1_ID, keyId, nonce, constants.ZERO_ADDRESS, {
      value: "1",
      from: TEE_WALLET_AUTHORIZATION_ADDRESSES[0],
    });

    const vrfEvent = requiredEventArgsFrom(tx, flareTeeManager, "VrfRequested") as any;
    expect(vrfEvent.walletId).to.be.equal(WALLET1_ID);
    expect(vrfEvent.keyId).to.be.equal(keyId.toString());

    const instEvent = requiredEventArgsFrom(tx, flareTeeManager, "TeeInstructionsSent") as any;
    expect(instEvent.rewardEpochId).to.be.equal("2");
    expect(instEvent.opType).to.be.equal(web3.utils.utf8ToHex("F_WALLET").padEnd(66, "0"));
    expect(instEvent.opCommand).to.be.equal(web3.utils.utf8ToHex("VRF").padEnd(66, "0"));
    expect(instEvent.message).to.be.equal(
      web3.eth.abi.encodeParameter(vrfInstructionMessageStruct, {
        walletId: WALLET1_ID,
        keyId: keyId.toString(),
        nonce: nonce,
      })
    );
    expect(vrfEvent.instructionId).to.be.equal(instEvent.instructionId);
  });
});
