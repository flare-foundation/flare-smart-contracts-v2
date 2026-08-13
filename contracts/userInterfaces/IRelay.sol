// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9;

import { RandomNumberV2Interface } from "./LTS/RandomNumberV2Interface.sol";

/**
 * Relay interface.
 */
interface IRelay is RandomNumberV2Interface {

    struct FeeConfig {
        uint8 protocolId;   // Protocol id for which the fee is set
        uint256 fee;        // Fee in native wei, or in base units of the configured fee
                            // token when one is set (see feeToken)
    }

    struct RelayInitialConfig {
        uint32 initialRewardEpochId;                           // The initial reward epoch id.
        uint32 startingVotingRoundIdForInitialRewardEpochId;   // The starting voting round id for the initial
                                                               // reward epoch.
        bytes32 initialSigningPolicyHash;                      // The initial signing policy hash.
        uint8 randomNumberProtocolId;                          // The protocol id of the random number protocol.
        uint32 firstVotingRoundStartTs;                        // The timestamp of the first voting round start.
        uint8 votingEpochDurationSeconds;                      // The duration of a voting epoch in seconds.
        uint32 firstRewardEpochStartVotingRoundId;             // The start voting round id of the first reward epoch.
        uint16 rewardEpochDurationInVotingEpochs;              // The duration of a reward epoch in voting epochs.
        uint16 thresholdIncreaseBIPS;                          // The threshold increase in BIPS for signing with
                                                               // old signing policy.
        uint32 messageFinalizationWindowInRewardEpochs;        // The window of reward epochs for finalizing
                                                               // the protocol messages.
        address payable feeCollectionAddress;                  // Fee collection address
        FeeConfig[] feeConfigs;                                // Fee configurations
        address feeToken;                                      // ERC-20 the verify() fee is paid in;
                                                               // zero = native coin. For chains without
                                                               // a (spendable) native token. Relay mode
                                                               // only; must be zero on a home deploy.
        address[] feeExemptAddresses;                          // Accounts exempt from the verify() fee at
                                                               // deployment (e.g. DVN adapters). Relay mode
                                                               // only; must be empty on a home deploy.
        uint256 sourceChainId;                                 // Source network id bound into every
                                                               // policy hash and signed digest. Explicit and
                                                               // nonzero on EVERY deployment; a home deploy
                                                               // (signingPolicySetter set) forces it to
                                                               // equal block.chainid.
        uint256 timelockDurationSeconds;                       // Initial owner-timelock duration applied to
                                                               // the fee setters and upgrades (see
                                                               // IOwnableWithTimelock); at most 7 days.
    }

    // Event is emitted when a new signing policy is initialized by the signing policy setter.
    event SigningPolicyInitialized(
        uint24 indexed rewardEpochId,   // Reward epoch id
        uint32 startVotingRoundId,      // First voting round id of validity.
                                        // Usually it is the first voting round of reward epoch rewardEpochId.
                                        // It can be later,
                                        // if the confirmation of the signing policy on Flare blockchain gets delayed.
        uint16 threshold,               // Confirmation threshold (absolute value of noramalised weights).
        uint256 seed,                   // Random seed.
        address[] voters,               // The list of eligible voters in the canonical order.
        uint16[] weights,               // The corresponding list of normalised signing weights of eligible voters.
                                        // Normalisation is done by compressing the weights from 32-byte values to
                                        // 2 bytes, while approximately keeping the weight relations.
        bytes signingPolicyBytes,       // The full signing policy byte encoded.
        uint64 timestamp                // Timestamp when this happened
    );

    // Event is emitted when a signing policy is relayed.
    // It contains minimalistic data in order to save gas. Data about the signing policy are
    // extractable from the calldata, assuming prefered usage of direct top-level call to relay().
    event SigningPolicyRelayed(
        uint256 indexed rewardEpochId        // Reward epoch id
    );

    // Event is emitted when a protocol message is relayed.
    event ProtocolMessageRelayed(
        uint8 indexed protocolId,           // Protocol id
        uint32 indexed votingRoundId,       // Voting round id
        bool isSecureRandom,                // Secure random flag
        bytes32 merkleRoot                  // Merkle root of the protocol message
    );

    // Event is emitted when a random number is relayed (random-number protocol).
    event RandomNumberRelayed(
        uint32 indexed votingRoundId,       // Voting round id of the random
        uint256 randomNumber,               // The relayed (Merkle-proven) random number value
        bool isSecureRandom                 // Whether the random is secure
    );

