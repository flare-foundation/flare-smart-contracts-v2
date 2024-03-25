// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../contracts/protocol/interface/IINodePossessionVerifier.sol";

contract MockNodePossessionVerification is IINodePossessionVerifier {

    address public voter;
    bytes20 public nodeId;

    bytes constant public CERTIFICATE_RAW_TEST = hex"01234567";
    bytes constant public SIGNATURE_TEST = hex"89abcdef";

    function setVoterAndNodeId(address _voter, bytes20 _nodeId) external {
        voter = _voter;
        nodeId = _nodeId;
    }

    function verifyNodePossession(
        address _voter,
        bytes20 _nodeId,
        bytes memory _certificateRaw,
        bytes memory _signature
    )
        external view
    {

        require(
            _voter == voter &&
            _nodeId == nodeId &&
            _certificateRaw.length == CERTIFICATE_RAW_TEST.length &&
            _signature.length == SIGNATURE_TEST.length,
            "node possession verification failed");
        for (uint256 i = 0; i < _certificateRaw.length; i++) {
            require(_certificateRaw[i] == CERTIFICATE_RAW_TEST[i], "node possession verification failed");
        }
        for (uint256 i = 0; i < _signature.length; i++) {
            require(_signature[i] == SIGNATURE_TEST[i], "node possession verification failed");
        }
    }
}