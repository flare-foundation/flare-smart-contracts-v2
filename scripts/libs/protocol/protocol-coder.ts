import { ethers } from "ethers";
import Web3 from "web3";

//////////////////////////////////////////////////////////////////////////////
// Interfaces
//////////////////////////////////////////////////////////////////////////////

export interface SigningPolicy {
  rewardEpochId: number;
  startVotingRoundId: number;
  threshold: number;
  seed: string;
  voters: string[];
  weights: number[];
}

export interface ECDSASignatureWithIndex {
  r: string;
  s: string;
  v: number;
  index: number;
}

export interface ECDSASignature {
  r: string;
  s: string;
  v: number;
}

export interface ProtocolMessageMerkleRoot {
  protocolId: number;
  votingRoundId: number;
  randomQualityScore: boolean;
  merkleRoot: string;
}

export interface PayloadMessage<T> {
  protocolId: number;
  votingRoundId: number;
  payload: T;
}

export interface SignaturePayload {
  type: string;
  message: ProtocolMessageMerkleRoot;
  signature: ECDSASignature;
  unsignedMessage: string;
}

//////////////////////////////////////////////////////////////////////////////
// Signing policy byte encoding structure
// 2 bytes - size
// 3 bytes - rewardEpochId
// 4 bytes - startingVotingRoundId
// 2 bytes - threshold
// 32 bytes - randomSeed
// array of 'size':
// - 20 bytes address
// - 2 bytes weight
// Total 43 + size * (20 + 2) bytes
//////////////////////////////////////////////////////////////////////////////

/**
 * Encodes signing policy into 0x-prefixed hex string representing byte encoding
 * @param policy
 * @returns
 */
export function encodeSigningPolicy(policy: SigningPolicy) {
  if (!policy) {
    throw Error("Signing policy is undefined");
  }
  if (!policy.voters || !policy.weights) {
    throw Error("Invalid signing policy");
  }
  if (policy.voters.length !== policy.weights.length) throw Error("Invalid signing policy");
  let signersAndWeights = "";
  const size = policy.voters.length;
  if (size > 2 ** 16 - 1) {
    throw Error("Too many signers");
  }
  for (let i = 0; i < size; i++) {
    signersAndWeights += policy.voters[i].slice(2) + policy.weights[i].toString(16).padStart(4, "0");
  }
  if (!/^0x[0-9a-f]{64}$/i.test(policy.seed)) {
    throw Error(`Invalid random seed format: ${policy.seed}`);
  }

  if (policy.rewardEpochId < 0 || policy.rewardEpochId > 2 ** 24 - 1) {
    throw Error(`Reward epoch id out of range: ${policy.rewardEpochId}`);
  }
  if (policy.startVotingRoundId < 0 || policy.startVotingRoundId > 2 ** 32 - 1) {
    throw Error(`Starting voting round id out of range: ${policy.startVotingRoundId}`);
  }
  if (policy.threshold < 0 || policy.threshold > 2 ** 16 - 1) {
    throw Error(`Threshold out of range: ${policy.threshold}`);
  }
  return (
    "0x" +
    size.toString(16).padStart(4, "0") +
    policy.rewardEpochId.toString(16).padStart(6, "0") +
    policy.startVotingRoundId.toString(16).padStart(8, "0") +
    policy.threshold.toString(16).padStart(4, "0") +
    policy.seed.slice(2) +
    signersAndWeights
  ).toLowerCase();
}

/**
 * Decodes signing policy from hex string (can be 0x-prefixed or not).
 * @param encodedPolicy
 * @returns
 */
export function decodeSigningPolicy(encodedPolicy: string): SigningPolicy {
  const encodedPolicyInternal = (encodedPolicy.startsWith("0x") ? encodedPolicy.slice(2) : encodedPolicy).toLowerCase();
  if (!/^[0-9a-f]*$/.test(encodedPolicyInternal)) {
    throw Error(`Invalid format - not hex string: ${encodedPolicy}`);
  }
  if (encodedPolicyInternal.length % 2 !== 0) {
    throw Error(`Invalid format - not even length: ${encodedPolicy.length}`);
  }
  if (encodedPolicyInternal.length < 4) {
    throw Error("Too short encoded signing policy");
  }
  const size = parseInt(encodedPolicyInternal.slice(0, 4), 16);
  const expectedLength = 86 + size * (20 + 2) * 2; //(2 + 3 + 4 + 2 + 32) * 2 = 86
  if (encodedPolicyInternal.length !== expectedLength) {
    throw Error(`Invalid encoded signing policy length: size = ${size}, length = ${encodedPolicyInternal.length}`);
  }
  const rewardEpochId = parseInt(encodedPolicyInternal.slice(4, 10), 16);
  const startingVotingRoundId = parseInt(encodedPolicyInternal.slice(10, 18), 16);
  const threshold = parseInt(encodedPolicyInternal.slice(18, 22), 16);
  const randomSeed = "0x" + encodedPolicyInternal.slice(22, 86);
  const signers: string[] = [];
  const weights: number[] = [];
  let totalWeight = 0;
  for (let i = 0; i < size; i++) {
    const start = 86 + i * 44; // 20 (address) + 2 (weight) = 44
    signers.push("0x" + encodedPolicyInternal.slice(start, start + 40));
    const weight = parseInt(encodedPolicyInternal.slice(start + 40, start + 44), 16);
    weights.push(weight);
    totalWeight += weight;
  }
  if (totalWeight > 2 ** 16 - 1) {
    throw Error(`Total weight exceeds 16-byte value: ${totalWeight}`);
  }
  return {
    rewardEpochId,
    startVotingRoundId: startingVotingRoundId,
    threshold,
    seed: randomSeed,
    voters: signers,
    weights,
  };
}

