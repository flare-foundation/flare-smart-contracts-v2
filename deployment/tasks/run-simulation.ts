import { time } from "@nomicfoundation/hardhat-network-helpers";
import fs from "fs";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import Web3 from "web3";
import { Account } from "web3-core";
import { toBN } from "web3-utils";
import { FtsoConfigurations } from "../../scripts/libs/protocol/FtsoConfigurations";
import {
  IProtocolMessageMerkleRoot,
  ProtocolMessageMerkleRoot,
} from "../../scripts/libs/protocol/ProtocolMessageMerkleRoot";
import { RelayMessage } from "../../scripts/libs/protocol/RelayMessage";
import { ISigningPolicy, SigningPolicy } from "../../scripts/libs/protocol/SigningPolicy";
import { generateSignatures } from "../../test/unit/protocol/coding/coding-helpers";
import * as util from "../../test/utils/key-to-address";
import { PChainStakeMirrorVerifierInstance } from "../../typechain-truffle";
import { MockContractInstance } from "../../typechain-truffle/@gnosis.pm/mock-contract/contracts/MockContract.sol/MockContract";
import { VoterRegistryInstance } from "../../typechain-truffle/contracts/protocol/implementation/VoterRegistry";
import { EpochSettings } from "../utils/EpochSettings";
import { DeployedContracts, deployContracts, serializeDeployedContractsAddresses } from "../utils/deploy-contracts";
import { errorString } from "../utils/error";
import { decodeLogs as decodeRawLogs } from "../utils/events";
import { MockDBIndexer } from "../utils/indexer/MockDBIndexer";
import { getLogger } from "../utils/logger";
import { Sign, Signature, SortitionKey, generateSortitionKey, ParseSortitionKey } from "../../test/utils/sortition";
import { sha256 } from "ethers";

// Simulation config
export const SIMULATION_DUMP_FOLDER = "./sim";
export const SETTINGS_FILE_LOCATION = `${SIMULATION_DUMP_FOLDER}/epoch-settings.json`;
export const DEPLOY_ADDRESSES_FILE = `${SIMULATION_DUMP_FOLDER}/deployed-addresses.json`;
export const SIMULATION_ACCOUNTS_FILE = `${SIMULATION_DUMP_FOLDER}/simulation-accounts.json`;
export const MEMORY_DATABASE_FILE = `${SIMULATION_DUMP_FOLDER}/indexer.db`;

export const TIMELOCK_SEC = 3600;
const REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS = 5;
const VOTING_EPOCH_DURATION_SEC = 20;
export const REWARD_EPOCH_DURATION_IN_SEC = REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS * VOTING_EPOCH_DURATION_SEC;

export const FIRST_REWARD_EPOCH_VOTING_ROUND_ID = 1000;
const FIRST_REWARD_EPOCH_START_VOTING_ROUND_ID = 1000;

export function bigIntReplacer(key: string, value: any): any {
  if (typeof value === "bigint") {
    return value.toString() + "n";
  }
  return value;
}

const OFFERS = [
  {
    amount: 25000000,
    feedId: FtsoConfigurations.encodeFeedId({ category: 1, name: "BTC/USD" }),
    minRewardedTurnoutBIPS: 5000,
    primaryBandRewardSharePPM: 450000,
    secondaryBandWidthPPM: 50000,
    claimBackAddress: "0x0000000000000000000000000000000000000000",
  },
  {
    amount: 50000000,
    feedId: FtsoConfigurations.encodeFeedId({ category: 1, name: "XRP/USD" }),
    minRewardedTurnoutBIPS: 5000,
    primaryBandRewardSharePPM: 650000,
    secondaryBandWidthPPM: 20000,
    claimBackAddress: "0x0000000000000000000000000000000000000000",
  },
];

