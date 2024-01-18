import fs from "fs";
import { TLPEvents } from "../../../deployment/utils/indexer/Entity";
import { FlareSystemManagerContract, FlareSystemManagerInstance } from "../../../typechain-truffle";
import { EpochSettings } from "../../../deployment/utils/EpochSettings";
import { ISigningPolicy } from "../protocol/SigningPolicy";

export const DEPLOY_ADDRESSES_FILE = "./db/deployed-addresses.json";

export const SUBMIT_SIGNATURES_SELECTOR = web3.utils.sha3("submitSignatures()")!.slice(0, 10);
export const RELAY_SELECTOR = web3.utils.sha3("relay()")!.slice(0, 10);
export const THRESHOLD_INCREASE_BIPS = 12000;
export function eventSignature(contractName: string, eventName: string): string {
  const contract = artifacts.require(contractName as any);
  return Object.entries(contract.events!).find((x: any) => x[1].name === eventName)![0];
}

function prefix0x(hex: string): string {
  return hex.startsWith("0x") ? hex : "0x" + hex;
}

export function decodeEvent(contractName: string, eventName: string, data: TLPEvents): any {
  const contract = artifacts.require(contractName as any);
  const signature = eventSignature(contractName, eventName);
  let abi = (Object.entries(contract.events!).find((x: any) => x[1].name === eventName)![1]! as any).inputs;
  return web3.eth.abi.decodeLog(
    abi,
    prefix0x(data.data),
    [prefix0x(data.topic0), prefix0x(data.topic1), prefix0x(data.topic2), prefix0x(data.topic3)].filter(x => x)
  );
}

export function contractAddress(contractName: string): string {
  const addresses = JSON.parse(fs.readFileSync(DEPLOY_ADDRESSES_FILE).toString());
  return addresses[contractName];
}

const FlareSystemManager: FlareSystemManagerContract = artifacts.require("FlareSystemManager");

export async function extractEpochSettings(flareSystemManagerAddress: string): Promise<EpochSettings> {
  const flareSystemManager: FlareSystemManagerInstance = await FlareSystemManager.at(flareSystemManagerAddress);
  return new EpochSettings(
    (await flareSystemManager.firstRewardEpochStartTs()).toNumber(),
    (await flareSystemManager.rewardEpochDurationSeconds()).toNumber(),
    (await flareSystemManager.firstVotingRoundStartTs()).toNumber(),
    (await flareSystemManager.votingEpochDurationSeconds()).toNumber(),
    (await flareSystemManager.newSigningPolicyInitializationStartSeconds()).toNumber(),
    (await flareSystemManager.voterRegistrationMinDurationSeconds()).toNumber(),
    (await flareSystemManager.voterRegistrationMinDurationBlocks()).toNumber()
  );
}

const privateKeys = JSON.parse(fs.readFileSync("./deployment/test-1020-accounts.json").toString());
const addressMap: Map<string, string> = new Map<string, string>();
privateKeys.forEach((x: any) => addressMap.set(web3.eth.accounts.privateKeyToAccount(x.privateKey).address.toLowerCase(), x.privateKey));

export function privateKeysForAddresses(addresses: string[]): string[] {  
  return addresses.map(address => addressMap.get(address.toLowerCase())!);
}


export const FIXED_TEST_VOTERS = [
  "0x3d91185a02774C70287F6c74Dd26d13DFB58ff16",
  "0x0a057a7172d0466AEF80976D7E8c80647DfD35e3",
  "0x650240A1F1024Fe55e6F2ed56679aB430E338581",
  "0x2E3bfF5d8F20FDb941adC794F9BF3deA0416988f"
];

export function eventToSigningPolicy(event: any): ISigningPolicy {
  return {
    rewardEpochId: parseInt(event.rewardEpochId),
    startVotingRoundId: parseInt(event.startVotingRoundId),
    threshold: parseInt(event.threshold),
    seed: "0x" + BigInt(event.seed).toString(16).padStart(64, "0").toLowerCase(),
    voters: event.voters.map((x: any) => x.toLowerCase()),
    weights: event.weights.map((x: any) => parseInt(x))  
  } as ISigningPolicy
}
