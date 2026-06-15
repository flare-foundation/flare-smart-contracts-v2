// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { IMachinePathManager, TEE_MACHINE_PATH_LIST } from "../../userInterfaces/tee/IMachinePathManager.sol";
import { Signature } from "../../userInterfaces/ISignature.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { SignedPayload } from "../../utils/lib/SignedPayload.sol";
import { MachinePathManager } from "../library/MachinePathManager.sol";
import { ExtensionGovernance } from "../library/ExtensionGovernance.sol";
import { ExtensionManager } from "../library/ExtensionManager.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title MachinePathManagerFacet
 * @notice Facet for managing per-extension governance-signed TEE machine path lists.
 */
contract MachinePathManagerFacet is IMachinePathManager {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    /// @inheritdoc IMachinePathManager
    function createNewMachinePathList(
        uint256 _extensionId
    )
        external
        returns (uint256 _nonce)
    {
        ExtensionManager.checkOnlyExtensionOwnerOrOperator(_extensionId);
        MachinePathManager.MachinePathList[] storage arr =
            MachinePathManager.getState().lists[_extensionId];
        arr.push();
        _nonce = arr.length;
        emit MachinePathListStarted(_extensionId, _nonce);
    }

    /// @inheritdoc IMachinePathManager
    function addMachinePaths(
        uint256 _extensionId,
        uint256 _nonce,
        MachinePath[] calldata _paths
    )
        external
    {
        ExtensionManager.checkOnlyExtensionOwnerOrOperator(_extensionId);
        MachinePathManager.MachinePathList storage pathList = MachinePathManager.list(_extensionId, _nonce);
        require(pathList.messageHash == bytes32(0), ListAlreadyFinalized());
        require(_paths.length > 0, NoPaths());

        for (uint256 i = 0; i < _paths.length; i++) {
            MachinePath calldata p = _paths[i];
            require(p.sourceTeeIds.length > 0, NoSourceTeeIds());
            require(p.destinationTeeIds.length > 0, NoDestinationTeeIds());
            MachinePathManager.MachinePathState storage ps = pathList.paths.push();
            for (uint256 j = 0; j < p.sourceTeeIds.length; j++) {
                address src = p.sourceTeeIds[j];
                bytes32 hash =
                    MachinePathManager.assertEligibleAndDeriveGovernanceHash(_extensionId, src);
                pathList.involvedGovernanceHashes.add(hash);
                require(!ps.sourceTeeIdExists[src], SourceTeeIdAlreadyExists());
                ps.sourceTeeIdExists[src] = true;
                ps.path.sourceTeeIds.push(src);
            }
            for (uint256 j = 0; j < p.destinationTeeIds.length; j++) {
                address dst = p.destinationTeeIds[j];
                bytes32 hash =
                    MachinePathManager.assertEligibleAndDeriveGovernanceHash(_extensionId, dst);
                pathList.involvedGovernanceHashes.add(hash);
                require(!ps.destinationTeeIdExists[dst], DestinationTeeIdAlreadyExists());
                ps.destinationTeeIdExists[dst] = true;
                ps.path.destinationTeeIds.push(dst);
            }
        }
        emit MachinePathsAdded(_extensionId, _nonce, _paths);
    }

    /// @inheritdoc IMachinePathManager
    function finalizeMachinePathList(
        uint256 _extensionId,
        uint256 _nonce
    )
        external
    {
        ExtensionManager.checkOnlyExtensionOwnerOrOperator(_extensionId);
        MachinePathManager.MachinePathList storage pathList = MachinePathManager.list(_extensionId, _nonce);
        require(pathList.messageHash == bytes32(0), ListAlreadyFinalized());
        require(pathList.paths.length > 0, NoPaths());
        // extensionId + nonce go into the inner dataHash, preventing cross-extension and
        // cross-list signature replay between lists that happen to share path content.
        // Per-path governance hashes are derived deterministically from the teeIds (which
        // are bound), so they need not be hashed in directly. The outer SignedPayload
        // envelope adds the TEE_MACHINE_PATH_LIST prefix and binds block.chainid.
        pathList.messageHash = SignedPayload.messageHash(
            TEE_MACHINE_PATH_LIST,
            keccak256(abi.encode(_extensionId, _nonce, _getMachinePaths(_extensionId, _nonce)))
        );
        emit MachinePathListFinalized(_extensionId, _nonce, pathList.involvedGovernanceHashes.values());
    }

    /// @inheritdoc IMachinePathManager
    function signMachinePathList(
        uint256 _extensionId,
        uint256 _nonce,
        Signature calldata _signature
    )
        external
    {
        MachinePathManager.MachinePathList storage pathList = MachinePathManager.list(_extensionId, _nonce);
        require(pathList.messageHash != bytes32(0), ListNotFinalized());
        require(!pathList.listSigned, ListAlreadySigned());

        address signer = ECDSA.recover(
            MessageHashUtils.toEthSignedMessageHash(pathList.messageHash),
            _signature.v,
            _signature.r,
            _signature.s
        );
        require(!pathList.signerHasSigned[signer], SignerAlreadySigned());

        bytes32[] memory hashes = pathList.involvedGovernanceHashes.values();
        bytes32[] memory counted = new bytes32[](hashes.length);
        uint256 countedLen;

        for (uint256 i = 0; i < hashes.length; i++) {
            if (ExtensionGovernance.isTeeGovernanceSigner(_extensionId, hashes[i], signer)) {
                pathList.signatureCount[hashes[i]] += 1;
                counted[countedLen] = hashes[i];
                countedLen++;
            }
        }
        require(countedLen > 0, UnrecognizedSigner());

        pathList.signerHasSigned[signer] = true;
        pathList.signatures.push(_signature);

        // Shrink the `counted` array to its actual length before emitting.
        // solhint-disable-next-line no-inline-assembly
        assembly { mstore(counted, countedLen) }
        emit MachinePathListSignatureAdded(_extensionId, _nonce, signer, counted);

        // Activation: list is signed when every involved governance has reached its threshold.
        // Then it is promoted to "active" iff its nonce strictly exceeds the current active nonce
        // (which is monotonically true here since nonces are strictly increasing per extension).
        bool allMet = true;
        for (uint256 i = 0; i < hashes.length; i++) {
            uint64 threshold =
                ExtensionGovernance.getTeeGovernanceThreshold(_extensionId, hashes[i]);
            if (pathList.signatureCount[hashes[i]] < threshold) {
                allMet = false;
                break;
            }
        }
        if (allMet) {
            pathList.listSigned = true;
            emit MachinePathListSigned(_extensionId, _nonce);
            MachinePathManager.State storage state = MachinePathManager.getState();
            if (_nonce > state.extensionActiveListNonce[_extensionId]) {
                state.extensionActiveListNonce[_extensionId] = _nonce;
            }
        }
    }

    /// @inheritdoc IMachinePathManager
    function isMachinePathValid(
        uint256 _extensionId,
        address _sourceTeeId,
        address _destinationTeeId
    )
        external view
        returns (bool)
    {
        return MachinePathManager.isMachinePathValid(_extensionId, _sourceTeeId, _destinationTeeId);
    }

    /// @inheritdoc IMachinePathManager
    function getActiveMachinePathListNonce(
        uint256 _extensionId
    )
        external view
        returns (uint256 _nonce)
    {
        return MachinePathManager.getActiveListNonce(_extensionId);
    }

    /// @inheritdoc IMachinePathManager
    function isMachinePathListFinalized(
        uint256 _extensionId,
        uint256 _nonce
    )
        external view
        returns (bool)
    {
        return MachinePathManager.list(_extensionId, _nonce).messageHash != bytes32(0);
    }

    /// @inheritdoc IMachinePathManager
    function isMachinePathListSigned(
        uint256 _extensionId,
        uint256 _nonce
    )
        external view
        returns (bool)
    {
        return MachinePathManager.list(_extensionId, _nonce).listSigned;
    }

    /// @inheritdoc IMachinePathManager
    function getMachinePathListMessageHash(
        uint256 _extensionId,
        uint256 _nonce
    )
        external view
        returns (bytes32)
    {
        return MachinePathManager.list(_extensionId, _nonce).messageHash;
    }

    /// @inheritdoc IMachinePathManager
    function getMachinePathListsCount(
        uint256 _extensionId
    )
        external view
        returns (uint256)
    {
        return MachinePathManager.getState().lists[_extensionId].length;
    }

    /// @inheritdoc IMachinePathManager
    function getMachinePathList(
        uint256 _extensionId,
        uint256 _nonce
    )
        external view
        returns (
            MachinePath[] memory _paths,
            bytes32[] memory _involvedGovernanceHashes,
            Signature[] memory _signatures,
            bool _signed
        )
    {
        MachinePathManager.MachinePathList storage pathList = MachinePathManager.list(_extensionId, _nonce);
        _paths = _getMachinePaths(_extensionId, _nonce);
        _involvedGovernanceHashes = pathList.involvedGovernanceHashes.values();
        _signatures = pathList.signatures;
        _signed = pathList.listSigned;
    }

    /// @inheritdoc IMachinePathManager
    function getMachinePathListSignatureCount(
        uint256 _extensionId,
        uint256 _nonce,
        bytes32 _governanceHash
    )
        external view
        returns (uint64)
    {
        return MachinePathManager.list(_extensionId, _nonce).signatureCount[_governanceHash];
    }

    // =========================================================================
    // Private helpers
    // =========================================================================

    function _getMachinePaths(
        uint256 _extensionId,
        uint256 _nonce
    )
        private view
        returns (MachinePath[] memory _paths)
    {
        MachinePathManager.MachinePathState[] storage stored =
            MachinePathManager.list(_extensionId, _nonce).paths;
        _paths = new MachinePath[](stored.length);
        for (uint256 i = 0; i < stored.length; i++) {
            _paths[i] = stored[i].path;
        }
    }
}
