// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * @title ISafeMinimal
 * @notice Minimal read-only view of a Safe (Gnosis Safe) multisig contract: the owner set,
 *         the confirmation threshold, the transaction nonce and the EIP-712 domain separator.
 * @dev External-protocol interface; matches Safe >= 1.3.0 (`OwnerManager` + the transaction nonce).
 */
interface ISafeMinimal {

    /**
     * Returns the Safe transaction nonce. The Safe increments it inside `execTransaction` BEFORE
     * making the inner call, so read during a call executed by the Safe it returns the signed
     * nonce + 1.
     */
    function nonce()
        external view
        returns (uint256);

    /**
     * Returns the Safe's EIP-712 domain separator. For Safe >= 1.3.0 this is
     * `keccak256(abi.encode(keccak256("EIP712Domain(uint256 chainId,address verifyingContract)"),
     * block.chainid, safe))` — checked at Safe-backed governance registration so that a Safe whose
     * SafeTxHash the protocol cannot reconstruct (older version, or a different wallet altogether)
     * fails fast instead of producing unverifiable approvals later.
     */
    function domainSeparator()
        external view
        returns (bytes32);

    /**
     * Returns the list of Safe owners.
     */
    function getOwners()
        external view
        returns (address[] memory);

    /**
     * Returns the number of owner confirmations required for a Safe transaction.
     */
    function getThreshold()
        external view
        returns (uint256);

    /**
     * Returns true if `_owner` is currently a Safe owner.
     */
    function isOwner(
        address _owner
    )
        external view
        returns (bool);
}
