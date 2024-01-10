import { DataSource } from "typeorm";
import { sleep } from "../../../deployment/tasks/run-simulation";
import { EpochSettings } from "../../../deployment/utils/EpochSettings";
import { TLPEvents, TLPTransaction } from "../../../deployment/utils/indexer/Entity";
import { getDataSource } from "../../../deployment/utils/indexer/data-source";
import { IPayloadMessage, PayloadMessage } from "../protocol/PayloadMessage";
import { ISignaturePayload, SignaturePayload } from "../protocol/SignaturePayload";
import { ISigningPolicy } from "../protocol/SigningPolicy";
import { Queue } from "./Queue";
import { FIXED_TEST_VOTERS, SUBMIT_SIGNATURES_SELECTOR, eventSignature, extractEpochSettings } from "./mock-test-helpers";

const fixedTestVotersMap = new Map<string, number>();
for (let i = 0; i < FIXED_TEST_VOTERS.length; i++) {
  fixedTestVotersMap.set(FIXED_TEST_VOTERS[i].toLowerCase(), i);
}

export interface QueueEntry {
  votingRoundId: number;
  protocolId: number;
  messageHash: string;
}

export class MockFinalizer {
  dataSource!: DataSource;
  epochSettings!: EpochSettings;
  constructor(
    public privateKey: string,
    public web3: Web3,
    public submissionContractAddress: string,
    public relayContractAddress: string,
    public flareSystemManagerAddress: string,
  ) { }

  // votingRoundId => protocolId => messageHahs => SignaturePayload[]
  results = new Map<number, Map<number, Map<string, ISignaturePayload[]>>>();
  weights = new Map<number, Map<number, Map<string, number>>>();
  // rewardEpochId => (voterAddress => index)
  voterMaps = new Map<number, Map<string, number>>();
  processed = new Map<number, Map<number, boolean>>();
  queue = new Queue<QueueEntry>();
  signingPolicies = new Map<number, ISigningPolicy>();

  // votingRoundId => protocolId => boolean
  // queue: [votingRoundId, protocolId]

  getVoterMapForVotingRound(votingRoundId: number): Map<string, number> {
    // currently fixed one
    return fixedTestVotersMap;
  }

  getVotersWeightForVotingRound(voter: string, votingRoundId: number): number {
    // TODO
    return 1;
  }

  getThresholdForVotingRound(votingRoundId: number): number {
    // TODO
    return 2;
  }

  // TODO: fix for messageHash
  async processQueue() {
    while (this.queue.size > 0) {
      const entry = this.queue.shift();
      const signaturePayloads = this.results.get(entry.votingRoundId)?.get(entry.protocolId)?.get(entry.messageHash);
      if (!signaturePayloads) {
        throw new Error(`No signature payloads for votingRoundId: ${entry.votingRoundId}, protocolId: ${entry.protocolId}`);
      }
      const encodedSignaturePayloads = signaturePayloads.map((payload) => {
        const payloadMessage = {
          votingRoundId: entry.votingRoundId,
          protocolId: entry.protocolId,
          payload: SignaturePayload.encode(payload)
        } as IPayloadMessage<string>;
        return PayloadMessage.encode(payloadMessage);
      });
      const signaturesData = PayloadMessage.concatenateHexStrings(encodedSignaturePayloads);
      const receipt = await web3.eth.sendTransaction({
        from: this.web3.eth.accounts.privateKeyToAccount(this.privateKey).address,
        to: this.relayContractAddress,
        data: SUBMIT_SIGNATURES_SELECTOR + signaturesData.slice(2),
      });
      this.processed.get(entry.votingRoundId)?.set(entry.protocolId, true);
    }
  }

  public async querySigningPolicies(startTime: number, endTime: number): Promise<ISigningPolicy[]> {
    const queryResult = await this.dataSource
      .getRepository(TLPEvents)
      .createQueryBuilder("event")
      .andWhere("event.timestamp >= :startTime", { startTime })
      .andWhere("event.timestamp <= :endTime", { endTime })
      .andWhere("event.address = :contractAddress", { contractAddress: this.relayContractAddress.slice(2).toLowerCase() })
      .andWhere("event.topic0 = :signature", { signature: eventSignature("Relay", "SigningPolicyInitialized").slice(2) })
      .getMany();

    console.dir(queryResult);
    return [];
  }

