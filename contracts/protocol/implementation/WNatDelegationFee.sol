// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../utils/implementation/AddressUpdatable.sol";
import "../../userInterfaces/IWNatDelegationFee.sol";
import "../../userInterfaces/IFlareSystemManager.sol";


contract WNatDelegationFee is AddressUpdatable, IWNatDelegationFee {

    /// Used for storing voter fee percentage settings.
    struct FeePercentage {
        uint16 valueBIPS;           // fee percentage value (value between 0 and 1e4)
        uint24 validFromEpochId;    // id of the reward epoch from which the value is valid
    }

    uint256 constant internal MAX_BIPS = 1e4;

    /// The offset in reward epochs for the fee percentage value to become effective.
    uint24 public immutable feePercentageUpdateOffset;
    /// The default fee percentage value.
    uint16 public immutable defaultFeePercentageBIPS;
    //slither-disable-next-line uninitialized-state
    mapping(address => FeePercentage[]) internal voterFeePercentages;

    /// The FlareSystemManager contract.
    IFlareSystemManager public flareSystemManager;

    /**
     * Constructor.
     * @param _addressUpdater The address of the AddressUpdater contract.
     * @param _feePercentageUpdateOffset The offset in reward epochs for the fee percentage value to become effective.
     * @param _defaultFeePercentageBIPS The default fee percentage value.
     */
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
     * @inheritdoc IWNatDelegationFee
     */
    function setVoterFeePercentage(uint16 _feePercentageBIPS) external returns (uint256) {
        require(_feePercentageBIPS <= MAX_BIPS, "fee percentage invalid");

        uint24 rewardEpochId = _getCurrentRewardEpochId() + feePercentageUpdateOffset;
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
     * @inheritdoc IWNatDelegationFee
     */
    function getVoterCurrentFeePercentage(address _voter) external view returns (uint16) {
        return _getVoterFeePercentage(_voter, _getCurrentRewardEpochId());
    }

    /**
     * @inheritdoc IWNatDelegationFee
     */
    function getVoterFeePercentage(
        address _voter,
        uint256 _rewardEpochId
    )
        external view
        returns (uint16)
    {
        require(_rewardEpochId <= _getCurrentRewardEpochId() + feePercentageUpdateOffset, "invalid reward epoch id");
        return _getVoterFeePercentage(_voter, _rewardEpochId);
    }

    /**
     * @inheritdoc IWNatDelegationFee
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
            uint256 currentEpochId = _getCurrentRewardEpochId();
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
        flareSystemManager = IFlareSystemManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemManager"));
    }

    /**
     * Returns fee percentage setting for `_voter` at `_rewardEpochId`.
     * @param _voter Voter address.
     * @param _rewardEpochId Reward epoch id.
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

    /**
     * Returns the current reward epoch id.
     */
    function _getCurrentRewardEpochId() internal view returns(uint24) {
        return flareSystemManager.getCurrentRewardEpochId();
    }
}
