// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../FdcVerificationBase.sol";
import "../../../userInterfaces/fdc/IEVMTransactionVerification.sol";

contract EVMTransactionVerification is FdcVerificationBase, IEVMTransactionVerification {
    using MerkleProof for bytes32[];

    /**
     * Constructor.
     * @param _addressUpdater The address of the AddressUpdater contract.
     * @param _fdcProtocolId The FDC protocol id.
     */
    constructor(address _addressUpdater, uint8 _fdcProtocolId) FdcVerificationBase(_addressUpdater, _fdcProtocolId) {}

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
}
