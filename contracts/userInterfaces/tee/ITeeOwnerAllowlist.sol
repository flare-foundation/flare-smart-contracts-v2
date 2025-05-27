// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * TeeOwnerAllowlist interface.
 */
interface ITeeOwnerAllowlist {

    event AllowedTeeMachineOwnersAdded(address[] owners);
    event AllowedTeeWalletProjectOwnersAdded(address[] owners);
    event AllTeeMachineOwnersAllowed();
    event AllTeeWalletProjectOwnersAllowed();

    /**
     * Returns true if all addresses are allowed to own a TEE machine.
     * @return _allAllowed True if all addresses are allowed, false otherwise.
     */
    function allTeeMachineOwnersAllowed()
        external view
        returns (bool _allAllowed);

    /**
     * Returns true if all addresses are allowed to own a TEE wallet project.
     * @return _allAllowed True if all addresses are allowed, false otherwise.
     */
    function allTeeWalletProjectOwnersAllowed()
        external view
        returns (bool _allAllowed);

    /**
     * Returns true if the owner is allowed to own a TEE machine.
     * @param _owner The address of the owner.
     * @return _isAllowed True if the owner is allowed, false otherwise.
     */
    function isAllowedTeeMachineOwner(
        address _owner
    )
        external view
        returns (bool _isAllowed);

    /**
     * Returns true if the owner is allowed to own a TEE wallet project.
     * @param _owner The address of the owner.
     * @return _isAllowed True if the owner is allowed, false otherwise.
     */
    function isAllowedTeeWalletProjectOwner(
        address _owner
    )
        external view
        returns (bool _isAllowed);

}