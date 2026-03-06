/**
 * Generates Sortition / BN254-VRF test data for Forge tests.
 * Called via vm.ffi() from Sortition.t.sol.
 *
 * Usage: node generate_sortition_data.js <mode>
 *   mode: "signature" | "proof" | "credential"
 *
 * "signature" outputs ABI-encoded: (G1Point pk, bytes32 msg, uint256 s, G1Point r)
 * "proof"     outputs ABI-encoded: (SortitionState, SortitionCredential)
 * "credential" outputs ABI-encoded: (SortitionState, SortitionCredential)
 *              where gamma.x <= scoreCutoff (loops until found)
 */

const { bn254 } = require("@noble/curves/bn254");
const { AbiCoder, keccak256, sha256, solidityPacked } = require("ethers");
const crypto = require("crypto");

const abiCoder = AbiCoder.defaultAbiCoder();
const N = bn254.CURVE.n;
const P = bn254.CURVE.p;

// ── Helpers ────────────────────────────────────────────────────────────────

function randomBigInt(max) {
    const bytes = crypto.randomBytes(32);
    return (BigInt("0x" + bytes.toString("hex")) % (max - 1n)) + 1n;
}

function modPow(base, exp, mod) {
    let result = 1n;
    base = base % mod;
    while (exp > 0n) {
        if (exp & 1n) result = (result * base) % mod;
        exp >>= 1n;
        base = (base * base) % mod;
    }
    return result;
}

/**
 * Matches Bn256.g1YFromX in Solidity.
 * Returns { x, y } or null if x is not a valid x-coordinate.
 */
function g1YFromX(x) {
    const ySquare = (modPow(x, 3n, P) + 3n) % P;
    const raised = modPow(ySquare, (P - 1n) / 2n, P);
    if (raised !== 1n || ySquare === 0n) return null;
    const y = modPow(ySquare, (P + 1n) / 4n, P);
    return { x, y };
}

/**
 * Matches Bn256.g1HashToPoint in Solidity.
 * sha256 + try-and-increment.
 */
function g1HashToPoint(data) {
    const h = BigInt(sha256(data));
    let x = h % P;
    for (;;) {
        const pt = g1YFromX(x);
        if (pt != null) {
            return bn254.ProjectivePoint.fromAffine(pt);
        }
        x += 1n;
    }
}

function generateKey() {
    const sk = randomBigInt(N);
    const pk = bn254.ProjectivePoint.BASE.multiply(sk);
    return { sk, pk };
}

// ── Modes ──────────────────────────────────────────────────────────────────

const mode = process.argv[2] || "signature";

const G1POINT_TYPE = "tuple(uint256,uint256)";
const SORTITION_STATE_TYPE =
    "tuple(uint256,uint256,uint256,uint256,tuple(uint256,uint256))";
const SORTITION_CREDENTIAL_TYPE =
    "tuple(uint256,tuple(uint256,uint256),uint256,uint256)";

