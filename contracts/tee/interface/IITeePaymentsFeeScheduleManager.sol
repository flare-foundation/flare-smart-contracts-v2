// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import {
    ITeePaymentsFeeScheduleManager
} from "../../userInterfaces/tee/ITeePaymentsFeeScheduleManager.sol";

/**
 * IITeePaymentsFeeScheduleManager internal interface.
 * @dev Extends the public ITeePaymentsFeeScheduleManager with governance-only management methods.
 */
interface IITeePaymentsFeeScheduleManager is ITeePaymentsFeeScheduleManager {

    /**
     * Batch sets per-sourceId fee schedule configuration.
     * Each config must satisfy: maxSchedules > 0, maxDelaySeconds + 1 >= maxSchedules, and
     * sourceId must be registered in the TeePaymentsRegistry.
     * Emits FeeScheduleConfigsSet event.
     * @param _configs The per-sourceId configuration.
     * Can only be called by the governance.
     */
    function setFeeScheduleConfigs(
        ITeePaymentsFeeScheduleManager.FeeScheduleConfigInput[] calldata _configs
    )
        external;

    /**
     * Batch clears per-sourceId fee schedule configuration.
     * Reverts if any sourceId is not currently configured. No registry check — cleanup always works.
     * Emits FeeScheduleConfigsCleared event.
     * @param _sourceIds The source ids to clear.
     * Can only be called by the governance.
     */
    function clearFeeScheduleConfigs(
        bytes32[] calldata _sourceIds
    )
        external;
}
