// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../FdcVerificationBase.sol";
import "../../../userInterfaces/fdc/IPaymentVerification.sol";

contract PaymentVerification is FdcVerificationBase, IPaymentVerification {
    using MerkleProof for bytes32[];

    /**
     * Constructor.
     * @param _addressUpdater The address of the AddressUpdater contract.
     * @param _fdcProtocolId The FDC protocol id.
     */
    constructor(address _addressUpdater, uint8 _fdcProtocolId) FdcVerificationBase(_addressUpdater, _fdcProtocolId) {}

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
}
