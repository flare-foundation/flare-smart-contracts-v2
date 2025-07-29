// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../../userInterfaces/tee/ITeeMachineRegistry.sol";

interface IITeeMachineRegistry is ITeeMachineRegistry {

    /**
     * Changes the status of the TEE machine.
     * @param _teeId The TEE machine id.
     * @param _newStatus The new status of the TEE machine.
     */
    function changeStatus(
        address _teeId,
        TeeStatus _newStatus
    )
        external;

    /**
     * Replicates the TEE machine and put it into production.
     * @param _oldTeeId The old TEE machine id.
     * @param _proof The proof of the replication.
     */
    function replicate(
        address _oldTeeId,
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        external;
}