// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { IExtensionGovernance } from "../../userInterfaces/tee/IExtensionGovernance.sol";
import { ITeeCommonErrors } from "../../userInterfaces/tee/ITeeCommonErrors.sol";
import { ISafeMinimal } from "../../utils/interface/ISafeMinimal.sol";
import { ExtensionGovernance } from "../library/ExtensionGovernance.sol";
import { ExtensionManager } from "../library/ExtensionManager.sol";
import { SafeTransactionVerifier } from "../library/SafeTransactionVerifier.sol";

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title ExtensionGovernanceFacet
 * @notice Facet for managing per-extension TEE governance configurations (signer set + threshold).
 */
contract ExtensionGovernanceFacet is IExtensionGovernance {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @inheritdoc IExtensionGovernance
    function setNewTeeGovernance(
        uint256 _extensionId,
        address[] calldata _signers,
        uint64 _signersThreshold
    )
        external
    {
        ExtensionManager.checkOnlyExtensionOwner(_extensionId);
        ExtensionGovernance.State storage s = ExtensionGovernance.getState();
        ExtensionGovernance.TeeExtensionGovernanceState storage extensionState =
            s.extensionStates[_extensionId];
        require(_signers.length > 0, NoSigners());
        require(
            _signersThreshold > 0 && _signersThreshold <= _signers.length,
            ITeeCommonErrors.InvalidThreshold()
        );
        bytes32 governanceHash = keccak256(abi.encode(_signers, _signersThreshold));
        emit NewTeeGovernanceSet(_extensionId, governanceHash, _signers, _signersThreshold);
        extensionState.latestTeeGovernanceHash = governanceHash;
        ExtensionGovernance.TeeGovernanceData storage teeGov =
            extensionState.governanceHashToTeeGovernance[governanceHash];
        if (teeGov.signersThreshold > 0) {
            return; // already set - just update the latest governance hash
        }
        teeGov.signersThreshold = _signersThreshold;
        for (uint256 i = 0; i < _signers.length; i++) {
            require(_signers[i] != address(0), InvalidSigner());
            require(teeGov.signers.add(_signers[i]), SignerAlreadyExists(_signers[i]));
        }
    }

    /// @inheritdoc IExtensionGovernance
    function setNewTeeGovernanceSafe(
        uint256 _extensionId,
        address _safe
    )
        external
    {
        ExtensionManager.checkOnlyExtensionOwner(_extensionId);
        address[] memory owners = ISafeMinimal(_safe).getOwners();
        uint256 threshold = ISafeMinimal(_safe).getThreshold();
        require(owners.length > 0, NoSigners());
        require(threshold > 0 && threshold <= owners.length, ITeeCommonErrors.InvalidThreshold());
        // Fail fast on incompatible wallets: `confirmMachinePathListSafeApproval` and TEE nodes
        // reconstruct SafeTxHashes under the Safe >= 1.3.0 domain formula, so a Safe whose live
        // domain separator differs (older version, or not a Safe at all) would only ever produce
        // approvals that can never be confirmed. Not a security check — registration already
        // trusts `_safe` for its owner snapshot — just an early, explicit failure.
        require(
            ISafeMinimal(_safe).domainSeparator() == SafeTransactionVerifier.domainSeparator(_safe),
            SafeDomainSeparatorMismatch()
        );
        // Lossless: threshold <= owners.length, and a decoded memory array can never have
        // 2^64 elements (solc caps memory allocations below 2^64 bytes, i.e. length < 2^59).
        uint64 signersThreshold = uint64(threshold);
        // Preimage begins with the diamond address — cannot collide with the plain flavor, whose
        // preimage begins with the ABI array-offset word (0x40). A future preimage change would
        // introduce a versioned domain tag as its first word.
        bytes32 governanceHash = keccak256(abi.encode(address(this), _safe, owners, signersThreshold));
        emit NewTeeSafeGovernanceSet(_extensionId, governanceHash, _safe, owners, signersThreshold);
        ExtensionGovernance.TeeExtensionGovernanceState storage extensionState =
            ExtensionGovernance.getState().extensionStates[_extensionId];
        extensionState.latestTeeGovernanceHash = governanceHash;
        ExtensionGovernance.TeeGovernanceData storage teeGov =
            extensionState.governanceHashToTeeGovernance[governanceHash];
        if (teeGov.signersThreshold > 0) {
            return; // already set - just update the latest governance hash
        }
        teeGov.signersThreshold = signersThreshold;
        teeGov.safeAddress = _safe;
        // A genuine Safe never reports zero-address or duplicate owners; validated defensively
        // since `_safe` is only claimed to be a Safe.
        for (uint256 i = 0; i < owners.length; i++) {
            require(owners[i] != address(0), InvalidSigner());
            require(teeGov.signers.add(owners[i]), SignerAlreadyExists(owners[i]));
        }
    }

    /// @inheritdoc IExtensionGovernance
    function getLatestTeeGovernanceHash(
        uint256 _extensionId
    )
        external view
        returns (bytes32)
    {
        return ExtensionGovernance.getLatestTeeGovernanceHash(_extensionId);
    }

    /// @inheritdoc IExtensionGovernance
    function getTeeGovernanceThreshold(
        uint256 _extensionId,
        bytes32 _governanceHash
    )
        external view
        returns (uint64)
    {
        return ExtensionGovernance.getTeeGovernanceThreshold(_extensionId, _governanceHash);
    }

    /// @inheritdoc IExtensionGovernance
    function isTeeGovernanceSigner(
        uint256 _extensionId,
        bytes32 _governanceHash,
        address _signer
    )
        external view
        returns (bool)
    {
        return ExtensionGovernance.isTeeGovernanceSigner(_extensionId, _governanceHash, _signer);
    }

    /// @inheritdoc IExtensionGovernance
    function getTeeGovernance(
        uint256 _extensionId,
        bytes32 _governanceHash
    )
        external view
        returns (
            address[] memory _signers,
            uint64 _signersThreshold,
            address _safe
        )
    {
        return _getGovernance(_extensionId, _governanceHash);
    }

    /// @inheritdoc IExtensionGovernance
    function getLatestTeeGovernance(
        uint256 _extensionId
    )
        external view
        returns (
            address[] memory _signers,
            uint64 _signersThreshold,
            address _safe
        )
    {
        return _getGovernance(_extensionId, ExtensionGovernance.getLatestTeeGovernanceHash(_extensionId));
    }

    /// @inheritdoc IExtensionGovernance
    function isGovernanceHashValid(
        uint256 _extensionId,
        bytes32 _governanceHash
    )
        external view
        returns (bool)
    {
        return ExtensionGovernance.isGovernanceHashValid(_extensionId, _governanceHash);
    }

    // =========================================================================
    // Private helpers
    // =========================================================================

    function _getGovernance(
        uint256 _extensionId,
        bytes32 _governanceHash
    )
        private view
        returns (
            address[] memory _signers,
            uint64 _signersThreshold,
            address _safe
        )
    {
        ExtensionGovernance.State storage s = ExtensionGovernance.getState();
        ExtensionGovernance.TeeGovernanceData storage teeGov =
            s.extensionStates[_extensionId].governanceHashToTeeGovernance[_governanceHash];
        _signersThreshold = teeGov.signersThreshold;
        require(_signersThreshold > 0, ITeeCommonErrors.InvalidGovernanceHash());
        _signers = teeGov.signers.values();
        _safe = teeGov.safeAddress;
    }
}
