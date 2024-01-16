// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../utils/implementation/AddressUpdatable.sol";
import "../../protocol/implementation/FlareSystemManager.sol";


contract WNatDelegationFee is AddressUpdatable {

    struct FeePercentage {          // used for storing voter fee percentage settings
        uint16 valueBIPS;           // fee percentage value (value between 0 and 1e4)
        uint24 validFromEpochId;    // id of the reward epoch from which the value is valid
    }

    uint256 constant internal MAX_BIPS = 1e4;

    uint24 public immutable feePercentageUpdateOffset; // fee percentage update timelock measured in reward epochs
    uint16 public immutable defaultFeePercentageBIPS; // default value for fee percentage
    mapping(address => FeePercentage[]) public voterFeePercentages;

    FlareSystemManager public flareSystemManager;

    event FeePercentageChanged(
        address indexed voter,
        uint16 value,
        uint24 validFromEpochId
    );

    constructor(
        address _addressUpdater,
        uint24 _feePercentageUpdateOffset,
        uint16 _defaultFeePercentageBIPS
    )
        AddressUpdatable(_addressUpdater)
    {
        require(_feePercentageUpdateOffset > 1, "offset too small");
        feePercentageUpdateOffset = _feePercentageUpdateOffset;
        defaultFeePercentageBIPS = _defaultFeePercentageBIPS;
    }

    /**
     * Allows voter to set (or update last) fee percentage.
     * @param _feePercentageBIPS    number representing fee percentage in BIPS
     * @return Returns the reward epoch number when the setting becomes effective.
     */
    function setVoterFeePercentage(uint16 _feePercentageBIPS) external returns (uint256) {
        require(_feePercentageBIPS <= MAX_BIPS, "fee percentage invalid");

        uint24 rewardEpochId = flareSystemManager.getCurrentRewardEpochId() + feePercentageUpdateOffset;
        FeePercentage[] storage fps = voterFeePercentages[msg.sender];

        // determine whether to update the last setting or add a new one
        uint256 position = fps.length;
        if (position > 0) {
            // do not allow updating the settings in the past
            assert(rewardEpochId >= fps[position - 1].validFromEpochId);

            if (rewardEpochId == fps[position - 1].validFromEpochId) {
                // update
                position = position - 1;
            }
        }
        if (position == fps.length) {
            // add
            fps.push();
        }

        // apply setting
        fps[position].valueBIPS = _feePercentageBIPS;
        fps[position].validFromEpochId = rewardEpochId;

        emit FeePercentageChanged(msg.sender, _feePercentageBIPS, rewardEpochId);
        return rewardEpochId;
    }


    /**
     * Returns the current fee percentage of `_voter`.
     * @param _voter                address representing voter
     */
    function getVoterCurrentFeePercentage(address _voter) external view returns (uint16) {
        return _getVoterFeePercentage(_voter, flareSystemManager.getCurrentRewardEpochId());
    }

    /**
     * Returns the fee percentage of `_voter` for given reward epoch id.
     * @param _voter                address representing voter
     * @param _rewardEpochId        reward epoch id
     * **NOTE:** fee percentage might still change for future reward epoch ids
     */
    function getVoterFeePercentage(
        address _voter,
        uint256 _rewardEpochId
    )
        external view
        returns (uint16)
    {
        return _getVoterFeePercentage(_voter, _rewardEpochId);
    }

    /**
     * Returns the scheduled fee percentage changes of `_voter`
     * @param _voter                address representing voter
     * @return _feePercentageBIPS   positional array of fee percentages in BIPS
     * @return _validFromEpochId    positional array of block numbers the fee setings are effective from
     * @return _fixed               positional array of boolean values indicating if settings are subjected to change
     */
    function getVoterScheduledFeePercentageChanges(
        address _voter
    )
        external view
        returns (
            uint256[] memory _feePercentageBIPS,
            uint256[] memory _validFromEpochId,
            bool[] memory _fixed
        )
    {
        FeePercentage[] storage fps = voterFeePercentages[_voter];
        if (fps.length > 0) {
            uint256 currentEpochId = flareSystemManager.getCurrentRewardEpochId();
            uint256 position = fps.length;
            while (position > 0 && fps[position - 1].validFromEpochId > currentEpochId) {
                position--;
            }
            uint256 count = fps.length - position;
            if (count > 0) {
                _feePercentageBIPS = new uint256[](count);
                _validFromEpochId = new uint256[](count);
                _fixed = new bool[](count);
                for (uint256 i = 0; i < count; i++) {
                    _feePercentageBIPS[i] = fps[i + position].valueBIPS;
                    _validFromEpochId[i] = fps[i + position].validFromEpochId;
                    _fixed[i] = (_validFromEpochId[i] - currentEpochId) != feePercentageUpdateOffset;
                }
            }
        }
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
     * Returns fee percentage setting for `_voter` at `_rewardEpochId`.
     * @param _voter                address representing a voter
     * @param _rewardEpochId        reward epoch id
     */
    function _getVoterFeePercentage(
        address _voter,
        uint256 _rewardEpochId
    )
        internal view
        returns (uint16)
    {
        FeePercentage[] storage fps = voterFeePercentages[_voter];
        uint256 index = fps.length;
        while (index > 0) {
            index--;
            if (_rewardEpochId >= fps[index].validFromEpochId) {
                return fps[index].valueBIPS;
            }
        }
        return defaultFeePercentageBIPS;
    }
}
