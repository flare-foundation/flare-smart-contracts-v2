// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * NodePossessionVerifier internal interface.
 */
interface IINodePossessionVerifier {

    /**
     * Verifies the possession of a node by a voter and reverts if the verification fails.
     * @param _voter The address of the voter.
     * @param _nodeId The node id.
     * @param _certificateRaw Certificate in raw format.
     * @param _signature Signature.
     */
    function verifyNodePossession(
        address _voter,
        bytes20 _nodeId,
        bytes memory _certificateRaw,
        bytes memory _signature
    )
        external view;
}