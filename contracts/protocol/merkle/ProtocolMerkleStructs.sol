// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../../userInterfaces/IRewardManager.sol";


interface ProtocolMerkleStructs {

    function rewardClaimStruct(IRewardManager.RewardClaim calldata _claim) external;

    function rewardClaimWithProofStruct(IRewardManager.RewardClaimWithProof calldata _proof) external;
}
