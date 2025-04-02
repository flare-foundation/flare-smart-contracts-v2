// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * TeeVersionManager interface.
 */
interface ITeeVersionManager {

    event CodeHashPlatformDisabled(bytes32 indexed codeHash, bytes32 platform);

    /**
     * Get the info if the code hash and platform pair is disabled.
     * @param _codeHash The code hash.
     * @param _platform The platform.
     */
    function codeHashPlatformDisabled(
        bytes32 _codeHash,
        bytes32 _platform
    )
        external view
        returns(bool);

    /**
     * Checks if the code hash and platform are supported.
     * @param _codeHash The code hash.
     * @param _platform The platform.
     * @return True if the code hash and platform are supported, false otherwise.
     */
    function isCodeHashPlatformSupported(
        bytes32 _codeHash,
        bytes32 _platform
    )
        external view
        returns(bool);
}
