// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../contracts/protocol/implementation/RewardManager.sol";

// solhint-disable-next-line max-states-count
contract RewardManagerTest is Test {

    struct RewardEpochData {
        uint24 id;
        uint256 vpBlock;
    }

    RewardManager private rewardManager;
    address private addressUpdater;
    address private governance;
    address private mockClaimSetupManager;
    address private mockFlareSystemsManager;
    address private mockPChainStakeMirror;
    address private mockCChainStake;
    address private mockWNat;
    address[] private rewardOffersManagers;
    address private mockFlareSystemsCalculator;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;
    address[] private rewardOwners;

    address private voter1;
    bytes20 private nodeId1;
    address private account1;
    address payable constant private BURN_ADDRESS = payable(0x000000000000000000000000000000000000dEaD);
    address private voter2;
    address private delegator;
    address private recipient;

    bytes32[] private merkleProof1;
    bytes32[] private merkleProof2;
    bytes32[] private merkleProof3;
    bytes32[] private merkleProof4;

    event RewardClaimed(
        address indexed beneficiary,
        address indexed rewardOwner,
        address indexed recipient,
        uint24 rewardEpochId,
        RewardManager.ClaimType claimType,
        uint120 amount
    );

    event RewardClaimsExpired(
        uint256 indexed rewardEpochId
    );

    function setUp() public {
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");

        rewardManager = new RewardManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            address(0)
        );

        mockClaimSetupManager = makeAddr("mockClaimSetupManager");
        mockFlareSystemsManager = makeAddr("mockFlareSystemsManager");
        mockPChainStakeMirror = makeAddr("mockPChainStakeMirror");
        mockCChainStake = makeAddr("mockCChainStake");
        mockWNat = makeAddr("mockWNat");
        mockFlareSystemsCalculator = makeAddr("mockFlareSystemsCalculator");

        vm.startPrank(addressUpdater);
        contractNameHashes = new bytes32[](7);
        contractAddresses = new address[](7);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("ClaimSetupManager"));
        contractNameHashes[2] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[3] = keccak256(abi.encode("PChainStakeMirror"));
        contractNameHashes[4] = keccak256(abi.encode("CChainStake"));
        contractNameHashes[5] = keccak256(abi.encode("WNat"));
        contractNameHashes[6] = keccak256(abi.encode("FlareSystemsCalculator"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = mockClaimSetupManager;
        contractAddresses[2] = mockFlareSystemsManager;
        contractAddresses[3] = mockPChainStakeMirror;
        contractAddresses[4] = mockCChainStake;
        contractAddresses[5] = mockWNat;
        contractAddresses[6] = mockFlareSystemsCalculator;
        rewardManager.updateContractAddresses(contractNameHashes, contractAddresses);
        vm.stopPrank();

        voter1 = makeAddr("voter1");
        nodeId1 = bytes20(makeAddr("nodeId1"));
        account1 = makeAddr("account1");
        voter2 = makeAddr("voter2");
        delegator = makeAddr("delegator");
        recipient = makeAddr("recipient");
    }

    //// claim tests
    // claim - only DIRECT type
    function testClaimDirect() public {
        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);

        bytes32[] memory merkleProof = new bytes32[](0);
        IRewardManager.RewardClaimWithProof[] memory proofs = new IRewardManager.RewardClaimWithProof[](1);
        IRewardManager.RewardClaim memory body = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 100, IRewardManager.ClaimType.DIRECT);
        IRewardManager.RewardClaimWithProof memory proof = IRewardManager.RewardClaimWithProof(
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

        _mockCalculateBurnFactor(rewardEpochData.id, voter1, 0);

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 0); // only DIRECT claim
        _setWNatData(rewardEpochData.vpBlock);
        _setPChainMirrorData(rewardEpochData.vpBlock);
        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

        // set executor who will claim instead of a reward owner
        address executor = makeAddr("executor");
        vm.prank(executor);
        vm.mockCall(
            mockClaimSetupManager,
            abi.encodeWithSelector(
                IIClaimSetupManager.checkExecutorAndAllowedRecipient.selector, executor, voter1, voter1),
            abi.encode()
        );
        vm.expectEmit();
        emit RewardClaimed(voter1, voter1, voter1, rewardEpochData.id, body.claimType, body.amount);
        rewardManager.claim(voter1, payable(voter1), rewardEpochData.id, false, proofs);
        assertEq(voter1.balance, body.amount);

        vm.expectRevert("already claimed");
        rewardManager.getStateOfRewardsAt(voter1, rewardEpochData.id);
    }

    // reward owner is address(0) - should not claim
    function testClaimDirectAddressZero() public {
        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);

        merkleProof1 = new bytes32[](1);
        merkleProof2 = new bytes32[](1);
        IRewardManager.RewardClaimWithProof[] memory proof1 = new IRewardManager.RewardClaimWithProof[](1);
        IRewardManager.RewardClaimWithProof[] memory proof2 = new IRewardManager.RewardClaimWithProof[](1);

        IRewardManager.RewardClaim memory body1 = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 100, IRewardManager.ClaimType.DIRECT);
        IRewardManager.RewardClaim memory body2 = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(address(0)), 200, IRewardManager.ClaimType.DIRECT);

        bytes32 leaf1 = keccak256(abi.encode(body1));
        bytes32 leaf2 = keccak256(abi.encode(body2));
        bytes32 merkleRoot = _hashPair(leaf1, leaf2);

        merkleProof1[0] = leaf2;
        proof1[0] = IRewardManager.RewardClaimWithProof(merkleProof1, body1);
        merkleProof2[0] = leaf1;
        proof2[0] = IRewardManager.RewardClaimWithProof(merkleProof2, body2);

        // contract needs some funds for rewarding
        _fundRewardContract(1000, rewardEpochData.id);

        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);
        _mockRewardsHash(rewardEpochData.id, merkleRoot);

        _mockCalculateBurnFactor(rewardEpochData.id, voter1, 0);

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 0); // only DIRECT claims
        _setWNatData(rewardEpochData.vpBlock);
        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

        vm.prank(voter1);
        vm.expectEmit();
        emit RewardClaimed(voter1, voter1, voter1, rewardEpochData.id, body1.claimType, body1.amount);
        rewardManager.claim(voter1, payable(voter1), rewardEpochData.id, false, proof1);
        assertEq(voter1.balance, body1.amount);

        // "claim" for address(0) - should not claim anything
        address[] memory delegates = new address[](0);
        uint256[] memory bips = new uint256[](0);
        _mockWNatDelegations(address(0), rewardEpochData.vpBlock, delegates, bips);
        _mockWNatBalance(address(0), rewardEpochData.vpBlock, 0);
        _mockWNatVp(address(0), rewardEpochData.vpBlock, 0);
        vm.prank(address(0));
        vm.recordLogs();
        rewardManager.claim(address(0), payable(recipient), rewardEpochData.id, false, proof2);
        assertEq(recipient.balance, 0);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 0);

    }


    // user has nothing to claim (no delegations, p-chain and c-chain not enabled)
    function testGetStateOfRewardsAt1() public {
        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);
        _mockGetVpBlock(0, rewardEpochData.vpBlock);
        _mockWNatBalance(voter1, rewardEpochData.vpBlock, rewardEpochData.id);
        _mockGetCurrentEpochId(0);
        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 0);
        _mockRewardsHash(rewardEpochData.id, bytes32("root"));

        RewardManager.RewardState[] memory rewardStates =
            rewardManager.getStateOfRewardsAt(voter1, rewardEpochData.id);
        assertEq(rewardStates.length, 0);
    }

    function testClaimDirectRevertRewardsHashZero() public {
        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);

        IRewardManager.RewardClaimWithProof[] memory proofs = new IRewardManager.RewardClaimWithProof[](0);

        _mockGetCurrentEpochId(0);
        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);
        _mockRewardsHash(rewardEpochData.id, bytes32(0));

        _mockCalculateBurnFactor(rewardEpochData.id, voter1, 0);

        _mockNoOfWeightBasedClaims(rewardEpochData.id, 0); // only DIRECT claim

        vm.prank(voter1);
        vm.expectRevert("rewards hash zero");
        rewardManager.claim(voter1, payable(voter1), rewardEpochData.id, false, proofs);

        vm.expectRevert("rewards hash zero");
        rewardManager.getStateOfRewardsAt(voter1, rewardEpochData.id);
    }

    // claim DIRECT and weight based (WNAT)
    function testClaimDirectAndWeightBased1() public {
        _enablePChainStakeMirror();
        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);
        IRewardManager.RewardClaimWithProof[] memory proofs = new IRewardManager.RewardClaimWithProof[](2);
        merkleProof1 = new bytes32[](1);
        merkleProof2 = new bytes32[](1);

        IRewardManager.RewardClaim memory body1 = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 100, IRewardManager.ClaimType.DIRECT);
        IRewardManager.RewardClaim memory body2 = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 200, IRewardManager.ClaimType.WNAT);
        bytes32 leaf1 = keccak256(abi.encode(body1));
        bytes32 leaf2 = keccak256(abi.encode(body2));
        bytes32 merkleRoot = _hashPair(leaf1, leaf2);

        // proof for DIRECT claim
        merkleProof1[0] = leaf2;
        proofs[0] = IRewardManager.RewardClaimWithProof(merkleProof1, body1);

        // proof for WNAT claim
        merkleProof2[0] = leaf1;
        proofs[1] = IRewardManager.RewardClaimWithProof(merkleProof2, body2);

        // contract needs some funds for rewarding
        _fundRewardContract(1000, rewardEpochData.id);

        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);
        _mockRewardsHash(rewardEpochData.id, merkleRoot);

        _mockCalculateBurnFactor(rewardEpochData.id, voter1, 0);

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 1); // DIRECT claim and one weight based claim (WNAT)
        // voter1 balance = 250; vp = 300; he is delegating 100% to himself
        _setWNatData(rewardEpochData.vpBlock);
        _setPChainMirrorData(rewardEpochData.vpBlock);
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
        _enablePChainStakeMirror();
        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);
        IRewardManager.RewardClaimWithProof[] memory proofs = new IRewardManager.RewardClaimWithProof[](0);

        _fundRewardContract(1000, rewardEpochData.id);
        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);
        _mockCalculateBurnFactor(rewardEpochData.id, voter1, 0);

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 1); // DIRECT claim and one weight based claim (WNAT)
        _setWNatData(rewardEpochData.vpBlock);
        _setPChainMirrorData(rewardEpochData.vpBlock);
        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

        // override delegations data from _setWnatData
        address[] memory delegates = new address[](0);
        uint256[] memory bips = new uint256[](0);
        _mockWNatDelegations(voter1, 10, delegates, bips);
        _mockUndelegatedVotePowerOfAt(voter1, rewardEpochData.vpBlock, 250);

        vm.prank(voter1);
        vm.expectRevert("not initialised");
        rewardManager.claim(voter1, payable(voter1), rewardEpochData.id, false, proofs);


        // set proofs and initialised claims
        proofs = new IRewardManager.RewardClaimWithProof[](2);
        merkleProof1 = new bytes32[](1);
        merkleProof2 = new bytes32[](1);

        IRewardManager.RewardClaim memory body1 = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 100, IRewardManager.ClaimType.DIRECT);
        IRewardManager.RewardClaim memory body2 = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 200, IRewardManager.ClaimType.WNAT);
        bytes32 leaf1 = keccak256(abi.encode(body1));
        bytes32 leaf2 = keccak256(abi.encode(body2));
        bytes32 merkleRoot = _hashPair(leaf1, leaf2);
        _mockRewardsHash(rewardEpochData.id, merkleRoot);

        // proof for DIRECT claim
        merkleProof1[0] = leaf2;
        proofs[0] = IRewardManager.RewardClaimWithProof(merkleProof1, body1);

        // proof for WNAT claim
        merkleProof2[0] = leaf1;
        proofs[1] = IRewardManager.RewardClaimWithProof(merkleProof2, body2);

        RewardManager.RewardState[] memory rewardStates =
            rewardManager.getStateOfRewardsAt(voter1, rewardEpochData.id);
        assertEq(rewardStates.length, 2); // WNAT (undelegated VP) and MIRROR

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

    // delegator claims, he is not delegating 100 %
    function testClaimWeightBased3() public {
        testClaimDirectAndWeightBased2();

        // set data for delegator
        address[] memory delegates = new address[](1);
        delegates[0] = voter1;
        uint256[] memory bips = new uint256[](1);
        bips[0] = 2000;
        _mockWNatDelegations(delegator, 10, delegates, bips);
        _mockWNatBalance(delegator, 10, 80);

        bytes20[] memory nodeIds = new bytes20[](1);
        uint256[] memory weights = new uint256[](1);
        nodeIds[0] = nodeId1;
        weights[0] = 30;
        _mockStakes(delegator, 10, nodeIds, weights);

        address[] memory accounts = new address[](1);
        accounts[0] = account1;
        weights[0] = 40;
        _mockCChainStakes(delegator, 10, accounts, weights);

        IRewardManager.RewardClaimWithProof[] memory proofs = new IRewardManager.RewardClaimWithProof[](0);

        _mockUndelegatedVotePowerOfAt(delegator, 10, 64);

        vm.prank(delegator);
        // WNAT rewards; should receive floor(200 * 250 / 300) = 166
        // WNAT rewards; should receive floor[(200 - 166) * 80 * 0.2 / (300 - 250)] = 10
        vm.expectEmit();
        emit RewardClaimed(voter1, delegator, delegator, 0, IRewardManager.ClaimType.WNAT, 10);
        // undelegated voter power
        vm.expectEmit();
        emit RewardClaimed(delegator, delegator, delegator, 0, IRewardManager.ClaimType.WNAT, 0);
        // MIRROR rewards; should receive ceil(300 * 30/400) = 22
        vm.expectEmit();
        emit RewardClaimed(address(nodeId1), delegator, delegator, 0, IRewardManager.ClaimType.MIRROR, 22);
        // CCHAIN rewards; should receive ceil(400 * 40/500) = 400 - 360 = 32
        vm.expectEmit();
        emit RewardClaimed(account1, delegator, delegator, 0, IRewardManager.ClaimType.CCHAIN, 32);
        rewardManager.claim(delegator, payable(delegator), 0, false, proofs);
        // assertEq(delegator.balance, 17 + 38 + 40);
    }

    // claim DIRECT and weight based (WNAT, MIRROR & CCHAIN)
    function testClaimDirectAndWeightBased2() public {
        _enablePChainStakeMirror();
        // enable cChain stake
        vm.prank(governance);
        rewardManager.enableCChainStake();
        assertEq(address(rewardManager.cChainStake()), address(0));
        vm.prank(addressUpdater);
        rewardManager.updateContractAddresses(contractNameHashes, contractAddresses);
        assertEq(address(rewardManager.cChainStake()), mockCChainStake);

        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);
        IRewardManager.RewardClaimWithProof[] memory proofs = new IRewardManager.RewardClaimWithProof[](4);
        merkleProof1 = new bytes32[](2);
        merkleProof2 = new bytes32[](2);
        merkleProof3 = new bytes32[](2);
        merkleProof4 = new bytes32[](2);

        IRewardManager.RewardClaim memory body1 = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 100, IRewardManager.ClaimType.DIRECT);
        IRewardManager.RewardClaim memory body2 = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 200, IRewardManager.ClaimType.WNAT);
        IRewardManager.RewardClaim memory body3 = IRewardManager.RewardClaim(
            rewardEpochData.id, nodeId1, 300, IRewardManager.ClaimType.MIRROR);
        IRewardManager.RewardClaim memory body4 = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(account1), 400, IRewardManager.ClaimType.CCHAIN);
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
        proofs[0] = IRewardManager.RewardClaimWithProof(merkleProof1, body1);

        // proof for WNAT claim
        merkleProof2[0] = hashes[0];
        merkleProof2[1] = hashes[5];
        proofs[1] = IRewardManager.RewardClaimWithProof(merkleProof2, body2);

        // proof for MIRROR claim
        merkleProof3[0] = hashes[3];
        merkleProof3[1] = hashes[4];
        proofs[2] = IRewardManager.RewardClaimWithProof(merkleProof3, body3);

        // proof for CCHAIN claim
        merkleProof4[0] = hashes[2];
        merkleProof4[1] = hashes[4];
        proofs[3] = IRewardManager.RewardClaimWithProof(merkleProof4, body4);

        // contract needs some funds for rewarding
        _fundRewardContract(1000, rewardEpochData.id);

        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);
        _mockRewardsHash(rewardEpochData.id, hashes[6]);

        _mockCalculateBurnFactor(rewardEpochData.id, voter1, 0);

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 3);
        // voter1 balance = 250; vp = 300; he is delegating 100% to himself
        _setWNatData(rewardEpochData.vpBlock);
        // voter1 has 350 weight on node1, which has 400 vp
        _setPChainMirrorData(rewardEpochData.vpBlock);
        // voter1 has 450 weight on account1, which has 500 vp
        _setCChainData(rewardEpochData.vpBlock);
        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

        // get state of rewards - all amounts zero because not yet initialized
        RewardManager.RewardState[] memory rewardStates =
            rewardManager.getStateOfRewardsAt(voter1, rewardEpochData.id);
        assertEq(rewardStates.length, 3);
        assertEq(address(rewardStates[0].beneficiary), voter1);
        assertEq(rewardStates[0].amount, 0);
        assertEq(rewardStates[0].initialised, false);
        assertEq(address(rewardStates[1].beneficiary), address(nodeId1));
        assertEq(rewardStates[1].amount, 0);
        assertEq(rewardStates[1].initialised, false);
        assertEq(address(rewardStates[2].beneficiary), account1);
        assertEq(rewardStates[2].amount, 0);
        assertEq(rewardStates[2].initialised, false);

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

    // claim DIRECT and weight based (WNAT, MIRROR & CCHAIN) for two epochs.
    // In second epoch there is not enough funds on contract for all rewards
    function testClaimDirectAndWeightBased3() public {
        _enablePChainStakeMirror();
        // enable cChain stake
       _enableCChainStake();

        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);
        IRewardManager.RewardClaimWithProof[] memory proofs = new IRewardManager.RewardClaimWithProof[](4);
        merkleProof1 = new bytes32[](2);
        merkleProof2 = new bytes32[](2);
        merkleProof3 = new bytes32[](2);
        merkleProof4 = new bytes32[](2);

        IRewardManager.RewardClaim memory body1 = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 100, IRewardManager.ClaimType.DIRECT);
        IRewardManager.RewardClaim memory body2 = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 200, IRewardManager.ClaimType.WNAT);
        IRewardManager.RewardClaim memory body3 = IRewardManager.RewardClaim(
            rewardEpochData.id, nodeId1, 300, IRewardManager.ClaimType.MIRROR);
        IRewardManager.RewardClaim memory body4 = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(account1), 400, IRewardManager.ClaimType.CCHAIN);
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
        proofs[0] = IRewardManager.RewardClaimWithProof(merkleProof1, body1);

        // proof for WNAT claim
        merkleProof2[0] = hashes[0];
        merkleProof2[1] = hashes[5];
        proofs[1] = IRewardManager.RewardClaimWithProof(merkleProof2, body2);

        // proof for MIRROR claim
        merkleProof3[0] = hashes[3];
        merkleProof3[1] = hashes[4];
        proofs[2] = IRewardManager.RewardClaimWithProof(merkleProof3, body3);

        // proof for CCHAIN claim
        merkleProof4[0] = hashes[2];
        merkleProof4[1] = hashes[4];
        proofs[3] = IRewardManager.RewardClaimWithProof(merkleProof4, body4);

        // contract needs some funds for rewarding
        _fundRewardContract(1000, rewardEpochData.id);

        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);
        _mockRewardsHash(rewardEpochData.id, hashes[6]);

        _mockCalculateBurnFactor(rewardEpochData.id, voter1, 0);

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 3);
        // voter1 balance = 250; vp = 300; he is delegating 100% to himself
        _setWNatData(rewardEpochData.vpBlock);
        // voter1 has 350 weight on node1, which has 400 vp
        _setPChainMirrorData(rewardEpochData.vpBlock);
        // voter1 has 450 weight on account1, which has 500 vp
        _setCChainData(rewardEpochData.vpBlock);
        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

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
        // CCHAIN rewards; should receive floor(400 * 450 / 500) = 360
        vm.expectEmit();
        emit RewardClaimed(account1, voter1, voter1, rewardEpochData.id, body4.claimType, 360);
        rewardManager.claim(voter1, payable(voter1), rewardEpochData.id, false, proofs);
        assertEq(voter1.balance, body1.amount + 166 + 262 + 360);

        // claim for next epoch (1)
        // vp block for epoch 1 was set to 2* vp block for epoch 0 (=20)
        rewardEpochData = RewardEpochData(1, 20);
        proofs = new IRewardManager.RewardClaimWithProof[](4);
        merkleProof1 = new bytes32[](2);
        merkleProof2 = new bytes32[](2);
        merkleProof3 = new bytes32[](2);
        merkleProof4 = new bytes32[](2);

        body1 = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 100, IRewardManager.ClaimType.DIRECT);
        body2 = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 200, IRewardManager.ClaimType.WNAT);
        body3 = IRewardManager.RewardClaim(
            rewardEpochData.id, nodeId1, 300, IRewardManager.ClaimType.MIRROR);
        body4 = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(account1), 400, IRewardManager.ClaimType.CCHAIN);
        hashes = new bytes32[](7);
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
        proofs[0] = IRewardManager.RewardClaimWithProof(merkleProof1, body1);

        // proof for WNAT claim
        merkleProof2[0] = hashes[0];
        merkleProof2[1] = hashes[5];
        proofs[1] = IRewardManager.RewardClaimWithProof(merkleProof2, body2);

        // proof for MIRROR claim
        merkleProof3[0] = hashes[3];
        merkleProof3[1] = hashes[4];
        proofs[2] = IRewardManager.RewardClaimWithProof(merkleProof3, body3);

        // proof for CCHAIN claim
        merkleProof4[0] = hashes[2];
        merkleProof4[1] = hashes[4];
        proofs[3] = IRewardManager.RewardClaimWithProof(merkleProof4, body4);

        _mockRewardsHash(rewardEpochData.id, hashes[6]);
        _mockCalculateBurnFactor(rewardEpochData.id, voter1, 0);
        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 3);
        // voter1 balance = 250; vp = 300; he is delegating 100% to himself
        _setWNatData(rewardEpochData.vpBlock);
        // voter1 has 350 weight on node1, which has 400 vp
        _setPChainMirrorData(rewardEpochData.vpBlock);
        // voter1 has 450 weight on account1, which has 500 vp
        _setCChainData(rewardEpochData.vpBlock);
        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

        //// claim for next epoch (1)
        _mockGetVpBlock(2, rewardEpochData.vpBlock * 2);
        // vp block for epoch 1 was set to 2* vp block for epoch 0 (=20)
        // reward contract has only 500 funds
        _fundRewardContract(500, rewardEpochData.id);
        // move one epoch forward
        _mockGetCurrentEpochId(2);
        vm.prank(voter1);
        // DIRECT rewards
        vm.expectEmit();
        emit RewardClaimed(voter1, voter1, voter1, rewardEpochData.id, body1.claimType, body1.amount);
        // WNAT rewards; should receive floor(200 * 250 / 300) = 166
        vm.expectEmit();
        emit RewardClaimed(voter1, voter1, voter1, rewardEpochData.id, body2.claimType, 166);
        // reward contract had only 500 funds. 100 was already spent for direct claim and
        // 200 was initialized for wNat. Only 200 is left for MIRROR
        // MIRROR rewards; should receive floor(300 * 350 / 400) = 175
        vm.expectEmit();
        emit RewardClaimed(address(nodeId1), voter1, voter1, rewardEpochData.id, body3.claimType, 175);
        // CCHAIN rewards; all 500 were already used for initializations. nothing left for cChain claim
        vm.expectEmit();
        emit RewardClaimed(account1, voter1, voter1, rewardEpochData.id, body4.claimType, 0);
        rewardManager.claim(voter1, payable(voter1), rewardEpochData.id, false, proofs);
        assertEq(voter1.balance, (body1.amount + 166 + 262 + 360) + (body1.amount + 166 + 175));
    }

    // weight based reward are already initialized; delegator claims for himself
    function testClaimWeightBased() public {
        testClaimDirectAndWeightBased2();

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

        IRewardManager.RewardClaimWithProof[] memory proofs = new IRewardManager.RewardClaimWithProof[](0);

        // get state of rewards for delegator
        RewardManager.RewardState[] memory rewardStates = rewardManager.getStateOfRewardsAt(delegator, 0);
        assertEq(rewardStates.length, 3);
        assertEq(address(rewardStates[0].beneficiary), voter1);
        assertEq(rewardStates[0].amount, 34);
        assertEq(rewardStates[0].initialised, true);
        assertEq(address(rewardStates[1].beneficiary), address(nodeId1));
        assertEq(rewardStates[1].amount, 38);
        assertEq(rewardStates[1].initialised, true);
        assertEq(address(rewardStates[2].beneficiary), account1);
        assertEq(rewardStates[2].amount, 40);
        assertEq(rewardStates[2].initialised, true);


        vm.prank(delegator);
        // WNAT rewards; should receive everything that is left (ceil(200 * 50/300) = 34)
        vm.expectEmit();
        emit RewardClaimed(voter1, delegator, delegator, 0, IRewardManager.ClaimType.WNAT, 34);
        // MIRROR rewards; should receive ceil(300 * 50/400) = 38
        vm.expectEmit();
        emit RewardClaimed(address(nodeId1), delegator, delegator, 0, IRewardManager.ClaimType.MIRROR, 38);
        // CCHAIN rewards; should receive ceil(400 * 50/500) = 400 - 360 = 40
        vm.expectEmit();
        emit RewardClaimed(account1, delegator, delegator, 0, IRewardManager.ClaimType.CCHAIN, 40);
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

    function testGetStateOfRewards() public {
        _enablePChainStakeMirror();
        _enableCChainStake();

        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);
        IRewardManager.RewardClaimWithProof[] memory proofs = new IRewardManager.RewardClaimWithProof[](3);
        IRewardManager.RewardClaimWithProof[] memory directProofs = new IRewardManager.RewardClaimWithProof[](2);
        merkleProof1 = new bytes32[](2);
        merkleProof2 = new bytes32[](2);
        merkleProof3 = new bytes32[](2);
        merkleProof4 = new bytes32[](2);

        IRewardManager.RewardClaim memory body1 = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 100, IRewardManager.ClaimType.DIRECT);
        IRewardManager.RewardClaim memory body2 = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 200, IRewardManager.ClaimType.WNAT);
        IRewardManager.RewardClaim memory body3 = IRewardManager.RewardClaim(
            rewardEpochData.id, nodeId1, 300, IRewardManager.ClaimType.MIRROR);
        IRewardManager.RewardClaim memory body4 = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(account1), 400, IRewardManager.ClaimType.CCHAIN);
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
        directProofs[0] = IRewardManager.RewardClaimWithProof(merkleProof1, body1);

        // proof for WNAT claim
        merkleProof2[0] = hashes[0];
        merkleProof2[1] = hashes[5];
        proofs[0] = IRewardManager.RewardClaimWithProof(merkleProof2, body2);

        // proof for MIRROR claim
        merkleProof3[0] = hashes[3];
        merkleProof3[1] = hashes[4];
        proofs[1] = IRewardManager.RewardClaimWithProof(merkleProof3, body3);

        // proof for CCHAIN claim
        merkleProof4[0] = hashes[2];
        merkleProof4[1] = hashes[4];
        proofs[2] = IRewardManager.RewardClaimWithProof(merkleProof4, body4);

        _fundRewardContract(1000, rewardEpochData.id);
        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);
        _mockRewardsHash(rewardEpochData.id, bytes32(0));
        RewardManager.RewardState[][] memory rewardStates = rewardManager.getStateOfRewards(voter1);
        assertEq(rewardStates.length, 0);

        _mockRewardsHash(rewardEpochData.id, hashes[6]);
        _mockCalculateBurnFactor(rewardEpochData.id, voter1, 0);

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 3);
        // voter1 balance = 250; vp = 300; he is delegating 100% to himself
        _setWNatData(rewardEpochData.vpBlock);
        // voter1 has 350 weight on node1, which has 400 vp
        _setPChainMirrorData(rewardEpochData.vpBlock);
        // voter1 has 450 weight on account1, which has 500 vp
        _setCChainData(rewardEpochData.vpBlock);
        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

        // get state of rewards - all amounts zero because not yet initialized
        rewardStates = rewardManager.getStateOfRewards(voter1);
        assertEq(rewardStates.length, 1);
        assertEq(address(rewardStates[0][0].beneficiary), voter1);
        assertEq(rewardStates[0][0].amount, 0);
        assertEq(rewardStates[0][0].initialised, false);
        assertEq(address(rewardStates[0][1].beneficiary), address(nodeId1));
        assertEq(rewardStates[0][1].amount, 0);
        assertEq(rewardStates[0][1].initialised, false);
        assertEq(address(rewardStates[0][2].beneficiary), account1);
        assertEq(rewardStates[0][2].amount, 0);
        assertEq(rewardStates[0][2].initialised, false);

        rewardManager.initialiseWeightBasedClaims(proofs);

        rewardStates = rewardManager.getStateOfRewards(voter1);
        assertEq(rewardStates.length, 1);
        assertEq(address(rewardStates[0][0].beneficiary), voter1);
        assertEq(rewardStates[0][0].amount, 166);
        assertEq(rewardStates[0][0].initialised, true);
        assertEq(address(rewardStates[0][1].beneficiary), address(nodeId1));
        assertEq(rewardStates[0][1].amount, 262);
        assertEq(rewardStates[0][1].initialised, true);
        assertEq(address(rewardStates[0][2].beneficiary), account1);
        assertEq(rewardStates[0][2].amount, 360);
        assertEq(rewardStates[0][2].initialised, true);

        // reward epoch 1
        rewardEpochData = RewardEpochData(1, 100);
        proofs = new IRewardManager.RewardClaimWithProof[](3);
        merkleProof1 = new bytes32[](2);
        merkleProof2 = new bytes32[](2);
        merkleProof3 = new bytes32[](2);
        merkleProof4 = new bytes32[](2);

        body1 = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 50, IRewardManager.ClaimType.FEE);
        body2 = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 100, IRewardManager.ClaimType.WNAT);
        body3 = IRewardManager.RewardClaim(
            rewardEpochData.id, nodeId1, 150, IRewardManager.ClaimType.MIRROR);
        body4 = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(account1), 200, IRewardManager.ClaimType.CCHAIN);
        hashes = new bytes32[](7);
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
        directProofs[1] = IRewardManager.RewardClaimWithProof(merkleProof1, body1);

        // proof for WNAT claim
        merkleProof2[0] = hashes[0];
        merkleProof2[1] = hashes[5];
        proofs[0] = IRewardManager.RewardClaimWithProof(merkleProof2, body2);

        // proof for MIRROR claim
        merkleProof3[0] = hashes[3];
        merkleProof3[1] = hashes[4];
        proofs[1] = IRewardManager.RewardClaimWithProof(merkleProof3, body3);

        // proof for CCHAIN claim
        merkleProof4[0] = hashes[2];
        merkleProof4[1] = hashes[4];
        proofs[2] = IRewardManager.RewardClaimWithProof(merkleProof4, body4);

        // contract needs funds for rewarding
        _fundRewardContract(1000, rewardEpochData.id);

        _mockGetCurrentEpochId(2);
        _mockGetVpBlock(2, 100 * 2);
        _mockRewardsHash(rewardEpochData.id, hashes[6]);
        _mockCalculateBurnFactor(rewardEpochData.id, voter1, 0);

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 3);
        _setWNatData(rewardEpochData.vpBlock);
        _setPChainMirrorData(rewardEpochData.vpBlock);
        _setCChainData(rewardEpochData.vpBlock);
        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

        rewardStates = rewardManager.getStateOfRewards(voter1);
        assertEq(rewardStates.length, 2);
        assertEq(address(rewardStates[0][0].beneficiary), voter1);
        assertEq(rewardStates[0][0].amount, 166);
        assertEq(rewardStates[0][0].initialised, true);
        assertEq(address(rewardStates[0][1].beneficiary), address(nodeId1));
        assertEq(rewardStates[0][1].amount, 262);
        assertEq(rewardStates[0][1].initialised, true);
        assertEq(address(rewardStates[0][2].beneficiary), account1);
        assertEq(rewardStates[0][2].amount, 360);
        assertEq(rewardStates[0][2].initialised, true);
        assertEq(address(rewardStates[1][0].beneficiary), voter1);
        assertEq(rewardStates[1][0].amount, 0);
        assertEq(rewardStates[1][0].initialised, false);
        assertEq(address(rewardStates[0][1].beneficiary), address(nodeId1));
        assertEq(rewardStates[1][1].amount, 0);
        assertEq(rewardStates[1][1].initialised, false);
        assertEq(address(rewardStates[0][2].beneficiary), account1);
        assertEq(rewardStates[1][2].amount, 0);
        assertEq(rewardStates[1][2].initialised, false);

        // initialize claims for epoch 1
        rewardManager.initialiseWeightBasedClaims(proofs);

        rewardStates = rewardManager.getStateOfRewards(voter1);
        assertEq(rewardStates.length, 2);
        assertEq(address(rewardStates[1][0].beneficiary), voter1);
        assertEq(rewardStates[1][0].amount, 83);
        assertEq(rewardStates[1][0].initialised, true);
        assertEq(address(rewardStates[1][1].beneficiary), address(nodeId1));
        assertEq(rewardStates[1][1].amount, 131);
        assertEq(rewardStates[1][1].initialised, true);
        assertEq(address(rewardStates[1][2].beneficiary), account1);
        assertEq(rewardStates[1][2].amount, 180);
        assertEq(rewardStates[1][2].initialised, true);

        proofs = new IRewardManager.RewardClaimWithProof[](0);
        vm.startPrank(voter1);
        // claim for reward epoch 0
        // // DIRECT rewards
        // vm.expectEmit();
        // emit RewardClaimed(voter1, voter1, voter1, rewardEpochData.id, body1.claimType, body1.amount);
        // WNAT rewards; should receive floor(200 * 250 / 300) = 166
        vm.expectEmit();
        emit RewardClaimed(voter1, voter1, voter1, 0, body2.claimType, 166);
        // MIRROR rewards; should receive floor(300 * 350 / 400) = 262
        vm.expectEmit();
        emit RewardClaimed(address(nodeId1), voter1, voter1, 0, body3.claimType, 262);
        // CCHAIN rewards; should receive floor (400 * 450 / 500) = 360
        vm.expectEmit();
        emit RewardClaimed(account1, voter1, voter1, 0, body4.claimType, 360);
        rewardManager.claim(voter1, payable(voter1), 0, false, proofs);
        assertEq(voter1.balance, 166 + 262 + 360);

        // check state of rewards
        rewardStates = rewardManager.getStateOfRewards(voter1);
        assertEq(rewardStates.length, 1);
        assertEq(rewardStates[0][0].amount, 83);
        assertEq(rewardStates[0][0].initialised, true);
        assertEq(address(rewardStates[0][1].beneficiary), address(nodeId1));
        assertEq(rewardStates[0][1].amount, 131);
        assertEq(rewardStates[0][1].initialised, true);
        assertEq(address(rewardStates[0][2].beneficiary), account1);
        assertEq(rewardStates[0][2].amount, 180);
        assertEq(rewardStates[0][2].initialised, true);

        // claim for reward epoch 1
        // WNAT rewards; should receive floor(100 * 250 / 300) = 83
        uint256 balanceBefore = voter1.balance;
        vm.expectEmit();
        emit RewardClaimed(voter1, voter1, voter1, 1, body2.claimType, 83);
        // MIRROR rewards; should receive floor(150 * 350 / 400) = 131
        vm.expectEmit();
        emit RewardClaimed(address(nodeId1), voter1, voter1, 1, body3.claimType, 131);
        // CCHAIN rewards; should receive floor (200 * 450 / 500) = 180
        vm.expectEmit();
        emit RewardClaimed(account1, voter1, voter1, 1, body4.claimType, 180);
        rewardManager.claim(voter1, payable(voter1), 1, false, proofs);
        assertEq(voter1.balance, balanceBefore + 83 + 131 + 180);

        // check state of rewards
        _mockRewardsHash(2, bytes32(0));
        rewardStates = rewardManager.getStateOfRewards(voter1);
        assertEq(rewardStates.length, 0);

        // claim DIRECT and FEE
        // DIRECT reward
        vm.expectEmit();
        emit RewardClaimed(voter1, voter1, voter1, 0, IRewardManager.ClaimType.DIRECT, 100);
        // FEE reward
        vm.expectEmit();
        emit RewardClaimed(voter1, voter1, voter1, 1, IRewardManager.ClaimType.FEE, 50);
        balanceBefore = voter1.balance;
        rewardManager.claim(voter1, payable(voter1), 1, false, directProofs);
        assertEq(voter1.balance, balanceBefore + 100 + 50);
        vm.stopPrank();
    }

    function testInitializeWeightBasedAndAfterClaim() public {
        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);
        IRewardManager.RewardClaimWithProof[] memory proofs = new IRewardManager.RewardClaimWithProof[](1);
        merkleProof1 = new bytes32[](0);

        IRewardManager.RewardClaim memory body1 = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 200, IRewardManager.ClaimType.WNAT);

        bytes32 merkleRoot = keccak256(abi.encode(body1));

        proofs[0] = IRewardManager.RewardClaimWithProof(merkleProof1, body1);

        // contract needs some funds for rewarding
        _fundRewardContract(1000, rewardEpochData.id);

        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);
        _mockRewardsHash(rewardEpochData.id, merkleRoot);

        _mockCalculateBurnFactor(rewardEpochData.id, voter1, 0);

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 1);
        // voter1 balance = 250; vp = 300; he is delegating 100% to himself
        _setWNatData(rewardEpochData.vpBlock);
        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

        RewardManager.UnclaimedRewardState memory state =
            rewardManager.getUnclaimedRewardState(voter1, rewardEpochData.id, IRewardManager.ClaimType.WNAT);
        assertEq(rewardManager.noOfInitialisedWeightBasedClaims(rewardEpochData.id), 0);
        assertEq(state.initialised, false);
        assertEq(state.amount, 0);
        assertEq(state.weight, 0);

        rewardManager.initialiseWeightBasedClaims(proofs);
        state = rewardManager.getUnclaimedRewardState(voter1, rewardEpochData.id, IRewardManager.ClaimType.WNAT);
        assertEq(rewardManager.noOfInitialisedWeightBasedClaims(rewardEpochData.id), 1);
        assertEq(state.initialised, true);
        assertEq(state.amount, 200);
        assertEq(state.weight, 300);

        vm.prank(voter1);
        // WNAT rewards; should receive floor(200 * 250 / 300) = 166
        vm.expectEmit();
        emit RewardClaimed(voter1, voter1, voter1, rewardEpochData.id, body1.claimType, 166);
        rewardManager.claim(voter1, payable(voter1), rewardEpochData.id, false, proofs);
        assertEq(voter1.balance, 166);

        state = rewardManager.getUnclaimedRewardState(voter1, rewardEpochData.id, IRewardManager.ClaimType.WNAT);
        assertEq(state.amount, 200 - 166);
        assertEq(state.weight, 300 - 250);
    }

    // weight based reward are already initialized; two delegators claim
    function testClaimWeightBased2() public {
        testClaimDirectAndWeightBased2();
        address delegator1 = makeAddr("delegator1");
        address delegator2 = makeAddr("delegator2");

        // set data for delegator
        address[] memory delegates = new address[](1);
        delegates[0] = voter1;
        uint256[] memory bips = new uint256[](1);
        bips[0] = 10000;
        _mockWNatDelegations(delegator1, 10, delegates, bips);
        _mockWNatBalance(delegator1, 10, 25);
        _mockWNatDelegations(delegator2, 10, delegates, bips);
        _mockWNatBalance(delegator2, 10, 25);

        bytes20[] memory nodeIds = new bytes20[](1);
        uint256[] memory weights = new uint256[](1);
        nodeIds[0] = nodeId1;
        weights[0] = 50;
        _mockStakes(delegator1, 10, nodeIds, weights);
        bytes20[] memory nodeIds1 = new bytes20[](0);
        uint256[] memory weights1 = new uint256[](0);
        // nodeIds = new bytes20[](0);
        // weights = new uint256[](0);
        _mockStakes(delegator2, 10, nodeIds1, weights1);

        address[] memory accounts = new address[](1);
        accounts[0] = account1;
        weights[0] = 50;
        _mockCChainStakes(delegator1, 10, accounts, weights);
        accounts = new address[](0);
        _mockCChainStakes(delegator2, 10, accounts, weights);

        IRewardManager.RewardClaimWithProof[] memory proofs = new IRewardManager.RewardClaimWithProof[](0);

        vm.prank(delegator1);
        // WNAT rewards; should receive (200 - 166) * 25 / (300 - 250) = 17
        vm.expectEmit();
        emit RewardClaimed(voter1, delegator1, delegator1, 0, IRewardManager.ClaimType.WNAT, 17);
        // MIRROR rewards; should receive ceil(300 * 50/400) = 38
        vm.expectEmit();
        emit RewardClaimed(address(nodeId1), delegator1, delegator1, 0, IRewardManager.ClaimType.MIRROR, 38);
        // CCHAIN rewards; should receive ceil(400 * 50/500) = 400 - 360 = 40
        vm.expectEmit();
        emit RewardClaimed(account1, delegator1, delegator1, 0, IRewardManager.ClaimType.CCHAIN, 40);
        rewardManager.claim(delegator1, payable(delegator1), 0, false, proofs);
        assertEq(delegator1.balance, 17 + 38 + 40);

        vm.prank(delegator2);
        vm.expectEmit();
        // WNAT rewards; should receive what is left (= 17)
        emit RewardClaimed(voter1, delegator2, delegator2, 0, IRewardManager.ClaimType.WNAT, 17);
        rewardManager.claim(delegator2, payable(delegator2), 0, false, proofs);
        assertEq(delegator2.balance, 17);
    }

    // reward weight > unclaimed weight
    function testClaimRevertRewardWeightTooLarge() public {
        testClaimDirectAndWeightBased2();

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

        IRewardManager.RewardClaimWithProof[] memory proofs = new IRewardManager.RewardClaimWithProof[](0);

        vm.prank(delegator);
        vm.expectRevert();
        rewardManager.claim(delegator, payable(delegator), 0, false, proofs);
    }

    function testClaimRevertNotInitialised() public {
        _enablePChainStakeMirror();
        _enableCChainStake();
        _fundRewardContract(1000, 0);
        vm.startPrank(governance);
        rewardManager.enableClaims();
        rewardManager.activate();
        vm.stopPrank();
        _mockGetCurrentEpochId(1);
        _mockGetVpBlock(1, 20);
        _mockNoOfWeightBasedClaims(0, 3);
        _mockGetVpBlock(0, 10);

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

        IRewardManager.RewardClaimWithProof[] memory proofs = new IRewardManager.RewardClaimWithProof[](0);

        vm.startPrank(delegator);
        vm.expectRevert("not initialised"); // WNAT
        rewardManager.claim(delegator, payable(delegator), 0, false, proofs);

        // _mockWNatBalance(delegator, 10, 0);
        _mockUndelegatedVotePowerOfAt(delegator, 10, 10);
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
        IRewardManager.RewardClaimWithProof[] memory proofs = new IRewardManager.RewardClaimWithProof[](1);
        IRewardManager.RewardClaim memory body = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 100, IRewardManager.ClaimType.DIRECT);
        IRewardManager.RewardClaimWithProof memory proof = IRewardManager.RewardClaimWithProof(
            merkleProof, body);
        proofs[0] = proof;
        bytes32 leaf1 = keccak256(abi.encode(body));
        bytes32 merkleRoot = leaf1;

        // contract needs some funds for rewarding
        _fundRewardContract(50, rewardEpochData.id);

        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);
        _mockRewardsHash(rewardEpochData.id, merkleRoot);

        _mockCalculateBurnFactor(rewardEpochData.id, voter1, 0);

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 0); // only DIRECT claim
        _setWNatData(rewardEpochData.vpBlock);
        _setPChainMirrorData(rewardEpochData.vpBlock);
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
        IRewardManager.RewardClaimWithProof[] memory proofs = new IRewardManager.RewardClaimWithProof[](1);
        IRewardManager.RewardClaim memory body = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 100, IRewardManager.ClaimType.FEE);
        IRewardManager.RewardClaimWithProof memory proof = IRewardManager.RewardClaimWithProof(
            merkleProof, body);
        proofs[0] = proof;
        bytes32 leaf1 = keccak256(abi.encode(body));
        bytes32 merkleRoot = leaf1;

        // contract needs some funds for rewarding
        _fundRewardContract(1000, rewardEpochData.id);

        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);
        _mockRewardsHash(rewardEpochData.id, merkleRoot);

        _mockCalculateBurnFactor(rewardEpochData.id, voter1, 100000); // 100k PPM = 10 %

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 0); // only FEE claim
        _setWNatData(rewardEpochData.vpBlock);
        _setPChainMirrorData(rewardEpochData.vpBlock);
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
        IRewardManager.RewardClaimWithProof[] memory proofs = new IRewardManager.RewardClaimWithProof[](1);
        IRewardManager.RewardClaim memory body = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 100, IRewardManager.ClaimType.FEE);
        IRewardManager.RewardClaimWithProof memory proof = IRewardManager.RewardClaimWithProof(
            merkleProof, body);
        proofs[0] = proof;
        bytes32 leaf1 = keccak256(abi.encode(body));
        bytes32 merkleRoot = keccak256(abi.encode(leaf1)); // wrong merkle root

        // contract needs some funds for rewarding
        _fundRewardContract(1000, rewardEpochData.id);

        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);
        _mockRewardsHash(rewardEpochData.id, merkleRoot);

        _mockCalculateBurnFactor(rewardEpochData.id, voter1, 0);

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 0); // only FEE claim
        _setWNatData(rewardEpochData.vpBlock);
        _setPChainMirrorData(rewardEpochData.vpBlock);
        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

        vm.prank(voter1);
        vm.expectRevert("merkle proof invalid");
        rewardManager.claim(voter1, payable(voter1), rewardEpochData.id, false, proofs);
    }

    function testClaimWeightRevertInvalidProof() public {
        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);

        bytes32[] memory merkleProof = new bytes32[](0);
        IRewardManager.RewardClaimWithProof[] memory proofs = new IRewardManager.RewardClaimWithProof[](1);
        IRewardManager.RewardClaim memory body = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 100, IRewardManager.ClaimType.WNAT);
        IRewardManager.RewardClaimWithProof memory proof = IRewardManager.RewardClaimWithProof(
            merkleProof, body);
        proofs[0] = proof;
        bytes32 leaf1 = keccak256(abi.encode(body));
        bytes32 merkleRoot = keccak256(abi.encode(leaf1)); // wrong merkle root

        // contract needs some funds for rewarding
        _fundRewardContract(1000, rewardEpochData.id);

        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);
        _mockRewardsHash(rewardEpochData.id, merkleRoot);

        _mockCalculateBurnFactor(rewardEpochData.id, voter1, 0);

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 0); // only FEE claim
        _setWNatData(rewardEpochData.vpBlock);
        _setPChainMirrorData(rewardEpochData.vpBlock);
        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

        vm.prank(voter1);
        vm.expectRevert("merkle proof invalid");
        rewardManager.claim(voter1, payable(voter1), rewardEpochData.id, false, proofs);
    }

    function testClaimWeightRevertEpochExpired() public {
        vm.prank(governance);
        _mockGetCurrentEpochId(10);
        _mockRewardEpochIdToExpireNext(15);
        rewardManager.setInitialRewardData();
        RewardEpochData memory rewardEpochData = RewardEpochData(16, 10);

        bytes32[] memory merkleProof = new bytes32[](0);
        IRewardManager.RewardClaimWithProof[] memory proofs = new IRewardManager.RewardClaimWithProof[](1);
        // epoch 13 is expired
        IRewardManager.RewardClaim memory body = IRewardManager.RewardClaim(
            13, bytes20(voter1), 100, IRewardManager.ClaimType.DIRECT);
        IRewardManager.RewardClaimWithProof memory proof = IRewardManager.RewardClaimWithProof(
            merkleProof, body);
        proofs[0] = proof;
        bytes32 leaf1 = keccak256(abi.encode(body));
        bytes32 merkleRoot = leaf1;

        _fundRewardContract(1000, rewardEpochData.id);

        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);
        _mockRewardsHash(rewardEpochData.id, merkleRoot);

        _mockCalculateBurnFactor(rewardEpochData.id, voter1, 0);

        _mockNoOfWeightBasedClaims(rewardEpochData.id, 0);
        _setWNatData(rewardEpochData.vpBlock);
        _setPChainMirrorData(rewardEpochData.vpBlock);
        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

        vm.prank(voter1);
        vm.expectRevert("reward epoch expired");
        rewardManager.claim(voter1, payable(voter1), rewardEpochData.id, false, proofs);
    }

    function testClaimRevertWrongBeneficiary() public {
        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);

        bytes32[] memory merkleProof = new bytes32[](0);
        IRewardManager.RewardClaimWithProof[] memory proofs = new IRewardManager.RewardClaimWithProof[](1);
        IRewardManager.RewardClaim memory body = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 100, IRewardManager.ClaimType.FEE);
        IRewardManager.RewardClaimWithProof memory proof = IRewardManager.RewardClaimWithProof(
            merkleProof, body);
        proofs[0] = proof;
        bytes32 leaf1 = keccak256(abi.encode(body));
        bytes32 merkleRoot = keccak256(abi.encode(leaf1)); // wrong merkle root

        // contract needs some funds for rewarding
        _fundRewardContract(1000, rewardEpochData.id);

        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);
        _mockRewardsHash(rewardEpochData.id, merkleRoot);

        _mockCalculateBurnFactor(rewardEpochData.id, voter1, 0);

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 0); // only FEE claim
        _setWNatData(rewardEpochData.vpBlock);
        _setPChainMirrorData(rewardEpochData.vpBlock);
        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

        vm.prank(voter2);
        vm.expectRevert("wrong beneficiary");
        rewardManager.claim(voter2, payable(voter1), rewardEpochData.id, false, proofs);
    }

    function testClaimAndWrap() public {
        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);

        bytes32[] memory merkleProof = new bytes32[](0);
        IRewardManager.RewardClaimWithProof[] memory proofs = new IRewardManager.RewardClaimWithProof[](1);
        IRewardManager.RewardClaim memory body = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 100, IRewardManager.ClaimType.FEE);
        IRewardManager.RewardClaimWithProof memory proof = IRewardManager.RewardClaimWithProof(
            merkleProof, body);
        proofs[0] = proof;
        bytes32 leaf1 = keccak256(abi.encode(body));
        bytes32 merkleRoot = leaf1; // wrong merkle root

        // contract needs some funds for rewarding
        _fundRewardContract(1000, rewardEpochData.id);

        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);
        _mockRewardsHash(rewardEpochData.id, merkleRoot);

        _mockCalculateBurnFactor(rewardEpochData.id, voter1, 0);

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 0); // only FEE claim
        _setWNatData(rewardEpochData.vpBlock);
        _setPChainMirrorData(rewardEpochData.vpBlock);
        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

        vm.prank(voter1);
        vm.expectEmit();
        emit RewardClaimed(voter1, voter1, voter1, rewardEpochData.id, body.claimType, body.amount);
        rewardManager.claim(voter1, payable(voter1), rewardEpochData.id, true, proofs);
        assertEq(voter1.balance, 0);
        assertEq(mockWNat.balance, body.amount);
    }

    function testClaimRevertNotClaimable() public {
        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);
        IRewardManager.RewardClaimWithProof[] memory proofs = new IRewardManager.RewardClaimWithProof[](0);

        _fundRewardContract(1000, rewardEpochData.id);
        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);

        vm.prank(voter1);
        vm.expectRevert("not claimable");
        // epoch > current epoch
        rewardManager.claim(voter1, payable(voter1), 3, false, proofs);

        vm.expectRevert("not claimable");
        rewardManager.getStateOfRewardsAt(voter1, 3);
    }

    function testClaimRevertZeroRecipient() public {
        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);
        IRewardManager.RewardClaimWithProof[] memory proofs = new IRewardManager.RewardClaimWithProof[](0);

        _fundRewardContract(1000, rewardEpochData.id);
        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);

        vm.prank(voter1);
        vm.expectRevert("recipient zero");
        rewardManager.claim(voter1, payable(address(0)), 0, false, proofs);
    }

    function testClaimRevertTransferFailed() public {
        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);

        bytes32[] memory merkleProof = new bytes32[](0);
        IRewardManager.RewardClaimWithProof[] memory proofs = new IRewardManager.RewardClaimWithProof[](1);
        IRewardManager.RewardClaim memory body = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 100, IRewardManager.ClaimType.DIRECT);
        IRewardManager.RewardClaimWithProof memory proof = IRewardManager.RewardClaimWithProof(
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

        _mockCalculateBurnFactor(rewardEpochData.id, voter1, 0);

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 0); // only DIRECT claim
        _setWNatData(rewardEpochData.vpBlock);
        _setPChainMirrorData(rewardEpochData.vpBlock);
        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

        // transfer of reward to voter failed
        vm.mockCallRevert(
            voter1,
            abi.encode(),
            abi.encode()
        );

        vm.prank(voter1);
        vm.expectRevert("transfer failed");
        rewardManager.claim(voter1, payable(voter1), rewardEpochData.id, false, proofs);
    }

    // claim weight based (wNat)  - delegating to two delegators
    function testClaimWNatTwoDelegations() public {
        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);
        IRewardManager.RewardClaimWithProof[] memory proofs = new IRewardManager.RewardClaimWithProof[](2);
        merkleProof1 = new bytes32[](1);
        merkleProof2 = new bytes32[](1);

        IRewardManager.RewardClaim memory body1 = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 100, IRewardManager.ClaimType.WNAT);
        IRewardManager.RewardClaim memory body2 = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter2), 200, IRewardManager.ClaimType.WNAT);
        bytes32 leaf1 = keccak256(abi.encode(body1));
        bytes32 leaf2 = keccak256(abi.encode(body2));
        bytes32 merkleRoot = _hashPair(leaf1, leaf2);

        // proof for the first WNAT claim
        merkleProof1[0] = leaf2;
        proofs[0] = IRewardManager.RewardClaimWithProof(merkleProof1, body1);

        // proof for the second WNAT claim
        merkleProof2[0] = leaf1;
        proofs[1] = IRewardManager.RewardClaimWithProof(merkleProof2, body2);

        // contract needs some funds for rewarding
        _fundRewardContract(300, rewardEpochData.id);

        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);
        _mockRewardsHash(rewardEpochData.id, merkleRoot);
        _mockCalculateBurnFactor(rewardEpochData.id, voter1, 0);

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 2);

        address[] memory delegates = new address[](2);
        delegates[0] = voter1;
        delegates[1] = voter2;
        uint256[] memory bips = new uint256[](2);
        bips[0] = 7000;
        bips[1] = 3000;
        _mockWNatDelegations(delegator, rewardEpochData.vpBlock, delegates, bips);
        _mockWNatBalance(delegator, rewardEpochData.vpBlock, 250);
        _mockWNatVp(voter1, rewardEpochData.vpBlock, 300);
        _mockWNatVp(voter2, rewardEpochData.vpBlock, 400);

        _setZeroStakes(delegator, rewardEpochData.vpBlock);

        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

        vm.prank(delegator);
        // first WNAT claim reward; should receive floor(250 * 0.7 / 300 * 100) = 58
        vm.expectEmit();
        emit RewardClaimed(voter1, delegator, recipient, rewardEpochData.id, body1.claimType, 58);
        // second WNAT claim reward; should receive floor(250 * 0.3 / 400 * 200) = 37
        vm.expectEmit();
        emit RewardClaimed(voter2, delegator, recipient, rewardEpochData.id, body2.claimType, 37);
        rewardManager.claim(delegator, payable(recipient), rewardEpochData.id, false, proofs);
        assertEq(recipient.balance, 58 + 37);
        assertEq(rewardManager.noOfInitialisedWeightBasedClaims(rewardEpochData.id), 2);
    }

    //// auto claim tests
    function testAutoClaimRevertNotClaimable() public {
        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);
        IRewardManager.RewardClaimWithProof[] memory proofs = new IRewardManager.RewardClaimWithProof[](0);

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
        _enablePChainStakeMirror();
        _enableCChainStake();

        rewardOwners = new address[](2);
        rewardOwners[0] = makeAddr("rewardOwner1");
        rewardOwners[1] = makeAddr("rewardOwner2");
        uint256 executorFee = 1; // 1wei
        _mockGetAutoClaimAddressesAndExecutorFee(voter1, rewardOwners, rewardOwners, executorFee);

        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);
        IRewardManager.RewardClaimWithProof[] memory proofs = new IRewardManager.RewardClaimWithProof[](4);
        merkleProof1 = new bytes32[](2);
        merkleProof2 = new bytes32[](2);
        merkleProof3 = new bytes32[](2);
        merkleProof4 = new bytes32[](2);

        IRewardManager.RewardClaim memory body1 = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 100, IRewardManager.ClaimType.DIRECT);
        IRewardManager.RewardClaim memory body2 = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 200, IRewardManager.ClaimType.WNAT);
        IRewardManager.RewardClaim memory body3 = IRewardManager.RewardClaim(
            rewardEpochData.id, nodeId1, 300, IRewardManager.ClaimType.MIRROR);
        IRewardManager.RewardClaim memory body4 = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(account1), 400, IRewardManager.ClaimType.CCHAIN);
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
        proofs[0] = IRewardManager.RewardClaimWithProof(merkleProof1, body1);

        // proof for WNAT claim
        merkleProof2[0] = hashes[0];
        merkleProof2[1] = hashes[5];
        proofs[1] = IRewardManager.RewardClaimWithProof(merkleProof2, body2);

        // proof for MIRROR claim
        merkleProof3[0] = hashes[3];
        merkleProof3[1] = hashes[4];
        proofs[2] = IRewardManager.RewardClaimWithProof(merkleProof3, body3);

        // proof for CCHAIN claim
        merkleProof4[0] = hashes[2];
        merkleProof4[1] = hashes[4];
        proofs[3] = IRewardManager.RewardClaimWithProof(merkleProof4, body4);

        _fundRewardContract(1000, rewardEpochData.id);
        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);
        _mockRewardsHash(rewardEpochData.id, hashes[6]);
        _mockCalculateBurnFactor(rewardEpochData.id, voter1, 0);

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 3);

        _setWNatData(rewardEpochData.vpBlock);
        _setWNatDataRewardOwners(rewardOwners, false);

        _setPChainMirrorData(rewardEpochData.vpBlock);
        _setPChainMirrorDataRewardOwners(rewardOwners);

        _setCChainData(rewardEpochData.vpBlock);
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
        _enablePChainStakeMirror();
        _enableCChainStake();

        rewardOwners = new address[](2);
        rewardOwners[0] = makeAddr("rewardOwner1");
        rewardOwners[1] = makeAddr("rewardOwner2");
        address[] memory pdas = new address[](2);
        pdas[0] = makeAddr("pda1");
        pdas[1] = makeAddr("pda2");

        uint256 executorFee = 1; // 1wei
        _mockGetAutoClaimAddressesAndExecutorFee(voter1, rewardOwners, pdas, executorFee);

        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);
        IRewardManager.RewardClaimWithProof[] memory proofs = new IRewardManager.RewardClaimWithProof[](4);
        merkleProof1 = new bytes32[](2);
        merkleProof2 = new bytes32[](2);
        merkleProof3 = new bytes32[](2);
        merkleProof4 = new bytes32[](2);

        IRewardManager.RewardClaim memory body1 = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 100, IRewardManager.ClaimType.DIRECT);
        IRewardManager.RewardClaim memory body2 = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 200, IRewardManager.ClaimType.WNAT);
        IRewardManager.RewardClaim memory body3 = IRewardManager.RewardClaim(
            rewardEpochData.id, nodeId1, 300, IRewardManager.ClaimType.MIRROR);
        IRewardManager.RewardClaim memory body4 = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(account1), 400, IRewardManager.ClaimType.CCHAIN);
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
        proofs[0] = IRewardManager.RewardClaimWithProof(merkleProof1, body1);

        // proof for WNAT claim
        merkleProof2[0] = hashes[0];
        merkleProof2[1] = hashes[5];
        proofs[1] = IRewardManager.RewardClaimWithProof(merkleProof2, body2);

        // proof for MIRROR claim
        merkleProof3[0] = hashes[3];
        merkleProof3[1] = hashes[4];
        proofs[2] = IRewardManager.RewardClaimWithProof(merkleProof3, body3);

        // proof for CCHAIN claim
        merkleProof4[0] = hashes[2];
        merkleProof4[1] = hashes[4];
        proofs[3] = IRewardManager.RewardClaimWithProof(merkleProof4, body4);

        _fundRewardContract(1000, rewardEpochData.id);
        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);
        _mockRewardsHash(rewardEpochData.id, hashes[6]);
        _mockCalculateBurnFactor(rewardEpochData.id, voter1, 0);

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 3);

        _setWNatData(rewardEpochData.vpBlock);
        _setWNatDataRewardOwners(rewardOwners, false);
        _setWNatDataRewardOwners(pdas, true);

        _setPChainMirrorData(rewardEpochData.vpBlock);
        _setPChainMirrorDataRewardOwners(rewardOwners);

        _setCChainData(rewardEpochData.vpBlock);
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
        IRewardManager.RewardClaimWithProof[] memory proofs = new IRewardManager.RewardClaimWithProof[](1);
        IRewardManager.RewardClaim memory body = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 200, IRewardManager.ClaimType.WNAT);
        IRewardManager.RewardClaimWithProof memory proof = IRewardManager.RewardClaimWithProof(
            merkleProof, body);
        proofs[0] = proof;

        bytes32 merkleRoot = keccak256(abi.encode(body));

        _fundRewardContract(1000, rewardEpochData.id);
        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);
        _mockRewardsHash(rewardEpochData.id, merkleRoot);
        _mockCalculateBurnFactor(rewardEpochData.id, voter1, 0);

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 1);

        _setWNatData(rewardEpochData.vpBlock);
        _setWNatDataRewardOwners(rewardOwners, false);

        _setPChainMirrorData(rewardEpochData.vpBlock);
        _setPChainMirrorDataRewardOwners(rewardOwners);

        _setCChainData(rewardEpochData.vpBlock);
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
        IRewardManager.RewardClaimWithProof[] memory proofs = new IRewardManager.RewardClaimWithProof[](1);
        IRewardManager.RewardClaim memory body = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 100, IRewardManager.ClaimType.FEE);
        IRewardManager.RewardClaimWithProof memory proof = IRewardManager.RewardClaimWithProof(
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

        _mockCalculateBurnFactor(rewardEpochData.id, voter1, 100000);

        _mockNoOfWeightBasedClaims(rewardEpochData.id, 0);
        _setWNatData(rewardEpochData.vpBlock);
        _setPChainMirrorData(rewardEpochData.vpBlock);
        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

        vm.prank(voter1);
        rewardManager.claim(voter1, payable(voter1), rewardEpochData.id, false, proofs);

        vm.startPrank(rewardOffersManagers[0]);
        rewardManager.addDailyAuthorizedInflation(15);
        rewardManager.receiveRewards{value: 800} (1, true);
        vm.expectRevert("reward epoch id in the past");
        rewardManager.receiveRewards{value: 700} (0, true);
        vm.stopPrank();
        vm.expectRevert("only reward offers manager");
        rewardManager.receiveRewards{value: 600} (0, true);


        (uint256 locked, uint256 inflation, uint256 totalClaimed) = rewardManager.getTokenPoolSupplyData();
        assertEq(locked, 1000 + 800 - 800);
        assertEq(inflation, 15);
        assertEq(totalClaimed, 90 + 10);
        (uint256 received, uint256 claimed, uint256 burned, uint256 inflationAuth, uint256 inflationRec) =
            rewardManager.getTotals();
        assertEq(received, 1000 + 800);
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
        IRewardManager.RewardClaimWithProof[] memory proofs = new IRewardManager.RewardClaimWithProof[](1);
        IRewardManager.RewardClaim memory body = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 100, IRewardManager.ClaimType.FEE);
        IRewardManager.RewardClaimWithProof memory proof = IRewardManager.RewardClaimWithProof(
            merkleProof, body);
        proofs[0] = proof;
        bytes32 leaf1 = keccak256(abi.encode(body));
        bytes32 merkleRoot = leaf1;

        _fundRewardContract(1000, rewardEpochData.id);
        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);
        _mockRewardsHash(rewardEpochData.id, merkleRoot);
        _mockCalculateBurnFactor(rewardEpochData.id, voter1, 0);
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 0);
        _setWNatData(rewardEpochData.vpBlock);
        _setPChainMirrorData(rewardEpochData.vpBlock);
        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

        assertEq(rewardManager.getNextClaimableRewardEpochId(voter1), 0);
        vm.prank(voter1);
        rewardManager.claim(voter1, payable(voter1), rewardEpochData.id, false, proofs);
        assertEq(rewardManager.getNextClaimableRewardEpochId(voter1), 1);

        RewardManager rewardManager2 = new RewardManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            address(0)
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
        assertEq(rewardManager2.getNextClaimableRewardEpochId(voter1), 123);
    }

    function testGetEpochsWithClaimableRewards() public {
        _mockGetCurrentEpochId(4);
        vm.prank(governance);
        rewardManager.enableClaims(); // also sets firstClaimableRewardEpochId (= min claimable epoch id) to 4
        _mockRewardsHash(4, bytes32(0));
        vm.expectRevert("no epoch with claimable rewards");
        rewardManager.getRewardEpochIdsWithClaimableRewards();

        // sets rewards hash for all epoch of to current
        _mockGetCurrentEpochId(13);
        for (uint24 i = 4; i < 14; i++) {
            _mockRewardsHash(i, bytes32("rewards hash"));
        }
        vm.prank(governance);
        (uint24 startId, uint24 endId) = rewardManager.getRewardEpochIdsWithClaimableRewards();
        assertEq(startId, 4);
        assertEq(endId, 13 - 1);
    }

    function testGetCleanupBlockNumber() public {
        vm.mockCall(
            mockWNat,
            abi.encodeWithSelector(bytes4(keccak256("cleanupBlockNumber()"))),
            abi.encode(1234)
        );
        assertEq(rewardManager.cleanupBlockNumber(), 1234);
    }

    function testSetNewRewardManagerRevert() public {
        vm.startPrank(governance);
        vm.expectRevert("address zero");
        rewardManager.setNewRewardManager(address(0));

        rewardManager.setNewRewardManager(makeAddr("newRewardManager"));
        assertEq(rewardManager.newRewardManager(), makeAddr("newRewardManager"));

        vm.expectRevert("already set");
        rewardManager.setNewRewardManager(makeAddr("newRewardManager1"));
        vm.stopPrank();
    }

    function testSetInitialRewardDataRevert() public {
        vm.startPrank(governance);
        _mockGetCurrentEpochId(100);
        _mockRewardEpochIdToExpireNext(90);
        rewardManager.setInitialRewardData();
        assertEq(rewardManager.getInitialRewardEpochId(), 100);
        assertEq(rewardManager.getRewardEpochIdToExpireNext(), 90);

        vm.expectRevert("not initial state");
        rewardManager.setInitialRewardData();
        vm.stopPrank();
    }

    function testCloseExpiredRewardEpoch() public {
        RewardManager oldRewardManager = new RewardManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            address(0)
        );
        vm.prank(addressUpdater);
        oldRewardManager.updateContractAddresses(contractNameHashes, contractAddresses);

        rewardManager = new RewardManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            address(oldRewardManager)
        );
        vm.prank(addressUpdater);
        rewardManager.updateContractAddresses(contractNameHashes, contractAddresses);

        RewardManager newRewardManager = new RewardManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            address(0)
        );

        _mockGetCurrentEpochId(100);
        _mockRewardEpochIdToExpireNext(90);

        vm.startPrank(governance);
        rewardManager.setInitialRewardData();
        rewardManager.setNewRewardManager(address(newRewardManager));
        vm.stopPrank();

        // try to close expired epoch - revert wrong address
        vm.expectRevert("only managers");
        rewardManager.closeExpiredRewardEpoch(91);

        vm.prank(address(newRewardManager));
        // try to close expired epoch - revert epoch id != next to expire
        vm.expectRevert("wrong epoch id");
        rewardManager.closeExpiredRewardEpoch(91);

        // set new reward manager
        vm.startPrank(governance);
        oldRewardManager.setNewRewardManager(address(rewardManager));
        _mockRewardEpochIdToExpireNext(90);
        oldRewardManager.setInitialRewardData();
        vm.stopPrank();

        // close expired epoch and burn everything that was not spent on rewards which is whole 1000
        _fundRewardContract(1000, 90);
        vm.startPrank(address(newRewardManager));
        vm.expectEmit();
        emit RewardClaimsExpired(90);
        rewardManager.closeExpiredRewardEpoch(90);
        assertEq(BURN_ADDRESS.balance, 1000);
        assertEq(rewardManager.getRewardEpochIdToExpireNext(), 91);

        // close epoch 91; no reward for that epoch -> nothing to burn
        vm.expectEmit();
        emit RewardClaimsExpired(91);
        rewardManager.closeExpiredRewardEpoch(91);
        assertEq(BURN_ADDRESS.balance, 1000);

        vm.stopPrank();

        // fund old contract for epoch 92
        vm.prank(governance);
        rewardOffersManagers = new address[](1);
        rewardOffersManagers[0] = makeAddr("rewardOffersManager");
        oldRewardManager.setRewardOffersManagerList(rewardOffersManagers);
        vm.deal(rewardOffersManagers[0], 1 ether);
        vm.prank(rewardOffersManagers[0]);
        oldRewardManager.receiveRewards{value: 300} (92, false);

        // fund current contract for epoch 92
        _fundRewardContract(500, 92);

        // close epoch 92 on current and old reward managers
        vm.prank(address(newRewardManager));
        vm.expectEmit();
        emit RewardClaimsExpired(92);
        vm.expectEmit();
        emit RewardClaimsExpired(92);
        rewardManager.closeExpiredRewardEpoch(92);
        assertEq(BURN_ADDRESS.balance, 1000 + 500 + 300);
        assertEq(rewardManager.getRewardEpochIdToExpireNext(), 93);
        assertEq(oldRewardManager.getRewardEpochIdToExpireNext(), 93);
    }

    function testClaimBurnAndClose() public {
        RewardManager newRewardManager = new RewardManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            address(0)
        );

        _mockGetCurrentEpochId(89);
        _mockRewardEpochIdToExpireNext(90);

        vm.startPrank(governance);
        rewardManager.setInitialRewardData();
        rewardManager.setNewRewardManager(address(newRewardManager));
        vm.stopPrank();

        RewardEpochData memory rewardEpochData = RewardEpochData(90, 10);

        bytes32[] memory merkleProof = new bytes32[](0);
        IRewardManager.RewardClaimWithProof[] memory proofs = new IRewardManager.RewardClaimWithProof[](1);
        IRewardManager.RewardClaim memory body = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 100, IRewardManager.ClaimType.FEE);
        IRewardManager.RewardClaimWithProof memory proof = IRewardManager.RewardClaimWithProof(
            merkleProof, body);
        proofs[0] = proof;
        bytes32 leaf1 = keccak256(abi.encode(body));
        bytes32 merkleRoot = leaf1;

        // contract needs some funds for rewarding
        _fundRewardContract(1000, rewardEpochData.id);

        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);
        _mockRewardsHash(rewardEpochData.id, merkleRoot);

        _mockCalculateBurnFactor(rewardEpochData.id, voter1, 100000); // 100k PPM = 10 %

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 0); // only FEE claim
        _setWNatData(rewardEpochData.vpBlock);
        _setPChainMirrorData(rewardEpochData.vpBlock);
        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

        vm.prank(voter1);
        // 10 % * 100 should be burned
        rewardManager.claim(voter1, payable(voter1), rewardEpochData.id, false, proofs);
        assertEq(voter1.balance, 90);
        assertEq(BURN_ADDRESS.balance, 10);


        // close epoch 90; should burn 1000 - 90 - 10 = 900
        vm.prank(address(newRewardManager));
        vm.expectEmit();
        emit RewardClaimsExpired(90);
        rewardManager.closeExpiredRewardEpoch(90);
        assertEq(BURN_ADDRESS.balance, 900 + 10);
    }



    //// helper functions
    function _mockGetCurrentEpochId(uint256 _epochId) private {
        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(IFlareSystemsManager.getCurrentRewardEpochId.selector),
            abi.encode(_epochId)
        );
    }

    function _mockGetVpBlock(uint256 _epochId, uint256 _vpBlock) private {
        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(IFlareSystemsManager.getVotePowerBlock.selector, _epochId),
            abi.encode(_vpBlock)
        );
    }

    function _mockRewardsHash(uint256 _epochId, bytes32 _hash) private {
        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(bytes4(keccak256("rewardsHash(uint256)")), _epochId),
            abi.encode(_hash)
        );
    }

    function _mockCalculateBurnFactor(uint256 _epochId, address _user, uint256 _burnFactor) private {
        vm.mockCall(
            mockFlareSystemsCalculator,
            abi.encodeWithSelector(IIFlareSystemsCalculator.calculateBurnFactorPPM.selector, _epochId, _user),
            abi.encode(_burnFactor)
        );
    }

    function _mockNoOfWeightBasedClaims(uint256 _epoch, uint256 _noOfClaims) private {
        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(bytes4(keccak256("noOfWeightBasedClaims(uint256)")), _epoch),
            abi.encode(_noOfClaims)
        );
    }

    function _mockWNatBalance(address _user, uint256 _vpBlock, uint256 _balance) private {
        vm.mockCall(
            mockWNat,
            abi.encodeWithSelector(bytes4(keccak256("balanceOfAt(address,uint256)")), _user, _vpBlock),
            abi.encode(_balance)
        );
    }

    function _mockWNatDelegations(
        address _user,
        uint256 _vpBlock,
        address[] memory _delegates,
        uint256[] memory _bips
    )
        private
    {
        vm.mockCall(
            mockWNat,
            abi.encodeWithSelector(bytes4(keccak256("delegatesOfAt(address,uint256)")), _user, _vpBlock),
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
            abi.encodeWithSelector(bytes4(keccak256("stakesOfAt(address,uint256)")), _user, _vpBlock),
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
            abi.encodeWithSelector(bytes4(keccak256("stakesOfAt(address,uint256)")), _user, _vpBlock),
            abi.encode(_accounts, _weights)
        );
    }

    function _mockWNatVp(address _user, uint256 _vpBlock, uint256 _vp) private {
        vm.mockCall(
            mockWNat,
            abi.encodeWithSelector(bytes4(keccak256("votePowerOfAt(address,uint256)")), _user, _vpBlock),
            abi.encode(_vp)
        );
    }

    function _mockMirroredVp(bytes20 _nodeId, uint256 _vpBlock, uint256 _vp) private {
        vm.mockCall(
            mockPChainStakeMirror,
            abi.encodeWithSelector(bytes4(keccak256("votePowerOfAt(bytes20,uint256)")), _nodeId, _vpBlock),
            abi.encode(_vp)
        );
    }

    function _mockCChainVp(address _account, uint256 _vpBlock, uint256 _vp) private {
        vm.mockCall(
            mockCChainStake,
            abi.encodeWithSelector(bytes4(keccak256("votePowerOfAt(address,uint256)")), _account, _vpBlock),
            abi.encode(_vp)
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
                IIClaimSetupManager.getAutoClaimAddressesAndExecutorFee.selector, _executor, _rewardOwners),
            abi.encode(_claimAddresses, _fee)
        );
    }

    function _setWNatData(uint256 _vpBlock) internal {
        address[] memory delegates = new address[](1);
        delegates[0] = voter1;
        uint256[] memory bips = new uint256[](1);
        bips[0] = 10000;
        _mockWNatDelegations(voter1, _vpBlock, delegates, bips);
        _mockWNatBalance(voter1, _vpBlock, 250);
        _mockWNatVp(voter1, _vpBlock, 300);
    }

    function _setWNatDataRewardOwners(address[] memory _rewardOwners, bool _pda) internal {
        address[] memory delegates = new address[](1);
        uint256[] memory bips = new uint256[](1);
        delegates[0] = voter1;
        bips[0] = 10000;
        uint256 balance1;
        uint256 balance2;
        if (!_pda) {
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

    function _setPChainMirrorData(uint256 _vpBlock) internal {
        bytes20[] memory nodeIds = new bytes20[](1);
        uint256[] memory weights = new uint256[](1);
        nodeIds[0] = nodeId1;
        weights[0] = 350;
        _mockStakes(voter1, _vpBlock, nodeIds, weights);
        _mockMirroredVp(nodeIds[0], _vpBlock, 400);
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

    function _setCChainData(uint256 _vpBlock) internal {
        address[] memory accounts = new address[](1);
        uint256[] memory weights = new uint256[](1);
        accounts[0] = account1;
        weights[0] = 450;
        _mockCChainStakes(voter1, _vpBlock, accounts, weights);
        _mockCChainVp(accounts[0], _vpBlock, 500);
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

    function _setZeroStakes(address _account, uint256 _vpBlock) private {
        bytes20[] memory nodeIds = new bytes20[](0);
        uint256[] memory weights = new uint256[](0);
        _mockStakes(_account, _vpBlock, nodeIds, weights);
    }

    function _mockUndelegatedVotePowerOfAt(
        address _account,
        uint256 _vpBlock,
        uint256 _undelegatedVotePower
    )
        private
    {
        vm.mockCall(
            mockWNat,
            abi.encodeWithSelector(bytes4(keccak256("undelegatedVotePowerOfAt(address,uint256)")), _account, _vpBlock),
            abi.encode(_undelegatedVotePower)
        );
    }

    function _enablePChainStakeMirror() private {
        vm.prank(governance);
        rewardManager.enablePChainStakeMirror();
        vm.prank(addressUpdater);
        rewardManager.updateContractAddresses(contractNameHashes, contractAddresses);
    }

    function _enableCChainStake() private {
        vm.prank(governance);
        rewardManager.enableCChainStake();
        vm.prank(addressUpdater);
        rewardManager.updateContractAddresses(contractNameHashes, contractAddresses);
    }

    function _mockRewardEpochIdToExpireNext(uint256 _epochId) private {
        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(bytes4(keccak256("rewardEpochIdToExpireNext()"))),
            abi.encode(_epochId)
        );
    }
}