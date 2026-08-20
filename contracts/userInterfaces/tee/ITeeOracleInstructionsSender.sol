// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9;

// Operation type shared by every TEE oracle instance. Per-feed distinctions live in extension
// membership and the signed payloads; the fee table keys on (opType, opCommand), so the three
// commands below still get independently priced fee rows.
bytes32 constant TEE_ORACLE_OP_TYPE = bytes32("TEE_ORACLE");

// Command for requesting a fresh feed observation. See `ITeeOracleInstructionsSender.requestFeedUpdate`.
bytes32 constant GET_FEED_COMMAND = bytes32("GET_FEED");

// Command for publishing endpoint configuration to a TEE machine.
bytes32 constant SET_ENDPOINTS_COMMAND = bytes32("SET_ENDPOINTS");

// Command for publishing the admin signer sets to a TEE machine.
bytes32 constant SET_ADMINS_COMMAND = bytes32("SET_ADMINS");

/**
 * @title ITeeOracleInstructionsSender
 * @notice Public interface for a TEE oracle extension's on-chain instructions entry point.
 * @dev One deployed instance serves one extension and any number of its feeds — every
 *      feed gets its own `TeeOracleFeedStore`, all reading this sender, so one machine
 *      fleet can serve multiple oracles. Configuration commitments and versions are kept
 *      per feed and per machine. The operation type and commands are constants shared by
 *      all instances (see above).
 *      Payload sizes are not artificially capped — transaction size and gas are the limit.
 */
interface ITeeOracleInstructionsSender {

    /**
     * Whether an endpoint's URL is published on-chain or provisioned privately.
     */
    enum EndpointKind {
        PUBLIC,
        PRIVATE
    }

    /**
     * One upstream data endpoint.
     * @param kind PUBLIC publishes the URL on-chain; PRIVATE publishes only a commitment.
     * @param url PUBLIC only: the endpoint URL. It may embed a placeholder token — e.g.
     * `{secret}` — that the TEE machine substitutes with the credential value named by
     * `secretRef`; the exact placeholder syntax is a convention between the published
     * configuration and the TEE extension implementation, not enforced on-chain. Must be
     * empty for PRIVATE.
     * @param urlHash PRIVATE only: commitment to the URL provisioned to the machine off-chain
     * (delivered like a credential, under `secretRef`). The commitment format is pinned in the
     * TEE extension build and should be salted — a bare hash of a low-entropy URL would be
     * brute-forceable from chain data. Must be zero for PUBLIC. A commitment is deliberately
     * used instead of a TEE-pubkey-encrypted URL: an on-chain ciphertext would expose the URL
     * forever if the machine's key ever leaked, a commitment reveals nothing.
     * @param secretRef The credential / provisioning NAME the machine resolves — never a value
     * (hence the name). For PUBLIC endpoints it names the credential substituted into the
     * URL's placeholder (empty when the URL has none); for PRIVATE endpoints it names the
     * off-chain-provisioned URL entry, which by the same convention may carry or reference a
     * credential of its own (e.g. an API-key auth header) — so even a
     * credentialed API's URL comes through configuration instead of being hardcoded in the
     * TEE extension build.
     */
    struct Endpoint {
        EndpointKind kind;
        string url;
        bytes32 urlHash;
        string secretRef;
    }

    /**
     * One tagged endpoint group. What a tag means (a chain's RPC set, a public or private
     * API, ...), which tags are required, and any per-tag policy are pinned in the TEE
     * extension build — the contract only enforces tag-agnostic shape rules.
     * @param group The group tag, e.g. `bytes32("flare")`, `bytes32(uint256(chainId))` or
     * `bytes32("hex_cash")`.
     * @param threshold How many endpoints in the group must agree.
     * @param endpoints The endpoints.
     */
    struct EndpointGroup {
        bytes32 group;
        uint64 threshold;
        Endpoint[] endpoints;
    }

    /**
     * Feed observation request payload, as ABI-encoded into the GET_FEED instruction message.
     * @param feedId The feed to observe.
     */
    struct FeedUpdateRequest {
        bytes21 feedId;
    }

    /**
     * Full endpoint configuration payload, as ABI-encoded into the instruction message.
     * @param version Contract-assigned monotonic version (see `endpointsVersion`).
     * @param feedId The feed this configuration serves — one machine may serve several
     * feeds, each with its own configuration.
     * @param groups The tagged endpoint groups.
     */
    struct Endpoints {
        uint64 version;
        bytes21 feedId;
        EndpointGroup[] groups;
    }

    /**
     * One role-tagged admin signer set. Role semantics (which credentials a role governs,
     * role-specific threshold floors, which roles must be present) are pinned in the TEE
     * extension build — the contract only enforces role-agnostic shape rules.
     * @param role The role tag, e.g. `bytes32("backing")` or `bytes32("providers")`.
     * @param threshold How many DISTINCT signers of this role are required.
     * @param admins The admin signer addresses; unique and non-zero within the role.
     */
    struct AdminRole {
        bytes32 role;
        uint64 threshold;
        address[] admins;
    }

