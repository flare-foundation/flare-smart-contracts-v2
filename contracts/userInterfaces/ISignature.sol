// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/// Signature structure
struct Signature {
    uint8 v;
    bytes32 r;
    bytes32 s;
}
