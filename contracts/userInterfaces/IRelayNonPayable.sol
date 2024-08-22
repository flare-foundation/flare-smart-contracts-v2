// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * Relay interface.
 */
interface IRelayNonPayable {

    /**
     * Returns true if there is finalization for a given protocol id and voting round id.
     * @param _protocolId The protocol id.
     * @param _votingRoundId The voting round id.
     */
    function isFinalized(uint256 _protocolId, uint256 _votingRoundId) external view returns (bool);

    /**
     * Verifies the leaf (or intermediate node) with the Merkle proof against the Merkle root
     * for given protocol id and voting round id.
     */
    function verify(uint256 _protocolId, uint256 _votingRoundId, bytes32 _leaf, bytes32[] calldata _proof)
        external view
        returns (bool);

    /**
     * Returns the current random number, its timestamp and the flag indicating if it is secure.
     * @return _randomNumber The current random number.
     * @return _isSecureRandom The flag indicating if the random number is secure.
     * @return _randomTimestamp The timestamp of the random number.
     */
    function getRandomNumber()
        external view
        returns (
            uint256 _randomNumber,
            bool _isSecureRandom,
            uint256 _randomTimestamp
        );

    /**
     * Returns the voting round id for given timestamp.
     * @param _timestamp The timestamp.
     * @return _votingRoundId The voting round id.
     */
    function getVotingRoundId(uint256 _timestamp) external view returns (uint256 _votingRoundId);

}