    /**
     * Full admin signer sets payload, as ABI-encoded into the instruction message.
     * @param version Contract-assigned monotonic version (see `adminsVersion`).
     * @param feedId The feed these admin sets serve.
     * @param roles The role-tagged admin sets.
     */
    struct Admins {
        uint64 version;
        bytes21 feedId;
        AdminRole[] roles;
    }

    /// Emitted once at initialization with the immutable per-instance configuration.
    event InstructionsSenderInitialised(uint256 indexed extensionId);

    /// Emitted when a feed update is requested; the id lets a keeper fetch the result.
    event FeedUpdateRequested(address indexed requester, bytes21 indexed feedId, bytes32 indexed instructionId);

    /// Emitted when endpoint configuration is sent to a TEE machine.
    event EndpointsSet(bytes21 indexed feedId, address indexed teeId, uint64 indexed version, bytes32 endpointsHash);

    /// Emitted when admin signer sets are sent to a TEE machine.
    event AdminsSet(bytes21 indexed feedId, address indexed teeId, uint64 indexed version, bytes32 adminsHash);

    error NoTeeIds();
    error ZeroTeeId();
    error DuplicateTeeId();
    error TeeIdNotInExtension();
    error TeeIdNotConfigured();
    error InvalidExtensionId();
    error InvalidFeedId();
    error NoGroups();
    error EmptyGroup();
    error DuplicateGroup();
    error NoEndpoints();
    error InvalidEndpoint();
    error InvalidThreshold();
    error NoRoles();
    error EmptyRole();
    error DuplicateRole();
    error NoAdmins();
    error ZeroAdmin();
    error DuplicateAdmin();

    /**
     * Requests a fresh feed observation from the given TEE machines.
     * Open to anyone; the instruction fee (msg.value) bounds spam and the feed store
     * verifies the TEE signature on the resulting feed update. Every targeted machine
     * must have endpoints and admins published for the feed, and the instruction message
     * carries the ABI-encoded `FeedUpdateRequest` so the machine knows which feed to observe.
     * @param _feedId The feed to observe.
     * @param _teeIds The TEE machines to ask (non-empty, unique, non-zero, on this
     * extension, configured for the feed).
     * @return _instructionId Id of the dispatched instruction, also emitted in `FeedUpdateRequested`.
     */
    function requestFeedUpdate(
        bytes21 _feedId,
        address[] calldata _teeIds
    )
        external payable
        returns (bytes32 _instructionId);

    /**
     * Returns the extension id this sender dispatches instructions for.
     * The matching feed store caches this value at its initialization.
     */
    function extensionId()
        external view
        returns (uint256);

    /**
     * Returns every feed id with both configuration kinds (endpoints and admins)
     * published, in first-completed order. Enumerable so a dashboard can list the
     * extension's feeds without an indexer.
     */
    function getFeedIds()
        external view
        returns (bytes21[] memory);

    /**
     * Whether a TEE machine has both configuration commitments (endpoints and admins)
     * published for a feed — the precondition `requestFeedUpdate` enforces per target.
     * Publication, not proof: whether the machine actually runs the configuration shows
     * up when its feed updates pass the store's commitment checks.
     * @param _feedId The feed id.
     * @param _teeId The TEE machine id.
     */
    function isTeeIdConfigured(
        bytes21 _feedId,
        address _teeId
    )
        external view
        returns (bool);

    /**
     * Returns the hash of the last endpoints payload published to a TEE machine for a feed.
     * The feed's store enforces this commitment on submitted feed updates.
     * @param _feedId The feed id.
     * @param _teeId The TEE machine id.
     * @return The keccak256 hash of the encoded payload, or zero if none was published.
     */
    function expectedEndpointsHash(
        bytes21 _feedId,
        address _teeId
    )
        external view
        returns (bytes32);

    /**
     * Returns the hash of the last admins payload published to a TEE machine for a feed.
     * The feed's store enforces this commitment on submitted feed updates.
     * @param _feedId The feed id.
     * @param _teeId The TEE machine id.
     * @return The keccak256 hash of the encoded payload, or zero if none was published.
     */
    function expectedAdminsHash(
        bytes21 _feedId,
        address _teeId
    )
        external view
        returns (bytes32);

    /**
     * Returns the version assigned to a feed's most recently published endpoint
     * configuration. Incremented by the contract on every `setEndpoints` publish for
     * the feed (any machine).
     * @param _feedId The feed id.
     */
    function endpointsVersion(
        bytes21 _feedId
    )
        external view
        returns (uint64);

    /**
     * Returns the version assigned to a feed's most recently published admin sets.
     * Incremented by the contract on every `setAdmins` publish for the feed (any machine).
     * @param _feedId The feed id.
     */
    function adminsVersion(
        bytes21 _feedId
    )
        external view
        returns (uint64);

    /**
     * Returns the endpoints version last published to a TEE machine for a feed (zero if none).
     * @param _feedId The feed id.
     * @param _teeId The TEE machine id.
     */
    function expectedEndpointsVersion(
        bytes21 _feedId,
        address _teeId
    )
        external view
        returns (uint64);

    /**
     * Returns the admins version last published to a TEE machine for a feed (zero if none).
     * @param _feedId The feed id.
     * @param _teeId The TEE machine id.
     */
    function expectedAdminsVersion(
        bytes21 _feedId,
        address _teeId
    )
        external view
        returns (uint64);
}
