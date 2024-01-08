import { time } from "@nomicfoundation/hardhat-network-helpers";
import fs from "fs";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import Web3 from "web3";
import { Account } from "web3-core";
import { toBN } from "web3-utils";
import { IProtocolMessageMerkleRoot, ProtocolMessageMerkleRoot } from "../../scripts/libs/protocol/ProtocolMessageMerkleRoot";
import {
  ISigningPolicy,
  SigningPolicy
} from "../../scripts/libs/protocol/SigningPolicy";
import { generateSignatures } from "../../test/unit/protocol/coding/coding-helpers";
import * as util from "../../test/utils/key-to-address";
import { PChainStakeMirrorVerifierInstance } from "../../typechain-truffle";
import { MockContractInstance } from "../../typechain-truffle/@gnosis.pm/mock-contract/contracts/MockContract.sol/MockContract";
import { VoterRegistryInstance } from "../../typechain-truffle/contracts/protocol/implementation/VoterRegistry";
import { EpochSettings } from "../utils/EpochSettings";
import { DeployedContracts, deployContracts } from "../utils/deploy-contracts";
import { errorString } from "../utils/error";
import { decodeLogs as decodeRawLogs } from "../utils/events";
import { MockDBIndexer } from "../utils/indexer/MockDBIndexer";
import { sqliteDatabase } from "../utils/indexer/data-source";
import { getLogger } from "../utils/logger";

// Simulation config
export const TIMELOCK_SEC = 3600;
const REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS = 5;
const VOTING_EPOCH_DURATION_SEC = 20;
export const REWARD_EPOCH_DURATION_IN_SEC = REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS * VOTING_EPOCH_DURATION_SEC;

export const FIRST_REWARD_EPOCH_VOTING_ROUND_ID = 1000;
const FIRST_REWARD_EPOCH_START_VOTING_ROUND_ID = 1000;

export const systemSettings = function (now: number) {
  return {
    firstVotingRoundStartTs: now - FIRST_REWARD_EPOCH_START_VOTING_ROUND_ID * VOTING_EPOCH_DURATION_SEC,
    votingEpochDurationSeconds: VOTING_EPOCH_DURATION_SEC,
    firstRewardEpochStartVotingRoundId: FIRST_REWARD_EPOCH_START_VOTING_ROUND_ID,
    rewardEpochDurationInVotingEpochs: REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS,
    newSigningPolicyInitializationStartSeconds: 40,
    nonPunishableRandomAcquisitionMinDurationSeconds: 10,
    nonPunishableRandomAcquisitionMinDurationBlocks: 1,
    voterRegistrationMinDurationSeconds: 10,
    voterRegistrationMinDurationBlocks: 1,
    nonPunishableSigningPolicySignMinDurationSeconds: 10,
    nonPunishableSigningPolicySignMinDurationBlocks: 1,
    signingPolicyThresholdPPM: 500000,
    signingPolicyMinNumberOfVoters: 2,
  };
};

// Misc constants
export const FTSO_PROTOCOL_ID = 100;
const GWEI = 1e9;
const RELAY_SELECTOR = Web3.utils.sha3("relay()")!.slice(0, 10);

interface RegisteredAccount {
  readonly submit: Account;
  readonly signing: Account;
  readonly policySigning: Account;
  readonly identity: Account;
}

class EventStore {
  initializedVotingRound = 0;
  /* Keeps track of events emitted by FlareSystemManager for each reward epoch. */
  readonly rewardEpochEvents = new Map<number, string[]>();
}

/**
 * Deploys smart contracts and runs a real-time simulation of voting and signing policy definition protocols.
 * Also incluses an embedded indexer recorting all transactions and events to a local SQLite database.
 *
 * Usage:
 *```
 *   yarn hardhat run-simulation
 *```
 * or
 *```
 *   yarn hardhat run-simulation --network local
 *```
 * to run the simulation on an external Hardhat network (requires running `yarn hardhat node` in a separate process).
 *
 * Contract deployment uses similar logic to the one in end-to-end tests and requires time shifting and
 * mocked contracts. Hence intially the network time is in the past, and once all contracts are deployed
 * and configured, it is synced with system time.
 *
 * The time syncing is required to allow external components (e.g. protocol manager) to interact with the
 * simulated network more easily (in terms of epoch action scheduling).
 *
 * Note: This is still a work in progress and might be buggy.
 */
