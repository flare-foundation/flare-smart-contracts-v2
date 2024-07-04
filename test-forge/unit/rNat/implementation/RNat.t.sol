// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../../contracts/rNat/implementation/RNat.sol";
import "../../../../contracts/rNat/implementation/RNatAccount.sol";
import "../../../mock/IWNatMock.sol";
import "flare-smart-contracts/contracts/token/interface/IIVPContract.sol";
import "flare-smart-contracts/contracts/token/interface/IIGovernanceVotePower.sol";
import "../../../../contracts/userInterfaces/ICChainStake.sol";
import "../../../mock/ERC20Mock.sol";

contract RNatTest is Test {

    uint256 internal constant MONTH = 30 days;
    address payable constant internal BURN_ADDRESS = payable(0x000000000000000000000000000000000000dEaD);

    RNatAccount private rNatAccount;
    RNat private rNat;
    address private owner;
    IWNatMock private wNat;
    address private governance;
    IIVPContract private vpContract;
    IIGovernanceVotePower private governanceVotePower;
    address private mockClaimSetupManager;
    address private addressUpdater;
    address private manager;
    address private fundingAddress;
    address private incentivePool;


    // projects
    string[] private projectNames;
    address[] private projectDistributors;

    // reward recipients (project users)
    address[] private rewardRecipients1; // for project 1
    address[] private rewardRecipients2; // for project 2

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    event RewardsClaimed(uint256 indexed projectId, uint256 indexed month, address indexed owner, uint128 amount);
    event ClaimingPermissionUpdated(uint256[] projectIds, bool disabled);
    event DistributionPermissionUpdated(uint256[] projectIds, bool disabled);

    function setUp() public {
        vm.warp(1000);
        owner = makeAddr("owner");
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");
        manager = makeAddr("manager");
        fundingAddress = makeAddr("fundingAddress1");
        rNat = new RNat(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            "rTest",
            "rT",
            18,
            manager,
            500
        );
        vm.prank(governance);
        rNat.setFundingAddress(fundingAddress);

        rNatAccount = new RNatAccount();
        rNatAccount.initialize(owner, rNat);

        // deploy WNat contract
        wNat = IWNatMock(deployCode(
            "artifacts-forge/FlareSmartContracts.sol/WNat.json",
            abi.encode(governance, "Wrapped NAT", "WNat")
        ));
        vpContract = IIVPContract(deployCode(
            "artifacts-forge/FlareSmartContracts.sol/VPContract.json",
            abi.encode(wNat, false)
        ));
        governanceVotePower = IIGovernanceVotePower(deployCode(
            "GovernanceVotePower.sol",
            abi.encode(wNat, makeAddr("pChain"), makeAddr("cChain"))
        ));
        vm.startPrank(governance);
        wNat.setGovernanceVotePower(governanceVotePower);
        wNat.setReadVpContract(vpContract);
        wNat.setWriteVpContract(vpContract);
        vm.stopPrank();

        mockClaimSetupManager = makeAddr("mockClaimSetupManager");
        vm.prank(addressUpdater);
        contractNameHashes = new bytes32[](3);
        contractAddresses = new address[](3);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("ClaimSetupManager"));
        contractNameHashes[2] = keccak256(abi.encode("WNat"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = mockClaimSetupManager;
        contractAddresses[2] = address(wNat);
        rNat.updateContractAddresses(contractNameHashes, contractAddresses);

        // fund funding addresses
        vm.deal(fundingAddress, 2000);

        projectDistributors.push(makeAddr("distributor1"));
        projectDistributors.push(makeAddr("distributor2"));
        projectNames.push("project1");
        projectNames.push("project2");

        rewardRecipients1.push(makeAddr("rewardRecipient1"));
        rewardRecipients1.push(makeAddr("rewardRecipient2"));
        rewardRecipients2.push(makeAddr("rewardRecipient1"));
        rewardRecipients2.push(makeAddr("rewardRecipient3"));
    }

    function testDeployRevertManagerZero() public {
        vm.expectRevert("address zero");
        new RNat(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            "rTest",
            "rT",
            18,
            address(0),
            500
        );
    }

    function testDeployRevertStartInFuture() public {
        vm.expectRevert("first month start in the future");
        new RNat(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            "rTest",
            "rT",
            18,
            manager,
            1500
        );
    }

    function testUpdateContractAddressesRevertDecimalsMismatch() public {
         rNat = new RNat(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            "rTest",
            "rT",
            5,
            manager,
            500
        );
        vm.prank(addressUpdater);
        contractNameHashes = new bytes32[](3);
        contractAddresses = new address[](3);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("ClaimSetupManager"));
        contractNameHashes[2] = keccak256(abi.encode("WNat"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = mockClaimSetupManager;
        contractAddresses[2] = address(wNat);
        vm.expectRevert("decimals mismatch");
        rNat.updateContractAddresses(contractNameHashes, contractAddresses);
    }

    function testSetLibraryAddressRevert() public {
        vm.prank(governance);
        vm.expectRevert("not a contract");
        rNat.setLibraryAddress(address(0));
    }

    function testSetLibraryAddress() public {
        vm.prank(governance);
        rNat.setLibraryAddress(address(rNatAccount));
        assertEq(rNat.libraryAddress(), address(rNatAccount));
    }

    function testReceiveRewardsRevert() public {
        vm.expectRevert("not a funding address");
        rNat.receiveRewards();
    }

    function testReceiveRewards() public {
        vm.prank(fundingAddress);
        rNat.receiveRewards{ value: 1000 } ();
        assertEq(address(rNat).balance, 1000);
    }

    function testAddProjectsRevertOnlyManager() public {
        vm.expectRevert("only manager");
        rNat.addProjects(new string[](0), new address[](0), new bool[](0));
    }

    function testAddProjectsRevertLengthsMismatch() public {
        vm.prank(manager);
        vm.expectRevert("lengths mismatch");
        rNat.addProjects(new string[](0), new address[](1), new bool[](0));
    }

    function testAddProjects() public {
        vm.prank(manager);
        bool[] memory currentMonthDistributionEnabled = new bool[](2);
        currentMonthDistributionEnabled[0] = true;
        currentMonthDistributionEnabled[1] = false;
        rNat.addProjects(projectNames, projectDistributors, currentMonthDistributionEnabled);
    }

    function testGetProjectsCount() public {
        assertEq(rNat.getProjectsCount(), 0);
        testAddProjects();
        assertEq(rNat.getProjectsCount(), 2);
    }

    function testGetProjectBasicInfo() public {
        testAddProjects();
        (string[] memory names, bool[] memory claimingDisabled) = rNat.getProjectsBasicInfo();
        assertEq(names.length, 2);
        assertEq(names[0], projectNames[0]);
        assertEq(names[1], projectNames[1]);
        assertEq(claimingDisabled.length, 2);
        assertEq(claimingDisabled[0], false);
        assertEq(claimingDisabled[1], false);
    }

    //// assign rewards
    function testAssignRewardsRevertTooFarInPast() public {
        vm.warp(500 + 4 * MONTH);
        vm.expectRevert("month too far in the past");
        vm.prank(manager);
        rNat.assignRewards(2, new uint256[](0), new uint128[](0));
    }

    function testAssignRewardsRevertLengthsMismatch() public {
        vm.prank(manager);
        vm.expectRevert("lengths mismatch");
        rNat.assignRewards(2, new uint256[](0), new uint128[](1));
    }

    function testAssignRewards() public {
        testAddProjects();
        testReceiveRewards();
        uint256[] memory projectIds = new uint256[](2);
        uint128[] memory amounts = new uint128[](2);
        projectIds[0] = 0;
        projectIds[1] = 1;
        amounts[0] = 100;
        amounts[1] = 300;
        vm.startPrank(manager);
        rNat.assignRewards(0, projectIds, amounts);

        amounts[0] = 200;
        amounts[1] = 400;
        rNat.assignRewards(2, projectIds, amounts);
        vm.stopPrank();

        (string memory name, address distributor, , , , uint128 totalAssignedRewards,
            uint128 totalDistributedRewards, uint128 totalClaimedRewards,
            uint128 totalUnassignedUnclaimedRewards, uint256[] memory monthsWithRewards) = rNat.getProjectInfo(0);
        assertEq(name, projectNames[0]);
        assertEq(distributor, projectDistributors[0]);
        assertEq(totalAssignedRewards, 100 + 200);
        assertEq(totalDistributedRewards, 0);
        assertEq(totalClaimedRewards, 0);
        assertEq(totalUnassignedUnclaimedRewards, 0);
        assertEq(monthsWithRewards.length, 2);
        assertEq(monthsWithRewards[0], 0);
        assertEq(monthsWithRewards[1], 2);

        (uint128 assignedRewards, uint128 distributedRewards,
            uint128 claimedRewards, uint128 unassignedUnclaimedRewards) = rNat.getProjectRewardsInfo(1, 0);
        assertEq(assignedRewards, 300);
        assertEq(distributedRewards, 0);
        assertEq(claimedRewards, 0);
        assertEq(unassignedUnclaimedRewards, 0);

        (assignedRewards, , ,) = rNat.getProjectRewardsInfo(1, 2);
        assertEq(assignedRewards, 400);
    }

    function testAssignRewardsRevertExceedsRewards() public {
        testAssignRewards();

        uint256[] memory projectIds = new uint256[](1);
        uint128[] memory amounts = new uint128[](1);
        projectIds[0] = 0;
        amounts[0] = 10;

        vm.prank(manager);
        vm.expectRevert("exceeds assignable rewards");
        rNat.assignRewards(3, projectIds, amounts);
    }

    // assign rewards for not increasign months
    function testAssignRewards2() public {
        testAddProjects();
        testReceiveRewards();
        uint256[] memory projectIds = new uint256[](2);
        uint128[] memory amounts = new uint128[](2);
        projectIds[0] = 0;
        projectIds[1] = 1;
        amounts[0] = 100;
        amounts[1] = 300;

        vm.prank(manager);
        rNat.assignRewards(2, projectIds, amounts);
        (, , , , , uint128 assigned, , , , uint256[] memory monthsWithRewards) = rNat.getProjectInfo(0);
        assertEq(assigned, 100);
        assertEq(monthsWithRewards.length, 1);
        assertEq(monthsWithRewards[0], 2);

        amounts[0] = 50;
        amounts[1] = 150;
        vm.prank(manager);
        rNat.assignRewards(0, projectIds, amounts);
        (, , , , , assigned, , , , monthsWithRewards) = rNat.getProjectInfo(0);
        assertEq(assigned, 150);
        assertEq(monthsWithRewards.length, 2);
        assertEq(monthsWithRewards[0], 0);
        assertEq(monthsWithRewards[1], 2);

        // assign rewards again for month 2
        amounts[0] = 20;
        amounts[1] = 30;
        vm.prank(manager);
        rNat.assignRewards(2, projectIds, amounts);
        (, , , , , assigned, , , , monthsWithRewards) = rNat.getProjectInfo(0);
        assertEq(assigned, 170);
        assertEq(monthsWithRewards.length, 2);
    }

    function testWithdrawUnassignedRewards() public {
        testReceiveRewards();
        testAddProjects();

        uint256[] memory projectIds = new uint256[](2);
        uint128[] memory amounts = new uint128[](2);
        projectIds[0] = 0;
        projectIds[1] = 1;
        amounts[0] = 100;
        amounts[1] = 300;
        vm.prank(manager);
        rNat.assignRewards(0, projectIds, amounts);

        (uint256 totalAssignableRewards, uint256 totalAssignedRewards, , , ) = rNat.getRewardsInfo();

        assertEq(totalAssignableRewards, 1000);
        assertEq(totalAssignedRewards, 400);

        address returnAddr = makeAddr("returnAddr");
        vm.prank(governance);
        rNat.withdrawUnassignedRewards(returnAddr, 600);
        (totalAssignableRewards, totalAssignedRewards, , , ) = rNat.getRewardsInfo();
        assertEq(address(returnAddr).balance, 600);
        assertEq(totalAssignableRewards, 400);
    }

    function testWithdrawUnassignedRewardsRevertAddrZero() public {
        vm.expectRevert("address zero");
        vm.prank(governance);
        rNat.withdrawUnassignedRewards(address(0), 10);
    }

    function testWithdrawUnassignedRewardsRevertFailed() public {
        address recipient = makeAddr("recipient");
        vm.mockCallRevert(
            recipient,
            abi.encode(),
            abi.encode()
        );
        vm.prank(governance);
        vm.expectRevert("Transfer failed");
        rNat.withdrawUnassignedRewards(recipient, 0);
    }

    function testWithdrawUnassignedRewardsRevertInsufficient() public {
        testAssignRewards();

        vm.prank(governance);
        vm.expectRevert("insufficient assignable rewards");
        rNat.withdrawUnassignedRewards(makeAddr("returnAddr"), 2000);
    }

    //// distribute rewards
    function testDistributeRewardsRevertWrongMonth() public {
        vm.warp(500 + 4 * MONTH);
        testAddProjects();

        // month in the future
        vm.expectRevert("distribution for month disabled");
        rNat.distributeRewards(0, 5, new address[](0), new uint128[](0));

        // month expired
        vm.expectRevert("distribution for month disabled");
        rNat.distributeRewards(0, 2, new address[](0), new uint128[](0));

        // project 1 can distribute for the current month
        vm.expectRevert("only distributor");
        rNat.distributeRewards(0, 4, new address[](0), new uint128[](0));

        // project 2 can't distribute for the current month
        vm.expectRevert("distribution for month disabled");
        rNat.distributeRewards(1, 4, new address[](0), new uint128[](0));
    }

    function testDistributeRewardsRevertLengthsMismatch() public {
        vm.expectRevert("lengths mismatch");
        rNat.distributeRewards(0, 0, new address[](0), new uint128[](1));
    }

    function testDistributeRewardsRevertInvalidProject() public {
        // add 2 projects
        testAddProjects();
        vm.expectRevert("invalid project id");
        rNat.distributeRewards(2, 0, new address[](0), new uint128[](0));
    }

    function testDistributeRewardsRevertWrongDistributor() public {
        testAddProjects();
        vm.prank(projectDistributors[1]); // distributor of the second project
        vm.expectRevert("only distributor");
        rNat.distributeRewards(0, 0, new address[](0), new uint128[](0));
    }

    function testDistributeRewardsRevertExceedsAssigned() public {
        testAssignRewards();

        uint128[] memory amounts = new uint128[](2);
        amounts[0] = 100;
        amounts[1] = 1;

        // 100 is assigned for the first project for month 0
        vm.prank(projectDistributors[0]);
        vm.expectRevert("exceeds assigned rewards");
        rNat.distributeRewards(0, 0, rewardRecipients1, amounts);
    }

    function testDistributeRewards() public {
        testAssignRewards();

        // 100 is assigned for the first project for month 0
        uint128[] memory amounts = new uint128[](2);
        amounts[0] = 50;
        amounts[1] = 50;
        vm.prank(projectDistributors[0]);
        rNat.distributeRewards(0, 0, rewardRecipients1, amounts);

        // 300 is assigned for the second project for month 0
        // project 2 doesn't have enabled distribution for current month
        amounts[0] = 100;
        amounts[1] = 200;
        vm.prank(projectDistributors[1]);
        vm.expectRevert("distribution for month disabled");
        rNat.distributeRewards(1, 0, rewardRecipients2, amounts);

        // go to month 1
        vm.warp(500 + MONTH);
        vm.prank(projectDistributors[1]);
        rNat.distributeRewards(1, 0, rewardRecipients2, amounts);

        (uint128 claimable) = rNat.getClaimableRewards(0, rewardRecipients1[0]);
        assertEq(claimable, 50);

        // go to month 3 and distribute rewards for month 2
        vm.warp(500 + 3 * MONTH);

        // 200 is assigned for the first project for month 2
        amounts[0] = 100;
        amounts[1] = 100;
        vm.prank(projectDistributors[0]);
        rNat.distributeRewards(0, 2, rewardRecipients1, amounts);

        // 400 is assigned for the second project for month 2
        amounts[0] = 50;
        amounts[1] = 100;
        vm.prank(projectDistributors[1]);
        rNat.distributeRewards(1, 2, rewardRecipients2, amounts);

        // distribute additional rewards for month 2
        amounts = new uint128[](1);
        address[] memory rewardRecipients = new address[](1);
        rewardRecipients[0] = rewardRecipients2[0];
        amounts[0] = 200;
        vm.prank(projectDistributors[1]);
        rNat.distributeRewards(1, 2, rewardRecipients, amounts);

        (claimable) = rNat.getClaimableRewards(0, rewardRecipients1[0]);
        assertEq(claimable, 50 + 100);
    }

    //// unassign rewards
    function testUnassignRewards() public {
        testAssignRewards();

        // 100 is assigned for the first project for month 0
        uint128[] memory amounts = new uint128[](2);
        amounts[0] = 25;
        amounts[1] = 50;
        vm.prank(projectDistributors[0]);
        rNat.distributeRewards(0, 0, rewardRecipients1, amounts);

        // go to month 1
        vm.warp(500 + MONTH);
        amounts[0] = 100;
        amounts[1] = 100;
        vm.prank(projectDistributors[1]);
        rNat.distributeRewards(1, 0, rewardRecipients2, amounts);

        // go to month 3 and distribute rewards for month 2
        vm.warp(500 + 3 * MONTH);

        // 200 is assigned for the first project for month 2
        amounts[0] = 100;
        amounts[1] = 100;
        vm.prank(projectDistributors[0]);
        rNat.distributeRewards(0, 2, rewardRecipients1, amounts);

        // 400 is assigned for the second project for month 2
        amounts[0] = 50;
        amounts[1] = 100;
        vm.prank(projectDistributors[1]);
        rNat.distributeRewards(1, 2, rewardRecipients2, amounts);

        // 700 was assigned; 350 should be undistributed (assigned but not distributed)
        (, , , , , uint128 assigned, uint128 distributed, , , ) = rNat.getProjectInfo(1);
        assertEq(assigned - distributed, 300 + 400 - (100 + 100 + 100 + 50));
        assertEq(assigned, 700);

        // unassign rewards for project 2
        // manager can unassign only for months for which distribution is not possible anymore
        // => disable distribution and unassign from governance address
        uint256[] memory projectIds = new uint256[](1);
        projectIds[0] = 1;
        vm.prank(manager);
        rNat.disableDistribution(projectIds);
        vm. prank(governance);
        uint256[] memory months = new uint256[](2);
        months[0] = 0;
        months[1] = 2;
        rNat.unassignRewards(1, months);
        // only 350 should be assigned (that was already distributed)
        (, , , , , , assigned, , , ) = rNat.getProjectInfo(1);
        assertEq(assigned, 350);

        // for project 1 unassign rewards for month 0
        (, , , , , assigned, , , , ) = rNat.getProjectInfo(0);
        assertEq(assigned, 300);
        projectIds[0] = 0;
        months = new uint256[](1);
        months[0] = 0;
        vm.prank(manager);
        rNat.unassignRewards(0, months);
        // 275 was already distributed
        (, , , , , assigned, , , , ) = rNat.getProjectInfo(0);
        assertEq(assigned, 275);
    }

    function testUnassignRewardsRevertNotAllowed() public {
        testAssignRewards();

        uint256[] memory months = new uint256[](1);
        months[0] = 0;

        vm.prank(governance);
        vm.expectRevert("unassignment not allowed");
        rNat.unassignRewards(0, months);
    }

    function testUnassignRevertWrongAddress() public {
        testAssignRewards();

        uint256[] memory months = new uint256[](1);
        months[0] = 0;

        vm.expectRevert("only manager or governance");
        rNat.unassignRewards(0, months);
    }

    function testUnassignUnclaimedRewards() public {
        testSetLibraryAddress();
        testDistributeRewards();
        _mockGetExecutorCurrentFeeValue(rewardRecipients1[0], 0);

        uint256[] memory projectIds = new uint256[](1);
        projectIds[0] = 0;
        vm.prank(rewardRecipients1[0]);
        rNat.claimRewards(projectIds, 2);

        // unassign unassignUnclaimedRewards for project 1, month 0
        uint256[] memory months = new uint256[](1);
        months[0] = 0;
        (uint128 assigned, uint128 distributed, uint128 claimed, uint128 unassignedUnclaimed) =
            rNat.getProjectRewardsInfo(0, 0);
        assertEq(assigned, 100);
        assertEq(distributed, 100);
        assertEq(claimed, 50);
        assertEq(unassignedUnclaimed, 0);
        (uint128 userAssigned, uint128 userClaimed, bool claimable) =
            rNat.getOwnerRewardsInfo(0, 0, rewardRecipients1[1]);
        assertEq(userAssigned, 50);
        assertEq(userClaimed, 0);
        assertEq(claimable, true);

        // can't unassign unclaimed before claiming is disabled
        vm.prank(governance);
        vm.expectRevert("claiming not disabled");
        rNat.unassignUnclaimedRewards(0, months);

        // disable claiming
        vm.prank(manager);
        rNat.disableClaiming(projectIds);

        // unassign unclaimed rewards
        vm.prank(governance);
        vm.expectEmit();
        emit DistributionPermissionUpdated(projectIds, true);
        rNat.unassignUnclaimedRewards(0, months);

        (assigned, distributed, claimed, unassignedUnclaimed) =
            rNat.getProjectRewardsInfo(0, 0);
        assertEq(assigned, 100);
        assertEq(distributed, 100);
        assertEq(claimed, 50);
        assertEq(unassignedUnclaimed, 50);

        (userAssigned, userClaimed, claimable) =
            rNat.getOwnerRewardsInfo(0, 0, rewardRecipients1[1]);
        assertEq(userAssigned, 50);
        assertEq(userClaimed, 0);
        assertEq(claimable, false);
    }

    ////
    function testDisableDistribution() public {
        testAssignRewards();

        uint128[] memory amounts = new uint128[](2);
        amounts[0] = 50;
        amounts[1] = 50;
        vm.prank(projectDistributors[0]);
        rNat.distributeRewards(0, 0, rewardRecipients1, amounts);

        // go to month 1 and distribute rewards for project 2
        vm.warp(500 + MONTH);
        vm.prank(projectDistributors[1]);
        rNat.distributeRewards(1, 0, rewardRecipients2, amounts);

        (uint128 claimable) = rNat.getClaimableRewards(0, rewardRecipients1[0]);
        assertEq(claimable, 50);

        // disable distribution for project 1
        vm.prank(manager);
        uint256[] memory projectsToDisable = new uint256[](1);
        projectsToDisable[0] = 0;
        rNat.disableDistribution(projectsToDisable);

        // go to month 3 and distribute rewards for month 2
        vm.warp(500 + 3 * MONTH);

        // project 1 has distribution disabled
        amounts[0] = 100;
        amounts[1] = 100;
        vm.prank(projectDistributors[0]);
        vm.expectRevert("distribution disabled");
        rNat.distributeRewards(0, 2, rewardRecipients1, amounts);

        // project 2 is still enabled
        amounts[0] = 50;
        amounts[1] = 100;
        vm.prank(projectDistributors[1]);
        rNat.distributeRewards(1, 2, rewardRecipients2, amounts);
    }

    function testAssignRewardsRevertDistributionDisabled() public {
        testDisableDistribution();

        uint256[] memory projectIds = new uint256[](1);
        uint128[] memory amounts = new uint128[](1);
        projectIds[0] = 0;
        amounts[0] = 100;
        vm.prank(manager);
        vm.expectRevert("distribution disabled");
        rNat.assignRewards(2, projectIds, amounts);
    }

    function testEnableDistribution() public {
        testDisableDistribution();

        // enable distribution for project 1
        vm.prank(governance);
        uint256[] memory projectsToEnable = new uint256[](1);
        projectsToEnable[0] = 0;
        rNat.enableDistribution(projectsToEnable);

        uint128[] memory amounts = new uint128[](2);
        amounts[0] = 100;
        amounts[1] = 100;
        vm.prank(projectDistributors[0]);
        rNat.distributeRewards(0, 2, rewardRecipients1, amounts);

        (uint128 claimable) = rNat.getClaimableRewards(0, rewardRecipients1[0]);
        assertEq(claimable, 50 + 100);
    }

    function testEnableDistributionRevertClaimingPermanentlyDisabled() public {
        testUnassignUnclaimedRewards();

        uint256[] memory projectsToEnable = new uint256[](1);
        projectsToEnable[0] = 0;

        vm.prank(governance);
        vm.expectRevert("claiming permanently disabled");
        rNat.enableDistribution(projectsToEnable);
    }

    function testGetOwnerRewardsInfo() public {
        testDistributeRewards();
        (uint128 assigned, uint128 claimed, ) =
            rNat.getOwnerRewardsInfo(0, 0, rewardRecipients1[0]);
        assertEq(assigned, 50);
        assertEq(claimed, 0);

        (assigned, , ) = rNat.getOwnerRewardsInfo(0, 0, rewardRecipients1[1]);
        assertEq(assigned, 50);

        (assigned, , ) = rNat.getOwnerRewardsInfo(1, 0, rewardRecipients2[0]);
        assertEq(assigned, 100);

        (assigned, , ) = rNat.getOwnerRewardsInfo(1, 0, rewardRecipients2[1]);
        assertEq(assigned, 200);

        (assigned, claimed, ) = rNat.getOwnerRewardsInfo(0, 5, rewardRecipients2[1]);
        assertEq(assigned, 0);
        assertEq(claimed, 0);
    }

    function testGetProjectInfo() public {
        testDistributeRewards();

        (string memory name, address distributor, , , , uint128 totalAssignedRewards,
            uint128 totalDistributedRewards, uint128 totalClaimedRewards,
            uint128 totalUnassignedUnclaimedRewards, uint256[] memory monthsWithRewards) = rNat.getProjectInfo(0);
        assertEq(name, projectNames[0]);
        assertEq(distributor, projectDistributors[0]);
        assertEq(totalAssignedRewards, 100 + 200);
        assertEq(totalDistributedRewards, 100 + 200);
        assertEq(totalClaimedRewards, 0);
        assertEq(totalUnassignedUnclaimedRewards, 0);
        assertEq(monthsWithRewards.length, 2);
        assertEq(monthsWithRewards[0], 0);
        assertEq(monthsWithRewards[1], 2);

        (name, distributor, , , , totalAssignedRewards,totalDistributedRewards,
        totalClaimedRewards, totalUnassignedUnclaimedRewards, monthsWithRewards) = rNat.getProjectInfo(1);
        assertEq(name, projectNames[1]);
        assertEq(distributor, projectDistributors[1]);
        assertEq(totalAssignedRewards, 300 + 400);
        assertEq(totalDistributedRewards, 300 + 150 + 200);
        assertEq(totalClaimedRewards, 0);
        assertEq(totalUnassignedUnclaimedRewards, 0);
        assertEq(monthsWithRewards.length, 2);
        assertEq(monthsWithRewards[0], 0);
        assertEq(monthsWithRewards[1], 2);
    }

    function testGetProjectRewardsInfo() public {
        testDistributeRewards();

        (uint128 assignedRewards, uint128 distributedRewards,
            uint128 claimedRewards, uint128 totalUnassignedUnclaimedRewards) = rNat.getProjectRewardsInfo(0, 0);
        assertEq(assignedRewards, 100);
        assertEq(distributedRewards, 100);
        assertEq(claimedRewards, 0);
        assertEq(totalUnassignedUnclaimedRewards, 0);

        (assignedRewards, distributedRewards,
            claimedRewards, totalUnassignedUnclaimedRewards) = rNat.getProjectRewardsInfo(0, 2);
        assertEq(assignedRewards, 200);
        assertEq(distributedRewards, 200);
        assertEq(claimedRewards, 0);
        assertEq(totalUnassignedUnclaimedRewards, 0);

        (assignedRewards, distributedRewards,
            claimedRewards, totalUnassignedUnclaimedRewards) = rNat.getProjectRewardsInfo(1, 0);
        assertEq(assignedRewards, 300);
        assertEq(distributedRewards, 300);
        assertEq(claimedRewards, 0);
        assertEq(totalUnassignedUnclaimedRewards, 0);

        (assignedRewards, distributedRewards,
            claimedRewards, totalUnassignedUnclaimedRewards) = rNat.getProjectRewardsInfo(1, 2);
        assertEq(assignedRewards, 400);
        assertEq(distributedRewards, 150 + 200);
        assertEq(claimedRewards, 0);
        assertEq(totalUnassignedUnclaimedRewards, 0);
    }

    //// claiming rewards
    function testClaimRewardsRevertWrongMonth() public {
        vm.expectRevert("month in the future");
        rNat.claimRewards(new uint256[](0), 1);
    }

    function testClaimRewardsRevertWrongProject() public {
        uint256[] memory projectIds = new uint256[](1);
        // add 2 projects
        testAddProjects();
        projectIds[0] = 2;
        vm.expectRevert("invalid project id");
        rNat.claimRewards(projectIds, 0);
    }

    function testClaimRevertLibraryAddressNotSet() public {
        testAddProjects();
        uint256[] memory projectIds = new uint256[](1);
        projectIds[0] = 0;
        vm.expectRevert("library address not set yet");
        rNat.claimRewards(projectIds, 0);
    }

    // rewardRecipient1 claims rewards for project1 and for months 0 and 2
    function testClaimRewards1() public {
        testSetLibraryAddress();
        testDistributeRewards();
        _mockGetExecutorCurrentFeeValue(rewardRecipients1[0], 0);

        uint256[] memory projectIds = new uint256[](1);
        projectIds[0] = 0;
        vm.prank(rewardRecipients1[0]);
        rNat.claimRewards(projectIds, 2);

        (uint128 assigned, uint128 claimed, ) = rNat.getOwnerRewardsInfo(0, 0, rewardRecipients1[0]);
        assertEq(assigned, 50);
        assertEq(claimed, 50);

        assertEq(rNat.getClaimableRewards(0, rewardRecipients1[0]), 0);
        assertEq(rNat.getClaimableRewards(1, rewardRecipients1[0]), 100 + 50 + 200);
        assertEq(rNat.getClaimableRewards(0, rewardRecipients1[1]), 50 + 100);

        (uint256 wNatBalance, uint256 rNatBalance, uint256 lockedBalance) = rNat.getBalancesOf(rewardRecipients1[0]);

        assertEq(wNatBalance, 50 + 100);
        assertEq(rNatBalance, 150);

        // time is at the beginning of the month 3
        // locked balance should be: ceil(50 * 9/12) + ceil(100 * 11/12) = 38 + 92 = 130
        assertEq(lockedBalance, 130);

        // move 4 days forward
        vm.warp(500 + 3 * MONTH + 4 days);
        // locked balance should be:
        // ceil(50 * (9 * 2.592.000 - 345600) / (12 * 2.592.000) +
        // ceil(100 * (11 * 2.592.000 - 345600) / 12 * 2.592.000) = 37 + 91 = 128
        (, , lockedBalance) = rNat.getBalancesOf(rewardRecipients1[0]);
        assertEq(lockedBalance, 128);
    }

    function testDisableClaiming() public {
        testSetLibraryAddress();
        testDistributeRewards();
        _mockGetExecutorCurrentFeeValue(rewardRecipients1[0], 0);

        uint256[] memory projectIds = new uint256[](1);
        projectIds[0] = 0;
        vm.prank(rewardRecipients1[0]);
        rNat.claimRewards(projectIds, 2);

        (uint128 assigned, uint128 claimed, ) = rNat.getOwnerRewardsInfo(0, 0, rewardRecipients1[0]);
        assertEq(assigned, 50);
        assertEq(claimed, 50);

        assertEq(rNat.getClaimableRewards(0, rewardRecipients1[1]), 150);

        // disable claiming
        vm.prank(manager);
        uint256[] memory projectsToDisable = new uint256[](1);
        projectsToDisable[0] = 0;
        vm.expectEmit();
        emit ClaimingPermissionUpdated(projectsToDisable, true);
        rNat.disableClaiming(projectsToDisable);

        assertEq(rNat.getClaimableRewards(0, rewardRecipients1[1]), 0);

        // second recipient for project 1 wants to claim
        vm.prank(rewardRecipients1[1]);
        vm.expectRevert("claiming disabled");
        rNat.claimRewards(projectIds, 2);
    }

    function testEnableClaiming() public {
        testDisableClaiming();

        // enable claiming
        uint256[] memory projectsToEnable = new uint256[](1);
        projectsToEnable[0] = 0;
        vm.prank(governance);
        vm.expectEmit();
        emit ClaimingPermissionUpdated(projectsToEnable, false);
        rNat.enableClaiming(projectsToEnable);

        // second recipient for project 1 claims
        _mockGetExecutorCurrentFeeValue(rewardRecipients1[1], 0);
        vm.prank(rewardRecipients1[1]);
        rNat.claimRewards(projectsToEnable, 2);

        (uint128 assigned, uint128 claimed, ) = rNat.getOwnerRewardsInfo(0, 0, rewardRecipients1[0]);
        assertEq(assigned, 50);
        assertEq(claimed, 50);
    }

    function testLockedAmount() public {
        testSetLibraryAddress();
        _mockGetExecutorCurrentFeeValue(rewardRecipients1[0], 10);
        testAddProjects();

        vm.deal(fundingAddress, 20 * 10**18);

        // receive rewards
        vm.prank(fundingAddress);
        rNat.receiveRewards{ value: 10 * 10**18 }();

        // assign rewards
        uint256[] memory projectIds = new uint256[](1);
        uint128[] memory amounts = new uint128[](1);
        projectIds[0] = 0;
        amounts[0] = 10 * 10**18;
        vm.prank(manager);
        rNat.assignRewards(0, projectIds, amounts);

        // distribute rewards
        amounts = new uint128[](2);
        amounts[0] = 10 * 10 ** 18;
        amounts[1] = 0;
        vm.prank(projectDistributors[0]);
        rNat.distributeRewards(0, 0, rewardRecipients1, amounts);

        // claim rewards
        vm.prank(rewardRecipients1[0]);
        rNat.claimRewards(projectIds, 0);

        // get balances
        (, uint256 rNatBalance, uint256 lockedBalance) = rNat.getBalancesOf(rewardRecipients1[0]);
        assertEq(rNatBalance, 10 * 10**18);
        // first month starts at 500, now is 1000
        // locked should be ceil(10 ** 18 * (12 * 2.592.000 + 500 - 1000) / 12 * 2.592.000) =
        // 9.999.839.248.971.193.416
        assertEq(lockedBalance, 9999839248971193416);

        // move one second forward; locked should be
        // ceil(10 ** 18 * (12 * 2.592.000 + 500 - 1000 - 1) / 12 * 2.592.000) = 9.999.838.927.469.135.803
        vm.warp(1000 + 1);
        (, rNatBalance, lockedBalance) = rNat.getBalancesOf(rewardRecipients1[0]);
        assertEq(rNatBalance, 10 * 10**18);
        assertEq(lockedBalance, 9999838927469135803);
    }

    function testDistributeAndClaimZ() public {
        testSetLibraryAddress();
        testAssignRewards();
        _mockGetExecutorCurrentFeeValue(rewardRecipients1[0], 0);
        _mockGetExecutorCurrentFeeValue(rewardRecipients1[1], 0);

        // 100 is assigned for the first project for month 0
        uint128[] memory amounts = new uint128[](2);
        amounts[0] = 0;
        amounts[1] = 50;
        vm.prank(projectDistributors[0]);
        rNat.distributeRewards(0, 0, rewardRecipients1, amounts);

        uint256[] memory projectIds = new uint256[](1);
        projectIds[0] = 0;
        vm.prank(rewardRecipients1[1]);
        vm.expectEmit();
        emit RewardsClaimed(0, 0, rewardRecipients1[1], 50);
        rNat.claimRewards(projectIds, 0);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        vm.prank(rewardRecipients1[0]);
        rNat.claimRewards(projectIds, 0);
        // no event should be emitted because the amount is 0
        assertEq(entries.length, 0);
    }

    function testGetBalances() public {
        testClaimRewards1();

        // rewardRecipient1 receives some FTSO rewards/airdrops to its account
        address delAccAddr = address(rNat.getRNatAccount(rewardRecipients1[0]));
        address addr = makeAddr("addr");
        vm.deal(addr, 100);
        vm.prank(addr);
        wNat.depositTo {value: 51} (delAccAddr);
        (uint256 wNatBalance, , uint256 lockedBalance) = rNat.getBalancesOf(rewardRecipients1[0]);
        assertEq(wNatBalance, 150 + 51);
        assertEq(lockedBalance, 128);
        assertEq(rNat.balanceOf(rewardRecipients1[0]), 150);
    }

    // rewardRecipient1 claims rewards for project1 and project2 and for months 0 and 2
    // function testClaimRewards2() public {
    // }


    function testTransferExternalToken() public {
        testClaimRewards1();
        address delAccAddr = address(rNat.getRNatAccount(rewardRecipients1[0]));
        ERC20Mock token = new ERC20Mock("XTOK", "XToken");

        // Mint tokens
        token.mintAmount(delAccAddr, 100);
        assertEq(token.balanceOf(delAccAddr), 100);

        // Should allow transfer
        vm.prank(rewardRecipients1[0]);
        rNat.transferExternalToken(token, 70);

        assertEq(token.balanceOf(delAccAddr), 30);
        assertEq(token.balanceOf(rewardRecipients1[0]), 70);
    }

    function testWithdrawAndWrap() public {
        testClaimRewards1();
        (uint256 wNatBalance, , uint256 lockedBalance) = rNat.getBalancesOf(rewardRecipients1[0]);
        assertEq(wNatBalance - lockedBalance, 22);
        vm.prank(rewardRecipients1[0]);
        rNat.withdraw(15, true);
        (wNatBalance, , lockedBalance) = rNat.getBalancesOf(rewardRecipients1[0]);
        assertEq(wNatBalance, 150 - 15);
        assertEq(wNat.balanceOf(rewardRecipients1[0]), 15);
        assertEq(wNatBalance - lockedBalance, 22 - 15);
    }

    function testWithdraw() public {
        testClaimRewards1();
        (uint256 wNatBalance, , uint256 lockedBalance) = rNat.getBalancesOf(rewardRecipients1[0]);
        assertEq(wNatBalance - lockedBalance, 22);
        vm.prank(rewardRecipients1[0]);
        rNat.withdraw(15, false);
        (wNatBalance, , lockedBalance) = rNat.getBalancesOf(rewardRecipients1[0]);
        assertEq(wNatBalance, 150 - 15);
        assertEq(wNat.balanceOf(rewardRecipients1[0]), 0);
        assertEq(rewardRecipients1[0].balance, 15);
        assertEq(wNatBalance - lockedBalance, 22 - 15);
    }

    function testWithdrawRevertInsufficientBalance() public {
        testClaimRewards1();
        vm.prank(rewardRecipients1[0]);
        vm.expectRevert("insufficient balance");
        rNat.withdraw(1500, false);
    }

    function testWithdrawAll() public {
        testClaimRewards1();
        vm.prank(rewardRecipients1[0]);
        rNat.withdrawAll(false);
        (uint256 wNatBalance, uint256 rNatBalance, uint256 lockedBalance) = rNat.getBalancesOf(rewardRecipients1[0]);
        assertEq(wNatBalance, 0);
        assertEq(rNatBalance, 0);
        assertEq(rewardRecipients1[0].balance, 22 + (150 - 22) / 2);
        assertEq(wNatBalance - lockedBalance, 0);
        assertEq(BURN_ADDRESS.balance, (150 - 22) / 2);
    }

    function testWithdrawAllWrap() public {
        testClaimRewards1();
        vm.prank(rewardRecipients1[0]);
        rNat.withdrawAll(true);
        (uint256 wNatBalance, uint256 rNatBalance, uint256 lockedBalance) = rNat.getBalancesOf(rewardRecipients1[0]);
        assertEq(wNatBalance, 0);
        assertEq(rNatBalance, 0);
        assertEq(wNat.balanceOf(rewardRecipients1[0]), 22 + (150 - 22) / 2);
        assertEq(wNatBalance - lockedBalance, 0);
        assertEq(BURN_ADDRESS.balance, (150 - 22) / 2);
    }

    // first withdraw non-rNat rewards, then rNat rewards
    function testWithdraw1() public {
        testClaimRewards1();
        address delAccAddr = address(rNat.getRNatAccount(rewardRecipients1[0]));
        address addr = makeAddr("addr");
        vm.deal(addr, 100);
        vm.prank(addr);
        wNat.depositTo {value: 51} (delAccAddr);

        (uint256 wNatBalance, uint256 rNatBalance, ) = rNat.getBalancesOf(rewardRecipients1[0]);
        assertEq(wNatBalance, 150 + 51);
        assertEq(rNatBalance, 150);

        // withdraw 40 wNat
        // rNat balance should not change
        vm.prank(rewardRecipients1[0]);
        rNat.withdraw(40, false);
        (wNatBalance, rNatBalance, ) = rNat.getBalancesOf(rewardRecipients1[0]);
        assertEq(wNatBalance, 150 + 51 - 40);
        assertEq(rNatBalance, 150);

        // withdraw 20 rNat
        // it should withdraw 11 non-rNat and 9 rNat
        vm.prank(rewardRecipients1[0]);
        rNat.withdraw(20, false);
        (wNatBalance, rNatBalance, ) = rNat.getBalancesOf(rewardRecipients1[0]);
        assertEq(wNatBalance, 150 + 51 - 40 - 20);
        assertEq(rNatBalance, 150 - 9);
    }

    function testGetRNatAccountRevert() public {
        vm.expectRevert("no RNat account");
        rNat.getRNatAccount(makeAddr("acc"));
    }

    function testGetCurrentMonth() public {
        assertEq(rNat.getCurrentMonth(), 0);

        vm.warp(500 + MONTH);
        assertEq(rNat.getCurrentMonth(), 1);

        vm.warp(500 + 2 * MONTH - 1);
        assertEq(rNat.getCurrentMonth(), 1);

        vm.warp(500 + 2 * MONTH);
        assertEq(rNat.getCurrentMonth(), 2);
    }


    //// update project, manager, funding addresses
    function testUpdateProjectRevertWrongId() public {
        testAddProjects();
        vm.prank(manager);
        vm.expectRevert("invalid project id");
        rNat.updateProject(2, "newName", makeAddr("newDistributor"), false);
    }

    function testUpdateProject() public {
        testDistributeRewards();

        (string memory name, address distributor, , , , , , , , ) = rNat.getProjectInfo(1);
        assertEq(name, "project2");
        assertEq(distributor, projectDistributors[1]);

        // update project
        vm.prank(manager);
        rNat.updateProject(1, "newName", makeAddr("newDistributor"), false);
        (name, distributor, , , , , , , , ) = rNat.getProjectInfo(1);
        assertEq(name, "newName");
        assertEq(distributor, makeAddr("newDistributor"));


        // try to distribute remaining rewards for the updated project
        // old distributor -> should revert
        uint128[] memory amounts = new uint128[](1);
        address[] memory rewardRecipients = new address[](1);
        rewardRecipients[0] = rewardRecipients2[0];
        amounts[0] = 50;
        vm.prank(projectDistributors[1]);
        vm.expectRevert("only distributor");
        rNat.distributeRewards(1, 2, rewardRecipients, amounts);

        // distribute with new distributor
        vm.prank(makeAddr("newDistributor"));
        rNat.distributeRewards(1, 2, rewardRecipients, amounts);
        (uint128 assignedRewards, uint128 distributedRewards, , ) =
            rNat.getProjectRewardsInfo(1, 2);
        assertEq(assignedRewards, 400);
        assertEq(distributedRewards, 150 + 200 + 50);
    }

    function testSetManager() public {
        testAddProjects();
        vm.prank(governance);
        rNat.setManager(makeAddr("newManager"));
        assertEq(rNat.manager(), makeAddr("newManager"));

        vm.prank(manager);
        vm.expectRevert("only manager");
        rNat.updateProject(1, "newName", makeAddr("newDistributor"), false);

        // update project with the new manager
        vm.prank(makeAddr("newManager"));
        rNat.updateProject(1, "newName", makeAddr("newDistributor"), false);
    }

    function testSetManagerRevert() public {
        vm.prank(governance);
        vm.expectRevert("address zero");
        rNat.setManager(address(0));
    }

    function testSetFundingAddress() public {
        vm.prank(governance);
        address newFundingAddress = makeAddr("newFundingAddress");
        rNat.setFundingAddress(newFundingAddress);
        address fundingAddr = rNat.fundingAddress();
        assertEq(fundingAddr, makeAddr("newFundingAddress"));

        // fund new funding addresses
        vm.deal(makeAddr("newFundingAddress"), 1000);

        // receive rewards
        // old funding address
        vm.prank(fundingAddress);
        vm.expectRevert("not a funding address");
        rNat.receiveRewards{ value: 500 } ();
        // new funding address
        vm.prank(makeAddr("newFundingAddress"));
        rNat.receiveRewards{ value: 500 } ();
        assertEq(address(rNat).balance, 500);
    }

    function testRevertSomeERC20Methods() public {
        vm.expectRevert("transfer not supported");
        rNat.transfer(makeAddr("addr"), 10);

        vm.expectRevert("allowance not supported");
        rNat.allowance(makeAddr("addr1"), makeAddr("addr2"));

        vm.expectRevert("approval not supported");
        rNat.approve(makeAddr("addr"), 10);

        vm.expectRevert("transfer not supported");
        rNat.transferFrom(makeAddr("addr1"), makeAddr("addr2"), 10);
    }

    function testUpdateAddressesRevertWrongWNat() public {
        vm.prank(addressUpdater);
        contractNameHashes = new bytes32[](3);
        contractAddresses = new address[](3);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("ClaimSetupManager"));
        contractNameHashes[2] = keccak256(abi.encode("WNat"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = mockClaimSetupManager;
        contractAddresses[2] = makeAddr("newWNat");
        vm.expectRevert("wrong wNat address");
        rNat.updateContractAddresses(contractNameHashes, contractAddresses);
    }

    function testSupply() public {
        testDistributeRewards();
        testSetLibraryAddress();

        (uint256 locked, , uint256 claimed) = rNat.getTokenPoolSupplyData();
        assertEq(locked, 1000);
        assertEq(claimed, 0);

        // user claims and withdraws
        _mockGetExecutorCurrentFeeValue(rewardRecipients1[0], 0);
        uint256[] memory projectIds = new uint256[](1);
        projectIds[0] = 0;
        vm.startPrank(rewardRecipients1[0]);
        rNat.claimRewards(projectIds, 2);
        rNat.withdraw(5, false);
        vm.stopPrank();
        (locked, , claimed) = rNat.getTokenPoolSupplyData();
        assertEq(locked, 1000);
        assertEq(claimed, 5);
        assertEq(rNat.totalSupply(), 150 - 5);


        // receive some more rewards
        vm.prank(fundingAddress);
        rNat.receiveRewards{ value: 500 } ();
        (locked, , claimed) = rNat.getTokenPoolSupplyData();
        assertEq(locked, 1000 + 500);
        assertEq(claimed, 5);

        // withdraw part of unassigned (400)
        vm.prank(governance);
        rNat.withdrawUnassignedRewards(makeAddr("addr"), 400);
        (locked, , claimed) = rNat.getTokenPoolSupplyData();
        assertEq(locked, 1000 + 500 - 400 + 400);
        assertEq(claimed, 5 + 400);
    }

    function testGetContractName() public {
        assertEq(rNat.getContractName(), "RNat");
    }

    function testSetClaimExecutors1() public {
        testClaimRewards1();

        address[] memory executors = new address[](2);
        executors[0] = makeAddr("executor1");
        executors[1] = rewardRecipients1[0];

        address delAccAddr = address(rNat.getRNatAccount(rewardRecipients1[0]));
        vm.deal(address(delAccAddr), 500);
        uint256 balanceBefore = rewardRecipients1[0].balance;

        vm.deal(rewardRecipients1[0], 3);
        vm.prank(rewardRecipients1[0]);
        rNat.setClaimExecutors {value: 3} (executors);
        // 500 (current balance of delAccAddr) is sent back to owner
        assertEq(rewardRecipients1[0].balance, 500 + balanceBefore);
    }

    //// incentive pool
    function testEnableIncentivePool() public {
        assertEq(rNat.incentivePoolEnabled(), false);
        vm.prank(governance);
        rNat.enableIncentivePool();
        assertEq(rNat.incentivePoolEnabled(), true);

        incentivePool = makeAddr("incentivePool");
        vm.deal(incentivePool, 50000);
        // add incentive pool address
        vm.prank(addressUpdater);
        contractNameHashes = new bytes32[](4);
        contractAddresses = new address[](4);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("ClaimSetupManager"));
        contractNameHashes[2] = keccak256(abi.encode("WNat"));
        contractNameHashes[3] = keccak256(abi.encode("IncentivePool"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = mockClaimSetupManager;
        contractAddresses[2] = address(wNat);
        contractAddresses[3] = incentivePool;
        rNat.updateContractAddresses(contractNameHashes, contractAddresses);
    }

    function testReceiveIncentive() public {
        testEnableIncentivePool();

        // receive rewards
        vm.prank(incentivePool);
        rNat.receiveIncentive{value: 3000} ();

        (uint256 locked, , ) = rNat.getTokenPoolSupplyData();
        assertEq(locked, 3000);
    }

    function testSetDailyAuthorizedIncentive() public {
        testEnableIncentivePool();
        vm.warp(123);
        vm.prank(incentivePool);
        rNat.setDailyAuthorizedIncentive(1000);

        vm.prank(incentivePool);
        rNat.receiveIncentive{value: 3000} ();
        (uint256 authorizedIncentive, uint256 receivedIncentive,
            uint256 lastAuthTs, uint256 dailyAuthIncentive) = rNat.getIncentivePoolReceiverInfo();
        assertEq(authorizedIncentive, 1000);
        assertEq(dailyAuthIncentive, 1000);
        assertEq(receivedIncentive, 3000);
        assertEq(lastAuthTs, 123);

        vm.warp(234);
        vm.startPrank(incentivePool);
        rNat.setDailyAuthorizedIncentive(8);
        rNat.receiveIncentive{value: 5} ();
        vm.stopPrank();
        (authorizedIncentive, receivedIncentive, lastAuthTs, dailyAuthIncentive) = rNat.getIncentivePoolReceiverInfo();
        assertEq(authorizedIncentive, 1000 + 8);
        assertEq(dailyAuthIncentive, 8);
        assertEq(receivedIncentive, 3000 + 5);
        assertEq(lastAuthTs, 234);
        assertEq(rNat.getExpectedBalance(), 3000 + 5);
    }

    function testSetDailyAuthorizedIncentiveRevert() public {
        testEnableIncentivePool();
        vm.expectRevert("incentive pool only");
        rNat.setDailyAuthorizedIncentive(1000);
    }

    function testGetIncentivePoolAddress() public {
        testEnableIncentivePool();
        assertEq(rNat.getIncentivePoolAddress(), incentivePool);
    }


    function _mockGetExecutorCurrentFeeValue(address _executor, uint256 _fee) internal {
        vm.mockCall(
            mockClaimSetupManager,
            abi.encodeWithSelector(
                IClaimSetupManager.getExecutorCurrentFeeValue.selector,
                _executor
            ),
            abi.encode(_fee)
        );
    }



}