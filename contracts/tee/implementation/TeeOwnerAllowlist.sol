// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../governance/implementation/Governed.sol";
import "../../userInterfaces/tee/ITeeOwnerAllowlist.sol";
import "../../utils/lib/AddressSet.sol";

/**
 * TeeOwnerAllowlist is used for allowlisting TEE machine owners and TEE wallet project owners.
 */
contract TeeOwnerAllowlist is ITeeOwnerAllowlist, Governed {
    using AddressSet for AddressSet.State;

    AddressSet.State private allowedTeeMachineOwners;
    AddressSet.State private allowedTeeWalletProjectOwners;

    bool public allTeeMachineOwnersAllowed = false;
    bool public allTeeWalletProjectOwnersAllowed = false;

    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance
    )
        Governed(_governanceSettings, _initialGovernance)
    {
        // do nothing
    }

    /**
     * Adds a list of allowed TEE machine owners.
     * @param _owners The list of addresses to add to the allowlist.
     * @dev Only governance can call this method.
     */
    function addAllowedTeeMachineOwners(
        address[] memory _owners
    )
        external onlyGovernance
    {
        allowedTeeMachineOwners.addAll(_owners);
        emit AllowedTeeMachineOwnersAdded(_owners);
    }

    /**
     * Adds a list of allowed TEE wallet project owners.
     * @param _owners The list of addresses to add to the allowlist.
     * @dev Only governance can call this method.
     */
    function addAllowedTeeWalletProjectOwners(
        address[] memory _owners
    )
        external onlyGovernance
    {
        allowedTeeWalletProjectOwners.addAll(_owners);
        emit AllowedTeeWalletProjectOwnersAdded(_owners);
    }

    /**
     * Allows all addresses to be TEE machine owners.
     * @dev Only governance can call this method.
     */
    function allowAllTeeMachineOwners()
        external onlyGovernance
    {
        allTeeMachineOwnersAllowed = true;
        emit AllTeeMachineOwnersAllowed();
    }

    /**
     * Allows all addresses to be TEE wallet project owners.
     * @dev Only governance can call this method.
     */
    function allowAllTeeWalletProjectOwners()
        external onlyGovernance
    {
        allTeeWalletProjectOwnersAllowed = true;
        emit AllTeeWalletProjectOwnersAllowed();
    }

    /**
     * @inheritdoc ITeeOwnerAllowlist
     */
    function isAllowedTeeMachineOwner(
        address _owner
    )
        external view
        returns (bool _isAllowed)
    {
        return allTeeMachineOwnersAllowed || allowedTeeMachineOwners.index[_owner] != 0;
    }

    /**
     * @inheritdoc ITeeOwnerAllowlist
     */
    function isAllowedTeeWalletProjectOwner(
        address _owner
    )
        external view
        returns (bool _isAllowed)
    {
        return allTeeWalletProjectOwnersAllowed || allowedTeeWalletProjectOwners.index[_owner] != 0;
    }
}
