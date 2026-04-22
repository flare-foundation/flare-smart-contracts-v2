// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IVrfVerifier } from "../../userInterfaces/tee/IVrfVerifier.sol";

/**
 * On-chain verification of VRF proofs on secp256k1
 * with optimization to reduce gas costs.
 */
contract VrfVerifier is IVrfVerifier {

    /// Field prime p = 2^256 − 2^32 − 977
    uint256 internal constant P =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F;

    /// Curve order N
    uint256 internal constant N =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;

    /// Generator point
    uint256 internal constant GX =
        0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798;
    uint256 internal constant GY =
        0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8;

    /// Curve coefficient b (y² = x³ + 7)
    uint256 internal constant CURVE_B = 7;

    /// (P+1)/4  — valid exponent for modular square root because P ≡ 3 mod 4
    uint256 internal constant SQRT_EXP =
        0x3FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFBFFFFF0C;

    /**
     * @inheritdoc IVrfVerifier
     */
    function verifyRandomness(
        Proof calldata _proof,
        uint256 _pkX,
        uint256 _pkY,
        bytes calldata _nonce
    )
        external view
        returns (bool _valid)
    {
        // ── input validation ────────────────────────────────────────────────
        require(_isOnCurve(Point(_pkX, _pkY)), PkNotOnCurve());
        require(_isOnCurve(_proof.gamma), GammaNotOnCurve());
        require(_proof.c > 0 && _proof.c < N, COutOfRange());
        require(_proof.s < N, SOutOfRange());

        // Hash the nonce to a curve point.
        Point memory h = _hashToCurve(_nonce);

        // Guard against the rare case h.x >= N (would make ecrecover invalid).
        // Probability ≈ (P − N) / P ≈ 2^{−128}.
        require(h.x < N, DegenerateInput());

        // verify witnesses u and cGamma
        address wantU = _toAddress(_proof.u.x, _proof.u.y);
        require(
            wantU != address(0) &&
                wantU == _ecMulAddr(_proof.s, _pkX, _pkY, _proof.c),
            InvalidUWitness()
        );

        address wantCG = _toAddress(_proof.cGamma.x, _proof.cGamma.y);
        require(
            wantCG != address(0) &&
                wantCG == _ecMulAddr(0, _proof.gamma.x, _proof.gamma.y, _proof.c),
            InvalidCGammaWitness()
        );

        _verifyVWitness(_proof, h);

        _valid = _verifyChallenge(_proof, _pkX, _pkY, h);
    }

    /**
     * @inheritdoc IVrfVerifier
     */
    function randomnessFromProof(
        uint256 _gammaX,
        uint256 _gammaY
    )
        external pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(bytes32(_gammaX), bytes32(_gammaY)));
    }

    /**
     * Modular exponentiation via EVM precompile 0x05 (BigModExp).
     */
    function _modExp(
        uint256 _base,
        uint256 _exponent,
        uint256 _modulus
    )
        internal view
        returns (uint256 _result)
    {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x20)
            mstore(add(ptr, 0x20), 0x20)
            mstore(add(ptr, 0x40), 0x20)
            mstore(add(ptr, 0x60), _base)
            mstore(add(ptr, 0x80), _exponent)
            mstore(add(ptr, 0xa0), _modulus)
            if iszero(staticcall(gas(), 0x05, ptr, 0xc0, ptr, 0x20)) {
                revert(0, 0)
            }
            _result := mload(ptr)
        }
    }

    /**
     * Hash bytes to a secp256k1 point (try-and-rehash).
     */
    function _hashToCurve(
        bytes memory _input
    )
        internal view
        returns (Point memory)
    {
        bytes32 buf = keccak256(_input);
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
        revert HashToCurveExceededIterationLimit();
    }

    /**
     * Modular square root: a^((P+1)/4) mod P. Returns 0 if a is not a QR.
     */
    function _modSqrt(
        uint256 _a
    )
        internal view
        returns (uint256 _result)
    {
        if (_a == 0) return 0;
        _result = _modExp(_a, SQRT_EXP, P);
        if (mulmod(_result, _result, P) != _a) return 0;
    }

    /**
     * Verify zInv and the v witness point.
     */
    function _verifyVWitness(
        Proof calldata _proof,
        Point memory _h
    )
        internal pure
    {
        // verify zInv, used for cheap point subtraction in the v witness check below
        uint256 denom = addmod(_proof.cGamma.x, P - _proof.v.x, P);
        require(
            denom != 0 && mulmod(_proof.zInv, denom, P) == 1,
            InvalidZInv()
        );

        // verify witness v
        uint256 num = addmod(P - _proof.cGamma.y, P - _proof.v.y, P);
        uint256 lambda = mulmod(num, _proof.zInv, P);
        uint256 wx = addmod(
            addmod(mulmod(lambda, lambda, P), P - _proof.v.x, P),
            P - _proof.cGamma.x,
            P
        );
        uint256 wy = addmod(
            mulmod(lambda, addmod(_proof.v.x, P - wx, P), P),
            P - _proof.v.y,
            P
        );
        address wantW = _toAddress(wx, wy);
        require(
            wantW != address(0) && wantW == _ecMulAddr(0, _h.x, _h.y, _proof.s),
            InvalidVWitness()
        );
    }

    /**
     * Verify the challenge scalar c against the hash of all witness data.
     */
    function _verifyChallenge(
        Proof calldata _proof,
        uint256 _pkX,
        uint256 _pkY,
        Point memory _h
    )
        internal pure
        returns (bool)
    {
        bytes memory packed = bytes.concat(
            abi.encode(GX, GY, _h.x, _h.y, _pkX, _pkY),
            abi.encode(
                _proof.gamma.x, _proof.gamma.y,
                _proof.u.x, _proof.u.y,
                _proof.v.x, _proof.v.y
            )
        );
        return (_hashToZn(packed) == _proof.c);
    }

    /**
     * keccak256(data) as uint256, reduced mod N.
     */
    function _hashToZn(
        bytes memory _data
    )
        internal pure
        returns (uint256)
    {
        return uint256(keccak256(_data)) % N;
    }

    /**
     * True iff (x,y) satisfies y² = x³ + 7 mod P.
     */
    function _isOnCurve(
        Point memory _p
    )
        internal pure
        returns (bool)
    {
        uint256 lhs = mulmod(_p.y, _p.y, P);
        uint256 rhs = addmod(mulmod(mulmod(_p.x, _p.x, P), _p.x, P), CURVE_B, P);
        return lhs == rhs;
    }

    /**
     * Returns addr(a·G + b·P) using the ecrecover trick.
     * Setting a = 0 gives addr(b·P), because
     * (N − px·0) mod N = 0 collapses the hash argument to zero.
     */
    function _ecMulAddr(
        uint256 _a,
        uint256 _px,
        uint256 _py,
        uint256 _b
    )
        internal pure
        returns (address)
    {
        return
            ecrecover(
                bytes32((N - mulmod(_px, _a, N)) % N),
                uint8(27 + (_py & 1)),
                bytes32(_px),
                bytes32(mulmod(_px, _b, N))
            );
    }

    /**
     * Ethereum address of a secp256k1 point: keccak256(x ‖ y)[12:].
     */
    function _toAddress(
        uint256 _x,
        uint256 _y
    )
        internal pure
        returns (address)
    {
        return
            address(
                uint160(
                    uint256(keccak256(abi.encodePacked(bytes32(_x), bytes32(_y))))
                )
            );
    }
}
