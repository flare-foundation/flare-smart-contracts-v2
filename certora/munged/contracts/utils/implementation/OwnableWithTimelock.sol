// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IOwnableWithTimelock} from "../../userInterfaces/IOwnableWithTimelock.sol";

/**
 * @title OwnableWithTimelock
 * @notice Ownable extension that timelocks selected owner calls using a dedicated storage slot.
 * @dev Upgradeable: built on `OwnableUpgradeable`; the concrete contract calls
 *      `__Ownable_init` from its `initialize`. Ownership transfer is guarded like every other
 *      owner call, so while a nonzero duration is configured no owner action can take effect
 *      without passing through the public queue-and-wait window; a zero duration disarms the
 *      timelock for every guarded call, transfers included. The one owner power that is
 *      immediate even with the timelock armed is `cancelTimelockedCall`,
 *      which can only withdraw a pending action, never enact one — the outgoing owner keeps it
 *      until execution and may cancel a queued transfer with it. There is no propose/accept
 *      handshake and no pending-owner state: when the call applies the role moves in one
 *      write, and a reverted execution moves nothing.
 *      Callers must validate the nonzero target because an incorrect target cannot be
 *      recovered by this contract. Its own state lives at a fixed ERC-7201 slot, independent
 *      of the inherited namespaced storage.
 *
 *      Queued calls are keyed by calldata hash alone: they carry no proposer and are not
 *      cleared by `transferOwnership`, so a call queued by a previous owner stays executable
 *      under the new owner — anyone can execute that exact operation, carrying its original
 *      owner authorization. Cancel every outstanding queued call before transferring
 *      ownership; the queue is not enumerable on-chain, so finding them means replaying
 *      `CallTimelocked` off-chain.
 */
