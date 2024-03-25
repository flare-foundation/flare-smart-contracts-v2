// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * IIPublicKeyVerifier internal interface.
 */
interface IIPublicKeyVerifier {

    /**
     * Verifies the public key ownership for a voter and reverts if the verification fails.
     * @param _voter The address of the voter.
     * @param _part1 First part of the public key.
     * @param _part2 Second part of the public key.
     * @param verificationData Additional data for the verification.
     */
    function verifyPublicKey(
        address _voter,
        bytes32 _part1,
        bytes32 _part2,
        bytes memory verificationData
    )
        external view;
}