// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../../tee/implementation/TeeRegistry.sol";

/**
 * TeeDataConnector interface.
 */
interface ITeeDataConnector {

    struct FtdcProve {
        ITeeRegistry.TeeMachineWithAttestationData[] teeMachines;
        uint16 thresholdBIPS;
        bytes attestationRequest;
    }

}
