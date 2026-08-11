// SPDX-License-Identifier: MIT
// Exact-version pin: the FV manifest (test-forge/fv/verification-manifest.json) attests the
// deployment artifact against this exact compiler, and the forge deploy scripts must produce
// byte-identical code to the attested Hardhat artifact — do not widen the pragma.
pragma solidity =0.8.35;

import { IIRelay } from "../interface/IIRelay.sol";
import { IRelay } from "../../userInterfaces/IRelay.sol";
// solhint-disable-next-line no-unused-import
import { RandomNumberV2Interface } from "../../userInterfaces/LTS/RandomNumberV2Interface.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { OwnableWithTimelock } from "../../utils/implementation/OwnableWithTimelock.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

/**
 * Relay (finalization) contract.
 */
contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {
    using MerkleProof for bytes32[];
    /**
     * State variables for the relay contract.
     * IMPORTANT: if you change this, you have to adapt the assembly code interacting with
     * the struct with relay() function.
     */
    struct StateData {
        /// The protocol id of the random number protocol.
        uint8 randomNumberProtocolId;
        /// The timestamp of the first voting round start.
        uint32 firstVotingRoundStartTs;
        /// The duration of a voting epoch in seconds.
        uint8 votingEpochDurationSeconds;
        /// The start voting round id of the first reward epoch.
        uint32 firstRewardEpochStartVotingRoundId;
        /// The duration of a reward epoch in voting epochs.
        uint16 rewardEpochDurationInVotingEpochs;
        /// The threshold increase in BIPS for signing with old signing policy.
        uint16 thresholdIncreaseBIPS;

        // Publication of current random number
        /// The voting round id of the random number generation.
        uint32 randomVotingRoundId;
        /// If true, the random number is generated secure.
        bool isSecureRandom;

        /// The last reward epoch id for which the signing policy has been initialized.
        uint32 lastInitializedRewardEpoch;

        /// If true, signing policy relay is disabled.
        bool noSigningPolicyRelay;

        /// If reward epoch of a message is less then
        /// lastInitializedRewardEpoch - messageFinalizationWindowInRewardEpochs
        /// relaying the message is rejected.
        uint32 messageFinalizationWindowInRewardEpochs;
    }

    // Auxilary struct for memory variables
    struct Counters {
        uint256 weightIndex;
        uint256 weightPos;
        uint256 voterIndex;
        uint256 voterPos;
        uint256 count;
        uint256 bytesToTake;
        bytes32 nextSlot;
        uint256 pos;
        uint256 signingPolicyPos;
    }

    // 4-byte custom-error selectors for the hand-written relay() assembly (compile-time
    // folded; the matching error declarations live on IRelay). One selector per failure.
    /* solhint-disable const-name-snakecase */
    uint32 private constant ERR_ALREADY_RELAYED = 0xd0ebeb4b; // bytes4(keccak256("AlreadyRelayed()"))
    uint32 private constant ERR_BAD_S = 0xf54d11f5; // bytes4(keccak256("BadS()"))
    uint32 private constant ERR_BAD_V = 0x8320c358; // bytes4(keccak256("BadV()"))
    uint32 private constant ERR_DELAYED_SIGN_POLICY = 0x0c01bf37; // bytes4(keccak256("DelayedSignPolicy()"))
    uint32 private constant ERR_ECRECOVER_ERROR = 0xc859b3f5; // bytes4(keccak256("EcrecoverError()"))
    // bytes4(keccak256("EcrecoverReturnedBadData()"))
    uint32 private constant ERR_ECRECOVER_RETURNED_BAD_DATA = 0x62bd175a;
    uint32 private constant ERR_INCORRECT_MERKLE_PROOF = 0x5d2f8a05; // bytes4(keccak256("IncorrectMerkleProof()"))
    uint32 private constant ERR_INDEX_OUT_OF_ORDER = 0x297f31e1; // bytes4(keccak256("IndexOutOfOrder()"))
    uint32 private constant ERR_INDEX_OUT_OF_RANGE = 0x1390f2a1; // bytes4(keccak256("IndexOutOfRange()"))
    // bytes4(keccak256("InvalidRandomNumberProof()"))
    uint32 private constant ERR_INVALID_RANDOM_NUMBER_PROOF = 0x987d1299;
    // bytes4(keccak256("InvalidSignPolicyLength()"))
    uint32 private constant ERR_INVALID_SIGN_POLICY_LENGTH = 0x5509ecdf;
    // bytes4(keccak256("InvalidSignPolicyMetadata()"))
    uint32 private constant ERR_INVALID_SIGN_POLICY_METADATA = 0x3fcc839e;
    uint32 private constant ERR_INVALID_VOTING_ROUND_ID = 0x01ed5f84; // bytes4(keccak256("InvalidVotingRoundId()"))
    uint32 private constant ERR_MESSAGE_TOO_OLD = 0x4ed02d0d; // bytes4(keccak256("MessageTooOld()"))
    uint32 private constant ERR_MUST_USE_NEW_SIGN_POLICY = 0xf64fd99c; // bytes4(keccak256("MustUseNewSignPolicy()"))
    uint32 private constant ERR_NO_NEW_SIGN_POLICY_SIZE = 0xf63c072c; // bytes4(keccak256("NoNewSignPolicySize()"))
    uint32 private constant ERR_NO_RANDOM_NUMBER = 0xd76adcd1; // bytes4(keccak256("NoRandomNumber()"))
    uint32 private constant ERR_NO_SIGNATURE_COUNT = 0xf8139caf; // bytes4(keccak256("NoSignatureCount()"))
    uint32 private constant ERR_NOT_ENOUGH_SIGNATURES = 0xe246dc63; // bytes4(keccak256("NotEnoughSignatures()"))
    uint32 private constant ERR_NOT_NEXT_REWARD_EPOCH = 0x124f824d; // bytes4(keccak256("NotNextRewardEpoch()"))
    // bytes4(keccak256("NotWithLastInitialized()"))
    uint32 private constant ERR_NOT_WITH_LAST_INITIALIZED = 0xbe8b3520;
    // bytes4(keccak256("SignPolicyRelayDisabled()"))
    uint32 private constant ERR_SIGN_POLICY_RELAY_DISABLED = 0xf0059553;
    uint32 private constant ERR_SIGNING_POLICY_EMPTY = 0x53c236da; // bytes4(keccak256("SigningPolicyEmpty()"))
    // bytes4(keccak256("SigningPolicyHashMismatch()"))
    uint32 private constant ERR_SIGNING_POLICY_HASH_MISMATCH = 0x143fc35c;
    uint32 private constant ERR_THRESHOLD_TOO_HIGH = 0xe56d58cf; // bytes4(keccak256("ThresholdTooHigh()"))
    uint32 private constant ERR_THRESHOLD_TOO_LOW = 0x398ecf8a; // bytes4(keccak256("ThresholdTooLow()"))
    uint32 private constant ERR_TOO_MANY_VOTERS = 0x4647aac9; // bytes4(keccak256("TooManyVoters()"))
    uint32 private constant ERR_TOO_SHORT_MESSAGE = 0x43a69646; // bytes4(keccak256("TooShortMessage()"))
    uint32 private constant ERR_TOTAL_WEIGHT_TOO_BIG = 0x8dd23571; // bytes4(keccak256("TotalWeightTooBig()"))
    uint32 private constant ERR_UNREACHABLE_CODE = 0xe0c9078c; // bytes4(keccak256("UnreachableCode()"))
    uint32 private constant ERR_WRONG_MESSAGE_FORMAT = 0xe3427225; // bytes4(keccak256("WrongMessageFormat()"))
    uint32 private constant ERR_WRONG_MESSAGE_FORMAT2 = 0x4913ec0d; // bytes4(keccak256("WrongMessageFormat2()"))
    // bytes4(keccak256("WrongSignPolicyRewardEpoch()"))
    uint32 private constant ERR_WRONG_SIGN_POLICY_REWARD_EPOCH = 0x8134d963;
    uint32 private constant ERR_WRONG_SIGNATURE = 0x356a4418; // bytes4(keccak256("WrongSignature()"))
    // bytes4(keccak256("WrongSizeForNewSignPolicy()"))
    uint32 private constant ERR_WRONG_SIZE_FOR_NEW_SIGN_POLICY = 0x60c18b0d;
    uint32 private constant ERR_ZERO_MERKLE_ROOT = 0x9266ee62; // bytes4(keccak256("ZeroMerkleRoot()"))
    uint32 private constant ERR_ZERO_SIGNER = 0xe5c48ac5; // bytes4(keccak256("ZeroSigner()"))
    /* solhint-enable const-name-snakecase */

    uint256 private constant THRESHOLD_BIPS = 10000;
    uint256 private constant SELECTOR_BYTES = 4;
    uint256 private constant MAX_VOTERS = 300;
    uint256 private constant MIN_THRESHOLD_BIPS = 5000;
    uint256 private constant MAX_THRESHOLD_BIPS = 6600;

    /// Transient (EIP-1153) slot holding verifyCustomSignatureWithThreshold's threshold override
    /// for the duration of its relay() self-call; 0 = no override, so a top-level relay() call
    /// always reads 0. uint256(keccak256("flare.relay.thresholdOverride")).
    uint256 private constant TSLOT_THRESHOLD_OVERRIDE =
        0x6cea5c73f8043432390b6161c6418f07a6dc8cc07557416a3f28d2fd6007a2c3;

    // Signing policy byte encoding structure
    // 2 bytes - numberOfVoters
    // 3 bytes - rewardEpochId
    // 4 bytes - startingVotingRoundId
    // 2 bytes - threshold
    // 32 bytes - randomSeed
    // array of 'size':
    // - 20 bytes address
    // - 2 bytes weight
    // Total 43 + size * (20 + 2) bytes
    // metadataLength = 11 bytes (size, rewardEpochId, startingVotingRoundId, threshold)

    /* solhint-disable const-name-snakecase */
    uint256 private constant METADATA_BYTES = 11;
    uint256 private constant REWARD_EPOCH_ID_BYTES = 3;
    uint256 private constant MD_MASK_threshold = 0xffff;
    uint256 private constant MD_BOFF_threshold = 0;
    uint256 private constant MD_MASK_startingVotingRoundId = 0xffffffff;
    uint256 private constant MD_BOFF_startingVotingRoundId = 16;
    uint256 private constant MD_MASK_rewardEpochId = 0xffffff;
    uint256 private constant MD_BOFF_rewardEpochId = 48;
    uint256 private constant MD_MASK_numberOfVoters = 0xffff;
    uint256 private constant MD_BOFF_numberOfVoters = 72;
    /* solhint-enable const-name-snakecase */

    uint256 private constant RANDOM_SEED_BYTES = 32;
    uint256 private constant ADDRESS_BYTES = 20;
    uint256 private constant WEIGHT_BYTES = 2;
    uint256 private constant WEIGHT_MASK = 0xffff;
    uint256 private constant ADDRESS_AND_WEIGHT_BYTES = 22; // ADDRESS_BYTES + WEIGHT_BYTES;
    //METADATA_BYTES + RANDOM_SEED_BYTES;
    uint256 private constant SIGNING_POLICY_PREFIX_BYTES = 43;

    // Protocol message merkle root structure
    // 1 byte - protocolId
    // 4 bytes - votingRoundId
    // 1 byte - isSecureRandom
    // 32 bytes - merkleRoot
    // Total 38 bytes
    // if loaded into a memory slot, these are right shifts and masks
    /* solhint-disable const-name-snakecase */
    uint256 private constant MESSAGE_BYTES = 38;
    uint256 private constant PROTOCOL_ID_BYTES = 1;
    uint256 private constant MESSAGE_NO_MR_BYTES = 6;
    uint256 private constant MSG_NMR_MASK_isSecureRandom = 0xff;
    uint256 private constant MSG_NMR_BOFF_isSecureRandom = 0;
    uint256 private constant MSG_NMR_MASK_votingRoundId = 0xffffffff;
    uint256 private constant MSG_NMR_BOFF_votingRoundId = 8;
    uint256 private constant MSG_NMR_MASK_protocolId = 0xff;
    uint256 private constant MSG_NMR_BOFF_protocolId = 40;
    /* solhint-enable const-name-snakecase */

    /* solhint-disable const-name-snakecase */
    uint256 private constant SD_MASK_randomNumberProtocolId = 0xff;
    uint256 private constant SD_BOFF_randomNumberProtocolId = 0;
    uint256 private constant SD_MASK_firstVotingRoundStartTs = 0xffffffff;
    uint256 private constant SD_BOFF_firstVotingRoundStartTs = 8;
    uint256 private constant SD_MASK_votingEpochDurationSeconds = 0xff;
    uint256 private constant SD_BOFF_votingEpochDurationSeconds = 40;
    uint256 private constant SD_MASK_firstRewardEpochStartVotingRoundId = 0xffffffff;
    uint256 private constant SD_BOFF_firstRewardEpochStartVotingRoundId = 48;
    uint256 private constant SD_MASK_rewardEpochDurationInVotingEpochs = 0xffff;
    uint256 private constant SD_BOFF_rewardEpochDurationInVotingEpochs = 80;
    uint256 private constant SD_MASK_thresholdIncreaseBIPS = 0xffff;
    uint256 private constant SD_BOFF_thresholdIncreaseBIPS = 96;
    uint256 private constant SD_MASK_randomVotingRoundId = 0xffffffff;
    uint256 private constant SD_BOFF_randomVotingRoundId = 112;
    uint256 private constant SD_MASK_isSecureRandom = 0xff;
    uint256 private constant SD_BOFF_isSecureRandom = 144;
    uint256 private constant SD_MASK_lastInitializedRewardEpoch = 0xffffffff;
    uint256 private constant SD_BOFF_lastInitializedRewardEpoch = 152;
    uint256 private constant SD_MASK_noSigningPolicyRelay = 0xff;
    uint256 private constant SD_BOFF_noSigningPolicyRelay = 184;
    uint256 private constant SD_MASK_messageFinalizationWindowInRewardEpochs = 0xffffffff;
    uint256 private constant SD_BOFF_messageFinalizationWindowInRewardEpochs = 192;

    /* solhint-enable const-name-snakecase */

    // Signature with index structure
    // 1 byte - v
    // 32 bytes - r
    // 32 bytes - s
    // 2 byte - index in signing policy
    // Total 67 bytes

    uint256 private constant NUMBER_OF_SIGNATURES_BYTES = 2;
    uint256 private constant NUMBER_OF_SIGNATURES_RIGHT_SHIFT_BITS = 240; // 8 * (32 - NUMBER_OF_SIGNATURES_BYTES)
    uint256 private constant NUMBER_OF_SIGNATURES_MASK = 0xffff;
    uint256 private constant SIGNATURE_WITH_INDEX_BYTES = 67; // 1 v + 32 r + 32 s + 2 index
    uint256 private constant SIGNATURE_V_BYTES = 1;
    uint256 private constant SIGNATURE_INDEX_RIGHT_SHIFT_BITS = 240; // 256 - 2*8 = 240

    // Memory slots
    /* solhint-disable const-name-snakecase */
    uint256 private constant M_0 = 0;
    uint256 private constant M_1 = 32;
    uint256 private constant M_2 = 64;
    uint256 private constant M_2_signingPolicyHashTmp = 64;
    uint256 private constant M_3 = 96;
    uint256 private constant M_3_existingSigningPolicyHashTmp = 96;
    uint256 private constant M_4 = 128;
    uint256 private constant M_5_stateData = 160;
    uint256 private constant M_5_isSecureRandom = 160;
    uint256 private constant M_6_merkleRoot = 192;
    uint256 private constant M_7_randomNumber = 224;
    uint256 private constant M_8_signatureStart = 256;

    uint256 private constant ADDRESS_OFFSET = 12;
    /* solhint-enable const-name-snakecase */

    /// The signing policy hash for given reward epoch id.
    mapping(uint256 rewardEpochId => bytes32) private toSigningPolicyHashPrivate;
    /// The merkle root for given protocol id and voting round id.
    //slither-disable-next-line uninitialized-state
    mapping(uint256 protocolId => mapping(uint256 votingRoundId => bytes32)) private merkleRootsPrivate;
    /// The start voting round id for given reward epoch id.
    mapping(uint256 rewardEpochId => uint256) public startingVotingRoundIds;
    /// The address of the signing policy setter (zero if disabled).
    address public signingPolicySetter;

    /// Fees in wei per protocol.
    mapping(uint256 => uint256) public protocolFeeInWei;
    /// fee collection address.
    address payable public feeCollectionAddress;

    /// A map with bits indicating whether a random number is secure for
    /// historical purposes. For given votingRoundId, the bit vector is obtained
    /// in index  votingRoundId / 256 and the bit is at position votingRoundId % 256.
    //slither-disable-next-line uninitialized-state
    mapping(uint256 => bytes32) internal isSecureRandomMap;

    /// The state of the relay contract.
    StateData public stateData;

    /// The relayed (Merkle-proven) random number for a given voting round id (RLY-03).
    //slither-disable-next-line uninitialized-state
    mapping(uint256 votingRoundId => uint256) private toRandomNumberPrivate;

    /// Old relay contract
    IRelay public oldRelay;
    /// The initial reward epoch id.
    uint32 public initialRewardEpochId;
    /// The starting voting round id for the initial
    uint32 public startingVotingRoundIdForInitialRewardEpochId;
    /// Addresses allowed to call verify() without paying the protocol fee (e.g. DVN
    /// adapters). Owner-set via setFeeExemptions.
    mapping(address account => bool) public override feeExemptAddress;
    /// RLY-23: the source network id bound into every stored signing-policy hash and, via the
    /// analogous wrap in relay(), every signed protocol-message digest —
    /// keccak256(sourceChainId ‖ contentHash) — so policies and messages minted for another
    /// network are rejected even under a fully overlapping voter set. Explicit and nonzero on
    /// every deployment, set once in initialize; home deploys force it to block.chainid.
    uint256 public override sourceChainId;

    /// Only signingPolicySetter address/contract can call this method.
    modifier onlySigningPolicySetter() {
        require(msg.sender == signingPolicySetter, OnlySigningPolicySetterRole());
        _;
    }

    /// Locks the implementation contract; state lives behind the proxy only.
    constructor() {
        _disableInitializers();
    }

    /**
     * Initializes the Relay behind its proxy. One atomic call configures EVERYTHING —
     * protocol config, the RLY-23 source binding, the owner-timelock duration and the
     * per-chain owner — and it runs inside the proxy constructor (see RelayProxy), so the
     * deterministic proxy address never exists uninitialized.
     * @param _initialConfig The initial configuration of the relay.
     * @param _signingPolicySetter The address of the signing policy setter.
     * @param _oldRelay The old relay contract (can be address(0)).
     * @param _initialOwner The per-chain owner (multisig): authorizes the fee setters and
     * upgrades through the OwnableWithTimelock queue (see IOwnableWithTimelock).
     */
    function initialize(
        RelayInitialConfig memory _initialConfig,
        address _signingPolicySetter,
        IRelay _oldRelay,
        address _initialOwner
    )
        external initializer
    {
        __Ownable_init(_initialOwner);
        require(_initialConfig.thresholdIncreaseBIPS >= THRESHOLD_BIPS, ThresholdIncreaseTooSmall());
        // RLY-11: reject zero epoch durations (would cause div-by-zero / silent-zero in epoch math).
        require(_initialConfig.rewardEpochDurationInVotingEpochs > 0, RewardEpochDurationZero());
        require(_initialConfig.votingEpochDurationSeconds > 0, VotingEpochDurationZero());
        // L-4: a zero initial signing-policy hash would brick the initial epoch (no relay message could match).
        // RLY-23: the supplied hash must already be source-bound — keccak256(sourceChainId ‖ contentHash) —
        // matching what relay()/setSigningPolicy store and verify. A content hash (or a hash bound to another
        // source) fails closed: no relay message can ever match it. Deploy scripts wrap on migration.
        require(_initialConfig.initialSigningPolicyHash != bytes32(0), InitialSigningPolicyHashZero());
        require(_initialConfig.firstRewardEpochStartVotingRoundId +
            _initialConfig.initialRewardEpochId * _initialConfig.rewardEpochDurationInVotingEpochs <=
            _initialConfig.startingVotingRoundIdForInitialRewardEpochId, InvalidInitialStartingVotingRoundId());
        initialRewardEpochId = _initialConfig.initialRewardEpochId;
        startingVotingRoundIdForInitialRewardEpochId =
            _initialConfig.startingVotingRoundIdForInitialRewardEpochId;
        // Migration handshake: lastInitializedRewardEpoch is seeded to initialRewardEpochId, and setSigningPolicy
        // strictly requires the next call to be exactly initialRewardEpochId + 1 ("not next reward epoch"). The
        // deployer (redeploy-relay.ts) must therefore cut over so the trusted setter's next policy is that epoch;
        // a zero next-epoch policy hash on the old relay is fail-closed by the L-4 require above.
        stateData.lastInitializedRewardEpoch = _initialConfig.initialRewardEpochId;
        startingVotingRoundIds[_initialConfig.initialRewardEpochId] =
            _initialConfig.startingVotingRoundIdForInitialRewardEpochId;
        toSigningPolicyHashPrivate[_initialConfig.initialRewardEpochId] = _initialConfig.initialSigningPolicyHash;
        require(_initialConfig.randomNumberProtocolId > 1, InvalidRandomNumberProtocolId());
        stateData.randomNumberProtocolId = _initialConfig.randomNumberProtocolId;
        stateData.firstVotingRoundStartTs = _initialConfig.firstVotingRoundStartTs;
        stateData.votingEpochDurationSeconds = _initialConfig.votingEpochDurationSeconds;
        stateData.firstRewardEpochStartVotingRoundId = _initialConfig.firstRewardEpochStartVotingRoundId;
        stateData.rewardEpochDurationInVotingEpochs = _initialConfig.rewardEpochDurationInVotingEpochs;
        stateData.thresholdIncreaseBIPS = _initialConfig.thresholdIncreaseBIPS;
        stateData.messageFinalizationWindowInRewardEpochs = _initialConfig.messageFinalizationWindowInRewardEpochs;
        if (_signingPolicySetter != address(0)) {
            // Setter-mode (home) deployments never charge a verify() fee, so seeded fees, fee
            // exemptions and a fee-collection address are all meaningless here; reject them to
            // catch a misconfigured home config.
            require(_initialConfig.feeConfigs.length == 0, FeeConfigNotAllowed());
            require(_initialConfig.feeExemptAddresses.length == 0, FeeExemptionsNotAllowed());
            require(_initialConfig.feeCollectionAddress == address(0), FeeConfigNotAllowed());
            // RLY-23 home-force: a live signing-policy setter (home deploy) must bind this chain.
            require(
                _initialConfig.sourceChainId == block.chainid,
                SourceChainIdMismatchOnHomeDeploy()
            );
            signingPolicySetter = _signingPolicySetter;
            stateData.noSigningPolicyRelay = true;
            emit SigningPolicySetterSet(_signingPolicySetter);
        } else {
            // In relay mode a zero fee-collection address would burn collected fees, so reject it.
            require(_initialConfig.feeCollectionAddress != address(0), FeeCollectionAddressZero());
            feeCollectionAddress = _initialConfig.feeCollectionAddress;
            emit FeeCollectionAddressSet(_initialConfig.feeCollectionAddress);
        }
        for (uint256 i = 0; i < _initialConfig.feeConfigs.length; i++) {
            uint8 protocolId = _initialConfig.feeConfigs[i].protocolId;
            require(protocolId > 1, InvalidProtocolId());
            protocolFeeInWei[protocolId] = _initialConfig.feeConfigs[i].feeInWei;
            emit ProtocolFeeSet(protocolId, _initialConfig.feeConfigs[i].feeInWei);
        }
        // Seed initial verify() fee exemptions (e.g. DVN adapters) so they are exempt from block
        // one, with no post-deploy governance round-trip. Relay mode only — the setter-mode branch
        // above requires this list empty. The owner can grant/revoke later via setFeeExemptions.
        for (uint256 i = 0; i < _initialConfig.feeExemptAddresses.length; i++) {
            address exemptAccount = _initialConfig.feeExemptAddresses[i];
            require(exemptAccount != address(0), FeeExemptAddressZero());
            feeExemptAddress[exemptAccount] = true;
            emit FeeExemptionSet(exemptAccount, true);
        }
        // RLY-23: the source-network id is mandatory on every deployment — home, mirror and
        // old-relay migration alike (the same artifact ships to every chain). A live
        // signing-policy setter (home deploy) additionally forces it to this chain (checked above).
        require(_initialConfig.sourceChainId != 0, SourceChainIdZero());
        sourceChainId = _initialConfig.sourceChainId;
        // The owner-timelock duration is deploy-configured so the owner (a multisig) needs no
        // post-deploy ceremony call. Writing the ERC-7201 namespaced state via the base's
        // internal getState() keeps the inherited OwnableWithTimelock file byte-identical to
        // its origin; the guard mirrors setTimelockDuration.
        require(
            _initialConfig.timelockDurationSeconds <= MAX_TIMELOCK_DURATION_SECONDS,
            TimelockDurationTooLong()
        );
        getState().timelockDurationSeconds = _initialConfig.timelockDurationSeconds;
        emit TimelockDurationSet(_initialConfig.timelockDurationSeconds);
        // new relay must be deployed in a compatible way (policy setter or not)
        if (address(_oldRelay) != address(0)) {
            require((_signingPolicySetter != address(0) && _oldRelay.signingPolicySetter() != address(0)) ||
                (_signingPolicySetter == address(0) && _oldRelay.signingPolicySetter() == address(0)),
                OldRelayIncompatible()
            );
            (
                ,
                uint32 firstVotingRoundStartTs,
                uint8 votingEpochDurationSeconds,
                uint32 firstRewardEpochStartVotingRoundId,
                uint16 rewardEpochDurationInVotingEpochs,
                ,,,,,
            ) = _oldRelay.stateData();
            require(_initialConfig.firstVotingRoundStartTs == firstVotingRoundStartTs, OldRelayWrongStartTs());
            require(
                _initialConfig.rewardEpochDurationInVotingEpochs == rewardEpochDurationInVotingEpochs,
                OldRelayWrongRewardEpochDuration()
            );
            require(
                _initialConfig.firstRewardEpochStartVotingRoundId == firstRewardEpochStartVotingRoundId,
                OldRelayWrongFirstRewardEpochStart()
            );
            require(
                _initialConfig.votingEpochDurationSeconds == votingEpochDurationSeconds,
                OldRelayWrongVotingEpochDuration()
            );
            oldRelay = _oldRelay;
        }
    }

    /**
     * @inheritdoc IIRelay
     */
    function setSigningPolicy(
        // using memory instead of calldata as called from another contract where signing policy is already in memory
        SigningPolicy memory _signingPolicy
    )
        external onlySigningPolicySetter
        returns (bytes32)
    {
        // RLY-06: the signing policy setter (trusted; FlareSystemsManager on Flare) is responsible for
        // ensuring the policy is well-formed — no zero-address voters, no duplicate voters, canonical
        // voter order, normalised weights. These are intentionally NOT re-validated here.
        require(stateData.lastInitializedRewardEpoch + 1 == _signingPolicy.rewardEpochId, NotNextRewardEpoch());
        // L-6 (documented, not enforced): the reward-epoch decision matrix (see the relay() gate that reads
        // startingVotingRoundIds[rewardEpochId + 1]) assumes a non-decreasing startVotingRoundId across epochs.
        // Like RLY-06, this canonical-ordering invariant is the trusted signing-policy setter's
        // (FlareSystemsManager) responsibility and is intentionally NOT re-checked here — an on-chain require
        // conflicts with legitimate setter-driven configurations. On pure-relay deployments (this setter is
        // unused) startingVotingRoundIds is instead written by the Mode-1 relay() path from the relayed policy
        // metadata; there the invariant is carried transitively by the voter quorum's signature over the
        // signing-policy hash (a faithfully-relayed canonical policy preserves it).
        require(_signingPolicy.voters.length > 0, SigningPolicyEmpty());
        require(_signingPolicy.voters.length <= MAX_VOTERS, TooManyVoters());
        require(_signingPolicy.voters.length == _signingPolicy.weights.length, VotersWeightsSizeMismatch());
        uint256 totalWeight = 0;
        for (uint256 i = 0; i < _signingPolicy.weights.length; i++) {
            totalWeight += _signingPolicy.weights[i];
        }
        require(totalWeight < 2**16, TotalWeightTooBig());
        require(
            uint256(_signingPolicy.threshold) * uint256(THRESHOLD_BIPS) >= totalWeight * MIN_THRESHOLD_BIPS,
            ThresholdTooLow()
        );
        require(
            uint256(_signingPolicy.threshold) * uint256(THRESHOLD_BIPS) <= totalWeight * MAX_THRESHOLD_BIPS,
            ThresholdTooHigh()
        );

        bytes memory signingPolicyBytes = new bytes(
            SIGNING_POLICY_PREFIX_BYTES +
                _signingPolicy.voters.length *
                ADDRESS_AND_WEIGHT_BYTES
        );

        Counters memory m;

        // bytes32 currentHash;
        // RLY-19: _signingPolicy.rewardEpochId is uint24 (see IIRelay.SigningPolicy), so the bytes3(...)
        // narrowing below is lossless and matches the mapping key — no >2**24 truncation is possible.
        bytes memory toHash = bytes.concat(
            bytes2(uint16(_signingPolicy.voters.length)),
            bytes3(_signingPolicy.rewardEpochId),
            bytes4(_signingPolicy.startVotingRoundId),
            bytes2(_signingPolicy.threshold),
            bytes32(uint256(_signingPolicy.seed)),
            bytes20(_signingPolicy.voters[0]),
            bytes1(uint8(_signingPolicy.weights[0] >> 8))
        );

        for (; m.signingPolicyPos < 64; m.signingPolicyPos++) {
            signingPolicyBytes[m.signingPolicyPos] = toHash[m.signingPolicyPos];
        }

        bytes32 currentHash = keccak256(toHash);

        m.weightIndex = 0;
        m.weightPos = 1;
        m.voterIndex = 1;
        m.voterPos = 0;

        while (m.weightIndex < _signingPolicy.voters.length) {
            m.count = 0;
            m.nextSlot = bytes32(uint256(0));
            m.bytesToTake = 0;
            while (
                m.count < 32 && m.weightIndex < _signingPolicy.voters.length
            ) {
                if (m.weightIndex < m.voterIndex) {
                    m.bytesToTake = 2 - m.weightPos;
                    m.pos = m.weightPos;
                    bytes32 weightData = bytes32(
                        uint256(
                            uint16(_signingPolicy.weights[m.weightIndex])
                        ) << (30 * 8)
                    );
                    if (m.count + m.bytesToTake > 32) {
                        m.bytesToTake = 32 - m.count;
                        m.weightPos += m.bytesToTake;
                    } else {
                        m.weightPos = 0;
                        m.weightIndex++;
                    }
                    m.nextSlot |= bytes32(
                        ((weightData << (8 * m.pos)) >> (8 * m.count))
                    );
                } else {
                    m.bytesToTake = 20 - m.voterPos;
                    m.pos = m.voterPos;
                    bytes32 voterData = bytes32(
                        uint256(uint160(_signingPolicy.voters[m.voterIndex])) <<
                            (12 * 8)
                    );
                    if (m.count + m.bytesToTake > 32) {
                        m.bytesToTake = 32 - m.count;
                        m.voterPos += m.bytesToTake;
                    } else {
                        m.voterPos = 0;
                        m.voterIndex++;
                    }
                    m.nextSlot |= bytes32(
                        ((voterData << (8 * m.pos)) >> (8 * m.count))
                    );
                }
                m.count += m.bytesToTake;
            }
            if (m.count > 0) {
                currentHash = keccak256(bytes.concat(currentHash, m.nextSlot));
                for (uint256 i = 0; i < m.count; i++) {
                    signingPolicyBytes[m.signingPolicyPos] = m.nextSlot[i];
                    m.signingPolicyPos++;
                }
            }
        }
        // RLY-23: chain-domain binding — the stored signing-policy hash commits to the configured
        // source network: keccak256(sourceChainId ‖ contentHash). Signatures over policies (and, via
        // the analogous wrap in relay(), over protocol messages) minted for another network are thereby
        // rejected even under a fully overlapping voter set. On a home deploy sourceChainId == block.chainid.
        currentHash = keccak256(abi.encodePacked(sourceChainId, currentHash));
        toSigningPolicyHashPrivate[_signingPolicy.rewardEpochId] = currentHash;
        stateData.lastInitializedRewardEpoch = _signingPolicy.rewardEpochId;
        startingVotingRoundIds[_signingPolicy.rewardEpochId] = _signingPolicy.startVotingRoundId;
        emit SigningPolicyInitialized(
            _signingPolicy.rewardEpochId,
            _signingPolicy.startVotingRoundId,
            _signingPolicy.threshold,
            _signingPolicy.seed,
            _signingPolicy.voters,
            _signingPolicy.weights,
            signingPolicyBytes,
            uint64(block.timestamp)
        );

        return currentHash;
    }

    /**
     * @inheritdoc IRelay
     */
    function verifyCustomSignature(
        bytes calldata _relayMessage,
        bytes32 _messageHash
    ) external returns (uint256 _rewardEpochId) {
        return _verifyCustomSignature(_relayMessage, _messageHash);
    }

    /**
     * @inheritdoc IRelay
     * @dev The override travels to the relay() self-call through a transient (EIP-1153) slot,
     * so relay()'s calldata layout and 35-byte return discriminator (RLY-07) stay untouched.
     * The slot is cleared before returning; on revert the tstore is rolled back with the frame,
     * so no override can ever leak into a later call of the same transaction.
     */
    function verifyCustomSignatureWithThreshold(
        bytes calldata _relayMessage,
        bytes32 _messageHash,
        uint16 _thresholdBIPS
    )
        external
        returns (uint256 _rewardEpochId)
    {
        // Values of 100% and above can never be satisfied under the strict weight > threshold
        // comparison — fail fast instead of burning the signature loop on them.
        require(_thresholdBIPS < THRESHOLD_BIPS, ThresholdTooHigh());
        // Zero is the no-override sentinel in the transient slot, so 0 falls back to the signing
        // policy's own threshold — the Fdc2RequestHeader.thresholdBIPS convention.
        uint256 tslot = TSLOT_THRESHOLD_OVERRIDE;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            tstore(tslot, _thresholdBIPS)
        }
        _rewardEpochId = _verifyCustomSignature(_relayMessage, _messageHash);
        // solhint-disable-next-line no-inline-assembly
        assembly {
            tstore(tslot, 0)
        }
    }

    /**
     * @inheritdoc IIRelay
     * @dev Relay-mode only: setter-mode (home) deployments never charge verify() fees, so
     * the setter fail-closes there (mirrors the initialize() seeding rule). With a nonzero
     * timelock duration the call is queued for permissionless execution after its ETA;
     * with zero it applies immediately (see IOwnableWithTimelock).
     */
    function setProtocolFees(
        FeeConfig[] calldata _feeConfigs
    )
        external
        onlyOwnerWithTimelock
    {
        require(signingPolicySetter == address(0), FeeConfigNotAllowed());
        for (uint256 i = 0; i < _feeConfigs.length; i++) {
            uint8 protocolId = _feeConfigs[i].protocolId;
            require(protocolId > 1, InvalidProtocolId());
            protocolFeeInWei[protocolId] = _feeConfigs[i].feeInWei;
            emit ProtocolFeeSet(protocolId, _feeConfigs[i].feeInWei);
        }
    }

    /**
     * @inheritdoc IIRelay
     * @dev Relay-mode only — setter-mode deployments charge no fee, so exemptions are
     * meaningless there (mirrors the initialize() seeding rule); same timelock semantics
     * as setProtocolFees.
     */
    function setFeeExemptions(
        FeeExemption[] calldata _exemptions
    )
        external
        onlyOwnerWithTimelock
    {
        require(signingPolicySetter == address(0), FeeExemptionsNotAllowed());
        for (uint256 i = 0; i < _exemptions.length; i++) {
            address account = _exemptions[i].account;
            require(account != address(0), FeeExemptAddressZero());
            feeExemptAddress[account] = _exemptions[i].exempt;
            emit FeeExemptionSet(account, _exemptions[i].exempt);
        }
    }

    /**
     * @inheritdoc IIRelay
     * @dev Relay-mode only (setter-mode deployments never collect fees); same timelock
     * semantics as setProtocolFees. The nonzero guard is load-bearing: a zero recipient
     * would burn every collected fee.
     */
    function setFeeCollectionAddress(
        address _feeCollectionAddress
    )
        external
        onlyOwnerWithTimelock
    {
        require(signingPolicySetter == address(0), FeeConfigNotAllowed());
        require(_feeCollectionAddress != address(0), FeeCollectionAddressZero());
        feeCollectionAddress = payable(_feeCollectionAddress);
        emit FeeCollectionAddressSet(_feeCollectionAddress);
    }

    /**
     * @inheritdoc IIRelay
     * @dev Setter-mode only — the deployment mode is fixed at initialize, so a relay-mode
     * deployment can never gain a setter and a setter-mode one can never clear it; same
     * timelock semantics as setProtocolFees.
     */
    function setSigningPolicySetter(
        address _signingPolicySetter
    )
        external
        onlyOwnerWithTimelock
    {
        require(signingPolicySetter != address(0), SigningPolicySetterNotAllowed());
        require(_signingPolicySetter != address(0), SigningPolicySetterZero());
        signingPolicySetter = _signingPolicySetter;
        emit SigningPolicySetterSet(_signingPolicySetter);
    }

    /////////////////////////////// UUPS UPGRADABLE ///////////////////////////////

    /// Returns the current implementation address behind the proxy.
    function implementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    /**
     * Upgrades the UUPS implementation through the owner-timelock path: with a nonzero
     * duration the exact call is queued for permissionless execution after its ETA; with
     * zero it executes immediately. Only the per-chain owner can queue; on Flare this is
     * Flare governance, on other chains the designated multisig.
     * @param _newImplementation The new implementation address.
     * @param _data Optional post-upgrade initialization calldata.
     */
    function upgradeToAndCall(
        address _newImplementation,
        bytes memory _data
    )
        public payable override
        onlyOwnerWithTimelock
    {
        super.upgradeToAndCall(_newImplementation, _data);
    }

    /// @dev Empty: authorization is `onlyOwnerWithTimelock` on the `upgradeToAndCall`
    ///      wrapper above.
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(
        address _newImplementation
    )
        internal override
    {}

    /**
     * @inheritdoc IRelay
     */
    function relay() external returns (bytes memory){
        // RLY-23: read once here; bound below into the signing-policy hash (threaded into
        // the calculateSigningPolicyHash helper as _sourceChainId) and, directly in the
        // main assembly body, into the protocol-message digest.
        uint256 srcChainId = sourceChainId;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // Helper function to revert with a 4-byte custom-error selector (declared on
            // IRelay; the ERR_* constants are compile-time keccak folds of the signatures).
            function revertWithError(_memPtr, _selector) {
                mstore(_memPtr, shl(224, _selector))
                revert(_memPtr, 4)
            }

            function assignStruct(_structObj, _valOffset, _valMask, newVal)
                -> _newStructObj
            {
                _newStructObj := or(
                    and(
                        // zeroing the field
                        _structObj,
                        not(
                            // zeroing mask
                            shl(_valOffset, _valMask)
                        )
                    ),
                    shl(_valOffset, newVal)
                )
            }

            // Helper function to assign value to right aligned byte encoded struct like object
            function structValue(_structObj, _valOffset, _valMask) -> _val {
                _val := and(shr(_valOffset, _structObj), _valMask)
            }

            // Helper function to calculate the expected reward epoch id from voting round id
            // Here the constants should be set properly
            function rewardEpochIdFromVotingRoundId(
                _stateDataObj,
                _votingRoundId
            ) -> _rewardEpochId {
                let firstRewardEpochStartVotingRoundId := structValue(
                    _stateDataObj,
                    SD_BOFF_firstRewardEpochStartVotingRoundId,
                    SD_MASK_firstRewardEpochStartVotingRoundId
                )
                if lt(_votingRoundId, firstRewardEpochStartVotingRoundId) {
                    revertWithError(mload(0x40), ERR_INVALID_VOTING_ROUND_ID)
                }
                _rewardEpochId := div(
                    sub(
                        _votingRoundId,
                        firstRewardEpochStartVotingRoundId
                    ),
                    structValue(
                        _stateDataObj,
                        SD_BOFF_rewardEpochDurationInVotingEpochs,
                        SD_MASK_rewardEpochDurationInVotingEpochs
                    )
                )
            }

            // Helper function to calculate the signing policy hash while trying to minimize the usage of memory
            // Uses slots 0 and 32
            function calculateSigningPolicyHash(
                _memPos,
                _calldataPos,
                _policyLength,
                _sourceChainId
            ) -> _policyHash {
                // first byte
                calldatacopy(_memPos, _calldataPos, 32)
                // all but last 32-byte word
                let endPos := add(_calldataPos, mul(div(_policyLength, 32), 32))
                for {
                    let pos := add(_calldataPos, 32)
                } lt(pos, endPos) {
                    pos := add(pos, 32)
                } {
                    calldatacopy(add(_memPos, M_1), pos, 32)
                    mstore(_memPos, keccak256(_memPos, 64))
                }
                if iszero(mod(_policyLength, 32)) {
                    // no additinal bytes
                    _policyHash := mload(_memPos)
                }
                if gt(mod(_policyLength, 32), 0) {
                    // handle the remaining bytes
                    mstore(add(_memPos, M_1), 0)
                    calldatacopy(add(_memPos, M_1), endPos, mod(_policyLength, 32)) // remaining bytes
                    mstore(_memPos, keccak256(_memPos, 64))
                    _policyHash := mload(_memPos)
                }
                // RLY-23: chain-domain binding — the signing-policy hash commits to the configured
                // source network: keccak256(sourceChainId ‖ contentHash). Reuses the two scratch slots
                // this function already owns. The id is set once at initialize (threaded in as
                // _sourceChainId), so the same policy verifies on every Relay that mirrors this source.
                mstore(_memPos, _sourceChainId)
                mstore(add(_memPos, M_1), _policyHash)
                _policyHash := keccak256(_memPos, 64)
            }

            function extractVotingRoundIdFromMessage(
                _signingPolicyLength
            ) -> _votingRoundId {
                _votingRoundId := structValue(
                    shr(
                        sub(256, mul(8, MESSAGE_NO_MR_BYTES)),
                        calldataload(add(SELECTOR_BYTES, _signingPolicyLength))
                    ),
                    MSG_NMR_BOFF_votingRoundId,
                    MSG_NMR_MASK_votingRoundId
                )
            }

            // Sums the voters' normalized weights of the signing policy starting at
            // _signingPolicyStart in calldata. Each weight is the WEIGHT_BYTES-wide field after
            // the voter address; reading it as the top bytes of a calldataload avoids memory use.
            function calculateTotalWeight(
                _metadata,
                _signingPolicyStart
            ) -> _totalWeight {
                let offset := add(
                    add(_signingPolicyStart, SIGNING_POLICY_PREFIX_BYTES),
                    ADDRESS_BYTES
                )
                let numberOfVoters := structValue(
                    _metadata,
                    MD_BOFF_numberOfVoters,
                    MD_MASK_numberOfVoters
                )
                for { let i := 0 } lt(i, numberOfVoters) { i := add(i, 1) } {
                    _totalWeight := add(
                        _totalWeight,
                        shr(
                            sub(256, mul(8, WEIGHT_BYTES)),
                            calldataload(add(offset, mul(i, ADDRESS_AND_WEIGHT_BYTES)))
                        )
                    )
                }
            }

            function checkThresholdConsistency(
                _memPtr,
                _metadata,
                _signingPolicyStart
            ) {
                let totalWeight := calculateTotalWeight(_metadata, _signingPolicyStart)
                if gt(totalWeight, sub(shl(16, 1),1)) {   // totalWeight > 2 ** 16 - 1
                    revertWithError(_memPtr, ERR_TOTAL_WEIGHT_TOO_BIG)
                }
                let threshold := structValue(
                    _metadata,
                    MD_BOFF_threshold,
                    MD_MASK_threshold
                )
                if lt(mul(threshold, THRESHOLD_BIPS), mul(totalWeight, MIN_THRESHOLD_BIPS)) {
                    revertWithError(_memPtr, ERR_THRESHOLD_TOO_LOW)
                }
                if gt(mul(threshold, THRESHOLD_BIPS), mul(totalWeight, MAX_THRESHOLD_BIPS)) {
                    revertWithError(_memPtr, ERR_THRESHOLD_TOO_HIGH)
                }
            }

            function setIsSecureRandomBit(_memPtr, _votingRoundId) {
                //  isSecureRandomMap[_votingRoundId / 256]
                mstore(_memPtr, div(_votingRoundId, 256)) // key (_votingRoundId / 256)
                mstore(add(_memPtr, 32), isSecureRandomMap.slot)

                sstore(
                    keccak256(_memPtr, 64),
                    or(
                        sload(keccak256(_memPtr, 64)),
                        shl(sub(255, mod(_votingRoundId, 256)), 1)
                    )
                )
            }

            // RLY-03: verify a random-number Merkle proof and persist the value.
            // The calldata after the signatures must be: randomNumber (32 bytes) followed by the
            // Merkle proof (a sequence of 32-byte nodes). The leaf is
            //   keccak256(abi.encode(uint256 votingRoundId, uint256 value, uint256 isSecure))
            // and the proof is processed with OpenZeppelin sorted-pair hashing up to _memPtrMerkleRoot.
            // On success, toRandomNumberPrivate[_votingRoundId] = randomNumber; otherwise it reverts.
            // Uses scratch at _memPtr, _memPtr+32, _memPtr+64.
            function processRandomMerkleProof(
                _memPtr, _proofStart, _memPtrMerkleRoot, _votingRoundId, _isSecureRandom
            ) {
                // calldata must contain at least the 32-byte random number after the signatures
                if lt(calldatasize(), add(_proofStart, 32)) {
                    revertWithError(_memPtr, ERR_NO_RANDOM_NUMBER)
                }
                // the trailing calldata (random number + proof) must be a whole number of 32-byte words
                if iszero(eq(mod(sub(calldatasize(), _proofStart), 32), 0)) {
                    revertWithError(_memPtr, ERR_INCORRECT_MERKLE_PROOF)
                }
                // leaf = keccak256(votingRoundId || value || isSecure)
                mstore(_memPtr, _votingRoundId)
                calldatacopy(add(_memPtr, 32), _proofStart, 32) // random number value
                mstore(add(_memPtr, 64), _isSecureRandom)
                mstore(_memPtr, keccak256(_memPtr, 96))
                for {
                    let pos := add(_proofStart, 32)
                } lt(pos, calldatasize()) {
                    pos := add(pos, 32)
                } {
                    calldatacopy(add(_memPtr, 32), pos, 32) // proof element
                    // sorted-pair parent hash
                    if lt(mload(_memPtr), mload(add(_memPtr, 32))) {
                        mstore(_memPtr, keccak256(_memPtr, 64))
                        continue
                    }
                    mstore(add(_memPtr, 64), mload(_memPtr))
                    mstore(_memPtr, keccak256(add(_memPtr, 32), 64))
                }
                if iszero(eq(mload(_memPtr), mload(_memPtrMerkleRoot))) {
                    revertWithError(_memPtr, ERR_INVALID_RANDOM_NUMBER_PROOF)
                }
                // toRandomNumberPrivate[_votingRoundId] = randomNumber
                calldatacopy(add(_memPtr, 64), _proofStart, 32) // reload value (slots 0/32 reused as map key/slot)
                mstore(_memPtr, _votingRoundId)
                mstore(add(_memPtr, 32), toRandomNumberPrivate.slot)
                sstore(keccak256(_memPtr, 64), mload(add(_memPtr, 64)))
            }
////////////// A comment on handling of signing policy and a message /////////////////////////////////////////
//
// A relayer provides a signing policy and a message.
// Let:
// v - votingRoundId of the message
// r - reward epoch of the signing policy
// exp(v) - expected reward epoch for `v`
// s - startVotingRound of signing policy for `r`
// s+ - startVotingRound od signing policy for `r + 1` (`i` must be >= `r + 1`)
// i - reward epoch of the last initialized signing policy
//
// Analysis of all combinations. Assume i >= r. Otherwise REVERT.
//     exp(v) < r  |      REVERT
// -----------------------------------------------------------------------------------------------------------
//     exp(v) == r | v >= s    OK
//                 | v < s     REVERT
// -----------------------------------------------------------------------------------------------------------
//     exp(v) > r  |  v < s    REVERT
//                 -------------------------------------------------------------------------------------------
//                 |  v >= s            |  i = r        OK (increase threshold)
//                 |                    ----------------------------------------------------------------------
//                 |                    |  i > r      | v >= s+       REVERT (new signing policy must be used)
//                 |                    |             | v < s+        OK
//
////////////// Start of code /////////////////////////////////////////////////////////////////////////////////
            // free memory pointer
            let memPtr := mload(0x40)
            // NOTE: the struct is packed in reverse order of bytes

            // stateData loaded into memory to slot M_5_stateData
            mstore(add(memPtr, M_5_stateData), sload(stateData.slot))

            ///////////// Extracting signing policy metadata /////////////
            if lt(calldatasize(), add(SELECTOR_BYTES, METADATA_BYTES)) {
                revertWithError(memPtr, ERR_INVALID_SIGN_POLICY_METADATA)
            }

            // read the metadata prefix directly from calldata, shifted to the right of bytes32
            // (the length check above guarantees the METADATA_BYTES are all within calldata)
            let metadata := shr(sub(256, mul(8, METADATA_BYTES)), calldataload(SELECTOR_BYTES))
            let rewardEpochId := structValue(
                metadata,
                MD_BOFF_rewardEpochId,
                MD_MASK_rewardEpochId
            )

            let signingPolicyLength := add(
                SIGNING_POLICY_PREFIX_BYTES,
                mul(
                    structValue(
                        metadata,
                        MD_BOFF_numberOfVoters,
                        MD_MASK_numberOfVoters
                    ),
                    ADDRESS_AND_WEIGHT_BYTES
                )
            )

            // The calldata must be of length at least 4 function selector + signingPolicyLength + 1 protocolId
            if lt(
                calldatasize(),
                add(SELECTOR_BYTES, add(signingPolicyLength, PROTOCOL_ID_BYTES))
            ) {
                revertWithError(memPtr, ERR_INVALID_SIGN_POLICY_LENGTH)
            }

            ///////////// Verifying signing policy /////////////
            // signing policy hash temporarily stored to slot M_2
            mstore(
                add(memPtr, M_2_signingPolicyHashTmp),
                calculateSigningPolicyHash(
                    memPtr,
                    SELECTOR_BYTES,
                    signingPolicyLength,
                    srcChainId
                )
            )

            //  toSigningPolicyHashPrivate[rewardEpochId] -> existingSigningPolicyHash
            mstore(memPtr, rewardEpochId) // key (rewardEpochId)
            mstore(add(memPtr, M_1), toSigningPolicyHashPrivate.slot)

            // store existing signing policy hash to slot M_3 temporarily
            mstore(
                add(memPtr, M_3_existingSigningPolicyHashTmp),
                sload(keccak256(memPtr, 64))
            )

            // From here on we have calldatasize() > 4 + signingPolicyLength

            ///////////// Verifying signing policy /////////////
            if iszero(
                eq(
                    mload(add(memPtr, M_2_signingPolicyHashTmp)),
                    mload(add(memPtr, M_3_existingSigningPolicyHashTmp))
                )
            ) {
                revertWithError(memPtr, ERR_SIGNING_POLICY_HASH_MISMATCH)
            }

            // Extracting protocolId, votingRoundId and isSecureRandom
            // 1 bytes - protocolId
            // 4 bytes - votingRoundId
            // 1 bytes - isSecureRandom
            // 32 bytes - merkleRoot
            // message length: 38

            let protocolId := shr(
                sub(256, mul(8, PROTOCOL_ID_BYTES)), // move to the rightmost position
                calldataload(add(SELECTOR_BYTES, signingPolicyLength))
            )

            let signatureStart := 0 // First index of signatures in calldata
            let threshold := structValue(
                metadata,
                MD_BOFF_threshold,
                MD_MASK_threshold
            )

            // Caller-chosen threshold override in BIPS of the policy's total normalized weight,
            // set only by verifyCustomSignatureWithThreshold's transient slot for the duration
            // of its self-call (0 on every top-level call).
            // SECURITY: gated to protocolId == 1 — the pure verification path, which stores
            // nothing and only returns — so an override can never lower the quorum for Mode-1
            // policy relay or Mode-2 finalization even though the wrapper forwards arbitrary
            // caller calldata. (The cross-epoch thresholdIncreaseBIPS bump below is unreachable
            // for protocolId == 1: its messageRewardEpochId always equals rewardEpochId.)
            if eq(protocolId, 1) {
                let overrideBIPS := tload(TSLOT_THRESHOLD_OVERRIDE)
                if gt(overrideBIPS, 0) {
                    // The policy metadata carries only the threshold, so sum the total weight
                    // from calldata (shared with checkThresholdConsistency; the policy content
                    // is hash-verified above, and registration bounds totalWeight <= 2^16 - 1).
                    // mulDivRoundUp(totalWeight, overrideBIPS, THRESHOLD_BIPS) — the same
                    // ceiling FlareSystemsManager._initializeNextSigningPolicy uses to derive a
                    // policy threshold from a BIPS-like fraction; acceptance below stays strict
                    // (weight > threshold), matching the Fdc2RequestHeader.thresholdBIPS spec.
                    threshold := div(
                        add(
                            mul(calculateTotalWeight(metadata, SELECTOR_BYTES), overrideBIPS),
                            sub(THRESHOLD_BIPS, 1)
                        ),
                        THRESHOLD_BIPS
                    )
                }
            }

            ///////////// Preparation of message hash /////////////
            // protocolId > 0 means we are relaying or checking the validity of signatures (Mode 2)
            // The signed hash is the message hash and it gets prepared into slot 32
            if gt(protocolId, 0) {
                let memPtrGP0 := mload(0x40)
                signatureStart := add(
                    SELECTOR_BYTES,
                    add(signingPolicyLength, MESSAGE_BYTES)
                )
                if lt(calldatasize(), signatureStart) {
                    revertWithError(memPtrGP0, ERR_TOO_SHORT_MESSAGE)
                }

                calldatacopy(
                    memPtrGP0,
                    add(SELECTOR_BYTES, signingPolicyLength),
                    MESSAGE_BYTES
                )

                let votingRoundId := structValue(
                    shr(
                        sub(256, mul(8, MESSAGE_NO_MR_BYTES)),
                        mload(memPtrGP0)
                    ),
                    MSG_NMR_BOFF_votingRoundId,
                    MSG_NMR_MASK_votingRoundId
                )
                // Check if merkleRootsPrivate[protocolId][votingRoundId] is set
                // NOTE: M1 is already consumed. Hence using M_3 and M_4
                mstore(add(memPtrGP0, M_3), protocolId) // key 1 (protocolId)
                mstore(add(memPtrGP0, M_4), merkleRootsPrivate.slot) // merkleRoot slot
                mstore(add(memPtrGP0, M_4), keccak256(add(memPtrGP0, M_3), 64))
                mstore(add(memPtrGP0, M_3), votingRoundId) // key 2 (votingRoundId)

                if gt(sload(keccak256(add(memPtrGP0, M_3), 64)), 0) {
                    revertWithError(memPtrGP0, ERR_ALREADY_RELAYED)
                }

                if eq(protocolId, 1) {
                    // both votingRoundId and isSecureRandom should be 0
                    if votingRoundId {
                        revertWithError(memPtrGP0, ERR_WRONG_MESSAGE_FORMAT)
                    }

                    if structValue( // isSecureRandom should be 0
                        shr(
                            sub(256, mul(8, MESSAGE_NO_MR_BYTES)),
                            mload(memPtrGP0)
                        ),
                        MSG_NMR_BOFF_isSecureRandom,
                        MSG_NMR_MASK_isSecureRandom
                    ) {
                        revertWithError(memPtrGP0, ERR_WRONG_MESSAGE_FORMAT2)
                    }
                }

                // the expected reward epoch id
                // for direct message signing (protocolId == 1)
                let messageRewardEpochId := rewardEpochId

                if iszero(eq(protocolId, 1)) {
                    messageRewardEpochId := rewardEpochIdFromVotingRoundId(
                        mload(add(memPtrGP0, M_5_stateData)),
                        votingRoundId
                    )
                }

                // Given a signing policy for reward epoch R one can sign either messages
                // in reward epochs R or later
                if lt(messageRewardEpochId, rewardEpochId) {
                    revertWithError(memPtrGP0, ERR_WRONG_SIGN_POLICY_REWARD_EPOCH)
                }

                // The message must not be too old
                // This limits the influence of participants in old signing policies
                if lt(
                    add(
                        messageRewardEpochId,
                        structValue(
                            mload(add(memPtrGP0, M_5_stateData)),
                            SD_BOFF_messageFinalizationWindowInRewardEpochs,
                            SD_MASK_messageFinalizationWindowInRewardEpochs
                        )
                    ),
                    structValue(
                        mload(add(memPtrGP0, M_5_stateData)),
                        SD_BOFF_lastInitializedRewardEpoch,
                        SD_MASK_lastInitializedRewardEpoch
                    )
                ){
                    revertWithError(memPtrGP0, ERR_MESSAGE_TOO_OLD)
                }

                let startingVotingRoundId := structValue(
                    metadata,
                    MD_BOFF_startingVotingRoundId,
                    MD_MASK_startingVotingRoundId
                )
                // in case the reward epoch id start gets delayed -> signing policy for earlier
                // reward epoch must be provided
                if and(iszero(eq(protocolId, 1)), lt(votingRoundId, startingVotingRoundId)) {
                    revertWithError(memPtrGP0, ERR_DELAYED_SIGN_POLICY)
                }

                if gt(messageRewardEpochId, rewardEpochId) {
                    let lastInitializedRewardEpoch :=
                        structValue(
                            mload(add(memPtrGP0, M_5_stateData)),
                            SD_BOFF_lastInitializedRewardEpoch,
                            SD_MASK_lastInitializedRewardEpoch
                        )
                    if gt(lastInitializedRewardEpoch, rewardEpochId) {
                        mstore(add(memPtrGP0, M_3), add(rewardEpochId, 1)) // key (rewardEpochId + 1)
                        mstore(add(memPtrGP0, M_4), startingVotingRoundIds.slot) // startingVotingRoundIds slot
                        let nextStartingVotingRoundId := sload(keccak256(add(memPtrGP0, M_3), 64))
                        // if votingRoundId >= nextStartingVotingRoundId, revert
                        if gt(add(votingRoundId, 1), nextStartingVotingRoundId) {
                            revertWithError(memPtrGP0, ERR_MUST_USE_NEW_SIGN_POLICY)
                        }
                    }
                    if eq(lastInitializedRewardEpoch, rewardEpochId) {
                        // RLY-05 (deferred, Low, no exploit): truncating integer `div` — the scaled
                        // threshold can be up to 1 weight-unit below the exact value, a sub-unit bias
                        // toward an attacker. Immaterial against the aggregate threshold; a ceil-div
                        // fix is deferred by decision. See docs/relay-fixes.md.
                        threshold := div(
                            mul(
                                threshold,
                                structValue(
                                    mload(add(memPtrGP0, M_5_stateData)),
                                    SD_BOFF_thresholdIncreaseBIPS,
                                    SD_MASK_thresholdIncreaseBIPS
                                )
                            ),
                            THRESHOLD_BIPS
                        )
                    }

                    // At this point we have situation:
                    // - messageRewardEpochId is not initialized -> increased threshold
                    // - messageRewardEpochId is initialized -> votingRoundId < nextStartingVotingRoundId
                    // consequently the threshold can stay the same
                }
                // all revert conditions are checked

                // Prepare the message hash into slot M_1
                mstore(add(memPtrGP0, M_1), keccak256(memPtrGP0, MESSAGE_BYTES))
                // RLY-23: chain-domain binding — the signed digest commits to the configured source:
                // M_1 <- keccak256(sourceChainId ‖ keccak256(message)). Slot M_0 (the spent message
                // bytes) is safe to reuse as scratch: this is the last statement of the block and the
                // accept path re-reads the message from calldata.
                mstore(memPtrGP0, srcChainId)
                mstore(add(memPtrGP0, M_1), keccak256(memPtrGP0, 64))
            }

            // protocolId == 0 means we are relaying new signing policy (Mode 1)
            // The signed hash is the signing policy hash and it gets prepared into slot 32

            if eq(protocolId, 0) {
                // Check if signing policy relay is enabled

                if gt(
                    structValue(
                        mload(add(mload(0x40), M_5_stateData)),
                        SD_BOFF_noSigningPolicyRelay,
                        SD_MASK_noSigningPolicyRelay
                    ),
                    0
                ) {
                    revertWithError(mload(0x40), ERR_SIGN_POLICY_RELAY_DISABLED)
                }

                if lt(
                    calldatasize(),
                    add(
                        SELECTOR_BYTES,
                        add(
                            signingPolicyLength,
                            add(PROTOCOL_ID_BYTES, METADATA_BYTES)
                        )
                    )
                ) {
                    revertWithError(mload(0x40), ERR_NO_NEW_SIGN_POLICY_SIZE)
                }

                // New metadata
                calldatacopy(
                    mload(0x40),
                    add(
                        SELECTOR_BYTES,
                        add(PROTOCOL_ID_BYTES, signingPolicyLength)
                    ),
                    METADATA_BYTES
                )

                let newMetadata := shr(
                    sub(256, mul(8, METADATA_BYTES)),
                    mload(mload(0x40))
                )
                let newNumberOfVoters := structValue(
                    newMetadata,
                    MD_BOFF_numberOfVoters,
                    MD_MASK_numberOfVoters
                )
                // must be at least one voter
                if eq(newNumberOfVoters, 0) {
                    revertWithError(mload(0x40), ERR_SIGNING_POLICY_EMPTY)
                }
                // must be at most MAX_VOTERS
                if gt(newNumberOfVoters, MAX_VOTERS) {
                    revertWithError(mload(0x40), ERR_TOO_MANY_VOTERS)
                }

                let newSigningPolicyLength := add(
                    SIGNING_POLICY_PREFIX_BYTES,
                    mul(newNumberOfVoters, ADDRESS_AND_WEIGHT_BYTES)
                )

                signatureStart := add(
                    SELECTOR_BYTES,
                    add(
                        signingPolicyLength,
                        add(PROTOCOL_ID_BYTES, newSigningPolicyLength)
                    )
                )

                if lt(calldatasize(), signatureStart) {
                    revertWithError(mload(0x40), ERR_WRONG_SIZE_FOR_NEW_SIGN_POLICY)
                }

                let newSigningPolicyRewardEpochId := structValue(
                    newMetadata,
                    MD_BOFF_rewardEpochId,
                    MD_MASK_rewardEpochId
                )

                let tmpLastInitializedRewardEpochId := structValue(
                    mload(add(mload(0x40), M_5_stateData)),
                    SD_BOFF_lastInitializedRewardEpoch,
                    SD_MASK_lastInitializedRewardEpoch
                )

                // should the old signing policy reward epoch id be the last intialized one
                if iszero(
                    eq(
                        tmpLastInitializedRewardEpochId,
                        rewardEpochId
                    )
                ) {
                    revertWithError(mload(0x40), ERR_NOT_WITH_LAST_INITIALIZED)
                }

                // Should be next reward epoch id
                if iszero(
                    eq(
                        add(1, tmpLastInitializedRewardEpochId),
                        newSigningPolicyRewardEpochId
                    )
                ) {
                    revertWithError(mload(0x40), ERR_NOT_NEXT_REWARD_EPOCH)
                }

                // Check the threshold consistency
                checkThresholdConsistency(
                    mload(0x40),
                    newMetadata,
                    add(
                        SELECTOR_BYTES,
                        add(PROTOCOL_ID_BYTES, signingPolicyLength)
                    )
                )

                let newSigningPolicyHash := calculateSigningPolicyHash(
                    mload(0x40),
                    add(
                        SELECTOR_BYTES,
                        add(signingPolicyLength, PROTOCOL_ID_BYTES)
                    ),
                    newSigningPolicyLength,
                    srcChainId
                )
                // Update temporary stateData. If the weight of signatures if
                // over threshold, then this will be written to storage
                mstore(
                    add(mload(0x40), M_5_stateData),
                    assignStruct(
                        mload(add(mload(0x40), M_5_stateData)),
                        SD_BOFF_lastInitializedRewardEpoch,
                        SD_MASK_lastInitializedRewardEpoch,
                        newSigningPolicyRewardEpochId
                    )
                )

                // RLY-08 (deferred, Note, no exploit): the two signing-policy storage writes below
                // (startingVotingRoundIds and toSigningPolicyHashPrivate) precede the signature-aggregate
                // threshold check (the accept gate later in the loop). This is atomicity-safe — if the
                // threshold is not met the whole transaction reverts and unwinds them (see the IMPORTANT
                // note a few lines down). A structural write-after-verify reorder is deferred by decision
                // (risky inline-assembly change for a no-exploit note). See docs/relay-fixes.md.
                // startingVotingRoundId[newSigningPolicyRewardEpochId] = newMetadata.startingVotingRoundId
                mstore(mload(0x40), newSigningPolicyRewardEpochId)
                mstore(add(mload(0x40), M_1), startingVotingRoundIds.slot)
                sstore(
                    keccak256(mload(0x40), 64),
                    structValue(
                        newMetadata,
                        MD_BOFF_startingVotingRoundId,
                        MD_MASK_startingVotingRoundId
                    )
                )

                // toSigningPolicyHashPrivate[newSigningPolicyRewardEpochId] = newSigningPolicyHash
                mstore(mload(0x40), newSigningPolicyRewardEpochId)
                mstore(add(mload(0x40), M_1), toSigningPolicyHashPrivate.slot)
                sstore(keccak256(mload(0x40), 64), newSigningPolicyHash)
                // Prepare the hash on slot 32 for signature verification
                mstore(add(mload(0x40), M_1), newSigningPolicyHash)
                // IMPORTANT: assumes that if threshold is not sufficient, the transaction will be reverted

                // emit event
                // use temporarily M_3 to store event signature
                mstore(add(mload(0x40), M_3), "SigningPolicyRelayed(uint256)")
                log2(mload(0x40), 0, keccak256(add(mload(0x40), M_3), 29), newSigningPolicyRewardEpochId)
            }

            // Assumptions here:
            // - memPtr (slot M_1) contains either protocol message merkle root hash or new signing policy hash
            // - signatureStart points to the first signature in calldata
            // - We are sure that calldatasize() >= signatureStart

            // Use M_2 temporarily to extract number of signatures
            // Note that M_1 is used for the hash
            if lt(
                calldatasize(),
                add(signatureStart, NUMBER_OF_SIGNATURES_BYTES)
            ) {
                revertWithError(memPtr, ERR_NO_SIGNATURE_COUNT)
            }

            calldatacopy(
                add(memPtr, M_2),
                signatureStart,
                NUMBER_OF_SIGNATURES_BYTES
            )
            let numberOfSignatures := and(
                shr(
                    NUMBER_OF_SIGNATURES_RIGHT_SHIFT_BITS,
                    mload(add(memPtr, M_2))
                ),
                NUMBER_OF_SIGNATURES_MASK
            )
            signatureStart := add(signatureStart, NUMBER_OF_SIGNATURES_BYTES)
            // RLY-03: stash signatureStart for the random-proof trailer (read deep in the random branch
            // where keeping it on the stack would risk stack-too-deep)
            mstore(add(memPtr, M_8_signatureStart), signatureStart)
            if lt(
                calldatasize(),
                add(
                    signatureStart,
                    mul(numberOfSignatures, SIGNATURE_WITH_INDEX_BYTES)
                )
            ) {
                revertWithError(memPtr, ERR_NOT_ENOUGH_SIGNATURES)
            }

            // Prefixed hash calculation
            // 4-bytes padded prefix into slot 0
            mstore(memPtr, "0000\x19Ethereum Signed Message:\n32")
            // Prefixed hash into slot 0, skipping 4-bytes of 0-prefix
            mstore(memPtr, keccak256(add(memPtr, 4), 60))

            // Processing signatures. Memory map:
            // memPtr (slot 0)  | prefixedHash
            // M_1              | v
            // M_2              | r, signer
            // M_3              | s, expectedSigner + weight
            // M_4              | index

            for {
                let numberOfVoters := structValue(
                    metadata,
                    MD_BOFF_numberOfVoters,
                    MD_MASK_numberOfVoters
                )
                let i := 0
                // accumulated weight of signatures
                let weight := 0
                // enforces increasing order of indices in signatures
                let nextUnusedIndex := 0
                let memPtrFor := mload(0x40)
            } lt(i, numberOfSignatures) {
                i := add(i, 1)
            } {
                // clear v - only the last byte will change
                mstore(add(memPtrFor, M_1), 0)

                calldatacopy(
                    add(memPtrFor, add(M_1, sub(32, SIGNATURE_V_BYTES))),
                    add(signatureStart, mul(i, SIGNATURE_WITH_INDEX_BYTES)), // signature position
                    SIGNATURE_WITH_INDEX_BYTES
                ) // 63 ... last byte of slot +32
                // Note that those things get set
                // - slot M_1 - the rightmost byte of 'v' gets set
                // - slot M_2    - r
                // - slot M_3    - s
                // - slot M_4   - index (only the top 2 bytes)
                let index := shr(
                    SIGNATURE_INDEX_RIGHT_SHIFT_BITS,
                    mload(add(memPtrFor, M_4))
                )

                // Index sanity checks in regard to signing policy.
                // RLY-06 linkage: signing policies are NOT re-checked for zero-address/duplicate voters
                // (the trusted setter, or for relayed policies the signed policy hash, owns that). The
                // strictly-increasing index below is what carries no-double-count security regardless of
                // policy origin: a duplicate voter can be counted at most once (index must strictly
                // increase), and a zero-address "voter" cannot be matched because ecrecover never yields
                // address(0) (enforced by the returndatasize / zero-signer checks above).
                if gt(add(index, 1), numberOfVoters) {
                    revertWithError(memPtrFor, ERR_INDEX_OUT_OF_RANGE)
                }

                if lt(index, nextUnusedIndex) {
                    revertWithError(memPtrFor, ERR_INDEX_OUT_OF_ORDER)
                }
                nextUnusedIndex := add(index, 1)

                // RLY-16: reject non-canonical ECDSA signatures (defence-in-depth; strict index
                // ordering already neutralizes malleability double-counting). v must be 27 or 28,
                // and s must lie in the lower half of the curve order (EIP-2 low-s).
                if iszero(or(
                    eq(and(mload(add(memPtrFor, M_1)), 0xff), 27),
                    eq(and(mload(add(memPtrFor, M_1)), 0xff), 28)
                )) {
                    revertWithError(memPtrFor, ERR_BAD_V)
                }
                if gt(
                    mload(add(memPtrFor, M_3)),
                    0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0
                ) {
                    revertWithError(memPtrFor, ERR_BAD_S)
                }

                // ecrecover call. Address goes to slot 64, it is 0 padded
                if iszero(
                    staticcall(
                        not(0),
                        0x01,
                        memPtrFor,
                        0x80,
                        add(memPtrFor, M_2),
                        32
                    )
                ) {
                    revertWithError(memPtrFor, ERR_ECRECOVER_ERROR)
                }
                if iszero(eq(returndatasize(),32)) {
                    revertWithError(memPtrFor, ERR_ECRECOVER_RETURNED_BAD_DATA)
                }
                // RLY-18: explicit zero-recovered-signer guard. Already implied by the returndatasize
                // check above (a successful recovery is never address(0)); kept for clarity/robustness.
                if iszero(mload(add(memPtrFor, M_2))) {
                    revertWithError(memPtrFor, ERR_ZERO_SIGNER)
                }
                // extract expected signer address to slot no 96
                mstore(add(memPtrFor, M_3), 0) // zeroing slot for expected address

                calldatacopy(
                    add(memPtrFor, sub(add(M_3, ADDRESS_OFFSET), WEIGHT_BYTES)),
                    add(
                        add(SELECTOR_BYTES, SIGNING_POLICY_PREFIX_BYTES),
                        mul(index, ADDRESS_AND_WEIGHT_BYTES)
                    ),
                    ADDRESS_AND_WEIGHT_BYTES
                )

                // Check if the recovered signer is the expected signer
                if iszero(
                    eq(
                        mload(add(memPtrFor, M_2)),
                        shr(mul(8, WEIGHT_BYTES), mload(add(memPtrFor, M_3))) // keep the address only
                    )
                ) {
                    revertWithError(memPtrFor, ERR_WRONG_SIGNATURE)
                }

                weight := add(
                    weight,
                    and(mload(add(memPtrFor, M_3)), WEIGHT_MASK)
                )

                if gt(weight, threshold) {
                    if eq(protocolId, 0) {
                        // Store updated stateData (lastInitializedRewardEpoch)
                        sstore(
                            stateData.slot,
                            mload(add(memPtrFor, M_5_stateData))
                        )
                        // in case protocolId == 0, the new signing policy is already stored
                        // and event emitted
                        return(0,0)
                    }

                    if gt(protocolId, 0) {
                        // M_6_merkleRoot <- Merkle root
                        calldatacopy(
                            add(memPtrFor, M_6_merkleRoot),
                            add(
                                add(SELECTOR_BYTES, signingPolicyLength),
                                sub(MESSAGE_BYTES, 32) // last 32 bytes are merkleRoot
                            ),
                            32
                        )
                        if eq(protocolId, 1) {
                            // RLY-07: this is the ONLY relay() path that returns non-empty data
                            // (35 bytes: 32-byte merkleRoot/hash + 3-byte rewardEpochId). Every other
                            // path returns 0 bytes or reverts, so _verifyCustomSignature uses the 35-byte
                            // length as the discriminator for this path — preserve it if changing returns.
                            mstore(memPtrFor, mload(add(memPtrFor, M_6_merkleRoot)))
                            mstore(
                                add(memPtrFor, M_1),
                                shl(sub(256, mul(8, REWARD_EPOCH_ID_BYTES)), rewardEpochId)
                            )
                            return (memPtrFor, add(32, REWARD_EPOCH_ID_BYTES))
                        }

                        // RLY-04: reject a zero merkle root (would break isFinalized and the
                        // already-relayed sentinel, and allow repeated event spam for the round).
                        if iszero(mload(add(memPtrFor, M_6_merkleRoot))) {
                            revertWithError(memPtrFor, ERR_ZERO_MERKLE_ROOT)
                        }

                        let votingRoundId := extractVotingRoundIdFromMessage(
                            signingPolicyLength
                        )

                        // writing into the map
                        mstore(memPtrFor, protocolId) // key 1 (protocolId)
                        mstore(add(memPtrFor, M_1), merkleRootsPrivate.slot) // merkleRoot slot

                        // parent map location in slot for next hashing
                        mstore(add(memPtrFor, M_1), keccak256(memPtrFor, 64))
                        mstore(memPtrFor, votingRoundId) // key 2 (votingRoundId)
                        // merkleRoot stored at merkleRootsPrivate[protocolId][votingRoundId]
                        sstore(
                            keccak256(memPtrFor, 64),
                            mload(add(memPtrFor, M_6_merkleRoot))
                        ) // set Merkle Root

                        // if protocolId != stateData.randomNumberProtocolId
                        // just emit an event
                        if iszero(
                            eq(
                                protocolId,
                                structValue(
                                    mload(add(memPtrFor, M_5_stateData)),
                                    SD_BOFF_randomNumberProtocolId,
                                    SD_MASK_randomNumberProtocolId
                                )
                            )
                        ) {
                            calldatacopy(
                                memPtrFor,
                                add(SELECTOR_BYTES, signingPolicyLength),
                                MESSAGE_NO_MR_BYTES
                            )
                            mstore(
                                memPtrFor,
                                shr(
                                    sub(256, mul(8, MESSAGE_NO_MR_BYTES)),
                                    mload(memPtrFor)
                                )
                            )

                            // Here we setup M_5 to value of isSecureRandom from message
                            // while in M_6 we have Merkle root
                            // Note that the value of isSecureRandom outside the random
                            // generating protocol is meaningless.
                            // These two fields are used for the emitted event
                            mstore(add(memPtrFor, M_5_isSecureRandom),
                                structValue(
                                    mload(memPtrFor),
                                    MSG_NMR_BOFF_isSecureRandom,
                                    MSG_NMR_MASK_isSecureRandom
                                )
                            )
                            mstore(add(memPtrFor, M_3), "ProtocolMessageRelayed(uint8,uin")
                            mstore(add(memPtrFor, M_4), "t32,bool,bytes32)")
                            log3(
                                add(memPtrFor, M_5_isSecureRandom), 64, keccak256(add(memPtrFor, M_3), 49),
                                protocolId, votingRoundId
                            )
                            return(0,0)
                        }

                        // if protocolId == stateData.randomNumberProtocolId
                        if eq(
                            protocolId,
                            structValue(
                                mload(add(memPtrFor, M_5_stateData)),
                                SD_BOFF_randomNumberProtocolId,
                                SD_MASK_randomNumberProtocolId
                            )
                        ) {
                            // RLY-14: read and normalize isSecureRandom from the message to {0,1}
                            calldatacopy(
                                memPtrFor,
                                add(SELECTOR_BYTES, signingPolicyLength),
                                MESSAGE_NO_MR_BYTES
                            )
                            let isSecure := iszero(iszero(
                                structValue(
                                    shr(sub(256, mul(8, MESSAGE_NO_MR_BYTES)), mload(memPtrFor)),
                                    MSG_NMR_BOFF_isSecureRandom,
                                    MSG_NMR_MASK_isSecureRandom
                                )
                            ))

                            // RLY-03: verify the random Merkle proof against the signed merkleRoot and store
                            // toRandomNumberPrivate[votingRoundId] (always, so historical lookups work).
                            // The trailer (randomNumber || proof) starts right after the signatures.
                            processRandomMerkleProof(
                                memPtrFor,
                                add(
                                    mload(add(memPtrFor, M_8_signatureStart)),
                                    mul(numberOfSignatures, SIGNATURE_WITH_INDEX_BYTES)
                                ),
                                add(memPtrFor, M_6_merkleRoot),
                                votingRoundId,
                                isSecure
                            )

                            // historical secure-random bit (always, for getRandomNumberHistorical)
                            if isSecure {
                                setIsSecureRandomBit(add(memPtrFor, M_3), votingRoundId)
                            }

                            // RLY-03 monotonicity: advance the live random pointer only for a newer round,
                            // so a stale (within-window) older round cannot regress the reported "current" random.
                            // L-7 (narrow/accepted): the stored pointer starts at 0, so a FIRST-ever random relayed
                            // at votingRoundId 0 would not advance it. The random protocol's first round is always
                            // > 0 in practice (firstRewardEpochStartVotingRoundId), so this edge is not reachable.
                            if gt(
                                votingRoundId,
                                structValue(
                                    mload(add(memPtrFor, M_5_stateData)),
                                    SD_BOFF_randomVotingRoundId,
                                    SD_MASK_randomVotingRoundId
                                )
                            ) {
                                sstore(
                                    stateData.slot,
                                    assignStruct(
                                        assignStruct(
                                            mload(add(memPtrFor, M_5_stateData)),
                                            SD_BOFF_randomVotingRoundId,
                                            SD_MASK_randomVotingRoundId,
                                            votingRoundId
                                        ),
                                        SD_BOFF_isSecureRandom,
                                        SD_MASK_isSecureRandom,
                                        isSecure
                                    )
                                )
                            }

                            // emit ProtocolMessageRelayed(protocolId, votingRoundId, isSecureRandom, merkleRoot)
                            // data: isSecureRandom (M_5) + merkleRoot (still in M_6)
                            mstore(add(memPtrFor, M_5_isSecureRandom), isSecure)
                            mstore(add(memPtrFor, M_3), "ProtocolMessageRelayed(uint8,uin")
                            mstore(add(memPtrFor, M_4), "t32,bool,bytes32)")
                            log3(
                                add(memPtrFor, M_5_isSecureRandom), 64, keccak256(add(memPtrFor, M_3), 49),
                                protocolId, votingRoundId
                            )

                            // RLY-03: emit RandomNumberRelayed(votingRoundId, randomNumber, isSecureRandom)
                            // data: randomNumber (M_6) + isSecureRandom (M_7); indexed topic: votingRoundId
                            calldatacopy(
                                add(memPtrFor, M_6_merkleRoot),
                                add(
                                    mload(add(memPtrFor, M_8_signatureStart)),
                                    mul(numberOfSignatures, SIGNATURE_WITH_INDEX_BYTES)
                                ),
                                32
                            )
                            mstore(add(memPtrFor, M_7_randomNumber), isSecure)
                            mstore(add(memPtrFor, M_3), "RandomNumberRelayed(uint32,uint2")
                            mstore(add(memPtrFor, M_4), "56,bool)")
                            log2(
                                add(memPtrFor, M_6_merkleRoot), 64, keccak256(add(memPtrFor, M_3), 40),
                                votingRoundId
                            )
                            return(0,0)
                        } // if protocolId == stateData.randomNumberProtocolId
                    } // if protocolId > 0
                    // this should never happen as particular cases are handled above and returns
                    // are done from there
                    revertWithError(mload(0x40), ERR_UNREACHABLE_CODE)
                }
            } // for

            // NO CODE SHOULD BE ADDED HERE
        } // assembly
        revert NotEnoughWeight();
    }

    /**
     * @inheritdoc IRelay
     */
    function verify(uint256 _protocolId, uint256 _votingRoundId, bytes32 _leaf, bytes32[] calldata _proof)
        external payable
        returns (bool)
    {
        // Read-delegation boundary: rounds below startingVotingRoundIdForInitialRewardEpochId are served by
        // the old relay (here and in merkleRoots/isFinalized/getRandomNumberHistorical/toSigningPolicyHash).
        // No new-relay write can land below this boundary (so there is no silent shadowing): the lowest stored
        // signing policy is initialRewardEpochId, and the relay() gates "Wrong sign policy reward epoch"
        // (messageRewardEpochId >= policy rewardEpochId) and "Delayed sign policy"
        // (votingRoundId >= policy startVotingRoundId) force every Mode-2 write to have
        // votingRoundId >= startingVotingRoundIdForInitialRewardEpochId. Write domain == read-delegation domain.
        if (address(oldRelay) != address(0) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId) {
            // RLY-13: fail closed if the old relay returns false (rather than reverting).
            // M-1: forward only the old relay's fee and refund any overpayment, so the fallback honours
            // the same fee/refund contract as the new-relay path below.
            uint256 oldFee = oldRelay.protocolFeeInWei(_protocolId);
            require(msg.value >= oldFee, TooLowFee());
            bool ok = oldRelay.verify{value: oldFee}(_protocolId, _votingRoundId, _leaf, _proof);
            require(ok, OldRelayVerificationFailed());
            uint256 oldRefund = msg.value - oldFee;
            if (oldRefund > 0) {
                /* solhint-disable avoid-low-level-calls */
                (bool oldRefundOk, ) = msg.sender.call{value: oldRefund}("");
                /* solhint-enable avoid-low-level-calls */
                require(oldRefundOk, RefundFailed());
            }
            return true;
        } else {
            require(_protocolId > 1, InvalidProtocolId());
            // Safe-governed allowlist (e.g. DVN adapters): exempt callers pay no fee. The
            // exemption deliberately does NOT extend to the old-relay delegation path above,
            // which forwards the old relay's own fee schedule.
            uint256 fee = feeExemptAddress[msg.sender] ? 0 : protocolFeeInWei[_protocolId];
            require(msg.value >= fee, TooLowFee());
            // RLY-01: never verify against an uninitialized (zero) Merkle root.
            bytes32 root = merkleRootsPrivate[_protocolId][_votingRoundId];
            require(root != bytes32(0), NotFinalized());
            require(_proof.verifyCalldata(root, _leaf), MerkleProofInvalid());
            // RLY-21: forward only the fee to the collection address and refund any overpayment.
            // verify() performs no state writes, so these external calls cannot corrupt contract state.
            if (fee > 0) {
                /* solhint-disable avoid-low-level-calls */
                //slither-disable-next-line arbitrary-send-eth
                (bool feeOk, ) = feeCollectionAddress.call{value: fee}("");
                /* solhint-enable avoid-low-level-calls */
                require(feeOk, FeeTransferFailed());
            }
            uint256 refund = msg.value - fee;
            if (refund > 0) {
                /* solhint-disable avoid-low-level-calls */
                (bool refundOk, ) = msg.sender.call{value: refund}("");
                /* solhint-enable avoid-low-level-calls */
                require(refundOk, RefundFailed());
            }
        }

        return true;
    }

    /**
     * @inheritdoc IRelay
     */
    function isFinalized(uint256 _protocolId, uint256 _votingRoundId)
        external view
        returns (bool)
    {
        if (address(oldRelay) != address(0) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId) {
            return oldRelay.isFinalized(_protocolId, _votingRoundId);
        }
        // RLY-09: a non-zero stored root is the finalized sentinel; RLY-04 guarantees relayed roots are
        // non-zero, so this sentinel is reliable (no zero-root "relayed-but-not-finalized" ambiguity).
        return merkleRootsPrivate[_protocolId][_votingRoundId] != bytes32(0);
    }

    /**
     * @inheritdoc IRelay
     */
    function merkleRoots(uint256 _protocolId, uint256 _votingRoundId)
        external view
        returns (bytes32 _merkleRoot)
    {
        if (address(oldRelay) != address(0) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId) {
            return oldRelay.merkleRoots(_protocolId, _votingRoundId);
        }
        require(signingPolicySetter != address(0), NoAccessToMerkleRoots());
        return merkleRootsPrivate[_protocolId][_votingRoundId];
    }

    /**
     * @inheritdoc RandomNumberV2Interface
     */
    function getRandomNumber()
        external view
        returns (
            uint256 _randomNumber,
            bool _isSecureRandom,
            uint256 _randomTimestamp
        )
    {
        // RLY-03: return the relayed (Merkle-proven) random value for the latest random round.
        // RLY-20: before the first random relay this returns (0, false, ts); consumers MUST gate on
        // _isSecureRandom (getRandomNumberHistorical instead reverts for an absent round).
        _randomNumber = toRandomNumberPrivate[stateData.randomVotingRoundId];
        _isSecureRandom = stateData.isSecureRandom;
        _randomTimestamp =
            stateData.firstVotingRoundStartTs +
            uint256(stateData.randomVotingRoundId + 1) *
            stateData.votingEpochDurationSeconds;
    }

    /**
     * @inheritdoc RandomNumberV2Interface
     */
    function getRandomNumberHistorical(uint256 _votingRoundId)
        external view
        returns (
            uint256 _randomNumber,
            bool _isSecureRandom,
            uint256 _randomTimestamp
        )
    {
        if (address(oldRelay) != address(0) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId) {
            return oldRelay.getRandomNumberHistorical(_votingRoundId);
        }
        // RLY-03 + L-1: gate presence on the finalized (non-zero, per RLY-04) merkle root, NOT on the value,
        // so a legitimately-relayed random value of 0 is returned rather than mis-read as "absent".
        require(merkleRootsPrivate[stateData.randomNumberProtocolId][_votingRoundId] != bytes32(0), NoRandomNumber());
        _randomNumber = toRandomNumberPrivate[_votingRoundId];
        _isSecureRandom =
            (isSecureRandomMap[_votingRoundId / 256] >> (255 - _votingRoundId % 256)) & bytes32(uint256(1))
                == bytes32(uint256(1));
        _randomTimestamp =
            stateData.firstVotingRoundStartTs +
            uint256(_votingRoundId + 1) *
            stateData.votingEpochDurationSeconds;
    }

    /**
     * @inheritdoc IRelay
     */
    function getVotingRoundId(uint256 _timestamp) external view returns (uint256) {
        require(_timestamp >= stateData.firstVotingRoundStartTs, HistoryBeforeStart());
        return (_timestamp - stateData.firstVotingRoundStartTs) / stateData.votingEpochDurationSeconds;
    }

    /**
     * @inheritdoc IRelay
     */
    function toSigningPolicyHash(uint256 _rewardEpochId) external view returns (bytes32) {
        if (address(oldRelay) != address(0) && _rewardEpochId < initialRewardEpochId) {
            return oldRelay.toSigningPolicyHash(_rewardEpochId);
        }
        require(signingPolicySetter != address(0), NoAccessToSigningPolicyHashes());
        return toSigningPolicyHashPrivate[_rewardEpochId];
    }

    /**
     * @inheritdoc IRelay
     */
    function lastInitializedRewardEpochData()
        external view
        returns (
            uint32 _lastInitializedRewardEpoch,
            uint32 _startingVotingRoundIdForLastInitializedRewardEpoch
        )
    {
        _lastInitializedRewardEpoch = stateData.lastInitializedRewardEpoch;
        _startingVotingRoundIdForLastInitializedRewardEpoch =
            uint32(startingVotingRoundIds[_lastInitializedRewardEpoch]);
    }

    function _verifyCustomSignature(
        bytes calldata _relayMessage,
        bytes32 _messageHash
    ) internal returns (uint256 _rewardEpochId) {
        /* solhint-disable avoid-low-level-calls */
        //slither-disable-next-line arbitrary-send-eth
        (bool success, bytes memory returnData) = address(this).call(_relayMessage);
        /* solhint-enable avoid-low-level-calls */
        require(success, VerificationFailed());
        // 32 bytes hash + 3 bytes reward epoch id.
        // RLY-07 (deferred, Note, no exploit): the 35-byte length is the unique discriminator of relay()'s
        // protocolId==1 path (all other paths return 0 bytes or revert). Preserve this invariant if relay()'s
        // returns change. A robust typed protocol discriminator would need an assembly return-format change
        // (higher risk for a no-exploit note), so it is deferred by decision. See docs/relay-fixes.md.
        require(returnData.length == 35, WrongVerificationData());
        bytes32 returnHash;
        uint256 returnRewardEpochId;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            returnHash := mload(add(returnData, 0x20))
            returnRewardEpochId := shr(sub(256, mul(8, REWARD_EPOCH_ID_BYTES)), mload(add(returnData, 0x40)))
        }
        require(bytes32(returnHash) == _messageHash, InvalidConfigHash());
        return returnRewardEpochId;
    }
}