export async function runSimulation(hre: HardhatRuntimeEnvironment, privateKeys: any[], voterCount: number) {
  const logger = getLogger("");

  // Account 0 is reserved for governance, 1-5 for contract address use, 10+ for voters.
  const accounts = privateKeys.map(x => hre.web3.eth.accounts.privateKeyToAccount(x.privateKey));
  const governanceAccount = accounts[0];

  const [c, rewardEpochStart] = await deployContracts(accounts, hre, governanceAccount);

  const submissionSelectors = {
    submit1: Web3.utils.sha3("submit1()")!.slice(2, 10),
    submit2: Web3.utils.sha3("submit2()")!.slice(2, 10),
    submitSignatures: Web3.utils.sha3("submitSignatures()")!.slice(2, 10),
  };

  logger.info(`Function selectors:\n${JSON.stringify(submissionSelectors, null, 2)}`);

  const indexer = new MockDBIndexer(hre.web3, {
    submission: c.submission.address,
    flareSystemManager: c.flareSystemManager.address,
  });

  logger.info(`Starting a mock c-chain indexer, data is recorded to SQLite database at ${sqliteDatabase}`);
  indexer.run().catch(e => {
    logger.error(`Indexer failed: ${errorString(e)}`);
  });

  const registeredAccounts: RegisteredAccount[] = await registerAccounts(voterCount, accounts, c, rewardEpochStart);
  fs.writeFileSync("simulation-accounts.json", JSON.stringify(registeredAccounts, null, 2));
  logger.info("Registered account keys written to ./simulation-accounts.json");

  const epochSettings = new EpochSettings(
    (await c.flareSystemManager.rewardEpochsStartTs()).toNumber(),
    (await c.flareSystemManager.rewardEpochDurationSeconds()).toNumber(),
    (await c.flareSystemManager.firstVotingRoundStartTs()).toNumber(),
    (await c.flareSystemManager.votingEpochDurationSeconds()).toNumber(),
    (await c.flareSystemManager.newSigningPolicyInitializationStartSeconds()).toNumber(),
    (await c.flareSystemManager.nonPunishableRandomAcquisitionMinDurationSeconds()).toNumber(),
    (await c.flareSystemManager.voterRegistrationMinDurationSeconds()).toNumber(),
    (await c.flareSystemManager.nonPunishableSigningPolicySignMinDurationSeconds()).toNumber()
  );
  logger.info(`EpochSettings:\n${JSON.stringify(epochSettings, null, 2)}`);

  const signingPolicies = new Map<number, ISigningPolicy>();
  await defineInitialSigningPolicy(
    c,
    rewardEpochStart,
    epochSettings,
    registeredAccounts,
    signingPolicies,
    governanceAccount
  );

  logger.info(`Syncing network time with system time`);
  const firstEpochStartMs = epochSettings.rewardEpochStartMs(1);
  if (Date.now() > firstEpochStartMs) await time.increaseTo(Math.floor(Date.now() / 1000));
  else {
    while (Date.now() < firstEpochStartMs) await sleep(500);
  }

  const currentRewardEpochId = (await c.flareSystemManager.getCurrentRewardEpochId()).toNumber();
  if (currentRewardEpochId != 1) {
    throw new Error("Reward epoch after setup expected to be 1");
  }

  logger.info(
    `[Starting simulation] System time ${new Date().toISOString()}, network time (latest block): ${new Date(
      (await time.latest()) * 1000
    ).toISOString()}`
  );

  const systemTime = Date.now();
  const timeUntilSigningPolicyProtocolStart =
    epochSettings.nextRewardEpochStartMs(systemTime) -
    epochSettings.newSigningPolicyInitializationStartSeconds * 1000 -
    systemTime +
    1;

  setTimeout(async () => {
    await runSigningPolicyProtocol();
  }, timeUntilSigningPolicyProtocolStart);

  scheduleVotingEpochActions();

  // Hardhat set interval mining to auto-mine blocks every second
  await hre.network.provider.send("evm_setIntervalMining", [1000]);

  const events = new EventStore();
  while (true) {
    const response = await c.flareSystemManager.daemonize({ gas: 10000000 });
    const blockTimestamp = +(await hre.web3.eth.getBlock(response.receipt.blockNumber)).timestamp;

    if (response.logs.length > 0) {
      // For events emitted by the FlareSystemManager.
      for (const log of response.logs) {
        await processLog(log, blockTimestamp, events);
      }
    } else {
      // For events emitted by the Relay (Truffle won't decode it automatically).
      const log = decodeRawLogs(response, c.relay, "SigningPolicyInitialized");
      if (log !== undefined) await processLog(log, blockTimestamp, events);
    }
    await sleep(500);
  }

  async function runSigningPolicyProtocol() {
    setTimeout(async () => {
      await runSigningPolicyProtocol();
    }, epochSettings.rewardEpochDurationSec * 1000);

    await defineNextSigningPolicy(governanceAccount, c, events.rewardEpochEvents, registeredAccounts);
  }

  function scheduleVotingEpochActions() {
    const time = Date.now();
    const nextEpochStartMs = epochSettings.nextVotingEpochStartMs(time);

    setTimeout(async () => {
      scheduleVotingEpochActions();
      await runVotingRound(c, signingPolicies, registeredAccounts, epochSettings, events, hre.web3);
    }, nextEpochStartMs - time + 1);
  }

  async function processLog(log: any, timestamp: number, events: EventStore) {
    logger.info(`Event ${log.event} emitted`);
    if (log.event == "NewVotingRoundInitiated") {
      const votingRoundId = epochSettings.votingEpochForTime(timestamp * 1000);
      if (votingRoundId > events.initializedVotingRound) {
        events.initializedVotingRound = votingRoundId;
      }
    } else {
      const rewardEpochId = epochSettings.rewardEpochForTime(timestamp * 1000);
      const existing = events.rewardEpochEvents.get(rewardEpochId) || [];
      existing.push(log.event);
      events.rewardEpochEvents.set(rewardEpochId, existing);

      if (log.event == "SigningPolicyInitialized") {
        const signingPolicy = extractSigningPolicy(log.args);
        signingPolicies.set(signingPolicy.rewardEpochId, signingPolicy);
        logger.info("New signing policy:\n" + JSON.stringify(signingPolicy, null, 2));
      }
    }
  }
}

