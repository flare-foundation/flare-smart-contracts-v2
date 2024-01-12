// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../lib/AddressHistory.sol";
import "../lib/NodesHistory.sol";
import "../lib/PublicKeyHistory.sol";
import "../../governance/implementation/Governed.sol";

contract EntityManager is Governed {
    using AddressHistory for AddressHistory.CheckPointHistoryState;
    using NodesHistory for NodesHistory.CheckPointHistoryState;
    using PublicKeyHistory for PublicKeyHistory.CheckPointHistoryState;

    struct Entity {
        AddressHistory.CheckPointHistoryState delegationAddress;
        AddressHistory.CheckPointHistoryState submitAddress;
        AddressHistory.CheckPointHistoryState submitSignaturesAddress;
        AddressHistory.CheckPointHistoryState signingPolicyAddress;
        NodesHistory.CheckPointHistoryState nodeIds;
        PublicKeyHistory.CheckPointHistoryState publicKey;
    }

    struct VoterAddresses {
        address delegationAddress;
        address submitAddress;
        address submitSignaturesAddress;
        address signingPolicyAddress;
    }

    uint32 public maxNodeIdsPerEntity;

    mapping(address => Entity) internal register; // voter to entity data
    mapping(bytes20 => AddressHistory.CheckPointHistoryState) internal nodeIdRegistered;
    mapping(bytes32 => AddressHistory.CheckPointHistoryState) internal publicKeyRegistered;
    mapping(address => AddressHistory.CheckPointHistoryState) internal delegationAddressRegistered;
    mapping(address => address) internal delegationAddressRegistrationQueue;
    mapping(address => AddressHistory.CheckPointHistoryState) internal submitAddressRegistered;
    mapping(address => address) internal submitAddressRegistrationQueue;
    mapping(address => AddressHistory.CheckPointHistoryState) internal submitSignaturesAddressRegistered;
    mapping(address => address) internal submitSignaturesAddressRegistrationQueue;
    mapping(address => AddressHistory.CheckPointHistoryState) internal signingPolicyAddressRegistered;
    mapping(address => address) internal signingPolicyAddressRegistrationQueue;

    event NodeIdRegistered(
        address indexed voter, bytes20 indexed nodeId);
    event NodeIdUnregistered(
        address indexed voter, bytes20 indexed nodeId);
    event PublicKeyRegistered(
        address indexed voter, bytes32 indexed part1, bytes32 indexed part2);
    event PublicKeyUnregistered(
        address indexed voter, bytes32 indexed part1, bytes32 indexed part2);
    event DelegationAddressRegistered(
        address indexed voter, address indexed delegationAddress);
    event DelegationAddressRegistrationConfirmed(
        address indexed voter, address indexed delegationAddress);
    event SubmitAddressRegistered(
        address indexed voter, address indexed submitAddress);
    event SubmitAddressRegistrationConfirmed(
        address indexed voter, address indexed submitAddress);
    event SubmitSignaturesAddressRegistered(
        address indexed voter, address indexed submitSignaturesAddress);
    event SubmitSignaturesAddressRegistrationConfirmed(
        address indexed voter, address indexed submitSignaturesAddress);
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

    function registerPublicKey(bytes32 _part1, bytes32 _part2) external {
        require(_part1 != bytes32(0) || _part2 != bytes32(0), "public key invalid");
        bytes32 publicKeyHash = keccak256(abi.encode(_part1, _part2));
        require(publicKeyRegistered[publicKeyHash].addressAtNow() == address(0), "public key already registered");
        (bytes32 oldPart1, bytes32 oldPart2) = register[msg.sender].publicKey.publicKeyAtNow();
        if (oldPart1 != bytes32(0) || oldPart2 != bytes32(0)) {
            bytes32 oldPublicKeyHash = keccak256(abi.encode(oldPart1, oldPart2));
            publicKeyRegistered[oldPublicKeyHash].setAddress(address(0));
            emit PublicKeyUnregistered(msg.sender, oldPart1, oldPart2);
        }
        register[msg.sender].publicKey.setPublicKey(_part1, _part2);
        publicKeyRegistered[publicKeyHash].setAddress(msg.sender);
        emit PublicKeyRegistered(msg.sender, _part1, _part2);
    }

    function unregisterPublicKey() external {
        (bytes32 part1, bytes32 part2) = register[msg.sender].publicKey.publicKeyAtNow();
        if (part1 == bytes32(0) && part2 == bytes32(0)) {
            return;
        }
        bytes32 publicKeyHash = keccak256(abi.encode(part1, part2));
        register[msg.sender].publicKey.setPublicKey(bytes32(0), bytes32(0));
        publicKeyRegistered[publicKeyHash].setAddress(address(0));
        emit PublicKeyUnregistered(msg.sender, part1, part2);
    }

    // msg.sender == voter
    function registerDelegationAddress(address _delegationAddress) external {
        require(delegationAddressRegistered[_delegationAddress].addressAtNow() == address(0),
            "delegation address already registered");
        delegationAddressRegistrationQueue[msg.sender] = _delegationAddress;
        emit DelegationAddressRegistered(msg.sender, _delegationAddress);
    }

    // msg.sender == delegation address
    function confirmDelegationAddressRegistration(address _voter) external {
        require(delegationAddressRegistered[msg.sender].addressAtNow() == address(0),
            "delegation address already registered");
        require(delegationAddressRegistrationQueue[_voter] == msg.sender,
            "delegation address not in registration queue");
        address oldDelegationAddress = register[_voter].delegationAddress.addressAtNow();
        if (oldDelegationAddress != address(0)) {
            delegationAddressRegistered[oldDelegationAddress].setAddress(address(0));
        }
        register[_voter].delegationAddress.setAddress(msg.sender);
        delegationAddressRegistered[msg.sender].setAddress(_voter);
        delete delegationAddressRegistrationQueue[_voter];
        emit DelegationAddressRegistrationConfirmed(_voter, msg.sender);
    }

    // msg.sender == voter
    function registerSubmitAddress(address _submitAddress) external {
        require(submitAddressRegistered[_submitAddress].addressAtNow() == address(0),
            "submit address already registered");
        submitAddressRegistrationQueue[msg.sender] = _submitAddress;
        emit SubmitAddressRegistered(msg.sender, _submitAddress);
    }

    // msg.sender == submit address
    function confirmSubmitAddressRegistration(address _voter) external {
        require(submitAddressRegistered[msg.sender].addressAtNow() == address(0),
            "submit address already registered");
        require(submitAddressRegistrationQueue[_voter] == msg.sender,
            "submit address not in registration queue");
        address oldSubmitAddress = register[_voter].submitAddress.addressAtNow();
        if (oldSubmitAddress != address(0)) {
            submitAddressRegistered[oldSubmitAddress].setAddress(address(0));
        }
        register[_voter].submitAddress.setAddress(msg.sender);
        submitAddressRegistered[msg.sender].setAddress(_voter);
        delete submitAddressRegistrationQueue[_voter];
        emit SubmitAddressRegistrationConfirmed(_voter, msg.sender);
    }

    // msg.sender == voter
    function registerSubmitSignaturesAddress(address _submitSignaturesAddress) external {
        require(submitSignaturesAddressRegistered[_submitSignaturesAddress].addressAtNow() == address(0),
            "submit signatures address already registered");
        submitSignaturesAddressRegistrationQueue[msg.sender] = _submitSignaturesAddress;
        emit SubmitSignaturesAddressRegistered(msg.sender, _submitSignaturesAddress);
    }

    // msg.sender == submit signatures address
    function confirmSubmitSignaturesAddressRegistration(address _voter) external {
        require(submitSignaturesAddressRegistered[msg.sender].addressAtNow() == address(0),
            "submit signatures address already registered");
        require(submitSignaturesAddressRegistrationQueue[_voter] == msg.sender,
            "submit signatures address not in registration queue");
        address oldSubmitSignaturesAddress = register[_voter].submitSignaturesAddress.addressAtNow();
        if (oldSubmitSignaturesAddress != address(0)) {
            submitSignaturesAddressRegistered[oldSubmitSignaturesAddress].setAddress(address(0));
        }
        register[_voter].submitSignaturesAddress.setAddress(msg.sender);
        submitSignaturesAddressRegistered[msg.sender].setAddress(_voter);
        delete submitSignaturesAddressRegistrationQueue[_voter];
        emit SubmitSignaturesAddressRegistrationConfirmed(_voter, msg.sender);
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

    function getPublicKeyOfAt(address _voter, uint256 _blockNumber) external view returns(bytes32, bytes32) {
        return register[_voter].publicKey.publicKeyAt(_blockNumber);
    }

    function getPublicKeyOf(address _voter) external view returns(bytes32, bytes32) {
        return register[_voter].publicKey.publicKeyAtNow();
    }

    function getVoterAddresses(address _voter, uint256 _blockNumber)
        external view
        returns (VoterAddresses memory _addresses)
    {
        _addresses.delegationAddress = register[_voter].delegationAddress.addressAt(_blockNumber);
        if (_addresses.delegationAddress == address(0)) {
            _addresses.delegationAddress = _voter;
        }

        _addresses.submitAddress = register[_voter].submitAddress.addressAt(_blockNumber);
        if (_addresses.submitAddress == address(0)) {
            _addresses.submitAddress = _voter;
        }

        _addresses.submitSignaturesAddress = register[_voter].submitSignaturesAddress.addressAt(_blockNumber);
        if (_addresses.submitSignaturesAddress == address(0)) {
            _addresses.submitSignaturesAddress = _voter;
        }

        _addresses.signingPolicyAddress = register[_voter].signingPolicyAddress.addressAt(_blockNumber);
        if (_addresses.signingPolicyAddress == address(0)) {
            _addresses.signingPolicyAddress = _voter;
        }
    }

    function getSubmitAddresses(address[] memory _voters, uint256 _blockNumber)
        external view
        returns (address[] memory _submitAddresses)
    {
        uint256 length = _voters.length;
        _submitAddresses = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            _submitAddresses[i] = register[_voters[i]].submitAddress.addressAt(_blockNumber);
            if (_submitAddresses[i] == address(0)) {
                _submitAddresses[i] = _voters[i];
            }
        }
    }

    function getSubmitSignaturesAddresses(address[] memory _voters, uint256 _blockNumber)
        external view
        returns (address[] memory _submitSignaturesAddresses)
    {
        uint256 length = _voters.length;
        _submitSignaturesAddresses = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            _submitSignaturesAddresses[i] = register[_voters[i]].submitSignaturesAddress.addressAt(_blockNumber);
            if (_submitSignaturesAddresses[i] == address(0)) {
                _submitSignaturesAddresses[i] = _voters[i];
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

    function getVoterForPublicKey(bytes32 _part1, bytes32 _part2, uint256 _blockNumber)
        external view
        returns (address _voter)
    {
        bytes32 publicKeyHash = keccak256(abi.encode(_part1, _part2));
        _voter = publicKeyRegistered[publicKeyHash].addressAt(_blockNumber);
    }

    function getVoterForSubmitAddress(address _submitAddress, uint256 _blockNumber)
        external view
        returns (address _voter)
    {
        _voter = submitAddressRegistered[_submitAddress].addressAt(_blockNumber);
        if (_voter == address(0)) {
            _voter = _submitAddress;
        }
    }

    function getVoterForSubmitSignaturesAddress(address _submitSignaturesAddress, uint256 _blockNumber)
        external view
        returns (address _voter)
    {
        _voter = submitSignaturesAddressRegistered[_submitSignaturesAddress].addressAt(_blockNumber);
        if (_voter == address(0)) {
            _voter = _submitSignaturesAddress;
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
