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
 *      fleet can serve multiple oracles. A feed's published configuration is committed to per
 *      feed by its `keccak256` ALONE — the encoded payload itself is never kept in storage, only
 *      logged; the version last dispatched to a machine is kept per feed and machine.
 *      The operation type and commands are constants shared by all instances (see above).
 *      Payload sizes are not artificially capped — transaction size and gas are the limit.
 *
 *      Configuration is PUBLISHED by Flare governance and DELIVERED to machines by an
 *      instruction. A publication (`setEndpoints` / `setAdmins` on the internal interface)
 *      auto-dispatches to the extension's live active set, resolved INSIDE the call body rather
 *      than taken as an argument: a governance call's arguments are frozen when the timelocked
 *      call is recorded, while the fleet's composition is only known when the executor runs it,
 *      so a target list in the signature makes a publication unexecutable whenever one named
 *      machine left PRODUCTION during the timelock. Reading the active set in the body instead is
 *      a snapshot of the executing block, and there is no delay between publication and fleet
 *      convergence. That set is dispatched to verbatim — the diamond maintains it as exactly the
 *      extension's PRODUCTION machines, so there is nothing to filter out of it.
 *      A publication takes the feed's next consecutive version for that kind, derived when the
 *      call EXECUTES. Ordering between two pending publications is a governance responsibility, as
 *      it is for every other timelocked setter: a call is keyed by its whole calldata, so two
 *      publications for one feed can be pending at once and the one executed LAST wins, even if it
 *      was proposed first. Governance cancels a superseded pending call instead of leaving it
 *      queued; only whitelisted executors can execute a matured call, so that ordering is under
 *      the same operational control as the proposals themselves.
 *      A publication skips its dispatch only in the two cases where no dispatch is possible at
 *      all — the extension is emergency paused, or its active set is empty — and then publishes
 *      the values without delivering them (`msg.value` must be zero, `ValueNotNeeded`). When it
 *      does dispatch, the whole `msg.value` is forwarded and the diamond's fee FLOOR is the only
 *      gate: too little reverts there (`FeeTooLow`) and is retryable. Whatever IS attached goes to
 *      `RewardManager.receiveRewards` in full, in the same transaction — the diamond keeps no
 *      balance, does no per-instruction accounting and offers no on-chain claim method. Size the
 *      value with `get*PublicationFee`, read in the block the execution lands in.
 *      Who funded a publication cannot be read on chain — the executed body's `msg.sender` is
 *      this contract and `FlareGovernance` does not record who called `executeGovernanceCall` —
 *      so a publication names its claim-back address explicitly (`_claimBackAddress`, non-zero).
 *      That address is RECORDED, not honoured on chain: it and the full value are fields of
 *      `TeeInstructionsSent`, which is how the OFF-CHAIN reward calculation learns who paid. What
 *      it then does with a surplus, or with the value of an instruction that never executed, is
 *      decided there and is not a guarantee of this contract.
 *      The permissionless methods need no such argument: their payer is `msg.sender`.
 *      Everything the executor CAN fix, above all too small an instruction fee and a
 *      misconfigured or unregistered TEE manager, reverts inside the diamond with its own error;
 *      that is cheap, because a bubbled revert rolls back `executeGovernanceCall`'s deletion of
 *      the timelock entry, leaving the pending call re-executable in the next block.
 *      Anyone may then push a published version to machines they name (`pushEndpoints` /
 *      `pushAdmins`, paying the instruction fee) — that is how a machine registered after the
 *      publication converges, how a publication made during a pause is delivered, and how an
 *      instruction that never reached its enclave is retried. A push SUPPLIES the configuration
 *      values (the groups / roles), which the contract re-encodes canonically with the version it
 *      holds in storage and checks against the stored hash: the values live in the
 *      `EndpointsPublished` / `AdminsPublished` log, which is where a pusher reads them from. That
 *      is a log-retention dependency, taken deliberately — storing the payload on-chain cost
 *      ~217,000 gas per PUBLIC endpoint and put a 25-group / 5-endpoint configuration (48.2 KB)
 *      at ~30.5M gas, above the 28,000,000 block gas limit on every Flare network; supplying it
 *      as calldata costs ~8,000 gas per endpoint, so the same configuration publishes at
 *      ~1.95M gas.
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
     * @param urlHash PRIVATE only: the COMMITMENT to the endpoint's URL. The URL itself is
     * delivered to the machine by a separate direct instruction, and the enclave accepts it only
     * if it hashes to this value — so the commitment is what binds the privately delivered URL to
     * the governance-published configuration. The commitment format is pinned in the TEE extension
     * build and should be salted — a bare hash of a low-entropy URL would be brute-forceable from
     * chain data. Must be zero for PUBLIC. A commitment is deliberately used instead of a
     * TEE-pubkey-encrypted URL: an on-chain ciphertext would expose the URL forever if the
     * machine's key ever leaked, a commitment reveals nothing.
     * @param secretRef The credential NAME the machine resolves — never a value (hence the name),
     * and never the URL. It is ORTHOGONAL to `kind`: it names a credential such as an API key,
     * which is provisioned separately from the URL and may be governed by a different admin role
     * entirely. Both kinds may carry one and both may leave it empty — a PUBLIC endpoint whose URL
     * has no placeholder to substitute, or a PRIVATE endpoint that needs no credential beyond the
     * URL itself, simply sets it to "". It is therefore NOT validated here, in either direction.
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
     * @param threshold How many endpoints in the group must agree; at least 1 and at most
     * `endpoints.length`, which is all the contract enforces. It does NOT check that the endpoints
     * are distinct sources, and deliberately so: a URL has unbounded equivalent spellings (host
     * case, a trailing slash, an explicit `:443`, a redundant query parameter), so any on-chain
     * comparison would be trivially bypassable while advertising a distinctness it cannot deliver
     * — and it would reject legitimate configurations, since the same host may appear twice under
     * different `secretRef` credentials and PRIVATE endpoints commit to SALTED hashes. That a
     * `threshold` of k really means k independent upstreams is therefore a property of the
     * published configuration and of the TEE extension build. Contrast `AdminRole.admins`, where
     * an `address` is canonical and the duplicate check IS a guarantee.
     * There is no floor either: a 1-of-1 group is accepted, and whether one is acceptable for a
     * given tag is a policy pinned in the TEE extension build.
     * @param endpoints The endpoints. The same upstream may appear in another group — groups are
     * separate quorums.
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

    /**
     * A feed's published configuration state, both kinds together. Packed into three storage
     * slots (the four `uint64`s share one), so a publication reads and writes one struct.
     * @param endpointsHash keccak256 of the feed's latest published endpoints payload, zero if
     * none. This is what the feed's `TeeOracleFeedStore` enforces on every submitted update, and
     * what `pushEndpoints` checks its caller-supplied values against once it has re-encoded them —
     * the payload itself is not stored, so this commitment is all the contract keeps of it.
     * @param adminsHash keccak256 of the feed's latest published admin-sets payload, zero if
     * none. Also enforced by the store and by `pushAdmins`.
     * @param endpointsVersion Version assigned to the latest endpoints publication (zero if
     * none); monotonic per feed and part of the encoded payload.
     * @param adminsVersion Version assigned to the latest admin-sets publication (zero if none).
     * @param endpointsPublishedAt Timestamp of the latest endpoints publication (zero if none).
     * @param adminsPublishedAt Timestamp of the latest admin-sets publication (zero if none).
     */
    struct FeedConfig {
        bytes32 endpointsHash;
        bytes32 adminsHash;
        uint64 endpointsVersion;
        uint64 adminsVersion;
        uint64 endpointsPublishedAt;
        uint64 adminsPublishedAt;
    }

    /**
     * The configuration versions last DISPATCHED to one machine for one feed, both kinds in a
     * single storage slot. Keeping them packed is what lets `requestFeedUpdate` check both kinds
     * of a target with one cold `SLOAD`, and makes the second kind's first write for a feed a
     * warm-slot update rather than a fresh one.
     * @param endpointsVersion Endpoints version last dispatched to the machine, zero if never.
     * @param adminsVersion Admin-sets version last dispatched to the machine, zero if never.
     */
    struct MachineVersions {
        uint64 endpointsVersion;
        uint64 adminsVersion;
    }

    /// Emitted once at initialization with the immutable per-instance configuration.
    event InstructionsSenderInitialised(uint256 indexed extensionId);

    /// Emitted when a feed update is requested; the id lets a keeper fetch the result.
    event FeedUpdateRequested(address indexed requester, bytes21 indexed feedId, bytes32 indexed instructionId);

    /// Emitted when governance publishes a new endpoint configuration for a feed, carrying the
    /// published GROUPS in full. This log is the ONLY place the configuration exists — nothing
    /// stores it — so it is where a pusher gets the `_groups` it hands straight to `pushEndpoints`,
    /// with no extraction step: what the log carries is exactly what the push takes. The
    /// surrounding `Endpoints` wrapper is deliberately NOT logged — its other two fields are the
    /// `version` and `feedId` topics above, and the push rebuilds the wrapper itself (version from
    /// storage, feed id from its own parameter), so logging it would duplicate both for nothing.
    /// Emitted UNCONDITIONALLY, including when the publication's auto-dispatch is skipped
    /// (extension emergency paused, or an empty active set): in that case no `TeeInstructionsSent`
    /// carries the payload either, so without this log the configuration would be unrecoverable
    /// and no later push could ever supply it. In the dispatching case the payload is therefore
    /// logged twice; the overlap is a deliberate trade at 8 gas per byte (~385k gas for a 48 KB
    /// payload) against ~217,000 gas per PUBLIC endpoint to keep it in storage, which put a
    /// 25-group / 5-endpoint configuration above the 28,000,000 block gas limit.
    event EndpointsPublished(
        bytes21 indexed feedId,
        uint64 indexed version,
        bytes32 endpointsHash,
        EndpointGroup[] groups
    );

    /// Emitted when governance publishes new admin signer sets for a feed, carrying the published
    /// ROLES in full. Same role, same unconditional emission and the same deliberate cost trade as
    /// `EndpointsPublished`; the source of `pushAdmins`' `_roles`, passed straight through.
    event AdminsPublished(
        bytes21 indexed feedId,
        uint64 indexed version,
        bytes32 adminsHash,
        AdminRole[] roles
    );

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
    /// The feed has no published configuration at all - neither kind, or only one of the two.
    error FeedNotConfigured();
    /// The address updater must not be zero: it can never be corrected afterwards.
    error ZeroAddressUpdater();
    error NoConfigPublished();
    error WrongConfigPayload();
    error ValueNotNeeded();
    error ZeroClaimBackAddress();

    /**
     * Requests a fresh feed observation from the given TEE machines.
     *
     * NOTE: an observation is stamped with the timestamp of the on-chain event that triggered it,
     * and the feed store's ratchet is STRICT, so at most one round per distinct block timestamp
     * can ever be published. Two keepers requesting in the same block each pay a full instruction
     * fee, but only the first of the two resulting rounds can land — the other reverts `NotNewer`
     * for ever. Equal `observedAt` therefore proves two contributions describe the same INSTANT,
     * not that they answered the same request.
     * Open to anyone; the instruction fee (msg.value) bounds spam and the feed store
     * verifies the TEE signature on the resulting feed update. Every targeted machine must
     * be at the feed's latest published generation for BOTH kinds (`isTeeIdConfigured`, else
     * `TeeIdNotConfigured`) — a lagging machine's answer would be rejected by the store, so it
     * must not be paid for. A feed with NOTHING published for one or both kinds fails earlier,
     * and separately, with `FeedNotConfigured`: the two need opposite remedies — wait for a
     * governance publication, versus push the published version to the machine — so they do not
     * share an error. The instruction message carries the ABI-encoded `FeedUpdateRequest`
     * so the machine knows which feed to observe.
     * @param _feedId The feed to observe.
     * @param _teeIds The TEE machines to ask (non-empty, unique, non-zero, on this
     * extension, at the feed's latest generation).
     * @return _instructionId Id of the dispatched instruction, also emitted in `FeedUpdateRequested`.
     */
    function requestFeedUpdate(
        bytes21 _feedId,
        address[] calldata _teeIds
    )
        external payable
        returns (bytes32 _instructionId);

    /**
     * Pushes a feed's latest published endpoint configuration to the given TEE machines.
     * Open to anyone, from the moment governance publishes it; the caller pays the instruction
     * fee (msg.value, forwarded whole) and is the claim-back address, exactly like
     * `requestFeedUpdate`. A publication already auto-dispatches to the extension's active set,
     * so this path exists for the machines that were not in it then — registered later, or out of
     * PRODUCTION at the time — and to retry an instruction that never reached its enclave.
     * Re-pushing a version a machine already holds is allowed and idempotent: it rewrites the
     * same version, so it can neither invalidate the machine nor be rate-limited into
     * uselessness. The instruction fee is the spam bound, exactly as it is for
     * `requestFeedUpdate`.
     * The list is dispatched AS GIVEN and a bad id REVERTS the whole call, never being silently
     * dropped: the caller names and pays for the machines it wants delivered to. The list must be
     * non-empty (`NoTeeIds`), free of the zero address (`ZeroTeeId`) and of duplicates
     * (`DuplicateTeeId`), and on this extension (`TeeIdNotInExtension`, checked on the first id —
     * the diamond requires all targets to share one extension); a target that is not in
     * PRODUCTION is rejected by the diamond with its own error. `NoConfigPublished` if the feed
     * has no published endpoints at all.
     * The CONFIGURATION VALUES are supplied by the caller, because nothing stores them: the
     * contract keeps only the hash, and the values live in the `EndpointsPublished` log. The
     * contract re-encodes them EXACTLY as `setEndpoints` did — `abi.encode(Endpoints({version,
     * feedId, groups}))`, with the version read from STORAGE, never from the caller — and requires
     * the result to hash to `latestEndpointsHash(_feedId)`, else `WrongConfigPayload`. Two
     * consequences: a caller cannot supply a wrong or stale version, since it does not supply one
     * at all; and stale or altered groups fail the hash check.
     * Fields are taken rather than a raw `bytes` payload deliberately. With raw bytes, hash
     * equality would depend on the CALLER's ABI encoder reproducing the published bytes exactly;
     * taking the fields and encoding canonically inside the contract means any correct set of
     * field values hashes correctly, whatever library or language the keeper uses. The payload is
     * not re-validated — a hash match proves it was validated at publication.
     * @param _feedId The feed whose latest published endpoints are pushed.
     * @param _teeIds The TEE machines to push to; `getEndpointsPushTargets` enumerates the
     * machines still behind the latest generation, which is the clean list to pass here. Price the
     * call with the diamond's `calculateFeeByTeeIds(TEE_ORACLE_OP_TYPE, SET_ENDPOINTS_COMMAND,
     * _teeIds)`.
     * @param _groups The tagged endpoint groups of the feed's latest publication, taken verbatim
     * from the `groups` field of its `EndpointsPublished` event.
     * @return _instructionId Id of the dispatched instruction.
     */
    function pushEndpoints(
        bytes21 _feedId,
        address[] calldata _teeIds,
        EndpointGroup[] calldata _groups
    )
        external payable
        returns (bytes32 _instructionId);

    /**
     * Pushes a feed's latest published admin signer sets to the given TEE machines.
     * Same caller, fee, validation and revert semantics as `pushEndpoints`, including the
     * caller-supplied values re-encoded here against the version in storage and checked against
     * the stored hash, with its own version and per-machine version records — the two kinds are
     * pushed independently, and each has its own commitment.
     * @param _feedId The feed whose latest published admin sets are pushed.
     * @param _teeIds The TEE machines to push to; see `getAdminsPushTargets`.
     * @param _roles The role-tagged admin sets of the feed's latest publication, taken verbatim
     * from the `roles` field of its `AdminsPublished` event.
     * @return _instructionId Id of the dispatched instruction.
     */
    function pushAdmins(
        bytes21 _feedId,
        address[] calldata _teeIds,
        AdminRole[] calldata _roles
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
     * Whether a TEE machine is at the feed's LATEST published generation for both kinds, i.e.
     * `expectedEndpointsVersion` equals `endpointsVersion` and `expectedAdminsVersion` equals
     * `adminsVersion`, with both feed-level versions non-zero. This is the precondition
     * `requestFeedUpdate` enforces per target, because the feed store gates submissions on the
     * feed's latest published hash: an observation from a lagging machine would be rejected.
     * Dispatch, not proof — the version record says what was last DISPATCHED to the machine, so
     * a machine whose instruction never reached its enclave still reads as current here and can
     * waste one request fee before a re-push. Proof-of-running only shows up when the machine's
     * feed updates pass the store's hash check.
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
     * Returns every machine of this extension that still NEEDS an endpoints push, i.e. the
     * extension's PRODUCTION machines (`getActiveTeeMachines(extensionId)`) whose
     * `expectedEndpointsVersion` is not the feed's latest `endpointsVersion`. Empty if the feed
     * has no published endpoints.
     * A keeper's entry point: the result is a ready-to-use `_teeIds` argument for `pushEndpoints`
     * (the `_groups` argument comes from the feed's `EndpointsPublished` log), and the
     * diamond's `calculateFeeByTeeIds` prices it. Machines already at the latest version are left
     * out here because they need nothing — `pushEndpoints` still accepts them, so an undelivered
     * instruction can be retried. Unpaginated: it is a view, so the loop over the extension's
     * active set costs the caller nothing on-chain.
     *
     * NOT A COMPLETE CONVERGENCE MECHANISM, and deliberately so. Two limitations a keeper must
     * cover from elsewhere:
     * - This is a comparison of DISPATCHED versions, and nothing here observes a machine's local
     *   state. A machine paused and unpaused under the SAME id with no publication in between
     *   keeps its recorded version, so it is omitted from this list even though its enclave may
     *   have lost the configuration entirely; the same holds for a restart, a re-provisioning, or
     *   an instruction that was dispatched but never applied. Keepers must therefore also react to
     *   restart / lost-state / failed-delivery signals and push to those machines EXPLICITLY,
     *   which always works: the push applies no version filter and re-pushing a version a machine
     *   already holds is idempotent. Automatic discovery of such a case would need a machine
     *   lifecycle generation or an acknowledgement signal, which this contract does not have.
     * - This view is NOT emergency-pause aware, unlike `get*PublicationFee`. While the extension
     *   is paused it keeps reporting who is behind, even though every push will revert
     *   (`EmergencyPauseActive`), so a caller that acts on it must check the pause state
     *   separately (`isExtensionEmergencyPaused`). The asymmetry is intentional: the fee views'
     *   output is ACTIONABLE — it is the value to attach, and during a pause it would be the wrong
     *   value — whereas "who is behind" stays true while paused, and blinding a diagnostic exactly
     *   when a problem is being diagnosed is worse than making its caller check one more thing.
     * @param _feedId The feed id.
     * @return _teeIds The pushable machines.
     */
    function getEndpointsPushTargets(
        bytes21 _feedId
    )
        external view
        returns (address[] memory _teeIds);

    /**
     * Returns every machine of this extension that still needs an admin-sets push.
     * See `getEndpointsPushTargets`, including both of its limitations: a same-id pause/unpause or
     * any other loss of local state is invisible here, and the view is not emergency-pause aware.
     * @param _feedId The feed id.
     * @return _teeIds The pushable machines.
     */
    function getAdminsPushTargets(
        bytes21 _feedId
    )
        external view
        returns (address[] memory _teeIds);

    /**
     * Prices a governance endpoints publication: the machines its auto-dispatch would target —
     * the extension's whole active set — and the fee they cost. This is the value the
     * governance executor should attach to `executeGovernanceCall`, and it must be read in the
     * block the execution lands in, since the target set is the live active set at execution
     * time. Kept as a view of its own, rather than left to the executor to assemble from
     * `getActiveTeeMachines` plus `calculateFeeByTeeIds`, because getting the value wrong costs
     * something either way: too little reverts the execution inside the diamond (`FeeTooLow`),
     * and whatever is attached is handed to the reward manager in full — the contracts neither
     * separate a surplus from the fee nor return it.
     * A fleet that shrinks or a fee row that changes between the read and the execution therefore
     * makes an earlier quote an overpayment, not a revert — hence "read it in the executing
     * block".
     * Note this is deliberately NOT `getEndpointsPushTargets`: a fresh publication is new to
     * every machine of the extension, including the ones currently at the previous latest
     * version, which that view filters out. While the extension is emergency paused it returns
     * no machines and no fee, mirroring the publication itself: the dispatch is skipped and the
     * execution must attach no value (see `setEndpoints`), as it must when the machine list here
     * is empty.
     * @return _teeIds The machines the publication would dispatch to.
     * @return _fee The instruction fee for exactly those machines.
     */
    function getEndpointsPublicationFee()
        external view
        returns (
            address[] memory _teeIds,
            uint256 _fee
        );

    /**
     * Prices a governance admin-sets publication. See `getEndpointsPublicationFee`; the machine
     * list is the same, the fee row is the `SET_ADMINS` one.
     * @return _teeIds The machines the publication would dispatch to.
     * @return _fee The instruction fee for exactly those machines.
     */
    function getAdminsPublicationFee()
        external view
        returns (
            address[] memory _teeIds,
            uint256 _fee
        );

    /**
     * Returns a feed's whole published configuration state — both hashes, both versions and both
     * publication timestamps — in one call, so a dashboard or keeper does not need six.
     * All fields are zero for a feed that has never been published to. For tooling: the feed
     * store deliberately keeps reading `latestEndpointsHash` / `latestAdminsHash` instead, since
     * this would also load the packed versions and timestamps slot it has no use for.
     * @param _feedId The feed id.
     * @return The feed's configuration state.
     */
    function getFeedConfig(
        bytes21 _feedId
    )
        external view
        returns (FeedConfig memory);

    /**
     * Returns the configuration versions last dispatched to a TEE machine for a feed, both kinds
     * at once. See `expectedEndpointsVersion` / `expectedAdminsVersion` for the single-field
     * getters and for what "dispatched" does and does not prove.
     * @param _feedId The feed id.
     * @param _teeId The TEE machine id.
     * @return The machine's dispatched versions for the feed.
     */
    function getMachineVersions(
        bytes21 _feedId,
        address _teeId
    )
        external view
        returns (MachineVersions memory);

    /**
     * Returns the keccak256 of a feed's latest published endpoints payload (zero if none).
     * Feed-level, and the value the feed's `TeeOracleFeedStore` enforces on every submitted
     * update: a publication therefore invalidates every machine still running the previous
     * generation until it adopts the new one. It is also the ONLY on-chain trace of the payload,
     * and what `pushEndpoints` checks its re-encoded `_groups` against.
     * @param _feedId The feed id.
     */
    function latestEndpointsHash(
        bytes21 _feedId
    )
        external view
        returns (bytes32);

    /**
     * Returns the keccak256 of a feed's latest published admin-sets payload (zero if none).
     * Enforced by the feed store on every submitted update, exactly like `latestEndpointsHash`.
     * @param _feedId The feed id.
     */
    function latestAdminsHash(
        bytes21 _feedId
    )
        external view
        returns (bytes32);

    /**
     * Returns the timestamp of a feed's latest endpoints publication (zero if none).
     * @param _feedId The feed id.
     */
    function endpointsPublishedAt(
        bytes21 _feedId
    )
        external view
        returns (uint64);

    /**
     * Returns the timestamp of a feed's latest admin-sets publication (zero if none).
     * @param _feedId The feed id.
     */
    function adminsPublishedAt(
        bytes21 _feedId
    )
        external view
        returns (uint64);

    /**
     * Returns the version assigned to a feed's most recently published endpoint
     * configuration. Governance signs it into each `setEndpoints` call and the contract requires
     * it to be exactly this value plus one, so the stream is strictly consecutive; the version is
     * part of the encoded payload, so republishing identical content still yields a new version
     * and a new hash. The next publication of this feed's endpoints must therefore sign
     * `endpointsVersion(_feedId) + 1`.
     * @param _feedId The feed id.
     */
    function endpointsVersion(
        bytes21 _feedId
    )
        external view
        returns (uint64);

    /**
     * Returns the version assigned to a feed's most recently published admin sets.
     * Its own consecutive stream, independent of the endpoints one: the next `setAdmins` for this
     * feed must sign `adminsVersion(_feedId) + 1`. See `endpointsVersion`.
     * @param _feedId The feed id.
     */
    function adminsVersion(
        bytes21 _feedId
    )
        external view
        returns (uint64);

    /**
     * Returns the endpoints version last DISPATCHED to a TEE machine for a feed (zero if none).
     * Equal to `endpointsVersion(_feedId)` once the machine has been sent the latest
     * publication; lower while it lags; versions may skip numbers (v1 straight to v5). This is
     * the only per-machine configuration record kept — it answers "which machines still need a
     * push" for `getEndpointsPushTargets` and gates `requestFeedUpdate`, while what the feed
     * store enforces is the feed-level `latestEndpointsHash`.
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
     * Returns the admins version last pushed to a TEE machine for a feed (zero if none).
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
