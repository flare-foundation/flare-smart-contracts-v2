// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../../contracts/fdc/implementation/FdcHub.sol";
import "../../../../contracts/protocol/implementation/RewardManager.sol";

contract FdcHubTest is Test {
    FdcHub private fdcHub;

    address private governance;
    address private addressUpdater;
    address private mockRewardManager;
    address private mockFlareSystemsManager;
    address private mockInflation;
    RewardManager private rewardManager;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    bytes32 private type1;
    bytes32 private source1;
    uint256 private fee1;
    bytes32 private type2;
    bytes32 private source2;
    uint256 private fee2;

    uint64 internal constant DAY = 1 days;

    event AttestationRequest(uint32 indexed votingRoundId, bytes data, uint256 fee);
    event InflationRewardsOffered(uint24 indexed rewardEpochId, uint256 amount);

    function setUp() public {
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");
        mockRewardManager = makeAddr("rewardManager");
        mockFlareSystemsManager = makeAddr("flareSystemsManager");
        mockInflation = makeAddr("inflation");

        fdcHub = new FdcHub(
          IGovernanceSettings(makeAddr("governanceSettings")),
          governance,
          addressUpdater
        );

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
        // contractAddresses[1] = mockRewardManager;
        contractAddresses[1] = address(rewardManager);
        contractAddresses[2] = mockFlareSystemsManager;
        contractAddresses[3] = mockInflation;
        fdcHub.updateContractAddresses(contractNameHashes, contractAddresses);

        // set contracts on reward manager
        contractNameHashes = new bytes32[](7);
        contractAddresses = new address[](7);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("VoterRegistry"));
        contractNameHashes[2] = keccak256(abi.encode("ClaimSetupManager"));
        contractNameHashes[3] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[4] = keccak256(abi.encode("FlareSystemsCalculator"));
        contractNameHashes[5] = keccak256(abi.encode("PChainStakeMirror"));
        contractNameHashes[6] = keccak256(abi.encode("WNat"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = makeAddr("voterRegistry");
        contractAddresses[2] = makeAddr("claimSetupManager");
        contractAddresses[3] = mockFlareSystemsManager;
        contractAddresses[4] = makeAddr("flareSystemsCalculator");
        contractAddresses[5] = makeAddr("pChainStakeMirror");
        contractAddresses[6] = makeAddr("wNat");
        rewardManager.updateContractAddresses(contractNameHashes, contractAddresses);
        vm.stopPrank();

        // set reward offers manager list on reward manager
        address[] memory rewardOffersManagers = new address[](1);
        rewardOffersManagers[0] = address(fdcHub);
        vm.prank(governance);
        rewardManager.setRewardOffersManagerList(rewardOffersManagers);

        type1 = bytes32("type1");
        source1 = bytes32("source1");
        fee1 = 123;
        type2 = bytes32("type2");
        source2 = bytes32("source2");
        fee2 = 456;

        vm.deal(mockInflation, 1 ether);
    }

    // type and source fee
    function testSetTypeAndSourceFee() public {
        vm.prank(governance);
        fdcHub.setTypeAndSourceFee(type1, source1, fee1);

        assertEq(fdcHub.typeAndSourceFees(_joinTypeAndSource(type1, source1)), fee1);
    }

    function testSetTypeAndSourceFeeRevertFeeZero() public {
        vm.prank(governance);
        vm.expectRevert("Fee must be greater than 0");
        fdcHub.setTypeAndSourceFee(type1, source1, 0);
    }

    function testRemoveTypeAndSourceFee() public {
        testSetTypeAndSourceFee();

        vm.prank(governance);
        fdcHub.removeTypeAndSourceFee(type1, source1);

        assertEq(fdcHub.typeAndSourceFees(_joinTypeAndSource(type1, source1)), 0);
    }

    function testRemoveTypeAndSourceFeeRevertNotSet() public {
        vm.prank(governance);
        vm.expectRevert("Fee not set");
        fdcHub.removeTypeAndSourceFee(type1, source1);
    }

    function testSetTypeAndSourceFees() public {
        bytes32[] memory types = new bytes32[](2);
        types[0] = type1;
        types[1] = type2;
        bytes32[] memory sources = new bytes32[](2);
        sources[0] = source1;
        sources[1] = source2;
        uint256[] memory fees = new uint256[](2);
        fees[0] = fee1;
        fees[1] = fee2;
        vm.prank(governance);
        fdcHub.setTypeAndSourceFees(types, sources, fees);

        assertEq(fdcHub.typeAndSourceFees(_joinTypeAndSource(type1, source1)), fee1);
        assertEq(fdcHub.typeAndSourceFees(_joinTypeAndSource(type2, source2)), fee2);
    }

    function testSetTypeAndSourceFeeRevertMismatch() public {
        bytes32[] memory types = new bytes32[](2);
        types[0] = type1;
        types[1] = type2;
        bytes32[] memory sources = new bytes32[](2);
        sources[0] = source1;
        sources[1] = source2;
        uint256[] memory fees = new uint256[](1);
        fees[0] = fee1;
        vm.prank(governance);
        vm.expectRevert("length mismatch");
        fdcHub.setTypeAndSourceFees(types, sources, fees);
    }

    function testRemoveTypeAndSourceFees() public {
        testSetTypeAndSourceFees();

        bytes32[] memory types = new bytes32[](1);
        types[0] = type1;
        bytes32[] memory sources = new bytes32[](1);
        sources[0] = source1;
        vm.prank(governance);
        fdcHub.removeTypeAndSourceFees(types, sources);

        assertEq(fdcHub.typeAndSourceFees(_joinTypeAndSource(type1, source1)), 0);
        assertEq(fdcHub.typeAndSourceFees(_joinTypeAndSource(type2, source2)), 456);
    }

    function testRemoveTypeAndSourceFeesRevertMismatch() public {
        testSetTypeAndSourceFees();

        bytes32[] memory types = new bytes32[](1);
        types[0] = type1;
        bytes32[] memory sources = new bytes32[](0);
        vm.prank(governance);
        vm.expectRevert("length mismatch");
        fdcHub.removeTypeAndSourceFees(types, sources);
    }


    function testGetRequestFee() public {
        testSetTypeAndSourceFee();

        bytes memory data = abi.encodePacked(type1, source1);
        data = abi.encodePacked(data, bytes32("additional data"));
        assertEq(fdcHub.getRequestFee(data), fee1);
    }

    function testGetBaseFeeRevert() public {
        vm.expectRevert("Request data too short, should at least specify type and source");
        fdcHub.getRequestFee(abi.encodePacked(type1));
    }

    function testRequestAttestation() public {
        testSetTypeAndSourceFee();
        address user = makeAddr("user");
        vm.deal(user, 1000);

        _mockGetCurrentEpochId(5);

        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(IFlareSystemsManager.getCurrentVotingEpochId.selector),
            abi.encode(1550)
        );

        vm.prank(user);
        vm.expectEmit();
        emit AttestationRequest(1550, abi.encodePacked(type1, source1), 123);
        fdcHub.requestAttestation { value: 123 }(abi.encodePacked(type1, source1));
        vm.assertEq(address(rewardManager).balance, 123);
    }

    function testRequestAttestationRevertFeeTooLow() public {
        testSetTypeAndSourceFee();
        address user = makeAddr("user");
        vm.deal(user, 1000);

        vm.prank(user);
        vm.expectRevert("fee to low, call getRequestFee to get the required fee amount");
        fdcHub.requestAttestation { value: 122 }(abi.encodePacked(type1, source1));
    }

    function testRequestAttestationRevertNoFeeSpecified() public {
        vm.expectRevert("No fee specified for this type and source");
        fdcHub.requestAttestation(abi.encodePacked(type1, source1));
    }

    function testTriggerInflationOffers() public {
        vm.startPrank(mockInflation);
        // set daily authorized inflation
        vm.warp(100); // block.timestamp = 100
        fdcHub.setDailyAuthorizedInflation(5000);
        ( , uint256 authorizedInflation, ) = fdcHub.getTokenPoolSupplyData();
        assertEq(authorizedInflation, 5000);

        // receive inflation
        vm.warp(200); // block.timestamp = 200
        fdcHub.receiveInflation{value: 5000} ();
        assertEq(address(fdcHub).balance, 5000);
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
        fdcHub.triggerRewardEpochSwitchover(2, 3 * DAY, DAY);
        assertEq(address(fdcHub).balance, 0);
        assertEq(address(rewardManager).balance, 5000);
        (uint256 locked, uint256 authorized, uint256 claimed ) = fdcHub.getTokenPoolSupplyData();
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
        fdcHub.triggerRewardEpochSwitchover(2, 3 * DAY, DAY);
    }



    function testGetContractName() view public {
        assertEq(fdcHub.getContractName(), "FdcHub");
    }


    function _joinTypeAndSource(bytes32 _type, bytes32 _source) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_type, _source));
    }

    function _mockGetCurrentEpochId(uint256 _epochId) internal {
        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(IFlareSystemsManager.getCurrentRewardEpochId.selector),
            abi.encode(_epochId)
        );
    }
}
