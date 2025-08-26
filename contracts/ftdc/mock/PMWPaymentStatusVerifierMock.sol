// SPDX-License-Identifier: MIT
pragma solidity  ^0.8.27;

import { IPMWPaymentStatus, PMW_PAYMENT_STATUS_ATTESTATION_TYPE }
    from "../../userInterfaces/ftdc/IPMWPaymentStatus.sol";
import { AddressUpdatable } from "../../utils/implementation/AddressUpdatable.sol";
import { ITeePayments } from "../../userInterfaces/tee/ITeePayments.sol";
import { ITeeExtensionRegistry } from "../../userInterfaces/tee/ITeeExtensionRegistry.sol";
import { ITeeVerification } from "../../userInterfaces/tee/ITeeVerification.sol";
import { IFtdcVerification } from "../../userInterfaces/ftdc/IFtdcVerification.sol";
import { IFtdcHub } from "../../userInterfaces/ftdc/IFtdcHub.sol";
import { IFlareSystemsManager } from "../../userInterfaces/IFlareSystemsManager.sol";
import { Signature } from "../../userInterfaces/ISignature.sol";
import { AddressSet } from "../../utils/lib/AddressSet.sol";

contract PMWPaymentStatusVerifierMock is AddressUpdatable {
    using AddressSet for AddressSet.State;

    AddressSet.State private cosigners;
    uint64 private teeThreshold;

    /// TEE extension registry contract.
    ITeeExtensionRegistry public teeExtensionRegistry;
    /// TEE payments contract.
    ITeePayments public teePayments;
    /// FTDC verification contract.
    IFtdcVerification public ftdcVerification;
    /// Flare systems manager contract.
    IFlareSystemsManager public flareSystemsManager;

    error InvalidSenderAddress();
    error TeeThresholdNotMet();
    error AmountTooLow();
    error NoCosigners();
    error TeeThresholdZero();

    /**
     * Constructor.
     * @param _cosigners Cosigners
     * @param _teeThreshold Tee threshold
     * @param _addressUpdater The address of the AddressUpdater contract.
     */
    constructor(
        address[] memory _cosigners,
        uint64 _teeThreshold,
        address _addressUpdater
    )
        AddressUpdatable(_addressUpdater)
    {
        _setCosigners(_cosigners);
        _setTeeThreshold(_teeThreshold);
    }

    function verify(
        IPMWPaymentStatus.Proof calldata _proof,
        bytes32 _sourceId,
        uint64 _teeThreshold
    )
        external
        returns (bool, uint256, uint256)
    {
        IFtdcHub.FtdcResponseHeader memory header = _proof.header;
        require(
            header.thresholdBIPS == 0 &&
            header.attestationType == PMW_PAYMENT_STATUS_ATTESTATION_TYPE &&
            header.sourceId == _sourceId,
            ITeeVerification.InvalidAttestation()
        );

        IPMWPaymentStatus.RequestBody memory requestBody = _proof.requestBody;
        IPMWPaymentStatus.ResponseBody memory responseBody = _proof.responseBody;

        bytes32 walletId = requestBody.walletId;
        require(
            keccak256(abi.encode(teePayments.getWalletAddress(walletId))) ==
            keccak256(abi.encode(responseBody.senderAddress)),
            InvalidSenderAddress()
        );

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
        _checkTeeSignatures(messageHash, _proof.signatures.teeSignatures, _teeThreshold);
        _checkCosignerSignatures(messageHash, _proof.signatures.cosignerSignatures, header.cosignersThreshold);

        require(responseBody.amount >= responseBody.receivedAmount, AmountTooLow());

        return(
            responseBody.transactionStatus == 0,
            responseBody.amount - responseBody.receivedAmount,
            responseBody.transactionFee
        );
    }

    function setCosigners(
        address[] memory _cosigners
    )
        external
    {
        _setCosigners(_cosigners);
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
        teeExtensionRegistry = ITeeExtensionRegistry(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeExtensionRegistry"));
        teePayments = ITeePayments(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeePayments"));
        ftdcVerification = IFtdcVerification(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FtdcVerification"));
    }

    function _checkSigningPolicySignatures(
        uint256 _currentRewardEpochId,
        bytes32 _messageHash,
        bytes calldata _signatures
    )
        internal
    {
        uint256 rewardEpochId = ftdcVerification.verifySigningPolicySignatures(_signatures, _messageHash);
        require(
            rewardEpochId == _currentRewardEpochId || rewardEpochId + 1 == _currentRewardEpochId,
            ITeeVerification.InvalidSigningPolicy()
        );
    }

    function _setCosigners(
        address[] memory _cosigners
    )
        internal
    {
        require(_cosigners.length > 0, NoCosigners());
        for (uint256 i = 0; i < _cosigners.length; i++) {
            require(_cosigners[i] != address(0), ITeeVerification.InvalidCosigner(_cosigners[i]));
        }
        cosigners.replaceAll(_cosigners);
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
        Signature[] calldata _signatures,
        uint64 _cosignersThreshold
    )
        internal view
    {
        if (_cosignersThreshold == 0) {
            return; // no cosigners, nothing to check
        }
        address[] memory cosignersList = ftdcVerification.verifyCosignerSignatures(_signatures, _messageHash);
        require(cosignersList.length >= _cosignersThreshold, ITeeVerification.CosignersThresholdNotMet());
        for (uint256 i = 0; i < cosignersList.length; i++) {
            require(cosigners.index[cosignersList[i]] != 0, ITeeVerification.InvalidCosigner(cosignersList[i]));
        }
    }

    function _checkTeeSignatures(
        bytes32 _messageHash,
        Signature[] calldata _signatures,
        uint64 _teeThreshold
    )
        internal view
    {
        address[] memory teesList = ftdcVerification.verifyTeeSignatures(_signatures, _messageHash);
        require(teesList.length >= _teeThreshold, TeeThresholdNotMet());
    }

    function _toCosignersMessageHash(bytes32 _messageHash)
        internal pure
        returns(bytes32)
    {
        return keccak256(bytes.concat(hex"010000000000", _messageHash));
    }
}