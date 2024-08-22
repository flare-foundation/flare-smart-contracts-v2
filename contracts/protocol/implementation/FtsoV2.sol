// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../userInterfaces/IFtsoV2.sol";
import "../../userInterfaces/IFastUpdater.sol";
import "../../userInterfaces/IFastUpdatesConfiguration.sol";
import "../../userInterfaces/IRelayNonPayable.sol";
import "../../utils/implementation/AddressUpdatable.sol";

contract FtsoV2 is IFtsoV2, AddressUpdatable {

    IFastUpdater public fastUpdater;
    IFastUpdatesConfiguration public fastUpdatesConfiguration;
    IRelayNonPayable public relay;

    uint256 public constant FTSO_PROTOCOL_ID = 100;

    constructor(
        address _addressUpdater
    )
        AddressUpdatable(_addressUpdater)
    {
    }

    /**
     * @inheritdoc IFtsoV2
     */
    function getFeedId(uint256 _index) external view returns (bytes21) {
        return fastUpdatesConfiguration.getFeedId(_index);
    }

    /**
     * @inheritdoc IFtsoV2
     */
    function getFeedIndex(bytes21 _feedId) external view returns (uint256) {
        return fastUpdatesConfiguration.getFeedIndex(_feedId);
    }

    /**
     * @inheritdoc IFtsoV2
     */
    function verifyFeedData(FeedDataWithProof calldata _feedData) external returns (bool) {
        bytes32 feedHash = keccak256(abi.encode(_feedData.body));
        require(
            relay.verify(FTSO_PROTOCOL_ID, _feedData.body.votingRoundId, feedHash, _feedData.proof), 
            "merkle proof invalid"
        );
        return true;
    }

    /**
     * @inheritdoc IFtsoV2
     */
    function getFeedByIndex(uint256 _index) external payable returns (uint256, int8, uint64) {
        return _getFeedByIndex(_index);
    }

    /**
     * @inheritdoc IFtsoV2
     */
    function getFeedById(bytes21 _id) external payable returns (uint256, int8, uint64) {
        return _getFeedByIndex(fastUpdatesConfiguration.getFeedIndex(_id));
    }

    /**
     * @inheritdoc IFtsoV2
     */
    function getFeedsByIndex(uint256[] calldata _indices)
        external payable
        returns (
            uint256[] memory,
            int8[] memory,
            uint64
        )
    {
        return fastUpdater.fetchCurrentFeeds{value: msg.value} (_indices);
    }

    /**
     * @inheritdoc IFtsoV2
     */
    function getFeedsById(bytes21[] calldata _feedIds)
        external payable
        returns(
            uint256[] memory,
            int8[] memory,
            uint64
        )
    {
        uint256[] memory indices = new uint256[](_feedIds.length);
        for (uint256 i = 0; i < _feedIds.length; i++) {
            indices[i] = fastUpdatesConfiguration.getFeedIndex(_feedIds[i]);
        }
        return fastUpdater.fetchCurrentFeeds{value: msg.value} (indices);
    }

    /**
     * @inheritdoc IFtsoV2
     */
    function getFeedByIndexInWei(uint256 _index) external payable
        returns (
            uint256 _value,
            uint64 _timestamp
        )
    {
        uint256[] memory indices = new uint256[](1);
        indices[0] = _index;
        uint256[] memory values;
        (values, _timestamp) = _getFeedsByIndexInWei(indices);
        _value = values[0];
    }

    /**
     * @inheritdoc IFtsoV2
     */
    function getFeedByIdInWei(bytes21 _feedId)
        external payable
        returns (
            uint256 _value,
            uint64 _timestamp
        )
    {
        uint256[] memory indices = new uint256[](1);
        indices[0] = fastUpdatesConfiguration.getFeedIndex(_feedId);
        uint256[] memory values;
        (values, _timestamp) = _getFeedsByIndexInWei(indices);
        _value = values[0];
    }

    /**
     * @inheritdoc IFtsoV2
     */
    function getFeedsByIndexInWei(uint256[] calldata _indices)
        external payable
        returns (
            uint256[] memory _values,
            uint64 _timestamp
        )
    {
        return _getFeedsByIndexInWei(_indices);
    }

    /**
     * @inheritdoc IFtsoV2
     */
    function getFeedsByIdInWei(bytes21[] calldata _feedIds)
        external payable
        returns (
            uint256[] memory _values,
            uint64 _timestamp
        )
    {
        uint256[] memory indices = new uint256[](_feedIds.length);
        for (uint256 i = 0; i < _feedIds.length; i++) {
            indices[i] = fastUpdatesConfiguration.getFeedIndex(_feedIds[i]);
        }
        return _getFeedsByIndexInWei(indices);
    }

    function _getFeedByIndex(uint256 _index)
        internal
        returns (
            uint256,
            int8,
            uint64
        )
    {
        uint256[] memory indices = new uint256[](1);
        indices[0] = _index;
        (uint256[] memory values, int8[] memory decimals, uint64 timestamp) =
            fastUpdater.fetchCurrentFeeds{value: msg.value} (indices);
        return (values[0], decimals[0], timestamp);
    }


    function _getFeedsByIndexInWei(uint256[] memory _indices)
        internal
        returns (
            uint256[] memory _values,
            uint64 _timestamp
        )
    {
        int8[] memory decimals;
        (_values, decimals, _timestamp) = fastUpdater.fetchCurrentFeeds{value: msg.value} (_indices);
        for (uint256 i = 0; i < _values.length; i++) {
            int256 decimalsDiff = 18 - decimals[i];
            // value in wei (18 decimals)
            if (decimalsDiff < 0) {
                _values[i] = _values[i] / (10 ** uint256(-decimalsDiff));
            } else {
                _values[i] = _values[i] * (10 ** uint256(decimalsDiff));
            }
        }
    }

    /**
     * Implementation of the AddressUpdatable abstract method.
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal override
    {
        fastUpdater = IFastUpdater(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FastUpdater"));
        fastUpdatesConfiguration = IFastUpdatesConfiguration(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FastUpdatesConfiguration"));
        relay = IRelayNonPayable(_getContractAddress(_contractNameHashes, _contractAddresses, "Relay"));
    }
}