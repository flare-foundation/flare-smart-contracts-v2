// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../userInterfaces/IFtsoFeedPublisher.sol";

contract FlareSystemMock {

    struct Policy {
        bytes32 pk1;
        bytes32 pk2;
        uint16 weight;
    }

    uint256 public randomSeed;
    uint256 public epochLen;

    mapping(uint256 => mapping(address => Policy)) public policies;
    mapping(uint256 => uint16) public totalWeights;

    constructor(uint256 _randomSeed, uint256 _epochLen) {
        randomSeed = _randomSeed;
        epochLen = _epochLen;
    }

    // Combines the functionality of VoterRegistry.registerVoter and EntityManager.registerPublicKey
    // from flare-smart-contracts-v2
    function registerAsVoter(uint256 _epoch, address _sender, Policy calldata _policy) external {
        require(_policy.weight != 0, "Weight must be nonzero");
        policies[_epoch][_sender] = _policy;
        totalWeights[_epoch] += _policy.weight;
    }

    function getSeed(uint256 /*_rewardEpochId*/) external view returns (uint256 _currentRandom) {
        return uint256(sha256(abi.encodePacked(block.number / epochLen, randomSeed)));
    }

    function getCurrentRewardEpochId() external view returns (uint24 _currentRewardEpochId) {
        return uint24(block.number / epochLen);
    }

    function getPublicKeyAndNormalisedWeight(
        uint256 _rewardEpochId,
        address _signingPolicyAddress
    )
        external view
        returns (
            bytes32 _publicKeyPart1,
            bytes32 _publicKeyPart2,
            uint16 _normalisedWeight,
            uint16 _normalisedWeightsSumOfVotersWithPublicKeys
        )
     {
        Policy storage policy = policies[_rewardEpochId][_signingPolicyAddress];
        _publicKeyPart1 = policy.pk1;
        _publicKeyPart2 = policy.pk2;

        _normalisedWeight = policy.weight;
        _normalisedWeightsSumOfVotersWithPublicKeys = totalWeights[_rewardEpochId];
    }

    function getCurrentFeed(bytes21 /*_feedId*/) external pure returns (IFtsoFeedPublisher.Feed memory _feed) {
        _feed = IFtsoFeedPublisher.Feed(0, 0, 100000, 10000, 2);
    }
}
