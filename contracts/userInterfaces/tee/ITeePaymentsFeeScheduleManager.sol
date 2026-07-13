// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { ITeePaymentsBase } from "./ITeePaymentsBase.sol";

/// @dev Default fee schedule: factor 1 (10000 BIPS = 0x2710), delay 0 seconds (0x0000).
bytes constant DEFAULT_FEE_SCHEDULE = hex"27100000";

/**
 * ITeePaymentsFeeScheduleManager interface.
 *
 * Shared fee schedule registry for all TeePayments instances. Provides:
 *  - Per-sourceId governance-configurable limits (max schedule entries, max delay seconds).
 *  - Per-(projectId, sourceId) default fee schedules set by project owner.
 *  - Per-(sourceId, accountAddress) overrides set by project owner.
 *  - Schedule validation/lookup used by TeePayments during pay()/reissue().
 */
interface ITeePaymentsFeeScheduleManager {

    /// Single fee schedule entry: one factor BIPS + delay seconds.
    /// A complete schedule is an array of these entries ordered ascending by delaySeconds.
    struct FeeSchedule {
        int16 factorBIPS;
        uint16 delaySeconds;
    }

    /// Input for batch per-sourceId fee schedule configuration.
    // NOTE: alphabetical field order for stdJson compatibility.
    struct FeeScheduleConfigInput {
        uint16 maxDelaySeconds;
        uint8 maxSchedules;
        bytes32 sourceId;
    }

    /// Per-sourceId fee schedule configuration (governance-managed limits).
    struct FeeScheduleConfig {
        uint8 maxSchedules;
        uint16 maxDelaySeconds;
    }

    event FeeScheduleConfigsSet(
        FeeScheduleConfigInput[] configs
    );

    event FeeScheduleConfigsCleared(
        bytes32[] sourceIds
    );

    event ProjectFeeScheduleSet(
        bytes32 indexed projectId,
        bytes32 indexed sourceId,
        FeeSchedule[] schedule
    );

    event ProjectFeeScheduleCleared(
        bytes32 indexed projectId,
        bytes32 indexed sourceId
    );

    event AccountFeeScheduleSet(
        bytes32 indexed projectId,
        bytes32 indexed sourceId,
        string accountAddress,
        bytes32 indexed accountHash,
        FeeSchedule[] schedule
    );

    event AccountFeeScheduleCleared(
        bytes32 indexed projectId,
        bytes32 indexed sourceId,
        string accountAddress,
        bytes32 indexed accountHash
    );

    error InvalidFeeFactor(uint256 index);
    error InvalidFeeDelay(uint256 index);
    error LengthsMismatch();
    error SourceLimitsNotConfigured(bytes32 sourceId);
    error TooManySchedules();
    error DelayTooLarge(uint256 delay, uint256 maxDelay);
    error OnlyProjectOwner();
    error OnlySystemExtensionId();
    error AccountNotRegistered();
    error UnsupportedSourceId(bytes32 sourceId);
    error InvalidFeeScheduleConfig(bytes32 sourceId, uint8 maxSchedules, uint16 maxDelaySeconds);
    error FeeScheduleConfigNotSet(bytes32 sourceId);
    error EmptyScheduleNotAllowed();
    error FeeScheduleNotSet();

    /**
     * Sets the default fee schedule for the given project + source id.
     * Empty schedules are rejected — use clearProjectFeeSchedule instead.
     * Reverts unless the project is on the system extension (id 0), since PMW payment accounts
     * — the only consumers of these schedules — can only be registered under extension 0.
     * Emits ProjectFeeScheduleSet event.
     * @param _projectId The project id.
     * @param _sourceId The source id.
     * @param _schedule The fee schedule entries, ordered ascending by delaySeconds.
     * Can only be called by the project owner.
     */
    function setProjectFeeSchedule(
        bytes32 _projectId,
        bytes32 _sourceId,
        FeeSchedule[] calldata _schedule
    )
        external;

