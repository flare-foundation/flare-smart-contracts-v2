// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Minimal, version-pinned Gnosis Safe transaction hashing helpers.
/// @dev The deployed GSS Safe version must be checked against these constants before use.
library GnosisSafeTx {
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        uint8 operation;
        uint256 safeTxGas;
        uint256 baseGas;
        uint256 gasPrice;
        address gasToken;
        address refundReceiver;
        uint256 nonce;
    }

    bytes32 internal constant DOMAIN_SEPARATOR_TYPEHASH = keccak256(
        "EIP712Domain(uint256 chainId,address verifyingContract)"
    );
    bytes32 internal constant SAFE_TX_TYPEHASH = keccak256(
        // solhint-disable-next-line max-line-length
        "SafeTx(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 nonce)"
    );

    function digest(
        Transaction memory txData,
        uint256 chainId,
        address safe
    ) internal pure returns (bytes32) {
        bytes32 domain = keccak256(abi.encode(
            DOMAIN_SEPARATOR_TYPEHASH,
            chainId,
            safe
        ));
        bytes32 structHash = keccak256(abi.encode(
            SAFE_TX_TYPEHASH,
            txData.to,
            txData.value,
            keccak256(txData.data),
            txData.operation,
            txData.safeTxGas,
            txData.baseGas,
            txData.gasPrice,
            txData.gasToken,
            txData.refundReceiver,
            txData.nonce
        ));
        return keccak256(abi.encodePacked("\x19\x01", domain, structHash));
    }
}
