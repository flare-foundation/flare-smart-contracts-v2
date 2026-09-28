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
    SET_ADMINS_COMMAND
} from "../../../../userInterfaces/tee/ITeeOracleInstructionsSender.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

/**
 * TeeOracleInstructionsSender contract.
 *
 * On-chain entry point for one TEE oracle extension's instructions: permissionless feed
 * observation requests plus governance-published endpoint and admin configuration, both
 * kept per feed — one sender serves every feed of the extension, so one machine fleet can
 * serve multiple oracles.
 *
 * Configuration is published by Flare governance and delivered by an instruction:
 * - `setEndpoints` / `setAdmins` PUBLISH a feed's latest configuration: validate, take the
 *   feed's next consecutive version (derived when the call EXECUTES — see the ordering note on
 *   `setEndpoints`), store only the encoded payload's HASH (the payload itself is logged, never stored —
 *   see below), then dispatch it VERBATIM to the extension's live active set, with the non-zero
 *   claim-back address governance named as the instruction's PAYER OF RECORD — the executed body's
 *   `msg.sender` is this contract, so the payer cannot be identified on chain and has to be
 *   stated. It is recorded in `TeeInstructionsSent`; a refund, if the off-chain reward
 *   calculation grants one, is claimed later through the `RewardManager` like any other reward.
 *   The targets are resolved INSIDE the body, never taken as a parameter: a
 *   governance call's arguments are frozen when the timelocked call is recorded, while the fleet's
 *   composition is only known when the executor runs it, so a target list in the signature makes
 *   a publication unexecutable whenever one named machine restarted, was paused or was re-keyed
 *   during the timelock. Reading `getActiveTeeMachines` in the body is a snapshot of the
 *   executing block, so publication and DISPATCH happen in one transaction; ADOPTION is off chain
 *   and lags it, and until enough machines have adopted, the store rejects updates that still
 *   carry the previous generation. That set
 *   needs no filtering: `MachineManager` maintains it as exactly the extension's PRODUCTION
 *   machines, so it carries no duplicate, no zero address and no foreign-extension id by
 *   construction, and a fresh version is new to every machine in it.
 *   Only the two cases where no dispatch is possible AT ALL skip delivery — the extension is
 *   emergency paused, or its active set is empty — and there the values are published and
 *   delivery is left to the push ("published, push later"). That skip is not free: the publication
 *   is final the moment it lands, so the feed store immediately rejects every machine still on the
 *   previous generation, and `requestFeedUpdate` rejects them too (their per-machine record is only
 *   advanced on the dispatching path). The feed stops updating and cannot even be ASKED to update
 *   until someone calls `pushEndpoints` / `pushAdmins` with the payload from the publication event
 *   and pays the fleet-wide instruction fee; unpausing alone does not restore it. Treat such a
 *   publication as requiring an immediate follow-up push.
 *   When a dispatch does happen the whole
 *   `msg.value` is forwarded and the diamond's floor (`FeeTooLow`) is the only fee gate: a short
 *   fee reverts there and is retryable, and whatever is attached reaches the reward manager in
 *   full, so the executor reads `get*PublicationFee` in the executing block and attaches
 *   that. Everything the executor CAN fix
 *   reverts, and reverting is cheap: `executeGovernanceCall` bubbles the revert, which rolls
 *   back its own deletion of the timelock entry, so the pending call survives and is
 *   re-executable in the next block with no re-proposal.
 * - `pushEndpoints` / `pushAdmins` let ANYONE deliver a published version to the machines they
 *   name, paying the instruction fee and SUPPLYING the configuration values, which this contract
 *   re-encodes with the version it holds and checks against the stored hash
 *   (`WrongConfigPayload`). The list is validated exactly as `requestFeedUpdate`
 *   validates its own (non-empty, non-zero, unique, on this extension) and then dispatched as
 *   given; a target that is not in PRODUCTION is left for the diamond to reject, so the call
 *   reverts instead of quietly dropping a machine the caller paid for. This is how a machine
 *   registered after a publication converges and how an instruction that never reached its
 *   enclave is retried; a re-push rewrites the same version idempotently.
 *   `getEndpointsPushTargets` / `getAdminsPushTargets` build the straggler list to pass in.
 *
 * Only the payload's HASH is kept on chain; the payload lives in the `EndpointsPublished` /
 * `AdminsPublished` log, which carries the published groups / roles as typed arrays — exactly what
 * the push takes back, the wrapper's other fields being the event's own topics.
 * Storing the encoded payload cost
 * ~217,000 gas per PUBLIC endpoint — 96% of a publication — which put a 25-group / 5-endpoint
 * configuration (48.2 KB) at ~30.5M gas, above the 28,000,000 block gas limit on flare, songbird,
 * coston2 and coston. Supplying it as calldata instead costs ~8,000 gas per endpoint, so the same
 * configuration publishes at ~1.95M gas — a ~16x reduction, bought at the price of a
 * log-retention dependency (a payload nobody kept is unpushable until governance republishes).
 * That is why the publication event carries the full payload UNCONDITIONALLY: when the dispatch is
 * skipped, nothing else logs it.
 * The push takes the payload's FIELDS, not raw bytes: hash equality then does not depend on the
 * caller's ABI encoder reproducing the published bytes, and the version cannot be supplied at all
 * — it is read from storage, exactly as the publication assigned it.
 *
 * What the feed's `TeeOracleFeedStore` enforces on a submitted feed update is the FEED-level
 * `latestEndpointsHash` / `latestAdminsHash`, not a per-machine record: a publication therefore
 * invalidates every machine still running the previous generation until it adopts the new one.
 * The per-machine `expectedEndpointsVersion` / `expectedAdminsVersion` records only what was
 * DISPATCHED — they answer "which machines still need a push" and gate `requestFeedUpdate`.
 */