abstract contract OwnableWithTimelock is OwnableUpgradeable, IOwnableWithTimelock {

    /// @custom:storage-location erc7201:utils.OwnableWithTimelock.State
    struct State {
        bool executing;
        uint256 timelockDurationSeconds;
        mapping(bytes32 encodedCallHash => uint256 allowedAfterTimestamp) timelockedCalls;
    }

    uint256 internal constant MAX_TIMELOCK_DURATION_SECONDS = 7 days;

    // erc7201 builtin not recognized by slither's parser; the constant is initialized at declaration
    //slither-disable-next-line uninitialized-state
    bytes32 internal constant STATE_POSITION = bytes32(erc7201("utils.OwnableWithTimelock.State"));

    modifier onlyOwnerWithTimelock() {
        if (_timeToExecuteTimelockedCall()) {
            _beforeExecuteTimelockedCall();
            _;
        } else {
            _recordTimelockedCall(msg.data);
        }
    }

    /// @inheritdoc IOwnableWithTimelock
    function executeTimelockedCall(
        bytes calldata _encodedCall
    )
        external
        virtual
    {
        State storage state = getState();
        bytes32 encodedCallHash = keccak256(_encodedCall);
        uint256 allowedAfterTimestamp = state.timelockedCalls[encodedCallHash];
        require(allowedAfterTimestamp != 0, TimelockInvalidSelector());
        require(block.timestamp >= allowedAfterTimestamp, TimelockNotAllowedYet());
        delete state.timelockedCalls[encodedCallHash];
        state.executing = true;
        //solhint-disable-next-line avoid-low-level-calls
        (bool success,) = address(this).call(_encodedCall);
        state.executing = false;
        emit TimelockedCallExecuted(encodedCallHash);
        _passReturnOrRevert(success);
    }

    /// @inheritdoc IOwnableWithTimelock
    function cancelTimelockedCall(
        bytes calldata _encodedCall
    )
        external
        virtual
        onlyOwner
    {
        State storage state = getState();
        bytes32 encodedCallHash = keccak256(_encodedCall);
        require(state.timelockedCalls[encodedCallHash] != 0, TimelockInvalidSelector());
        emit TimelockedCallCanceled(encodedCallHash);
        delete state.timelockedCalls[encodedCallHash];
    }

    /// @inheritdoc IOwnableWithTimelock
    function setTimelockDuration(
        uint256 _timelockDurationSeconds
    )
        external
        virtual
        onlyOwnerWithTimelock
    {
        State storage state = getState();
        require(_timelockDurationSeconds <= MAX_TIMELOCK_DURATION_SECONDS, TimelockDurationTooLong());
        state.timelockDurationSeconds = _timelockDurationSeconds;
        emit TimelockDurationSet(_timelockDurationSeconds);
    }

    /**
     * @notice Transfers ownership, under the timelock like every other guarded call.
     * @dev Not `super.transferOwnership`: on the execute path the call arrives as a self-call
     *      from `executeTimelockedCall`, `_beforeExecuteTimelockedCall` deliberately skips the
     *      owner check, and `Ownable`'s own `onlyOwner` would then reject `msg.sender ==
     *      address(this)`. The internal `_transferOwnership` has no such check, so the
     *      zero-address guard is reapplied here.
     *
     *      With a zero duration this still applies immediately, matching every other guarded
     *      setter. While a transfer is queued the caller remains the owner and may cancel it.
     *      Queued calls are not bound to an owner generation and survive the transfer; cancel
     *      every outstanding one first.
     * @param _newOwner The new owner. Must be nonzero; an incorrect target cannot be recovered.
     */
    function transferOwnership(
        address _newOwner
    )
        public override
        onlyOwnerWithTimelock
    {
        require(_newOwner != address(0), OwnableInvalidOwner(address(0)));
        _transferOwnership(_newOwner);
    }

    /// @inheritdoc IOwnableWithTimelock
    function getTimelockDurationSeconds()
        public
        view
        virtual
        returns (uint256)
    {
        State storage state = getState();
        return state.timelockDurationSeconds;
    }

    /// @inheritdoc IOwnableWithTimelock
    function getExecuteTimelockedCallTimestamp(
        bytes calldata _encodedCall
    )
        public
        view
        virtual
        returns (uint256 _allowedAfterTimestamp)
    {
        State storage state = getState();
        bytes32 encodedCallHash = keccak256(_encodedCall);
        _allowedAfterTimestamp = state.timelockedCalls[encodedCallHash];
        require(_allowedAfterTimestamp != 0, TimelockInvalidSelector());
    }

    /**
     * @notice Disabled to prevent permanently frozen administration; rotate
     *         governance through `transferOwnership`.
     */
    function renounceOwnership()
        public
        pure
        override
    {
        revert RenounceDisabled();
    }

    function _beforeExecuteTimelockedCall()
        internal
        virtual
    {
        State storage state = getState();
        if (state.executing) {
            assert(msg.sender == address(this));
            state.executing = false;
        } else {
            _checkOwner();
        }
    }

    /// @dev An upsert keyed solely by `keccak256(_encodedCall)`: queuing
    ///      calldata that is already pending replaces its ETA — including
    ///      pushing a matured call's ETA forward — and emits a regular
    ///      `CallTimelocked`, indistinguishable from a fresh queueing. The
    ///      latest emitted (and stored) ETA is the authoritative one, and two
    ///      identical calls can never be pending concurrently. Only the owner
    ///      queues, so an overwrite is always governance's own act — a double
    ///      submission or a deliberate re-schedule — never a third party's.
    function _recordTimelockedCall(
        bytes calldata _encodedCall
    )
        internal
        virtual
    {
        State storage state = getState();
        _checkOwner();
        // Execution replays only calldata via a zero-value self-call, so value
        // sent when queuing would be trapped; duration 0 still forwards it.
        require(msg.value == 0, TimelockValueNotAllowed());
        bytes32 encodedCallHash = keccak256(_encodedCall);
        uint256 allowedAt = block.timestamp + state.timelockDurationSeconds;
        state.timelockedCalls[encodedCallHash] = allowedAt;
        emit CallTimelocked(_encodedCall, encodedCallHash, allowedAt);
    }

    function _timeToExecuteTimelockedCall()
        internal
        view
        virtual
        returns (bool)
    {
        State storage state = getState();
        return state.executing || state.timelockDurationSeconds == 0;
    }

    function _passReturnOrRevert(
        bool _success
    )
        internal
        pure
        virtual
    {
        //solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") {
            let size := returndatasize()
            let ptr := mload(0x40)
            mstore(0x40, add(ptr, size))
            returndatacopy(ptr, 0, size)
            if _success {
                return(ptr, size)
            }
            revert(ptr, size)
        }
    }

    function getState()
        internal
        pure
        returns (State storage _state)
    {
        bytes32 position = STATE_POSITION;
        //solhint-disable-next-line no-inline-assembly
        assembly {
            _state.slot := position
        }
    }
}