    /// The verify() fee configuration was set — once at every relay-mode deployment (seeded
    /// config) and on every setProtocolFees call. The event is SELF-CONTAINED: it carries the
    /// fee token (zero = native coin) and the complete fee table; every protocol not listed
    /// has fee 0. The latest event therefore fully describes the current fee configuration.
    event ProtocolFeesSet(
        address indexed feeToken,
        FeeConfig[] feeConfigs
    );

    /// A verify() fee exemption was set — at deployment (seeded config) or by the owner.
    event FeeExemptionSet(
        address indexed account,
        bool exempt
    );

    /// The verify() fee-collection recipient was set — at deployment (seeded config) or by
    /// the owner.
    event FeeCollectionAddressSet(
        address indexed feeCollectionAddress
    );

    /// The trusted signing-policy setter was set — at deployment or by the owner (e.g. after
    /// a FlareSystemsManager redeployment).
    event SigningPolicySetterSet(
        address indexed signingPolicySetter
    );


    // ---- Typed failure ABI. relay() raises these from its assembly via 4-byte selectors.
    error AlreadyRelayed();
    error BadS();
    error BadV();
    error DelayedSignPolicy();
    /// A protocol id appears more than once in a supplied fee table — the self-contained
    /// ProtocolFeesSet event must be unambiguous.
    error DuplicateProtocolId();
    error EcrecoverError();
    error EcrecoverReturnedBadData();
    error FeeCollectionAddressZero();
    error FeeConfigNotAllowed();
    /// An initial fee-exempt address is the zero address.
    error FeeExemptAddressZero();
    /// Initial fee-exempt addresses supplied on a setter-mode (home) deploy, which charges no fee.
    error FeeExemptionsNotAllowed();
    /// The deprecated protocolFeeInWei() getter was called while a fee token is active — the
    /// fee is then in token base units, not wei; use protocolFee() and feeToken() instead.
    error FeeTokenActive();
    error FeeTransferFailed();
    error HistoryBeforeStart();
    error IncorrectMerkleProof();
    error IndexOutOfOrder();
    error IndexOutOfRange();
    error InitialSigningPolicyHashZero();
    error InvalidConfigHash();
    error InvalidInitialStartingVotingRoundId();
    error InvalidProtocolId();
    error InvalidRandomNumberProof();
    error InvalidRandomNumberProtocolId();
    error InvalidSignPolicyLength();
    error InvalidSignPolicyMetadata();
    error InvalidVotingRoundId();
    error MerkleProofInvalid();
    error MessageTooOld();
    /// Native value was sent to verify() while a fee token is active — the fee is then paid
    /// exclusively in that token (via allowance), so any attached value would strand.
    error MsgValueNotAllowed();
    error MustUseNewSignPolicy();
    error NoAccessToMerkleRoots();
    error NoAccessToSigningPolicyHashes();
    error NoNewSignPolicySize();
    error NoRandomNumber();
    error NoSignatureCount();
    error NotEnoughSignatures();
    error NotEnoughWeight();
    error NotFinalized();
    error NotNextRewardEpoch();
    error NotWithLastInitialized();
    error OldRelayIncompatible();
    /// Old-relay migration is home-only: a relay-mode (mirror) deployment charges verify() fees,
    /// and delegating pre-boundary calls to an old relay would entangle its fee schedule with
    /// this contract's fee and fee-exemption logic. Mirrors seed a fresh source snapshot instead.
    error OldRelayNotAllowedInRelayMode();
    error OldRelayVerificationFailed();
    error OldRelayWrongFirstRewardEpochStart();
    error OldRelayWrongRewardEpochDuration();
    error OldRelayWrongStartTs();
    error OldRelayWrongVotingEpochDuration();
    error OnlySigningPolicySetterRole();
    /// A configured protocol fee is zero. With full-replace fee semantics a free protocol is
    /// expressed by omitting it, so every listed (protocolId, fee) entry must be nonzero.
    error ProtocolFeeZero();
    error RefundFailed();
    error RewardEpochDurationZero();
    error SignPolicyRelayDisabled();
    error SigningPolicyEmpty();
    error SigningPolicyHashMismatch();
    /// Updating the signing-policy setter on a relay-mode deployment (the mode is fixed at
    /// deploy, so a relay-mode deployment can never gain a setter).
    error SigningPolicySetterNotAllowed();
    /// The signing-policy setter update is the zero address (the mode cannot be cleared).
    error SigningPolicySetterZero();
    error SourceChainIdMismatchOnHomeDeploy();
    /// The configured source network id is zero.
    error SourceChainIdZero();
    error ThresholdIncreaseTooSmall();
    error ThresholdTooHigh();
    error ThresholdTooLow();
    error TooLowFee();
    error TooManyVoters();
    error TooShortMessage();
    error TotalWeightTooBig();
    error UnreachableCode();
    error VerificationFailed();
    error VotersWeightsSizeMismatch();
    error VotingEpochDurationZero();
    error WrongMessageFormat();
    error WrongMessageFormat2();
    error WrongSignPolicyRewardEpoch();
    error WrongSignature();
    error WrongSizeForNewSignPolicy();
    error WrongVerificationData();
    error ZeroMerkleRoot();
    error ZeroSigner();

