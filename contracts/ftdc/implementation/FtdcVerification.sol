// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "../../utils/implementation/AddressUpdatable.sol";
import "../../userInterfaces/tee/ITeeMachineRegistry.sol";
import "../../userInterfaces/IRelay.sol";
import "../../userInterfaces/ftdc/IFtdcVerification.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * FtdcVerification contract.
 *
 * This contract is used to verify FTDC attestations.
 */
contract FtdcVerification is IFtdcVerification, AddressUpdatable {

    /// The TEE machine registry contract.
    ITeeMachineRegistry public teeMachineRegistry;
    /// The Relay contract.
    IRelay public relay;

    /**
     * Constructor.
     * @param _addressUpdater The address of the AddressUpdater contract.
     */
    constructor(address _addressUpdater) AddressUpdatable(_addressUpdater) {
        // empty constructor
    }

    /**
     * @inheritdoc IFtdcVerification
     */
    function verifySigningPolicySignatures(
        bytes calldata _signingPolicySignatures,
        bytes32 _messageHash
    )
        external returns (uint256 _rewardEpochId)
    {
        return relay.verifyCustomSignature(_signingPolicySignatures, _messageHash);
    }

    /**
     * @inheritdoc IFtdcVerification
     */
    function verifyTeeSignature(
        Signature calldata _signature,
        bytes32 _messageHash
    )
        external view returns (address _signingTeeId)
    {
        _signingTeeId = ECDSA.recover(
            MessageHashUtils.toEthSignedMessageHash(_messageHash),
            _signature.v,
            _signature.r,
            _signature.s
        );
        require(
            teeMachineRegistry.getTeeMachineStatus(_signingTeeId) == ITeeMachineRegistry.TeeStatus.PRODUCTION,
            TeeMachineNotAvailable()
        );
    }

    /**
     * @inheritdoc IFtdcVerification
     */
    function verifyTeeSignatures(
        Signature[] calldata _signatures,
        bytes32 _messageHash
    )
        external view returns(address[] memory _signingTeeIds)
    {
        _signingTeeIds = new address[](_signatures.length);
        for (uint256 i = 0; i < _signatures.length; i++) {
            Signature calldata signature = _signatures[i];
            address teeId = ECDSA.recover(
                MessageHashUtils.toEthSignedMessageHash(_messageHash),
                signature.v,
                signature.r,
                signature.s
            );
            require(
                teeMachineRegistry.getTeeMachineStatus(teeId) == ITeeMachineRegistry.TeeStatus.PRODUCTION,
                TeeMachineNotAvailable()
            );
            for (uint256 j = 0; j < i; j++) {
                require(_signingTeeIds[j] != teeId, DuplicatedTeeId(teeId));
            }
            _signingTeeIds[i] = teeId;
        }
    }

    /**
     * @inheritdoc IFtdcVerification
     */
    function verifyCosignerSignatures(
        Signature[] calldata _signatures,
        bytes32 _messageHash
    )
        external pure returns(address[] memory _cosigners)
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
        teeMachineRegistry = ITeeMachineRegistry(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeMachineRegistry"));
        relay = IRelay(_getContractAddress(_contractNameHashes, _contractAddresses, "Relay"));
    }
}
