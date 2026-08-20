// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
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
    uint64 private constant MAX_AGE = 1 hours;
    uint64 private constant MAX_FUTURE_SKEW = 2 minutes;
    uint256 private constant FEE = 5;
    bytes32 private constant ENDPOINTS_HASH = keccak256("endpoints");
    bytes32 private constant ADMINS_HASH = keccak256("admins");
    uint256 private constant TIMELOCK = 3600;

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
            MAX_AGE,
            MAX_FUTURE_SKEW,
            feeDestination,
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
        _mockExpectedEndpointsHash(teeId, ENDPOINTS_HASH);
        _mockExpectedAdminsHash(teeId, ADMINS_HASH);
        _mockCalculateFee(FEE);
    }

    // -------------------------------------------------------------------------
    // initialization
    // -------------------------------------------------------------------------

    function testInitialState() public {
        assertEq(feedStore.extensionId(), EXTENSION_ID);
        assertEq(address(feedStore.instructionsSender()), instructionsSender);
        assertEq(feedStore.feedId(), FEED_ID);
        assertEq(feedStore.maxAge(), MAX_AGE);
        assertEq(feedStore.maxFutureSkew(), MAX_FUTURE_SKEW);
        assertEq(feedStore.feeDestination(), feeDestination);
        assertEq(feedStore.observedAt(), 0);
        assertEq(feedStore.governance(), governance);
        assertEq(feedStore.implementation(), address(feedStoreImpl));
    }

    function testInitializeEmitsEvents() public {
        vm.expectEmit();
        emit ITeeOracleFeedStore.FeedStoreInitialised(instructionsSender, EXTENSION_ID, FEED_ID);
        vm.expectEmit();
        emit ITeeOracleFeedStore.AcceptanceWindowSet(MAX_AGE, MAX_FUTURE_SKEW);
        vm.expectEmit();
        emit ITeeOracleFeedStore.FeeDestinationSet(feeDestination);
        new TeeOracleFeedStoreProxy(
            governanceSettings,
            governance,
            addressUpdater,
            ITeeOracleInstructionsSender(instructionsSender),
            FEED_ID,
            MAX_AGE,
            MAX_FUTURE_SKEW,
            feeDestination,
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
            MAX_AGE,
            MAX_FUTURE_SKEW,
            feeDestination,
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
            MAX_AGE,
            MAX_FUTURE_SKEW,
            feeDestination,
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
            MAX_AGE,
            MAX_FUTURE_SKEW,
            address(0),
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
            MAX_AGE,
            MAX_FUTURE_SKEW,
            feeDestination,
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
            MAX_AGE,
            MAX_FUTURE_SKEW,
            feeDestination
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
            MAX_AGE,
            MAX_FUTURE_SKEW,
            feeDestination
        );
    }

    // -------------------------------------------------------------------------
    // submitFeedUpdate
    // -------------------------------------------------------------------------

    function testSubmitFeedUpdate() public {
        ITeeOracleFeedStore.FeedUpdate memory feedUpdate = _makeFeedUpdate(123456, 4, _now());

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
        emit ITeeOracleFeedStore.FeedUpdated(123456, 4, _now(), teeId);
        feedStore.submitFeedUpdate(feedUpdate, signature);

        assertEq(feedStore.observedAt(), _now());
        (int256 value, int8 decimals, uint64 timestamp) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(value, 123456);
        assertEq(decimals, 4);
        assertEq(timestamp, _now());
    }

    function testSubmitFeedUpdateNegativeValue() public {
        _submit(-42, -3, _now());
        (int256 value, int8 decimals,) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(value, -42);
        assertEq(decimals, -3);
    }

    function testSubmitFeedUpdateDynamicDecimals() public {
        _submit(123456, 4, _now());
        _submit(1234567, 5, _now() + 1);
        (int256 value, int8 decimals,) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(value, 1234567);
        assertEq(decimals, 5);
    }

    function testSubmitFeedUpdateRevertWrongExtensionId() public {
        ITeeOracleFeedStore.FeedUpdate memory feedUpdate = _makeFeedUpdate(1, 0, _now());
        feedUpdate.extensionId = EXTENSION_ID + 1;
        vm.expectRevert(ITeeOracleFeedStore.WrongExtensionId.selector);
        feedStore.submitFeedUpdate(feedUpdate, signature);
    }

    function testSubmitFeedUpdateRevertWrongFeedId() public {
        ITeeOracleFeedStore.FeedUpdate memory feedUpdate = _makeFeedUpdate(1, 0, _now());
        feedUpdate.feedId = bytes21(bytes.concat(bytes1(uint8(0x21)), bytes("OTHER")));
        vm.expectRevert(ITeeOracleFeedStore.WrongFeedId.selector);
        feedStore.submitFeedUpdate(feedUpdate, signature);
    }

    function testSubmitFeedUpdateRevertNoEndpointsPublished() public {
        _mockExpectedEndpointsHash(teeId, bytes32(0));
        vm.expectRevert(ITeeOracleFeedStore.NoEndpointsPublished.selector);
        feedStore.submitFeedUpdate(_makeFeedUpdate(1, 0, _now()), signature);
    }

    function testSubmitFeedUpdateRevertStaleEndpoints() public {
        _mockExpectedEndpointsHash(teeId, keccak256("newer endpoints"));
        vm.expectRevert(ITeeOracleFeedStore.StaleEndpoints.selector);
        feedStore.submitFeedUpdate(_makeFeedUpdate(1, 0, _now()), signature);
    }

    function testSubmitFeedUpdateRevertNoAdminsPublished() public {
        _mockExpectedAdminsHash(teeId, bytes32(0));
        vm.expectRevert(ITeeOracleFeedStore.NoAdminsPublished.selector);
        feedStore.submitFeedUpdate(_makeFeedUpdate(1, 0, _now()), signature);
    }

    function testSubmitFeedUpdateRevertStaleAdmins() public {
        _mockExpectedAdminsHash(teeId, keccak256("newer admins"));
        vm.expectRevert(ITeeOracleFeedStore.StaleAdmins.selector);
        feedStore.submitFeedUpdate(_makeFeedUpdate(1, 0, _now()), signature);
    }

    function testSubmitFeedUpdatePerMachineCommitments() public {
        // a machine still running an older configuration is rejected even
        // while another machine's commitments are current
        address otherTeeId = makeAddr("otherTeeId");
        _mockVerifyTeeSignature(otherTeeId);
        _mockExpectedEndpointsHash(otherTeeId, keccak256("newer endpoints"));
        _mockExpectedAdminsHash(otherTeeId, ADMINS_HASH);
        vm.expectRevert(ITeeOracleFeedStore.StaleEndpoints.selector);
        feedStore.submitFeedUpdate(_makeFeedUpdate(1, 0, _now()), signature);
    }

    function testSubmitFeedUpdateRevertNotNewerSameTimestamp() public {
        _submit(1, 0, _now());
        vm.expectRevert(ITeeOracleFeedStore.NotNewer.selector);
        feedStore.submitFeedUpdate(_makeFeedUpdate(2, 0, _now()), signature);
    }

    function testSubmitFeedUpdateRevertNotNewerOlderTimestamp() public {
        _submit(1, 0, _now());
        vm.expectRevert(ITeeOracleFeedStore.NotNewer.selector);
        feedStore.submitFeedUpdate(_makeFeedUpdate(2, 0, _now() - 1), signature);
    }

    function testSubmitFeedUpdateAcceptsAtFutureSkewBoundary() public {
        _submit(1, 0, _now() + MAX_FUTURE_SKEW);
        assertEq(feedStore.observedAt(), _now() + MAX_FUTURE_SKEW);
    }

    function testSubmitFeedUpdateRevertTooFarAhead() public {
        vm.expectRevert(ITeeOracleFeedStore.TooFarAhead.selector);
        feedStore.submitFeedUpdate(_makeFeedUpdate(1, 0, _now() + MAX_FUTURE_SKEW + 1), signature);
    }

    function testSubmitFeedUpdateAcceptsAtMaxAgeBoundary() public {
        _submit(1, 0, _now() - MAX_AGE);
        assertEq(feedStore.observedAt(), _now() - MAX_AGE);
    }

    function testSubmitFeedUpdateRevertTooOld() public {
        vm.expectRevert(ITeeOracleFeedStore.TooOld.selector);
        feedStore.submitFeedUpdate(_makeFeedUpdate(1, 0, _now() - MAX_AGE - 1), signature);
    }

    function testSubmitFeedUpdateHeldBackUpdateExpires() public {
        // an update signed now but withheld past maxAge is no longer submittable
        ITeeOracleFeedStore.FeedUpdate memory feedUpdate = _makeFeedUpdate(1, 0, _now());
        vm.warp(_now() + MAX_AGE + 1);
        vm.expectRevert(ITeeOracleFeedStore.TooOld.selector);
        feedStore.submitFeedUpdate(feedUpdate, signature);
    }

    function testSubmitFeedUpdateVerifierRevertBubbles() public {
        // the verifier's typed errors bubble up unchanged
        vm.mockCallRevert(
            fdc2Verification,
            abi.encodeWithSelector(VERIFY_TEE_SIGNATURE_SELECTOR),
            abi.encodeWithSignature("InvalidTeeMachineExtensionId()")
        );
        vm.expectRevert(abi.encodeWithSignature("InvalidTeeMachineExtensionId()"));
        feedStore.submitFeedUpdate(_makeFeedUpdate(1, 0, _now()), signature);
    }

    function testSubmitFeedUpdateRejectedUpdateStoresNothing() public {
        _submit(1, 0, _now());
        vm.expectRevert(ITeeOracleFeedStore.NotNewer.selector);
        feedStore.submitFeedUpdate(_makeFeedUpdate(999, 9, _now()), signature);
        (int256 value, int8 decimals,) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(value, 1);
        assertEq(decimals, 0);
    }

    // -------------------------------------------------------------------------
    // getCurrentFeed / calculateFee
    // -------------------------------------------------------------------------

    function testGetCurrentFeedRevertNoValuePublished() public {
        vm.expectRevert(ITeeOracleFeedStore.NoValuePublished.selector);
        feedStore.getCurrentFeed{value: FEE}();
    }

    function testGetCurrentFeedRevertFeeTooLow() public {
        _submit(1, 0, _now());
        vm.expectRevert(ITeeOracleFeedStore.FeeTooLow.selector);
        feedStore.getCurrentFeed{value: FEE - 1}();
    }

    function testGetCurrentFeedForwardsEntireValue() public {
        _submit(1, 0, _now());
        feedStore.getCurrentFeed{value: FEE + 7}();
        // no refund of overpayment - nothing accumulates on the store
        assertEq(feeDestination.balance, FEE + 7);
        assertEq(address(feedStore).balance, 0);
    }

    function testGetCurrentFeedZeroFeeZeroValue() public {
        _mockCalculateFee(0);
        _submit(1, 0, _now());
        (int256 value,,) = feedStore.getCurrentFeed();
        assertEq(value, 1);
        assertEq(feeDestination.balance, 0);
    }

    function testGetCurrentFeedRevertFeeTransferFailed() public {
        _submit(1, 0, _now());
        address rejecting = address(new RejectingReceiver());
        vm.prank(governance);
        feedStore.setFeeDestination(rejecting);
        vm.expectRevert(ITeeOracleFeedStore.FeeTransferFailed.selector);
        feedStore.getCurrentFeed{value: FEE}();
    }

    function testGetCurrentFeedClampsFutureTimestamp() public {
        _submit(1, 0, _now() + MAX_FUTURE_SKEW);
        (,, uint64 timestamp) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(timestamp, _now());
        // once chain time catches up, the true timestamp is served
        vm.warp(_now() + MAX_FUTURE_SKEW + 10);
        (,, timestamp) = feedStore.getCurrentFeed{value: FEE}();
        assertEq(timestamp, 1_700_000_000 + MAX_FUTURE_SKEW);
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

    function testSetAcceptanceWindow() public {
        vm.expectEmit();
        emit ITeeOracleFeedStore.AcceptanceWindowSet(2 hours, 5 minutes);
        vm.prank(governance);
        feedStore.setAcceptanceWindow(2 hours, 5 minutes);
        assertEq(feedStore.maxAge(), 2 hours);
        assertEq(feedStore.maxFutureSkew(), 5 minutes);
    }

    function testSetAcceptanceWindowRevertOnlyGovernance() public {
        vm.expectRevert(IFlareGovernance.OnlyGovernance.selector);
        feedStore.setAcceptanceWindow(2 hours, 5 minutes);
    }

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

    function testSetAcceptanceWindowTimelocked() public {
        _switchToProduction();

        bytes memory call = abi.encodeCall(feedStore.setAcceptanceWindow, (2 hours, 5 minutes));
        vm.prank(productionGovernance);
        (bool ok,) = address(feedStore).call(call);
        assertTrue(ok);
        assertEq(feedStore.maxAge(), MAX_AGE, "must not execute immediately");

        vm.warp(vm.getBlockTimestamp() + TIMELOCK);
        vm.prank(executor);
        IFlareGovernance(address(feedStore)).executeGovernanceCall(call);
        assertEq(feedStore.maxAge(), 2 hours);
        assertEq(feedStore.maxFutureSkew(), 5 minutes);
    }

    // -------------------------------------------------------------------------
    // upgrade / address updater
    // -------------------------------------------------------------------------

    function testUpgradeToAndCallPreservesState() public {
        _submit(77, 2, _now());
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

    // -------------------------------------------------------------------------
    // helpers
    // -------------------------------------------------------------------------

    function _now() private view returns (uint64) {
        return uint64(vm.getBlockTimestamp());
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
        feedStore.submitFeedUpdate(_makeFeedUpdate(_value, _decimals, _observedAt), signature);
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

    function _mockExpectedEndpointsHash(address _teeId, bytes32 _hash) private {
        vm.mockCall(
            instructionsSender,
            abi.encodeWithSelector(ITeeOracleInstructionsSender.expectedEndpointsHash.selector, _teeId),
            abi.encode(_hash)
        );
    }

    function _mockExpectedAdminsHash(address _teeId, bytes32 _hash) private {
        vm.mockCall(
            instructionsSender,
            abi.encodeWithSelector(ITeeOracleInstructionsSender.expectedAdminsHash.selector, _teeId),
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
