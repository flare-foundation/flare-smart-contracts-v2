// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../lib/AddressHistory.sol";
import "../lib/NodesHistory.sol";
import "../../governance/implementation/Governed.sol";

contract EntityManager is Governed {
    using AddressHistory for AddressHistory.CheckPointHistoryState;
    using NodesHistory for NodesHistory.CheckPointHistoryState;

    struct Entity {
        AddressHistory.CheckPointHistoryState dataProviderAddress;
        AddressHistory.CheckPointHistoryState depositSignaturesAddress;
        AddressHistory.CheckPointHistoryState signingPolicyAddress;
        NodesHistory.CheckPointHistoryState nodeIds;
    }

    struct VoterAddresses {
        address dataProviderAddress;
        address depositSignaturesAddress;
        address signingPolicyAddress;
    }

    uint32 public maxNodeIdsPerEntity;

    mapping(address => Entity) internal register; // voter to entity data
    mapping(bytes20 => AddressHistory.CheckPointHistoryState) internal nodeIdRegistered;
    mapping(address => AddressHistory.CheckPointHistoryState) internal dataProviderAddressRegistered;
    mapping(address => address) internal dataProviderAddressRegistrationQueue;
    mapping(address => AddressHistory.CheckPointHistoryState) internal depositSignaturesAddressRegistered;
    mapping(address => address) internal depositSignaturesAddressRegistrationQueue;
    mapping(address => AddressHistory.CheckPointHistoryState) internal signingPolicyAddressRegistered;
    mapping(address => address) internal signingPolicyAddressRegistrationQueue;

    event NodeIdRegistered(
        address indexed voter, bytes20 indexed nodeId);
    event NodeIdUnregistered(
        address indexed voter, bytes20 indexed nodeId);
    event DataProviderAddressRegistered(
        address indexed voter, address indexed dataProviderAddress);
    event DataProviderAddressRegistrationConfirmed(
        address indexed voter, address indexed dataProviderAddress);
    event DepositSignaturesAddressRegistered(
        address indexed voter, address indexed depositSignaturesAddress);
    event DepositSignaturesAddressRegistrationConfirmed(
        address indexed voter, address indexed depositSignaturesAddress);
    event SigningPolicyAddressRegistered(
        address indexed voter, address indexed signingPolicyAddress);
    event SigningPolicyAddressRegistrationConfirmed(
        address indexed voter, address indexed signingPolicyAddress);
    event MaxNodeIdsPerEntitySet(
        uint256 maxNodeIdsPerEntity);

    constructor(
        IGovernanceSettings _governanceSettings,
        address _governance,
        uint32 _maxNodeIdsPerEntity
    )
        Governed(_governanceSettings, _governance)
    {
        require(_maxNodeIdsPerEntity > 0, "max node ids per entity zero");
        maxNodeIdsPerEntity = _maxNodeIdsPerEntity;
        emit MaxNodeIdsPerEntitySet(_maxNodeIdsPerEntity);
    }

    function registerNodeId(bytes20 _nodeId) external {
        require(nodeIdRegistered[_nodeId].addressAtNow() == address(0), "node id already registered");
        register[msg.sender].nodeIds.addRemoveNodeId(_nodeId, true, maxNodeIdsPerEntity);
        nodeIdRegistered[_nodeId].setAddress(msg.sender);
        emit NodeIdRegistered(msg.sender, _nodeId);
    }

    function unregisterNodeId(bytes20 _nodeId) external {
        require(nodeIdRegistered[_nodeId].addressAtNow() == msg.sender, "node id not registered with msg.sender");
        register[msg.sender].nodeIds.addRemoveNodeId(_nodeId, false, maxNodeIdsPerEntity);
        nodeIdRegistered[_nodeId].setAddress(address(0));
        emit NodeIdUnregistered(msg.sender, _nodeId);
    }

    // msg.sender == voter
    function registerDataProviderAddress(address _dataProviderAddress) external {
        require(dataProviderAddressRegistered[_dataProviderAddress].addressAtNow() == address(0),
            "data provider address already registered");
        dataProviderAddressRegistrationQueue[msg.sender] = _dataProviderAddress;
        emit DataProviderAddressRegistered(msg.sender, _dataProviderAddress);
    }

    // msg.sender == data provider address
    function confirmDataProviderAddressRegistration(address _voter) external {
        require(dataProviderAddressRegistered[msg.sender].addressAtNow() == address(0),
            "data provider address already registered");
        require(dataProviderAddressRegistrationQueue[_voter] == msg.sender,
            "data provider address not in registration queue");
        address oldDataProviderAddress = register[_voter].dataProviderAddress.addressAtNow();
        if (oldDataProviderAddress != address(0)) {
            dataProviderAddressRegistered[oldDataProviderAddress].setAddress(address(0));
        }
        register[_voter].dataProviderAddress.setAddress(msg.sender);
        dataProviderAddressRegistered[msg.sender].setAddress(_voter);
        delete dataProviderAddressRegistrationQueue[_voter];
        emit DataProviderAddressRegistrationConfirmed(_voter, msg.sender);
    }

    // msg.sender == voter
    function registerDepositSignaturesAddress(address _depositSignaturesAddress) external {
        require(depositSignaturesAddressRegistered[_depositSignaturesAddress].addressAtNow() == address(0),
            "deposit signatures address already registered");
        depositSignaturesAddressRegistrationQueue[msg.sender] = _depositSignaturesAddress;
        emit DepositSignaturesAddressRegistered(msg.sender, _depositSignaturesAddress);
    }

    // msg.sender == deposit signatures address
    function confirmDepositSignaturesAddressRegistration(address _voter) external {
        require(depositSignaturesAddressRegistered[msg.sender].addressAtNow() == address(0),
            "deposit signatures address already registered");
        require(depositSignaturesAddressRegistrationQueue[_voter] == msg.sender,
            "deposit signatures address not in registration queue");
        address oldDepositSignaturesAddress = register[_voter].depositSignaturesAddress.addressAtNow();
        if (oldDepositSignaturesAddress != address(0)) {
            depositSignaturesAddressRegistered[oldDepositSignaturesAddress].setAddress(address(0));
        }
        register[_voter].depositSignaturesAddress.setAddress(msg.sender);
        depositSignaturesAddressRegistered[msg.sender].setAddress(_voter);
        delete depositSignaturesAddressRegistrationQueue[_voter];
        emit DepositSignaturesAddressRegistrationConfirmed(_voter, msg.sender);
    }

    // msg.sender == voter
    function registerSigningPolicyAddress(address _signingPolicyAddress) external {
        require(signingPolicyAddressRegistered[_signingPolicyAddress].addressAtNow() == address(0),
            "signing policy address already registered");
        signingPolicyAddressRegistrationQueue[msg.sender] = _signingPolicyAddress;
        emit SigningPolicyAddressRegistered(msg.sender, _signingPolicyAddress);
    }

    // msg.sender == signing address
    function confirmSigningPolicyAddressRegistration(address _voter) external {
        require(signingPolicyAddressRegistered[msg.sender].addressAtNow() == address(0),
            "signing policy address already registered");
        require(signingPolicyAddressRegistrationQueue[_voter] == msg.sender,
            "signing policy address not in registration queue");
        address oldSigningPolicyAddress = register[_voter].signingPolicyAddress.addressAtNow();
        if (oldSigningPolicyAddress != address(0)) {
            signingPolicyAddressRegistered[oldSigningPolicyAddress].setAddress(address(0));
        }
        register[_voter].signingPolicyAddress.setAddress(msg.sender);
        signingPolicyAddressRegistered[msg.sender].setAddress(_voter);
        delete signingPolicyAddressRegistrationQueue[_voter];
        emit SigningPolicyAddressRegistrationConfirmed(_voter, msg.sender);
    }

    function setMaxNodeIdsPerEntity(uint32 _newMaxNodeIdsPerEntity) external onlyGovernance {
        require(_newMaxNodeIdsPerEntity > maxNodeIdsPerEntity, "can increase only");
        maxNodeIdsPerEntity = _newMaxNodeIdsPerEntity;
        emit MaxNodeIdsPerEntitySet(_newMaxNodeIdsPerEntity);
    }

    function getNodeIdsOfAt(address _voter, uint256 _blockNumber) external view returns (bytes20[] memory) {
        return register[_voter].nodeIds.nodeIdsAt(_blockNumber);
    }

    function getNodeIdsOf(address _voter) external view returns (bytes20[] memory) {
        return register[_voter].nodeIds.nodeIdsAt(block.number);
    }

    function getVoterAddresses(address _voter, uint256 _blockNumber)
        external view
        returns (VoterAddresses memory _addresses)
    {
        _addresses.dataProviderAddress = register[_voter].dataProviderAddress.addressAt(_blockNumber);
        if (_addresses.dataProviderAddress == address(0)) {
            _addresses.dataProviderAddress = _voter;
        }

        _addresses.depositSignaturesAddress = register[_voter].depositSignaturesAddress.addressAt(_blockNumber);
        if (_addresses.depositSignaturesAddress == address(0)) {
            _addresses.depositSignaturesAddress = _voter;
        }

        _addresses.signingPolicyAddress = register[_voter].signingPolicyAddress.addressAt(_blockNumber);
        if (_addresses.signingPolicyAddress == address(0)) {
            _addresses.signingPolicyAddress = _voter;
        }
    }

    function getDataProviderAddresses(address[] memory _voters, uint256 _blockNumber)
        external view
        returns (address[] memory _dataProviderAddresses)
    {
        uint256 length = _voters.length;
        _dataProviderAddresses = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            _dataProviderAddresses[i] = register[_voters[i]].dataProviderAddress.addressAt(_blockNumber);
            if (_dataProviderAddresses[i] == address(0)) {
                _dataProviderAddresses[i] = _voters[i];
            }
        }
    }

    function getDepositSignaturesAddresses(address[] memory _voters, uint256 _blockNumber)
        external view
        returns (address[] memory _depositSignaturesAddresses)
    {
        uint256 length = _voters.length;
        _depositSignaturesAddresses = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            _depositSignaturesAddresses[i] = register[_voters[i]].depositSignaturesAddress.addressAt(_blockNumber);
            if (_depositSignaturesAddresses[i] == address(0)) {
                _depositSignaturesAddresses[i] = _voters[i];
            }
        }
    }

    function getSigningPolicyAddresses(address[] memory _voters, uint256 _blockNumber)
        external view
        returns (address[] memory _signingPolicyAddresses)
    {
        uint256 length = _voters.length;
        _signingPolicyAddresses = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            _signingPolicyAddresses[i] = register[_voters[i]].signingPolicyAddress.addressAt(_blockNumber);
            if (_signingPolicyAddresses[i] == address(0)) {
                _signingPolicyAddresses[i] = _voters[i];
            }
        }
    }

    function getVoterForNodeId(bytes20 _nodeId, uint256 _blockNumber)
        external view
        returns (address _voter)
    {
        _voter = nodeIdRegistered[_nodeId].addressAt(_blockNumber);
    }

    function getVoterForDataProviderAddress(address _dataProviderAddress, uint256 _blockNumber)
        external view
        returns (address _voter)
    {
        _voter = dataProviderAddressRegistered[_dataProviderAddress].addressAt(_blockNumber);
        if (_voter == address(0)) {
            _voter = _dataProviderAddress;
        }
    }

    function getVoterForDepositSignaturesAddress(address _depositSignaturesAddress, uint256 _blockNumber)
        external view
        returns (address _voter)
    {
        _voter = depositSignaturesAddressRegistered[_depositSignaturesAddress].addressAt(_blockNumber);
        if (_voter == address(0)) {
            _voter = _depositSignaturesAddress;
        }
    }

    function getVoterForSigningPolicyAddress(address _signingPolicyAddress, uint256 _blockNumber)
        external view
        returns (address _voter)
    {
        _voter = signingPolicyAddressRegistered[_signingPolicyAddress].addressAt(_blockNumber);
        if (_voter == address(0)) {
            _voter = _signingPolicyAddress;
        }
    }
}
