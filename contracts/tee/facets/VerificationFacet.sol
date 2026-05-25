// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IIVerification } from "../interface/IIVerification.sol";
import { IVerification, TEE_SOURCE_ID } from "../../userInterfaces/tee/IVerification.sol";
import { IInstructions } from "../../userInterfaces/tee/IInstructions.sol";
import { IMachineManager, REG_OP_TYPE } from "../../userInterfaces/tee/IMachineManager.sol";
import { IWalletManager } from "../../userInterfaces/tee/IWalletManager.sol";
import { ITeeAvailabilityCheck, TEE_AVAILABILITY_CHECK_ATTESTATION_TYPE }
    from "../../userInterfaces/fdc2/ITeeAvailabilityCheck.sol";
import { IPMWMultisigAccountConfigured, PMW_MULTISIG_ACCOUNT_CONFIGURED_ATTESTATION_TYPE }
    from "../../userInterfaces/fdc2/IPMWMultisigAccountConfigured.sol";
import { IFdc2Hub } from "../../userInterfaces/fdc2/IFdc2Hub.sol";
import { IFdc2Verification } from "../../userInterfaces/fdc2/IFdc2Verification.sol";
import { IFlareSystemsManager } from "../../userInterfaces/IFlareSystemsManager.sol";
import { IRelay } from "../../userInterfaces/IRelay.sol";
import { Verification } from "../library/Verification.sol";
import { MachineManager } from "../library/MachineManager.sol";
import { Replication } from "../library/Replication.sol";
import { ExternalAddresses } from "../library/ExternalAddresses.sol";
import { Instructions } from "../library/Instructions.sol";
import { WalletManager } from "../library/WalletManager.sol";
import { WalletKeyManager } from "../library/WalletKeyManager.sol";
import { FlareGovernedAccess } from "../../governance/implementation/FlareGovernedAccess.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title VerificationFacet
 * @notice Facet for TEE machine attestation, availability checks, and wallet (PMW) verification.
 */
