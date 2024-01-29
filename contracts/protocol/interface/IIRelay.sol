// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../../userInterfaces/IRelay.sol";

/**
 * Relay internal interface.
 */
interface IIRelay is IRelay {

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

    /**
     * Sets the signing policy.
     * @param _signingPolicy Signing policy.
     * @return Returns signing policy hash.
     * @dev This method can only be called by the signing policy setter.
     */
    function setSigningPolicy(SigningPolicy memory _signingPolicy) external returns (bytes32);

}
