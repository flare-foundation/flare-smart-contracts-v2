// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Canonical hashing shared by the Flare governance checker and target Relays.
library GSSGovernance {
    bytes32 internal constant OWNER_CONFIG_TYPEHASH = keccak256(
        "FlareRelayOwnerConfiguration(uint256 sourceChainId,address safe,"
        "uint256 safeNonce,uint256 threshold,address[] owners)"
    );

    function ownerConfigHash(
        uint256 sourceChainId,
        address safe,
        uint256 safeNonce,
        uint256 threshold,
        address[] memory owners
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, safeNonce, threshold, owners));
    }
}
