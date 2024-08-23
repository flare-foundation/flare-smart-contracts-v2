// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../userInterfaces/LTS/FtsoV2Interface.sol";
import "../../userInterfaces/IFastUpdater.sol";
import "../../userInterfaces/IFastUpdatesConfiguration.sol";
import "../../userInterfaces/IRelay.sol";
import "../../utils/implementation/AddressUpdatable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract FtsoV2 is FtsoV2Interface, AddressUpdatable {
    using MerkleProof for bytes32[];

    IFastUpdater public fastUpdater;
    IFastUpdatesConfiguration public fastUpdatesConfiguration;
    IRelay public relay;

    uint256 public constant FTSO_PROTOCOL_ID = 100;

    constructor(
        address _addressUpdater
    )
        AddressUpdatable(_addressUpdater)
    {
    }

    /**
     * @inheritdoc FtsoV2Interface
     */
    function getFeedId(uint256 _index) external view returns (bytes21) {
        return fastUpdatesConfiguration.getFeedId(_index);
    }

    /**
     * @inheritdoc FtsoV2Interface
     */
    function getFeedIndex(bytes21 _feedId) external view returns (uint256) {
        return fastUpdatesConfiguration.getFeedIndex(_feedId);
    }

    /**
     * @inheritdoc FtsoV2Interface
     */
    function verifyFeedData(FeedDataWithProof calldata _feedData) external view returns (bool) {
        bytes32 feedHash = keccak256(abi.encode(_feedData.body));
        bytes32 merkleRoot = relay.merkleRoots(FTSO_PROTOCOL_ID, _feedData.body.votingRoundId);
        require(_feedData.proof.verifyCalldata(merkleRoot, feedHash), "merkle proof invalid");
        return true;
    }

    /**
     * @inheritdoc FtsoV2Interface
     */
    function getFeedByIndex(uint256 _index) external payable returns (uint256, int8, uint64) {
        return _getFeedByIndex(_index);
    }

    /**
     * @inheritdoc FtsoV2Interface
     */
    function getFeedById(bytes21 _feedId) external payable returns (uint256, int8, uint64) {
        return _getFeedByIndex(fastUpdatesConfiguration.getFeedIndex(_feedId));
    }

    /**
     * @inheritdoc FtsoV2Interface
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
     * @inheritdoc FtsoV2Interface
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
     * @inheritdoc FtsoV2Interface
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
     * @inheritdoc FtsoV2Interface
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
     * @inheritdoc FtsoV2Interface
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
     * @inheritdoc FtsoV2Interface
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
        relay = IRelay(_getContractAddress(_contractNameHashes, _contractAddresses, "Relay"));
    }
}