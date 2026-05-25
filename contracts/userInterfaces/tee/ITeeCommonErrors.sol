// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * @title ITeeCommonErrors
 * @notice Shared error declarations used across multiple FlareTeeManager facet interfaces.
 * @dev Extracted to avoid "Identifier already declared" conflicts when facet interfaces
 *      are combined into aggregate interfaces (IFlareTeeManager, IIFlareTeeManager).
 */
interface ITeeCommonErrors {

    // =========================================================================
    // Access control
    // =========================================================================

    error OnlyOwner();
    error OnlyExtensionOwner();
    error OnlyProposedOwner();
    error OnlyOwnerOrBackupManager();
    error OnlyProductionOrPausedStatus();
    error OwnerNotAllowed();
    error NotOwnerOrPauser(address caller);
    error NotOwnerOrUnpauser(address caller);

    // =========================================================================
    // Validation
    // =========================================================================

    error ExtensionIdMismatch();
    error TeeMachineNotAvailable();
    error InvalidKeyType();
    error InvalidSigningAlgo();
    error InvalidPublicKey();
    error InvalidDuration();
    error InvalidResponseData();
    error InvalidThreshold();
    error InvalidCosigner(address cosigner);
    error DuplicatedCosigner(address cosigner);
    error InvalidAvailabilityCheckStatus();
    error InvalidWalletStatus();
    error LengthsMismatch();
    error VersionNotSupported();
    error AvailabilityCheckTimestampInvalid();
    error KeyTypeNotSupported(bytes32 keyType);
    error InvalidNonce();
    error InvalidGovernanceHash();
    error InvalidAddress();
    error AddressAlreadyInSet(address addr);
    error AddressNotInSet(address addr);
    error NoAddresses();
}
