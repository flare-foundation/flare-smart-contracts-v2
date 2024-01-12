import { DataSource } from "typeorm";
import { Logger } from "winston";
import { sleep } from "../../../deployment/tasks/run-simulation";
import { EpochSettings } from "../../../deployment/utils/EpochSettings";
import { TLPEvents, TLPTransaction } from "../../../deployment/utils/indexer/Entity";
import { getDataSource } from "../../../deployment/utils/indexer/data-source";
import { getLogger } from "../../../deployment/utils/logger";
import { ProtocolMessageMerkleRoot } from "../protocol/ProtocolMessageMerkleRoot";
import { ISignaturePayload, SignaturePayload } from "../protocol/SignaturePayload";
import { ISigningPolicy, SigningPolicy } from "../protocol/SigningPolicy";
import { Queue } from "./Queue";
import { RELAY_SELECTOR, SUBMIT_SIGNATURES_SELECTOR, THRESHOLD_INCREASE_BIPS, decodeEvent, eventSignature, eventToSigningPolicy, extractEpochSettings } from "./mock-test-helpers";

const SUMMARY_RANGE = 4
export interface QueueEntry {
  votingRoundId: number;
  protocolId: number;
  messageHash: string;
}
export interface SigningPolicyUse {
  signingPolicy: ISigningPolicy
  threshold: number;
}

export class MockFinalizer {
  dataSource!: DataSource;
  epochSettings!: EpochSettings;
  logger!: Logger;
  constructor(
    public privateKey: string,
    public web3: Web3,
    public submissionContractAddress: string,
    public relayContractAddress: string,
    public flareSystemManagerAddress: string,
    public historySec = 60 * 5, // 5 minutes
    public indexerRefreshWindowSec = 3, // 3 seconds
  ) {
    this.logger = getLogger(`finalizer`);
  }

  // votingRoundId => protocolId => messageHash => SignaturePayload[]
  results = new Map<number, Map<number, Map<string, ISignaturePayload[]>>>();
  weights = new Map<number, Map<number, Map<string, number>>>();
  // How many signatures in the list are needed to finalize the message
  // if 0 or undefined, then the message does not have enough signatures
  thresholdReached = new Map<number, Map<number, Map<string, number>>>();

  // rewardEpochId => (voterAddress => index)
  voterToIndexMaps = new Map<number, Map<string, number>>();
  voterToWeightMaps = new Map<number, Map<string, number>>();
  // rewardEpochId => ISigningPolicy
  signingPolicies = new Map<number, ISigningPolicy>();
  // votingRoundId => protocolId => boolean
  processed = new Map<number, Map<number, boolean>>();
  queue = new Queue<QueueEntry>();

  minRewardEpochSigningPolicy = -1;
  maxRewardEpochSigningPolicy = -1;


  getMatchingSigningPolicy(votingRoundId: number): SigningPolicyUse | undefined {
    if (this.minRewardEpochSigningPolicy < 0) {
      this.logger?.info(`No signing policies yet`);
      return undefined;
    }
    let minStartVotingEpochId = this.signingPolicies.get(this.minRewardEpochSigningPolicy)!.startVotingRoundId;
    if (votingRoundId < minStartVotingEpochId) {
      this.logger.info(`Below`);
      return undefined;
    }
    let maxStartVotingEpochId = this.signingPolicies.get(this.maxRewardEpochSigningPolicy)!.startVotingRoundId;
    if (votingRoundId > maxStartVotingEpochId) {
      const expectedRewardEpoch = this.epochSettings.expectedRewardEpochForVotingRoundId(votingRoundId);
      if (expectedRewardEpoch == this.maxRewardEpochSigningPolicy) {
        return {
          signingPolicy: this.signingPolicies.get(this.maxRewardEpochSigningPolicy)!,
          threshold: this.signingPolicies.get(this.maxRewardEpochSigningPolicy)!.threshold
        }
      }
      if (expectedRewardEpoch == this.maxRewardEpochSigningPolicy + 1) {
        return {
          signingPolicy: this.signingPolicies.get(this.maxRewardEpochSigningPolicy)!,
          threshold: Math.floor(this.signingPolicies.get(this.maxRewardEpochSigningPolicy)!.threshold * THRESHOLD_INCREASE_BIPS / 10000)
        }
      }
      this.logger.info(`Above: votingRoundId: ${votingRoundId}, maxStartVotingEpochId: ${maxStartVotingEpochId}, expectedRewardEpoch: ${expectedRewardEpoch}`);
      return undefined;
    }
    // TODO: use binary search to optimize
    let rewardEpochId = this.minRewardEpochSigningPolicy;
    while (votingRoundId < this.signingPolicies.get(rewardEpochId)!.startVotingRoundId) rewardEpochId++;
    return {
      signingPolicy: this.signingPolicies.get(rewardEpochId)!,
      threshold: this.signingPolicies.get(rewardEpochId)!.threshold
    }
  }

