// SPDX-License-Identifier: MIT
pragma solidity  ^0.8.27;

import { IPMWPaymentStatus, PMW_PAYMENT_STATUS_ATTESTATION_TYPE }
    from "../../userInterfaces/fdc2/IPMWPaymentStatus.sol";
import { AddressUpdatable } from "../../utils/implementation/AddressUpdatable.sol";
import { ITeePayments } from "../../userInterfaces/tee/ITeePayments.sol";
import { ITeePaymentsRegistry } from "../../userInterfaces/tee/ITeePaymentsRegistry.sol";
import { IVerification } from "../../userInterfaces/tee/IVerification.sol";
import { ITeeCommonErrors } from "../../userInterfaces/tee/ITeeCommonErrors.sol";
import { IFdc2Verification } from "../../userInterfaces/fdc2/IFdc2Verification.sol";
import { IFdc2Hub } from "../../userInterfaces/fdc2/IFdc2Hub.sol";
import { IFlareSystemsManager } from "../../userInterfaces/IFlareSystemsManager.sol";
import { Signature } from "../../userInterfaces/ISignature.sol";
import { AddressSet } from "../../utils/lib/AddressSet.sol";

contract PMWPaymentStatusVerifierMock is AddressUpdatable {
    using AddressSet for AddressSet.State;

    AddressSet.State private cosigners;
    uint64 private teeThreshold;
    uint64 private cosignersThreshold;

    /// FDC2 verification contract.
    IFdc2Verification public fdc2Verification;
    /// Flare systems manager contract.
    IFlareSystemsManager public flareSystemsManager;
    /// TEE payments registry
    ITeePaymentsRegistry public teePaymentsRegistry;

    error TeeThresholdNotMet();
    error AmountTooLow();
    error TeeThresholdZero();
    error UnsupportedSourceId();

    /**
     * Constructor.
     * @param _addressUpdater The address of the AddressUpdater contract.
     * @param _cosigners Cosigners
     * @param _cosignersThreshold Cosigners threshold
     * @param _teeThreshold Tee threshold
     */
    constructor(
        address _addressUpdater,
        address[] memory _cosigners,
        uint64 _cosignersThreshold,
        uint64 _teeThreshold
    )
        AddressUpdatable(_addressUpdater)
    {
        _setCosigners(_cosigners, _cosignersThreshold);
        _setTeeThreshold(_teeThreshold);
    }

    function verify(
        IPMWPaymentStatus.Proof calldata _proof
    )
        external
        returns (
            bool,
            uint256,
            uint256
        )
    {
        IFdc2Hub.Fdc2ResponseHeader calldata header = _proof.header;
        IPMWPaymentStatus.RequestBody calldata requestBody = _proof.requestBody;

        address teePaymentsAddress = teePaymentsRegistry.getTeePaymentsForSource(header.sourceId);
        require (teePaymentsAddress != address(0), UnsupportedSourceId());
        ITeePayments teePayments = ITeePayments(teePaymentsAddress);

        bytes32 walletId = teePayments.getWalletId(ITeePayments.PMWMultisigAccount({
            sourceId: header.sourceId,
            accountAddress: requestBody.senderAddress
        }));

        require(
            teePayments.getOpType() == requestBody.opType &&
            walletId != bytes32(0) &&
            header.thresholdBIPS == 0 &&
            header.attestationType == PMW_PAYMENT_STATUS_ATTESTATION_TYPE &&
            header.cosignersThreshold == cosignersThreshold,
            IVerification.InvalidAttestation()
        );

        IPMWPaymentStatus.ResponseBody calldata responseBody = _proof.responseBody;

        bytes32 messageHash = keccak256(
            abi.encode(
                keccak256(abi.encode(header)),
                keccak256(abi.encode(requestBody)),
                keccak256(abi.encode(responseBody))
            )
        );
        uint256 currentRewardEpochId = flareSystemsManager.getCurrentRewardEpochId();
        _checkSigningPolicySignatures(currentRewardEpochId, messageHash, _proof.signatures.signingPolicySignatures);

        messageHash = _toCosignersMessageHash(messageHash);
        _checkTeeSignatures(messageHash, _proof.signatures.teeSignatures);
        _checkCosignerSignatures(messageHash, _proof.signatures.cosignerSignatures);

        require(responseBody.amount >= responseBody.receivedAmount, AmountTooLow());

        return(
            responseBody.transactionStatus == 0,
            responseBody.amount - responseBody.receivedAmount,
            responseBody.transactionFee
        );
    }

    function setCosigners(
        address[] calldata _cosigners,
        uint64 _cosignersThreshold
    )
        external
    {
        _setCosigners(_cosigners, _cosignersThreshold);
    }

    function setTeeThreshold(
        uint64 _teeThreshold
    )
        external
    {
        _setTeeThreshold(_teeThreshold);
    }

    /**
     * @inheritdoc AddressUpdatable
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal override
    {
        fdc2Verification = IFdc2Verification(
            _getContractAddress(_contractNameHashes, _contractAddresses, "Fdc2Verification"));
        flareSystemsManager = IFlareSystemsManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsManager"));
        teePaymentsRegistry = ITeePaymentsRegistry(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeePaymentsRegistry"));
    }

    function _checkSigningPolicySignatures(
        uint256 _currentRewardEpochId,
        bytes32 _messageHash,
        bytes calldata _signatures
    )
        internal
    {
        uint256 rewardEpochId = fdc2Verification.verifySigningPolicySignatures(_signatures, _messageHash);
        require(
            rewardEpochId == _currentRewardEpochId || rewardEpochId + 1 == _currentRewardEpochId,
            IVerification.InvalidSigningPolicy()
        );
    }

    function _setCosigners(
        address[] memory _cosigners,
        uint64 _cosignersThreshold
    )
        internal
    {
        require(
            _cosigners.length >= _cosignersThreshold && (_cosigners.length == 0 || _cosignersThreshold > 0),
            ITeeCommonErrors.InvalidThreshold()
        );
        for (uint256 i = 0; i < _cosigners.length; i++) {
            require(_cosigners[i] != address(0), ITeeCommonErrors.InvalidCosigner(_cosigners[i]));
        }
        cosigners.replaceAll(_cosigners);
        cosignersThreshold = _cosignersThreshold;
    }

    function _setTeeThreshold(
        uint64 _teeThreshold
    )
        internal
    {
        require(_teeThreshold > 0, TeeThresholdZero());
        teeThreshold = _teeThreshold;
    }

    function _checkCosignerSignatures(
        bytes32 _messageHash,
        Signature[] calldata _signatures
    )
        internal view
    {
        if (cosignersThreshold == 0) {
            return; // no cosigners, nothing to check
        }
        address[] memory cosignersList = fdc2Verification.recoverCosigners(_signatures, _messageHash);
        require(cosignersList.length >= cosignersThreshold, IVerification.CosignersThresholdNotMet());
        for (uint256 i = 0; i < cosignersList.length; i++) {
            require(cosigners.index[cosignersList[i]] != 0, ITeeCommonErrors.InvalidCosigner(cosignersList[i]));
        }
    }

    function _checkTeeSignatures(
        bytes32 _messageHash,
        Signature[] calldata _signatures
    )
        internal view
    {
        address[] memory teesList = fdc2Verification.verifyTeeSignatures(_signatures, _messageHash);
        require(teesList.length >= teeThreshold, TeeThresholdNotMet());
    }

    function _toCosignersMessageHash(
        bytes32 _messageHash
    )
        internal pure
        returns (bytes32)
    {
        return keccak256(bytes.concat(hex"010000000000", _messageHash));
    }
}