type PChainStake = {
  txId: string;
  stakingType: number;
  inputAddress: string;
  nodeId: string;
  startTime: number;
  endTime: number;
  weight: number;
};

async function registerAccounts(
  voterCount: number,
  accounts: Account[],
  c: DeployedContracts,
  rewardEpochStart: number
): Promise<RegisteredAccount[]> {
  const registeredAccounts: RegisteredAccount[] = [];
  const weightGwei = 1000;
  let accountOffset = 10;

  for (let i = 0; i < voterCount; i++) {
    const nodeId = "0x012345678901234567890123456789012345678" + i;
    const stakeId = web3.utils.keccak256("stake" + i);

    const identityAccount = accounts[accountOffset++];
    const submitAccount = accounts[accountOffset++];
    const signingAccount = accounts[accountOffset++];
    const policySigningAccount = accounts[accountOffset++];

    const prvKey = identityAccount.privateKey.slice(2);
    const prvkeyBuffer = Buffer.from(prvKey, "hex");
    const [x, y] = util.privateKeyToPublicKeyPair(prvkeyBuffer);
    const pubKey = "0x" + util.encodePublicKey(x, y, false).toString("hex");
    const pAddr = "0x" + util.publicKeyToAvalancheAddress(x, y).toString("hex");
    await c.addressBinder.registerAddresses(pubKey, pAddr, identityAccount.address);

    const data = await setMockStakingData(
      c.verifierMock,
      c.pChainVerifier,
      stakeId,
      0,
      pAddr,
      nodeId,
      toBN(rewardEpochStart - 10),
      toBN(rewardEpochStart + 10000),
      weightGwei
    );
    await c.pChainStakeMirror.mirrorStake(data, []);

    await c.wNat.deposit({ value: weightGwei * GWEI, from: identityAccount.address });

    await c.entityManager.registerNodeId(nodeId, { from: identityAccount.address });
    await c.entityManager.registerSubmitAddress(submitAccount.address, { from: identityAccount.address });
    await c.entityManager.confirmSubmitAddressRegistration(identityAccount.address, {
      from: submitAccount.address,
    });
    await c.entityManager.registerSubmitSignaturesAddress(signingAccount.address, { from: identityAccount.address });
    await c.entityManager.confirmSubmitSignaturesAddressRegistration(identityAccount.address, {
      from: signingAccount.address,
    });

    await c.entityManager.registerSigningPolicyAddress(policySigningAccount.address, { from: identityAccount.address });
    await c.entityManager.confirmSigningPolicyAddressRegistration(identityAccount.address, {
      from: policySigningAccount.address,
    });

    registeredAccounts.push({
      identity: identityAccount,
      submit: submitAccount,
      signing: signingAccount,
      policySigning: policySigningAccount,
    });
  }
  return registeredAccounts;
}

