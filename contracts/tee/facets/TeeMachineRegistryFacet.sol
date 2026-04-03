// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ITeeMachineRegistryFacet, REG_OP_TYPE } from "../../userInterfaces/tee/ITeeMachineRegistryFacet.sol";
import { ITeeVerificationFacet } from "../../userInterfaces/tee/ITeeVerificationFacet.sol";
import { ITeeExtensionRegistryFacet } from "../../userInterfaces/tee/ITeeExtensionRegistryFacet.sol";
import { ITeeAvailabilityCheck } from "../../userInterfaces/fdc2/ITeeAvailabilityCheck.sol";
import { IRelay } from "../../userInterfaces/IRelay.sol";
import { PublicKey } from "../../userInterfaces/IPublicKey.sol";
import { Signature } from "../../userInterfaces/ISignature.sol";
import { PublicKeyUtils } from "../../utils/lib/PublicKeyUtils.sol";
import { TeeMachineRegistry } from "../library/TeeMachineRegistry.sol";
import { TeeExtensionRegistry } from "../library/TeeExtensionRegistry.sol";
import { TeeOwnerAllowlist } from "../library/TeeOwnerAllowlist.sol";
import { TeeVerification } from "../library/TeeVerification.sol";
import { TeeExternalAddresses } from "../library/TeeExternalAddresses.sol";
import { TeeInstructionSender } from "../library/TeeInstructionSender.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title TeeMachineRegistryFacet
 * @notice Facet for TEE machine registration and status management.
 */
