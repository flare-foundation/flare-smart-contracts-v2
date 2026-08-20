// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9;

import { ITeeOracleFeedStore } from "../../../../userInterfaces/tee/ITeeOracleFeedStore.sol";

/**
 * @title IITeeOracleFeedStore
 * @notice Internal interface for the TEE oracle feed store — adds the
 *         Flare-governance-only methods on top of the public interface.
 */
interface IITeeOracleFeedStore is ITeeOracleFeedStore {

    /**
     * Updates the destination address collected read fees are forwarded to.
     * Only governance can call this method.
     * @param _feeDestination The fee destination address; must be non-zero.
     */
    function setFeeDestination(
        address _feeDestination
    )
        external;
}
