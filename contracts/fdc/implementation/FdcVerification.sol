// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./FdcVerificationBase.sol";
import "../../userInterfaces/fdc/IAddressValidityVerification.sol";
import "../../userInterfaces/fdc/IBalanceDecreasingTransactionVerification.sol";
import "../../userInterfaces/fdc/IConfirmedBlockHeightExistsVerification.sol";
import "../../userInterfaces/fdc/IEVMTransactionVerification.sol";
import "../../userInterfaces/fdc/IPaymentVerification.sol";
import "../../userInterfaces/fdc/IReferencedPaymentNonexistenceVerification.sol";

contract FdcVerification is FdcVerificationBase,
    IAddressValidityVerification,
    IBalanceDecreasingTransactionVerification,
    IConfirmedBlockHeightExistsVerification,
    IEVMTransactionVerification,
    IPaymentVerification,
    IReferencedPaymentNonexistenceVerification
{
    using MerkleProof for bytes32[];

    /**
     * Constructor.
     * @param _addressUpdater The address of the AddressUpdater contract.
     * @param _fdcProtocolId The FDC protocol id.
     */
    constructor(address _addressUpdater, uint8 _fdcProtocolId) FdcVerificationBase(_addressUpdater, _fdcProtocolId) {}

    /**
     * @inheritdoc IAddressValidityVerification
     */
    function verifyAddressValidity(IAddressValidity.Proof calldata _proof)
        external view returns (bool _proved)
    {
        bytes32 merkleRoot = relay.merkleRoots(fdcProtocolId, _proof.data.votingRound);
        return
            _proof.data.attestationType == bytes32("AddressValidity") &&
            _proof.merkleProof.verifyCalldata(merkleRoot, keccak256(abi.encode(_proof.data)));
    }

    /**
     * @inheritdoc IBalanceDecreasingTransactionVerification
     */
    function verifyBalanceDecreasingTransaction(IBalanceDecreasingTransaction.Proof calldata _proof)
        external view returns (bool _proved)
    {
        bytes32 merkleRoot = relay.merkleRoots(fdcProtocolId, _proof.data.votingRound);
        return
            _proof.data.attestationType == bytes32("BalanceDecreasingTransaction") &&
            _proof.merkleProof.verifyCalldata(merkleRoot, keccak256(abi.encode(_proof.data)));
    }

    /**
     * @inheritdoc IConfirmedBlockHeightExistsVerification
     */
    function verifyConfirmedBlockHeightExists(IConfirmedBlockHeightExists.Proof calldata _proof)
        external view returns (bool _proved)
    {
        bytes32 merkleRoot = relay.merkleRoots(fdcProtocolId, _proof.data.votingRound);
        return
            _proof.data.attestationType == bytes32("ConfirmedBlockHeightExists") &&
            _proof.merkleProof.verifyCalldata(merkleRoot, keccak256(abi.encode(_proof.data)));
   }

    /**
     * @inheritdoc IEVMTransactionVerification
     */
    function verifyEVMTransaction(IEVMTransaction.Proof calldata _proof)
        external view returns (bool _proved)
    {
        bytes32 merkleRoot = relay.merkleRoots(fdcProtocolId, _proof.data.votingRound);
        return
            _proof.data.attestationType == bytes32("EVMTransaction") &&
            _proof.merkleProof.verifyCalldata(merkleRoot, keccak256(abi.encode(_proof.data)));
    }

    /**
     * @inheritdoc IPaymentVerification
     */
    function verifyPayment(IPayment.Proof calldata _proof)
        external view returns (bool _proved)
    {
        bytes32 merkleRoot = relay.merkleRoots(fdcProtocolId, _proof.data.votingRound);
        return
            _proof.data.attestationType == bytes32("Payment") &&
            _proof.merkleProof.verifyCalldata(merkleRoot, keccak256(abi.encode(_proof.data)));
    }

    /**
     * @inheritdoc IReferencedPaymentNonexistenceVerification
     */
    function verifyReferencedPaymentNonexistence(IReferencedPaymentNonexistence.Proof calldata _proof)
        external view returns (bool _proved)
    {
        bytes32 merkleRoot = relay.merkleRoots(fdcProtocolId, _proof.data.votingRound);
        return
            _proof.data.attestationType == bytes32("ReferencedPaymentNonexistence") &&
            _proof.merkleProof.verifyCalldata(merkleRoot, keccak256(abi.encode(_proof.data)));
    }
}
