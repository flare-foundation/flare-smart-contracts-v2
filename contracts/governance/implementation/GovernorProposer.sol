// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../interface/IIGovernorProposer.sol";
import "./Governed.sol";

abstract contract GovernorProposer is IIGovernorProposer, Governed {

    mapping(address => bool) private proposers;

    event ProposersChanged(address[] addedProposers, address[] removedProposers);

    /**
     * Initializes the governor parameters.
     * @param _proposers Array of addresses allowed to submit a proposal.
     */
    constructor(
        address[] memory _proposers
    ) {
        _changeProposers(_proposers, new address[](0));
    }

    /**
     * Changes proposers.
     * @param _proposersToAdd Array of addresses to make eligible to submit a proposal.
     * @param _proposersToRemove Array of addresses to make ineligible to submit a proposal.
     * @dev This operation can only be performed by governance.
     * Emits a ProposersChanged event.
     */
    function changeProposers(
        address[] memory _proposersToAdd,
        address[] memory _proposersToRemove
    ) public onlyGovernance {
        _changeProposers(_proposersToAdd, _proposersToRemove);
    }

    /**
     * @inheritdoc IIGovernorProposer
     */
    function isProposer(address _account) public view returns (bool) {
        return proposers[_account];
    }

    /**
     * Changes proposers.
     * @param _proposersToAdd Array of addresses to make eligible to submit a proposal.
     * @param _proposersToRemove Array of addresses to make ineligible to submit a proposal.
     * Emits a ProposersChanged event.
     */
    function _changeProposers(address[] memory _proposersToAdd, address[] memory _proposersToRemove) internal {
        emit ProposersChanged(_proposersToAdd, _proposersToRemove);
        for (uint256 i = 0; i < _proposersToAdd.length; i++) {
            proposers[_proposersToAdd[i]] = true;
        }
        for (uint256 i = 0; i < _proposersToRemove.length; i++) {
            proposers[_proposersToRemove[i]] = false;
        }
    }

}
