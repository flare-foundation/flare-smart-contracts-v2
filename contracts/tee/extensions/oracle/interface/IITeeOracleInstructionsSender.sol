// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9;

import {
    ITeeOracleInstructionsSender
} from "../../../../userInterfaces/tee/ITeeOracleInstructionsSender.sol";

/**
 * @title IITeeOracleInstructionsSender
 * @notice Internal interface for the TEE oracle instructions sender — adds the
 *         Flare-governance-only methods on top of the public interface.
 */
interface IITeeOracleInstructionsSender is ITeeOracleInstructionsSender {

    /**
     * Publishes endpoint configuration to the given TEE machines.
     * Assigns the next `endpointsVersion` once for the whole publication, so every targeted
     * machine shares the same version and payload hash (fleet-comparable). Records the
     * expected hash and version per machine BEFORE dispatch (so undelivered instructions
     * block stale submissions), then dispatches one SET_ENDPOINTS instruction to all the
     * machines, forwarding the entire msg.value as the fee — in production mode the executor
     * attaches it to `executeGovernanceCall` (recording rejects value). Fees of unexecuted
     * instructions are claimable to `_claimBackAddress`.
     * Only governance can call this method.
     * @param _teeIds The TEE machines to configure (non-empty, unique, non-zero; the
     * instructions facet requires them all on this extension and in PRODUCTION status).
     * @param _groups The tagged endpoint groups; validated on-chain (see the payload structs).
     * @param _claimBackAddress Address that can claim back the fee if the instructions are
     * not executed (optional, zero to skip).
     */
    function setEndpoints(
        address[] calldata _teeIds,
        EndpointGroup[] calldata _groups,
        address _claimBackAddress
    )
        external payable;

    /**
     * Publishes the role-tagged admin signer sets to the given TEE machines.
     * Same shape as `setEndpoints`: assigns the next `adminsVersion` once for the whole
     * publication, records the expected hash and version per machine before dispatch, then
     * dispatches one SET_ADMINS instruction to all the machines, forwarding the entire
     * msg.value as the fee.
     * Only governance can call this method.
     * @param _teeIds The TEE machines to configure (non-empty, unique, non-zero).
     * @param _roles The role-tagged admin sets; validated on-chain (role-agnostic rules only).
     * @param _claimBackAddress Address that can claim back the fee if the instructions are
     * not executed (optional, zero to skip).
     */
    function setAdmins(
        address[] calldata _teeIds,
        AdminRole[] calldata _roles,
        address _claimBackAddress
    )
        external payable;
}