async function defineNextSigningPolicy(
  governanceAccount: Account,
  c: DeployedContracts,
  rewardEvents: Map<number, string[]>,
  registeredAccounts: RegisteredAccount[]
) {
  const logger = getLogger("signingPolicy");

  const rewardEpochId = (await c.flareSystemManager.getCurrentRewardEpochId()).toNumber();
  const nextRewardEpochId = rewardEpochId + 1;
  logger.info(`Running signing policy definition protocol, current reward epoch: ${rewardEpochId}`);

  logger.info("Awaiting random acquisition start");
  while (!rewardEvents.get(rewardEpochId)?.includes("RandomAcquisitionStarted")) {
    logger.info("Waiting for random acuisition");
    await sleep(500);
  }

  if (!(await c.flareSystemManager.getCurrentRandomWithQuality())[1]) throw new Error("No good random");

  logger.info("Awaiting voting power block selection");
  while (!rewardEvents.get(rewardEpochId)?.includes("VotePowerBlockSelected")) {
    await sleep(500);
  }

  for (const acc of registeredAccounts) {
    await registerVoter(nextRewardEpochId, acc, c.voterRegistry);
  }

  logger.info("Awaiting signing policy initialization");
  while (!rewardEvents.get(rewardEpochId)?.includes("SigningPolicyInitialized")) {
    await sleep(500);
  }

  logger.info("Signing policy for next reward epoch", nextRewardEpochId);
  const newSigningPolicyHash = await c.relay.toSigningPolicyHash(nextRewardEpochId);

  for (const acc of registeredAccounts) {
    const signature = web3.eth.accounts.sign(newSigningPolicyHash, acc.policySigning.privateKey);

    const signResponse = await c.flareSystemManager.signNewSigningPolicy(
      nextRewardEpochId,
      newSigningPolicyHash,
      signature,
      {
        from: governanceAccount.address,
      }
    );
    if (signResponse.logs[0]?.event != "SigningPolicySigned") {
      throw new Error("Expected signing policy to be signed");
    }

    const args = signResponse.logs[0].args as any;
    if (args.thresholdReached) {
      logger.info(`Signed policy with account ${acc.policySigning.address} - threshold reached`);
      return;
    }
  }
}

/**
 * Runs a mock FTSOv2 voting protocol.
 *
 * Note that currently commits, reveals, ang signing currently don't submit any actual data, just generate "empty" transactions.
 * Also the merkle root that gets finalized is randomly generated and not based on voting round results.
 */
async function runVotingRound(
  c: DeployedContracts,
  signingPolicies: Map<number, ISigningPolicy>,
  registeredAccounts: RegisteredAccount[],
  epochSettings: EpochSettings,
  events: EventStore,
  web3: Web3
) {
  const logger = getLogger("voting");

  const now = Date.now();
  const votingRoundId = epochSettings.votingEpochForTime(now);
  const rewardEpochId = epochSettings.rewardEpochForTime(now);

  while (votingRoundId < events.initializedVotingRound) {
    logger.info("Waiting for voting round to start", votingRoundId);
    await sleep(500);
  }

  logger.info(`Running voting protocol for round ${votingRoundId}, reward epoch: ${rewardEpochId}`);

  for (const acc of registeredAccounts) {
    await c.submission.submit1({ from: acc.submit.address });
  }

  for (const acc of registeredAccounts) {
    await c.submission.submit2({ from: acc.submit.address });
  }

  const revealDeadlineMs =
    epochSettings.votingEpochStartMs(votingRoundId) + (epochSettings.votingEpochDurationSec * 1000) / 2;
  await sleep(revealDeadlineMs - Date.now());

  for (const acc of registeredAccounts) {
    await c.submission.submitSignatures({ from: acc.signing.address });
  }

  // TODO: Obtain actual merkle root and sigantures from the indexer, use fake if not present.
  const fakeMerkleRoot = web3.utils.keccak256("root1" + votingRoundId);
  const messageData: IProtocolMessageMerkleRoot = {
    protocolId: FTSO_PROTOCOL_ID,
    votingRoundId: votingRoundId,
    randomQualityScore: true,
    merkleRoot: fakeMerkleRoot,
  };
  const fullMessage = ProtocolMessageMerkleRoot.encode(messageData).slice(2);
  const messageHash = Web3.utils.keccak256("0x" + fullMessage);
  const signatures = await generateSignatures(
    registeredAccounts.map(x => x.policySigning.privateKey),
    messageHash,
    registeredAccounts.length
  );
  const encodedSigningPolicy = SigningPolicy.encode(signingPolicies.get(rewardEpochId)!).slice(2);
  const fullData = RELAY_SELECTOR + encodedSigningPolicy + fullMessage + signatures;

  await web3.eth.sendTransaction({
    from: registeredAccounts[0].policySigning.address,
    to: c.relay.address,
    data: fullData,
  });

  logger.info(`Voting round ${votingRoundId} finished`);
}

