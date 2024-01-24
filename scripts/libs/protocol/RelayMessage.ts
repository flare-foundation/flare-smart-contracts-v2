import { ethers } from "ethers";
import { ECDSASignatureWithIndex, IECDSASignatureWithIndex } from "./ECDSASignatureWithIndex";
import { IProtocolMessageMerkleRoot, ProtocolMessageMerkleRoot } from "./ProtocolMessageMerkleRoot";
import { ISigningPolicy, SigningPolicy } from "./SigningPolicy";

export interface IRelayMessage {
  signingPolicy: ISigningPolicy;
  protocolMessageMerkleRoot?: IProtocolMessageMerkleRoot;
  newSigningPolicy?: ISigningPolicy;
  signatures: IECDSASignatureWithIndex[];
}

export namespace RelayMessage {

  /**
   * Encodes relay message into 0x-prefixed hex string representing byte encoding.
   * If @param verify is true, the message is checked to be valid, throwing an error if not.
   * Validation includes:
   * - signing policy is present and valid
   * - signatures are present and valid (at least empty list)
   * - exactly one of protocol message merkle root or new signing policy is present
   * - protocol message merkle root or new signing policy is valid
   * - if new signing protocol is present, it is for the next reward epoch relative to signing policy
   * - signatures are valid according to signing policy
   * - signatures are in ascending order by index in signing policy and indices of signatures match indices in signing policy
   * - threshold is met
   * @param message 
   * @param verify 
   * @returns 
   */
  export function encode(message: IRelayMessage, verify = false): string {
    if (!message) {
      throw Error("Relay message is undefined");
    }
    if (!message.signingPolicy) {
      throw Error("Invalid relay message: no signing policy");
    }
    if (!message.signatures) {
      throw Error("Invalid relay message: no signatures. Must be at least empty array");
    }
    if (message.signatures.length > message.signingPolicy.voters.length) {
      throw Error("Invalid relay message: too many signatures");
    }
    if (message.protocolMessageMerkleRoot && message.newSigningPolicy) {
      throw Error("Invalid relay message: protocol message merkle root and new signing policy are mutually exclusive");
    }
    if (!message.protocolMessageMerkleRoot && !message.newSigningPolicy) {
      throw Error("Invalid relay message: protocol message merkle root or new signing policy must be present");
    }
    let encoded = SigningPolicy.encode(message.signingPolicy);
    let hashToSign: string;
    if (message.protocolMessageMerkleRoot) {
      const encodedMessage = ProtocolMessageMerkleRoot.encode(message.protocolMessageMerkleRoot);
      encoded += encodedMessage.slice(2);
      if(verify) {
        hashToSign = ethers.keccak256(encodedMessage);
      }      
    } else {
      encoded += "00";  // protocolId == 0 indicates new signing policy
      const encodedNewSigningPolicy = SigningPolicy.encode(message.newSigningPolicy!);
      encoded += encodedNewSigningPolicy.slice(2);
      if(verify) {
        hashToSign = SigningPolicy.hashEncoded(encodedNewSigningPolicy);
      }      
    }
    let lastObservedIndex = -1;
    let totalWeight = 0;
    encoded += ECDSASignatureWithIndex.encodeSignatureList(message.signatures).slice(2);
    if(verify) {
      for (const signature of message.signatures) {
        if(signature.index <= lastObservedIndex) {
          throw Error(`Invalid signature: indices must be in ascending order`);
        }
        lastObservedIndex = signature.index
        if(verify) {
          const actualSigner = ECDSASignatureWithIndex.recoverSigner(hashToSign!, signature);        
          const signingPolicySigner = message.signingPolicy.voters[signature.index];
          if(actualSigner.toLowerCase() !== signingPolicySigner.toLowerCase()) {
            throw Error(`Invalid signature: signer ${actualSigner} does not match signing policy ${signingPolicySigner}`);
          }
          totalWeight += message.signingPolicy.weights[signature.index];
        }
      }  
      if(totalWeight <= message.signingPolicy.threshold) {
        throw Error(`Invalid relay message: threshold not met`);
      }
    }
    return encoded;
  }

  /**
   * Decodes relay message from hex string (can be 0x-prefixed or not).
   * @param encoded 
   * @returns 
   */
  export function decode(encoded: string): IRelayMessage {
    const signingPolicy = SigningPolicy.decode(encoded, false);
    const encodedInternal = encoded.startsWith("0x") ? encoded.slice(2) : encoded;
    let newSigningPolicy: ISigningPolicy | undefined;
    let protocolMessageMerkleRoot: IProtocolMessageMerkleRoot | undefined;
    if(encodedInternal.length <= signingPolicy.encodedLength!) {
      throw Error(`Invalid relay message: too short`);
    }
    const protocolId = encodedInternal.slice(signingPolicy.encodedLength!, signingPolicy.encodedLength! + 2);
    let encodedSignatures = "";
    if(protocolId === "00") {
      const rest = encodedInternal.slice(signingPolicy.encodedLength! + 2);
      newSigningPolicy = SigningPolicy.decode(rest, false);
      if(rest.length <= newSigningPolicy.encodedLength!) {
        throw Error(`Invalid relay message: too short - missing signatures`);
      }
      encodedSignatures = rest.slice(newSigningPolicy.encodedLength!);
    } else {
      const rest = encodedInternal.slice(signingPolicy.encodedLength!);
      protocolMessageMerkleRoot = ProtocolMessageMerkleRoot.decode(rest, false);
      encodedSignatures = rest.slice(protocolMessageMerkleRoot.encodedLength!);
    }
    const signatures = ECDSASignatureWithIndex.decodeSignatureList(encodedSignatures);
    return {
      signingPolicy,
      protocolMessageMerkleRoot,
      newSigningPolicy,
      signatures,
    }
  }

  export function equals(a: IRelayMessage, b: IRelayMessage): boolean {
    if(!SigningPolicy.equals(a.signingPolicy, b.signingPolicy)) {
      return false;
    }
    if(a.signatures.length !== b.signatures.length) {
      return false;
    }
    for(let i = 0; i < a.signatures.length; i++) {
      if(!ECDSASignatureWithIndex.equals(a.signatures[i], b.signatures[i])) {
        return false;
      }
    }

    if(a.protocolMessageMerkleRoot && !b.protocolMessageMerkleRoot || !a.protocolMessageMerkleRoot && b.protocolMessageMerkleRoot) {
      return false;
    }
    if(a.newSigningPolicy && !b.newSigningPolicy || !a.newSigningPolicy && b.newSigningPolicy) {
      return false;
    }
    if(a.newSigningPolicy && b.newSigningPolicy) {
      return SigningPolicy.equals(a.newSigningPolicy, b.newSigningPolicy!);
    }
    if(a.protocolMessageMerkleRoot && b.protocolMessageMerkleRoot) {
      return ProtocolMessageMerkleRoot.equals(a.protocolMessageMerkleRoot, b.protocolMessageMerkleRoot!);
    }
    // One of messages is invalid
    return false;
  }

}