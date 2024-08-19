// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../interface/types/ConfirmedBlockHeightExists.sol";
import "../../interface/external/IMerkleRootStorage.sol";
import "./interface/IConfirmedBlockHeightExistsVerification.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract ConfirmedBlockHeightExistsVerification is IConfirmedBlockHeightExistsVerification {
   using MerkleProof for bytes32[];

   IMerkleRootStorage public immutable merkleRootStorage;

   constructor(IMerkleRootStorage _merkleRootStorage) {
      merkleRootStorage = _merkleRootStorage;
   }

   function verifyConfirmedBlockHeightExists(
      ConfirmedBlockHeightExists.Proof calldata _proof
   ) external view returns (bool _proved) {
      return _proof.data.attestationType == bytes32("ConfirmedBlockHeightExists") &&
         _proof.merkleProof.verify(
            merkleRootStorage.merkleRoot(_proof.data.votingRound),
            keccak256(abi.encode(_proof.data))
         );
   }
}
   