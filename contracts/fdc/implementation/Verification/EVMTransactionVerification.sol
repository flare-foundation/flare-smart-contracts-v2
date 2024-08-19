// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../interface/types/EVMTransaction.sol";
import "../../interface/external/IMerkleRootStorage.sol";
import "./interface/IEVMTransactionVerification.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract EVMTransactionVerification is IEVMTransactionVerification {
   using MerkleProof for bytes32[];

   IMerkleRootStorage public immutable merkleRootStorage;

   constructor(IMerkleRootStorage _merkleRootStorage) {
      merkleRootStorage = _merkleRootStorage;
   }

   function verifyEVMTransaction(
      EVMTransaction.Proof calldata _proof
   ) external view returns (bool _proved) {
      return _proof.data.attestationType == bytes32("EVMTransaction") &&
         _proof.merkleProof.verify(
            merkleRootStorage.merkleRoot(_proof.data.votingRound),
            keccak256(abi.encode(_proof.data))
         );
   }
}
   