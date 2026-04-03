// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ITeeGovernanceFacet } from "../../userInterfaces/tee/ITeeGovernanceFacet.sol";
import { ITeeCommonErrors } from "../../userInterfaces/tee/ITeeCommonErrors.sol";
import { Signature } from "../../userInterfaces/ISignature.sol";
import { TeeGovernance } from "../library/TeeGovernance.sol";
import { TeeExtensionRegistry } from "../library/TeeExtensionRegistry.sol";

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title TeeGovernanceFacet
 * @notice Facet for managing TEE extension governance signers and pausing addresses.
 */
contract TeeGovernanceFacet is ITeeGovernanceFacet {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @inheritdoc ITeeGovernanceFacet
    function setNewTeeGovernance(
        uint256 _extensionId,
        address[] calldata _signers,
        uint64 _signersThreshold
    )
        external
    {
        TeeExtensionRegistry.checkOnlyExtensionOwner(_extensionId);
        TeeGovernance.State storage s = TeeGovernance.getState();
        TeeGovernance.TeeExtensionState storage extensionState = s.extensionStates[_extensionId];
        require(_signers.length > 0, NoSigners());
        require(
            _signersThreshold > 0 && _signersThreshold <= _signers.length,
            ITeeCommonErrors.InvalidThreshold()
        );
        bytes32 governanceHash = keccak256(abi.encode(_signers, _signersThreshold));
        emit NewTeeGovernanceSet(_extensionId, governanceHash, _signers, _signersThreshold);
        extensionState.latestTeeGovernanceHash = governanceHash;
        TeeGovernance.TeeGovernanceData storage teeGov =
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

    /// @inheritdoc ITeeGovernanceFacet
    function setTeePausingAddresses(
        uint256 _extensionId,
        address[] calldata _pausingAddresses
    )
        external
    {
        TeeExtensionRegistry.checkOnlyExtensionOwner(_extensionId);
        TeeGovernance.State storage s = TeeGovernance.getState();
        TeeGovernance.TeeExtensionState storage extensionState = s.extensionStates[_extensionId];
        uint256 nonce = extensionState.nextPausingAddressesNonce++;
        TeeGovernance.TeePausingAddressesState storage teePausingAddresses =
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

    /// @inheritdoc ITeeGovernanceFacet
    function signTeePausingAddresses(
        uint256 _extensionId,
        uint256 _nonce,
        Signature calldata _signature
    )
        external
    {
        TeeGovernance.State storage s = TeeGovernance.getState();
        TeeGovernance.TeeExtensionState storage extensionState = s.extensionStates[_extensionId];
        require(_nonce < extensionState.nextPausingAddressesNonce, InvalidNonce());
        TeeGovernance.TeePausingAddressesState storage teePausingAddresses =
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

    /// @inheritdoc ITeeGovernanceFacet
    function getLatestTeeGovernanceHash(
        uint256 _extensionId
    )
        external view
        returns (bytes32)
    {
        return TeeGovernance.getLatestTeeGovernanceHash(_extensionId);
    }

    /// @inheritdoc ITeeGovernanceFacet
    function getTeeGovernanceThreshold(
        uint256 _extensionId,
        bytes32 _governanceHash
    )
        external view
        returns (uint64)
    {
        return TeeGovernance.getTeeGovernanceThreshold(_extensionId, _governanceHash);
    }

    /// @inheritdoc ITeeGovernanceFacet
    function isTeeGovernanceSigner(
        uint256 _extensionId,
        bytes32 _governanceHash,
        address _signer
    )
        external view
        returns (bool)
    {
        return TeeGovernance.isTeeGovernanceSigner(_extensionId, _governanceHash, _signer);
    }

    /// @inheritdoc ITeeGovernanceFacet
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

    /// @inheritdoc ITeeGovernanceFacet
    function getLatestTeeGovernance(
        uint256 _extensionId
    )
        external view
        returns (
            address[] memory _signers,
            uint64 _signersThreshold
        )
    {
        bytes32 latestHash = TeeGovernance.getLatestTeeGovernanceHash(_extensionId);
        require(latestHash != bytes32(0), GovernanceNotSet());
        return _getGovernance(_extensionId, latestHash);
    }

    /// @inheritdoc ITeeGovernanceFacet
    function isGovernanceHashValid(
        uint256 _extensionId,
        bytes32 _governanceHash
    )
        external view
        returns (bool)
    {
        return TeeGovernance.isGovernanceHashValid(_extensionId, _governanceHash);
    }

    /// @inheritdoc ITeeGovernanceFacet
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
        TeeGovernance.State storage s = TeeGovernance.getState();
        require(_nonce < s.extensionStates[_extensionId].nextPausingAddressesNonce, InvalidNonce());
        return _getTeePausingAddresses(_extensionId, _nonce);
    }

    /// @inheritdoc ITeeGovernanceFacet
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
        TeeGovernance.State storage s = TeeGovernance.getState();
        TeeGovernance.TeeExtensionState storage extensionState = s.extensionStates[_extensionId];
        require(extensionState.nextPausingAddressesNonce > 0, PausingAddressesNotSet());
        _nonce = extensionState.nextPausingAddressesNonce - 1;
        (_pausingAddresses, _signatures) = _getTeePausingAddresses(_extensionId, _nonce);
    }

    /// @inheritdoc ITeeGovernanceFacet
    function isTeePausingAddressesSigner(
        uint256 _extensionId,
        address _signer
    )
        external view
        returns (bool)
    {
        return TeeGovernance.getState().extensionStates[_extensionId].teePausingAddressesSigner[_signer];
    }

    /// @inheritdoc ITeeGovernanceFacet
    function hasSignedTeePausingAddresses(
        uint256 _extensionId,
        uint256 _nonce,
        address _signer
    )
        external view
        returns (bool)
    {
        TeeGovernance.State storage s = TeeGovernance.getState();
        TeeGovernance.TeeExtensionState storage extensionState = s.extensionStates[_extensionId];
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
        TeeGovernance.State storage s = TeeGovernance.getState();
        TeeGovernance.TeeGovernanceData storage teeGov =
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
        TeeGovernance.State storage s = TeeGovernance.getState();
        TeeGovernance.TeePausingAddressesState storage teePausingAddresses =
            s.extensionStates[_extensionId].nonceToTeePausingAddresses[_nonce];
        _pausingAddresses = teePausingAddresses.pausingAddresses.values();
        _signatures = teePausingAddresses.signatures;
    }
}
