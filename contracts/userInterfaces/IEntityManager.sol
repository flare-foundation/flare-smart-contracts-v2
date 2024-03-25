// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * EntityManager interface.
 */
interface IEntityManager {

    /// Voter addresses.
    struct VoterAddresses {
        address submitAddress;
        address submitSignaturesAddress;
        address signingPolicyAddress;
    }

    /// Event emitted when a node id is registered.
    event NodeIdRegistered(
        address indexed voter, bytes20 indexed nodeId);
    /// Event emitted when a node id is unregistered.
    event NodeIdUnregistered(
        address indexed voter, bytes20 indexed nodeId);
    /// Event emitted when a public key is registered.
    event PublicKeyRegistered(
        address indexed voter, bytes32 indexed part1, bytes32 indexed part2);
    /// Event emitted when a public key is unregistered.
    event PublicKeyUnregistered(
        address indexed voter, bytes32 indexed part1, bytes32 indexed part2);
    /// Event emitted when a delegation address is proposed.
    event DelegationAddressProposed(
        address indexed voter, address indexed delegationAddress);
    /// Event emitted when a delegation address registration is confirmed.
    event DelegationAddressRegistrationConfirmed(
        address indexed voter, address indexed delegationAddress);
    /// Event emitted when a submit address is proposed.
    event SubmitAddressProposed(
        address indexed voter, address indexed submitAddress);
    /// Event emitted when a submit address registration is confirmed.
    event SubmitAddressRegistrationConfirmed(
        address indexed voter, address indexed submitAddress);
    /// Event emitted when a submit signatures address is proposed.
    event SubmitSignaturesAddressProposed(
        address indexed voter, address indexed submitSignaturesAddress);
    /// Event emitted when a submit signatures address registration is confirmed.
    event SubmitSignaturesAddressRegistrationConfirmed(
        address indexed voter, address indexed submitSignaturesAddress);
    /// Event emitted when a signing policy address is proposed.
    event SigningPolicyAddressProposed(
        address indexed voter, address indexed signingPolicyAddress);
    /// Event emitted when a signing policy address registration is confirmed.
    event SigningPolicyAddressRegistrationConfirmed(
        address indexed voter, address indexed signingPolicyAddress);
    /// Event emitted when the maximum number of node ids per entity is set.
    event MaxNodeIdsPerEntitySet(
        uint256 maxNodeIdsPerEntity);

    /**
     * Registers a node id.
     * @param _nodeId Node id.
     * @param _certificateRaw Certificate in raw format.
     * @param _signature Signature.
     */
    function registerNodeId(bytes20 _nodeId, bytes calldata _certificateRaw, bytes calldata _signature) external;

    /**
     * Unregisters a node id.
     * @param _nodeId Node id.
     */
    function unregisterNodeId(bytes20 _nodeId) external;

    /**
     * Registers a public key.
     * @param _part1 First part of the public key.
     * @param _part2 Second part of the public key.
     * @param _verificationData Additional data used to verify the public key.
     */
    function registerPublicKey(bytes32 _part1, bytes32 _part2, bytes calldata _verificationData) external;

    /**
     * Unregisters a public key.
     */
    function unregisterPublicKey() external;

    /**
     * Proposes a delegation address (called by the voter).
     * @param _delegationAddress Delegation address.
     */
    function proposeDelegationAddress(address _delegationAddress) external;

    /**
     * Confirms a delegation address registration (called by the delegation address).
     * @param _voter Voter address.
     */
    function confirmDelegationAddressRegistration(address _voter) external;

    /**
     * Proposes a submit address (called by the voter).
     * @param _submitAddress Submit address.
     */
    function proposeSubmitAddress(address _submitAddress) external;

    /**
     * Confirms a submit address registration (called by the submit address).
     * @param _voter Voter address.
     */
    function confirmSubmitAddressRegistration(address _voter) external;

    /**
     * Proposes a submit signatures address (called by the voter).
     * @param _submitSignaturesAddress Submit signatures address.
     */
    function proposeSubmitSignaturesAddress(address _submitSignaturesAddress) external;

    /**
     * Confirms a submit signatures address registration (called by the submit signatures address).
     * @param _voter Voter address.
     */
    function confirmSubmitSignaturesAddressRegistration(address _voter) external;

