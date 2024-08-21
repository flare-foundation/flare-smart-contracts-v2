// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "flare-smart-contracts/contracts/genesis/interface/IIPriceSubmitter.sol";
import "../../governance/implementation/Governed.sol";

/**
 * VoterWhitelisterProxy contract.
 */

contract VoterWhitelisterProxy is Governed {

    /// Address of the PriceSubmitter contract set at construction time.
    IIPriceSubmitter public immutable priceSubmitter;

    /**
     * Emitted when an account is removed from the voter whitelist.
     * @param voter Address of the removed account.
     * @param ftsoIndex Index of the FTSO in which it was registered.
     */
    event VoterRemovedFromWhitelist(address voter, uint256 ftsoIndex);

    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        IIPriceSubmitter _priceSubmitter
    )
        Governed(_governanceSettings, _initialGovernance)
    {
        priceSubmitter = _priceSubmitter;
    }

    /**
     * Removes voters from the whitelist.
     * @param _removedVoters Array of addresses to remove from the whitelist.
     * @param _ftsoIndex Index of the FTSO for which to remove voters from the whitelist.
     */
    function votersRemovedFromWhitelist(address[] memory _removedVoters, uint256 _ftsoIndex) external onlyGovernance {
        for (uint256 i = 0; i < _removedVoters.length; i++) {
            emit VoterRemovedFromWhitelist(_removedVoters[i], _ftsoIndex);
        }
        priceSubmitter.votersRemovedFromWhitelist(_removedVoters, _ftsoIndex);
    }


}