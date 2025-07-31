// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./TeeBase.sol";
import "../../userInterfaces/tee/ITeeGovernance.sol";
import "../../userInterfaces/tee/ITeeExtensionRegistry.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * TeeGovernance is used for managing TEE governance.
 */
contract TeeGovernance is ITeeGovernance, TeeBase {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct TeeGovernanceState {
        EnumerableSet.AddressSet signers;
        uint64 signersThreshold;
    }

    struct TeePausingAddressesState {
        EnumerableSet.AddressSet pausingAddresses;
        bytes32 pausingAddressesHash;
        mapping(address => bool) signers;
        Signature[] signatures;
    }

    struct TeeExtensionState {
        /// Next nonce for pausing addresses.
        uint256 nextPausingAddressesNonce;
        mapping(uint256 nonce => TeePausingAddressesState) nonceToTeePausingAddresses;
        mapping(address signer => bool) teePausingAddressesSigner; // any TEE governance signer
        /// The latest TEE governance hash.
        bytes32 latestTeeGovernanceHash;
        mapping(bytes32 governanceHash => TeeGovernanceState) governanceHashToTeeGovernance;
    }

    mapping(uint256 extensionId => TeeExtensionState) private extensionStates;

    /// TEE extension registry contract.
    ITeeExtensionRegistry public teeExtensionRegistry;

    modifier onlyExtensionOwner(uint256 _extensionId) {
        require(
            msg.sender == teeExtensionRegistry.getExtensionOwner(_extensionId),
            "only extension owner"
        );
        _;
    }

    /**
     * Constructor that initializes with invalid parameters to prevent direct deployment/updates.
     */
    constructor() TeeBase() {}

    /**
     * Proxyable initialization method. Can be called only once, from the proxy constructor
     * (single call is assured by GovernedBase.initialise).
     */
    function initialize(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater
    )
        external
    {
        TeeBase.initializeBase(_governanceSettings, _initialGovernance, _addressUpdater);
    }

    /**
     * Sets new TEE governance.
     * @param _signers The new governance signers.
     * @param _signersThreshold The new governance signers threshold.
     * Can only be called by the governance.
     */
    function setNewTeeGovernance(
        uint256 _extensionId,
        address[] calldata _signers,
        uint64 _signersThreshold
    )
        external onlyExtensionOwner(_extensionId)
    {
        TeeExtensionState storage extensionState = extensionStates[_extensionId];
        require(_signers.length > 0, "no signers");
        require(_signersThreshold > 0 && _signersThreshold <= _signers.length, "invalid threshold");
        bytes32 governanceHash = keccak256(abi.encode(_signers, _signersThreshold));
        emit NewTeeGovernanceSet(_extensionId, governanceHash, _signers, _signersThreshold);
        extensionState.latestTeeGovernanceHash = governanceHash;
        TeeGovernanceState storage teeGovernance = extensionState.governanceHashToTeeGovernance[governanceHash];
        if (teeGovernance.signersThreshold > 0) {
            return; // already set - just update the latest governance hash
        }
        teeGovernance.signersThreshold = _signersThreshold;
        for (uint256 i = 0; i < _signers.length; i++) {
            require(teeGovernance.signers.add(_signers[i]), "signer already exists");
            extensionState.teePausingAddressesSigner[_signers[i]] = true;
        }
    }

    /**
     * Sets new TEE pausing addresses.
     * @param _pausingAddresses The list of new pausing addresses, can be empty.
     * Can only be called by the governance.
     */
    function setTeePausingAddresses(
        uint256 _extensionId,
        address[] calldata _pausingAddresses
    )
        external
        onlyExtensionOwner(_extensionId)
    {
        TeeExtensionState storage extensionState = extensionStates[_extensionId];
        uint256 nonce = extensionState.nextPausingAddressesNonce++;
        TeePausingAddressesState storage teePausingAddresses = extensionState.nonceToTeePausingAddresses[nonce];
        for (uint256 i = 0; i < _pausingAddresses.length; i++) {
            require(teePausingAddresses.pausingAddresses.add(_pausingAddresses[i]), "pausing address already exists");
        }
        teePausingAddresses.pausingAddressesHash =
            keccak256(abi.encode("TEE_PAUSING_ADDRESSES", nonce, _pausingAddresses));
        emit NewPausingAddressesSet(_extensionId, nonce, _pausingAddresses);
    }

    /**
     * @inheritdoc ITeeGovernance
     */
    function signTeePausingAddresses(
        uint256 _extensionId,
        uint256 _nonce,
        Signature calldata _signature
    )
        external
    {
        TeeExtensionState storage extensionState = extensionStates[_extensionId];
        require(_nonce < extensionState.nextPausingAddressesNonce, "invalid nonce");
        TeePausingAddressesState storage teePausingAddresses = extensionState.nonceToTeePausingAddresses[_nonce];
        address signer = ECDSA.recover(
            MessageHashUtils.toEthSignedMessageHash(teePausingAddresses.pausingAddressesHash),
            _signature.v,
            _signature.r,
            _signature.s
        );
        require(extensionState.teePausingAddressesSigner[signer], "not a signer");
        require(!teePausingAddresses.signers[signer], "already signed");
        teePausingAddresses.signers[signer] = true;
        teePausingAddresses.signatures.push(_signature);
        emit NewPausingAddressesSigned(_extensionId, _nonce, signer, _signature);
    }

    /**
     * @inheritdoc ITeeGovernance
     */
    function getLatestTeeGovernanceHash(
        uint256 _extensionId
    )
        external view
        returns (bytes32)
    {
        return extensionStates[_extensionId].latestTeeGovernanceHash;
    }

    /**
     * @inheritdoc ITeeGovernance
     */
    function getTeeGovernanceThreshold(
        uint256 _extensionId,
        bytes32 _governanceHash
    )
        external view
        returns (uint64)
    {
        return extensionStates[_extensionId].governanceHashToTeeGovernance[_governanceHash].signersThreshold;
    }

    /**
     * @inheritdoc ITeeGovernance
     */
    function isTeeGovernanceSigner(
        uint256 _extensionId,
        bytes32 _governanceHash,
        address _signer
    )
        external view
        returns (bool)
    {
        return extensionStates[_extensionId].governanceHashToTeeGovernance[_governanceHash].signers.contains(_signer);
    }

    /**
     * @inheritdoc ITeeGovernance
     */
    function getTeeGovernance(
        uint256 _extensionId,
        bytes32 _governanceHash
    )
        external view
        returns(address[] memory _signers, uint64 _signersThreshold)
    {
        return _getGovernance(_extensionId, _governanceHash);
    }

    /**
     * @inheritdoc ITeeGovernance
     */
    function getLatestTeeGovernance(
        uint256 _extensionId
    )
        external view
        returns(address[] memory _signers, uint64 _signersThreshold)
    {
        bytes32 latestTeeGovernanceHash = extensionStates[_extensionId].latestTeeGovernanceHash;
        require(latestTeeGovernanceHash != bytes32(0), "governance not set");
        return _getGovernance(_extensionId, latestTeeGovernanceHash);
    }

    /**
     * @inheritdoc ITeeGovernance
     */
    function isGovernanceHashValid(
        uint256 _extensionId,
        bytes32 _governanceHash
    )
        external view
        returns (bool)
    {
        return extensionStates[_extensionId].governanceHashToTeeGovernance[_governanceHash].signersThreshold > 0;
    }

    /**
     * @inheritdoc ITeeGovernance
     */
    function getTeePausingAddresses(
        uint256 _extensionId,
        uint256 _nonce
    )
        external view
        returns (address[] memory _pausingAddresses, Signature[] memory _signatures)
    {
        require(_nonce < extensionStates[_extensionId].nextPausingAddressesNonce, "invalid nonce");
        return _getTeePausingAddresses(_extensionId, _nonce);
    }

    /**
     * @inheritdoc ITeeGovernance
     */
    function getLatestTeePausingAddresses(
        uint256 _extensionId
    )
        external view
        returns (uint256 _nonce, address[] memory _pausingAddresses, Signature[] memory _signatures)
    {
        TeeExtensionState storage extensionState = extensionStates[_extensionId];
        require(extensionState.nextPausingAddressesNonce > 0, "pausing addresses not set");
        _nonce = extensionState.nextPausingAddressesNonce - 1;
        (_pausingAddresses, _signatures) =  _getTeePausingAddresses(_extensionId, _nonce);
    }

    /**
     * @inheritdoc ITeeGovernance
     */
    function isTeePausingAddressesSigner(
        uint256 _extensionId,
        address _signer
    )
        external view
        returns (bool)
    {
        return extensionStates[_extensionId].teePausingAddressesSigner[_signer];
    }

    /**
     * @inheritdoc ITeeGovernance
     */
    function hasSignedTeePausingAddresses(
        uint256 _extensionId,
        uint256 _nonce,
        address _signer
    )
        external view
        returns (bool)
    {
        TeeExtensionState storage extensionState = extensionStates[_extensionId];
        require(_nonce < extensionState.nextPausingAddressesNonce, "invalid nonce");
        return extensionState.nonceToTeePausingAddresses[_nonce].signers[_signer];
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
        teeExtensionRegistry = ITeeExtensionRegistry(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeExtensionRegistry"));
    }

    function _getGovernance(
        uint256 _extensionId,
        bytes32 _governanceHash
    )
        internal view
        returns(address[] memory _signers, uint64 _signersThreshold)
    {
        TeeExtensionState storage extensionState = extensionStates[_extensionId];
        _signersThreshold = extensionState.governanceHashToTeeGovernance[_governanceHash].signersThreshold;
        require(_signersThreshold > 0, "invalid governance hash");
        _signers = extensionState.governanceHashToTeeGovernance[_governanceHash].signers.values();
    }

    function _getTeePausingAddresses(
        uint256 _extensionId,
        uint256 _nonce
    )
        internal view
        returns (address[] memory _pausingAddresses, Signature[] memory _signatures)
    {
        TeeExtensionState storage extensionState = extensionStates[_extensionId];
        TeePausingAddressesState storage teePausingAddresses = extensionState.nonceToTeePausingAddresses[_nonce];
        _pausingAddresses = teePausingAddresses.pausingAddresses.values();
        _signatures = teePausingAddresses.signatures;
    }
}