function processEnv() {
  const SKIP_VOTER_REGISTRATION_SET = new Set<string>();
  const SKIP_SIGNING_POLICY_SIGNING_SET = new Set<string>();
  let SKIP_VOTING_EPOCH_ACTIONS = false;
  if (process.env.SKIP_VOTER_REGISTRATION_SET) {
    process.env.SKIP_VOTER_REGISTRATION_SET.split(",").forEach(x => {
      if (/^0x[0-9a-f]{40}$/i.test(x.trim())) {
        SKIP_VOTER_REGISTRATION_SET.add(x.trim().toLowerCase());
      }
    });
  }

  if (process.env.SKIP_SIGNING_POLICY_SIGNING_SET) {
    process.env.SKIP_SIGNING_POLICY_SIGNING_SET.split(",").forEach(x => {
      if (/^0x[0-9a-f]{40}$/i.test(x.trim())) {
        SKIP_SIGNING_POLICY_SIGNING_SET.add(x.trim().toLowerCase());
      }
    });
  }

  if (process.env.SKIP_VOTING_EPOCH_ACTIONS) {
    console.log("Skipping voting epoch actions");
    SKIP_VOTING_EPOCH_ACTIONS = true;
  }

  let SKIP_FINALIZATIONS = false;
  if (process.env.SKIP_FINALIZATIONS) {
    console.log("Skipping finalizations");
    SKIP_FINALIZATIONS = true;
  }

  return {
    SKIP_VOTER_REGISTRATION_SET,
    SKIP_SIGNING_POLICY_SIGNING_SET,
    SKIP_VOTING_EPOCH_ACTIONS,
    SKIP_FINALIZATIONS,
  };
}

const { SKIP_VOTER_REGISTRATION_SET, SKIP_SIGNING_POLICY_SIGNING_SET, SKIP_VOTING_EPOCH_ACTIONS, SKIP_FINALIZATIONS } =
  processEnv();

export const systemSettings = function (now: number) {
  return {
    firstVotingRoundStartTs: now - FIRST_REWARD_EPOCH_START_VOTING_ROUND_ID * VOTING_EPOCH_DURATION_SEC,
    votingEpochDurationSeconds: VOTING_EPOCH_DURATION_SEC,
    firstRewardEpochStartVotingRoundId: FIRST_REWARD_EPOCH_START_VOTING_ROUND_ID,
    rewardEpochDurationInVotingEpochs: REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS,
    updatableSettings: {
      newSigningPolicyInitializationStartSeconds: 45,
      randomAcquisitionMaxDurationSeconds: 80,
      randomAcquisitionMaxDurationBlocks: 1000,
      newSigningPolicyMinNumberOfVotingRoundsDelay: 0,
      voterRegistrationMinDurationSeconds: 10,
      voterRegistrationMinDurationBlocks: 1,
      submitUptimeVoteMinDurationSeconds: 10,
      submitUptimeVoteMinDurationBlocks: 1,
      signingPolicyThresholdPPM: 500000,
      signingPolicyMinNumberOfVoters: 2,
      rewardExpiryOffsetSeconds: 1000,
    },
  };
};

// Misc constants
export const FTSO_PROTOCOL_ID = 100;
const GWEI = 1e9;
const RELAY_SELECTOR = Web3.utils.sha3("relay()")!.slice(0, 10);

interface RegisteredAccount {
  readonly submit: Account;
  readonly submitSignatures: Account;
  readonly signingPolicy: Account;
  readonly identity: Account;
  readonly sortitionKey: SortitionKeyStrings;
}

interface SortitionKeyStrings {
  readonly sk: string;
  readonly pkx: string;
  readonly pky: string;
}

class EventStore {
  initializedVotingRound = 0;
  /* Keeps track of events emitted by FlareSystemsManager for each reward epoch. */
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
  if (!fs.existsSync(SIMULATION_DUMP_FOLDER)) {
    fs.mkdirSync(SIMULATION_DUMP_FOLDER);
  }
  const logger = getLogger("");

  logger.info(`SKIP_VOTER_REGISTRATION_SET: ${new Array(...SKIP_VOTER_REGISTRATION_SET).join(" ")}`);
  logger.info(`SKIP_SIGNING_POLICY_SIGNING_SET:  ${new Array(...SKIP_SIGNING_POLICY_SIGNING_SET).join(" ")}`);
  logger.info(`SKIP_VOTING_EPOCH_ACTIONS: ${SKIP_VOTING_EPOCH_ACTIONS}`);
  logger.info(`SKIP_FINALIZATIONS: ${SKIP_FINALIZATIONS}`);
  logger.info(`Simulation specific files generated in ${SIMULATION_DUMP_FOLDER}`);

  // Account 0 is reserved for governance, 1-5 for contract address use, 10+ for voters.
  const accounts = privateKeys.map(x => hre.web3.eth.accounts.privateKeyToAccount(x.privateKey));
  const governanceAccount = accounts[0];

