// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { FlareUpgradeableBase } from "../../../../governance/implementation/FlareUpgradeableBase.sol";
import { IFlareTeeManager } from "../../../../userInterfaces/tee/IFlareTeeManager.sol";
import { IInstructions } from "../../../../userInterfaces/tee/IInstructions.sol";
import {
    IITeeOracleInstructionsSender
} from "../interface/IITeeOracleInstructionsSender.sol";
import {
    ITeeOracleInstructionsSender,
    TEE_ORACLE_OP_TYPE,
    GET_FEED_COMMAND,
    SET_ENDPOINTS_COMMAND,
    SET_ADMINS_COMMAND,
    GET_FEED_REQUEST_V1
} from "../../../../userInterfaces/tee/ITeeOracleInstructionsSender.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

/**
 * TeeOracleInstructionsSender contract.
 *
 * On-chain entry point for one TEE oracle extension's instructions: permissionless feed
 * observation requests plus governance-published endpoint and admin configuration. The
 * published configuration is committed on-chain (hash + contract-assigned version) BEFORE
 * dispatch, so the matching `TeeOracleFeedStore` only accepts feed updates from machines that
 * prove they run the latest published configuration.
 */
contract TeeOracleInstructionsSender is IITeeOracleInstructionsSender, FlareUpgradeableBase {

    /// The FlareTeeManager Diamond contract.
    IFlareTeeManager public flareTeeManager;

    /// The extension this sender dispatches instructions for.
    uint256 public extensionId;

    /// Version assigned to the most recently published endpoint configuration.
    uint64 public endpointsVersion;
    /// Version assigned to the most recently published admin sets.
    uint64 public adminsVersion;

    /// keccak256 of the last endpoints payload published per machine; the feed store enforces this.
    mapping(address teeId => bytes32) public expectedEndpointsHash;
    /// keccak256 of the last admins payload published per machine; the feed store enforces this.
    mapping(address teeId => bytes32) public expectedAdminsHash;
    /// Endpoints version last published per machine.
    mapping(address teeId => uint64) public expectedEndpointsVersion;
    /// Admins version last published per machine.
    mapping(address teeId => uint64) public expectedAdminsVersion;

    /**
     * Constructor that initializes with invalid parameters to prevent direct deployment/updates.
     */
    constructor() FlareUpgradeableBase() {}

    /**
     * Proxyable initialization method. Can be called only once, from the proxy constructor
     * (single call is assured by the `initializer` modifier).
     * @param _governanceSettings The governance settings contract.
     * @param _initialGovernance The initial governance address.
     * @param _addressUpdater The AddressUpdater contract.
     * @param _extensionId The extension id this sender dispatches instructions for.
     */
    function initialize(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        uint256 _extensionId
    )
        external
        initializer
    {
        FlareUpgradeableBase.initializeBase(_governanceSettings, _initialGovernance, _addressUpdater);
        require(_extensionId != 0, InvalidExtensionId());
        extensionId = _extensionId;
        emit InstructionsSenderInitialised(_extensionId);
    }

    /**
     * @inheritdoc ITeeOracleInstructionsSender
     */
    function requestFeedUpdate()
        external payable
        returns (bytes32 _instructionId)
    {
        address[] memory teeIds = flareTeeManager.getRandomTeeIds(extensionId, 1);
        _instructionId = _sendInstructions(teeIds, GET_FEED_COMMAND, GET_FEED_REQUEST_V1, msg.sender);
        emit FeedUpdateRequested(msg.sender, _instructionId);
    }

    /**
     * @inheritdoc IITeeOracleInstructionsSender
     */
    function setEndpoints(
        address[] calldata _teeIds,
        EndpointGroup[] calldata _groups,
        address _claimBackAddress
    )
        external payable
        onlyGovernance
    {
        _validateTeeIds(_teeIds);
        _validateEndpoints(_groups);

        // One version per publication: every targeted machine shares the same
        // version and payload hash, so the fleet's generations stay comparable.
        endpointsVersion++;
        uint64 version = endpointsVersion;
        bytes memory message = abi.encode(Endpoints({version: version, groups: _groups}));
        bytes32 endpointsHash = keccak256(message);

        // Record the commitments before dispatch so undelivered instructions block stale submissions.
        for (uint256 i = 0; i < _teeIds.length; i++) {
            expectedEndpointsHash[_teeIds[i]] = endpointsHash;
            expectedEndpointsVersion[_teeIds[i]] = version;
            emit EndpointsSet(_teeIds[i], version, endpointsHash);
        }

        _sendInstructions(_teeIds, SET_ENDPOINTS_COMMAND, message, _claimBackAddress);
    }

    /**
     * @inheritdoc IITeeOracleInstructionsSender
     */
    function setAdmins(
        address[] calldata _teeIds,
        AdminRole[] calldata _roles,
        address _claimBackAddress
    )
        external payable
        onlyGovernance
    {
        _validateTeeIds(_teeIds);
        _validateAdminRoles(_roles);

        // One version per publication — see setEndpoints.
        adminsVersion++;
        uint64 version = adminsVersion;
        bytes memory message = abi.encode(Admins({version: version, roles: _roles}));
        bytes32 adminsHash = keccak256(message);

        // Record the commitments before dispatch so undelivered instructions block stale submissions.
        for (uint256 i = 0; i < _teeIds.length; i++) {
            expectedAdminsHash[_teeIds[i]] = adminsHash;
            expectedAdminsVersion[_teeIds[i]] = version;
            emit AdminsSet(_teeIds[i], version, adminsHash);
        }

        _sendInstructions(_teeIds, SET_ADMINS_COMMAND, message, _claimBackAddress);
    }

    /**
     * Updates external contract addresses.
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal override
    {
        flareTeeManager = IFlareTeeManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareTeeManager"));
    }

    /**
     * Dispatches one instruction to the given machines, forwarding the entire msg.value as
     * the fee — the diamond enforces the fee floor and forwards the value to the reward
     * manager, from where fees of unexecuted instructions are claimable to
     * `_claimBackAddress`. For the governance-gated configuration publications the value is
     * attached by the executor via `executeGovernanceCall` (recording rejects value).
     */
    // flareTeeManager is a trusted system contract set via AddressUpdatable, not an arbitrary address.
    //slither-disable-next-line arbitrary-send-eth
    function _sendInstructions(
        address[] memory _teeIds,
        bytes32 _opCommand,
        bytes memory _message,
        address _claimBackAddress
    )
        internal
        returns (bytes32 _instructionId)
    {
        return flareTeeManager.sendInstructions{value: msg.value}(
            _teeIds,
            IInstructions.TeeInstructionParams({
                opType: TEE_ORACLE_OP_TYPE,
                opCommand: _opCommand,
                message: _message,
                cosigners: new address[](0),
                cosignersThreshold: 0,
                claimBackAddress: _claimBackAddress
            })
        );
    }

    /**
     * Requires a non-empty list of unique, non-zero TEE machine ids belonging to this
     * sender's extension.
     */
    function _validateTeeIds(
        address[] calldata _teeIds
    )
        internal view
    {
        require(_teeIds.length > 0, NoTeeIds());
        // The diamond derives the extension from the targeted machines and only checks that
        // this contract is THAT extension's registered sender — and registering a sender on a
        // (foreign) extension requires no consent from the sender contract. Pin the target
        // extension explicitly so commitments and fees can never go to another extension's
        // machines. Checking the first id suffices: the diamond requires all targeted
        // machines to share one extension, and the whole publication is atomic.
        require(flareTeeManager.getExtensionId(_teeIds[0]) == extensionId, TeeIdNotInExtension());
        for (uint256 i = 0; i < _teeIds.length; i++) {
            require(_teeIds[i] != address(0), ZeroTeeId());
            for (uint256 j = 0; j < i; j++) {
                require(_teeIds[j] != _teeIds[i], DuplicateTeeId());
            }
        }
    }

    /**
     * Validates an endpoints payload — tag-agnostic shape rules only. Tag semantics
     * (required groups, URL scheme policy, credential-name policy, private-URL commitment
     * format) are pinned in the TEE extension build. No count caps — transaction size and
     * gas are the natural limit.
     */
    function _validateEndpoints(
        EndpointGroup[] calldata _groups
    )
        internal pure
    {
        require(_groups.length > 0, NoGroups());
        for (uint256 i = 0; i < _groups.length; i++) {
            EndpointGroup calldata group = _groups[i];
            require(group.group != bytes32(0), EmptyGroup());
            for (uint256 j = 0; j < i; j++) {
                require(_groups[j].group != group.group, DuplicateGroup());
            }
            require(group.endpoints.length > 0, NoEndpoints());
            require(group.threshold >= 1 && group.threshold <= group.endpoints.length, InvalidThreshold());
            for (uint256 j = 0; j < group.endpoints.length; j++) {
                _checkEndpoint(group.endpoints[j]);
            }
        }
    }

    /**
     * Validates an admins payload — role-agnostic rules only. Role semantics (which
     * credentials a role governs, role-specific threshold floors, required roles) are
     * pinned in the TEE extension build. No count caps — transaction size and gas are
     * the natural limit.
     */
    function _validateAdminRoles(
        AdminRole[] calldata _roles
    )
        internal pure
    {
        require(_roles.length > 0, NoRoles());
        for (uint256 i = 0; i < _roles.length; i++) {
            AdminRole calldata role = _roles[i];
            require(role.role != bytes32(0), EmptyRole());
            for (uint256 j = 0; j < i; j++) {
                require(_roles[j].role != role.role, DuplicateRole());
            }
            require(role.admins.length > 0, NoAdmins());
            require(role.threshold >= 1 && role.threshold <= role.admins.length, InvalidThreshold());
            for (uint256 j = 0; j < role.admins.length; j++) {
                address admin = role.admins[j];
                require(admin != address(0), ZeroAdmin());
                for (uint256 k = 0; k < j; k++) {
                    require(role.admins[k] != admin, DuplicateAdmin());
                }
            }
        }
    }

    /**
     * Requires kind-consistent endpoint fields. PRIVATE is the special case — it publishes
     * a commitment and no URL; every other kind (PUBLIC today, possible future additions)
     * publishes a URL and no commitment.
     */
    function _checkEndpoint(
        Endpoint calldata _endpoint
    )
        internal pure
    {
        if (_endpoint.kind == EndpointKind.PRIVATE) {
            require(bytes(_endpoint.url).length == 0 && _endpoint.urlHash != bytes32(0), InvalidEndpoint());
        } else {
            require(bytes(_endpoint.url).length > 0 && _endpoint.urlHash == bytes32(0), InvalidEndpoint());
        }
    }
}
