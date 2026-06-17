// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { FlareUpgradeableBase } from "../../governance/implementation/FlareUpgradeableBase.sol";
import { IIFlareTeeManager } from "../interface/IIFlareTeeManager.sol";
import { ITeePaymentsConfigVerifier } from "../../userInterfaces/tee/ITeePaymentsConfigVerifier.sol";
import { ITeePaymentsRegistry } from "../../userInterfaces/tee/ITeePaymentsRegistry.sol";
import { IWalletManager } from "../../userInterfaces/tee/IWalletManager.sol";
import { IFdc2Verification } from "../../userInterfaces/fdc2/IFdc2Verification.sol";
import { IFdc2Hub } from "../../userInterfaces/fdc2/IFdc2Hub.sol";
import {
    IPMWMultisigAccountConfigured,
    PMW_MULTISIG_ACCOUNT_CONFIGURED_ATTESTATION_TYPE
} from "../../userInterfaces/fdc2/IPMWMultisigAccountConfigured.sol";
import {
    IPMWMultisigUtxoConfigured,
    PMW_MULTISIG_UTXO_CONFIGURED_ATTESTATION_TYPE
} from "../../userInterfaces/fdc2/IPMWMultisigUtxoConfigured.sol";
import { IFlareSystemsManager } from "../../userInterfaces/IFlareSystemsManager.sol";
import { AddressUpdatable } from "../../utils/implementation/AddressUpdatable.sol";
import { Fdc2ProofVerification } from "../../fdc2/library/Fdc2ProofVerification.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

/**
 * TeePaymentsConfigVerifier — shared request + verify contract for PMW multisig configuration
 * attestations, used by both the account-based TeePayments and the UTXO-based TeePaymentsUtxo
 * contracts. Keeping the request/verify logic here (rather than duplicated in each payment
 * contract) keeps the payment contracts within the EVM contract size limit.
 *
 * The contract is stateless with respect to accounts/anchors: the `verify*` methods validate a
 * proof and return the extracted verified data; the payment contracts own all account/anchor state.
 */
