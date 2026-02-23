/**
 * This script will deploy new relay contract.
 */

import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { ChainParameters } from '../chain-config/chain-parameters';
import { Contracts } from "./Contracts";
import { spewNewContractInfo } from './deploy-utils';
import { RelayInitialConfig } from '../utils/RelayInitialConfig';
import { RelayContract } from '../../typechain-truffle/contracts/protocol/implementation/Relay';
import { FlareSystemsManagerContract, FlareSystemsManagerInstance } from '../../typechain-truffle/contracts/protocol/implementation/FlareSystemsManager';


export async function redeployRelay(
  hre: HardhatRuntimeEnvironment,
  contracts: Contracts,
  parameters: ChainParameters,
  quiet: boolean = false
) {
  const web3 = hre.web3;
  const artifacts = hre.artifacts;
  const BN = web3.utils.toBN;

  const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

  const Relay: RelayContract = artifacts.require("Relay");
  const FlareSystemsManager: FlareSystemsManagerContract = artifacts.require("FlareSystemsManager");

  // Define accounts in play for the deployment process
  let deployerAccount: any;

  try {
    deployerAccount = web3.eth.accounts.privateKeyToAccount(parameters.deployerPrivateKey);
  } catch (e) {
    throw Error("Check .env file, if the private keys are correct and are prefixed by '0x'.\n" + e)
  }

  // Wire up the default account that will do the deployment
  web3.eth.defaultAccount = deployerAccount.address;

  const flareSystemsManager: FlareSystemsManagerInstance = await FlareSystemsManager.at(contracts.getContractAddress(Contracts.FLARE_SYSTEMS_MANAGER));
  const oldRelay = await Relay.at(contracts.getContractAddress(Contracts.RELAY));

  const nextRewardEpochId = (await flareSystemsManager.getCurrentRewardEpochId()).toNumber() + 1;
  const startVotingRoundId = await flareSystemsManager.getStartVotingRoundId(nextRewardEpochId);
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