    /**
     * Clears the project default fee schedule for the given source id.
     * Reverts if no schedule is currently set.
     * Emits ProjectFeeScheduleCleared event.
     * @param _projectId The project id.
     * @param _sourceId The source id.
     * Can only be called by the project owner.
     */
    function clearProjectFeeSchedule(
        bytes32 _projectId,
        bytes32 _sourceId
    )
        external;

    /**
     * Sets the account-specific fee schedule override.
     * Project id is derived from the account via the registry -> TeePayments -> walletId chain,
     * so a project owner cannot stomp on accounts not in their project.
     * Empty schedules are rejected — use clearAccountFeeSchedule instead.
     * Emits AccountFeeScheduleSet event.
     * @param _account The PMW multisig account.
     * @param _schedule The fee schedule entries, ordered ascending by delaySeconds.
     * Can only be called by the account owner.
     */
    function setAccountFeeSchedule(
        ITeePaymentsBase.PMWMultisigAccount calldata _account,
        FeeSchedule[] calldata _schedule
    )
        external;

    /**
     * Clears the account-specific fee schedule override.
     * Reverts if no override is currently set.
     * Emits AccountFeeScheduleCleared event.
     * @param _account The PMW multisig account.
     * Can only be called by the account owner.
     */
    function clearAccountFeeSchedule(
        ITeePaymentsBase.PMWMultisigAccount calldata _account
    )
        external;

    /**
     * Returns the effective encoded fee schedule for the given account.
     * Precedence: account override -> project default -> DEFAULT_FEE_SCHEDULE.
     * @param _projectId The project id.
     * @param _sourceId The source id.
     * @param _accountHash The account hash (keccak256(sourceId, accountAddress)).
     * @return _feeSchedule The effective encoded fee schedule (4 bytes per entry).
     */
    function getEffectiveSchedule(
        bytes32 _projectId,
        bytes32 _sourceId,
        bytes32 _accountHash
    )
        external view
        returns (bytes memory _feeSchedule);

    /**
     * Validates multiple fee schedules that share a common delays array (reissue use case)
     * and returns their encoded bytes.
     *
     * Validates the shared delays once (count, ascending, max), then per-payment: length
     * match + factor range + encoding. Saves external-call overhead and redundant delay
     * validation compared to calling a per-schedule validator in a loop.
     *
     * If the source has no fee schedule configuration (maxSchedules == 0), the method still
     * accepts the trivial schedule shape — at most 1 entry with delay 0 and any valid non-zero
     * factor (including negative, for reissue-based invalidation). Richer schedules require
     * governance to configure the source first.
     *
     * @param _sourceId The source id.
     * @param _factorsBIPSPerPayment Per-payment factor arrays; each must have the same length as `_delaysSeconds`.
     * @param _delaysSeconds Shared delay seconds array, ordered strictly ascending.
     * @return _encodedPerPayment Encoded fee schedule bytes per payment (4 bytes per entry).
     */
    function validateAndEncodeSchedules(
        bytes32 _sourceId,
        int16[][] calldata _factorsBIPSPerPayment,
        uint16[] calldata _delaysSeconds
    )
        external view
        returns (bytes[] memory _encodedPerPayment);

    /**
     * Returns the project default fee schedule.
     * @param _projectId The project id.
     * @param _sourceId The source id.
     * @return _schedule The fee schedule entries.
     */
    function getProjectFeeSchedule(
        bytes32 _projectId,
        bytes32 _sourceId
    )
        external view
        returns (FeeSchedule[] memory _schedule);

    /**
     * Returns the account-specific fee schedule override (if any).
     * @param _account The PMW multisig account.
     * @return _schedule The fee schedule entries.
     */
    function getAccountFeeSchedule(
        ITeePaymentsBase.PMWMultisigAccount calldata _account
    )
        external view
        returns (FeeSchedule[] memory _schedule);

    /**
     * Returns the per-sourceId fee schedule configuration.
     * @param _sourceId The source id.
     * @return _config The fee schedule config (maxSchedules + maxDelaySeconds).
     */
    function getFeeScheduleConfig(
        bytes32 _sourceId
    )
        external view
        returns (FeeScheduleConfig memory _config);
}
