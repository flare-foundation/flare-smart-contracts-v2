// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../../contracts/protocol/implementation/FtsoProxy.sol";
import "../../../../contracts/protocol/implementation/FtsoManagerProxy.sol";
import "../../../../contracts/protocol/implementation/Submission.sol";
import "../../../../contracts/fastUpdates/implementation/FastUpdater.sol";
import "../../../../contracts/fastUpdates/implementation/FastUpdatesConfiguration.sol";
import "../../../../contracts/fastUpdates/implementation/FastUpdateIncentiveManager.sol";


// solhint-disable-next-line max-states-count
contract FtsoProxyTest is Test {

    FtsoProxy private ftsoProxyFLR;
    FtsoProxy private ftsoProxySGB;
    FtsoProxy private ftsoProxyBTC;
    FtsoManagerProxy private ftsoManagerProxy;
    FastUpdater private fastUpdater;
    FastUpdatesConfiguration private fastUpdatesConfiguration;
    Submission private submission;

    address private governance;
    address private addressUpdater;
    address private flareDaemon;
    address private mockFlareSystemsManager;
    address private mockInflation;
    address private mockRewardManager;
    address private mockFtsoInflationConfigurations;
    address private mockFtsoFeedPublisher;
    address private mockRewardManagerV2;
    address private mockRelay;
    FastUpdateIncentiveManager private fastUpdateIncentiveManager;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    uint256 constant private SAMPLE_SIZE = 0x1000000000000000000000000000000;
    uint256 constant private RANGE = 0x800000000000000000000000000;
    uint256 constant private SAMPLE_INCREASE_LIMIT = 0x100000000000000000000000000000;
    uint256 constant private RANGE_INCREASE_LIMIT = 0x8000000000000000000000000000;
    uint256 constant private RANGE_INCREASE_PRICE = 10 ** 24;
    uint256 constant private SAMPLE_SIZE_INCREASE_PRICE = 1425;
    uint256 constant private DURATION = 8;

    address private voter;

    function setUp() public {
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");
        flareDaemon = makeAddr("flareDaemon");

        ftsoManagerProxy = new FtsoManagerProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            makeAddr("oldFtsoManager")
        );

        submission = new Submission(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            false
        );

        mockFlareSystemsManager = makeAddr("mockFlareSystemsManager");

        fastUpdateIncentiveManager = new FastUpdateIncentiveManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            FPA.SampleSize.wrap(SAMPLE_SIZE),
            FPA.Range.wrap(RANGE),
            FPA.SampleSize.wrap(SAMPLE_INCREASE_LIMIT),
            FPA.Range.wrap(RANGE_INCREASE_LIMIT),
            FPA.Fee.wrap(SAMPLE_SIZE_INCREASE_PRICE),
            FPA.Fee.wrap(RANGE_INCREASE_PRICE),
            DURATION
        );


        fastUpdatesConfiguration = new FastUpdatesConfiguration(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater
        );

        fastUpdater = new FastUpdater(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            flareDaemon,
            uint32(block.timestamp),
            90,
            10
        );

        mockFlareSystemsManager = makeAddr("mockFlareSystemsManager");
        mockInflation = makeAddr("mockInflation");
        mockRewardManager = makeAddr("mockRewardManager");
        mockRewardManagerV2 = makeAddr("rewardManagerV2");
        mockFtsoInflationConfigurations = makeAddr("mockFtsoInflationConfigurations");
        mockFtsoFeedPublisher = makeAddr("ftsoFeedPublisher");
        mockRelay = makeAddr("mockRelay");

        vm.startPrank(addressUpdater);
        contractNameHashes = new bytes32[](2);
        contractAddresses = new address[](2);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("FastUpdater"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = address(fastUpdater);
        fastUpdatesConfiguration.updateContractAddresses(contractNameHashes, contractAddresses);

        contractNameHashes = new bytes32[](6);
        contractAddresses = new address[](6);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[2] = keccak256(abi.encode("FastUpdateIncentiveManager"));
        contractNameHashes[3] = keccak256(abi.encode("VoterRegistry"));
        contractNameHashes[4] = keccak256(abi.encode("FastUpdatesConfiguration"));
        contractNameHashes[5] = keccak256(abi.encode("FtsoFeedPublisher"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = mockFlareSystemsManager;
        contractAddresses[2] = address(fastUpdateIncentiveManager);
        contractAddresses[3] = makeAddr("mockVoterRegistry");
        contractAddresses[4] = address(fastUpdatesConfiguration);
        contractAddresses[5] = mockFtsoFeedPublisher;
        fastUpdater.updateContractAddresses(contractNameHashes, contractAddresses);

        contractNameHashes = new bytes32[](3);
        contractAddresses = new address[](3);
        contractNameHashes[0] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[1] = keccak256(abi.encode("Relay"));
        contractNameHashes[2] = keccak256(abi.encode("AddressUpdater"));
        contractAddresses[0] = mockFlareSystemsManager;
        contractAddresses[1] = mockRelay;
        contractAddresses[2] = addressUpdater;
        submission.updateContractAddresses(contractNameHashes, contractAddresses);

        contractNameHashes = new bytes32[](8);
        contractAddresses = new address[](8);
        contractNameHashes[0] = keccak256(abi.encode("FtsoRewardManagerProxy"));
        contractNameHashes[1] = keccak256(abi.encode("RewardManager"));
        contractNameHashes[2] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[3] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[4] = keccak256(abi.encode("Submission"));
        contractNameHashes[5] = keccak256(abi.encode("FastUpdater"));
        contractNameHashes[6] = keccak256(abi.encode("FastUpdatesConfiguration"));
        contractNameHashes[7] = keccak256(abi.encode("FtsoRegistry"));
        contractAddresses[0] = mockRewardManager;
        contractAddresses[1] = mockRewardManagerV2;
        contractAddresses[2] = mockFlareSystemsManager;
        contractAddresses[3] = addressUpdater;
        contractAddresses[4] = address(submission);
        contractAddresses[5] = address(fastUpdater);
        contractAddresses[6] = address(fastUpdatesConfiguration);
        contractAddresses[7] = makeAddr("mockFtsoRegistry");
        ftsoManagerProxy.updateContractAddresses(contractNameHashes, contractAddresses);
        vm.stopPrank();

        /// ftso proxy contract(s)
        ftsoProxyFLR = new FtsoProxy(
            "FLR",
            bytes21("FLR"),
            100,
            IIFtsoManagerProxy(address(ftsoManagerProxy))
        );

        ftsoProxySGB = new FtsoProxy(
            "SGB",
            bytes21("SGB"),
            100,
            IIFtsoManagerProxy(address(ftsoManagerProxy))
        );

        ftsoProxyBTC = new FtsoProxy(
            "BTC",
            bytes21("BTC"),
            100,
            IIFtsoManagerProxy(address(ftsoManagerProxy))
        );

        address[] memory freeFetchContracts = new address[](3);
        freeFetchContracts[0] = address(ftsoProxyFLR);
        freeFetchContracts[1] = address(ftsoProxySGB);
        freeFetchContracts[2] = address(ftsoProxyBTC);
        vm.prank(governance);
        fastUpdater.setFreeFetchContracts(freeFetchContracts);
    }


    function testGetContractAddresses() public {
        assertEq(address(ftsoProxyFLR.fastUpdater()), address(fastUpdater));
        assertEq(address(ftsoProxyFLR.fastUpdatesConfiguration()), address(fastUpdatesConfiguration));
        assertEq(address(ftsoProxyFLR.flareSystemsManager()), mockFlareSystemsManager);
        assertEq(address(ftsoProxyFLR.submission()), address(submission));
    }

    function testSymbol() public {
        // deploying contract in test for constructor coverage
        FtsoProxy ftsoProxyETH = new FtsoProxy(
            "ETH",
            bytes21("ETH"),
            100,
            IIFtsoManagerProxy(address(ftsoManagerProxy))
        );
        assertEq(ftsoProxyETH.symbol(), "ETH");
        assertEq(ftsoProxyETH.feedId(), bytes21("ETH"));
    }

    function testActive() public {
        assertTrue(ftsoProxyFLR.active());
    }

    function testGetCurrentEpochId() public {
        _mockGetCurrentVotingEpochId(134);
        assertEq(ftsoProxyFLR.getCurrentEpochId(), 134);
    }

    function testGetEpochId() public {
        _mockFirstVotingRoundStartTs(1000);
        _mockVotingEpochDurationSeconds(90);
        assertEq(ftsoProxyFLR.getEpochId(1000), 0);
        assertEq(ftsoProxyFLR.getEpochId(1090), 1);
        assertEq(ftsoProxyFLR.getEpochId(1179), 1);
    }

    function testGetEpochPrice() public {
        vm.expectRevert("not supported");
        ftsoProxyFLR.getEpochPrice(1);
    }

    function testGetPriceEpochData() public {
        uint256 currentRewardEpoch = 3;
        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(IFlareSystemsManager.getCurrentRewardEpoch.selector),
            abi.encode(currentRewardEpoch)
        );
        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(IFlareSystemsManager.getVotePowerBlock.selector, currentRewardEpoch),
            abi.encode(987)
        );
        _mockFirstVotingRoundStartTs(1000);
        _mockVotingEpochDurationSeconds(90);
        _mockGetCurrentVotingEpochId(123);

        (uint256 epochId, uint256 submitEnd, uint256 revealEnd, uint256 vpBlock, bool fallbackMode) =
            ftsoProxyFLR.getPriceEpochData();
        assertEq(epochId, 123);
        assertEq(submitEnd, 1000 + (123 + 1) * 90);
        assertEq(revealEnd, 1000 + (123 + 1) * 90 + 45);
        assertEq(vpBlock, 987);
        assertFalse(fallbackMode);
    }

    function testGetPriceEpochConfiguration() public {
        _mockFirstVotingRoundStartTs(2000);
        _mockVotingEpochDurationSeconds(90);
        (uint256 firstEpochStart, uint256 submitSeconds, uint256 revealSeconds) =
            ftsoProxyFLR.getPriceEpochConfiguration();
        assertEq(firstEpochStart, 2000);
        assertEq(submitSeconds, 90);
        assertEq(revealSeconds, 45);
    }

    function testGetEpochPriceForVoter() public {
        vm.expectRevert("not supported");
        ftsoProxyFLR.getEpochPriceForVoter(1, makeAddr("voter"));
    }

    function testGetCurrentRandom() public {
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(bytes4(keccak256("getRandomNumber()"))),
            abi.encode(812, true, 123456)
        );
        assertEq(ftsoProxyFLR.getCurrentRandom(), 812);
    }

    function testGetRandom() public {
        // todo
    }

    function testGetCurrentPriceFromTrustedProviders() public {
        vm.expectRevert("not supported");
        ftsoProxyFLR.getCurrentPriceFromTrustedProviders();
    }

    function testGetCurrentPriceWithDecimalsFromTrustedProviders() public {
        vm.expectRevert("not supported");
        ftsoProxyFLR.getCurrentPriceWithDecimalsFromTrustedProviders();
    }

    function testGetCurrentPrice() public {
        _addFeeds();
        (uint256 price, uint256 timestamp) = ftsoProxyFLR.getCurrentPrice();
        assertEq(price, 1234560);
        assertEq(timestamp, 0);

        (price, ) = ftsoProxySGB.getCurrentPrice();
        assertEq(price, 123456);

        (price, ) = ftsoProxyBTC.getCurrentPrice();
        assertEq(price, 89 * 10 ** 6 * 10 ** 5);
    }

    function testGetCurrentPriceWithDecimals() public {
        _addFeeds();
        (uint256 price, uint256 timestamp, uint256 decimals) = ftsoProxyFLR.getCurrentPriceWithDecimals();
        assertEq(price, 1234560);
        assertEq(timestamp, 0);
        assertEq(decimals, 5);
    }

    function testGetCurrentPriceDetails() public {
        _addFeeds();
        (
            uint256 price,
            uint256 timestamp,
            IFtso.PriceFinalizationType finalizationType,
            uint256 finalizationTimestamp,
            IFtso.PriceFinalizationType finalizationType2
        ) = ftsoProxySGB.getCurrentPriceDetails();
        assertEq(price, 123456);
        assertEq(timestamp, 0);
        assertEq(uint8(finalizationType), uint8(IFtso.PriceFinalizationType.WEIGHTED_MEDIAN));
        assertEq(finalizationTimestamp, 0);
        assertEq(uint8(finalizationType2), uint8(IFtso.PriceFinalizationType.WEIGHTED_MEDIAN));
    }


    ////
    function _mockGetCurrentVotingEpochId(uint256 _epochId) private {
        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(IFlareSystemsManager.getCurrentVotingEpochId.selector),
            abi.encode(_epochId)
        );
    }

    function _mockFirstVotingRoundStartTs(uint256 _startTs) private {
        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(IFlareSystemsManager.firstVotingRoundStartTs.selector),
            abi.encode(_startTs)
        );
    }

    function _mockVotingEpochDurationSeconds(uint256 _duration) private {
        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(IFlareSystemsManager.votingEpochDurationSeconds.selector),
            abi.encode(_duration)
        );
    }

    function _addFeeds() public {
        IFastUpdatesConfiguration.FeedConfiguration[] memory feedConfigs =
            new IFastUpdatesConfiguration.FeedConfiguration[](3);

        feedConfigs[0] = IFastUpdatesConfiguration.FeedConfiguration({
            feedId: bytes21("FLR"),
            rewardBandValue: 100,
            inflationShare: 150
        });

        feedConfigs[1] = IFastUpdatesConfiguration.FeedConfiguration({
            feedId: bytes21("SGB"),
            rewardBandValue: 200,
            inflationShare: 250
        });

        feedConfigs[2] = IFastUpdatesConfiguration.FeedConfiguration({
            feedId: bytes21("BTC"),
            rewardBandValue: 300,
            inflationShare: 350
        });

        vm.mockCall(
            mockFtsoFeedPublisher,
            abi.encodeWithSelector(bytes4(keccak256("getCurrentFeed(bytes21)")), bytes21("FLR")),
            abi.encode(IFtsoFeedPublisher.Feed({
                votingRoundId: 1,
                id: bytes21("FLR"),
                value: 123456,
                turnoutBIPS: 1000,
                decimals: 4
            }))
        );

        vm.mockCall(
            mockFtsoFeedPublisher,
            abi.encodeWithSelector(bytes4(keccak256("getCurrentFeed(bytes21)")), bytes21("SGB")),
            abi.encode(IFtsoFeedPublisher.Feed({
                votingRoundId: 1,
                id: bytes21("SGB"),
                value: 1234567,
                turnoutBIPS: 1000,
                decimals: 6
            }))
        );

        vm.mockCall(
            mockFtsoFeedPublisher,
            abi.encodeWithSelector(bytes4(keccak256("getCurrentFeed(bytes21)")), bytes21("BTC")),
            abi.encode(IFtsoFeedPublisher.Feed({
                votingRoundId: 1,
                id: bytes21("BTC"),
                value: 89,
                turnoutBIPS: 1000,
                decimals: -6
            }))
        );

        vm.prank(governance);
        fastUpdatesConfiguration.addFeeds(feedConfigs);
    }


}