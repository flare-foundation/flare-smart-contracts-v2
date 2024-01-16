// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../governance/implementation/Governed.sol";
import "../../utils/implementation/AddressUpdatable.sol";
import "../../protocol/implementation/FlareSystemManager.sol";


contract FtsoFeedDecimals is Governed, AddressUpdatable {

    struct Decimals {               // used for storing data provider fee percentage settings
        int8 value;                 // number of decimals (negative exponent)
        uint24 validFromEpochId;    // id of the reward epoch from which the value is valid
    }

    uint24 public immutable decimalsUpdateOffset; // decimals update timelock measured in reward epochs
    int8 public immutable defaultDecimals; // default value for number of decimals
    mapping(bytes8 => Decimals[]) internal decimals;

    FlareSystemManager public flareSystemManager;

    event DecimalsChanged(bytes8 feedName, int8 decimals, uint24 rewardEpochId);

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
     * @param _feedNname feed name
     * @param _decimals number of decimals (negative exponent)
     */
    function setDecimals(bytes8 _feedNname, int8 _decimals) external onlyGovernance {
        uint24 rewardEpochId = flareSystemManager.getCurrentRewardEpochId() + decimalsUpdateOffset;
        Decimals[] storage decimalsForFeedName = decimals[_feedNname];

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

        emit DecimalsChanged(_feedNname, _decimals, rewardEpochId);
    }

    /**
     * Returns current decimals set for `_feedNname`
     * @param _feedNname feed name
     */
    function getCurrentDecimals(bytes8 _feedNname) external view returns (int8) {
        return _getDecimals(_feedNname, flareSystemManager.getCurrentRewardEpochId());
    }

    /**
     * Returns the decimals of `_feedName` for given reward epoch id
     * @param _feedName feed name
     * @param _rewardEpochId reward epoch id
     * **NOTE:** decimals might still change for future reward epoch ids
     */
    function getDecimals(
        bytes8 _feedName,
        uint256 _rewardEpochId
    )
        external view
        returns (int8)
    {
        return _getDecimals(_feedName, _rewardEpochId);
    }

    /**
     * Returns current decimals setting for `_feedNames`.
     * @param _feedNames            concatenated feed names (each feedName bytes8)
     * @return _decimals            concatenated corresponding decimals (each as bytes1(uint8(int8)))
     */
    function getCurrentDecimalsBulk(
        bytes memory _feedNames
    )
        external view
        returns (bytes memory _decimals)
    {
        return _getDecimalsBulk(_feedNames, flareSystemManager.getCurrentRewardEpochId());
    }

    /**
     * Returns decimals setting for `_feedNames` at `_rewardEpochId`.
     * @param _feedNames            concatenated feed names (each feedName bytes8)
     * @param _rewardEpochId        reward epoch id
     * @return _decimals            concatenated corresponding decimals (each as bytes1(uint8(int8)))
     * **NOTE:** decimals might still change for future reward epoch ids
     */
    function getDecimalsBulk(
        bytes memory _feedNames,
        uint256 _rewardEpochId
    )
        external view
        returns (bytes memory _decimals)
    {
        return _getDecimalsBulk(_feedNames, _rewardEpochId);
    }

    /**
     * @notice Implementation of the AddressUpdatable abstract method.
     * @dev It can be overridden if other contracts are needed.
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
     * Returns decimals setting for `_name` at `_rewardEpochId`.
     * @param _name                 name for offer
     * @param _rewardEpochId        reward epoch id
     */
    function _getDecimals(
        bytes8 _name,
        uint256 _rewardEpochId
    )
        internal view
        returns (int8)
    {
        Decimals[] storage decimalsForName = decimals[_name];
        uint256 index = decimalsForName.length;
        while (index > 0) {
            index--;
            if (_rewardEpochId >= decimalsForName[index].validFromEpochId) {
                return decimalsForName[index].value;
            }
        }
        return defaultDecimals;
    }

    /**
     * Returns decimals setting for `_feedNames` at `_rewardEpochId`.
     * @param _feedNames            concatenated feed names (each name bytes8)
     * @param _rewardEpochId        reward epoch id
     */
    function _getDecimalsBulk(
        bytes memory _feedNames,
        uint256 _rewardEpochId
    )
        internal view
        returns (bytes memory _decimals)
    {
        //slither-disable-next-line weak-prng
        assert(_feedNames.length % 8 == 0);
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
}
