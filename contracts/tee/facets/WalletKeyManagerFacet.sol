// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { IWalletKeyManager, TEE_KEY_EXISTENCE } from "../../userInterfaces/tee/IWalletKeyManager.sol";
import { IWalletManager, WALLET_OP_TYPE } from "../../userInterfaces/tee/IWalletManager.sol";
import { IInstructions } from "../../userInterfaces/tee/IInstructions.sol";
import { IMachineManager } from "../../userInterfaces/tee/IMachineManager.sol";
import { TeeIdKeyIdPair } from "../../userInterfaces/tee/ITeeIdKeyIdPair.sol";
import { PublicKey } from "../../userInterfaces/IPublicKey.sol";
import { Signature } from "../../userInterfaces/ISignature.sol";
import { SignedPayload } from "../../utils/lib/SignedPayload.sol";
import { WalletKeyManager } from "../library/WalletKeyManager.sol";
import { WalletManager } from "../library/WalletManager.sol";
import { WalletProjectManager } from "../library/WalletProjectManager.sol";
import { MachineManager } from "../library/MachineManager.sol";
import { Instructions } from "../library/Instructions.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title WalletKeyManagerFacet
 * @notice Facet for TEE wallet key management.
 */
contract WalletKeyManagerFacet is IWalletKeyManager {

    bytes32 internal constant KEY_GENERATE = bytes32("KEY_GENERATE");
    bytes32 internal constant KEY_DELETE = bytes32("KEY_DELETE");

    modifier onlyOwner(bytes32 _walletId) {
        _checkOnlyOwner(_walletId);
        _;
    }

    modifier onlyOwnerOrBackupManager(bytes32 _walletId) {
        _checkOnlyOwnerOrBackupManager(_walletId);
        _;
    }

    /**
     * @inheritdoc IWalletKeyManager
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
        WalletKeyManager.TeeWalletKeysState storage keys =
            WalletKeyManager.getState().walletKeys[_walletId];
        keys.multisigThreshold = _multisigThreshold;
        emit WalletMultisigThresholdSet(_walletId, _multisigThreshold);
    }

    /**
     * @inheritdoc IWalletKeyManager
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
        MachineManager.checkTeeMachineInProduction(_teeId);
        _checkWalletStatus(_walletId);
        bytes32 projectId = WalletManager.getWalletProjectId(_walletId);
        require(
            WalletProjectManager.getExtensionId(projectId) == MachineManager.getExtensionId(_teeId),
            ExtensionIdMismatch()
        );
        WalletKeyManager.TeeWalletKeysState storage keys =
            WalletKeyManager.getState().walletKeys[_walletId];
        _keyId = keys.keyIdCounter++;

        emit WalletKeyAdded(_teeId, _walletId, _keyId);

        (PublicKey[] memory adminsPublicKeys, uint64 adminsThreshold) =
            WalletManager.getWalletAdminsPublicKeysAndThreshold(_walletId);
        (address[] memory cosigners, uint64 cosignersThreshold) =
            WalletManager.getWalletCosignersAndThreshold(_walletId);

        KeyGenerate memory message = KeyGenerate({
            teeId: _teeId,
            walletId: _walletId,
            keyId: _keyId,
            keyType: WalletProjectManager.getKeyType(projectId),
            signingAlgo: WalletProjectManager.getSigningAlgo(projectId),
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
     * @inheritdoc IWalletKeyManager
     */
    function confirmKey(
        KeyExistence calldata _proof,
        Signature calldata _teeSignature
    )
        external
        onlyOwnerOrBackupManager(_proof.walletId)
    {
        MachineManager.checkTeeMachineInProduction(_proof.teeId);
        bytes32 walletId = _proof.walletId;
        uint64 keyId = _proof.keyId;
        WalletKeyManager.TeeWalletKeysState storage keys =
            WalletKeyManager.getState().walletKeys[walletId];
        require(keys.keyIdCounter > keyId, InvalidKeyId());
        WalletKeyManager.KeyDefinition storage keyDefinition = keys.keyDefinitions[keyId];
        require(_proof.nonce == keyDefinition.nonces[_proof.teeId], InvalidNonce());

        bytes32 projectId = WalletManager.getWalletProjectId(walletId);
        require(_proof.keyType == WalletProjectManager.getKeyType(projectId), InvalidKeyType());
        require(
            _proof.signingAlgo == WalletProjectManager.getSigningAlgo(projectId),
            InvalidSigningAlgo()
        );
        require(
            WalletProjectManager.getExtensionId(projectId) == MachineManager.getExtensionId(_proof.teeId),
            ExtensionIdMismatch()
        );

        _validateKeyExistenceConfigConstants(walletId, _proof.configConstants);
        require(_proof.settingsVersion == bytes32(0) && _proof.settings.length == 0, InvalidSettings());

        address teeId = ECDSA.recover(
            SignedPayload.ethSignedHash(TEE_KEY_EXISTENCE, keccak256(abi.encode(_proof))),
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
     * @inheritdoc IWalletKeyManager
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
        MachineManager.checkTeeMachineInProduction(_teeId);
        bytes32 projectId = WalletManager.getWalletProjectId(_walletId);
        require(
            WalletProjectManager.getExtensionId(projectId) == MachineManager.getExtensionId(_teeId),
            ExtensionIdMismatch()
        );
        WalletKeyManager.TeeWalletKeysState storage keys =
            WalletKeyManager.getState().walletKeys[_walletId];
        WalletKeyManager.KeyDefinition storage keyDefinition = keys.keyDefinitions[_keyId];
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
     * @inheritdoc IWalletKeyManager
     */
    function cleanUpTeeIds(
        bytes32 _walletId,
        uint64 _keyId
    )
        external
        onlyOwnerOrBackupManager(_walletId)
    {
        WalletKeyManager.TeeWalletKeysState storage keys =
            WalletKeyManager.getState().walletKeys[_walletId];
        WalletKeyManager.KeyDefinition storage keyDefinition = keys.keyDefinitions[_keyId];
        require(keyDefinition.publicKey.length > 0, InvalidKeyId());
        address[] storage teeIds = keyDefinition.teeIds;
        for (uint256 i = teeIds.length; i > 0; i--) {
            if (MachineManager.getTeeMachineStatus(teeIds[i - 1]) !=
                IMachineManager.TeeStatus.PRODUCTION)
            {
                emit WalletKeyDeleted(teeIds[i - 1], _walletId, _keyId);
                teeIds[i - 1] = teeIds[teeIds.length - 1];
                teeIds.pop();
            }
        }
    }

    /**
     * @inheritdoc IWalletKeyManager
     */
    function receivingTeesAndKeys(
        bytes32 _walletId
    )
        external
        returns (TeeIdKeyIdPair[] memory _teeIdKeyIdPairs)
    {
        return WalletKeyManager.receivingTeesAndKeys(_walletId);
    }

    /**
     * @inheritdoc IWalletKeyManager
     */
    function getReceivingTeeIds(
        bytes32 _walletId
    )
        external view
        returns (address[] memory _teeIds)
    {
        return WalletKeyManager.getReceivingTeeIds(_walletId);
    }

    /**
     * @inheritdoc IWalletKeyManager
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
        return WalletKeyManager.getWalletKeysInfo(_walletId);
    }

    /**
     * @inheritdoc IWalletKeyManager
     */
    function getWalletKeyPublicKey(
        bytes32 _walletId,
        uint64 _keyId
    )
        external view
        returns (bytes memory _publicKey)
    {
        return WalletKeyManager.getWalletKeyPublicKey(_walletId, _keyId);
    }

    /**
     * @inheritdoc IWalletKeyManager
     */
    function getWalletPublicKeys(
        bytes32 _walletId
    )
        external view
        returns (
            uint64 _multisigThreshold,
            bytes[] memory _publicKeys
        )
    {
        return WalletKeyManager.getWalletPublicKeys(_walletId);
    }

    /**
     * @inheritdoc IWalletKeyManager
     */
    function getWalletKeyTeeIds(
        bytes32 _walletId,
        uint64 _keyId
    )
        external view
        returns (address[] memory _teeIds)
    {
        return WalletKeyManager.getWalletKeyTeeIds(_walletId, _keyId);
    }

    /**
     * @inheritdoc IWalletKeyManager
     */
    function getKeyNonce(
        address _teeId,
        bytes32 _walletId,
        uint64 _keyId
    )
        external view
        returns (
            uint256 _nonce,
            bool _teeHoldsKey
        )
    {
        WalletKeyManager.KeyDefinition storage keyDefinition =
            WalletKeyManager.getState().walletKeys[_walletId].keyDefinitions[_keyId];
        require(keyDefinition.publicKey.length > 0, InvalidKeyId());
        bytes32 projectId = WalletManager.getWalletProjectId(_walletId);
        require(
            MachineManager.getExtensionId(_teeId) == WalletProjectManager.getExtensionId(projectId),
            ExtensionIdMismatch()
        );
        _nonce = keyDefinition.nonces[_teeId];
        address[] storage teeIds = keyDefinition.teeIds;
        for (uint256 i = 0; i < teeIds.length; i++) {
            if (teeIds[i] == _teeId) {
                _teeHoldsKey = true;
                break;
            }
        }
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
        Instructions.sendInstructions(
            bytes32(0),
            teeIds,
            IInstructions.TeeInstructionParams(
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
            WalletManager.getWalletAdminsPublicKeysAndThreshold(_walletId);
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
            WalletManager.getWalletCosignersAndThreshold(_walletId);
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
        bytes32 projectId = WalletManager.getWalletProjectId(_walletId);
        require(WalletProjectManager.getOwner(projectId) == msg.sender, OnlyOwner());
    }

    function _checkOnlyOwnerOrBackupManager(
        bytes32 _walletId
    )
        private view
    {
        bytes32 projectId = WalletManager.getWalletProjectId(_walletId);
        WalletProjectManager.checkOnlyOwnerOrBackupManager(projectId);
    }

    function _checkWalletStatus(
        bytes32 _walletId
    )
        private view
    {
        require(
            WalletManager.getWalletStatus(_walletId) == IWalletManager.WalletStatus.INITIALIZED,
            InvalidWalletStatus()
        );
    }
}
