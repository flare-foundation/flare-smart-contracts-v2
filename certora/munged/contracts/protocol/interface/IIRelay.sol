// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IRelay } from "../../userInterfaces/IRelay.sol";
import { IOwnableWithTimelock } from "../../userInterfaces/IOwnableWithTimelock.sol";

/**
 * Relay internal interface: the trusted signing-policy setter path plus the owner-governance
 * surface. Every owner setter is annotated `onlyOwnerWithTimelock` in the implementation —
 * with a nonzero timelock duration a call queues for permissionless execution after its ETA
 * (see IOwnableWithTimelock), with zero it applies immediately.
 */
interface IIRelay is IRelay, IOwnableWithTimelock {

    struct SigningPolicy {
        uint24 rewardEpochId;       // Reward epoch id.
        uint32 startVotingRoundId;  // First voting round id of validity.
                                    // Usually it is the first voting round of reward epoch rID.
                                    // It can be later,
                                    // if the confirmation of the signing policy on Flare blockchain gets delayed.
        uint16 threshold;           // Confirmation threshold (absolute value of noramalised weights).
        uint256 seed;               // Random seed.
        address[] voters;           // The list of eligible voters in the canonical order.
        uint16[] weights;           // The corresponding list of normalised signing weights of eligible voters.
                                    // Normalisation is done by compressing the weights from 32-byte values to 2 bytes,
                                    // while approximately keeping the weight relations.
    }

    /// A verify() fee-exemption update entry for `setFeeExemptions`.
    struct FeeExemption {
        address account;    // The account whose exemption is set.
        bool exempt;        // True grants the exemption, false revokes it.
    }

    /**
     * Sets the signing policy.
     * @param _signingPolicy Signing policy.
     * @return Returns signing policy hash.
     * @dev This method can only be called by the signing policy setter (on Flare: FlareSystemsManager),
     *      which is trusted. The signing policy setter MUST ensure the signing policy is well-formed; in
     *      particular it MUST guarantee that there are no zero-address voters and no duplicate voters, that
     *      the voters are given in the canonical order, and that the weights are correctly normalised.
     *      These properties are intentionally NOT re-validated on-chain; correctness relies on
     *      the trusted setter.
     */
    function setSigningPolicy(SigningPolicy memory _signingPolicy) external returns (bytes32);

    /**
     * Sets the verify() fee for each listed protocol id. Relay mode only — a setter-mode
     * (home) deployment charges no fee and reverts with `FeeConfigNotAllowed`.
     * @param _feeConfigs The (protocolId, feeInWei) pairs to set; every protocol id must be
     * greater than 1.
     */
    function setProtocolFees(
        FeeConfig[] calldata _feeConfigs
    )
        external;

    /**
     * Grants or revokes verify() fee exemptions (e.g. DVN adapters). Relay mode only — a
     * setter-mode (home) deployment charges no fee and reverts with `FeeExemptionsNotAllowed`.
     * @param _exemptions The (account, exempt) entries to apply; accounts must be nonzero.
     */
    function setFeeExemptions(
        FeeExemption[] calldata _exemptions
    )
        external;

    /**
     * Points collected verify() fees at a new recipient. Relay mode only — a setter-mode
     * (home) deployment collects no fees and reverts with `FeeConfigNotAllowed`.
     * @param _feeCollectionAddress The new fee recipient; must be nonzero (a zero recipient
     * would burn every collected fee).
     */
    function setFeeCollectionAddress(
        address _feeCollectionAddress
    )
        external;

    /**
     * Repoints the trusted signing-policy setter (e.g. after a FlareSystemsManager
     * redeployment). Setter mode only — the deployment mode is fixed at initialize, so a
     * relay-mode deployment can never gain a setter (`SigningPolicySetterNotAllowed`) and a
     * setter-mode one can never clear it (`SigningPolicySetterZero`).
     * @param _signingPolicySetter The new signing-policy setter; must be nonzero.
     */
    function setSigningPolicySetter(
        address _signingPolicySetter
    )
        external;

}
