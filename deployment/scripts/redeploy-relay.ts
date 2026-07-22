/**
 * This script will deploy new relay contract.
 */

import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { ChainParameters } from '../chain-config/chain-parameters';
import { Contracts } from "./Contracts";
import { spewNewContractInfo } from './deploy-utils';
import { RelayInitialConfig } from '../utils/RelayInitialConfig';
import { FlareSystemsManagerContract, FlareSystemsManagerInstance, RelayContract } from '../../typechain-truffle';
import { Account } from 'web3-core';

export async function redeployRelay(
  hre: HardhatRuntimeEnvironment,
  contracts: Contracts,
  parameters: ChainParameters,
  quiet: boolean = false
) {
  const web3 = hre.web3;
  const artifacts = hre.artifacts;

  const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

  const Relay = artifacts.require("Relay") as RelayContract;
  const FlareSystemsManager = artifacts.require("FlareSystemsManager") as FlareSystemsManagerContract;

  // Define accounts in play for the deployment process
  let deployerAccount: Account;

  try {
    deployerAccount = web3.eth.accounts.privateKeyToAccount(parameters.deployerPrivateKey);
  } catch (e) {
    throw Error("Check .env file, if the private keys are correct and are prefixed by '0x'.\n" + String(e))
  }

  // Wire up the default account that will do the deployment
  web3.eth.defaultAccount = deployerAccount.address;

  const flareSystemsManager: FlareSystemsManagerInstance = await FlareSystemsManager.at(contracts.getContractAddress(Contracts.FLARE_SYSTEMS_MANAGER));
  const oldRelay = await Relay.at(contracts.getContractAddress(Contracts.RELAY));

  const nextRewardEpochId = (await flareSystemsManager.getCurrentRewardEpochId()).toNumber() + 1;
  const startVotingRoundId = await flareSystemsManager.getStartVotingRoundId(nextRewardEpochId);
  // RLY-23 MIGRATION NOTE: the new Relay stores/verifies CHAIN-BOUND policy hashes
  // (keccak256(chainid ‖ contentHash)). If `oldRelay` predates RLY-23, its getter returns the bare
  // content hash and the value below MUST be wrapped once with chainBoundHash(hash, chainId)
  // (scripts/libs/protocol/ChainDomain.ts) before deployment; if `oldRelay` is already RLY-23,
  // the value is already chain-bound and must NOT be wrapped again. Decide at cutover time.
  const signingPolicyHash = await oldRelay.toSigningPolicyHash(nextRewardEpochId);
  const relayInitialConfig: RelayInitialConfig = {
    initialRewardEpochId: nextRewardEpochId,
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

  const relay = await Relay.new(
    relayInitialConfig,
    flareSystemsManager.address,
    oldRelay.address
  );
  spewNewContractInfo(contracts, null, Relay.contractName, `Relay.sol`, relay.address, quiet);

  contracts.serialize();
  if (!quiet) {
    console.error("Deploy complete.");
  }
}

