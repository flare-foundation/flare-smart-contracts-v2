// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * FtsoFeedDecimals interface.
 */
interface IFtsoFeedDecimals {

    /// Event emitted when a feed decimals value is changed.
    event DecimalsChanged(bytes21 indexed feedId, int8 decimals, uint24 rewardEpochId);

    /// The offset in reward epochs for the decimals value to become effective.
    function decimalsUpdateOffset() external view returns (uint24);

    /// The default decimals value.
    function defaultDecimals() external view returns (int8);

    /**
     * Returns current decimals set for `_feedId`.
     * @param _feedId Feed id.
     */
    function getCurrentDecimals(bytes21 _feedId) external view returns (int8);

    /**
     * Returns the decimals of `_feedId` for given reward epoch id.
     * @param _feedId Feed id.
     * @param _rewardEpochId Reward epoch id.
     * **NOTE:** decimals might still change for the `current + decimalsUpdateOffset` reward epoch id.
     */
    function getDecimals(
        bytes21 _feedId,
        uint256 _rewardEpochId
    )
        external view
        returns (int8);

    /**
     * Returns the scheduled decimals changes of `_feedId`.
     * @param _feedId Feed id.
     * @return _decimals Positional array of decimals.
     * @return _validFromEpochId Positional array of reward epoch ids the decimals settings are effective from.
     * @return _fixed Positional array of boolean values indicating if settings are subjected to change.
     */
    function getScheduledDecimalsChanges(
        bytes21 _feedId
    )
        external view
        returns (
            int8[] memory _decimals,
            uint256[] memory _validFromEpochId,
            bool[] memory _fixed
        );

    /**
     * Returns current decimals setting for `_feedIds`.
     * @param _feedIds Concatenated feed ids (each feedId bytes21).
     * @return _decimals Concatenated corresponding decimals (each as bytes1(uint8(int8))).
     */
    function getCurrentDecimalsBulk(
        bytes memory _feedIds
    )
        external view
        returns (bytes memory _decimals);

    /**
     * Returns decimals setting for `_feedIds` at `_rewardEpochId`.
     * @param _feedIds Concatenated feed ids (each feedId bytes21).
     * @param _rewardEpochId Reward epoch id.
     * @return _decimals Concatenated corresponding decimals (each as bytes1(uint8(int8))).
     * **NOTE:** decimals might still change for the `current + decimalsUpdateOffset` reward epoch id.
     */
    function getDecimalsBulk(
        bytes memory _feedIds,
        uint256 _rewardEpochId
    )
        external view
        returns (bytes memory _decimals);
}
