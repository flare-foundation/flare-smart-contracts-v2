// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ITeeWalletKeyManagerFacet } from "../../userInterfaces/tee/ITeeWalletKeyManagerFacet.sol";
import { ITeeWalletManagerFacet, WALLET_OP_TYPE } from "../../userInterfaces/tee/ITeeWalletManagerFacet.sol";
import { ITeeExtensionRegistryFacet } from "../../userInterfaces/tee/ITeeExtensionRegistryFacet.sol";
import { ITeeMachineRegistryFacet } from "../../userInterfaces/tee/ITeeMachineRegistryFacet.sol";
import { TeeIdKeyIdPair } from "../../userInterfaces/tee/ITeeIdKeyIdPair.sol";
import { PublicKey } from "../../userInterfaces/IPublicKey.sol";
import { Signature } from "../../userInterfaces/ISignature.sol";
import { TeeWalletKeyManager } from "../library/TeeWalletKeyManager.sol";
import { TeeWalletManager } from "../library/TeeWalletManager.sol";
import { TeeWalletProjectManager } from "../library/TeeWalletProjectManager.sol";
import { TeeMachineRegistry } from "../library/TeeMachineRegistry.sol";
import { TeeInstructionSender } from "../library/TeeInstructionSender.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title TeeWalletKeyManagerFacet
 * @notice Facet for TEE wallet key management.
 */