if (mode === "submit_update") {
    // Generates data for a valid submitUpdates call.
    // Usage: node generate_sortition_data.js submit_update <baseSeed> <blockNum> <scoreCutoff> <ecdsaPrivKey> [deltasHex]
    // Output: ABI-encoded (pk.x, pk.y, replicate, gamma.x, gamma.y, c, s, ecdsaV, ecdsaR, ecdsaS, deltas)
    (async () => {
    const ethers = require("ethers");
    const { Wallet, getBytes } = ethers;

    const baseSeedArg = BigInt(process.argv[3]);
    const blockNumArg = BigInt(process.argv[4]);
    const scoreCutoffArg = BigInt(process.argv[5]);
    const ecdsaPrivKeyRaw = process.argv[6];
    // Convert decimal or hex string to 0x-prefixed hex
    const ecdsaPrivKey = ecdsaPrivKeyRaw.startsWith("0x")
        ? ecdsaPrivKeyRaw
        : "0x" + BigInt(ecdsaPrivKeyRaw).toString(16).padStart(64, "0");

    const wallet = new Wallet(ecdsaPrivKey);

    // Deltas: use provided hex or empty
    const deltas = process.argv[7] || "0x";

    for (;;) {
        const key = generateKey();
        // Use replicate 0 for simplicity; weight just needs to be > replicate
        const replicate = 0n;

        const seedPacked = solidityPacked(
            ["uint256", "uint256", "uint256"],
            [baseSeedArg, blockNumArg, replicate]
        );
        const h = g1HashToPoint(seedPacked);
        const gamma = h.multiply(key.sk).toAffine();

        // Check if gamma.x passes sortition cutoff
        if (gamma.x > scoreCutoffArg) continue;

        const k2 = randomBigInt(N);
        const u = bn254.ProjectivePoint.BASE.multiply(k2).toAffine();
        const v = h.multiply(k2).toAffine();

        const challengePacked = abiCoder.encode(
            Array(12).fill("uint256"),
            [
                bn254.ProjectivePoint.BASE.x,
                bn254.ProjectivePoint.BASE.y,
                h.x, h.y,
                key.pk.x, key.pk.y,
                gamma.x, gamma.y,
                u.x, u.y,
                v.x, v.y,
            ]
        );
        const c = BigInt(sha256(challengePacked)) % N;
        const s = (((k2 - c * key.sk) % N) + N) % N;

        // Sign the message hash with ECDSA
        // msgHashed = sha256(abi.encode(sortitionBlock, sortitionCredential, deltas))
        const innerEncoded = abiCoder.encode(
            ["uint256", SORTITION_CREDENTIAL_TYPE, "bytes"],
            [blockNumArg, [replicate, [gamma.x, gamma.y], c, s], deltas]
        );
        const msgHashed = sha256(innerEncoded);
        // signMessage handles EIP-191 prefix ("\x19Ethereum Signed Message:\n32" + hash)
        const ecdsaSigRaw = await wallet.signMessage(getBytes(msgHashed));
        const ecdsaSig = ethers.Signature.from(ecdsaSigRaw);

        const encoded = abiCoder.encode(
            [
                "uint256", "uint256",  // pk.x, pk.y
                "uint256",             // replicate
                "uint256", "uint256",  // gamma.x, gamma.y
                "uint256", "uint256",  // c, s
                "uint8", "bytes32", "bytes32",  // ECDSA v, r, s
                "bytes"                // deltas
            ],
            [
                key.pk.x, key.pk.y,
                replicate,
                gamma.x, gamma.y,
                c, s,
                ecdsaSig.v,
                ecdsaSig.r,
                ecdsaSig.s,
                deltas
            ]
        );
        process.stdout.write(encoded);
        break;
    }
    })();
} else if (mode === "verify_key") {
    // Generates a BN254 key + Schnorr signature over sha256(abi.encodePacked(voterAddress))
    // Usage: node generate_sortition_data.js verify_key <voterAddress>
    const voterAddress = process.argv[3];
    const key = generateKey();
    const msg = sha256(solidityPacked(["address"], [voterAddress]));

    const k = randomBigInt(N);
    const r = bn254.ProjectivePoint.BASE.multiply(k).toAffine();
    const packed = solidityPacked(
        ["uint256", "uint256", "bytes32", "uint256", "uint256"],
        [key.pk.x, key.pk.y, msg, r.x, r.y]
    );
    const e = BigInt(keccak256(packed)) % N;
    const s = (((k - key.sk * e) % N) + N) % N;

    // Output: (pk.x, pk.y, s, r.x, r.y)
    const encoded = abiCoder.encode(
        ["uint256", "uint256", "uint256", "uint256", "uint256"],
        [key.pk.x, key.pk.y, s, r.x, r.y]
    );
    process.stdout.write(encoded);
} else if (mode === "signature") {
    const key = generateKey();
    const msg =
        "0x0000000000000000000000000000000000000000000000000000000000000002";

    // Schnorr signature: r = k·G, e = H(pk ‖ msg ‖ r) mod N, s = (k - sk·e) mod N
    const k = randomBigInt(N);
    const r = bn254.ProjectivePoint.BASE.multiply(k).toAffine();
    const packed = solidityPacked(
        ["uint256", "uint256", "bytes32", "uint256", "uint256"],
        [key.pk.x, key.pk.y, msg, r.x, r.y]
    );
    const e = BigInt(keccak256(packed)) % N;
    const s = (((k - key.sk * e) % N) + N) % N;

    const encoded = abiCoder.encode(
        [G1POINT_TYPE, "bytes32", "uint256", G1POINT_TYPE],
        [[key.pk.x, key.pk.y], msg, s, [r.x, r.y]]
    );
    process.stdout.write(encoded);
} else if (mode === "proof" || mode === "credential") {
    const scoreCutoff = 2n ** 248n;

    for (;;) {
        const key = generateKey();
        const baseSeed = randomBigInt(N);
        const blockNum = 1n;
        const replicate = randomBigInt(N);
        const weight = replicate + 1n;

        // Hash to curve: h = g1HashToPoint(encodePacked(baseSeed, blockNum, replicate))
        const seedPacked = solidityPacked(
            ["uint256", "uint256", "uint256"],
            [baseSeed, blockNum, replicate]
        );
        const h = g1HashToPoint(seedPacked);

        // VRF: gamma = sk · h
        const gamma = h.multiply(key.sk).toAffine();

        // Schnorr-like proof: k random, u = k·G, v = k·h
        const k = randomBigInt(N);
        const u = bn254.ProjectivePoint.BASE.multiply(k).toAffine();
        const v = h.multiply(k).toAffine();

        // Challenge: c = sha256(G, h, pk, gamma, u, v) mod N
        const challengePacked = abiCoder.encode(
            Array(12).fill("uint256"),
            [
                bn254.ProjectivePoint.BASE.x,
                bn254.ProjectivePoint.BASE.y,
                h.x,
                h.y,
                key.pk.x,
                key.pk.y,
                gamma.x,
                gamma.y,
                u.x,
                u.y,
                v.x,
                v.y,
            ]
        );
        const c = BigInt(sha256(challengePacked)) % N;
        const s = (((k - c * key.sk) % N) + N) % N;

        if (mode === "proof") {
            // Return any valid proof
            const encoded = abiCoder.encode(
                [SORTITION_STATE_TYPE, SORTITION_CREDENTIAL_TYPE],
                [
                    [baseSeed, blockNum, 0, 0, [key.pk.x, key.pk.y]],
                    [replicate, [gamma.x, gamma.y], c, s],
                ]
            );
            process.stdout.write(encoded);
            break;
        }

        // credential mode: loop until gamma.x <= scoreCutoff
        if (gamma.x <= scoreCutoff) {
            const encoded = abiCoder.encode(
                [SORTITION_STATE_TYPE, SORTITION_CREDENTIAL_TYPE],
                [
                    [
                        baseSeed,
                        blockNum,
                        scoreCutoff,
                        weight,
                        [key.pk.x, key.pk.y],
                    ],
                    [replicate, [gamma.x, gamma.y], c, s],
                ]
            );
            process.stdout.write(encoded);
            break;
        }
    }
}
