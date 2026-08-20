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
     * Updates the acceptance window — both directions in one policy.
     * Only governance can call this method.
     * @param _maxAge The maximum update age at submission time, in seconds (past direction —
     * bounds the selective-submission window; tolerates delivery latency).
     * @param _maxFutureSkew The max clock drift allowed for future-dated updates, in seconds
     * (future direction — keep tight: a future-dated observation freezes the feed and reads
     * as fresh until chain time catches up).
     */
    function setAcceptanceWindow(
        uint64 _maxAge,
        uint64 _maxFutureSkew
    )
        external;

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
