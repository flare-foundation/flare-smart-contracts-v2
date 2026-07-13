import { secp256k1 } from "@noble/curves/secp256k1";
import { keccak256, AbiCoder, getBytes, hexlify } from "ethers";
import { expect } from "chai";
import { expectRevert } from "@openzeppelin/test-helpers";

import { randomInt } from "../../../utils/sortition";
import { getTestFile } from "../../../utils/constants";
import { VrfVerifierContract, VrfVerifierInstance } from "../../../../typechain-truffle/contracts/tee/lib/VrfVerifier";

const VrfVerifier = artifacts.require("VrfVerifier") as VrfVerifierContract;

// ── secp256k1 constants ──────────────────────────────────────────────────────
const P = secp256k1.CURVE.p;
const N = secp256k1.CURVE.n;
const GX = secp256k1.CURVE.Gx;
const GY = secp256k1.CURVE.Gy;
// (P+1)/4 is the exponent for modular square root when P ≡ 3 mod 4
const SQRT_EXP = (P + 1n) / 4n;

const abiCoder = AbiCoder.defaultAbiCoder();

type AffinePoint = { x: bigint; y: bigint };

interface VrfProof {
  gamma: AffinePoint;
  c: bigint;
  s: bigint;
  u: AffinePoint;
  cGamma: AffinePoint;
  v: AffinePoint;
  zInv: bigint;
}

// ── helpers matching VrfVerifier.sol internals exactly ───────────────────────

function modExp(base: bigint, exp: bigint, mod: bigint): bigint {
  let result = 1n;
  base = base % mod;
  while (exp > 0n) {
    if (exp & 1n) result = (result * base) % mod;
    exp >>= 1n;
    base = (base * base) % mod;
  }
  return result;
}

/** Mirrors VrfVerifier._modSqrt: returns 0 if a is not a quadratic residue. */
function modSqrt(a: bigint): bigint {
  if (a === 0n) return 0n;
  const result = modExp(a, SQRT_EXP, P);
  if ((result * result) % P !== a) return 0n;
  return result;
}

/**
 * Mirrors VrfVerifier._hashToCurve.
 * Hashes `input` to a secp256k1 point using the try-and-increment method.
 */
function hashToCurve(input: Uint8Array): AffinePoint {
  let buf = keccak256(input); // "0x..." – same as keccak256(input) in Solidity
  let x = BigInt(buf) % P;
  for (let i = 0; i < 256; i++) {
    const rhs = (((((x * x) % P) * x) % P) + 7n) % P;
    const y = modSqrt(rhs);
    if (y !== 0n) return { x, y };
    // keccak256(abi.encodePacked(buf)) where buf is bytes32 = raw 32 bytes
    buf = keccak256(getBytes(buf));
    x = BigInt(buf) % P;
  }
  throw new Error("VRF: HashToCurve exceeded iteration limit");
}

/**
 * Mirrors VrfVerifier._hashToZn.
 * Encodes the twelve points/scalars with abi.encode and reduces keccak256 mod N.
 */
function hashToZn(
  hx: bigint,
  hy: bigint,
  pkx: bigint,
  pky: bigint,
  gx: bigint,
  gy: bigint,
  ux: bigint,
  uy: bigint,
  vx: bigint,
  vy: bigint
): bigint {
  const packed = abiCoder.encode(
    [
      "uint256",
      "uint256",
      "uint256",
      "uint256",
      "uint256",
      "uint256",
      "uint256",
      "uint256",
      "uint256",
      "uint256",
      "uint256",
      "uint256",
    ],
    [GX, GY, hx, hy, pkx, pky, gx, gy, ux, uy, vx, vy]
  );
  return BigInt(keccak256(packed)) % N;
}

/**
 * Generates a VRF proof for (sk, nonce) that can be verified by VrfVerifier.verifyRandomness.
 * The witness fields (u, cGamma, v, zInv) are computed off-chain as the contract expects.
 */
function generateVrfProof(sk: bigint, pk: AffinePoint, nonce: Uint8Array): VrfProof {
  const h = hashToCurve(nonce);
  if (h.x >= N) throw new Error("VRF: h.x >= N (degenerate input)");

  const gamma = secp256k1.ProjectivePoint.fromAffine(h).multiply(sk).toAffine();

  const k = randomInt(N - 1n) + 1n; // k in [1, N)

  const u = secp256k1.ProjectivePoint.BASE.multiply(k).toAffine(); // k·G
  const v = secp256k1.ProjectivePoint.fromAffine(h).multiply(k).toAffine(); // k·h

  const c = hashToZn(h.x, h.y, pk.x, pk.y, gamma.x, gamma.y, u.x, u.y, v.x, v.y);

  // s = (k − sk·c) mod N
  const s = (((k - ((sk * c) % N)) % N) + N) % N;

  const cGamma = secp256k1.ProjectivePoint.fromAffine(gamma).multiply(c).toAffine(); // c·gamma

  const denom = (cGamma.x - v.x + P) % P;
  const zInv = modExp(denom, P - 2n, P); // Fermat: a^(P−2) ≡ a^{−1} mod P

  return { gamma, c, s, u, cGamma, v, zInv };
}

