// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../ISignature.sol";

/**
 * TeeGovernance interface.
 */
interface ITeeGovernance {

    event NewTeeGovernanceSet(
        bytes32 indexed governanceHash,
        address[] signers,
        uint64 signersThreshold
    );

    event NewPauseAddressesSet(
        uint256 indexed nonce,
        address[] pauseAddresses
    );

    event NewPauseAddressesSigned(
        uint256 indexed nonce,
        address indexed signer,
        Signature signature
    );

    /**
     * Signs pause addresses.
     * @param _nonce The nonce of the pause addresses.
     * @param _signature The signature of the TEE pause addresses list.
     */
    function signTeePauseAddresses(
        uint256 _nonce,
        Signature calldata _signature
    )
        external;

    /**
     * Returns the governance hash of the latest TEE governance.
     */
    function latestTeeGovernanceHash() external view returns(bytes32);

    /**
     * Returns the TEE governance threshold for the given governance hash.
     * @param _governanceHash The governance hash.
     * @return The TEE governance threshold.
     */
    function getTeeGovernanceThreshold(
        bytes32 _governanceHash
    )
        external view
        returns (uint64);

    /**
     * Returns true if the given address is a TEE governance signer for the given governance hash.
     * @param _governanceHash The governance hash.
     * @param _signer The address to check.
     * @return True if the address is a TEE governance signer, false otherwise.
     */
    function isTeeGovernanceSigner(
        bytes32 _governanceHash,
        address _signer
    )
        external view
        returns (bool);

    /**
     * Returns the governance for the given governance hash.
     * @param _governanceHash The governance hash.
     * @return _signers The governance signers.
     * @return _signersThreshold The governance signers threshold.
     */
    function getTeeGovernance(bytes32 _governanceHash)
        external view
        returns(address[] memory _signers, uint64 _signersThreshold);

    /**
     * Returns the latest governance.
     * @return _signers The latest governance signers.
     * @return _signersThreshold The latest governance signers threshold.
     */
    function getLatestTeeGovernance()
        external view
        returns(address[] memory _signers, uint64 _signersThreshold);

    /**
     * Checks if the governance hash is valid.
     * @param _governanceHash The governance hash.
     * @return True if the governance hash is valid, false otherwise.
     */
    function isGovernanceHashValid(
        bytes32 _governanceHash
    )
        external view
        returns (bool);

    /**
     * Returns the TEE pause addresses for the given nonce.
     * @param _nonce The nonce.
     * @return _pauseAddresses The TEE pause addresses.
     * @return _signatures The signatures of the TEE pause addresses list signed by TEE governance signers.
     */
    function getTeePauseAddresses(
        uint256 _nonce
    )
        external view
        returns (address[] memory _pauseAddresses, Signature[] memory _signatures);

    /**
     * Returns the latest TEE pause addresses.
     * @return _nonce The nonce of the latest TEE pause addresses.
     * @return _pauseAddresses The latest TEE pause addresses.
     * @return _signatures The signatures of the latest TEE pause addresses list signed by TEE governance signers.
     */
    function getLatestTeePauseAddresses()
        external view
        returns (uint256 _nonce, address[] memory _pauseAddresses, Signature[] memory _signatures);

    /**
     * Checks if the given address is a TEE pause addresses signer.
     * @param _signer The address to check.
     * @return True if the address is a TEE pause addresses signer, false otherwise.
     */
    function isTeePauseAddressesSigner(
        address _signer
    )
        external view
        returns (bool);

    /**
     * Checks if the given address has signed a TEE pause addresses for the given nonce.
     * @param _nonce The nonce.
     * @param _signer The address to check.
     * @return True if the address has signed a TEE pause addresses for the given nonce, false otherwise.
     */
    function hasSignedTeePauseAddresses(
        uint256 _nonce,
        address _signer
    )
        external view
        returns (bool);
}
