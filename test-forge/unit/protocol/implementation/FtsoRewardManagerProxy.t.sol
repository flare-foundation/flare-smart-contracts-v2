// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../../contracts/protocol/implementation/RewardManager.sol";
import "../../../../contracts/protocol/implementation/FtsoRewardManagerProxy.sol";
import "../../../../contracts/protocol/implementation/WNatDelegationFee.sol";

// solhint-disable-next-line max-states-count
contract FtsoRewardManagerProxyTest is Test {

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
    FtsoRewardManagerProxy private ftsoRewardManagerProxy;
    WNatDelegationFee private wNatDelegationFee;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;
    address[] private rewardOwners;

    address private voter1;
    bytes20 private nodeId1;
    address private account1;
    address payable constant private BURN_ADDRESS = payable(0x000000000000000000000000000000000000dEaD);
    address private voter2;
    address private delegator;
    address payable private recipient;

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
            address(0),
            0
        );

        ftsoRewardManagerProxy = new FtsoRewardManagerProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            makeAddr("oldFtsoRewardManager")
        );

        mockClaimSetupManager = makeAddr("mockClaimSetupManager");
        mockFlareSystemsManager = makeAddr("mockFlareSystemsManager");
        mockPChainStakeMirror = makeAddr("mockPChainStakeMirror");
        mockCChainStake = makeAddr("mockCChainStake");
        mockWNat = makeAddr("mockWNat");
        mockFlareSystemsCalculator = makeAddr("mockFlareSystemsCalculator");

        wNatDelegationFee = new WNatDelegationFee(addressUpdater, 2, 2000);

        vm.prank(governance);
        vm.expectRevert("reward manager not set");
        ftsoRewardManagerProxy.enable();

        vm.startPrank(addressUpdater);
        contractNameHashes = new bytes32[](5);
        contractAddresses = new address[](5);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[2] = keccak256(abi.encode("WNat"));
        contractNameHashes[3] = keccak256(abi.encode("WNatDelegationFee"));
        contractNameHashes[4] = keccak256(abi.encode("RewardManager"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = mockFlareSystemsManager;
        contractAddresses[2] = mockWNat;
        contractAddresses[3] = address(wNatDelegationFee);
        contractAddresses[4] = address(rewardManager);
        ftsoRewardManagerProxy.updateContractAddresses(contractNameHashes, contractAddresses);

        contractNameHashes = new bytes32[](2);
        contractAddresses = new address[](2);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("FlareSystemsManager"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = mockFlareSystemsManager;
        wNatDelegationFee.updateContractAddresses(contractNameHashes, contractAddresses);

        contractNameHashes = new bytes32[](8);
        contractAddresses = new address[](8);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("ClaimSetupManager"));
        contractNameHashes[2] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[3] = keccak256(abi.encode("PChainStakeMirror"));
        contractNameHashes[4] = keccak256(abi.encode("CChainStake"));
        contractNameHashes[5] = keccak256(abi.encode("WNat"));
        contractNameHashes[6] = keccak256(abi.encode("FlareSystemsCalculator"));
        contractNameHashes[7] = keccak256(abi.encode("FtsoRewardManagerProxy"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = mockClaimSetupManager;
        contractAddresses[2] = mockFlareSystemsManager;
        contractAddresses[3] = mockPChainStakeMirror;
        contractAddresses[4] = mockCChainStake;
        contractAddresses[5] = mockWNat;
        contractAddresses[6] = mockFlareSystemsCalculator;
        contractAddresses[7] = address(ftsoRewardManagerProxy);
        rewardManager.updateContractAddresses(contractNameHashes, contractAddresses);
        vm.stopPrank();

        voter1 = makeAddr("voter1");
        nodeId1 = bytes20(makeAddr("nodeId1"));
        account1 = makeAddr("account1");
        voter2 = makeAddr("voter2");
        delegator = makeAddr("delegator");
        recipient = payable(makeAddr("recipient"));
    }

    function testClaimRewardRevertNotEnabled() public {
        vm.expectRevert("ftso reward manager proxy disabled");
        uint256[] memory rewardEpochIds = new uint256[](0);
        ftsoRewardManagerProxy.claimReward(recipient, rewardEpochIds);
    }

    function testClaimReward() public {
        _enablePChainStakeMirror();
        // enable ftso reward manager proxy
        vm.prank(governance);
        ftsoRewardManagerProxy.enable();

        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);
        IRewardManager.RewardClaimWithProof[] memory proofs = new IRewardManager.RewardClaimWithProof[](1);
        merkleProof1 = new bytes32[](1);

        IRewardManager.RewardClaim memory body1 = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 200, IRewardManager.ClaimType.WNAT);
        bytes32 leaf1 = keccak256(abi.encode(body1));
        bytes32 merkleRoot = _hashPair(leaf1, leaf1);

        // proof for WNAT claim
        merkleProof1[0] = leaf1;
        proofs[0] = IRewardManager.RewardClaimWithProof(merkleProof1, body1);

        // contract needs some funds for rewarding
        _fundRewardContract(1000, rewardEpochData.id);

        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);
        _mockRewardsHash(rewardEpochData.id, merkleRoot);

        _mockCalculateBurnFactor(rewardEpochData.id, voter1, 0);

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 1);

        // voter data
        // voter1 balance = 250; vp = 300; he is delegating 100% to himself
        _setWNatData(rewardEpochData.vpBlock);
        _setPChainMirrorData(rewardEpochData.vpBlock);
        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

        // delegator data
        address[] memory delegates = new address[](1);
        delegates[0] = voter1;
        uint256[] memory bips = new uint256[](1);
        bips[0] = 10000;
        _mockWNatDelegations(delegator, rewardEpochData.vpBlock, delegates, bips);
        _mockWNatBalance(delegator, rewardEpochData.vpBlock, 50);
        bytes20[] memory nodeIds = new bytes20[](1);
        uint256[] memory weights = new uint256[](1);
        nodeIds[0] = nodeId1;
        weights[0] = 350;
        _mockStakes(delegator, rewardEpochData.vpBlock, nodeIds, weights);
        _mockMirroredVp(nodeIds[0], rewardEpochData.vpBlock, 400);

        // initialize
        rewardManager.initialiseWeightBasedClaims(proofs);

        // WNAT reward claim for delegator; should receive 200 * 50/300 = 33
        vm.prank(delegator);
        vm.expectEmit();
        emit RewardClaimed(voter1, delegator, recipient, rewardEpochData.id, body1.claimType, 33);
        uint256[] memory rewardEpochs = new uint256[](1);
        rewardEpochs[0] = 0;
        ftsoRewardManagerProxy.claimReward(recipient, rewardEpochs);
        assertEq(recipient.balance, 33);

        //// reward epoch 1
        rewardEpochData = RewardEpochData(1, 20);
        _fundRewardContract(100, rewardEpochData.id);
        proofs = new IRewardManager.RewardClaimWithProof[](1);
        merkleProof1 = new bytes32[](1);

        body1 = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 200, IRewardManager.ClaimType.WNAT);
        leaf1 = keccak256(abi.encode(body1));
        merkleRoot = _hashPair(leaf1, leaf1);

        // proof for WNAT claim
        merkleProof1[0] = leaf1;
        proofs[0] = IRewardManager.RewardClaimWithProof(merkleProof1, body1);

        _mockRewardsHash(rewardEpochData.id, merkleRoot);
        _mockCalculateBurnFactor(rewardEpochData.id, voter1, 0);

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 1);

        // voter data
        // voter1 balance = 250; vp = 300; he is delegating 100% to himself
        _setWNatData(rewardEpochData.vpBlock);
        _setPChainMirrorData(rewardEpochData.vpBlock);
        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

        // initialize
        rewardManager.initialiseWeightBasedClaims(proofs);

        // voter1 claims for reward epochs 0 and 1
        _mockGetCurrentEpochId(2);
        rewardEpochs = new uint256[](2);
        rewardEpochs[0] = 1;
        rewardEpochs[1] = 0;
        vm.prank(voter1);
        ftsoRewardManagerProxy.claimReward(payable(voter1), rewardEpochs);
        // should receive 167 (epoch 0) + 100 * 250/300 (epoch 1) = 167 + 83
        assertEq(voter1.balance, 167 + 83);
    }

    function testClaimRevertNotEnabled() public {
        vm.expectRevert("ftso reward manager proxy disabled");
        ftsoRewardManagerProxy.claim(recipient, recipient, 0, false);
    }

    function testClaim() public {
        _enablePChainStakeMirror();
        // enable ftso reward manager proxy
        vm.prank(governance);
        ftsoRewardManagerProxy.enable();

        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);
        IRewardManager.RewardClaimWithProof[] memory proofs = new IRewardManager.RewardClaimWithProof[](1);
        merkleProof1 = new bytes32[](1);

        IRewardManager.RewardClaim memory body1 = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 200, IRewardManager.ClaimType.WNAT);
        bytes32 leaf1 = keccak256(abi.encode(body1));
        bytes32 merkleRoot = _hashPair(leaf1, leaf1);

        // proof for WNAT claim
        merkleProof1[0] = leaf1;
        proofs[0] = IRewardManager.RewardClaimWithProof(merkleProof1, body1);

        // contract needs some funds for rewarding
        _fundRewardContract(1000, rewardEpochData.id);

        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);
        _mockRewardsHash(rewardEpochData.id, merkleRoot);

        _mockCalculateBurnFactor(rewardEpochData.id, voter1, 0);

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 1);

        // voter data
        // voter1 balance = 250; vp = 300; he is delegating 100% to himself
        _setWNatData(rewardEpochData.vpBlock);
        _setPChainMirrorData(rewardEpochData.vpBlock);
        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

        // delegator data
        address[] memory delegates = new address[](1);
        delegates[0] = voter1;
        uint256[] memory bips = new uint256[](1);
        bips[0] = 10000;
        _mockWNatDelegations(delegator, rewardEpochData.vpBlock, delegates, bips);
        _mockWNatBalance(delegator, rewardEpochData.vpBlock, 50);
        bytes20[] memory nodeIds = new bytes20[](1);
        uint256[] memory weights = new uint256[](1);
        nodeIds[0] = nodeId1;
        weights[0] = 350;
        _mockStakes(delegator, rewardEpochData.vpBlock, nodeIds, weights);
        _mockMirroredVp(nodeIds[0], rewardEpochData.vpBlock, 400);

        // initialize
        rewardManager.initialiseWeightBasedClaims(proofs);

        // WNAT reward claim for delegator; should receive 200 * 50/300 = 33
        vm.prank(delegator);
        vm.expectEmit();
        emit RewardClaimed(voter1, delegator, recipient, rewardEpochData.id, body1.claimType, 33);
        uint256[] memory rewardEpochs = new uint256[](1);
        rewardEpochs[0] = 0;
        ftsoRewardManagerProxy.claim(delegator, recipient, 0, false);
        assertEq(recipient.balance, 33);

        //// reward epoch 1
        rewardEpochData = RewardEpochData(1, 20);
        _fundRewardContract(100, rewardEpochData.id);
        proofs = new IRewardManager.RewardClaimWithProof[](1);
        merkleProof1 = new bytes32[](1);

        body1 = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 200, IRewardManager.ClaimType.WNAT);
        leaf1 = keccak256(abi.encode(body1));
        merkleRoot = _hashPair(leaf1, leaf1);

        // proof for WNAT claim
        merkleProof1[0] = leaf1;
        proofs[0] = IRewardManager.RewardClaimWithProof(merkleProof1, body1);

        _mockRewardsHash(rewardEpochData.id, merkleRoot);
        _mockCalculateBurnFactor(rewardEpochData.id, voter1, 0);

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 1);

        // voter data
        // voter1 balance = 250; vp = 300; he is delegating 100% to himself
        _setWNatData(rewardEpochData.vpBlock);
        _setPChainMirrorData(rewardEpochData.vpBlock);
        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

        // initialize
        rewardManager.initialiseWeightBasedClaims(proofs);

        // voter1 claims for reward epochs 0 and 1
        _mockGetCurrentEpochId(2);
        rewardEpochs = new uint256[](2);
        rewardEpochs[0] = 1;
        rewardEpochs[1] = 0;

        // disable proxy contract
        vm.startPrank(governance);
        ftsoRewardManagerProxy.disable();
        vm.expectRevert("ftso reward manager proxy disabled");
        ftsoRewardManagerProxy.claim(voter1, payable(voter1), 1, false);

        // enable proxy again
        ftsoRewardManagerProxy.enable();
        vm.stopPrank();

        // set executor who will claim instead of a reward owner
        address executor = makeAddr("executor");
        vm.mockCall(
            mockClaimSetupManager,
            abi.encodeWithSelector(
                IIClaimSetupManager.checkExecutorAndAllowedRecipient.selector, executor, voter1, voter1),
            abi.encode()
        );
        vm.prank(executor);
        ftsoRewardManagerProxy.claim(voter1, payable(voter1), 1, false);
        // for each epoch should receive 167 + 100 * 250/300 = 167 + 83
        assertEq(voter1.balance, 167 + 83);
    }

    function testEnableAndDisable() public {
        // revert if not governance
        vm.expectRevert("only governance");
        ftsoRewardManagerProxy.enable();

        // enable proxy contract
        vm.prank(governance);
        ftsoRewardManagerProxy.enable();
        assertEq(ftsoRewardManagerProxy.enabled(), true);

        // revert if not governance
        vm.expectRevert("only governance");
        ftsoRewardManagerProxy.disable();

        // disable proxy contract
        vm.prank(governance);
        ftsoRewardManagerProxy.disable();
        assertEq(ftsoRewardManagerProxy.enabled(), false);
    }

    function testSetNewFRMRevertAddressZero() public {
        vm.prank(governance);
        vm.expectRevert("address zero");
        ftsoRewardManagerProxy.setNewFtsoRewardManager(address(0));
    }

    function testSetNewFRM() public {
        assertEq(ftsoRewardManagerProxy.newFtsoRewardManager(), address(0));
        address newFtsoRewardManager = makeAddr("newFtsoRewardManager");
        vm.prank(governance);
        ftsoRewardManagerProxy.setNewFtsoRewardManager(newFtsoRewardManager);
        assertEq(ftsoRewardManagerProxy.newFtsoRewardManager(), newFtsoRewardManager);
    }

    function testSetNewFRMRevertAlreadySet() public {
        testSetNewFRM();
        vm.prank(governance);
        vm.expectRevert("already set");
        ftsoRewardManagerProxy.setNewFtsoRewardManager(makeAddr("newFtsoRewardManager1"));
    }

    function testActive() public {
        // disabled nad RewardManager not active
        assertEq(ftsoRewardManagerProxy.active(), false);

        // enabled and RewardManager not active
        vm.prank(governance);
        ftsoRewardManagerProxy.enable();
        assertEq(ftsoRewardManagerProxy.active(), false);

        // enabled and RewardManager active
        vm.prank(governance);
        rewardManager.activate();
        assertEq(ftsoRewardManagerProxy.active(), true);

        // disabled and RewardManager active
        vm.prank(governance);
        ftsoRewardManagerProxy.disable();
        assertEq(ftsoRewardManagerProxy.active(), false);
    }

    function testGetDataProviderCurrentFeePercentage() public {
        _mockGetCurrentEpochId(0);
        assertEq(ftsoRewardManagerProxy.getDataProviderCurrentFeePercentage(voter1), 2000);

        // change fee to 10%
        vm.prank(voter1);
        wNatDelegationFee.setVoterFeePercentage(uint16(1000));

        // move to epoch 2
        _mockGetCurrentEpochId(2);
        assertEq(ftsoRewardManagerProxy.getDataProviderCurrentFeePercentage(voter1), 1000);
    }

    function testGetDataProviderFeePercentage() public {
        _mockGetCurrentEpochId(0);

        // change fee to 10%
        vm.prank(voter1);
        wNatDelegationFee.setVoterFeePercentage(uint16(1000));

        assertEq(ftsoRewardManagerProxy.getDataProviderFeePercentage(voter1, 0), 2000);
        assertEq(ftsoRewardManagerProxy.getDataProviderFeePercentage(voter1, 1), 2000);
        assertEq(ftsoRewardManagerProxy.getDataProviderFeePercentage(voter1, 2), 1000);
    }

    function testGetDataProviderScheduledFeePercentageChanges() public {
        _mockGetCurrentEpochId(0);

        // change fee to 10%
        vm.prank(voter1);
        wNatDelegationFee.setVoterFeePercentage(uint16(1000));

        // set fee to 5%
        _mockGetCurrentEpochId(1);
        vm.prank(voter1);
        wNatDelegationFee.setVoterFeePercentage(uint16(500));

        (uint256[] memory percentageBIPS, uint256[] memory validFrom, bool[] memory isFixed) =
            ftsoRewardManagerProxy.getDataProviderScheduledFeePercentageChanges(voter1);
        assertEq(percentageBIPS.length, 2);
        assertEq(percentageBIPS[0], 1000);
        assertEq(percentageBIPS[1], 500);
        assertEq(validFrom[0], 2);
        assertEq(validFrom[1], 3);
        assertEq(isFixed[0], true);
        assertEq(isFixed[1], false);
    }

    function testGetEpochReward() public {
        testClaimReward();

        (uint256 totalReward, uint256 claimedReward) = ftsoRewardManagerProxy.getEpochReward(0);
        assertEq(totalReward, 1000);
        assertEq(claimedReward, 200);

        (totalReward, claimedReward) = ftsoRewardManagerProxy.getEpochReward(1);
        assertEq(totalReward, 100);
        assertEq(claimedReward, 83);
    }

    // user has nothing to claim (no delegations, p-chain and c-chain not enabled)
    function testGetStateOfRewards1() public {
        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);
        _mockGetVpBlock(0, rewardEpochData.vpBlock);
        _mockWNatBalance(voter1, rewardEpochData.vpBlock, rewardEpochData.id);
        _mockGetCurrentEpochId(0);
        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 0);
        _mockRewardsHash(rewardEpochData.id, bytes32("root"));

        (address[] memory providers, uint256[] memory amounts, bool[] memory claimed, bool claimable) =
            ftsoRewardManagerProxy.getStateOfRewards(voter1, 0);
        assertEq(providers.length, 0);
        assertEq(amounts.length, 0);
        assertEq(claimed.length, 0);
        assertEq(claimable, true);
    }

    function testGetStateOfRewardsRevertNotInitialized() public {
        _enablePChainStakeMirror();
        // enable ftso reward manager proxy
        vm.prank(governance);
        ftsoRewardManagerProxy.enable();

        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);
        IRewardManager.RewardClaimWithProof[] memory proofs = new IRewardManager.RewardClaimWithProof[](1);
        merkleProof1 = new bytes32[](1);

        IRewardManager.RewardClaim memory body1 = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 200, IRewardManager.ClaimType.WNAT);
        bytes32 leaf1 = keccak256(abi.encode(body1));
        bytes32 merkleRoot = _hashPair(leaf1, leaf1);

        // proof for WNAT claim
        merkleProof1[0] = leaf1;
        proofs[0] = IRewardManager.RewardClaimWithProof(merkleProof1, body1);

        // contract needs some funds for rewarding
        _fundRewardContract(1000, rewardEpochData.id);

        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);
        _mockRewardsHash(rewardEpochData.id, merkleRoot);

        _mockCalculateBurnFactor(rewardEpochData.id, voter1, 0);

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 1);

        // voter data
        // voter1 balance = 250; vp = 300; he is delegating 100% to himself
        _setWNatData(rewardEpochData.vpBlock);
        _setPChainMirrorData(rewardEpochData.vpBlock);
        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

        // get state of rewards
        vm.expectRevert("not initialised");
        ftsoRewardManagerProxy.getStateOfRewards(voter1, 0);
    }

    function testGetStateOfRewards2() public {
        _enablePChainStakeMirror();
        // enable ftso reward manager proxy
        vm.prank(governance);
        ftsoRewardManagerProxy.enable();

        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);
        IRewardManager.RewardClaimWithProof[] memory proofs = new IRewardManager.RewardClaimWithProof[](1);
        merkleProof1 = new bytes32[](1);

        IRewardManager.RewardClaim memory body1 = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 200, IRewardManager.ClaimType.WNAT);
        bytes32 leaf1 = keccak256(abi.encode(body1));
        bytes32 merkleRoot = _hashPair(leaf1, leaf1);

        // proof for WNAT claim
        merkleProof1[0] = leaf1;
        proofs[0] = IRewardManager.RewardClaimWithProof(merkleProof1, body1);

        // contract needs some funds for rewarding
        _fundRewardContract(1000, rewardEpochData.id);

        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);
        _mockRewardsHash(rewardEpochData.id, merkleRoot);

        _mockCalculateBurnFactor(rewardEpochData.id, voter1, 0);

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 1);

        // voter data
        // voter1 balance = 250; vp = 300; he is delegating 100% to himself
        _setWNatData(rewardEpochData.vpBlock);
        _setPChainMirrorData(rewardEpochData.vpBlock);
        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

        // delegator data
        address[] memory delegates = new address[](1);
        delegates[0] = voter1;
        uint256[] memory bips = new uint256[](1);
        bips[0] = 10000;
        _mockWNatDelegations(delegator, rewardEpochData.vpBlock, delegates, bips);
        _mockWNatBalance(delegator, rewardEpochData.vpBlock, 50);
        bytes20[] memory nodeIds = new bytes20[](1);
        uint256[] memory weights = new uint256[](1);
        nodeIds[0] = nodeId1;
        weights[0] = 350;
        _mockStakes(delegator, rewardEpochData.vpBlock, nodeIds, weights);
        _mockMirroredVp(nodeIds[0], rewardEpochData.vpBlock, 400);

        // initialize
        rewardManager.initialiseWeightBasedClaims(proofs);

        // get state of rewards
        (address[] memory providers, uint256[] memory amounts, bool[] memory claimed, bool claimable) =
            ftsoRewardManagerProxy.getStateOfRewards(voter1, 0);
        assertEq(providers.length, 2);
        assertEq(providers[0], voter1);
        assertEq(providers[1], address(nodeId1));
        assertEq(amounts[0], 166);
        assertEq(amounts[1], 0);
        assertEq(claimed[0], false);
        assertEq(claimed[1], false);
        assertEq(claimable, true);

        // get state of rewards for delegator
        (providers, amounts, claimed, claimable) = ftsoRewardManagerProxy.getStateOfRewards(delegator, 0);
        assertEq(providers.length, 2);
        assertEq(providers[0], voter1);
        assertEq(providers[1], address(nodeId1));
        assertEq(amounts[0], 33);
        assertEq(amounts[1], 0);
        assertEq(claimed[0], false);
        assertEq(claimed[1], false);
        assertEq(claimable, true);
    }

    function testGetStateOfRewardsNotClaimable() public {
        testClaimReward();

        ftsoRewardManagerProxy.getStateOfRewards(voter1, 0);
        (address[] memory providers, uint256[] memory amounts, bool[] memory claimed, bool claimable) =
            ftsoRewardManagerProxy.getStateOfRewards(voter1, 0);
        assertEq(providers.length, 0);
        assertEq(amounts.length, 0);
        assertEq(claimed.length, 0);
        assertEq(claimable, false);
    }

    function testGetStateOfRewardsRevertWithMsg() public {
        _mockGetCurrentEpochId(2);
        vm.expectRevert("not claimable");
        // state in the future
        ftsoRewardManagerProxy.getStateOfRewards(voter1, 8);
    }

    function testGetEpochsWithClaimableRewards() public {
        _mockGetCurrentEpochId(0);
        vm.prank(governance);
        rewardManager.enableClaims();
        _mockRewardsHash(0, bytes32("root1"));
        _mockRewardsHash(1, bytes32("root2"));
        _mockRewardsHash(2, bytes32("root3"));
        _mockRewardsHash(3, bytes32("root4"));
        _mockRewardsHash(4, bytes32(0));
        _mockGetCurrentEpochId(5);

        (uint256 start, uint256 end) = ftsoRewardManagerProxy.getEpochsWithClaimableRewards();
        assertEq(start, 0);
        assertEq(end, 3);
    }

    function testNextClaimableRewardEpoch() public {
        _mockGetCurrentEpochId(0);
        vm.prank(governance);
        rewardManager.enableClaims();
        assertEq(ftsoRewardManagerProxy.nextClaimableRewardEpoch(voter1), 0);

        // claim
        _enablePChainStakeMirror();
        // enable ftso reward manager proxy
        vm.prank(governance);
        ftsoRewardManagerProxy.enable();

        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);
        IRewardManager.RewardClaimWithProof[] memory proofs = new IRewardManager.RewardClaimWithProof[](1);
        merkleProof1 = new bytes32[](1);

        IRewardManager.RewardClaim memory body1 = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 200, IRewardManager.ClaimType.WNAT);
        bytes32 leaf1 = keccak256(abi.encode(body1));
        bytes32 merkleRoot = _hashPair(leaf1, leaf1);

        // proof for WNAT claim
        merkleProof1[0] = leaf1;
        proofs[0] = IRewardManager.RewardClaimWithProof(merkleProof1, body1);

        // contract needs some funds for rewarding
        _fundRewardContract(1000, rewardEpochData.id);

        vm.prank(governance);
        rewardManager.activate();
        _mockRewardsHash(rewardEpochData.id, merkleRoot);

        _mockCalculateBurnFactor(rewardEpochData.id, voter1, 0);

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 1);

        // voter data
        // voter1 balance = 250; vp = 300; he is delegating 100% to himself
        _setWNatData(rewardEpochData.vpBlock);
        _setPChainMirrorData(rewardEpochData.vpBlock);
        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

        // initialize
        rewardManager.initialiseWeightBasedClaims(proofs);

        _mockGetCurrentEpochId(2);
        vm.prank(voter1);
        uint256[] memory rewardEpochs = new uint256[](1);
        rewardEpochs[0] = 0;
        ftsoRewardManagerProxy.claim(voter1, recipient, 0, false);

        assertEq(ftsoRewardManagerProxy.nextClaimableRewardEpoch(voter1), 1);
    }

    function testGetEpochsWithUnclaimedRewardsUninitialized() public {
        _mockGetCurrentEpochId(0);
        vm.prank(governance);
        rewardManager.enableClaims();
        _mockRewardsHash(0, bytes32(0));
        uint256[] memory epochs = ftsoRewardManagerProxy.getEpochsWithUnclaimedRewards(voter1);
        assertEq(epochs.length, 0);

         _enablePChainStakeMirror();
        // enable ftso reward manager proxy
        vm.prank(governance);
        ftsoRewardManagerProxy.enable();

        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);
        IRewardManager.RewardClaimWithProof[] memory proofs = new IRewardManager.RewardClaimWithProof[](1);
        merkleProof1 = new bytes32[](1);

        IRewardManager.RewardClaim memory body1 = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 200, IRewardManager.ClaimType.WNAT);
        bytes32 leaf1 = keccak256(abi.encode(body1));
        bytes32 merkleRoot = _hashPair(leaf1, leaf1);

        // proof for WNAT claim
        merkleProof1[0] = leaf1;
        proofs[0] = IRewardManager.RewardClaimWithProof(merkleProof1, body1);

        // contract needs some funds for rewarding
        _fundRewardContract(1000, rewardEpochData.id);

        vm.prank(governance);
        rewardManager.activate();
        _mockRewardsHash(rewardEpochData.id, merkleRoot);

        _mockCalculateBurnFactor(rewardEpochData.id, voter1, 0);

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 1);

        // voter data
        // voter1 balance = 250; vp = 300; he is delegating 100% to himself
        _setWNatData(rewardEpochData.vpBlock);
        _setPChainMirrorData(rewardEpochData.vpBlock);
        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

        epochs = ftsoRewardManagerProxy.getEpochsWithUnclaimedRewards(voter1);
        assertEq(epochs.length, 0);
    }

    function testGetEpochsWithUnclaimedRewardsInitialized() public {
        testGetEpochsWithUnclaimedRewardsUninitialized();

        // initialize
        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);
        IRewardManager.RewardClaimWithProof[] memory proofs = new IRewardManager.RewardClaimWithProof[](1);
        merkleProof1 = new bytes32[](1);

        IRewardManager.RewardClaim memory body1 = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 200, IRewardManager.ClaimType.WNAT);
        bytes32 leaf1 = keccak256(abi.encode(body1));
        merkleProof1[0] = leaf1;
        proofs[0] = IRewardManager.RewardClaimWithProof(merkleProof1, body1);
        rewardManager.initialiseWeightBasedClaims(proofs);

        uint256[] memory epochs = ftsoRewardManagerProxy.getEpochsWithUnclaimedRewards(voter1);
        assertEq(epochs.length, 1);
        assertEq(epochs[0], 0);
    }

    function testGetClaimedReward1() public {
        _enablePChainStakeMirror();
        // enable ftso reward manager proxy
        vm.prank(governance);
        ftsoRewardManagerProxy.enable();

        RewardEpochData memory rewardEpochData = RewardEpochData(0, 10);
        IRewardManager.RewardClaimWithProof[] memory proofs = new IRewardManager.RewardClaimWithProof[](1);
        merkleProof1 = new bytes32[](1);

        IRewardManager.RewardClaim memory body1 = IRewardManager.RewardClaim(
            rewardEpochData.id, bytes20(voter1), 200, IRewardManager.ClaimType.WNAT);
        bytes32 leaf1 = keccak256(abi.encode(body1));
        bytes32 merkleRoot = _hashPair(leaf1, leaf1);

        // proof for WNAT claim
        merkleProof1[0] = leaf1;
        proofs[0] = IRewardManager.RewardClaimWithProof(merkleProof1, body1);

        // contract needs some funds for rewarding
        _fundRewardContract(1000, rewardEpochData.id);

        _enableAndActivate(rewardEpochData.id, rewardEpochData.vpBlock);
        _mockRewardsHash(rewardEpochData.id, merkleRoot);

        _mockCalculateBurnFactor(rewardEpochData.id, voter1, 0);

        // _claimWeightBasedRewards
        _mockNoOfWeightBasedClaims(rewardEpochData.id, 1);

        // voter data
        _setWNatData(rewardEpochData.vpBlock);
        _setPChainMirrorData(rewardEpochData.vpBlock);
        _mockGetVpBlock(rewardEpochData.id, rewardEpochData.vpBlock);

        address[] memory delegates = new address[](1);
        delegates[0] = voter1;
        uint256[] memory bips = new uint256[](1);
        bips[0] = 10000;
        _mockWNatDelegations(delegator, rewardEpochData.vpBlock, delegates, bips);
        _mockWNatBalance(delegator, rewardEpochData.vpBlock, 50);
        bytes20[] memory nodeIds = new bytes20[](1);
        uint256[] memory weights = new uint256[](1);
        nodeIds[0] = nodeId1;
        weights[0] = 350;
        _mockStakes(delegator, rewardEpochData.vpBlock, nodeIds, weights);
        _mockMirroredVp(nodeIds[0], rewardEpochData.vpBlock, 400);

        // get claimed reward
        (bool claimed, uint256 amount) = ftsoRewardManagerProxy.getClaimedReward(0, voter1, delegator);
        assertEq(claimed, false);
        assertEq(amount, 0);

        // initialize rewards
        rewardManager.initialiseWeightBasedClaims(proofs);
        (claimed, amount) = ftsoRewardManagerProxy.getClaimedReward(0, voter1, delegator);
        assertEq(claimed, false);
        assertEq(amount, 33);
    }

    // already claimed
    function testGetClaimedReward2() public {
        testGetClaimedReward1();

        // claim
        _mockGetCurrentEpochId(2);
        vm.prank(delegator);
        uint256[] memory rewardEpochs = new uint256[](1);
        rewardEpochs[0] = 0;
        ftsoRewardManagerProxy.claim(delegator, recipient, 0, false);

        (bool claimed, uint256 amount) = ftsoRewardManagerProxy.getClaimedReward(0, voter1, delegator);
        assertEq(claimed, true);
        assertEq(amount, 0);
    }

    function testGetClaimedRewardRevertWithMsg() public {
        _mockGetCurrentEpochId(2);
        vm.expectRevert("not claimable");
        // state in the future
        ftsoRewardManagerProxy.getClaimedReward(12, voter1, delegator);
    }

    function testGetRewardEpochToExpireNext() public {
        _mockGetCurrentEpochId(0);
        vm.prank(governance);
        rewardManager.enableClaims();

        assertEq(ftsoRewardManagerProxy.getRewardEpochToExpireNext(), 0);

        vm.prank(mockFlareSystemsManager);
        rewardManager.closeExpiredRewardEpoch(0);

        assertEq(ftsoRewardManagerProxy.getRewardEpochToExpireNext(), 1);
    }

    function testGetRewardEpochVotePowerBlock() public {
        _mockGetVpBlock(0, 10);
        assertEq(ftsoRewardManagerProxy.getRewardEpochVotePowerBlock(0), 10);
    }

    function testGetCurrentRewardEpochId() public {
        _mockGetCurrentEpochId(9);
        assertEq(ftsoRewardManagerProxy.getCurrentRewardEpoch(), 9);
    }

    function testGetInitialRewardEpoch() public {
        assertEq(ftsoRewardManagerProxy.getInitialRewardEpoch(), 0);

        _mockGetCurrentEpochId(9);
        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(bytes4(keccak256("rewardEpochIdToExpireNext()"))),
            abi.encode(3)
        );
        vm.prank(governance);
        rewardManager.setInitialRewardData();
        assertEq(ftsoRewardManagerProxy.getInitialRewardEpoch(), 9);
    }

    function testClaimRewardFromDataProviders() public {
        assertEq(ftsoRewardManagerProxy.claimRewardFromDataProviders(
            payable(voter1), new uint256[](0), new address[](0)), 0);
    }

    function testClaimFromDataProviders() public {
        assertEq(ftsoRewardManagerProxy.claimFromDataProviders(
            voter1, recipient, new uint256[](0), new address[](0), false), 0);
    }

    function testAutoClaim() public {
        vm.expectRevert("not supported, use RewardManager");
        ftsoRewardManagerProxy.autoClaim(new address[](0), 0);
    }

    function testSetDataProviderFeePercentage() public {
        vm.expectRevert("not supported, use WNatDelegationFee");
        ftsoRewardManagerProxy.setDataProviderFeePercentage(2);
    }

    function testGetStateOfRewardsFromDataProviders() public {
        (uint256[] memory amounts, bool[] memory claimed, bool claimable) =
            ftsoRewardManagerProxy.getStateOfRewardsFromDataProviders(voter1, 0, new address[](0));
        assertEq(amounts.length, 0);
        assertEq(claimed.length, 0);
        assertEq(claimable, false);
    }

    function testGetDataProviderPerformanceInfo() public {
        (uint256 amount, uint256 revocation) =
            ftsoRewardManagerProxy.getDataProviderPerformanceInfo(0, voter1);
        assertEq(amount, 0);
        assertEq(revocation, 0);
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
            abi.encodeWithSelector(bytes4(keccak256("noOfWeightBasedClaims(uint256,uint256)")), _epoch, 0),
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

    function _enablePChainStakeMirror() private {
        vm.prank(governance);
        rewardManager.enablePChainStakeMirror();
        vm.prank(addressUpdater);
        rewardManager.updateContractAddresses(contractNameHashes, contractAddresses);
    }
}