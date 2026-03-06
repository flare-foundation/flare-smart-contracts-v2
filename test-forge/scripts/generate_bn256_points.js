/**
 * Generates bn254 (alt_bn128) test data for Forge tests.
 * Called via vm.ffi() from Bn256.t.sol.
 *
 * Usage: node generate_bn256_points.js <mode>
 *   mode: "add" | "mul"
 *
 * "add" outputs ABI-encoded: (ax, ay, bx, by, cx, cy)
 *   where a, b are random G1 points and c = a + b.
 *
 * "mul" outputs ABI-encoded: (ax, ay, scalar, cx, cy)
 *   where a is a random G1 point, scalar is random, and c = a * scalar.
 */

const { bn254 } = require("@noble/curves/bn254");
const { AbiCoder } = require("ethers");
const crypto = require("crypto");

const abiCoder = AbiCoder.defaultAbiCoder();
const N = bn254.CURVE.n;

function randomBigInt(max) {
    const bytes = crypto.randomBytes(32);
    return (BigInt("0x" + bytes.toString("hex")) % (max - 1n)) + 1n;
}

const mode = process.argv[2] || "add";

if (mode === "add") {
    const r1 = randomBigInt(N);
    const r2 = randomBigInt(N);
    const a = bn254.ProjectivePoint.BASE.multiply(r1).toAffine();
    const b = bn254.ProjectivePoint.BASE.multiply(r2).toAffine();
    const c = bn254.ProjectivePoint.fromAffine(a)
        .add(bn254.ProjectivePoint.fromAffine(b))
        .toAffine();

    const encoded = abiCoder.encode(
        ["uint256", "uint256", "uint256", "uint256", "uint256", "uint256"],
        [a.x, a.y, b.x, b.y, c.x, c.y]
    );
    process.stdout.write(encoded);
} else if (mode === "mul") {
    const r1 = randomBigInt(N);
    const r2 = randomBigInt(N);
    const a = bn254.ProjectivePoint.BASE.multiply(r1).toAffine();
    const c = bn254.ProjectivePoint.fromAffine(a).multiply(r2).toAffine();

    const encoded = abiCoder.encode(
        ["uint256", "uint256", "uint256", "uint256", "uint256"],
        [a.x, a.y, r2, c.x, c.y]
    );
    process.stdout.write(encoded);
}
