// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { TeeBase } from "./TeeBase.sol";
import { IITeeExtensionRegistry } from "../interface/IITeeExtensionRegistry.sol";
import { ITeeVrf } from "../../userInterfaces/tee/ITeeVrf.sol";
import { ITeeMachineRegistry } from "../../userInterfaces/tee/ITeeMachineRegistry.sol";
import { ITeeWalletKeyManager } from "../../userInterfaces/tee/ITeeWalletKeyManager.sol";
import { ITeeWalletManager } from "../../userInterfaces/tee/ITeeWalletManager.sol";
import { ITeeWalletProjectManager } from "../../userInterfaces/tee/ITeeWalletProjectManager.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

/**
 * TeeVrf is a contract used for instructing TEE machines to generate a VRF proof
 * for a given wallet key and nonce.
 */
contract TeeVrf is ITeeVrf, TeeBase {

    bytes32 public constant WALLET_OP_TYPE = bytes32("F_WALLET");
    bytes32 public constant VRF = bytes32("VRF");

    /// TeeExtensionRegistry contract.
    IITeeExtensionRegistry public teeExtensionRegistry;
    /// TeeMachineRegistry contract.
    ITeeMachineRegistry public teeMachineRegistry;
    /// TeeWalletProjectManager contract.
    ITeeWalletProjectManager public teeWalletProjectManager;
    /// TeeWalletManager contract.
    ITeeWalletManager public teeWalletManager;
    /// TeeWalletKeyManager contract.
    ITeeWalletKeyManager public teeWalletKeyManager;

    /// Mapping of wallet ID to the address authorized to request VRF for the wallet.
    mapping(bytes32 walletId => address) private vrfAuthorizationAddresses;

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
        require(vrfAuthorizationAddresses[_walletId] == msg.sender, OnlyAuthorizationAddress());
        require(
            teeWalletManager.getWalletStatus(_walletId) == ITeeWalletManager.WalletStatus.PRODUCTION,
            WalletNotInProduction()
        );
        address[] memory teeIds = teeWalletKeyManager.getWalletKeyTeeIds(_walletId, _keyId);
        // remove all tee ids that are not in production status
        uint256 productionTeeCount = 0;
        for (uint256 i = 0; i < teeIds.length; i++) {
            if (teeMachineRegistry.getTeeMachineStatus(teeIds[i]) == ITeeMachineRegistry.TeeStatus.PRODUCTION) {
                teeIds[productionTeeCount] = teeIds[i];
                productionTeeCount++;
            }
        }
        require(productionTeeCount > 0, NoTeesForKey());

        // resize the array to the new length which is <= original length - that is always safe
        // this is done using inline assembly as Solidity does not provide a way to resize memory arrays
        // solhint-disable-next-line no-inline-assembly
        assembly { mstore(teeIds, productionTeeCount) }

        VrfInstructionMessage memory message = VrfInstructionMessage({
            walletId: _walletId,
            keyId: _keyId,
            nonce: _nonce
        });
        _instructionId = teeExtensionRegistry.sendInstructions{value: msg.value}(
            teeIds,
            WALLET_OP_TYPE,
            VRF,
            abi.encode(message),
            new address[](0),
            0
        );
        emit VrfRequested(_walletId, _keyId, _instructionId);
    }

    /**
     * @inheritdoc ITeeVrf
     */
    function setVrfAuthorizationAddress(
        bytes32 _walletId,
        address _authorizationAddress
    )
        external
    {
        bytes32 projectId = teeWalletManager.getWalletProjectId(_walletId);
        require(teeWalletProjectManager.getOwner(projectId) == msg.sender, OnlyWalletOwner());
        vrfAuthorizationAddresses[_walletId] = _authorizationAddress;
        emit VrfAuthorizationAddressSet(_walletId, _authorizationAddress);
    }

    /**
     * @inheritdoc ITeeVrf
     */
    function getVrfAuthorizationAddress(bytes32 _walletId) external view returns (address) {
        return vrfAuthorizationAddresses[_walletId];
    }

    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal virtual override
    {
        teeExtensionRegistry = IITeeExtensionRegistry(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeExtensionRegistry"));
        teeMachineRegistry = ITeeMachineRegistry(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeMachineRegistry"));
        teeWalletProjectManager = ITeeWalletProjectManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeWalletProjectManager"));
        teeWalletManager = ITeeWalletManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeWalletManager"));
        teeWalletKeyManager = ITeeWalletKeyManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeWalletKeyManager"));
    }
}