contract TeeWalletKeyManagerFacet is ITeeWalletKeyManagerFacet {

    bytes32 public constant KEY_GENERATE = bytes32("KEY_GENERATE");
    bytes32 public constant KEY_DELETE = bytes32("KEY_DELETE");

    modifier onlyOwner(bytes32 _walletId) {
        _checkOnlyOwner(_walletId);
        _;
    }

    modifier onlyOwnerOrBackupManager(bytes32 _walletId) {
        _checkOnlyOwnerOrBackupManager(_walletId);
        _;
    }

    /**
     * @inheritdoc ITeeWalletKeyManagerFacet
     */
    function setMultisigThreshold(
        bytes32 _walletId,
        uint64 _multisigThreshold
    )
        external
        onlyOwner(_walletId)
    {
        require(_multisigThreshold > 0, InvalidThreshold());
        _checkWalletStatus(_walletId);
        TeeWalletKeyManager.TeeWalletKeysState storage keys =
            TeeWalletKeyManager.getState().walletKeys[_walletId];
        keys.multisigThreshold = _multisigThreshold;
        emit WalletMultisigThresholdSet(_walletId, _multisigThreshold);
    }

    /**
     * @inheritdoc ITeeWalletKeyManagerFacet
     */
    function addKey(
        address _teeId,
        bytes32 _walletId,
        address _claimBackAddress
    )
        external payable
        onlyOwner(_walletId)
        returns (uint64 _keyId)
    {
        TeeMachineRegistry.checkTeeMachineInProduction(_teeId);
        _checkWalletStatus(_walletId);
        bytes32 projectId = TeeWalletManager.getWalletProjectId(_walletId);
        require(
            TeeWalletProjectManager.getExtensionId(projectId) == TeeMachineRegistry.getExtensionId(_teeId),
            ExtensionIdMismatch()
        );
        TeeWalletKeyManager.TeeWalletKeysState storage keys =
            TeeWalletKeyManager.getState().walletKeys[_walletId];
        _keyId = keys.keyIdCounter++;

        emit WalletKeyAdded(_teeId, _walletId, _keyId);

        (PublicKey[] memory adminsPublicKeys, uint64 adminsThreshold) =
            TeeWalletManager.getWalletAdminsPublicKeysAndThreshold(_walletId);
        (address[] memory cosigners, uint64 cosignersThreshold) =
            TeeWalletManager.getWalletCosignersAndThreshold(_walletId);

        KeyGenerate memory message = KeyGenerate({
            teeId: _teeId,
            walletId: _walletId,
            keyId: _keyId,
            keyType: TeeWalletProjectManager.getKeyType(projectId),
            signingAlgo: TeeWalletProjectManager.getSigningAlgo(projectId),
            configConstants: KeyConfigConstants({
                adminsPublicKeys: adminsPublicKeys,
                adminsThreshold: adminsThreshold,
                cosigners: cosigners,
                cosignersThreshold: cosignersThreshold
            })
        });

        _sendInstructions(_teeId, KEY_GENERATE, abi.encode(message), _claimBackAddress);
    }

    /**
     * @inheritdoc ITeeWalletKeyManagerFacet
     */
    function confirmKey(
        KeyExistence calldata _proof,
        Signature calldata _teeSignature
    )
        external
        onlyOwnerOrBackupManager(_proof.walletId)
    {
        TeeMachineRegistry.checkTeeMachineInProduction(_proof.teeId);
        bytes32 walletId = _proof.walletId;
        uint64 keyId = _proof.keyId;
        TeeWalletKeyManager.TeeWalletKeysState storage keys =
            TeeWalletKeyManager.getState().walletKeys[walletId];
        require(keys.keyIdCounter > keyId, InvalidKeyId());
        TeeWalletKeyManager.KeyDefinition storage keyDefinition = keys.keyDefinitions[keyId];
        require(_proof.nonce == keyDefinition.nonces[_proof.teeId], InvalidNonce());

        {
            bytes32 projectId = TeeWalletManager.getWalletProjectId(walletId);
            require(_proof.keyType == TeeWalletProjectManager.getKeyType(projectId), InvalidKeyType());
            require(
                _proof.signingAlgo == TeeWalletProjectManager.getSigningAlgo(projectId),
                InvalidSigningAlgo()
            );
        }

        _validateKeyExistenceConfigConstants(walletId, _proof.configConstants);
        require(_proof.settingsVersion == bytes32(0) && _proof.settings.length == 0, InvalidSettings());

        // check TEE signature
        address teeId = ECDSA.recover(
            MessageHashUtils.toEthSignedMessageHash(keccak256(abi.encode(_proof))),
            _teeSignature.v,
            _teeSignature.r,
            _teeSignature.s
        );
        require(teeId == _proof.teeId, InvalidTeeSignature());

        if (keyDefinition.publicKey.length > 0) {
            require(_proof.nonce > 0 && _proof.restored, KeyNotRestoredOnTeeMachine());
            require(
                keccak256(keyDefinition.publicKey) == keccak256(_proof.publicKey),
                InvalidPublicKey()
            );
            address[] storage keyDefinitionTeeIds = keyDefinition.teeIds;
            for (uint256 i = 0; i < keyDefinitionTeeIds.length; i++) {
                require(keyDefinitionTeeIds[i] != teeId, TeeIdAlreadyAdded());
            }
            keyDefinitionTeeIds.push(teeId);
        } else {
            assert(_proof.nonce == 0);
            require(_proof.publicKey.length > 0, InvalidPublicKey());
            _checkWalletStatus(walletId);
            _checkOnlyOwner(walletId);
            require(!_proof.restored, KeyNotGeneratedOnTeeMachine());
            keys.keyIds.push(keyId);
            keyDefinition.publicKey = _proof.publicKey;
            keyDefinition.teeIds.push(teeId);
        }

        emit WalletKeyConfirmed(teeId, walletId, keyId, _proof.publicKey);
    }

    /**
     * @inheritdoc ITeeWalletKeyManagerFacet
     */
    function deleteKey(
        address _teeId,
        bytes32 _walletId,
        uint64 _keyId,
        address _claimBackAddress
    )
        external payable
        onlyOwner(_walletId)
    {
        TeeMachineRegistry.checkTeeMachineInProduction(_teeId);
        bytes32 projectId = TeeWalletManager.getWalletProjectId(_walletId);
        require(
            TeeWalletProjectManager.getExtensionId(projectId) == TeeMachineRegistry.getExtensionId(_teeId),
            ExtensionIdMismatch()
        );
        TeeWalletKeyManager.TeeWalletKeysState storage keys =
            TeeWalletKeyManager.getState().walletKeys[_walletId];
        TeeWalletKeyManager.KeyDefinition storage keyDefinition = keys.keyDefinitions[_keyId];
        require(keyDefinition.publicKey.length > 0, InvalidKeyId());
        // delete tee id from key definition if exists
        uint256 length = keyDefinition.teeIds.length;
        if (length > 0) {
            uint256 index;
            for (index = 0; index < length; index++) {
                if (keyDefinition.teeIds[index] == _teeId) {
                    break;
                }
            }
            if (index < length) {
                keyDefinition.teeIds[index] = keyDefinition.teeIds[length - 1];
                keyDefinition.teeIds.pop();
            }
        }

        emit WalletKeyDeleted(_teeId, _walletId, _keyId);

        KeyDelete memory message = KeyDelete({
            teeId: _teeId,
            walletId: _walletId,
            keyId: _keyId,
            nonce: ++keyDefinition.nonces[_teeId]
        });
        _sendInstructions(_teeId, KEY_DELETE, abi.encode(message), _claimBackAddress);
    }

    /**
     * @inheritdoc ITeeWalletKeyManagerFacet
     */
    function cleanUpTeeIds(
        bytes32 _walletId,
        uint64 _keyId
    )
        external
        onlyOwnerOrBackupManager(_walletId)
    {
        TeeWalletKeyManager.TeeWalletKeysState storage keys =
            TeeWalletKeyManager.getState().walletKeys[_walletId];
        TeeWalletKeyManager.KeyDefinition storage keyDefinition = keys.keyDefinitions[_keyId];
        require(keyDefinition.publicKey.length > 0, InvalidKeyId());
        address[] storage teeIds = keyDefinition.teeIds;
        for (uint256 i = teeIds.length; i > 0; i--) {
            if (TeeMachineRegistry.getTeeMachineStatus(teeIds[i - 1]) !=
                ITeeMachineRegistryFacet.TeeStatus.PRODUCTION)
            {
                emit WalletKeyDeleted(teeIds[i - 1], _walletId, _keyId);
                teeIds[i - 1] = teeIds[teeIds.length - 1];
                teeIds.pop();
            }
        }
    }

    /**
     * @inheritdoc ITeeWalletKeyManagerFacet
     */
    function receivingTeesAndKeys(
        bytes32 _walletId
    )
        external
        returns (TeeIdKeyIdPair[] memory _teeIdKeyIdPairs)
    {
        return TeeWalletKeyManager.receivingTeesAndKeys(_walletId);
    }

    /**
     * @inheritdoc ITeeWalletKeyManagerFacet
     */
    function getWalletKeysInfo(
        bytes32 _walletId
    )
        external view
        returns (
            uint64 _multisigThreshold,
            uint64[] memory _keyIds,
            uint64 _counter
        )
    {
        return TeeWalletKeyManager.getWalletKeysInfo(_walletId);
    }

    /**
     * @inheritdoc ITeeWalletKeyManagerFacet
     */
    function getWalletKeyPublicKey(
        bytes32 _walletId,
        uint64 _keyId
    )
        external view
        returns (bytes memory _publicKey)
    {
        return TeeWalletKeyManager.getWalletKeyPublicKey(_walletId, _keyId);
    }

    /**
     * @inheritdoc ITeeWalletKeyManagerFacet
     */
    function getWalletKeyTeeIds(
        bytes32 _walletId,
        uint64 _keyId
    )
        external view
        returns (address[] memory _teeIds)
    {
        return TeeWalletKeyManager.getWalletKeyTeeIds(_walletId, _keyId);
    }

    // =========================================================================
    // Private helpers
    // =========================================================================

    function _sendInstructions(
        address _teeId,
        bytes32 _opCommand,
        bytes memory _message,
        address _claimBackAddress
    )
        private
    {
        address[] memory teeIds = new address[](1);
        teeIds[0] = _teeId;
        TeeInstructionSender.sendInstructions(
            bytes32(0),
            teeIds,
            ITeeExtensionRegistryFacet.TeeInstructionParams(
                WALLET_OP_TYPE,
                _opCommand,
                _message,
                new address[](0),
                0,
                _claimBackAddress
            )
        );
    }

    function _validateKeyExistenceConfigConstants(
        bytes32 _walletId,
        KeyConfigConstants calldata _configConstants
    )
        private view
    {
        (PublicKey[] memory adminsPublicKeys, uint64 adminsThreshold) =
            TeeWalletManager.getWalletAdminsPublicKeysAndThreshold(_walletId);
        require(_configConstants.adminsPublicKeys.length == adminsPublicKeys.length, LengthsMismatch());
        require(_configConstants.adminsThreshold == adminsThreshold, InvalidThreshold());
        for (uint256 i = 0; i < adminsPublicKeys.length; i++) {
            require(
                _configConstants.adminsPublicKeys[i].x == adminsPublicKeys[i].x &&
                _configConstants.adminsPublicKeys[i].y == adminsPublicKeys[i].y,
                InvalidPublicKey()
            );
        }
        (address[] memory cosigners, uint64 cosignersThreshold) =
            TeeWalletManager.getWalletCosignersAndThreshold(_walletId);
        require(_configConstants.cosigners.length == cosigners.length, LengthsMismatch());
        require(_configConstants.cosignersThreshold == cosignersThreshold, InvalidThreshold());
        for (uint256 i = 0; i < cosigners.length; i++) {
            require(_configConstants.cosigners[i] == cosigners[i], InvalidAddress());
        }
    }

    function _checkOnlyOwner(
        bytes32 _walletId
    )
        private view
    {
        bytes32 projectId = TeeWalletManager.getWalletProjectId(_walletId);
        require(TeeWalletProjectManager.getOwner(projectId) == msg.sender, OnlyOwner());
    }

    function _checkOnlyOwnerOrBackupManager(
        bytes32 _walletId
    )
        private view
    {
        bytes32 projectId = TeeWalletManager.getWalletProjectId(_walletId);
        TeeWalletProjectManager.checkOnlyOwnerOrBackupManager(projectId);
    }

    function _checkWalletStatus(
        bytes32 _walletId
    )
        private view
    {
        require(
            TeeWalletManager.getWalletStatus(_walletId) == ITeeWalletManagerFacet.WalletStatus.INITIALIZED,
            InvalidWalletStatus()
        );
    }
}
