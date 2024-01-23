// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../governance/implementation/Governed.sol";
import "../../utils/implementation/AddressUpdatable.sol";
import "../../protocol/implementation/FlareSystemManager.sol";


contract FtsoFeedDecimals is Governed, AddressUpdatable {

    /// Used for storing feed decimals settings.
    struct Decimals {
        int8 value;                 // number of decimals (negative exponent)
        uint24 validFromEpochId;    // id of the reward epoch from which the value is valid
    }

    /// The offset in reward epochs for the decimals value to become effective.
    uint24 public immutable decimalsUpdateOffset;
    /// The default decimals value.
    int8 public immutable defaultDecimals;
    //slither-disable-next-line uninitialized-state
    mapping(bytes8 => Decimals[]) internal decimals;

    /// The FlareSystemManager contract.
    FlareSystemManager public flareSystemManager;

    /// Event emitted when a feed decimals value is changed.
    event DecimalsChanged(bytes8 feedName, int8 decimals, uint24 rewardEpochId);

    /**
     * Constructor.
     * @param _governanceSettings The address of the GovernanceSettings contract.
     * @param _initialGovernance The initial governance address.
     * @param _addressUpdater The address of the AddressUpdater contract.
     * @param _decimalsUpdateOffset The offset in reward epochs for the decimals value to become effective.
     * @param _defaultDecimals The default decimals value.
     */
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        uint24 _decimalsUpdateOffset,
        int8 _defaultDecimals
    )
        Governed(_governanceSettings, _initialGovernance) AddressUpdatable(_addressUpdater)
    {
        require(_decimalsUpdateOffset > 1, "offset too small");
        decimalsUpdateOffset = _decimalsUpdateOffset;
        defaultDecimals = _defaultDecimals;
    }

    /**
     * Allows governance to set (or update last) decimal for given feed name.
     * @param _feedName Feed name.
     * @param _decimals Number of decimals (negative exponent).
     * @dev Only governance can call this method.
     */
    function setDecimals(bytes8 _feedName, int8 _decimals) external onlyGovernance {
        uint24 rewardEpochId = _getCurrentRewardEpochId() + decimalsUpdateOffset;
        Decimals[] storage decimalsForFeedName = decimals[_feedName];

        // determine whether to update the last setting or add a new one
        uint256 position = decimalsForFeedName.length;
        if (position > 0) {
            // do not allow updating the settings in the past
            assert(rewardEpochId >= decimalsForFeedName[position - 1].validFromEpochId);

            if (rewardEpochId == decimalsForFeedName[position - 1].validFromEpochId) {
                // update
                position = position - 1;
            }
        }
        if (position == decimalsForFeedName.length) {
            // add
            decimalsForFeedName.push();
        }

        // apply setting
        decimalsForFeedName[position].value = _decimals;
        decimalsForFeedName[position].validFromEpochId = rewardEpochId;

        emit DecimalsChanged(_feedName, _decimals, rewardEpochId);
    }

    /**
     * Returns current decimals set for `_feedName`.
     * @param _feedName Feed name.
     */
    function getCurrentDecimals(bytes8 _feedName) external view returns (int8) {
        return _getDecimals(_feedName, _getCurrentRewardEpochId());
    }

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
        returns (int8)
    {
        require(_rewardEpochId <= _getCurrentRewardEpochId() + decimalsUpdateOffset, "invalid reward epoch id");
        return _getDecimals(_feedName, _rewardEpochId);
    }

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
        )
    {
        Decimals[] storage decimalsForFeedName = decimals[_feedName];
        if (decimalsForFeedName.length > 0) {
            uint256 currentEpochId = _getCurrentRewardEpochId();
            uint256 position = decimalsForFeedName.length;
            while (position > 0 && decimalsForFeedName[position - 1].validFromEpochId > currentEpochId) {
                position--;
            }
            uint256 count = decimalsForFeedName.length - position;
            if (count > 0) {
                _decimals = new int8[](count);
                _validFromEpochId = new uint256[](count);
                _fixed = new bool[](count);
                for (uint256 i = 0; i < count; i++) {
                    _decimals[i] = decimalsForFeedName[i + position].value;
                    _validFromEpochId[i] = decimalsForFeedName[i + position].validFromEpochId;
                    _fixed[i] = (_validFromEpochId[i] - currentEpochId) != decimalsUpdateOffset;
                }
            }
        }
    }

    /**
     * Returns current decimals setting for `_feedNames`.
     * @param _feedNames Concatenated feed names (each feedName bytes8).
     * @return _decimals Concatenated corresponding decimals (each as bytes1(uint8(int8))).
     */
    function getCurrentDecimalsBulk(
        bytes memory _feedNames
    )
        external view
        returns (bytes memory _decimals)
    {
        return _getDecimalsBulk(_feedNames, _getCurrentRewardEpochId());
    }

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
        returns (bytes memory _decimals)
    {
        require(_rewardEpochId <= _getCurrentRewardEpochId() + decimalsUpdateOffset, "invalid reward epoch id");
        return _getDecimalsBulk(_feedNames, _rewardEpochId);
    }

    /**
     * @inheritdoc AddressUpdatable
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal override
    {
        flareSystemManager = FlareSystemManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemManager"));
    }

    /**
     * Returns decimals setting for `_feedName` at `_rewardEpochId`.
     * @param _feedName Feed name.
     * @param _rewardEpochId Reward epoch id.
     */
    function _getDecimals(
        bytes8 _feedName,
        uint256 _rewardEpochId
    )
        internal view
        returns (int8)
    {
        Decimals[] storage decimalsForFeedName = decimals[_feedName];
        uint256 index = decimalsForFeedName.length;
        while (index > 0) {
            index--;
            if (_rewardEpochId >= decimalsForFeedName[index].validFromEpochId) {
                return decimalsForFeedName[index].value;
            }
        }
        return defaultDecimals;
    }

    /**
     * Returns decimals setting for `_feedNames` at `_rewardEpochId`.
     * @param _feedNames Concatenated feed names (each name bytes8).
     * @param _rewardEpochId Reward epoch id.
     */
    function _getDecimalsBulk(
        bytes memory _feedNames,
        uint256 _rewardEpochId
    )
        internal view
        returns (bytes memory _decimals)
    {
        //slither-disable-next-line weak-prng
        require(_feedNames.length % 8 == 0, "invalid _feedNames length");
        uint256 length = _feedNames.length / 8;
        _decimals = new bytes(length);
        bytes memory feedName = new bytes(8);
        for (uint256 i = 0; i < length; i++) {
            for (uint256 j = 0; j < 8; j++) {
                feedName[j] = _feedNames[8 * i + j];
            }
            int8 dec = _getDecimals(bytes8(feedName), _rewardEpochId);
            _decimals[i] = bytes1(uint8(dec));
        }
    }

    /**
     * Returns the current reward epoch id.
     */
    function _getCurrentRewardEpochId() internal view returns(uint24) {
        return flareSystemManager.getCurrentRewardEpochId();
    }
}
