// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../../contracts/staking/implementation/ValidatorRewardOffersManager.sol";
import "../../../../contracts/protocol/implementation/RewardManager.sol";

contract ValidatorRewardOffersManagerTest is Test {

    ValidatorRewardOffersManager private validatorRewardOffersManager;

    address private governance;
    address private addressUpdater;
    address private mockRewardManager;
    address private mockFlareSystemsManager;
    address private mockInflation;
    RewardManager private rewardManager;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    uint16 internal constant MAX_BIPS = 1e4;
    uint24 internal constant PPM_MAX = 1e6;
    address private claimBackAddr;
    address private sender;

    uint64 internal constant DAY = 1 days;

    event InflationRewardsOffered(
        // reward epoch id
        uint24 indexed rewardEpochId,
        // amount (in wei) of reward in native coin
        uint256 amount
    );

    function setUp() public {
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");

        validatorRewardOffersManager = new ValidatorRewardOffersManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater
        );

        mockRewardManager = makeAddr("rewardManager");
        mockFlareSystemsManager = makeAddr("flareSystemsManager");
        mockInflation = makeAddr("inflation");

        rewardManager = new RewardManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            address(0),
            0
        );

        vm.startPrank(addressUpdater);
        contractNameHashes = new bytes32[](4);
        contractAddresses = new address[](4);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("RewardManager"));
        contractNameHashes[2] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[3] = keccak256(abi.encode("Inflation"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = address(rewardManager);
        // contractAddresses[1] = mockRewardManager;
        contractAddresses[2] = mockFlareSystemsManager;
        contractAddresses[3] = mockInflation;
        validatorRewardOffersManager.updateContractAddresses(contractNameHashes, contractAddresses);

        // set contracts on reward manager
        contractNameHashes = new bytes32[](8);
        contractAddresses = new address[](8);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("VoterRegistry"));
        contractNameHashes[2] = keccak256(abi.encode("ClaimSetupManager"));
        contractNameHashes[3] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[4] = keccak256(abi.encode("FlareSystemsCalculator"));
        contractNameHashes[5] = keccak256(abi.encode("PChainStakeMirror"));
        contractNameHashes[6] = keccak256(abi.encode("WNat"));
        contractNameHashes[7] = keccak256(abi.encode("RewardManagerProxy"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = makeAddr("voterRegistry");
        contractAddresses[2] = makeAddr("claimSetupManager");
        contractAddresses[3] = mockFlareSystemsManager;
        contractAddresses[4] = makeAddr("flareSystemsCalculator");
        contractAddresses[5] = makeAddr("pChainStakeMirror");
        contractAddresses[6] = makeAddr("wNat");
        contractAddresses[7] = makeAddr("rewardManagerProxy");
        rewardManager.updateContractAddresses(contractNameHashes, contractAddresses);
        vm.stopPrank();

        // set reward offers manager list on reward manager
        address[] memory rewardOffersManagers = new address[](1);
        rewardOffersManagers[0] = address(validatorRewardOffersManager);
        vm.prank(governance);
        rewardManager.setRewardOffersManagerList(rewardOffersManagers);

        // fund inflation contract
        vm.deal(mockInflation, 1 ether);
    }

    function testGetContractName() public {
        assertEq(validatorRewardOffersManager.getContractName(), "ValidatorRewardOffersManager");
    }

    function testTriggerInflationOffers() public {
        vm.startPrank(mockInflation);
        // set daily authorized inflation
        vm.warp(100); // block.timestamp = 100
        validatorRewardOffersManager.setDailyAuthorizedInflation(5000);
        ( , uint256 authorizedInflation, ) = validatorRewardOffersManager.getTokenPoolSupplyData();
        assertEq(authorizedInflation, 5000);

        // receive inflation
        vm.warp(200); // block.timestamp = 200
        validatorRewardOffersManager.receiveInflation{value: 5000} ();
        assertEq(address(validatorRewardOffersManager).balance, 5000);
        vm.stopPrank();


        _mockGetCurrentEpochId(2);
        // trigger switchover, which will trigger inflation offers
        // interval start = 3*DAY - 2*DAY = DAY
        // interval end = max(200 + DAY, 3*DAY - DAY) = 2*DAY
        // totalRewardAmount = 5000 * DAY / (2*DAY - DAY) = 5000
        vm.prank(mockFlareSystemsManager);
        vm.expectEmit();
        emit InflationRewardsOffered(
            2 + 1,
            5000
        );
        validatorRewardOffersManager.triggerRewardEpochSwitchover(2, 3 * DAY, DAY);
        assertEq(address(validatorRewardOffersManager).balance, 0);
        assertEq(address(rewardManager).balance, 5000);
        (uint256 locked, uint256 authorized, uint256 claimed ) = validatorRewardOffersManager.getTokenPoolSupplyData();
        assertEq(locked, 0);
        assertEq(authorized, 5000);
        assertEq(claimed, 5000);

        // totalInflationReceivedWei == totalInflationRewardsOfferedWei -> amounts should be zero
        vm.prank(mockFlareSystemsManager);
        vm.expectEmit();
        emit InflationRewardsOffered(
            2 + 1,
            0 // amount
        );
        validatorRewardOffersManager.triggerRewardEpochSwitchover(2, 3 * DAY, DAY);
    }

    function testTriggerInflationOffers1() public {
        vm.startPrank(mockInflation);
        // set daily authorized inflation
        vm.warp(100); // block.timestamp = 100
        validatorRewardOffersManager.setDailyAuthorizedInflation(5000);
        ( , uint256 authorizedInflation, ) = validatorRewardOffersManager.getTokenPoolSupplyData();
        assertEq(authorizedInflation, 5000);

        // receive inflation
        vm.warp(DAY + DAY / 2); // block.timestamp = 200
        validatorRewardOffersManager.receiveInflation{value: 5000} ();
        assertEq(address(validatorRewardOffersManager).balance, 5000);
        vm.stopPrank();


        _mockGetCurrentEpochId(2);
        // trigger switchover, which will trigger inflation offers
        // interval start = 4*DAY - 2*DAY = 2*DAY
        // interval end = max(1.5*DAY + DAY, 4*DAY - DAY) = 3*DAY
        // totalRewardAmount = 1667 * DAY / DAY = 1667
        vm.prank(mockFlareSystemsManager);
        vm.expectEmit();
        emit InflationRewardsOffered(
            2 + 1,
            3333
        );
        validatorRewardOffersManager.triggerRewardEpochSwitchover(2, 3 * DAY, DAY);
        assertEq(address(validatorRewardOffersManager).balance, 5000 - 3333);
        assertEq(address(rewardManager).balance, 3333);
        (uint256 locked, uint256 authorized, uint256 claimed) = validatorRewardOffersManager.getTokenPoolSupplyData();
        assertEq(locked, 0);
        assertEq(authorized, 5000);
        assertEq(claimed, 3333);

        vm.warp(block.timestamp + DAY);
        _mockGetCurrentEpochId(3);
        vm.prank(mockFlareSystemsManager);
        vm.expectEmit();
        emit InflationRewardsOffered(
            4,
            1667
        );
        validatorRewardOffersManager.triggerRewardEpochSwitchover(3, 4 * DAY, DAY);
        (locked, authorized, claimed) = validatorRewardOffersManager.getTokenPoolSupplyData();
        assertEq(locked, 0);
        assertEq(authorized, 5000);
        assertEq(claimed, 5000);
    }

    function testGetInflationAddress() public {
        assertEq(validatorRewardOffersManager.getInflationAddress(), mockInflation);
    }

    function testReceiveInflationRevert() public {
        vm.expectRevert("inflation only");
        validatorRewardOffersManager.receiveInflation();
    }

    //// helper functions
    function _mockGetCurrentEpochId(uint256 _epochId) internal {
        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(IFlareSystemsManager.getCurrentRewardEpochId.selector),
            abi.encode(_epochId)
        );
    }

    function _mockCurrentRewardEpochExpectedEndTs(uint256 _endTs) internal {
        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(bytes4(keccak256("currentRewardEpochExpectedEndTs()"))),
            abi.encode(_endTs)
        );
    }

    function _mockNewSigningPolicyInitializationStartSeconds(uint256 _startSeconds) internal {
        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(bytes4(keccak256("newSigningPolicyInitializationStartSeconds()"))),
            abi.encode(_startSeconds)
        );
    }

    function _setTimes() internal {
        _mockGetCurrentEpochId(2);
        vm.warp(100); // block.timestamp = 100
        _mockCurrentRewardEpochExpectedEndTs(110);
        _mockNewSigningPolicyInitializationStartSeconds(5);
    }

}