contract TeeOracleInstructionsSender is IITeeOracleInstructionsSender, FlareUpgradeableBase {

    /// The FlareTeeManager Diamond contract.
    IFlareTeeManager public flareTeeManager;

    /// The extension this sender dispatches instructions for.
    uint256 public extensionId;

    /// A feed's published configuration for both kinds: hashes, versions and publication
    /// timestamps, packed into three slots. `internal` with explicit getters rather than
    /// `public`, so the individual accessors declared on the interface keep their names.
    mapping(bytes21 feedId => FeedConfig) internal feedConfigs;

    /// The versions last DISPATCHED per feed and machine, both kinds in one slot. The only
    /// per-machine configuration record kept: it answers "which machines still need a push" and
    /// gates `requestFeedUpdate`, which reads both kinds of a target with one cold SLOAD. What
    /// the feed store enforces is the feed-level `FeedConfig.endpointsHash` / `.adminsHash`.
    mapping(bytes21 feedId => mapping(address teeId => MachineVersions)) internal machineVersions;

    /// Every feed id with both configuration kinds (endpoints and admins) published,
    /// append-only. Enumerable so a dashboard can list the extension's feeds without
    /// an indexer.
    bytes21[] internal feedIds;

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
        // `AddressUpdatable.setAddressUpdaterValue` does not check this, and a zero updater
        // cannot be corrected through the normal path: `updateContractAddresses` is gated on
        // `msg.sender == addressUpdater`, so `flareTeeManager` would stay unset and every
        // publication, push and request would revert. Only a governance UUPS upgrade to an
        // implementation that rewrites the slot could recover it.
        require(_addressUpdater != address(0), ZeroAddressUpdater());
        require(_extensionId != 0, InvalidExtensionId());
        extensionId = _extensionId;
        emit InstructionsSenderInitialised(_extensionId);
    }

    /**
     * @inheritdoc ITeeOracleInstructionsSender
     */
    function requestFeedUpdate(
        bytes21 _feedId,
        address[] calldata _teeIds
    )
        external payable
        returns (bytes32 _instructionId)
    {
        require(_feedId != bytes21(0), InvalidFeedId());
        _validateTeeIds(_teeIds);
        // Only machines at the feed's LATEST generation are asked: the store gates submissions
        // on the feed-level hash, so a lagging machine's answer would be rejected outright.
        // The feed's own versions are read ONCE here rather than per target — including the
        // both-kinds-published check, so an unpublished feed fails before the loop.
        FeedConfig storage config = feedConfigs[_feedId];
        uint64 endpoints = config.endpointsVersion;
        uint64 admins = config.adminsVersion;
        // A feed-level condition, so it gets a feed-level error: the two cases need opposite
        // remedies - wait for a governance publication, versus push the published version to the
        // machine - and `TeeIdNotConfigured` cannot tell a caller which one it is looking at.
        require(endpoints != 0 && admins != 0, FeedNotConfigured());
        for (uint256 i = 0; i < _teeIds.length; i++) {
            require(_isTeeIdAtVersions(_feedId, _teeIds[i], endpoints, admins), TeeIdNotConfigured());
        }
        _instructionId = _sendInstructions(
            _teeIds, GET_FEED_COMMAND, abi.encode(FeedUpdateRequest(_feedId)), msg.sender);
        emit FeedUpdateRequested(msg.sender, _feedId, _instructionId);
    }

    /**
     * @inheritdoc ITeeOracleInstructionsSender
     */
    function pushEndpoints(
        bytes21 _feedId,
        address[] calldata _teeIds,
        EndpointGroup[] calldata _groups
    )
        external payable
        returns (bytes32 _instructionId)
    {
        FeedConfig storage config = feedConfigs[_feedId];
        bytes32 endpointsHash = config.endpointsHash;
        require(endpointsHash != bytes32(0), NoConfigPublished());
        uint64 version = config.endpointsVersion;
        // The values are the caller's to supply — nothing stores them, only `EndpointsPublished`
        // logs them — and they are re-encoded here EXACTLY as `setEndpoints` encoded them, with
        // the version taken from STORAGE rather than from the caller: a wrong or stale version
        // cannot be supplied because none is supplied. Fields rather than a raw `bytes` payload,
        // so hash equality does not depend on the caller's ABI encoder reproducing the published
        // bytes — any correct set of field values hashes correctly. No re-validation: a hash match
        // proves the payload was validated at publication.
        bytes memory message =
            abi.encode(Endpoints({version: version, feedId: _feedId, groups: _groups}));
        require(keccak256(message) == endpointsHash, WrongConfigPayload());
        _validateTeeIds(_teeIds);
        // The caller's list is dispatched as given. No version filter: a machine already at the
        // latest version is accepted, because this is also the retry path for an instruction that
        // never reached its enclave — the re-dispatch is idempotent and the fee is the spam bound,
        // exactly as it is for `requestFeedUpdate`. No status filter either: the diamond rejects a
        // non-PRODUCTION target, and reverting is the honest answer to a caller who named it.
        // Copied to memory once here, since both the record loop and the dispatch take `memory`.
        address[] memory targets = _teeIds;

        _recordEndpointsTargets(_feedId, targets, version, endpointsHash);

        _instructionId = _sendInstructions(targets, SET_ENDPOINTS_COMMAND, message, msg.sender);
    }

    /**
     * @inheritdoc ITeeOracleInstructionsSender
     */
    function pushAdmins(
        bytes21 _feedId,
        address[] calldata _teeIds,
        AdminRole[] calldata _roles
    )
        external payable
        returns (bytes32 _instructionId)
    {
        FeedConfig storage config = feedConfigs[_feedId];
        bytes32 adminsHash = config.adminsHash;
        require(adminsHash != bytes32(0), NoConfigPublished());
        uint64 version = config.adminsVersion;
        // See `pushEndpoints`: the roles come from the `AdminsPublished` log, the version from
        // storage, and the canonical re-encoding is checked against the stored commitment.
        bytes memory message =
            abi.encode(Admins({version: version, feedId: _feedId, roles: _roles}));
        require(keccak256(message) == adminsHash, WrongConfigPayload());
        _validateTeeIds(_teeIds);
        // See `pushEndpoints`: the list is dispatched as given, retries included, copied to
        // memory once for the record loop and the dispatch.
        address[] memory targets = _teeIds;

        _recordAdminsTargets(_feedId, targets, version, adminsHash);

        _instructionId = _sendInstructions(targets, SET_ADMINS_COMMAND, message, msg.sender);
    }

    /**
     * @inheritdoc IITeeOracleInstructionsSender
     */
    function setEndpoints(
        bytes21 _feedId,
        EndpointGroup[] calldata _groups,
        address _claimBackAddress
    )
        external payable
        onlyGovernance
    {
        require(_feedId != bytes21(0), InvalidFeedId());
        // Who funds the execution cannot be read on chain, so governance names the payer of
        // record; the diamond only emits it, unvalidated, hence the zero check here.
        require(_claimBackAddress != address(0), ZeroClaimBackAddress());
        _validateEndpoints(_groups);

        // One version per publication: every machine dispatched this payload shares the same
        // version and hash, so the feed's fleet generations stay comparable. It is derived HERE,
        // at execution time, as the feed's next consecutive one - it is not an argument.
        // ORDERING IS A GOVERNANCE RESPONSIBILITY, as it is for every other timelocked setter in
        // this repository: `FlareGovernance` keys a pending call by the hash of its whole
        // calldata, so two publications for one feed and kind can be pending at once and execute
        // in either order, and the one that executes LAST becomes the feed's configuration - even
        // if it was proposed first. Governance must therefore CANCEL a superseded publication
        // rather than leave it queued; execution is not permissionless (only whitelisted
        // executors can call `executeGovernanceCall`), so the ordering is theirs to control.
        // The checked addition reverts at `type(uint64).max` rather than wrapping round to a
        // version machines already hold.
        FeedConfig storage config = feedConfigs[_feedId];
        uint64 version = config.endpointsVersion + 1;
        _recordFeedId(_feedId, version, config.adminsVersion);
        // One `abi.encode` serves the commitment AND the instruction body. The event then encodes
        // the groups a SECOND time for its log data — `emit` cannot be pointed at an existing
        // buffer, and the two encodings do not coincide anyway (the body wraps the groups in
        // `Endpoints`, the log data is the bare array behind an offset).
        // The struct is therefore built in memory explicitly and the event is handed
        // `endpoints.groups`, i.e. the copy already made for the encode: emitting the CALLDATA
        // `_groups` instead makes the log encoder traverse calldata a second time, measured at
        // ~52,000 gas more on a 48 KB payload. As written, the typed event costs ~8,700 gas over a
        // raw `bytes message` one — under 1% of the publication.
        Endpoints memory endpoints = Endpoints({version: version, feedId: _feedId, groups: _groups});
        bytes memory message = abi.encode(endpoints);
        bytes32 endpointsHash = keccak256(message);

        // Only the commitment is stored. Keeping the payload cost ~217,000 gas per PUBLIC
        // endpoint — 96% of a publication, and above the 28,000,000 block gas limit for a
        // 25-group / 5-endpoint configuration — so the payload rides in the event instead and
        // `pushEndpoints` supplies it back, checked against this hash.
        config.endpointsVersion = version;
        config.endpointsHash = endpointsHash;
        config.endpointsPublishedAt = uint64(block.timestamp);

        // The full payload is logged UNCONDITIONALLY, before the dispatch is even attempted: when
        // the dispatch is skipped no `TeeInstructionsSent` carries it either, so this log would be
        // the only record of it and a push has nothing else to read. In the dispatching case the
        // payload is logged twice; that overlap costs 8 gas per byte (~385k for 48 KB) and is
        // accepted, since making the log conditional would make an undeliverable configuration
        // unrecoverable.
        emit EndpointsPublished(_feedId, version, endpointsHash, endpoints.groups);

        // The publication is stored and final at this point. Delivery targets the extension's
        // active set as it stands in THIS block, unfiltered: it is exactly the extension's
        // PRODUCTION machines, and a fresh version is new to every one of them. Anything the
        // executor can fix — a short fee, a misconfigured or unregistered TEE manager — is left
        // to revert inside the diamond, which is retryable.
        // The pause is checked FIRST: while paused nothing can be dispatched, and reading the
        // active set is an unpaginated diamond call that also builds a `string[]` of machine
        // URLs this contract discards.
        if (flareTeeManager.isExtensionEmergencyPaused(extensionId)) {
            _requireNoValue();
            return;
        }
        address[] memory targets = _activeTeeIds();
        if (targets.length == 0) {
            _requireNoValue();
            return;
        }
        _recordEndpointsTargets(_feedId, targets, version, endpointsHash);
        _sendInstructions(targets, SET_ENDPOINTS_COMMAND, message, _claimBackAddress);
    }

    /**
     * @inheritdoc IITeeOracleInstructionsSender
     */
    function setAdmins(
        bytes21 _feedId,
        AdminRole[] calldata _roles,
        address _claimBackAddress
    )
        external payable
        onlyGovernance
    {
        require(_feedId != bytes21(0), InvalidFeedId());
        // See setEndpoints: the claim-back address is named, and must not be zero.
        require(_claimBackAddress != address(0), ZeroClaimBackAddress());
        _validateAdminRoles(_roles);

        // One version per publication, derived here as the feed's next consecutive one — see
        // setEndpoints on why ordering between two pending publications is governance's to
        // control. The admin sets have their own version stream, so the two kinds never contend
        // for a number.
        FeedConfig storage config = feedConfigs[_feedId];
        uint64 version = config.adminsVersion + 1;
        _recordFeedId(_feedId, version, config.endpointsVersion);
        // One encode for the commitment and the dispatch, the roles logged separately from the
        // same memory copy — see setEndpoints on the double encoding and why `admins.roles` rather
        // than the calldata `_roles` is what the event gets.
        Admins memory admins = Admins({version: version, feedId: _feedId, roles: _roles});
        bytes memory message = abi.encode(admins);
        bytes32 adminsHash = keccak256(message);

        // Hash only, payload in the event — see setEndpoints for the gas measurement behind it.
        config.adminsVersion = version;
        config.adminsHash = adminsHash;
        config.adminsPublishedAt = uint64(block.timestamp);

        // Unconditional, dispatch or no dispatch — see setEndpoints.
        emit AdminsPublished(_feedId, version, adminsHash, admins.roles);

        // Delivery to the live active set — see setEndpoints, including why the pause is
        // checked before the set is read.
        if (flareTeeManager.isExtensionEmergencyPaused(extensionId)) {
            _requireNoValue();
            return;
        }
        address[] memory targets = _activeTeeIds();
        if (targets.length == 0) {
            _requireNoValue();
            return;
        }
        _recordAdminsTargets(_feedId, targets, version, adminsHash);
        _sendInstructions(targets, SET_ADMINS_COMMAND, message, _claimBackAddress);
    }

    /**
     * @inheritdoc ITeeOracleInstructionsSender
     */
    function getFeedIds()
        external view
        returns (bytes21[] memory)
    {
        return feedIds;
    }

    /**
     * @inheritdoc ITeeOracleInstructionsSender
     */
    function getEndpointsPushTargets(
        bytes21 _feedId
    )
        external view
        returns (address[] memory _teeIds)
    {
        FeedConfig storage config = feedConfigs[_feedId];
        // Without a publication every machine would look "not at the latest version", so the
        // version filter alone would report the whole fleet as lagging.
        if (config.endpointsHash == bytes32(0)) {
            return new address[](0);
        }
        // This view answers "who still NEEDS a push", so machines already at the latest version
        // are left out. `pushEndpoints` still accepts them, as a retry.
        return _laggingTargets(_feedId, _activeTeeIds(), config.endpointsVersion, true);
    }

    /**
     * @inheritdoc ITeeOracleInstructionsSender
     */
    function getAdminsPushTargets(
        bytes21 _feedId
    )
        external view
        returns (address[] memory _teeIds)
    {
        FeedConfig storage config = feedConfigs[_feedId];
        if (config.adminsHash == bytes32(0)) {
            return new address[](0);
        }
        return _laggingTargets(_feedId, _activeTeeIds(), config.adminsVersion, false);
    }

    /**
     * @inheritdoc ITeeOracleInstructionsSender
     */
    function getEndpointsPublicationFee()
        external view
        returns (
            address[] memory _teeIds,
            uint256 _fee
        )
    {
        // Mirrors what the publication actually does: while the extension is emergency paused
        // nothing is dispatched and attaching value reverts `ValueNotNeeded`, so the preview
        // must report no targets and no fee rather than a number the executor cannot use.
        if (flareTeeManager.isExtensionEmergencyPaused(extensionId)) {
            return (new address[](0), 0);
        }
        _teeIds = _activeTeeIds();
        if (_teeIds.length > 0) {
            _fee = flareTeeManager.calculateFeeByTeeIds(
                TEE_ORACLE_OP_TYPE, SET_ENDPOINTS_COMMAND, _teeIds);
        }
    }

    /**
     * @inheritdoc ITeeOracleInstructionsSender
     */
    function getAdminsPublicationFee()
        external view
        returns (
            address[] memory _teeIds,
            uint256 _fee
        )
    {
        // Mirrors what the publication actually does: while the extension is emergency paused
        // nothing is dispatched and attaching value reverts `ValueNotNeeded`, so the preview
        // must report no targets and no fee rather than a number the executor cannot use.
        if (flareTeeManager.isExtensionEmergencyPaused(extensionId)) {
            return (new address[](0), 0);
        }
        _teeIds = _activeTeeIds();
        if (_teeIds.length > 0) {
            _fee = flareTeeManager.calculateFeeByTeeIds(
                TEE_ORACLE_OP_TYPE, SET_ADMINS_COMMAND, _teeIds);
        }
    }

    /**
     * @inheritdoc ITeeOracleInstructionsSender
     */
    function getFeedConfig(
        bytes21 _feedId
    )
        external view
        returns (FeedConfig memory)
    {
        return feedConfigs[_feedId];
    }

    /**
     * @inheritdoc ITeeOracleInstructionsSender
     */
    function getMachineVersions(
        bytes21 _feedId,
        address _teeId
    )
        external view
        returns (MachineVersions memory)
    {
        return machineVersions[_feedId][_teeId];
    }

    /**
     * @inheritdoc ITeeOracleInstructionsSender
     */
    function latestEndpointsHash(
        bytes21 _feedId
    )
        external view
        returns (bytes32)
    {
        return feedConfigs[_feedId].endpointsHash;
    }

    /**
     * @inheritdoc ITeeOracleInstructionsSender
     */
    function latestAdminsHash(
        bytes21 _feedId
    )
        external view
        returns (bytes32)
    {
        return feedConfigs[_feedId].adminsHash;
    }

    /**
     * @inheritdoc ITeeOracleInstructionsSender
     */
    function endpointsVersion(
        bytes21 _feedId
    )
        external view
        returns (uint64)
    {
        return feedConfigs[_feedId].endpointsVersion;
    }

    /**
     * @inheritdoc ITeeOracleInstructionsSender
     */
    function adminsVersion(
        bytes21 _feedId
    )
        external view
        returns (uint64)
    {
        return feedConfigs[_feedId].adminsVersion;
    }

    /**
     * @inheritdoc ITeeOracleInstructionsSender
     */
    function endpointsPublishedAt(
        bytes21 _feedId
    )
        external view
        returns (uint64)
    {
        return feedConfigs[_feedId].endpointsPublishedAt;
    }

    /**
     * @inheritdoc ITeeOracleInstructionsSender
     */
    function adminsPublishedAt(
        bytes21 _feedId
    )
        external view
        returns (uint64)
    {
        return feedConfigs[_feedId].adminsPublishedAt;
    }

    /**
     * @inheritdoc ITeeOracleInstructionsSender
     */
    function expectedEndpointsVersion(
        bytes21 _feedId,
        address _teeId
    )
        external view
        returns (uint64)
    {
        return machineVersions[_feedId][_teeId].endpointsVersion;
    }

    /**
     * @inheritdoc ITeeOracleInstructionsSender
     */
    function expectedAdminsVersion(
        bytes21 _feedId,
        address _teeId
    )
        external view
        returns (uint64)
    {
        return machineVersions[_feedId][_teeId].adminsVersion;
    }

    /**
     * @inheritdoc ITeeOracleInstructionsSender
     */
    function isTeeIdConfigured(
        bytes21 _feedId,
        address _teeId
    )
        public view
        returns (bool)
    {
        FeedConfig storage config = feedConfigs[_feedId];
        return _isTeeIdAtVersions(_feedId, _teeId, config.endpointsVersion, config.adminsVersion);
    }

    /**
     * Writes the per-machine endpoints version record for every target and logs it, before the
     * dispatch that carries the payload. Shared by the publication's auto-dispatch and by
     * `pushEndpoints` so both leave identical state.
     * @param _feedId The feed being dispatched.
     * @param _targets The accepted machines.
     * @param _version The version being dispatched.
     * @param _endpointsHash The feed's latest published endpoints hash.
     */
    function _recordEndpointsTargets(
        bytes21 _feedId,
        address[] memory _targets,
        uint64 _version,
        bytes32 _endpointsHash
    )
        internal
    {
        for (uint256 i = 0; i < _targets.length; i++) {
            machineVersions[_feedId][_targets[i]].endpointsVersion = _version;
            emit EndpointsSet(_feedId, _targets[i], _version, _endpointsHash);
        }
    }

    /**
     * Writes the per-machine admins version record for every target and logs it.
     * See `_recordEndpointsTargets`.
     * @param _feedId The feed being dispatched.
     * @param _targets The accepted machines.
     * @param _version The version being dispatched.
     * @param _adminsHash The feed's latest published admin-sets hash.
     */
    function _recordAdminsTargets(
        bytes21 _feedId,
        address[] memory _targets,
        uint64 _version,
        bytes32 _adminsHash
    )
        internal
    {
        for (uint256 i = 0; i < _targets.length; i++) {
            machineVersions[_feedId][_targets[i]].adminsVersion = _version;
            emit AdminsSet(_feedId, _targets[i], _version, _adminsHash);
        }
    }

    /**
     * Appends a feed id once BOTH configuration kinds are published — the same condition
     * `requestFeedUpdate` checks per machine. Triggered when the kind just published
     * reached its first version and the other kind already exists, which happens exactly
     * once per feed.
     */
    function _recordFeedId(
        bytes21 _feedId,
        uint64 _publishedVersion,
        uint64 _otherVersion
    )
        internal
    {
        if (_publishedVersion == 1 && _otherVersion != 0) {
            feedIds.push(_feedId);
        }
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
     * the fee, on every path — publication and push alike. The diamond enforces only a fee FLOOR
     * (`Instructions.sendInstructions`: `require(calculatedFee <= msg.value, FeeTooLow())`) and
     * then hands the WHOLE value to `RewardManager.receiveRewards` in the same transaction; it
     * keeps no balance and does no per-instruction accounting, and exposes no claim method of its
     * own - the value is claimable only the way any reward is, through the `RewardManager`, and
     * only if the off-chain calculation attributes an amount to the payer of record.
     * `_claimBackAddress` is only carried into the emitted `TeeInstructionsSent`, alongside the
     * full `msg.value`. On chain, therefore, a surplus is simply part of that epoch's rewards and
     * nothing distinguishes it from the fee. What happens NEXT is the off-chain reward
     * calculation's business: it has the payer of record and the exact value from the log, so it
     * MAY return a surplus, or MAY keep the value of an instruction that never executed — a
     * reward-script policy decision, not a guarantee of these contracts. Either way, reading the
     * fee in the block the call lands in is what keeps the attached value right, so every caller
     * — the executor of a publication included — does that.
     * The permissionless methods are caller-funded and pass `msg.sender` as the payer of record;
     * a governance publication is funded by whatever the executor attached to
     * `executeGovernanceCall` and passes the address governance named, because the executed
     * body's `msg.sender` is this contract itself and the payer cannot be identified on chain.
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
     * Rejects value attached to a publication that skips its dispatch — the extension is
     * emergency paused, or its active set is empty.
     * Those are the only two conditions the governance executor cannot do anything about: the
     * diamond hard-rejects every dispatch while paused (`Instructions.sendInstructions`) and
     * there is nothing to dispatch to when the fleet is not registered yet. Landing a corrected
     * configuration on chain must stay possible in both cases, not least because the pause may
     * exist BECAUSE the published endpoints or admins are wrong; the permissionless push
     * delivers it afterwards.
     * Everything else — a short fee, an unset or wrong TEE manager, this contract not being the
     * extension's registered instructions sender — is deliberately NOT pre-checked: it reverts
     * inside the diamond with its own canonical error, which surfaces the deployment or funding
     * mistake instead of hiding it, and costs nothing, since `executeGovernanceCall` bubbles the
     * revert and thereby rolls back its own deletion of the timelock entry.
     * A skipped dispatch creates NO instruction, so there is no fee to attach and nothing would
     * record the payer: the executed body's `msg.sender` is this contract, and `FlareGovernance`
     * does not record who called `executeGovernanceCall`, so the executor cannot be identified.
     * Forwarding the value to the reward manager with no instruction logged, or keeping it here,
     * would both be worse than reverting and telling the executor to re-execute with none
     * attached.
     */
    function _requireNoValue()
        internal view
    {
        require(msg.value == 0, ValueNotNeeded());
    }

    /**
     * Whether a machine holds both of the given versions for a feed — the body of
     * `isTeeIdConfigured`, taking the feed's two versions as arguments so `requestFeedUpdate`
     * can read the `FeedConfig` once and then check every target without touching it again.
     * @param _feedId The feed id.
     * @param _teeId The TEE machine id.
     * @param _endpointsVersion The feed's latest published endpoints version.
     * @param _adminsVersion The feed's latest published admin-sets version.
     * @return True if both kinds' latest versions were dispatched to the machine.
     */
    function _isTeeIdAtVersions(
        bytes21 _feedId,
        address _teeId,
        uint64 _endpointsVersion,
        uint64 _adminsVersion
    )
        internal view
        returns (bool)
    {
        // Both feed-level versions must exist, or an unpublished feed would report every
        // machine as configured (0 == 0).
        if (_endpointsVersion == 0 || _adminsVersion == 0) {
            return false;
        }
        // Both kinds come from one packed slot, so this is a single cold SLOAD per machine —
        // which is what `requestFeedUpdate` pays per target.
        MachineVersions storage versions = machineVersions[_feedId][_teeId];
        return versions.endpointsVersion == _endpointsVersion && versions.adminsVersion == _adminsVersion;
    }

    /**
     * Drops machines already recorded at `_latestVersion` from the candidates: the "which
     * machines still NEED this version" question, asked by `getEndpointsPushTargets` /
     * `getAdminsPushTargets`. The state-changing push paths deliberately do not apply this rule,
     * so an instruction the enclave never received can be retried immediately: there is no
     * cooldown, the instruction fee is the spam bound (exactly as it is for `requestFeedUpdate`),
     * and a re-dispatch rewrites the same version, so it changes nothing the feed store reads.
     * @param _feedId The feed being dispatched.
     * @param _candidates The candidate machine ids. Compacted and shrunk IN PLACE, so it must be
     * a freshly allocated array the caller does not reuse — both callers pass `_activeTeeIds()`.
     * @param _latestVersion The feed's latest published version of the kind being dispatched.
     * @param _endpoints True to compare the endpoints version, false for the admin-sets version.
     * A flag rather than a `storage` pointer to the mapping, because the two versions now share
     * one packed struct and a struct field cannot be passed as a storage pointer.
     * @return _lagging The candidates that are behind `_latestVersion`.
     */
    function _laggingTargets(
        bytes21 _feedId,
        address[] memory _candidates,
        uint64 _latestVersion,
        bool _endpoints
    )
        internal view
        returns (address[] memory _lagging)
    {
        uint256 count = 0;
        for (uint256 i = 0; i < _candidates.length; i++) {
            MachineVersions storage versions = machineVersions[_feedId][_candidates[i]];
            uint64 dispatched = _endpoints ? versions.endpointsVersion : versions.adminsVersion;
            if (dispatched != _latestVersion) {
                _candidates[count] = _candidates[i];
                count++;
            }
        }
        _lagging = _candidates;
        // Shrink the freshly allocated candidate array to the lagging machines compacted into
        // its head, rather than copying them into a second exact-size array.
        // solhint-disable-next-line no-inline-assembly
        assembly { mstore(_lagging, count) }
    }

    /**
     * Returns the extension's PRODUCTION machines — `MachineManager`'s `extensionActiveTeeIds`
     * set, maintained by `changeStatus`: a machine enters on the transition to PRODUCTION and
     * leaves on PAUSED / SUSPENDED / BANNED, so the set is exactly this extension's PRODUCTION
     * machines, with no duplicate and no zero address. That invariant is why every caller here
     * dispatches or prices the set as it comes, with no eligibility filter of its own.
     * Unpaginated, and the diamond also builds a `string[]` of their URLs that is thrown away
     * here. That cost falls on the `get*PushTargets` / `get*PublicationFee` views (free) and on
     * a governance publication, whose gas is therefore bounded by the extension's fleet size.
     */
    function _activeTeeIds()
        internal view
        returns (address[] memory _teeIds)
    {
        (_teeIds,) = flareTeeManager.getActiveTeeMachines(extensionId);
    }

    /**
     * Requires a non-empty list of unique, non-zero TEE machine ids belonging to this sender's
     * extension. Shared by every caller-directed path — `requestFeedUpdate`, `pushEndpoints`,
     * `pushAdmins` — all of which revert on a bad id instead of dropping it: the caller names the
     * machines it pays for, so a silently skipped target would deliver less than was paid for.
     * PRODUCTION status is deliberately NOT checked here; the diamond rejects a non-PRODUCTION
     * target with its own error.
     */
    function _validateTeeIds(
        address[] calldata _teeIds
    )
        internal view
    {
        require(_teeIds.length > 0, NoTeeIds());
        // Every LOCAL rule is checked BEFORE the manager is consulted at all. With the extension
        // lookup on `_teeIds[0]` in front of this loop, a zero first element reached the manager
        // and surfaced its `TeeNotFound()` instead of this contract's declared `ZeroTeeId()` —
        // the caller's own malformed argument reported as a registry miss.
        for (uint256 i = 0; i < _teeIds.length; i++) {
            require(_teeIds[i] != address(0), ZeroTeeId());
            for (uint256 j = 0; j < i; j++) {
                require(_teeIds[j] != _teeIds[i], DuplicateTeeId());
            }
        }
        // The diamond derives the extension from the targeted machines and only checks that
        // this contract is THAT extension's registered sender — and registering a sender on a
        // (foreign) extension requires no consent from the sender contract. Pin the target
        // extension explicitly so commitments and fees can never go to another extension's
        // machines. Checking the first id suffices: the diamond requires all targeted
        // machines to share one extension, and the whole request is atomic. A first id that is no
        // machine at all still reverts with the manager's `TeeNotFound()` — the registry is the
        // only thing that can answer that question.
        require(flareTeeManager.getExtensionId(_teeIds[0]) == extensionId, TeeIdNotInExtension());
    }

    /**
     * Validates an endpoints payload — tag-agnostic shape rules only. Tag semantics
     * (required groups, URL scheme policy, credential-name policy, private-URL commitment
     * format) are pinned in the TEE extension build. No count caps — transaction size and
     * gas are the natural limit.
     * NOTE: endpoints are deliberately NOT de-duplicated within a group, unlike the admins of a
     * role. The asymmetry is not an oversight: an `address` is a canonical 20 bytes, so
     * `DuplicateAdmin` is a guarantee, whereas a URL has unbounded equivalent spellings — host
     * case, a trailing slash, an explicit `:443`, a redundant query parameter — so a string
     * comparison would be trivially bypassable and would advertise a distinctness it cannot
     * deliver. It would also REJECT legitimate configurations: the same host may appear twice
     * under different `secretRef` credentials, and PRIVATE endpoints commit to SALTED hashes, so
     * two entries for one upstream differ on chain by construction. Whether a group's endpoints
     * are genuinely independent sources is therefore a property of the published configuration
     * and of the TEE extension build, not something this contract can check — see
     * `ITeeOracleInstructionsSender.EndpointGroup`.
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
     * publishes a URL and no commitment. `secretRef` is orthogonal to both and is NOT required
     * by either: it names a credential, not the URL, and an endpoint that needs none leaves it
     * empty. See `ITeeOracleInstructionsSender.Endpoint`.
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
