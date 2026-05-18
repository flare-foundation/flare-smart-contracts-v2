// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { FlareUpgradeableBase } from "../../governance/implementation/FlareUpgradeableBase.sol";
import { IFlareTeeManager } from "../../userInterfaces/tee/IFlareTeeManager.sol";
import { IMachineManager } from "../../userInterfaces/tee/IMachineManager.sol";
import { IRelay } from "../../userInterfaces/IRelay.sol";
import { IFdc2Verification } from "../../userInterfaces/fdc2/IFdc2Verification.sol";
import { Signature } from "../../userInterfaces/ISignature.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

/**
 * Fdc2Verification contract.
 *
 * This contract is used to verify FDC2 attestations.
 */
contract Fdc2Verification is IFdc2Verification, FlareUpgradeableBase {

    /// The FlareTeeManager Diamond contract.
    IFlareTeeManager public flareTeeManager;
    /// The Relay contract.
    IRelay public relay;

    /**
     * Constructor that initializes with invalid parameters to prevent direct deployment/updates.
     */
    constructor() FlareUpgradeableBase() {}

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
        FlareUpgradeableBase.initializeBase(_governanceSettings, _initialGovernance, _addressUpdater);
    }

    /**
     * @inheritdoc IFdc2Verification
     */
    function verifySigningPolicySignatures(
        bytes calldata _signingPolicySignatures,
        bytes32 _messageHash
    )
        external
        returns (uint256 _rewardEpochId)
    {
        return relay.verifyCustomSignature(_signingPolicySignatures, _messageHash);
    }

    /**
     * @inheritdoc IFdc2Verification
     */
    function verifyTeeSignature(
        Signature calldata _signature,
        bytes32 _messageHash
    )
        external view
        returns (address _signingTeeId)
    {
        _signingTeeId = _verifyTeeSignature(_signature, _messageHash);
    }

    /**
     * @inheritdoc IFdc2Verification
     */
    function verifyTeeSignatures(
        Signature[] calldata _signatures,
        bytes32 _messageHash
    )
        external view
        returns (address[] memory _signingTeeIds)
    {
        _signingTeeIds = new address[](_signatures.length);
        for (uint256 i = 0; i < _signatures.length; i++) {
            address teeId = _verifyTeeSignature(_signatures[i], _messageHash);
            for (uint256 j = 0; j < i; j++) {
                require(_signingTeeIds[j] != teeId, DuplicatedTeeId(teeId));
            }
            _signingTeeIds[i] = teeId;
        }
    }

    /**
     * @inheritdoc IFdc2Verification
     */
    function recoverCosigners(
        Signature[] calldata _signatures,
        bytes32 _messageHash
    )
        external pure
        returns (address[] memory _cosigners)
    {
        _cosigners = new address[](_signatures.length);
        for (uint256 i = 0; i < _signatures.length; i++) {
            Signature calldata signature = _signatures[i];
            address cosigner = ECDSA.recover(
                MessageHashUtils.toEthSignedMessageHash(_messageHash),
                signature.v,
                signature.r,
                signature.s
            );
            for (uint256 j = 0; j < i; j++) {
                require(_cosigners[j] != cosigner, DuplicatedCosigner(cosigner));
            }
            _cosigners[i] = cosigner;
        }
    }

    /**
     * Implementation of the AddressUpdatable abstract method.
     * @dev It can be overridden if other contracts are needed.
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal virtual override
    {
        flareTeeManager = IFlareTeeManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareTeeManager"));
        relay = IRelay(_getContractAddress(_contractNameHashes, _contractAddresses, "Relay"));
    }

    function _verifyTeeSignature(
        Signature calldata _signature,
        bytes32 _messageHash
    )
        internal view
        returns (address _signingTeeId)
    {
        _signingTeeId = ECDSA.recover(
            MessageHashUtils.toEthSignedMessageHash(_messageHash),
            _signature.v,
            _signature.r,
            _signature.s
        );
        require(
            flareTeeManager.getExtensionId(_signingTeeId) == 0,
            InvalidTeeMachineExtensionId()
        );
        require(
            flareTeeManager.getTeeMachineStatus(_signingTeeId) == IMachineManager.TeeStatus.PRODUCTION,
            TeeMachineNotAvailable()
        );
    }
}