  const [c, rewardEpochStart, initialSigningPolicy] = await deployContracts(accounts, hre, governanceAccount);
  serializeDeployedContractsAddresses(c, DEPLOY_ADDRESSES_FILE);
  const submissionSelectors = {
    submit1: Web3.utils.sha3("submit1()")!.slice(2, 10),
    submit2: Web3.utils.sha3("submit2()")!.slice(2, 10),
    submitSignatures: Web3.utils.sha3("submitSignatures()")!.slice(2, 10),
    relay: Web3.utils.sha3("relay()")!.slice(2, 10),
  };

  logger.info(`Function selectors:\n${JSON.stringify(submissionSelectors, null, 2)}`);

  const indexer = new MockDBIndexer(hre.web3, {
    submission: c.submission.address,
    flareSystemsManager: c.flareSystemsManager.address,
    voterRegistry: c.voterRegistry.address,
    ftsoRewardOffersManager: c.ftsoRewardOffersManager.address,
  });

  logger.info(`Starting a mock c-chain indexer, data is recorded to SQLite database at ${MEMORY_DATABASE_FILE}`);
  indexer.run().catch(e => {
    logger.error(`Indexer failed: ${errorString(e)}`);
  });

  const registeredAccounts: RegisteredAccount[] = await registerAccounts(voterCount, accounts, c, rewardEpochStart);
  fs.writeFileSync(SIMULATION_ACCOUNTS_FILE, JSON.stringify(registeredAccounts, bigIntReplacer, 2));
  logger.info("Registered account keys written to " + SIMULATION_ACCOUNTS_FILE);

  const epochSettings = new EpochSettings(
    (await c.flareSystemsManager.firstRewardEpochStartTs()).toNumber(),
    (await c.flareSystemsManager.rewardEpochDurationSeconds()).toNumber(),
    (await c.flareSystemsManager.firstVotingRoundStartTs()).toNumber(),
    (await c.flareSystemsManager.votingEpochDurationSeconds()).toNumber(),
    (await c.flareSystemsManager.newSigningPolicyInitializationStartSeconds()).toNumber(),
    (await c.flareSystemsManager.voterRegistrationMinDurationSeconds()).toNumber(),
    (await c.flareSystemsManager.voterRegistrationMinDurationBlocks()).toNumber()
  );
  logger.info(`EpochSettings:\n${JSON.stringify(epochSettings, null, 2)}`);
  fs.writeFileSync(
    SETTINGS_FILE_LOCATION,
    JSON.stringify(
      {
        firstRewardEpochStartVotingId:
          (epochSettings.rewardEpochStartSec - epochSettings.firstVotingEpochStartSec) /
          epochSettings.votingEpochDurationSec,
        rewardEpochDurationInVotingEpochs: epochSettings.rewardEpochDurationSec / epochSettings.votingEpochDurationSec,
        ...epochSettings,
      },
      null,
      2
    )
  );
  fs.writeFileSync(
    SETTINGS_FILE_LOCATION,
    JSON.stringify(
      {
        firstRewardEpochStartVotingId:
          (epochSettings.rewardEpochStartSec - epochSettings.firstVotingEpochStartSec) /
          epochSettings.votingEpochDurationSec,
        rewardEpochDurationInVotingEpochs: epochSettings.rewardEpochDurationSec / epochSettings.votingEpochDurationSec,
        ...epochSettings,
      },
      null,
      2
    )
  );
  logger.info(`Epoch settings written to ${SETTINGS_FILE_LOCATION}`);

  const signingPolicies = new Map<number, ISigningPolicy>();
  signingPolicies.set(initialSigningPolicy.rewardEpochId, initialSigningPolicy);
  const events = new EventStore();

  await defineInitialSigningPolicy(
    c,
    rewardEpochStart,
    epochSettings,
    registeredAccounts,
    signingPolicies,
    hre.web3,
    governanceAccount
  );

  logger.info(`Syncing network time with system time`);
  const firstEpochStartMs = epochSettings.rewardEpochStartMs(1);
  if (Date.now() > firstEpochStartMs) await time.increaseTo(Math.floor(Date.now() / 1000));
  else {
    while (Date.now() < firstEpochStartMs) await sleep(500);
  }

  await c.flareDaemon.trigger({ gas: 20000000 });

  const currentRewardEpochId = (await c.flareSystemsManager.getCurrentRewardEpochId()).toNumber();
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

