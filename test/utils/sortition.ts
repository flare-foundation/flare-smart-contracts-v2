import crypto from "crypto";

import { Field } from "@noble/curves/abstract/modular"; // also known as alt_bn128
import type { AffinePoint, ProjPointType } from "@noble/curves/abstract/weierstrass";
import { bn254 } from "@noble/curves/bn254"; // also known as alt_bn128
import { sha256 } from "ethers";
import { encodePacked } from "web3-utils";
import utils from "web3-utils";

export type SortitionKey = {
  readonly sk: bigint;
  readonly pk: ProjPointType<bigint>;
};

export type Proof = {
  readonly gamma: ProjPointType<bigint>;
  readonly c: bigint;
  readonly s: bigint;
};

export type Signature = {
  s: bigint;
  r: ProjPointType<bigint>;
};

/**
 * Generates a sortition key.
 * @returns The generated sortition key.
 */
export function generateSortitionKey(): SortitionKey {
  const sk = randomInt(bn254.CURVE.n);
  const pk = bn254.ProjectivePoint.BASE.multiply(sk);
  const key: SortitionKey = { sk: sk, pk: pk };

  return key;
}

/**
 * Parses a sortition key from string.
 *
 * @param skString - The hexagonal string representation of a private key.
 * @returns The generated sortition key.
 * *
 */
export function ParseSortitionKey(skString: string): SortitionKey {
  const sk = BigInt(skString) % bn254.CURVE.n;
  const pk = bn254.ProjectivePoint.BASE.multiply(sk);
  const key: SortitionKey = { sk: sk, pk: pk };

  return key;
}

/**
 * Calculates the randomness value based on the provided parameters.
 *
 * @param key - The sortition key.
 * @param baseSeed - The base seed value.
 * @param blockNum - The block number.
 * @param replicate - The replicate value.
 * @returns The calculated randomness value.
 */
export function calculateRandomness(key: SortitionKey, baseSeed: string, blockNum: string, replicate: string): bigint {
  const msg: string =
    encodePacked(
      { value: baseSeed, type: "uint256" },
      { value: blockNum, type: "uint256" },
      { value: replicate, type: "uint256" }
    ) ?? "";

  const h = g1HashToPoint(msg);
  const gamma = h.multiply(key.sk);

  return gamma.x;
}

/**
 * Generates a verifiable randomness proof.
 *
 * @param key - The sortition key.
 * @param baseSeed - The base seed.
 * @param blockNum - The block number.
 * @param replicate - The replicate value.
 * @returns The verifiable randomness proof.
 */
export function generateVerifiableRandomnessProof(
  key: SortitionKey,
  baseSeed: string,
  blockNum: string,
  replicate: string
): Proof {
  let msg: string =
    encodePacked(
      { value: baseSeed, type: "uint256" },
      { value: blockNum, type: "uint256" },
      { value: replicate, type: "uint256" }
    ) ?? "";

  const h = g1HashToPoint(msg);
  const gamma = h.multiply(key.sk);
  const k = randomInt(bn254.CURVE.n);
  const gToK = bn254.ProjectivePoint.BASE.multiply(k);
  const hToK = h.multiply(k);
  msg =
    encodePacked(
      { value: bn254.ProjectivePoint.BASE.x.toString(), type: "uint256" },
      { value: bn254.ProjectivePoint.BASE.y.toString(), type: "uint256" },
      { value: h.x.toString(), type: "uint256" },
      { value: h.y.toString(), type: "uint256" },
      { value: key.pk.x.toString(), type: "uint256" },
      { value: key.pk.y.toString(), type: "uint256" },
      { value: gamma.x.toString(), type: "uint256" },
      { value: gamma.y.toString(), type: "uint256" },
      { value: gToK.x.toString(), type: "uint256" },
      { value: gToK.y.toString(), type: "uint256" },
      { value: hToK.x.toString(), type: "uint256" },
      { value: hToK.y.toString(), type: "uint256" }
    ) ?? "";

  const c = BigInt(sha256(msg)) % bn254.CURVE.n;
  const s = (((k - c * key.sk) % bn254.CURVE.n) + bn254.CURVE.n) % bn254.CURVE.n; // modulo twice to avoid negative
  const proof: Proof = { gamma: gamma, c: c, s: s };

  return proof;
}

/**
 * Calculates the y-coordinate of a point on the elliptic curve given the x-coordinate.
 * @param x The x-coordinate of the point.
 * @returns The y-coordinate of the point if it exists, otherwise null.
 */
function g1YFromX(x: bigint): ProjPointType<bigint> | null {
  const ySquare = (x * x * x + 3n) % bn254.CURVE.p;
  const fp = Field(bn254.CURVE.p);

  try {
    const y = fp.sqrt(ySquare);

    const point1: AffinePoint<bigint> = { x: x, y: y };
    const point2 = bn254.ProjectivePoint.fromAffine(point1);
    return point2;
  } catch (e) {
    return null;
  }
}

/**
 * Computes the hash of a message and maps it to a point on the G1 elliptic curve.
 * @param m - The message to be hashed.
 * @returns The resulting point on the G1 curve.
 */
export function g1HashToPoint(m: string): ProjPointType<bigint> {
  const h = BigInt(sha256(m));
  let x: bigint = h % bn254.CURVE.p;
  for (;;) {
    const point = g1YFromX(x);
    if (point != null) {
      return point;
    }
    x += 1n;
  }
}

/**
 * Signs a message based on Schnorr signature using SortitionKey.
 * @param key - The sortition key.
 * @param msg - The message to be signed
 * @returns Signature of the message.
 */
export function Sign(key: SortitionKey, msg: string): Signature {
  const k = randomInt(bn254.CURVE.n);
  const r = bn254.ProjectivePoint.BASE.multiply(k);
  const encoded =
    encodePacked(
      { value: key.pk.x.toString(), type: "uint256" },
      { value: key.pk.y.toString(), type: "uint256" },
      { value: msg, type: "bytes32" },
      { value: r.x.toString(), type: "uint256" },
      { value: r.y.toString(), type: "uint256" }
    ) ?? "";

  const e = utils.soliditySha3(encoded)!;
  const s = (((k - key.sk * BigInt(e)) % bn254.CURVE.n) + bn254.CURVE.n) % bn254.CURVE.n;

  const signature: Signature = { s: s, r: r };

  return signature;
}

/**
 * Generates a random integer between 0 (inclusive) and the specified maximum value (exclusive).
 * @param max The maximum value for the random integer.
 * @returns A random integer between 0 (inclusive) and the specified maximum value (exclusive).
 */
export function randomInt(max: bigint): bigint {
  const length = max.toString(2).length;
  const numBytes = Math.floor((length - 1) / 8) + 1;
  const twoToLength = 2n ** BigInt(length);
  for (;;) {
    const randomBytes = crypto.randomBytes(numBytes).toString("hex");
    const r = BigInt("0x" + randomBytes) % twoToLength;

    if (r < max) {
      return r;
    }
  }
}
