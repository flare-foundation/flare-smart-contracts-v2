// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../utils/implementation/AddressUpdatable.sol";
import "../../userInterfaces/IRelay.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

abstract contract BaseVerification is AddressUpdatable {
  using MerkleProof for bytes32[];

  /// The Relay contract.
  IRelay public relay;
  /// The FDC protocol id.
  uint8 public immutable fdcProtocolId;

  /**
   * Constructor.
   * @param _addressUpdater The address of the AddressUpdater contract.
   * @param _fdcProtocolId The FDC protocol id.
   */
  constructor(address _addressUpdater, uint8 _fdcProtocolId) AddressUpdatable(_addressUpdater) {
    fdcProtocolId = _fdcProtocolId;
  }
}
