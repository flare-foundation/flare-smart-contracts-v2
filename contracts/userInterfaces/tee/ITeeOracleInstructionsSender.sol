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

// Request envelope version carried by every GET_FEED instruction. The instructions facet
// rejects an empty `message`, so a request must carry something; the extension pins this
// same constant and rejects anything else.
bytes constant GET_FEED_REQUEST_V1 = hex"01";

/**
 * @title ITeeOracleInstructionsSender
 * @notice Public interface for a TEE oracle extension's on-chain instructions entry point.
 * @dev One deployed instance serves one extension (one feed); the operation type and
 *      commands are constants shared by all instances (see above).
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
     * Full endpoint configuration payload, as ABI-encoded into the instruction message.
     * @param version Contract-assigned monotonic version (see `endpointsVersion`).
     * @param groups The tagged endpoint groups.
     */
    struct Endpoints {
        uint64 version;
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
     * @param roles The role-tagged admin sets.
     */
    struct Admins {
        uint64 version;
        AdminRole[] roles;
    }

    /// Emitted once at initialization with the immutable per-instance configuration.
    event InstructionsSenderInitialised(uint256 indexed extensionId);

    /// Emitted when a feed update is requested; the id lets a keeper fetch the result.
    event FeedUpdateRequested(address indexed requester, bytes32 indexed instructionId);

    /// Emitted when endpoint configuration is sent to a TEE machine.
    event EndpointsSet(address indexed teeId, uint64 indexed version, bytes32 indexed endpointsHash);

    /// Emitted when admin signer sets are sent to a TEE machine.
    event AdminsSet(address indexed teeId, uint64 indexed version, bytes32 indexed adminsHash);

    error NoTeeIds();
    error ZeroTeeId();
    error DuplicateTeeId();
    error TeeIdNotInExtension();
    error InvalidExtensionId();
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
     * Requests a fresh feed observation from a random registered TEE machine.
     * Open to anyone; the instruction fee (msg.value) bounds spam and the feed store
     * verifies the TEE signature on the resulting feed update.
     * @return _instructionId Id of the dispatched instruction, also emitted in `FeedUpdateRequested`.
     */
    function requestFeedUpdate()
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
     * Returns the hash of the last endpoints payload published to a TEE machine.
     * The matching feed store enforces this commitment on submitted feed updates.
     * @param _teeId The TEE machine id.
     * @return The keccak256 hash of the encoded payload, or zero if none was published.
     */
    function expectedEndpointsHash(
        address _teeId
    )
        external view
        returns (bytes32);

    /**
     * Returns the hash of the last admins payload published to a TEE machine.
     * The matching feed store enforces this commitment on submitted feed updates.
     * @param _teeId The TEE machine id.
     * @return The keccak256 hash of the encoded payload, or zero if none was published.
     */
    function expectedAdminsHash(
        address _teeId
    )
        external view
        returns (bytes32);

    /**
     * Returns the version assigned to the most recently published endpoint configuration.
     * Incremented by the contract on every `setEndpoints` publish (any machine).
     */
    function endpointsVersion()
        external view
        returns (uint64);

    /**
     * Returns the version assigned to the most recently published admin sets.
     * Incremented by the contract on every `setAdmins` publish (any machine).
     */
    function adminsVersion()
        external view
        returns (uint64);

    /**
     * Returns the endpoints version last published to a TEE machine (zero if none).
     * @param _teeId The TEE machine id.
     */
    function expectedEndpointsVersion(
        address _teeId
    )
        external view
        returns (uint64);

    /**
     * Returns the admins version last published to a TEE machine (zero if none).
     * @param _teeId The TEE machine id.
     */
    function expectedAdminsVersion(
        address _teeId
    )
        external view
        returns (uint64);
}
