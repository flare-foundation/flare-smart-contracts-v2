// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * @title ISafeMinimal
 * @notice Minimal read-only view of a Safe (Gnosis Safe) multisig contract, used to snapshot its
 *         owner set and confirmation threshold when registering a Safe-backed TEE governance and
 *         to check snapshot satisfiability when the Safe approves a machine path list.
 * @dev External-protocol interface; matches Safe >= 1.3.0 `OwnerManager`.
 */
interface ISafeMinimal {

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
