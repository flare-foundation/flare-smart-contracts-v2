// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../ISignature.sol";

/**
 * TeeGovernance interface.
 */
interface ITeeGovernance {

    event NewTeeGovernanceSet(
        uint256 indexed extensionId,
        bytes32 indexed governanceHash,
        address[] signers,
        uint64 signersThreshold
    );

    event NewPausingAddressesSet(
        uint256 indexed extensionId,
        uint256 indexed nonce,
        address[] pausingAddresses
    );

    event NewPausingAddressesSigned(
        uint256 indexed extensionId,
        uint256 indexed nonce,
        address indexed signer,
        Signature signature
    );

    /**
     * Signs pausing addresses.
     * @param _extensionId The id of the extension.
     * @param _nonce The nonce of the pausing addresses.
     * @param _signature The signature of the TEE pausing addresses list.
     */
    function signTeePausingAddresses(
        uint256 _extensionId,
        uint256 _nonce,
        Signature calldata _signature
    )
        external;

    /**
     * Returns the governance hash of the latest TEE governance.
     * @param _extensionId The id of the extension.
     */
    function getLatestTeeGovernanceHash(
        uint256 _extensionId
    )
        external view
        returns(bytes32);

    /**
     * Returns the TEE governance threshold for the given governance hash.
     * @param _extensionId The id of the extension.
     * @param _governanceHash The governance hash.
     * @return The TEE governance threshold.
     */
    function getTeeGovernanceThreshold(
        uint256 _extensionId,
        bytes32 _governanceHash
    )
        external view
        returns (uint64);

    /**
     * Returns true if the given address is a TEE governance signer for the given governance hash.
     * @param _extensionId The id of the extension.
     * @param _governanceHash The governance hash.
     * @param _signer The address to check.
     * @return True if the address is a TEE governance signer, false otherwise.
     */
    function isTeeGovernanceSigner(
        uint256 _extensionId,
        bytes32 _governanceHash,
        address _signer
    )
        external view
        returns (bool);

    /**
     * Returns the governance for the given governance hash.
     * @param _extensionId The id of the extension.
     * @param _governanceHash The governance hash.
     * @return _signers The governance signers.
     * @return _signersThreshold The governance signers threshold.
     */
    function getTeeGovernance(
        uint256 _extensionId,
        bytes32 _governanceHash
    )
        external view
        returns(address[] memory _signers, uint64 _signersThreshold);

    /**
     * Returns the latest governance.
     * @param _extensionId The id of the extension.
     * @return _signers The latest governance signers.
     * @return _signersThreshold The latest governance signers threshold.
     */
    function getLatestTeeGovernance(
        uint256 _extensionId
    )
        external view
        returns(address[] memory _signers, uint64 _signersThreshold);

    /**
     * Checks if the governance hash is valid.
     * @param _extensionId The id of the extension.
     * @param _governanceHash The governance hash.
     * @return True if the governance hash is valid, false otherwise.
     */
    function isGovernanceHashValid(
        uint256 _extensionId,
        bytes32 _governanceHash
    )
        external view
        returns (bool);

    /**
     * Returns the TEE pausing addresses for the given nonce.
     * @param _extensionId The id of the extension.
     * @param _nonce The nonce.
     * @return _pausingAddresses The TEE pausing addresses.
     * @return _signatures The signatures of the TEE pausing addresses list signed by TEE governance signers.
     */
    function getTeePausingAddresses(
        uint256 _extensionId,
        uint256 _nonce
    )
        external view
        returns (address[] memory _pausingAddresses, Signature[] memory _signatures);

    /**
     * Returns the latest TEE pausing addresses.
     * @param _extensionId The id of the extension.
     * @return _nonce The nonce of the latest TEE pausing addresses.
     * @return _pausingAddresses The latest TEE pausing addresses.
     * @return _signatures The signatures of the latest TEE pausing addresses list signed by TEE governance signers.
     */
    function getLatestTeePausingAddresses(
        uint256 _extensionId
    )
        external view
        returns (uint256 _nonce, address[] memory _pausingAddresses, Signature[] memory _signatures);

    /**
     * Checks if the given address is a TEE pausing addresses signer.
     * @param _extensionId The id of the extension.
     * @param _signer The address to check.
     * @return True if the address is a TEE pausing addresses signer, false otherwise.
     */
    function isTeePausingAddressesSigner(
        uint256 _extensionId,
        address _signer
    )
        external view
        returns (bool);

    /**
     * Checks if the given address has signed a TEE pausing addresses for the given nonce.
     * @param _extensionId The id of the extension.
     * @param _nonce The nonce.
     * @param _signer The address to check.
     * @return True if the address has signed a TEE pausing addresses for the given nonce, false otherwise.
     */
    function hasSignedTeePausingAddresses(
        uint256 _extensionId,
        uint256 _nonce,
        address _signer
    )
        external view
        returns (bool);
}
