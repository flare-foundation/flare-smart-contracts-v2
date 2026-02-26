// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { TeeBase } from "./TeeBase.sol";
import { IITeeExtensionRegistry } from "../interface/IITeeExtensionRegistry.sol";
import { ITeeVrf } from "../../userInterfaces/tee/ITeeVrf.sol";
import { ITeeWalletKeyManager } from "../../userInterfaces/tee/ITeeWalletKeyManager.sol";
import { ITeeWalletManager } from "../../userInterfaces/tee/ITeeWalletManager.sol";
import { ITeeWalletProjectManager } from "../../userInterfaces/tee/ITeeWalletProjectManager.sol";
import { IGovernanceSettings } from "flare-smart-contracts/contracts/userInterfaces/IGovernanceSettings.sol";

/**
 * TeeVrf is a contract used for instructing TEE machines to generate a VRF proof
 * for a given wallet key and nonce.
 */
contract TeeVrf is ITeeVrf, TeeBase {

    bytes32 public constant VRF = bytes32("VRF");
    bytes32 internal constant F_WALLET = bytes32("F_WALLET");

    /// TeeExtensionRegistry contract.
    IITeeExtensionRegistry public teeExtensionRegistry;
    /// TeeWalletKeyManager contract.
    ITeeWalletKeyManager public teeWalletKeyManager;
    /// TeeWalletManager contract.
    ITeeWalletManager public teeWalletManager;
    /// TeeWalletProjectManager contract.
    ITeeWalletProjectManager public teeWalletProjectManager;

    /**
     * Constructor that initializes with invalid parameters to prevent direct deployment/updates.
     */
    constructor() TeeBase() {}

    /**
     * Proxyable initialization method. Can be called only once, from the proxy constructor
     * (single call is assured by GovernedBase.initialise).
     */
    function initialize(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater
    )
        external virtual
    {
        TeeBase.initializeBase(_governanceSettings, _initialGovernance, _addressUpdater);
    }

    /**
     * @inheritdoc ITeeVrf
     */
    function requestVrf(
        bytes32 _walletId,
        uint64 _keyId,
        bytes calldata _nonce
    )
        external payable
        returns (bytes32 _instructionId)
    {
        require(_nonce.length > 0, NonceEmpty());
        bytes32 projectId = teeWalletManager.getWalletProjectId(_walletId);
        require(teeWalletProjectManager.getOwner(projectId) == msg.sender, OnlyWalletOwner());
        require(
            teeWalletManager.getWalletStatus(_walletId) == ITeeWalletManager.WalletStatus.PRODUCTION,
            WalletNotInProduction()
        );
        address[] memory teeIds = teeWalletKeyManager.getWalletKeyTeeIds(_walletId, _keyId);
        require(teeIds.length > 0, NoTeesForKey());
        VrfInstructionMessage memory message = VrfInstructionMessage({
            walletId: _walletId,
            keyId: _keyId,
            nonce: _nonce
        });
        _instructionId = teeExtensionRegistry.sendSystemInstructions{value: msg.value}(
            bytes32(0),
            teeIds,
            F_WALLET,
            VRF,
            abi.encode(message),
            new address[](0),
            0
        );
        emit VrfRequested(_walletId, _keyId, _instructionId);
    }

    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal virtual override
    {
        teeExtensionRegistry = IITeeExtensionRegistry(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeExtensionRegistry"));
        teeWalletKeyManager = ITeeWalletKeyManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeWalletKeyManager"));
        teeWalletManager = ITeeWalletManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeWalletManager"));
        teeWalletProjectManager = ITeeWalletProjectManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeWalletProjectManager"));
    }
}
