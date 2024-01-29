// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "flare-smart-contracts/contracts/staking/interface/IIPChainStakeMirrorVerifier.sol";
import "flare-smart-contracts/contracts/userInterfaces/IPChainStakeMirrorMultiSigVoting.sol";
import "../userInterfaces/IRelay.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * Contract used for P-chain staking verification using stake data and Merkle proof.
 */
contract PChainStakeMirrorVerifier is IIPChainStakeMirrorVerifier {
    using MerkleProof for bytes32[];

    uint256 public constant P_CHAIN_STAKE_MIRROR_PROTOCOL_ID = 1;

    /// Relay contract with voted Merkle roots.
    IRelay public immutable relay;
    /// P-chain stake mirror voting contract with voted Merkle roots.
    IPChainStakeMirrorMultiSigVoting public immutable pChainStakeMirrorVoting;

    /// Minimum stake duration in seconds.
    uint256 public immutable minStakeDurationSeconds;
    /// Maximum stake duration in seconds.
    uint256 public immutable maxStakeDurationSeconds;
    /// Minimum stake amount in Gwei.
    uint256 public immutable minStakeAmountGwei;
    /// Maximum stake amount in Gwei.
    uint256 public immutable maxStakeAmountGwei;

    /**
     * Initializes the contract with default parameters
     * @param _pChainStakeMirrorVoting PChainStakeMirrorVoting contract address.
     * @param _minStakeDurationSeconds Minimum stake duration in seconds.
     * @param _maxStakeDurationSeconds Maximum stake duration in seconds.
     * @param _minStakeAmountGwei Minimum stake amount in Gwei.
     * @param _maxStakeAmountGwei Maximum stake amount in Gwei.
     */
    constructor(
        IPChainStakeMirrorMultiSigVoting _pChainStakeMirrorVoting,
        IRelay _relay,
        uint256 _minStakeDurationSeconds,
        uint256 _maxStakeDurationSeconds,
        uint256 _minStakeAmountGwei,
        uint256 _maxStakeAmountGwei
    ) {
        require(_minStakeDurationSeconds <= _maxStakeDurationSeconds, "durations invalid");
        require(_minStakeAmountGwei <= _maxStakeAmountGwei, "amounts invalid");
        pChainStakeMirrorVoting = _pChainStakeMirrorVoting;
        relay = _relay;
        minStakeDurationSeconds = _minStakeDurationSeconds;
        maxStakeDurationSeconds = _maxStakeDurationSeconds;
        minStakeAmountGwei = _minStakeAmountGwei;
        maxStakeAmountGwei = _maxStakeAmountGwei;
    }

    /**
     * @inheritdoc IIPChainStakeMirrorVerifier
     */
    function verifyStake(
        PChainStake calldata _stakeData,
        bytes32[] calldata _merkleProof
    )
        external view
        returns (bool)
    {
        if (_stakeData.endTime < _stakeData.startTime) {
            return false;
        }
        uint256 stakeDuration = _stakeData.endTime - _stakeData.startTime;

        return stakeDuration >= minStakeDurationSeconds &&
            stakeDuration <= maxStakeDurationSeconds &&
            _stakeData.weight >= minStakeAmountGwei &&
            _stakeData.weight <= maxStakeAmountGwei &&
            _verifyMerkleProof(
                _merkleProof,
                _merkleRootForStartTime(_stakeData.startTime),
                _hashPChainStaking(_stakeData)
            );
    }

    /**
     * Gets the Merkle root for the given start time.
     * @param _startTime The start time.
     * @return _merkleRoot The Merkle root.
     */
    function _merkleRootForStartTime(uint256 _startTime) internal view returns(bytes32 _merkleRoot) {
        _merkleRoot = relay.merkleRoots(P_CHAIN_STAKE_MIRROR_PROTOCOL_ID, relay.getVotingRoundId(_startTime));
        if (_merkleRoot == bytes32(0)) {
            _merkleRoot = pChainStakeMirrorVoting.getMerkleRoot(pChainStakeMirrorVoting.getEpochId(_startTime));
        }
    }

    /**
     * Hashes the PChainStake data.
     * @param _data The PChainStake data.
     * @return _hash The hash.
     */
    function _hashPChainStaking(PChainStake calldata _data) internal pure returns (bytes32) {
        return keccak256(abi.encode(_data));
    }

    /**
     * Verifies the Merkle proof.
     * @param _proof The Merkle proof.
     * @param _merkleRoot The Merkle root.
     * @param _leaf The leaf.
     * @return True if the proof is valid.
     */
    function _verifyMerkleProof(
        bytes32[] memory _proof,
        bytes32 _merkleRoot,
        bytes32 _leaf
    )
        internal pure
        returns (bool)
    {
        return _proof.verify(_merkleRoot, _leaf);
    }

}
