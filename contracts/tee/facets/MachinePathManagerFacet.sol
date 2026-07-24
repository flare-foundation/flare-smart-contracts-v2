// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { IMachinePathManager, TEE_MACHINE_PATH_LIST } from "../../userInterfaces/tee/IMachinePathManager.sol";
import { Signature } from "../../userInterfaces/ISignature.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { SignedPayload } from "../../utils/lib/SignedPayload.sol";
import { ISafeMinimal } from "../interface/ISafeMinimal.sol";
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
        _nonce = ++MachinePathManager.getState().listCount[_extensionId];
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
            MachinePathManager.MachinePathState storage ps = pathList.paths[pathList.pathCount++];
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
        require(pathList.pathCount > 0, NoPaths());
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

        _activateWhenFullySigned(_extensionId, _nonce, pathList);
    }

    /// @inheritdoc IMachinePathManager
    function approveMachinePathList(
        uint256 _extensionId,
        uint256 _nonce,
        bytes32 _messageHash
    )
        external
    {
        MachinePathManager.MachinePathList storage pathList = MachinePathManager.list(_extensionId, _nonce);
        require(pathList.messageHash != bytes32(0), ListNotFinalized());
        require(_messageHash == pathList.messageHash, MessageHashMismatch());

        bytes32[] memory hashes = pathList.involvedGovernanceHashes.values();
        // Phase 1: match the caller against the involved governances' registered Safe addresses,
        // rejecting unrecognized callers without any external call.
        bool anySafeMatch = false;
        for (uint256 i = 0; i < hashes.length; i++) {
            if (ExtensionGovernance.getTeeGovernanceSafeAddress(_extensionId, hashes[i]) == msg.sender) {
                anySafeMatch = true;
                break;
            }
        }
        require(anySafeMatch, UnrecognizedSigner());

        // Phase 2: mark Safe-approved every involved snapshot the caller Safe's live quorum can
        // still cover (one Safe call represents threshold-many owner confirmations). The flags are
        // a satisfaction path independent of the ECDSA signature counts, which stay untouched.
        // Repeat approvals — including after activation — are idempotent (no per-signer dedup is
        // needed here, a contract can never produce the ECDSA signature the dedup exists for) and
        // each appends a fresh Approval entry for relays. Snapshots the live quorum can no longer
        // satisfy are skipped — they can still be covered by direct snapshot-owner signatures via
        // `signMachinePathList`.
        uint256 liveThreshold = ISafeMinimal(msg.sender).getThreshold();
        bytes32[] memory satisfied = new bytes32[](hashes.length);
        uint256 satisfiedLen;
        for (uint256 i = 0; i < hashes.length; i++) {
            if (
                ExtensionGovernance.getTeeGovernanceSafeAddress(_extensionId, hashes[i]) == msg.sender &&
                ExtensionGovernance.isSnapshotSatisfiable(
                    _extensionId, hashes[i], ISafeMinimal(msg.sender), liveThreshold
                )
            ) {
                pathList.safeApproved[hashes[i]] = true;
                satisfied[satisfiedLen] = hashes[i];
                satisfiedLen++;
            }
        }
        require(satisfiedLen > 0, SafeGovernanceStale());

        // The Safe increments its nonce inside execTransaction BEFORE making the inner call, so
        // the nonce the owners signed is nonce() - 1. It is the one SafeTxHash ingredient not
        // recoverable from the execTransaction calldata; recording it makes the Approval entry a
        // complete artifact pointer for off-chain verifiers. Underflows (reverts) for a responder
        // reporting nonce 0 — impossible for a genuine Safe mid-execTransaction. The uint32 cast
        // truncates silently above 2^32, but each Safe nonce is an executed Safe transaction, so
        // a genuine Safe cannot get near it (billions of transactions — more than one per block
        // for centuries); a rogue responder can misreport its nonce regardless of any range
        // check, and the value is advisory artifact data — a wrong nonce only makes off-chain
        // artifact reconstruction fail (fail-closed), signatures are verified against the node's
        // own anchors.
        uint32 safeNonce = uint32(ISafeMinimal(msg.sender).nonce() - 1);
        pathList.approvals.push(Approval(msg.sender, uint64(block.number), safeNonce));

        // Shrink the `satisfied` array to its actual length before emitting.
        // solhint-disable-next-line no-inline-assembly
        assembly { mstore(satisfied, satisfiedLen) }
        emit MachinePathListApproved(_extensionId, _nonce, msg.sender, safeNonce, satisfied);

        _activateWhenFullySigned(_extensionId, _nonce, pathList);
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
        return MachinePathManager.getState().listCount[_extensionId];
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

    /// @inheritdoc IMachinePathManager
    function getMachinePathListApprovals(
        uint256 _extensionId,
        uint256 _nonce
    )
        external view
        returns (Approval[] memory _approvals)
    {
        _approvals = MachinePathManager.list(_extensionId, _nonce).approvals;
    }

    /// @inheritdoc IMachinePathManager
    function isMachinePathListSafeApproved(
        uint256 _extensionId,
        uint256 _nonce,
        bytes32 _governanceHash
    )
        external view
        returns (bool)
    {
        return MachinePathManager.list(_extensionId, _nonce).safeApproved[_governanceHash];
    }

    // =========================================================================
    // Private helpers
    // =========================================================================

    /**
     * Shared activation tail of both approval paths: the list is fully signed when every involved
     * governance has signed off — its ECDSA signature count reached its threshold, or its Safe
     * approved it — and is then promoted to "active" iff its nonce strictly exceeds the current
     * active nonce (which is monotonically true here since nonces are strictly increasing per
     * extension). Activation is a one-shot transition: signatures and approvals may keep
     * accumulating afterwards (evidence collection for off-chain verifiers), but this function
     * returns early once the list is signed, so MachinePathListSigned fires at most once.
     */
    function _activateWhenFullySigned(
        uint256 _extensionId,
        uint256 _nonce,
        MachinePathManager.MachinePathList storage _pathList
    )
        private
    {
        if (_pathList.listSigned) {
            return;
        }
        bytes32[] memory hashes = _pathList.involvedGovernanceHashes.values();
        bool fullySigned = true;
        for (uint256 i = 0; i < hashes.length; i++) {
            if (_pathList.safeApproved[hashes[i]]) {
                continue;
            }
            uint64 threshold = ExtensionGovernance.getTeeGovernanceThreshold(_extensionId, hashes[i]);
            if (_pathList.signatureCount[hashes[i]] < threshold) {
                fullySigned = false;
                break;
            }
        }
        if (fullySigned) {
            _pathList.listSigned = true;
            emit MachinePathListSigned(_extensionId, _nonce);
            MachinePathManager.State storage state = MachinePathManager.getState();
            if (_nonce > state.extensionActiveListNonce[_extensionId]) {
                state.extensionActiveListNonce[_extensionId] = _nonce;
            }
        }
    }

    function _getMachinePaths(
        uint256 _extensionId,
        uint256 _nonce
    )
        private view
        returns (MachinePath[] memory _paths)
    {
        MachinePathManager.MachinePathList storage pathList = MachinePathManager.list(_extensionId, _nonce);
        uint256 count = pathList.pathCount;
        _paths = new MachinePath[](count);
        for (uint256 i = 0; i < count; i++) {
            _paths[i] = pathList.paths[i].path;
        }
    }
}