  scheduleOfferRewardsActions(events);
  logger.info(`Skipping voting epoch actions: ${SKIP_VOTING_EPOCH_ACTIONS}`);
  const nowtime = Date.now();
  const nextEpochStartMs = epochSettings.nextVotingEpochStartMs(nowtime);
  logger.info(`Next voting epoch starts at ${new Date(nextEpochStartMs).toISOString()} | ${nextEpochStartMs}`);
  scheduleVotingEpochActions(SKIP_VOTING_EPOCH_ACTIONS);

  // Hardhat set interval mining to auto-mine blocks every second
  await hre.network.provider.send("evm_setIntervalMining", [1000]);

  while (true) {
    const response = await c.flareDaemon.trigger({ gas: 20000000 });
    // if (response.receipt.gasUsed > 100000) console.log("Gas used:", response.receipt.gasUsed);
    const blockTimestamp = +(await hre.web3.eth.getBlock(response.receipt.blockNumber)).timestamp;
    let logs;
    // For events emitted by the FlareSystemsManager.
    const eventList = [
      "RandomAcquisitionStarted",
      "VotePowerBlockSelected",
      "SigningPolicySigned",
      "RewardEpochStarted",
      "SignUptimeVoteEnabled",
      "UptimeVoteSubmitted",
      "UptimeVoteSigned",
      "RewardsSigned",
    ];
    for (const event of eventList) {
      logs = decodeRawLogs(response, c.flareSystemsManager, event);
      for (const log of logs) {
        await processLog(log, blockTimestamp, events);
      }
    }
    logs = decodeRawLogs(response, c.ftsoRewardOffersManager, "InflationRewardsOffered");
    for (const log of logs) {
      await processLog(log, blockTimestamp, events);
    }
    logs = decodeRawLogs(response, c.fastUpdateIncentiveManager, "InflationRewardsOffered");
    for (const log of logs) {
      await processLog(log, blockTimestamp, events);
    }
    logs = decodeRawLogs(response, c.fdcHub, "InflationRewardsOffered");
    for (const log of logs) {
      await processLog(log, blockTimestamp, events);
    }
    logs = decodeRawLogs(response, c.relay, "SigningPolicyInitialized");
    for (const log of logs) {
      await processLog(log, blockTimestamp, events);
    }
    await sleep(500);
  }

  async function runSigningPolicyProtocol() {
    setTimeout(async () => {
      await runSigningPolicyProtocol();
    }, epochSettings.rewardEpochDurationSec * 1000);

    await defineNextSigningPolicy(governanceAccount, c, events.rewardEpochEvents, registeredAccounts);
  }

  function scheduleVotingEpochActions(skipSubmit: boolean) {
    const time = Date.now();
    const nextEpochStartMs = epochSettings.nextVotingEpochStartMs(time);

    setTimeout(async () => {
      scheduleVotingEpochActions(skipSubmit);
      await runVotingRound(
        skipSubmit,
        c,
        signingPolicies,
        registeredAccounts,
        epochSettings,
        events,
        hre.web3,
        SKIP_FINALIZATIONS
      );
    }, nextEpochStartMs - time + 1);
  }