    /**
     * Proposes a signing policy address (called by the voter).
     * @param _signingPolicyAddress Signing policy address.
     */
    function proposeSigningPolicyAddress(address _signingPolicyAddress) external;

    /**
     * Confirms a signing policy address registration (called by the signing policy address).
     * @param _voter Voter address.
     */
    function confirmSigningPolicyAddressRegistration(address _voter) external;

    /**
     * Gets the delegation address of a voter at a specific block number.
     * @param _voter Voter address.
     * @param _blockNumber Block number.
     * @return Public key.
     */
    function getDelegationAddressOfAt(address _voter, uint256 _blockNumber) external view returns(address);

    /**
     * Gets the delegation address of a voter at the current block number.
     * @param _voter Voter address.
     * @return Public key.
     */
    function getDelegationAddressOf(address _voter) external view returns(address);

    /**
     * Gets the node ids of a voter at a specific block number.
     * @param _voter Voter address.
     * @param _blockNumber Block number.
     * @return Node ids.
     */
    function getNodeIdsOfAt(address _voter, uint256 _blockNumber) external view returns (bytes20[] memory);

    /**
     * Gets the node ids of a voter at the current block number.
     * @param _voter Voter address.
     * @return Node ids.
     */
    function getNodeIdsOf(address _voter) external view returns (bytes20[] memory);

    /**
     * Gets the public key of a voter at a specific block number.
     * @param _voter Voter address.
     * @param _blockNumber Block number.
     * @return Public key.
     */
    function getPublicKeyOfAt(address _voter, uint256 _blockNumber) external view returns(bytes32, bytes32);

    /**
     * Gets the public key of a voter at the current block number.
     * @param _voter Voter address.
     * @return Public key.
     */
    function getPublicKeyOf(address _voter) external view returns(bytes32, bytes32);

    /**
     * Gets voter's addresses at a specific block number.
     * @param _voter Voter address.
     * @param _blockNumber Block number.
     * @return _addresses Voter addresses.
     */
    function getVoterAddressesAt(address _voter, uint256 _blockNumber)
        external view
        returns (VoterAddresses memory _addresses);

    /**
     * Gets voter's addresses at the current block number.
     * @param _voter Voter address.
     * @return _addresses Voter addresses.
     */
    function getVoterAddresses(address _voter)
        external view
        returns (VoterAddresses memory _addresses);

    /**
     * Gets voter's address for a node id at a specific block number.
     * @param _nodeId Node id.
     * @param _blockNumber Block number.
     * @return _voter Voter address.
     */
    function getVoterForNodeId(bytes20 _nodeId, uint256 _blockNumber)
        external view
        returns (address _voter);

    /**
     * Gets voter's address for a public key at a specific block number.
     * @param _part1 First part of the public key.
     * @param _part2 Second part of the public key.
     * @param _blockNumber Block number.
     * @return _voter Voter address.
     */
    function getVoterForPublicKey(bytes32 _part1, bytes32 _part2, uint256 _blockNumber)
        external view
        returns (address _voter);

    /**
     * Gets voter's address for a delegation address at a specific block number.
     * @param _delegationAddress Delegation address.
     * @param _blockNumber Block number.
     * @return _voter Voter address.
     */
    function getVoterForDelegationAddress(address _delegationAddress, uint256 _blockNumber)
        external view
        returns (address _voter);

    /**
     * Gets voter's address for a submit address at a specific block number.
     * @param _submitAddress Submit address.
     * @param _blockNumber Block number.
     * @return _voter Voter address.
     */
    function getVoterForSubmitAddress(address _submitAddress, uint256 _blockNumber)
        external view
        returns (address _voter);

    /**
     * Gets voter's address for a submit signatures address at a specific block number.
     * @param _submitSignaturesAddress Submit signatures address.
     * @param _blockNumber Block number.
     * @return _voter Voter address.
     */
    function getVoterForSubmitSignaturesAddress(address _submitSignaturesAddress, uint256 _blockNumber)
        external view
        returns (address _voter);

    /**
     * Gets voter's address for a signing policy address at a specific block number.
     * @param _signingPolicyAddress Signing policy address.
     * @param _blockNumber Block number.
     * @return _voter Voter address.
     */
    function getVoterForSigningPolicyAddress(address _signingPolicyAddress, uint256 _blockNumber)
        external view
        returns (address _voter);
}
