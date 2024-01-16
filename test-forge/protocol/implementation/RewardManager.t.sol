// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../contracts/protocol/implementation/RewardManager.sol";
import "../../../contracts/protocol/implementation/FlareSystemManager.sol";
import "../../../contracts/protocol/interface/IWNat.sol";
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
    FlareSystemManager private flareSystemManager;
    address[] private rewardOffersManagers;

    IWNat private wNat;
    IPChainStakeMirror private pChainStakeMirror;
    ICChainStake private cChainStake;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    address private voter1;
    bytes20 private nodeId1;
    address private account1;

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
            2000
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

    function testConstructorOffsetTooSmall() public {
        vm.expectRevert("offset too small");
        new RewardManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            1,
            2000
        );
    }

    //// claim tests
    // claim - only DIRECT type
    function testClaimDirect() public {
        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);

        // bytes32[] memory merkleProof = new bytes32[](1);
        bytes32[] memory merkleProof = new bytes32[](0);
        RewardManager.RewardClaimWithProof[] memory proofs = new RewardManager.RewardClaimWithProof[](1);
        RewardManager.RewardClaim memory body = RewardManager.RewardClaim(RewardManager.ClaimType.DIRECT, 100, voter1);
        RewardManager.RewardClaimWithProof memory proof = RewardManager.RewardClaimWithProof(
            merkleProof, rewardEpochData.id, body);
        proofs[0] = proof;
        bytes32 leaf1 = keccak256(abi.encode(body));
        // bytes32 leaf2 = keccak256("leaf2");
        // merkleProof[0] = leaf2;
        bytes32 merkleRoot = MerkleProof.processProof(merkleProof, leaf1);

        // reward manager not yet activated
        vm.expectRevert("reward manager deactivated");
        rewardManager.claim(voter1, payable(voter1), rewardEpochData.id, false, proofs);

        // contract needs some funds for rewarding
        _fundRewardContract(1000, rewardEpochData.id);

        vm.startPrank(governance);
        rewardManager.enableClaims();
        rewardManager.activate();
        vm.stopPrank();
        _mockGetCurrentEpochId(1);
        _mockGetVpBlock(rewardEpochData.id + 1, rewardEpochData.vpBlock * 2);
        _mockRewardsHash(rewardEpochData.id, merkleRoot);

        _mockGetBurnFactor(rewardEpochData.id, voter1, 0);

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 0); // only DIRECT claim
        _setWNatData();
        _setPChainMirrorData();
        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

        uint256 balanceBefore = voter1.balance;
        vm.prank(voter1);
        vm.expectEmit();
        emit RewardClaimed(voter1, voter1, voter1, rewardEpochData.id, body.claimType, body.amount);
        rewardManager.claim(voter1, payable(voter1), rewardEpochData.id, false, proofs);
        uint256 balanceAfter = voter1.balance;
        assertEq(balanceAfter - balanceBefore, body.amount);
    }

    // claim DIRECT and weight based (WNAT)
    function testClaimDirectAndWeightBased1() public {
        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);
        RewardManager.RewardClaimWithProof[] memory proofs = new RewardManager.RewardClaimWithProof[](2);
        bytes32[] memory merkleProof1 = new bytes32[](1);
        bytes32[] memory merkleProof2 = new bytes32[](1);

        RewardManager.RewardClaim memory body1 = RewardManager.RewardClaim(
            RewardManager.ClaimType.DIRECT, 100, voter1);
        RewardManager.RewardClaim memory body2 = RewardManager.RewardClaim(
            RewardManager.ClaimType.WNAT, 200, voter1);
        bytes32 leaf1 = keccak256(abi.encode(body1));
        bytes32 leaf2 = keccak256(abi.encode(body2));
        bytes32 merkleRoot = _hashPair(leaf1, leaf2);

        // proof for DIRECT claim
        merkleProof1[0] = leaf2;
        proofs[0] = RewardManager.RewardClaimWithProof(merkleProof1, rewardEpochData.id, body1);

        // proof for WNAT claim
        merkleProof2[0] = leaf1;
        proofs[1] = RewardManager.RewardClaimWithProof(merkleProof2, rewardEpochData.id, body2);

        // contract needs some funds for rewarding
        _fundRewardContract(1000, rewardEpochData.id);

        vm.startPrank(governance);
        rewardManager.enableClaims();
        rewardManager.activate();
        vm.stopPrank();
        _mockGetCurrentEpochId(1);
        _mockGetVpBlock(rewardEpochData.id + 1, rewardEpochData.vpBlock * 2);
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
            RewardManager.ClaimType.DIRECT, 100, voter1);
        RewardManager.RewardClaim memory body2 = RewardManager.RewardClaim(
            RewardManager.ClaimType.WNAT, 200, voter1);
        RewardManager.RewardClaim memory body3 = RewardManager.RewardClaim(
            RewardManager.ClaimType.MIRROR, 300, address(nodeId1));
        RewardManager.RewardClaim memory body4 = RewardManager.RewardClaim(
            RewardManager.ClaimType.CCHAIN, 400, account1);
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
        proofs[0] = RewardManager.RewardClaimWithProof(merkleProof1, rewardEpochData.id, body1);

        // proof for WNAT claim
        merkleProof2[0] = hashes[0];
        merkleProof2[1] = hashes[5];
        proofs[1] = RewardManager.RewardClaimWithProof(merkleProof2, rewardEpochData.id, body2);

        // proof for MIRROR claim
        merkleProof3[0] = hashes[3];
        merkleProof3[1] = hashes[4];
        proofs[2] = RewardManager.RewardClaimWithProof(merkleProof3, rewardEpochData.id, body3);

        // proof for CCHAIN claim
        merkleProof4[0] = hashes[2];
        merkleProof4[1] = hashes[4];
        proofs[3] = RewardManager.RewardClaimWithProof(merkleProof4, rewardEpochData.id, body4);

        // contract needs some funds for rewarding
        _fundRewardContract(1000, rewardEpochData.id);

        vm.startPrank(governance);
        rewardManager.enableClaims();
        rewardManager.activate();
        vm.stopPrank();
        _mockGetCurrentEpochId(1);
        _mockGetVpBlock(rewardEpochData.id + 1, rewardEpochData.vpBlock * 2);
        _mockRewardsHash(rewardEpochData.id, hashes[6]);

        _mockGetBurnFactor(rewardEpochData.id, voter1, 0);

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 1); // DIRECT claim and one weight based claim (WNAT)
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
        // WNAT rewards; should receive 200 * 250/300 = 166
        vm.expectEmit();
        emit RewardClaimed(voter1, voter1, voter1, rewardEpochData.id, body2.claimType, 166);
        // MIRROR rewards; should receive 300 * 350/400 = 262
        vm.expectEmit();
        emit RewardClaimed(address(nodeId1), voter1, voter1, rewardEpochData.id, body3.claimType, 262);
        // CCHAIN rewards; should receive 400 * 450/500 = 360
        vm.expectEmit();
        emit RewardClaimed(account1, voter1, voter1, rewardEpochData.id, body4.claimType, 360);
        rewardManager.claim(voter1, payable(voter1), rewardEpochData.id, false, proofs);
        // uint256 balanceAfter = voter1.balance;
        assertEq(voter1.balance, body1.amount + 166 + 262 + 360);
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

    function testSetFeePercentage() public {
        _mockGetCurrentEpochId(0);
        address dataProvider = makeAddr("dataProvider");
        assertEq(rewardManager.getDataProviderCurrentFeePercentage(dataProvider), 2000); // default fee
        (uint256[] memory percentageBIPS, uint256[] memory validFrom, bool[] memory isFixed) =
            rewardManager.getDataProviderScheduledFeePercentageChanges(dataProvider);
        assertEq(percentageBIPS.length, 0);

        vm.startPrank(dataProvider);
        // see fee too high
        vm.expectRevert("fee percentage invalid");
        rewardManager.setDataProviderFeePercentage(uint16(10000 + 1));
        // set fee 10 %
        assertEq(rewardManager.setDataProviderFeePercentage(uint16(1000)), 0 + 2);
        assertEq(rewardManager.getDataProviderFeePercentage(dataProvider, 2), 1000);
        // change again (to 5 %)
        assertEq(rewardManager.setDataProviderFeePercentage(uint16(500)), 0 + 2);
        assertEq(rewardManager.getDataProviderFeePercentage(dataProvider, 2), 500);
        // move to epoch 1 and set fee to 15 %
        _mockGetCurrentEpochId(1);
        assertEq(rewardManager.setDataProviderFeePercentage(uint16(1500)), 1 + 2);

        (percentageBIPS, validFrom, isFixed) =
            rewardManager.getDataProviderScheduledFeePercentageChanges(dataProvider);
        assertEq(percentageBIPS.length, 2);
        assertEq(percentageBIPS[0], 500);
        assertEq(percentageBIPS[1], 1500);
        assertEq(validFrom[0], 2);
        assertEq(validFrom[1], 3);
        assertEq(isFixed[0], true);
        assertEq(isFixed[1], false);

        // move to epoch 2
        _mockGetCurrentEpochId(2);
        assertEq(rewardManager.getDataProviderCurrentFeePercentage(dataProvider), 500);
        // move to epoch 3
        _mockGetCurrentEpochId(3);
        assertEq(rewardManager.getDataProviderCurrentFeePercentage(dataProvider), 1500);
        vm.stopPrank();
    }

    function testSetFeePercentageRevert() public {
        _mockGetCurrentEpochId(0);
        vm.startPrank(dataProvider);
        rewardManager.setDataProviderFeePercentage(uint16(1000));
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

    function _mockStakes(
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

    function _mockCChainStakes(
        address _user,
        uint256 _vpBlock,
        address[] memory _accounts,
        uint256[] memory _weights
    ) private
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

    function _setWNatData() internal {
        address[] memory delegates = new address[](1);
        delegates[0] = voter1;
        uint256[] memory bips = new uint256[](1);
        bips[0] = 10000;
        _mockWNatDelegations(voter1, 10, delegates, bips);
        _mockWNatBalance(voter1, 10, 250);
        _mockWNatVp(voter1, 10, 300);
    }

    function _setPChainMirrorData() internal {
        bytes20[] memory nodeIds = new bytes20[](1);
        uint256[] memory weights = new uint256[](1);
        nodeIds[0] = nodeId1;
        weights[0] = 350;
        _mockStakes(voter1, 10, nodeIds, weights);
        _mockMirroredVp(nodeIds[0], 10, 400);
    }

    function _setCChainData() internal {
        address[] memory accounts = new address[](1);
        uint256[] memory weights = new uint256[](1);
        accounts[0] = account1;
        weights[0] = 450;
        _mockCChainStakes(voter1, 10, accounts, weights);
        _mockCChainVp(accounts[0], 10, 500);
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
}