  function scheduleOfferRewardsActions(eventStore: EventStore) {
    const time = Date.now();
    const nextEpochStartMs = epochSettings.nextRewardEpochStartMs(time);

    setTimeout(async () => {
      scheduleOfferRewardsActions(eventStore);
      await runOfferRewards(c, epochSettings, eventStore);
    }, nextEpochStartMs - time + 1000);
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

  const logger = getLogger("");

  for (let i = 0; i < voterCount; i++) {
    const nodeId = "0x0123456789012345678901234567890123456" + i.toString().padStart(3, "0");
    const stakeId = web3.utils.keccak256("stake" + i);

    const identityAccount = accounts[accountOffset++];
    const delegationAccount = accounts[accountOffset++];
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
      c.mockContract,
      c.pChainStakeMirrorVerifier,
      stakeId,
      0,
      pAddr,
      nodeId,
      toBN(rewardEpochStart - 10),
      toBN(rewardEpochStart + 10000),
      weightGwei
    );
    await c.pChainStakeMirror.mirrorStake(data, []);

    await c.wNat.deposit({ value: weightGwei * GWEI, from: delegationAccount.address });

    await c.entityManager.registerNodeId(nodeId, "0x", "0x", { from: identityAccount.address });
    await c.entityManager.proposeDelegationAddress(delegationAccount.address, { from: identityAccount.address });
    await c.entityManager.confirmDelegationAddressRegistration(identityAccount.address, {
      from: delegationAccount.address,
    });
    await c.entityManager.proposeSubmitAddress(submitAccount.address, { from: identityAccount.address });
    await c.entityManager.confirmSubmitAddressRegistration(identityAccount.address, {
      from: submitAccount.address,
    });
    await c.entityManager.proposeSubmitSignaturesAddress(signingAccount.address, { from: identityAccount.address });
    await c.entityManager.confirmSubmitSignaturesAddressRegistration(identityAccount.address, {
      from: signingAccount.address,
    });

    await c.entityManager.proposeSigningPolicyAddress(policySigningAccount.address, { from: identityAccount.address });
    await c.entityManager.confirmSigningPolicyAddressRegistration(identityAccount.address, {
      from: policySigningAccount.address,
    });

    const key: SortitionKey = ParseSortitionKey(policySigningAccount.privateKey);
    const msg = sha256(web3.utils.encodePacked(identityAccount.address)!);

    const signature: Signature = Sign(key, msg);
    const pkx = "0x" + web3.utils.padLeft(key.pk.x.toString(16), 64);
    const pky = "0x" + web3.utils.padLeft(key.pk.y.toString(16), 64);
    const sk = "0x" + web3.utils.padLeft(key.sk.toString(16), 64);
    const sortitionKey: SortitionKeyStrings = { sk, pkx, pky };
    await c.entityManager.registerPublicKey(
      pkx,
      pky,
      web3.eth.abi.encodeParameters(
        ["uint256", "uint256", "uint256"],
        [signature.s.toString(), signature.r.x.toString(), signature.r.y.toString()]
      ),
      { from: identityAccount.address }
    );

    registeredAccounts.push({
      identity: identityAccount,
      submit: submitAccount,
      submitSignatures: signingAccount,
      signingPolicy: policySigningAccount,
      sortitionKey: sortitionKey,
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

  const rewardEpochId = (await c.flareSystemsManager.getCurrentRewardEpochId()).toNumber();
  const nextRewardEpochId = rewardEpochId + 1;
  logger.info(`Running signing policy definition protocol, current reward epoch: ${rewardEpochId}`);

  logger.info("Awaiting random acquisition start");
  while (!rewardEvents.get(rewardEpochId)?.includes("RandomAcquisitionStarted")) {
    logger.info("Waiting for random acuisition");
    await sleep(500);
  }

  if (!(await c.submission.getCurrentRandomWithQuality())[1]) throw new Error("No good random");

  logger.info("Awaiting voting power block selection");
  while (!rewardEvents.get(rewardEpochId)?.includes("VotePowerBlockSelected")) {
    await sleep(500);
  }

  for (const acc of registeredAccounts) {
    if (SKIP_VOTER_REGISTRATION_SET.has(acc.signingPolicy.address.toLowerCase())) {
      logger.info(`Skipping automatic voter registration for ${acc.signingPolicy.address}`);
      continue;
    } else logger.info(`Registering voter ${acc.signingPolicy.address}`);
    await registerVoter(nextRewardEpochId, acc, c.voterRegistry);
  }

  logger.info("Awaiting signing policy initialization");
  while (!rewardEvents.get(rewardEpochId)?.includes("SigningPolicyInitialized")) {
    await sleep(500);
  }

  logger.info("Signing policy for next reward epoch", nextRewardEpochId);
  const newSigningPolicyHash = await c.relay.toSigningPolicyHash(nextRewardEpochId);

  for (const acc of registeredAccounts) {
    if (SKIP_SIGNING_POLICY_SIGNING_SET.has(acc.signingPolicy.address.toLowerCase())) {
      logger.info(`Skipping automatic new signing policy signing for ${acc.signingPolicy.address}`);
      continue;
    }
    const signature = web3.eth.accounts.sign(newSigningPolicyHash, acc.signingPolicy.privateKey);

    const signResponse = await c.flareSystemsManager.signNewSigningPolicy(
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
      logger.info(`Signed policy with account ${acc.signingPolicy.address} - threshold reached`);
      return;
    }
  }
}

async function runOfferRewards(
  c: DeployedContracts,
  epochSettings: EpochSettings,
  eventStore?: EventStore,
  forceEpoch?: number
) {
  const logger = getLogger("offerRewards");

  const nextRewardEpochId = forceEpoch ?? epochSettings.rewardEpochForTime(Date.now()) + 1;

  if (forceEpoch == null) {
    logger.info(`Waiting for reward epoch ${nextRewardEpochId - 1} to start`);
    while (!eventStore!.rewardEpochEvents.get(nextRewardEpochId - 1)?.includes("RewardEpochStarted")) {
      await sleep(500);
    }
  }

  let rewards = 0;
  for (const offer of OFFERS) {
    rewards += offer.amount;
  }
  try {
    await c.ftsoRewardOffersManager.offerRewards(nextRewardEpochId, OFFERS, { value: rewards });
    logger.info("Rewards offered");
  } catch (e) {
    logger.error("Rewards not offered: " + e);
  }
}

/**
 * Runs a mock FTSOv2 voting protocol.
 *
 * Note that currently commits, reveals, ang signing currently don't submit any actual data, just generate "empty" transactions.
 * Also the merkle root that gets finalized is randomly generated and not based on voting round results.
 */
async function runVotingRound(
  skipSubmit: boolean,
  c: DeployedContracts,
  signingPolicies: Map<number, ISigningPolicy>,
  registeredAccounts: RegisteredAccount[],
  epochSettings: EpochSettings,
  events: EventStore,
  web3: Web3,
  skipFinalisation: boolean = false,
  now: number = Date.now()
) {
  const logger = getLogger("voting");

  const votingRoundId = epochSettings.votingEpochForTime(now);
  const rewardEpochId = epochSettings.rewardEpochForTime(now);

  while (votingRoundId < events.initializedVotingRound) {
    logger.info("Waiting for voting round to start", votingRoundId);
    await sleep(500);
  }

  logger.info(`Running voting protocol for round ${votingRoundId}, reward epoch: ${rewardEpochId}`);

  const previousMerkleRoot = await c.relay.getConfirmedMerkleRoot(FTSO_PROTOCOL_ID, votingRoundId - 2);
  logger.info(`Confirmed merkle root in the last round ${votingRoundId - 2}: ${previousMerkleRoot}`);

  if (!skipSubmit) {
    for (const acc of registeredAccounts) {
      try {
        await c.submission.submit1({ from: acc.submit.address });
      } catch (e) {
        logger.error(e);
      }
    }
    const revealStartMs = epochSettings.votingEpochStartMs(votingRoundId + 1);
    await sleep(revealStartMs - Date.now());
    for (const acc of registeredAccounts) {
      try {
        await c.submission.submit2({ from: acc.submit.address });
      } catch (e) {
        logger.error(e);
      }
    }
  }

  const revealDeadlineMs =
    epochSettings.votingEpochStartMs(votingRoundId + 1) + (epochSettings.votingEpochDurationSec * 1000) / 2;
  await sleep(revealDeadlineMs - Date.now());

  if (!skipSubmit) {
    for (const acc of registeredAccounts) {
      try {
        await c.submission.submitSignatures({ from: acc.submitSignatures.address });
      } catch (e) {
        logger.error(e);
      }
    }
  }
  if (!skipFinalisation) await fakeFinalize(web3, signingPolicies, registeredAccounts, epochSettings, c, now);
  logger.info(`Voting round ${votingRoundId} finished`);
}

async function fakeFinalize(
  web3: Web3,
  signingPolicies: Map<number, ISigningPolicy>,
  registeredAccounts: RegisteredAccount[],
  epochSettings: EpochSettings,
  c: DeployedContracts,
  now: number
) {
  const logger = getLogger("finalize");

  const votingRoundId = epochSettings.votingEpochForTime(now);
  const rewardEpochId = epochSettings.rewardEpochForTime(now);

  const fakeMerkleRoot = web3.utils.keccak256("root1" + votingRoundId);
  const messageData: IProtocolMessageMerkleRoot = {
    protocolId: FTSO_PROTOCOL_ID,
    votingRoundId: votingRoundId,
    isSecureRandom: true,
    merkleRoot: fakeMerkleRoot,
  };

  const signingPolicy = signingPolicies.get(rewardEpochId)!;
  const privateKeysInOrder = [];
  for (const voter of signingPolicy.voters) {
    const acc = registeredAccounts.find(x => x.signingPolicy.address.toLowerCase() == voter.toLowerCase())!;
    if (acc) {
      privateKeysInOrder.push(acc.signingPolicy.privateKey);
    } else {
      logger.info(`Voter not among registered accounts: ${voter}`);
    }
  }
  const messageHash = ProtocolMessageMerkleRoot.hash(messageData);
  const signatures = await generateSignatures(privateKeysInOrder, messageHash, privateKeysInOrder.length);

  const relayMessage = {
    signingPolicy: signingPolicy,
    signatures,
    protocolMessageMerkleRoot: messageData,
  };

  const fullData = RelayMessage.encode(relayMessage);

  try {
    await web3.eth.sendTransaction({
      from: registeredAccounts[0].signingPolicy.address,
      to: c.relay.address,
      data: RELAY_SELECTOR + fullData.slice(2),
    });
    logger.info(`Finalized for voting round ${votingRoundId}`);
  } catch (e) {
    logger.error(e);
  }
}

/** Initializes a signing policy for the first reward epoch, signed by governance. */
async function defineInitialSigningPolicy(
  c: DeployedContracts,
  rewardEpochStart: number,
  epochSettings: EpochSettings,
  registeredAccounts: RegisteredAccount[],
  signingPolicies: Map<number, ISigningPolicy>,
  web3: Web3,
  governanceAccount: Account
) {
  await runOfferRewards(c, epochSettings, undefined, 1);

  await time.increaseTo(
    rewardEpochStart + (REWARD_EPOCH_DURATION_IN_SEC - epochSettings.newSigningPolicyInitializationStartSeconds)
  );

  const response = await c.flareDaemon.trigger({ gas: 20000000 });
  const logs = decodeRawLogs(response, c.flareSystemsManager, "RandomAcquisitionStarted");
  if (logs.length == 0) {
    throw new Error("Expected random acquisition to start");
  }

  const key = generateSortitionKey();
  const pkx = "0x" + web3.utils.padLeft(key.pk.x.toString(16), 64);
  const pky = "0x" + web3.utils.padLeft(key.pk.y.toString(16), 64);
  const sk = "0x" + web3.utils.padLeft(key.sk.toString(16), 64);
  const sortitionKey: SortitionKeyStrings = { sk, pkx, pky };
  const governance = {
    identity: governanceAccount,
    submit: governanceAccount,
    submitSignatures: governanceAccount,
    signingPolicy: governanceAccount,
    sortitionKey: sortitionKey,
  };

  await fakeFinalize(web3, signingPolicies, [governance], epochSettings, c, (await time.latest()) * 1000);

  await time.increaseTo(
    rewardEpochStart +
      (REWARD_EPOCH_DURATION_IN_SEC - Math.floor(epochSettings.newSigningPolicyInitializationStartSeconds / 2))
  );

  const response2 = await c.flareDaemon.trigger({ gas: 20000000 });
  const logs2 = decodeRawLogs(response2, c.flareSystemsManager, "VotePowerBlockSelected");
  if (logs2.length == 0) {
    throw new Error("Expected random acquisition to start");
  }

  for (const acc of registeredAccounts) {
    await registerVoter(1, acc, c.voterRegistry);
  }

  await time.increaseTo(
    rewardEpochStart +
      (REWARD_EPOCH_DURATION_IN_SEC -
        Math.floor(epochSettings.newSigningPolicyInitializationStartSeconds / 2) +
        epochSettings.voterRegistrationMinDurationSeconds +
        5)
  );

  const response3 = await c.flareDaemon.trigger({ gas: 20000000 });
  const logs3 = decodeRawLogs(response3, c.relay, "SigningPolicyInitialized");

  if (logs3.length == 0) {
    throw new Error("Expected signing policy to be initialized");
  } else {
    const arg = logs3[0].args;
    signingPolicies.set(1, extractSigningPolicy(arg));
  }
}

async function registerVoter(rewardEpochId: number, acc: RegisteredAccount, voterRegistry: VoterRegistryInstance) {
  const hash = web3.utils.keccak256(
    web3.eth.abi.encodeParameters(["uint24", "address"], [rewardEpochId, acc.identity.address])
  );

  const signature = web3.eth.accounts.sign(hash, acc.signingPolicy.privateKey);
  await voterRegistry.registerVoter(acc.identity.address, signature, { from: acc.submitSignatures.address });
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
