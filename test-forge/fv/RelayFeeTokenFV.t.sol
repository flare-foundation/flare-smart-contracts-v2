// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// solhint-disable func-name-mixedcase

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Relay} from "../../contracts/protocol/implementation/Relay.sol";
import {RelayProxy} from "../../contracts/protocol/implementation/RelayProxy.sol";
import {IRelay} from "../../contracts/userInterfaces/IRelay.sol";
import {IIRelay} from "../../contracts/protocol/interface/IIRelay.sol";

/// Deterministic, exact-transfer ERC-20 for executing SafeERC20 against real token bytecode.
/// It deliberately has no callbacks, fees, rebasing, or privileged transfer behavior.
contract RelayStandardFeeTokenFV is IERC20 {
    uint256 public override totalSupply;
    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;

    function mint(address account, uint256 amount) external {
        totalSupply += amount;
        balanceOf[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        uint256 available = allowance[sender][msg.sender];
        require(available >= amount, "insufficient allowance");
        allowance[sender][msg.sender] = available - amount;
        emit Approval(sender, msg.sender, available - amount);
        _transfer(sender, recipient, amount);
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        uint256 available = balanceOf[sender];
        require(available >= amount, "insufficient balance");
        balanceOf[sender] = available - amount;
        balanceOf[recipient] += amount;
        emit Transfer(sender, recipient, amount);
    }
}

/// Token sentinel for paths that must not invoke `transferFrom`. Any such invocation fails with
/// a harness-specific error, so a successful free/exempt call or an exact Relay rejection proves
/// that the external token call was not reached.
contract RelayTransferFromSentinelFV {
    error UnexpectedTransferFrom();

    function transferFrom(address, address, uint256) external pure returns (bool) {
        revert UnexpectedTransferFrom();
    }
}

/**
 * Fee-token and fee-table properties over the production Relay implementation behind its proxy.
 *
 * The verification root is constructed directly in Relay's documented base storage slot 1. This
 * keeps the harness focused on verify()'s fee path rather than coupling it to relay()'s signature
 * loop. An empty proof is valid exactly when leaf == the stored root. Every charged-success proof
 * has a separate counterexample-based reachability control.
 */
contract RelayFeeTokenFV is Test {
    address payable internal constant FEE_COLLECTION = payable(address(0xFEE));
    uint8 internal constant PID = 3;
    uint8 internal constant OTHER_PID = 4;
    uint8 internal constant OMITTED_PID = 5;
    uint256 internal constant VRID = 3360;
    bytes32 internal constant ROOT = bytes32(uint256(1));
    bytes32 internal constant BAD_LEAF = bytes32(uint256(2));
    uint256 internal constant TOKEN_BALANCE = type(uint128).max;

    function setUp() public {}

    receive() external payable {}

    function _config(address token, IRelay.FeeConfig[] memory fees)
        internal
        view
        returns (IRelay.RelayInitialConfig memory cfg)
    {
        cfg.initialRewardEpochId = 1;
        cfg.startingVotingRoundIdForInitialRewardEpochId = uint32(VRID);
        cfg.initialSigningPolicyHash = bytes32(uint256(1));
        cfg.randomNumberProtocolId = 2;
        cfg.firstVotingRoundStartTs = 1_700_000_000;
        cfg.votingEpochDurationSeconds = 90;
        cfg.firstRewardEpochStartVotingRoundId = 0;
        cfg.rewardEpochDurationInVotingEpochs = 3360;
        cfg.thresholdIncreaseBIPS = 12_000;
        cfg.messageFinalizationWindowInRewardEpochs = 5;
        cfg.feeCollectionAddress = FEE_COLLECTION;
        cfg.feeConfigs = fees;
        cfg.feeToken = token;
        cfg.feeExemptAddresses = new address[](0);
        cfg.sourceChainId = block.chainid;
        cfg.timelockDurationSeconds = 0;
    }

    function _deploy(address token, IRelay.FeeConfig[] memory fees) internal returns (Relay relay) {
        Relay implementation = new Relay();
        relay = Relay(
            address(
                new RelayProxy(
                    address(implementation), _config(token, fees), address(0), IRelay(address(0)), address(this)
                )
            )
        );
    }

    function _oneFee(uint8 protocolId, uint256 fee) internal pure returns (IRelay.FeeConfig[] memory fees) {
        fees = new IRelay.FeeConfig[](1);
        fees[0] = IRelay.FeeConfig({protocolId: protocolId, fee: fee});
    }

    function _emptyFees() internal pure returns (IRelay.FeeConfig[] memory fees) {
        fees = new IRelay.FeeConfig[](0);
    }

    function _finalizeRoot(Relay relay, uint8 protocolId, bytes32 root) internal {
        bytes32 inner = keccak256(abi.encode(uint256(protocolId), uint256(1)));
        bytes32 slot = keccak256(abi.encode(VRID, inner));
        vm.store(address(relay), slot, root);
    }

    function _arrangeToken(uint96 fee) internal returns (Relay relay, RelayStandardFeeTokenFV token) {
        token = new RelayStandardFeeTokenFV();
        relay = _deploy(address(token), _oneFee(PID, fee));
        _finalizeRoot(relay, PID, ROOT);
        token.mint(address(this), TOKEN_BALANCE);
        token.approve(address(relay), fee);
    }

    function _arrangeTransferFromSentinel(uint96 fee) internal returns (Relay relay) {
        RelayTransferFromSentinelFV token = new RelayTransferFromSentinelFV();
        relay = _deploy(address(token), _oneFee(PID, fee));
        _finalizeRoot(relay, PID, ROOT);
        assert(relay.feeToken() == address(token));
        assert(RelayTransferFromSentinelFV.UnexpectedTransferFrom.selector != IRelay.MsgValueNotAllowed.selector);
        assert(RelayTransferFromSentinelFV.UnexpectedTransferFrom.selector != IRelay.MerkleProofInvalid.selector);
        assert(RelayTransferFromSentinelFV.UnexpectedTransferFrom.selector != IRelay.NotFinalized.selector);
    }

    function _callVerify(Relay relay, uint256 value, uint8 protocolId, bytes32 leaf)
        internal
        returns (bool ok, bytes memory returnData)
    {
        (ok, returnData) = address(relay).call{value: value}(
            abi.encodeWithSelector(Relay.verify.selector, uint256(protocolId), VRID, leaf, new bytes32[](0))
        );
    }

    function _revertSelector(bytes memory returnData) internal pure returns (bytes4 selector) {
        if (returnData.length >= 4) {
            assembly {
                selector := mload(add(returnData, 0x20))
            }
        }
    }

    function _assertEmptyFeeState(Relay relay) internal view {
        assert(relay.feeToken() == address(0));
        assert(relay.protocolFee(PID) == 0);
        assert(relay.protocolFee(OTHER_PID) == 0);
        assert(relay.getFeeConfigs().length == 0);
    }

    // A successful token-mode verification pulls exactly the configured amount directly from
    // the caller to the collector and consumes exactly that allowance. The Relay holds neither
    // tokens nor native value.
    // EXPECT: PASS (proof).
    function check_tokenVerify_transfersExactFee(uint96 fee) external {
        vm.assume(fee > 0);
        (Relay relay, RelayStandardFeeTokenFV token) = _arrangeToken(fee);
        uint256 callerBefore = token.balanceOf(address(this));
        uint256 collectorBefore = token.balanceOf(FEE_COLLECTION);

        (bool ok,) = _callVerify(relay, 0, PID, ROOT);

        assert(ok);
        assert(callerBefore - token.balanceOf(address(this)) == fee);
        assert(token.balanceOf(FEE_COLLECTION) - collectorBefore == fee);
        assert(token.balanceOf(address(relay)) == 0);
        assert(token.allowance(address(this), address(relay)) == 0);
        assert(address(relay).balance == 0);
    }

    // Native value is forbidden in token mode before any external token call. The sentinel would
    // replace this exact Relay error if transferFrom were reached.
    // EXPECT: PASS (proof).
    function check_tokenVerify_rejectsMsgValueExactly(uint96 fee) external {
        vm.assume(fee > 0);
        Relay relay = _arrangeTransferFromSentinel(fee);
        vm.deal(address(this), 1);

        (bool ok, bytes memory returnData) = _callVerify(relay, 1, PID, ROOT);

        assert(!ok);
        assert(_revertSelector(returnData) == IRelay.MsgValueNotAllowed.selector);
        assert(address(this).balance == 1);
        assert(address(relay).balance == 0);
    }

    // Fee exemption is evaluated before charging. The exempt call succeeds against a token whose
    // transferFrom always reverts, proving that the external token call is not reached.
    // EXPECT: PASS (proof).
    function check_tokenVerify_exemptCallerPaysNothing(uint96 fee) external {
        vm.assume(fee > 0);
        Relay relay = _arrangeTransferFromSentinel(fee);
        IIRelay.FeeExemption[] memory exemptions = new IIRelay.FeeExemption[](1);
        exemptions[0] = IIRelay.FeeExemption({account: address(this), exempt: true});
        relay.setFeeExemptions(exemptions);

        (bool ok,) = _callVerify(relay, 0, PID, ROOT);

        assert(ok);
    }

    // A bad proof fails with Relay's exact error. The transferFrom sentinel has a distinct error,
    // so this also proves SafeERC20 is not reached before proof rejection.
    // EXPECT: PASS (proof).
    function check_tokenVerify_invalidProofFailsBeforeCharge(uint96 fee) external {
        vm.assume(fee > 0);
        Relay relay = _arrangeTransferFromSentinel(fee);

        (bool ok, bytes memory returnData) = _callVerify(relay, 0, PID, BAD_LEAF);

        assert(!ok);
        assert(_revertSelector(returnData) == IRelay.MerkleProofInvalid.selector);
    }

    // An uninitialized root fails with NotFinalized before Merkle processing or SafeERC20. The
    // sentinel's distinct transferFrom error proves the external token call is not reached.
    // EXPECT: PASS (proof).
    function check_tokenVerify_unfinalizedFailsBeforeChargeExactly(uint96 fee) external {
        vm.assume(fee > 0);
        Relay relay = _arrangeTransferFromSentinel(fee);
        _finalizeRoot(relay, PID, bytes32(0));

        (bool ok, bytes memory returnData) = _callVerify(relay, 0, PID, ROOT);

        assert(!ok);
        assert(_revertSelector(returnData) == IRelay.NotFinalized.selector);
    }

    // A protocol omitted from the table is free even while a token denomination is active, so
    // verification succeeds against a transferFrom sentinel, proving that it performs no token call.
    // EXPECT: PASS (proof).
    function check_tokenVerify_omittedProtocolSkipsTransfer(uint96 configuredFee) external {
        vm.assume(configuredFee > 0);
        Relay relay = _arrangeTransferFromSentinel(configuredFee);
        _finalizeRoot(relay, OTHER_PID, ROOT);

        (bool ok,) = _callVerify(relay, 0, OTHER_PID, ROOT);

        assert(ok);
        assert(relay.protocolFee(OTHER_PID) == 0);
    }

    // The denomination-neutral getter remains usable, while the native-wei compatibility getter
    // fails closed with its exact typed error whenever a token is active.
    // EXPECT: PASS (proof).
    function check_tokenNativeWeiGetter_revertsExactly(uint96 fee) external {
        vm.assume(fee > 0);
        (Relay relay,) = _arrangeToken(fee);
        (bool ok, bytes memory returnData) =
            address(relay).staticcall(abi.encodeCall(relay.protocolFeeInWei, (uint256(PID))));

        assert(relay.protocolFee(PID) == fee);
        assert(!ok);
        assert(_revertSelector(returnData) == IRelay.FeeTokenActive.selector);
    }

    // setProtocolFees is a full replace: omitted entries are cleared before a new denomination
    // is installed, and an empty replace clears both the table and the token.
    // EXPECT: PASS (proof).
    function check_feeTable_fullReplaceClearsOmitted(uint96 oldFee, uint96 retainedFee, uint96 newFee) external {
        vm.assume(oldFee > 0 && retainedFee > 0 && newFee > 0);
        IRelay.FeeConfig[] memory initial = new IRelay.FeeConfig[](2);
        initial[0] = IRelay.FeeConfig({protocolId: PID, fee: oldFee});
        initial[1] = IRelay.FeeConfig({protocolId: OTHER_PID, fee: retainedFee});
        Relay relay = _deploy(address(0xA11CE), initial);

        relay.setProtocolFees(address(0xB0B), _oneFee(OTHER_PID, newFee));
        IRelay.FeeConfig[] memory replaced = relay.getFeeConfigs();
        assert(relay.feeToken() == address(0xB0B));
        assert(relay.protocolFee(PID) == 0);
        assert(relay.protocolFee(OTHER_PID) == newFee);
        assert(replaced.length == 1);
        assert(replaced[0].protocolId == OTHER_PID && replaced[0].fee == newFee);

        relay.setProtocolFees(address(0), _emptyFees());
        _assertEmptyFeeState(relay);
    }

    // Enumeration and mapping are two views of the same nonzero table: every enumerated item
    // has the mapping value, both installed ids occur exactly once, and an omitted id maps to zero.
    // EXPECT: PASS (proof).
    function check_feeTable_enumerationMatchesMapping(uint96 fee3, uint96 fee4) external {
        vm.assume(fee3 > 0 && fee4 > 0);
        IRelay.FeeConfig[] memory fees = new IRelay.FeeConfig[](2);
        fees[0] = IRelay.FeeConfig({protocolId: PID, fee: fee3});
        fees[1] = IRelay.FeeConfig({protocolId: OTHER_PID, fee: fee4});
        Relay relay = _deploy(address(0x70CE2), fees);
        IRelay.FeeConfig[] memory table = relay.getFeeConfigs();
        bool seen3;
        bool seen4;

        assert(table.length == 2);
        for (uint256 i = 0; i < table.length; i++) {
            IRelay.FeeConfig memory item = table[i];
            assert(item.fee > 0);
            assert(relay.protocolFee(item.protocolId) == item.fee);
            assert(item.protocolId == PID || item.protocolId == OTHER_PID);
            if (item.protocolId == PID) {
                assert(!seen3 && item.fee == fee3);
                seen3 = true;
            } else {
                assert(!seen4 && item.fee == fee4);
                seen4 = true;
            }
        }
        assert(seen3 && seen4);
        assert(relay.protocolFee(PID) == fee3);
        assert(relay.protocolFee(OTHER_PID) == fee4);
        assert(relay.protocolFee(OMITTED_PID) == 0);
    }

    // Duplicate ids are rejected exactly and the whole attempted replacement, including the
    // denomination change and first loop iteration, rolls back.
    // EXPECT: PASS (proof).
    function check_feeTable_rejectsDuplicateExactly(uint96 priorFee, uint96 firstFee, uint96 secondFee) external {
        vm.assume(priorFee > 0 && firstFee > 0 && secondFee > 0);
        address priorToken = address(0xA11CE);
        Relay relay = _deploy(priorToken, _oneFee(OTHER_PID, priorFee));
        IRelay.FeeConfig[] memory duplicate = new IRelay.FeeConfig[](2);
        duplicate[0] = IRelay.FeeConfig({protocolId: PID, fee: firstFee});
        duplicate[1] = IRelay.FeeConfig({protocolId: PID, fee: secondFee});

        (bool ok, bytes memory returnData) =
            address(relay).call(abi.encodeCall(relay.setProtocolFees, (address(0x70CE2), duplicate)));

        assert(!ok);
        assert(_revertSelector(returnData) == IRelay.DuplicateProtocolId.selector);
        IRelay.FeeConfig[] memory preserved = relay.getFeeConfigs();
        assert(relay.feeToken() == priorToken);
        assert(relay.protocolFee(PID) == 0);
        assert(relay.protocolFee(OTHER_PID) == priorFee);
        assert(preserved.length == 1);
        assert(preserved[0].protocolId == OTHER_PID && preserved[0].fee == priorFee);
    }

    // A listed zero fee is invalid; free protocols must be omitted. The rejected call is atomic.
    // EXPECT: PASS (proof).
    function check_feeTable_rejectsZeroExactly() external {
        Relay relay = _deploy(address(0), _emptyFees());

        (bool ok, bytes memory returnData) =
            address(relay).call(abi.encodeCall(relay.setProtocolFees, (address(0x70CE2), _oneFee(PID, 0))));

        assert(!ok);
        assert(_revertSelector(returnData) == IRelay.ProtocolFeeZero.selector);
        _assertEmptyFeeState(relay);
    }

    // Protocol ids 0 and 1 are reserved and rejected before the fee is installed.
    // EXPECT: PASS (proof).
    function check_feeTable_rejectsReservedExactly(uint8 protocolId, uint96 fee) external {
        vm.assume(protocolId <= 1);
        vm.assume(fee > 0);
        Relay relay = _deploy(address(0), _emptyFees());

        (bool ok, bytes memory returnData) =
            address(relay).call(abi.encodeCall(relay.setProtocolFees, (address(0x70CE2), _oneFee(protocolId, fee))));

        assert(!ok);
        assert(_revertSelector(returnData) == IRelay.InvalidProtocolId.selector);
        _assertEmptyFeeState(relay);
    }

    // Anti-vacuity: the exact-transfer path is reachable for a valid positive configured fee.
    // EXPECT: COUNTEREXAMPLE (reachability control).
    function check_reach_tokenVerifyExactFee(uint96 fee) external {
        vm.assume(fee > 0);
        (Relay relay,) = _arrangeToken(fee);
        (bool ok,) = _callVerify(relay, 0, PID, ROOT);
        assert(!ok); // EXPECT counterexample: token-paid verification succeeds
    }
}
