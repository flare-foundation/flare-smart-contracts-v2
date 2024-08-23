// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "flare-smart-contracts/contracts/genesis/interface/IFlareDaemonize.sol";
import "../../governance/implementation/Governed.sol";
import "../../utils/implementation/AddressUpdatable.sol";
import "../../utils/lib/SafePct.sol";
import "../interface/IIRewardEpochSwitchoverTrigger.sol";
import "../interface/IIVoterRegistrationTrigger.sol";
import "../interface/IICleanupBlockNumberManager.sol";
import "../interface/IIFlareSystemsManager.sol";
import "../interface/IIVoterRegistry.sol";
import "../interface/IIRewardManager.sol";
import "../interface/IIRelay.sol";
import "../interface/IISubmission.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * FlareSystemsManager is responsible for initialization of reward epochs and voting rounds using FlareDaemon calls.
 * This contract is also used for managing signing policies, uptime votes and rewards.
 */
//solhint-disable-next-line max-states-count
contract FlareSystemsManager is Governed, AddressUpdatable, IFlareDaemonize, IIFlareSystemsManager {
    using SafeCast for uint256;
    using SafePct for uint256;

    /// Updatable settings.
    struct Settings {
        uint16 randomAcquisitionMaxDurationSeconds;
        uint16 randomAcquisitionMaxDurationBlocks;
        uint16 newSigningPolicyInitializationStartSeconds;
        uint8 newSigningPolicyMinNumberOfVotingRoundsDelay;
        uint16 voterRegistrationMinDurationSeconds;
        uint16 voterRegistrationMinDurationBlocks;
        uint16 submitUptimeVoteMinDurationSeconds;
        uint16 submitUptimeVoteMinDurationBlocks;
        uint24 signingPolicyThresholdPPM;
        uint16 signingPolicyMinNumberOfVoters;
        uint32 rewardExpiryOffsetSeconds;
    }

    /// Initial settings.
    struct InitialSettings {
        uint16 initialRandomVotePowerBlockSelectionSize;
        uint24 initialRewardEpochId;
        uint16 initialRewardEpochThreshold;
    }

    /// Voter data - timestamp and block number of signing
    struct VoterData {
        uint64 signTs;
        uint64 signBlock;
    }

    /// Votes - accumulated weight and voters
    struct Votes {
        uint16 accumulatedWeight;
        mapping(address => VoterData) voters;
    }

    /// Reward epoch state
    struct RewardEpochState {
        uint64 randomAcquisitionStartTs;
        uint64 randomAcquisitionStartBlock;
        uint64 randomAcquisitionEndTs; // vote power block selected, voter registration start
        uint64 randomAcquisitionEndBlock;

        uint64 signingPolicySignStartTs; // voter registration end, new signing policy defined
        uint64 signingPolicySignStartBlock;
        uint64 signingPolicySignEndTs;
        uint64 signingPolicySignEndBlock;

        uint64 rewardsSignStartTs; // uptime vote sign end
        uint64 rewardsSignStartBlock;
        uint64 rewardsSignEndTs;
        uint64 rewardsSignEndBlock;

        uint64 rewardEpochStartTs;
        uint64 rewardEpochStartBlock;

        uint64 uptimeVoteSignStartTs; // uptime vote submit end
        uint64 uptimeVoteSignStartBlock;

        uint256 seed; // secure random number
        uint64 votePowerBlock;
        uint32 startVotingRoundId;
        uint16 threshold; // absolute value in normalised weight

        Votes signingPolicyVotes;
        Votes submitUptimeVoteVotes;
        mapping(bytes32 uptimeVoteHash => Votes) uptimeVoteVotes;
        mapping(bytes32 rewardsVoteHash => Votes) rewardVotes;
    }


    uint256 internal constant UINT16_MAX = type(uint16).max;
    uint256 internal constant UINT256_MAX = type(uint256).max;
    uint256 internal constant PPM_MAX = 1e6;

    /// The FlareDaemon contract, set at construction time.
    address public immutable flareDaemon;

    /// Timestamp when the first reward epoch started, in seconds since UNIX epoch.
    uint64 public immutable firstRewardEpochStartTs;
    /// Duration of reward epochs, in seconds.
    uint64 public immutable rewardEpochDurationSeconds;
    /// Timestamp when the first voting epoch started, in seconds since UNIX epoch.
    uint64 public immutable firstVotingRoundStartTs;
    /// Duration of voting epochs, in seconds.
    uint64 public immutable votingEpochDurationSeconds;

    /// Number of blocks used for initial random vote power block selection.
    uint64 public immutable initialRandomVotePowerBlockSelectionSize;

    /// Reward epoch state for given reward epoch
    mapping(uint256 rewardEpochId => RewardEpochState) internal rewardEpochState;

    /// Uptime vote hash for given reward epoch id
    mapping(uint256 rewardEpochId => bytes32) public uptimeVoteHash;

    /// Rewards hash for given reward epoch id
    mapping(uint256 rewardEpochId => bytes32) public rewardsHash;

    /// Number of weight based claims for given reward epoch id and reward manager id
    mapping(uint256 rewardEpochId => mapping(uint256 rewardManagerId => uint256)) public noOfWeightBasedClaims;
    /// Hash of number of weight based claims for given reward epoch id
    mapping(uint256 rewardEpochId => bytes32) public noOfWeightBasedClaimsHash;

    // Signing policy settings
    /// Maximum duration of random acquisition phase, in seconds.
    uint64 public randomAcquisitionMaxDurationSeconds; // 8 hours
    /// Maximum duration of random acquisition phase, in blocks.
    uint64 public randomAcquisitionMaxDurationBlocks; // 15000
    /// Time before reward epoch end when new signing policy initialization starts, in seconds.
    uint64 public newSigningPolicyInitializationStartSeconds; // 2 hours
    /// Minimum delay before new signing policy can be active, in voting rounds.
    uint32 public newSigningPolicyMinNumberOfVotingRoundsDelay; // 3
    /// Reward epoch expiry offset, in seconds.
    uint32 public rewardExpiryOffsetSeconds;
    /// Minimum duration of voter registration phase, in seconds.
    uint64 public voterRegistrationMinDurationSeconds; // 30 minutes
    /// Minimum duration of voter registration phase, in blocks.
    uint64 public voterRegistrationMinDurationBlocks; // 900
    /// Minimum duration of submit uptime vote phase, in seconds.
    uint64 public submitUptimeVoteMinDurationSeconds; // 10 minutes
    /// Minimum duration of submit uptime vote phase, in blocks.
    uint64 public submitUptimeVoteMinDurationBlocks; // 300 blocks
    /// Signing policy threshold, in parts per million.
    uint24 public signingPolicyThresholdPPM;
    /// Minimum number of voters for signing policy.
    uint16 public signingPolicyMinNumberOfVoters;
    /// Indicates if submit3 method is aligned with current reward epoch submit addresses.
    bool public submit3Aligned = true;
    /// Indicates if rewards epoch expiration and vote power block cleanup should be triggered after each epoch.
    bool public triggerExpirationAndCleanup = false;

    /// Timestamp when current reward epoch should end, in seconds since UNIX epoch.
    uint64 public currentRewardEpochExpectedEndTs;

    /// The last voting round id that was initialized.
    uint32 public lastInitializedVotingRoundId;

    /// The reward epoch id that will expire next.
    uint24 public rewardEpochIdToExpireNext;

    /// The last reward epoch id with sign uptime vote enabled.
    uint24 internal lastRewardEpochIdWithSignUptimeVoteEnabled;

    /// The VoterRegistry contract.
    IIVoterRegistry public voterRegistry;
    /// The Submission contract.
    IISubmission public submission;
    /// The Relay contract.
    IIRelay public relay;
    /// The RewardManager contract.
    IIRewardManager public rewardManager;
    /// The CleanupBlockNumberManager contract.
    IICleanupBlockNumberManager public cleanupBlockNumberManager;
    /// The VoterRegistrationTrigger contract.
    IIVoterRegistrationTrigger public voterRegistrationTriggerContract;
    /// Reward epoch switchover trigger contracts.
    IIRewardEpochSwitchoverTrigger[] internal rewardEpochSwitchoverTriggerContracts;

    /// Modifier for allowing only FlareDaemon contract to call the method.
    modifier onlyFlareDaemon {
        _checkOnlyFlareDaemon();
        _;
    }

    /// Modifier for allowing only if reward epoch is initialized.
    modifier onlyIfInitialized(uint256 _rewardEpochId) {
        _checkIfInitialized(_rewardEpochId);
        _;
    }

    /**
     * @dev Constructor.
     * @param _governanceSettings The address of the GovernanceSettings contract.
     * @param _initialGovernance The initial governance address.
     * @param _addressUpdater The address of the AddressUpdater contract.
     * @param _flareDaemon The address of the FlareDaemon contract.
     * @param _settings Updatable settings.
     * @param _firstVotingRoundStartTs Timestamp when the first voting round started, in seconds since UNIX epoch.
     * @param _votingEpochDurationSeconds Duration of voting epochs, in seconds.
     * @param _firstRewardEpochStartVotingRoundId First voting round id of the first reward epoch.
     * @param _rewardEpochDurationInVotingEpochs Duration of reward epochs, in voting epochs.
     * @param _initialSettings Initial settings.
     */
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        address _flareDaemon,
        Settings memory _settings,
        uint32 _firstVotingRoundStartTs,
        uint8 _votingEpochDurationSeconds,
        uint32 _firstRewardEpochStartVotingRoundId,
        uint16 _rewardEpochDurationInVotingEpochs,
        InitialSettings memory _initialSettings
    )
        Governed(_governanceSettings, _initialGovernance) AddressUpdatable(_addressUpdater)
    {
        require(_flareDaemon != address(0), "flare daemon zero");
        require(_rewardEpochDurationInVotingEpochs > 0, "reward epoch duration zero");
        require(_votingEpochDurationSeconds > 0, "voting epoch duration zero");
        require(_initialSettings.initialRandomVotePowerBlockSelectionSize > 0, "zero blocks");

        // set updatable settings
        _updateSettings(_settings);

        // set immutable settings
        flareDaemon = _flareDaemon;
        firstVotingRoundStartTs = _firstVotingRoundStartTs;
        votingEpochDurationSeconds = _votingEpochDurationSeconds;
        firstRewardEpochStartTs = _firstVotingRoundStartTs +
            _firstRewardEpochStartVotingRoundId * _votingEpochDurationSeconds;
        rewardEpochDurationSeconds = uint64(_rewardEpochDurationInVotingEpochs) * _votingEpochDurationSeconds;
        initialRandomVotePowerBlockSelectionSize = _initialSettings.initialRandomVotePowerBlockSelectionSize;

        rewardEpochIdToExpireNext = _initialSettings.initialRewardEpochId + 1; // no vote power block in initial epoch
        lastRewardEpochIdWithSignUptimeVoteEnabled = _initialSettings.initialRewardEpochId;
        currentRewardEpochExpectedEndTs = firstRewardEpochStartTs +
            (_initialSettings.initialRewardEpochId + 1) * rewardEpochDurationSeconds;
        rewardEpochState[_initialSettings.initialRewardEpochId].threshold =
            _initialSettings.initialRewardEpochThreshold;
        require(
            currentRewardEpochExpectedEndTs > block.timestamp + _settings.newSigningPolicyInitializationStartSeconds,
            "reward epoch end not in the future");
    }

    /**
     * @inheritdoc IFlareDaemonize
     */
    function daemonize() external onlyFlareDaemon returns (bool) {
        uint32 currentVotingEpochId = _getCurrentVotingEpochId();
        uint24 currentRewardEpochId = _getCurrentRewardEpochId();
        uint24 initializationRewardEpochId = currentRewardEpochId;

        if (block.timestamp >= currentRewardEpochExpectedEndTs - newSigningPolicyInitializationStartSeconds) {
            uint24 nextRewardEpochId = currentRewardEpochId + 1;

            // check if new signing policy is already defined
            if (_getSigningPolicyHash(nextRewardEpochId) == bytes32(0)) {
                RewardEpochState storage state = rewardEpochState[nextRewardEpochId];
                if (state.randomAcquisitionStartTs == 0) {
                    state.randomAcquisitionStartTs = block.timestamp.toUint64();
                    state.randomAcquisitionStartBlock = block.number.toUint64();
                    voterRegistry.setNewSigningPolicyInitializationStartBlockNumber(nextRewardEpochId);
                    emit RandomAcquisitionStarted(nextRewardEpochId, block.timestamp.toUint64());
                } else if (state.randomAcquisitionEndTs == 0) {
                    (uint256 random, bool isSecureRandom, uint256 randomTs) = relay.getRandomNumber();
                    uint64 votePowerBlock = 0;
                    if (randomTs > state.randomAcquisitionStartTs && isSecureRandom) {
                        votePowerBlock = _selectVotePowerBlock(nextRewardEpochId, random);
                    } else if (state.randomAcquisitionStartBlock + randomAcquisitionMaxDurationBlocks < block.number &&
                        state.randomAcquisitionStartTs + randomAcquisitionMaxDurationSeconds < block.timestamp)
                    {
                        // use current vote power block => same voters
                        votePowerBlock = rewardEpochState[currentRewardEpochId].votePowerBlock;
                        if (votePowerBlock != 0) {
                            // use current random as well
                            random = rewardEpochState[currentRewardEpochId].seed;
                        } else {
                            // in case of initial reward epoch just use unsecure random
                            votePowerBlock = _selectVotePowerBlock(nextRewardEpochId, random);
                        }
                    }
                    if (votePowerBlock != 0) { // vote power block was selected
                        assert(votePowerBlock < block.number);
                        state.randomAcquisitionEndTs = block.timestamp.toUint64();
                        state.randomAcquisitionEndBlock = block.number.toUint64();
                        state.votePowerBlock = votePowerBlock;
                        state.seed = random;
                        emit VotePowerBlockSelected(nextRewardEpochId, votePowerBlock, block.timestamp.toUint64());

                        if (address(voterRegistrationTriggerContract) != address(0)) {
                            _triggerVoterRegistration(nextRewardEpochId);
                        }
                    }
                } else if (!_isVoterRegistrationEnabled(nextRewardEpochId, state)) {
                    // state.signingPolicySignStartTs == 0
                    state.signingPolicySignStartTs = block.timestamp.toUint64();
                    state.signingPolicySignStartBlock = block.number.toUint64();
                    _initializeNextSigningPolicy(nextRewardEpochId);
                }
            }

            // start new reward epoch if it is time and new signing policy is defined
            if (_isNextRewardEpochId(nextRewardEpochId)) {
                currentRewardEpochId = nextRewardEpochId;
                currentRewardEpochExpectedEndTs += rewardEpochDurationSeconds; // update storage value
                rewardEpochState[currentRewardEpochId].rewardEpochStartTs = block.timestamp.toUint64();
                rewardEpochState[currentRewardEpochId].rewardEpochStartBlock = block.number.toUint64();
                emit RewardEpochStarted(
                    currentRewardEpochId,
                    rewardEpochState[currentRewardEpochId].startVotingRoundId,
                    block.timestamp.toUint64()
                );
                if (triggerExpirationAndCleanup) {
                    // close expired reward epochs and cleanup vote power block
                    _closeExpiredRewardEpochs(currentRewardEpochId);
                    _cleanupOnRewardEpochFinalization();
                }
                _triggerRewardEpochSwitchover(currentRewardEpochId, currentRewardEpochExpectedEndTs);
            }
        }

        // in case of new voting round - init new voting round on Submission contract
        if (currentVotingEpochId > lastInitializedVotingRoundId) {
            address[] memory submit1Addresses;
            address[] memory submit2Addresses;
            address[] memory submitSignaturesAddresses;
            lastInitializedVotingRoundId = currentVotingEpochId;
            submit2Addresses = voterRegistry.getRegisteredSubmitAddresses(initializationRewardEpochId);
            submitSignaturesAddresses =
                voterRegistry.getRegisteredSubmitSignaturesAddresses(initializationRewardEpochId);
            // in case of new reward epoch - get new submit1Addresses otherwise they are the same as submit2Addresses
            if (currentRewardEpochId > initializationRewardEpochId) {
                submit1Addresses = voterRegistry.getRegisteredSubmitAddresses(currentRewardEpochId);
            } else {
                submit1Addresses = submit2Addresses;
            }
            submission.initNewVotingRound(
                submit1Addresses,
                submit2Addresses,
                submit3Aligned ? submit1Addresses : submit2Addresses,
                submitSignaturesAddresses
            );
        }

        // is it time to enable sign uptime vote
        uint24 signUptimeVoteRewardEpochId = lastRewardEpochIdWithSignUptimeVoteEnabled + 1;
        if (currentRewardEpochId > signUptimeVoteRewardEpochId &&
            rewardEpochState[signUptimeVoteRewardEpochId].uptimeVoteSignStartTs == 0)
        {
            // signUptimeVoteRewardEpochId + 1 <= currentRewardEpochId -> rewardEpochStartTs/Block != 0
            RewardEpochState storage nextState = rewardEpochState[signUptimeVoteRewardEpochId + 1];
            if (nextState.rewardEpochStartTs + submitUptimeVoteMinDurationSeconds < block.timestamp &&
                nextState.rewardEpochStartBlock + submitUptimeVoteMinDurationBlocks < block.number)
            {
                lastRewardEpochIdWithSignUptimeVoteEnabled = signUptimeVoteRewardEpochId;
                rewardEpochState[signUptimeVoteRewardEpochId].uptimeVoteSignStartTs = block.timestamp.toUint64();
                rewardEpochState[signUptimeVoteRewardEpochId].uptimeVoteSignStartBlock = block.number.toUint64();
                emit SignUptimeVoteEnabled(signUptimeVoteRewardEpochId, block.timestamp.toUint64());
            }
        }

        // if cleanup is triggered elsewhere, check if it is time to close some reward epochs with cleaned up block
        if (!triggerExpirationAndCleanup) {
            uint256 cleanupBlockNumber = rewardManager.cleanupBlockNumber();
            while (rewardEpochIdToExpireNext < currentRewardEpochId &&
                rewardEpochState[rewardEpochIdToExpireNext].votePowerBlock < cleanupBlockNumber)
            {
                try rewardManager.closeExpiredRewardEpoch(rewardEpochIdToExpireNext) {
                    rewardEpochIdToExpireNext++;
                } catch {
                    emit ClosingExpiredRewardEpochFailed(rewardEpochIdToExpireNext);
                    // Do not proceed with the loop.
                    break;
                }
            }
        }

        return true;
    }

    /**
     * @inheritdoc IFlareSystemsManager
     */
    function signNewSigningPolicy(
        uint24 _rewardEpochId,
        bytes32 _newSigningPolicyHash,
        Signature calldata _signature
    )
        external
    {
        require(_newSigningPolicyHash != bytes32(0) && _getSigningPolicyHash(_rewardEpochId) == _newSigningPolicyHash,
            "new signing policy hash invalid");
        RewardEpochState storage state = rewardEpochState[_rewardEpochId];
        require(state.signingPolicySignEndTs == 0, "new signing policy already signed");
        (address signingPolicyAddress, address voter, uint16 weight) =
            _getVoterData(_rewardEpochId - 1, _newSigningPolicyHash, _signature);
        _checkIfVoterAlreadySigned(state.signingPolicyVotes.voters[voter].signTs);
        // save voter's timestamp and block number
        state.signingPolicyVotes.voters[voter] = VoterData(block.timestamp.toUint64(), block.number.toUint64());
        // check if signing threshold is reached (use previous epoch threshold)
        bool thresholdReached =
            state.signingPolicyVotes.accumulatedWeight + weight > rewardEpochState[_rewardEpochId - 1].threshold;
        if (thresholdReached) {
            // save timestamp and block number (this enables rewards signing)
            state.signingPolicySignEndTs = block.timestamp.toUint64();
            state.signingPolicySignEndBlock = block.number.toUint64();
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

    /**
     * @inheritdoc IFlareSystemsManager
     */
    function submitUptimeVote(
        uint24 _rewardEpochId,
        bytes20[] calldata _nodeIds,
        Signature calldata _signature
    )
        external
    {
        _checkIfPastRewardEpoch(_rewardEpochId);
        RewardEpochState storage state = rewardEpochState[_rewardEpochId];
        require(state.uptimeVoteSignStartTs == 0, "submit uptime vote already ended");
        bytes32 messageHash = keccak256(abi.encode(_rewardEpochId, _nodeIds));
        (address signingPolicyAddress, address voter, ) =
            _getVoterData(_rewardEpochId, messageHash, _signature);
        // save voter's timestamp and block number (overrides previous submit)
        state.submitUptimeVoteVotes.voters[voter] = VoterData(block.timestamp.toUint64(), block.number.toUint64());
        emit UptimeVoteSubmitted(
            _rewardEpochId,
            signingPolicyAddress,
            voter,
            _nodeIds,
            block.timestamp.toUint64()
        );
    }

    /**
     * @inheritdoc IFlareSystemsManager
     */
    function signUptimeVote(
        uint24 _rewardEpochId,
        bytes32 _uptimeVoteHash,
        Signature calldata _signature
    )
        external
    {
        require(_uptimeVoteHash != bytes32(0), "uptime vote hash zero");
        _checkIfPastRewardEpoch(_rewardEpochId);
        RewardEpochState storage state = rewardEpochState[_rewardEpochId];
        require(state.uptimeVoteSignStartTs != 0, "sign uptime vote not started yet");
        require(uptimeVoteHash[_rewardEpochId] == bytes32(0), "uptime vote hash already signed");
        bytes32 messageHash = keccak256(abi.encode(_rewardEpochId, _uptimeVoteHash));
        (address signingPolicyAddress, address voter, uint16 weight) =
            _getVoterData(_rewardEpochId, messageHash, _signature);
        _checkIfVoterAlreadySigned(state.uptimeVoteVotes[_uptimeVoteHash].voters[voter].signTs);
        // save voter's timestamp and block number
        state.uptimeVoteVotes[_uptimeVoteHash].voters[voter] =
            VoterData(block.timestamp.toUint64(), block.number.toUint64());
        // check if signing threshold is reached
        bool thresholdReached = state.uptimeVoteVotes[_uptimeVoteHash].accumulatedWeight + weight > state.threshold;
        if (thresholdReached) {
            // save timestamp and block number (this enables rewards signing)
            state.rewardsSignStartTs = block.timestamp.toUint64();
            state.rewardsSignStartBlock = block.number.toUint64();
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

    /**
     * @inheritdoc IFlareSystemsManager
     */
    function signRewards(
        uint24 _rewardEpochId,
        NumberOfWeightBasedClaims[] calldata _noOfWeightBasedClaims,
        bytes32 _rewardsHash,
        Signature calldata _signature
    )
        external
    {
        _checkConditionsForSigningRewards(_rewardEpochId, _rewardsHash);
        _checkIsUptimeVoteHashSigned(_rewardEpochId);
        require(rewardsHash[_rewardEpochId] == bytes32(0), "rewards hash already signed");
        bytes32 messageHash = keccak256(abi.encode(
            _rewardEpochId, keccak256(abi.encode(_noOfWeightBasedClaims)), _rewardsHash));
        (address signingPolicyAddress, address voter, uint16 weight) =
            _getVoterData(_rewardEpochId, messageHash, _signature);
        RewardEpochState storage state = rewardEpochState[_rewardEpochId];
        _checkIfVoterAlreadySigned(state.rewardVotes[messageHash].voters[voter].signTs);
        // save voter's timestamp and block number
        state.rewardVotes[messageHash].voters[voter] =
            VoterData(block.timestamp.toUint64(), block.number.toUint64());
        // check if signing threshold is reached
        bool thresholdReached = state.rewardVotes[messageHash].accumulatedWeight + weight > state.threshold;
        if (thresholdReached) {
            // save timestamp and block number (this enables claiming)
            state.rewardsSignEndTs = block.timestamp.toUint64();
            state.rewardsSignEndBlock = block.number.toUint64();
            delete state.rewardVotes[messageHash].accumulatedWeight;
        } else {
            // keep collecting signatures
            state.rewardVotes[messageHash].accumulatedWeight += weight;
        }
        _updateRewardsHashAndEmitRewardsSigned(
            _rewardEpochId,
            signingPolicyAddress,
            voter,
            _rewardsHash,
            _noOfWeightBasedClaims,
            thresholdReached
        );
    }

    /**
     * Method for setting rewards hash and number of weight based claims.
     * @param _rewardEpochId Reward epoch id of the rewards.
     * @param _noOfWeightBasedClaims Number of weight based claims.
     * @param _rewardsHash Rewards hash.
     * @dev Only governance can call this method.
     * @dev Note that in case _noOfWeightBasedClaims were already set, they are not deleted and have to be overwritten.
     */
    function setRewardsData(
        uint24 _rewardEpochId,
        NumberOfWeightBasedClaims[] calldata _noOfWeightBasedClaims,
        bytes32 _rewardsHash
    )
        external onlyImmediateGovernance
    {
        _checkConditionsForSigningRewards(_rewardEpochId, _rewardsHash);
        _updateRewardsHashAndEmitRewardsSigned(
            _rewardEpochId,
            governance(),
            governance(),
            _rewardsHash,
            _noOfWeightBasedClaims,
            true
        );
    }

    /**
     * Sets whether to trigger rewards epoch expiration and vote power block cleanup after each epoch.
     * @dev Only governance can call this method.
     */
    function setTriggerExpirationAndCleanup(bool _triggerExpirationAndCleanup) external onlyGovernance {
        triggerExpirationAndCleanup = _triggerExpirationAndCleanup;
    }

    /**
     * Sets whether submit3 method is aligned with current reward epoch submit addresses.
     * @dev Only governance can call this method.
     */
    function setSubmit3Aligned(bool _submit3Aligned) external onlyGovernance {
        submit3Aligned = _submit3Aligned;
    }

    /**
     * Sets the voter registration trigger contract.
     * @param _contract The new voter registration trigger contract.
     * @dev Only governance can call this method.
     */
    function setVoterRegistrationTriggerContract(
        IIVoterRegistrationTrigger _contract
    )
        external onlyGovernance
    {
        voterRegistrationTriggerContract = _contract;
    }

    /**
     *  Updates the settings.
     *  @param _settings The new settings.
     *  @dev Only governance can call this method.
     */
    function updateSettings(Settings memory _settings) external onlyGovernance {
        _updateSettings(_settings);
    }

    /**
     * Sets the reward epoch switchover trigger contracts.
     * @param _contracts The new reward epoch switchover trigger contracts.
     * @dev Only governance can call this method.
     */
    function setRewardEpochSwitchoverTriggerContracts(
        IIRewardEpochSwitchoverTrigger[] calldata _contracts
    )
        external onlyGovernance
    {
        delete rewardEpochSwitchoverTriggerContracts;
        uint256 length = _contracts.length;
        for (uint256 i = 0; i < length; i++) {
            IIRewardEpochSwitchoverTrigger contractAddress = _contracts[i];
            for (uint256 j = i + 1; j < length; j++) {
                require(contractAddress != _contracts[j], "duplicated contracts");
            }
            rewardEpochSwitchoverTriggerContracts.push(contractAddress);
        }
    }

    /**
     * Returns the reward epoch switchover trigger contracts.
     */
    function getRewardEpochSwitchoverTriggerContracts()
        external view
        returns(IIRewardEpochSwitchoverTrigger[] memory)
    {
        return rewardEpochSwitchoverTriggerContracts;
    }

    /**
     * @inheritdoc ProtocolsV2Interface
     */
    function getVotePowerBlock(uint256 _rewardEpochId)
        external view
        returns(uint64 _votePowerBlock)
    {
        _votePowerBlock = rewardEpochState[_rewardEpochId].votePowerBlock;
        require(_votePowerBlock != 0, "vote power block not initialized yet");
    }

    /**
     * @inheritdoc IFlareSystemsManager
     */
    function getSeed(uint256 _rewardEpochId)
        external view
        returns(uint256)
    {
        // check votePowerBlock, seed can be zero
        require(rewardEpochState[_rewardEpochId].votePowerBlock != 0, "seed not initialized yet");
        return rewardEpochState[_rewardEpochId].seed;
    }

    /**
     * @inheritdoc ProtocolsV2Interface
     */
    function getStartVotingRoundId(uint256 _rewardEpochId)
        external view
        onlyIfInitialized(_rewardEpochId)
        returns(uint32)
    {
        return rewardEpochState[_rewardEpochId].startVotingRoundId;
    }

    /**
     * @inheritdoc IFlareSystemsManager
     */
    function getThreshold(uint256 _rewardEpochId)
        external view
        onlyIfInitialized(_rewardEpochId)
        returns(uint16)
    {
        return rewardEpochState[_rewardEpochId].threshold;
    }

    /**
     * @inheritdoc IFlareSystemsManager
     */
    function getVoterRegistrationData(
        uint256 _rewardEpochId
    )
        external view
        returns (
            uint256 _votePowerBlock,
            bool _enabled
        )
    {
        _votePowerBlock = rewardEpochState[_rewardEpochId].votePowerBlock;
        _enabled = _isVoterRegistrationEnabled(_rewardEpochId, rewardEpochState[_rewardEpochId]);
    }

    /**
     * @inheritdoc IFlareSystemsManager
     */
    function isVoterRegistrationEnabled() external view returns (bool) {
        uint256 nextRewardEpochId = _getCurrentRewardEpochId() + 1;
        return _isVoterRegistrationEnabled(nextRewardEpochId, rewardEpochState[nextRewardEpochId]);
    }

    /**
     * @inheritdoc IIFlareSystemsManager
     */
    function getRewardEpochStartInfo(uint24 _rewardEpochId)
        external view
        returns(
            uint64 _rewardEpochStartTs,
            uint64 _rewardEpochStartBlock
        )
    {
        RewardEpochState storage state = rewardEpochState[_rewardEpochId];
        _rewardEpochStartTs = state.rewardEpochStartTs;
        _rewardEpochStartBlock = state.rewardEpochStartBlock;
    }

    /**
     * @inheritdoc IIFlareSystemsManager
     */
    function getRandomAcquisitionInfo(uint24 _rewardEpochId)
        external view
        returns(
            uint64 _randomAcquisitionStartTs,
            uint64 _randomAcquisitionStartBlock,
            uint64 _randomAcquisitionEndTs,
            uint64 _randomAcquisitionEndBlock
        )
    {
        RewardEpochState storage state = rewardEpochState[_rewardEpochId];
        _randomAcquisitionStartTs = state.randomAcquisitionStartTs;
        _randomAcquisitionStartBlock = state.randomAcquisitionStartBlock;
        _randomAcquisitionEndTs = state.randomAcquisitionEndTs;
        _randomAcquisitionEndBlock = state.randomAcquisitionEndBlock;
    }

    /**
     * @inheritdoc IIFlareSystemsManager
     */
    function getVoterSigningPolicySignInfo(uint24 _rewardEpochId, address _voter)
        external view
        returns(
            uint64 _signingPolicySignTs,
            uint64 _signingPolicySignBlock
        )
    {
        RewardEpochState storage state = rewardEpochState[_rewardEpochId];
        VoterData storage data = state.signingPolicyVotes.voters[_voter];
        _signingPolicySignTs = data.signTs;
        _signingPolicySignBlock = data.signBlock;
    }

    /**
     * @inheritdoc IIFlareSystemsManager
     */
    function getSigningPolicySignInfo(uint24 _rewardEpochId)
        external view
        returns(
            uint64 _signingPolicySignStartTs,
            uint64 _signingPolicySignStartBlock,
            uint64 _signingPolicySignEndTs,
            uint64 _signingPolicySignEndBlock
        )
    {
        RewardEpochState storage state = rewardEpochState[_rewardEpochId];
        _signingPolicySignStartTs = state.signingPolicySignStartTs;
        _signingPolicySignStartBlock = state.signingPolicySignStartBlock;
        _signingPolicySignEndTs = state.signingPolicySignEndTs;
        _signingPolicySignEndBlock = state.signingPolicySignEndBlock;
    }

    /**
     * @inheritdoc IIFlareSystemsManager
     */
    function getVoterUptimeVoteSubmitInfo(uint24 _rewardEpochId, address _voter)
        external view
        returns(
            uint64 _uptimeVoteSubmitTs,
            uint64 _uptimeVoteSubmitBlock
        )
    {
        RewardEpochState storage state = rewardEpochState[_rewardEpochId];
        VoterData storage data = state.submitUptimeVoteVotes.voters[_voter];
        _uptimeVoteSubmitTs = data.signTs;
        _uptimeVoteSubmitBlock = data.signBlock;
    }

    /**
     * @inheritdoc IIFlareSystemsManager
     */
    function getVoterUptimeVoteSignInfo(uint24 _rewardEpochId, address _voter)
        external view
        returns(
            uint64 _uptimeVoteSignTs,
            uint64 _uptimeVoteSignBlock
        )
    {
        _checkIsUptimeVoteHashSigned(_rewardEpochId);
        RewardEpochState storage state = rewardEpochState[_rewardEpochId];
        VoterData storage data = state.uptimeVoteVotes[uptimeVoteHash[_rewardEpochId]].voters[_voter];
        _uptimeVoteSignTs = data.signTs;
        _uptimeVoteSignBlock = data.signBlock;
    }

    /**
     * @inheritdoc IIFlareSystemsManager
     */
    function getUptimeVoteSignStartInfo(uint24 _rewardEpochId)
        external view
        returns(
            uint64 _uptimeVoteSignStartTs,
            uint64 _uptimeVoteSignStartBlock
        )
    {
        RewardEpochState storage state = rewardEpochState[_rewardEpochId];
        _uptimeVoteSignStartTs = state.uptimeVoteSignStartTs;
        _uptimeVoteSignStartBlock = state.uptimeVoteSignStartBlock;
    }

    /**
     * @inheritdoc IIFlareSystemsManager
     */
    function getVoterRewardsSignInfo(uint24 _rewardEpochId, address _voter)
        external view
        returns(
            uint64 _rewardsSignTs,
            uint64 _rewardsSignBlock
        )
    {
        require(rewardsHash[_rewardEpochId] != bytes32(0), "rewards hash not signed yet");
        RewardEpochState storage state = rewardEpochState[_rewardEpochId];
        bytes32 messageHash = keccak256(abi.encode(
            _rewardEpochId, noOfWeightBasedClaimsHash[_rewardEpochId], rewardsHash[_rewardEpochId]));
        VoterData storage data = state.rewardVotes[messageHash].voters[_voter];
        _rewardsSignTs = data.signTs;
        _rewardsSignBlock = data.signBlock;
    }

    /**
     * @inheritdoc IIFlareSystemsManager
     */
    function getRewardsSignInfo(uint24 _rewardEpochId)
        external view
        returns(
            uint64 _rewardsSignStartTs,
            uint64 _rewardsSignStartBlock,
            uint64 _rewardsSignEndTs,
            uint64 _rewardsSignEndBlock
        )
    {
        RewardEpochState storage state = rewardEpochState[_rewardEpochId];
        _rewardsSignStartTs = state.rewardsSignStartTs;
        _rewardsSignStartBlock = state.rewardsSignStartBlock;
        _rewardsSignEndTs = state.rewardsSignEndTs;
        _rewardsSignEndBlock = state.rewardsSignEndBlock;
    }

    /**
     * @inheritdoc ProtocolsV2Interface
     */
    function getCurrentRewardEpochId() external view returns(uint24) {
        return _getCurrentRewardEpochId();
    }

    /**
     * @inheritdoc ProtocolsV2Interface
     */
    function getCurrentVotingEpochId() external view returns(uint32) {
        return _getCurrentVotingEpochId();
    }

    /**
     * @inheritdoc IFlareSystemsManager
     */
    function getCurrentRewardEpoch() external view returns(uint256) {
        return _getCurrentRewardEpochId();
    }

    /**
     * @inheritdoc IFlareDaemonize
     */
    function switchToFallbackMode() external view onlyFlareDaemon returns (bool) {
        // do nothing - there is no fallback mode in FlareSystemsManager contract
        return false;
    }

    /**
     * @inheritdoc IFlareDaemonize
     */
    function getContractName() external pure returns (string memory) {
        return "FlareSystemsManager";
    }

    /**
     * Initialization of the next signing policy.
     * @param _nextRewardEpochId Reward epoch id of the next signing policy.
     */
    function _initializeNextSigningPolicy(uint24 _nextRewardEpochId) internal {
        RewardEpochState storage state = rewardEpochState[_nextRewardEpochId];
        IIRelay.SigningPolicy memory signingPolicy;
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
        voterRegistry = IIVoterRegistry(
            _getContractAddress(_contractNameHashes, _contractAddresses, "VoterRegistry"));
        submission = IISubmission(_getContractAddress(_contractNameHashes, _contractAddresses, "Submission"));
        relay = IIRelay(_getContractAddress(_contractNameHashes, _contractAddresses, "Relay"));
        rewardManager = IIRewardManager(_getContractAddress(_contractNameHashes, _contractAddresses, "RewardManager"));
        cleanupBlockNumberManager = IICleanupBlockNumberManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "CleanupBlockNumberManager"));
    }

    /**
     * Updates the settings.
     * @param _settings The new settings.
     */
    function _updateSettings(Settings memory _settings) internal {
        require(_settings.signingPolicyThresholdPPM <= PPM_MAX, "threshold too high");
        require(_settings.signingPolicyMinNumberOfVoters > 0 && (address(voterRegistry) == address(0) ||
            voterRegistry.maxVoters() >= _settings.signingPolicyMinNumberOfVoters), "invalid number of voters");
        require(_settings.rewardExpiryOffsetSeconds <= block.timestamp, "expiry too long");

        randomAcquisitionMaxDurationSeconds = _settings.randomAcquisitionMaxDurationSeconds;
        randomAcquisitionMaxDurationBlocks = _settings.randomAcquisitionMaxDurationBlocks;
        newSigningPolicyInitializationStartSeconds = _settings.newSigningPolicyInitializationStartSeconds;
        newSigningPolicyMinNumberOfVotingRoundsDelay = _settings.newSigningPolicyMinNumberOfVotingRoundsDelay;
        rewardExpiryOffsetSeconds = _settings.rewardExpiryOffsetSeconds;
        voterRegistrationMinDurationSeconds = _settings.voterRegistrationMinDurationSeconds;
        voterRegistrationMinDurationBlocks = _settings.voterRegistrationMinDurationBlocks;
        submitUptimeVoteMinDurationSeconds = _settings.submitUptimeVoteMinDurationSeconds;
        submitUptimeVoteMinDurationBlocks = _settings.submitUptimeVoteMinDurationBlocks;
        signingPolicyThresholdPPM = _settings.signingPolicyThresholdPPM;
        signingPolicyMinNumberOfVoters = _settings.signingPolicyMinNumberOfVoters;
    }

    /**
     * Triggers voter registration immediately after random vote power block is selected.
     */
    function _triggerVoterRegistration(uint24 _nextRewardEpochId) internal {
        try voterRegistrationTriggerContract.triggerVoterRegistration(_nextRewardEpochId) {
        } catch {
            emit TriggeringVoterRegistrationFailed(_nextRewardEpochId);
        }
    }

    /**
     * Closes expired reward epochs.
     */
    function _closeExpiredRewardEpochs(uint24 _currentRewardEpochId) internal {
        uint256 expiryThreshold = block.timestamp - rewardExpiryOffsetSeconds;
        // NOTE: start time of (i+1)th reward epoch is the end time of i-th
        // This loop is clearly bounded by the value currentRewardEpoch, which is
        // always kept to the value of rewardEpochs.length - 1 in code and this value
        // does not change in the loop.
        while (rewardEpochIdToExpireNext < _currentRewardEpochId &&
            rewardEpochState[rewardEpochIdToExpireNext + 1].rewardEpochStartTs <= expiryThreshold)
        {   // Note: Since nextRewardEpochToExpire + 1 starts at that time
            // nextRewardEpochToExpire ends strictly before expiryThreshold,
            try rewardManager.closeExpiredRewardEpoch(rewardEpochIdToExpireNext) {
                rewardEpochIdToExpireNext++;
            } catch {
                emit ClosingExpiredRewardEpochFailed(rewardEpochIdToExpireNext);
                // Do not proceed with the loop.
                break;
            }
        }
    }

    /**
     * Performs any cleanup needed immediately after a reward epoch is finalized.
     */
    function _cleanupOnRewardEpochFinalization() internal {
        uint64 cleanupBlock = rewardEpochState[rewardEpochIdToExpireNext].votePowerBlock;
        try cleanupBlockNumberManager.setCleanUpBlockNumber(cleanupBlock) {
        } catch {
            emit SettingCleanUpBlockNumberFailed(cleanupBlock);
        }
    }

    /**
     * Triggers reward epoch switchover.
     */
    function _triggerRewardEpochSwitchover(uint24 rewardEpochId, uint64 rewardEpochExpectedEndTs) internal {
        for (uint256 i = 0; i < rewardEpochSwitchoverTriggerContracts.length; i++) {
            rewardEpochSwitchoverTriggerContracts[i].triggerRewardEpochSwitchover(
                rewardEpochId,
                rewardEpochExpectedEndTs,
                rewardEpochDurationSeconds);
        }
    }

    /**
     * Updates rewards hash (if thresold is reached) and emits RewardsSigned event.
     * @param _rewardEpochId Reward epoch id.
     * @param _signingPolicyAddress Voter's signing policy address.
     * @param _voter Voter's address.
     * @param _rewardsHash Rewards hash.
     * @param _noOfWeightBasedClaims Number of weight based claims.
     * @param _thresholdReached True if threshold is reached.
     */
    function _updateRewardsHashAndEmitRewardsSigned(
        uint24 _rewardEpochId,
        address _signingPolicyAddress,
        address _voter,
        bytes32 _rewardsHash,
        NumberOfWeightBasedClaims[] calldata _noOfWeightBasedClaims,
        bool _thresholdReached
    )
        internal
    {
        if (_thresholdReached) {
            rewardsHash[_rewardEpochId] = _rewardsHash;
            noOfWeightBasedClaimsHash[_rewardEpochId] = keccak256(abi.encode(_noOfWeightBasedClaims));
            for (uint256 i = 0; i < _noOfWeightBasedClaims.length; i++) {
                uint256 rewardManagerId = _noOfWeightBasedClaims[i].rewardManagerId;
                require(i == 0 || rewardManagerId > _noOfWeightBasedClaims[i - 1].rewardManagerId,
                    "reward manager id not increasing");
                noOfWeightBasedClaims[_rewardEpochId][rewardManagerId] =
                    _noOfWeightBasedClaims[i].noOfWeightBasedClaims;
            }
        }
        emit RewardsSigned(
            _rewardEpochId,
            _signingPolicyAddress,
            _voter,
            _rewardsHash,
            _noOfWeightBasedClaims,
            block.timestamp.toUint64(),
            _thresholdReached
        );
    }

    /**
     * Returns the voter data for given reward epoch id.
     * @param _rewardEpochId Reward epoch id.
     * @param _messageHash Message hash.
     * @param _signature Signature.
     * @return _signingPolicyAddress Signing policy address.
     * @return _voter Voter address.
     * @return _weight Voter weight (normalised).
     */
    function _getVoterData(
        uint24 _rewardEpochId,
        bytes32 _messageHash,
        Signature calldata _signature
    )
        internal view
        returns(address _signingPolicyAddress, address _voter, uint16 _weight)
    {
        _signingPolicyAddress = ECDSA.recover(
            MessageHashUtils.toEthSignedMessageHash(_messageHash),
            _signature.v,
            _signature.r,
            _signature.s
        );
        (_voter, _weight) = voterRegistry.getVoterWithNormalisedWeight(_rewardEpochId, _signingPolicyAddress);
        require(_voter != address(0), "signature invalid");
    }

    /**
     * Selects vote power block for given reward epoch id.
     * @param _nextRewardEpochId Reward epoch id.
     * @param _random Random number.
     * @return _votePowerBlock Vote power block.
     */
    function _selectVotePowerBlock(uint24 _nextRewardEpochId, uint256 _random)
        internal view
        returns(uint64 _votePowerBlock)
    {
        // randomTs > state.randomAcquisitionStartTs && isSecureRandom == true
        uint64 startBlock = rewardEpochState[_nextRewardEpochId - 1].randomAcquisitionStartBlock;
        // 0 < endBlock < block.number
        uint64 endBlock = rewardEpochState[_nextRewardEpochId].randomAcquisitionStartBlock;
        uint64 numberOfBlocks;
        if (startBlock == 0) {
            // endBlock > 0 && initialRandomVotePowerBlockSelectionSize > 0
            numberOfBlocks = Math.min(endBlock, initialRandomVotePowerBlockSelectionSize).toUint64();
        } else {
            // endBlock > startBlock
            numberOfBlocks = endBlock - startBlock;
        }

        //slither-disable-next-line weak-prng
        uint256 votePowerBlocksAgo = _random % numberOfBlocks; // numberOfBlocks > 0
        _votePowerBlock = endBlock - votePowerBlocksAgo.toUint64();
    }

    /**
     * Returns the current reward epoch id.
     */
    function _getCurrentRewardEpochId() internal view returns(uint24) {
        return (uint256(currentRewardEpochExpectedEndTs - firstRewardEpochStartTs) / rewardEpochDurationSeconds - 1)
            .toUint24();
    }

    /**
     * Returns true if it is time for and next reward epoch id is defined.
     */
    function _isNextRewardEpochId(uint24 _nextRewardEpochId) internal view returns (bool) {
        return block.timestamp >= currentRewardEpochExpectedEndTs &&
            _getSigningPolicyHash(_nextRewardEpochId) != bytes32(0) &&
            _getCurrentVotingEpochId() >= rewardEpochState[_nextRewardEpochId].startVotingRoundId;
    }

    /**
     * Returns the current voting epoch id.
     */
    function _getCurrentVotingEpochId() internal view returns(uint32) {
        return ((block.timestamp - firstVotingRoundStartTs) / votingEpochDurationSeconds).toUint32();
    }

    /**
     * Returns the signing policy hash for given reward epoch id.
     */
    function _getSigningPolicyHash(uint24 _rewardEpoch) internal view returns (bytes32) {
        return relay.toSigningPolicyHash(_rewardEpoch);
    }

    /**
     * Voter registration is enabled until enough time has passed and enough blocks have been created
     * or until a minimum number of voters have been registered.
     */
    function _isVoterRegistrationEnabled(
        uint256 _rewardEpoch,
        RewardEpochState storage _state
    )
        internal view
        returns(bool)
    {
        return _state.randomAcquisitionEndTs != 0 && (
            block.timestamp <= _state.randomAcquisitionEndTs + voterRegistrationMinDurationSeconds ||
            block.number <= _state.randomAcquisitionEndBlock + voterRegistrationMinDurationBlocks ||
            voterRegistry.getNumberOfRegisteredVoters(_rewardEpoch) < signingPolicyMinNumberOfVoters);
    }

    /**
     * Returns the start voting round id for next reward epoch.
     */
    function _getStartVotingRoundId() internal view returns (uint32 _startVotingRoundId) {
        uint256 timeFromStart = currentRewardEpochExpectedEndTs - firstVotingRoundStartTs;
        _startVotingRoundId = (timeFromStart / votingEpochDurationSeconds).toUint32();
        uint32 minStartVotingRoundId = _getCurrentVotingEpochId() + newSigningPolicyMinNumberOfVotingRoundsDelay + 1;
        if (_startVotingRoundId < minStartVotingRoundId) {
            _startVotingRoundId = minStartVotingRoundId;
        }
    }

    /**
     * Checks conditions for singing the rewards.
     */
    function _checkConditionsForSigningRewards(uint24 _rewardEpochId, bytes32 _rewardsHash) internal view {
        require(_rewardsHash != bytes32(0), "rewards hash zero");
        _checkIfPastRewardEpoch(_rewardEpochId);
        require(rewardEpochState[_rewardEpochId + 1].signingPolicySignEndTs != 0, "signing policy not signed yet");
    }

    /**
     * Checks if caller is flare daemon.
     */
    function _checkOnlyFlareDaemon() internal view {
        require(msg.sender == address(flareDaemon), "only flare daemon");
    }

    /**
     * Checks if reward epoch is initialized.
     */
    function _checkIfInitialized(uint256 _rewardEpochId) internal view {
        require(rewardEpochState[_rewardEpochId].signingPolicySignStartTs != 0, "reward epoch not initialized yet");
    }

    /**
     * Checks if uptime vote hash is signed.
     */
    function _checkIsUptimeVoteHashSigned(uint24 _rewardEpochId) internal view {
        require(uptimeVoteHash[_rewardEpochId] != bytes32(0), "uptime vote hash not signed yet");
    }

    /**
     * Checks if it is a past reward epoch.
     */
    function _checkIfPastRewardEpoch(uint24 _rewardEpochId) internal view {
        require(_rewardEpochId < _getCurrentRewardEpochId(), "epoch not ended yet");
    }

    /**
     * Checks if voter has already signed.
     */
    function _checkIfVoterAlreadySigned(uint64 _signTs) internal pure {
        require(_signTs == 0, "voter already signed");
    }
}
