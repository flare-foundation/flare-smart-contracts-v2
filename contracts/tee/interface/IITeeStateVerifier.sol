// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../../userInterfaces/tee/ITeeStateVerifier.sol";

interface IITeeStateVerifier is ITeeStateVerifier {

    enum TeeMachineStatus { ACTIVE, PAUSED, PAUSED_FOR_UPGRADE }

    struct TeeMachineState {
        TeeMachineStatus status;
        address initialTeeId; // Id of the TEE machine generated at the machine startup, it never changes.
        bytes32 teeGovernanceHash; // Hash of the TEE governance.
        uint256 nonce;
        uint256 pauseNonce;
    }
}