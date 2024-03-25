export interface IFeedId {
  type: number;
  name: string;
}

export namespace FtsoConfigurations {

  /**
   * Encodes feed id into byte encoding, represented by 0x-prefixed hex string
   * @param feedId
   * @returns
   */
  export function encodeFeedId(feedId: IFeedId): string {
    return encodeFeedIds([feedId]);
  }

  /**
   * Encodes feed ids into byte encoding, represented by 0x-prefixed hex string
   * @param feedIds
   * @returns
   */
  export function encodeFeedIds(feedIds: IFeedId[]): string {
    let result = "0x";
    for (const feedId of feedIds) {
      if (feedId.type < 0 || feedId.type >= 2**8) {
        throw Error(`Invalid feed type: ${feedId.type}`);
      }
      if (feedId.name.length > 20) {
        throw Error(`Invalid feed id: ${feedId.name} - length: ${feedId.name.length}`);
      }
      result += feedId.type.toString(16).padStart(2, "0") + Buffer.from(feedId.name).toString("hex").padEnd(40, "0");
    }
    return result;
  }

  /**
   * Decodes feed ids from byte encoding, represented by 0x-prefixed hex string
   * @param encodedFeedIds
   * @returns
   */
  export function decodeFeedIds(encodedFeedIds: string): IFeedId[] {
    const encodedFeedIdsInternal = encodedFeedIds.startsWith("0x")
      ? encodedFeedIds.slice(2)
      : encodedFeedIds;
    if (!/^[0-9a-f]*$/.test(encodedFeedIdsInternal)) {
      throw Error(`Invalid format - not hex string: ${encodedFeedIds}`);
    }
    if (encodedFeedIdsInternal.length % 42 != 0) {
      throw Error(`Invalid format - wrong length: ${encodedFeedIds}`);
    }
    const result: IFeedId[] = [];
    for (let i = 0; i < encodedFeedIdsInternal.length / 42; i++) {
      let type = parseInt(encodedFeedIdsInternal.slice(i * 42, i * 42 + 2), 16);
      if (type < 0 || type >= 2**8) { // can never happen
        throw Error(`Invalid type: ${type}`);
      }
      result[i] = { type, name: Buffer.from(encodedFeedIdsInternal.slice(i * 42 + 2, (i + 1) * 42), "hex").toString().replaceAll("\0", "") };
    }

    return result;
  }

  /**
   * Encodes secondary band width PPMs into byte encoding, represented by 0x-prefixed hex string
   * @param values
   * @returns
   */
  export function encodeSecondaryBandWidthPPMs(values: number[]): string {
    let result = "0x";
    for (const value of values) {
      if (value < 0 || value > 1000000) {
        throw Error(`Invalid secondary band width PPM: ${value}`);
      }
      result += value.toString(16).padStart(6, "0");
    }
    return result;
  }

  /**
   * Decodes secondary band width PPMs from byte encoding, represented by 0x-prefixed hex string
   * @param encodedSecondaryBandWidthPPMs
   * @returns
   */
  export function decodeSecondaryBandWidthPPMs(encodedSecondaryBandWidthPPMs: string): number[] {
    const encodedSecondaryBandWidthPPMsInternal = encodedSecondaryBandWidthPPMs.startsWith("0x")
      ? encodedSecondaryBandWidthPPMs.slice(2)
      : encodedSecondaryBandWidthPPMs;
    if (!/^[0-9a-f]*$/.test(encodedSecondaryBandWidthPPMsInternal)) {
      throw Error(`Invalid format - not hex string: ${encodedSecondaryBandWidthPPMs}`);
    }
    if (encodedSecondaryBandWidthPPMsInternal.length % 6 != 0) {
      throw Error(`Invalid format - wrong length: ${encodedSecondaryBandWidthPPMs}`);
    }
    const result: number[] = [];
    for (let i = 0; i < encodedSecondaryBandWidthPPMsInternal.length / 6; i++) {
      const value = parseInt(encodedSecondaryBandWidthPPMsInternal.slice(i * 6, (i + 1) * 6), 16);
      if (value < 0 || value > 1000000) {
        throw Error(`Invalid secondary band width PPM: ${value}`);
      }
      result[i] = value;
    }

    return result;
  }

  /**
   * Encodes decimals into byte encoding, represented by 0x-prefixed hex string
   * @param values
   * @returns
   */
  export function encodeDecimals(values: number[]): string {
    let result = "0x";
    for (let value of values) {
      if (value < -(2**7) || value >= 2**7) {
        throw Error(`Invalid decimals: ${value}`);
      }
      if (value < 0) {
        value += 2**8;
      }
      result += value.toString(16).padStart(2, "0");
    }
    return result;
  }

  /**
   * Decodes decimals from byte encoding, represented by 0x-prefixed hex string
   * @param encodedDecimals
   * @returns
   */
  export function decodeDecimals(encodedDecimals: string): number[] {
    const encodedDecimalsInternal = encodedDecimals.startsWith("0x")
      ? encodedDecimals.slice(2)
      : encodedDecimals;
    if (!/^[0-9a-f]*$/.test(encodedDecimalsInternal)) {
      throw Error(`Invalid format - not hex string: ${encodedDecimals}`);
    }
    if (encodedDecimalsInternal.length % 2 != 0) {
      throw Error(`Invalid format - wrong length: ${encodedDecimals}`);
    }
    const result: number[] = [];
    for (let i = 0; i < encodedDecimalsInternal.length / 2; i++) {
      let value = parseInt(encodedDecimalsInternal.slice(i * 2, (i + 1) * 2), 16);
      if (value < 0 || value >= 2**8) { // can never happen
        throw Error(`Invalid decimals: ${value}`);
      }
      if (value >= 2**7) {
        value -= 2**8;
      }
      result[i] = value;
    }
    return result;
  }
}
