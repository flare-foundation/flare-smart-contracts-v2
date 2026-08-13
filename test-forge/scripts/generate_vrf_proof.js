/**
 * Generates VRF proof test data for Forge tests.
 * Called via vm.ffi() from VrfVerifier.t.sol.
 *
 * Usage: node generate_vrf_proof.js <mode> [nonce]
 *   mode: "valid" | "wrong_pk" | "tampered_gamma" | "pk_x_unverifiable" | "gamma_x_unverifiable"
 *   nonce: optional nonce string (default: "test-nonce")
 *
 * Outputs ABI-encoded: (Proof, pkX, pkY, nonce)
 * where Proof matches VrfVerifier.Proof struct layout.
 */

const { secp256k1 } = require("@noble/curves/secp256k1");
const { keccak256, AbiCoder, getBytes, solidityPacked } = require("ethers");

const P = secp256k1.CURVE.p;
const N = secp256k1.CURVE.n;
const GX = secp256k1.CURVE.Gx;
const GY = secp256k1.CURVE.Gy;
const SQRT_EXP = (P + 1n) / 4n;

const abiCoder = AbiCoder.defaultAbiCoder();

function modExp(base, exp, mod) {
    let result = 1n;
    base = base % mod;
    while (exp > 0n) {
        if (exp & 1n) result = (result * base) % mod;
        exp >>= 1n;
        base = (base * base) % mod;
    }
    return result;
}

function modSqrt(a) {
    if (a === 0n) return 0n;
    const result = modExp(a, SQRT_EXP, P);
    if ((result * result) % P !== a) return 0n;
    return result;
}

// Mirrors VrfVerifier._hashToCurve: salted with the public key so each key
// is bound to an independent hash-to-curve function.
function hashToCurve(pk, input) {
    // abi.encodePacked(bytes32(pk.x), bytes32(pk.y), input)
    let buf = keccak256(solidityPacked(["uint256", "uint256", "bytes"], [pk.x, pk.y, input]));
    let x = BigInt(buf) % P;
    for (let i = 0; i < 256; i++) {
        const rhs = ((((x * x) % P) * x) % P + 7n) % P;
        const y = modSqrt(rhs);
        if (y !== 0n) return { x, y };
        buf = keccak256(getBytes(buf));
        x = BigInt(buf) % P;
    }
    throw new Error("HashToCurve exceeded iteration limit");
}

function hashToZn(hx, hy, pkx, pky, gx, gy, ux, uy, vx, vy) {
    const packed = abiCoder.encode(
        Array(12).fill("uint256"),
        [GX, GY, hx, hy, pkx, pky, gx, gy, ux, uy, vx, vy]
    );
    return BigInt(keccak256(packed)) % N;
}

function randomBigInt(max) {
    const bytes = require("crypto").randomBytes(32);
    return (BigInt("0x" + bytes.toString("hex")) % (max - 1n)) + 1n;
}

// Finds an on-curve secp256k1 point whose x-coordinate lies in [N, P).
// Such points exist (the gap P - N is ~2^128 wide) but cannot occur for a
// real key/gamma with probability > 2^{-128}, so we construct one explicitly
// to exercise the PkXUnverifiable / GammaXUnverifiable guards.
function onCurvePointWithXAboveN() {
    let x = N;
    for (let i = 0; i < 1000; i++) {
        const rhs = ((((x * x) % P) * x) % P + 7n) % P;
        const y = modSqrt(rhs);
        if (y !== 0n) return { x, y };
        x += 1n;
    }
    throw new Error("could not find on-curve point with x >= N");
}

function generateProof(sk, pk, nonceBytes) {
    const h = hashToCurve(pk, nonceBytes);
    if (h.x >= N) throw new Error("h.x >= N");

    const gamma = secp256k1.ProjectivePoint.fromAffine(h).multiply(sk).toAffine();
    const k = randomBigInt(N);
    const u = secp256k1.ProjectivePoint.BASE.multiply(k).toAffine();
    const v = secp256k1.ProjectivePoint.fromAffine(h).multiply(k).toAffine();
    const c = hashToZn(h.x, h.y, pk.x, pk.y, gamma.x, gamma.y, u.x, u.y, v.x, v.y);
    const s = ((k - ((sk * c) % N)) % N + N) % N;
    const cGamma = secp256k1.ProjectivePoint.fromAffine(gamma).multiply(c).toAffine();
    const denom = (cGamma.x - v.x + P) % P;
    const zInv = modExp(denom, P - 2n, P);

    return { gamma, c, s, u, cGamma, v, zInv };
}

const mode = process.argv[2] || "valid";
const nonceStr = process.argv[3] || "test-nonce";
const nonceBytes = new TextEncoder().encode(nonceStr);

const sk = randomBigInt(N);
const pk = secp256k1.ProjectivePoint.BASE.multiply(sk).toAffine();
const proof = generateProof(sk, pk, nonceBytes);

let outputPkX = pk.x;
let outputPkY = pk.y;
let outputGamma = proof.gamma;

if (mode === "wrong_pk") {
    const wrongSk = randomBigInt(N);
    const wrongPk = secp256k1.ProjectivePoint.BASE.multiply(wrongSk).toAffine();
    outputPkX = wrongPk.x;
    outputPkY = wrongPk.y;
} else if (mode === "tampered_gamma") {
    outputGamma = secp256k1.ProjectivePoint.BASE.multiply(randomBigInt(N)).toAffine();
} else if (mode === "pk_x_unverifiable") {
    // On-curve public key with x in [N, P): rejected by the PkXUnverifiable guard.
    const pkUnverifiable = onCurvePointWithXAboveN();
    outputPkX = pkUnverifiable.x;
    outputPkY = pkUnverifiable.y;
} else if (mode === "gamma_x_unverifiable") {
    // On-curve gamma with x in [N, P): rejected by the GammaXUnverifiable guard.
    outputGamma = onCurvePointWithXAboveN();
}

// Encode as (Proof, pkX, pkY, nonce) matching VrfVerifier.Proof struct layout
const PROOF_TYPE = "tuple(tuple(uint256,uint256),uint256,uint256," +
    "tuple(uint256,uint256),tuple(uint256,uint256),tuple(uint256,uint256),uint256)";

const encoded = abiCoder.encode(
    [PROOF_TYPE, "uint256", "uint256", "bytes"],
    [
        [
            [outputGamma.x, outputGamma.y],
            proof.c,
            proof.s,
            [proof.u.x, proof.u.y],
            [proof.cGamma.x, proof.cGamma.y],
            [proof.v.x, proof.v.y],
            proof.zInv,
        ],
        outputPkX,
        outputPkY,
        nonceBytes,
    ]
);

process.stdout.write(encoded);