    /**
     * Checks the relay message for sufficient weight of signatures for the _messageHash
     * signed for protocol message Merkle root of the form (1, 0, 0, _messageHash).
     * If the check is successful, reward epoch id of the signing policy is returned.
     * Otherwise the function reverts.
     * **SECURITY:** This is a generic signature-quorum oracle. Relay verifies EIP-191
     *           signatures over `keccak256(sourceChainId ‖ (1, 0, 0, _messageHash))` using
     *           the signing policy encoded in `_relayMessage`. `sourceChainId` identifies the
     *           configured signing source; it does not bind the destination chain, this Relay
     *           instance, the consuming contract, an operation, or a nonce. The same signatures
     *           can therefore be replayed against another Relay with the same source-domain and
     *           accepted signing policy, including a Relay on another destination chain. Callers
     *           must domain-separate `_messageHash` for their application, including every replay
     *           boundary they require (for example destination chain id, consuming contract,
     *           operation and nonce).
     * @param _relayMessage Full calldata for the `relay()` self-call, including its 4-byte selector.
     * @param _messageHash The hash of the message.
     * @return _rewardEpochId The reward epoch id of the signing policy.
     */
    function verifyCustomSignature(
        bytes calldata _relayMessage,
        bytes32 _messageHash
    )
        external
        returns (uint256 _rewardEpochId);

    /**
     * Same check as `verifyCustomSignature`, but against a caller-chosen signature-weight
     * threshold instead of the signing policy's own. The override applies ONLY to this
     * verification (the protocolId == 1 path, which stores nothing); protocol
     * finalization and signing-policy relay always use the policy threshold.
     * The same domain-separation caveat as `verifyCustomSignature` applies.
     * NOTE: an override below the signing policy threshold weakens only this caller's acceptance
     * rule — the result then means "more than the requested fraction of the weight signed",
     * not that the protocol's quorum was reached.
     * @param _relayMessage Full calldata for the `relay()` self-call, including its 4-byte selector.
     * @param _messageHash The hash of the message.
     * @param _thresholdBIPS The threshold in BIPS of the signing policy's total normalized
     * weight (e.g. 5000 = 50%); 0 uses the signing policy's own threshold (the
     * `Fdc2RequestHeader.thresholdBIPS` convention). The effective threshold is
     * `floor(totalWeight * _thresholdBIPS / 10000)` and is compared with strict
     * inequality. This is equivalent to requiring
     * `signedWeight * 10000 > totalWeight * _thresholdBIPS`, so 5000 requires strictly
     * more than 50% of the weight. Values of 10000 and above are unsatisfiable and
     * revert with `ThresholdTooHigh`.
     * @return _rewardEpochId The reward epoch id of the signing policy.
     */
    function verifyCustomSignatureWithThreshold(
        bytes calldata _relayMessage,
        bytes32 _messageHash,
        uint16 _thresholdBIPS
    )
        external
        returns (uint256 _rewardEpochId);

