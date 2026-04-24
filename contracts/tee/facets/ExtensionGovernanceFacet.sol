// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IExtensionGovernance } from "../../userInterfaces/tee/IExtensionGovernance.sol";
import { ITeeCommonErrors } from "../../userInterfaces/tee/ITeeCommonErrors.sol";
import { Signature } from "../../userInterfaces/ISignature.sol";
import { ExtensionGovernance } from "../library/ExtensionGovernance.sol";
import { ExtensionManager } from "../library/ExtensionManager.sol";

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title ExtensionGovernanceFacet
 * @notice Facet for managing TEE extension governance signers and pausing addresses.
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
        ExtensionGovernance.TeeExtensionState storage extensionState = s.extensionStates[_extensionId];
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
            require(teeGov.signers.add(_signers[i]), SignerAlreadyExists(_signers[i]));
            extensionState.teePausingAddressesSigner[_signers[i]] = true;
        }
    }

    /// @inheritdoc IExtensionGovernance
    function setTeePausingAddresses(
        uint256 _extensionId,
        address[] calldata _pausingAddresses
    )
        external
    {
        ExtensionManager.checkOnlyExtensionOwner(_extensionId);
        ExtensionGovernance.State storage s = ExtensionGovernance.getState();
        ExtensionGovernance.TeeExtensionState storage extensionState = s.extensionStates[_extensionId];
        uint256 nonce = extensionState.nextPausingAddressesNonce++;
        ExtensionGovernance.TeePausingAddressesState storage teePausingAddresses =
            extensionState.nonceToTeePausingAddresses[nonce];
        for (uint256 i = 0; i < _pausingAddresses.length; i++) {
            require(
                teePausingAddresses.pausingAddresses.add(_pausingAddresses[i]),
                PausingAddressAlreadyExists(_pausingAddresses[i])
            );
        }
        teePausingAddresses.pausingAddressesHash =
            keccak256(abi.encode("TEE_PAUSING_ADDRESSES", nonce, _pausingAddresses));
        emit NewPausingAddressesSet(_extensionId, nonce, _pausingAddresses);
    }

    /// @inheritdoc IExtensionGovernance
    function signTeePausingAddresses(
        uint256 _extensionId,
        uint256 _nonce,
        Signature calldata _signature
    )
        external
    {
        ExtensionGovernance.State storage s = ExtensionGovernance.getState();
        ExtensionGovernance.TeeExtensionState storage extensionState = s.extensionStates[_extensionId];
        require(_nonce < extensionState.nextPausingAddressesNonce, InvalidNonce());
        ExtensionGovernance.TeePausingAddressesState storage teePausingAddresses =
            extensionState.nonceToTeePausingAddresses[_nonce];
        address signer = ECDSA.recover(
            MessageHashUtils.toEthSignedMessageHash(teePausingAddresses.pausingAddressesHash),
            _signature.v,
            _signature.r,
            _signature.s
        );
        require(extensionState.teePausingAddressesSigner[signer], NotASigner(signer));
        require(!teePausingAddresses.signers[signer], AlreadySigned(signer));
        teePausingAddresses.signers[signer] = true;
        teePausingAddresses.signatures.push(_signature);
        emit NewPausingAddressesSigned(_extensionId, _nonce, signer, _signature);
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
            uint64 _signersThreshold
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
            uint64 _signersThreshold
        )
    {
        bytes32 latestHash = ExtensionGovernance.getLatestTeeGovernanceHash(_extensionId);
        require(latestHash != bytes32(0), GovernanceNotSet());
        return _getGovernance(_extensionId, latestHash);
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

    /// @inheritdoc IExtensionGovernance
    function getTeePausingAddresses(
        uint256 _extensionId,
        uint256 _nonce
    )
        external view
        returns (
            address[] memory _pausingAddresses,
            Signature[] memory _signatures
        )
    {
        ExtensionGovernance.State storage s = ExtensionGovernance.getState();
        require(_nonce < s.extensionStates[_extensionId].nextPausingAddressesNonce, InvalidNonce());
        return _getTeePausingAddresses(_extensionId, _nonce);
    }

    /// @inheritdoc IExtensionGovernance
    function getLatestTeePausingAddresses(
        uint256 _extensionId
    )
        external view
        returns (
            uint256 _nonce,
            address[] memory _pausingAddresses,
            Signature[] memory _signatures
        )
    {
        ExtensionGovernance.State storage s = ExtensionGovernance.getState();
        ExtensionGovernance.TeeExtensionState storage extensionState = s.extensionStates[_extensionId];
        require(extensionState.nextPausingAddressesNonce > 0, PausingAddressesNotSet());
        _nonce = extensionState.nextPausingAddressesNonce - 1;
        (_pausingAddresses, _signatures) = _getTeePausingAddresses(_extensionId, _nonce);
    }

    /// @inheritdoc IExtensionGovernance
    function isTeePausingAddressesSigner(
        uint256 _extensionId,
        address _signer
    )
        external view
        returns (bool)
    {
        return ExtensionGovernance.getState().extensionStates[_extensionId].teePausingAddressesSigner[_signer];
    }

    /// @inheritdoc IExtensionGovernance
    function hasSignedTeePausingAddresses(
        uint256 _extensionId,
        uint256 _nonce,
        address _signer
    )
        external view
        returns (bool)
    {
        ExtensionGovernance.State storage s = ExtensionGovernance.getState();
        ExtensionGovernance.TeeExtensionState storage extensionState = s.extensionStates[_extensionId];
        require(_nonce < extensionState.nextPausingAddressesNonce, InvalidNonce());
        return extensionState.nonceToTeePausingAddresses[_nonce].signers[_signer];
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
            uint64 _signersThreshold
        )
    {
        ExtensionGovernance.State storage s = ExtensionGovernance.getState();
        ExtensionGovernance.TeeGovernanceData storage teeGov =
            s.extensionStates[_extensionId].governanceHashToTeeGovernance[_governanceHash];
        _signersThreshold = teeGov.signersThreshold;
        require(_signersThreshold > 0, InvalidGovernanceHash());
        _signers = teeGov.signers.values();
    }

    function _getTeePausingAddresses(
        uint256 _extensionId,
        uint256 _nonce
    )
        private view
        returns (
            address[] memory _pausingAddresses,
            Signature[] memory _signatures
        )
    {
        ExtensionGovernance.State storage s = ExtensionGovernance.getState();
        ExtensionGovernance.TeePausingAddressesState storage teePausingAddresses =
            s.extensionStates[_extensionId].nonceToTeePausingAddresses[_nonce];
        _pausingAddresses = teePausingAddresses.pausingAddresses.values();
        _signatures = teePausingAddresses.signatures;
    }
}
