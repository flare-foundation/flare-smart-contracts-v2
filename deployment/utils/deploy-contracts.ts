import fs from "fs";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import {
  VoterRegistryContract,
  VoterRegistryInstance,
} from "../../typechain-truffle/contracts/protocol/implementation/VoterRegistry";
import {
  FlareSystemManagerContract,
  FlareSystemManagerInstance,
} from "../../typechain-truffle/contracts/protocol/implementation/FlareSystemManager";
import {
  SubmissionContract,
  SubmissionInstance,
} from "../../typechain-truffle/contracts/protocol/implementation/Submission";
import { RelayContract, RelayInstance } from "../../typechain-truffle/contracts/protocol/implementation/Relay";
import { ISigningPolicy } from "../../scripts/libs/protocol/SigningPolicy";
import { VPContractInstance } from "../../typechain-truffle/flattened/FlareSmartContracts.sol/VPContract";
import { WNatContract } from "../../typechain-truffle/flattened/FlareSmartContracts.sol/WNat";
import { MockContractContract } from "../../typechain-truffle/@gnosis.pm/mock-contract/contracts/MockContract.sol/MockContract";
import { GovernanceVotePowerContract } from "../../typechain-truffle/contracts/mock/GovernanceVotePower";
import { AddressBinderContract } from "../../typechain-truffle/flattened/FlareSmartContracts.sol/AddressBinder";
import { VPContractContract } from "../../typechain-truffle/flattened/FlareSmartContracts.sol/VPContract";
import { EntityManagerContract } from "../../typechain-truffle/contracts/protocol/implementation/EntityManager";
import {
  AddressBinderInstance,
  EntityManagerInstance,
  GovernanceVotePowerInstance,
  MockContractInstance,
  PChainStakeMirrorInstance,
  PChainStakeMirrorVerifierInstance,
  WNatInstance,
} from "../../typechain-truffle";

import { PChainStakeMirrorVerifierContract } from "../../typechain-truffle/contracts/protocol/implementation/PChainStakeMirrorVerifier";
import { CChainStakeContract, CChainStakeInstance } from "../../typechain-truffle/contracts/mock/CChainStake";
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
import Web3 from "web3";
import { getLogger } from "./logger";
import { executeTimelockedGovernanceCall, testDeployGovernanceSettings } from "./contract-helpers";
import { PChainStakeMirrorContract } from "../../typechain-truffle/flattened/FlareSmartContracts.sol/PChainStakeMirror";

const RANDOM_ROOT = Web3.utils.keccak256("root");
const GET_CURRENT_RANDOM_SELECTOR = Web3.utils.sha3("getCurrentRandom()")!.slice(0, 10);

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
  readonly flareSystemManager: FlareSystemManagerInstance;
  readonly submission: SubmissionInstance;
  readonly relay: RelayInstance;
}

const logger = getLogger("contracts");

