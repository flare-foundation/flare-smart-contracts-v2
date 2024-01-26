// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./IRandomProvider.sol";

/**
 * Submission interface.
 */
interface ISubmission is IRandomProvider {

    /// Event emitted when a new voting round is initiated.
    event NewVotingRoundInitiated();

    /**
     * Submit1 method. Used in multiple protocols (i.e. as FTSO commit method).
     */
    function submit1() external returns (bool);

    /**
     * Submit2 method. Used in multiple protocols (i.e. as FTSO reveal method).
     */
    function submit2() external returns (bool);

    /**
     * Submit3 method. Future usage.
     */
    function submit3() external returns (bool);

    /**
     * SubmitSignatures method. Used in multiple protocols (i.e. as FTSO submit signature method).
     */
    function submitSignatures() external returns (bool);

    /**
     * SubmitAndPass method. Future usage.
     * @param _data The data to pass to the submitAndPassContract.
     */
    function submitAndPass(bytes calldata _data) external returns (bool);
}
