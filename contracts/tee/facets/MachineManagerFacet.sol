// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IMachineManager } from "../../userInterfaces/tee/IMachineManager.sol";
import { IMachineEmergencyPause } from "../../userInterfaces/tee/IMachineEmergencyPause.sol";
import { ITeeAvailabilityCheck } from "../../userInterfaces/fdc2/ITeeAvailabilityCheck.sol";
import { IRelay } from "../../userInterfaces/IRelay.sol";
import { PublicKey } from "../../userInterfaces/IPublicKey.sol";
import { Signature } from "../../userInterfaces/ISignature.sol";
import { PublicKeyUtils } from "../../utils/lib/PublicKeyUtils.sol";
import { MachineManager } from "../library/MachineManager.sol";
import { MachineEmergencyPause } from "../library/MachineEmergencyPause.sol";
import { ExtensionManager } from "../library/ExtensionManager.sol";
import { OwnerAllowlist } from "../library/OwnerAllowlist.sol";
import { Verification } from "../library/Verification.sol";
import { ExternalAddresses } from "../library/ExternalAddresses.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title MachineManagerFacet
 * @notice Facet for TEE machine registration and status management.
 */
contract MachineManagerFacet is IMachineManager {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @inheritdoc IMachineManager
    function register(
        TeeMachineData calldata _teeMachineData,
        Signature calldata _teeMachineDataSignature,
        address _teeProxyId,
        string calldata _url,
        address _claimBackAddress
    )
        external payable
    {
        require(msg.sender == _teeMachineData.initialOwner, OnlyOwner());
        require(
            OwnerAllowlist.isAllowedTeeMachineOwner(_teeMachineData.extensionId, _teeMachineData.initialOwner),
            OwnerNotAllowed()
        );
        require(PublicKeyUtils.isPublicKeyValid(_teeMachineData.publicKey), InvalidTeePublicKey());
        // Bind chainid into the signed payload so a TEE registration signature
        // produced for one Flare network cannot be replayed on another.
        address teeId = ECDSA.recover(
            MessageHashUtils.toEthSignedMessageHash(
                keccak256(abi.encode(bytes32("TEE_MACHINE_REGISTER"), block.chainid, _teeMachineData))
            ),
            _teeMachineDataSignature.v,
            _teeMachineDataSignature.r,
            _teeMachineDataSignature.s
        );
        require(teeId == PublicKeyUtils.getAddress(_teeMachineData.publicKey), InvalidTeePublicKeyOrSignature());
        require(_teeProxyId != address(0), InvalidTeeProxyId());
        require(bytes(_url).length > 0, InvalidUrl());

        MachineManager.State storage s = MachineManager.getState();
        require(s.teeMachineStates[teeId].owner == address(0), AlreadyRegistered());
        MachineManager.checkCodeHashPlatformSupported(
            _teeMachineData.extensionId,
            _teeMachineData.codeHash,
            _teeMachineData.platform
        );

        s.teeMachineStates[teeId] = MachineManager.TeeMachineState({
            extensionId: _teeMachineData.extensionId,
            initialTeeId: teeId,
            teePublicKey: _teeMachineData.publicKey,
            initialSigningPolicyId: 0,
            owner: _teeMachineData.initialOwner,
            teeProxyId: _teeProxyId,
            status: TeeStatus.INITIALIZED,
            lastStatusChangeTs: block.timestamp,
            codeHash: _teeMachineData.codeHash,
            platform: _teeMachineData.platform,
            url: _url
        });

        // Registration path: attesting on the machine itself (no prior challenge exists yet).
        Verification.requestTeeAttestation(teeId, teeId, _claimBackAddress);
        emit TeeMachineRegistered(
            teeId,
            _teeProxyId,
            _teeMachineData.initialOwner,
            _teeMachineData.extensionId,
            _url,
            _teeMachineData.codeHash,
            _teeMachineData.platform
        );
    }

    /// @inheritdoc IMachineManager
    function toProduction(
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        external
    {
        address teeId = _proof.requestBody.teeId;
        MachineManager.State storage s = MachineManager.getState();
        MachineManager.TeeMachineState storage state = s.teeMachineStates[teeId];
        require(state.owner != address(0), TeeNotFound());
        TeeStatus status = state.status;
        if (status != TeeStatus.SUSPENDED) {
            require(msg.sender == state.owner, OnlyOwner());
            require(status == TeeStatus.INITIALIZED || status == TeeStatus.PAUSED, InvalidTeeStatus());
        }
        MachineManager.checkCodeHashPlatformSupported(state.extensionId, state.codeHash, state.platform);
        MachineManager.validateAvailabilityCheckStatus(_proof.responseBody.status);
        MachineManager.validateAvailabilityCheckTs(teeId, _proof.header.timestamp);

        IMachineManager.TeeMachineWithAttestationData memory teeMachine =
            MachineManager.getTeeMachineWithAttestationData(teeId);
        require(Verification.verifyAvailabilityCheckProof(teeMachine, status, _proof), InvalidResponseData());

        if (status == TeeStatus.INITIALIZED) {
            state.initialSigningPolicyId = _proof.responseBody.initialSigningPolicyId;
        }

        state.status = TeeStatus.PRODUCTION;
        state.lastStatusChangeTs = block.timestamp;
        s.extensionActiveTeeIds[state.extensionId].add(teeId);
        s.activeTeeIds.add(teeId);
        Verification.extendAvailability(_proof);
        emit TeeMachineStatusChanged(teeId, TeeStatus.PRODUCTION);
    }

    /// @inheritdoc IMachineManager
    function pause(
        address _teeId
    )
        external
    {
        MachineManager.State storage s = MachineManager.getState();
        MachineManager.TeeMachineState storage state = s.teeMachineStates[_teeId];
        require(state.owner != address(0), TeeNotFound());
        TeeStatus newStatus;
        if (msg.sender == state.owner ||
            ExtensionManager.isCodeHashPlatformDisabled(state.extensionId, state.codeHash, state.platform))
        {
            MachineManager.checkTeeStatus(state.status, TeeStatus.PRODUCTION, TeeStatus.SUSPENDED);
            newStatus = TeeStatus.PAUSED;
        } else {
            require(
                !MachineEmergencyPause.isExtensionInEmergencyOrGrace(state.extensionId),
                IMachineEmergencyPause.EmergencyProtectionActive(state.extensionId)
            );
            MachineManager.checkTeeStatus(state.status, TeeStatus.PRODUCTION);
            (uint64 endTs,) = Verification.getAvailabilityCheckValidity(_teeId);
            require(endTs < block.timestamp, OnlyOwnerOrExpiredAvailabilityCheckOrDisabledVersion());
            newStatus = TeeStatus.SUSPENDED;
        }

        state.status = newStatus;
        state.lastStatusChangeTs = block.timestamp;
        s.extensionActiveTeeIds[state.extensionId].remove(_teeId);
        s.activeTeeIds.remove(_teeId);
        emit TeeMachineStatusChanged(_teeId, newStatus);
    }

    /// @inheritdoc IMachineManager
    function pauseWithProof(
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        external
    {
        address teeId = _proof.requestBody.teeId;
        MachineManager.State storage s = MachineManager.getState();
        MachineManager.TeeMachineState storage state = s.teeMachineStates[teeId];
        require(state.owner != address(0), TeeNotFound());
        MachineManager.checkTeeStatus(state.status, TeeStatus.PRODUCTION);

        IMachineManager.TeeMachineWithAttestationData memory teeMachine =
            MachineManager.getTeeMachineWithAttestationData(teeId);
        bool responseDataValid = Verification.verifyAvailabilityCheckProof(
            teeMachine, state.status, _proof
        );
        require(
            !responseDataValid ||
            _proof.responseBody.status != ITeeAvailabilityCheck.AvailabilityCheckStatus.OK,
            InvalidResponseDataOrAvailabilityCheckStatus()
        );
        MachineManager.validateAvailabilityCheckTs(teeId, _proof.header.timestamp);

        state.status = TeeStatus.SUSPENDED;
        state.lastStatusChangeTs = block.timestamp;
        s.extensionActiveTeeIds[state.extensionId].remove(teeId);
        s.activeTeeIds.remove(teeId);
        emit TeeMachineStatusChanged(teeId, TeeStatus.SUSPENDED);
    }

    /// @inheritdoc IMachineManager
    function ban(
        address _teeId
    )
        external
    {
        MachineManager.State storage s = MachineManager.getState();
        MachineManager.TeeMachineState storage state = s.teeMachineStates[_teeId];
        require(state.owner != address(0), TeeNotFound());
        ExtensionManager.checkOnlyExtensionOwner(state.extensionId);
        TeeStatus status = state.status;
        require(
            status == TeeStatus.PAUSED || status == TeeStatus.SUSPENDED || status == TeeStatus.PRODUCTION,
            InvalidTeeStatus()
        );
        state.status = TeeStatus.BANNED;
        state.lastStatusChangeTs = block.timestamp;
        s.extensionActiveTeeIds[state.extensionId].remove(_teeId);
        s.activeTeeIds.remove(_teeId);
        emit TeeMachineStatusChanged(_teeId, TeeStatus.BANNED);
    }

    /// @inheritdoc IMachineManager
    function unban(
        address _teeId
    )
        external
    {
        MachineManager.TeeMachineState storage state = MachineManager.getTeeMachineState(_teeId);
        ExtensionManager.checkOnlyExtensionOwner(state.extensionId);
        MachineManager.checkTeeStatus(state.status, TeeStatus.BANNED);
        state.status = TeeStatus.PAUSED;
        state.lastStatusChangeTs = block.timestamp;
        emit TeeMachineStatusChanged(_teeId, TeeStatus.PAUSED);
    }

    /// @inheritdoc IMachineManager
    function proposeNewOwner(
        address _teeId,
        address _newOwner
    )
        external
    {
        MachineManager.TeeMachineState storage state = MachineManager.getTeeMachineState(_teeId);
        require(msg.sender == state.owner, OnlyOwner());
        require(
            _newOwner == address(0) || OwnerAllowlist.isAllowedTeeMachineOwner(state.extensionId, _newOwner),
            OwnerNotAllowed()
        );
        MachineManager.getState().proposedTeeOwner[_teeId] = _newOwner;
        emit NewOwnerProposed(_teeId, msg.sender, _newOwner);
    }

    /// @inheritdoc IMachineManager
    function confirmOwnership(
        address _teeId
    )
        external
    {
        MachineManager.TeeMachineState storage state = MachineManager.getTeeMachineState(_teeId);
        require(OwnerAllowlist.isAllowedTeeMachineOwner(state.extensionId, msg.sender), OwnerNotAllowed());
        MachineManager.State storage s = MachineManager.getState();
        require(s.proposedTeeOwner[_teeId] == msg.sender, OnlyProposedOwner());
        state.owner = msg.sender;
        delete s.proposedTeeOwner[_teeId];
        emit NewOwnerConfirmed(_teeId, msg.sender);
    }

    /// @inheritdoc IMachineManager
    function updateTeeMachineSettings(
        address _teeId,
        address _teeProxyId,
        string calldata _url
    )
        external
    {
        MachineManager.TeeMachineState storage state = MachineManager.getTeeMachineState(_teeId);
        require(msg.sender == state.owner, OnlyOwner());
        require(_teeProxyId != address(0), InvalidTeeProxyId());
        require(bytes(_url).length > 0, InvalidUrl());
        state.teeProxyId = _teeProxyId;
        state.url = _url;
        TeeStatus status = state.status;
        if (status == TeeStatus.PRODUCTION || status == TeeStatus.SUSPENDED) {
            state.status = TeeStatus.PAUSED;
            state.lastStatusChangeTs = block.timestamp;
            MachineManager.State storage s = MachineManager.getState();
            s.extensionActiveTeeIds[state.extensionId].remove(_teeId);
            s.activeTeeIds.remove(_teeId);
            emit TeeMachineStatusChanged(_teeId, TeeStatus.PAUSED);
        }
        emit TeeMachineSettingsUpdated(_teeId, _teeProxyId, _url);
    }

    // =========================================================================
    // Getters
    // =========================================================================

    /// @inheritdoc IMachineManager
    function getTeeMachineStatus(
        address _teeId
    )
        external view
        returns (TeeStatus)
    {
        return MachineManager.getTeeMachineStatus(_teeId);
    }

    /// @inheritdoc IMachineManager
    function getTeeMachineOwner(
        address _teeId
    )
        external view
        returns (address)
    {
        return MachineManager.getTeeMachineOwner(_teeId);
    }

    /// @inheritdoc IMachineManager
    function getInitialSigningPolicyId(
        address _teeId
    )
        external view
        returns (uint32)
    {
        return MachineManager.getInitialSigningPolicyId(_teeId);
    }

    /// @inheritdoc IMachineManager
    function getTeeMachine(
        address _teeId
    )
        external view
        returns (TeeMachine memory)
    {
        return MachineManager.getTeeMachine(_teeId);
    }

    /// @inheritdoc IMachineManager
    function getTeeMachineWithAttestationData(
        address _teeId
    )
        external view
        returns (TeeMachineWithAttestationData memory)
    {
        return MachineManager.getTeeMachineWithAttestationData(_teeId);
    }

    /// @inheritdoc IMachineManager
    function getRandomTeeIds(
        uint256 _extensionId,
        uint256 _count
    )
        external view
        returns (address[] memory _teeIds)
    {
        MachineManager.State storage s = MachineManager.getState();
        uint256 length = s.extensionActiveTeeIds[_extensionId].length();
        require(_count <= length, TooMany());
        (uint256 randomNumber,,) = IRelay(ExternalAddresses.getState().relay).getRandomNumber();

        // Reservoir sampling
        uint256[] memory indices = new uint256[](_count);
        for (uint256 i = 0; i < _count; i++) {
            indices[i] = i;
        }
        for (uint256 i = _count; i < length; i++) {
            randomNumber = uint256(keccak256(abi.encode(randomNumber, i)));
            uint256 j = randomNumber % (i + 1);
            if (j < _count) {
                indices[j] = i;
            }
        }

        _teeIds = new address[](_count);
        for (uint256 i = 0; i < _count; i++) {
            _teeIds[i] = s.extensionActiveTeeIds[_extensionId].at(indices[i]);
        }
    }

    /// @inheritdoc IMachineManager
    function getAllActiveTeeMachines(
        uint256 _start,
        uint256 _end
    )
        external view
        returns (
            address[] memory _teeIds,
            string[] memory _urls,
            uint256 _totalLength
        )
    {
        MachineManager.State storage s = MachineManager.getState();
        _totalLength = s.activeTeeIds.length();
        _end = Math.min(_end, _totalLength);
        _start = Math.min(_start, _end);
        _teeIds = new address[](_end - _start);
        _urls = new string[](_end - _start);
        for (uint256 i = _start; i < _end; i++) {
            uint256 index = i - _start;
            _teeIds[index] = s.activeTeeIds.at(i);
            _urls[index] = s.teeMachineStates[_teeIds[index]].url;
        }
    }

    /// @inheritdoc IMachineManager
    function getActiveTeeMachines(
        uint256 _extensionId
    )
        external view
        returns (
            address[] memory _teeIds,
            string[] memory _urls
        )
    {
        MachineManager.State storage s = MachineManager.getState();
        _teeIds = s.extensionActiveTeeIds[_extensionId].values();
        uint256 length = _teeIds.length;
        _urls = new string[](length);
        for (uint256 i = 0; i < length; i++) {
            _urls[i] = s.teeMachineStates[_teeIds[i]].url;
        }
    }

    /// @inheritdoc IMachineManager
    function getExtensionId(
        address _teeId
    )
        external view
        returns (uint256)
    {
        return MachineManager.getExtensionId(_teeId);
    }

    /// @inheritdoc IMachineManager
    function getPublicKey(
        address _teeId
    )
        external view
        returns (PublicKey memory)
    {
        return MachineManager.getPublicKey(_teeId);
    }

    /// @inheritdoc IMachineManager
    function getLastStatusChangeTs(
        address _teeId
    )
        external view
        returns (uint256)
    {
        return MachineManager.getLastStatusChangeTs(_teeId);
    }

}
