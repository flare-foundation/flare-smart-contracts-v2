// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { IMachinePathManager } from "../../userInterfaces/tee/IMachinePathManager.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title SafeTransactionVerifier
 * @notice Stateless helpers for verifying Safe (Gnosis Safe) owner signatures on-chain: EIP-712
 *         SafeTxHash reconstruction for the fixed transaction shape the protocol accepts (a plain
 *         single contract call with zero value and zero gas-refund fields), and parsing of the
 *         Safe's packed 65-byte signature encoding.
 * @dev Matches Safe >= 1.3.0 (the first version whose domain separator binds `chainId`); the
 *      compatibility is enforced at governance registration by comparing the Safe's live
 *      `domainSeparator()` against `domainSeparator(address)` below. Everything here is pure
 *      computation over caller-supplied data — no live Safe state is read, which is the point:
 *      verification binds to the owner snapshot frozen in the governance hash, not to whatever
 *      the Safe's configuration is at verification time.
 */
library SafeTransactionVerifier {

    /// keccak256("EIP712Domain(uint256 chainId,address verifyingContract)") — Safe >= 1.3.0.
    bytes32 internal constant DOMAIN_SEPARATOR_TYPEHASH =
        keccak256("EIP712Domain(uint256 chainId,address verifyingContract)");

    /// The Safe transaction EIP-712 type hash (unchanged since Safe 1.0.0).
    bytes32 internal constant SAFE_TX_TYPEHASH = keccak256(
        "SafeTx(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,"
        "uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 nonce)"
    );

    /**
     * Returns the EIP-712 domain separator of `_safe` on this chain per the Safe >= 1.3.0 formula.
     */
    function domainSeparator(
        address _safe
    )
        internal view
        returns (bytes32)
    {
        return keccak256(abi.encode(DOMAIN_SEPARATOR_TYPEHASH, block.chainid, _safe));
    }

    /**
     * Reconstructs the EIP-712 SafeTxHash the owners of `_safe` signed for a plain single
     * contract call: `operation == CALL` and `value` / `safeTxGas` / `baseGas` / `gasPrice` /
     * `gasToken` / `refundReceiver` all zero — the only transaction shape the protocol accepts
     * (see `IMachinePathManager.approveMachinePathList`). A Safe transaction proposed with any
     * other shape yields a different hash and fails signature recovery (fail-closed).
     */
    function callSafeTxHash(
        address _safe,
        address _to,
        bytes memory _data,
        uint256 _safeNonce
    )
        internal view
        returns (bytes32)
    {
        bytes32 safeTxHash = keccak256(abi.encode(
            SAFE_TX_TYPEHASH,
            _to,
            uint256(0),         // value
            keccak256(_data),
            uint8(0),           // operation: CALL
            uint256(0),         // safeTxGas
            uint256(0),         // baseGas
            uint256(0),         // gasPrice
            address(0),         // gasToken
            address(0),         // refundReceiver
            _safeNonce
        ));
        return keccak256(abi.encodePacked(bytes1(0x19), bytes1(0x01), domainSeparator(_safe), safeTxHash));
    }

    /**
     * Parses the Safe's packed signature encoding (65-byte `{r,s,v}` chunks) and recovers one
     * signer per chunk: `v` in {27,28} recovers over `_safeTxHash` directly, `v` in {31,32}
     * (`eth_sign` flow) over its EIP-191-prefixed form with `v - 4`. Approved-hash (`v == 1`) and
     * contract-signature (`v == 0`) chunks revert `InvalidSignatureType` — they carry no ECDSA
     * signature to verify. Recovered signers must be strictly ascending (`UnorderedSignatures`),
     * the Safe's own `checkSignatures` ordering rule — a blob copied from an executed
     * `execTransaction` already satisfies it, and strictness guarantees uniqueness without a
     * seen-set. Any other malformed chunk fails inside `ECDSA.recover` (fail-closed; high-s
     * malleable chunks are rejected too — normalize off-chain if ever encountered).
     */
    function recoverOrderedSigners(
        bytes32 _safeTxHash,
        bytes calldata _signatures
    )
        internal pure
        returns (address[] memory _signers)
    {
        uint256 count = _signatures.length / 65;
        require(
            count > 0 && _signatures.length == count * 65,
            IMachinePathManager.InvalidSignaturesLength()
        );
        _signers = new address[](count);
        address last = address(0);
        for (uint256 i = 0; i < count; i++) {
            uint256 offset = i * 65;
            bytes32 r = bytes32(_signatures[offset:offset + 32]);
            bytes32 s = bytes32(_signatures[offset + 32:offset + 64]);
            uint8 v = uint8(_signatures[offset + 64]);
            require(v > 1, IMachinePathManager.InvalidSignatureType());
            address signer;
            if (v > 30) {
                signer = ECDSA.recover(MessageHashUtils.toEthSignedMessageHash(_safeTxHash), v - 4, r, s);
            } else {
                signer = ECDSA.recover(_safeTxHash, v, r, s);
            }
            require(signer > last, IMachinePathManager.UnorderedSignatures());
            last = signer;
            _signers[i] = signer;
        }
    }
}
