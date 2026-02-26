// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title VRFVerifier
 * @notice On-chain verification of VRF proofs on secp256k1
 *         with optimization to reduce gas costs.
 */
contract VRFVerifier {
    /// @dev Field prime p = 2^256 − 2^32 − 977
    uint256 internal constant P =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F;

    /// @dev Curve order N
    uint256 internal constant N =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;

    /// @dev Generator point
    uint256 internal constant GX =
        0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798;
    uint256 internal constant GY =
        0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8;

    /// @dev Curve coefficient b (y² = x³ + 7)
    uint256 internal constant CURVE_B = 7;

    /// @dev (P+1)/4  — valid exponent for modular square root because P ≡ 3 mod 4
    uint256 internal constant SQRT_EXP =
        0x3FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFBFFFFF0C;

    struct Point {
        uint256 x;
        uint256 y;
    }

    /**
     * @notice Extended VRF proof that includes the witness points needed for
     *         the ecrecover-based gas optimization.
     *
     * @param gamma   gamma = sk · HashToG1(nonce)
     * @param c       Challenge scalar
     * @param s       Response scalar  (s = k − sk·c mod N)
     * @param u       u = c·pk + s·G         (witness)
     * @param cGamma  c·gamma                (witness, intermediate for v)
     * @param v       v = c·gamma + s·h      (witness)
     * @param zInv    modInv(cGamma.x − v.x, P)  (avoids BigModExp for point subtraction)
     */
    struct Proof {
        Point gamma;
        uint256 c;
        uint256 s;
        // witness points (computed off-chain by the prover to save gas on-chain)
        Point u;
        Point cGamma;
        Point v;
        uint256 zInv;
    }

    /**
     * @notice Verify a VRF proof using the ecrecover trick for cheap secp256k1
     *         scalar-multiplication checks.
     *
     * @param proof  Extended proof including witness points (see struct above).
     * @param pkX    Prover's public key x-coordinate.
     * @param pkY    Prover's public key y-coordinate.
     * @param nonce  The nonce used to generate the proof.
     *
     * @return valid  True iff the proof is valid for (pk, nonce).
     */
    function verifyRandomness(
        Proof calldata proof,
        uint256 pkX,
        uint256 pkY,
        bytes calldata nonce
    ) external view returns (bool valid) {
        // ── input validation ────────────────────────────────────────────────
        require(_isOnCurve(Point(pkX, pkY)), "VRF: pk not on curve");
        require(_isOnCurve(proof.gamma), "VRF: gamma not on curve");
        require(proof.c > 0 && proof.c < N, "VRF: c out of range");
        require(proof.s < N, "VRF: s out of range");

        // Hash the nonce to a curve point.
        Point memory h = _hashToCurve(nonce);

        // Guard against the rare case h.x >= N (would make ecrecover invalid).
        // Probability ≈ (P − N) / P ≈ 2^{−128}.
        require(h.x < N, "VRF: h.x >= N (degenerate input)");

        // verify witnesses u and cGamma
        address wantU = _toAddress(proof.u.x, proof.u.y);
        require(
            wantU != address(0) &&
                wantU == _ecMulAddr(proof.s, pkX, pkY, proof.c),
            "VRF: invalid u witness"
        );

        address wantCG = _toAddress(proof.cGamma.x, proof.cGamma.y);
        require(
            wantCG != address(0) &&
                wantCG == _ecMulAddr(0, proof.gamma.x, proof.gamma.y, proof.c),
            "VRF: invalid cGamma witness"
        );

        // verify zInv, used for cheap point subtraction in the v witness check below
        uint256 denom = addmod(proof.cGamma.x, P - proof.v.x, P);
        require(
            denom != 0 && mulmod(proof.zInv, denom, P) == 1,
            "VRF: invalid zInv"
        );

        // verify witness v
        uint256 num = addmod(P - proof.cGamma.y, P - proof.v.y, P);
        uint256 lambda = mulmod(num, proof.zInv, P);
        uint256 wx = addmod(
            addmod(mulmod(lambda, lambda, P), P - proof.v.x, P),
            P - proof.cGamma.x,
            P
        );
        uint256 wy = addmod(
            mulmod(lambda, addmod(proof.v.x, P - wx, P), P),
            P - proof.v.y,
            P
        );
        address wantW = _toAddress(wx, wy);
        require(
            wantW != address(0) && wantW == _ecMulAddr(0, h.x, h.y, proof.s),
            "VRF: invalid v witness"
        );

        // verify the proof
        bytes memory packed = abi.encode(
            GX,
            GY,
            h.x,
            h.y,
            pkX,
            pkY,
            proof.gamma.x,
            proof.gamma.y,
            proof.u.x,
            proof.u.y,
            proof.v.x,
            proof.v.y
        );
        valid = (_hashToZn(packed) == proof.c);
    }

    /**
     * @dev Derive the randomness output from a verified gamma point.
     */
    function randomnessFromProof(
        uint256 gammaX,
        uint256 gammaY
    ) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(bytes32(gammaX), bytes32(gammaY)));
    }

    /**
     * @dev Hash bytes to a secp256k1 point (try-and-rehash).
     */
    function _hashToCurve(
        bytes memory input
    ) internal view returns (Point memory) {
        bytes32 buf = keccak256(input);
        uint256 x = uint256(buf) % P;
        for (uint256 i = 0; i < 256; i++) {
            // probability of a valid point is ≈ 1/2, so 256 iterations is enough for negligible failure probability
            uint256 rhs = addmod(mulmod(mulmod(x, x, P), x, P), CURVE_B, P);
            uint256 y = _modSqrt(rhs);
            if (y != 0) {
                return Point(x, y);
            }
            buf = keccak256(abi.encodePacked(buf));
            x = uint256(buf) % P;
        }
        revert("VRF: HashToCurve exceeded iteration limit");
    }

    /// @dev keccak256(data) as uint256, reduced mod N.
    function _hashToZn(bytes memory data) internal pure returns (uint256) {
        return uint256(keccak256(data)) % N;
    }

    /// @dev Modular square root: a^((P+1)/4) mod P.  Returns 0 if a is not a QR.
    function _modSqrt(uint256 a) internal view returns (uint256 result) {
        if (a == 0) return 0;
        result = _modExp(a, SQRT_EXP, P);
        if (mulmod(result, result, P) != a) return 0;
    }

    /// @dev Modular exponentiation via EVM precompile 0x05 (BigModExp).
    function _modExp(
        uint256 base,
        uint256 exponent,
        uint256 modulus
    ) internal view returns (uint256 result) {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x20)
            mstore(add(ptr, 0x20), 0x20)
            mstore(add(ptr, 0x40), 0x20)
            mstore(add(ptr, 0x60), base)
            mstore(add(ptr, 0x80), exponent)
            mstore(add(ptr, 0xa0), modulus)
            if iszero(staticcall(gas(), 0x05, ptr, 0xc0, ptr, 0x20)) {
                revert(0, 0)
            }
            result := mload(ptr)
        }
    }

    /// @dev True iff (x,y) satisfies y² = x³ + 7 mod P.
    function _isOnCurve(Point memory p) internal pure returns (bool) {
        uint256 lhs = mulmod(p.y, p.y, P);
        uint256 rhs = addmod(mulmod(mulmod(p.x, p.x, P), p.x, P), CURVE_B, P);
        return lhs == rhs;
    }

    /**
     * @dev Returns addr(a·G + b·P) using the ecrecover trick.
     *      Setting a = 0 gives addr(b·P), because
     *      (N − px·0) mod N = 0 collapses the hash argument to zero.
     */
    function _ecMulAddr(
        uint256 a,
        uint256 px,
        uint256 py,
        uint256 b
    ) internal pure returns (address) {
        return
            ecrecover(
                bytes32((N - mulmod(px, a, N)) % N),
                uint8(27 + (py & 1)),
                bytes32(px),
                bytes32(mulmod(px, b, N))
            );
    }

    /// @dev Ethereum address of a secp256k1 point: keccak256(x ‖ y)[12:].
    function _toAddress(uint256 x, uint256 y) internal pure returns (address) {
        return
            address(
                uint160(
                    uint256(keccak256(abi.encodePacked(bytes32(x), bytes32(y))))
                )
            );
    }
}
