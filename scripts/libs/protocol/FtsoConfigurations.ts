export namespace FtsoConfigurations {
  /**
   * Encodes feed names into byte encoding, represented by 0x-prefixed hex string
   * @param feedNames
   * @returns
   */
  export function encodeFeedNames(feedNames: string[]): string {
    let result = "0x";
    for (const feedName of feedNames) {
      if (feedName.length > 8) {
        throw Error(`Invalid feed name: ${feedName} - length: ${feedName.length}`);
      }
      result += Buffer.from(feedName).toString("hex").padEnd(16, "0");
    }
    return result;
  }

  /**
   * Decodes feed names from byte encoding, represented by 0x-prefixed hex string
   * @param encodedFeedNames
   * @returns
   */
  export function decodeFeedNames(encodedFeedNames: string): string[] {
    const encodedFeedNamesInternal = encodedFeedNames.startsWith("0x")
      ? encodedFeedNames.slice(2)
      : encodedFeedNames;
    if (!/^[0-9a-f]*$/.test(encodedFeedNamesInternal)) {
      throw Error(`Invalid format - not hex string: ${encodedFeedNames}`);
    }
    if (encodedFeedNamesInternal.length % 16 != 0) {
      throw Error(`Invalid format - wrong length: ${encodedFeedNames}`);
    }
    const result: string[] = [];
    for (let i = 0; i < encodedFeedNamesInternal.length / 16; i++) {
      result[i] = Buffer.from(encodedFeedNamesInternal.slice(i * 16, (i + 1) * 16), "hex").toString().replaceAll("\0", "");
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
