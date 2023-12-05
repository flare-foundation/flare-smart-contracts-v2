// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "flare-smart-contracts/contracts/genesis/interface/IFlareDaemonize.sol";
import "../../governance/implementation/AddressUpdatable.sol";
import "../../governance/implementation/Governed.sol";
import "../interface/IRandomProvider.sol";
import "./VoterWhitelister.sol";
import "./Submission.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";


// global constants
uint64 constant NEW_SIGNING_POLICY_PROTOCOL_ID = 0;
uint64 constant UPTIME_VOTE_PROTOCOL_ID = 1;
uint64 constant REWARDS_PROTOCOL_ID = 2;
uint64 constant FTSO_PROTOCOL_ID = 100;

contract Finalisation is Governed, AddressUpdatable, IFlareDaemonize, IRandomProvider {
    using SafeCast for uint256;

    uint256 internal constant UINT16_MAX = type(uint16).max;
    uint256 internal constant UINT256_MAX = type(uint256).max;
    uint256 internal constant PPM_MAX = 1e6;


    struct SigningPolicy {
        uint64 rId;                 // Reward epoch id.
        uint64 startVotingRoundId;  // First voting round id of validity. Usually it is the first voting round of reward epoch rID.
                                    // It can be later, if the confirmation of the signing policy on Flare blockchain gets delayed.
        uint64 threshold;           // Confirmation threshold in terms of PPM (parts per million). Usually more than 500,000.
        uint256 seed;               // Random seed.
        address[] voters;           // The list of eligible voters in the canonical order.
        uint16[] weights;           // The corresponding list of normalised signing weights of eligible voters.
                                    // Normalisation is done by compressing the weights from 32-byte values to 2 bytes,
                                    // while approximately keeping the weight relations.
    }

    struct VoterData {
        uint64 signTs;
        uint64 signBlock;
    }

    struct Votes {
        uint16 accumulatedWeight;
        mapping(address => VoterData) voters;
    }

    struct RewardEpochState {
        uint64 randomAcquisitionStartTs;
        uint64 randomAcquisitionStartBlock;
        uint64 voterRegistrationStartTs; // random acquisition end, vote power block selected
        uint64 voterRegistrationStartBlock;

        uint64 singingPolicySignStartTs; // voter registration end, new signing policy defined
        uint64 singingPolicySignStartBlock;
        uint64 singingPolicySignEndTs;
        uint64 singingPolicySignEndBlock;

        uint64 uptimeVoteSignEndTs;
        uint64 uptimeVoteSignEndBlock;
        uint64 rewardsSignEndTs;
        uint64 rewardsSignEndBlock;

        uint256 seed; // good random number
        uint64 votePowerBlock;
        uint64 startVotingRoundId;
        uint64 thresholdPPM;

        Votes signingPolicyVotes;
        mapping(bytes32 => Votes) uptimeVoteVotes;
        mapping(bytes32 => Votes) rewardVotes;
    }

    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    struct SignatureWithIndex {
        uint16 index;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    /// The FlareDaemon contract, set at construction time.
    address public immutable flareDaemon;

    /// Timestamp when the first reward epoch started, in seconds since UNIX epoch.
    uint64 public immutable rewardEpochsStartTs;
    /// Duration of reward epochs, in seconds.
    uint64 public immutable rewardEpochDurationSeconds;

    /// Timestamp when the first voting epoch started, in seconds since UNIX epoch.
    uint64 public immutable votingEpochsStartTs;
    /// Duration of voting epochs, in seconds.
    uint64 public immutable votingEpochDurationSeconds;

    mapping(uint256 => RewardEpochState) internal rewardEpochState;
    // mapping: protocol id => (mapping: voting round id => root)
    mapping(uint64 => mapping(uint64 => bytes32)) internal roots;
    // mapping: reward epoch id => number of weight based claims
    mapping(uint64 => uint256) public noOfWeightBasedClaims;

    // current random information
    uint256 internal currentRandom;
    uint64 internal currentRandomTs;
    bool internal currentRandomQuality;

    // Signing policy settings
    uint256 public immutable newSigningPolicyInitializationStartSeconds = 2 hours;
    uint256 public immutable nonPunishableRandomAcquisitionMinDurationSeconds = 75 minutes;
    uint256 public immutable nonPunishableRandomAcquisitionMinDurationBlocks = 2250;
    uint256 public immutable voterRegistrationMinDurationSeconds = 30 minutes;
    uint256 public immutable voterRegistrationMinDurationBlocks = 900;
    uint256 public immutable nonPunishableSigningPolicySignMinDurationSeconds = 20 minutes;
    uint256 public immutable nonPunishableSigningPolicySignMinDurationBlocks = 600;
    uint64 public signingPolicyThresholdPPM;
    uint64 public signingPolicyMinNumberOfVoters;

    /// Timestamp when current reward epoch ends, in seconds since UNIX epoch.
    uint64 internal currentRewardEpochEndTs;

    uint64 internal lastInitialisedVotingRound;

    /// The VoterWhitelister contract.
    VoterWhitelister public voterWhitelister;

    /// The Submission contract.
    Submission public submission;

    event SigningPolicyInitialized(
        uint64 rId,                 // Reward epoch id.
        uint64 startVotingRoundId,  // First voting round id of validity. Usually it is the first voting round of reward epoch rId.
                                    // It can be later, if the confirmation of the signing policy on Flare blockchain gets delayed.
        uint64 threshold,           // Confirmation threshold in terms of PPM (parts per million). Usually more than 500000.
        uint256 seed,               // Random seed.
        address[] voters,           // The list of eligible voters in the canonical order.
        uint16[] weights            // The corresponding list of normalised signing weights of eligible voters.
                                    // Normalisation is done by compressing the weights from 32-byte values to 2 bytes,
                                    // while approximately keeping the weight relations.
    );

    event VotePowerBlockSelected(
        uint64 rId,                 // Reward epoch id.
        uint64 votePowerBlock,      // Vote power block for given reward epoch
        uint64 timestamp            // Timestamp when this happened
    );

    event SigningPolicySigned(
        uint64 rId,                 // Reward epoch id.
        address signingAddress,     // Address which signed this
        address voter,              // Voter (entity)
        uint64 timestamp,           // Timestamp when this happened
        bool thresholdReached       // Indicates if signing threshold was reached
    );

    event UptimeVoteSigned(
        uint64 rId,                 // Reward epoch id.
        address signingAddress,     // Address which signed this
        address voter,              // Voter (entity)
        bytes32 uptimeVoteHash,     // Uptime vote hash
        uint64 timestamp,           // Timestamp when this happened
        bool thresholdReached       // Indicates if signing threshold was reached
    );

    event RewardsSigned(
        uint64 rId,                     // Reward epoch id.
        address signingAddress,         // Address which signed this
        address voter,                  // Voter (entity)
        bytes32 rewardsHash,            // Rewards hash
        uint256 noOfWeightBasedClaims,  // Number of weight based claims
        uint64 timestamp,               // Timestamp when this happened
        bool thresholdReached           // Indicates if signing threshold was reached
    );

    /// Only FlareDaemon contract can call this method.
    modifier onlyFlareDaemon {
        require (msg.sender == flareDaemon, "only flare daemon");
        _;
    }

    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        address _flareDaemon,
        uint64 _votingEpochsStartTs,
        uint64 _votingEpochDurationSeconds,
        uint64 _rewardEpochsStartTs,
        uint64 _rewardEpochDurationSeconds,
        uint64 _signingPolicyThresholdPPM,
        uint64 _signingPolicyMinNumberOfVoters,
        uint64 _firstRewardEpoch,
        bytes32 _firstRewardEpochSigningPolicyHash
    )
        Governed(_governanceSettings, _initialGovernance) AddressUpdatable(_addressUpdater)
    {
        require(_flareDaemon != address(0), "flare daemon zero");
        require(_rewardEpochDurationSeconds > 0, "reward epoch duration zero");
        require(_votingEpochDurationSeconds > 0, "voting epoch duration zero");
        require(_rewardEpochDurationSeconds % _votingEpochDurationSeconds == 0, "invalid durations");
        require((_rewardEpochsStartTs - _votingEpochsStartTs) % _votingEpochDurationSeconds == 0, "invalid start timestamps");
        require(_signingPolicyThresholdPPM <= PPM_MAX, "threshold too high");
        require(_signingPolicyMinNumberOfVoters > 0, "zero voters");
        flareDaemon = _flareDaemon;
        votingEpochsStartTs = _votingEpochsStartTs;
        votingEpochDurationSeconds = _votingEpochDurationSeconds;
        rewardEpochsStartTs = _rewardEpochsStartTs;
        rewardEpochDurationSeconds = _rewardEpochDurationSeconds;
        signingPolicyThresholdPPM = _signingPolicyThresholdPPM;
        signingPolicyMinNumberOfVoters = _signingPolicyMinNumberOfVoters;

        currentRewardEpochEndTs = _rewardEpochsStartTs + (_firstRewardEpoch + 1) * _rewardEpochDurationSeconds;
        roots[NEW_SIGNING_POLICY_PROTOCOL_ID][_firstRewardEpoch] = _firstRewardEpochSigningPolicyHash;
    }

    function daemonize() external onlyFlareDaemon returns (bool) {
        address[] memory revealAddresses;
        address[] memory signingAddresses;
        uint64 currentVotingEpoch = _getCurrentVotingEpoch();
        uint64 currentRewardEpoch = _getCurrentRewardEpoch();
        if (currentVotingEpoch > lastInitialisedVotingRound) {
            // in case of new voting round - get reveal and signing addresses
            revealAddresses = voterWhitelister.getWhitelistedFtsoAddresses(currentRewardEpoch);
            signingAddresses = voterWhitelister.getWhitelistedSigningAddresses(currentRewardEpoch);
        }

        if (block.timestamp >= currentRewardEpochEndTs - newSigningPolicyInitializationStartSeconds) {
            uint64 nextRewardEpoch = currentRewardEpoch + 1;

            // check if new signing policy is already defined
            if (roots[NEW_SIGNING_POLICY_PROTOCOL_ID][nextRewardEpoch] == bytes32(0)) {
                RewardEpochState storage state = rewardEpochState[nextRewardEpoch];
                if (state.randomAcquisitionStartTs == 0) {
                    state.randomAcquisitionStartTs = block.timestamp.toUint64();
                    state.randomAcquisitionStartBlock = block.number.toUint64();
                } else if (state.voterRegistrationStartTs == 0) {
                    if (currentRandomTs > state.randomAcquisitionStartTs && currentRandomQuality) {
                        state.voterRegistrationStartTs = block.timestamp.toUint64();
                        state.voterRegistrationStartBlock = block.number.toUint64();
                        _selectVotePowerBlock(nextRewardEpoch);
                    }
                } else if (!_isVoterRegistrationEnabled(nextRewardEpoch, state)) { // state.singingPolicySignStartTs == 0
                    state.singingPolicySignStartTs = block.timestamp.toUint64();
                    state.singingPolicySignStartBlock = block.number.toUint64();
                    _initializeNextSigningPolicy(nextRewardEpoch);
                }
            }

            // start new reward epoch if it is time and new signing policy is defined
            if (_isNextRewardEpoch(nextRewardEpoch)) {
                currentRewardEpochEndTs += rewardEpochDurationSeconds;
            }
        }

        // in case of new voting round - init new voting round on Submission contract
        if (currentVotingEpoch > lastInitialisedVotingRound) {
            lastInitialisedVotingRound = currentVotingEpoch;
            address[] memory commitAddresses;
            // in case of new reward epoch - get new commit addresses otherwise they are the same as reveal addresses
            if (_getCurrentRewardEpoch() > currentRewardEpoch) {
                commitAddresses = voterWhitelister.getWhitelistedFtsoAddresses(currentRewardEpoch + 1);
            } else {
                commitAddresses = revealAddresses;
            }
            submission.initVotingRound(commitAddresses, revealAddresses, signingAddresses);
        }

        return true;
    }

    /**
     * Method for collecting signatures for the new signing policy
     * @param _rId Reward epoch id of the new signing policy
     * @param _newSigningPolicyHash New signing policy hash
     * @param _signature Signature
     */
    function signNewSigningPolicy(
        uint64 _rId,
        bytes32 _newSigningPolicyHash,
        Signature calldata _signature
    )
        external
    {
        RewardEpochState storage state = rewardEpochState[_rId - 1];
        require(_newSigningPolicyHash != bytes32(0) && roots[NEW_SIGNING_POLICY_PROTOCOL_ID][_rId] == _newSigningPolicyHash,
            "new signing policy hash invalid");
        require(state.singingPolicySignEndTs == 0, "new signing policy already signed");
        bytes32 messageHash = keccak256(abi.encode(_rId, _newSigningPolicyHash));
        bytes32 signedMessageHash = ECDSA.toEthSignedMessageHash(messageHash); // TODO - remove rId?
        address signingAddress = ECDSA.recover(signedMessageHash, _signature.v, _signature.r, _signature.s);
        (address voter, uint16 weight) = voterWhitelister.getVoterWithNormalisedWeight(_rId - 1, signingAddress);
        require(voter != address(0), "signature invalid");
        require(state.signingPolicyVotes.voters[voter].signTs == 0, "signing address already signed");
        state.signingPolicyVotes.voters[voter] = VoterData(block.timestamp.toUint64(), block.number.toUint64());
        if (state.signingPolicyVotes.accumulatedWeight + weight >= UINT16_MAX * state.thresholdPPM / PPM_MAX) {
            // threshold reached, save timestamp and block number (this enables claiming)
            state.singingPolicySignEndTs = block.timestamp.toUint64();
            state.singingPolicySignEndBlock = block.number.toUint64();
            delete state.signingPolicyVotes.accumulatedWeight;
            emit SigningPolicySigned(_rId, signingAddress, voter, block.timestamp.toUint64(), true);
        } else {
            // keep collecting signatures
            state.signingPolicyVotes.accumulatedWeight += weight;
            emit SigningPolicySigned(_rId, signingAddress, voter, block.timestamp.toUint64(), false);
        }
    }

    function signUptimeVote(
        uint64 _rId,
        bytes32 _uptimeVoteHash,
        Signature calldata _signature
    )
        external
    {
        RewardEpochState storage state = rewardEpochState[_rId];
        require(_rId < getCurrentRewardEpoch(), "epoch not ended yet");
        require (roots[UPTIME_VOTE_PROTOCOL_ID][_rId] == bytes32(0), "uptime vote hash already signed");
        bytes32 messageHash = keccak256(abi.encode(_rId, _uptimeVoteHash));
        bytes32 signedMessageHash = ECDSA.toEthSignedMessageHash(messageHash);
        address signingAddress = ECDSA.recover(signedMessageHash, _signature.v, _signature.r, _signature.s);
        (address voter, uint16 weight) = voterWhitelister.getVoterWithNormalisedWeight(_rId, signingAddress);
        require(voter != address(0), "signature invalid");
        require(state.uptimeVoteVotes[_uptimeVoteHash].voters[voter].signTs == 0, "voter already signed");
        // save signing address timestamp and block number
        state.uptimeVoteVotes[_uptimeVoteHash].voters[voter] = VoterData(block.timestamp.toUint64(), block.number.toUint64());
        if (state.uptimeVoteVotes[_uptimeVoteHash].accumulatedWeight + weight >= UINT16_MAX * state.thresholdPPM / PPM_MAX) {
            // threshold reached, save timestamp and block number (this enables rewards signing)
            state.uptimeVoteSignEndTs = block.timestamp.toUint64();
            state.uptimeVoteSignEndBlock = block.number.toUint64();
            roots[UPTIME_VOTE_PROTOCOL_ID][_rId] = _uptimeVoteHash;
            delete state.uptimeVoteVotes[_uptimeVoteHash].accumulatedWeight;
            emit UptimeVoteSigned(_rId, signingAddress, voter, _uptimeVoteHash, block.timestamp.toUint64(), true);
        } else {
            // keep collecting signatures
            state.uptimeVoteVotes[_uptimeVoteHash].accumulatedWeight += weight;
            emit UptimeVoteSigned(_rId, signingAddress, voter, _uptimeVoteHash, block.timestamp.toUint64(), false);
        }
    }

    function signRewards(
        uint64 _rId,
        uint256 _noOfWeightBasedClaims,
        bytes32 _rewardsHash,
        Signature calldata _signature
    )
        external
    {
        RewardEpochState storage state = rewardEpochState[_rId];
        require(_rId < getCurrentRewardEpoch(), "epoch not ended yet");
        require(state.singingPolicySignEndTs != 0, "new signing policy not signed yet");
        require(roots[UPTIME_VOTE_PROTOCOL_ID][_rId] != bytes32(0), "uptime vote hash not signed yet");
        require (roots[REWARDS_PROTOCOL_ID][_rId] == bytes32(0), "rewards hash already signed");
        bytes32 messageHash = keccak256(abi.encode(_rId, _noOfWeightBasedClaims, _rewardsHash));
        bytes32 signedMessageHash = ECDSA.toEthSignedMessageHash(messageHash);
        address signingAddress = ECDSA.recover(signedMessageHash, _signature.v, _signature.r, _signature.s);
        (address voter, uint16 weight) = voterWhitelister.getVoterWithNormalisedWeight(_rId, signingAddress);
        require(voter != address(0), "signature invalid");
        require(state.rewardVotes[messageHash].voters[voter].signTs == 0, "voter already signed");
        // save signing address timestamp and block number
        state.rewardVotes[messageHash].voters[voter] = VoterData(block.timestamp.toUint64(), block.number.toUint64());
        if (state.rewardVotes[messageHash].accumulatedWeight + weight >= UINT16_MAX * state.thresholdPPM / PPM_MAX) {
            // threshold reached, save timestamp and block number (this enables claiming)
            state.rewardsSignEndTs = block.timestamp.toUint64();
            state.rewardsSignEndBlock = block.number.toUint64();
            roots[REWARDS_PROTOCOL_ID][_rId] = _rewardsHash;
            noOfWeightBasedClaims[_rId] = _noOfWeightBasedClaims;
            delete state.rewardVotes[messageHash].accumulatedWeight;
            emit RewardsSigned(_rId, signingAddress, voter, _rewardsHash, _noOfWeightBasedClaims, block.timestamp.toUint64(), true);
        } else {
            // keep collecting signatures
            state.rewardVotes[messageHash].accumulatedWeight += weight;
            emit RewardsSigned(_rId, signingAddress, voter, _rewardsHash, _noOfWeightBasedClaims, block.timestamp.toUint64(), false);
        }
    }

    function finalise(
        SigningPolicy calldata _signingPolicy,
        uint64 _pId,
        uint64 _votingRoundId,
        bool _quality,
        bytes32 _root,
        SignatureWithIndex[] calldata _signatures
    )
        external
    {
        require(_pId > 2, "protocol id invalid");
        require(roots[_pId][_votingRoundId] == bytes32(0), "already finalised");
        uint64 rId = _signingPolicy.rId;
        require(roots[NEW_SIGNING_POLICY_PROTOCOL_ID][rId] == keccak256(abi.encode(_signingPolicy)), "signing policy invalid");
        require(rewardEpochState[rId].startVotingRoundId <= _votingRoundId, "voting round too low");
        uint64 nextStartVotingRoundId = rewardEpochState[rId + 1].startVotingRoundId;
        require(nextStartVotingRoundId == 0 || _votingRoundId < nextStartVotingRoundId, "voting round too high");
        uint16 accumulatedWeight = 0;
        bytes32 messageHash = ECDSA.toEthSignedMessageHash(keccak256(abi.encode(_pId, _votingRoundId, _quality, _root)));
        for (uint256 i = 0; i < _signatures.length; i++) {
            SignatureWithIndex calldata signature = _signatures[i];
            address signingAddress = ECDSA.recover(messageHash, signature.v, signature.r, signature.s);
            require(signingAddress == _signingPolicy.voters[signature.index], "signature invalid");
            accumulatedWeight += _signingPolicy.weights[signature.index];
        }
        require(accumulatedWeight >= UINT16_MAX * rewardEpochState[rId].thresholdPPM / PPM_MAX, "threshold not reached");
        // save root
        roots[_pId][_votingRoundId] = _root;
        if (_pId == FTSO_PROTOCOL_ID) {
            currentRandom = uint256(_root);
            currentRandomTs = votingEpochsStartTs + _votingRoundId * votingEpochDurationSeconds; // TODO check increasing time?
            currentRandomQuality = _quality;
        }
    }

    function changeSigningPolicySettings(
        uint64 _signingPolicyThresholdPPM,
        uint64 _signingPolicyMinNumberOfVoters
    )
        external onlyGovernance
    {
        require(_signingPolicyThresholdPPM <= PPM_MAX, "threshold too high");
        require(_signingPolicyMinNumberOfVoters > 0, "zero voters");
        signingPolicyThresholdPPM = _signingPolicyThresholdPPM;
        signingPolicyMinNumberOfVoters = _signingPolicyMinNumberOfVoters;
    }

    function getVotePowerBlock(uint256 _rewardEpoch) external view returns(uint256 _votePowerBlock) {
        _votePowerBlock = rewardEpochState[_rewardEpoch].votePowerBlock;
        require(_votePowerBlock != 0, "vote power block not initialized yet");
    }

    function getVoterRegistrationData(
        uint256 _rewardEpoch
    )
        external view
        returns (
            uint256 _votePowerBlock,
            bool _enabled
        )
    {
        _votePowerBlock = rewardEpochState[_rewardEpoch].votePowerBlock;
        _enabled = _isVoterRegistrationEnabled(_rewardEpoch, rewardEpochState[_rewardEpoch]);
    }

    // <= PPM_MAX
    function getRewardsFeeBurnFactor(uint64 _rewardEpoch, address _rewardOwner) external view returns(uint256) {
        // TODO
    }

    function getCurrentRandom() external view returns(uint256 _currentRandom) {
        return currentRandom;
    }

    function getCurrentRandomWithQuality() external view returns(uint256 _currentRandom, bool _goodRandom) {
        return (currentRandom, currentRandomQuality);
    }

    function getConfirmedMerkleRoot(uint64 _pId, uint64 _rId) external view returns(bytes32) {
        return roots[_pId][_rId];
    }

    function switchToFallbackMode() external pure returns (bool) {
        // do nothing - there is no fallback mode in Finalisation contract
        return false;
    }

    function getContractName() external pure returns (string memory) {
        return "Finalisation";
    }

    function getCurrentRewardEpoch() public view returns(uint64 _currentRewardEpoch) {
        _currentRewardEpoch = _getCurrentRewardEpoch();
        if (_isNextRewardEpoch(_currentRewardEpoch + 1)) {
            // first transaction in the block (daemonize() call will change `currentRewardEpochEndTs` value after it)
            _currentRewardEpoch += 1;
        }
    }

    function _selectVotePowerBlock(uint64 _nextRewardEpoch) internal {
        // currentRandomTs > state.randomAcquisitionStartTs && currentRandomQuality == true
        RewardEpochState storage state = rewardEpochState[_nextRewardEpoch];
        uint64 endBlock = state.randomAcquisitionStartBlock;
        uint64 numberOfBlocks = endBlock; // endBlock > 0
        if (rewardEpochState[_nextRewardEpoch - 1].randomAcquisitionStartBlock == 0) {
            numberOfBlocks = Math.min(endBlock, 150000).toUint64(); // approx number of blocks per reward epoch
        } else {
            // rewardEpochState[_nextRewardEpoch - 1].randomAcquisitionStartBlock < endBlock
            numberOfBlocks -= rewardEpochState[_nextRewardEpoch - 1].randomAcquisitionStartBlock;
        }

        //slither-disable-next-line weak-prng
        uint256 votepowerBlocksAgo = currentRandom % numberOfBlocks;
        if (votepowerBlocksAgo == 0) {
            votepowerBlocksAgo = 1;
        }
        uint64 votePowerBlock = endBlock - votepowerBlocksAgo.toUint64();
        state.votePowerBlock = votePowerBlock;
        state.seed = currentRandom;

        emit VotePowerBlockSelected(_nextRewardEpoch, votePowerBlock, block.timestamp.toUint64());
    }

    function _initializeNextSigningPolicy(uint64 _nextRewardEpoch) internal {
        RewardEpochState storage state = rewardEpochState[_nextRewardEpoch];
        SigningPolicy memory sp;
        sp.rId = _nextRewardEpoch;
        sp.startVotingRoundId = _getStartVotingRoundId();
        (sp.voters, sp.weights) = voterWhitelister.createSigningPolicySnapshot(_nextRewardEpoch);
        sp.threshold = signingPolicyThresholdPPM;
        sp.seed = state.seed;

        state.startVotingRoundId = sp.startVotingRoundId;
        state.thresholdPPM = sp.threshold;
        roots[NEW_SIGNING_POLICY_PROTOCOL_ID][_nextRewardEpoch] = keccak256(abi.encode(sp));

        emit SigningPolicyInitialized(sp.rId, sp.startVotingRoundId, sp.threshold, sp.seed, sp.voters, sp.weights);
    }

    function _getCurrentRewardEpoch() internal view returns(uint64) {
        return (currentRewardEpochEndTs - rewardEpochsStartTs) / rewardEpochDurationSeconds;
    }

    function _isNextRewardEpoch(uint64 _nextRewardEpoch) internal view returns (bool) {
        return block.timestamp >= currentRewardEpochEndTs &&
            roots[NEW_SIGNING_POLICY_PROTOCOL_ID][_nextRewardEpoch] != bytes32(0) &&
            _getCurrentVotingEpoch() >= rewardEpochState[_nextRewardEpoch].startVotingRoundId;
    }

    function _getCurrentVotingEpoch() internal view returns(uint64) {
        return ((block.timestamp - votingEpochsStartTs) / votingEpochDurationSeconds).toUint64();
    }

    /**
     * voter registration is enabled until enough time has passed and enough blocks have been created
     * or until a minimum number of voters have been registered.
     */
    function _isVoterRegistrationEnabled(uint256 _rewardEpoch, RewardEpochState storage _state) internal view returns(bool) {
        return block.timestamp <= _state.voterRegistrationStartTs + voterRegistrationMinDurationSeconds ||
            block.number <= _state.voterRegistrationStartBlock + voterRegistrationMinDurationBlocks ||
            voterWhitelister.getNumberOfWhitelistedVoters(_rewardEpoch) < signingPolicyMinNumberOfVoters;
    }

    function _getStartVotingRoundId() internal view returns (uint64 _startVotingRoundId) {
        uint64 timeFromStart = currentRewardEpochEndTs;
        if (block.timestamp > timeFromStart) {
            timeFromStart = block.timestamp.toUint64();
        }
        timeFromStart -= votingEpochsStartTs; // currentRewardEpochEndTs >= rewardEpochsStartTs >= votingEpochsStartTs
        _startVotingRoundId = timeFromStart / votingEpochDurationSeconds;
        if (timeFromStart % votingEpochDurationSeconds != 0) {
            _startVotingRoundId += 1;
        }
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
        voterWhitelister = VoterWhitelister(_getContractAddress(_contractNameHashes, _contractAddresses, "VoterWhitelister"));
        submission = Submission(_getContractAddress(_contractNameHashes, _contractAddresses, "Submission"));
    }
}