// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../governance/implementation/Governed.sol";
import "../../utils/implementation/AddressUpdatable.sol";
import "../../userInterfaces/IFlareSystemsManager.sol";
import "../../userInterfaces/IFtsoFeedDecimals.sol";


contract FtsoFeedDecimals is Governed, AddressUpdatable, IFtsoFeedDecimals {

    /// Used for storing feed decimals settings.
    struct Decimals {
        int8 value;                 // number of decimals (negative exponent)
        uint24 validFromEpochId;    // id of the reward epoch from which the value is valid
    }

    /// Used for setting initial feed decimals.
    struct InitialFeedDecimals {
        bytes21 feedId;
        int8 decimals;
    }

    /// The offset in reward epochs for the decimals value to become effective.
    uint24 public immutable decimalsUpdateOffset;
    /// The default decimals value.
    int8 public immutable defaultDecimals;
    //slither-disable-next-line uninitialized-state
    mapping(bytes21 feedId => Decimals[]) internal decimals;

    /// The FlareSystemsManager contract.
    IFlareSystemsManager public flareSystemsManager;

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
        int8 _defaultDecimals,
        uint24 _initialRewardEpochId,
        InitialFeedDecimals[] memory _initialFeedDecimals
    )
        Governed(_governanceSettings, _initialGovernance) AddressUpdatable(_addressUpdater)
    {
        require(_decimalsUpdateOffset > 1, "offset too small");
        decimalsUpdateOffset = _decimalsUpdateOffset;
        defaultDecimals = _defaultDecimals;
        for (uint256 i = 0; i < _initialFeedDecimals.length; i++) {
            InitialFeedDecimals memory ifds = _initialFeedDecimals[i];
            decimals[ifds.feedId].push(Decimals(ifds.decimals, _initialRewardEpochId));
            emit DecimalsChanged(ifds.feedId, ifds.decimals, _initialRewardEpochId);
        }
    }

    /**
     * Allows governance to set (or update last) decimal for given feed id.
     * @param _feedId Feed id.
     * @param _decimals Number of decimals (negative exponent).
     * @dev Only governance can call this method.
     */
    function setDecimals(bytes21 _feedId, int8 _decimals) external onlyGovernance {
        uint24 rewardEpochId = _getCurrentRewardEpochId() + decimalsUpdateOffset;
        Decimals[] storage decimalsForFeedId = decimals[_feedId];

        // determine whether to update the last setting or add a new one
        uint256 position = decimalsForFeedId.length;
        if (position > 0) {
            // do not allow updating the settings in the past
            assert(rewardEpochId >= decimalsForFeedId[position - 1].validFromEpochId);

            if (rewardEpochId == decimalsForFeedId[position - 1].validFromEpochId) {
                // update
                position = position - 1;
            }
        }
        if (position == decimalsForFeedId.length) {
            // add
            decimalsForFeedId.push();
        }

        // apply setting
        decimalsForFeedId[position].value = _decimals;
        decimalsForFeedId[position].validFromEpochId = rewardEpochId;

        emit DecimalsChanged(_feedId, _decimals, rewardEpochId);
    }

    /**
     * @inheritdoc IFtsoFeedDecimals
     */
    function getCurrentDecimals(bytes21 _feedId) external view returns (int8) {
        return _getDecimals(_feedId, _getCurrentRewardEpochId());
    }

    /**
     * @inheritdoc IFtsoFeedDecimals
     */
    function getDecimals(
        bytes21 _feedId,
        uint256 _rewardEpochId
    )
        external view
        returns (int8)
    {
        require(_rewardEpochId <= _getCurrentRewardEpochId() + decimalsUpdateOffset, "invalid reward epoch id");
        return _getDecimals(_feedId, _rewardEpochId);
    }

    /**
     * @inheritdoc IFtsoFeedDecimals
     */
    function getScheduledDecimalsChanges(
        bytes21 _feedId
    )
        external view
        returns (
            int8[] memory _decimals,
            uint256[] memory _validFromEpochId,
            bool[] memory _fixed
        )
    {
        Decimals[] storage decimalsForFeedId = decimals[_feedId];
        if (decimalsForFeedId.length > 0) {
            uint256 currentEpochId = _getCurrentRewardEpochId();
            uint256 position = decimalsForFeedId.length;
            while (position > 0 && decimalsForFeedId[position - 1].validFromEpochId > currentEpochId) {
                position--;
            }
            uint256 count = decimalsForFeedId.length - position;
            if (count > 0) {
                _decimals = new int8[](count);
                _validFromEpochId = new uint256[](count);
                _fixed = new bool[](count);
                for (uint256 i = 0; i < count; i++) {
                    _decimals[i] = decimalsForFeedId[i + position].value;
                    _validFromEpochId[i] = decimalsForFeedId[i + position].validFromEpochId;
                    _fixed[i] = (_validFromEpochId[i] - currentEpochId) != decimalsUpdateOffset;
                }
            }
        }
    }

    /**
     * @inheritdoc IFtsoFeedDecimals
     */
    function getCurrentDecimalsBulk(
        bytes memory _feedIds
    )
        external view
        returns (bytes memory _decimals)
    {
        return _getDecimalsBulk(_feedIds, _getCurrentRewardEpochId());
    }

    /**
     * @inheritdoc IFtsoFeedDecimals
     */
    function getDecimalsBulk(
        bytes memory _feedIds,
        uint256 _rewardEpochId
    )
        external view
        returns (bytes memory _decimals)
    {
        require(_rewardEpochId <= _getCurrentRewardEpochId() + decimalsUpdateOffset, "invalid reward epoch id");
        return _getDecimalsBulk(_feedIds, _rewardEpochId);
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
        flareSystemsManager = IFlareSystemsManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsManager"));
    }

    /**
     * Returns decimals setting for `_feedId` at `_rewardEpochId`.
     * @param _feedId Feed id.
     * @param _rewardEpochId Reward epoch id.
     */
    function _getDecimals(
        bytes21 _feedId,
        uint256 _rewardEpochId
    )
        internal view
        returns (int8)
    {
        Decimals[] storage decimalsForFeedId = decimals[_feedId];
        uint256 index = decimalsForFeedId.length;
        while (index > 0) {
            index--;
            if (_rewardEpochId >= decimalsForFeedId[index].validFromEpochId) {
                return decimalsForFeedId[index].value;
            }
        }
        return defaultDecimals;
    }

    /**
     * Returns decimals setting for `_feedIds` at `_rewardEpochId`.
     * @param _feedIds Concatenated feed ids (each feed id is bytes21).
     * @param _rewardEpochId Reward epoch id.
     */
    function _getDecimalsBulk(
        bytes memory _feedIds,
        uint256 _rewardEpochId
    )
        internal view
        returns (bytes memory _decimals)
    {
        //slither-disable-next-line weak-prng
        require(_feedIds.length % 21 == 0, "invalid _feedIds length");
        uint256 length = _feedIds.length / 21;
        _decimals = new bytes(length);
        bytes memory feedId = new bytes(21);
        for (uint256 i = 0; i < length; i++) {
            for (uint256 j = 0; j < 21; j++) {
                feedId[j] = _feedIds[21 * i + j];
            }
            int8 dec = _getDecimals(bytes21(feedId), _rewardEpochId);
            _decimals[i] = bytes1(uint8(dec));
        }
    }

    /**
     * Returns the current reward epoch id.
     */
    function _getCurrentRewardEpochId() internal view returns(uint24) {
        return flareSystemsManager.getCurrentRewardEpochId();
    }
}
