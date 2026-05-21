// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IExtensionPausing } from "../../userInterfaces/tee/IExtensionPausing.sol";
import { ITeeCommonErrors } from "../../userInterfaces/tee/ITeeCommonErrors.sol";
import { Signature } from "../../userInterfaces/ISignature.sol";
import { ExtensionGovernance } from "../library/ExtensionGovernance.sol";
import { ExtensionManager } from "../library/ExtensionManager.sol";
import { ExtensionPausing } from "../library/ExtensionPausing.sol";

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title ExtensionPausingFacet
 * @notice Facet for managing per-extension TEE pausing-addresses records pinned to one or more
 *         governance configurations. Each pinned governance hash maintains its own approval;
 *         signature collection across all approvals is independent.
 */
contract ExtensionPausingFacet is IExtensionPausing {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @inheritdoc IExtensionPausing
    function setTeePausingAddresses(
        uint256 _extensionId,
        bytes32[] calldata _governanceHashes,
        address[] calldata _pausingAddresses
    )
        external
    {
        ExtensionManager.checkOnlyExtensionOwner(_extensionId);
        require(_governanceHashes.length > 0, NoGovernanceHashes());
        // Validate each hash is known AND ensure no duplicates within the list.
        // Pairwise comparison is fine for small N; duplicates would otherwise make the record
        // permanently unsignable (the inner-loop iteration would always hit AlreadySigned).
        for (uint256 i = 0; i < _governanceHashes.length; i++) {
            require(
                ExtensionGovernance.isGovernanceHashValid(_extensionId, _governanceHashes[i]),
                ITeeCommonErrors.InvalidGovernanceHash()
            );
            for (uint256 j = i + 1; j < _governanceHashes.length; j++) {
                require(
                    _governanceHashes[i] != _governanceHashes[j],
                    DuplicateGovernanceHash()
                );
            }
        }

        ExtensionPausing.State storage s = ExtensionPausing.getState();
        ExtensionPausing.TeeExtensionPausingState storage extensionState =
            s.extensionStates[_extensionId];
        uint256 nonce = extensionState.nextPausingAddressesNonce++;
        ExtensionPausing.TeePausingAddressesRecord storage record =
            extensionState.nonceToTeePausingAddresses[nonce];
        for (uint256 i = 0; i < _pausingAddresses.length; i++) {
            require(
                record.pausingAddresses.add(_pausingAddresses[i]),
                PausingAddressAlreadyExists(_pausingAddresses[i])
            );
        }
        for (uint256 i = 0; i < _governanceHashes.length; i++) {
            record.governanceHashes.push(_governanceHashes[i]);
        }
        record.messageHash = keccak256(
            abi.encode(
                "TEE_PAUSING_ADDRESSES",
                block.chainid,
                _extensionId,
                nonce,
                _governanceHashes,
                _pausingAddresses
            )
        );
        emit NewPausingAddressesSet(_extensionId, nonce, _governanceHashes, _pausingAddresses);
    }

    /// @inheritdoc IExtensionPausing
    function signTeePausingAddresses(
        uint256 _extensionId,
        uint256 _nonce,
        Signature calldata _signature
    )
        external
    {
        ExtensionPausing.State storage s = ExtensionPausing.getState();
        ExtensionPausing.TeeExtensionPausingState storage extensionState =
            s.extensionStates[_extensionId];
        require(_nonce < extensionState.nextPausingAddressesNonce, ITeeCommonErrors.InvalidNonce());
        ExtensionPausing.TeePausingAddressesRecord storage record =
            extensionState.nonceToTeePausingAddresses[_nonce];

        address signer = ECDSA.recover(
            MessageHashUtils.toEthSignedMessageHash(record.messageHash),
            _signature.v,
            _signature.r,
            _signature.s
        );

        bool anyMatch;
        uint256 hashesLen = record.governanceHashes.length;
        for (uint256 i = 0; i < hashesLen; i++) {
            bytes32 governanceHash = record.governanceHashes[i];
            if (!ExtensionGovernance.isTeeGovernanceSigner(_extensionId, governanceHash, signer)) {
                continue;
            }
            anyMatch = true;
            ExtensionPausing.TeePausingApproval storage approval = record.approvals[governanceHash];
            require(!approval.hasSigned[signer], AlreadySigned(signer));
            approval.hasSigned[signer] = true;
            approval.signatureCount++;
            emit NewPausingAddressesSigned(_extensionId, _nonce, governanceHash, signer, _signature);

            // Per-hash threshold detection. Note: we do NOT short-circuit the outer
            // loop — every matching approval still gets credited for this signature, and
            // every approval may independently reach its threshold on a later sign.
            if (!approval.thresholdMet &&
                approval.signatureCount >=
                    ExtensionGovernance.getTeeGovernanceThreshold(_extensionId, governanceHash))
            {
                approval.thresholdMet = true;
                emit TeePausingAddressesThresholdMet(_extensionId, _nonce, governanceHash);
            }
        }
        require(anyMatch, NotASigner(signer));

        // Canonical, deduplicated write — happens once per accepted sign call regardless of
        // how many approvals the signer was valid under.
        record.signatures.push(_signature);
    }

    /// @inheritdoc IExtensionPausing
    function getTeePausingAddresses(
        uint256 _extensionId,
        uint256 _nonce
    )
        external view
        returns (
            address[] memory _pausingAddresses,
            bytes32[] memory _governanceHashes,
            Signature[][] memory _signaturesPerHash,
            bool[] memory _thresholdMetPerHash
        )
    {
        ExtensionPausing.State storage s = ExtensionPausing.getState();
        require(
            _nonce < s.extensionStates[_extensionId].nextPausingAddressesNonce,
            ITeeCommonErrors.InvalidNonce()
        );
        return _getTeePausingAddresses(_extensionId, _nonce);
    }

    /// @inheritdoc IExtensionPausing
    function getLatestTeePausingAddresses(
        uint256 _extensionId
    )
        external view
        returns (
            uint256 _nonce,
            address[] memory _pausingAddresses,
            bytes32[] memory _governanceHashes,
            Signature[][] memory _signaturesPerHash,
            bool[] memory _thresholdMetPerHash
        )
    {
        ExtensionPausing.State storage s = ExtensionPausing.getState();
        ExtensionPausing.TeeExtensionPausingState storage extensionState =
            s.extensionStates[_extensionId];
        require(extensionState.nextPausingAddressesNonce > 0, PausingAddressesNotSet());
        _nonce = extensionState.nextPausingAddressesNonce - 1;
        (_pausingAddresses, _governanceHashes, _signaturesPerHash, _thresholdMetPerHash) =
            _getTeePausingAddresses(_extensionId, _nonce);
    }

    /// @inheritdoc IExtensionPausing
    function hasSignedTeePausingAddresses(
        uint256 _extensionId,
        uint256 _nonce,
        bytes32 _governanceHash,
        address _signer
    )
        external view
        returns (bool)
    {
        ExtensionPausing.State storage s = ExtensionPausing.getState();
        ExtensionPausing.TeeExtensionPausingState storage extensionState =
            s.extensionStates[_extensionId];
        require(_nonce < extensionState.nextPausingAddressesNonce, ITeeCommonErrors.InvalidNonce());
        return extensionState.nonceToTeePausingAddresses[_nonce].approvals[_governanceHash].hasSigned[_signer];
    }

    // =========================================================================
    // Private helpers
    // =========================================================================

    function _getTeePausingAddresses(
        uint256 _extensionId,
        uint256 _nonce
    )
        private view
        returns (
            address[] memory _pausingAddresses,
            bytes32[] memory _governanceHashes,
            Signature[][] memory _signaturesPerHash,
            bool[] memory _thresholdMetPerHash
        )
    {
        ExtensionPausing.State storage s = ExtensionPausing.getState();
        ExtensionPausing.TeePausingAddressesRecord storage record =
            s.extensionStates[_extensionId].nonceToTeePausingAddresses[_nonce];
        _pausingAddresses = record.pausingAddresses.values();
        uint256 hashesLen = record.governanceHashes.length;
        uint256 sigsLen = record.signatures.length;

        _governanceHashes = new bytes32[](hashesLen);
        _signaturesPerHash = new Signature[][](hashesLen);
        _thresholdMetPerHash = new bool[](hashesLen);

        // 1. Pre-size each per-hash bucket from the on-chain signatureCount counters.
        uint256[] memory cursors = new uint256[](hashesLen);
        for (uint256 j = 0; j < hashesLen; j++) {
            bytes32 governanceHash = record.governanceHashes[j];
            _governanceHashes[j] = governanceHash;
            ExtensionPausing.TeePausingApproval storage approval = record.approvals[governanceHash];
            _signaturesPerHash[j] = new Signature[](approval.signatureCount);
            _thresholdMetPerHash[j] = approval.thresholdMet;
        }

        // 2. Single pass: read each signature once, recover its signer, and distribute into
        //    every per-hash bucket the signer is a member of (via the `hasSigned` mapping).
        //    Signatures appear in each bucket in their original chronological order.
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(record.messageHash);
        for (uint256 i = 0; i < sigsLen; i++) {
            Signature memory sig = record.signatures[i];
            address signer = ECDSA.recover(ethSignedMessageHash, sig.v, sig.r, sig.s);
            for (uint256 j = 0; j < hashesLen; j++) {
                if (record.approvals[_governanceHashes[j]].hasSigned[signer]) {
                    _signaturesPerHash[j][cursors[j]++] = sig;
                }
            }
        }
    }
}