contract VerificationFacet is IIVerification, FlareGovernedAccess {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 internal constant TEE_ATTESTATION = bytes32("TEE_ATTESTATION");

    /// @inheritdoc IVerification
    function requestTeeAttestation(
        address _teeId,
        address _claimBackAddress
    )
        external payable
    {
        Verification.State storage s = Verification.getState();
        bytes32 challenge;
        if (s.challengeTs[_teeId] + s.challengeValidityDurationSeconds > block.timestamp) {
            challenge = s.challenges[_teeId];
        } else {
            (uint256 randomNumber,,) = IRelay(ExternalAddresses.getState().relay).getRandomNumber();
            challenge = keccak256(abi.encode(_teeId, block.timestamp, randomNumber));
            s.challenges[_teeId] = challenge;
            s.challengeTs[_teeId] = block.timestamp;
        }

        address attestingTeeId = _getAttestingTeeId(_teeId);

        IMachineManager.TeeMachineWithAttestationData memory teeMachineWithAttestationData =
            MachineManager.getTeeMachineWithAttestationData(attestingTeeId);
        IMachineManager.TeeMachine memory teeMachine = MachineManager.getTeeMachine(attestingTeeId);
        teeMachineWithAttestationData.teeId = _teeId;
        teeMachine.teeId = _teeId;

        TeeAttestation memory message = TeeAttestation({
            teeMachine: teeMachineWithAttestationData,
            challenge: challenge
        });
        IMachineManager.TeeMachine[] memory teeMachines =
            new IMachineManager.TeeMachine[](1);
        teeMachines[0] = teeMachine;

        Instructions.sendInstructions(
            bytes32(0),
            teeMachines,
            IInstructions.TeeInstructionParams(
                REG_OP_TYPE,
                TEE_ATTESTATION,
                abi.encode(message),
                new address[](0),
                0,
                _claimBackAddress
            )
        );
        emit TeeAttestationRequested(_teeId, challenge);
    }

    /// @inheritdoc IVerification
    function requestAvailabilityCheckAttestation(
        address _teeId,
        bytes32 _instructionId,
        address _testOnTeeId,
        address _proofOwner,
        address _claimBackAddress
    )
        external payable
    {
        Verification.State storage s = Verification.getState();
        require(
            s.challengeTs[_teeId] + s.challengeValidityDurationSeconds > block.timestamp,
            ChallengeExpired(s.challengeTs[_teeId])
        );
        address attestingTeeId = _getAttestingTeeId(_teeId);
        IMachineManager.TeeMachine memory teeMachine = MachineManager.getTeeMachine(attestingTeeId);
        ITeeAvailabilityCheck.RequestBody memory requestBody = ITeeAvailabilityCheck.RequestBody({
            teeId: _teeId,
            teeProxyId: teeMachine.teeProxyId,
            url: teeMachine.url,
            challenge: s.challenges[_teeId],
            instructionId: _instructionId
        });

        address[] memory registrationCosigners = new address[](0);
        uint64 registrationCosignersThreshold = 0;
        IMachineManager.TeeStatus status = MachineManager.getTeeMachineStatus(attestingTeeId);
        if (status == IMachineManager.TeeStatus.INITIALIZED ||
            status == IMachineManager.TeeStatus.REPLICATING)
        {
            registrationCosigners = s.cosigners.values();
            registrationCosignersThreshold = s.cosignersThreshold;
        }

        Verification.requestFdc2Attestation(
            _testOnTeeId,
            registrationCosigners,
            registrationCosignersThreshold,
            TEE_AVAILABILITY_CHECK_ATTESTATION_TYPE,
            TEE_SOURCE_ID,
            abi.encode(requestBody),
            _proofOwner,
            _claimBackAddress
        );
    }

    /// @inheritdoc IVerification
    function confirmAvailability(
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        external
    {
        address teeId = _proof.requestBody.teeId;
        MachineManager.checkTeeMachineInProduction(teeId);
        MachineManager.validateAvailabilityCheckStatus(_proof.responseBody.status);
        uint256 extensionId = MachineManager.getExtensionId(teeId);
        IMachineManager.TeeMachineWithAttestationData memory teeMachine =
            MachineManager.getTeeMachineWithAttestationData(teeId);
        MachineManager.checkCodeHashPlatformSupported(extensionId, teeMachine.codeHash, teeMachine.platform);
        require(
            Verification.verifyAvailabilityCheckProof(
                teeMachine, IMachineManager.TeeStatus.PRODUCTION, _proof
            ),
            InvalidResponseData()
        );
        Verification.extendAvailability(_proof);
    }

    /// @inheritdoc IVerification
    function verifyAvailabilityCheckProof(
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        external
        returns (bool)
    {
        address teeId = _proof.requestBody.teeId;
        IMachineManager.TeeStatus status = MachineManager.getTeeMachineStatus(teeId);
        IMachineManager.TeeMachineWithAttestationData memory teeMachine =
            MachineManager.getTeeMachineWithAttestationData(teeId);
        return Verification.verifyAvailabilityCheckProof(teeMachine, status, _proof);
    }

    /// @inheritdoc IIVerification
    function setCosigners(
        address[] calldata _cosigners,
        uint64 _cosignersThreshold
    )
        external
        onlyGovernance
    {
        require(
            _cosigners.length >= _cosignersThreshold && (_cosigners.length == 0 || _cosignersThreshold > 0),
            InvalidThreshold()
        );
        Verification.State storage s = Verification.getState();
        address[] memory currentCosigners = s.cosigners.values();
        for (uint256 i = currentCosigners.length; i > 0; i--) {
            s.cosigners.remove(currentCosigners[i - 1]);
        }
        for (uint256 i = 0; i < _cosigners.length; i++) {
            require(_cosigners[i] != address(0), InvalidCosigner(_cosigners[i]));
            require(s.cosigners.add(_cosigners[i]), DuplicatedCosigner(_cosigners[i]));
        }
        s.cosignersThreshold = _cosignersThreshold;
        emit CosignersSet(_cosigners, _cosignersThreshold);
    }

    /// @inheritdoc IIVerification
    function updateSettings(
        uint64 _availabilityCheckValidityDurationSeconds,
        uint64 _signingPolicyValidityDurationInRewardEpochs,
        uint64 _challengeValidityDurationSeconds
    )
        external
        onlyGovernance
    {
        Verification.updateSettings(
            _availabilityCheckValidityDurationSeconds,
            _signingPolicyValidityDurationInRewardEpochs,
            _challengeValidityDurationSeconds
        );
    }

    // =========================================================================
    // Getters
    // =========================================================================

    /// @inheritdoc IVerification
    function getCosigners()
        external view
        returns (
            address[] memory _cosigners,
            uint64 _cosignersThreshold
        )
    {
        Verification.State storage s = Verification.getState();
        _cosigners = s.cosigners.values();
        _cosignersThreshold = s.cosignersThreshold;
    }

    /// @inheritdoc IVerification
    function getSettings()
        external view
        returns (
            uint256 _availabilityCheckValidityDurationSeconds,
            uint256 _challengeValidityDurationSeconds
        )
    {
        Verification.State storage s = Verification.getState();
        _availabilityCheckValidityDurationSeconds = s.availabilityCheckValidityDurationSeconds;
        _challengeValidityDurationSeconds = s.challengeValidityDurationSeconds;
    }

    /// @inheritdoc IVerification
    function getAvailabilityCheckValidity(
        address _teeId
    )
        external view
        returns (
            uint64 _endTs,
            uint32 _lastSigningPolicyId
        )
    {
        return Verification.getAvailabilityCheckValidity(_teeId);
    }

    // =========================================================================
    // Wallet verification (PMW)
    // =========================================================================

    /// @inheritdoc IVerification
    function requestPMWMultisigAccountConfiguredAttestation(
        bytes32 _walletId,
        bytes32 _sourceId,
        string calldata _accountAddress,
        address _testOnTeeId,
        address _proofOwner,
        address _claimBackAddress
    )
        external payable
    {
        require(bytes(_accountAddress).length > 0, AccountAddressZero());
        IWalletManager.WalletStatus walletStatus = WalletManager.getWalletStatus(_walletId);
        require(
            walletStatus == IWalletManager.WalletStatus.PRODUCTION ||
                walletStatus == IWalletManager.WalletStatus.PAUSED,
            OnlyProductionOrPausedStatus()
        );

        (uint64 multisigThreshold, uint64[] memory keyIds, ) =
            WalletKeyManager.getWalletKeysInfo(_walletId);
        IPMWMultisigAccountConfigured.RequestBody memory requestBody =
            IPMWMultisigAccountConfigured.RequestBody({
                accountAddress: _accountAddress,
                publicKeys: new bytes[](keyIds.length),
                threshold: multisigThreshold
            });
        for (uint256 i = 0; i < keyIds.length; i++) {
            requestBody.publicKeys[i] = WalletKeyManager.getWalletKeyPublicKey(_walletId, keyIds[i]);
        }

        Verification.State storage verState = Verification.getState();
        Verification.requestFdc2Attestation(
            _testOnTeeId,
            verState.cosigners.values(),
            verState.cosignersThreshold,
            PMW_MULTISIG_ACCOUNT_CONFIGURED_ATTESTATION_TYPE,
            _sourceId,
            abi.encode(requestBody),
            _proofOwner,
            _claimBackAddress
        );
    }

    /// @inheritdoc IVerification
    function verifyPMWMultisigAccountConfiguredProof(
        bytes32 _walletId,
        IPMWMultisigAccountConfigured.Proof calldata _proof
    )
        external
        returns (bool)
    {
        IFdc2Hub.Fdc2ResponseHeader calldata header = _proof.header;
        require(
            header.chainId == block.chainid &&
            header.thresholdBIPS == 0 &&
            header.attestationType == PMW_MULTISIG_ACCOUNT_CONFIGURED_ATTESTATION_TYPE,
            InvalidAttestation()
        );

        {
            IPMWMultisigAccountConfigured.RequestBody calldata requestBody = _proof.requestBody;
            (uint64 multisigThreshold, uint64[] memory keyIds, ) =
                WalletKeyManager.getWalletKeysInfo(_walletId);
            require(
                multisigThreshold == requestBody.threshold &&
                    keyIds.length == requestBody.publicKeys.length,
                InvalidRequestBody()
            );
            for (uint256 i = 0; i < keyIds.length; i++) {
                bytes memory publicKey = WalletKeyManager.getWalletKeyPublicKey(_walletId, keyIds[i]);
                require(
                    keccak256(requestBody.publicKeys[i]) == keccak256(publicKey),
                    InvalidRequestBody()
                );
            }
        }

        // Chain binding is enforced by `header.chainId == block.chainid` above and the inner
        // `keccak256(abi.encode(header))` — so a TEE / signing-policy / cosigner signature
        // produced for one Flare network cannot be replayed on another.
        bytes32 messageHash = keccak256(abi.encode(
            keccak256(abi.encode(header)),
            keccak256(abi.encode(_proof.requestBody)),
            keccak256(abi.encode(_proof.responseBody))
        ));

        ExternalAddresses.State storage ext = ExternalAddresses.getState();
        uint256 currentRewardEpochId =
            IFlareSystemsManager(ext.flareSystemsManager).getCurrentRewardEpochId();

        if (_proof.signatures.teeSignatures.length > 0) {
            IFdc2Verification(ext.fdc2Verification).verifyTeeSignatures(
                _proof.signatures.teeSignatures, messageHash
            );
        } else {
            Verification.checkSigningPolicySignatures(
                currentRewardEpochId, messageHash, _proof.signatures.signingPolicySignatures
            );
        }
        Verification.checkCosignerSignatures(
            Verification.toCosignersMessageHash(messageHash),
            _proof.signatures.cosignerSignatures
        );

        return _proof.responseBody.status == IPMWMultisigAccountConfigured.PMWMultisigAccountStatus.OK;
    }

    // =========================================================================
    // Internal
    // =========================================================================

    function _getAttestingTeeId(
        address _teeId
    )
        private view
        returns (address _attestingTeeId)
    {
        _attestingTeeId = Replication.getReplicatingTeeId(_teeId);
        if (_attestingTeeId == address(0)) {
            _attestingTeeId = _teeId;
        }
    }
}
