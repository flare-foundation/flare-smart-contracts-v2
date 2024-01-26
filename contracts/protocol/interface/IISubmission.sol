// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../../userInterfaces/ISubmission.sol";


/**
 * Submission internal interface.
 */
interface IISubmission is ISubmission {

    /**
     * Initiates a new voting round.
     * @param _submit1Addresses The addresses that can call submit1.
     * @param _submit2Addresses The addresses that can call submit2.
     * @param _submit3Addresses The addresses that can call submit3.
     * @param _submitSignaturesAddresses The addresses that can call submitSignatures.
     * @dev This method can only be called by the FlareSystemManager contract.
     */
    function initNewVotingRound(
        address[] memory _submit1Addresses,
        address[] memory _submit2Addresses,
        address[] memory _submit3Addresses,
        address[] memory _submitSignaturesAddresses
    )
        external;
}
