// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * TeeGovernance interface.
 */
interface ITeeGovernance {

    /**
     * Returns the governance hash of the latest TEE governance.
     */
    function latestTeeGovernanceHash() external view returns(bytes32);

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
