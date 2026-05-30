// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IIReplication } from "../interface/IIReplication.sol";
import { IReplication } from "../../userInterfaces/tee/IReplication.sol";
import { IInstructions } from "../../userInterfaces/tee/IInstructions.sol";
import { IMachineManager, REG_OP_TYPE } from "../../userInterfaces/tee/IMachineManager.sol";
import { ITeeAvailabilityCheck } from "../../userInterfaces/fdc2/ITeeAvailabilityCheck.sol";
import { ITeeCommonErrors } from "../../userInterfaces/tee/ITeeCommonErrors.sol";
import { Replication } from "../library/Replication.sol";
import { MachineManager } from "../library/MachineManager.sol";
import { MachinePathManager } from "../library/MachinePathManager.sol";
import { Verification } from "../library/Verification.sol";
import { Instructions } from "../library/Instructions.sol";
import { FlareGovernedAccess } from "../../governance/implementation/FlareGovernedAccess.sol";

/**
 * @title ReplicationFacet
 * @notice Facet for TEE machine replication and upgrade management.
 */
contract ReplicationFacet is IIReplication, FlareGovernedAccess {

    bytes32 internal constant TO_PAUSE_FOR_UPGRADE = bytes32("TO_PAUSE_FOR_UPGRADE");
    bytes32 internal constant REPLICATE_FROM = bytes32("REPLICATE_FROM");

    modifier onlyMachineOwner(address _teeId) {
        require(
            msg.sender == MachineManager.getTeeMachineOwner(_teeId),
            OnlyMachineOwner()
        );
        _;
    }

    /// Reverts `NotReplicationCapable` unless `_teeId` has both a non-zero `initialTeeId`
    /// (TEE-attested at first availability check) and a non-zero `governanceHash`
    /// (owner's commitment at registration). Replication and `toPauseForUpgrade` require both.
    modifier onlyReplicationCapable(address _teeId) {
        require(
            MachineManager.getTeeMachineWithAttestationData(_teeId).initialTeeId != address(0) &&
            MachineManager.getTeeMachineGovernanceHash(_teeId) != bytes32(0),
            NotReplicationCapable(_teeId)
        );
        _;
    }

    /// @inheritdoc IReplication
    function toPauseForUpgrade(
        address _teeId,
        address _claimBackAddress
    )
        external payable
        onlyMachineOwner(_teeId)
        onlyReplicationCapable(_teeId)
    {
        IMachineManager.TeeStatus status = MachineManager.getTeeMachineStatus(_teeId);
        MachineManager.checkTeeStatus(
            status,
            IMachineManager.TeeStatus.PAUSED,
            IMachineManager.TeeStatus.PAUSED_FOR_UPGRADE
        );
        if (status == IMachineManager.TeeStatus.PAUSED) {
            Replication.State storage s = Replication.getState();
            require(
                MachineManager.getLastStatusChangeTs(_teeId) +
                    s.pauseBeforeUpgradeMinDurationSeconds < block.timestamp,
                TooSoon()
            );
            MachineManager.changeStatus(_teeId, IMachineManager.TeeStatus.PAUSED_FOR_UPGRADE);
        }

        IMachineManager.TeeMachineWithAttestationData memory teeMachine =
            MachineManager.getTeeMachineWithAttestationData(_teeId);
        PauseForUpgrade memory message = PauseForUpgrade({
            teeId: _teeId,
            initialTeeId: teeMachine.initialTeeId
        });
        address[] memory teeIds = new address[](1);
        teeIds[0] = _teeId;
        _sendInstructions(teeIds, TO_PAUSE_FOR_UPGRADE, abi.encode(message), _claimBackAddress);
        emit TeeMachinePausedForUpgrade(_teeId);
    }

    /// @inheritdoc IReplication
    function replicateFrom(
        address _oldTeeId,
        ITeeAvailabilityCheck.Proof calldata _proof,
        address _claimBackAddress
    )
        external payable
        onlyMachineOwner(_oldTeeId)
        onlyMachineOwner(_proof.requestBody.teeId)
        onlyReplicationCapable(_oldTeeId)
    {
        address newTeeId = _proof.requestBody.teeId;
        IMachineManager.TeeStatus oldStatus = MachineManager.getTeeMachineStatus(_oldTeeId);
        MachineManager.checkTeeStatus(oldStatus, IMachineManager.TeeStatus.PAUSED_FOR_UPGRADE);
        IMachineManager.TeeStatus newStatus = MachineManager.getTeeMachineStatus(newTeeId);
        require(
            newStatus == IMachineManager.TeeStatus.INITIALIZED ||
            (Replication.getReplicatingTeeId(_oldTeeId) == newTeeId &&
                newStatus == IMachineManager.TeeStatus.REPLICATING), // retry
            IMachineManager.InvalidTeeStatus()
        );

        // The destination machine's `governanceHash` is committed at registration; require it
        // non-zero now. The `InvalidSystemStateVersion` guard plus the verifier's strict
        // `state.initialTeeId == storedInitialTeeId` check together enforce that the new
        // machine's TEE binary is replication-capable — the pre-write below populates the
        // stored slot with `newTeeId` so the comparison only passes if the TEE attests it.
        require(
            MachineManager.getTeeMachineGovernanceHash(newTeeId) != bytes32(0),
            NotReplicationCapable(newTeeId)
        );

        uint256 extensionId = MachineManager.getExtensionId(_oldTeeId);
        require(extensionId == MachineManager.getExtensionId(newTeeId), ExtensionMismatch());

        require(_proof.responseBody.state.systemStateVersion != bytes32(0), InvalidSystemStateVersion());

        // Pre-commit the new machine's `initialTeeId` on first attestation so the verifier's
        // single strict-compare path validates against `newTeeId`. State changes roll back on
        // any subsequent revert.
        if (newStatus == IMachineManager.TeeStatus.INITIALIZED) {
            MachineManager.getState().teeMachineStates[newTeeId].initialTeeId = newTeeId;
        }

        IMachineManager.TeeMachineWithAttestationData memory newTeeMachine =
            MachineManager.getTeeMachineWithAttestationData(newTeeId);
        MachineManager.checkCodeHashPlatformSupported(extensionId, newTeeMachine.codeHash, newTeeMachine.platform);
        IMachineManager.TeeMachineWithAttestationData memory oldTeeMachine =
            MachineManager.getTeeMachineWithAttestationData(_oldTeeId);
        // Authorization: (oldTeeId, newTeeId) must be present in the extension's active path list.
        // Reverts NoActiveMachinePathList / InvalidMachinePath on miss.
        uint256 listNonce = MachinePathManager.requireActiveListNonceForPath(
            extensionId, _oldTeeId, newTeeId
        );
        MachineManager.validateAvailabilityCheckStatus(_proof.responseBody.status);
        MachineManager.validateAvailabilityCheckTs(newTeeId, _proof.header.timestamp);

        require(
            Verification.verifyAvailabilityCheckProof(newTeeMachine, newStatus, _proof),
            ITeeCommonErrors.InvalidResponseData()
        );

        Replication.getState().replicatingTeeIds[_oldTeeId] = newTeeId;
        MachineManager.changeStatus(newTeeId, IMachineManager.TeeStatus.REPLICATING);

        _triggerReplication(oldTeeMachine, newTeeMachine, listNonce, _claimBackAddress);
        emit TeeMachineReplicationTriggered(_oldTeeId, newTeeId, listNonce);
    }

    /// @inheritdoc IReplication
    function confirmReplicate(
        address _newTeeId,
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        external
        onlyMachineOwner(_proof.requestBody.teeId)
        onlyMachineOwner(_newTeeId)
    {
        address oldTeeId = _proof.requestBody.teeId;
        require(Replication.getReplicatingTeeId(oldTeeId) == _newTeeId, ReplicationNotValid());
        delete Replication.getState().replicatingTeeIds[oldTeeId];
        require(
            _proof.responseBody.state.systemStateVersion != bytes32(0),
            InvalidSystemStateVersion()
        );
        _replicate(_newTeeId, _proof);
        emit TeeMachineReplicationConfirmed(oldTeeId, _newTeeId);
    }

    /// @inheritdoc IIReplication
    function setPauseBeforeUpgradeMinDurationSeconds(
        uint256 _pauseBeforeUpgradeMinDurationSeconds
    )
        external
        onlyGovernance
    {
        Replication.setPauseBeforeUpgradeMinDurationSeconds(_pauseBeforeUpgradeMinDurationSeconds);
    }

    /// @inheritdoc IReplication
    function getReplicatingTeeId(
        address _oldTeeId
    )
        external view
        returns (address)
    {
        return Replication.getReplicatingTeeId(_oldTeeId);
    }

    // =========================================================================
    // Private helpers
    // =========================================================================

    function _triggerReplication(
        IMachineManager.TeeMachineWithAttestationData memory _oldTeeMachine,
        IMachineManager.TeeMachineWithAttestationData memory _newTeeMachine,
        uint256 _listNonce,
        address _claimBackAddress
    )
        private
    {
        ReplicateTeeMachine memory message = ReplicateTeeMachine({
            oldTeeMachine: _oldTeeMachine,
            newTeeMachine: _newTeeMachine,
            machinePathListNonce: _listNonce
        });
        address[] memory teeIds = new address[](2);
        teeIds[0] = _oldTeeMachine.teeId;
        teeIds[1] = _newTeeMachine.teeId;
        _sendInstructions(teeIds, REPLICATE_FROM, abi.encode(message), _claimBackAddress);
    }

    function _replicate(
        address _newTeeId,
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        private
    {
        address oldTeeId = _proof.requestBody.teeId;
        MachineManager.TeeMachineState storage oldState =
            MachineManager.getTeeMachineState(oldTeeId);
        MachineManager.TeeMachineState storage newState =
            MachineManager.getTeeMachineState(_newTeeId);

        MachineManager.checkTeeStatus(
            oldState.status, IMachineManager.TeeStatus.PAUSED_FOR_UPGRADE
        );
        MachineManager.checkTeeStatus(
            newState.status, IMachineManager.TeeStatus.REPLICATING
        );
        assert(_newTeeId == newState.initialTeeId);
        require(oldState.owner == newState.owner, IMachineManager.OwnerMismatch());
        require(
            oldState.extensionId == newState.extensionId,
            ITeeCommonErrors.ExtensionIdMismatch()
        );
        MachineManager.checkCodeHashPlatformSupported(
            newState.extensionId, newState.codeHash, newState.platform
        );
        MachineManager.validateAvailabilityCheckStatus(_proof.responseBody.status);
        MachineManager.validateAvailabilityCheckTs(_newTeeId, _proof.header.timestamp);

        // Copy TEE machine data from the new TEE machine state into the old TEE machine slot.
        //
        // Chain identity preserved
        // ------------------------
        // The mapping key (`oldTeeId` → `oldState`) stays — we mutate the value in place, not the
        // key. Two derived fields also stay (deliberately NOT copied):
        //
        //   - teeId / mapping key  — by construction, equals `address(teePublicKey)` (see
        //                            `MachineManagerFacet.register`, which requires
        //                            `teeId == PublicKeyUtils.getAddress(publicKey)`).
        //   - teePublicKey         — stays the OLD TEE's public key. The `REPLICATE_FROM`
        //                            instruction (sent below) directs the source TEE to securely
        //                            hand over its *private* key to the destination TEE as part of
        //                            replication — analogous to, but distinct from, the
        //                            `KeyDirectBackup`/`KeyDirectRestore` flow that ports
        //                            *wallet* keys. From that moment on, the new physical TEE
        //                            holds two keypairs: its own (used only to authorize the
        //                            takeover) and the old machine's (used to sign and decrypt
        //                            as `oldTeeId` from now on). Because the new TEE can sign
        //                            as `oldTeeId`, the on-chain (teeId, teePublicKey) pair must
        //                            stay the old one — otherwise the derivation invariant
        //                            `teeId == address(teePublicKey)` would break, and consumers
        //                            that encrypt to `getPublicKey(oldTeeId)` would target a key
        //                            the new TEE cannot decrypt.
        //
        // Replaced with the new TEE's data
        // --------------------------------
        //   - initialTeeId       — the new TEE's provisioning identity (the keypair it was
        //                          registered with). From now on, availability-check proofs from
        //                          this slot must attest `state.initialTeeId == new initialTeeId`
        //                          (see SystemStateVerifier).
        //   - teeProxyId, url    — the new TEE's proxy address and URL; consumers route requests here.
        //   - codeHash, platform — the new TEE's software version and hardware platform.
        //   - governanceHash     — the new TEE's committed extension governance set.
        //   - initialSigningPolicyId — taken from the just-verified proof (the new TEE's attested
        //                              starting signing policy), not from `newState`.
        //   - status             — set to REPLICATING here; `changeStatus(...)` below advances it
        //                          to PRODUCTION (and refreshes `lastStatusChangeTs`).
        //
        // Deliberately NOT copied
        // -----------------------
        //   - extensionId — replication is within a single extension; checked equal above.
        //   - owner       — replication preserves ownership; checked equal above.
        //   - teePublicKey — see "Chain identity preserved" above.
        //   - lastStatusChangeTs — refreshed by the subsequent `changeStatus` call.
        oldState.initialTeeId = newState.initialTeeId;
        oldState.teeProxyId = newState.teeProxyId;
        oldState.codeHash = newState.codeHash;
        oldState.platform = newState.platform;
        oldState.governanceHash = newState.governanceHash;
        oldState.url = newState.url;
        oldState.initialSigningPolicyId = _proof.responseBody.initialSigningPolicyId;
        oldState.status = IMachineManager.TeeStatus.REPLICATING;

        // delete the new TEE machine state
        MachineManager.State storage regState = MachineManager.getState();
        delete regState.teeMachineStates[_newTeeId];

        // verify the availability check proof for the updated TEE machine data
        IMachineManager.TeeMachineWithAttestationData memory oldTeeMachine =
            IMachineManager.TeeMachineWithAttestationData({
                teeId: oldTeeId,
                initialTeeId: oldState.initialTeeId,
                url: oldState.url,
                codeHash: oldState.codeHash,
                platform: oldState.platform
            });
        require(
            Verification.verifyAvailabilityCheckProof(
                oldTeeMachine, IMachineManager.TeeStatus.REPLICATING, _proof
            ),
            ITeeCommonErrors.InvalidResponseData()
        );

        // put TEE machine into production
        MachineManager.changeStatus(oldTeeId, IMachineManager.TeeStatus.PRODUCTION);
        Verification.extendAvailability(_proof);
    }

    function _sendInstructions(
        address[] memory _teeIds,
        bytes32 _opCommand,
        bytes memory _message,
        address _claimBackAddress
    )
        private
    {
        Instructions.sendInstructions(
            bytes32(0),
            _teeIds,
            IInstructions.TeeInstructionParams(
                REG_OP_TYPE,
                _opCommand,
                _message,
                new address[](0),
                0,
                _claimBackAddress
            )
        );
    }
}
