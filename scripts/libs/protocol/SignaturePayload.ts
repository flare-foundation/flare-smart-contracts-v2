import Web3 from "web3";
import { ECDSASignatureWithIndex } from "./ECDSASignatureWithIndex";
import { IPayloadMessage, PayloadMessage } from "./PayloadMessage";
import { IProtocolMessageMerkleRoot, ProtocolMessageMerkleRoot } from "./ProtocolMessageMerkleRoot";
import { ISigningPolicy } from "./SigningPolicy";
import { IECDSASignature, ECDSASignature } from "./ECDSASignature";


export interface ISignaturePayload {
  type: string;
  message: IProtocolMessageMerkleRoot;
  signature: IECDSASignature;
  unsignedMessage: string;
}

export namespace SignaturePayload {
  /**
   * Endodes signature payload into byte encoding, represented by 0x-prefixed hex string
   * @param signaturePayload
   * @returns
   */
  export function encode(signaturePayload: ISignaturePayload): string {
    const message = ProtocolMessageMerkleRoot.encode(signaturePayload.message);
    const signature = ECDSASignature.encode(signaturePayload.signature);
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
  export function decode(encodedSignaturePayload: string): ISignaturePayload {
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
      message: ProtocolMessageMerkleRoot.decode(message),
      signature: ECDSASignatureWithIndex.decode(signature),
      unsignedMessage,
    };
  }

  /**
   * Decodes properly formated signature calldata into array of payloads with signatures
   * @param calldata
   */
  export function decodeCalldata(calldata: string): IPayloadMessage<ISignaturePayload>[] {
    const calldataInternal = calldata.startsWith("0x") ? calldata.slice(2) : calldata;
    if (!(/^[0-9a-f]*$/.test(calldataInternal) && calldataInternal.length % 2 === 0)) {
      throw Error(`Invalid format - not byte sequence representing hex string: ${calldata}`);
    }
    if (calldataInternal.length < 8) {
      throw Error(`Invalid format - too short: ${calldata}`);
    }
    const strippedCalldata = "0x" + calldataInternal.slice(8);
    const signatureRecords = PayloadMessage.decode(strippedCalldata);
    const result: IPayloadMessage<ISignaturePayload>[] = [];
    for (let record of signatureRecords) {
      result.push({
        protocolId: record.protocolId,
        votingRoundId: record.votingRoundId,
        payload: SignaturePayload.decode(record.payload),
      });
    }
    return result;
  }

  /**
   *
   * @param signaturePayloads
   * @param signingPolicy
   * @returns
   */
  export function verifySignatures(
    messageHash: string,
    signatures: IECDSASignature[],
    signingPolicy: ISigningPolicy
  ): boolean {
    if (signatures.length === 0) {
      return false;
    }
    const web3 = new Web3();
    const weightMap: Map<string, number> = new Map<string, number>();
    const signerIndex: Map<string, number> = new Map<string, number>();
    for (let i = 0; i < signingPolicy.voters.length; i++) {
      weightMap.set(signingPolicy.voters[i].toLowerCase(), signingPolicy.weights[i]);
      signerIndex.set(signingPolicy.voters[i].toLowerCase(), i);
    }
    let totalWeight = 0;
    let nextAllowedSignerIndex = 0;
    for (let signature of signatures) {
      const signer = web3.eth.accounts.recover(
        messageHash,
        "0x" + signature.v.toString(16),
        signature.r,
        signature.s
      ).toLowerCase();
      const index = signerIndex.get(signer);
      if (index === undefined) {
        throw Error(`Invalid signer: ${signer}. Not in signing policy`);
      }
      if (index < nextAllowedSignerIndex) {
        throw Error(`Invalid signer sequence.`);
      }
      nextAllowedSignerIndex = index + 1;
      const weight = weightMap.get(signer);
      if (weight === undefined) { // This should not happen
        throw Error(`Invalid signer: ${signer}. Not in signing policy`);
      }
      totalWeight += weight;
      if (totalWeight >= signingPolicy.threshold) {
        return true;
      }
    }
    return false;
  }

  /**
   * Checks whether signature payloads satisfy signing policy threshold.
   * It is assumed that signature payloads have the same message and
   * are sorted according to signing policy.
   * @param signaturePayloads
   * @param signingPolicy
   * @returns
   */
  export function verifySignaturePayloads(
    signaturePayloads: IPayloadMessage<ISignaturePayload>[],
    signingPolicy: ISigningPolicy
  ): boolean {
    if (signaturePayloads.length === 0) {
      return false;
    }
    const web3 = new Web3();
    const message: IProtocolMessageMerkleRoot = signaturePayloads[0].payload.message;
    const messageHash = web3.utils.keccak256(ProtocolMessageMerkleRoot.encode(message));
    const signatures: IECDSASignature[] = [];
    for (let payload of signaturePayloads) {
      if (!ProtocolMessageMerkleRoot.equals(payload.payload.message, message)) {
        throw Error(`Invalid payload message`);
      }
      signatures.push(payload.payload.signature);
    }
    return verifySignatures(messageHash, signatures, signingPolicy);
  }

  /**
   * Sorts signature payloads according to signing policy.
   * It assumes signature payloads have the same message.
   * @param signaturePayloads
   * @param signingPolicy
   */
  export function sortSignaturePayloads(
    signaturePayloads: IPayloadMessage<ISignaturePayload>[],
    signingPolicy: ISigningPolicy
  ) {
    const signerIndex: Map<string, number> = new Map<string, number>();
    const web3 = new Web3();
    for (let i = 0; i < signingPolicy.voters.length; i++) {
      signerIndex.set(signingPolicy.voters[i].toLowerCase(), i);
    }
    signaturePayloads.sort((a, b) => {
      const messageHash = web3.utils.keccak256(ProtocolMessageMerkleRoot.encode(a.payload.message));
      const signerA = web3.eth.accounts.recover(
        messageHash,
        "0x" + a.payload.signature.v.toString(16),
        a.payload.signature.r,
        a.payload.signature.s
      ).toLowerCase();
      const signerB = web3.eth.accounts.recover(
        messageHash,
        "0x" + b.payload.signature.v.toString(16),
        b.payload.signature.r,
        b.payload.signature.s
      ).toLowerCase();
      const indexA = signerIndex.get(signerA);
      const indexB = signerIndex.get(signerB);
      if (indexA === undefined || indexB === undefined) {
        throw Error(`Invalid signer: ${signerA} or ${signerB}. Not in signing policy`);
      }
      return indexA - indexB;
    });
  }

}