export async function deployContracts(
  accounts: Account[],
  hre: HardhatRuntimeEnvironment,
  governanceAccount: Account
): Promise<[DeployedContracts, number]> {
  const FLARE_DAEMON_ADDR = governanceAccount.address;
  const ADDRESS_UPDATER_ADDR = accounts[1].address;
  const CLEANER_CONTRACT_ADDR = accounts[2].address;
  const CLEANUP_BLOCK_NUMBER_MANAGER_ADDR = accounts[3].address;
  const MULTI_SIG_VOTING_ADDR = accounts[4].address;
  const RELAY_ADDR = accounts[5].address;

  const MockContract: MockContractContract = hre.artifacts.require("MockContract");
  const WNat: WNatContract = hre.artifacts.require("WNat");
  const VPContract: VPContractContract = hre.artifacts.require("VPContract");
  const PChainStakeMirror: PChainStakeMirrorContract = hre.artifacts.require("PChainStakeMirror");
  const GovernanceVotePower: GovernanceVotePowerContract = hre.artifacts.require("GovernanceVotePower" as any);
  const AddressBinder: AddressBinderContract = hre.artifacts.require("AddressBinder");
  const PChainStakeMirrorVerifier: PChainStakeMirrorVerifierContract = artifacts.require("PChainStakeMirrorVerifier");
  const EntityManager: EntityManagerContract = hre.artifacts.require("EntityManager");
  const VoterRegistry: VoterRegistryContract = hre.artifacts.require("VoterRegistry");
  const FlareSystemManager: FlareSystemManagerContract = hre.artifacts.require("FlareSystemManager");
  const Submission: SubmissionContract = hre.artifacts.require("Submission");
  const CChainStake: CChainStakeContract = artifacts.require("CChainStake");
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
  const priceSubmitterMock = await MockContract.new();
  await priceSubmitterMock.givenMethodReturnUint(GET_CURRENT_RANDOM_SELECTOR, RANDOM_ROOT);

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
  const intialThreshold = 500;

  const voterRegistry = await VoterRegistry.new(
    governanceSettings.address,
    governanceAccount.address,
    ADDRESS_UPDATER_ADDR,
    100,
    0,
    initialVoters,
    initialWeights
  );

  const initialSigningPolicy: ISigningPolicy = {
    rewardEpochId: 0,
    startVotingRoundId: FIRST_REWARD_EPOCH_VOTING_ROUND_ID,
    threshold: intialThreshold,
    seed: web3.utils.keccak256("123"),
    voters: initialVoters,
    weights: initialWeights,
  };

  const settings = systemSettings(rewardEpochStart);
  const flareSystemManager: FlareSystemManagerInstance = await FlareSystemManager.new(
    governanceSettings.address,
    governanceAccount.address,
    ADDRESS_UPDATER_ADDR,
    FLARE_DAEMON_ADDR,
    settings,
    1,
    0,
    intialThreshold
  );

  await flareSystemManager.changeRandomProvider(true);
  const relay = await Relay.new(
    flareSystemManager.address,
    initialSigningPolicy.rewardEpochId,
    initialSigningPolicy.startVotingRoundId,
    getSigningPolicyHash(initialSigningPolicy),
    FTSO_PROTOCOL_ID,
    settings.firstVotingRoundStartTs,
    settings.votingEpochDurationSeconds,
    settings.firstRewardEpochStartVotingRoundId,
    settings.rewardEpochDurationInVotingEpochs,
    12000
  );

  const submission = await Submission.new(
    governanceSettings.address,
    governanceAccount.address,
    ADDRESS_UPDATER_ADDR,
    false
  );

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
      Contracts.FLARE_SYSTEM_MANAGER,
      Contracts.ENTITY_MANAGER,
      Contracts.WNAT,
      Contracts.P_CHAIN_STAKE_MIRROR,
    ]),
    [ADDRESS_UPDATER_ADDR, flareSystemManager.address, entityManager.address, wNat.address, pChainStakeMirror.address],
    { from: ADDRESS_UPDATER_ADDR }
  );

  await flareSystemManager.updateContractAddresses(
    encodeContractNames(hre.web3, [
      Contracts.ADDRESS_UPDATER,
      Contracts.VOTER_REGISTRY,
      Contracts.SUBMISSION,
      Contracts.RELAY,
      Contracts.PRICE_SUBMITTER,
    ]),
    [ADDRESS_UPDATER_ADDR, voterRegistry.address, submission.address, relay.address, priceSubmitterMock.address],
    { from: ADDRESS_UPDATER_ADDR }
  );

  await submission.updateContractAddresses(
    encodeContractNames(hre.web3, [Contracts.ADDRESS_UPDATER, Contracts.FLARE_SYSTEM_MANAGER, Contracts.RELAY]),
    [ADDRESS_UPDATER_ADDR, flareSystemManager.address, relay.address],
    { from: ADDRESS_UPDATER_ADDR }
  );

  await pChainStakeMirror.setCleanerContract(CLEANER_CONTRACT_ADDR);
  await pChainStakeMirror.activate();
  await cChainStake.activate();

  logger.info(
    `Finished deploying contracts:\n  FlareSystemManager: ${flareSystemManager.address},\n  Submission: ${submission.address},\n  Relay: ${relay.address}`
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
    flareSystemManager,
    submission,
    relay,
  };

  return [contracts, rewardEpochStart];
}

export function serializeDeployedContractsAddresses(contracts: DeployedContracts, fname: string) {
  const result: any = {};
  Object.entries(contracts).forEach(([name, contract]) => {
    result[contract.constructor.contractName] = (contract as any).address;
  });
  fs.writeFileSync(fname, JSON.stringify(result, null, 2));
}

