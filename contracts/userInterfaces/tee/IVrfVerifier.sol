// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * @title IVrfVerifier
 * @notice On-chain verification of VRF proofs on secp256k1
 *         with optimization to reduce gas costs.
 */
interface IVrfVerifier {

    struct Point {
        uint256 x;
        uint256 y;
    }

    /**
     * Extended VRF proof that includes the witness points needed for
     * the ecrecover-based gas optimization.
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

    /// Public key point does not satisfy y² = x³ + 7.
    error PkNotOnCurve();

    /// Public key x-coordinate is in [N, P) and therefore cannot be checked via the ecrecover trick.
    error PkXUnverifiable();

    /// Gamma point does not satisfy y² = x³ + 7.
    error GammaNotOnCurve();

    /// Gamma x-coordinate is in [N, P) and therefore cannot be checked via the ecrecover trick.
    error GammaXUnverifiable();

    /// Challenge scalar c is zero or >= curve order N.
    error COutOfRange();

    /// Response scalar s is >= curve order N.
    error SOutOfRange();

    /// Hash-to-curve x-coordinate is in [N, P) and therefore cannot be checked via the ecrecover trick.
    error HXUnverifiable();

    /// Witness point u does not match c·pk + s·G.
    error InvalidUWitness();

    /// Witness point cGamma does not match c·gamma.
    error InvalidCGammaWitness();

    /// Hash-to-curve failed to find a valid point within 256 iterations.
    error HashToCurveExceededIterationLimit();

    /// Provided zInv is not the modular inverse of (cGamma.x - v.x).
    error InvalidZInv();

    /// Witness point v does not match c·gamma + s·h.
    error InvalidVWitness();

    /**
     * Verify a VRF proof using the ecrecover trick for cheap secp256k1
     * scalar-multiplication checks.
     * @param _proof  Extended proof including witness points (see struct above).
     * @param _pkX    Prover's public key x-coordinate.
     * @param _pkY    Prover's public key y-coordinate.
     * @param _nonce  The nonce used to generate the proof.
     * @return _valid  True iff the proof is valid for (pk, nonce).
     */
    function verifyRandomness(
        Proof calldata _proof,
        uint256 _pkX,
        uint256 _pkY,
        bytes calldata _nonce
    )
        external view
        returns (bool _valid);

    /**
     * Derive the randomness output from a gamma point.
     * @dev This function performs NO verification — it simply hashes the gamma coordinates.
     *      It MUST only be called with a gamma that has already been accepted by
     *      {verifyRandomness}; calling it on an unverified gamma yields the hash of
     *      attacker-chosen data, not verified randomness.
     */
    function randomnessFromProof(
        uint256 _gammaX,
        uint256 _gammaY
    )
        external pure
        returns (bytes32);
}
