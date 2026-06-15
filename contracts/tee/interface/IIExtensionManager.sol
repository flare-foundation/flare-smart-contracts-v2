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
     * Remove system supported platforms.
     * Removing a platform only blocks adding it to NEW TEE versions (via addTeeVersion);
     * existing versions keep their own platform set and are unaffected.
     * Emits SystemSupportedPlatformsRemoved event.
     * @param _platforms List of platforms to remove. Each must currently be system supported.
     * @dev Only governance can call this method.
     */
    function removeSystemSupportedPlatforms(
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

    /**
     * Remove system supported signing algorithms (and key types once their last algorithm is removed).
     * For each key type, the listed signing algorithms are removed; when a key type has no remaining
     * signing algorithms it is also removed from the system-supported key types.
     * Removing only blocks creating NEW projects (via createProject) with that key type / signing
     * algorithm combination; existing projects keep their stored signing algorithm and their backup,
     * restore and key operations are unaffected.
     * Emits SystemSupportedKeyTypesAndSigningAlgosRemoved event.
     * @param _keyTypes List of key types to remove signing algorithms from.
     * @param _signingAlgosByKeyType List of signing algorithms to remove for each key type.
     * @dev Only governance can call this method.
     */
    function removeSystemSupportedKeyTypesAndSigningAlgos(
        bytes32[] calldata _keyTypes,
        bytes32[][] calldata _signingAlgosByKeyType
    )
        external;

}
