// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../contracts/protocol/implementation/RewardManager.sol";
import "../../../contracts/protocol/implementation/FlareSystemManager.sol";
import "../../../contracts/protocol/interface/IWNat.sol";
import "../../../contracts/protocol/implementation/VoterRegistry.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import "forge-std/console2.sol";

contract RewardManagerTest is Test {

    struct RewardEpochData {
        uint24 id;
        uint256 vpBlock;
    }

    RewardManager private rewardManager;
    address private addressUpdater;
    address private governance;
    address private mockVoterRegistry;
    address private mockClaimSetupManager;
    address private mockFlareSystemManager;
    address private mockPChainStakeMirror;
    address private mockCChainStake;
    address private mockWNat;
    address[] private rewardOffersManagers;

    FlareSystemManager private flareSystemManager;
    IWNat private wNat;
    IPChainStakeMirror private pChainStakeMirror;
    ICChainStake private cChainStake;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;
    address[] private rewardOwners;

    address private voter1;
    bytes20 private nodeId1;
    address private account1;
    address payable constant private BURN_ADDRESS = payable(0x000000000000000000000000000000000000dEaD);

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
            addressUpdater
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

        voter1 = makeAddr("voter1");
        nodeId1 = bytes20(makeAddr("nodeId1"));
        account1 = makeAddr("account1");
    }

    //// claim tests
    // claim - only DIRECT type
    function testClaimDirect() public {
        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);

        bytes32[] memory merkleProof = new bytes32[](0);
        RewardManager.RewardClaimWithProof[] memory proofs = new RewardManager.RewardClaimWithProof[](1);
        RewardManager.RewardClaim memory body = RewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 100, RewardManager.ClaimType.DIRECT);
        RewardManager.RewardClaimWithProof memory proof = RewardManager.RewardClaimWithProof(
            merkleProof, body);
        proofs[0] = proof;
        bytes32 leaf1 = keccak256(abi.encode(body));
        bytes32 merkleRoot = leaf1;

        // reward manager not yet activated
        vm.expectRevert("reward manager deactivated");
        rewardManager.claim(voter1, payable(voter1), rewardEpochData.id, false, proofs);

        // contract needs some funds for rewarding
        _fundRewardContract(1000, rewardEpochData.id);

        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);
        _mockRewardsHash(rewardEpochData.id, merkleRoot);

        _mockGetBurnFactor(rewardEpochData.id, voter1, 0);

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 0); // only DIRECT claim
        _setWNatData();
        _setPChainMirrorData();
        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

        // set executor who will claim instead of a reward owner
        address executor = makeAddr("executor");
        vm.mockCall(
            mockClaimSetupManager,
            abi.encodeWithSelector(
                IClaimSetupManager.checkExecutorAndAllowedRecipient.selector, executor, voter1, voter1),
            abi.encode()
        );
        vm.expectEmit();
        emit RewardClaimed(voter1, voter1, voter1, rewardEpochData.id, body.claimType, body.amount);
        rewardManager.claim(voter1, payable(voter1), rewardEpochData.id, false, proofs);
        assertEq(voter1.balance, body.amount);
    }

    // claim DIRECT and weight based (WNAT)
    function testClaimDirectAndWeightBased1() public {
        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);
        RewardManager.RewardClaimWithProof[] memory proofs = new RewardManager.RewardClaimWithProof[](2);
        bytes32[] memory merkleProof1 = new bytes32[](1);
        bytes32[] memory merkleProof2 = new bytes32[](1);

        RewardManager.RewardClaim memory body1 = RewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 100, RewardManager.ClaimType.DIRECT);
        RewardManager.RewardClaim memory body2 = RewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 200, RewardManager.ClaimType.WNAT);
        bytes32 leaf1 = keccak256(abi.encode(body1));
        bytes32 leaf2 = keccak256(abi.encode(body2));
        bytes32 merkleRoot = _hashPair(leaf1, leaf2);

        // proof for DIRECT claim
        merkleProof1[0] = leaf2;
        proofs[0] = RewardManager.RewardClaimWithProof(merkleProof1, body1);

        // proof for WNAT claim
        merkleProof2[0] = leaf1;
        proofs[1] = RewardManager.RewardClaimWithProof(merkleProof2, body2);

        // contract needs some funds for rewarding
        _fundRewardContract(1000, rewardEpochData.id);

        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);
        _mockRewardsHash(rewardEpochData.id, merkleRoot);

        _mockGetBurnFactor(rewardEpochData.id, voter1, 0);

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 1); // DIRECT claim and one weight based claim (WNAT)
        // voter1 balance = 250; vp = 300; he is delegating 100% to himself
        _setWNatData();
        _setPChainMirrorData();
        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

        uint256 balanceBefore = voter1.balance;
        vm.prank(voter1);
        // DIRECT claim reward
        vm.expectEmit();
        emit RewardClaimed(voter1, voter1, voter1, rewardEpochData.id, body1.claimType, body1.amount);
        // WNAT claim reward; should receive 200 * 250/300 = 166
        vm.expectEmit();
        emit RewardClaimed(voter1, voter1, voter1, rewardEpochData.id, body2.claimType, 166);
        rewardManager.claim(voter1, payable(voter1), rewardEpochData.id, false, proofs);
        uint256 balanceAfter = voter1.balance;
        assertEq(balanceAfter - balanceBefore, body1.amount + 166);
    }

    // user has undelegated voter power and is voter - claim self delegation rewards
    function testClaimDirectAndWeightBase2() public {
        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);
        RewardManager.RewardClaimWithProof[] memory proofs = new RewardManager.RewardClaimWithProof[](0);

        _fundRewardContract(1000, rewardEpochData.id);
        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);
        _mockGetBurnFactor(rewardEpochData.id, voter1, 0);

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 1); // DIRECT claim and one weight based claim (WNAT)
        // voter1 balance = 250; vp = 300; he is delegating 100% to himself
        _setWNatData();
        _setPChainMirrorData();
        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

        // override delegations data from _setWnatData
        address[] memory delegates = new address[](0);
        uint256[] memory bips = new uint256[](0);
        _mockWNatDelegations(voter1, 10, delegates, bips);
        _mockIsVoterRegistered(voter1, 0, true);

        vm.prank(voter1);
        vm.expectRevert("not initialised");
        rewardManager.claim(voter1, payable(voter1), rewardEpochData.id, false, proofs);

        // set proofs and initialised claims
        proofs = new RewardManager.RewardClaimWithProof[](2);
        bytes32[] memory merkleProof1 = new bytes32[](1);
        bytes32[] memory merkleProof2 = new bytes32[](1);

        RewardManager.RewardClaim memory body1 = RewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 100, RewardManager.ClaimType.DIRECT);
        RewardManager.RewardClaim memory body2 = RewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 200, RewardManager.ClaimType.WNAT);
        bytes32 leaf1 = keccak256(abi.encode(body1));
        bytes32 leaf2 = keccak256(abi.encode(body2));
        bytes32 merkleRoot = _hashPair(leaf1, leaf2);
        _mockRewardsHash(rewardEpochData.id, merkleRoot);

        // proof for DIRECT claim
        merkleProof1[0] = leaf2;
        proofs[0] = RewardManager.RewardClaimWithProof(merkleProof1, body1);

        // proof for WNAT claim
        merkleProof2[0] = leaf1;
        proofs[1] = RewardManager.RewardClaimWithProof(merkleProof2, body2);

        vm.prank(voter1);
        // DIRECT claim reward
        vm.expectEmit();
        emit RewardClaimed(voter1, voter1, voter1, rewardEpochData.id, body1.claimType, body1.amount);
        // WNAT claim reward; should receive 200 * 250/300 = 166
        vm.expectEmit();
        emit RewardClaimed(voter1, voter1, voter1, rewardEpochData.id, body2.claimType, 166);
        rewardManager.claim(voter1, payable(voter1), rewardEpochData.id, false, proofs);
        assertEq(voter1.balance, body1.amount + 166);
    }


    // claim DIRECT and weight based (WNAT, MIRROR & CCHAIN)
    function testClaimDirectAndWeightBased2() public {
        // enable cChain stake
        vm.prank(governance);
        rewardManager.enableCChainStake();
        assertEq(address(rewardManager.cChainStake()), address(0));
        vm.prank(addressUpdater);
        rewardManager.updateContractAddresses(contractNameHashes, contractAddresses);
        assertEq(address(rewardManager.cChainStake()), mockCChainStake);

        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);
        RewardManager.RewardClaimWithProof[] memory proofs = new RewardManager.RewardClaimWithProof[](4);
        bytes32[] memory merkleProof1 = new bytes32[](2);
        bytes32[] memory merkleProof2 = new bytes32[](2);
        bytes32[] memory merkleProof3 = new bytes32[](2);
        bytes32[] memory merkleProof4 = new bytes32[](2);

        RewardManager.RewardClaim memory body1 = RewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 100, RewardManager.ClaimType.DIRECT);
        RewardManager.RewardClaim memory body2 = RewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 200, RewardManager.ClaimType.WNAT);
        RewardManager.RewardClaim memory body3 = RewardManager.RewardClaim(
            rewardEpochData.id, nodeId1, 300, RewardManager.ClaimType.MIRROR);
        RewardManager.RewardClaim memory body4 = RewardManager.RewardClaim(
            rewardEpochData.id, bytes20(account1), 400, RewardManager.ClaimType.CCHAIN);
        bytes32[] memory hashes = new bytes32[](7);
        hashes[0] = keccak256(abi.encode(body1)); // leaf1
        hashes[1] = keccak256(abi.encode(body2)); // leaf2
        hashes[2] = keccak256(abi.encode(body3)); // leaf3
        hashes[3] = keccak256(abi.encode(body4)); // leaf4
        hashes[4] = _hashPair(hashes[0], hashes[1]); // hash1
        hashes[5] = _hashPair(hashes[2], hashes[3]); // hash2
        hashes[6] = _hashPair(hashes[4], hashes[5]); // merkleRoot

        // proof for DIRECT claim
        merkleProof1[0] = hashes[1];
        merkleProof1[1] = hashes[5];
        proofs[0] = RewardManager.RewardClaimWithProof(merkleProof1, body1);

        // proof for WNAT claim
        merkleProof2[0] = hashes[0];
        merkleProof2[1] = hashes[5];
        proofs[1] = RewardManager.RewardClaimWithProof(merkleProof2, body2);

        // proof for MIRROR claim
        merkleProof3[0] = hashes[3];
        merkleProof3[1] = hashes[4];
        proofs[2] = RewardManager.RewardClaimWithProof(merkleProof3, body3);

        // proof for CCHAIN claim
        merkleProof4[0] = hashes[2];
        merkleProof4[1] = hashes[4];
        proofs[3] = RewardManager.RewardClaimWithProof(merkleProof4, body4);

        // contract needs some funds for rewarding
        _fundRewardContract(1000, rewardEpochData.id);

        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);
        _mockRewardsHash(rewardEpochData.id, hashes[6]);

        _mockGetBurnFactor(rewardEpochData.id, voter1, 0);

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 3);
        // voter1 balance = 250; vp = 300; he is delegating 100% to himself
        _setWNatData();
        // voter1 has 350 weight on node1, which has 400 vp
        _setPChainMirrorData();
        // voter1 has 450 weight on account1, which has 500 vp
        _setCChainData();
        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

        // uint256 balanceBefore = voter1.balance;
        vm.prank(voter1);
        // DIRECT rewards
        vm.expectEmit();
        emit RewardClaimed(voter1, voter1, voter1, rewardEpochData.id, body1.claimType, body1.amount);
        // WNAT rewards; should receive floor(200 * 250 / 300) = 166
        vm.expectEmit();
        emit RewardClaimed(voter1, voter1, voter1, rewardEpochData.id, body2.claimType, 166);
        // MIRROR rewards; should receive floor(300 * 350 / 400) = 262
        vm.expectEmit();
        emit RewardClaimed(address(nodeId1), voter1, voter1, rewardEpochData.id, body3.claimType, 262);
        // CCHAIN rewards; should receive floor (400 * 450 / 500) = 360
        vm.expectEmit();
        emit RewardClaimed(account1, voter1, voter1, rewardEpochData.id, body4.claimType, 360);
        rewardManager.claim(voter1, payable(voter1), rewardEpochData.id, false, proofs);
        // uint256 balanceAfter = voter1.balance;
        assertEq(voter1.balance, body1.amount + 166 + 262 + 360);
    }

    // weight based reward are already initialized; delegator claims for himself
    function testClaimWeightBased() public {
        testClaimDirectAndWeightBased2();
        address delegator = makeAddr("delegator");

        // set data for delegator
        address[] memory delegates = new address[](1);
        delegates[0] = voter1;
        uint256[] memory bips = new uint256[](1);
        bips[0] = 10000;
        _mockWNatDelegations(delegator, 10, delegates, bips);
        _mockWNatBalance(delegator, 10, 50);

        bytes20[] memory nodeIds = new bytes20[](1);
        uint256[] memory weights = new uint256[](1);
        nodeIds[0] = nodeId1;
        weights[0] = 50;
        _mockStakes(delegator, 10, nodeIds, weights);

        address[] memory accounts = new address[](1);
        accounts[0] = account1;
        weights[0] = 50;
        _mockCChainStakes(delegator, 10, accounts, weights);

        RewardManager.RewardClaimWithProof[] memory proofs = new RewardManager.RewardClaimWithProof[](0);

        vm.prank(delegator);
        // WNAT rewards; should receive everything that is left (ceil(200 * 50/300) = 34)
        vm.expectEmit();
        emit RewardClaimed(voter1, delegator, delegator, 0, RewardManager.ClaimType.WNAT, 34);
        // MIRROR rewards; should receive ceil(300 * 50/400) = 38
        vm.expectEmit();
        emit RewardClaimed(address(nodeId1), delegator, delegator, 0, RewardManager.ClaimType.MIRROR, 38);
        // CCHAIN rewards; should receive ceil(400 * 50/500) = 400 - 360 = 40
        vm.expectEmit();
        emit RewardClaimed(account1, delegator, delegator, 0, RewardManager.ClaimType.CCHAIN, 40);
        rewardManager.claim(delegator, payable(delegator), 0, false, proofs);
        assertEq(delegator.balance, 34 + 38 + 40);

        // everything was already claimed; delegator has 0 mirrored balances
        address delegator2 = makeAddr("delegator2");
        _mockWNatDelegations(delegator2, 10, delegates, bips);
        _mockWNatBalance(delegator2, 10, 50);
        weights[0] = 0;
        _mockStakes(delegator2, 10, nodeIds, weights);
        _mockCChainStakes(delegator2, 10, accounts, weights);
        vm.prank(delegator2);
        rewardManager.claim(delegator2, payable(delegator2), 0, false, proofs);
        assertEq(delegator2.balance, 0);
    }

    // reward weight > unclaimed weight
    function testClaimRevertRewardWeightTooLarge() public {
        testClaimDirectAndWeightBased2();
        address delegator = makeAddr("delegator");

        // set data for delegator
        address[] memory delegates = new address[](1);
        delegates[0] = voter1;
        uint256[] memory bips = new uint256[](1);
        bips[0] = 10000;
        _mockWNatDelegations(delegator, 10, delegates, bips);
        _mockWNatBalance(delegator, 10, 50000); // 50000 > 250

        bytes20[] memory nodeIds = new bytes20[](1);
        uint256[] memory weights = new uint256[](1);
        nodeIds[0] = nodeId1;
        weights[0] = 50;
        _mockStakes(delegator, 10, nodeIds, weights);

        address[] memory accounts = new address[](1);
        accounts[0] = account1;
        weights[0] = 50;
        _mockCChainStakes(delegator, 10, accounts, weights);

        RewardManager.RewardClaimWithProof[] memory proofs = new RewardManager.RewardClaimWithProof[](0);

        vm.prank(delegator);
        vm.expectRevert();
        rewardManager.claim(delegator, payable(delegator), 0, false, proofs);
    }

    function testClaimRevertNotInitialised() public {
        _fundRewardContract(1000, 0);
        vm.startPrank(governance);
        rewardManager.enableClaims();
        rewardManager.activate();
        rewardManager.enableCChainStake();
        vm.stopPrank();
        vm.prank(addressUpdater);
        rewardManager.updateContractAddresses(contractNameHashes, contractAddresses);
        _mockGetCurrentEpochId(1);
        _mockGetVpBlock(1, 20);
        _mockNoOfWeightBasedClaims(0, 3);
        _mockGetVpBlock(0, 10);

        address delegator = makeAddr("delegator");
        // set data for delegator
        address[] memory delegates = new address[](1);
        delegates[0] = voter1;
        uint256[] memory bips = new uint256[](1);
        bips[0] = 10000;
        _mockWNatDelegations(delegator, 10, delegates, bips);
        _mockWNatBalance(delegator, 10, 50);

        bytes20[] memory nodeIds = new bytes20[](1);
        uint256[] memory weights = new uint256[](1);
        nodeIds[0] = nodeId1;
        weights[0] = 50;
        _mockStakes(delegator, 10, nodeIds, weights);

        address[] memory accounts = new address[](1);
        accounts[0] = account1;
        weights[0] = 50;
        _mockCChainStakes(delegator, 10, accounts, weights);

        RewardManager.RewardClaimWithProof[] memory proofs = new RewardManager.RewardClaimWithProof[](0);

        vm.startPrank(delegator);
        vm.expectRevert("not initialised"); // WNAT
        rewardManager.claim(delegator, payable(delegator), 0, false, proofs);

        // _mockWNatBalance(delegator, 10, 0);
        _mockIsVoterRegistered(delegator, 0, false);
        delegates = new address[](0);
        bips = new uint256[](0);
        _mockWNatDelegations(delegator, 10, delegates, bips);
        vm.expectRevert("not initialised");
        rewardManager.claim(delegator, payable(delegator), 0, false, proofs);

        // WNAT balance 0 -> will not revert anymore; MIRROR should revert now
        _mockWNatBalance(delegator, 10, 0);
        vm.expectRevert("not initialised"); // MIRROR
        rewardManager.claim(delegator, payable(delegator), 0, false, proofs);

        // delegator doesn't  have mirrored stakes -> will not revert anymore; CCHAIN should revert now
        nodeIds = new bytes20[](0);
        weights = new uint256[](0);
        _mockStakes(delegator, 10, nodeIds, weights);
        vm.expectRevert("not initialised"); // CCHAIN
        rewardManager.claim(delegator, payable(delegator), 0, false, proofs);
    }

    // total rewards < initialised rewards -> reduce total rewards
    function testClaimReduceRewardAmount() public {
         RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);

        bytes32[] memory merkleProof = new bytes32[](0);
        RewardManager.RewardClaimWithProof[] memory proofs = new RewardManager.RewardClaimWithProof[](1);
        RewardManager.RewardClaim memory body = RewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 100, RewardManager.ClaimType.DIRECT);
        RewardManager.RewardClaimWithProof memory proof = RewardManager.RewardClaimWithProof(
            merkleProof, body);
        proofs[0] = proof;
        bytes32 leaf1 = keccak256(abi.encode(body));
        bytes32 merkleRoot = leaf1;

        // contract needs some funds for rewarding
        _fundRewardContract(50, rewardEpochData.id);

        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);
        _mockRewardsHash(rewardEpochData.id, merkleRoot);

        _mockGetBurnFactor(rewardEpochData.id, voter1, 0);

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 0); // only DIRECT claim
        _setWNatData();
        _setPChainMirrorData();
        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

        vm.prank(voter1);
        vm.expectEmit();
        // contract received only 50, so claimer can't receive 100
        emit RewardClaimed(voter1, voter1, voter1, rewardEpochData.id, body.claimType, 50);
        rewardManager.claim(voter1, payable(voter1), rewardEpochData.id, false, proofs);
        assertEq(voter1.balance, 50);
    }

    function testClaimAndBurn() public {
        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);

        bytes32[] memory merkleProof = new bytes32[](0);
        RewardManager.RewardClaimWithProof[] memory proofs = new RewardManager.RewardClaimWithProof[](1);
        RewardManager.RewardClaim memory body = RewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 100, RewardManager.ClaimType.FEE);
        RewardManager.RewardClaimWithProof memory proof = RewardManager.RewardClaimWithProof(
            merkleProof, body);
        proofs[0] = proof;
        bytes32 leaf1 = keccak256(abi.encode(body));
        bytes32 merkleRoot = leaf1;

        // contract needs some funds for rewarding
        _fundRewardContract(1000, rewardEpochData.id);

        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);
        _mockRewardsHash(rewardEpochData.id, merkleRoot);

        _mockGetBurnFactor(rewardEpochData.id, voter1, 100000); // 100k PPM = 10 %

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 0); // only FEE claim
        _setWNatData();
        _setPChainMirrorData();
        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

        vm.prank(voter1);
        // 10 % * 100 should be burned
        vm.expectEmit();
        emit RewardClaimed(voter1, voter1, BURN_ADDRESS, rewardEpochData.id, body.claimType, 10);
        vm.expectEmit();
        emit RewardClaimed(voter1, voter1, voter1, rewardEpochData.id, body.claimType, 90);
        rewardManager.claim(voter1, payable(voter1), rewardEpochData.id, false, proofs);
        assertEq(voter1.balance, 90);
        assertEq(BURN_ADDRESS.balance, 10);
    }

    function testClaimDirectRevertInvalidProof() public {
        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);

        bytes32[] memory merkleProof = new bytes32[](0);
        RewardManager.RewardClaimWithProof[] memory proofs = new RewardManager.RewardClaimWithProof[](1);
        RewardManager.RewardClaim memory body = RewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 100, RewardManager.ClaimType.FEE);
        RewardManager.RewardClaimWithProof memory proof = RewardManager.RewardClaimWithProof(
            merkleProof, body);
        proofs[0] = proof;
        bytes32 leaf1 = keccak256(abi.encode(body));
        bytes32 merkleRoot = keccak256(abi.encode(leaf1)); // wrong merkle root

        // contract needs some funds for rewarding
        _fundRewardContract(1000, rewardEpochData.id);

        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);
        _mockRewardsHash(rewardEpochData.id, merkleRoot);

        _mockGetBurnFactor(rewardEpochData.id, voter1, 0);

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 0); // only FEE claim
        _setWNatData();
        _setPChainMirrorData();
        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

        vm.prank(voter1);
        vm.expectRevert("merkle proof invalid");
        rewardManager.claim(voter1, payable(voter1), rewardEpochData.id, false, proofs);
    }

    function testClaimWeightRevertInvalidProof() public {
        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);

        bytes32[] memory merkleProof = new bytes32[](0);
        RewardManager.RewardClaimWithProof[] memory proofs = new RewardManager.RewardClaimWithProof[](1);
        RewardManager.RewardClaim memory body = RewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 100, RewardManager.ClaimType.WNAT);
        RewardManager.RewardClaimWithProof memory proof = RewardManager.RewardClaimWithProof(
            merkleProof, body);
        proofs[0] = proof;
        bytes32 leaf1 = keccak256(abi.encode(body));
        bytes32 merkleRoot = keccak256(abi.encode(leaf1)); // wrong merkle root

        // contract needs some funds for rewarding
        _fundRewardContract(1000, rewardEpochData.id);

        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);
        _mockRewardsHash(rewardEpochData.id, merkleRoot);

        _mockGetBurnFactor(rewardEpochData.id, voter1, 0);

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 0); // only FEE claim
        _setWNatData();
        _setPChainMirrorData();
        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

        vm.prank(voter1);
        vm.expectRevert("merkle proof invalid");
        rewardManager.claim(voter1, payable(voter1), rewardEpochData.id, false, proofs);
    }

    function testClaimRevertWrongBeneficiary() public {
        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);

        bytes32[] memory merkleProof = new bytes32[](0);
        RewardManager.RewardClaimWithProof[] memory proofs = new RewardManager.RewardClaimWithProof[](1);
        RewardManager.RewardClaim memory body = RewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 100, RewardManager.ClaimType.FEE);
        RewardManager.RewardClaimWithProof memory proof = RewardManager.RewardClaimWithProof(
            merkleProof, body);
        proofs[0] = proof;
        bytes32 leaf1 = keccak256(abi.encode(body));
        bytes32 merkleRoot = keccak256(abi.encode(leaf1)); // wrong merkle root

        // contract needs some funds for rewarding
        _fundRewardContract(1000, rewardEpochData.id);

        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);
        _mockRewardsHash(rewardEpochData.id, merkleRoot);

        _mockGetBurnFactor(rewardEpochData.id, voter1, 0);

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 0); // only FEE claim
        _setWNatData();
        _setPChainMirrorData();
        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

        address voter2 = makeAddr("voter2");
        vm.prank(voter2);
        vm.expectRevert("wrong beneficiary");
        rewardManager.claim(voter2, payable(voter1), rewardEpochData.id, false, proofs);
    }

    function testClaimAndWrap() public {
        // TODO deploy WNAT contract, set balance and voter power
        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);

        bytes32[] memory merkleProof = new bytes32[](0);
        RewardManager.RewardClaimWithProof[] memory proofs = new RewardManager.RewardClaimWithProof[](1);
        RewardManager.RewardClaim memory body = RewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 100, RewardManager.ClaimType.FEE);
        RewardManager.RewardClaimWithProof memory proof = RewardManager.RewardClaimWithProof(
            merkleProof, body);
        proofs[0] = proof;
        bytes32 leaf1 = keccak256(abi.encode(body));
        bytes32 merkleRoot = leaf1; // wrong merkle root

        // contract needs some funds for rewarding
        _fundRewardContract(1000, rewardEpochData.id);

        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);
        _mockRewardsHash(rewardEpochData.id, merkleRoot);

        _mockGetBurnFactor(rewardEpochData.id, voter1, 0);

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 0); // only FEE claim
        _setWNatData();
        _setPChainMirrorData();
        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

        vm.prank(voter1);
        vm.expectEmit();
        emit RewardClaimed(voter1, voter1, voter1, rewardEpochData.id, body.claimType, body.amount);
        rewardManager.claim(voter1, payable(voter1), rewardEpochData.id, true, proofs);
        assertEq(voter1.balance, 0);
        // assertEq(mockWNat.balanceOf(voter1), body.amount);
    }

    function testClaimRevertNotClaimable() public {
        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);
        RewardManager.RewardClaimWithProof[] memory proofs = new RewardManager.RewardClaimWithProof[](0);

        _fundRewardContract(1000, rewardEpochData.id);
        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);

        vm.prank(voter1);
        vm.expectRevert("not claimable");
        // epoch > current epoch
        rewardManager.claim(voter1, payable(voter1), 3, false, proofs);
    }

    function testClaimRevertZeroRecipient() public {
        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);
        RewardManager.RewardClaimWithProof[] memory proofs = new RewardManager.RewardClaimWithProof[](0);

        _fundRewardContract(1000, rewardEpochData.id);
        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);

        vm.prank(voter1);
        vm.expectRevert("recipient zero");
        rewardManager.claim(voter1, payable(address(0)), 0, false, proofs);
    }

    //// auto claim tests
    function testAutoClaimRevertNotClaimable() public {
        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);
        RewardManager.RewardClaimWithProof[] memory proofs = new RewardManager.RewardClaimWithProof[](0);

        _fundRewardContract(1000, rewardEpochData.id);
        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);

        rewardOwners = new address[](1);
        rewardOwners[0] = voter1;
        vm.prank(voter1);
        vm.expectRevert("not claimable");
        // epoch > current epoch
        rewardManager.autoClaim(rewardOwners, 3, proofs);
    }

    // no PDA;
    function testAutoClaim() public {
        rewardOwners = new address[](2);
        rewardOwners[0] = makeAddr("rewardOwner1");
        rewardOwners[1] = makeAddr("rewardOwner2");
        uint256 executorFee = 1; // 1wei
        _mockGetAutoClaimAddressesAndExecutorFee(voter1, rewardOwners, rewardOwners, executorFee);

        // enable cChain stake
        vm.prank(governance);
        rewardManager.enableCChainStake();
        vm.prank(addressUpdater);
        rewardManager.updateContractAddresses(contractNameHashes, contractAddresses);

        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);
        RewardManager.RewardClaimWithProof[] memory proofs = new RewardManager.RewardClaimWithProof[](4);
        bytes32[] memory merkleProof1 = new bytes32[](2);
        bytes32[] memory merkleProof2 = new bytes32[](2);
        bytes32[] memory merkleProof3 = new bytes32[](2);
        bytes32[] memory merkleProof4 = new bytes32[](2);

        RewardManager.RewardClaim memory body1 = RewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 100, RewardManager.ClaimType.DIRECT);
        RewardManager.RewardClaim memory body2 = RewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 200, RewardManager.ClaimType.WNAT);
        RewardManager.RewardClaim memory body3 = RewardManager.RewardClaim(
            rewardEpochData.id, nodeId1, 300, RewardManager.ClaimType.MIRROR);
        RewardManager.RewardClaim memory body4 = RewardManager.RewardClaim(
            rewardEpochData.id, bytes20(account1), 400, RewardManager.ClaimType.CCHAIN);
        bytes32[] memory hashes = new bytes32[](7);
        hashes[0] = keccak256(abi.encode(body1)); // leaf1
        hashes[1] = keccak256(abi.encode(body2)); // leaf2
        hashes[2] = keccak256(abi.encode(body3)); // leaf3
        hashes[3] = keccak256(abi.encode(body4)); // leaf4
        hashes[4] = _hashPair(hashes[0], hashes[1]); // hash1
        hashes[5] = _hashPair(hashes[2], hashes[3]); // hash2
        hashes[6] = _hashPair(hashes[4], hashes[5]); // merkleRoot

        // proof for DIRECT claim; will not be used since auto claim supports only weight based claims
        merkleProof1[0] = hashes[1];
        merkleProof1[1] = hashes[5];
        proofs[0] = RewardManager.RewardClaimWithProof(merkleProof1, body1);

        // proof for WNAT claim
        merkleProof2[0] = hashes[0];
        merkleProof2[1] = hashes[5];
        proofs[1] = RewardManager.RewardClaimWithProof(merkleProof2, body2);

        // proof for MIRROR claim
        merkleProof3[0] = hashes[3];
        merkleProof3[1] = hashes[4];
        proofs[2] = RewardManager.RewardClaimWithProof(merkleProof3, body3);

        // proof for CCHAIN claim
        merkleProof4[0] = hashes[2];
        merkleProof4[1] = hashes[4];
        proofs[3] = RewardManager.RewardClaimWithProof(merkleProof4, body4);

        _fundRewardContract(1000, rewardEpochData.id);
        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);
        _mockRewardsHash(rewardEpochData.id, hashes[6]);
        _mockGetBurnFactor(rewardEpochData.id, voter1, 0);

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 3);

        _setWNatData();
        _setWNatDataRewardOwners(rewardOwners, false);

        _setPChainMirrorData();
        _setPChainMirrorDataRewardOwners(rewardOwners);

        _setCChainData();
        _setCChainDataRewardOwners(rewardOwners);

        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

        vm.prank(voter1);
        // owner1:
        // wnat: floor(200 * 10 / 300) = 6;
        // mirror: floor(300 * 10 / 400) = 7;
        // cchain: floor(400 * 10 / 500) = 8;
        vm.expectEmit();
        emit RewardClaimed(voter1, rewardOwners[0], rewardOwners[0], rewardEpochData.id, body2.claimType, 6);
        vm.expectEmit();
        emit RewardClaimed(address(nodeId1), rewardOwners[0],
            rewardOwners[0], rewardEpochData.id, body3.claimType, 7);
        vm.expectEmit();
        emit RewardClaimed(account1, rewardOwners[0], rewardOwners[0], rewardEpochData.id, body4.claimType, 8);

        // owner2:
        // wnat: floor(200 * 20 / 300) = 13;
        // mirror: floor(300 * 20 / 400) = 15;
        // cchain: floor(400 * 20 / 500) = 16;
        // owner 2 should receive floor(200 * 20 / 300) = 13
        vm.expectEmit();
        emit RewardClaimed(voter1, rewardOwners[1], rewardOwners[1], rewardEpochData.id, body2.claimType, 13);
        vm.expectEmit();
        emit RewardClaimed(address(nodeId1), rewardOwners[1],
            rewardOwners[1], rewardEpochData.id, body3.claimType, 15);
        vm.expectEmit();
        emit RewardClaimed(account1, rewardOwners[1], rewardOwners[1], rewardEpochData.id, body4.claimType, 16);

        rewardManager.autoClaim(rewardOwners, rewardEpochData.id, proofs);
        // executor should receive 1 * 2 = 2
        assertEq(voter1.balance, 2);
        assertEq(address(rewardManager).balance, 1000 - 20 - 43 - 2 * 1);
        assertEq(address(mockWNat).balance, 20 + 43);
    }

    function testAutoClaimPDA() public {
        rewardOwners = new address[](2);
        rewardOwners[0] = makeAddr("rewardOwner1");
        rewardOwners[1] = makeAddr("rewardOwner2");
        address[] memory pdas = new address[](2);
        pdas[0] = makeAddr("pda1");
        pdas[1] = makeAddr("pda2");

        uint256 executorFee = 1; // 1wei
        _mockGetAutoClaimAddressesAndExecutorFee(voter1, rewardOwners, pdas, executorFee);

        // enable cChain stake
        vm.prank(governance);
        rewardManager.enableCChainStake();
        vm.prank(addressUpdater);
        rewardManager.updateContractAddresses(contractNameHashes, contractAddresses);

        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);
        RewardManager.RewardClaimWithProof[] memory proofs = new RewardManager.RewardClaimWithProof[](4);
        bytes32[] memory merkleProof1 = new bytes32[](2);
        bytes32[] memory merkleProof2 = new bytes32[](2);
        bytes32[] memory merkleProof3 = new bytes32[](2);
        bytes32[] memory merkleProof4 = new bytes32[](2);

        RewardManager.RewardClaim memory body1 = RewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 100, RewardManager.ClaimType.DIRECT);
        RewardManager.RewardClaim memory body2 = RewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 200, RewardManager.ClaimType.WNAT);
        RewardManager.RewardClaim memory body3 = RewardManager.RewardClaim(
            rewardEpochData.id, nodeId1, 300, RewardManager.ClaimType.MIRROR);
        RewardManager.RewardClaim memory body4 = RewardManager.RewardClaim(
            rewardEpochData.id, bytes20(account1), 400, RewardManager.ClaimType.CCHAIN);
        bytes32[] memory hashes = new bytes32[](7);
        hashes[0] = keccak256(abi.encode(body1)); // leaf1
        hashes[1] = keccak256(abi.encode(body2)); // leaf2
        hashes[2] = keccak256(abi.encode(body3)); // leaf3
        hashes[3] = keccak256(abi.encode(body4)); // leaf4
        hashes[4] = _hashPair(hashes[0], hashes[1]); // hash1
        hashes[5] = _hashPair(hashes[2], hashes[3]); // hash2
        hashes[6] = _hashPair(hashes[4], hashes[5]); // merkleRoot

        // proof for DIRECT claim; will not be used since auto claim supports only weight based claims
        merkleProof1[0] = hashes[1];
        merkleProof1[1] = hashes[5];
        proofs[0] = RewardManager.RewardClaimWithProof(merkleProof1, body1);

        // proof for WNAT claim
        merkleProof2[0] = hashes[0];
        merkleProof2[1] = hashes[5];
        proofs[1] = RewardManager.RewardClaimWithProof(merkleProof2, body2);

        // proof for MIRROR claim
        merkleProof3[0] = hashes[3];
        merkleProof3[1] = hashes[4];
        proofs[2] = RewardManager.RewardClaimWithProof(merkleProof3, body3);

        // proof for CCHAIN claim
        merkleProof4[0] = hashes[2];
        merkleProof4[1] = hashes[4];
        proofs[3] = RewardManager.RewardClaimWithProof(merkleProof4, body4);

        _fundRewardContract(1000, rewardEpochData.id);
        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);
        _mockRewardsHash(rewardEpochData.id, hashes[6]);
        _mockGetBurnFactor(rewardEpochData.id, voter1, 0);

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 3);

        _setWNatData();
        _setWNatDataRewardOwners(rewardOwners, false);
        _setWNatDataRewardOwners(pdas, true);

        _setPChainMirrorData();
        _setPChainMirrorDataRewardOwners(rewardOwners);

        _setCChainData();
        _setCChainDataRewardOwners(rewardOwners);

        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

        vm.prank(voter1);
        // owner1:
        // wnat: floor(200 * 10 / 300) = 6
        // mirror: floor(300 * 10 / 400) = 7
        // cchain: floor(400 * 10 / 500) = 8
        vm.expectEmit();
        emit RewardClaimed(voter1, rewardOwners[0], pdas[0], rewardEpochData.id, body2.claimType, 6);
        vm.expectEmit();
        emit RewardClaimed(address(nodeId1), rewardOwners[0],
            pdas[0], rewardEpochData.id, body3.claimType, 7);
        vm.expectEmit();
        emit RewardClaimed(account1, rewardOwners[0], pdas[0], rewardEpochData.id, body4.claimType, 8);
        // PDA WNat for owner1: floor(200 * 5 / 300) = 3
        vm.expectEmit();
        emit RewardClaimed(voter1, pdas[0], pdas[0], rewardEpochData.id, body2.claimType, 3);

        // owner2:
        // wnat: floor(200 * 20 / 300) = 13
        // mirror: floor(300 * 20 / 400) = 15
        // cchain: floor(400 * 20 / 500) = 16
        vm.expectEmit();
        emit RewardClaimed(voter1, rewardOwners[1], pdas[1], rewardEpochData.id, body2.claimType, 13);
        vm.expectEmit();
        emit RewardClaimed(address(nodeId1), rewardOwners[1],
            pdas[1], rewardEpochData.id, body3.claimType, 15);
        vm.expectEmit();
        emit RewardClaimed(account1, rewardOwners[1], pdas[1], rewardEpochData.id, body4.claimType, 16);
        // PDA WNat for owner2: floor(200 * 15 / 300) = 10
        vm.expectEmit();
        emit RewardClaimed(voter1, pdas[1], pdas[1], rewardEpochData.id, body2.claimType, 10);

        rewardManager.autoClaim(rewardOwners, rewardEpochData.id, proofs);
        // executor should receive 1 * 2 = 2
        // pda1 should receive 6 + 7 + 8 + 3 - 1 = 23
        // pda2 should receive 13 + 15 + 16 + 10 - 1 = 53
        assertEq(voter1.balance, 2);
        assertEq(address(rewardManager).balance, 1000 - 23 - 53 - 2 * 1);
        assertEq(address(mockWNat).balance, 23 + 53);
    }

    function testAutoClaimRevertAmountTooSmall() public {
        rewardOwners = new address[](2);
        rewardOwners[0] = makeAddr("rewardOwner1");
        rewardOwners[1] = makeAddr("rewardOwner2");
        uint256 executorFee = 1000; // 1wei
        _mockGetAutoClaimAddressesAndExecutorFee(voter1, rewardOwners, rewardOwners, executorFee);

        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);
        bytes32[] memory merkleProof = new bytes32[](0);
        RewardManager.RewardClaimWithProof[] memory proofs = new RewardManager.RewardClaimWithProof[](1);
        RewardManager.RewardClaim memory body = RewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 200, RewardManager.ClaimType.WNAT);
        RewardManager.RewardClaimWithProof memory proof = RewardManager.RewardClaimWithProof(
            merkleProof, body);
        proofs[0] = proof;

        bytes32 merkleRoot = keccak256(abi.encode(body));

        _fundRewardContract(1000, rewardEpochData.id);
        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);
        _mockRewardsHash(rewardEpochData.id, merkleRoot);
        _mockGetBurnFactor(rewardEpochData.id, voter1, 0);

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 1);

        _setWNatData();
        _setWNatDataRewardOwners(rewardOwners, false);

        _setPChainMirrorData();
        _setPChainMirrorDataRewardOwners(rewardOwners);

        _setCChainData();
        _setCChainDataRewardOwners(rewardOwners);

        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

        vm.prank(voter1);
        vm.expectRevert("claimed amount too small");
        rewardManager.autoClaim(rewardOwners, rewardEpochData.id, proofs);
    }



    ////
    function testActivateAndDeactivate() public {
        vm.prank(governance);
        rewardManager.activate();
        assertEq(rewardManager.active(), true);
        vm.prank(governance);
        rewardManager.deactivate();
        assertEq(rewardManager.active(), false);
    }

    function testGetRewardOffersManagerList() public {
        vm.prank(governance);
        rewardOffersManagers = new address[](2);
        rewardOffersManagers[0] = makeAddr("rewardOffersManager1");
        rewardOffersManagers[1] = makeAddr("rewardOffersManager2");
        rewardManager.setRewardOffersManagerList(rewardOffersManagers);
        address[] memory offerManagers = rewardManager.getRewardOffersManagerList();
        assertEq(offerManagers.length, 2);
        assertEq(offerManagers[0], rewardOffersManagers[0]);
        assertEq(offerManagers[1], rewardOffersManagers[1]);
    }

    function testGetBalanceAndSupply() public {
        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);

        bytes32[] memory merkleProof = new bytes32[](0);
        RewardManager.RewardClaimWithProof[] memory proofs = new RewardManager.RewardClaimWithProof[](1);
        RewardManager.RewardClaim memory body = RewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 100, RewardManager.ClaimType.FEE);
        RewardManager.RewardClaimWithProof memory proof = RewardManager.RewardClaimWithProof(
            merkleProof, body);
        proofs[0] = proof;
        bytes32 leaf1 = keccak256(abi.encode(body));
        bytes32 merkleRoot = leaf1;

        assertEq(rewardManager.getExpectedBalance(), 0);
        // contract needs some funds for rewarding
        _fundRewardContract(1000, rewardEpochData.id);
        assertEq(rewardManager.getExpectedBalance(), 1000);

        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);
        _mockRewardsHash(rewardEpochData.id, merkleRoot);

        _mockGetBurnFactor(rewardEpochData.id, voter1, 100000);

        _mockNoOfWeightBasedClaims(rewardEpochData.id, 0);
        _setWNatData();
        _setPChainMirrorData();
        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

        vm.prank(voter1);
        rewardManager.claim(voter1, payable(voter1), rewardEpochData.id, false, proofs);

        vm.startPrank(rewardOffersManagers[0]);
        rewardManager.addDailyAuthorizedInflation(15);
        rewardManager.receiveRewards{value: 800} (1, true);
        vm.expectRevert("reward epoch id in the past");
        rewardManager.receiveRewards{value: 800} (0, true);
        vm.stopPrank();
        vm.expectRevert("only reward offers manager");
        rewardManager.receiveRewards{value: 800} (0, true);


        (uint256 locked, uint256 inflation, uint256 totalClaimed) = rewardManager.getTokenPoolSupplyData();
        assertEq(locked, 1000 + 800 - 800);
        assertEq(inflation, 15);
        assertEq(totalClaimed, 90 + 10);
        (uint256 claimed, uint256 burned, uint256 inflationAuth, uint256 inflationRec) = rewardManager.getTotals();
        assertEq(claimed, 90);
        assertEq(burned, 10);
        assertEq(inflationAuth, 15);
        assertEq(inflationRec, 800);

        _mockGetCurrentEpochId(91);
        assertEq(rewardManager.getCurrentRewardEpochId(), 91);
    }

    function testNextClaimableEpoch() public {
        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);

        bytes32[] memory merkleProof = new bytes32[](0);
        RewardManager.RewardClaimWithProof[] memory proofs = new RewardManager.RewardClaimWithProof[](1);
        RewardManager.RewardClaim memory body = RewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 100, RewardManager.ClaimType.FEE);
        RewardManager.RewardClaimWithProof memory proof = RewardManager.RewardClaimWithProof(
            merkleProof, body);
        proofs[0] = proof;
        bytes32 leaf1 = keccak256(abi.encode(body));
        bytes32 merkleRoot = leaf1;

        _fundRewardContract(1000, rewardEpochData.id);
        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);
        _mockRewardsHash(rewardEpochData.id, merkleRoot);
        _mockGetBurnFactor(rewardEpochData.id, voter1, 0);
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 0);
        _setWNatData();
        _setPChainMirrorData();
        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

        assertEq(rewardManager.nextClaimableRewardEpochId(voter1), 0);
        vm.prank(voter1);
        rewardManager.claim(voter1, payable(voter1), rewardEpochData.id, false, proofs);
        assertEq(rewardManager.nextClaimableRewardEpochId(voter1), 1);

        RewardManager rewardManager2 = new RewardManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater
        );

        vm.prank(addressUpdater);
        rewardManager2.updateContractAddresses(contractNameHashes, contractAddresses);
        _mockGetCurrentEpochId(123);
        vm.startPrank(governance);
        rewardManager2.enableClaims();
        rewardManager2.activate();
        vm.expectRevert("already enabled");
        rewardManager2.enableClaims();
        vm.stopPrank();
        assertEq(rewardManager2.nextClaimableRewardEpochId(voter1), 123);
    }

    function testGetEpochsWithClaimableRewards() public {
        _mockGetCurrentEpochId(0);
        vm.expectRevert("no epoch with claimable rewards");
        rewardManager.getEpochIdsWithClaimableRewards();

        vm.prank(governance);
        rewardManager.enableClaims();
        _mockGetCurrentEpochId(13);
        (uint256 startId, uint endId) = rewardManager.getEpochIdsWithClaimableRewards();
        assertEq(startId, 0);
        assertEq(endId, 13 - 1);
    }

    // TODO test new, old reawrd manager, expire epoch, setInitialRewardData; require(success, "transfer failed");
    function testSetNewRewardManager() public {
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
    )
        private
    {
        vm.mockCall(
            mockWNat,
            abi.encodeWithSelector(wNat.delegatesOfAt.selector, _user, _vpBlock),
            abi.encode(_delegates, _bips)
        );
    }

    function _mockStakes(
        address _user,
        uint256 _vpBlock,
        bytes20[] memory _nodeIds,
        uint256[] memory _weights
    )
        private
    {
        vm.mockCall(
            mockPChainStakeMirror,
            abi.encodeWithSelector(pChainStakeMirror.stakesOfAt.selector, _user, _vpBlock),
            abi.encode(_nodeIds, _weights)
        );
    }

    function _mockCChainStakes(
        address _user,
        uint256 _vpBlock,
        address[] memory _accounts,
        uint256[] memory _weights
    )
        private
    {
        vm.mockCall(
            mockCChainStake,
            abi.encodeWithSelector(cChainStake.stakesOfAt.selector, _user, _vpBlock),
            abi.encode(_accounts, _weights)
        );
    }

    function _mockWNatVp(address _user, uint256 _vpBlock, uint256 _vp) private {
        vm.mockCall(
            mockWNat,
            abi.encodeWithSelector(wNat.votePowerOfAt.selector, _user, _vpBlock),
            abi.encode(_vp)
        );
    }

    function _mockMirroredVp(bytes20 _nodeId, uint256 _vpBlock, uint256 _vp) private {
        vm.mockCall(
            mockPChainStakeMirror,
            abi.encodeWithSelector(pChainStakeMirror.votePowerOfAt.selector, _nodeId, _vpBlock),
            abi.encode(_vp)
        );
    }

    function _mockCChainVp(address _account, uint256 _vpBlock, uint256 _vp) private {
        vm.mockCall(
            mockCChainStake,
            abi.encodeWithSelector(cChainStake.votePowerOfAt.selector, _account, _vpBlock),
            abi.encode(_vp)
        );
    }

    function _mockIsVoterRegistered(address _voter, uint256 _epoch, bool _registered) private {
        vm.mockCall(
            mockVoterRegistry,
            abi.encodeWithSelector(VoterRegistry.isVoterRegistered.selector, _voter, _epoch),
            abi.encode(_registered)
        );
    }

    function _mockGetAutoClaimAddressesAndExecutorFee(
        address _executor,
        address[] memory _rewardOwners,
        address[] memory _claimAddresses,
        uint256 _fee
    )
        private
    {
        vm.mockCall(
            mockClaimSetupManager,
            abi.encodeWithSelector(
                IClaimSetupManager.getAutoClaimAddressesAndExecutorFee.selector, _executor, _rewardOwners),
            abi.encode(_claimAddresses, _fee)
        );
    }

    function _setWNatData() internal {
        address[] memory delegates = new address[](1);
        delegates[0] = voter1;
        uint256[] memory bips = new uint256[](1);
        bips[0] = 10000;
        _mockWNatDelegations(voter1, 10, delegates, bips);
        _mockWNatBalance(voter1, 10, 250);
        _mockWNatVp(voter1, 10, 300);
    }

    function _setWNatDataRewardOwners(address[] memory _rewardOwners, bool _PDA) internal {
        address[] memory delegates = new address[](1);
        uint256[] memory bips = new uint256[](1);
        delegates[0] = voter1;
        bips[0] = 10000;
        uint256 balance1;
        uint256 balance2;
        if (!_PDA) {
            balance1 = 10;
            balance2 = 20;
        } else {
            balance1 = 5;
            balance2 = 15;
        }
        _mockWNatDelegations(_rewardOwners[0], 10, delegates, bips);
        _mockWNatBalance(_rewardOwners[0], 10, balance1);
        _mockWNatDelegations(_rewardOwners[1], 10, delegates, bips);
        _mockWNatBalance(_rewardOwners[1], 10, balance2);
    }

    function _setPChainMirrorData() internal {
        bytes20[] memory nodeIds = new bytes20[](1);
        uint256[] memory weights = new uint256[](1);
        nodeIds[0] = nodeId1;
        weights[0] = 350;
        _mockStakes(voter1, 10, nodeIds, weights);
        _mockMirroredVp(nodeIds[0], 10, 400);
    }

    function _setPChainMirrorDataRewardOwners(address[] memory _rewardOwners) internal {
        bytes20[] memory nodeIds = new bytes20[](1);
        uint256[] memory weights = new uint256[](1);
        nodeIds[0] = nodeId1;
        weights[0] = 10;
        _mockStakes(_rewardOwners[0], 10, nodeIds, weights);
        weights[0] = 20;
        _mockStakes(_rewardOwners[1], 10, nodeIds, weights);

    }

    function _setCChainData() internal {
        address[] memory accounts = new address[](1);
        uint256[] memory weights = new uint256[](1);
        accounts[0] = account1;
        weights[0] = 450;
        _mockCChainStakes(voter1, 10, accounts, weights);
        _mockCChainVp(accounts[0], 10, 500);
    }

    function _setCChainDataRewardOwners(address[] memory _rewardOwners) internal {
        address[] memory accounts = new address[](1);
        uint256[] memory weights = new uint256[](1);
        accounts[0] = account1;
        weights[0] = 10;
        _mockCChainStakes(_rewardOwners[0], 10, accounts, weights);
        weights[0] = 20;
        _mockCChainStakes(_rewardOwners[1], 10, accounts, weights);
    }

    function _fundRewardContract(uint256 _amountWei, uint24 _rewardEpochId) internal {
        _mockGetCurrentEpochId(_rewardEpochId);
        vm.prank(governance);
        rewardOffersManagers = new address[](1);
        rewardOffersManagers[0] = makeAddr("rewardOffersManager");
        rewardManager.setRewardOffersManagerList(rewardOffersManagers);
        vm.deal(rewardOffersManagers[0], 1 ether);
        vm.prank(rewardOffersManagers[0]);
        rewardManager.receiveRewards{value: _amountWei} (_rewardEpochId, false);
    }

    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? keccak256(abi.encode(a, b)) : keccak256(abi.encode(b, a));
    }

    function _enableAndActivate(uint256 _epochId, uint256 _vpBlock) private {
        vm.startPrank(governance);
        rewardManager.enableClaims();
        rewardManager.activate();
        vm.stopPrank();
        _mockGetCurrentEpochId(_epochId + 1);
        // mock next reward epoch data
        _mockGetVpBlock(_epochId + 1, _vpBlock * 2);
    }
}