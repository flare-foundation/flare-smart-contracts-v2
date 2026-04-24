// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IWalletManager } from "../../userInterfaces/tee/IWalletManager.sol";
import { PublicKey } from "../../userInterfaces/IPublicKey.sol";
import { PublicKeyUtils } from "../../utils/lib/PublicKeyUtils.sol";
import { WalletManager } from "../library/WalletManager.sol";
import { WalletProjectManager } from "../library/WalletProjectManager.sol";
import { WalletKeyManager } from "../library/WalletKeyManager.sol";

/**
 * @title WalletManagerFacet
 * @notice Facet for TEE wallet lifecycle management.
 */
contract WalletManagerFacet is IWalletManager {

    modifier onlyOwner(bytes32 _walletId) {
        _checkOnlyOwner(_walletId);
        _;
    }

    /**
     * @inheritdoc IWalletManager
     */
    function createWallet(
        bytes32 _projectId
    )
        external
        returns (bytes32 _walletId)
    {
        require(WalletProjectManager.getOwner(_projectId) == msg.sender, OnlyOwner());
        WalletManager.State storage s = WalletManager.getState();
        _walletId = keccak256(abi.encode("WALLET", msg.sender, ++s.walletCounter));
        WalletManager.TeeWalletState storage wallet = s.wallets[_walletId];
        assert(wallet.projectId == bytes32(0)); // should never revert
        s.projectWallets[_projectId].push(_walletId);
        wallet.projectId = _projectId;
        wallet.status = WalletStatus.CREATED;
        emit WalletCreated(_projectId, _walletId);
    }

    /**
     * @inheritdoc IWalletManager
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
        WalletManager.TeeWalletState storage wallet = WalletManager.getState().wallets[_walletId];
        WalletManager.checkWalletStatus(wallet.status, WalletStatus.CREATED);
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
     * @inheritdoc IWalletManager
     */
    function confirmAdmin(
        bytes32 _walletId
    )
        external
    {
        WalletManager.TeeWalletState storage wallet = WalletManager.getState().wallets[_walletId];
        WalletManager.checkWalletStatus(wallet.status, WalletStatus.CREATED);
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
     * @inheritdoc IWalletManager
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
        WalletManager.TeeWalletState storage wallet = WalletManager.getState().wallets[_walletId];
        WalletManager.checkWalletStatus(wallet.status, WalletStatus.CREATED);
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
     * @inheritdoc IWalletManager
     */
    function confirmCosigner(
        bytes32 _walletId
    )
        external
    {
        WalletManager.TeeWalletState storage wallet = WalletManager.getState().wallets[_walletId];
        WalletManager.checkWalletStatus(wallet.status, WalletStatus.CREATED);
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
     * @inheritdoc IWalletManager
     */
    function closeWalletInitialization(
        bytes32 _walletId
    )
        external
        onlyOwner(_walletId)
    {
        WalletManager.TeeWalletState storage wallet = WalletManager.getState().wallets[_walletId];
        WalletManager.checkWalletStatus(wallet.status, WalletStatus.CREATED);
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
     * @inheritdoc IWalletManager
     */
    function enableWallet(
        bytes32 _walletId
    )
        external
        onlyOwner(_walletId)
    {
        WalletManager.TeeWalletState storage wallet = WalletManager.getState().wallets[_walletId];
        WalletStatus status = wallet.status;
        require(status == WalletStatus.INITIALIZED || status == WalletStatus.PAUSED, InvalidWalletStatus());
        if (status == WalletStatus.INITIALIZED) {
            (uint64 multisigThreshold, uint64[] memory keyIds, ) =
                WalletKeyManager.getWalletKeysInfo(_walletId);
            require(multisigThreshold > 0, MultisigThresholdNotSet());
            require(keyIds.length >= multisigThreshold, NotEnoughKeys());
        }
        wallet.status = WalletStatus.PRODUCTION;
        emit WalletEnabled(_walletId);
    }

    /**
     * @inheritdoc IWalletManager
     */
    function pauseWallet(
        bytes32 _walletId
    )
        external
        onlyOwner(_walletId)
    {
        WalletManager.TeeWalletState storage wallet = WalletManager.getState().wallets[_walletId];
        WalletManager.checkWalletStatus(wallet.status, WalletStatus.PRODUCTION);
        wallet.status = WalletStatus.PAUSED;
        emit WalletPaused(_walletId);
    }

    /**
     * @inheritdoc IWalletManager
     */
    function getProjectWalletIds(
        bytes32 _projectId
    )
        external view
        returns (bytes32[] memory _walletIds)
    {
        return WalletManager.getState().projectWallets[_projectId];
    }

    /**
     * @inheritdoc IWalletManager
     */
    function getWalletProjectId(
        bytes32 _walletId
    )
        external view
        returns (bytes32 _projectId)
    {
        return WalletManager.getWalletProjectId(_walletId);
    }

    /**
     * @inheritdoc IWalletManager
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
        return WalletManager.getWalletAdminsPublicKeysAndThreshold(_walletId);
    }

    /**
     * @inheritdoc IWalletManager
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
        return WalletManager.getWalletAdminsAndThreshold(_walletId);
    }

    /**
     * @inheritdoc IWalletManager
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
        return WalletManager.getWalletCosignersAndThreshold(_walletId);
    }

    /**
     * @inheritdoc IWalletManager
     */
    function getWalletStatus(
        bytes32 _walletId
    )
        external view
        returns (WalletStatus _status)
    {
        return WalletManager.getWalletStatus(_walletId);
    }

    function _checkOnlyOwner(
        bytes32 _walletId
    )
        private view
    {
        address owner = WalletProjectManager.getOwner(
            WalletManager.getWalletProjectId(_walletId)
        );
        require(owner == msg.sender, OnlyOwner());
    }
}
