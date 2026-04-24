// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IExtensionManager } from "../../userInterfaces/tee/IExtensionManager.sol";

/**
 * @title IIExtensionManager
 * @notice Internal interface for the ExtensionManagerFacet.
 * @dev Extends the public interface with governance-only methods.
 */
interface IIExtensionManager is IExtensionManager {

    /**
     * Add system supported platforms.
     * Emits SystemSupportedPlatformsAdded event.
     * @param _platforms List of platforms to add.
     * @dev Only governance can call this method.
     */
    function addSystemSupportedPlatforms(
        bytes32[] calldata _platforms
    )
        external;

    /**
     * Add system supported key types and signing algorithms.
     * Emits SystemSupportedKeyTypesAndSigningAlgosAdded event.
     * @param _keyTypes List of key types to add.
     * @param _signingAlgosByKeyType List of signing algorithms for each key type.
     * @dev Only governance can call this method.
     */
    function addSystemSupportedKeyTypesAndSigningAlgos(
        bytes32[] calldata _keyTypes,
        bytes32[][] calldata _signingAlgosByKeyType
    )
        external;

}
