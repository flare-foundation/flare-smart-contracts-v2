import { ethers } from "ethers";
import { chainBoundHash } from "./ChainDomain";

export interface IProtocolMessageMerkleRoot {
  protocolId: number;
  votingRoundId: number;
  isSecureRandom: boolean;
  merkleRoot: string;
  encodedLength?: number; // used only as a parsing result when parsing signing policy encoded into Relay message
}

export namespace ProtocolMessageMerkleRoot {
  //////////////////////////////////////////////////////////////////////////////
  // Protocol message merkle root structure
  // 1 byte - protocolId
  // 4 bytes - votingRoundId
  // 1 byte - isSecureRandom
  // 32 bytes - merkleRoot
  // Total 38 bytes
  //////////////////////////////////////////////////////////////////////////////
  /**
   * Encode protocol message merkle root into 0x-prefixed hex string representing byte encoding
   * @param message
   * @returns
   */
  export function encode(message: IProtocolMessageMerkleRoot): string {
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
      (message.isSecureRandom ? 1 : 0).toString(16).padStart(2, "0") +
      message.merkleRoot.slice(2)
    ).toLowerCase();
  }

  /**
   * Decodes signed message from hex string (can be 0x-prefixed or not).
   * @param encodedMessage
   * @returns
   */
  export function decode(encodedMessage: string, exactEncoding = true): IProtocolMessageMerkleRoot {
    const encodedMessageInternal = encodedMessage.startsWith("0x") ? encodedMessage.slice(2) : encodedMessage;
    // (1 + 4 + 1 + 32) * 2 = 38 * 2 = 76
    if (!/^[0-9a-f]*$/.test(encodedMessageInternal)) {
      throw Error(`Invalid format - not hex string: ${encodedMessage}`);
    }
    if (encodedMessageInternal.length < 76) {
      throw Error(`Invalid encoded message length: ${encodedMessageInternal.length}`);
    }
    if (exactEncoding && encodedMessageInternal.length !== 76) {
      throw Error(`Invalid encoded message length: ${encodedMessageInternal.length}. Should be exact length 76`);
    }
    let encodedLengthEntry = {};
    if (!exactEncoding) {
      encodedLengthEntry = { encodedLength: 76 };
    }
    const protocolId = parseInt(encodedMessageInternal.slice(0, 2), 16);
    const votingRoundId = parseInt(encodedMessageInternal.slice(2, 10), 16);
    const encodedIsSecureRandom = encodedMessageInternal.slice(10, 12);
    let isSecureRandom = false;
    if (encodedIsSecureRandom === "00") {
      isSecureRandom = false;
    } else if (encodedIsSecureRandom === "01") {
      isSecureRandom = true;
    } else {
      throw Error("Invalid random quality score");
    }
    const merkleRoot = "0x" + encodedMessageInternal.slice(12, 76);
    return {
      protocolId,
      votingRoundId,
      isSecureRandom,
      merkleRoot,
      ...encodedLengthEntry,
    };
  }

  /**
   * Compares two protocol message merkle roots
   * @param a
   * @param b
   * @returns
   */
  export function equals(a: IProtocolMessageMerkleRoot, b: IProtocolMessageMerkleRoot): boolean {
    return (
      a.protocolId === b.protocolId &&
      a.votingRoundId === b.votingRoundId &&
      a.isSecureRandom === b.isSecureRandom &&
      a.merkleRoot === b.merkleRoot
    );
  }

  /**
   * The digest voters sign for a protocol message (before the EIP-191 prefix is applied by the
   * signing routine). Since RLY-23 it is chain-bound: keccak256(chainId ‖ keccak256(encode(message))).
   * @param message
   * @param chainId the configured source chain id (`relay.sourceChainId()`)
   */
  export function hash(message: IProtocolMessageMerkleRoot, chainId: number | bigint): string {
    return chainBoundHash(ethers.keccak256(encode(message)), chainId);
  }
  /**
   * Provides string representation of protocol message merkle root.
   * Can be used for e.g. logging.
   * @param message
   * @returns
   */
  export function print(message: IProtocolMessageMerkleRoot) {
    return `(${message.protocolId}, ${message.votingRoundId}, ${message.isSecureRandom}, ${message.merkleRoot})`;
  }
}
