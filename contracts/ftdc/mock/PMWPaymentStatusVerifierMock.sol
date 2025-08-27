// SPDX-License-Identifier: MIT
pragma solidity  ^0.8.27;

import { IPMWPaymentStatus, PMW_PAYMENT_STATUS_ATTESTATION_TYPE }
    from "../../userInterfaces/ftdc/IPMWPaymentStatus.sol";
import { AddressUpdatable } from "../../utils/implementation/AddressUpdatable.sol";
import { TeePayments } from "../../tee/implementation/TeePayments.sol";
import { ITeeWalletManager } from "../../userInterfaces/tee/ITeeWalletManager.sol";
import { ITeeWalletProjectManager } from "../../userInterfaces/tee/ITeeWalletProjectManager.sol";
import { ITeeExtensionRegistry } from "../../userInterfaces/tee/ITeeExtensionRegistry.sol";
import { ITeeVerification } from "../../userInterfaces/tee/ITeeVerification.sol";
import { IFtdcVerification } from "../../userInterfaces/ftdc/IFtdcVerification.sol";
import { IFtdcHub } from "../../userInterfaces/ftdc/IFtdcHub.sol";
import { IFlareSystemsManager } from "../../userInterfaces/IFlareSystemsManager.sol";
import { Signature } from "../../userInterfaces/ISignature.sol";
import { AddressSet } from "../../utils/lib/AddressSet.sol";

contract PMWPaymentStatusVerifierMock is AddressUpdatable {
    using AddressSet for AddressSet.State;

    struct WalletProjectTempState {
        bytes32 walletId;
        bytes32 projectId;
        uint256 extensionId;
        bytes32 opType;
    }

    AddressSet.State private cosigners;
    uint64 private teeThreshold;
    uint64 private cosignersThreshold;

    /// TEE extension registry contract.
    ITeeExtensionRegistry public teeExtensionRegistry;
    /// TEE wallet manager contract.
    ITeeWalletManager public teeWalletManager;
    /// TEE wallet project manager contract.
    ITeeWalletProjectManager public teeWalletProjectManager;
    /// FTDC verification contract.
    IFtdcVerification public ftdcVerification;
    /// Flare systems manager contract.
    IFlareSystemsManager public flareSystemsManager;

    error InvalidSenderAddress();
    error TeeThresholdNotMet();
    error AmountTooLow();
    error TeeThresholdZero();

    /**
     * Constructor.
     * @param _cosigners Cosigners
     * @param _teeThreshold Tee threshold
     * @param _addressUpdater The address of the AddressUpdater contract.
     */
    constructor(
        address[] memory _cosigners,
        uint64 _cosignersThreshold,
        uint64 _teeThreshold,
        address _addressUpdater
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
        returns (bool, uint256, uint256)
    {
        IPMWPaymentStatus.RequestBody memory requestBody = _proof.requestBody;

        WalletProjectTempState memory tempState;
        tempState.walletId = requestBody.walletId;
        tempState.projectId = teeWalletManager.getWalletProjectId(tempState.walletId);
        tempState.extensionId = teeWalletProjectManager.getExtensionId(tempState.projectId);
        tempState.opType = teeWalletProjectManager.getOpType(tempState.projectId);
        TeePayments teePayments =
            TeePayments(address(teeExtensionRegistry.getWalletProjectOpTypeConstantsProvider(
                tempState.extensionId, tempState.opType)));

        IFtdcHub.FtdcResponseHeader memory header = _proof.header;
        bytes32 sourceId = teePayments.sourceId();
        require(
            header.thresholdBIPS == 0 &&
            header.attestationType == PMW_PAYMENT_STATUS_ATTESTATION_TYPE &&
            header.sourceId == sourceId &&
            header.cosignersThreshold == cosignersThreshold,
            ITeeVerification.InvalidAttestation()
        );

        IPMWPaymentStatus.ResponseBody memory responseBody = _proof.responseBody;

        require(
            keccak256(abi.encode(teePayments.getWalletAddress(tempState.walletId))) ==
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
        _checkTeeSignatures(messageHash, _proof.signatures.teeSignatures, teeThreshold);
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
        teeExtensionRegistry = ITeeExtensionRegistry(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeExtensionRegistry"));
        teeWalletManager = ITeeWalletManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeWalletManager"));
        teeWalletProjectManager = ITeeWalletProjectManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeWalletProjectManager"));
        ftdcVerification = IFtdcVerification(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FtdcVerification"));
        flareSystemsManager = IFlareSystemsManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsManager"));
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
        address[] memory _cosigners,
        uint64 _cosignersThreshold
    )
        internal
    {
        require(
            _cosigners.length >= _cosignersThreshold && (_cosigners.length == 0 || _cosignersThreshold > 0),
            ITeeVerification.InvalidThreshold()
        );
        for (uint256 i = 0; i < _cosigners.length; i++) {
            require(_cosigners[i] != address(0), ITeeVerification.InvalidCosigner(_cosigners[i]));
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
        address[] memory cosignersList = ftdcVerification.verifyCosignerSignatures(_signatures, _messageHash);
        require(cosignersList.length >= cosignersThreshold, ITeeVerification.CosignersThresholdNotMet());
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