// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import {
    IIAddressUpdatable
} from "@flarenetwork/flare-periphery-contracts/flare/addressUpdater/interfaces/IIAddressUpdatable.sol";
import { ITeeAddressUpdatableFacet } from
    "../../userInterfaces/tee/ITeeAddressUpdatableFacet.sol";

/**
 * @title IITeeAddressUpdatableFacet
 * @notice Internal interface for the TeeAddressUpdatableFacet.
 * @dev Combines the public getter interface with the
 *      AddressUpdater-callable `updateContractAddresses`.
 */
interface IITeeAddressUpdatableFacet is
    ITeeAddressUpdatableFacet,
    IIAddressUpdatable
{}
