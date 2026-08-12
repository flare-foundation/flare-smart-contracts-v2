// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9;

import { RandomNumberV2Interface } from "./LTS/RandomNumberV2Interface.sol";

/**
 * Relay interface.
 */
interface IRelay is RandomNumberV2Interface {

    struct FeeConfig {
        uint8 protocolId;   // Protocol id for which the fee is set
        uint256 feeInWei;   // Fee in wei
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
        address[] feeExemptAddresses;                          // Accounts exempt from the verify() fee at
                                                               // deployment (e.g. DVN adapters). Relay mode
                                                               // only; must be empty on a home deploy.
        uint256 sourceChainId;                                 // RLY-23 source network id bound into every
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

    /// A protocol verify() fee was set — at deployment (seeded config) or by the owner.
    event ProtocolFeeSet(
        uint8 indexed protocolId,
        uint256 feeInWei
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


    // ---- Typed failure ABI (replaces the pre-2026-08 string reasons; the legacy string is
    // ---- noted per error). relay() raises these from its assembly via 4-byte selectors.
    /// Legacy reason: "Already relayed".
    error AlreadyRelayed();
    /// Legacy reason: "Bad s".
    error BadS();
    /// Legacy reason: "Bad v".
    error BadV();
    /// Legacy reason: "Delayed sign policy".
    error DelayedSignPolicy();
    /// Legacy reason: "ecrecover error".
    error EcrecoverError();
    /// Legacy reason: "ecrecover returned bad data".
    error EcrecoverReturnedBadData();
    /// Legacy reason: "fee collection address zero".
    error FeeCollectionAddressZero();
    /// Legacy reason: "fee cannot be set".
    error FeeConfigNotAllowed();
    /// An initial fee-exempt address is the zero address.
    error FeeExemptAddressZero();
    /// Initial fee-exempt addresses supplied on a setter-mode (home) deploy, which charges no fee.
    error FeeExemptionsNotAllowed();
    /// Legacy reason: "Transfer failed".
    error FeeTransferFailed();
    /// Legacy reason: "before the start".
    error HistoryBeforeStart();
    /// Legacy reason: "Incorrect merkle proof".
    error IncorrectMerkleProof();
    /// Legacy reason: "Index out of order".
    error IndexOutOfOrder();
    /// Legacy reason: "Index out of range".
    error IndexOutOfRange();
    /// Legacy reason: "initial signing policy hash zero".
    error InitialSigningPolicyHashZero();
    /// Legacy reason: "Invalid config hash".
    error InvalidConfigHash();
    /// Legacy reason: "invalid initial starting voting round id".
    error InvalidInitialStartingVotingRoundId();
    /// Legacy reason: "invalid protocol id".
    error InvalidProtocolId();
    /// Legacy reason: "Invalid random number proof".
    error InvalidRandomNumberProof();
    /// Legacy reason: "random number protocol id must be > 1".
    error InvalidRandomNumberProtocolId();
    /// Legacy reason: "Invalid sign policy length".
    error InvalidSignPolicyLength();
    /// Legacy reason: "Invalid sign policy metadata".
    error InvalidSignPolicyMetadata();
    /// Legacy reason: "Invalid voting round id".
    error InvalidVotingRoundId();
    /// Legacy reason: "merkle proof invalid".
    error MerkleProofInvalid();
    /// Legacy reason: "Message too old".
    error MessageTooOld();
    /// Legacy reason: "Must use new sign policy".
    error MustUseNewSignPolicy();
    /// Legacy reason: "no access to merkle roots".
    error NoAccessToMerkleRoots();
    /// Legacy reason: "no access to signing policy hashes".
    error NoAccessToSigningPolicyHashes();
    /// Legacy reason: "No new sign policy size".
    error NoNewSignPolicySize();
    /// Legacy reason: "No random number" / "no random number".
    error NoRandomNumber();
    /// Legacy reason: "No signature count".
    error NoSignatureCount();
    /// Legacy reason: "Not enough signatures".
    error NotEnoughSignatures();
    /// Legacy reason: "Not enough weight".
    error NotEnoughWeight();
    /// Legacy reason: "not finalized".
    error NotFinalized();
    /// Legacy reason: "Not next reward epoch" / "not next reward epoch".
    error NotNextRewardEpoch();
    /// Legacy reason: "Not with last intialized".
    error NotWithLastInitialized();
    /// Legacy reason: "old relay incompatible".
    error OldRelayIncompatible();
    /// Legacy reason: "old relay verification failed".
    error OldRelayVerificationFailed();
    /// Legacy reason: "wrong first reward epoch start".
    error OldRelayWrongFirstRewardEpochStart();
    /// Legacy reason: "wrong reward epoch duration".
    error OldRelayWrongRewardEpochDuration();
    /// Legacy reason: "wrong start ts".
    error OldRelayWrongStartTs();
    /// Legacy reason: "wrong voting epoch duration".
    error OldRelayWrongVotingEpochDuration();
    /// Legacy reason: "only sign policy setter".
    error OnlySigningPolicySetterRole();
    /// Legacy reason: "Refund failed".
    error RefundFailed();
    /// Legacy reason: "reward epoch duration zero".
    error RewardEpochDurationZero();
    /// Legacy reason: "Sign policy relay disabled".
    error SignPolicyRelayDisabled();
    /// Legacy reason: "must be non-trivial".
    error SigningPolicyEmpty();
    /// Legacy reason: "Signing policy hash mismatch".
    error SigningPolicyHashMismatch();
    /// Updating the signing-policy setter on a relay-mode deployment (the mode is fixed at
    /// deploy, so a relay-mode deployment can never gain a setter).
    error SigningPolicySetterNotAllowed();
    /// The signing-policy setter update is the zero address (the mode cannot be cleared).
    error SigningPolicySetterZero();
    /// Legacy reason: "source chain id must match on home deploy".
    error SourceChainIdMismatchOnHomeDeploy();
    /// The configured RLY-23 source network id is zero.
    error SourceChainIdZero();
    /// Legacy reason: "threshold increase too small".
    error ThresholdIncreaseTooSmall();
    /// Legacy reason: "too big threshold".
    error ThresholdTooHigh();
    /// Legacy reason: "too small threshold".
    error ThresholdTooLow();
    /// Legacy reason: "too low fee".
    error TooLowFee();
    /// Legacy reason: "too many voters".
    error TooManyVoters();
    /// Legacy reason: "Too short message".
    error TooShortMessage();
    /// Legacy reason: "total weight too big".
    error TotalWeightTooBig();
    /// Legacy reason: "This should never happen".
    error UnreachableCode();
    /// Legacy reason: "Verification failed".
    error VerificationFailed();
    /// Legacy reason: "size mismatch".
    error VotersWeightsSizeMismatch();
    /// Legacy reason: "voting epoch duration zero".
    error VotingEpochDurationZero();
    /// Legacy reason: "Wrong message format".
    error WrongMessageFormat();
    /// Legacy reason: "Wrong message format2".
    error WrongMessageFormat2();
    /// Legacy reason: "Wrong sign policy reward epoch".
    error WrongSignPolicyRewardEpoch();
    /// Legacy reason: "Wrong signature".
    error WrongSignature();
    /// Legacy reason: "Wrong size for new sign policy".
    error WrongSizeForNewSignPolicy();
    /// Legacy reason: "Wrong verification data".
    error WrongVerificationData();
    /// Legacy reason: "zero merkle root".
    error ZeroMerkleRoot();
    /// Legacy reason: "Zero signer".
    error ZeroSigner();

    /**
     * Checks the relay message for sufficient weight of signatures for the _messageHash
     * signed for protocol message Merkle root of the form (1, 0, 0, _messageHash).
     * If the check is successful, reward epoch id of the signing policy is returned.
     * Otherwise the function reverts.
     * **SECURITY (L-3, updated by RLY-23):** This is a generic signature-quorum oracle — it only checks that
     *           enough current voters signed _messageHash. Since RLY-23 the verified digest is source-bound:
     *           voters sign keccak256(sourceChainId ‖ 38-byte message) over the protocol message
     *           (1, 0, 0, _messageHash), so cross-CHAIN replay of the same signatures is rejected.
     *           The digest still does NOT bind this contract's address or any nonce:
     *           callers MUST still domain-separate _messageHash themselves (e.g. include the consuming contract
     *           address and an application nonce); otherwise the same voter signatures can be replayed for the
     *           same _messageHash on another deployment on THIS chain with an overlapping signing policy.
     * @param _relayMessage The relay message.
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
     * The same L-3 domain-separation caveat as `verifyCustomSignature` applies.
     * NOTE: a threshold below the signing policy's only weakens THIS caller's acceptance
     * rule — the result then means "more than the requested fraction of the weight signed",
     * not that the protocol's quorum was reached.
     * @param _relayMessage The relay message.
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
     * Depending on the data provided, the contract operations in essentially two modes:
     * (1) Relaying signing policy. The structure of the calldata is:
     *        function signature (4 bytes) + active signing policy
     *             + 0 (1 byte) + new signing policy,
     *     total of exactly 4423 bytes.
     * (2) Relaying signed message. The structure of the calldata is:
     *        function signature (4 bytes) + signing policy
     *           + signed message (38 bytes) + ECDSA signatures with indices (67 bytes each)
     *     This case splits into two subcases:
     *     - protocolId = 1: Message id must be of the form (protocolId, 0, 0, merkleRoot).
     *       The validity of the signatures of sufficient weight is checked and if
     *       successful, the merkleRoot from the message is returned (32 bytes) and the
     *       reward epoch id of the signing policy as well (additional 3 bytes)
     *     - protocolId > 1: The validity of the signatures of sufficient weight is checked and if
     *       it is valid, the merkleRoot is published for protocolId and votingRoundId.
     * Reverts if relaying is not successful.
     */
    function relay() external returns (bytes memory);

    /**
     * Verifies the leaf (or intermediate node) with the Merkle proof against the Merkle root
     * for given protocol id and voting round id.
     * A fee may need to be paid. It is protocol specific.
     * **NOTE:** Overpayment above the protocol fee is refunded to the caller via a value-bearing call, so a
     *           contract caller MUST be able to receive ETH (or send exactly the fee);
     *           otherwise verify() reverts (L-2).
     * **NOTE (RLY-15):** A leaf equal to the (finalized, non-zero) root verifies with an empty proof —
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
     * otherwise the contract is deployed on mainnet.
     */
    function signingPolicySetter() external view returns (address);

    /**
     * Returns the signing policy hash for given reward epoch id.
     * The function is reverted if signingPolicySetter is NOT set, hence on all
     * deployments where the contract is used as a pure relay.
     * **RLY-23:** the returned hash is source-bound: keccak256(sourceChainId ‖ encoded policy bytes) —
     * one keccak over the 32-byte source chain id followed by the raw 43 + 22 * n byte encoding, no
     * padding. Off-chain code comparing against a locally computed policy hash must use the same scheme
     * (epochs served by an old-format `oldRelay` fallback still return that contract's retired
     * chained-fold content hash).
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
     * Returns fee in wei for one verification of a given protocol id.
     * @param _protocolId The protocol id.
     */
    function protocolFeeInWei(uint256 _protocolId) external view returns (uint256);

    /**
     * Returns whether `account` may call `verify()` without paying the protocol fee.
     */
    function feeExemptAddress(address account) external view returns (bool);

    /**
     * Returns the configured source-network id (RLY-23 origin binding): the network whose
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
