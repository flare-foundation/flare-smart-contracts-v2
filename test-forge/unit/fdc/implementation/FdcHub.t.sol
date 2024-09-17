// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../../contracts/fdc/implementation/FdcHub.sol";
import "../../../../contracts/fdc/implementation/FdcInflationConfigurations.sol";
import "../../../../contracts/fdc/implementation/FdcRequestFeeConfigurations.sol";
import "../../../../contracts/protocol/implementation/RewardManager.sol";

contract FdcHubTest is Test {
    FdcHub private fdcHub;
    FdcInflationConfigurations private fdcInflationConfigurations;
    FdcRequestFeeConfigurations private fdcRequestFeeConfigurations;

    IFdcInflationConfigurations.FdcConfiguration[] private fdcConfigurations;

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

    event AttestationRequest(bytes data, uint256 fee);
    event InflationRewardsOffered(
        // reward epoch id
        uint24 indexed rewardEpochId,
        // fdc configurations
        IFdcInflationConfigurations.FdcConfiguration[] fdcConfigurations,
        // amount (in wei) of reward in native coin
        uint256 amount
    );

    function setUp() public {
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");
        mockRewardManager = makeAddr("rewardManager");
        mockFlareSystemsManager = makeAddr("flareSystemsManager");
        mockInflation = makeAddr("inflation");

        fdcHub = new FdcHub(
          IGovernanceSettings(makeAddr("governanceSettings")),
          governance,
          addressUpdater,
          30
        );

        fdcInflationConfigurations = new FdcInflationConfigurations(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater
        );

        fdcRequestFeeConfigurations = new FdcRequestFeeConfigurations(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance
        );

        rewardManager = new RewardManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            address(0),
            0
        );

        vm.startPrank(addressUpdater);
        // set contracts on fdc hub
        contractNameHashes = new bytes32[](6);
        contractAddresses = new address[](6);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("RewardManager"));
        contractNameHashes[2] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[3] = keccak256(abi.encode("Inflation"));
        contractNameHashes[4] = keccak256(abi.encode("FdcInflationConfigurations"));
        contractNameHashes[5] = keccak256(abi.encode("FdcRequestFeeConfigurations"));
        contractAddresses[0] = addressUpdater;
        // contractAddresses[1] = mockRewardManager;
        contractAddresses[1] = address(rewardManager);
        contractAddresses[2] = mockFlareSystemsManager;
        contractAddresses[3] = mockInflation;
        contractAddresses[4] = address(fdcInflationConfigurations);
        contractAddresses[5] = address(fdcRequestFeeConfigurations);
        fdcHub.updateContractAddresses(contractNameHashes, contractAddresses);

        // set contracts on fdc inflation configurations
        contractNameHashes = new bytes32[](2);
        contractAddresses = new address[](2);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("FdcRequestFeeConfigurations"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = address(fdcRequestFeeConfigurations);
        fdcInflationConfigurations.updateContractAddresses(contractNameHashes, contractAddresses);

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
        contractNameHashes[7] = keccak256(abi.encode("FtsoRewardManager"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = makeAddr("voterRegistry");
        contractAddresses[2] = makeAddr("claimSetupManager");
        contractAddresses[3] = mockFlareSystemsManager;
        contractAddresses[4] = makeAddr("flareSystemsCalculator");
        contractAddresses[5] = makeAddr("pChainStakeMirror");
        contractAddresses[6] = makeAddr("wNat");
        contractAddresses[7] = makeAddr("ftsoRewardManager");
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

        fdcConfigurations.push(IFdcInflationConfigurations.FdcConfiguration({
            attestationType: type1,
            source: source1,
            inflationShare: 10000,
            minRequestsThreshold: 2,
            mode: 0
        }));

        vm.prank(governance);
        fdcRequestFeeConfigurations.setTypeAndSourceFee(type1, source1, fee1);
    }

    function testRequestAttestation() public {
        address user = makeAddr("user");
        vm.deal(user, 1000);

        _mockGetCurrentEpochId(5);

        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(IIFlareSystemsManager.currentRewardEpochExpectedEndTs.selector),
            abi.encode(1550)
        );

        vm.prank(user);
        vm.expectEmit();
        emit AttestationRequest(abi.encodePacked(type1, source1), 123);
        fdcHub.requestAttestation { value: 123 }(abi.encodePacked(type1, source1));
        vm.assertEq(address(rewardManager).balance, 123);

        (uint256 totalRewardsWei,,,,) = rewardManager.getRewardEpochTotals(5);
        vm.assertEq(totalRewardsWei, 123);
    }

    function testRequestAttestation2() public {
        address user = makeAddr("user");
        vm.deal(user, 1000);

        vm.warp(50);

        _mockGetCurrentEpochId(5);

        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(IIFlareSystemsManager.currentRewardEpochExpectedEndTs.selector),
            abi.encode(60)
        );
        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(ProtocolsV2Interface.getStartVotingRoundId.selector, 6),
            abi.encode(16)
        );
        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(ProtocolsV2Interface.getCurrentVotingEpochId.selector),
            abi.encode(14)
        );

        vm.prank(user);
        vm.expectEmit();
        bytes32 typeAndSource = _joinTypeAndSource(type1, source1);
        emit AttestationRequest(abi.encodePacked(type1, source1, typeAndSource, typeAndSource,
            typeAndSource, typeAndSource, typeAndSource, typeAndSource, typeAndSource, typeAndSource), 123);
        fdcHub.requestAttestation { value: 123 }(abi.encodePacked(type1, source1, typeAndSource, typeAndSource,
            typeAndSource, typeAndSource, typeAndSource, typeAndSource, typeAndSource, typeAndSource));
        vm.assertEq(address(rewardManager).balance, 123);

        (uint256 totalRewardsWei,,,,) = rewardManager.getRewardEpochTotals(5);
        vm.assertEq(totalRewardsWei, 123);
    }

    function testRequestAttestation3() public {
        address user = makeAddr("user");
        vm.deal(user, 1000);

        vm.warp(50);

        _mockGetCurrentEpochId(5);

        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(IIFlareSystemsManager.currentRewardEpochExpectedEndTs.selector),
            abi.encode(60)
        );
        vm.mockCallRevert(
            mockFlareSystemsManager,
            abi.encodeWithSelector(ProtocolsV2Interface.getStartVotingRoundId.selector, 6),
            abi.encode()
        );

        vm.prank(user);
        vm.expectEmit();
        emit AttestationRequest(abi.encodePacked(type1, source1), 123);
        fdcHub.requestAttestation { value: 123 }(abi.encodePacked(type1, source1));
        vm.assertEq(address(rewardManager).balance, 123);

        (uint256 totalRewardsWei,,,,) = rewardManager.getRewardEpochTotals(5);
        vm.assertEq(totalRewardsWei, 123);
    }

    function testRequestAttestation4() public {
        address user = makeAddr("user");
        vm.deal(user, 1000);

        vm.warp(50);

        _mockGetCurrentEpochId(5);

        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(IIFlareSystemsManager.currentRewardEpochExpectedEndTs.selector),
            abi.encode(60)
        );
        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(ProtocolsV2Interface.getStartVotingRoundId.selector, 6),
            abi.encode(15)
        );
        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(ProtocolsV2Interface.getCurrentVotingEpochId.selector),
            abi.encode(14)
        );

        vm.prank(user);
        vm.expectEmit();
        emit AttestationRequest(abi.encodePacked(type1, source1), 123);
        fdcHub.requestAttestation { value: 123 }(abi.encodePacked(type1, source1));
        vm.assertEq(address(rewardManager).balance, 123);

        (uint256 totalRewardsWei,,,,) = rewardManager.getRewardEpochTotals(6);
        vm.assertEq(totalRewardsWei, 123);
    }

    function testRequestAttestationRevertFeeTooLow() public {
        address user = makeAddr("user");
        vm.deal(user, 1000);

        vm.prank(user);
        vm.expectRevert("fee to low, call getRequestFee to get the required fee amount");
        fdcHub.requestAttestation { value: 122 }(abi.encodePacked(type1, source1));
    }

    function testRequestAttestationRevertTypeAndSourceCombinationNotSupported() public {
        vm.expectRevert("Type and source combination not supported");
        fdcHub.requestAttestation(abi.encodePacked(type1, source2));
    }

    function testTriggerInflationOffers() public {
        vm.prank(governance);
        fdcInflationConfigurations.addFdcConfigurations(fdcConfigurations);

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
            fdcConfigurations,
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
            fdcConfigurations,
            0 // amount
        );
        fdcHub.triggerRewardEpochSwitchover(2, 3 * DAY, DAY);
    }

    function testGetContractName() public view {
        assertEq(fdcHub.getContractName(), "FdcHub");
    }


    function _mockGetCurrentEpochId(uint256 _epochId) internal {
        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(ProtocolsV2Interface.getCurrentRewardEpochId.selector),
            abi.encode(_epochId)
        );
    }

    function _joinTypeAndSource(bytes32 _type, bytes32 _source) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_type, _source));
    }
}
