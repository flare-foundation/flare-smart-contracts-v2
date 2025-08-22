// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { TeeBase } from "./TeeBase.sol";
import { IITeeMachineRegistry } from "../interface/IITeeMachineRegistry.sol";
import { ITeeExtensionRegistry } from "../../userInterfaces/tee/ITeeExtensionRegistry.sol";
import { ITeeOwnerAllowlist } from "../../userInterfaces/tee/ITeeOwnerAllowlist.sol";
import { ITeeVerification } from "../../userInterfaces/tee/ITeeVerification.sol";
import { ITeeReplication } from "../../userInterfaces/tee/ITeeReplication.sol";
import { ITeeAvailabilityCheck } from "../../userInterfaces/ftdc/ITeeAvailabilityCheck.sol";
import { IRelay } from "../../userInterfaces/IRelay.sol";
import { AddressSet } from "../../utils/lib/AddressSet.sol";
import { IGovernanceSettings } from "flare-smart-contracts/contracts/userInterfaces/IGovernanceSettings.sol";
import { ITeeMachineRegistry } from "../../userInterfaces/tee/ITeeMachineRegistry.sol";
import { AddressUpdatable } from "../../utils/implementation/AddressUpdatable.sol";

/**
 * TeeMachineRegistry is used for registration of TEE machines.
 */
