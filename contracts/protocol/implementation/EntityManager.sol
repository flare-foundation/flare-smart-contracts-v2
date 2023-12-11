// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../lib/NodesHistory.sol";
import "../../governance/implementation/Governed.sol";

contract EntityManager is Governed {
    using NodesHistory for NodesHistory.CheckPointHistoryState;

    struct Entity {
        address dataProviderAddress;
        address signingAddress;
        NodesHistory.CheckPointHistoryState nodeIds;
    }

    uint256 public maxNodeIdsPerEntity;

    mapping(address => Entity) internal register; // voter to entity data
    mapping(bytes20 => address) internal nodeIdRegistered;
    mapping(address => address) internal dataProviderAddressRegistered;
    mapping(address => address) internal dataProviderAddressRegistrationQueue;
    mapping(address => address) internal signingAddressRegistered;
    mapping(address => address) internal signingAddressRegistrationQueue;

    event NodeIdRegistered(address indexed voter, bytes20 indexed nodeId);
    event NodeIdUnregistered(address indexed voter, bytes20 indexed nodeId);
    event DataProviderAddressRegistered(address indexed voter, address indexed dataProviderAddress);
    event DataProviderAddressRegistrationConfirmed(address indexed voter, address indexed dataProviderAddress);
    event SigningAddressRegistered(address indexed voter, address indexed signingAddress);
    event SigningAddressRegistrationConfirmed(address indexed voter, address indexed signingAddress);
    event MaxNodeIdsPerEntitySet(uint256 maxNodeIdsPerEntity);

    constructor(
        IGovernanceSettings _governanceSettings,
        address _governance,
        uint256 _maxNodeIdsPerEntity
    )
        Governed(_governanceSettings, _governance)
    {
        require(_maxNodeIdsPerEntity > 0, "max node ids per entity zero");
        maxNodeIdsPerEntity = _maxNodeIdsPerEntity;
        emit MaxNodeIdsPerEntitySet(_maxNodeIdsPerEntity);
    }

    function registerNodeId(bytes20 _nodeId) external {
        require(nodeIdRegistered[_nodeId] == address(0), "node id already registered");
        register[msg.sender].nodeIds.addRemoveNodeId(_nodeId, true, maxNodeIdsPerEntity);
        nodeIdRegistered[_nodeId] = msg.sender;
        emit NodeIdRegistered(msg.sender, _nodeId);
    }

    function unregisterNodeId(bytes20 _nodeId) external {
        require(nodeIdRegistered[_nodeId] == msg.sender, "node id not registered with msg.sender");
        register[msg.sender].nodeIds.addRemoveNodeId(_nodeId, false, maxNodeIdsPerEntity);
        delete nodeIdRegistered[_nodeId];
        emit NodeIdUnregistered(msg.sender, _nodeId);
    }

    // msg.sender == voter
    function registerDataProviderAddress(address _dataProviderAddress) external {
        require(dataProviderAddressRegistered[_dataProviderAddress] == address(0),
            "data provider address already registered");
        dataProviderAddressRegistrationQueue[msg.sender] = _dataProviderAddress;
        emit DataProviderAddressRegistered(msg.sender, _dataProviderAddress);
    }

    // msg.sender == data provider address
    function confirmDataProviderAddressRegistration(address _voter) external {
        require(dataProviderAddressRegistered[msg.sender] == address(0),
            "data provider address already registered");
        require(dataProviderAddressRegistrationQueue[_voter] == msg.sender,
            "data provider address not in registration queue");
        address oldDataProviderAddress = register[_voter].dataProviderAddress;
        if (oldDataProviderAddress != address(0)) {
            delete dataProviderAddressRegistered[oldDataProviderAddress];
        }
        register[_voter].dataProviderAddress = msg.sender;
        dataProviderAddressRegistered[msg.sender] = _voter;
        delete dataProviderAddressRegistrationQueue[_voter];
        emit DataProviderAddressRegistrationConfirmed(_voter, msg.sender);
    }

    // msg.sender == voter
    function registerSigningAddress(address _signingAddress) external {
        require(signingAddressRegistered[_signingAddress] == address(0), "signing address already registered");
        signingAddressRegistrationQueue[msg.sender] = _signingAddress;
        emit SigningAddressRegistered(msg.sender, _signingAddress);
    }

    // msg.sender == signing address
    function confirmSigningAddressRegistration(address _voter) external {
        require(signingAddressRegistered[msg.sender] == address(0), "signing address already registered");
        require(signingAddressRegistrationQueue[_voter] == msg.sender, "signing address not in registration queue");
        address oldSigningAddress = register[_voter].signingAddress;
        if (oldSigningAddress != address(0)) {
            delete signingAddressRegistered[oldSigningAddress];
        }
        register[_voter].signingAddress = msg.sender;
        signingAddressRegistered[msg.sender] = _voter;
        delete signingAddressRegistrationQueue[_voter];
        emit SigningAddressRegistrationConfirmed(_voter, msg.sender);
    }

    function setMaxNodeIdsPerEntity(uint256 _newMaxNodeIdsPerEntity) external onlyGovernance {
        require(_newMaxNodeIdsPerEntity > maxNodeIdsPerEntity, "can increase only");
        maxNodeIdsPerEntity = _newMaxNodeIdsPerEntity;
        emit MaxNodeIdsPerEntitySet(_newMaxNodeIdsPerEntity);
    }

    function getNodeIdsOfAt(address _voter, uint256 _blockNumber) external view returns (bytes20[] memory) {
        return register[_voter].nodeIds.nodeIdsAt(_blockNumber);
    }

    function getSigningAddress(address _voter) external view returns (address _signingAddress) {
        _signingAddress = register[_voter].signingAddress;
        if (_signingAddress == address(0)) {
            _signingAddress = _voter;
        }
    }

    function getDataProviderAddress(address _voter) external view returns (address _dataProviderAddress) {
        _dataProviderAddress = register[_voter].dataProviderAddress;
        if (_dataProviderAddress == address(0)) {
            _dataProviderAddress = _voter;
        }
    }
}
