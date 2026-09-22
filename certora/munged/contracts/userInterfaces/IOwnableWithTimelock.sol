// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9;

/**
 * @title IOwnableWithTimelock
 * @notice Generic interface for ownable timelocked call execution.
 * @dev Three properties callers must plan around, none visible in the ABI.
 *
 *      A guarded call **either applies or queues**, and both return success.
 *      A void guarded call returns empty ABI data in each case, so the return
 *      value cannot distinguish them either. Read back
 *      `getExecuteTimelockedCallTimestamp` or the target's own getter to tell
 *      which happened.
 *
 *      **A queued call whose migration data invokes another guarded function is
 *      not executable**: execution self-calls the proxy and consumes the
 *      `executing` flag, so the nested call tries to queue and reverts on the
 *      owner check. A zero duration takes the immediate branch instead, so the
 *      same data rehearses green on testnet and fails on a timelocked mainnet.
 *      Guard migration entry points on owner-or-self, not on the timelock.
 *
 *      **Queued calls survive `transferOwnership`.** They are keyed by
 *      calldata hash alone, with no proposer, so a call queued by the
 *      previous owner remains executable after the transfer unless
 *      cancelled first: anyone can execute that exact operation, carrying
 *      its original owner authorization. `transferOwnership` is itself a
 *      guarded call, so with a nonzero duration the transfer is visible for
 *      the delay before it applies, and that window is when the outstanding
 *      queue must be cleared. With a zero duration there is no window: the
 *      transfer applies at once and the queue carries over unexamined.
 *      The queue is not enumerable on-chain, so clearing it means replaying
 *      `CallTimelocked` and cancelling what is still pending.
 */
interface IOwnableWithTimelock {

    /**
     * @notice Emitted when a call is timelocked and can be executed later.
     *         An upsert keyed by `encodedCallHash`: re-queuing identical
     *         calldata resets the pending ETA and emits this event again, so
     *         the latest `allowedAfterTimestamp` per hash is authoritative
     *         and two identical calls are never pending concurrently.
     * @param encodedCall ABI encoded call data.
     * @param encodedCallHash Hash of encoded call.
     * @param allowedAfterTimestamp Earliest timestamp when call is executable.
     */
    event CallTimelocked(
        bytes encodedCall,
        bytes32 encodedCallHash,
        uint256 allowedAfterTimestamp
    );

    /**
     * @notice Emitted when a timelocked call is executed.
     * @param encodedCallHash Hash of encoded call.
     */
    event TimelockedCallExecuted(
        bytes32 encodedCallHash
    );

    /**
     * @notice Emitted when a timelocked call is canceled.
     * @param encodedCallHash Hash of encoded call.
     */
    event TimelockedCallCanceled(
        bytes32 encodedCallHash
    );

    /**
     * @notice Emitted when timelock duration is updated.
     * @param timelockDurationSeconds New timelock duration in seconds.
     */
    event TimelockDurationSet(
        uint256 timelockDurationSeconds
    );

    /**
     * @notice Reverts when the encoded call has no queued timelock entry.
     */
    error TimelockInvalidSelector();

    /**
     * @notice Reverts when timelocked call execution is attempted too early.
     */
    error TimelockNotAllowedYet();

    /**
     * @notice Reverts when requested timelock duration exceeds maximum.
     */
    error TimelockDurationTooLong();

    /**
     * @notice Reverts when a call is queued with a nonzero value. Execution
     *         replays only the recorded calldata (never value), so queued
     *         value would be trapped in the contract.
     */
    error TimelockValueNotAllowed();

    /**
     * @notice Reverts on any `renounceOwnership` call. The role cannot be
     *         given up, only moved with `transferOwnership` — itself a guarded
     *         call, so it queues and waits whenever a nonzero duration is set.
     */
    error RenounceDisabled();

    /**
     * @notice Executes a queued call once its recorded ETA has passed.
     * @param _encodedCall ABI encoded call data.
     * @dev Permissionless after the ETA recorded when the call was queued (not
     *      the current timelock duration).
     */
    function executeTimelockedCall(
        bytes calldata _encodedCall
    )
        external;

    /**
     * @notice Cancels a queued timelocked call.
     * @param _encodedCall ABI encoded call data.
     */
    function cancelTimelockedCall(
        bytes calldata _encodedCall
    )
        external;

    /**
     * @notice Sets the timelock duration for owner-controlled calls, through the
     *         current owner-timelock path (this call is itself protected).
     * @param _timelockDurationSeconds Timelock duration in seconds.
     */
    function setTimelockDuration(
        uint256 _timelockDurationSeconds
    )
        external;

    /**
     * @notice Returns timestamp when a timelocked call may be executed.
     * @param _encodedCall ABI encoded call data.
     * @return _allowedAfterTimestamp Earliest execution timestamp.
     */
    function getExecuteTimelockedCallTimestamp(
        bytes calldata _encodedCall
    )
        external view
        returns (uint256 _allowedAfterTimestamp);

    /**
     * @notice Returns the configured timelock duration in seconds.
     * @return Timelock duration in seconds.
     */
    function getTimelockDurationSeconds() external view returns (uint256);
}