contract TeeMachineRegistryFacet is ITeeMachineRegistryFacet {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @inheritdoc ITeeMachineRegistryFacet
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
            TeeOwnerAllowlist.isAllowedTeeMachineOwner(_teeMachineData.extensionId, _teeMachineData.initialOwner),
            OwnerNotAllowed()
        );
        require(PublicKeyUtils.isPublicKeyValid(_teeMachineData.publicKey), InvalidTeePublicKey());
        address teeId = ECDSA.recover(
            MessageHashUtils.toEthSignedMessageHash(keccak256(abi.encode(_teeMachineData))),
            _teeMachineDataSignature.v,
            _teeMachineDataSignature.r,
            _teeMachineDataSignature.s
        );
        require(teeId == PublicKeyUtils.getAddress(_teeMachineData.publicKey), InvalidTeePublicKeyOrSignature());
        require(_teeProxyId != address(0), InvalidTeeProxyId());
        require(bytes(_url).length > 0, InvalidUrl());

        TeeMachineRegistry.State storage s = TeeMachineRegistry.getState();
        require(s.teeMachineStates[teeId].owner == address(0), AlreadyRegistered());
        TeeMachineRegistry.checkCodeHashPlatformSupported(
            _teeMachineData.extensionId,
            _teeMachineData.codeHash,
            _teeMachineData.platform
        );

        s.teeMachineStates[teeId] = TeeMachineRegistry.TeeMachineState({
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

        _requestTeeAttestation(teeId, _claimBackAddress);
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

    /// @inheritdoc ITeeMachineRegistryFacet
    function toProduction(
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        external
    {
        address teeId = _proof.requestBody.teeId;
        TeeMachineRegistry.State storage s = TeeMachineRegistry.getState();
        TeeMachineRegistry.TeeMachineState storage state = s.teeMachineStates[teeId];
        require(state.owner != address(0), TeeNotFound());
        TeeStatus status = state.status;
        if (status != TeeStatus.SUSPENDED) {
            require(msg.sender == state.owner, OnlyOwner());
            require(status == TeeStatus.INITIALIZED || status == TeeStatus.PAUSED, InvalidTeeStatus());
        }
        TeeMachineRegistry.checkCodeHashPlatformSupported(state.extensionId, state.codeHash, state.platform);
        TeeMachineRegistry.validateAvailabilityCheckStatus(_proof.responseBody.status);
        TeeMachineRegistry.validateAvailabilityCheckTs(teeId, _proof.header.timestamp);

        ITeeMachineRegistryFacet.TeeMachineWithAttestationData memory teeMachine =
            TeeMachineRegistry.getTeeMachineWithAttestationData(teeId);
        require(TeeVerification.verifyAvailabilityCheckProof(teeMachine, status, _proof), InvalidResponseData());

        if (status == TeeStatus.INITIALIZED) {
            state.initialSigningPolicyId = _proof.responseBody.initialSigningPolicyId;
        }

        state.status = TeeStatus.PRODUCTION;
        state.lastStatusChangeTs = block.timestamp;
        s.extensionActiveTeeIds[state.extensionId].add(teeId);
        s.activeTeeIds.add(teeId);
        TeeVerification.extendAvailability(_proof);
        emit TeeMachineStatusChanged(teeId, TeeStatus.PRODUCTION);
    }

    /// @inheritdoc ITeeMachineRegistryFacet
    function pause(
        address _teeId
    )
        external
    {
        TeeMachineRegistry.State storage s = TeeMachineRegistry.getState();
        TeeMachineRegistry.TeeMachineState storage state = s.teeMachineStates[_teeId];
        require(state.owner != address(0), TeeNotFound());
        TeeStatus newStatus;
        if (msg.sender == state.owner ||
            TeeExtensionRegistry.isCodeHashPlatformDisabled(state.extensionId, state.codeHash, state.platform))
        {
            TeeMachineRegistry.checkTeeStatus(state.status, TeeStatus.PRODUCTION, TeeStatus.SUSPENDED);
            newStatus = TeeStatus.PAUSED;
        } else {
            TeeMachineRegistry.checkTeeStatus(state.status, TeeStatus.PRODUCTION);
            (uint64 endTs,) = TeeVerification.getAvailabilityCheckValidity(_teeId);
            require(endTs < block.timestamp, OnlyOwnerOrExpiredAvailabilityCheckOrDisabledVersion());
            newStatus = TeeStatus.SUSPENDED;
        }

        state.status = newStatus;
        state.lastStatusChangeTs = block.timestamp;
        s.extensionActiveTeeIds[state.extensionId].remove(_teeId);
        s.activeTeeIds.remove(_teeId);
        emit TeeMachineStatusChanged(_teeId, newStatus);
    }

    /// @inheritdoc ITeeMachineRegistryFacet
    function pauseWithProof(
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        external
    {
        address teeId = _proof.requestBody.teeId;
        TeeMachineRegistry.State storage s = TeeMachineRegistry.getState();
        TeeMachineRegistry.TeeMachineState storage state = s.teeMachineStates[teeId];
        require(state.owner != address(0), TeeNotFound());
        TeeMachineRegistry.checkTeeStatus(state.status, TeeStatus.PRODUCTION);

        ITeeMachineRegistryFacet.TeeMachineWithAttestationData memory teeMachine =
            TeeMachineRegistry.getTeeMachineWithAttestationData(teeId);
        bool responseDataValid = TeeVerification.verifyAvailabilityCheckProof(
            teeMachine, state.status, _proof
        );
        require(
            !responseDataValid ||
            _proof.responseBody.status != ITeeAvailabilityCheck.AvailabilityCheckStatus.OK,
            InvalidResponseDataOrAvailabilityCheckStatus()
        );
        TeeMachineRegistry.validateAvailabilityCheckTs(teeId, _proof.header.timestamp);

        state.status = TeeStatus.SUSPENDED;
        state.lastStatusChangeTs = block.timestamp;
        s.extensionActiveTeeIds[state.extensionId].remove(teeId);
        s.activeTeeIds.remove(teeId);
        emit TeeMachineStatusChanged(teeId, TeeStatus.SUSPENDED);
    }

    /// @inheritdoc ITeeMachineRegistryFacet
    function ban(
        address _teeId
    )
        external
    {
        TeeMachineRegistry.State storage s = TeeMachineRegistry.getState();
        TeeMachineRegistry.TeeMachineState storage state = s.teeMachineStates[_teeId];
        require(state.owner != address(0), TeeNotFound());
        TeeExtensionRegistry.checkOnlyExtensionOwner(state.extensionId);
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

    /// @inheritdoc ITeeMachineRegistryFacet
    function unban(
        address _teeId
    )
        external
    {
        TeeMachineRegistry.TeeMachineState storage state = TeeMachineRegistry.getTeeMachineState(_teeId);
        TeeExtensionRegistry.checkOnlyExtensionOwner(state.extensionId);
        TeeMachineRegistry.checkTeeStatus(state.status, TeeStatus.BANNED);
        state.status = TeeStatus.PAUSED;
        state.lastStatusChangeTs = block.timestamp;
        emit TeeMachineStatusChanged(_teeId, TeeStatus.PAUSED);
    }

    /// @inheritdoc ITeeMachineRegistryFacet
    function proposeNewOwner(
        address _teeId,
        address _newOwner
    )
        external
    {
        TeeMachineRegistry.TeeMachineState storage state = TeeMachineRegistry.getTeeMachineState(_teeId);
        require(msg.sender == state.owner, OnlyOwner());
        require(
            _newOwner == address(0) || TeeOwnerAllowlist.isAllowedTeeMachineOwner(state.extensionId, _newOwner),
            OwnerNotAllowed()
        );
        TeeMachineRegistry.getState().proposedTeeOwner[_teeId] = _newOwner;
        emit NewOwnerProposed(_teeId, msg.sender, _newOwner);
    }

    /// @inheritdoc ITeeMachineRegistryFacet
    function confirmOwnership(
        address _teeId
    )
        external
    {
        TeeMachineRegistry.TeeMachineState storage state = TeeMachineRegistry.getTeeMachineState(_teeId);
        require(TeeOwnerAllowlist.isAllowedTeeMachineOwner(state.extensionId, msg.sender), OwnerNotAllowed());
        TeeMachineRegistry.State storage s = TeeMachineRegistry.getState();
        require(s.proposedTeeOwner[_teeId] == msg.sender, OnlyProposedOwner());
        state.owner = msg.sender;
        delete s.proposedTeeOwner[_teeId];
        emit NewOwnerConfirmed(_teeId, msg.sender);
    }

    /// @inheritdoc ITeeMachineRegistryFacet
    function updateTeeMachineSettings(
        address _teeId,
        address _teeProxyId,
        string calldata _url
    )
        external
    {
        TeeMachineRegistry.TeeMachineState storage state = TeeMachineRegistry.getTeeMachineState(_teeId);
        require(msg.sender == state.owner, OnlyOwner());
        require(_teeProxyId != address(0), InvalidTeeProxyId());
        require(bytes(_url).length > 0, InvalidUrl());
        state.teeProxyId = _teeProxyId;
        state.url = _url;
        TeeStatus status = state.status;
        if (status == TeeStatus.PRODUCTION || status == TeeStatus.SUSPENDED) {
            state.status = TeeStatus.PAUSED;
            state.lastStatusChangeTs = block.timestamp;
            TeeMachineRegistry.State storage s = TeeMachineRegistry.getState();
            s.extensionActiveTeeIds[state.extensionId].remove(_teeId);
            s.activeTeeIds.remove(_teeId);
            emit TeeMachineStatusChanged(_teeId, TeeStatus.PAUSED);
        }
        emit TeeMachineSettingsUpdated(_teeId, _teeProxyId, _url);
    }

    // =========================================================================
    // Getters
    // =========================================================================

    /// @inheritdoc ITeeMachineRegistryFacet
    function getTeeMachineStatus(
        address _teeId
    )
        external view
        returns (TeeStatus)
    {
        return TeeMachineRegistry.getTeeMachineStatus(_teeId);
    }

    /// @inheritdoc ITeeMachineRegistryFacet
    function getTeeMachineOwner(
        address _teeId
    )
        external view
        returns (address)
    {
        return TeeMachineRegistry.getTeeMachineOwner(_teeId);
    }

    /// @inheritdoc ITeeMachineRegistryFacet
    function getInitialSigningPolicyId(
        address _teeId
    )
        external view
        returns (uint32)
    {
        return TeeMachineRegistry.getInitialSigningPolicyId(_teeId);
    }

    /// @inheritdoc ITeeMachineRegistryFacet
    function getTeeMachine(
        address _teeId
    )
        external view
        returns (TeeMachine memory)
    {
        return TeeMachineRegistry.getTeeMachine(_teeId);
    }

    /// @inheritdoc ITeeMachineRegistryFacet
    function getTeeMachineWithAttestationData(
        address _teeId
    )
        external view
        returns (TeeMachineWithAttestationData memory)
    {
        return TeeMachineRegistry.getTeeMachineWithAttestationData(_teeId);
    }

    /// @inheritdoc ITeeMachineRegistryFacet
    function getRandomTeeIds(
        uint256 _extensionId,
        uint256 _count
    )
        external view
        returns (address[] memory _teeIds)
    {
        TeeMachineRegistry.State storage s = TeeMachineRegistry.getState();
        uint256 length = s.extensionActiveTeeIds[_extensionId].length();
        require(_count <= length, TooMany());
        (uint256 randomNumber,,) = IRelay(TeeExternalAddresses.getState().relay).getRandomNumber();

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

    /// @inheritdoc ITeeMachineRegistryFacet
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
        TeeMachineRegistry.State storage s = TeeMachineRegistry.getState();
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

    /// @inheritdoc ITeeMachineRegistryFacet
    function getActiveTeeMachines(
        uint256 _extensionId
    )
        external view
        returns (
            address[] memory _teeIds,
            string[] memory _urls
        )
    {
        TeeMachineRegistry.State storage s = TeeMachineRegistry.getState();
        _teeIds = s.extensionActiveTeeIds[_extensionId].values();
        uint256 length = _teeIds.length;
        _urls = new string[](length);
        for (uint256 i = 0; i < length; i++) {
            _urls[i] = s.teeMachineStates[_teeIds[i]].url;
        }
    }

    /// @inheritdoc ITeeMachineRegistryFacet
    function getExtensionId(
        address _teeId
    )
        external view
        returns (uint256)
    {
        return TeeMachineRegistry.getExtensionId(_teeId);
    }

    /// @inheritdoc ITeeMachineRegistryFacet
    function getPublicKey(
        address _teeId
    )
        external view
        returns (PublicKey memory)
    {
        return TeeMachineRegistry.getPublicKey(_teeId);
    }

    /// @inheritdoc ITeeMachineRegistryFacet
    function getLastStatusChangeTs(
        address _teeId
    )
        external view
        returns (uint256)
    {
        return TeeMachineRegistry.getLastStatusChangeTs(_teeId);
    }

    // =========================================================================
    // Internal
    // =========================================================================

    function _requestTeeAttestation(
        address _teeId,
        address _claimBackAddress
    )
        private
    {
        TeeVerification.State storage vs = TeeVerification.getState();
        (uint256 randomNumber,,) = IRelay(TeeExternalAddresses.getState().relay).getRandomNumber();
        bytes32 challenge = keccak256(abi.encode(_teeId, block.timestamp, randomNumber));
        vs.challenges[_teeId] = challenge;
        vs.challengeTs[_teeId] = block.timestamp;

        ITeeMachineRegistryFacet.TeeMachineWithAttestationData memory teeMachineWithAttestationData =
            TeeMachineRegistry.getTeeMachineWithAttestationData(_teeId);
        ITeeMachineRegistryFacet.TeeMachine memory teeMachine = TeeMachineRegistry.getTeeMachine(_teeId);

        ITeeVerificationFacet.TeeAttestation memory message = ITeeVerificationFacet.TeeAttestation({
            teeMachine: teeMachineWithAttestationData,
            challenge: challenge
        });

        ITeeMachineRegistryFacet.TeeMachine[] memory teeMachines =
            new ITeeMachineRegistryFacet.TeeMachine[](1);
        teeMachines[0] = teeMachine;

        ITeeExtensionRegistryFacet.TeeInstructionParams memory instrParams =
            ITeeExtensionRegistryFacet.TeeInstructionParams(
                REG_OP_TYPE,
                bytes32("TEE_ATTESTATION"),
                abi.encode(message),
                new address[](0),
                0,
                _claimBackAddress
            );

        TeeInstructionSender.sendInstructions(bytes32(0), teeMachines, instrParams);
        emit ITeeVerificationFacet.TeeAttestationRequested(_teeId, challenge);
    }
}
