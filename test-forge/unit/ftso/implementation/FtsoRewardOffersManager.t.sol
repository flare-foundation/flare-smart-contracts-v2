// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../../contracts/ftso/implementation/FtsoRewardOffersManager.sol";
import "../../../../contracts/protocol/implementation/RewardManager.sol";

contract FtsoRewardOffersManagerTest is Test {

    FtsoRewardOffersManager private ftsoRewardOffersManager;

    address private governance;
    address private addressUpdater;
    address private mockFtsoInflationConfigurations;
    address private mockFtsoFeedDecimals;
    address private mockRewardManager;
    address private mockFlareSystemsManager;
    address private mockInflation;
    RewardManager private rewardManager;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    bytes21 private feedId1;
    bytes21 private feedId2;
    uint16 internal constant MAX_BIPS = 1e4;
    uint24 internal constant PPM_MAX = 1e6;
    address private claimBackAddr;
    address private sender;
    bytes private feeds1;
    bytes private feeds2;

    uint64 internal constant DAY = 1 days;

    event RewardsOffered(
        // reward epoch id
        uint24 indexed rewardEpochId,
        // feed id - i.e. type + base/quote symbol
        bytes21 feedId,
        // number of decimals (negative exponent)
        int8 decimals,
        // amount (in wei) of reward in native coin
        uint256 amount,
        // minimal reward eligibility turnout threshold in BIPS (basis points)
        uint16 minRewardedTurnoutBIPS,
        // primary band reward share in PPM (parts per million)
        uint24 primaryBandRewardSharePPM,
        // secondary band width in PPM (parts per million) in relation to the median
        uint24 secondaryBandWidthPPM,
        // address that can claim undistributed part of the reward (or burn address)
        address claimBackAddress
    );

    event InflationRewardsOffered(
        // reward epoch id
        uint24 indexed rewardEpochId,
        // feed ids - i.e. type + base/quote symbols - multiple of 21 (one feedId is bytes21)
        bytes feedIds,
        // decimals encoded to - multiple of 1 (int8)
        bytes decimals,
        // amount (in wei) of reward in native coin
        uint256 amount,
        // minimal reward eligibility turnout threshold in BIPS (basis points)
        uint16 minRewardedTurnoutBIPS,
        // primary band reward share in PPM (parts per million)
        uint24 primaryBandRewardSharePPM,
        // secondary band width in PPM (parts per million) in relation to the median - multiple of 3 (uint24)
        bytes secondaryBandWidthPPMs,
        // rewards split mode (0 means equally, 1 means random,...)
        uint16 mode
    );

    function setUp() public {
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");

        ftsoRewardOffersManager = new FtsoRewardOffersManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            100
        );

        mockRewardManager = makeAddr("rewardManager");
        mockFtsoInflationConfigurations = makeAddr("ftsoInflationConfigurations");
        mockFtsoFeedDecimals = makeAddr("ftsoFeedDecimals");
        mockFlareSystemsManager = makeAddr("flareSystemsManager");
        mockInflation = makeAddr("inflation");

        rewardManager = new RewardManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            address(0)
        );

        vm.startPrank(addressUpdater);
        contractNameHashes = new bytes32[](6);
        contractAddresses = new address[](6);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("RewardManager"));
        contractNameHashes[2] = keccak256(abi.encode("FtsoInflationConfigurations"));
        contractNameHashes[3] = keccak256(abi.encode("FtsoFeedDecimals"));
        contractNameHashes[4] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[5] = keccak256(abi.encode("Inflation"));
        contractAddresses[0] = addressUpdater;
        // contractAddresses[1] = mockRewardManager;
        contractAddresses[1] = address(rewardManager);
        contractAddresses[2] = mockFtsoInflationConfigurations;
        contractAddresses[3] = mockFtsoFeedDecimals;
        contractAddresses[4] = mockFlareSystemsManager;
        contractAddresses[5] = mockInflation;
        ftsoRewardOffersManager.updateContractAddresses(contractNameHashes, contractAddresses);

        // set contract on reward manager
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

        feedId1 = bytes21("feed1");
        feedId2 = bytes21("feed2");
        claimBackAddr = makeAddr("claimBackAddr");
        sender = makeAddr("sender");

        // fund sender of offers
        vm.deal(sender, 1 ether);

        // set reward offers manager list on reward manager
        address[] memory rewardOffersManagers = new address[](1);
        rewardOffersManagers[0] = address(ftsoRewardOffersManager);
        vm.prank(governance);
        rewardManager.setRewardOffersManagerList(rewardOffersManagers);
    }

    function testGetContractName() public {
        assertEq(ftsoRewardOffersManager.getContractName(), "FtsoRewardOffersManager");
    }

    // offerRewards tests
    function testOfferRewardsRevertNotNextEpoch() public {
        _mockGetCurrentEpochId(1);
        IFtsoRewardOffersManager.Offer[] memory offers;
        offers = new IFtsoRewardOffersManager.Offer[](0);

        vm.expectRevert("not next reward epoch id");
        ftsoRewardOffersManager.offerRewards(4, offers);
    }

    function testOfferRewardsRevertTooLate() public {
        _mockGetCurrentEpochId(2);
        vm.warp(100); // block.timestamp = 100
        _mockCurrentRewardEpochExpectedEndTs(110);
        _mockNewSigningPolicyInitializationStartSeconds(20);
        IFtsoRewardOffersManager.Offer[] memory offers;
        offers = new IFtsoRewardOffersManager.Offer[](0);

        vm.expectRevert("too late for next reward epoch");
        ftsoRewardOffersManager.offerRewards(2 + 1, offers);
    }

    function testOfferRewardsRevertInvalidThresholdValue() public {
        _setTimes();
        IFtsoRewardOffersManager.Offer[] memory offers;
        offers = new IFtsoRewardOffersManager.Offer[](1);
        offers[0] = IFtsoRewardOffersManager.Offer(
            uint120(1000),
            feedId1,
            MAX_BIPS + 1,
            10000,
            20000,
            claimBackAddr
        );
        vm.expectRevert("invalid minRewardedTurnoutBIPS value");
        ftsoRewardOffersManager.offerRewards(2 + 1, offers);
    }

    function testOfferRewardsRevertInvalidPrimaryBand() public {
        _setTimes();
        IFtsoRewardOffersManager.Offer[] memory offers;
        offers = new IFtsoRewardOffersManager.Offer[](1);
        offers[0] = IFtsoRewardOffersManager.Offer(
            uint120(1000),
            feedId1,
            5000,
            PPM_MAX + 1,
            20000,
            claimBackAddr
        );
        vm.expectRevert("invalid primaryBandRewardSharePPM value");
        ftsoRewardOffersManager.offerRewards(2 + 1, offers);
    }

    function testOfferRewardsRevertInvalidSecondaryBand() public {
        _setTimes();
        IFtsoRewardOffersManager.Offer[] memory offers;
        offers = new IFtsoRewardOffersManager.Offer[](1);
        offers[0] = IFtsoRewardOffersManager.Offer(
            uint120(1000),
            feedId1,
            5000,
            10000,
            PPM_MAX + 1,
            claimBackAddr
        );
        vm.expectRevert("invalid secondaryBandWidthPPM value");
        ftsoRewardOffersManager.offerRewards(2 + 1, offers);
    }

    function testOfferRewardsRevertOfferTooSmall() public {
        _setTimes();
        IFtsoRewardOffersManager.Offer[] memory offers;
        offers = new IFtsoRewardOffersManager.Offer[](1);
        offers[0] = IFtsoRewardOffersManager.Offer(
            uint120(90),
            feedId1,
            5000,
            10000,
            20000,
            claimBackAddr
        );
        vm.expectRevert("rewards offer value too small");
        ftsoRewardOffersManager.offerRewards(2 + 1, offers);
    }

    function testOfferRewards() public {
        _setTimes();
        IFtsoRewardOffersManager.Offer[] memory offers;
        offers = new IFtsoRewardOffersManager.Offer[](2);
        offers[0] = IFtsoRewardOffersManager.Offer(
            uint120(1000),
            feedId1,
            5000,
            10000,
            20000,
            claimBackAddr
        );
        offers[1] = IFtsoRewardOffersManager.Offer(
            uint120(2000),
            feedId2,
            6000,
            40000,
            50000,
            address(0)
        );

        _mockGetDecimals(feedId1, 4);
        _mockGetDecimals(feedId2, -5);

        vm.expectEmit();
        emit RewardsOffered(
            2 + 1,
            offers[0].feedId,
            int8(4),
            offers[0].amount,
            offers[0].minRewardedTurnoutBIPS,
            offers[0].primaryBandRewardSharePPM,
            offers[0].secondaryBandWidthPPM,
            claimBackAddr
        );
        vm.expectEmit();
        emit RewardsOffered(
            2 + 1,
            offers[1].feedId,
            int8(-5),
            offers[1].amount,
            offers[1].minRewardedTurnoutBIPS,
            offers[1].primaryBandRewardSharePPM,
            offers[1].secondaryBandWidthPPM,
            sender
        );

        vm.startPrank(sender);
        // send wrong value
        vm.expectRevert("amount offered is not the same as value sent");
        ftsoRewardOffersManager.offerRewards{value: 3001} (2 + 1, offers);

        // _mockReceiveRewards(3000);
        assertEq(address(rewardManager).balance, 0);
        ftsoRewardOffersManager.offerRewards{value: 3000} (2 + 1, offers);
        assertEq(address(rewardManager).balance, 3000);
        vm.stopPrank();
    }

    function testSetMinimalRewardsOfferValue() public {
        assertEq(ftsoRewardOffersManager.minimalRewardsOfferValueWei(), 100);
        vm.prank(governance);
        ftsoRewardOffersManager.setMinimalRewardsOfferValue(1000);
        assertEq(ftsoRewardOffersManager.minimalRewardsOfferValueWei(), 1000);
    }

    //// trigger inflation offers
    function testTriggerInflationOffers() public {
        // fund inflation contract
        vm.deal(mockInflation, 1 ether);

        vm.startPrank(mockInflation);
        // add daily authorized inflation on reward manager contract
        vm.warp(100); // block.timestamp = 100
        ftsoRewardOffersManager.setDailyAuthorizedInflation(5000);
        ( , uint256 authorizedInflation, ) = ftsoRewardOffersManager.getTokenPoolSupplyData();
        assertEq(authorizedInflation, 5000);

        // receive inflation
        vm.warp(200); // block.timestamp = 200
        ftsoRewardOffersManager.receiveInflation{value: 5000} ();
        assertEq(address(ftsoRewardOffersManager).balance, 5000);
        vm.stopPrank();

        // set inflation configurations
        IFtsoInflationConfigurations.FtsoConfiguration[] memory ftsoConfigs =
            new IFtsoInflationConfigurations.FtsoConfiguration[](2);
        feeds1 = bytes.concat(bytes21("feed1"), bytes21("feed2"));
        bytes memory secondaryBands = bytes.concat(bytes3(uint24(10000)), bytes3(uint24(20000)));
        ftsoConfigs[0] = IFtsoInflationConfigurations.FtsoConfiguration(
            feeds1,
            60,
            5000,
            30000,
            secondaryBands,
            0
        );
        bytes memory decimals1 = bytes.concat(bytes1(uint8(4)), bytes1(uint8(int8(-5))));
        _mockGetDecimalsBulk(feeds1, decimals1);

        feeds2 = bytes.concat(bytes21("feed3"), bytes21("feed4"));
        ftsoConfigs[1] = IFtsoInflationConfigurations.FtsoConfiguration(
            feeds2,
            40,
            6000,
            40000,
            secondaryBands,
            0
        );
        // bytes memory decimals2 = bytes.concat(bytes1(uint8(6)), bytes1(uint8(int8(-7))));
        // _mockGetDecimalsBulk(feeds2, decimals2);
        _mockGetFtsoConfigurations(ftsoConfigs);
        _mockGetCurrentEpochId(2);
        // trigger switchover, which will trigger inflation offers
        // interval start = 3*DAY - 2*DAY = DAY
        // interval end = max(200 + DAY, 3*DAY - DAY) = 2*DAY
        // totalRewardAmount = 5000 * DAY / (2*DAY - DAY) = 5000
        vm.prank(mockFlareSystemsManager);
        vm.expectEmit();
        emit InflationRewardsOffered(
            2 + 1,
            feeds1,
            decimals1,
            5000 * 60 / 100,
            ftsoConfigs[0].minRewardedTurnoutBIPS,
            ftsoConfigs[0].primaryBandRewardSharePPM,
            ftsoConfigs[0].secondaryBandWidthPPMs,
            ftsoConfigs[0].mode
        );
        vm.expectEmit();
        emit InflationRewardsOffered(
            2 + 1,
            feeds2,
            decimals1,
            5000 * 40 / 100,
            ftsoConfigs[1].minRewardedTurnoutBIPS,
            ftsoConfigs[1].primaryBandRewardSharePPM,
            ftsoConfigs[1].secondaryBandWidthPPMs,
            ftsoConfigs[1].mode
        );
        ftsoRewardOffersManager.triggerRewardEpochSwitchover(2, 3 * DAY, DAY);
        (uint256 locked, uint256 authorized, uint256 claimed ) = ftsoRewardOffersManager.getTokenPoolSupplyData();
        assertEq(locked, 0);
        assertEq(authorized, 5000);
        assertEq(claimed, 5000 * 60 / 100 + 5000 * 40 / 100);

        // totalInflationReceivedWei == totalInflationRewardsOfferedWei -> amounts should be zero
        vm.prank(mockFlareSystemsManager);
        vm.expectEmit();
        emit InflationRewardsOffered(
            2 + 1,
            feeds1,
            decimals1,
            0, // amount
            ftsoConfigs[0].minRewardedTurnoutBIPS,
            ftsoConfigs[0].primaryBandRewardSharePPM,
            ftsoConfigs[0].secondaryBandWidthPPMs,
            ftsoConfigs[0].mode
        );
        vm.expectEmit();
        emit InflationRewardsOffered(
            2 + 1,
            feeds2,
            decimals1,
            0, // amount
            ftsoConfigs[1].minRewardedTurnoutBIPS,
            ftsoConfigs[1].primaryBandRewardSharePPM,
            ftsoConfigs[1].secondaryBandWidthPPMs,
            ftsoConfigs[1].mode
        );
        ftsoRewardOffersManager.triggerRewardEpochSwitchover(2, 3 * DAY, DAY);
    }

    // one ftso group has 0 share
    function testTriggerInflationOffersShareZero() public {
        // fund inflation contract
        vm.deal(mockInflation, 1 ether);

        vm.startPrank(mockInflation);
        // add daily authorized inflation on reward manager contract
        vm.warp(100); // block.timestamp = 100
        ftsoRewardOffersManager.setDailyAuthorizedInflation(5000);
        ( , uint256 authorizedInflation, ) = ftsoRewardOffersManager.getTokenPoolSupplyData();
        assertEq(authorizedInflation, 5000);

        // receive inflation
        vm.warp(200); // block.timestamp = 200
        ftsoRewardOffersManager.receiveInflation{value: 5000} ();
        assertEq(address(ftsoRewardOffersManager).balance, 5000);
        vm.stopPrank();

        // set inflation configurations
        IFtsoInflationConfigurations.FtsoConfiguration[] memory ftsoConfigs =
            new IFtsoInflationConfigurations.FtsoConfiguration[](2);
        feeds1 = bytes.concat(bytes21("feed1"), bytes21("feed2"));
        bytes memory secondaryBands = bytes.concat(bytes3(uint24(10000)), bytes3(uint24(20000)));
        ftsoConfigs[0] = IFtsoInflationConfigurations.FtsoConfiguration(
            feeds1,
            60,
            3000,
            30000,
            secondaryBands,
            0
        );
        bytes memory decimals1 = bytes.concat(bytes1(uint8(4)), bytes1(uint8(int8(-5))));
        _mockGetDecimalsBulk(feeds1, decimals1);

        feeds2 = bytes.concat(bytes21("feed3"), bytes21("feed4"));
        ftsoConfigs[1] = IFtsoInflationConfigurations.FtsoConfiguration(
            feeds2,
            0, // zero share
            4000,
            40000,
            secondaryBands,
            0
        );
        _mockGetFtsoConfigurations(ftsoConfigs);
        _mockGetCurrentEpochId(2);
        vm.expectEmit();
        emit InflationRewardsOffered(
            2 + 1,
            feeds1,
            decimals1,
            5000,
            ftsoConfigs[0].minRewardedTurnoutBIPS,
            ftsoConfigs[0].primaryBandRewardSharePPM,
            ftsoConfigs[0].secondaryBandWidthPPMs,
            ftsoConfigs[0].mode
        );
        vm.expectEmit();
        emit InflationRewardsOffered(
            2 + 1,
            feeds2,
            decimals1,
            5000 * 0 / 100,
            ftsoConfigs[1].minRewardedTurnoutBIPS,
            ftsoConfigs[1].primaryBandRewardSharePPM,
            ftsoConfigs[1].secondaryBandWidthPPMs,
            ftsoConfigs[1].mode
        );
        assertEq(ftsoRewardOffersManager.getExpectedBalance(), 5000);
        vm.prank(mockFlareSystemsManager);
        ftsoRewardOffersManager.triggerRewardEpochSwitchover(2, 3 * DAY, DAY);
        assertEq(ftsoRewardOffersManager.getExpectedBalance(), 0);
    }

    // length of feeds is 0
    function testTriggerInflationOffersZeroFeeds() public {
        // fund inflation contract
        vm.deal(mockInflation, 1 ether);

        vm.startPrank(mockInflation);
        // add daily authorized inflation on reward manager contract
        vm.warp(100); // block.timestamp = 100
        ftsoRewardOffersManager.setDailyAuthorizedInflation(5000);
        ( , uint256 authorizedInflation, ) = ftsoRewardOffersManager.getTokenPoolSupplyData();
        assertEq(authorizedInflation, 5000);

        // receive inflation
        vm.warp(200); // block.timestamp = 200
        ftsoRewardOffersManager.receiveInflation{value: 5000} ();
        assertEq(address(ftsoRewardOffersManager).balance, 5000);
        vm.stopPrank();

        // set inflation configurations
        IFtsoInflationConfigurations.FtsoConfiguration[] memory ftsoConfigs =
            new IFtsoInflationConfigurations.FtsoConfiguration[](0);
        _mockGetFtsoConfigurations(ftsoConfigs);
        _mockGetCurrentEpochId(2);

        vm.recordLogs();
        vm.prank(mockFlareSystemsManager);
        ftsoRewardOffersManager.triggerRewardEpochSwitchover(2, 3 * DAY, DAY);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        // there were no logs emitted -> no offers were made
        assertEq(entries.length, 0);
    }

    function testGetInflationAddress() public {
        assertEq(ftsoRewardOffersManager.getInflationAddress(), mockInflation);
    }

    function testReceiveInflationRevert() public {
        vm.expectRevert("inflation only");
        ftsoRewardOffersManager.receiveInflation();
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

    function _mockGetDecimals(bytes21 _feedId, int8 _decimals) internal {
        vm.mockCall(
            mockFtsoFeedDecimals,
            abi.encodeWithSelector(IFtsoFeedDecimals.getDecimals.selector, _feedId),
            abi.encode(_decimals)
        );
    }

    //solhint-disable-next-line no-unused-vars
    function _mockGetDecimalsBulk(bytes memory _feedIds, bytes memory _decimals) internal {
        vm.mockCall(
            mockFtsoFeedDecimals,
            // TODO: why it does not work if mocking with parameter (_feedIds)
            abi.encodeWithSelector(IFtsoFeedDecimals.getDecimalsBulk.selector),
            abi.encode(_decimals)
        );
    }

    function _mockReceiveRewards(uint256 _amount) internal {
        vm.mockCall(
            mockRewardManager,
            _amount,
            abi.encodeWithSelector(RewardManager.receiveRewards.selector, 3, true),
            abi.encode()
        );
    }

    function _setTimes() internal {
        _mockGetCurrentEpochId(2);
        vm.warp(100); // block.timestamp = 100
        _mockCurrentRewardEpochExpectedEndTs(110);
        _mockNewSigningPolicyInitializationStartSeconds(5);
    }

    function _mockGetFtsoConfigurations(
        IFtsoInflationConfigurations.FtsoConfiguration[] memory _ftsoConfigs
    )
        internal
    {
        vm.mockCall(
            mockFtsoInflationConfigurations,
            abi.encodeWithSelector(IFtsoInflationConfigurations.getFtsoConfigurations.selector),
            abi.encode(_ftsoConfigs)
        );
    }

}