// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../lib/NodesHistory.sol";

contract EntityManager {
    using NodesHistory for NodesHistory.CheckPointHistoryState;

    struct Entity {
        address ftsoAddress;
        address signingAddress;
        NodesHistory.CheckPointHistoryState nodeIds;
    }

    mapping(address => Entity) internal register; // voter to entity data
    mapping(bytes20 => address) internal nodeIdRegistered;
    mapping(address => address) internal ftsoAddressRegistered;
    mapping(address => address) internal ftsoAddressRegistrationQueue;
    mapping(address => address) internal signingAddressRegistered;
    mapping(address => address) internal signingAddressRegistrationQueue;

    function registerNodeId(bytes20 _nodeId) external {
        require(nodeIdRegistered[_nodeId] == address(0), "node id already registered");
        register[msg.sender].nodeIds.addRemoveNodeId(_nodeId, true);
        nodeIdRegistered[_nodeId] = msg.sender;
    }

    function unregisterNodeId(bytes20 _nodeId) external {
        require(nodeIdRegistered[_nodeId] == msg.sender, "node id not registered with msg.sender");
        register[msg.sender].nodeIds.addRemoveNodeId(_nodeId, false);
        delete nodeIdRegistered[_nodeId];
    }

    // msg.sender == voter
    function registerFtsoAddress(address _ftsoAddress) external {
        require(ftsoAddressRegistered[_ftsoAddress] == address(0), "ftso address already registered");
        ftsoAddressRegistrationQueue[msg.sender] = _ftsoAddress;
    }

    // msg.sender == ftso address
    function confirmFtsoAddressRegistration(address _voter) external {
        require(ftsoAddressRegistered[msg.sender] == address(0), "ftso address already registered");
        require(ftsoAddressRegistrationQueue[_voter] == msg.sender, "ftso address not in registration queue");
        address oldFtsoAddress = register[_voter].ftsoAddress;
        if (oldFtsoAddress != address(0)) {
            delete ftsoAddressRegistered[oldFtsoAddress];
        }
        register[_voter].ftsoAddress = msg.sender;
        ftsoAddressRegistered[msg.sender] = _voter;
        delete ftsoAddressRegistrationQueue[_voter];
    }

    // msg.sender == voter
    function registerSigningAddress(address _signingAddress) external {
        require(signingAddressRegistered[_signingAddress] == address(0), "signing address already registered");
        signingAddressRegistrationQueue[msg.sender] = _signingAddress;
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

    function getFtsoAddress(address _voter) external view returns (address _ftsoAddress) {
        _ftsoAddress = register[_voter].ftsoAddress;
        if (_ftsoAddress == address(0)) {
            _ftsoAddress = _voter;
        }
    }
}
