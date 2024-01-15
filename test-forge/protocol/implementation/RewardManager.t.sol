// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../contracts/protocol/implementation/RewardManager.sol";
import "../../../contracts/protocol/implementation/FlareSystemManager.sol";
import "../../../contracts/protocol/interface/IWNat.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

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
    FlareSystemManager private flareSystemManager;
    address[] private rewardOffersManagers;
    IWNat private wNat;
    IPChainStakeMirror private pChainStakeMirror;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    event RewardClaimed(
        address indexed voter,
        address indexed whoClaimed,
        address indexed sentTo,
        uint24 rewardEpochId,
        RewardManager.ClaimType claimType,
        uint120 amount
    );

    function setUp() public {
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");

        rewardManager = new RewardManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            2,
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

    function testConstructorOffsetTooSmall() public {
        vm.expectRevert("offset too small");
        new RewardManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            1,
            20000
        );
    }

    //// claim tests
    // claim - only DIRECT type
    function testClaimDirect() public {
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

        bytes32 leftLeaf = keccak256(abi.encode(body));
        bytes32 rightLeaf = keccak256("rightLeaf");
        merkleProof[0] = rightLeaf;
        // bytes32 merkleRoot = keccak256(abi.encode(rightLeaf, leftLeaf));
        bytes32 merkleRoot = MerkleProof.processProof(merkleProof, leftLeaf);
        uint256 vpBlock = 10;

        // reward manager not yet activated
        vm.expectRevert("reward manager deactivated");
        rewardManager.claim(voter1, payable(voter1), rewardEpochId, false, proofs);

        _mockGetCurrentEpochId(0);
        // contract needs some funds for rewarding
        _fundRewardContract(1000, rewardEpochId);

        vm.startPrank(governance);
        rewardManager.enableClaims();
        rewardManager.activate();
        vm.stopPrank();
        _mockGetCurrentEpochId(1);
        _mockGetVpBlock(1, vpBlock);
        _mockRewardsHash(rewardEpochId, merkleRoot);

        _mockGetBurnFactor(rewardEpochId, voter1, 0);

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochId, 0); // only FEE claim
        _setWNatData();
        _setPChainMirrorData();
        _mockGetVpBlock(0, vpBlock);

        // uint256 balanceBefore = voter1.balance;
        vm.prank(voter1);
        vm.expectEmit();
        emit RewardClaimed(voter1, voter1, voter1, rewardEpochId, claimType, amount);
        rewardManager.claim(voter1, payable(voter1), rewardEpochId, false, proofs);
        // uint256 balanceAfter = voter1.balance;
        assertEq(voter1.balance, amount);
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

    function _mockRewardsHash(uint256 _epochId, bytes32 _hash) private {
        vm.mockCall(
            mockFlareSystemManager,
            abi.encodeWithSelector(flareSystemManager.rewardsHash.selector, _epochId),
            abi.encode(_hash)
        );
    }

    function _mockGetBurnFactor(uint256 _epochId, address _user, uint256 _burnFactor) private {
        vm.mockCall(
            mockFlareSystemManager,
            abi.encodeWithSelector(FlareSystemManager.getRewardsFeeBurnFactor.selector, _epochId, _user),
            abi.encode(_burnFactor)
        );
    }

    function _mockNoOfWeightBasedClaims(uint256 _epoch, uint256 _noOfClaims) private {
        vm.mockCall(
            mockFlareSystemManager,
            abi.encodeWithSelector(flareSystemManager.noOfWeightBasedClaims.selector, _epoch),
            abi.encode(_noOfClaims)
        );
    }

    function _mockWNatBalance(address _user, uint256 _vpBlock, uint256 _balance) private {
        vm.mockCall(
            mockWNat,
            abi.encodeWithSelector(wNat.balanceOfAt.selector, _user, _vpBlock),
            abi.encode(_balance)
        );
    }

    function _mockWNatDelegations(
        address _user, uint256 _vpBlock,
        address[] memory _delegates,
        uint256[] memory _bips
    ) private
    {
        vm.mockCall(
            mockWNat,
            abi.encodeWithSelector(wNat.delegatesOfAt.selector, _user, _vpBlock),
            abi.encode(_delegates, _bips)
        );
    }

    function _mockStakesOfAt(
        address _user,
        uint256 _vpBlock,
        bytes20[] memory _nodeIds,
        uint256[] memory _weights
    ) private
    {
        vm.mockCall(
            mockPChainStakeMirror,
            abi.encodeWithSelector(pChainStakeMirror.stakesOfAt.selector, _user, _vpBlock),
            abi.encode(_nodeIds, _weights)
        );
    }

    function _setWNatData() internal {
        address[] memory delegates = new address[](1);
        delegates[0] = makeAddr("delegate");
        uint256[] memory bips = new uint256[](1);
        bips[0] = 10000;
        _mockWNatDelegations(makeAddr("voter1"), 10, delegates, bips);
        _mockWNatBalance(makeAddr("voter1"), 10, 200);
    }

    function _setPChainMirrorData() internal {
        bytes20[] memory nodeIds = new bytes20[](1);
        uint256[] memory weights = new uint256[](1);
        nodeIds[0] = bytes20(makeAddr("nodeId1"));
        weights[0] = 200;
        _mockStakesOfAt(makeAddr("voter1"), 10, nodeIds, weights);
    }

    function _fundRewardContract(uint256 _amountWei, uint24 _rewardEpochId) internal {
        vm.prank(governance);
        rewardOffersManagers = new address[](1);
        rewardOffersManagers[0] = makeAddr("rewardOffersManager");
        rewardManager.setRewardOffersManagerList(rewardOffersManagers);
        vm.deal(rewardOffersManagers[0], 1 ether);
        vm.prank(rewardOffersManagers[0]);
        rewardManager.receiveRewards{value: _amountWei} (_rewardEpochId, false);
    }
}