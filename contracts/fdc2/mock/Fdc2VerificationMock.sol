// SPDX-License-Identifier: MIT
pragma solidity  ^0.8.27;

import {AddressUpdatable} from "../../utils/implementation/AddressUpdatable.sol";
import {ITeeMachineRegistryFacet} from "../../userInterfaces/tee/ITeeMachineRegistryFacet.sol";
import {IRelay} from "../../userInterfaces/IRelay.sol";
import {IFdc2Verification} from "../../userInterfaces/fdc2/IFdc2Verification.sol";
import {Signature} from "../../userInterfaces/ISignature.sol";
import {AddressSet} from "../../utils/lib/AddressSet.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * Fdc2Verification MOCK contract.
 *
 * This contract is used to verify FDC2 attestations.
 */
contract Fdc2VerificationMock is IFdc2Verification, AddressUpdatable {
    using AddressSet for AddressSet.State;

    /// The TEE machine registry contract.
    ITeeMachineRegistryFacet public teeMachineRegistry;
    /// The Relay contract.
    IRelay public relay;

    bool private returnActiveTeeIds = true;
    AddressSet.State private signingTeeIds;

    /**
     * Constructor.
     * @param _addressUpdater The address of the AddressUpdater contract.
     */
    constructor(
        address _addressUpdater
    )
        AddressUpdatable(_addressUpdater)
    {
        // empty constructor
    }

    // Mock function for testing purposes only.
    function setSigningTeeIds(
        address[] calldata _signingTeeIds
    )
        external
    {
        returnActiveTeeIds = false;
        signingTeeIds.replaceAll(_signingTeeIds);
    }

    /**
     * @inheritdoc IFdc2Verification
     */
    function verifySigningPolicySignatures(
        bytes calldata /*_relayMessage*/,
        bytes32 /*_messageHash*/
    )
        external view
        returns (uint256 _rewardEpochId)
    {
        // no verification
        // always return the latest reward epoch id
        (_rewardEpochId, ) = relay.lastInitializedRewardEpochData();
    }

    /**
     * @inheritdoc IFdc2Verification
     */
    function verifyTeeSignature(
        Signature calldata /*_signature*/,
        bytes32 /*_messageHash*/
    )
        external view
        returns (address _signingTeeId)
    {
        address[] memory teeIds;
        // no verification
        if (returnActiveTeeIds) {
            (teeIds,) = teeMachineRegistry.getActiveTeeMachines(0);
        } else {
            teeIds = signingTeeIds.list;
        }
        if (teeIds.length > 0) {
            _signingTeeId = teeIds[0];
        }
    }

    /**
     * @inheritdoc IFdc2Verification
     */
    function verifyTeeSignatures(
        Signature[] calldata /*_signatures*/,
        bytes32 /*_messageHash*/
    )
        external view
        returns (address[] memory _signingTeeIds)
    {
        // no verification
        if (returnActiveTeeIds) {
            (_signingTeeIds,) = teeMachineRegistry.getActiveTeeMachines(0);
        } else {
            _signingTeeIds = signingTeeIds.list;
        }
    }

    /**
     * @inheritdoc IFdc2Verification
     */
    function verifyCosignerSignatures(
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
        teeMachineRegistry = ITeeMachineRegistryFacet(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeMachineRegistry"));
        relay = IRelay(_getContractAddress(_contractNameHashes, _contractAddresses, "Relay"));
    }
}
