// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * FtsoFeedDecimals interface.
 */
interface IFtsoFeedDecimals {

    /// Event emitted when a feed decimals value is changed.
    event DecimalsChanged(bytes8 indexed feedName, int8 decimals, uint24 rewardEpochId);

    /// The offset in reward epochs for the decimals value to become effective.
    function decimalsUpdateOffset() external view returns (uint24);

    /// The default decimals value.
    function defaultDecimals() external view returns (int8);

    /**
     * Returns current decimals set for `_feedName`.
     * @param _feedName Feed name.
     */
    function getCurrentDecimals(bytes8 _feedName) external view returns (int8);

    /**
     * Returns the decimals of `_feedName` for given reward epoch id.
     * @param _feedName Feed name.
     * @param _rewardEpochId Reward epoch id.
     * **NOTE:** decimals might still change for the `current + decimalsUpdateOffset` reward epoch id.
     */
    function getDecimals(
        bytes8 _feedName,
        uint256 _rewardEpochId
    )
        external view
        returns (int8);

    /**
     * Returns the scheduled decimals changes of `_feedName`.
     * @param _feedName Feed name.
     * @return _decimals Positional array of decimals.
     * @return _validFromEpochId Positional array of reward epoch ids the decimals setings are effective from.
     * @return _fixed Positional array of boolean values indicating if settings are subjected to change.
     */
    function getScheduledDecimalsChanges(
        bytes8 _feedName
    )
        external view
        returns (
            int8[] memory _decimals,
            uint256[] memory _validFromEpochId,
            bool[] memory _fixed
        );

    /**
     * Returns current decimals setting for `_feedNames`.
     * @param _feedNames Concatenated feed names (each feedName bytes8).
     * @return _decimals Concatenated corresponding decimals (each as bytes1(uint8(int8))).
     */
    function getCurrentDecimalsBulk(
        bytes memory _feedNames
    )
        external view
        returns (bytes memory _decimals);

    /**
     * Returns decimals setting for `_feedNames` at `_rewardEpochId`.
     * @param _feedNames Concatenated feed names (each feedName bytes8).
     * @param _rewardEpochId Reward epoch id.
     * @return _decimals Concatenated corresponding decimals (each as bytes1(uint8(int8))).
     * **NOTE:** decimals might still change for the `current + decimalsUpdateOffset` reward epoch id.
     */
    function getDecimalsBulk(
        bytes memory _feedNames,
        uint256 _rewardEpochId
    )
        external view
        returns (bytes memory _decimals);
}
