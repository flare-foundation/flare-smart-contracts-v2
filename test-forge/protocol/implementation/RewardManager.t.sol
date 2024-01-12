// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../contracts/protocol/implementation/RewardManager.sol";
import "../../../contracts/protocol/implementation/FlareSystemManager.sol";

import "forge-std/console2.sol";

contract RewardManagerTest is Test {

    RewardManager private rewardManager;
    address private addressUpdater;
    address private governance;
    address private mockVoterRegistry;
    address private mockClaimSetupManager;
    address private mockFlareSystemManager;
    address private mockPChainStakeMirror;
    address private mockCChainStake;
    address private mockWNat;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    function setUp() public {
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");

        rewardManager = new RewardManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            1,
            20000
        );

        mockVoterRegistry = makeAddr("mockVoterRegistry");
        mockClaimSetupManager = makeAddr("mockClaimSetupManager");
        mockFlareSystemManager = makeAddr("mockFlareSystemManager");
        mockPChainStakeMirror = makeAddr("mockPChainStakeMirror");
        mockCChainStake = makeAddr("mockCChainStake");
        mockWNat = makeAddr("mockWNat");

        vm.startPrank(addressUpdater);
        contractNameHashes = new bytes32[](7);
        contractAddresses = new address[](7);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("VoterRegistry"));
        contractNameHashes[2] = keccak256(abi.encode("ClaimSetupManager"));
        contractNameHashes[3] = keccak256(abi.encode("FlareSystemManager"));
        contractNameHashes[4] = keccak256(abi.encode("PChainStakeMirror"));
        contractNameHashes[5] = keccak256(abi.encode("CChainStake"));
        contractNameHashes[6] = keccak256(abi.encode("WNat"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = mockVoterRegistry;
        contractAddresses[2] = mockClaimSetupManager;
        contractAddresses[3] = mockFlareSystemManager;
        contractAddresses[4] = mockPChainStakeMirror;
        contractAddresses[5] = mockCChainStake;
        contractAddresses[6] = mockWNat;
        rewardManager.updateContractAddresses(contractNameHashes, contractAddresses);
        vm.stopPrank();
    }

    //// claim tests
    function test() public {
        address voter1 = makeAddr("voter1");
        bytes32[] memory merkleProof = new bytes32[](1);
        RewardManager.RewardClaimWithProof[] memory proofs = new RewardManager.RewardClaimWithProof[](1);
        uint24 rewardEpochId = 0;
        RewardManager.ClaimType claimType = RewardManager.ClaimType.DIRECT;
        uint120 amount = 100;
        RewardManager.RewardClaim memory body = RewardManager.RewardClaim(claimType, amount, voter1);
        RewardManager.RewardClaimWithProof memory proof = RewardManager.RewardClaimWithProof(
            merkleProof, rewardEpochId, body);
        proofs[0] = proof;

        _mockGetCurrentEpochId(1);

        rewardManager.claim(voter1, payable(voter1), rewardEpochId, false, proofs);
    }


    //// helper functions
    function _mockGetCurrentEpochId(uint256 _epochId) private {
        vm.mockCall(
            mockFlareSystemManager,
            abi.encodeWithSelector(FlareSystemManager.getCurrentRewardEpochId.selector),
            abi.encode(_epochId)
        );
    }

    function _mockGetVpBlock(uint256 _epochId, uint256 _vpBlock) private {
        vm.mockCall(
            mockFlareSystemManager,
            abi.encodeWithSelector(FlareSystemManager.getVotePowerBlock.selector, _epochId),
            abi.encode(_vpBlock)
        );
    }
}