  public async querySignaturePayloads(startTime: number, endTime: number): Promise<ISignaturePayload[]> {
    const queryResult = await this.dataSource
      .getRepository(TLPTransaction)
      .createQueryBuilder("tx")
      .andWhere("tx.timestamp >= :startTime", { startTime })
      .andWhere("tx.timestamp <= :endTime", { endTime })
      .andWhere("tx.to_address = :contractAddress", { contractAddress: this.submissionContractAddress.slice(2).toLowerCase() })
      .andWhere("tx.function_sig = :signature", { signature: SUBMIT_SIGNATURES_SELECTOR.slice(2).toLowerCase() })
      .getMany();
    const result: ISignaturePayload[] = [];
    queryResult.filter((tx) => tx.input.length > 8).forEach((tx) => {
      SignaturePayload.decodeCalldata(tx.input).forEach((payload) => {
        result.push(payload.payload);
      })
    });
    return result;

  }

  public processResult(signaturePayloads: ISignaturePayload[]) {
    signaturePayloads.forEach((payload) => {
      const votingRoundId = payload.message.votingRoundId;
      const protocolId = payload.message.protocolId;
      const augPayload = SignaturePayload.augment(payload, this.getVoterMapForVotingRound(votingRoundId));
      const messageHash = augPayload.messageHash;
      if(!messageHash) {
        throw new Error(`No message hash for payload: ${JSON.stringify(payload)}`);
      }
      if (!this.results.has(votingRoundId)) {
        this.results.set(votingRoundId, new Map<number, Map<string, ISignaturePayload[]>>());
        this.weights.set(votingRoundId, new Map<number, Map<string, number>>());
      }
      if (!this.results.get(votingRoundId)!.has(protocolId)) {
        this.results.get(votingRoundId)!.set(protocolId, new Map<string, ISignaturePayload[]>());
        this.weights.get(votingRoundId)!.set(protocolId, new Map<string, number>());
      }
      if (!this.results.get(votingRoundId)!.get(protocolId)!.has(messageHash)) {
        this.results.get(votingRoundId)!.get(protocolId)!.set(messageHash, []);
        this.weights.get(votingRoundId)!.get(protocolId)!.set(messageHash, 0);
      }
      let sortedList = this.results.get(votingRoundId)!.get(protocolId)!.get(messageHash)!;
      const inserted = SignaturePayload.insertInSigningPolicySortedList(sortedList, augPayload);
      // TODO
      if (inserted) {
        // TODO: log if logging enabled
        // check if threshold reached
        let totalWeight = 0;
        for(const payload of sortedList) {
          totalWeight += this.getVotersWeightForVotingRound(payload.signer!, votingRoundId);
        }
        this.weights.get(votingRoundId)!.get(protocolId)!.set(messageHash, totalWeight);
        if (totalWeight >= this.getThresholdForVotingRound(votingRoundId)) {
          this.queue.push({
            votingRoundId,
            protocolId,
            messageHash
          });
        }
      }
    })
  }

  public printStatus() {
    console.log(`Queue size: ${this.queue.size}`);
    console.log(`Processed: ${this.processed.size}`);
    console.log(`Results: ${this.results.size}`);
  }

  public async run() {
    this.dataSource = await getDataSource(true);
    this.epochSettings = await extractEpochSettings(this.flareSystemManagerAddress);
    let endTimeSec = Math.floor(Date.now() / 1000);
    const indexerTimeBufferSec = 3;
    let startTimeSec = endTimeSec - 60;  // start one minute ago
    // get current reward epoch signing policies
    // 
    // await this.querySigningPolicies(fiveMinutesAgo, now);
    let result = await this.querySignaturePayloads(startTimeSec, endTimeSec);
    startTimeSec = endTimeSec - indexerTimeBufferSec;
    this.processResult(result);
    this.printStatus();
    while(true) {
      endTimeSec = Math.floor(Date.now() / 1000);
      result = await this.querySignaturePayloads(startTimeSec, endTimeSec);
      startTimeSec = endTimeSec - indexerTimeBufferSec;
      this.processResult(result);
      this.printStatus();
      await sleep(500);      
    }

  }
}
