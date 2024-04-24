// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../governance/implementation/Governed.sol";
import "../../utils/implementation/AddressUpdatable.sol";
import "../../userInterfaces/IFastUpdatesConfiguration.sol";
import "../interface/IIFastUpdater.sol";


/**
 * This contract is used to manage the Fast updates configuration.
 */
contract FastUpdatesConfiguration is Governed, AddressUpdatable, IFastUpdatesConfiguration {

    IIFastUpdater public fastUpdater;
    FeedConfiguration[] internal feedConfigurations;
    mapping(bytes21 => uint256) internal feedIdToIndex; // index + 1, to distinguish from 0
    uint256[] internal unusedIndices;


    /**
     * Constructor.
     * @param _governanceSettings The address of the GovernanceSettings contract.
     * @param _initialGovernance The initial governance address.
     * @param _addressUpdater The address of the AddressUpdater contract.
     */
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater
    )
        Governed(_governanceSettings, _initialGovernance) AddressUpdatable(_addressUpdater)
    { }

    /**
     * Allows governance to add new feed configurations.
     * @param _feedConfigs The feed configurations to add.
     * @dev Only governance can call this method.
     */
    function addFeeds(FeedConfiguration[] calldata _feedConfigs) external onlyGovernance {
        uint256[] memory indices = new uint256[](_feedConfigs.length);
        for (uint256 i = 0; i < _feedConfigs.length; i++) {
            bytes21 feedId = _feedConfigs[i].feedId;
            require(feedId != bytes21(0), "invalid feed id");
            require(feedIdToIndex[feedId] == 0, "feed already exists");
            uint256 index;
            if (unusedIndices.length > 0) {
                index = unusedIndices[unusedIndices.length - 1];
                unusedIndices.pop();
            } else {
                index = feedConfigurations.length;
                feedConfigurations.push();
            }
            indices[i] = index;
            feedConfigurations[index] = _feedConfigs[i];
            feedIdToIndex[feedId] = index + 1; // to distinguish from 0
            emit FeedAdded(feedId, _feedConfigs[i].rewardBandValue, _feedConfigs[i].inflationShare, index);
        }
        fastUpdater.resetFeeds(indices);
    }

    /**
     * Allows governance to update feed configurations.
     * @param _feedConfigs The feed configurations to update.
     * @dev Only governance can call this method.
     */
    function updateFeeds(FeedConfiguration[] calldata _feedConfigs) external onlyGovernance {
        for (uint256 i = 0; i < _feedConfigs.length; i++) {
            bytes21 feedId = _feedConfigs[i].feedId;
            require(feedId != bytes21(0), "invalid feed id");
            uint256 index = feedIdToIndex[feedId];
            require(index != 0, "feed does not exist");
            index--;
            feedConfigurations[index] = _feedConfigs[i];
            emit FeedUpdated(feedId, _feedConfigs[i].rewardBandValue, _feedConfigs[i].inflationShare, index);
        }
    }

    /**
     * Allows governance to remove existing feeds.
     * @param _feedIds The feed ids to remove.
     * @dev Only governance can call this method.
     */
    function removeFeeds(bytes21[] calldata _feedIds) external onlyGovernance {
        uint256[] memory indices = new uint256[](_feedIds.length);
        for (uint256 i = 0; i < _feedIds.length; i++) {
            uint256 index = feedIdToIndex[_feedIds[i]];
            require(index != 0, "feed does not exist");
            index--;
            indices[i] = index;
            unusedIndices.push(index);
            delete feedConfigurations[index];
            delete feedIdToIndex[_feedIds[i]];
            emit FeedRemoved(_feedIds[i], index);
        }
        fastUpdater.removeFeeds(indices);
    }

    /**
     * @inheritdoc IFastUpdatesConfiguration
     */
    function getFeedIndex(bytes21 _feedId) external view returns (uint256 _index) {
        _index = feedIdToIndex[_feedId];
        require(_index != 0, "feed does not exist");
        _index--;
    }

    /**
     * @inheritdoc IFastUpdatesConfiguration
     */
    function getFeedId(uint256 _index) external view returns (bytes21 _feedId) {
        require(_index < feedConfigurations.length, "invalid index");
        _feedId = feedConfigurations[_index].feedId;
    }

    /**
     * @inheritdoc IFastUpdatesConfiguration
     */
    function getFeedIds() external view returns (bytes21[] memory _feedIds) {
        uint256 length = feedConfigurations.length;
        _feedIds = new bytes21[](length);
        for (uint256 i = 0; i < length; i++) {
            _feedIds[i] = feedConfigurations[i].feedId;
        }
    }

    /**
     * @inheritdoc IFastUpdatesConfiguration
     */
    function getNumberOfFeeds() external view returns (uint256) {
        return feedConfigurations.length;
    }

    /**
     * @inheritdoc IFastUpdatesConfiguration
     */
    function getFeedConfigurations() external view returns (FeedConfiguration[] memory) {
        return feedConfigurations;
    }

    /**
     * @inheritdoc IFastUpdatesConfiguration
     */
    function getFeedConfigurationsBytes()
        external view
        returns (
            bytes memory _feedIds,
            bytes memory _rewardBandValues,
            bytes memory _inflationShares
        )
    {
        uint256 length = feedConfigurations.length;
        _feedIds = new bytes(length * 21);
        _rewardBandValues = new bytes(length * 4);
        _inflationShares = new bytes(length * 3);
        for (uint256 i = 0; i < length; i++) {
            bytes21 feedId = feedConfigurations[i].feedId;
            bytes4 rewardBandValue = bytes4(feedConfigurations[i].rewardBandValue);
            bytes3 inflationShare = bytes3(feedConfigurations[i].inflationShare);
            for (uint256 j = 0; j < 21; j++) {
                _feedIds[i * 21 + j] = feedId[j];
            }
            for (uint256 j = 0; j < 4; j++) {
                _rewardBandValues[i * 4 + j] = rewardBandValue[j];
            }
            for (uint256 j = 0; j < 3; j++) {
                _inflationShares[i * 3 + j] = inflationShare[j];
            }
        }
    }

    /**
     * @inheritdoc IFastUpdatesConfiguration
     */
    function getUnusedIndices() external view returns (uint256[] memory) {
        return unusedIndices;
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
        fastUpdater = IIFastUpdater(_getContractAddress(_contractNameHashes, _contractAddresses, "FastUpdater"));
    }
}
