// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../contracts/ftso/implementation/FtsoRewardOffersManager.sol";

contract FtsoRewardOffersManagerTest is Test {

    FtsoRewardOffersManager private ftsoRewardOffersManager;

    address private governance;
    address private addressUpdater;
    address private mockFtsoInflationConfigurations;
    address private mockFtsoFeedDecimals;
    address private mockRewardManager;
    address private mockFlareSystemManager;
    address private mockInflation;
    FlareSystemManager private flareSystemManager;
    RewardManager private rewardManager;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    bytes8 private feedName1;
    bytes8 private feedName2;
    uint24 internal constant PPM_MAX = 1e6;
    address[] private leadProviders;
    address private claimBackAddr;
    address private sender;

    event RewardsOffered(
        // reward epoch id
        uint24 rewardEpochId,
        // feed name - i.e. base/quote symbol
        bytes8 feedName,
        // number of decimals (negative exponent)
        int8 decimals,
        // amount (in wei) of reward in native coin
        uint256 amount,
        // primary band reward share in PPM (parts per million)
        uint24 primaryBandRewardSharePPM,
        // secondary band width in PPM (parts per million) in relation to the median
        uint24 secondaryBandWidthPPM,
        // reward eligibility in PPM (parts per million) in relation to the median of the lead providers
        uint24 rewardEligibilityPPM,
        // list of lead providers
        address[] leadProviders,
        // address that can claim undistributed part of the reward (or burn address)
        address claimBackAddress
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
        mockFlareSystemManager = makeAddr("flareSystemManager");
        mockInflation = makeAddr("inflation");

        rewardManager = new RewardManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater
        );

        vm.startPrank(addressUpdater);
        contractNameHashes = new bytes32[](6);
        contractAddresses = new address[](6);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("RewardManager"));
        contractNameHashes[2] = keccak256(abi.encode("FtsoInflationConfigurations"));
        contractNameHashes[3] = keccak256(abi.encode("FtsoFeedDecimals"));
        contractNameHashes[4] = keccak256(abi.encode("FlareSystemManager"));
        contractNameHashes[5] = keccak256(abi.encode("Inflation"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = mockRewardManager;
        // contractAddresses[1] = address(rewardManager);
        contractAddresses[2] = mockFtsoInflationConfigurations;
        contractAddresses[3] = mockFtsoFeedDecimals;
        contractAddresses[4] = mockFlareSystemManager;
        contractAddresses[5] = mockInflation;
        ftsoRewardOffersManager.updateContractAddresses(contractNameHashes, contractAddresses);
        vm.stopPrank();

        feedName1 = bytes8("feed1");
        feedName2 = bytes8("feed2");
        leadProviders = new address[](2);
        leadProviders[0] = makeAddr("leadProvider1");
        leadProviders[1] = makeAddr("leadProvider2");
        claimBackAddr = makeAddr("claimBackAddr");
        sender = makeAddr("sender");

        // fund sender of offers
        vm.deal(sender, 1 ether);
    }

    function testGetContractName() public {
        assertEq(ftsoRewardOffersManager.getContractName(), "FtsoRewardOffersManager");
    }

    // offerRewards tests
    function testOfferRewardsRevertNotNextEpoch() public {
        _mockGetCurrentEpochId(1);
        FtsoRewardOffersManager.Offer[] memory offers;
        offers = new FtsoRewardOffersManager.Offer[](0);

        vm.expectRevert("not next reward epoch id");
        ftsoRewardOffersManager.offerRewards(4, offers);
    }

    function testOfferRewardsRevertTooLate() public {
        _mockGetCurrentEpochId(2);
        vm.warp(100); // block.timestamp = 100
        _mockCurrentRewardEpochExpectedEndTs(110);
        _mockNewSigningPolicyInitializationStartSeconds(20);
        FtsoRewardOffersManager.Offer[] memory offers;
        offers = new FtsoRewardOffersManager.Offer[](0);

        vm.expectRevert("too late for next reward epoch");
        ftsoRewardOffersManager.offerRewards(2 + 1, offers);
    }

    function testOfferRewardsRevertInvalidPrimaryBand() public {
        _setTimes();
        FtsoRewardOffersManager.Offer[] memory offers;
        offers = new FtsoRewardOffersManager.Offer[](1);
        offers[0] = FtsoRewardOffersManager.Offer(
            uint120(1000),
            feedName1,
            PPM_MAX + 1,
            20000,
            3000,
            leadProviders,
            claimBackAddr
        );
        vm.expectRevert("invalid primaryBandRewardSharePPM value");
        ftsoRewardOffersManager.offerRewards(2 + 1, offers);
    }

    function testOfferRewardsRevertInvalidSecondaryBand() public {
        _setTimes();
        FtsoRewardOffersManager.Offer[] memory offers;
        offers = new FtsoRewardOffersManager.Offer[](1);
        offers[0] = FtsoRewardOffersManager.Offer(
            uint120(1000),
            feedName1,
            10000,
            PPM_MAX + 1,
            3000,
            leadProviders,
            claimBackAddr
        );
        vm.expectRevert("invalid secondaryBandWidthPPM value");
        ftsoRewardOffersManager.offerRewards(2 + 1, offers);
    }

    function testOfferRewardsRevertInvalidRewardEligibilityValue() public {
        _setTimes();
        FtsoRewardOffersManager.Offer[] memory offers;
        offers = new FtsoRewardOffersManager.Offer[](1);
        offers[0] = FtsoRewardOffersManager.Offer(
            uint120(1000),
            feedName1,
            10000,
            20000,
            PPM_MAX + 1,
            leadProviders,
            claimBackAddr
        );
        vm.expectRevert("invalid rewardEligibilityPPM value");
        ftsoRewardOffersManager.offerRewards(2 + 1, offers);
    }

    function testOfferRewardsRevertOfferTooSmall() public {
        _setTimes();
        FtsoRewardOffersManager.Offer[] memory offers;
        offers = new FtsoRewardOffersManager.Offer[](1);
        offers[0] = FtsoRewardOffersManager.Offer(
            uint120(90),
            feedName1,
            10000,
            20000,
            30000,
            leadProviders,
            claimBackAddr
        );
        vm.expectRevert("rewards offer value too small");
        ftsoRewardOffersManager.offerRewards(2 + 1, offers);
    }

    function testX() public {
        console2.log("addr", address(ftsoRewardOffersManager));
        _setTimes();
        FtsoRewardOffersManager.Offer[] memory offers;
        offers = new FtsoRewardOffersManager.Offer[](2);
        offers[0] = FtsoRewardOffersManager.Offer(
            uint120(1000),
            feedName1,
            10000,
            20000,
            30000,
            leadProviders,
            claimBackAddr
        );
        offers[1] = FtsoRewardOffersManager.Offer(
            uint120(2000),
            feedName2,
            40000,
            50000,
            60000,
            leadProviders,
            address(0)
        );

        _mockGetDecimals(feedName1, 4);
        _mockGetDecimals(feedName2, -5);

        vm.expectEmit();
        emit RewardsOffered(
            2 + 1,
            offers[0].feedName,
            int8(4),
            offers[0].amount,
            offers[0].primaryBandRewardSharePPM,
            offers[0].secondaryBandWidthPPM,
            offers[0].rewardEligibilityPPM,
            leadProviders,
            claimBackAddr
        );
        vm.expectEmit();
        emit RewardsOffered(
            2 + 1,
            offers[1].feedName,
            int8(-5),
            offers[1].amount,
            offers[1].primaryBandRewardSharePPM,
            offers[1].secondaryBandWidthPPM,
            offers[1].rewardEligibilityPPM,
            leadProviders,
            sender
        );
        _mockReceiveRewards(3000);
        vm.prank(sender);
        ftsoRewardOffersManager.offerRewards{value: 3000} (2 + 1, offers);
        assertEq(mockRewardManager.balance, 3000);
    }

    //// helper functions
    function _mockGetCurrentEpochId(uint256 _epochId) internal {
        vm.mockCall(
            mockFlareSystemManager,
            abi.encodeWithSelector(FlareSystemManager.getCurrentRewardEpochId.selector),
            abi.encode(_epochId)
        );
    }

    function _mockCurrentRewardEpochExpectedEndTs(uint256 _endTs) internal {
        vm.mockCall(
            mockFlareSystemManager,
            abi.encodeWithSelector(flareSystemManager.currentRewardEpochExpectedEndTs.selector),
            abi.encode(_endTs)
        );
    }

    function _mockNewSigningPolicyInitializationStartSeconds(uint256 _startSeconds) internal {
        vm.mockCall(
            mockFlareSystemManager,
            abi.encodeWithSelector(flareSystemManager.newSigningPolicyInitializationStartSeconds.selector),
            abi.encode(_startSeconds)
        );
    }

    function _mockGetDecimals(bytes8 _feedName, int8 _decimals) internal {
        vm.mockCall(
            mockFtsoFeedDecimals,
            abi.encodeWithSelector(FtsoFeedDecimals.getDecimals.selector, _feedName),
            abi.encode(_decimals)
        );
    }

    function _mockReceiveRewards(uint256 _amount) internal {
        vm.mockCall(
            mockRewardManager,
            // _amount,
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

}