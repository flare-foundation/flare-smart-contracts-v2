// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { Fdc2RewardOffersManager } from
    "../../../../contracts/fdc2/implementation/Fdc2RewardOffersManager.sol";
import { Fdc2RewardOffersManagerProxy } from
    "../../../../contracts/fdc2/proxy/Fdc2RewardOffersManagerProxy.sol";
import { RewardManager } from "../../../../contracts/protocol/implementation/RewardManager.sol";
import { IFdc2RewardOffersManager } from
    "../../../../contracts/userInterfaces/fdc2/IFdc2RewardOffersManager.sol";
import { IFdc2InflationConfigurations } from
    "../../../../contracts/userInterfaces/fdc2/IFdc2InflationConfigurations.sol";
import { ProtocolsV2Interface } from "../../../../contracts/userInterfaces/LTS/ProtocolsV2Interface.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

contract Fdc2RewardOffersManagerTest is Test {

    uint64 internal constant DAY = 1 days;

    Fdc2RewardOffersManager private fdc2RewardOffersManager;

    address private governance;
    address private addressUpdater;
    address private mockFlareSystemsManager;
    address private mockInflation;
    address private mockFdc2InflationConfigurations;
    RewardManager private rewardManager;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    function setUp() public {
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");

        Fdc2RewardOffersManager impl = new Fdc2RewardOffersManager();
        Fdc2RewardOffersManagerProxy proxy = new Fdc2RewardOffersManagerProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            address(impl)
        );
        fdc2RewardOffersManager = Fdc2RewardOffersManager(address(proxy));

        mockFlareSystemsManager = makeAddr("flareSystemsManager");
        mockInflation = makeAddr("inflation");
        mockFdc2InflationConfigurations = makeAddr("fdc2InflationConfigurations");

        rewardManager = new RewardManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            address(0),
            0
        );

        vm.startPrank(addressUpdater);
        contractNameHashes = new bytes32[](5);
        contractAddresses = new address[](5);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("RewardManager"));
        contractNameHashes[2] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[3] = keccak256(abi.encode("Inflation"));
        contractNameHashes[4] = keccak256(abi.encode("Fdc2InflationConfigurations"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = address(rewardManager);
        contractAddresses[2] = mockFlareSystemsManager;
        contractAddresses[3] = mockInflation;
        contractAddresses[4] = mockFdc2InflationConfigurations;
        fdc2RewardOffersManager.updateContractAddresses(contractNameHashes, contractAddresses);

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
        contractAddresses[7] = makeAddr("FtsoRewardManagerProxy");
        rewardManager.updateContractAddresses(contractNameHashes, contractAddresses);
        vm.stopPrank();

        address[] memory rewardOffersManagers = new address[](1);
        rewardOffersManagers[0] = address(fdc2RewardOffersManager);
        vm.prank(governance);
        rewardManager.setRewardOffersManagerList(rewardOffersManagers);

        vm.deal(mockInflation, 1 ether);
    }

    function testGetContractName() public {
        assertEq(fdc2RewardOffersManager.getContractName(), "Fdc2RewardOffersManager");
    }

    function testTriggerInflationOffers() public {
        vm.startPrank(mockInflation);
        vm.warp(100);
        fdc2RewardOffersManager.setDailyAuthorizedInflation(5000);
        ( , uint256 authorizedInflation, ) = fdc2RewardOffersManager.getTokenPoolSupplyData();
        assertEq(authorizedInflation, 5000);

        vm.warp(200);
        fdc2RewardOffersManager.receiveInflation{value: 5000} ();
        assertEq(address(fdc2RewardOffersManager).balance, 5000);
        vm.stopPrank();

        IFdc2InflationConfigurations.Fdc2Configuration[] memory configs =
            new IFdc2InflationConfigurations.Fdc2Configuration[](1);
        configs[0] = IFdc2InflationConfigurations.Fdc2Configuration(
            bytes32("TeeAvailabilityCheck"), bytes32("TEE"), 10000, 2, 0
        );
        _mockGetFdc2Configurations(configs);
        _mockGetCurrentEpochId(2);

        // interval start = 3*DAY - 2*DAY = DAY
        // interval end = max(200 + DAY, 3*DAY - DAY) = 2*DAY
        // totalRewardAmount = 5000 * DAY / (2*DAY - DAY) = 5000
        vm.prank(mockFlareSystemsManager);
        vm.expectEmit();
        emit IFdc2RewardOffersManager.InflationRewardsOffered(
            2 + 1,
            configs,
            5000
        );
        fdc2RewardOffersManager.triggerRewardEpochSwitchover(2, 3 * DAY, DAY);
        assertEq(address(fdc2RewardOffersManager).balance, 0);
        assertEq(address(rewardManager).balance, 5000);
        (uint256 locked, uint256 authorized, uint256 claimed) = fdc2RewardOffersManager.getTokenPoolSupplyData();
        assertEq(locked, 0);
        assertEq(authorized, 5000);
        assertEq(claimed, 5000);

        // totalInflationReceivedWei == totalInflationRewardsOfferedWei -> amounts should be zero
        vm.prank(mockFlareSystemsManager);
        vm.expectEmit();
        emit IFdc2RewardOffersManager.InflationRewardsOffered(
            2 + 1,
            configs,
            0
        );
        fdc2RewardOffersManager.triggerRewardEpochSwitchover(2, 3 * DAY, DAY);
    }

    function testTriggerInflationOffersPartial() public {
        vm.startPrank(mockInflation);
        vm.warp(100);
        fdc2RewardOffersManager.setDailyAuthorizedInflation(5000);

        vm.warp(DAY + DAY / 2);
        fdc2RewardOffersManager.receiveInflation{value: 5000} ();
        vm.stopPrank();

        IFdc2InflationConfigurations.Fdc2Configuration[] memory configs =
            new IFdc2InflationConfigurations.Fdc2Configuration[](0);
        _mockGetFdc2Configurations(configs);
        _mockGetCurrentEpochId(2);

        // intervalStart = 3*DAY - 2*DAY = DAY
        // intervalEnd   = max(1.5*DAY + DAY, 3*DAY - DAY) = 2.5*DAY
        // totalReward   = 5000 * DAY / (2.5*DAY - DAY) = 5000 / 1.5 = 3333
        vm.prank(mockFlareSystemsManager);
        vm.expectEmit();
        emit IFdc2RewardOffersManager.InflationRewardsOffered(
            2 + 1,
            configs,
            3333
        );
        fdc2RewardOffersManager.triggerRewardEpochSwitchover(2, 3 * DAY, DAY);
        assertEq(address(fdc2RewardOffersManager).balance, 5000 - 3333);
        assertEq(address(rewardManager).balance, 3333);
        (uint256 locked, uint256 authorized, uint256 claimed) = fdc2RewardOffersManager.getTokenPoolSupplyData();
        assertEq(locked, 0);
        assertEq(authorized, 5000);
        assertEq(claimed, 3333);
    }

    function testGetInflationAddress() public {
        assertEq(fdc2RewardOffersManager.getInflationAddress(), mockInflation);
    }

    function testReceiveInflationRevert() public {
        vm.expectRevert("inflation only");
        fdc2RewardOffersManager.receiveInflation();
    }

    function testTriggerRevertOnlyFlareSystemsManager() public {
        vm.expectRevert("only flare system manager");
        fdc2RewardOffersManager.triggerRewardEpochSwitchover(2, 3 * DAY, DAY);
    }

    function _mockGetCurrentEpochId(uint256 _epochId) internal {
        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(ProtocolsV2Interface.getCurrentRewardEpochId.selector),
            abi.encode(_epochId)
        );
    }

    function _mockGetFdc2Configurations(
        IFdc2InflationConfigurations.Fdc2Configuration[] memory _configs
    )
        internal
    {
        vm.mockCall(
            mockFdc2InflationConfigurations,
            abi.encodeWithSelector(IFdc2InflationConfigurations.getFdc2Configurations.selector),
            abi.encode(_configs)
        );
    }
}
