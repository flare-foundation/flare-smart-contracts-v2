// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { ISafeGovernance } from "./ISafeGovernance.sol";

/**
 * Relay-specific extension of the generic Safe governance interface: the only app-specific
 * action Relay understands is `changeProtocolFees`.
 */
interface IRelayGovernance is ISafeGovernance {

    event GovernanceFeeUpdated(
        uint256 indexed targetChainId,
        uint256 indexed protocolId,
        uint256 feeInWei,
        uint256 safeNonce,
        bytes32 indexed ownerConfigHash
    );

    event GovernanceFeeExemptionUpdated(
        uint256 indexed targetChainId,
        address indexed account,
        bool exempt,
        uint256 safeNonce,
        bytes32 indexed ownerConfigHash
    );

    event GovernanceFeeCollectionUpdated(
        uint256 indexed targetChainId,
        address indexed feeCollectionAddress,
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