contract TeeMachineRegistry is IITeeMachineRegistry, TeeBase {
    using AddressSet for AddressSet.State;

    struct TeeMachineState {
        uint256 extensionId;
        address initialTeeId;
        uint32 initialSigningPolicyId;
        address owner;
        address teeProxyId; // address of the TEE proxy
        TeeStatus status;
        uint256 lastStatusChangeTs;
        bytes32 codeHash;
        bytes32 platform; // utf8 encoded
        string url;
    }

    bytes32 public constant REG_OP_TYPE = bytes32("F_REG");

    /// TEE extension registry contract.
    ITeeExtensionRegistry public teeExtensionRegistry;
    /// TEE owner allowlist contract.
    ITeeOwnerAllowlist public teeOwnerAllowlist;
    /// TEE verification contract.
    ITeeVerification public teeVerification;
    // TEE replicate contract.
    ITeeReplication public teeReplication;
    /// Relay contract.
    IRelay public relay;

    AddressSet.State private activeTeeIds;
    mapping(uint256 extensionId => AddressSet.State) private extensionActiveTeeIds;
    mapping(address teeId => TeeMachineState) private teeMachineStates;
    /// Proposed new TEE owner.
    mapping(address teeId => address) public proposedTeeOwner;

    modifier onlyOwner(address _teeId) {
        _checkOnlyOwner(_teeId);
        _;
    }

    modifier onlyTeeReplicationContract() {
        require(msg.sender == address(teeReplication), OnlyTeeReplicationContract());
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
     * @inheritdoc ITeeMachineRegistry
     */
    function register(
        uint256 _extensionId,
        address _teeId,
        address _teeProxyId,
        string calldata _url,
        bytes32 _codeHash,
        bytes32 _platform
    )
        external payable
    {
        require(teeOwnerAllowlist.isAllowedTeeMachineOwner(_extensionId, msg.sender), OwnerNotAllowed());
        require(_teeId != address(0), InvalidTeeId());
        require(_teeProxyId != address(0), InvalidTeeProxyId());
        require(bytes(_url).length > 0, InvalidUrl());
        require(teeMachineStates[_teeId].owner == address(0), AlreadyRegistered());
        _checkCodeHashPlatformSupported(_extensionId, _codeHash, _platform);

        teeMachineStates[_teeId] = TeeMachineState({
            extensionId: _extensionId,
            initialTeeId: _teeId,
            initialSigningPolicyId: 0, // temporary value, will be set when TEE machine is put into production
            owner: msg.sender,
            teeProxyId: _teeProxyId,
            status: TeeStatus.INITIALIZED,
            lastStatusChangeTs: block.timestamp,
            codeHash: _codeHash,
            platform: _platform,
            url: _url
        });

        teeVerification.requestTeeAttestation{value: msg.value}(_teeId);
        emit TeeMachineRegistered(_teeId, _teeProxyId, msg.sender, _extensionId, _url, _codeHash, _platform);
    }

    /**
     * @inheritdoc ITeeMachineRegistry
     */
    function toProduction(
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        external
    {
        address teeId = _proof.requestBody.teeId;
        TeeMachineState storage state = teeMachineStates[teeId];
        TeeStatus status = state.status;
        require(
            status == TeeStatus.PAUSED_WITH_PROOF ||
            (status == TeeStatus.INITIALIZED || status == TeeStatus.PAUSED) && msg.sender == state.owner,
            InvalidTeeStatus()
        );
        _checkCodeHashPlatformSupported(state.extensionId, state.codeHash, state.platform);
        _validateAvailabilityCheckStatus(_proof.responseBody.status);
        _validateAvailabilityCheckTs(teeId, _proof.header.timestamp);
        require(teeVerification.verifyAvailabilityCheckProof(_proof), InvalidResponseData());
        if (status == TeeStatus.INITIALIZED) {
            state.initialSigningPolicyId = _proof.responseBody.initialSigningPolicyId;
        }

        state.status = TeeStatus.PRODUCTION;
        state.lastStatusChangeTs = block.timestamp;
        extensionActiveTeeIds[state.extensionId].add(teeId);
        activeTeeIds.add(teeId);
        teeVerification.confirmAvailability(_proof);
        emit TeeMachinePutIntoProduction(teeId);
    }

    /**
     * @inheritdoc ITeeMachineRegistry
     */
    function pause(address _teeId)
        external
    {
        TeeMachineState storage state = teeMachineStates[_teeId];
        _checkTeeStatus(state.status, TeeStatus.PRODUCTION, TeeStatus.PAUSED_WITH_PROOF);
        require(
            msg.sender == state.owner ||
            teeExtensionRegistry.codeHashPlatformDisabled(state.extensionId, state.codeHash, state.platform),
            OnlyOwnerOrDisabledVersion()
        );

        state.status = TeeStatus.PAUSED;
        state.lastStatusChangeTs = block.timestamp;
        extensionActiveTeeIds[state.extensionId].remove(_teeId);
        activeTeeIds.remove(_teeId);
        emit TeeMachinePaused(_teeId, false);
    }

    /**
     * @inheritdoc ITeeMachineRegistry
     */
    function pauseWithProof(
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        external
    {
        address teeId = _proof.requestBody.teeId;
        TeeMachineState storage state = teeMachineStates[teeId];
        _checkTeeStatus(state.status, TeeStatus.PRODUCTION);
        bool responseDataValid = teeVerification.verifyAvailabilityCheckProof(_proof);
        require(
            !responseDataValid ||
            _proof.responseBody.status != ITeeAvailabilityCheck.AvailabilityCheckStatus.OK,
            InvalidResponseDataOrAvailabilityCheckStatus()
        );
        _validateAvailabilityCheckTs(teeId, _proof.header.timestamp);

        state.status = TeeStatus.PAUSED_WITH_PROOF;
        state.lastStatusChangeTs = block.timestamp;
        extensionActiveTeeIds[state.extensionId].remove(teeId);
        activeTeeIds.remove(teeId);
        emit TeeMachinePaused(teeId, true);
    }

    /**
     * @inheritdoc ITeeMachineRegistry
     */
    function proposeNewOwner(address _teeId, address _newOwner)
        external onlyOwner(_teeId)
    {
        uint256 extensionId = teeMachineStates[_teeId].extensionId;
        require(
            _newOwner == address(0) || teeOwnerAllowlist.isAllowedTeeMachineOwner(extensionId, _newOwner),
            OwnerNotAllowed()
        );
        proposedTeeOwner[_teeId] = _newOwner;
        emit NewOwnerProposed(_teeId, msg.sender, _newOwner);
    }

    /**
     * @inheritdoc ITeeMachineRegistry
     */
    function confirmOwnership(address _teeId)
        external
    {
        uint256 extensionId = teeMachineStates[_teeId].extensionId;
        require(teeOwnerAllowlist.isAllowedTeeMachineOwner(extensionId, msg.sender), OwnerNotAllowed());
        require(proposedTeeOwner[_teeId] == msg.sender, OnlyProposedOwner());
        teeMachineStates[_teeId].owner = msg.sender;
        delete proposedTeeOwner[_teeId];
        emit NewOwnerConfirmed(_teeId, msg.sender);
    }

    /**
     * @inheritdoc ITeeMachineRegistry
     */
    function setTeeProxyId(address _teeId, address _teeProxyId)
        external onlyOwner(_teeId)
    {
        require(_teeProxyId != address(0), InvalidTeeProxyId());
        TeeMachineState storage state = teeMachineStates[_teeId];
        state.teeProxyId = _teeProxyId;
        emit TeeProxyIdSet(_teeId, _teeProxyId);
    }

    /**
     * @inheritdoc IITeeMachineRegistry
     */
    function changeStatus(
        address _teeId,
        TeeStatus _newStatus
    )
        external onlyTeeReplicationContract
    {
        TeeMachineState storage state = _getTeeMachineState(_teeId);
        if (_newStatus == TeeStatus.REPLICATING) {
            _checkTeeStatus(state.status, TeeStatus.INITIALIZED, TeeStatus.REPLICATING);
        } else if (_newStatus == TeeStatus.PAUSED_FOR_UPGRADE) {
            _checkTeeStatus(state.status, TeeStatus.PAUSED, TeeStatus.PAUSED_FOR_UPGRADE);
        } else {
            revert InvalidNewStatus();
        }

        state.status = _newStatus;
        state.lastStatusChangeTs = block.timestamp;
    }

    /**
     * @inheritdoc IITeeMachineRegistry
     */
    function replicate(
        address _newTeeId,
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        external onlyTeeReplicationContract
    {
        address oldTeeId = _proof.requestBody.teeId;
        TeeMachineState storage oldState = _getTeeMachineState(oldTeeId);
        TeeMachineState storage newState = _getTeeMachineState(_newTeeId);
        _checkTeeStatus(oldState.status, TeeStatus.PAUSED_FOR_UPGRADE);
        _checkTeeStatus(newState.status, TeeStatus.REPLICATING);
        require(oldState.owner == newState.owner, OwnerMismatch());
        require(oldState.extensionId == newState.extensionId, ExtensionIdMismatch());
        _checkCodeHashPlatformSupported(newState.extensionId, newState.codeHash, newState.platform);
        _validateAvailabilityCheckStatus(_proof.responseBody.status);
        _validateAvailabilityCheckTs(_newTeeId, _proof.header.timestamp);
        // copy TEE machine data from new TEE machine to old TEE machine
        oldState.initialTeeId = newState.initialTeeId;
        oldState.initialSigningPolicyId = newState.initialSigningPolicyId;
        oldState.teeProxyId = newState.teeProxyId;
        oldState.codeHash = newState.codeHash;
        oldState.platform = newState.platform;
        oldState.url = newState.url;
        // delete the new TEE machine state
        delete teeMachineStates[_newTeeId];
        // verify the availability check proof for the updated TEE machine data
        require(teeVerification.verifyAvailabilityCheckProof(_proof), InvalidResponseData());

        // put TEE machine into production
        oldState.status = TeeStatus.PRODUCTION;
        oldState.lastStatusChangeTs = block.timestamp;
        extensionActiveTeeIds[oldState.extensionId].add(oldTeeId);
        activeTeeIds.add(oldTeeId);
        teeVerification.confirmAvailability(_proof);
        emit TeeMachinePutIntoProduction(oldTeeId);
    }

    /**
     * @inheritdoc ITeeMachineRegistry
     */
    function getTeeMachineStatus(address _teeId)
        external view
        returns(TeeStatus)
    {
        TeeMachineState storage state = _getTeeMachineState(_teeId);
        return state.status;
    }

    /**
     * @inheritdoc ITeeMachineRegistry
     */
    function getTeeMachineOwner(address _teeId)
        external view
        returns(address)
    {
        TeeMachineState storage state = _getTeeMachineState(_teeId);
        return state.owner;
    }

    /**
     * @inheritdoc ITeeMachineRegistry
     */
    function getInitialSigningPolicyId(address _teeId)
        external view
        returns (uint32)
    {
        TeeMachineState storage state = _getTeeMachineState(_teeId);
        return state.initialSigningPolicyId;
    }

    /**
     * @inheritdoc ITeeMachineRegistry
     */
    function getTeeMachine(address _teeId)
        external view
        returns(TeeMachine memory _teeMachine)
    {
        TeeMachineState storage state = _getTeeMachineState(_teeId);
        _teeMachine = TeeMachine({
            teeId: _teeId,
            teeProxyId: state.teeProxyId,
            url: state.url
        });
    }

    /**
     * @inheritdoc ITeeMachineRegistry
     */
    function getTeeMachineWithAttestationData(address _teeId)
        external view
        returns(TeeMachineWithAttestationData memory _teeMachine)
    {
        TeeMachineState storage state = _getTeeMachineState(_teeId);
        _teeMachine = _getTeeMachineWithAttestationData(_teeId, state);
    }

    /**
     * @inheritdoc ITeeMachineRegistry
     */
    function getRandomTeeIds(uint256 _extensionId, uint256 _count)
        external view
        returns(address[] memory _teeIds)
    {
        uint256 length = extensionActiveTeeIds[_extensionId].list.length;
        require (_count <= length, TooMany());
        (uint256 randomNumber,,) = relay.getRandomNumber();

        // Reservoir sampling
        uint256[] memory indices = new uint256[](_count);
        for (uint256 i = 0; i < _count; i++) {
            indices[i] = i;
        }
        for (uint256 i = _count; i < length; i++) {
            randomNumber = uint256(keccak256(abi.encode(randomNumber, i)));
            uint256 j = randomNumber % (i + 1);
            if (j < _count) {
                indices[j] = i;
            }
        }

        // Copy tee ids for random indices
        _teeIds = new address[](_count);
        for (uint256 i = 0; i < _count; i++) {
            _teeIds[i] = extensionActiveTeeIds[_extensionId].list[indices[i]];
        }
    }

    /**
     * @inheritdoc ITeeMachineRegistry
     */
    function getAllActiveTeeMachines()
        external view
        returns(address[] memory _teeIds, string[] memory _urls)
    {
        _teeIds = activeTeeIds.list;
        uint256 length = _teeIds.length;
        _urls = new string[](length);
        for (uint256 i = 0; i < length; i++) {
            _urls[i] = teeMachineStates[_teeIds[i]].url;
        }
    }

    /**
     * @inheritdoc ITeeMachineRegistry
     */
    function getActiveTeeMachines(uint256 _extensionId)
        external view
        returns(address[] memory _teeIds, string[] memory _urls)
    {
        _teeIds = extensionActiveTeeIds[_extensionId].list;
        uint256 length = _teeIds.length;
        _urls = new string[](length);
        for (uint256 i = 0; i < length; i++) {
            _urls[i] = teeMachineStates[_teeIds[i]].url;
        }
    }

    /**
     * @inheritdoc ITeeMachineRegistry
     */
    function getExtensionId(address _teeId)
        external view
        returns (uint256)
    {
        TeeMachineState storage state = _getTeeMachineState(_teeId);
        return state.extensionId;
    }

    /**
     * @inheritdoc ITeeMachineRegistry
     */
    function getLastStatusChangeTs(address _teeId)
        external view
        returns (uint256)
    {
        TeeMachineState storage state = _getTeeMachineState(_teeId);
        return state.lastStatusChangeTs;
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
        teeOwnerAllowlist = ITeeOwnerAllowlist(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeOwnerAllowlist"));
        teeVerification = ITeeVerification(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeVerification"));
        teeReplication = ITeeReplication(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeReplication"));
        relay = IRelay(_getContractAddress(_contractNameHashes, _contractAddresses, "Relay"));
    }

    function _validateAvailabilityCheckTs(address _teeId, uint256 _availabilityCheckTs) internal view {
        require(_availabilityCheckTs >= teeMachineStates[_teeId].lastStatusChangeTs, AcTimestampInvalid());
    }

    function _getTeeMachineState(address _teeId) internal view returns(TeeMachineState storage _state) {
        _state = teeMachineStates[_teeId];
        require(_state.owner != address(0), TeeNotFound());
    }

    function _getTeeMachineWithAttestationData(address _teeId, TeeMachineState storage _state)
        internal view
        returns(TeeMachineWithAttestationData memory)
    {
        return TeeMachineWithAttestationData({
            teeId: _teeId,
            initialTeeId: _state.initialTeeId,
            url: _state.url,
            codeHash: _state.codeHash,
            platform: _state.platform
        });
    }

    function _checkCodeHashPlatformSupported(
        uint256 _extensionId,
        bytes32 _codeHash,
        bytes32 _platform
    )
        internal view
    {
        require(
            teeExtensionRegistry.isCodeHashPlatformSupported(_extensionId, _codeHash, _platform),
            VersionNotSupported()
        );
    }

    function _checkOnlyOwner(address _teeId) internal view {
        require(msg.sender == teeMachineStates[_teeId].owner, OnlyOwner());
    }

    function _checkTeeStatus(TeeStatus _actualStatus, TeeStatus _expectedStatus)
        internal pure
    {
        require(_actualStatus == _expectedStatus, InvalidTeeStatus());
    }

    function _checkTeeStatus(TeeStatus _actualStatus, TeeStatus _expectedStatus1, TeeStatus _expectedStatus2)
        internal pure
    {
        require(_actualStatus == _expectedStatus1 || _actualStatus == _expectedStatus2, InvalidTeeStatus());
    }

    function _validateAvailabilityCheckStatus(
        ITeeAvailabilityCheck.AvailabilityCheckStatus _status
    )
        internal pure
    {
        require(_status == ITeeAvailabilityCheck.AvailabilityCheckStatus.OK, InvalidAvailabilityCheckStatus());
    }
}
