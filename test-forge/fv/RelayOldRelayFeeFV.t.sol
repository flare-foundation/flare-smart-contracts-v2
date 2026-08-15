// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// solhint-disable func-name-mixedcase

import {Test} from "forge-std/Test.sol";
import {Relay} from "../../contracts/protocol/implementation/Relay.sol";
import {RelayProxy} from "../../contracts/protocol/implementation/RelayProxy.sol";
import {IRelay} from "../../contracts/userInterfaces/IRelay.sol";

/// Compatible setter-mode source used to observe the delegated verify call.
/// The fee getter can be made unusable, so a successful call proves that Relay
/// does not consult it on the pre-boundary path.
contract RelayOldRelayFeeSourceFV {
    error FeeGetterCalled();
    error DelegatedFeeRequired();

    uint256 internal immutable requiredFee;
    bool internal immutable rejectFeeQuery;
    uint256 public callCount;
    uint256 public receivedValue;

    constructor(uint256 _requiredFee, bool _rejectFeeQuery) {
        requiredFee = _requiredFee;
        rejectFeeQuery = _rejectFeeQuery;
    }

    function signingPolicySetter() external pure returns (address) {
        return address(0x5E77E5);
    }

    function stateData()
        external
        pure
        returns (uint8, uint32, uint8, uint32, uint16, uint16, uint32, bool, uint32, bool, uint32)
    {
        return (0, 1, 1, 0, 1, 0, 0, false, 0, false, 0);
    }

    function protocolFeeInWei(uint256) external view returns (uint256) {
        if (rejectFeeQuery) revert FeeGetterCalled();
        return requiredFee;
    }

    function verify(uint256, uint256, bytes32, bytes32[] calldata) external payable returns (bool) {
        if (msg.value < requiredFee) revert DelegatedFeeRequired();
        callCount++;
        receivedValue = msg.value;
        return true;
    }
}

/**
 * Bounded value-flow properties for pre-boundary verify() delegation.
 *
 * The real proxied Relay is initialized in setter mode with a compatible source.
 * The successful fixture rejects every fee-getter query, accepts only the value
 * received by verify(), and records that value. The positive-fee fixture accepts
 * a delegated call only when the required value reaches it. Together the checks
 * pin getter independence, zero-value delegation, full refund, and fail-closed
 * behavior for a source that enforces a positive fee.
 */
contract RelayOldRelayFeeFV is Test {
    uint256 internal constant CALLER_BALANCE = type(uint128).max;
    uint256 internal constant PROTOCOL_ID = 3;
    uint256 internal constant PRE_BOUNDARY_ROUND = 0;
    bytes32 internal constant LEAF = keccak256("old-relay-fv-leaf");

    function setUp() public {}

    receive() external payable {}

    function _config() internal view returns (IRelay.RelayInitialConfig memory cfg) {
        cfg.initialRewardEpochId = 1;
        cfg.startingVotingRoundIdForInitialRewardEpochId = 1;
        cfg.initialSigningPolicyHash = bytes32(uint256(1));
        cfg.randomNumberProtocolId = 2;
        cfg.firstVotingRoundStartTs = 1;
        cfg.votingEpochDurationSeconds = 1;
        cfg.firstRewardEpochStartVotingRoundId = 0;
        cfg.rewardEpochDurationInVotingEpochs = 1;
        cfg.thresholdIncreaseBIPS = 10_000;
        cfg.messageFinalizationWindowInRewardEpochs = 1;
        cfg.feeCollectionAddress = payable(address(0));
        cfg.feeConfigs = new IRelay.FeeConfig[](0);
        cfg.feeToken = address(0);
        cfg.feeExemptAddresses = new address[](0);
        cfg.sourceChainId = block.chainid;
        cfg.timelockDurationSeconds = 0;
    }

    function _deploy(RelayOldRelayFeeSourceFV source) internal returns (Relay relay) {
        Relay implementation = new Relay();
        relay = Relay(
            address(
                new RelayProxy(
                    address(implementation), _config(), address(0x515E77E2), IRelay(address(source)), address(this)
                )
            )
        );
    }

    function _verify(Relay relay, uint256 msgValue) internal returns (bool ok) {
        (ok,) = address(relay).call{value: msgValue}(
            abi.encodeWithSelector(Relay.verify.selector, PROTOCOL_ID, PRE_BOUNDARY_ROUND, LEAF, new bytes32[](0))
        );
    }

    /// A successful pre-boundary verification consults no fee getter, forwards
    /// zero value, refunds all attached value, and leaves no native balance in Relay.
    // EXPECT: PASS (proof).
    function check_oldRelay_zeroValueFullRefund(uint128 msgValue) external {
        RelayOldRelayFeeSourceFV source = new RelayOldRelayFeeSourceFV(0, true);
        Relay relay = _deploy(source);
        vm.deal(address(this), CALLER_BALANCE);
        vm.deal(address(source), 0);
        vm.deal(address(relay), 0);
        uint256 callerBefore = address(this).balance;

        bool ok = _verify(relay, msgValue);

        assert(ok);
        assert(source.callCount() == 1);
        assert(source.receivedValue() == 0);
        assert(address(source).balance == 0);
        assert(address(relay).balance == 0);
        assert(address(this).balance == callerBefore);
    }

    /// A compatible-looking source that enforces a positive delegated fee
    /// rejects the zero-value call even when the caller attached enough value.
    // EXPECT: PASS (proof).
    function check_oldRelay_positiveFeeSourceFailsClosed(uint96 fee, uint128 msgValue) external {
        vm.assume(fee > 0);
        vm.assume(msgValue >= fee);
        RelayOldRelayFeeSourceFV source = new RelayOldRelayFeeSourceFV(fee, false);
        Relay relay = _deploy(source);
        vm.deal(address(this), CALLER_BALANCE);
        vm.deal(address(source), 0);
        vm.deal(address(relay), 0);
        uint256 callerBefore = address(this).balance;

        bool ok = _verify(relay, msgValue);

        assert(!ok);
        assert(source.callCount() == 0);
        assert(source.receivedValue() == 0);
        assert(address(source).balance == 0);
        assert(address(relay).balance == 0);
        assert(address(this).balance == callerBefore);
    }

    /// The successful delegated path is reachable with an attached value that is fully refunded.
    // EXPECT: COUNTEREXAMPLE (reachability control).
    function check_reach_oldRelay_freeDelegation() external {
        RelayOldRelayFeeSourceFV source = new RelayOldRelayFeeSourceFV(0, true);
        Relay relay = _deploy(source);
        vm.deal(address(this), 1);
        bool ok = _verify(relay, 1);
        assert(!ok);
    }
}