    /**
     * Finalization function for new signing policies and protocol messages.
     * It can be used as finalization contract on Flare chain or as relay contract on other EVM chain.
     * Can be called in two modes. It expects calldata that is parsed in a custom manner.
     * Hence the transaction calls should assemble relevant calldata in the 'data' field.
     * Depending on the data provided, the contract operates in two modes:
     * (1) Relaying signing policy. The structure of the calldata is:
     *        function signature (4 bytes) + active signing policy
     *             + 0 (1 byte) + new signing policy
     *             + signature count (2 bytes) + indexed ECDSA signatures (67 bytes each).
     *     Each policy has variable length `43 + 22 * numberOfVoters`, so the
     *     complete calldata length depends on both voter counts.
     * (2) Relaying signed message. The structure of the calldata is:
     *        function signature (4 bytes) + signing policy
     *           + signed message (38 bytes) + signature count (2 bytes)
     *           + indexed ECDSA signatures (67 bytes each).
     *     For the configured random-number protocol, the signatures are followed by a
     *     random number (32 bytes) and zero or more Merkle-proof nodes (32 bytes each).
     *     This case splits into two subcases:
     *     - protocolId = 1: Message id must be of the form (protocolId, 0, 0, merkleRoot).
     *       The validity of the signatures of sufficient weight is checked and if
     *       successful, raw return data contains the merkleRoot from the message (32 bytes)
     *       followed by the reward epoch id of the signing policy (3 bytes). No state is written.
     *     - protocolId > 1: The validity of the signatures of sufficient weight is checked and if
     *       it is valid, the merkleRoot is published for protocolId and votingRoundId.
     *     Signature indices must be strictly increasing, and accepted weight must strictly
     *     exceed the applicable threshold.
     * Reverts if relaying is not successful.
     */
    function relay() external returns (bytes memory);

    /**
     * Verifies the leaf (or intermediate node) with the Merkle proof against the Merkle root
     * for given protocol id and voting round id.
     * A fee may need to be paid. It is protocol specific.
     * Payment medium depends on the configuration (see feeToken):
     * - No fee token set (all home deployments, default on mirrors): the fee is paid in native
     *   coin via msg.value. Overpayment above the protocol fee is refunded to the caller via a
     *   value-bearing call, so a contract caller MUST be able to receive ETH (or send exactly
     *   the fee); otherwise verify() reverts.
     * - Fee token set (mirror deployments on chains without a spendable native token): the exact
     *   fee is pulled via the token's transferFrom to the fee-collection address, so the caller
     *   MUST approve at least the fee beforehand. msg.value MUST be zero (MsgValueNotAllowed);
     *   there is no refund path.
     * **NOTE:** A leaf equal to the (finalized, non-zero) root verifies with an empty proof —
     *           a standard Merkle property. Off-chain leaf encoding MUST be domain-separated from internal
     *           and root node hashes so an internal node cannot be presented as a differently-typed leaf.
     * @param _protocolId The protocol id.
     * @param _votingRoundId The voting round id.
     * @param _leaf The leaf (or intermediate node) to verify.
     * @param _proof The Merkle proof.
     * @return True if the verification is successful.
     */
    function verify(uint256 _protocolId, uint256 _votingRoundId, bytes32 _leaf, bytes32[] calldata _proof)
        external payable
        returns (bool);

    /**
     * Returns the address of the signing policy setter.
     * If the address is zero, the contract is used as a pure relay,
     * otherwise the contract operates in setter (home) mode.
     */
    function signingPolicySetter() external view returns (address);

    /**
     * Returns the signing policy hash for given reward epoch id.
     * The function is reverted if signingPolicySetter is NOT set, hence on all
     * deployments where the contract is used as a pure relay.
     * The returned hash is source-bound: keccak256(sourceChainId ‖ encoded policy bytes) —
     * one keccak over the 32-byte source chain id followed by the raw 43 + 22 * n byte encoding, no
     * padding. Off-chain code comparing against a locally computed policy hash must use the same scheme.
     * Epochs served by an `oldRelay` fallback return that contract's configured hash format.
     * @param _rewardEpochId The reward epoch id.
     * @return _signingPolicyHash The signing policy hash.
     */
    function toSigningPolicyHash(uint256 _rewardEpochId) external view returns (bytes32 _signingPolicyHash);

    /**
     * Returns true if there is finalization for a given protocol id and voting round id.
     * @param _protocolId The protocol id.
     * @param _votingRoundId The voting round id.
     */
    function isFinalized(uint256 _protocolId, uint256 _votingRoundId) external view returns (bool);

    /**
     * Returns the Merkle root for given protocol id and voting round id.
     * The function is reverted if signingPolicySetter is NOT set, hence on all
     * deployments where the contract is used as a pure relay.
     * @param _protocolId The protocol id.
     * @param _votingRoundId The voting round id.
     * @return _merkleRoot The Merkle root.
     */
    function merkleRoots(uint256 _protocolId, uint256 _votingRoundId) external view returns (bytes32 _merkleRoot);

