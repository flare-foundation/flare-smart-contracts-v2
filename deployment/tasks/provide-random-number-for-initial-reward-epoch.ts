import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Contracts } from "../scripts/Contracts";
import { ChainParameters } from "../chain-config/chain-parameters";
import { FlareSystemsManagerContract } from "../../typechain-truffle/contracts/protocol/implementation/FlareSystemsManager";
import { RelayContract } from "../../typechain-truffle/contracts/protocol/implementation/Relay";
import { ISigningPolicy } from "../../scripts/libs/protocol/SigningPolicy";
import { IProtocolMessageMerkleRoot, ProtocolMessageMerkleRoot } from "../../scripts/libs/protocol/ProtocolMessageMerkleRoot";
import { generateSignatures } from "../../test/unit/protocol/coding/coding-helpers";
import { RelayMessage } from "../../scripts/libs/protocol/RelayMessage";

/**
 * This script will provide a random number for initial reward epoch.
 * It assumes that all contracts have been deployed and contract addresses
 * provided in Contracts object.
 * @dev Do not send anything out via console.log unless it is json defining the created contracts.
 */
export async function provideRandomNumberForInitialRewardEpoch(
  hre: HardhatRuntimeEnvironment,
  initialVoterPrivateKey: string,
  triggerFlareDaemon: boolean,
  contracts: Contracts,
  parameters: ChainParameters,
  quiet: boolean = false) {

  const web3 = hre.web3;
  const artifacts = hre.artifacts;

  if (!quiet) {
    console.error("Providing random number for initial reward epoch...");
  }

  const initialVoter = parameters.initialVoters[0];

  // Wire up the default account that will send the transactions
  web3.eth.defaultAccount = initialVoter;

  // Get contract definitions
  const FlareSystemsManager: FlareSystemsManagerContract = artifacts.require("FlareSystemsManager");
  const Relay: RelayContract = artifacts.require("Relay");

  // Fetch contracts
  const flareSystemsManager = await FlareSystemsManager.at(contracts.getContractAddress(Contracts.FLARE_SYSTEMS_MANAGER));
  const relay = await Relay.at(contracts.getContractAddress(Contracts.RELAY));

  const RELAY_SELECTOR = web3.utils.sha3("relay()")!.slice(0, 10); // first 4 bytes is function selector
  const TRIGGER_SELECTOR = web3.utils.sha3("trigger()")!.slice(0, 10); // first 4 bytes is function selector
  const ZERO_BYTES32 = "0x0000000000000000000000000000000000000000000000000000000000000000";

  const initialRewardEpochId = (await flareSystemsManager.getCurrentRewardEpochId()).toNumber();
  const flareDaemonAddress = await flareSystemsManager.flareDaemon();
  const initialRewardEpochStartVotingRoundId = (await relay.startingVotingRoundIds(initialRewardEpochId)).toNumber();

  console.error(`Current reward epoch id: ${initialRewardEpochId}.`);
  console.error(`Current reward epoch start voting round id: ${initialRewardEpochStartVotingRoundId}.`);
  console.error(`Current reward epoch expected end timestamp: ${(await flareSystemsManager.currentRewardEpochExpectedEndTs()).toString()}.`);

  const initialSigningPolicy: ISigningPolicy = {
    rewardEpochId: initialRewardEpochId,
    startVotingRoundId: initialRewardEpochStartVotingRoundId,
    threshold: parameters.initialThreshold,
    seed: web3.utils.keccak256("123"),
    voters: parameters.initialVoters,
    weights: parameters.initialNormalisedWeights
  };

  while (true) {
    if (triggerFlareDaemon) {
      await web3.eth.sendTransaction({
        from: initialVoter,
        to: flareDaemonAddress,
        data: TRIGGER_SELECTOR,
        gas: 100000000
      });
      console.error("Flare daemon triggered successfully.");
    }
    const latestBlock = await web3.eth.getBlock(await web3.eth.getBlockNumber());
    console.error(`Latest block timestamp: ${latestBlock.timestamp}.`);
    const rai = await flareSystemsManager.getRandomAcquisitionInfo(initialRewardEpochId + 1);
    if (rai[0].toString() !== "0") {
      if (rai[2].toString() !== "0") {
        if (!quiet) {
          console.error("Random number for initial reward epoch submitted successfully.");
        }
        break;
      }
      const votingRoundId = (await relay.getVotingRoundId(latestBlock.timestamp)).toNumber();
      const merkleRootHash = await relay.getConfirmedMerkleRoot(parameters.ftsoProtocolId, votingRoundId);
      if (merkleRootHash === ZERO_BYTES32) {
        const random = Math.floor(Math.random() * 1e6);
        const merkleRoot = web3.utils.keccak256(web3.eth.abi.encodeParameters(
          ["tuple(uint32,uint256,bool)"],
          [[votingRoundId, random, true]]));
        const messageData: IProtocolMessageMerkleRoot = { protocolId: parameters.ftsoProtocolId, votingRoundId: votingRoundId, isSecureRandom: true, merkleRoot: merkleRoot };
        const messageHash = ProtocolMessageMerkleRoot.hash(messageData);
        const signatures = await generateSignatures([initialVoterPrivateKey], messageHash, 1);

        const relayMessage = {
            signingPolicy: initialSigningPolicy,
            signatures,
            protocolMessageMerkleRoot: messageData,
        };

        const fullData = RelayMessage.encode(relayMessage);

        await web3.eth.sendTransaction({
            from: initialVoter,
            to: relay.address,
            data: RELAY_SELECTOR + fullData.slice(2)
        });

        console.error(`Providing random number for voting round id: ${votingRoundId}.`);
      }
    }
    await sleep(5000);
  }
}

async function sleep(ms: number) {
  await new Promise<void>(resolve => setTimeout(() => resolve(), ms));
}