//////////////////////////////////////////////////////////////////////////////
// Signature with index structure
// 1 byte - v
// 32 bytes - r
// 32 bytes - s
// 2 byte - index in signing policy
// Total 67 bytes
//////////////////////////////////////////////////////////////////////////////

/**
 * Encodes ECDSA signature with index into 0x-prefixed hex string representing byte encoding
 * @param signature
 * @returns
 */
export function encodeECDSASignatureWithIndex(signature: ECDSASignatureWithIndex): string {
  return (
    "0x" +
    signature.v.toString(16).padStart(2, "0") +
    signature.r.slice(2) +
    signature.s.slice(2) +
    signature.index.toString(16).padStart(4, "0")
  );
}

/**
 * Encodes ECDSA signature into 0x-prefixed hex string representing byte encoding
 * @param signature 
 * @returns 
 */
export function encodeECDSASignature(signature: ECDSASignature): string {
  return (
    "0x" +
    signature.v.toString(16).padStart(2, "0") +
    signature.r.slice(2) +
    signature.s.slice(2)
  );

}

/**
 * Decodes ECDSA signature with index from hex string (can be 0x-prefixed or not).
 * @param encodedSignature
 * @returns
 */
export function decodeECDSASignatureWithIndex(encodedSignature: string): ECDSASignatureWithIndex {
  const encodedSignatureInternal = (
    encodedSignature.startsWith("0x") ? encodedSignature.slice(2) : encodedSignature
  ).toLowerCase();
  if (!/^[0-9a-f]*$/.test(encodedSignatureInternal)) {
    throw Error(`Invalid format - not hex string: ${encodedSignature}`);
  }
  if (encodedSignatureInternal.length !== 134) {
    // (1 + 32 + 32 + 2) * 2 = 134
    throw Error(`Invalid encoded signature length: ${encodedSignatureInternal.length}`);
  }
  const v = parseInt(encodedSignatureInternal.slice(0, 2), 16);
  const r = "0x" + encodedSignatureInternal.slice(2, 66);
  const s = "0x" + encodedSignatureInternal.slice(66, 130);
  const index = parseInt(encodedSignatureInternal.slice(130, 134), 16);
  return {
    v,
    r,
    s,
    index,
  };
}

//////////////////////////////////////////////////////////////////////////////
// Protocol message merkle root structure
// 1 byte - protocolId
// 4 bytes - votingRoundId
// 1 byte - randomQualityScore
// 32 bytes - merkleRoot
// Total 38 bytes
//////////////////////////////////////////////////////////////////////////////

/**
 *
 * @param message
 * @returns
 */
export function encodeProtocolMessageMerkleRoot(message: ProtocolMessageMerkleRoot): string {
  if (!message) {
    throw Error("Signed message is undefined");
  }
  if (!message.merkleRoot) {
    throw Error("Invalid signed message");
  }
  if (!/^0x[0-9a-f]{64}$/i.test(message.merkleRoot)) {
    throw Error(`Invalid merkle root format: ${message.merkleRoot}`);
  }
  if (message.protocolId < 0 || message.protocolId > 2 ** 8 - 1) {
    throw Error(`Protocol id out of range: ${message.protocolId}`);
  }
  if (message.votingRoundId < 0 || message.votingRoundId > 2 ** 32 - 1) {
    throw Error(`Voting round id out of range: ${message.votingRoundId}`);
  }
  return (
    "0x" +
    message.protocolId.toString(16).padStart(2, "0") +
    message.votingRoundId.toString(16).padStart(8, "0") +
    (message.randomQualityScore ? 1 : 0).toString(16).padStart(2, "0") +
    message.merkleRoot.slice(2)
  ).toLowerCase();
}

/**
 * Decodes signed message from hex string (can be 0x-prefixed or not).
 * @param encodedMessage
 * @returns
 */
