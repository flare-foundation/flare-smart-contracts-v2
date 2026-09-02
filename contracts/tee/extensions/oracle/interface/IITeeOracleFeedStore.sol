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
     * NOTE: `getCurrentFeed` forwards the whole `msg.value` to this address with all remaining
     * gas, and every paid read of the feed goes through it — including FtsoV2's multi-feed loop,
     * which calls the store while still holding value it has to forward to later feeds. The
     * destination should therefore be a codeless address, or a contract with a trivial,
     * non-reverting `receive`: a destination that reverts fails EVERY read of this feed until
     * another timelocked call replaces it, and a destination that executes can re-enter FtsoV2 or
     * this store between the elements of one batch read.
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
     * NOTE: two governance invariants nothing on chain can check, each of which stops the feed
     * silently — through a REVERT, not an event — when it is set wrong: `requiredSignatures` must
     * stay at or below the number of PRODUCTION machines running the feed's latest published
     * configuration, and the two deviation terms must not be so small that an honest fleet cannot
     * meet them (both zero demands bit-exact agreement of the two central values at an even
     * count, and agreement within one unit at an odd one). Each is recoverable only by a second,
     * timelocked call.
     * NOTE: this is an ordinary timelocked governance call, keyed by the hash of its whole
     * calldata, so two policies can be pending at once and execute in either order — an older,
     * weaker one landing last silently restores a lower `requiredSignatures`. Nothing makes the
     * loser unexecutable, here or on the sender's configuration publications, so governance must
     * CANCEL a superseded policy call rather than leave it queued. The same applies to
     * `setFeeDestination`.
     * Only governance can call this method.
     * @param _submissionPolicy The new policy. Its `maxSpreadAbsolute` is denominated at the
     * fixed `10**-8` reference scale, not at any particular submission's scale.
     */
    function setSubmissionPolicy(
        SubmissionPolicy calldata _submissionPolicy
    )
        external;
}
