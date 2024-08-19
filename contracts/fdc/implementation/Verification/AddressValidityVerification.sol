// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../../userInterfaces/fdc/IAddressValidityVerification.sol";

import "../IFdcVerificationBase.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract AddressValidityVerification is BaseVerification, IAddressValidityVerification {
  using MerkleProof for bytes32[];

  /**
   * Constructor.
   * @param _addressUpdater The address of the AddressUpdater contract.
   * @param _fdcProtocolId The FDC protocol id.
   */
  constructor(address _addressUpdater, uint8 _fdcProtocolId) BaseVerification(_addressUpdater, _fdcProtocolId) {}

  function verifyAddressValidity(IAddressValidity.Proof calldata _proof) external view returns (bool _proved) {
    bytes32 merkleRoot = relay.merkleRoots(fdcProtocolId, _proof.data.votingRound);
    return
      _proof.data.attestationType == bytes32("AddressValidity") &&
      _proof.merkleProof.verifyCalldata(merkleRoot, keccak256(abi.encode(_proof.data)));
  }
}
