import { ECDSASignatureWithIndex, IECDSASignatureWithIndex } from "./ECDSASignatureWithIndex";
import { IProtocolMessageMerkleRoot, ProtocolMessageMerkleRoot } from "./ProtocolMessageMerkleRoot";
import { ISigningPolicy, SigningPolicy } from "./SigningPolicy";

export interface IRelayMessage {
  signingPolicy: ISigningPolicy;
  protocolMessageMerkleRoot?: IProtocolMessageMerkleRoot | undefined;
  newSigningPolicy?: ISigningPolicy | undefined;
  signatures: IECDSASignatureWithIndex[];
  // RLY-03: for the random-number protocol, the relay message carries a trailer after the
  // signatures: the random number value plus its Merkle proof against the message merkleRoot.
  isRandomNumberGeneratingProtocolMessage?: boolean;
  randomNumber?: string; // uint256 as 0x-prefixed 32-byte hex string
  merkleProof?: string[]; // sequence of 0x-prefixed 32-byte hex strings
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
   * @param chainId the configured source chain id (`relay.sourceChainId()`)
   *                (RLY-23 chain-domain binding; required when verify is true)
   * @returns
   */
  export function encode(message: IRelayMessage, verify = false, chainId?: number | bigint): string {
    if (!message) {
      throw Error("Relay message is undefined");
    }
    if (verify && chainId === undefined) {
      throw Error("chainId is required when verify is true (RLY-23 chain-domain binding)");
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
      if (verify) {
        // RLY-23: voters sign the chain-bound digest keccak256(chainId ‖ keccak256(message)).
        hashToSign = ProtocolMessageMerkleRoot.hash(message.protocolMessageMerkleRoot, chainId!);
      }
    } else {
      encoded += "00"; // protocolId == 0 indicates new signing policy
      const encodedNewSigningPolicy = SigningPolicy.encode(message.newSigningPolicy!);
      encoded += encodedNewSigningPolicy.slice(2);
      if (verify) {
        // RLY-23: the signed (and stored) signing-policy hash is chain-bound.
        hashToSign = SigningPolicy.hashEncoded(encodedNewSigningPolicy, chainId!);
      }
    }
    let lastObservedIndex = -1;
    let totalWeight = 0;
    encoded += ECDSASignatureWithIndex.encodeSignatureList(message.signatures).slice(2);
    // RLY-03: append the random-number trailer (randomNumber || merkleProof) after the signatures.
    if (message.isRandomNumberGeneratingProtocolMessage) {
      if (
        !message.randomNumber ||
        message.randomNumber.length !== 66 ||
        !/^0x[0-9a-fA-F]{64}$/.test(message.randomNumber)
      ) {
        throw Error("Invalid relay message: randomNumber must be a 32-byte hex string (0x-prefixed)");
      }
      encoded += message.randomNumber.slice(2);
      if (!message.merkleProof) {
        throw Error("Invalid relay message: merkleProof is missing for random-number protocol message");
      }
      for (const proofElement of message.merkleProof) {
        if (proofElement.length !== 66 || !/^0x[0-9a-fA-F]{64}$/.test(proofElement)) {
          throw Error("Invalid relay message: merkleProof elements must be 32-byte hex strings (0x-prefixed)");
        }
        encoded += proofElement.slice(2);
      }
    }
    if (verify) {
      for (const signature of message.signatures) {
        if (signature.index <= lastObservedIndex) {
          throw Error(`Invalid signature: indices must be in ascending order`);
        }
        lastObservedIndex = signature.index;
        if (verify) {
          const actualSigner = ECDSASignatureWithIndex.recoverSigner(hashToSign!, signature);
          const signingPolicySigner = message.signingPolicy.voters[signature.index];
          if (actualSigner.toLowerCase() !== signingPolicySigner.toLowerCase()) {
            throw Error(
              `Invalid signature: signer ${actualSigner} does not match signing policy ${signingPolicySigner}`
            );
          }
          totalWeight += message.signingPolicy.weights[signature.index];
        }
      }
      if (totalWeight <= message.signingPolicy.threshold) {
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
    if (encodedInternal.length <= signingPolicy.encodedLength!) {
      throw Error(`Invalid relay message: too short`);
    }
    const protocolId = encodedInternal.slice(signingPolicy.encodedLength, signingPolicy.encodedLength! + 2);
    let encodedSignatures = "";
    if (protocolId === "00") {
      const rest = encodedInternal.slice(signingPolicy.encodedLength! + 2);
      newSigningPolicy = SigningPolicy.decode(rest, false);
      if (rest.length <= newSigningPolicy.encodedLength!) {
        throw Error(`Invalid relay message: too short - missing signatures`);
      }
      encodedSignatures = rest.slice(newSigningPolicy.encodedLength);
    } else {
      const rest = encodedInternal.slice(signingPolicy.encodedLength);
      protocolMessageMerkleRoot = ProtocolMessageMerkleRoot.decode(rest, false);
      encodedSignatures = rest.slice(protocolMessageMerkleRoot.encodedLength);
    }
    // RLY-03: separate the signature list from an optional random-number trailer. `decodeSignatureList`
    // requires an exact-length input, so we cannot hand it the trailer — slice the list precisely first
    // (2-byte count prefix + count * 67-byte records) and treat any remainder as the trailer that
    // `encode()` appended (randomNumber || merkleProof).
    if (encodedSignatures.length < 4) {
      throw Error(`Invalid relay message: too short - missing signatures`);
    }
    const signatureCount = parseInt(encodedSignatures.slice(0, 4), 16);
    const signatureListLength = 4 + signatureCount * 134; // (1 + 32 + 32 + 2) * 2 hex chars per signature
    if (encodedSignatures.length < signatureListLength) {
      throw Error(`Invalid relay message: signature list truncated`);
    }
    const signatures = ECDSASignatureWithIndex.decodeSignatureList(encodedSignatures.slice(0, signatureListLength));
    const trailer = encodedSignatures.slice(signatureListLength);
    let isRandomNumberGeneratingProtocolMessage: boolean | undefined;
    let randomNumber: string | undefined;
    let merkleProof: string[] | undefined;
    if (trailer.length > 0) {
      // RLY-03 trailer: a 32-byte random number followed by zero or more 32-byte Merkle-proof elements
      // (mirror of the append in `encode()`).
      if (trailer.length % 64 !== 0) {
        throw Error(`Invalid relay message: random trailer length (${trailer.length}) not a multiple of 64`);
      }
      isRandomNumberGeneratingProtocolMessage = true;
      randomNumber = "0x" + trailer.slice(0, 64);
      merkleProof = [];
      for (let position = 64; position < trailer.length; position += 64) {
        merkleProof.push("0x" + trailer.slice(position, position + 64));
      }
    }
    return {
      signingPolicy,
      protocolMessageMerkleRoot,
      newSigningPolicy,
      signatures,
      isRandomNumberGeneratingProtocolMessage,
      randomNumber,
      merkleProof,
    };
  }

  export function equals(a: IRelayMessage, b: IRelayMessage): boolean {
    if (!SigningPolicy.equals(a.signingPolicy, b.signingPolicy)) {
      return false;
    }
    if (a.signatures.length !== b.signatures.length) {
      return false;
    }
    for (let i = 0; i < a.signatures.length; i++) {
      if (!ECDSASignatureWithIndex.equals(a.signatures[i], b.signatures[i])) {
        return false;
      }
    }

    if (
      (a.protocolMessageMerkleRoot && !b.protocolMessageMerkleRoot) ||
      (!a.protocolMessageMerkleRoot && b.protocolMessageMerkleRoot)
    ) {
      return false;
    }
    if ((a.newSigningPolicy && !b.newSigningPolicy) || (!a.newSigningPolicy && b.newSigningPolicy)) {
      return false;
    }
    if (a.newSigningPolicy && b.newSigningPolicy) {
      return SigningPolicy.equals(a.newSigningPolicy, b.newSigningPolicy);
    }
    if (a.protocolMessageMerkleRoot && b.protocolMessageMerkleRoot) {
      return ProtocolMessageMerkleRoot.equals(a.protocolMessageMerkleRoot, b.protocolMessageMerkleRoot);
    }
    // One of messages is invalid
    return false;
  }
}
