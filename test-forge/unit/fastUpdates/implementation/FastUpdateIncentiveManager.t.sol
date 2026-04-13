// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {
    FastUpdateIncentiveManager
} from "../../../../contracts/fastUpdates/implementation/FastUpdateIncentiveManager.sol";
import {IFastUpdatesConfiguration} from "../../../../contracts/userInterfaces/IFastUpdatesConfiguration.sol";
import {IFastUpdateIncentiveManager} from "../../../../contracts/userInterfaces/IFastUpdateIncentiveManager.sol";
import {IGovernanceSettings} from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import "../../../../contracts/fastUpdates/lib/FixedPointArithmetic.sol" as FPA;
contract FastUpdateIncentiveManagerTest is Test {

    FastUpdateIncentiveManager private manager;
    address private rewardManager;

    address private governance;
    address private addressUpdater;
    address private inflation;
    address private fastUpdater;
    address private flareSystemsManager;
    address private fastUpdatesConfiguration;

    // FPA constants: RangeOrSampleFPA(x) = floor(x * 2^120)
    uint256 private constant SAMPLE_SIZE = uint256(1) << 120;           // 1
    uint256 private constant RANGE = uint256(1) << 107;                 // 2^-13
    uint256 private constant SAMPLE_INCREASE_LIMIT = uint256(1) << 116; // 1/16
    uint256 private constant RANGE_INCREASE_LIMIT = uint256(1) << 111;  // 2^-9
    uint256 private constant RANGE_INCREASE_PRICE = 10 ** 24;
    uint256 private constant SAMPLE_SIZE_INCREASE_PRICE = 1425;
    uint256 private constant DURATION = 8;

    event InflationRewardsOffered(
        uint24 indexed rewardEpochId,
        IFastUpdatesConfiguration.FeedConfiguration[] feedConfigurations,
        uint256 amount
    );

    function setUp() public {
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");
        inflation = makeAddr("inflation");
        fastUpdater = makeAddr("fastUpdater");
        flareSystemsManager = makeAddr("flareSystemsManager");
        fastUpdatesConfiguration = makeAddr("fastUpdatesConfiguration");

        rewardManager = makeAddr("rewardManager");
        vm.etch(rewardManager, hex"00");
        vm.mockCall(
            rewardManager,
            abi.encodeWithSignature("getCurrentRewardEpochId()"),
            abi.encode(uint24(0))
        );

        manager = new FastUpdateIncentiveManager(
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

        bytes32[] memory nameHashes = new bytes32[](6);
        address[] memory addrs = new address[](6);
        nameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        nameHashes[1] = keccak256(abi.encode("FlareSystemsManager"));
        nameHashes[2] = keccak256(abi.encode("Inflation"));
        nameHashes[3] = keccak256(abi.encode("RewardManager"));
        nameHashes[4] = keccak256(abi.encode("FastUpdater"));
        nameHashes[5] = keccak256(abi.encode("FastUpdatesConfiguration"));
        addrs[0] = addressUpdater;
        addrs[1] = flareSystemsManager;
        addrs[2] = inflation;
        addrs[3] = rewardManager;
        addrs[4] = fastUpdater;
        addrs[5] = fastUpdatesConfiguration;

        vm.prank(addressUpdater);
        manager.updateContractAddresses(nameHashes, addrs);
    }

    // ── Basic getters ────────────────────────────────────────────────────────

    function testGetExpectedSampleSize() public {
        assertEq(FPA.SampleSize.unwrap(manager.getExpectedSampleSize()), SAMPLE_SIZE);
    }

    function testGetRange() public {
        assertEq(FPA.Range.unwrap(manager.getRange()), RANGE);
    }

    function testGetPrecision() public {
        uint256 expected = (RANGE << 127) / SAMPLE_SIZE;
        assertEq(FPA.Precision.unwrap(manager.getPrecision()), expected);
    }

    function testGetScale() public {
        uint256 precision = (RANGE << 127) / SAMPLE_SIZE;
        uint256 expected = (1 << 127) + precision;
        assertEq(FPA.Scale.unwrap(manager.getScale()), expected);
    }

    function testGetBaseScale() public {
        uint256 precision = (RANGE << 127) / SAMPLE_SIZE;
        uint256 expected = (1 << 127) + precision;
        assertEq(FPA.Scale.unwrap(manager.getBaseScale()), expected);
    }

    // ── Offer incentive ──────────────────────────────────────────────────────

    function testOfferIncentive() public {
        // Cost: RANGE_INCREASE_PRICE / (1 / RANGE) = RANGE_INCREASE_PRICE / 8192
        uint256 cost = RANGE_INCREASE_PRICE / (1 << 13);

        IFastUpdateIncentiveManager.IncentiveOffer memory offer = IFastUpdateIncentiveManager.IncentiveOffer({
            rangeIncrease: FPA.Range.wrap(RANGE),
            rangeLimit: FPA.Range.wrap(RANGE << 1)
        });

        address sender = makeAddr("sender");
        vm.deal(sender, cost);
        vm.prank(sender);
        manager.offerIncentive{value: cost}(offer);

        // Range doubled
        uint256 newRange = RANGE << 1;
        assertEq(FPA.Range.unwrap(manager.getRange()), newRange);
        // Sample size unchanged
        assertEq(FPA.SampleSize.unwrap(manager.getExpectedSampleSize()), SAMPLE_SIZE);

        // Precision = newRange / sampleSize
        uint256 expectedPrecision = (newRange << 127) / SAMPLE_SIZE;
        assertEq(FPA.Precision.unwrap(manager.getPrecision()), expectedPrecision);

        // Scale = 1 + precision
        assertEq(FPA.Scale.unwrap(manager.getScale()), (1 << 127) + expectedPrecision);

        // Base scale unchanged
        uint256 basePrecision = (RANGE << 127) / SAMPLE_SIZE;
        assertEq(FPA.Scale.unwrap(manager.getBaseScale()), (1 << 127) + basePrecision);
    }

    function testOfferIncentiveNotIncreaseRange() public {
        // rangeLimit <= current range → range stays the same
        IFastUpdateIncentiveManager.IncentiveOffer memory offer = IFastUpdateIncentiveManager.IncentiveOffer({
            rangeIncrease: FPA.Range.wrap(RANGE << 2),  // RANGE * 4
            rangeLimit: FPA.Range.wrap(RANGE)            // = current range
        });

        address sender = makeAddr("sender");
        vm.deal(sender, 100000);
        vm.prank(sender);
        manager.offerIncentive{value: 100000}(offer);

        assertEq(FPA.Range.unwrap(manager.getRange()), RANGE);
    }

    function testOfferIncentiveOnlyIncreaseSampleSize() public {
        IFastUpdateIncentiveManager.IncentiveOffer memory offer = IFastUpdateIncentiveManager.IncentiveOffer({
            rangeIncrease: FPA.Range.wrap(0),
            rangeLimit: FPA.Range.wrap(0)
        });

        address sender = makeAddr("sender");
        vm.deal(sender, 100000);
        vm.prank(sender);
        manager.offerIncentive{value: 100000}(offer);

        assertEq(FPA.Range.unwrap(manager.getRange()), RANGE);
        assertGt(FPA.SampleSize.unwrap(manager.getExpectedSampleSize()), SAMPLE_SIZE);
    }

    function testOfferIncentiveRefund1() public {
        // rangeLimit < current range, rangeIncrease = 0 → full refund
        IFastUpdateIncentiveManager.IncentiveOffer memory offer = IFastUpdateIncentiveManager.IncentiveOffer({
            rangeIncrease: FPA.Range.wrap(0),
            rangeLimit: FPA.Range.wrap(RANGE >> 1)  // RANGE / 2
        });

        address sender = makeAddr("sender");
        vm.deal(sender, 100000);
        vm.prank(sender);
        manager.offerIncentive{value: 100000}(offer);

        assertEq(FPA.Range.unwrap(manager.getRange()), RANGE);
        assertEq(FPA.SampleSize.unwrap(manager.getExpectedSampleSize()), SAMPLE_SIZE);
        assertEq(address(manager).balance, 0);
    }

    function testOfferIncentiveRefund2() public {
        // rangeIncrease > 0 but rangeLimit < current range → full refund
        IFastUpdateIncentiveManager.IncentiveOffer memory offer = IFastUpdateIncentiveManager.IncentiveOffer({
            rangeIncrease: FPA.Range.wrap(RANGE >> 2),  // RANGE / 4
            rangeLimit: FPA.Range.wrap(RANGE >> 1)       // RANGE / 2
        });

        address sender = makeAddr("sender");
        vm.deal(sender, 100000);
        vm.prank(sender);
        manager.offerIncentive{value: 100000}(offer);

        assertEq(FPA.Range.unwrap(manager.getRange()), RANGE);
        assertEq(FPA.SampleSize.unwrap(manager.getExpectedSampleSize()), SAMPLE_SIZE);
        assertEq(address(manager).balance, 0);
    }

    function testOfferIncentiveRefund3() public {
        // rangeIncrease > 0 but rangeLimit = 0 → full refund
        IFastUpdateIncentiveManager.IncentiveOffer memory offer = IFastUpdateIncentiveManager.IncentiveOffer({
            rangeIncrease: FPA.Range.wrap(RANGE >> 2),  // RANGE / 4
            rangeLimit: FPA.Range.wrap(0)
        });

        address sender = makeAddr("sender");
        vm.deal(sender, 100000);
        vm.prank(sender);
        manager.offerIncentive{value: 100000}(offer);

        assertEq(FPA.Range.unwrap(manager.getRange()), RANGE);
        assertEq(FPA.SampleSize.unwrap(manager.getExpectedSampleSize()), SAMPLE_SIZE);
        assertEq(address(manager).balance, 0);
    }

    function testOfferIncentiveCapByRangeIncreaseLimit() public {
        IFastUpdateIncentiveManager.IncentiveOffer memory offer = IFastUpdateIncentiveManager.IncentiveOffer({
            rangeIncrease: FPA.Range.wrap(RANGE * 20),
            rangeLimit: FPA.Range.wrap(RANGE_INCREASE_LIMIT * 20)
        });

        address sender = makeAddr("sender");
        uint256 bigValue = 9e30;
        vm.deal(sender, bigValue);
        vm.prank(sender);
        manager.offerIncentive{value: bigValue}(offer);

        assertEq(FPA.Range.unwrap(manager.getRange()), RANGE_INCREASE_LIMIT);
    }

    // ── Offer incentive reverts ──────────────────────────────────────────────

    function testRevertInsufficientContribution() public {
        IFastUpdateIncentiveManager.IncentiveOffer memory offer = IFastUpdateIncentiveManager.IncentiveOffer({
            rangeIncrease: FPA.Range.wrap(RANGE),
            rangeLimit: FPA.Range.wrap(RANGE << 1)
        });

        address sender = makeAddr("sender");
        vm.prank(sender);
        vm.expectRevert("Insufficient contribution to pay for range increase");
        manager.offerIncentive(offer);
    }

    function testRevertRangeIncreaseTooLarge() public {
        IFastUpdateIncentiveManager.IncentiveOffer memory offer = IFastUpdateIncentiveManager.IncentiveOffer({
            rangeIncrease: FPA.Range.wrap(2 ** 255),
            rangeLimit: FPA.Range.wrap(RANGE << 1)
        });

        address sender = makeAddr("sender");
        vm.prank(sender);
        vm.expectRevert("Range increase too large");
        manager.offerIncentive(offer);
    }

    function testRevertPrecisionGreaterThan100Percent() public {
        // Constructor with rangeIncreaseLimit >= sampleSize
        vm.expectRevert("Parameters should not allow making the precision greater than 100%");
        new FastUpdateIncentiveManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            FPA.SampleSize.wrap(SAMPLE_SIZE),
            FPA.Range.wrap(RANGE),
            FPA.SampleSize.wrap(SAMPLE_INCREASE_LIMIT),
            FPA.Range.wrap(uint256(1) << 120),  // rangeIncreaseLimit = 1 (== sampleSize)
            FPA.Fee.wrap(SAMPLE_SIZE_INCREASE_PRICE),
            FPA.Fee.wrap(RANGE_INCREASE_PRICE),
            DURATION
        );

        // setRangeIncreaseLimit with too large value
        vm.prank(governance);
        vm.expectRevert("Parameters should not allow making the precision greater than 100%");
        manager.setRangeIncreaseLimit(FPA.Range.wrap(uint256(4) << 120));
    }

    // ── Advance and reset ────────────────────────────────────────────────────

    function testAdvanceAndReset() public {
        uint256 cost = RANGE_INCREASE_PRICE / (1 << 13);
        IFastUpdateIncentiveManager.IncentiveOffer memory offer = IFastUpdateIncentiveManager.IncentiveOffer({
            rangeIncrease: FPA.Range.wrap(RANGE),
            rangeLimit: FPA.Range.wrap(RANGE << 1)
        });

        address sender = makeAddr("sender");
        vm.deal(sender, cost);
        vm.prank(sender);
        manager.offerIncentive{value: cost}(offer);

        assertEq(FPA.Range.unwrap(manager.getRange()), RANGE << 1);

        // Advance 10 times (> DURATION=8) to reset the increase
        // Each advance must be in a new block (circular index uses block.number)
        for (uint256 i = 0; i < 10; i++) {
            vm.roll(block.number + 1);
            vm.prank(fastUpdater);
            manager.advance();
        }

        assertEq(FPA.Range.unwrap(manager.getRange()), RANGE);
    }

    function testRevertAdvanceNotFastUpdater() public {
        vm.expectRevert("only fast updater");
        manager.advance();
    }

    // ── Incentive duration ───────────────────────────────────────────────────

    function testChangeIncentiveDuration() public {
        assertEq(manager.getIncentiveDuration(), DURATION);

        vm.prank(governance);
        manager.setIncentiveParameters(
            FPA.SampleSize.wrap(SAMPLE_SIZE),
            FPA.Range.wrap(RANGE),
            FPA.Fee.wrap(SAMPLE_SIZE_INCREASE_PRICE),
            10
        );

        assertEq(manager.getIncentiveDuration(), 10);
    }

    function testRevertCircularLengthZero() public {
        vm.prank(governance);
        vm.expectRevert("CircularListManager: circular length must be greater than 0");
        manager.setIncentiveParameters(
            FPA.SampleSize.wrap(SAMPLE_SIZE),
            FPA.Range.wrap(RANGE),
            FPA.Fee.wrap(SAMPLE_SIZE_INCREASE_PRICE),
            0
        );
    }

    // ── Inflation offers ─────────────────────────────────────────────────────

    function testTriggerInflationOffers() public {
        uint256 day = 60 * 60 * 24;

        // Mock getFeedConfigurations
        IFastUpdatesConfiguration.FeedConfiguration[] memory configs =
            new IFastUpdatesConfiguration.FeedConfiguration[](2);
        configs[0] = IFastUpdatesConfiguration.FeedConfiguration({
            feedId: bytes21("feed1"),
            rewardBandValue: 5000,
            inflationShare: 10000
        });
        configs[1] = IFastUpdatesConfiguration.FeedConfiguration({
            feedId: bytes21("feed2"),
            rewardBandValue: 5000,
            inflationShare: 10000
        });

        vm.mockCall(
            fastUpdatesConfiguration,
            abi.encodeWithSelector(IFastUpdatesConfiguration.getFeedConfigurations.selector),
            abi.encode(configs)
        );

        assertEq(manager.getContractName(), "FastUpdateIncentiveManager");

        // Set daily authorized inflation
        vm.prank(inflation);
        manager.setDailyAuthorizedInflation(5000);

        // Receive inflation
        vm.deal(inflation, 5000);
        vm.prank(inflation);
        manager.receiveInflation{value: 5000}();

        uint256 time = block.timestamp;
        assertEq(address(manager).balance, 5000);

        // Trigger switchover
        vm.prank(flareSystemsManager);
        vm.expectEmit(true, false, false, true);
        emit InflationRewardsOffered(3, configs, 5000);
        manager.triggerRewardEpochSwitchover(
            2,
            uint64(3 * day + time),
            uint64(day)
        );

        assertEq(address(manager).balance, 0);
        assertEq(rewardManager.balance, 5000);

        // Token pool supply data
        (uint256 locked, uint256 totalAuthorized, uint256 totalClaimed) = manager.getTokenPoolSupplyData();
        assertEq(locked, 0);
        assertEq(totalAuthorized, 5000);
        assertEq(totalClaimed, 5000);
    }

    // ── Governance setters ───────────────────────────────────────────────────

    function testSetLimitsAndPrice() public {
        assertEq(FPA.SampleSize.unwrap(manager.sampleIncreaseLimit()), SAMPLE_INCREASE_LIMIT);
        assertEq(FPA.Fee.unwrap(manager.rangeIncreasePrice()), RANGE_INCREASE_PRICE);
        assertEq(FPA.Range.unwrap(manager.rangeIncreaseLimit()), RANGE_INCREASE_LIMIT);

        vm.startPrank(governance);
        manager.setSampleIncreaseLimit(FPA.SampleSize.wrap(SAMPLE_INCREASE_LIMIT << 1));
        manager.setRangeIncreaseLimit(FPA.Range.wrap(RANGE_INCREASE_LIMIT << 1));
        manager.setRangeIncreasePrice(FPA.Fee.wrap(RANGE_INCREASE_PRICE * 2));
        vm.stopPrank();

        assertEq(FPA.SampleSize.unwrap(manager.sampleIncreaseLimit()), SAMPLE_INCREASE_LIMIT << 1);
        assertEq(FPA.Range.unwrap(manager.rangeIncreaseLimit()), RANGE_INCREASE_LIMIT << 1);
        assertEq(FPA.Fee.unwrap(manager.rangeIncreasePrice()), RANGE_INCREASE_PRICE * 2);
    }

    function testSetSampleSizeAndRange() public {
        assertEq(FPA.SampleSize.unwrap(manager.getExpectedSampleSize()), SAMPLE_SIZE);
        assertEq(FPA.Range.unwrap(manager.getRange()), RANGE);

        vm.prank(governance);
        manager.setIncentiveParameters(
            FPA.SampleSize.wrap(SAMPLE_SIZE << 1),
            FPA.Range.wrap(RANGE << 1),
            FPA.Fee.wrap(SAMPLE_SIZE_INCREASE_PRICE * 2),
            DURATION
        );

        assertEq(FPA.SampleSize.unwrap(manager.getExpectedSampleSize()), SAMPLE_SIZE << 1);
        assertEq(FPA.Range.unwrap(manager.getRange()), RANGE << 1);
        assertEq(FPA.Fee.unwrap(manager.getCurrentSampleSizeIncreasePrice()), SAMPLE_SIZE_INCREASE_PRICE * 2);
    }

    // ── Revert: values too big ───────────────────────────────────────────────

    function testRevertSampleIncreaseLimitTooLarge() public {
        vm.prank(governance);
        vm.expectRevert("Sample increase limit too large");
        manager.setSampleIncreaseLimit(FPA.SampleSize.wrap(2 ** 255));
    }

    function testRevertRangeIncreasePriceTooLarge() public {
        // Use 2^128 — large enough to fail FPA.check but small enough that
        // the multiplication in _checkRangeParameters doesn't overflow to zero
        vm.prank(governance);
        vm.expectRevert("Range increase price too large");
        manager.setRangeIncreasePrice(FPA.Fee.wrap(uint256(1) << 128));
    }

    // ── Revert: setIncentiveParameters edge cases ────────────────────────────

    function testRevertSampleSizeTooLarge() public {
        vm.prank(governance);
        vm.expectRevert("Sample size too large");
        manager.setIncentiveParameters(
            FPA.SampleSize.wrap(2 ** 255),
            FPA.Range.wrap(RANGE),
            FPA.Fee.wrap(SAMPLE_SIZE_INCREASE_PRICE),
            DURATION
        );
    }

    function testRevertPrecisionGreaterThan100PercentViaSetParams() public {
        vm.prank(governance);
        vm.expectRevert("Parameters should not allow making the precision greater than 100%");
        manager.setIncentiveParameters(
            FPA.SampleSize.wrap(RANGE << 1),   // sampleSize = RANGE * 2
            FPA.Range.wrap(RANGE),
            FPA.Fee.wrap(SAMPLE_SIZE_INCREASE_PRICE),
            DURATION
        );
    }

    function testRevertRangeGreaterThanLimit() public {
        vm.prank(governance);
        vm.expectRevert("Range cannot be greater than the range increase limit");
        manager.setIncentiveParameters(
            FPA.SampleSize.wrap(RANGE_INCREASE_LIMIT << 1),
            FPA.Range.wrap(RANGE_INCREASE_LIMIT * 3),
            FPA.Fee.wrap(SAMPLE_SIZE_INCREASE_PRICE),
            DURATION
        );
    }

    function testRevertPrecisionTooSmall() public {
        vm.prank(governance);
        vm.expectRevert("Precision value of updates needs to be at least 2^(-25)");
        manager.setIncentiveParameters(
            FPA.SampleSize.wrap(uint256(1) << 120),    // 1
            FPA.Range.wrap(uint256(1) << 90),           // 2^-30
            FPA.Fee.wrap(SAMPLE_SIZE_INCREASE_PRICE),
            DURATION
        );
    }

    // ── Revert: only governance ──────────────────────────────────────────────

    function testRevertOnlyGovernanceSetIncentiveParameters() public {
        address notGov = makeAddr("notGovernance");
        vm.prank(notGov);
        vm.expectRevert("only governance");
        manager.setIncentiveParameters(
            FPA.SampleSize.wrap(SAMPLE_SIZE),
            FPA.Range.wrap(RANGE),
            FPA.Fee.wrap(SAMPLE_SIZE_INCREASE_PRICE),
            DURATION
        );
    }

    function testRevertOnlyGovernanceSetSampleIncreaseLimit() public {
        address notGov = makeAddr("notGovernance");
        vm.prank(notGov);
        vm.expectRevert("only governance");
        manager.setSampleIncreaseLimit(FPA.SampleSize.wrap(SAMPLE_INCREASE_LIMIT));
    }

    function testRevertOnlyGovernanceSetRangeIncreasePrice() public {
        address notGov = makeAddr("notGovernance");
        vm.prank(notGov);
        vm.expectRevert("only governance");
        manager.setRangeIncreasePrice(FPA.Fee.wrap(RANGE_INCREASE_PRICE));
    }

    function testRevertOnlyGovernanceSetRangeIncreaseLimit() public {
        address notGov = makeAddr("notGovernance");
        vm.prank(notGov);
        vm.expectRevert("only governance");
        manager.setRangeIncreaseLimit(FPA.Range.wrap(RANGE_INCREASE_LIMIT));
    }

    // ── Revert: values too low ───────────────────────────────────────────────

    function testRevertRangeIncreasePriceTooLowViaSetParams() public {
        vm.prank(governance);
        // solhint-disable-next-line max-line-length
        vm.expectRevert(
            "Range increase price too low, range increase of 1e-6 of base range should cost at least 1 wei"
        );
        manager.setIncentiveParameters(
            FPA.SampleSize.wrap(uint256(1) << 120),
            FPA.Range.wrap(1e5),
            FPA.Fee.wrap(SAMPLE_SIZE_INCREASE_PRICE),
            DURATION
        );
    }

    function testRevertRangeIncreasePriceTooLowViaSetPrice() public {
        vm.prank(governance);
        // solhint-disable-next-line max-line-length
        vm.expectRevert(
            "Range increase price too low, range increase of 1e-6 of base range should cost at least 1 wei"
        );
        manager.setRangeIncreasePrice(FPA.Fee.wrap(5));
    }

    function testRevertRangeIncreaseLimitRangeGreaterThanLimit() public {
        vm.prank(governance);
        vm.expectRevert("Range cannot be greater than the range increase limit");
        manager.setRangeIncreaseLimit(FPA.Range.wrap(5));
    }
}