/** Converts a VrfProof to the struct shape expected by the contract. */
function toContractProof(proof: VrfProof) {
  return {
    gamma: { x: proof.gamma.x.toString(), y: proof.gamma.y.toString() },
    c: proof.c.toString(),
    s: proof.s.toString(),
    u: { x: proof.u.x.toString(), y: proof.u.y.toString() },
    cGamma: { x: proof.cGamma.x.toString(), y: proof.cGamma.y.toString() },
    v: { x: proof.v.x.toString(), y: proof.v.y.toString() },
    zInv: proof.zInv.toString(),
  };
}

// ── tests ────────────────────────────────────────────────────────────────────

contract(`VrfVerifier.sol; ${getTestFile(__filename)}`, () => {
  let verifier: VrfVerifierInstance;

  before(async () => {
    verifier = await VrfVerifier.new();
  });

  it("should verify a valid VRF proof", async () => {
    const sk = randomInt(N - 1n) + 1n;
    const pk = secp256k1.ProjectivePoint.BASE.multiply(sk).toAffine();
    const nonce = new TextEncoder().encode("test-nonce");

    const proof = generateVrfProof(sk, pk, nonce);
    const valid = await verifier.verifyRandomness(
      toContractProof(proof),
      pk.x.toString(),
      pk.y.toString(),
      hexlify(nonce)
    );

    expect(valid).to.equal(true);
  });

  it("should return the same randomness for the same nonce regardless of the k blinding factor", async () => {
    const sk = randomInt(N - 1n) + 1n;
    const pk = secp256k1.ProjectivePoint.BASE.multiply(sk).toAffine();
    const nonce = new TextEncoder().encode("deterministic-nonce");

    // Two proofs with independent k values → same gamma → same randomness
    const proof1 = generateVrfProof(sk, pk, nonce);
    const proof2 = generateVrfProof(sk, pk, nonce);

    const r1 = await verifier.randomnessFromProof(proof1.gamma.x.toString(), proof1.gamma.y.toString());
    const r2 = await verifier.randomnessFromProof(proof2.gamma.x.toString(), proof2.gamma.y.toString());

    expect(r1).to.equal(r2);
  });

  it("should return different randomness for different nonces", async () => {
    const sk = randomInt(N - 1n) + 1n;
    const pk = secp256k1.ProjectivePoint.BASE.multiply(sk).toAffine();

    const proof1 = generateVrfProof(sk, pk, new TextEncoder().encode("nonce-a"));
    const proof2 = generateVrfProof(sk, pk, new TextEncoder().encode("nonce-b"));

    const r1 = await verifier.randomnessFromProof(proof1.gamma.x.toString(), proof1.gamma.y.toString());
    const r2 = await verifier.randomnessFromProof(proof2.gamma.x.toString(), proof2.gamma.y.toString());

    expect(r1).to.not.equal(r2);
  });

  it("should reject a proof presented with the wrong public key", async () => {
    const sk = randomInt(N - 1n) + 1n;
    const pk = secp256k1.ProjectivePoint.BASE.multiply(sk).toAffine();
    const nonce = new TextEncoder().encode("test-nonce");
    const proof = generateVrfProof(sk, pk, nonce);

    const wrongSk = randomInt(N - 1n) + 1n;
    const wrongPk = secp256k1.ProjectivePoint.BASE.multiply(wrongSk).toAffine();

    await expectRevert(
      verifier.verifyRandomness(toContractProof(proof), wrongPk.x.toString(), wrongPk.y.toString(), hexlify(nonce)),
      "InvalidUWitness()"
    );
  });

  it("should reject a proof with a tampered gamma", async () => {
    const sk = randomInt(N - 1n) + 1n;
    const pk = secp256k1.ProjectivePoint.BASE.multiply(sk).toAffine();
    const nonce = new TextEncoder().encode("test-nonce");
    const proof = generateVrfProof(sk, pk, nonce);

    // Replace gamma with a random point on the curve
    const tamperedGamma = secp256k1.ProjectivePoint.BASE.multiply(randomInt(N - 1n) + 1n).toAffine();
    const tamperedProof = {
      ...toContractProof(proof),
      gamma: { x: tamperedGamma.x.toString(), y: tamperedGamma.y.toString() },
    };

    await expectRevert(
      verifier.verifyRandomness(tamperedProof, pk.x.toString(), pk.y.toString(), hexlify(nonce)),
      "InvalidCGammaWitness()"
    );
  });

  it("should verify proofs for multiple independent key pairs", async () => {
    const nonce = new TextEncoder().encode("shared-nonce");
    for (let i = 0; i < 3; i++) {
      const sk = randomInt(N - 1n) + 1n;
      const pk = secp256k1.ProjectivePoint.BASE.multiply(sk).toAffine();
      const proof = generateVrfProof(sk, pk, nonce);
      const valid = await verifier.verifyRandomness(
        toContractProof(proof),
        pk.x.toString(),
        pk.y.toString(),
        hexlify(nonce)
      );
      expect(valid).to.equal(true);
    }
  });
});
