// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * WNatDelegationFee interface.
 */
interface IWNatDelegationFee {

    /// Event emitted when a voter fee percentage value is changed.
    event FeePercentageChanged(address indexed voter, uint16 value, uint24 validFromEpochId);

    /**
     * Allows voter to set (or update last) fee percentage.
     * @param _feePercentageBIPS Number representing fee percentage in BIPS.
     * @return Returns the reward epoch number when the value becomes effective.
     */
    function setVoterFeePercentage(uint16 _feePercentageBIPS) external returns (uint256);

    /// The offset in reward epochs for the fee percentage value to become effective.
    function feePercentageUpdateOffset() external view returns (uint24);

    /// The default fee percentage value.
    function defaultFeePercentageBIPS() external view returns (uint16);

    /**
     * Returns the current fee percentage of `_voter`.
     * @param _voter Voter address.
     */
    function getVoterCurrentFeePercentage(address _voter) external view returns (uint16);

    /**
     * Returns the fee percentage of `_voter` for given reward epoch id.
     * @param _voter Voter address.
     * @param _rewardEpochId Reward epoch id.
     * **NOTE:** fee percentage might still change for the `current + feePercentageUpdateOffset` reward epoch id
     */
    function getVoterFeePercentage(
        address _voter,
        uint256 _rewardEpochId
    )
        external view
        returns (uint16);

    /**
     * Returns the scheduled fee percentage changes of `_voter`.
     * @param _voter Voter address.
     * @return _feePercentageBIPS Positional array of fee percentages in BIPS.
     * @return _validFromEpochId Positional array of reward epoch ids the fee setings are effective from.
     * @return _fixed Positional array of boolean values indicating if settings are subjected to change.
     */
    function getVoterScheduledFeePercentageChanges(
        address _voter
    )
        external view
        returns (
            uint256[] memory _feePercentageBIPS,
            uint256[] memory _validFromEpochId,
            bool[] memory _fixed
        );
}
