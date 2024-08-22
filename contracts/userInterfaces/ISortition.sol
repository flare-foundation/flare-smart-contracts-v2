// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import {G1Point} from "./IBn256.sol";

struct SortitionCredential {
  uint256 replicate;
  G1Point gamma;
  uint256 c;
  uint256 s;
}
