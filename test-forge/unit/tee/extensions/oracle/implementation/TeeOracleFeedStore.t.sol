// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import {
    TeeOracleFeedStore
} from "../../../../../../contracts/tee/extensions/oracle/implementation/TeeOracleFeedStore.sol";
import {
    TeeOracleFeedStoreProxy
} from "../../../../../../contracts/tee/extensions/oracle/proxy/TeeOracleFeedStoreProxy.sol";
import {
    ITeeOracleFeedStore,
    TEE_ORACLE_FEED
} from "../../../../../../contracts/userInterfaces/tee/ITeeOracleFeedStore.sol";
import {
    ITeeOracleInstructionsSender
} from "../../../../../../contracts/userInterfaces/tee/ITeeOracleInstructionsSender.sol";
import { IFeeCalculator } from "../../../../../../contracts/userInterfaces/IFeeCalculator.sol";
import { IFlareGovernance } from "../../../../../../contracts/userInterfaces/IFlareGovernance.sol";
import { Signature } from "../../../../../../contracts/userInterfaces/ISignature.sol";
import { SignedPayload } from "../../../../../../contracts/utils/lib/SignedPayload.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

contract RejectingReceiver {
    // no receive/fallback - plain value transfers revert
}

contract TeeOracleFeedStoreTest is Test {

    uint256 private constant EXTENSION_ID = 1;
    bytes21 private constant FEED_ID = bytes21(bytes.concat(bytes1(uint8(0x20)), bytes("USDX/USD")));
    uint256 private constant FEE = 5;
    bytes32 private constant ENDPOINTS_HASH = keccak256("endpoints");
    bytes32 private constant ADMINS_HASH = keccak256("admins");
    uint256 private constant TIMELOCK = 3600;
    // deployment defaults: threshold 1 (behaves as a single-signature store), 1% relative
    // deviation, no absolute allowance
    uint8 private constant REQUIRED_SIGNATURES = 1;
    uint16 private constant MAX_SPREAD_BIPS = 100;
    uint64 private constant MAX_SPREAD_ABSOLUTE = 0;
    uint256 private constant MAX_SIGNATURES = 32;

    bytes4 private constant VERIFY_TEE_SIGNATURE_SELECTOR =
        bytes4(keccak256("verifyTeeSignature(uint256,(uint8,bytes32,bytes32),bytes32)"));

    TeeOracleFeedStore private feedStore;
    TeeOracleFeedStore private feedStoreImpl;

    address private governance;
    address private productionGovernance;
    address private executor;
    address private addressUpdater;
    address private feeDestination;
    address private instructionsSender;
    address private fdc2Verification;
    address private feeCalculator;
    address private teeId;
    IGovernanceSettings private governanceSettings;

    Signature private signature;

    function setUp() public {
        vm.warp(1_700_000_000);

        governance = makeAddr("governance");
        productionGovernance = makeAddr("productionGovernance");
        executor = makeAddr("executor");
        addressUpdater = makeAddr("addressUpdater");
        feeDestination = makeAddr("feeDestination");
        instructionsSender = makeAddr("instructionsSender");
        teeId = makeAddr("teeId");
        governanceSettings = IGovernanceSettings(makeAddr("governanceSettings"));
        signature = Signature(27, bytes32(uint256(1)), bytes32(uint256(2)));

        _mockSenderExtensionId(EXTENSION_ID);

        feedStoreImpl = new TeeOracleFeedStore();
        TeeOracleFeedStoreProxy proxy = new TeeOracleFeedStoreProxy(
            governanceSettings,
            governance,
            addressUpdater,
            ITeeOracleInstructionsSender(instructionsSender),
            FEED_ID,
            feeDestination,
            _policy(REQUIRED_SIGNATURES, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE),
            address(feedStoreImpl)
        );
        feedStore = TeeOracleFeedStore(address(proxy));

        bytes32[] memory contractNameHashes = new bytes32[](3);
        address[] memory contractAddresses = new address[](3);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("Fdc2Verification"));
        contractNameHashes[2] = keccak256(abi.encode("FeeCalculator"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = makeAddr("Fdc2Verification");
        contractAddresses[2] = makeAddr("FeeCalculator");
        vm.prank(addressUpdater);
        feedStore.updateContractAddresses(contractNameHashes, contractAddresses);

        fdc2Verification = address(feedStore.fdc2Verification());
        feeCalculator = address(feedStore.feeCalculator());

        _mockVerifyTeeSignature(teeId);
        _mockLatestEndpointsHash(ENDPOINTS_HASH);
        _mockLatestAdminsHash(ADMINS_HASH);
        _mockCalculateFee(FEE);
    }

    // -------------------------------------------------------------------------
    // initialization
    // -------------------------------------------------------------------------

    function testInitialState() public {
        assertEq(feedStore.extensionId(), EXTENSION_ID);
        assertEq(address(feedStore.instructionsSender()), instructionsSender);
        assertEq(feedStore.feedId(), FEED_ID);
        assertEq(feedStore.feeDestination(), feeDestination);
        assertEq(feedStore.requiredSignatures(), REQUIRED_SIGNATURES);
        assertEq(feedStore.maxSpreadBIPS(), MAX_SPREAD_BIPS);
        assertEq(feedStore.maxSpreadAbsolute(), MAX_SPREAD_ABSOLUTE);
        assertEq(
            keccak256(abi.encode(feedStore.getSubmissionPolicy())),
            keccak256(abi.encode(_policy(REQUIRED_SIGNATURES, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE)))
        );
        assertEq(feedStore.observedAt(), 0);
        assertEq(feedStore.governance(), governance);
        assertEq(feedStore.implementation(), address(feedStoreImpl));
    }

    function testInitializeEmitsEvents() public {
        vm.expectEmit();
        emit ITeeOracleFeedStore.FeedStoreInitialised(instructionsSender, EXTENSION_ID, FEED_ID);
        vm.expectEmit();
        emit ITeeOracleFeedStore.FeeDestinationSet(feeDestination);
        vm.expectEmit();
        emit ITeeOracleFeedStore.SubmissionPolicySet(
            REQUIRED_SIGNATURES, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE);
        new TeeOracleFeedStoreProxy(
            governanceSettings,
            governance,
            addressUpdater,
            ITeeOracleInstructionsSender(instructionsSender),
            FEED_ID,
            feeDestination,
            _policy(REQUIRED_SIGNATURES, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE),
            address(feedStoreImpl)
        );
    }

    function testInitializeRevertZeroInstructionsSender() public {
        vm.expectRevert(ITeeOracleFeedStore.ZeroAddress.selector);
        new TeeOracleFeedStoreProxy(
            governanceSettings,
            governance,
            addressUpdater,
            ITeeOracleInstructionsSender(address(0)),
            FEED_ID,
            feeDestination,
            _policy(REQUIRED_SIGNATURES, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE),
            address(feedStoreImpl)
        );
    }

    function testInitializeRevertInvalidFeedCategory() public {
        // category byte below the custom range [0x20, 0x40)
        bytes21 badFeedId = bytes21(bytes.concat(bytes1(uint8(0x01)), bytes("USDX/USD")));
        vm.expectRevert(ITeeOracleFeedStore.InvalidFeedCategory.selector);
        new TeeOracleFeedStoreProxy(
            governanceSettings,
            governance,
            addressUpdater,
            ITeeOracleInstructionsSender(instructionsSender),
            badFeedId,
            feeDestination,
            _policy(REQUIRED_SIGNATURES, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE),
            address(feedStoreImpl)
        );
    }

    function testInitializeRevertZeroFeeDestination() public {
        vm.expectRevert(ITeeOracleFeedStore.ZeroAddress.selector);
        new TeeOracleFeedStoreProxy(
            governanceSettings,
            governance,
            addressUpdater,
            ITeeOracleInstructionsSender(instructionsSender),
            FEED_ID,
            address(0),
            _policy(REQUIRED_SIGNATURES, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE),
            address(feedStoreImpl)
        );
    }

    function testInitializeRevertUninitializedSender() public {
        // a zero extension id means the sender proxy is not initialized yet
        _mockSenderExtensionId(0);
        vm.expectRevert(ITeeOracleFeedStore.ZeroExtensionId.selector);
        new TeeOracleFeedStoreProxy(
            governanceSettings,
            governance,
            addressUpdater,
            ITeeOracleInstructionsSender(instructionsSender),
            FEED_ID,
            feeDestination,
            _policy(REQUIRED_SIGNATURES, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE),
            address(feedStoreImpl)
        );
    }

    function testReinitializeReverts() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        feedStore.initialize(
            governanceSettings,
            governance,
            addressUpdater,
            ITeeOracleInstructionsSender(instructionsSender),
            FEED_ID,
            feeDestination,
            _policy(REQUIRED_SIGNATURES, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE)
        );
    }

    function testImplementationCannotBeInitialized() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        feedStoreImpl.initialize(
            governanceSettings,
            governance,
            addressUpdater,
            ITeeOracleInstructionsSender(instructionsSender),
            FEED_ID,
            feeDestination,
            _policy(REQUIRED_SIGNATURES, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE)
        );
    }

    // -------------------------------------------------------------------------
    // submitFeedUpdates - one signature: requiredSignatures = 1 and a one-element batch
    // -------------------------------------------------------------------------

    function testSubmitFeedUpdatesOneSignature() public {
        ITeeOracleFeedStore.FeedUpdate memory feedUpdate = _makeFeedUpdate(123456, 4, _now() - 1);

        // the store must verify against the exact SignedPayload digest of the update
        vm.expectCall(
            fdc2Verification,
            abi.encodeWithSelector(
                VERIFY_TEE_SIGNATURE_SELECTOR,
                EXTENSION_ID,
                signature,
                SignedPayload.messageHash(TEE_ORACLE_FEED, keccak256(abi.encode(feedUpdate)))
            )
        );
        vm.expectEmit();
        emit ITeeOracleFeedStore.FeedUpdated(123456, 4, _now() - 1, _teeIds(teeId));
        feedStore.submitFeedUpdates(_one(feedUpdate, signature));

        assertEq(feedStore.observedAt(), _now() - 1);
        (int256 value, int8 decimals, uint64 timestamp) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(value, 123456);
        assertEq(decimals, 4);
        assertEq(timestamp, _now() - 1);
    }

    function testSubmitFeedUpdatesOneSignatureNegativeValue() public {
        _submit(-42, -3, _now() - 1);
        (int256 value, int8 decimals,) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(value, -42);
        assertEq(decimals, -3);
    }

    function testSubmitFeedUpdatesOneSignatureDynamicDecimals() public {
        _submit(123456, 4, _now() - 2);
        _submit(1234567, 5, _now() - 1);
        (int256 value, int8 decimals,) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(value, 1234567);
        assertEq(decimals, 5);
    }

    function testSubmitFeedUpdatesOneSignatureRevertWrongExtensionId() public {
        ITeeOracleFeedStore.FeedUpdate memory feedUpdate = _makeFeedUpdate(1, 0, _now() - 1);
        feedUpdate.extensionId = EXTENSION_ID + 1;
        vm.expectRevert(ITeeOracleFeedStore.WrongExtensionId.selector);
        feedStore.submitFeedUpdates(_one(feedUpdate, signature));
    }

    function testSubmitFeedUpdatesOneSignatureRevertWrongFeedId() public {
        ITeeOracleFeedStore.FeedUpdate memory feedUpdate = _makeFeedUpdate(1, 0, _now() - 1);
        feedUpdate.feedId = bytes21(bytes.concat(bytes1(uint8(0x21)), bytes("OTHER")));
        vm.expectRevert(ITeeOracleFeedStore.WrongFeedId.selector);
        feedStore.submitFeedUpdates(_one(feedUpdate, signature));
    }

    function testSubmitFeedUpdatesOneSignatureRevertNoEndpointsPublished() public {
        _mockLatestEndpointsHash(bytes32(0));
        vm.expectRevert(ITeeOracleFeedStore.NoEndpointsPublished.selector);
        feedStore.submitFeedUpdates(_one(_makeFeedUpdate(1, 0, _now() - 1), signature));
    }

    function testSubmitFeedUpdatesOneSignatureRevertStaleEndpoints() public {
        _mockLatestEndpointsHash(keccak256("newer endpoints"));
        vm.expectRevert(ITeeOracleFeedStore.StaleEndpoints.selector);
        feedStore.submitFeedUpdates(_one(_makeFeedUpdate(1, 0, _now() - 1), signature));
    }

    function testSubmitFeedUpdatesOneSignatureRevertNoAdminsPublished() public {
        _mockLatestAdminsHash(bytes32(0));
        vm.expectRevert(ITeeOracleFeedStore.NoAdminsPublished.selector);
        feedStore.submitFeedUpdates(_one(_makeFeedUpdate(1, 0, _now() - 1), signature));
    }

    function testSubmitFeedUpdatesOneSignatureRevertStaleAdmins() public {
        _mockLatestAdminsHash(keccak256("newer admins"));
        vm.expectRevert(ITeeOracleFeedStore.StaleAdmins.selector);
        feedStore.submitFeedUpdates(_one(_makeFeedUpdate(1, 0, _now() - 1), signature));
    }

    function testSubmitFeedUpdatesOneSignatureCommitmentsAreFeedLevelNotPerMachine() public {
        // the check does not depend on WHICH machine signed: every machine of the extension
        // is held to the feed's single latest published generation
        address otherTeeId = makeAddr("otherTeeId");
        _mockVerifyTeeSignature(otherTeeId);
        _submit(1, 0, _now() - 2);
        (int256 value,,) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(value, 1);

        _mockLatestEndpointsHash(keccak256("newer endpoints"));
        _mockVerifyTeeSignature(teeId);
        vm.expectRevert(ITeeOracleFeedStore.StaleEndpoints.selector);
        feedStore.submitFeedUpdates(_one(_makeFeedUpdate(2, 0, _now() - 1), signature));
        _mockVerifyTeeSignature(otherTeeId);
        vm.expectRevert(ITeeOracleFeedStore.StaleEndpoints.selector);
        feedStore.submitFeedUpdates(_one(_makeFeedUpdate(2, 0, _now() - 1), signature));
    }

    function testSubmitFeedUpdatesOneSignatureUndispatchedPublicationInvalidatesMachine() public {
        // Regression guard for the feed-level commitment model (the inverse of the per-machine
        // model it replaced): the store reads the FEED-level `latestEndpointsHash`, never a
        // per-machine record. So a publication that has not reached this machine yet
        // invalidates it immediately - which is the point: a configuration change takes effect
        // at once, instead of machine by machine, and no machine keeps serving a superseded
        // configuration just because its instruction is still in flight.
        _submit(111, 0, _now() - 3);
        (int256 value,,) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(value, 111);

        // governance publishes a new generation; nothing was pushed to this machine, and it is
        // already rejected while it keeps running the old one
        bytes32 newerHash = keccak256("endpoints v2");
        _mockLatestEndpointsHash(newerHash);
        vm.expectRevert(ITeeOracleFeedStore.StaleEndpoints.selector);
        feedStore.submitFeedUpdates(_one(_makeFeedUpdate(222, 0, _now() - 2), signature));

        // it is accepted again only once it actually runs the new configuration
        ITeeOracleFeedStore.FeedUpdate memory feedUpdate = _makeFeedUpdate(333, 0, _now() - 1);
        feedUpdate.endpointsHash = newerHash;
        feedStore.submitFeedUpdates(_one(feedUpdate, signature));
        (value,,) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(value, 333);
    }

    function testSubmitFeedUpdatesOneSignatureUndispatchedAdminsPublicationInvalidatesMachine() public {
        // same for the admin sets - the two kinds are checked on identical terms
        _submit(111, 0, _now() - 3);
        bytes32 newerHash = keccak256("admins v2");
        _mockLatestAdminsHash(newerHash);
        vm.expectRevert(ITeeOracleFeedStore.StaleAdmins.selector);
        feedStore.submitFeedUpdates(_one(_makeFeedUpdate(222, 0, _now() - 2), signature));

        ITeeOracleFeedStore.FeedUpdate memory feedUpdate = _makeFeedUpdate(333, 0, _now() - 1);
        feedUpdate.adminsHash = newerHash;
        feedStore.submitFeedUpdates(_one(feedUpdate, signature));
        (int256 value,,) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(value, 333);
    }

    function testSubmitFeedUpdatesOneSignatureRevertNotNewerSameTimestamp() public {
        _submit(1, 0, _now() - 1);
        vm.expectRevert(ITeeOracleFeedStore.NotNewer.selector);
        feedStore.submitFeedUpdates(_one(_makeFeedUpdate(2, 0, _now() - 1), signature));
    }

    function testSubmitFeedUpdatesOneSignatureRevertNotNewerOlderTimestamp() public {
        _submit(1, 0, _now() - 1);
        vm.expectRevert(ITeeOracleFeedStore.NotNewer.selector);
        feedStore.submitFeedUpdates(_one(_makeFeedUpdate(2, 0, _now() - 2), signature));
    }

    function testSubmitFeedUpdatesOneSignatureAcceptsFreshestObservation() public {
        // the freshest acceptable observation is one second old - the observation event
        // and the update submission cannot land in the same block
        _submit(1, 0, _now() - 1);
        assertEq(feedStore.observedAt(), _now() - 1);
    }

    function testSubmitFeedUpdatesOneSignatureRevertAtChainTime() public {
        // an observation stamped at (or after) chain time is invalid input — the round
        // trip through the machine cannot complete within one block, and a future-dated
        // update would freeze the feed irreversibly (observedAt ratchet)
        vm.expectRevert(ITeeOracleFeedStore.TooFarAhead.selector);
        feedStore.submitFeedUpdates(_one(_makeFeedUpdate(1, 0, _now()), signature));
    }

    function testSubmitFeedUpdatesOneSignatureRevertTooFarAhead() public {
        vm.expectRevert(ITeeOracleFeedStore.TooFarAhead.selector);
        feedStore.submitFeedUpdates(_one(_makeFeedUpdate(1, 0, _now() + 1), signature));
    }

    function testSubmitFeedUpdatesOneSignatureAcceptsOldObservation() public {
        // any increasing timestamp is acceptable - staleness is the consumer's check
        _submit(1, 0, _now() - 30 days);
        assertEq(feedStore.observedAt(), _now() - 30 days);
    }

    function testSubmitFeedUpdatesOneSignatureHeldBackUpdateStaysSubmittable() public {
        // a withheld update stays submittable; consumers see its true (old) timestamp
        ITeeOracleFeedStore.FeedUpdate memory feedUpdate = _makeFeedUpdate(1, 0, _now() - 1);
        uint64 signedAt = _now() - 1;
        vm.warp(_now() + 30 days);
        feedStore.submitFeedUpdates(_one(feedUpdate, signature));
        (,, uint64 timestamp) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(timestamp, signedAt);
    }

    function testSubmitFeedUpdatesOneSignatureVerifierRevertBubbles() public {
        // the verifier's typed errors bubble up unchanged
        vm.mockCallRevert(
            fdc2Verification,
            abi.encodeWithSelector(VERIFY_TEE_SIGNATURE_SELECTOR),
            abi.encodeWithSignature("InvalidTeeMachineExtensionId()")
        );
        vm.expectRevert(abi.encodeWithSignature("InvalidTeeMachineExtensionId()"));
        feedStore.submitFeedUpdates(_one(_makeFeedUpdate(1, 0, _now() - 1), signature));
    }

    function testSubmitFeedUpdatesOneSignatureRejectedUpdateStoresNothing() public {
        _submit(1, 0, _now() - 1);
        vm.expectRevert(ITeeOracleFeedStore.NotNewer.selector);
        feedStore.submitFeedUpdates(_one(_makeFeedUpdate(999, 9, _now() - 1), signature));
        (int256 value, int8 decimals,) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(value, 1);
        assertEq(decimals, 0);
    }

    // -------------------------------------------------------------------------
    // submitFeedUpdates - threshold and aggregation
    // -------------------------------------------------------------------------

    function testSubmitFeedUpdatesSingleElement() public {
        // a threshold-1 store accepts a one-element array - the only way to submit one signature
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch, address[] memory batchTeeIds) =
            _makeBatch(_values(123456), _scales(4), _now() - 1);
        vm.expectEmit();
        emit ITeeOracleFeedStore.FeedUpdated(123456, 4, _now() - 1, batchTeeIds);
        feedStore.submitFeedUpdates(batch);
        (int256 value, int8 decimals, uint64 timestamp) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(value, 123456);
        assertEq(decimals, 4);
        assertEq(timestamp, _now() - 1);
    }

    function testSubmitFeedUpdatesTwoOfThree() public {
        _setPolicy(2, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE);
        // three contributions within 1% of the median: the middle one is stored
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch, address[] memory batchTeeIds) =
            _makeBatch(_values(100000, 100050, 100100), _scales(4), _now() - 1);
        vm.expectEmit();
        emit ITeeOracleFeedStore.FeedUpdated(100050, 4, _now() - 1, batchTeeIds);
        feedStore.submitFeedUpdates(batch);
        (int256 value, int8 decimals,) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(value, 100050, "median of an odd count is the middle value");
        assertEq(decimals, 4, "one common scale is stored unchanged");
        assertEq(batchTeeIds.length, 3);
    }

    function testSubmitFeedUpdatesThreeOfFive() public {
        _setPolicy(3, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch,) =
            _makeBatch(_values(100100, 100000, 100050, 100025, 100075), _scales(4), _now() - 1);
        // deliberately unsorted input - the store sorts a memory copy
        feedStore.submitFeedUpdates(batch);
        (int256 value,,) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(value, 100050);
    }

    function testSubmitFeedUpdatesAcceptsMoreThanTheThreshold() public {
        _setPolicy(2, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch,) =
            _makeBatch(_values(100000, 100050, 100075, 100100), _scales(4), _now() - 1);
        feedStore.submitFeedUpdates(batch);
        (int256 value,,) = feedStore.getCurrentFeed{value: FEE}();
        // even count: the int256 average of the two middle values, truncated toward zero
        assertEq(value, 100062);
    }

    function testSubmitFeedUpdatesMedianEvenCountTruncatesTowardZero() public {
        _setPolicy(2, 10000, MAX_SPREAD_ABSOLUTE);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch,) =
            _makeBatch(_values(1, 2), _scales(0), _now() - 1);
        feedStore.submitFeedUpdates(batch);
        (int256 value,,) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(value, 1, "(1 + 2) / 2 truncates toward zero");
    }

    function testSubmitFeedUpdatesMedianEvenCountNegativeTruncatesTowardZero() public {
        _setPolicy(2, 10000, MAX_SPREAD_ABSOLUTE);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch,) =
            _makeBatch(_values(-1, -2), _scales(0), _now() - 1);
        feedStore.submitFeedUpdates(batch);
        (int256 value,,) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(value, -1, "(-1 + -2) / 2 truncates toward zero, not down");
    }

    function testSubmitFeedUpdatesIdenticalDecimalsAreExact() public {
        // one common scale: no normalisation, no re-scaling loop, the median is stored as is
        _setPolicy(3, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch,) =
            _makeBatch(_values(2147483600, 2147483610, 2147483620), _scales(8), _now() - 1);
        feedStore.submitFeedUpdates(batch);
        (int256 value, int8 decimals,) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(value, 2147483610, "exactly the middle contribution, at int32's edge");
        assertEq(decimals, 8);
    }

    function testSubmitFeedUpdatesMixedDecimalsNormaliseToTheFinest() public {
        // three machines reporting the SAME quantity 1.0 at three different scales
        _setPolicy(3, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch,) =
            _makeBatch(_values(100, 1000, 10000), _scales(2, 3, 4), _now() - 1);
        feedStore.submitFeedUpdates(batch);
        (int256 value, int8 decimals,) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(value, 10000, "normalised to the batch's finest scale");
        assertEq(decimals, 4);
        // the range is zero, so the deviation bound passes even at a 1% allowance
    }

    function testSubmitFeedUpdatesMixedDecimalsCoarsestFirst() public {
        // same, with the finest scale arriving first - the batch order must not matter
        _setPolicy(3, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch,) =
            _makeBatch(_values(10000, 1000, 100), _scales(4, 3, 2), _now() - 1);
        feedStore.submitFeedUpdates(batch);
        (int256 value, int8 decimals,) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(value, 10000);
        assertEq(decimals, 4);
    }

    function testSubmitFeedUpdatesNegativeDecimals() public {
        // negative scales: 5e3 reported as (5, -3) and as (500, -1); only the DIFFERENCE of the
        // two scales drives the normalisation, so the sign is irrelevant
        _setPolicy(2, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch,) =
            _makeBatch(_values(5, 500), _scales(-3, -1), _now() - 1);
        feedStore.submitFeedUpdates(batch);
        (int256 value, int8 decimals,) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(value, 500, "5 * 10^2 == 500, both at scale -1");
        assertEq(decimals, -1);
    }

    function testSubmitFeedUpdatesNegativeValuesAndNegativeDecimals() public {
        _setPolicy(3, 10000, MAX_SPREAD_ABSOLUTE);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch,) =
            _makeBatch(_values(-5000, -50, -499), _scales(-1, -3, -1), _now() - 1);
        feedStore.submitFeedUpdates(batch);
        (int256 value, int8 decimals,) = feedStore.getCurrentFeed{value: FEE}();
        // normalised to -1: -5000, -5000, -499*... -> sorted: -5000, -5000, -499
        assertEq(value, -5000);
        assertEq(decimals, -1);
    }

    function testSubmitFeedUpdatesRoundsHalfAwayFromZero() public {
        // the median at the batch's finest scale is 2_500_000_005 (scale 1), which does not fit
        // int32; dividing once yields exactly x.5, and rounding is AWAY from zero
        _setPolicy(2, 10000, MAX_SPREAD_ABSOLUTE);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch,) =
            _makeBatch(_values(2000000000, 300000001), _scales(1, 0), _now() - 1);
        feedStore.submitFeedUpdates(batch);
        (int256 value, int8 decimals,) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(value, 250000001, "250000000.5 rounds away from zero");
        assertEq(decimals, 0, "one decade coarser than the normalisation scale");
    }

    function testSubmitFeedUpdatesRoundsHalfAwayFromZeroNegative() public {
        // the mirror image: -2_500_000_005 must round to -250000001, not -250000000
        _setPolicy(2, 10000, MAX_SPREAD_ABSOLUTE);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch,) =
            _makeBatch(_values(-2000000000, -300000001), _scales(1, 0), _now() - 1);
        feedStore.submitFeedUpdates(batch);
        (int256 value, int8 decimals,) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(value, -250000001, "-250000000.5 rounds away from zero, symmetrically");
        assertEq(decimals, 0);
    }

    function testSubmitFeedUpdatesSpreadJustInsideTheBound() public {
        // 100 BIPS of a median of 100050 is 1000 (the division floors). At an ODD count the
        // judged spread is HALF the neighbour difference (FAssets' `_calculateMedian`), so 2000
        // apart is exactly 1000 and the inclusive bound accepts it.
        _setPolicy(3, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch,) =
            _makeBatch(_values(100050, 100050, 102050), _scales(4), _now() - 1);
        feedStore.submitFeedUpdates(batch);
        (int256 value,,) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(value, 100050);
    }

    function testSubmitFeedUpdatesRevertSpreadTooBigJustOutsideTheBound() public {
        // two units wider than the previous test: the neighbours are 2002 apart, so the judged
        // (halved) spread is 1001 against an allowance of 1000 - the median is not well
        // determined and nothing is published. The error still reports the RAW neighbours.
        _setPolicy(3, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch,) =
            _makeBatch(_values(100050, 100050, 102052), _scales(4), _now() - 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeOracleFeedStore.SpreadTooBig.selector, int256(100050), int256(102052),
                int256(100050), int8(4)
            )
        );
        feedStore.submitFeedUpdates(batch);
    }

    /// For UNIFORM adjacent spacing the judged spread must not depend on the batch's parity —
    /// that is what FAssets' halving of the odd case buys, and dropping it would make a uniformly
    /// spaced odd batch twice as hard to publish as an even one at the same spacing. It is only
    /// that: for an asymmetric sample the two parities are genuinely different statistics (an
    /// average of two gaps versus one raw gap).
    function testSubmitFeedUpdatesSpreadIsParityNeutral() public {
        _setPolicy(2, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE);
        // Four machines around 100050 with gaps 1000/2000/1000: the even batch's judged spread is
        // the single CENTRAL gap, 2000; 100 BIPS of the median is 1000, so it is refused. The data
        // is chosen so that this central gap equals the odd batch's average gap below.
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory even,) =
            _makeBatch(_values(98050, 99050, 101050, 102050), _scales(4), _now() - 1);
        vm.expectRevert();
        feedStore.submitFeedUpdates(even);

        // The odd batch IS uniformly spaced at 2000, so its two gaps span 4000 and the halving
        // brings it back to 2000 - the SAME judged number as the even batch above, refused for the
        // same reason rather than twice as harshly.
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory odd,) =
            _makeBatch(_values(98050, 100050, 102050), _scales(4), _now() - 1);
        vm.expectRevert();
        feedStore.submitFeedUpdates(odd);

        // ... and a spacing that IS inside the bound lands at both parities
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory evenOk,) =
            _makeBatch(_values(99050, 99550, 100550, 101050), _scales(4), _now() - 2);
        feedStore.submitFeedUpdates(evenOk);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory oddOk,) =
            _makeBatch(_values(99050, 100050, 101050), _scales(4), _now() - 1);
        feedStore.submitFeedUpdates(oddOk);
        (int256 value,,) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(value, 100050);
    }

    function testSubmitFeedUpdatesRevertSpreadTooBigZeroMedian() public {
        // a zero median leaves only the absolute allowance, which defaults to zero. That does NOT
        // mean unanimity is required in general - values outside the bracketing pair escape the
        // rejection spread (not the flagging; none exist at N = 3 anyway), and at an odd count
        // the bracketing pair may differ by one unit - but here the bracketing pair IS (-5, 5),
        // whose halved gap is 5, so the batch cannot pass
        _setPolicy(3, MAX_SPREAD_BIPS, 0);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch,) =
            _makeBatch(_values(-5, 0, 5), _scales(0), _now() - 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeOracleFeedStore.SpreadTooBig.selector, int256(-5), int256(5), int256(0),
                int8(0)
            )
        );
        feedStore.submitFeedUpdates(batch);
    }

    function testSubmitFeedUpdatesZeroMedianPassesWithAbsoluteAllowance() public {
        // the absolute term is what makes a feed that crosses zero updatable at all: `value` is
        // signed, and a purely relative bound around a zero median permits no disagreement.
        // 1e9 at the fixed 10^-8 reference scale is a real tolerance of 10.0, which at this
        // batch's `decimals` of 0 is 10 units
        _setPolicy(3, MAX_SPREAD_BIPS, 1_000_000_000);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch,) =
            _makeBatch(_values(-5, 0, 5), _scales(0), _now() - 1);
        feedStore.submitFeedUpdates(batch);
        (int256 value,,) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(value, 0);
    }

    function testSubmitFeedUpdatesNegativeMedianUsesAbsoluteValueAsTheBase() public {
        // the bound is taken from abs(median), so a negative feed is judged on the same numbers as
        // its positive mirror: allowed = 1% of abs(-100050) = 1000, and the raw bracketing gap of
        // 1000 halves to a judged spread of 500 - comfortably inside it
        _setPolicy(3, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch,) =
            _makeBatch(_values(-101050, -100050, -100050), _scales(4), _now() - 1);
        feedStore.submitFeedUpdates(batch);
        (int256 value,,) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(value, -100050, "the bound is abs(median), so a negative feed behaves the same");
    }

    function testSubmitFeedUpdatesRevertSpreadTooBigNegativeMedian() public {
        _setPolicy(3, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch,) =
            _makeBatch(_values(-102052, -100050, -100050), _scales(4), _now() - 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeOracleFeedStore.SpreadTooBig.selector, int256(-102052), int256(-100050),
                int256(-100050), int8(4)
            )
        );
        feedStore.submitFeedUpdates(batch);
    }

    function testSubmitFeedUpdatesEmitsEveryContributorInSubmissionOrder() public {
        _setPolicy(3, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch, address[] memory batchTeeIds) =
            _makeBatch(_values(100100, 100000, 100050), _scales(4), _now() - 1);
        vm.expectEmit();
        emit ITeeOracleFeedStore.FeedUpdated(100050, 4, _now() - 1, batchTeeIds);
        feedStore.submitFeedUpdates(batch);
    }

    function testSubmitFeedUpdatesVerifiesEveryElementAgainstItsOwnDigest() public {
        _setPolicy(2, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch,) =
            _makeBatch(_values(100000, 100050), _scales(4), _now() - 1);
        for (uint256 i = 0; i < batch.length; i++) {
            vm.expectCall(
                fdc2Verification,
                abi.encodeWithSelector(
                    VERIFY_TEE_SIGNATURE_SELECTOR,
                    EXTENSION_ID,
                    batch[i].signature,
                    SignedPayload.messageHash(
                        TEE_ORACLE_FEED, keccak256(abi.encode(batch[i].feedUpdate)))
                )
            );
        }
        feedStore.submitFeedUpdates(batch);
    }

    function testSubmitFeedUpdatesRevertNotEnoughSignatures() public {
        _setPolicy(3, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch,) =
            _makeBatch(_values(100000, 100050), _scales(4), _now() - 1);
        vm.expectRevert(ITeeOracleFeedStore.NotEnoughSignatures.selector);
        feedStore.submitFeedUpdates(batch);
    }

    function testSubmitFeedUpdatesRevertNotEnoughSignaturesEmptyBatch() public {
        ITeeOracleFeedStore.SignedFeedUpdate[] memory batch =
            new ITeeOracleFeedStore.SignedFeedUpdate[](0);
        vm.expectRevert(ITeeOracleFeedStore.NotEnoughSignatures.selector);
        feedStore.submitFeedUpdates(batch);
    }

    function testSubmitFeedUpdatesRevertNotEnoughSignaturesAboveThresholdOne() public {
        // a one-element array stops being enough the moment the threshold is raised - there is
        // no single-update entry point that could bypass it
        _setPolicy(2, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE);
        vm.expectRevert(ITeeOracleFeedStore.NotEnoughSignatures.selector);
        feedStore.submitFeedUpdates(_one(_makeFeedUpdate(1, 0, _now() - 1), signature));
    }

    function testSubmitFeedUpdatesRevertTooManySignatures() public {
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch,) =
            _makeUniformBatch(MAX_SIGNATURES + 1, 100000, 4, _now() - 1);
        vm.expectRevert(ITeeOracleFeedStore.TooManySignatures.selector);
        feedStore.submitFeedUpdates(batch);
    }

    function testSubmitFeedUpdatesAcceptsExactlyMaxSignatures() public {
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch,) =
            _makeUniformBatch(MAX_SIGNATURES, 100000, 4, _now() - 1);
        feedStore.submitFeedUpdates(batch);
        (int256 value,,) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(value, 100000);
    }

    function testSubmitFeedUpdatesRevertDuplicateTeeId() public {
        _setPolicy(2, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch, address[] memory batchTeeIds) =
            _makeBatch(_values(100000, 100050), _scales(4), _now() - 1);
        // the second element recovers to the FIRST machine: one machine must not be able to
        // reach the threshold alone
        _mockSignerFor(1, batchTeeIds[0]);
        vm.expectRevert(ITeeOracleFeedStore.DuplicateTeeId.selector);
        feedStore.submitFeedUpdates(batch);
    }

    function testSubmitFeedUpdatesRevertObservedAtMismatch() public {
        _setPolicy(2, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch,) =
            _makeBatch(_values(100000, 100050), _scales(4), _now() - 1);
        batch[1].feedUpdate.observedAt = _now() - 2;
        vm.expectRevert(ITeeOracleFeedStore.ObservedAtMismatch.selector);
        feedStore.submitFeedUpdates(batch);
    }

    function testSubmitFeedUpdatesRevertDecimalsSpreadTooBig() public {
        _setPolicy(2, 10000, MAX_SPREAD_ABSOLUTE);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch,) =
            _makeBatch(_values(1, 1000000000), _scales(0, 9), _now() - 1);
        vm.expectRevert(ITeeOracleFeedStore.DecimalsSpreadTooBig.selector);
        feedStore.submitFeedUpdates(batch);
    }

    function testSubmitFeedUpdatesAcceptsDecimalsSpreadAtTheBound() public {
        // exactly eight decades apart, and reporting the same quantity, so the range is zero
        _setPolicy(2, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch,) =
            _makeBatch(_values(1, 100000000), _scales(0, 8), _now() - 1);
        feedStore.submitFeedUpdates(batch);
        (int256 value, int8 decimals,) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(value, 100000000);
        assertEq(decimals, 8);
    }

    function testSubmitFeedUpdatesRevertStaleEndpointsOnOneElement() public {
        // a single lagging machine inside an otherwise valid batch fails the WHOLE batch - the
        // configuration check is feed-level, so a batch mixing generations cannot land
        _setPolicy(3, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch,) =
            _makeBatch(_values(100000, 100050, 100100), _scales(4), _now() - 1);
        batch[2].feedUpdate.endpointsHash = keccak256("previous endpoints");
        vm.expectRevert(ITeeOracleFeedStore.StaleEndpoints.selector);
        feedStore.submitFeedUpdates(batch);
    }

    function testSubmitFeedUpdatesRevertStaleAdminsOnOneElement() public {
        _setPolicy(3, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch,) =
            _makeBatch(_values(100000, 100050, 100100), _scales(4), _now() - 1);
        batch[1].feedUpdate.adminsHash = keccak256("previous admins");
        vm.expectRevert(ITeeOracleFeedStore.StaleAdmins.selector);
        feedStore.submitFeedUpdates(batch);
    }

    function testSubmitFeedUpdatesRevertWrongFeedIdOnOneElement() public {
        _setPolicy(2, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch,) =
            _makeBatch(_values(100000, 100050), _scales(4), _now() - 1);
        batch[1].feedUpdate.feedId = bytes21(bytes.concat(bytes1(uint8(0x21)), bytes("OTHER")));
        vm.expectRevert(ITeeOracleFeedStore.WrongFeedId.selector);
        feedStore.submitFeedUpdates(batch);
    }

    function testSubmitFeedUpdatesRevertNonProductionSigner() public {
        // one element signed by a machine that is not PRODUCTION: the verifier's typed error
        // bubbles and takes the whole batch with it
        _setPolicy(2, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch,) =
            _makeBatch(_values(100000, 100050), _scales(4), _now() - 1);
        vm.mockCallRevert(
            fdc2Verification,
            abi.encodeWithSelector(
                VERIFY_TEE_SIGNATURE_SELECTOR, EXTENSION_ID, batch[1].signature),
            abi.encodeWithSignature("TeeMachineNotAvailable()")
        );
        vm.expectRevert(abi.encodeWithSignature("TeeMachineNotAvailable()"));
        feedStore.submitFeedUpdates(batch);
    }

    function testSubmitFeedUpdatesRevertNotNewer() public {
        _setPolicy(2, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch,) =
            _makeBatch(_values(100000, 100050), _scales(4), _now() - 2);
        feedStore.submitFeedUpdates(batch);
        // the common observedAt is checked ONCE against the ratchet, exactly as a single
        // submission is
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory again,) =
            _makeBatch(_values(100000, 100050), _scales(4), _now() - 2);
        vm.expectRevert(ITeeOracleFeedStore.NotNewer.selector);
        feedStore.submitFeedUpdates(again);
    }

    function testSubmitFeedUpdatesRevertTooFarAhead() public {
        _setPolicy(2, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch,) =
            _makeBatch(_values(100000, 100050), _scales(4), _now());
        vm.expectRevert(ITeeOracleFeedStore.TooFarAhead.selector);
        feedStore.submitFeedUpdates(batch);
    }

    function testSubmitFeedUpdatesRejectedBatchStoresNothing() public {
        _setPolicy(2, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory good,) =
            _makeBatch(_values(100000, 100050), _scales(4), _now() - 2);
        feedStore.submitFeedUpdates(good);

        // failing on the LAST element - nothing of the batch may survive
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory bad,) =
            _makeBatch(_values(200000, 200050), _scales(4), _now() - 1);
        bad[1].feedUpdate.adminsHash = keccak256("previous admins");
        vm.expectRevert(ITeeOracleFeedStore.StaleAdmins.selector);
        feedStore.submitFeedUpdates(bad);

        (int256 value,, uint64 timestamp) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(value, 100025, "the earlier batch's median is untouched");
        assertEq(timestamp, _now() - 2);
    }

    // -------------------------------------------------------------------------
    // outliers: flagged, never rejected
    // -------------------------------------------------------------------------

    function testSubmitFeedUpdatesTailOutlierPublishesAndIsFlagged() public {
        // N = 5 with one machine 100% off: the median's neighbours are 50 apart, so the median is
        // well determined and the feed updates - and the diverging machine is named in
        // FeedOutliers instead of taking the batch down with it. Rejecting here would only teach
        // submitters to filter the batch off chain, losing the divergence information entirely.
        _setPolicy(3, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch, address[] memory batchTeeIds) =
            _makeBatch(_values(100000, 100025, 100050, 100075, 200000), _scales(4), _now() - 1);

        address[] memory expectedTeeIds = new address[](1);
        expectedTeeIds[0] = batchTeeIds[4];
        int256[] memory expectedDeviations = new int256[](1);
        expectedDeviations[0] = 200000 - 100050;
        vm.expectEmit();
        emit ITeeOracleFeedStore.FeedUpdated(100050, 4, _now() - 1, batchTeeIds);
        vm.expectEmit();
        emit ITeeOracleFeedStore.FeedOutliers(
            _now() - 1, 100050, 4, expectedTeeIds, expectedDeviations);
        feedStore.submitFeedUpdates(batch);

        (int256 value,,) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(value, 100050, "the feed still updates - the outlier did not move the median");
    }

    function testSubmitFeedUpdatesFlagsOutliersOnBothSides() public {
        _setPolicy(3, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch, address[] memory batchTeeIds) =
            _makeBatch(_values(10000, 100025, 100050, 100075, 200000), _scales(4), _now() - 1);

        // named in SUBMISSION order, with signed deviations, so the log shows the direction
        address[] memory expectedTeeIds = new address[](2);
        expectedTeeIds[0] = batchTeeIds[0];
        expectedTeeIds[1] = batchTeeIds[4];
        int256[] memory expectedDeviations = new int256[](2);
        expectedDeviations[0] = 10000 - 100050;
        expectedDeviations[1] = 200000 - 100050;
        vm.expectEmit();
        emit ITeeOracleFeedStore.FeedOutliers(
            _now() - 1, 100050, 4, expectedTeeIds, expectedDeviations);
        feedStore.submitFeedUpdates(batch);
    }

    function testSubmitFeedUpdatesNegativeMedianFlagsSymmetrically() public {
        _setPolicy(3, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch, address[] memory batchTeeIds) =
            _makeBatch(_values(-100000, -100025, -100050, -100075, -200000), _scales(4), _now() - 1);

        address[] memory expectedTeeIds = new address[](1);
        expectedTeeIds[0] = batchTeeIds[4];
        int256[] memory expectedDeviations = new int256[](1);
        expectedDeviations[0] = -200000 - (-100050);
        vm.expectEmit();
        emit ITeeOracleFeedStore.FeedOutliers(
            _now() - 1, -100050, 4, expectedTeeIds, expectedDeviations);
        feedStore.submitFeedUpdates(batch);
        (int256 value,,) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(value, -100050);
    }

    function testSubmitFeedUpdatesEmitsNoOutlierEventWhenAllWithinTheBound() public {
        _setPolicy(3, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch,) =
            _makeBatch(_values(100000, 100025, 100050, 100075, 100100), _scales(4), _now() - 1);
        vm.recordLogs();
        feedStore.submitFeedUpdates(batch);
        assertEq(_countOutlierLogs(vm.getRecordedLogs()), 0, "no outliers, no event");
    }

    function testSubmitFeedUpdatesNearZeroMedianDoesNotFlagEveryone() public {
        // without the absolute term a median of zero makes the allowance zero, so every
        // contribution that is not exactly the median would be flagged. 1e9 at the 10^-8
        // reference scale is a tolerance of 10.0, i.e. 10 units at this batch's `decimals` of 0
        _setPolicy(3, MAX_SPREAD_BIPS, 1_000_000_000);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch,) =
            _makeBatch(_values(-5, 0, 5), _scales(0), _now() - 1);
        vm.recordLogs();
        feedStore.submitFeedUpdates(batch);
        assertEq(_countOutlierLogs(vm.getRecordedLogs()), 0);
        (int256 value,,) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(value, 0);
    }

    function testSubmitFeedUpdatesNeighbourAndRangeChecksCoincideAtThree() public {
        // the very batch whose tail is only FLAGGED at N = 5 is REJECTED at N = 3. The median is
        // unchanged (sorted[1] either way) - what changes is that at N = 3 the tail IS a
        // bracketing value, so it enters the judged spread instead of being excluded from it
        _setPolicy(3, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch,) =
            _makeBatch(_values(100025, 100050, 200000), _scales(4), _now() - 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeOracleFeedStore.SpreadTooBig.selector, int256(100025), int256(200000),
                int256(100050), int8(4)
            )
        );
        feedStore.submitFeedUpdates(batch);
    }

    // -------------------------------------------------------------------------
    // the absolute term's fixed reference scale
    // -------------------------------------------------------------------------

    function testSubmitFeedUpdatesAbsoluteBoundKeepsItsRealMeaningAcrossScales() public {
        // maxSpreadAbsolute is denominated at 10^-8 whatever the batch's own scale: 1e9 is a real
        // tolerance of 10.0, which is 10 units at `decimals` 0 and 1000 units at `decimals` 2.
        // With maxSpreadBIPS at 0 the bound is purely absolute, so the two batches below are
        // judged against exactly the same real tolerance.
        _setPolicy(3, 0, 1_000_000_000);

        // decimals 0: neighbours 20 apart are a judged (halved) spread of exactly 10 - accepted
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory atZero,) =
            _makeBatch(_values(0, 5, 20), _scales(0), _now() - 3);
        feedStore.submitFeedUpdates(atZero);
        (int256 value, int8 decimals,) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(value, 5);
        assertEq(decimals, 0);

        // decimals 2: the SAME real spread (10.0) is accepted, which is 1000 units there
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory atTwo,) =
            _makeBatch(_values(0, 500, 2000), _scales(2), _now() - 2);
        feedStore.submitFeedUpdates(atTwo);
        (value, decimals,) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(value, 500);
        assertEq(decimals, 2);

        // and one judged unit past it is refused at both scales
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory tooWideAtZero,) =
            _makeBatch(_values(0, 5, 22), _scales(0), _now() - 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeOracleFeedStore.SpreadTooBig.selector, int256(0), int256(22), int256(5),
                int8(0)
            )
        );
        feedStore.submitFeedUpdates(tooWideAtZero);

        (ITeeOracleFeedStore.SignedFeedUpdate[] memory tooWideAtTwo,) =
            _makeBatch(_values(0, 500, 2002), _scales(2), _now() - 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeOracleFeedStore.SpreadTooBig.selector, int256(0), int256(2002), int256(500),
                int8(2)
            )
        );
        feedStore.submitFeedUpdates(tooWideAtTwo);
    }

    function testSubmitFeedUpdatesAbsoluteBoundClampsAtBothEnds() public {
        // scaling the bound up: the widest possible deviation is ~4.3e17, so a bound above that
        // permits everything - and the clamp is what keeps 10**k inside uint256 when the
        // reference scale and the batch's scale are dozens of decades apart
        _setPolicy(2, 0, type(uint64).max);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory wideOpen,) =
            _makeBatch(_values(-2000000000, 2000000000), _scales(8), _now() - 2);
        feedStore.submitFeedUpdates(wideOpen);
        (int256 value,,) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(value, 0, "(-2e9 + 2e9) / 2");

        // scaling it down: at `decimals` -120 the bound is far below one unit of the batch's
        // scale, so it rounds to nothing. With the bound at zero the bracketing pair must agree
        // (exactly at an even count, within one unit at an odd one); values outside the bracket
        // stay out of the rejection spread, though not out of the flagging
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory scaledAway,) =
            _makeBatch(_values(100, 101), _scales(-120), _now() - 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeOracleFeedStore.SpreadTooBig.selector, int256(100), int256(101), int256(100),
                int8(-120)
            )
        );
        feedStore.submitFeedUpdates(scaledAway);
    }

    // -------------------------------------------------------------------------
    // the returned aggregation (an eth_call on submitFeedUpdates is the dry run)
    // -------------------------------------------------------------------------

    function testSubmitFeedUpdatesReturnsTheAggregation() public {
        // there is no separate preview view: a caller rehearses a batch by eth_call-ing this very
        // function, which returns the aggregation it acted on and enforces every rule
        _setPolicy(3, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch,) =
            _makeBatch(_values(100000, 100050, 100100), _scales(4), _now() - 1);
        ITeeOracleFeedStore.FeedAggregation memory aggregation = feedStore.submitFeedUpdates(batch);
        assertEq(aggregation.median, 100050);
        assertEq(aggregation.minValue, 100000);
        assertEq(aggregation.maxValue, 100100);
        assertEq(aggregation.decimals, 4);
        assertEq(aggregation.allowedDeviation, 1000, "100 BIPS of abs(median), floored");
        assertEq(aggregation.outlierTeeIds.length, 0);
        assertEq(aggregation.outlierDeviations.length, 0);
        // and the numbers returned are the numbers stored
        (int256 stored, int8 storedDecimals,) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(stored, aggregation.median);
        assertEq(storedDecimals, aggregation.decimals);
    }

    function testSubmitFeedUpdatesReturnsTheOutlierSetTheEventReports() public {
        // the returned outlier arrays ARE the arrays FeedOutliers was emitted from
        _setPolicy(3, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch, address[] memory batchTeeIds) =
            _makeBatch(_values(100000, 100025, 100050, 100075, 200000), _scales(4), _now() - 1);

        address[] memory expectedTeeIds = new address[](1);
        expectedTeeIds[0] = batchTeeIds[4];
        int256[] memory expectedDeviations = new int256[](1);
        expectedDeviations[0] = 200000 - 100050;
        vm.expectEmit();
        emit ITeeOracleFeedStore.FeedOutliers(
            _now() - 1, 100050, 4, expectedTeeIds, expectedDeviations);
        ITeeOracleFeedStore.FeedAggregation memory aggregation = feedStore.submitFeedUpdates(batch);
        assertEq(aggregation.outlierTeeIds, expectedTeeIds);
        assertEq(aggregation.outlierDeviations, expectedDeviations);
        assertEq(aggregation.median, 100050);
        assertEq(aggregation.decimals, 4);
    }

    function testSubmitFeedUpdatesSingleElementReturnsTheAggregation() public {
        // a one-element batch returns the same shape: median is the submitted value, the range is
        // a point, and there can be no outlier
        ITeeOracleFeedStore.FeedAggregation memory aggregation =
            feedStore.submitFeedUpdates(_one(_makeFeedUpdate(123456, 4, _now() - 1), signature));
        assertEq(aggregation.median, 123456);
        assertEq(aggregation.minValue, 123456);
        assertEq(aggregation.maxValue, 123456);
        assertEq(aggregation.decimals, 4);
        assertEq(aggregation.outlierTeeIds.length, 0);
    }

    function testSubmitFeedUpdatesFailingBatchIsDiagnosableFromTheRevert() public {
        // a failing dry run is as informative as a preview would have been: SpreadTooBig carries
        // both bracketing values and the median, at the batch's normalisation scale
        _setPolicy(3, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch,) =
            _makeBatch(_values(100050, 100050, 102052), _scales(4), _now() - 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeOracleFeedStore.SpreadTooBig.selector, int256(100050), int256(102052),
                int256(100050), int8(4))
        );
        feedStore.submitFeedUpdates(batch);
        // and nothing was stored, so a rehearsal cannot be mistaken for a landed submission
        assertEq(feedStore.observedAt(), 0);
    }

    function testSubmitFeedUpdatesDryRunRejectsAnUnverifiableBatch() public {
        // the deliberate difference from a view-only preview: the dry run runs the REAL rules, so
        // a batch that could not land does not report a median either - it reverts where the real
        // submission would, which is the property that makes an eth_call trustworthy
        _setPolicy(2, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch,) =
            _makeBatch(_values(100000, 100050), _scales(4), _now() - 1);
        vm.mockCallRevert(
            fdc2Verification,
            abi.encodeWithSelector(
                VERIFY_TEE_SIGNATURE_SELECTOR, EXTENSION_ID, batch[1].signature),
            abi.encodeWithSignature("TeeNotFound()")
        );
        vm.expectRevert(abi.encodeWithSignature("TeeNotFound()"));
        feedStore.submitFeedUpdates(batch);
        assertEq(feedStore.observedAt(), 0);
    }

    // -------------------------------------------------------------------------
    // gas
    // -------------------------------------------------------------------------

    function testSubmitFeedUpdatesGas() public {
        // reported in docs/tee-oracle-threshold-feed-plan-2026-08-31.md; measured as the
        // gasleft() delta around the call, so it excludes the 21k transaction base and the
        // calldata cost. NOTE: the verifier is MOCKED here, so the per-signature figure covers
        // the store's own work only - no ecrecover and no machine lookup in the diamond. The
        // integration suite measures the same call against the real verifier.
        _measureSubmitGas(1); // warm-up: first-write and cold-callee costs out of the way
        emit log_named_uint("gas N=1", _measureSubmitGas(1));
        emit log_named_uint("gas N=3", _measureSubmitGas(3));
        emit log_named_uint("gas N=5", _measureSubmitGas(5));
        emit log_named_uint("gas N=9", _measureSubmitGas(9));
        emit log_named_uint("gas N=32", _measureSubmitGas(32));
    }

    // -------------------------------------------------------------------------
    // setSubmissionPolicy
    // -------------------------------------------------------------------------

    function testSetSubmissionPolicy() public {
        vm.expectEmit();
        emit ITeeOracleFeedStore.SubmissionPolicySet(3, 250, 7);
        vm.prank(governance);
        feedStore.setSubmissionPolicy(_policy(3, 250, 7));
        assertEq(feedStore.requiredSignatures(), 3);
        assertEq(feedStore.maxSpreadBIPS(), 250);
        assertEq(feedStore.maxSpreadAbsolute(), 7);
    }

    function testSetSubmissionPolicyAcceptsTheBounds() public {
        vm.prank(governance);
        feedStore.setSubmissionPolicy(_policy(uint8(MAX_SIGNATURES), 10000, type(uint64).max));
        assertEq(feedStore.requiredSignatures(), uint8(MAX_SIGNATURES));
        assertEq(feedStore.maxSpreadBIPS(), 10000);
        assertEq(feedStore.maxSpreadAbsolute(), type(uint64).max);
    }

    function testSetSubmissionPolicyRevertZeroThreshold() public {
        vm.expectRevert(ITeeOracleFeedStore.InvalidSubmissionPolicy.selector);
        vm.prank(governance);
        feedStore.setSubmissionPolicy(_policy(0, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE));
    }

    function testSetSubmissionPolicyRevertThresholdAboveCap() public {
        vm.expectRevert(ITeeOracleFeedStore.InvalidSubmissionPolicy.selector);
        vm.prank(governance);
        feedStore.setSubmissionPolicy(_policy(uint8(MAX_SIGNATURES + 1), MAX_SPREAD_BIPS, 0));
    }

    function testSetSubmissionPolicyRevertBipsAboveHundredPercent() public {
        vm.expectRevert(ITeeOracleFeedStore.InvalidSubmissionPolicy.selector);
        vm.prank(governance);
        feedStore.setSubmissionPolicy(_policy(1, 10001, 0));
    }

    function testSetSubmissionPolicyRevertOnlyGovernance() public {
        vm.expectRevert(IFlareGovernance.OnlyGovernance.selector);
        feedStore.setSubmissionPolicy(_policy(2, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE));
    }

    function testSetSubmissionPolicyTimelocked() public {
        _switchToProduction();
        bytes memory call =
            abi.encodeCall(feedStore.setSubmissionPolicy, (_policy(3, 250, 7)));
        vm.prank(productionGovernance);
        (bool ok,) = address(feedStore).call(call);
        assertTrue(ok);
        assertEq(feedStore.requiredSignatures(), REQUIRED_SIGNATURES, "must not execute at once");

        vm.warp(vm.getBlockTimestamp() + TIMELOCK);
        vm.prank(executor);
        IFlareGovernance(address(feedStore)).executeGovernanceCall(call);
        assertEq(feedStore.requiredSignatures(), 3);
        assertEq(feedStore.maxSpreadBIPS(), 250);
        assertEq(feedStore.maxSpreadAbsolute(), 7);
    }

    function testInitializeRevertInvalidSubmissionPolicy() public {
        vm.expectRevert(ITeeOracleFeedStore.InvalidSubmissionPolicy.selector);
        new TeeOracleFeedStoreProxy(
            governanceSettings,
            governance,
            addressUpdater,
            ITeeOracleInstructionsSender(instructionsSender),
            FEED_ID,
            feeDestination,
            _policy(0, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE),
            address(feedStoreImpl)
        );
    }

    // -------------------------------------------------------------------------
    // getCurrentFeed / calculateFee
    // -------------------------------------------------------------------------

    function testGetCurrentFeedRevertNoValuePublished() public {
        vm.expectRevert(ITeeOracleFeedStore.NoValuePublished.selector);
        feedStore.getCurrentFeed{value: FEE}();
    }

    function testGetCurrentFeedRevertFeeTooLow() public {
        _submit(1, 0, _now() - 1);
        vm.expectRevert(ITeeOracleFeedStore.FeeTooLow.selector);
        feedStore.getCurrentFeed{value: FEE - 1}();
    }

    function testGetCurrentFeedForwardsEntireValue() public {
        _submit(1, 0, _now() - 1);
        feedStore.getCurrentFeed{value: FEE + 7}();
        // no refund of overpayment - nothing accumulates on the store
        assertEq(feeDestination.balance, FEE + 7);
        assertEq(address(feedStore).balance, 0);
    }

    function testGetCurrentFeedZeroFeeZeroValue() public {
        _mockCalculateFee(0);
        _submit(1, 0, _now() - 1);
        (int256 value,,) = feedStore.getCurrentFeed();
        assertEq(value, 1);
        assertEq(feeDestination.balance, 0);
    }

    function testGetCurrentFeedRevertFeeTransferFailed() public {
        _submit(1, 0, _now() - 1);
        address rejecting = address(new RejectingReceiver());
        vm.prank(governance);
        feedStore.setFeeDestination(rejecting);
        vm.expectRevert(ITeeOracleFeedStore.FeeTransferFailed.selector);
        feedStore.getCurrentFeed{value: FEE}();
    }

    function testCalculateFee() public {
        bytes21[] memory feedIds = new bytes21[](1);
        feedIds[0] = FEED_ID;
        vm.expectCall(
            feeCalculator,
            abi.encodeWithSelector(IFeeCalculator.calculateFeeByIds.selector, feedIds)
        );
        assertEq(feedStore.calculateFee(), FEE);
    }

    // -------------------------------------------------------------------------
    // governance setters
    // -------------------------------------------------------------------------

    function testSetFeeDestination() public {
        address newDestination = makeAddr("newDestination");
        vm.expectEmit();
        emit ITeeOracleFeedStore.FeeDestinationSet(newDestination);
        vm.prank(governance);
        feedStore.setFeeDestination(newDestination);
        assertEq(feedStore.feeDestination(), newDestination);
    }

    function testSetFeeDestinationRevertZeroAddress() public {
        vm.expectRevert(ITeeOracleFeedStore.ZeroAddress.selector);
        vm.prank(governance);
        feedStore.setFeeDestination(address(0));
    }

    function testSetFeeDestinationRevertOnlyGovernance() public {
        vm.expectRevert(IFlareGovernance.OnlyGovernance.selector);
        feedStore.setFeeDestination(makeAddr("newDestination"));
    }

    // -------------------------------------------------------------------------
    // governance timelock (production mode)
    // -------------------------------------------------------------------------

    function testSetFeeDestinationTimelocked() public {
        _switchToProduction();

        address newDestination = makeAddr("newDestination");
        bytes memory call = abi.encodeCall(feedStore.setFeeDestination, (newDestination));
        vm.prank(productionGovernance);
        (bool ok,) = address(feedStore).call(call);
        assertTrue(ok);
        assertEq(feedStore.feeDestination(), feeDestination, "must not execute immediately");

        vm.warp(vm.getBlockTimestamp() + TIMELOCK);
        vm.prank(executor);
        IFlareGovernance(address(feedStore)).executeGovernanceCall(call);
        assertEq(feedStore.feeDestination(), newDestination);
    }

    // -------------------------------------------------------------------------
    // upgrade / address updater
    // -------------------------------------------------------------------------

    function testUpgradeToAndCallPreservesState() public {
        _submit(77, 2, _now() - 1);
        TeeOracleFeedStore newImpl = new TeeOracleFeedStore();
        vm.prank(governance);
        feedStore.upgradeToAndCall(address(newImpl), "");
        assertEq(feedStore.implementation(), address(newImpl));
        assertEq(feedStore.extensionId(), EXTENSION_ID);
        (int256 value, int8 decimals,) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(value, 77);
        assertEq(decimals, 2);
    }

    function testUpgradeToAndCallRevertOnlyGovernance() public {
        TeeOracleFeedStore newImpl = new TeeOracleFeedStore();
        vm.expectRevert(IFlareGovernance.OnlyGovernance.selector);
        feedStore.upgradeToAndCall(address(newImpl), "");
    }

    function testUpdateContractAddressesRevertOnlyAddressUpdater() public {
        bytes32[] memory contractNameHashes = new bytes32[](0);
        address[] memory contractAddresses = new address[](0);
        vm.expectRevert("only address updater");
        feedStore.updateContractAddresses(contractNameHashes, contractAddresses);
    }


    /// The policy and the feed state live in different slots; neither write may disturb the other.
    function testSetSubmissionPolicyDoesNotDisturbTheFeedState() public {
        _submit(100000, 4, _now() - 1);
        _setPolicy(1, 250, 7);
        (int256 value_, int8 decimals_, uint64 timestamp_) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(value_, 100000);
        assertEq(decimals_, 4);
        assertEq(timestamp_, _now() - 1);
        assertEq(feedStore.maxSpreadAbsolute(), 7);
    }
    // -------------------------------------------------------------------------
    // getCurrentFeed orders its state reads before the fee transfer
    // -------------------------------------------------------------------------

    /// The unpublished-feed check must be reached WITHOUT first handing control (and the value)
    /// to `feeDestination`: a reverting destination must not be able to mask `NoValuePublished`,
    /// and the destination must not be called at all on a read that cannot succeed.
    function testGetCurrentFeedRevertsNoValuePublishedWithoutCallingFeeDestination() public {
        // a destination that rejects every plain transfer
        address rejecting = address(new RejectingReceiver());
        vm.prank(governance);
        feedStore.setFeeDestination(rejecting);
        // still NoValuePublished, not FeeTransferFailed: the state read happens first
        vm.expectRevert(ITeeOracleFeedStore.NoValuePublished.selector);
        feedStore.getCurrentFeed{value: FEE}();
    }

    /// And the fee still reaches the destination on the successful path.
    function testGetCurrentFeedForwardsTheFeeAfterReadingState() public {
        _submit(100000, 4, _now() - 1);
        uint256 before = feeDestination.balance;
        (int256 value_, int8 decimals_, uint64 timestamp_) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(value_, 100000);
        assertEq(decimals_, 4);
        assertEq(timestamp_, _now() - 1);
        assertEq(feeDestination.balance - before, FEE);
    }

    // -------------------------------------------------------------------------
    // coverage the audit named as missing
    // -------------------------------------------------------------------------

    /// `_absoluteAllowance`'s scale-UP branch (0 < shift <= 20) was never entered by any test:
    /// every existing case sits at decimals <= 8. At decimals 10 the setting is multiplied by
    /// 10**2, so S = 5 means 500 normalised units - and the batch either side of that bound
    /// decides acceptance.
    function testSubmitFeedUpdatesAbsoluteAllowanceScalesUpAboveTheReferenceScale() public {
        _setPolicy(2, 0, 5);
        // spread 500 == the rescaled bound, accepted (the comparison is inclusive)
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory ok, ) =
            _makeBatch(_values(100000, 100500), _scales(10), _now() - 2);
        feedStore.submitFeedUpdates(ok);
        // spread 501 is one unit over
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory tooWide, ) =
            _makeBatch(_values(100000, 100501), _scales(10), _now() - 1);
        vm.expectRevert();
        feedStore.submitFeedUpdates(tooWide);
    }

    /// The `shift > 20` clamp: at decimals 29 the rescaled term reaches UNBOUNDED_SPREAD, which
    /// exceeds every reachable deviation - so the spread check is disabled entirely. This is the
    /// documented operator trap, pinned here so it cannot change silently.
    function testSubmitFeedUpdatesAbsoluteAllowanceClampAboveTwentyDisablesTheBound() public {
        _setPolicy(2, 0, 1);
        // normalisation scale 29 puts `shift` at 21, past the clamp, so the rescaled term is
        // UNBOUNDED_SPREAD; the batch's own scales differ by the maximum 8 decades, so the two
        // normalised values are eight orders of magnitude apart and the median downscales back
        // into the readable window
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch, ) =
            _makeBatch(_values(2000000000, 2000000000), _scales(29, 21), _now() - 1);
        // a spread of ~2e17 normalised units, accepted anyway - the clamp disabled the bound
        ITeeOracleFeedStore.FeedAggregation memory aggregation = feedStore.submitFeedUpdates(batch);
        assertEq(aggregation.decimals, 29);
        assertEq(aggregation.maxValue - aggregation.minValue, 199999998000000000);
        assertEq(aggregation.allowedDeviation, 1e19);
        assertEq(feedStore.observedAt(), _now() - 1);
    }

    /// `_toStoredScale` running more than one iteration, and the documented divergence between
    /// the batch's normalisation `decimals` and the coarser scale the value is STORED at.
    function testSubmitFeedUpdatesDownscalesRepeatedlyAndReportsBothScales() public {
        _setPolicy(2, 10000, type(uint64).max);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch, ) =
            _makeBatch(_values(2000000000, 2100000000), _scales(8, 0), _now() - 1);
        ITeeOracleFeedStore.FeedAggregation memory aggregation = feedStore.submitFeedUpdates(batch);
        // normalisation scale is the batch's largest decimals
        assertEq(aggregation.decimals, 8);
        // median of [2e9, 2.1e17] at scale 8 is 1.05e17, which needs EIGHT divisions by ten to
        // fit int32 - so the stored scale is 8 - 8 = 0 and the stored value is the rounded median
        (int256 value_, int8 storedDecimals, ) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(aggregation.median, 105000001000000000);
        assertEq(storedDecimals, 0);
        assertEq(value_, 1050000010);
    }

    /// The negative mirror of the multi-decade rounding case: the one-shot division must round
    /// half AWAY from zero symmetrically, so the stored value is -505000000 and not -505000001.
    function testSubmitFeedUpdatesRoundsOnceAcrossSeveralDecadesNegative() public {
        _setPolicy(2, 10000, type(uint64).max);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch,) =
            _makeBatch(_values(-1000000000, -1000000098), _scales(0, 2), _now() - 1);
        ITeeOracleFeedStore.FeedAggregation memory a = feedStore.submitFeedUpdates(batch);
        assertEq(a.median, -50500000049);
        assertEq(a.decimals, 2);
        (int256 value_, int8 storedDecimals,) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(storedDecimals, 0);
        assertEq(value_, -505000000, "per-decade rounding would give -505000001");
    }

    /// The odd-count spread is the MEAN of the two flanking gaps, so an ASYMMETRIC sample is
    /// judged on that mean while flagging fires on the largest single deviation. At the boundary
    /// this makes rejection strictly looser than flagging: the batch below is accepted with the
    /// divergent machine merely named, and only two units more span tips it over.
    function testSubmitFeedUpdatesOddSpreadIsTheMeanOfTheFlankingGaps() public {
        _setPolicy(3, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE);
        // median 100050, allowed = 1% = 1000; one neighbour sits ON the median, so the raw span
        // is 2000 and the judged spread is exactly 1000 - accepted, and the far machine flagged
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory atBound, address[] memory ids) =
            _makeBatch(_values(100050, 100050, 102050), _scales(4), _now() - 2);
        ITeeOracleFeedStore.FeedAggregation memory a = feedStore.submitFeedUpdates(atBound);
        assertEq(a.median, 100050);
        assertEq(a.spread, 1000);
        assertEq(a.allowedDeviation, 1000);
        assertEq(a.outlierTeeIds.length, 1, "rejection is looser than flagging at an odd count");
        assertEq(a.outlierTeeIds[0], ids[2]);

        // ONE unit wider is still accepted - the odd spread FLOORS, so a raw gap of 2A+1 judges
        // as A. This is the real boundary, and it only exists because of the halving.
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory atOddBound,) =
            _makeBatch(_values(100050, 100050, 102051), _scales(4), _now() - 1);
        ITeeOracleFeedStore.FeedAggregation memory b = feedStore.submitFeedUpdates(atOddBound);
        assertEq(b.spread, 1000, "raw gap 2A+1 floors to A");
        assertEq(b.allowedDeviation, 1000);

        // two units wider: judged spread 1001 > 1000
        vm.warp(vm.getBlockTimestamp() + 2);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory past,) =
            _makeBatch(_values(100050, 100050, 102052), _scales(4), _now() - 1);
        vm.expectRevert();
        feedStore.submitFeedUpdates(past);
    }

    /// A zero bound gives true unanimity only at N <= 2. The caller chooses the batch, so a
    /// threshold of 2 does not stop it submitting a third signature that changes the answer.
    function testSubmitFeedUpdatesZeroBoundUnanimityOnlyHoldsAtTwo() public {
        _setPolicy(2, 0, 0);
        // the pair disagrees by one unit: refused
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory pair,) =
            _makeBatch(_values(0, 1), _scales(0), _now() - 2);
        vm.expectRevert();
        feedStore.submitFeedUpdates(pair);

        // the same disagreement inside a caller-selected triple publishes and merely flags it
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory triple, address[] memory ids) =
            _makeBatch(_values(0, 0, 1), _scales(0), _now() - 1);
        ITeeOracleFeedStore.FeedAggregation memory a = feedStore.submitFeedUpdates(triple);
        assertEq(a.median, 0);
        assertEq(a.spread, 0);
        assertEq(a.outlierTeeIds.length, 1);
        assertEq(a.outlierTeeIds[0], ids[2]);
    }

    /// `FeedAggregation.spread` must report the value the rejection test actually compared, since
    /// a dry-run caller cannot re-derive it from the other fields.
    function testSubmitFeedUpdatesReturnsTheComparedSpread() public {
        _setPolicy(2, 10000, 0);
        // even count: the gap between the two averaged values, not halved
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory even,) =
            _makeBatch(_values(100, 200), _scales(0), _now() - 3);
        assertEq(feedStore.submitFeedUpdates(even).spread, 100);
        // odd count: half the flanking span
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory odd,) =
            _makeBatch(_values(100, 150, 200), _scales(0), _now() - 2);
        assertEq(feedStore.submitFeedUpdates(odd).spread, 50);
        // single element: zero (the threshold has to allow a one-element batch)
        _setPolicy(1, 10000, 0);
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory one,) =
            _makeBatch(_values(100), _scales(0), _now() - 1);
        assertEq(feedStore.submitFeedUpdates(one).spread, 0);
    }

    /// Rounding must be applied ONCE, to the original median, at whichever scale is finally used.
    /// Rounding per decade instead compounds: this median crosses two decades and the two modes
    /// disagree by one unit in the last place.
    function testSubmitFeedUpdatesRoundsOnceAcrossSeveralDecades() public {
        _setPolicy(2, 10000, type(uint64).max);
        // 1000000000 @ decimals 0 normalises to 1e11; 1000000098 @ decimals 2 stays as it is;
        // the median is 50_500_000_049 at decimals 2, which needs two decades to fit int32.
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch,) =
            _makeBatch(_values(1000000000, 1000000098), _scales(0, 2), _now() - 1);
        ITeeOracleFeedStore.FeedAggregation memory aggregation = feedStore.submitFeedUpdates(batch);
        assertEq(aggregation.median, 50500000049);
        assertEq(aggregation.decimals, 2);
        (int256 value_, int8 storedDecimals,) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(storedDecimals, 0);
        // 50_500_000_049 / 100 rounds to 505_000_000; rounding per decade would give 505_000_001
        assertEq(value_, 505000000);
    }

    /// `_isOutlier` is strict `>`, so a contribution exactly AT the bound is not flagged. The
    /// existing suite exercised the boundary but never asserted which side it falls on.
    function testSubmitFeedUpdatesDeviationExactlyAtTheBoundIsNotFlagged() public {
        _setPolicy(3, 0, 0);
        // bound is 0, all five identical: no outlier, and deviation 0 is not > 0
        vm.recordLogs();
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch, ) =
            _makeBatch(_values(100, 100, 100, 100, 100), _scales(4), _now() - 1);
        feedStore.submitFeedUpdates(batch);
        assertEq(_countOutlierLogs(vm.getRecordedLogs()), 0);
    }

    /// An EVEN count combined with a flagged tail - the even bracketing branch and `_emitOutliers`
    /// were never exercised together.
    function testSubmitFeedUpdatesEvenCountFlagsATailOutlier() public {
        _setPolicy(4, 100, 0);
        vm.recordLogs();
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch, address[] memory batchTeeIds) =
            _makeBatch(_values(100000, 100000, 100000, 200000), _scales(4), _now() - 1);
        ITeeOracleFeedStore.FeedAggregation memory aggregation = feedStore.submitFeedUpdates(batch);
        // even count: the two averaged values bracket the median, so the tail cannot reject it
        assertEq(aggregation.median, 100000);
        assertEq(aggregation.outlierTeeIds.length, 1);
        assertEq(aggregation.outlierTeeIds[0], batchTeeIds[3]);
        assertEq(aggregation.outlierDeviations[0], 100000);
        assertEq(_countOutlierLogs(vm.getRecordedLogs()), 1);
    }

    /// The insertion sort was only ever handed already-sorted (all-equal) input at large N.
    /// A strictly DESCENDING batch is its worst case and must still produce the right median.
    function testSubmitFeedUpdatesSortsADescendingBatchOfThirtyTwo() public {
        _setPolicy(uint8(MAX_SIGNATURES), 10000, type(uint64).max);
        int32[] memory descending = new int32[](MAX_SIGNATURES);
        for (uint256 i = 0; i < MAX_SIGNATURES; i++) {
            descending[i] = int32(uint32(MAX_SIGNATURES - i)) * 1000;
        }
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch, ) =
            _makeBatch(descending, _scales(4), _now() - 1);
        ITeeOracleFeedStore.FeedAggregation memory aggregation = feedStore.submitFeedUpdates(batch);
        // 32 values 1000..32000: the two central ones are 16000 and 17000
        assertEq(aggregation.median, 16500);
        assertEq(aggregation.minValue, 1000);
        assertEq(aggregation.maxValue, 32000);
    }

    // -------------------------------------------------------------------------
    // initialization
    // -------------------------------------------------------------------------

    function testInitializeRevertZeroAddressUpdater() public {
        TeeOracleFeedStore impl = new TeeOracleFeedStore();
        vm.expectRevert(ITeeOracleFeedStore.ZeroAddress.selector);
        new TeeOracleFeedStoreProxy(
            governanceSettings,
            governance,
            address(0),
            ITeeOracleInstructionsSender(instructionsSender),
            FEED_ID,
            feeDestination,
            _policy(REQUIRED_SIGNATURES, MAX_SPREAD_BIPS, MAX_SPREAD_ABSOLUTE),
            address(impl)
        );
    }

    // -------------------------------------------------------------------------
    // helpers
    // -------------------------------------------------------------------------

    function _now() private view returns (uint64) {
        return uint64(vm.getBlockTimestamp());
    }

    /// A one-element submission batch. `submitFeedUpdates` is the only submission entry point,
    /// so a single signature is submitted as an array of one - which is also exactly the
    /// threshold-1 case these tests exercise.
    function _one(
        ITeeOracleFeedStore.FeedUpdate memory _feedUpdate,
        Signature memory _signature
    )
        private pure
        returns (ITeeOracleFeedStore.SignedFeedUpdate[] memory _batch)
    {
        _batch = new ITeeOracleFeedStore.SignedFeedUpdate[](1);
        _batch[0] = ITeeOracleFeedStore.SignedFeedUpdate(_feedUpdate, _signature);
    }

    function _makeFeedUpdate(
        int32 _value,
        int8 _decimals,
        uint64 _observedAt
    )
        private pure
        returns (ITeeOracleFeedStore.FeedUpdate memory)
    {
        return ITeeOracleFeedStore.FeedUpdate({
            extensionId: EXTENSION_ID,
            feedId: FEED_ID,
            value: _value,
            decimals: _decimals,
            observedAt: _observedAt,
            endpointsHash: ENDPOINTS_HASH,
            adminsHash: ADMINS_HASH
        });
    }

    function _submit(int32 _value, int8 _decimals, uint64 _observedAt) private {
        feedStore.submitFeedUpdates(_one(_makeFeedUpdate(_value, _decimals, _observedAt), signature));
    }

    function _mockSenderExtensionId(uint256 _extensionId) private {
        vm.mockCall(
            instructionsSender,
            abi.encodeWithSelector(ITeeOracleInstructionsSender.extensionId.selector),
            abi.encode(_extensionId)
        );
    }

    function _mockVerifyTeeSignature(address _teeId) private {
        vm.mockCall(
            fdc2Verification,
            abi.encodeWithSelector(VERIFY_TEE_SIGNATURE_SELECTOR),
            abi.encode(_teeId)
        );
    }

    function _mockLatestEndpointsHash(bytes32 _hash) private {
        vm.mockCall(
            instructionsSender,
            abi.encodeCall(ITeeOracleInstructionsSender.latestEndpointsHash, (FEED_ID)),
            abi.encode(_hash)
        );
    }

    function _mockLatestAdminsHash(bytes32 _hash) private {
        vm.mockCall(
            instructionsSender,
            abi.encodeCall(ITeeOracleInstructionsSender.latestAdminsHash, (FEED_ID)),
            abi.encode(_hash)
        );
    }

    function _mockCalculateFee(uint256 _fee) private {
        vm.mockCall(
            feeCalculator,
            abi.encodeWithSelector(IFeeCalculator.calculateFeeByIds.selector),
            abi.encode(_fee)
        );
    }

    /// A one-element contributor list, the shape `FeedUpdated` carries for a single submission.
    function _teeIds(address _teeId)
        private pure
        returns (address[] memory _list)
    {
        _list = new address[](1);
        _list[0] = _teeId;
    }

    /// A distinct signature per batch index, so every element can be mocked to its own signer.
    function _signatureFor(uint256 _index)
        private pure
        returns (Signature memory)
    {
        return Signature(27, bytes32(uint256(0x100 + _index)), bytes32(uint256(0x200 + _index)));
    }

    /// Mocks the verifier for ONE element's signature. The mock's calldata is longer than
    /// setUp's blanket selector mock, so it wins for that element - which is how a batch
    /// resolves to N distinct PRODUCTION machines.
    function _mockSignerFor(uint256 _index, address _teeIdForIndex) private {
        vm.mockCall(
            fdc2Verification,
            abi.encodeWithSelector(
                VERIFY_TEE_SIGNATURE_SELECTOR, EXTENSION_ID, _signatureFor(_index)),
            abi.encode(_teeIdForIndex)
        );
    }

    /// Builds a batch with one element per value, each signed by its own (mocked) machine and
    /// all carrying the same `_observedAt`. `_decimalsPerValue` is either one scale for the whole
    /// batch or one per element.
    function _makeBatch(
        int32[] memory _valuesPerElement,
        int8[] memory _decimalsPerValue,
        uint64 _batchObservedAt
    )
        private
        returns (
            ITeeOracleFeedStore.SignedFeedUpdate[] memory _batch,
            address[] memory _batchTeeIds
        )
    {
        _batchTeeIds = _mockBatchSigners(_valuesPerElement.length);
        _batch = new ITeeOracleFeedStore.SignedFeedUpdate[](_valuesPerElement.length);
        for (uint256 i = 0; i < _valuesPerElement.length; i++) {
            _batch[i] = ITeeOracleFeedStore.SignedFeedUpdate({
                feedUpdate: _makeFeedUpdate(
                    _valuesPerElement[i],
                    _decimalsPerValue.length == 1 ? _decimalsPerValue[0] : _decimalsPerValue[i],
                    _batchObservedAt
                ),
                signature: _signatureFor(i)
            });
        }
    }

    /// One mocked PRODUCTION machine per batch index, in index order.
    function _mockBatchSigners(uint256 _count)
        private
        returns (address[] memory _list)
    {
        _list = new address[](_count);
        for (uint256 i = 0; i < _count; i++) {
            _list[i] = makeAddr(string.concat("teeMachine", vm.toString(i)));
            _mockSignerFor(i, _list[i]);
        }
    }

    /// `_count` elements, all reporting the same value at the same scale (range 0, so the
    /// deviation bound is irrelevant) - for the count bounds and the gas measurements.
    function _makeUniformBatch(
        uint256 _count,
        int32 _value,
        int8 _decimals,
        uint64 _batchObservedAt
    )
        private
        returns (
            ITeeOracleFeedStore.SignedFeedUpdate[] memory _batch,
            address[] memory _batchTeeIds
        )
    {
        int32[] memory valuesPerElement = new int32[](_count);
        for (uint256 i = 0; i < _count; i++) {
            valuesPerElement[i] = _value;
        }
        return _makeBatch(valuesPerElement, _scales(_decimals), _batchObservedAt);
    }

    function _measureSubmitGas(uint256 _count)
        private
        returns (uint256)
    {
        (ITeeOracleFeedStore.SignedFeedUpdate[] memory batch,) =
            _makeUniformBatch(_count, 100000, 4, _now() - 1);
        // keeps the ratchet satisfied across the measurements in one test
        vm.warp(vm.getBlockTimestamp() + 1);
        uint256 gasBefore = gasleft();
        feedStore.submitFeedUpdates(batch);
        return gasBefore - gasleft();
    }

    function _setPolicy(
        uint8 _requiredSignatures,
        uint16 _maxSpreadBIPS,
        uint64 _maxSpreadAbsolute
    )
        private
    {
        vm.prank(governance);
        feedStore.setSubmissionPolicy(
            _policy(_requiredSignatures, _maxSpreadBIPS, _maxSpreadAbsolute));
    }

    /// How many `FeedOutliers` events the recorded logs contain.
    function _countOutlierLogs(Vm.Log[] memory _logs)
        private pure
        returns (uint256 _count)
    {
        for (uint256 i = 0; i < _logs.length; i++) {
            if (_logs[i].topics[0] == ITeeOracleFeedStore.FeedOutliers.selector) {
                _count++;
            }
        }
    }

    function _policy(
        uint8 _requiredSignatures,
        uint16 _maxSpreadBIPS,
        uint64 _maxSpreadAbsolute
    )
        private pure
        returns (ITeeOracleFeedStore.SubmissionPolicy memory)
    {
        return ITeeOracleFeedStore.SubmissionPolicy({
            requiredSignatures: _requiredSignatures,
            maxSpreadBIPS: _maxSpreadBIPS,
            maxSpreadAbsolute: _maxSpreadAbsolute
        });
    }

    function _values(int32 _a)
        private pure
        returns (int32[] memory _list)
    {
        _list = new int32[](1);
        _list[0] = _a;
    }

    function _values(int32 _a, int32 _b)
        private pure
        returns (int32[] memory _list)
    {
        _list = new int32[](2);
        _list[0] = _a;
        _list[1] = _b;
    }

    function _values(int32 _a, int32 _b, int32 _c)
        private pure
        returns (int32[] memory _list)
    {
        _list = new int32[](3);
        _list[0] = _a;
        _list[1] = _b;
        _list[2] = _c;
    }

    function _values(int32 _a, int32 _b, int32 _c, int32 _d)
        private pure
        returns (int32[] memory _list)
    {
        _list = new int32[](4);
        _list[0] = _a;
        _list[1] = _b;
        _list[2] = _c;
        _list[3] = _d;
    }

    function _values(int32 _a, int32 _b, int32 _c, int32 _d, int32 _e)
        private pure
        returns (int32[] memory _list)
    {
        _list = new int32[](5);
        _list[0] = _a;
        _list[1] = _b;
        _list[2] = _c;
        _list[3] = _d;
        _list[4] = _e;
    }

    function _scales(int8 _a)
        private pure
        returns (int8[] memory _list)
    {
        _list = new int8[](1);
        _list[0] = _a;
    }

    function _scales(int8 _a, int8 _b)
        private pure
        returns (int8[] memory _list)
    {
        _list = new int8[](2);
        _list[0] = _a;
        _list[1] = _b;
    }

    function _scales(int8 _a, int8 _b, int8 _c)
        private pure
        returns (int8[] memory _list)
    {
        _list = new int8[](3);
        _list[0] = _a;
        _list[1] = _b;
        _list[2] = _c;
    }

    function _switchToProduction() private {
        vm.prank(governance);
        feedStore.switchToProductionMode();
        vm.mockCall(
            address(governanceSettings),
            abi.encodeWithSelector(IGovernanceSettings.getGovernanceAddress.selector),
            abi.encode(productionGovernance)
        );
        vm.mockCall(
            address(governanceSettings),
            abi.encodeWithSelector(IGovernanceSettings.getTimelock.selector),
            abi.encode(TIMELOCK)
        );
        vm.mockCall(
            address(governanceSettings),
            abi.encodeWithSelector(IGovernanceSettings.isExecutor.selector, executor),
            abi.encode(true)
        );
    }
}
