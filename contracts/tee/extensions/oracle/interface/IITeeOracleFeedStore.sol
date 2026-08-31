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

    /**
     * Updates the submission policy: how many distinct machine signatures a submission must
     * carry and how far the contributed values may diverge. Reverts with
     * `InvalidSubmissionPolicy` on a zero threshold, a threshold above the store's
     * 32-signature cap, or a relative bound above 10000 BIPS.
     * NOTE: governance must also keep `requiredSignatures` at or below the number of PRODUCTION
     * machines running the feed's latest published configuration — nothing on chain can check
     * that, and a threshold above it silently stops the feed from updating.
     * Only governance can call this method.
     * @param _submissionPolicy The new policy. Its `maxSpreadAbsolute` is denominated at the
     * fixed `10**-8` reference scale, not at any particular submission's scale.
     */
    function setSubmissionPolicy(
        SubmissionPolicy calldata _submissionPolicy
    )
        external;
}
