// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../lib/AddressHistory.sol";
import "../lib/NodesHistory.sol";
import "../lib/PublicKeyHistory.sol";
import "../interface/IIEntityManager.sol";
import "../interface/IINodePossessionVerifier.sol";
import "../interface/IIPublicKeyVerifier.sol";
import "../../governance/implementation/Governed.sol";

/**
 * Entity manager contract.
 */
contract EntityManager is Governed, IIEntityManager {
    using AddressHistory for AddressHistory.CheckPointHistoryState;
    using NodesHistory for NodesHistory.CheckPointHistoryState;
    using PublicKeyHistory for PublicKeyHistory.CheckPointHistoryState;

    /// Entity data.
    struct Entity {
        AddressHistory.CheckPointHistoryState delegationAddress;
        AddressHistory.CheckPointHistoryState submitAddress;
        AddressHistory.CheckPointHistoryState submitSignaturesAddress;
        AddressHistory.CheckPointHistoryState signingPolicyAddress;
        NodesHistory.CheckPointHistoryState nodeIds;
        PublicKeyHistory.CheckPointHistoryState publicKey;
    }

    /// Initial voter data.
    struct InitialVoterData {
        address voter;
        address delegationAddress;
        bytes20[] nodeIds;
    }

    /// The public key verification contract used in `registerPublicKey` call.
    IIPublicKeyVerifier public publicKeyVerifier;
    /// The node possession verification contract used in `registerNodeId` call.
    IINodePossessionVerifier public nodePossessionVerifier;
    /// Maximum number of node ids per entity.
    uint32 public maxNodeIdsPerEntity;

    mapping(address voter => Entity) internal register; // voter to entity data
    mapping(bytes20 nodeId => AddressHistory.CheckPointHistoryState) internal nodeIdRegistered;
    mapping(bytes32 publicKey => AddressHistory.CheckPointHistoryState) internal publicKeyRegistered;
    mapping(address delegationAddress => AddressHistory.CheckPointHistoryState) internal delegationAddressRegistered;
    mapping(address voter => address delegationAddress) internal delegationAddressRegistrationQueue;
    mapping(address submitAddress => AddressHistory.CheckPointHistoryState) internal submitAddressRegistered;
    mapping(address voter => address submitAddress) internal submitAddressRegistrationQueue;
    mapping(address submitSignaturesAddress =>
        AddressHistory.CheckPointHistoryState) internal submitSignaturesAddressRegistered;
    mapping(address voter => address submitSignaturesAddress) internal submitSignaturesAddressRegistrationQueue;
    mapping(address signingPolicyAddress =>
        AddressHistory.CheckPointHistoryState) internal signingPolicyAddressRegistered;
    mapping(address voter => address signingPolicyAddress) internal signingPolicyAddressRegistrationQueue;


    /**
     * @dev Constructor.
     * @param _governanceSettings The address of the GovernanceSettings contract.
     * @param _initialGovernance The initial governance address.
     * @param _maxNodeIdsPerEntity Maximum number of node ids per entity.
     */
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        uint32 _maxNodeIdsPerEntity
    )
        Governed(_governanceSettings, _initialGovernance)
    {
        maxNodeIdsPerEntity = _maxNodeIdsPerEntity;
        emit MaxNodeIdsPerEntitySet(_maxNodeIdsPerEntity);
    }

    /**
     * @inheritdoc IEntityManager
     */
    function registerNodeId(bytes20 _nodeId, bytes calldata _certificateRaw, bytes calldata _signature) external {
        require(nodeIdRegistered[_nodeId].addressAtNow() == address(0), "node id already registered");
        require(address(nodePossessionVerifier) != address(0), "node id registration not enabled");
        nodePossessionVerifier.verifyNodePossession(msg.sender, _nodeId, _certificateRaw, _signature);
        register[msg.sender].nodeIds.addRemoveNodeId(_nodeId, true, maxNodeIdsPerEntity);
        nodeIdRegistered[_nodeId].setAddress(msg.sender);
        emit NodeIdRegistered(msg.sender, _nodeId);
    }

    /**
     * @inheritdoc IEntityManager
     */
    function unregisterNodeId(bytes20 _nodeId) external {
        require(nodeIdRegistered[_nodeId].addressAtNow() == msg.sender, "node id not registered with msg.sender");
        register[msg.sender].nodeIds.addRemoveNodeId(_nodeId, false, maxNodeIdsPerEntity);
        nodeIdRegistered[_nodeId].setAddress(address(0));
        emit NodeIdUnregistered(msg.sender, _nodeId);
    }

    /**
     * @inheritdoc IEntityManager
     */
    function registerPublicKey(bytes32 _part1, bytes32 _part2, bytes calldata _verificationData) external {
        require(_part1 != bytes32(0) || _part2 != bytes32(0), "public key invalid");
        require(address(publicKeyVerifier) != address(0), "public key registration not enabled");
        publicKeyVerifier.verifyPublicKey(msg.sender, _part1, _part2, _verificationData);
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

    /**
     * @inheritdoc IEntityManager
     */
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

    /**
     * @inheritdoc IEntityManager
     */
    function proposeDelegationAddress(address _delegationAddress) external {
        require(delegationAddressRegistered[_delegationAddress].addressAtNow() == address(0),
            "delegation address already registered");
        delegationAddressRegistrationQueue[msg.sender] = _delegationAddress;
        emit DelegationAddressProposed(msg.sender, _delegationAddress);
    }

    /**
     * @inheritdoc IEntityManager
     */
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

    /**
     * @inheritdoc IEntityManager
     */
    function proposeSubmitAddress(address _submitAddress) external {
        require(submitAddressRegistered[_submitAddress].addressAtNow() == address(0),
            "submit address already registered");
        submitAddressRegistrationQueue[msg.sender] = _submitAddress;
        emit SubmitAddressProposed(msg.sender, _submitAddress);
    }

    /**
     * @inheritdoc IEntityManager
     */
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

    /**
     * @inheritdoc IEntityManager
     */
    function proposeSubmitSignaturesAddress(address _submitSignaturesAddress) external {
        require(submitSignaturesAddressRegistered[_submitSignaturesAddress].addressAtNow() == address(0),
            "submit signatures address already registered");
        submitSignaturesAddressRegistrationQueue[msg.sender] = _submitSignaturesAddress;
        emit SubmitSignaturesAddressProposed(msg.sender, _submitSignaturesAddress);
    }

    /**
     * @inheritdoc IEntityManager
     */
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

    /**
     * @inheritdoc IEntityManager
     */
    function proposeSigningPolicyAddress(address _signingPolicyAddress) external {
        require(signingPolicyAddressRegistered[_signingPolicyAddress].addressAtNow() == address(0),
            "signing policy address already registered");
        signingPolicyAddressRegistrationQueue[msg.sender] = _signingPolicyAddress;
        emit SigningPolicyAddressProposed(msg.sender, _signingPolicyAddress);
    }

    /**
     * @inheritdoc IEntityManager
     */
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

    /**
     * Sets the maximum number of node ids per entity.
     * @param _newMaxNodeIdsPerEntity New maximum number of node ids per entity.
     * @dev Max node ids per entity can only be increased.
     * @dev Only governance can call this method.
     */
    function setMaxNodeIdsPerEntity(uint32 _newMaxNodeIdsPerEntity) external onlyGovernance {
        require(_newMaxNodeIdsPerEntity > maxNodeIdsPerEntity, "can increase only");
        maxNodeIdsPerEntity = _newMaxNodeIdsPerEntity;
        emit MaxNodeIdsPerEntitySet(_newMaxNodeIdsPerEntity);
    }

    /**
     * Sets the public key verification contract.
     * @param _publicKeyVerifier The public key verification contract used in `registerPublicKey`.
     * @dev Only governance can call this method.
     */
    function setPublicKeyVerifier(IIPublicKeyVerifier _publicKeyVerifier) external onlyGovernance {
        publicKeyVerifier = _publicKeyVerifier;
    }

    /**
     * Sets the node possession verification contract.
     * @param _nodePossessionVerifier The node possession verification contract used in `registerNodeId`.
     * @dev Only governance can call this method.
     */
    function setNodePossessionVerifier(IINodePossessionVerifier _nodePossessionVerifier) external onlyGovernance {
        nodePossessionVerifier = _nodePossessionVerifier;
    }

    /**
     * Sets the initial voter data.
     * @param _data Initial voter data list.
     * @dev Only governance can call this method.
     */
    function setInitialVoterData(InitialVoterData[] calldata _data) external onlyGovernance {
        require(!productionMode, "already in production mode");
        uint32 maxNodeIds = maxNodeIdsPerEntity; // load in memory
        for (uint256 i = 0; i < _data.length; i++) {
            InitialVoterData calldata voterData = _data[i];
            require(voterData.voter != address(0), "voter address zero");
            Entity storage entity = register[voterData.voter];
            if (voterData.delegationAddress != address(0)) {
                require(entity.delegationAddress.addressAtNow() == address(0), "delegation address already set");
                require(delegationAddressRegistered[voterData.delegationAddress].addressAtNow() == address(0),
                    "delegation address already registered");
                entity.delegationAddress.setAddress(voterData.delegationAddress);
                delegationAddressRegistered[voterData.delegationAddress].setAddress(voterData.voter);
                emit DelegationAddressProposed(voterData.voter, voterData.delegationAddress);
                emit DelegationAddressRegistrationConfirmed(voterData.voter, voterData.delegationAddress);
            }
            for (uint256 j = 0; j < voterData.nodeIds.length; j++) {
                bytes20 nodeId = voterData.nodeIds[j];
                require(nodeIdRegistered[nodeId].addressAtNow() == address(0), "node id already registered");
                entity.nodeIds.addRemoveNodeId(nodeId, true, maxNodeIds);
                nodeIdRegistered[nodeId].setAddress(voterData.voter);
                emit NodeIdRegistered(voterData.voter, nodeId);
            }
        }
    }

    /**
     * @inheritdoc IEntityManager
     */
    function getDelegationAddressOfAt(
        address _voter,
        uint256 _blockNumber
    )
        external view
        returns(address _delegationAddress)
    {
        _delegationAddress = register[_voter].delegationAddress.addressAt(_blockNumber);
        if (_delegationAddress == address(0)) {
            _delegationAddress = _voter;
        }
    }

    /**
     * @inheritdoc IEntityManager
     */
    function getDelegationAddressOf(address _voter) external view returns(address _delegationAddress) {
        _delegationAddress = register[_voter].delegationAddress.addressAtNow();
        if (_delegationAddress == address(0)) {
            _delegationAddress = _voter;
        }
    }

    /**
     * @inheritdoc IEntityManager
     */
    function getNodeIdsOfAt(address _voter, uint256 _blockNumber) external view returns (bytes20[] memory) {
        return register[_voter].nodeIds.nodeIdsAt(_blockNumber);
    }

    /**
     * @inheritdoc IEntityManager
     */
    function getNodeIdsOf(address _voter) external view returns (bytes20[] memory) {
        return register[_voter].nodeIds.nodeIdsAt(block.number);
    }

    /**
     * @inheritdoc IEntityManager
     */
    function getPublicKeyOfAt(address _voter, uint256 _blockNumber) external view returns(bytes32, bytes32) {
        return register[_voter].publicKey.publicKeyAt(_blockNumber);
    }

    /**
     * @inheritdoc IEntityManager
     */
    function getPublicKeyOf(address _voter) external view returns(bytes32, bytes32) {
        return register[_voter].publicKey.publicKeyAtNow();
    }

    /**
     * @inheritdoc IEntityManager
     */
    function getVoterAddressesAt(address _voter, uint256 _blockNumber)
        external view
        returns (VoterAddresses memory _addresses)
    {
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

    /**
     * @inheritdoc IEntityManager
     */
    function getVoterAddresses(address _voter)
        external view
        returns (VoterAddresses memory _addresses)
    {
        _addresses.submitAddress = register[_voter].submitAddress.addressAtNow();
        if (_addresses.submitAddress == address(0)) {
            _addresses.submitAddress = _voter;
        }

        _addresses.submitSignaturesAddress = register[_voter].submitSignaturesAddress.addressAtNow();
        if (_addresses.submitSignaturesAddress == address(0)) {
            _addresses.submitSignaturesAddress = _voter;
        }

        _addresses.signingPolicyAddress = register[_voter].signingPolicyAddress.addressAtNow();
        if (_addresses.signingPolicyAddress == address(0)) {
            _addresses.signingPolicyAddress = _voter;
        }
    }

    /**
     * @inheritdoc IIEntityManager
     */
    function getDelegationAddresses(address[] memory _voters, uint256 _blockNumber)
        external view
        returns (address[] memory _delegationAddresses)
    {
        uint256 length = _voters.length;
        _delegationAddresses = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            _delegationAddresses[i] = register[_voters[i]].delegationAddress.addressAt(_blockNumber);
            if (_delegationAddresses[i] == address(0)) {
                _delegationAddresses[i] = _voters[i];
            }
        }
    }

    /**
     * @inheritdoc IIEntityManager
     */
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

    /**
     * @inheritdoc IIEntityManager
     */
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

    /**
     * @inheritdoc IIEntityManager
     */
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

    /**
     * @inheritdoc IIEntityManager
     */
    function getPublicKeys(address[] memory _voters, uint256 _blockNumber)
        external view
        returns (bytes32[] memory _parts1, bytes32[] memory _parts2)
    {
        uint256 length = _voters.length;
        _parts1 = new bytes32[](length);
        _parts2 = new bytes32[](length);
        for (uint256 i = 0; i < length; i++) {
            (bytes32 part1, bytes32 part2) = register[_voters[i]].publicKey.publicKeyAt(_blockNumber);
            _parts1[i] = part1;
            _parts2[i] = part2;
        }
    }

    /**
     * @inheritdoc IIEntityManager
     */
    function getNodeIds(address[] memory _voters, uint256 _blockNumber)
        external view
        returns (bytes20[][] memory _nodeIds)
    {
        uint256 length = _voters.length;
        _nodeIds = new bytes20[][](length);
        for (uint256 i = 0; i < length; i++) {
            _nodeIds[i] = register[_voters[i]].nodeIds.nodeIdsAt(_blockNumber);
        }
    }

    /**
     * @inheritdoc IEntityManager
     */
    function getVoterForNodeId(bytes20 _nodeId, uint256 _blockNumber)
        external view
        returns (address _voter)
    {
        _voter = nodeIdRegistered[_nodeId].addressAt(_blockNumber);
    }

    /**
     * @inheritdoc IEntityManager
     */
    function getVoterForPublicKey(bytes32 _part1, bytes32 _part2, uint256 _blockNumber)
        external view
        returns (address _voter)
    {
        bytes32 publicKeyHash = keccak256(abi.encode(_part1, _part2));
        _voter = publicKeyRegistered[publicKeyHash].addressAt(_blockNumber);
    }

    /**
     * @inheritdoc IEntityManager
     */
    function getVoterForDelegationAddress(address _delegationAddress, uint256 _blockNumber)
        external view
        returns (address _voter)
    {
        _voter = delegationAddressRegistered[_delegationAddress].addressAt(_blockNumber);
        if (_voter == address(0)) {
            _voter = _delegationAddress;
        }
    }

    /**
     * @inheritdoc IEntityManager
     */
    function getVoterForSubmitAddress(address _submitAddress, uint256 _blockNumber)
        external view
        returns (address _voter)
    {
        _voter = submitAddressRegistered[_submitAddress].addressAt(_blockNumber);
        if (_voter == address(0)) {
            _voter = _submitAddress;
        }
    }

    /**
     * @inheritdoc IEntityManager
     */
    function getVoterForSubmitSignaturesAddress(address _submitSignaturesAddress, uint256 _blockNumber)
        external view
        returns (address _voter)
    {
        _voter = submitSignaturesAddressRegistered[_submitSignaturesAddress].addressAt(_blockNumber);
        if (_voter == address(0)) {
            _voter = _submitSignaturesAddress;
        }
    }

    /**
     * @inheritdoc IEntityManager
     */
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