/** Initializes a signing policy for the first reward epoch, signed by governance. */
async function defineInitialSigningPolicy(
  c: DeployedContracts,
  rewardEpochStart: number,
  epochSettings: EpochSettings,
  registeredAccounts: RegisteredAccount[],
  signingPolicies: Map<number, ISigningPolicy>,
  governanceAccount: Account
) {
  await time.increaseTo(
    rewardEpochStart + (REWARD_EPOCH_DURATION_IN_SEC - epochSettings.newSigningPolicyInitializationStartSeconds)
  );

  const resp = await c.flareSystemManager.daemonize();
  if (resp.logs[0]?.event != "RandomAcquisitionStarted") {
    throw new Error("Expected random acquisition to start");
  }

  await time.increase(epochSettings.nonPunishableRandomAcquisitionMinDurationSeconds);

  const resp2 = await c.flareSystemManager.daemonize();
  if (resp2.logs[0]?.event != "VotePowerBlockSelected") {
    throw new Error("Expected vote power block to be selected");
  }

  for (const acc of registeredAccounts) {
    await registerVoter(1, acc, c.voterRegistry);
  }

  await time.increaseTo(
    rewardEpochStart + (REWARD_EPOCH_DURATION_IN_SEC - epochSettings.nonPunishableSigningPolicySignMinDurationSeconds)
  );

  const resp3 = await c.flareSystemManager.daemonize();
  const eventLog = decodeRawLogs(resp3, c.relay, "SigningPolicyInitialized");

  if (eventLog.event != "SigningPolicyInitialized") {
    throw new Error("Expected signing policy to be initialized");
  } else {
    const arg = eventLog.args;
    signingPolicies.set(1, extractSigningPolicy(arg));
  }
  const rewardEpochId = 1;
  const newSigningPolicyHash = await c.relay.toSigningPolicyHash(rewardEpochId);

  const signature = web3.eth.accounts.sign(newSigningPolicyHash, governanceAccount.privateKey);
  const resp4 = await c.flareSystemManager.signNewSigningPolicy(rewardEpochId, newSigningPolicyHash, signature, {
    from: governanceAccount.address,
  });

  if (resp4.logs[0]?.event != "SigningPolicySigned") {
    throw new Error("Expected signing policy to be signed");
  }
  const args = resp4.logs[0].args as any;
  if (!args.thresholdReached) {
    throw new Error("Threshold not reached");
  }

  await c.flareSystemManager.changeRandomProvider(false);
}

async function registerVoter(rewardEpochId: number, acc: RegisteredAccount, voterRegistry: VoterRegistryInstance) {
  const hash = web3.utils.keccak256(
    web3.eth.abi.encodeParameters(["uint24", "address"], [rewardEpochId, acc.identity.address])
  );

  const signature = web3.eth.accounts.sign(hash, acc.policySigning.privateKey);
  await voterRegistry.registerVoter(acc.identity.address, signature, { from: acc.signing.address });
}

function extractSigningPolicy(logArg: any) {
  return {
    rewardEpochId: +logArg.rewardEpochId,
    startVotingRoundId: +logArg.startVotingRoundId,
    threshold: +logArg.threshold,
    seed: "0x" + toBN(logArg.seed).toString("hex", 64),
    voters: logArg.voters,
    weights: logArg.weights.map((x: any) => +x),
  };
}

async function setMockStakingData(
  verifierMock: MockContractInstance,
  pChainVerifier: PChainStakeMirrorVerifierInstance,
  txId: string,
  stakingType: number,
  inputAddress: string,
  nodeId: string,
  startTime: BN,
  endTime: BN,
  weight: number,
  stakingProved: boolean = true
): Promise<PChainStake> {
  const data: PChainStake = {
    txId: txId,
    stakingType: stakingType,
    inputAddress: inputAddress,
    nodeId: nodeId,
    startTime: startTime.toNumber(),
    endTime: endTime.toNumber(),
    weight: weight,
  };

  const verifyPChainStakingMethod = pChainVerifier.contract.methods.verifyStake(data, []).encodeABI();
  await verifierMock.givenCalldataReturnBool(verifyPChainStakingMethod, stakingProved);
  return data;
}

export async function sleep(ms: number) {
  await new Promise<void>(resolve => setTimeout(() => resolve(), ms));
}

export function encodeContractNames(web3: any, names: string[]): string[] {
  return names.map(name => encodeString(name, web3));
}

export function encodeString(text: string, web3: any): string {
  return web3.utils.keccak256(web3.eth.abi.encodeParameters(["string"], [text]));
}
export function getSigningPolicyHash(signingPolicy: ISigningPolicy): string {
  return SigningPolicy.hash(signingPolicy);
}
