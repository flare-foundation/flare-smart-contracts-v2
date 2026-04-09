// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ITeeWalletManagerFacet, WALLET_OP_TYPE } from "../../userInterfaces/tee/ITeeWalletManagerFacet.sol";
import { ITeeExtensionRegistryFacet } from "../../userInterfaces/tee/ITeeExtensionRegistryFacet.sol";
import { PublicKey } from "../../userInterfaces/IPublicKey.sol";
import { TeeIdKeyIdPair } from "../../userInterfaces/tee/ITeeIdKeyIdPair.sol";
import { PublicKeyUtils } from "../../utils/lib/PublicKeyUtils.sol";
import { TeeWalletManager } from "../library/TeeWalletManager.sol";
import { TeeWalletProjectManager } from "../library/TeeWalletProjectManager.sol";
import { TeeWalletKeyManager } from "../library/TeeWalletKeyManager.sol";
import { TeeMachineRegistry } from "../library/TeeMachineRegistry.sol";
import { TeeInstructionSender } from "../library/TeeInstructionSender.sol";

/**
 * @title TeeWalletManagerFacet
 * @notice Facet for TEE wallet lifecycle management.
 */
contract TeeWalletManagerFacet is ITeeWalletManagerFacet {

    bytes32 public constant SET_PAUSING_ADDRESSES = bytes32("SET_PAUSING_ADDRESSES");
    bytes32 public constant RESUME = bytes32("RESUME");

    modifier onlyOwner(bytes32 _walletId) {
        _checkOnlyOwner(_walletId);
        _;
    }

    /**
     * @inheritdoc ITeeWalletManagerFacet
     */
    function createWallet(
        bytes32 _projectId
    )
        external
        returns (bytes32 _walletId)
    {
        require(TeeWalletProjectManager.getOwner(_projectId) == msg.sender, OnlyOwner());
        TeeWalletManager.State storage s = TeeWalletManager.getState();
        _walletId = keccak256(abi.encode("WALLET", msg.sender, ++s.walletCounter));
        TeeWalletManager.TeeWalletState storage wallet = s.wallets[_walletId];
        assert(wallet.projectId == bytes32(0)); // should never revert
        s.projectWallets[_projectId].push(_walletId);
        wallet.projectId = _projectId;
        wallet.status = WalletStatus.CREATED;
        emit WalletCreated(_projectId, _walletId);
    }

    /**
     * @inheritdoc ITeeWalletManagerFacet
     */
    function setAdmins(
        bytes32 _walletId,
        PublicKey[] calldata _adminsPublicKeys,
        uint64 _adminsThreshold
    )
        external
        onlyOwner(_walletId)
    {
        require(_adminsPublicKeys.length >= _adminsThreshold, NotEnoughAdmins());
        require(_adminsThreshold > 0, InvalidAdminsThreshold());
        for (uint256 i = 0; i < _adminsPublicKeys.length; i++) {
            PublicKey calldata pk = _adminsPublicKeys[i];
            require(PublicKeyUtils.isPublicKeyValid(pk), InvalidAdminPublicKey(pk));
            for (uint256 j = 0; j < i; j++) {
                require(
                    _adminsPublicKeys[j].x != pk.x || _adminsPublicKeys[j].y != pk.y,
                    DuplicatedPublicKey(pk)
                );
            }
        }
        TeeWalletManager.TeeWalletState storage wallet = TeeWalletManager.getState().wallets[_walletId];
        TeeWalletManager.checkWalletStatus(wallet.status, WalletStatus.CREATED);
        while (wallet.adminsPublicKeys.length > 0) {
            wallet.adminsPublicKeys.pop();
        }
        for (uint256 i = 0; i < _adminsPublicKeys.length; i++) {
            wallet.adminsPublicKeys.push(_adminsPublicKeys[i]);
        }
        wallet.adminsThreshold = _adminsThreshold;
        emit WalletAdminsSet(_walletId, _adminsPublicKeys, _adminsThreshold);
    }

    /**
     * @inheritdoc ITeeWalletManagerFacet
     */
    function confirmAdmin(
        bytes32 _walletId
    )
        external
    {
        TeeWalletManager.TeeWalletState storage wallet = TeeWalletManager.getState().wallets[_walletId];
        TeeWalletManager.checkWalletStatus(wallet.status, WalletStatus.CREATED);
        for (uint256 i = 0; i < wallet.adminsPublicKeys.length; i++) {
            address adminAddress = PublicKeyUtils.getAddress(wallet.adminsPublicKeys[i]);
            if (adminAddress == msg.sender) {
                wallet.adminConfirmations[msg.sender] = true;
                emit WalletAdminConfirmed(_walletId, msg.sender);
                return;
            }
        }
        revert InvalidAdmin();
    }

    /**
     * @inheritdoc ITeeWalletManagerFacet
     */
    function setCosigners(
        bytes32 _walletId,
        address[] calldata _cosigners,
        uint64 _cosignersThreshold
    )
        external
        onlyOwner(_walletId)
    {
        require(
            _cosigners.length >= _cosignersThreshold && (_cosigners.length == 0 || _cosignersThreshold > 0),
            InvalidCosignersThreshold()
        );
        TeeWalletManager.TeeWalletState storage wallet = TeeWalletManager.getState().wallets[_walletId];
        TeeWalletManager.checkWalletStatus(wallet.status, WalletStatus.CREATED);
        for (uint256 i = 0; i < _cosigners.length; i++) {
            require(_cosigners[i] != address(0), InvalidCosigner(_cosigners[i]));
            for (uint256 j = 0; j < i; j++) {
                require(_cosigners[j] != _cosigners[i], DuplicatedCosigner(_cosigners[i]));
            }
        }
        wallet.cosigners = _cosigners;
        wallet.cosignersThreshold = _cosignersThreshold;
        emit WalletCosignersSet(_walletId, _cosigners, _cosignersThreshold);
    }

    /**
     * @inheritdoc ITeeWalletManagerFacet
     */
    function confirmCosigner(
        bytes32 _walletId
    )
        external
    {
        TeeWalletManager.TeeWalletState storage wallet = TeeWalletManager.getState().wallets[_walletId];
        TeeWalletManager.checkWalletStatus(wallet.status, WalletStatus.CREATED);
        for (uint256 i = 0; i < wallet.cosigners.length; i++) {
            if (wallet.cosigners[i] == msg.sender) {
                wallet.cosignerConfirmations[msg.sender] = true;
                emit WalletCosignerConfirmed(_walletId, msg.sender);
                return;
            }
        }
        revert InvalidCosigner(msg.sender);
    }

    /**
     * @inheritdoc ITeeWalletManagerFacet
     */
    function closeWalletInitialization(
        bytes32 _walletId
    )
        external
        onlyOwner(_walletId)
    {
        TeeWalletManager.TeeWalletState storage wallet = TeeWalletManager.getState().wallets[_walletId];
        TeeWalletManager.checkWalletStatus(wallet.status, WalletStatus.CREATED);
        require(wallet.adminsPublicKeys.length > 0, AdminsNotSet());
        for (uint256 i = 0; i < wallet.adminsPublicKeys.length; i++) {
            address adminAddress = PublicKeyUtils.getAddress(wallet.adminsPublicKeys[i]);
            require(wallet.adminConfirmations[adminAddress], NotAllAdminsConfirmed(adminAddress));
        }
        for (uint256 i = 0; i < wallet.cosigners.length; i++) {
            require(
                wallet.cosignerConfirmations[wallet.cosigners[i]],
                NotAllCosignersConfirmed(wallet.cosigners[i])
            );
        }
        wallet.status = WalletStatus.INITIALIZED;
        emit WalletInitialized(_walletId);
    }

    /**
     * @inheritdoc ITeeWalletManagerFacet
     */
    function enableWallet(
        bytes32 _walletId
    )
        external
        onlyOwner(_walletId)
    {
        TeeWalletManager.TeeWalletState storage wallet = TeeWalletManager.getState().wallets[_walletId];
        WalletStatus status = wallet.status;
        require(status == WalletStatus.INITIALIZED || status == WalletStatus.PAUSED, InvalidWalletStatus());
        if (status == WalletStatus.INITIALIZED) {
            (uint64 multisigThreshold, uint64[] memory keyIds, ) =
                TeeWalletKeyManager.getWalletKeysInfo(_walletId);
            require(multisigThreshold > 0, MultisigThresholdNotSet());
            require(keyIds.length >= multisigThreshold, NotEnoughKeys());
        }
        wallet.status = WalletStatus.PRODUCTION;
        emit WalletEnabled(_walletId);
    }

    /**
     * @inheritdoc ITeeWalletManagerFacet
     */
    function pauseWallet(
        bytes32 _walletId
    )
        external
        onlyOwner(_walletId)
    {
        TeeWalletManager.TeeWalletState storage wallet = TeeWalletManager.getState().wallets[_walletId];
        TeeWalletManager.checkWalletStatus(wallet.status, WalletStatus.PRODUCTION);
        wallet.status = WalletStatus.PAUSED;
        emit WalletPaused(_walletId);
    }

    /**
     * @inheritdoc ITeeWalletManagerFacet
     */
    function setPausingAddresses(
        bytes32 _walletId,
        address[] calldata _pausingAddresses,
        address _claimBackAddress
    )
        external payable
        onlyOwner(_walletId)
    {
        WalletStatus walletStatus = TeeWalletManager.getWalletStatus(_walletId);
        require(
            walletStatus == WalletStatus.PRODUCTION || walletStatus == WalletStatus.PAUSED,
            OnlyProductionOrPausedStatus()
        );
        TeeIdKeyIdPair[] memory teeIdKeyIdPairs = TeeWalletKeyManager.receivingTeesAndKeys(_walletId);

        TeeWalletManager.State storage s = TeeWalletManager.getState();
        SetPausingAddresses memory message = SetPausingAddresses({
            walletId: _walletId,
            nonce: s.setPausingAddressesNonce[_walletId]++,
            teeIdKeyIdPairs: teeIdKeyIdPairs,
            pausingAddresses: _pausingAddresses
        });
        (address[] memory admins, uint64 adminsThreshold) =
            TeeWalletManager.getWalletAdminsAndThreshold(_walletId);

        TeeInstructionSender.sendInstructions(
            bytes32(0),
            _toTeeIds(teeIdKeyIdPairs),
            ITeeExtensionRegistryFacet.TeeInstructionParams(
                WALLET_OP_TYPE,
                SET_PAUSING_ADDRESSES,
                abi.encode(message),
                admins,
                adminsThreshold,
                _claimBackAddress
            )
        );
    }

    /**
     * @inheritdoc ITeeWalletManagerFacet
     */
    function resume(
        bytes32 _walletId,
        ResumeKeyData[] calldata _keysData,
        address _claimBackAddress
    )
        external payable
        onlyOwner(_walletId)
    {
        WalletStatus walletStatus = TeeWalletManager.getWalletStatus(_walletId);
        require(
            walletStatus == WalletStatus.PRODUCTION || walletStatus == WalletStatus.PAUSED,
            OnlyProductionOrPausedStatus()
        );

        uint256 numOfKeys = _keysData.length;
        address[] memory teeIds = new address[](numOfKeys);
        (, uint64[] memory keyIds, ) = TeeWalletKeyManager.getWalletKeysInfo(_walletId);
        for (uint256 i = 0; i < numOfKeys; i++) {
            bool found = false;
            for (uint256 j = 0; j < keyIds.length; j++) {
                if (keyIds[j] == _keysData[i].keyId) {
                    found = true;
                    break;
                }
            }
            require(found, WrongKeyId());
            TeeMachineRegistry.checkTeeMachineInProduction(_keysData[i].teeId);
            teeIds[i] = _keysData[i].teeId;
        }

        Resume memory message = Resume({
            walletId: _walletId,
            keysData: _keysData
        });
        TeeInstructionSender.sendInstructions(
            bytes32(0),
            teeIds,
            ITeeExtensionRegistryFacet.TeeInstructionParams(
                WALLET_OP_TYPE,
                RESUME,
                abi.encode(message),
                new address[](0),
                0,
                _claimBackAddress
            )
        );
    }

    /**
     * @inheritdoc ITeeWalletManagerFacet
     */
    function getProjectWalletIds(
        bytes32 _projectId
    )
        external view
        returns (bytes32[] memory _walletIds)
    {
        return TeeWalletManager.getState().projectWallets[_projectId];
    }

    /**
     * @inheritdoc ITeeWalletManagerFacet
     */
    function getWalletProjectId(
        bytes32 _walletId
    )
        external view
        returns (bytes32 _projectId)
    {
        return TeeWalletManager.getWalletProjectId(_walletId);
    }

    /**
     * @inheritdoc ITeeWalletManagerFacet
     */
    function getWalletAdminsPublicKeysAndThreshold(
        bytes32 _walletId
    )
        external view
        returns (
            PublicKey[] memory _adminsPublicKeys,
            uint64 _adminsThreshold
        )
    {
        return TeeWalletManager.getWalletAdminsPublicKeysAndThreshold(_walletId);
    }

    /**
     * @inheritdoc ITeeWalletManagerFacet
     */
    function getWalletAdminsAndThreshold(
        bytes32 _walletId
    )
        external view
        returns (
            address[] memory _admins,
            uint64 _adminsThreshold
        )
    {
        return TeeWalletManager.getWalletAdminsAndThreshold(_walletId);
    }

    /**
     * @inheritdoc ITeeWalletManagerFacet
     */
    function getWalletCosignersAndThreshold(
        bytes32 _walletId
    )
        external view
        returns (
            address[] memory _cosigners,
            uint64 _cosignersThreshold
        )
    {
        return TeeWalletManager.getWalletCosignersAndThreshold(_walletId);
    }

    /**
     * @inheritdoc ITeeWalletManagerFacet
     */
    function getWalletStatus(
        bytes32 _walletId
    )
        external view
        returns (WalletStatus _status)
    {
        return TeeWalletManager.getWalletStatus(_walletId);
    }

    function _checkOnlyOwner(
        bytes32 _walletId
    )
        private view
    {
        address owner = TeeWalletProjectManager.getOwner(
            TeeWalletManager.getWalletProjectId(_walletId)
        );
        require(owner == msg.sender, OnlyOwner());
    }

    function _toTeeIds(
        TeeIdKeyIdPair[] memory _teeIdKeyIdPairs
    )
        private pure
        returns (address[] memory _teeIds)
    {
        _teeIds = new address[](_teeIdKeyIdPairs.length);
        for (uint256 i = 0; i < _teeIdKeyIdPairs.length; i++) {
            _teeIds[i] = _teeIdKeyIdPairs[i].teeId;
        }
    }
}
