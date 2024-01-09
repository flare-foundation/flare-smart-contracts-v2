
export interface IPayloadMessage<T> {
  protocolId: number;
  votingRoundId: number;
  payload: T;
}

export namespace PayloadMessage {
  /**
   * Encodes data in byte sequence that can be concatenated with other encoded data for use in submission functions in
   * Submission.sol contract
   * @param protocolId
   * @param votingRoundRoundId
   * @param payload
   * @returns
   */
  export function encode(payloadMessage: IPayloadMessage<string>): string {
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
  export function decode(message: string): IPayloadMessage<string>[] {
    const messageInternal = message.startsWith("0x") ? message.slice(2) : message;
    if (!/^[0-9a-f]*$/.test(messageInternal)) {
      throw Error(`Invalid format - not hex string: ${message}`);
    }
    if (messageInternal.length % 2 !== 0) {
      throw Error(`Invalid format - not even length: ${message.length}`);
    }
    let i = 0;
    let result: IPayloadMessage<string>[] = [];
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

}