contract TeePaymentsConfigVerifier is ITeePaymentsConfigVerifier, FlareUpgradeableBase {

    uint256 internal constant MAX_ANCHOR_COUNT = 32;

    /// FlareTeeManager Diamond contract.
    IIFlareTeeManager public flareTeeManager;
    /// Flare systems manager contract.
    IFlareSystemsManager public flareSystemsManager;
    /// Shared sourceId -> TeePayments registry.
    ITeePaymentsRegistry public teePaymentsRegistry;
    /// FDC2 verification contract.
    IFdc2Verification public fdc2Verification;
    /// FDC2 hub contract.
    IFdc2Hub public fdc2Hub;

    /**
     * Constructor that initializes with invalid parameters to prevent direct deployment/updates.
     */
    constructor() FlareUpgradeableBase() {}

    /**
     * Proxyable initialization method. Can be called only once, from the proxy constructor
     * (single call is assured by the `initializer` modifier).
     * @param _governanceSettings The governance settings interface.
     * @param _initialGovernance The initial governance address.
     * @param _addressUpdater The address updater contract.
     */
    function initialize(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater
    )
        external virtual
        initializer
    {
        FlareUpgradeableBase.initializeBase(_governanceSettings, _initialGovernance, _addressUpdater);
    }

    /**
     * @inheritdoc ITeePaymentsConfigVerifier
     */
    function requestAccountConfiguredAttestation(
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
        _checkConfiguredAttestationRequest(_walletId, _sourceId);
        (uint64 multisigThreshold, bytes[] memory publicKeys) =
            flareTeeManager.getWalletPublicKeys(_walletId);
        IFdc2Hub.Fdc2AttestationRequest memory request = IFdc2Hub.Fdc2AttestationRequest({
            header: IFdc2Hub.Fdc2RequestHeader({
                attestationType: PMW_MULTISIG_ACCOUNT_CONFIGURED_ATTESTATION_TYPE,
                sourceId: _sourceId,
                thresholdBIPS: 0,
                proofOwner: _proofOwner
            }),
            requestBody: abi.encode(IPMWMultisigAccountConfigured.RequestBody({
                accountAddress: _accountAddress,
                publicKeys: publicKeys,
                threshold: multisigThreshold
            }))
        });
        _requestConfiguredAttestation(request, _testOnTeeId, _claimBackAddress);
    }

    /**
     * @inheritdoc ITeePaymentsConfigVerifier
     */
    function requestUtxoConfiguredAttestation(
        bytes32 _walletId,
        bytes32 _sourceId,
        uint32 _accountIndex,
        IPMWMultisigUtxoConfigured.Anchor[] calldata _anchors,
        address _testOnTeeId,
        address _proofOwner,
        address _claimBackAddress
    )
        external payable
    {
        require(_anchors.length > 0, AnchorSetEmpty());
        _checkConfiguredAttestationRequest(_walletId, _sourceId);
        (uint64 multisigThreshold, bytes[] memory publicKeys) =
            flareTeeManager.getWalletPublicKeys(_walletId);
        IFdc2Hub.Fdc2AttestationRequest memory request = IFdc2Hub.Fdc2AttestationRequest({
            header: IFdc2Hub.Fdc2RequestHeader({
                attestationType: PMW_MULTISIG_UTXO_CONFIGURED_ATTESTATION_TYPE,
                sourceId: _sourceId,
                thresholdBIPS: 0,
                proofOwner: _proofOwner
            }),
            requestBody: abi.encode(IPMWMultisigUtxoConfigured.RequestBody({
                accountIndex: _accountIndex,
                publicKeys: publicKeys,
                threshold: multisigThreshold,
                anchors: _anchors
            }))
        });
        _requestConfiguredAttestation(request, _testOnTeeId, _claimBackAddress);
    }

    /**
     * @inheritdoc ITeePaymentsConfigVerifier
     */
    function verifyAccountConfiguredProof(
        bytes32 _walletId,
        IPMWMultisigAccountConfigured.Proof calldata _proof
    )
        external
    {
        require(
            _proof.header.thresholdBIPS == 0 &&
            _proof.header.attestationType == PMW_MULTISIG_ACCOUNT_CONFIGURED_ATTESTATION_TYPE,
            InvalidAttestation()
        );
        _checkWalletPublicKeys(_walletId, _proof.requestBody.threshold, _proof.requestBody.publicKeys);
        _verifyConfiguredProofSignatures(
            keccak256(abi.encode(
                keccak256(abi.encode(_proof.header)),
                keccak256(abi.encode(_proof.requestBody)),
                keccak256(abi.encode(_proof.responseBody))
            )),
            _proof.signatures
        );
        require(
            _proof.responseBody.status == IPMWMultisigAccountConfigured.PMWMultisigAccountStatus.OK,
            InvalidProof()
        );
        require(bytes(_proof.requestBody.accountAddress).length > 0, AccountAddressZero());
    }

    /**
     * @inheritdoc ITeePaymentsConfigVerifier
     */
    function verifyUtxoConfiguredProof(
        bytes32 _walletId,
        IPMWMultisigUtxoConfigured.Proof calldata _proof
    )
        external
    {
        require(
            _proof.header.thresholdBIPS == 0 &&
            _proof.header.attestationType == PMW_MULTISIG_UTXO_CONFIGURED_ATTESTATION_TYPE,
            InvalidAttestation()
        );
        _checkUtxoProofAnchorShape(_proof);
        _checkWalletPublicKeys(_walletId, _proof.requestBody.threshold, _proof.requestBody.publicKeys);
        _verifyConfiguredProofSignatures(
            keccak256(abi.encode(
                keccak256(abi.encode(_proof.header)),
                keccak256(abi.encode(_proof.requestBody)),
                keccak256(abi.encode(_proof.responseBody))
            )),
            _proof.signatures
        );
        require(
            _proof.responseBody.status == IPMWMultisigUtxoConfigured.PMWMultisigUtxoStatus.OK,
            InvalidProof()
        );
    }

    /**
     * @inheritdoc AddressUpdatable
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal virtual override
    {
        flareTeeManager = IIFlareTeeManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareTeeManager"));
        flareSystemsManager = IFlareSystemsManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsManager"));
        teePaymentsRegistry = ITeePaymentsRegistry(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeePaymentsRegistry"));
        fdc2Verification = IFdc2Verification(
            _getContractAddress(_contractNameHashes, _contractAddresses, "Fdc2Verification"));
        fdc2Hub = IFdc2Hub(
            _getContractAddress(_contractNameHashes, _contractAddresses, "Fdc2Hub"));
    }

    function _requestConfiguredAttestation(
        IFdc2Hub.Fdc2AttestationRequest memory _request,
        address _testOnTeeId,
        address _claimBackAddress
    )
        internal
    {
        (address[] memory cosigners, uint64 cosignersThreshold) = flareTeeManager.getCosigners();
        (uint256 numberOfTees, address[] memory teeIds) = _teeTargets(_testOnTeeId);
        fdc2Hub.requestAttestation{value: msg.value}(
            _request,
            numberOfTees,
            teeIds,
            cosigners,
            cosignersThreshold,
            _claimBackAddress
        );
    }

    function _verifyConfiguredProofSignatures(
        bytes32 _dataHash,
        IFdc2Verification.Fdc2Signatures calldata _signatures
    )
        internal
    {
        bytes32 messageHash = Fdc2ProofVerification.messageHash(_dataHash);
        uint256 currentRewardEpochId = flareSystemsManager.getCurrentRewardEpochId();
        (address[] memory cosigners, uint64 cosignersThreshold) = flareTeeManager.getCosigners();
        if (_signatures.teeSignatures.length > 0) {
            Fdc2ProofVerification.verifyTeeSignatures(
                address(fdc2Verification), _signatures.teeSignatures, messageHash
            );
        } else {
            Fdc2ProofVerification.verifySigningPolicySignatures(
                address(fdc2Verification),
                currentRewardEpochId,
                _signatures.signingPolicySignatures,
                messageHash
            );
        }
        Fdc2ProofVerification.verifyCosignerSignatures(
            address(fdc2Verification),
            messageHash,
            _signatures.cosignerSignatures,
            cosigners,
            cosignersThreshold
        );
    }

    function _checkConfiguredAttestationRequest(
        bytes32 _walletId,
        bytes32 _sourceId
    )
        internal view
    {
        bytes32 projectId = flareTeeManager.getWalletProjectId(_walletId);
        bytes32 sourceKeyType = _sourceKeyType(_sourceId);
        require(flareTeeManager.getExtensionId(projectId) == 0, OnlySystemExtensionId());
        require(flareTeeManager.getKeyType(projectId) == sourceKeyType, WrongKeyType());
        IWalletManager.WalletStatus walletStatus = flareTeeManager.getWalletStatus(_walletId);
        require(
            walletStatus == IWalletManager.WalletStatus.PRODUCTION ||
            walletStatus == IWalletManager.WalletStatus.PAUSED,
            OnlyProductionOrPausedStatus()
        );
    }

    function _checkWalletPublicKeys(
        bytes32 _walletId,
        uint64 _threshold,
        bytes[] calldata _publicKeys
    )
        internal view
    {
        (uint64 walletThreshold, bytes[] memory walletPublicKeys) =
            flareTeeManager.getWalletPublicKeys(_walletId);
        require(
            walletThreshold == _threshold &&
            walletPublicKeys.length == _publicKeys.length,
            InvalidRequestBody()
        );
        for (uint256 i = 0; i < walletPublicKeys.length; i++) {
            require(keccak256(_publicKeys[i]) == keccak256(walletPublicKeys[i]), InvalidRequestBody());
        }
    }

    function _sourceKeyType(
        bytes32 _sourceId
    )
        internal view
        returns (bytes32 _keyType)
    {
        address teePayments;
        (_keyType, teePayments) = teePaymentsRegistry.getSourceKeyTypeAndTeePayments(_sourceId);
        require(teePayments != address(0), UnsupportedSourceId());
    }

    function _checkUtxoProofAnchorShape(
        IPMWMultisigUtxoConfigured.Proof calldata _proof
    )
        internal pure
    {
        uint256 anchorCount = _proof.requestBody.anchors.length;
        require(anchorCount > 0, AnchorSetEmpty());
        require(anchorCount <= MAX_ANCHOR_COUNT, AnchorLimitExceeded());
        require(_proof.responseBody.anchorAddresses.length == anchorCount, LengthsMismatch());
        require(bytes(_proof.responseBody.accountAddress).length > 0, AccountAddressZero());
        for (uint256 i = 0; i < anchorCount; i++) {
            require(bytes(_proof.responseBody.anchorAddresses[i]).length > 0, AnchorAddressZero());
        }
    }

    function _teeTargets(
        address _testOnTeeId
    )
        internal pure
        returns (
            uint256 _numberOfTees,
            address[] memory _teeIds
        )
    {
        if (_testOnTeeId != address(0)) {
            _teeIds = new address[](1);
            _teeIds[0] = _testOnTeeId;
        } else {
            _numberOfTees = 1;
        }
    }
}
