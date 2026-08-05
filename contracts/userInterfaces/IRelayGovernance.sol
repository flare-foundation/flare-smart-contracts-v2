// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { ISafeGovernance } from "./ISafeGovernance.sol";

/**
 * Relay-specific extension of the generic Safe governance interface: the only app-specific
 * action Relay understands is `changeProtocolFees`.
 */
interface IRelayGovernance is ISafeGovernance {

    /// A protocol verify() fee was set — at deployment (seeded config) or by a governance
    /// action. Reports only WHAT was set; the authorizing nonce/owner-configuration is reported
    /// once per governance action by `GovernanceSettingsApplied`.
    event ProtocolFeeSet(
        uint8 indexed protocolId,
        uint256 feeInWei
    );

    /// A verify() fee exemption was set — at deployment (seeded config) or by a governance action.
    event FeeExemptionSet(
        address indexed account,
        bool exempt
    );

    /// The verify() fee-collection recipient was set — at deployment (seeded config) or by a
    /// governance action.
    event FeeCollectionAddressSet(
        address indexed feeCollectionAddress
    );

    /// Emitted once per governance action after its settings are applied on this deployment,
    /// identifying the Safe nonce and admitted owner configuration it was authorized under. The
    /// chain id is not reported — an action only ever applies on its own chain. Not emitted at
    /// deployment (no governance action then; the genesis configuration is `GovernanceInitialized`).
    event GovernanceSettingsApplied(
        uint256 safeNonce,
        bytes32 indexed ownerConfigHash
    );

    /// @dev Deprecated: signature failures now revert with the typed ISafeGovernance errors
    /// (or OpenZeppelin ECDSA errors). Retained only for FV-harness compile compatibility
    /// until the formal-verification re-baseline.
    error InvalidGovernanceSignatures();

    /// Renouncing ownership is disabled: it would permanently freeze the implementation.
    /// Ownership only moves via `transferOwnership`.
    error RenounceOwnershipDisabled();

    /// Returns the configured source-network id (RLY-23 origin binding): the network whose
    /// voter quorum and Safe this Relay verifies. Equals block.chainid on home deployments.
    function sourceChainId() external view returns (uint256);

    /// Returns whether `account` may call `verify()` without paying the protocol fee.
    function feeExemptAddress(address account) external view returns (bool);
}
