// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * TeeGovernance interface.
 */
interface ITeeGovernance {

    event NewTeeGovernanceSet(
        bytes32 indexed governanceHash,
        address[] signers,
        uint256 signersThreshold
    );

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
        returns (uint256);

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
        returns(address[] memory _signers, uint256 _signersThreshold);

    /**
     * Returns the latest governance.
     * @return _signers The latest governance signers.
     * @return _signersThreshold The latest governance signers threshold.
     */
    function getLatestTeeGovernance()
        external view
        returns(address[] memory _signers, uint256 _signersThreshold);

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
}