    /**
     * Returns the start voting round id for given reward epoch id.
     * @param _rewardEpochId The reward epoch id.
     * @return _startingVotingRoundId The start voting round id.
     */
    function startingVotingRoundIds(uint256 _rewardEpochId) external view returns (uint256 _startingVotingRoundId);

    /**
     * Returns the voting round id for given timestamp.
     * @param _timestamp The timestamp.
     * @return _votingRoundId The voting round id.
     */
    function getVotingRoundId(uint256 _timestamp) external view returns (uint256 _votingRoundId);

    /**
     * Returns last initialized reward epoch data.
     * @return _lastInitializedRewardEpoch Last initialized reward epoch.
     * @return _startingVotingRoundIdForLastInitializedRewardEpoch Starting voting round id for it.
     */
    function lastInitializedRewardEpochData()
        external view
        returns (
            uint32 _lastInitializedRewardEpoch,
            uint32 _startingVotingRoundIdForLastInitializedRewardEpoch
        );

    /**
     * Returns fee collection address.
     */
    function feeCollectionAddress() external view returns (address payable);

    /**
     * Returns the fee for one verification of a given protocol id, in native wei — or in
     * base units of the configured fee token when one is set (see feeToken).
     * @param _protocolId The protocol id.
     */
    function protocolFee(uint256 _protocolId) external view returns (uint256);

    /**
     * Returns the ERC-20 token the verify() fee is paid in, or the zero address when fees
     * are paid in the native coin (all home deployments, default on mirrors). A configured
     * token is always a standard exact-transfer ERC-20 — fee-on-transfer or rebasing tokens
     * are unsupported.
     */
    function feeToken() external view returns (address);

    /**
     * Returns the complete fee table: every protocol id with a nonzero verify() fee and that
     * fee, denominated per feeToken() (native wei when it is zero). Order is unspecified.
     */
    function getFeeConfigs() external view returns (FeeConfig[] memory _feeConfigs);

    /**
     * Returns fee in wei for one verification of a given protocol id.
     * @dev Deprecated pre-feeToken name of protocolFee(). Reverts with FeeTokenActive when a
     * fee token is set, so a token-denominated fee can never be misread as a wei amount.
     * @param _protocolId The protocol id.
     */
    function protocolFeeInWei(uint256 _protocolId) external view returns (uint256);

    /**
     * Returns whether `account` may call `verify()` without paying the protocol fee.
     */
    function feeExemptAddress(address account) external view returns (bool);

    /**
     * Returns the configured source-network id: the network whose
     * voter quorum this Relay verifies. Equals block.chainid on home deployments.
     */
    function sourceChainId() external view returns (uint256);

    /**
     * Returns the state data.
     * @return randomNumberProtocolId The protocol id of the random number protocol.
     * @return firstVotingRoundStartTs The timestamp of the first voting round start.
     * @return votingEpochDurationSeconds The duration of a voting epoch in seconds.
     * @return firstRewardEpochStartVotingRoundId The start voting round id of the first reward epoch.
     * @return rewardEpochDurationInVotingEpochs The duration of a reward epoch in voting epochs.
     * @return thresholdIncreaseBIPS The threshold increase in BIPS for signing with old signing policy.
     * @return randomVotingRoundId The random voting round id.
     * @return isSecureRandom The secure random flag.
     * @return lastInitializedRewardEpoch The last initialized reward epoch.
     * @return noSigningPolicyRelay The flag indicating no signing policy relay.
     * @return messageFinalizationWindowInRewardEpochs The window of reward epochs for finalizing the
     *  protocol messages.
     */
    function stateData()
        external
        view
        returns (
            uint8 randomNumberProtocolId,
            uint32 firstVotingRoundStartTs,
            uint8 votingEpochDurationSeconds,
            uint32 firstRewardEpochStartVotingRoundId,
            uint16 rewardEpochDurationInVotingEpochs,
            uint16 thresholdIncreaseBIPS,
            uint32 randomVotingRoundId,
            bool isSecureRandom,
            uint32 lastInitializedRewardEpoch,
            bool noSigningPolicyRelay,
            uint32 messageFinalizationWindowInRewardEpochs
        );

}
