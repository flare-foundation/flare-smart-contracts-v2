// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IIRelay} from "../interface/IIRelay.sol";
import {IRelay} from "../../userInterfaces/IRelay.sol";
// solhint-disable-next-line no-unused-import
import {RandomNumberV2Interface} from "../../userInterfaces/LTS/RandomNumberV2Interface.sol";
import {IRelayGovernance} from "../../userInterfaces/IRelayGovernance.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {GSSGovernance} from "../../governance/GSSGovernance.sol";
import {GnosisSafeTx} from "../../governance/GnosisSafeTx.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * Relay (finalization) contract.
 */
contract Relay is IIRelay, IRelayGovernance {
    using MerkleProof for bytes32[];
    using ECDSA for bytes32;

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

    struct GovernanceFeeUpdate {
        uint256 targetChainId;
        uint256 protocolId;
        uint256 feeInWei;
    }

    uint256 private constant THRESHOLD_BIPS = 10000;
    uint256 private constant SELECTOR_BYTES = 4;
    uint256 private constant MAX_VOTERS = 300;
    uint256 private constant MIN_THRESHOLD_BIPS = 5000;
    uint256 private constant MAX_THRESHOLD_BIPS = 6600;

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

    uint256 public immutable override governanceSourceChainId;
    address public immutable override governanceSafe;
    uint256 public immutable override governanceReplayFloor;
    bytes32 public override activeOwnerConfigHash;
    uint256 public override activeOwnerConfigSafeNonce;
    uint256 public override lastGovernanceSafeNonce;
    uint256 public override governanceThreshold;
    address[] private governanceOwners;
    mapping(uint256 safeNonce => bool) public override governanceSafeNonceConsumed;
    uint256 private constant MAX_GOVERNANCE_OWNERS = 256;
    uint256 private constant MAX_GOVERNANCE_FEE_UPDATES = 256;

    bytes4 private constant CHANGE_OWNERS_SELECTOR =
        bytes4(keccak256("changeOwners(uint256,bytes32,uint256,address[])"));
    bytes4 private constant CHANGE_PROTOCOL_FEES_SELECTOR =
        bytes4(keccak256("changeProtocolFees(uint256,bytes32,(uint256,uint256,uint256)[])"));

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
    IRelay public immutable oldRelay;
    /// The initial reward epoch id.
    uint32 public immutable initialRewardEpochId;
    /// The starting voting round id for the initial
    uint32 public immutable startingVotingRoundIdForInitialRewardEpochId;

    /// Only signingPolicySetter address/contract can call this method.
    modifier onlySigningPolicySetter() {
        require(msg.sender == signingPolicySetter, "only sign policy setter");
        _;
    }

    /**
     * Constructor.
     * @param _initialConfig The initial configuration of the relay.
     * @param _signingPolicySetter The address of the signing policy setter.
     * @param _oldRelay The old relay contract (can be address(0)).
     */
    constructor(RelayInitialConfig memory _initialConfig, address _signingPolicySetter, IRelay _oldRelay) {
        require(_initialConfig.thresholdIncreaseBIPS >= THRESHOLD_BIPS, "threshold increase too small");
        // RLY-11: reject zero epoch durations (would cause div-by-zero / silent-zero in epoch math).
        require(_initialConfig.rewardEpochDurationInVotingEpochs > 0, "reward epoch duration zero");
        require(_initialConfig.votingEpochDurationSeconds > 0, "voting epoch duration zero");
        // L-4: a zero initial signing-policy hash would brick the initial epoch (no relay message could match).
        // RLY-23: the supplied hash must already be chain-bound — keccak256(chainid ‖ contentHash) for THIS
        // chain — matching what relay()/setSigningPolicy store and verify. A content hash (or a hash bound to
        // another chain) fails closed: no relay message can ever match it. Deploy scripts wrap on migration.
        require(_initialConfig.initialSigningPolicyHash != bytes32(0), "initial signing policy hash zero");
        require(
            _initialConfig.firstRewardEpochStartVotingRoundId + _initialConfig.initialRewardEpochId
                    * _initialConfig.rewardEpochDurationInVotingEpochs
                <= _initialConfig.startingVotingRoundIdForInitialRewardEpochId,
            "invalid initial starting voting round id"
        );
        initialRewardEpochId = _initialConfig.initialRewardEpochId;
        startingVotingRoundIdForInitialRewardEpochId = _initialConfig.startingVotingRoundIdForInitialRewardEpochId;
        signingPolicySetter = _signingPolicySetter;
        // Migration handshake: lastInitializedRewardEpoch is seeded to initialRewardEpochId, and setSigningPolicy
        // strictly requires the next call to be exactly initialRewardEpochId + 1 ("not next reward epoch"). The
        // deployer (redeploy-relay.ts) must therefore cut over so the trusted setter's next policy is that epoch;
        // a zero next-epoch policy hash on the old relay is fail-closed by the L-4 require above.
        stateData.lastInitializedRewardEpoch = _initialConfig.initialRewardEpochId;
        startingVotingRoundIds[_initialConfig.initialRewardEpochId] =
        _initialConfig.startingVotingRoundIdForInitialRewardEpochId;
        toSigningPolicyHashPrivate[_initialConfig.initialRewardEpochId] = _initialConfig.initialSigningPolicyHash;
        require(_initialConfig.randomNumberProtocolId > 1, "random number protocol id must be > 1");
        stateData.randomNumberProtocolId = _initialConfig.randomNumberProtocolId;
        stateData.firstVotingRoundStartTs = _initialConfig.firstVotingRoundStartTs;
        stateData.votingEpochDurationSeconds = _initialConfig.votingEpochDurationSeconds;
        stateData.firstRewardEpochStartVotingRoundId = _initialConfig.firstRewardEpochStartVotingRoundId;
        stateData.rewardEpochDurationInVotingEpochs = _initialConfig.rewardEpochDurationInVotingEpochs;
        stateData.thresholdIncreaseBIPS = _initialConfig.thresholdIncreaseBIPS;
        stateData.messageFinalizationWindowInRewardEpochs = _initialConfig.messageFinalizationWindowInRewardEpochs;
        if (_signingPolicySetter != address(0)) {
            require(_initialConfig.feeConfigs.length == 0, "fee cannot be set");
            stateData.noSigningPolicyRelay = true;
        }
        feeCollectionAddress = _initialConfig.feeCollectionAddress;
        // In relay mode a zero fee-collection address would burn collected fees, so reject it.
        require(
            _signingPolicySetter != address(0) || _initialConfig.feeCollectionAddress != address(0),
            "fee collection address zero"
        );
        for (uint256 i = 0; i < _initialConfig.feeConfigs.length; i++) {
            uint8 protocolId = _initialConfig.feeConfigs[i].protocolId;
            require(protocolId > 1, "invalid protocol id");
            protocolFeeInWei[protocolId] = _initialConfig.feeConfigs[i].feeInWei;
        }
        governanceSourceChainId = _initialConfig.governanceSourceChainId;
        governanceSafe = _initialConfig.governanceSafe;
        governanceThreshold = _initialConfig.governanceThreshold;
        activeOwnerConfigSafeNonce = _initialConfig.governanceOwnerConfigSafeNonce;
        lastGovernanceSafeNonce = _initialConfig.governanceSafeNonce;
        governanceReplayFloor = _initialConfig.governanceSafeNonce;
        bool hasGovernanceConfiguration = governanceSourceChainId != 0 || governanceSafe != address(0)
            || governanceThreshold != 0 || _initialConfig.governanceOwners.length != 0
            || activeOwnerConfigSafeNonce != 0 || lastGovernanceSafeNonce != 0;
        if (hasGovernanceConfiguration) {
            // The Safe exists on the source chain, so target-chain deployment cannot inspect its code.
            if (governanceSourceChainId == 0 || governanceSafe == address(0)) {
                revert InvalidGovernanceSource();
            }
            if (_signingPolicySetter != address(0) || _oldRelay != IRelay(address(0))) {
                revert InvalidGovernanceDeployment();
            }
            if (_initialConfig.governanceOwners.length > MAX_GOVERNANCE_OWNERS) {
                revert InvalidGovernanceOwnerConfiguration();
            }
            if (activeOwnerConfigSafeNonce > governanceReplayFloor) {
                revert InvalidGovernanceOwnerConfiguration();
            }
            _validateGovernanceOwners(_initialConfig.governanceOwners, governanceThreshold);
            for (uint256 i; i < _initialConfig.governanceOwners.length; ++i) {
                governanceOwners.push(_initialConfig.governanceOwners[i]);
            }
            activeOwnerConfigHash =
                _governanceOwnerConfigHash(activeOwnerConfigSafeNonce, governanceThreshold, governanceOwners);
            emit GovernanceInitialized(
                activeOwnerConfigHash,
                activeOwnerConfigSafeNonce,
                governanceReplayFloor,
                governanceThreshold,
                governanceOwners
            );
        }
        oldRelay = _oldRelay;
        // new relay must be deployed in a compatible way (policy setter or not)
        if (oldRelay != IIRelay(address(0))) {
            require(
                (signingPolicySetter != address(0) && oldRelay.signingPolicySetter() != address(0))
                    || (signingPolicySetter == address(0) && oldRelay.signingPolicySetter() == address(0)),
                "old relay incompatible"
            );
            (
                ,
                uint32 firstVotingRoundStartTs,
                uint8 votingEpochDurationSeconds,
                uint32 firstRewardEpochStartVotingRoundId,
                uint16 rewardEpochDurationInVotingEpochs,,,,,,
            ) = oldRelay.stateData();
            require(stateData.firstVotingRoundStartTs == firstVotingRoundStartTs, "wrong start ts");
            require(
                stateData.rewardEpochDurationInVotingEpochs == rewardEpochDurationInVotingEpochs,
                "wrong reward epoch duration"
            );
            require(
                stateData.firstRewardEpochStartVotingRoundId == firstRewardEpochStartVotingRoundId,
                "wrong first reward epoch start"
            );
            require(stateData.votingEpochDurationSeconds == votingEpochDurationSeconds, "wrong voting epoch duration");
        }
    }

    /**
     * @inheritdoc IIRelay
     */
    function setSigningPolicy(
        // using memory instead of calldata as called from another contract where signing policy is already in memory
        SigningPolicy memory _signingPolicy
    )
        external
        onlySigningPolicySetter
        returns (bytes32)
    {
        // RLY-06: the signing policy setter (trusted; FlareSystemsManager on Flare) is responsible for
        // ensuring the policy is well-formed — no zero-address voters, no duplicate voters, canonical
        // voter order, normalised weights. These are intentionally NOT re-validated here.
        require(stateData.lastInitializedRewardEpoch + 1 == _signingPolicy.rewardEpochId, "not next reward epoch");
        // L-6 (documented, not enforced): the reward-epoch decision matrix (see the relay() gate that reads
        // startingVotingRoundIds[rewardEpochId + 1]) assumes a non-decreasing startVotingRoundId across epochs.
        // Like RLY-06, this canonical-ordering invariant is the trusted signing-policy setter's
        // (FlareSystemsManager) responsibility and is intentionally NOT re-checked here — an on-chain require
        // conflicts with legitimate setter-driven configurations. On pure-relay deployments (this setter is
        // unused) startingVotingRoundIds is instead written by the Mode-1 relay() path from the relayed policy
        // metadata; there the invariant is carried transitively by the voter quorum's signature over the
        // signing-policy hash (a faithfully-relayed canonical policy preserves it).
        require(_signingPolicy.voters.length > 0, "must be non-trivial");
        require(_signingPolicy.voters.length <= MAX_VOTERS, "too many voters");
        require(_signingPolicy.voters.length == _signingPolicy.weights.length, "size mismatch");
        uint256 totalWeight = 0;
        for (uint256 i = 0; i < _signingPolicy.weights.length; i++) {
            totalWeight += _signingPolicy.weights[i];
        }
        require(totalWeight < 2 ** 16, "total weight too big");
        require(
            uint256(_signingPolicy.threshold) * uint256(THRESHOLD_BIPS) >= totalWeight * MIN_THRESHOLD_BIPS,
            "too small threshold"
        );
        require(
            uint256(_signingPolicy.threshold) * uint256(THRESHOLD_BIPS) <= totalWeight * MAX_THRESHOLD_BIPS,
            "too big threshold"
        );

        bytes memory signingPolicyBytes =
            new bytes(SIGNING_POLICY_PREFIX_BYTES + _signingPolicy.voters.length * ADDRESS_AND_WEIGHT_BYTES);

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
            while (m.count < 32 && m.weightIndex < _signingPolicy.voters.length) {
                if (m.weightIndex < m.voterIndex) {
                    m.bytesToTake = 2 - m.weightPos;
                    m.pos = m.weightPos;
                    bytes32 weightData = bytes32(uint256(uint16(_signingPolicy.weights[m.weightIndex])) << (30 * 8));
                    if (m.count + m.bytesToTake > 32) {
                        m.bytesToTake = 32 - m.count;
                        m.weightPos += m.bytesToTake;
                    } else {
                        m.weightPos = 0;
                        m.weightIndex++;
                    }
                    m.nextSlot |= bytes32(((weightData << (8 * m.pos)) >> (8 * m.count)));
                } else {
                    m.bytesToTake = 20 - m.voterPos;
                    m.pos = m.voterPos;
                    bytes32 voterData = bytes32(uint256(uint160(_signingPolicy.voters[m.voterIndex])) << (12 * 8));
                    if (m.count + m.bytesToTake > 32) {
                        m.bytesToTake = 32 - m.count;
                        m.voterPos += m.bytesToTake;
                    } else {
                        m.voterPos = 0;
                        m.voterIndex++;
                    }
                    m.nextSlot |= bytes32(((voterData << (8 * m.pos)) >> (8 * m.count)));
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
        // RLY-23: chain-domain binding — the stored signing-policy hash commits to this
        // chain: keccak256(block.chainid ‖ contentHash). Signatures over policies (and, via the
        // analogous wrap in relay(), over protocol messages) minted for another network are
        // thereby rejected even under a fully overlapping voter set.
        currentHash = keccak256(abi.encodePacked(block.chainid, currentHash));
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
    function verifyCustomSignature(bytes calldata _relayMessage, bytes32 _messageHash)
        external
        returns (uint256 _rewardEpochId)
    {
        return _verifyCustomSignature(_relayMessage, _messageHash);
    }

    /// @notice Verifies a Safe transaction signed for the Flare source chain and applies its local fee updates.
    /// @dev The source-chain target is covered by the Safe digest but is not part of Relay authorization.
    /// Acceptance proves threshold authorization, not that the source-chain transaction was executed.
    function processGSSMessage(GnosisSafeTx.Transaction calldata txData, bytes calldata signatures) external override {
        if (governanceSafe == address(0) || txData.operation != 0 || txData.value != 0) {
            revert InvalidGovernanceTransaction();
        }
        _verifyGovernanceSignatures(txData, signatures);
        _processVerifiedGovernanceAction(txData.data, txData.nonce);
    }

    /// @dev Applies an action after the enclosing Safe transaction and signer set have been verified.
    /// Kept separate so the state machine can be proved independently of the ECDSA precompile model.
    function _processVerifiedGovernanceAction(bytes calldata action, uint256 safeTxNonce) internal {
        bytes4 selector = _governanceSelector(action);
        uint256 actionNonce = _governanceActionNonce(action);
        if (safeTxNonce == type(uint256).max || actionNonce != safeTxNonce + 1) {
            revert InvalidGovernanceTransaction();
        }
        if (actionNonce <= governanceReplayFloor) {
            revert GovernanceNonceBeforeReplayFloor(actionNonce, governanceReplayFloor);
        }
        if (governanceSafeNonceConsumed[actionNonce]) {
            revert GovernanceNonceAlreadyConsumed(actionNonce);
        }
        if (selector == CHANGE_OWNERS_SELECTOR) {
            if (actionNonce <= activeOwnerConfigSafeNonce) {
                revert GovernanceOwnerConfigNonceNotIncreasing(actionNonce, activeOwnerConfigSafeNonce);
            }
            _applyGovernanceOwners(action);
            governanceSafeNonceConsumed[actionNonce] = true;
            if (actionNonce > lastGovernanceSafeNonce) {
                lastGovernanceSafeNonce = actionNonce;
            }
        } else if (selector == CHANGE_PROTOCOL_FEES_SELECTOR) {
            if (actionNonce <= lastGovernanceSafeNonce) {
                revert GovernanceNonceNotMonotonic(actionNonce, lastGovernanceSafeNonce);
            }
            if (_applyGovernanceFees(action)) {
                governanceSafeNonceConsumed[actionNonce] = true;
                lastGovernanceSafeNonce = actionNonce;
            }
        } else {
            revert UnknownGovernanceAction(selector);
        }
    }

    function governanceOwnersLength() external view override returns (uint256) {
        return governanceOwners.length;
    }

    function governanceOwner(uint256 index) external view override returns (address) {
        return governanceOwners[index];
    }

    function _verifyGovernanceSignatures(GnosisSafeTx.Transaction calldata txData, bytes calldata signatures)
        internal
        view
    {
        uint256 count = signatures.length / 65;
        if (
            signatures.length == 0 || signatures.length % 65 != 0 || count < governanceThreshold
                || count > governanceOwners.length
        ) {
            revert InvalidGovernanceSignatures();
        }
        bytes32 digest = GnosisSafeTx.digest(_copyGovernanceTx(txData), governanceSourceChainId, governanceSafe);
        address[] memory signers = new address[](count);
        for (uint256 i; i < count; ++i) {
            (address signer, ECDSA.RecoverError recoverError,) = digest.tryRecover(signatures[i * 65:(i + 1) * 65]);
            if (recoverError != ECDSA.RecoverError.NoError || signer == address(0)) {
                revert InvalidGovernanceSignatures();
            }
            signers[i] = signer;
        }
        _validateGovernanceSigners(signers);
    }

    function _validateGovernanceSigners(address[] memory signers) internal view {
        if (signers.length == 0 || signers.length < governanceThreshold || signers.length > governanceOwners.length) {
            revert InvalidGovernanceSignatures();
        }
        address previous;
        for (uint256 i; i < signers.length; ++i) {
            address signer = signers[i];
            if (signer == address(0) || (i > 0 && signer <= previous) || !_isGovernanceOwner(signer)) {
                revert InvalidGovernanceSignatures();
            }
            previous = signer;
        }
    }

    function _copyGovernanceTx(GnosisSafeTx.Transaction calldata source)
        internal
        pure
        returns (GnosisSafeTx.Transaction memory target)
    {
        target = GnosisSafeTx.Transaction(
            source.to,
            source.value,
            source.data,
            source.operation,
            source.safeTxGas,
            source.baseGas,
            source.gasPrice,
            source.gasToken,
            source.refundReceiver,
            source.nonce
        );
    }

    // solhint-disable-next-line ordering
    function _applyGovernanceOwners(bytes calldata action) internal {
        (uint256 nonce, bytes32 currentHash, uint256 threshold, address[] memory owners) =
            abi.decode(action[4:], (uint256, bytes32, uint256, address[]));
        if (
            keccak256(action)
                != keccak256(abi.encodeWithSelector(CHANGE_OWNERS_SELECTOR, nonce, currentHash, threshold, owners))
        ) revert InvalidGovernanceTransaction();
        if (currentHash != activeOwnerConfigHash) {
            revert GovernanceOwnerHashMismatch(currentHash, activeOwnerConfigHash);
        }
        if (owners.length > MAX_GOVERNANCE_OWNERS) revert InvalidGovernanceOwnerConfiguration();
        _validateGovernanceOwners(owners, threshold);
        bytes32 previous = activeOwnerConfigHash;
        bytes32 next = _governanceOwnerConfigHash(nonce, threshold, owners);
        delete governanceOwners;
        for (uint256 i; i < owners.length; ++i) {
            governanceOwners.push(owners[i]);
        }
        governanceThreshold = threshold;
        activeOwnerConfigSafeNonce = nonce;
        activeOwnerConfigHash = next;
        emit GovernanceOwnerConfigUpdated(previous, next, nonce, threshold, owners);
    }

    function _applyGovernanceFees(bytes calldata action) internal returns (bool relevant) {
        (uint256 nonce, bytes32 configHash, GovernanceFeeUpdate[] memory updates) =
            abi.decode(action[4:], (uint256, bytes32, GovernanceFeeUpdate[]));
        if (
            keccak256(action)
                != keccak256(abi.encodeWithSelector(CHANGE_PROTOCOL_FEES_SELECTOR, nonce, configHash, updates))
        ) revert InvalidGovernanceTransaction();
        if (configHash != activeOwnerConfigHash) revert GovernanceOwnerHashMismatch(configHash, activeOwnerConfigHash);
        if (updates.length == 0 || updates.length > MAX_GOVERNANCE_FEE_UPDATES) {
            revert InvalidGovernanceTransaction();
        }
        for (uint256 i; i < updates.length; ++i) {
            GovernanceFeeUpdate memory update = updates[i];
            if (update.targetChainId == 0 || update.protocolId <= 1) {
                revert InvalidGovernanceTransaction();
            }
            if (i > 0) {
                GovernanceFeeUpdate memory previous = updates[i - 1];
                if (
                    update.targetChainId < previous.targetChainId
                        || (update.targetChainId == previous.targetChainId && update.protocolId <= previous.protocolId)
                ) {
                    revert InvalidGovernanceTransaction();
                }
            }
            if (update.targetChainId == block.chainid) relevant = true;
        }
        if (!relevant) return false;
        for (uint256 i; i < updates.length; ++i) {
            if (updates[i].targetChainId != block.chainid) continue;
            protocolFeeInWei[updates[i].protocolId] = updates[i].feeInWei;
            emit GovernanceFeeUpdated(block.chainid, updates[i].protocolId, updates[i].feeInWei, nonce, configHash);
        }
    }

    function _governanceSelector(bytes calldata data) internal pure returns (bytes4 selector) {
        if (data.length < 4) revert InvalidGovernanceTransaction();
        selector = bytes4(data[:4]);
    }

    function _governanceActionNonce(bytes calldata data) internal pure returns (uint256 actionNonce) {
        if (data.length < 36) revert InvalidGovernanceTransaction();
        actionNonce = abi.decode(data[4:36], (uint256));
    }

    function _isGovernanceOwner(address account) internal view returns (bool) {
        uint256 low;
        uint256 high = governanceOwners.length;
        while (low < high) {
            uint256 middle = (low + high) / 2;
            address candidate = governanceOwners[middle];
            if (candidate < account) {
                low = middle + 1;
            } else {
                high = middle;
            }
        }
        if (low < governanceOwners.length && governanceOwners[low] == account) return true;
        return false;
    }

    function _validateGovernanceOwners(address[] memory owners, uint256 threshold) internal pure {
        if (owners.length == 0 || threshold == 0 || threshold > owners.length) {
            revert InvalidGovernanceOwnerConfiguration();
        }
        for (uint256 i; i < owners.length; ++i) {
            if (owners[i] == address(0) || (i > 0 && owners[i - 1] >= owners[i])) {
                revert InvalidGovernanceOwnerConfiguration();
            }
        }
    }

    function _governanceOwnerConfigHash(uint256 ownerConfigSafeNonce, uint256 threshold, address[] memory owners)
        internal
        view
        returns (bytes32)
    {
        return
            GSSGovernance.ownerConfigHash(
                governanceSourceChainId, governanceSafe, ownerConfigSafeNonce, threshold, owners
            );
    }

    /**
     * @inheritdoc IRelay
     */
    function relay() external returns (bytes memory) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // Helper function to revert with a message
            // Since string length cannot be determined in assembly easily, the matching length
            // of the message string must be provided.
            function revertWithMessage(_memPtr, _message, _msgLength) {
                mstore(_memPtr, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                mstore(add(_memPtr, 0x04), 0x20) // String offset
                mstore(add(_memPtr, 0x24), _msgLength) // Revert reason length
                mstore(add(_memPtr, 0x44), _message)
                revert(_memPtr, 0x64) // Revert data length is 4 bytes for selector and 3 slots of 0x20 bytes
            }

            function assignStruct(_structObj, _valOffset, _valMask, newVal) -> _newStructObj {
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
            function rewardEpochIdFromVotingRoundId(_stateDataObj, _votingRoundId) -> _rewardEpochId {
                let firstRewardEpochStartVotingRoundId :=
                    structValue(
                        _stateDataObj,
                        SD_BOFF_firstRewardEpochStartVotingRoundId,
                        SD_MASK_firstRewardEpochStartVotingRoundId
                    )
                if lt(_votingRoundId, firstRewardEpochStartVotingRoundId) {
                    revertWithMessage(mload(0x40), "Invalid voting round id", 23)
                }
                _rewardEpochId := div(
                    sub(_votingRoundId, firstRewardEpochStartVotingRoundId),
                    structValue(
                        _stateDataObj,
                        SD_BOFF_rewardEpochDurationInVotingEpochs,
                        SD_MASK_rewardEpochDurationInVotingEpochs
                    )
                )
            }

            // Helper function to calculate the signing policy hash while trying to minimize the usage of memory
            // Uses slots 0 and 32
            function calculateSigningPolicyHash(_memPos, _calldataPos, _policyLength) -> _policyHash {
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
                // RLY-23: chain-domain binding — the signing-policy hash commits to this
                // chain: keccak256(chainid ‖ contentHash). Reuses the two scratch slots
                // this function already owns. Runtime chainid() (not a deploy-time value)
                // so a chain-id-changing fork fails closed.
                mstore(_memPos, chainid())
                mstore(add(_memPos, M_1), _policyHash)
                _policyHash := keccak256(_memPos, 64)
            }

            function extractVotingRoundIdFromMessage(_memPtr, _signingPolicyLength) -> _votingRoundId {
                calldatacopy(_memPtr, add(SELECTOR_BYTES, _signingPolicyLength), MESSAGE_NO_MR_BYTES)

                _votingRoundId := structValue(
                    shr(sub(256, mul(8, MESSAGE_NO_MR_BYTES)), mload(_memPtr)),
                    MSG_NMR_BOFF_votingRoundId,
                    MSG_NMR_MASK_votingRoundId
                )
            }

            function checkThresholdConsistency(_memPtr, _metadata, _signingPolicyStart) {
                let totalWeight := 0
                for {
                    let i := 0
                    let offset := add(add(_signingPolicyStart, SIGNING_POLICY_PREFIX_BYTES), ADDRESS_BYTES)
                    let numberOfVoters := structValue(_metadata, MD_BOFF_numberOfVoters, MD_MASK_numberOfVoters)
                } lt(i, numberOfVoters) {
                    i := add(i, 1)
                } {
                    // clear the memory slot
                    mstore(_memPtr, 0)
                    // copy the weight to the rightmost WEIGHT_BYTES
                    calldatacopy(
                        add(_memPtr, sub(32, WEIGHT_BYTES)),
                        add(offset, mul(i, ADDRESS_AND_WEIGHT_BYTES)),
                        WEIGHT_BYTES
                    )
                    // add to the total weight
                    totalWeight := add(totalWeight, mload(_memPtr))
                }
                if gt(totalWeight, sub(shl(16, 1), 1)) {
                    // totalWeight > 2 ** 16 - 1
                    revertWithMessage(_memPtr, "total weight too big", 20)
                }
                let threshold := structValue(_metadata, MD_BOFF_threshold, MD_MASK_threshold)
                if lt(mul(threshold, THRESHOLD_BIPS), mul(totalWeight, MIN_THRESHOLD_BIPS)) {
                    revertWithMessage(_memPtr, "too small threshold", 19)
                }
                if gt(mul(threshold, THRESHOLD_BIPS), mul(totalWeight, MAX_THRESHOLD_BIPS)) {
                    revertWithMessage(_memPtr, "too big threshold", 17)
                }
            }

            function setIsSecureRandomBit(_memPtr, _votingRoundId) {
                //  isSecureRandomMap[_votingRoundId / 256]
                mstore(_memPtr, div(_votingRoundId, 256)) // key (_votingRoundId / 256)
                mstore(add(_memPtr, 32), isSecureRandomMap.slot)

                sstore(
                    keccak256(_memPtr, 64),
                    or(sload(keccak256(_memPtr, 64)), shl(sub(255, mod(_votingRoundId, 256)), 1))
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
                _memPtr,
                _proofStart,
                _memPtrMerkleRoot,
                _votingRoundId,
                _isSecureRandom
            ) {
                // calldata must contain at least the 32-byte random number after the signatures
                if lt(calldatasize(), add(_proofStart, 32)) {
                    revertWithMessage(_memPtr, "No random number", 16)
                }
                // the trailing calldata (random number + proof) must be a whole number of 32-byte words
                if iszero(eq(mod(sub(calldatasize(), _proofStart), 32), 0)) {
                    revertWithMessage(_memPtr, "Incorrect merkle proof", 22)
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
                    revertWithMessage(_memPtr, "Invalid random number proof", 27)
                }
                // toRandomNumberPrivate[_votingRoundId] = randomNumber
                calldatacopy(add(_memPtr, 64), _proofStart, 32) // reload value (slots 0/32 reused as map key/slot)
                mstore(_memPtr, _votingRoundId)
                mstore(add(_memPtr, 32), toRandomNumberPrivate.slot)
                sstore(keccak256(_memPtr, 64), mload(add(_memPtr, 64)))
            }
            ////////////// A comment on handling of signing policy and a message //////////////////////////////
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
            // ------------------------------------------------------------------------------------------------
            //     exp(v) == r | v >= s    OK
            //                 | v < s     REVERT
            // ------------------------------------------------------------------------------------------------
            //     exp(v) > r  |  v < s    REVERT
            //                 -------------------------------------------------------------------------------
            //                 |  v >= s            |  i = r        OK (increase threshold)
            //                 |                    -----------------------------------------------------------
            //                 |                    |  i > r      | v >= s+
            //                 |                    |             |              REVERT (new policy must be used)
            //                 |                    |             | v < s+        OK
            //
            ////////////// Start of code //////////////////////////////////////////////////////////////////////
            // free memory pointer
            let memPtr := mload(0x40)
            // NOTE: the struct is packed in reverse order of bytes

            // stateData loaded into memory to slot M_5_stateData
            mstore(add(memPtr, M_5_stateData), sload(stateData.slot))

            ///////////// Extracting signing policy metadata /////////////
            if lt(calldatasize(), add(SELECTOR_BYTES, METADATA_BYTES)) {
                revertWithMessage(memPtr, "Invalid sign policy metadata", 28)
            }

            calldatacopy(memPtr, SELECTOR_BYTES, METADATA_BYTES)
            // shift to right of bytes32
            let metadata := shr(sub(256, mul(8, METADATA_BYTES)), mload(memPtr))
            let rewardEpochId := structValue(metadata, MD_BOFF_rewardEpochId, MD_MASK_rewardEpochId)

            let signingPolicyLength :=
                add(
                    SIGNING_POLICY_PREFIX_BYTES,
                    mul(
                        structValue(metadata, MD_BOFF_numberOfVoters, MD_MASK_numberOfVoters),
                        ADDRESS_AND_WEIGHT_BYTES
                    )
                )

            // The calldata must be of length at least 4 function selector + signingPolicyLength + 1 protocolId
            if lt(calldatasize(), add(SELECTOR_BYTES, add(signingPolicyLength, PROTOCOL_ID_BYTES))) {
                revertWithMessage(memPtr, "Invalid sign policy length", 26)
            }

            ///////////// Verifying signing policy /////////////
            // signing policy hash temporarily stored to slot M_2
            mstore(
                add(memPtr, M_2_signingPolicyHashTmp),
                calculateSigningPolicyHash(memPtr, SELECTOR_BYTES, signingPolicyLength)
            )

            //  toSigningPolicyHashPrivate[rewardEpochId] -> existingSigningPolicyHash
            mstore(memPtr, rewardEpochId) // key (rewardEpochId)
            mstore(add(memPtr, M_1), toSigningPolicyHashPrivate.slot)

            // store existing signing policy hash to slot M_3 temporarily
            mstore(add(memPtr, M_3_existingSigningPolicyHashTmp), sload(keccak256(memPtr, 64)))

            // From here on we have calldatasize() > 4 + signingPolicyLength

            ///////////// Verifying signing policy /////////////
            if iszero(
                eq(mload(add(memPtr, M_2_signingPolicyHashTmp)), mload(add(memPtr, M_3_existingSigningPolicyHashTmp)))
            ) {
                revertWithMessage(memPtr, "Signing policy hash mismatch", 28)
            }

            // Extracting protocolId, votingRoundId and isSecureRandom
            // 1 bytes - protocolId
            // 4 bytes - votingRoundId
            // 1 bytes - isSecureRandom
            // 32 bytes - merkleRoot
            // message length: 38

            calldatacopy(memPtr, add(SELECTOR_BYTES, signingPolicyLength), PROTOCOL_ID_BYTES)

            let protocolId :=
                shr(
                    sub(256, mul(8, PROTOCOL_ID_BYTES)), // move to the rightmost position
                    mload(memPtr)
                )

            let signatureStart := 0 // First index of signatures in calldata
            let threshold := structValue(metadata, MD_BOFF_threshold, MD_MASK_threshold)

            ///////////// Preparation of message hash /////////////
            // protocolId > 0 means we are relaying or checking the validity of signatures (Mode 2)
            // The signed hash is the message hash and it gets prepared into slot 32
            if gt(protocolId, 0) {
                let memPtrGP0 := mload(0x40)
                signatureStart := add(SELECTOR_BYTES, add(signingPolicyLength, MESSAGE_BYTES))
                if lt(calldatasize(), signatureStart) {
                    revertWithMessage(memPtrGP0, "Too short message", 17)
                }

                calldatacopy(memPtrGP0, add(SELECTOR_BYTES, signingPolicyLength), MESSAGE_BYTES)

                let votingRoundId :=
                    structValue(
                        shr(sub(256, mul(8, MESSAGE_NO_MR_BYTES)), mload(memPtrGP0)),
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
                    revertWithMessage(memPtrGP0, "Already relayed", 15)
                }

                if eq(protocolId, 1) {
                    // both votingRoundId and isSecureRandom should be 0
                    if votingRoundId {
                        revertWithMessage(memPtrGP0, "Wrong message format", 20)
                    }

                    if structValue( // isSecureRandom should be 0
                        shr(sub(256, mul(8, MESSAGE_NO_MR_BYTES)), mload(memPtrGP0)),
                        MSG_NMR_BOFF_isSecureRandom,
                        MSG_NMR_MASK_isSecureRandom
                    ) {
                        revertWithMessage(memPtrGP0, "Wrong message format2", 21)
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
                    revertWithMessage(memPtrGP0, "Wrong sign policy reward epoch", 30)
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
                ) {
                    revertWithMessage(memPtrGP0, "Message too old", 15)
                }

                let startingVotingRoundId :=
                    structValue(metadata, MD_BOFF_startingVotingRoundId, MD_MASK_startingVotingRoundId)
                // in case the reward epoch id start gets delayed -> signing policy for earlier
                // reward epoch must be provided
                if and(iszero(eq(protocolId, 1)), lt(votingRoundId, startingVotingRoundId)) {
                    revertWithMessage(memPtrGP0, "Delayed sign policy", 19)
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
                            revertWithMessage(memPtrGP0, "Must use new sign policy", 24)
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
                // RLY-23: chain-domain binding — the signed digest commits to this chain:
                // M_1 <- keccak256(chainid ‖ keccak256(message)). Slot M_0 (the spent
                // message bytes) is safe to reuse as scratch: this is the last statement
                // of the block and the accept path re-reads the message from calldata.
                mstore(memPtrGP0, chainid())
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
                    revertWithMessage(mload(0x40), "Sign policy relay disabled", 26)
                }

                if lt(
                    calldatasize(),
                    add(SELECTOR_BYTES, add(signingPolicyLength, add(PROTOCOL_ID_BYTES, METADATA_BYTES)))
                ) {
                    revertWithMessage(mload(0x40), "No new sign policy size", 23)
                }

                // New metadata
                calldatacopy(
                    mload(0x40),
                    add(SELECTOR_BYTES, add(PROTOCOL_ID_BYTES, signingPolicyLength)),
                    METADATA_BYTES
                )

                let newMetadata := shr(sub(256, mul(8, METADATA_BYTES)), mload(mload(0x40)))
                let newNumberOfVoters := structValue(newMetadata, MD_BOFF_numberOfVoters, MD_MASK_numberOfVoters)
                // must be at least one voter
                if eq(newNumberOfVoters, 0) {
                    revertWithMessage(mload(0x40), "must be non-trivial", 19)
                }
                // must be at most MAX_VOTERS
                if gt(newNumberOfVoters, MAX_VOTERS) {
                    revertWithMessage(mload(0x40), "too many voters", 15)
                }

                let newSigningPolicyLength :=
                    add(SIGNING_POLICY_PREFIX_BYTES, mul(newNumberOfVoters, ADDRESS_AND_WEIGHT_BYTES))

                signatureStart := add(
                    SELECTOR_BYTES,
                    add(signingPolicyLength, add(PROTOCOL_ID_BYTES, newSigningPolicyLength))
                )

                if lt(calldatasize(), signatureStart) {
                    revertWithMessage(mload(0x40), "Wrong size for new sign policy", 30)
                }

                let newSigningPolicyRewardEpochId :=
                    structValue(newMetadata, MD_BOFF_rewardEpochId, MD_MASK_rewardEpochId)

                let tmpLastInitializedRewardEpochId :=
                    structValue(
                        mload(add(mload(0x40), M_5_stateData)),
                        SD_BOFF_lastInitializedRewardEpoch,
                        SD_MASK_lastInitializedRewardEpoch
                    )

                // should the old signing policy reward epoch id be the last intialized one
                if iszero(eq(tmpLastInitializedRewardEpochId, rewardEpochId)) {
                    revertWithMessage(mload(0x40), "Not with last intialized", 24)
                }

                // Should be next reward epoch id
                if iszero(eq(add(1, tmpLastInitializedRewardEpochId), newSigningPolicyRewardEpochId)) {
                    revertWithMessage(mload(0x40), "Not next reward epoch", 21)
                }

                // Check the threshold consistency
                checkThresholdConsistency(
                    mload(0x40),
                    newMetadata,
                    add(SELECTOR_BYTES, add(PROTOCOL_ID_BYTES, signingPolicyLength))
                )

                let newSigningPolicyHash :=
                    calculateSigningPolicyHash(
                        mload(0x40),
                        add(SELECTOR_BYTES, add(signingPolicyLength, PROTOCOL_ID_BYTES)),
                        newSigningPolicyLength
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
                    structValue(newMetadata, MD_BOFF_startingVotingRoundId, MD_MASK_startingVotingRoundId)
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
            if lt(calldatasize(), add(signatureStart, NUMBER_OF_SIGNATURES_BYTES)) {
                revertWithMessage(memPtr, "No signature count", 18)
            }

            calldatacopy(add(memPtr, M_2), signatureStart, NUMBER_OF_SIGNATURES_BYTES)
            let numberOfSignatures :=
                and(shr(NUMBER_OF_SIGNATURES_RIGHT_SHIFT_BITS, mload(add(memPtr, M_2))), NUMBER_OF_SIGNATURES_MASK)
            signatureStart := add(signatureStart, NUMBER_OF_SIGNATURES_BYTES)
            // RLY-03: stash signatureStart for the random-proof trailer (read deep in the random branch
            // where keeping it on the stack would risk stack-too-deep)
            mstore(add(memPtr, M_8_signatureStart), signatureStart)
            if lt(calldatasize(), add(signatureStart, mul(numberOfSignatures, SIGNATURE_WITH_INDEX_BYTES))) {
                revertWithMessage(memPtr, "Not enough signatures", 21)
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
                let numberOfVoters := structValue(metadata, MD_BOFF_numberOfVoters, MD_MASK_numberOfVoters)
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
                let index := shr(SIGNATURE_INDEX_RIGHT_SHIFT_BITS, mload(add(memPtrFor, M_4)))

                // Index sanity checks in regard to signing policy.
                // RLY-06 linkage: signing policies are NOT re-checked for zero-address/duplicate voters
                // (the trusted setter, or for relayed policies the signed policy hash, owns that). The
                // strictly-increasing index below is what carries no-double-count security regardless of
                // policy origin: a duplicate voter can be counted at most once (index must strictly
                // increase), and a zero-address "voter" cannot be matched because ecrecover never yields
                // address(0) (enforced by the returndatasize / zero-signer checks above).
                if gt(add(index, 1), numberOfVoters) {
                    revertWithMessage(memPtrFor, "Index out of range", 18)
                }

                if lt(index, nextUnusedIndex) {
                    revertWithMessage(memPtrFor, "Index out of order", 18)
                }
                nextUnusedIndex := add(index, 1)

                // RLY-16: reject non-canonical ECDSA signatures (defence-in-depth; strict index
                // ordering already neutralizes malleability double-counting). v must be 27 or 28,
                // and s must lie in the lower half of the curve order (EIP-2 low-s).
                if iszero(
                    or(eq(and(mload(add(memPtrFor, M_1)), 0xff), 27), eq(and(mload(add(memPtrFor, M_1)), 0xff), 28))
                ) {
                    revertWithMessage(memPtrFor, "Bad v", 5)
                }
                if gt(mload(add(memPtrFor, M_3)), 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
                    revertWithMessage(memPtrFor, "Bad s", 5)
                }

                // ecrecover call. Address goes to slot 64, it is 0 padded
                if iszero(staticcall(not(0), 0x01, memPtrFor, 0x80, add(memPtrFor, M_2), 32)) {
                    revertWithMessage(memPtrFor, "ecrecover error", 15)
                }
                if iszero(eq(returndatasize(), 32)) {
                    revertWithMessage(memPtrFor, "ecrecover returned bad data", 27)
                }
                // RLY-18: explicit zero-recovered-signer guard. Already implied by the returndatasize
                // check above (a successful recovery is never address(0)); kept for clarity/robustness.
                if iszero(mload(add(memPtrFor, M_2))) {
                    revertWithMessage(memPtrFor, "Zero signer", 11)
                }
                // extract expected signer address to slot no 96
                mstore(add(memPtrFor, M_3), 0) // zeroing slot for expected address

                calldatacopy(
                    add(memPtrFor, sub(add(M_3, ADDRESS_OFFSET), WEIGHT_BYTES)),
                    add(add(SELECTOR_BYTES, SIGNING_POLICY_PREFIX_BYTES), mul(index, ADDRESS_AND_WEIGHT_BYTES)),
                    ADDRESS_AND_WEIGHT_BYTES
                )

                // Check if the recovered signer is the expected signer
                if iszero(
                    eq(
                        mload(add(memPtrFor, M_2)),
                        shr(mul(8, WEIGHT_BYTES), mload(add(memPtrFor, M_3))) // keep the address only
                    )
                ) {
                    revertWithMessage(memPtrFor, "Wrong signature", 15)
                }

                weight := add(weight, and(mload(add(memPtrFor, M_3)), WEIGHT_MASK))

                if gt(weight, threshold) {
                    if eq(protocolId, 0) {
                        // Store updated stateData (lastInitializedRewardEpoch)
                        sstore(stateData.slot, mload(add(memPtrFor, M_5_stateData)))
                        // in case protocolId == 0, the new signing policy is already stored
                        // and event emitted
                        return(0, 0)
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
                            mstore(add(memPtrFor, M_1), shl(sub(256, mul(8, REWARD_EPOCH_ID_BYTES)), rewardEpochId))
                            return(memPtrFor, add(32, REWARD_EPOCH_ID_BYTES))
                        }

                        // RLY-04: reject a zero merkle root (would break isFinalized and the
                        // already-relayed sentinel, and allow repeated event spam for the round).
                        if iszero(mload(add(memPtrFor, M_6_merkleRoot))) {
                            revertWithMessage(memPtrFor, "zero merkle root", 16)
                        }

                        let votingRoundId := extractVotingRoundIdFromMessage(memPtrFor, signingPolicyLength)

                        // writing into the map
                        mstore(memPtrFor, protocolId) // key 1 (protocolId)
                        mstore(add(memPtrFor, M_1), merkleRootsPrivate.slot) // merkleRoot slot

                        // parent map location in slot for next hashing
                        mstore(add(memPtrFor, M_1), keccak256(memPtrFor, 64))
                        mstore(memPtrFor, votingRoundId) // key 2 (votingRoundId)
                        // merkleRoot stored at merkleRootsPrivate[protocolId][votingRoundId]
                        sstore(keccak256(memPtrFor, 64), mload(add(memPtrFor, M_6_merkleRoot))) // set Merkle Root

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
                            calldatacopy(memPtrFor, add(SELECTOR_BYTES, signingPolicyLength), MESSAGE_NO_MR_BYTES)
                            mstore(memPtrFor, shr(sub(256, mul(8, MESSAGE_NO_MR_BYTES)), mload(memPtrFor)))

                            // Here we setup M_5 to value of isSecureRandom from message
                            // while in M_6 we have Merkle root
                            // Note that the value of isSecureRandom outside the random
                            // generating protocol is meaningless.
                            // These two fields are used for the emitted event
                            mstore(
                                add(memPtrFor, M_5_isSecureRandom),
                                structValue(mload(memPtrFor), MSG_NMR_BOFF_isSecureRandom, MSG_NMR_MASK_isSecureRandom)
                            )
                            mstore(add(memPtrFor, M_3), "ProtocolMessageRelayed(uint8,uin")
                            mstore(add(memPtrFor, M_4), "t32,bool,bytes32)")
                            log3(
                                add(memPtrFor, M_5_isSecureRandom),
                                64,
                                keccak256(add(memPtrFor, M_3), 49),
                                protocolId,
                                votingRoundId
                            )
                            return(0, 0)
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
                            calldatacopy(memPtrFor, add(SELECTOR_BYTES, signingPolicyLength), MESSAGE_NO_MR_BYTES)
                            let isSecure :=
                                iszero(
                                    iszero(
                                        structValue(
                                            shr(sub(256, mul(8, MESSAGE_NO_MR_BYTES)), mload(memPtrFor)),
                                            MSG_NMR_BOFF_isSecureRandom,
                                            MSG_NMR_MASK_isSecureRandom
                                        )
                                    )
                                )

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
                                add(memPtrFor, M_5_isSecureRandom),
                                64,
                                keccak256(add(memPtrFor, M_3), 49),
                                protocolId,
                                votingRoundId
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
                            log2(add(memPtrFor, M_6_merkleRoot), 64, keccak256(add(memPtrFor, M_3), 40), votingRoundId)
                            return(0, 0)
                        } // if protocolId == stateData.randomNumberProtocolId
                    } // if protocolId > 0
                    // this should never happen as particular cases are handled above and returns
                    // are done from there
                    revertWithMessage(mload(0x40), "This should never happen", 24)
                }
            } // for


            // NO CODE SHOULD BE ADDED HERE
        } // assembly
        revert("Not enough weight");
    }

    /**
     * @inheritdoc IRelay
     */
    function verify(uint256 _protocolId, uint256 _votingRoundId, bytes32 _leaf, bytes32[] calldata _proof)
        external
        payable
        returns (bool)
    {
        // Read-delegation boundary: rounds below startingVotingRoundIdForInitialRewardEpochId are served by
        // the old relay (here and in merkleRoots/isFinalized/getRandomNumberHistorical/toSigningPolicyHash).
        // No new-relay write can land below this boundary (so there is no silent shadowing): the lowest stored
        // signing policy is initialRewardEpochId, and the relay() gates "Wrong sign policy reward epoch"
        // (messageRewardEpochId >= policy rewardEpochId) and "Delayed sign policy"
        // (votingRoundId >= policy startVotingRoundId) force every Mode-2 write to have
        // votingRoundId >= startingVotingRoundIdForInitialRewardEpochId. Write domain == read-delegation domain.
        if (oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId) {
            // RLY-13: fail closed if the old relay returns false (rather than reverting).
            // M-1: forward only the old relay's fee and refund any overpayment, so the fallback honours
            // the same fee/refund contract as the new-relay path below.
            uint256 oldFee = oldRelay.protocolFeeInWei(_protocolId);
            require(msg.value >= oldFee, "too low fee");
            bool ok = oldRelay.verify{value: oldFee}(_protocolId, _votingRoundId, _leaf, _proof);
            require(ok, "old relay verification failed");
            uint256 oldRefund = msg.value - oldFee;
            if (oldRefund > 0) {
                /* solhint-disable avoid-low-level-calls */
                (bool oldRefundOk,) = msg.sender.call{value: oldRefund}("");
                /* solhint-enable avoid-low-level-calls */
                require(oldRefundOk, "Refund failed");
            }
            return true;
        } else {
            require(_protocolId > 1, "invalid protocol id");
            uint256 fee = protocolFeeInWei[_protocolId];
            require(msg.value >= fee, "too low fee");
            // RLY-01: never verify against an uninitialized (zero) Merkle root.
            bytes32 root = merkleRootsPrivate[_protocolId][_votingRoundId];
            require(root != bytes32(0), "not finalized");
            require(_proof.verifyCalldata(root, _leaf), "merkle proof invalid");
            // RLY-21: forward only the fee to the collection address and refund any overpayment.
            // verify() performs no state writes, so these external calls cannot corrupt contract state.
            if (fee > 0) {
                /* solhint-disable avoid-low-level-calls */
                //slither-disable-next-line arbitrary-send-eth
                (bool feeOk,) = feeCollectionAddress.call{value: fee}("");
                /* solhint-enable avoid-low-level-calls */
                require(feeOk, "Transfer failed");
            }
            uint256 refund = msg.value - fee;
            if (refund > 0) {
                /* solhint-disable avoid-low-level-calls */
                (bool refundOk,) = msg.sender.call{value: refund}("");
                /* solhint-enable avoid-low-level-calls */
                require(refundOk, "Refund failed");
            }
        }

        return true;
    }

    /**
     * @inheritdoc IRelay
     */
    function isFinalized(uint256 _protocolId, uint256 _votingRoundId) external view returns (bool) {
        if (oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId) {
            return oldRelay.isFinalized(_protocolId, _votingRoundId);
        }
        // RLY-09: a non-zero stored root is the finalized sentinel; RLY-04 guarantees relayed roots are
        // non-zero, so this sentinel is reliable (no zero-root "relayed-but-not-finalized" ambiguity).
        return merkleRootsPrivate[_protocolId][_votingRoundId] != bytes32(0);
    }

    /**
     * @inheritdoc IRelay
     */
    function merkleRoots(uint256 _protocolId, uint256 _votingRoundId) external view returns (bytes32 _merkleRoot) {
        if (oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId) {
            return oldRelay.merkleRoots(_protocolId, _votingRoundId);
        }
        require(signingPolicySetter != address(0), "no access to merkle roots");
        return merkleRootsPrivate[_protocolId][_votingRoundId];
    }

    /**
     * @inheritdoc RandomNumberV2Interface
     */
    function getRandomNumber()
        external
        view
        returns (uint256 _randomNumber, bool _isSecureRandom, uint256 _randomTimestamp)
    {
        // RLY-03: return the relayed (Merkle-proven) random value for the latest random round.
        // RLY-20: before the first random relay this returns (0, false, ts); consumers MUST gate on
        // _isSecureRandom (getRandomNumberHistorical instead reverts for an absent round).
        _randomNumber = toRandomNumberPrivate[stateData.randomVotingRoundId];
        _isSecureRandom = stateData.isSecureRandom;
        _randomTimestamp = stateData.firstVotingRoundStartTs + uint256(stateData.randomVotingRoundId + 1)
            * stateData.votingEpochDurationSeconds;
    }

    /**
     * @inheritdoc RandomNumberV2Interface
     */
    function getRandomNumberHistorical(uint256 _votingRoundId)
        external
        view
        returns (uint256 _randomNumber, bool _isSecureRandom, uint256 _randomTimestamp)
    {
        if (oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId) {
            return oldRelay.getRandomNumberHistorical(_votingRoundId);
        }
        // RLY-03 + L-1: gate presence on the finalized (non-zero, per RLY-04) merkle root, NOT on the value,
        // so a legitimately-relayed random value of 0 is returned rather than mis-read as "absent".
        require(
            merkleRootsPrivate[stateData.randomNumberProtocolId][_votingRoundId] != bytes32(0),
            "no random number"
        );
        _randomNumber = toRandomNumberPrivate[_votingRoundId];
        _isSecureRandom = (isSecureRandomMap[_votingRoundId / 256] >> (255 - _votingRoundId % 256))
                & bytes32(uint256(1)) == bytes32(uint256(1));
        _randomTimestamp =
            stateData.firstVotingRoundStartTs + uint256(_votingRoundId + 1) * stateData.votingEpochDurationSeconds;
    }

    /**
     * @inheritdoc IRelay
     */
    function getVotingRoundId(uint256 _timestamp) external view returns (uint256) {
        require(_timestamp >= stateData.firstVotingRoundStartTs, "before the start");
        return (_timestamp - stateData.firstVotingRoundStartTs) / stateData.votingEpochDurationSeconds;
    }

    /**
     * @inheritdoc IRelay
     */
    function toSigningPolicyHash(uint256 _rewardEpochId) external view returns (bytes32) {
        if (oldRelay != IRelay(address(0)) && _rewardEpochId < initialRewardEpochId) {
            return oldRelay.toSigningPolicyHash(_rewardEpochId);
        }
        require(signingPolicySetter != address(0), "no access to signing policy hashes");
        return toSigningPolicyHashPrivate[_rewardEpochId];
    }

    /**
     * @inheritdoc IRelay
     */
    function lastInitializedRewardEpochData()
        external
        view
        returns (uint32 _lastInitializedRewardEpoch, uint32 _startingVotingRoundIdForLastInitializedRewardEpoch)
    {
        _lastInitializedRewardEpoch = stateData.lastInitializedRewardEpoch;
        _startingVotingRoundIdForLastInitializedRewardEpoch =
            uint32(startingVotingRoundIds[_lastInitializedRewardEpoch]);
    }

    function _verifyCustomSignature(bytes calldata _relayMessage, bytes32 _messageHash)
        internal
        returns (uint256 _rewardEpochId)
    {
        /* solhint-disable avoid-low-level-calls */
        //slither-disable-next-line arbitrary-send-eth
        (bool success, bytes memory returnData) = address(this).call(_relayMessage);
        /* solhint-enable avoid-low-level-calls */
        require(success, "Verification failed");
        // 32 bytes hash + 3 bytes reward epoch id.
        // RLY-07 (deferred, Note, no exploit): the 35-byte length is the unique discriminator of relay()'s
        // protocolId==1 path (all other paths return 0 bytes or revert). Preserve this invariant if relay()'s
        // returns change. A robust typed protocol discriminator would need an assembly return-format change
        // (higher risk for a no-exploit note), so it is deferred by decision. See docs/relay-fixes.md.
        require(returnData.length == 35, "Wrong verification data");
        bytes32 returnHash;
        uint256 returnRewardEpochId;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            returnHash := mload(add(returnData, 0x20))
            returnRewardEpochId := shr(sub(256, mul(8, REWARD_EPOCH_ID_BYTES)), mload(add(returnData, 0x40)))
        }
        require(bytes32(returnHash) == _messageHash, "Invalid config hash");
        return returnRewardEpochId;
    }
}
