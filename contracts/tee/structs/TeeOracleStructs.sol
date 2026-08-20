// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9;

import { ITeeOracleFeedStore } from "../../userInterfaces/tee/ITeeOracleFeedStore.sol";
import {
    ITeeOracleInstructionsSender
} from "../../userInterfaces/tee/ITeeOracleInstructionsSender.sol";

/**
 * @title TeeOracleStructs
 * @notice ABI-only re-export of the TEE oracle payload structs so off-chain tooling can
 *         look up their layout via the compiled artifact (same pattern as the TEE structs
 *         interfaces). Not deployed; not called.
 */
interface TeeOracleStructs {

    function feedUpdateStruct(ITeeOracleFeedStore.FeedUpdate calldata) external;

    function endpointsStruct(ITeeOracleInstructionsSender.Endpoints calldata) external;

    function endpointGroupStruct(ITeeOracleInstructionsSender.EndpointGroup calldata) external;

    function endpointStruct(ITeeOracleInstructionsSender.Endpoint calldata) external;

    function adminsStruct(ITeeOracleInstructionsSender.Admins calldata) external;

    function adminRoleStruct(ITeeOracleInstructionsSender.AdminRole calldata) external;
}