export function decodeProtocolMessageMerkleRoot(encodedMessage: string): ProtocolMessageMerkleRoot {
  const encodedMessageInternal = encodedMessage.startsWith("0x") ? encodedMessage.slice(2) : encodedMessage;
  // (1 + 4 + 1 + 32) * 2 = 38 * 2 = 76
  if (!/^[0-9a-f]{76}$/.test(encodedMessageInternal)) {
    throw Error(`Invalid format - not hex string: ${encodedMessage}`);
  }
  const protocolId = parseInt(encodedMessageInternal.slice(0, 2), 16);
  const votingRoundId = parseInt(encodedMessageInternal.slice(2, 10), 16);
  const encodedRandomQualityScore = encodedMessageInternal.slice(10, 12);
  let randomQualityScore = false;
  if (encodedRandomQualityScore === "00") {
    randomQualityScore = false;
  } else if (encodedRandomQualityScore === "01") {
    randomQualityScore = true;
  } else {
    throw Error("Invalid random quality score");
  }
  const merkleRoot = "0x" + encodedMessageInternal.slice(12, 76);
  return {
    protocolId,
    votingRoundId,
    randomQualityScore,
    merkleRoot,
  };
}

//////////////////////////////////////////////////////////////////////////////
// Signing policy hash calculation
// It is done by padding byte array with 0 bytes to a multiple of 32 and then
// Sequentially hashing 32-byte chunks with soliditySha3
//////////////////////////////////////////////////////////////////////////////

/**
 * Calculates signing policy hash from encoded signing policy
 * @param signingPolicy
 * @returns
 */
export function signingPolicyHash(signingPolicy: string) {
  const signingPolicyInternal = signingPolicy.startsWith("0x") ? signingPolicy.slice(2) : signingPolicy;
  const splitted = signingPolicyInternal.match(/.{1,64}/g)!.map(x => x.padEnd(64, "0"))!;
  let hash: string = ethers.keccak256("0x" + splitted[0] + splitted[1])!;
  for (let i = 2; i < splitted!.length; i++) {
    hash = ethers.keccak256("0x" + hash.slice(2) + splitted[i])!;
  }
  return hash;
}

/**
 * Signs message hash with ECDSA using private key
 * @param messageHash 
 * @param privateKey 
 * @param index 
 * @returns 
 */
export async function signMessageHashECDSAWithIndex(
  messageHash: string,
  privateKey: string,
  index: number
): Promise<ECDSASignatureWithIndex> {
  if (!/^0x[0-9a-f]{64}$/i.test(messageHash)) {
    throw Error(`Invalid message hash format: ${messageHash}`);
  }
  const web3 = new Web3();
  let signatureObject = web3.eth.accounts.sign(messageHash, privateKey);
  return {
    v: parseInt(signatureObject.v.slice(2), 16),
    r: signatureObject.r,
    s: signatureObject.s,
    index,
  } as ECDSASignatureWithIndex;

  // The next code occasionally does not work well
  // Example is first private key and the message:
  // {
  //   protocolId: 15,
  //   votingRoundId: 4111,
  //   randomQualityScore: true,
  //   merkleRoot: '0x29c81c1d44d6d822982fa1d09e09bde8db25fb8df6cd03b6e8d6c3bea1d512f6'
  // }
  // TODO: find out why

  /*
  const wallet = new ethers.Wallet(privateKey);
  const sigBytes = await wallet.signMessage(ethers.toBeArray(messageHash));
  const sig = ethers.Signature.from(sigBytes);
  console.log("SIG")
  console.dir(sig)
  return {
    v: sig.v,
    r: sig.r,
    s: sig.s,
    index,
  };
  */
}

/**
 * Encodes data in byte sequence that can be concatenated with other encoded data for use in submission functions in
 * Submission.sol contract
 * @param protocolId 
 * @param votingRoundRoundId 
 * @param payload 
 * @returns 
 */
export function encodeBeforeConcatenation(payloadMessage: PayloadMessage<string>): string {
  if (payloadMessage.protocolId < 0 || payloadMessage.protocolId > 2 ** 8 - 1) {
    throw Error(`Protocol id out of range: ${payloadMessage.protocolId}`);
  }
  if (payloadMessage.votingRoundId < 0 || payloadMessage.votingRoundId > 2 ** 32 - 1) {
    throw Error(`Voting round id out of range: ${payloadMessage.votingRoundId}`);
  }
  if (!/^0x[0-9a-f]*$/i.test(payloadMessage.payload)) {
    throw Error(`Invalid payload format: ${payloadMessage.payload}`);
  }
  return (
    "0x" +
    payloadMessage.protocolId.toString(16).padStart(2, "0") +
    payloadMessage.votingRoundId.toString(16).padStart(8, "0") +
    (payloadMessage.payload.slice(2).length / 2).toString(16).padStart(4, "0") +
    payloadMessage.payload.slice(2)
  ).toLowerCase();
}

