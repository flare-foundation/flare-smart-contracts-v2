// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;


interface IRewardManager {

    enum ClaimType { DIRECT, FEE, WNAT, MIRROR, CCHAIN }

    struct RewardClaimWithProof {
        bytes32[] merkleProof;
        RewardClaim body;
    }

    struct RewardClaim {
        uint24 rewardEpochId;
        bytes20 beneficiary; // c-chain address or node id (bytes20) in case of type MIRROR
        uint120 amount; // in wei
        ClaimType claimType;
    }
}
