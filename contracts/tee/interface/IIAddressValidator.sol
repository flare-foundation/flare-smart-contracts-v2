// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { IAddressValidator } from "../../userInterfaces/tee/IAddressValidator.sol";

/**
 * IIAddressValidator internal interface.
 *
 * Extends the public {IAddressValidator} with the Flare-governance-only configuration surface.
 */
interface IIAddressValidator is IAddressValidator {

    /**
     * Sets (or overwrites) the validation profiles for a batch of sources. Governance only.
     * @param _configs The source configurations to set; must be non-empty.
     */
    function setSourceConfigs(
        SourceConfig[] calldata _configs
    )
        external;
}
