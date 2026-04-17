// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import {
    IIAddressUpdatable
} from "@flarenetwork/flare-periphery-contracts/flare/addressUpdater/interfaces/IIAddressUpdatable.sol";
import { IExternalAddressesFacet } from
    "../../userInterfaces/tee/IExternalAddressesFacet.sol";

/**
 * @title IIExternalAddressesFacet
 * @notice Internal interface for the ExternalAddressesFacet.
 * @dev Combines the public getter interface with the
 *      AddressUpdater-callable `updateContractAddresses`.
 */
interface IIExternalAddressesFacet is
    IExternalAddressesFacet,
    IIAddressUpdatable
{}
