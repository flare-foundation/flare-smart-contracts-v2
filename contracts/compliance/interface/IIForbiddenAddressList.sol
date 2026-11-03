// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IForbiddenAddressList } from "../../userInterfaces/IForbiddenAddressList.sol";

/**
 * Internal forbidden address list interface: the governance-only methods. Removing an address releases value and
 * adding a maintainer grants a power, so both are timelocked; removing a maintainer is immediate, as every revocation
 * is.
 */
interface IIForbiddenAddressList is IForbiddenAddressList {

    /**
     * Removes addresses from a source's list; an address not on it is skipped. The last entry takes a removed one's
     * place. Raises the source's version if any address was removed. Emits ForbiddenAddressRemoved for each, and
     * ListVersionChanged once if any was removed.
     * @param _sourceId The source.
     * @param _addresses The addresses, as they were added.
     * Can only be called by governance (with timelock in production mode).
     */
    function removeForbiddenAddresses(
        bytes32 _sourceId,
        string[] calldata _addresses
    )
        external;

    /**
     * Removes addresses from the EVM list; an address not on it is skipped. The last entry takes a removed one's
     * place. Raises the EVM list's version if any address was removed. Emits ForbiddenEvmAddressRemoved for each, and
     * EvmListVersionChanged once if any was removed.
     * @param _addresses The addresses.
     * Can only be called by governance (with timelock in production mode).
     */
    function removeForbiddenEvmAddresses(
        address[] calldata _addresses
    )
        external;

    /**
     * Sets the source's personal account provider: from now on, every address newly added under the source has its
     * Personal Account listed on the EVM list too. Zero clears it. Both are timelocked: a provider decides which EVM
     * addresses are frozen, and clearing it lets an owner's Personal Account go unlisted. Emits
     * PersonalAccountProviderSet.
     * @param _sourceId The source (`UnsupportedSourceId` unless the list holds one under it).
     * @param _provider The provider, a contract (`PersonalAccountProviderWithoutCode`), or zero.
     * Can only be called by governance (with timelock in production mode).
     */
    function setPersonalAccountProvider(
        bytes32 _sourceId,
        address _provider
    )
        external;

    /**
     * Adds maintainers; an address already one is skipped. Reverts `MaintainerZero` for the zero address. Emits
     * MaintainersAdded.
     * @param _maintainers The maintainers, typically compliance multisigs.
     * Can only be called by governance (with timelock in production mode).
     */
    function addMaintainers(
        address[] calldata _maintainers
    )
        external;

    /**
     * Removes maintainers at once; an address that is not one is skipped. Emits MaintainersRemoved.
     * @param _maintainers The maintainers to remove.
     * Can only be called by governance (without timelock).
     */
    function removeMaintainers(
        address[] calldata _maintainers
    )
        external;
}