  recordProcessed(entry: QueueEntry) {
    if (!this.processed.has(entry.votingRoundId)) {
      this.processed.set(entry.votingRoundId, new Map<number, boolean>());
    }
    this.processed.get(entry.votingRoundId)!.set(entry.protocolId, true);
  }

  recentProcessedSummary(lastVotingRoundId: number): string {
    let result = "Processed:";
    for (const [votingRoundId, protocolIdToProcessed] of this.processed.entries()) {
      if (votingRoundId > lastVotingRoundId) {
        let processedProtocolIds: number[] = []
        for (const [protocolId, processed] of protocolIdToProcessed.entries()) {
          if (processed) {
            processedProtocolIds.push(protocolId);
          }
        }
        processedProtocolIds.sort();
        result += ` ${votingRoundId}: ${processedProtocolIds.join(", ")} |`;
      }
    }
    return result;
  }

  async processQueue() {
    while (this.queue.size > 0) {
      const entry = this.queue.shift();
      const signaturePayloads = this.results.get(entry.votingRoundId)?.get(entry.protocolId)?.get(entry.messageHash);
      const matchingSigningPolicy = this.getMatchingSigningPolicy(entry.votingRoundId);

      if (!signaturePayloads) {
        throw new Error(`No signature payloads for votingRoundId: ${entry.votingRoundId}, protocolId: ${entry.protocolId}`);
      }

      const messageData = signaturePayloads[0].message;
      const fullMessage = ProtocolMessageMerkleRoot.encode(messageData).slice(2);
      const signatures = SignaturePayload.encodeForRelay(signaturePayloads).slice(2);
      const signingPolicy = SigningPolicy.encode(matchingSigningPolicy!.signingPolicy).slice(2);
      const fullData = signingPolicy + fullMessage + signatures;

      try {
        const receipt = await web3.eth.sendTransaction({
          from: this.web3.eth.accounts.privateKeyToAccount(this.privateKey).address,
          to: this.relayContractAddress,
          data: RELAY_SELECTOR + fullData,
        });
        this.recordProcessed(entry);
        this.logger.info(`Finalized: ${ProtocolMessageMerkleRoot.print(messageData)}`);
      } catch (e) {
        this.logger.error(`Error finalizing ${ProtocolMessageMerkleRoot.print(messageData)}. Skipped`);
        this.logger.error(`ERROR: ${e}`);
      }
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
    const signingPolicyEvents = queryResult.map((event) => decodeEvent("Relay", "SigningPolicyInitialized", event));
    return signingPolicyEvents.map(event => eventToSigningPolicy(event));
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

  public processSigningPolicies(newSigningPolicies: ISigningPolicy[]) {
    newSigningPolicies.sort((a, b) => a.rewardEpochId - b.rewardEpochId);
    for (const signingPolicy of newSigningPolicies) {
      if (!this.signingPolicies.has(signingPolicy.rewardEpochId)) {
        if (this.signingPolicies.size === 0 || this.signingPolicies.get(signingPolicy.rewardEpochId - 1) !== undefined) {
          if (this.signingPolicies.get(signingPolicy.rewardEpochId) !== undefined) {
            // Already processed
            continue;
          }
          if (this.minRewardEpochSigningPolicy === -1) {
            this.minRewardEpochSigningPolicy = signingPolicy.rewardEpochId;
          }
          this.signingPolicies.set(signingPolicy.rewardEpochId, signingPolicy);
          this.maxRewardEpochSigningPolicy = signingPolicy.rewardEpochId;

          let voterToIndex = new Map<string, number>();
          let voterToWeight = new Map<string, number>();
          for (let i = 0; i < signingPolicy.voters.length; i++) {
            voterToIndex.set(signingPolicy.voters[i], i);
            voterToWeight.set(signingPolicy.voters[i], signingPolicy.weights[i]);
          }
          this.voterToIndexMaps.set(signingPolicy.rewardEpochId, voterToIndex);
          this.voterToWeightMaps.set(signingPolicy.rewardEpochId, voterToWeight);
        } else {
          throw new Error(`Missing signing policy for epoch ${signingPolicy.rewardEpochId - 1}`)
        }
      }
    }
  }

  public processSignaturePayloads(signaturePayloads: ISignaturePayload[]) {
    for (const payload of signaturePayloads) {
      const votingRoundId = payload.message.votingRoundId;
      const protocolId = payload.message.protocolId;
      const matchingSigningPolicy = this.getMatchingSigningPolicy(votingRoundId);
      if (!matchingSigningPolicy) {
        this.logger.info(`No signing policy for votingRoundId: ${votingRoundId}. Expected reward epoch: ${this.epochSettings.expectedRewardEpochForVotingRoundId(votingRoundId)}`);
        return;
      }
      const voterToIndexMap = this.voterToIndexMaps.get(matchingSigningPolicy!.signingPolicy.rewardEpochId!);
      const augPayload = SignaturePayload.augment(payload, voterToIndexMap!);
      if (augPayload.signer === undefined) {
        this.logger.info(`Signer not in the singing policy for rewardEpochId: ${matchingSigningPolicy!.signingPolicy.rewardEpochId!}.`);
        return;
      }
      const messageHash = augPayload.messageHash;
      if (!messageHash) {
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

      if (inserted) {
        // check if threshold reached
        const voterToWeightMap = this.voterToWeightMaps.get(matchingSigningPolicy!.signingPolicy.rewardEpochId!);
        let totalWeight = 0;
        for (const payload of sortedList) {
          totalWeight += voterToWeightMap!.get(payload.signer!)!;
        }
        // this.logger.info(`Total weight: ${totalWeight} (${votingRoundId}, ${protocolId}, ${messageHash}))`);
        this.weights.get(votingRoundId)!.get(protocolId)!.set(messageHash, totalWeight);
        if (totalWeight > matchingSigningPolicy.threshold) {
          if (!this.thresholdReached.has(votingRoundId)) {
            this.thresholdReached.set(votingRoundId, new Map<number, Map<string, number>>());
          }
          if (!this.thresholdReached.get(votingRoundId)!.has(protocolId)) {
            this.thresholdReached.get(votingRoundId)!.set(protocolId, new Map<string, number>());
          }
          if (this.thresholdReached!.get(votingRoundId)!.get(protocolId)!.has(messageHash)) {
            // no need for entering the queue again
            return;
          }
          this.thresholdReached.get(votingRoundId)!.get(protocolId)!.set(messageHash, sortedList.length);
          this.queue.push({
            votingRoundId,
            protocolId,
            messageHash
          });
        }
      }
    }
  }

  public logStatus() {
    const expectedRewardEpochId = this.epochSettings.expectedRewardEpochForVotingRoundId(this.epochSettings.votingEpochForTime(Date.now()))
    this.logger.info("---------------------------------------")
    this.logger.info(`Expected reward epoch: ${expectedRewardEpochId}`);
    this.logger.info(`Signing policies: ${this.signingPolicies.size} [${this.minRewardEpochSigningPolicy}, ${this.maxRewardEpochSigningPolicy}]`);
    this.logger.info(`${this.recentProcessedSummary(expectedRewardEpochId - SUMMARY_RANGE)}`);
  }

  public async run() {
    this.dataSource = await getDataSource(true);
    this.epochSettings = await extractEpochSettings(this.flareSystemManagerAddress);
    let endTimeSec = Math.floor(Date.now() / 1000);
    let startTimeSec = endTimeSec - this.historySec;  // start one minute ago
    let newSigningPolicies = await this.querySigningPolicies(startTimeSec, endTimeSec);
    this.processSigningPolicies(newSigningPolicies);
    let signaturePayloads = await this.querySignaturePayloads(startTimeSec, endTimeSec);
    startTimeSec = endTimeSec - this.indexerRefreshWindowSec;
    this.processSignaturePayloads(signaturePayloads);
    setInterval(() => this.logStatus(), 5000)
    while (true) {
      endTimeSec = Math.floor(Date.now() / 1000);
      newSigningPolicies = await this.querySigningPolicies(startTimeSec, endTimeSec);
      this.processSigningPolicies(newSigningPolicies);
      signaturePayloads = await this.querySignaturePayloads(startTimeSec, endTimeSec);
      this.processSignaturePayloads(signaturePayloads);
      startTimeSec = endTimeSec - this.indexerRefreshWindowSec;
      await this.processQueue()
      await sleep(500);
    }

  }
}
