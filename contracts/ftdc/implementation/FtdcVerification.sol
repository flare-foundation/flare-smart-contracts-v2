// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../utils/implementation/AddressUpdatable.sol";
import "../../userInterfaces/tee/ITeeRegistry.sol";
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

    /// The TEE registry contract.
    ITeeRegistry public teeRegistry;
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
        bytes calldata _relayMessage,
        bytes32 _messageHash
    )
        external returns (uint256 _rewardEpochId)
    {
        // 1 byte (protocolId=1), 4 bytes (votingRoundId=0), 1 byte (isSecureRandom=false), 32 bytes (messageHash)
        bytes memory customMessage = bytes.concat(bytes1(uint8(1)), bytes5(0), _messageHash);
        return relay.verifyCustomSignature(_relayMessage, keccak256(customMessage));
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
            require(teeRegistry.getTeeMachineStatus(teeId) == ITeeRegistry.TeeStatus.PRODUCTION, "TEE not active");
            for (uint256 j = 0; j < i; j++) {
                require(_signingTeeIds[j] != teeId, "duplicated TEE id");
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
                require(_cosigners[j] != cosigner, "duplicated cosigner");
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
        teeRegistry = ITeeRegistry(_getContractAddress(_contractNameHashes, _contractAddresses, "TeeRegistry"));
        relay = IRelay(_getContractAddress(_contractNameHashes, _contractAddresses, "Relay"));
    }
}
