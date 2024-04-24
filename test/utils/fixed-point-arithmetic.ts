/**
 * Converts a range or sample size value to a fixed-point arithmetic representation.
 * @param x - The range value to be converted.
 * @returns The fixed-point arithmetic representation of the range value.
 * @throws Error if the range value is out of bounds.
 */
export function RangeOrSampleFPA(x: number): string {
    const xInteger = Math.floor(x)
    const xFractional = x - xInteger
    const fractionalDigits = xFractional.toString(16).substring(2).padEnd(30,"0")
    const integerDigits = xInteger.toString(16)
    if (integerDigits.length > 2) throw new Error("range or sample size too large")
    return "0x" + (integerDigits + fractionalDigits).replace(/^0+/, "")
}