// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "flare-smart-contracts/contracts/genesis/interface/IFlareDaemonize.sol";
import "flare-smart-contracts/contracts/userInterfaces/IPriceSubmitter.sol";
import "../../governance/implementation/Governed.sol";
import "../../utils/implementation/AddressUpdatable.sol";
import "../../utils/lib/SafePct.sol";
import "../interface/IRandomProvider.sol";
import "../interface/IRewardEpochSwitchoverTrigger.sol";
import "./VoterRegistry.sol";
import "./Relay.sol";
import "./Submission.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

//solhint-disable-next-line max-states-count
contract FlareSystemManager is Governed, AddressUpdatable, IFlareDaemonize, IRandomProvider {
    using SafeCast for uint256;
    using SafePct for uint256;

    struct Settings {
        uint64 firstVotingRoundStartTs;
        uint64 votingEpochDurationSeconds;
        uint64 firstRewardEpochStartVotingRoundId;
        uint64 rewardEpochDurationInVotingEpochs;
        uint64 newSigningPolicyInitializationStartSeconds;
        uint64 nonPunishableRandomAcquisitionMinDurationSeconds;
        uint64 nonPunishableRandomAcquisitionMinDurationBlocks;
        uint64 voterRegistrationMinDurationSeconds;
        uint64 voterRegistrationMinDurationBlocks;
        uint64 nonPunishableSigningPolicySignMinDurationSeconds;
        uint64 nonPunishableSigningPolicySignMinDurationBlocks;
        uint64 signingPolicyThresholdPPM;
        uint64 signingPolicyMinNumberOfVoters;
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
        uint32 startVotingRoundId;
        uint16 threshold; // absolute value in normalised weight

        Votes signingPolicyVotes;
        mapping(bytes32 => Votes) uptimeVoteVotes;
        mapping(bytes32 => Votes) rewardVotes;
    }

    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    uint256 internal constant UINT16_MAX = type(uint16).max;
    uint256 internal constant UINT256_MAX = type(uint256).max;
    uint256 internal constant PPM_MAX = 1e6;

    /// The FlareDaemon contract, set at construction time.
    address public immutable flareDaemon;

    /// Timestamp when the first reward epoch started, in seconds since UNIX epoch.
    uint64 public immutable rewardEpochsStartTs;
    /// Duration of reward epochs, in seconds.
    uint64 public immutable rewardEpochDurationSeconds;

    /// Timestamp when the first voting epoch started, in seconds since UNIX epoch.
    uint64 public immutable firstVotingRoundStartTs;
    /// Duration of voting epochs, in seconds.
    uint64 public immutable votingEpochDurationSeconds;

    mapping(uint256 => RewardEpochState) internal rewardEpochState;
    // mapping: reward epoch id => uptime vote hash
    mapping(uint256 => bytes32) public uptimeVoteHash;
    // mapping: reward epoch id => rewards hash
    mapping(uint256 => bytes32) public rewardsHash;
    // mapping: reward epoch id => number of weight based claims
    mapping(uint256 => uint256) public noOfWeightBasedClaims;

    uint64 internal immutable firstRandomAcquisitionNumberOfBlocks;

    // Signing policy settings
    uint64 public newSigningPolicyInitializationStartSeconds; // 2 hours
    uint64 public nonPunishableRandomAcquisitionMinDurationSeconds; // 75 minutes
    uint64 public nonPunishableRandomAcquisitionMinDurationBlocks; // 2250
    uint64 public voterRegistrationMinDurationSeconds; // 30 minutes
    uint64 public voterRegistrationMinDurationBlocks; // 900
    uint64 public nonPunishableSigningPolicySignMinDurationSeconds; // 20 minutes
    uint64 public nonPunishableSigningPolicySignMinDurationBlocks; // 600
    uint64 public signingPolicyThresholdPPM;
    uint64 public signingPolicyMinNumberOfVoters;

    /// Timestamp when current reward epoch should end, in seconds since UNIX epoch.
    uint64 public currentRewardEpochExpectedEndTs;

    uint64 public lastInitialisedVotingRoundId;

    uint24 public rewardEpochIdToExpireNext;

    /// The VoterRegistry contract.
    VoterRegistry public voterRegistry;

    /// The Submission contract.
    Submission public submission;

    /// The Relay contract.
    Relay public relay;
    /// flag indicating if random is obtained using price submitter or relay contract
    bool public usePriceSubmitterAsRandomProvider;

    /// The PriceSubmitter contract.
    IPriceSubmitter public priceSubmitter;

    IRewardEpochSwitchoverTrigger[] internal rewardEpochSwitchoverTriggerContracts;

    event RandomAcquisitionStarted(
        uint24 rewardEpochId,       // Reward epoch id
        uint64 timestamp            // Timestamp when this happened
    );

    event VotePowerBlockSelected(
        uint24 rewardEpochId,       // Reward epoch id
        uint64 votePowerBlock,      // Vote power block for given reward epoch
        uint64 timestamp            // Timestamp when this happened
    );

    event SigningPolicySigned(
        uint24 rewardEpochId,           // Reward epoch id
        address signingPolicyAddress,   // Address which signed this
        address voter,                  // Voter (entity)
        uint64 timestamp,               // Timestamp when this happened
        bool thresholdReached           // Indicates if signing threshold was reached
    );

    event RewardEpochStarted(
        uint24 rewardEpochId,           // Reward epoch id
        uint32 startVotingRoundId,      // First voting round id of validity
        uint64 timestamp                // Timestamp when this happened
    );

    event UptimeVoteSigned(
        uint24 rewardEpochId,           // Reward epoch id
        address signingPolicyAddress,   // Address which signed this
        address voter,                  // Voter (entity)
        bytes32 uptimeVoteHash,         // Uptime vote hash
        uint64 timestamp,               // Timestamp when this happened
        bool thresholdReached           // Indicates if signing threshold was reached
    );

    event RewardsSigned(
        uint24 rewardEpochId,           // Reward epoch id
        address signingPolicyAddress,   // Address which signed this
        address voter,                  // Voter (entity)
        bytes32 rewardsHash,            // Rewards hash
        uint256 noOfWeightBasedClaims,  // Number of weight based claims
        uint64 timestamp,               // Timestamp when this happened
        bool thresholdReached           // Indicates if signing threshold was reached
    );

    /// Only FlareDaemon contract can call this method.
    modifier onlyFlareDaemon {
        require(msg.sender == flareDaemon, "only flare daemon");
        _;
    }

    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        address _flareDaemon,
        Settings memory _settings,
        uint64 _firstRandomAcquisitionNumberOfBlocks,
        uint24 _firstRewardEpochId,
        uint16 _firstRewardEpochThreshold
    )
        Governed(_governanceSettings, _initialGovernance) AddressUpdatable(_addressUpdater)
    {
        require(_flareDaemon != address(0), "flare daemon zero");
        require(_settings.rewardEpochDurationInVotingEpochs > 0, "reward epoch duration zero");
        require(_settings.votingEpochDurationSeconds > 0, "voting epoch duration zero");
        require(_settings.signingPolicyThresholdPPM <= PPM_MAX, "threshold too high");
        require(_settings.signingPolicyMinNumberOfVoters > 0, "zero voters");
        require(_firstRandomAcquisitionNumberOfBlocks > 0, "zero blocks");
        flareDaemon = _flareDaemon;
        firstVotingRoundStartTs = _settings.firstVotingRoundStartTs;
        votingEpochDurationSeconds = _settings.votingEpochDurationSeconds;
        rewardEpochsStartTs = _settings.firstVotingRoundStartTs +
            _settings.firstRewardEpochStartVotingRoundId * _settings.votingEpochDurationSeconds;
        rewardEpochDurationSeconds =
            _settings.rewardEpochDurationInVotingEpochs * _settings.votingEpochDurationSeconds;
        newSigningPolicyInitializationStartSeconds = _settings.newSigningPolicyInitializationStartSeconds;
        nonPunishableRandomAcquisitionMinDurationSeconds = _settings.nonPunishableRandomAcquisitionMinDurationSeconds;
        nonPunishableRandomAcquisitionMinDurationBlocks = _settings.nonPunishableRandomAcquisitionMinDurationBlocks;
        voterRegistrationMinDurationSeconds = _settings.voterRegistrationMinDurationSeconds;
        voterRegistrationMinDurationBlocks = _settings.voterRegistrationMinDurationBlocks;
        nonPunishableSigningPolicySignMinDurationSeconds = _settings.nonPunishableSigningPolicySignMinDurationSeconds;
        nonPunishableSigningPolicySignMinDurationBlocks = _settings.nonPunishableSigningPolicySignMinDurationBlocks;
        signingPolicyThresholdPPM = _settings.signingPolicyThresholdPPM;
        signingPolicyMinNumberOfVoters = _settings.signingPolicyMinNumberOfVoters;

        firstRandomAcquisitionNumberOfBlocks = _firstRandomAcquisitionNumberOfBlocks;
        currentRewardEpochExpectedEndTs = rewardEpochsStartTs + (_firstRewardEpochId + 1) * rewardEpochDurationSeconds;
        rewardEpochState[_firstRewardEpochId].threshold = _firstRewardEpochThreshold;
        require(
            currentRewardEpochExpectedEndTs > block.timestamp + _settings.newSigningPolicyInitializationStartSeconds,
            "reward epoch end not in the future");
    }

    /**
     * @inheritdoc IFlareDaemonize
     */
    function daemonize() external override onlyFlareDaemon returns (bool) {
        uint32 currentVotingEpochId = _getCurrentVotingEpochId();
        uint24 currentRewardEpochId = _getCurrentRewardEpochId();

        if (block.timestamp >= currentRewardEpochExpectedEndTs - newSigningPolicyInitializationStartSeconds) {
            uint24 nextRewardEpochId = currentRewardEpochId + 1;

            // check if new signing policy is already defined
            if (_getSingingPolicyHash(nextRewardEpochId) == bytes32(0)) {
                RewardEpochState storage state = rewardEpochState[nextRewardEpochId];
                if (state.randomAcquisitionStartTs == 0) {
                    state.randomAcquisitionStartTs = block.timestamp.toUint64();
                    state.randomAcquisitionStartBlock = block.number.toUint64();
                    voterRegistry.setNewSigningPolicyInitializationStartBlockNumber(nextRewardEpochId);
                    emit RandomAcquisitionStarted(nextRewardEpochId, block.timestamp.toUint64());
                } else if (state.voterRegistrationStartTs == 0) {
                    (uint256 random, bool randomQuality, uint64 randomTs) = _getRandom();
                    if (randomTs > state.randomAcquisitionStartTs && randomQuality) {
                        state.voterRegistrationStartTs = block.timestamp.toUint64();
                        state.voterRegistrationStartBlock = block.number.toUint64();
                        _selectVotePowerBlock(nextRewardEpochId, random);
                    }
                } else if (!_isVoterRegistrationEnabled(nextRewardEpochId, state)) {
                    // state.singingPolicySignStartTs == 0
                    state.singingPolicySignStartTs = block.timestamp.toUint64();
                    state.singingPolicySignStartBlock = block.number.toUint64();
                    _initializeNextSigningPolicy(nextRewardEpochId);
                }
            }

            // start new reward epoch if it is time and new signing policy is defined
            if (_isNextRewardEpochId(nextRewardEpochId)) {
                uint64 nextRewardEpochExpectedEndTs = currentRewardEpochExpectedEndTs + rewardEpochDurationSeconds;
                currentRewardEpochExpectedEndTs = nextRewardEpochExpectedEndTs;
                emit RewardEpochStarted(
                    nextRewardEpochId,
                    rewardEpochState[nextRewardEpochId].startVotingRoundId,
                    block.timestamp.toUint64()
                );
                uint256 len = rewardEpochSwitchoverTriggerContracts.length;
                for (uint256 i = 0; i < len; i++) {
                    rewardEpochSwitchoverTriggerContracts[i].triggerRewardEpochSwitchover(
                        nextRewardEpochId,
                        nextRewardEpochExpectedEndTs,
                        rewardEpochDurationSeconds
                    );
                }
            }
        }

        // in case of new voting round - init new voting round on Submission contract
        if (currentVotingEpochId > lastInitialisedVotingRoundId) {
            address[] memory submit1Addresses;
            address[] memory submit2Addresses;
            address[] memory submitSignaturesAddresses;
            lastInitialisedVotingRoundId = currentVotingEpochId;
            submit2Addresses = voterRegistry.getRegisteredSubmitAddresses(currentRewardEpochId);
            submitSignaturesAddresses = voterRegistry.getRegisteredSubmitSignaturesAddresses(currentRewardEpochId);
            // in case of new reward epoch - get new submit1Addresses otherwise they are the same as submit2Addresses
            if (_getCurrentRewardEpochId() > currentRewardEpochId) {
                submit1Addresses = voterRegistry.getRegisteredSubmitAddresses(currentRewardEpochId + 1);
            } else {
                submit1Addresses = submit2Addresses;
            }
            submission.initNewVotingRound(
                submit1Addresses,
                submit2Addresses,
                submit1Addresses,
                submitSignaturesAddresses
            );
        }

        return true;
    }

    /**
     * Method for collecting signatures for the new signing policy
     * @param _rewardEpochId Reward epoch id of the new signing policy
     * @param _newSigningPolicyHash New signing policy hash
     * @param _signature Signature
     */
    function signNewSigningPolicy(
        uint24 _rewardEpochId,
        bytes32 _newSigningPolicyHash,
        Signature calldata _signature
    )
        external
    {
        RewardEpochState storage state = rewardEpochState[_rewardEpochId - 1];
        require(_newSigningPolicyHash != bytes32(0) && _getSingingPolicyHash(_rewardEpochId) == _newSigningPolicyHash,
            "new signing policy hash invalid");
        require(state.singingPolicySignEndTs == 0, "new signing policy already signed");
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(_newSigningPolicyHash);
        address signingPolicyAddress = ECDSA.recover(signedMessageHash, _signature.v, _signature.r, _signature.s);
        (address voter, uint16 weight) = voterRegistry.getVoterWithNormalisedWeight(
            _rewardEpochId - 1, signingPolicyAddress);
        require(voter != address(0), "signature invalid");
        require(state.signingPolicyVotes.voters[voter].signTs == 0, "signing address already signed");
        // save signing address timestamp and block number
        state.signingPolicyVotes.voters[voter] = VoterData(block.timestamp.toUint64(), block.number.toUint64());
        // check if signing threshold is reached
        bool thresholdReached = state.signingPolicyVotes.accumulatedWeight + weight > state.threshold;
        if (thresholdReached) {
            // save timestamp and block number (this enables claiming)
            state.singingPolicySignEndTs = block.timestamp.toUint64();
            state.singingPolicySignEndBlock = block.number.toUint64();
            delete state.signingPolicyVotes.accumulatedWeight;
        } else {
            // keep collecting signatures
            state.signingPolicyVotes.accumulatedWeight += weight;
        }
        emit SigningPolicySigned(
            _rewardEpochId,
            signingPolicyAddress,
            voter,
            block.timestamp.toUint64(),
            thresholdReached
        );
    }

    function signUptimeVote(
        uint24 _rewardEpochId,
        bytes32 _uptimeVoteHash,
        Signature calldata _signature
    )
        external
    {
        RewardEpochState storage state = rewardEpochState[_rewardEpochId];
        require(_rewardEpochId < getCurrentRewardEpochId(), "epoch not ended yet");
        require(uptimeVoteHash[_rewardEpochId] == bytes32(0), "uptime vote hash already signed");
        bytes32 messageHash = keccak256(abi.encode(_rewardEpochId, _uptimeVoteHash));
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        address signingPolicyAddress = ECDSA.recover(signedMessageHash, _signature.v, _signature.r, _signature.s);
        (address voter, uint16 weight) = voterRegistry.getVoterWithNormalisedWeight(
            _rewardEpochId, signingPolicyAddress);
        require(voter != address(0), "signature invalid");
        require(state.uptimeVoteVotes[_uptimeVoteHash].voters[voter].signTs == 0, "voter already signed");
        // save signing address timestamp and block number
        state.uptimeVoteVotes[_uptimeVoteHash].voters[voter] =
            VoterData(block.timestamp.toUint64(), block.number.toUint64());
        // check if signing threshold is reached
        bool thresholdReached = state.uptimeVoteVotes[_uptimeVoteHash].accumulatedWeight + weight > state.threshold;
        if (thresholdReached) {
            // save timestamp and block number (this enables rewards signing)
            state.uptimeVoteSignEndTs = block.timestamp.toUint64();
            state.uptimeVoteSignEndBlock = block.number.toUint64();
            uptimeVoteHash[_rewardEpochId] = _uptimeVoteHash;
            delete state.uptimeVoteVotes[_uptimeVoteHash].accumulatedWeight;
        } else {
            // keep collecting signatures
            state.uptimeVoteVotes[_uptimeVoteHash].accumulatedWeight += weight;
        }
        emit UptimeVoteSigned(
            _rewardEpochId,
            signingPolicyAddress,
            voter,
            _uptimeVoteHash,
            block.timestamp.toUint64(),
            thresholdReached
        );
    }

    function signRewards(
        uint24 _rewardEpochId,
        uint64 _noOfWeightBasedClaims,
        bytes32 _rewardsHash,
        Signature calldata _signature
    )
        external
    {
        RewardEpochState storage state = rewardEpochState[_rewardEpochId];
        require(_rewardEpochId < getCurrentRewardEpochId(), "epoch not ended yet");
        require(state.singingPolicySignEndTs != 0, "new signing policy not signed yet");
        require(uptimeVoteHash[_rewardEpochId] != bytes32(0), "uptime vote hash not signed yet");
        require(rewardsHash[_rewardEpochId] == bytes32(0), "rewards hash already signed");
        bytes32 messageHash = keccak256(abi.encode(_rewardEpochId, _noOfWeightBasedClaims, _rewardsHash));
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        address signingPolicyAddress = ECDSA.recover(signedMessageHash, _signature.v, _signature.r, _signature.s);
        (address voter, uint16 weight) =
            voterRegistry.getVoterWithNormalisedWeight(_rewardEpochId, signingPolicyAddress);
        require(voter != address(0), "signature invalid");
        require(state.rewardVotes[messageHash].voters[voter].signTs == 0, "voter already signed");
        // save signing address timestamp and block number
        state.rewardVotes[messageHash].voters[voter] =
            VoterData(block.timestamp.toUint64(), block.number.toUint64());
        // check if signing threshold is reached
        bool thresholdReached = state.rewardVotes[messageHash].accumulatedWeight + weight > state.threshold;
        if (thresholdReached) {
            // save timestamp and block number (this enables claiming)
            state.rewardsSignEndTs = block.timestamp.toUint64();
            state.rewardsSignEndBlock = block.number.toUint64();
            rewardsHash[_rewardEpochId] = _rewardsHash;
            noOfWeightBasedClaims[_rewardEpochId] = _noOfWeightBasedClaims;
            delete state.rewardVotes[messageHash].accumulatedWeight;
        } else {
            // keep collecting signatures
            state.rewardVotes[messageHash].accumulatedWeight += weight;
        }
        emit RewardsSigned(
            _rewardEpochId,
            signingPolicyAddress,
            voter,
            _rewardsHash,
            _noOfWeightBasedClaims,
            block.timestamp.toUint64(),
            thresholdReached
        );
    }

    function setRewardsHash(
        uint24 _rewardEpochId,
        uint64 _noOfWeightBasedClaims,
        bytes32 _rewardsHash
    )
        external onlyGovernance
    {
        require(_rewardEpochId < getCurrentRewardEpochId(), "epoch not ended yet");
        require(rewardsHash[_rewardEpochId] == bytes32(0), "rewards hash already signed");
        rewardsHash[_rewardEpochId] = _rewardsHash;
        noOfWeightBasedClaims[_rewardEpochId] = _noOfWeightBasedClaims;
        emit RewardsSigned(
            _rewardEpochId,
            governance(),
            governance(),
            _rewardsHash,
            _noOfWeightBasedClaims,
            block.timestamp.toUint64(),
            true
        );
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

    function changeRandomProvider(bool _usePriceSubmitter) external onlyGovernance {
        usePriceSubmitterAsRandomProvider = _usePriceSubmitter;
    }

    function setRewardEpochSwitchoverTriggerContracts(
        IRewardEpochSwitchoverTrigger[] calldata _contracts
    )
        external onlyGovernance
    {
        rewardEpochSwitchoverTriggerContracts = _contracts; // TODO cehck duplicates
    }

    function getRewardEpochSwitchoverTriggerContracts() external view returns(IRewardEpochSwitchoverTrigger[] memory) {
        return rewardEpochSwitchoverTriggerContracts;
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

    function isVoterRegistrationEnabled() external view returns (bool) {
        uint256 nextRewardEpochId = getCurrentRewardEpochId() + 1;
        return _isVoterRegistrationEnabled(nextRewardEpochId, rewardEpochState[nextRewardEpochId]);
    }

    // <= PPM_MAX
    function getRewardsFeeBurnFactor(uint64 _rewardEpoch, address _rewardOwner) external view returns(uint256) {
        // TODO
    }

    function getCurrentRandom() external view returns(uint256 _currentRandom) {
        (_currentRandom, , ) = _getRandom();
    }

    function getCurrentRandomWithQuality() external view returns(uint256 _currentRandom, bool _goodRandom) {
        (_currentRandom, _goodRandom, ) = _getRandom();
    }

    /**
     * @inheritdoc IFlareDaemonize
     */
    function switchToFallbackMode() external pure override returns (bool) {
        // do nothing - there is no fallback mode in FlareSystemManager contract
        return false;
    }

    /**
     * @inheritdoc IFlareDaemonize
     */
    function getContractName() external pure override returns (string memory) {
        return "FlareSystemManager";
    }

    function getCurrentRewardEpochId() public view returns(uint24 _currentRewardEpochId) {
        _currentRewardEpochId = _getCurrentRewardEpochId();
        if (_isNextRewardEpochId(_currentRewardEpochId + 1)) {
            // first transaction in the block (daemonize() call will change `currentRewardEpochExpectedEndTs` value)
            _currentRewardEpochId += 1;
        }
    }

    function _selectVotePowerBlock(uint24 _nextRewardEpochId, uint256 _random) internal {
        // randomTs > state.randomAcquisitionStartTs && randomQuality == true
        RewardEpochState storage state = rewardEpochState[_nextRewardEpochId];
        uint64 endBlock = state.randomAcquisitionStartBlock;
        uint64 numberOfBlocks;
        if (rewardEpochState[_nextRewardEpochId - 1].randomAcquisitionStartBlock == 0) {
            // endBlock > 0 && firstRandomAcquisitionNumberOfBlocks > 0
            numberOfBlocks = Math.min(endBlock, firstRandomAcquisitionNumberOfBlocks).toUint64();
        } else {
            // endBlock > rewardEpochState[_nextRewardEpochId - 1].randomAcquisitionStartBlock
            numberOfBlocks = endBlock - rewardEpochState[_nextRewardEpochId - 1].randomAcquisitionStartBlock;
        }

        //slither-disable-next-line weak-prng
        uint256 votepowerBlocksAgo = _random % numberOfBlocks; // numberOfBlocks > 0
        if (votepowerBlocksAgo == 0) {
            votepowerBlocksAgo = 1;
        }
        uint64 votePowerBlock = endBlock - votepowerBlocksAgo.toUint64(); // endBlock > 0
        state.votePowerBlock = votePowerBlock;
        state.seed = _random;

        emit VotePowerBlockSelected(_nextRewardEpochId, votePowerBlock, block.timestamp.toUint64());
    }

    function _initializeNextSigningPolicy(uint24 _nextRewardEpochId) internal {
        RewardEpochState storage state = rewardEpochState[_nextRewardEpochId];
        Relay.SigningPolicy memory signingPolicy;
        signingPolicy.rewardEpochId = _nextRewardEpochId;
        signingPolicy.startVotingRoundId = _getStartVotingRoundId();
        uint256 normalisedWeightsSum;
        (signingPolicy.voters, signingPolicy.weights, normalisedWeightsSum) =
            voterRegistry.createSigningPolicySnapshot(_nextRewardEpochId);
        signingPolicy.threshold = normalisedWeightsSum.mulDivRoundUp(signingPolicyThresholdPPM, PPM_MAX).toUint16();
        signingPolicy.seed = state.seed;

        state.startVotingRoundId = signingPolicy.startVotingRoundId;
        state.threshold = signingPolicy.threshold;
        relay.setSigningPolicy(signingPolicy);
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
        voterRegistry = VoterRegistry(
            _getContractAddress(_contractNameHashes, _contractAddresses, "VoterRegistry"));
        submission = Submission(_getContractAddress(_contractNameHashes, _contractAddresses, "Submission"));
        relay = Relay(_getContractAddress(_contractNameHashes, _contractAddresses, "Relay"));
        priceSubmitter = IPriceSubmitter(
            _getContractAddress(_contractNameHashes, _contractAddresses, "PriceSubmitter"));
    }

    function _getCurrentRewardEpochId() internal view returns(uint24) {
        return (uint256(currentRewardEpochExpectedEndTs - rewardEpochsStartTs) / rewardEpochDurationSeconds - 1)
            .toUint24();
    }

    function _isNextRewardEpochId(uint24 _nextRewardEpochId) internal view returns (bool) {
        return block.timestamp >= currentRewardEpochExpectedEndTs &&
            _getSingingPolicyHash(_nextRewardEpochId) != bytes32(0) &&
            _getCurrentVotingEpochId() >= rewardEpochState[_nextRewardEpochId].startVotingRoundId;
    }

    function _getCurrentVotingEpochId() internal view returns(uint32) {
        return ((block.timestamp - firstVotingRoundStartTs) / votingEpochDurationSeconds).toUint32();
    }

    function _getSingingPolicyHash(uint24 _rewardEpoch) internal view returns (bytes32) {
        return relay.toSigningPolicyHash(_rewardEpoch);
    }

    /**
     * voter registration is enabled until enough time has passed and enough blocks have been created
     * or until a minimum number of voters have been registered.
     */
    function _isVoterRegistrationEnabled(
        uint256 _rewardEpoch,
        RewardEpochState storage _state
    )
        internal view
        returns(bool)
    {
        return _state.voterRegistrationStartTs != 0 && (
            block.timestamp <= _state.voterRegistrationStartTs + voterRegistrationMinDurationSeconds ||
            block.number <= _state.voterRegistrationStartBlock + voterRegistrationMinDurationBlocks ||
            voterRegistry.getNumberOfRegisteredVoters(_rewardEpoch) < signingPolicyMinNumberOfVoters);
    }

    function _getRandom() internal view returns (uint256 _random, bool _quality, uint64 _randomTs) {
        if (usePriceSubmitterAsRandomProvider) {
            return (priceSubmitter.getCurrentRandom(), true, block.timestamp.toUint64());
        }
        return relay.getRandomNumber();
    }

    function _getStartVotingRoundId() internal view returns (uint32 _startVotingRoundId) {
        uint256 timeFromStart = currentRewardEpochExpectedEndTs;
        if (block.timestamp >= timeFromStart) {
            timeFromStart = block.timestamp.toUint64() + 1; // start in next block
        }
        // currentRewardEpochExpectedEndTs >= rewardEpochsStartTs >= firstVotingRoundStartTs
        timeFromStart -= firstVotingRoundStartTs;
        _startVotingRoundId = (timeFromStart / votingEpochDurationSeconds).toUint32();
        // if in the middle of voting round start with the next one
        //slither-disable-next-line weak-prng //not a random
        if (timeFromStart % votingEpochDurationSeconds != 0) {
            _startVotingRoundId += 1;
        }
    }
}