/**
 * Decodes data from concatenated byte sequence
 * @param message 
 * @returns 
 */
export function prefixDecodeEncodingBeforeConcatenation(message: string): PayloadMessage<string>[] {
  const messageInternal = message.startsWith("0x") ? message.slice(2) : message;
  if (!/^[0-9a-f]*$/.test(messageInternal)) {
    throw Error(`Invalid format - not hex string: ${message}`);
  }
  if (messageInternal.length % 2 !== 0) {
    throw Error(`Invalid format - not even length: ${message.length}`);
  }
  let i = 0;
  let result: PayloadMessage<string>[] = [];
  while (i < messageInternal.length) {
    // 14 = 2 + 8 + 4
    if (messageInternal.length - i < 14) {
      throw Error(`Invalid format - too short. Error at ${i} of ${message.length}`);
    }
    const protocolId = parseInt(messageInternal.slice(i, i + 2), 16);
    const votingRoundId = parseInt(messageInternal.slice(i + 2, i + 10), 16);
    const payloadLength = parseInt(messageInternal.slice(i + 10, i + 14), 16);
    const payload = "0x" + messageInternal.slice(i + 14, i + 14 + payloadLength * 2);
    if (payloadLength * 2 + 14 > messageInternal.length - i) {
      throw Error(`Invalid format - too short: ${message.length}`);
    }
    i += payloadLength * 2 + 14;
    result.push({
      protocolId,
      votingRoundId,
      payload,
    });
  }
  return result;
}

/**
 * Endodes signature payload into byte encoding, represented by 0x-prefixed hex string
 * @param signaturePayload 
 * @returns 
 */
export function encodeSignaturePayload(signaturePayload: SignaturePayload): string {
  const message = encodeProtocolMessageMerkleRoot(signaturePayload.message);
  const signature = encodeECDSASignature(signaturePayload.signature);
  return (
    "0x" +
    signaturePayload.type.slice(2) +
    message.slice(2) +
    signature.slice(2) +
    signaturePayload.unsignedMessage.slice(2)
  ).toLowerCase();
}

/**
 * Decodes signature payload from byte encoding, represented by 0x-prefixed hex string
 * @param encodedSignaturePayload 
 * @returns 
 */
export function decodeSignaturePayload(encodedSignaturePayload: string): SignaturePayload {
  const encodedSignaturePayloadInternal = encodedSignaturePayload.startsWith("0x")
    ? encodedSignaturePayload.slice(2)
    : encodedSignaturePayload;
  if (!/^[0-9a-f]*$/.test(encodedSignaturePayloadInternal)) {
    throw Error(`Invalid format - not hex string: ${encodedSignaturePayload}`);
  }
  if (encodedSignaturePayloadInternal.length < 2 + 38 * 2 + 65 * 2) {
    throw Error(`Invalid format - too short: ${encodedSignaturePayload}`);
  }
  const type = "0x" + encodedSignaturePayloadInternal.slice(0, 2);
  const message = "0x" + encodedSignaturePayloadInternal.slice(2, 2 + 38 * 2);
  const signature = "0x" + encodedSignaturePayloadInternal.slice(2 + 38 * 2, 2 + 38 * 2 + 65 * 2);
  const unsignedMessage = "0x" + encodedSignaturePayloadInternal.slice(2 + 38 * 2 + 65 * 2);
  return {
    type,
    message: decodeProtocolMessageMerkleRoot(message),
    signature: decodeECDSASignatureWithIndex(signature),
    unsignedMessage,
  };
}

/**
 * Decodes properly formated signature calldata into array of payloads with signatures
 * @param calldata 
 */
export function decodeSignatureCalldata(calldata: string): PayloadMessage<SignaturePayload>[] {
  const calldataInternal = calldata.startsWith("0x") ? calldata.slice(2) : calldata;
  if (!(/^[0-9a-f]*$/.test(calldataInternal) && calldataInternal.length % 2 === 0)) {
    throw Error(`Invalid format - not byte sequence representing hex string: ${calldata}`);
  }
  if (calldataInternal.length < 8) {
    throw Error(`Invalid format - too short: ${calldata}`);
  }
  const strippedCalldata = "0x" + calldataInternal.slice(8);
  const signatureRecords = prefixDecodeEncodingBeforeConcatenation(strippedCalldata);
  const result: PayloadMessage<SignaturePayload>[] = [];
  for(let record of signatureRecords) {
    result.push({
      protocolId: record.protocolId,
      votingRoundId: record.votingRoundId,
      payload: decodeSignaturePayload(record.payload),
    })
  }
  return result;
}