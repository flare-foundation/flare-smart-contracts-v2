// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "flare-smart-contracts/contracts/genesis/interface/IFlareDaemonize.sol";
import "../../governance/implementation/Governed.sol";
import "../../utils/implementation/AddressUpdatable.sol";
import "../../utils/lib/SafePct.sol";
import "../interface/IIRewardEpochSwitchoverTrigger.sol";
import "../interface/IIVoterRegistrationTrigger.sol";
import "../interface/IICleanupBlockNumberManager.sol";
import "../interface/IIFlareSystemManager.sol";
import "../interface/IIVoterRegistry.sol";
import "../interface/IIRewardManager.sol";
import "../interface/IIRelay.sol";
import "../interface/IISubmission.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * FlareSystemManager is responsible for initialization of reward epochs and voting rounds using FlareDaemon calls.
 * This contract is also used for managing signing policies, uptime votes and rewards.
 */
//solhint-disable-next-line max-states-count
contract FlareSystemManager is Governed, AddressUpdatable, IFlareDaemonize, IIFlareSystemManager {
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

        uint256 seed; // secure random number
        uint64 votePowerBlock;
        uint32 startVotingRoundId;
        uint16 threshold; // absolute value in normalised weight

        uint64 rewardEpochStartTs;
        uint64 rewardEpochStartBlock;

        Votes signingPolicyVotes;
        mapping(bytes32 => Votes) uptimeVoteVotes;
        mapping(bytes32 => Votes) rewardVotes;
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
    mapping(uint256 => RewardEpochState) internal rewardEpochState; // mapping: reward epoch id => reward epoch state

    /// Uptime vote hash for given reward epoch id
    mapping(uint256 => bytes32) public uptimeVoteHash; // mapping: reward epoch id => uptime vote hash
    /// Rewards hash for given reward epoch id
    mapping(uint256 => bytes32) public rewardsHash; // mapping: reward epoch id => rewards hash
    /// Number of weight based claims for given reward epoch id
    mapping(uint256 => uint256) public noOfWeightBasedClaims; // mapping: reward epoch id => no. of weight based claims

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
    /// Signing policy threshold, in parts per million.
    uint24 public signingPolicyThresholdPPM;
    /// Minimum number of voters for signing policy.
    uint16 public signingPolicyMinNumberOfVoters;
    /// Indicates if rewards epoch expiration and vote power block cleanup should be triggered after each epoch.
    bool public triggerExpirationAndCleanup = false;

    /// Timestamp when current reward epoch should end, in seconds since UNIX epoch.
    uint64 public currentRewardEpochExpectedEndTs;

    /// The last voting round id that was initialized.
    uint32 public lastInitializedVotingRoundId;

    /// The reward epoch id that will expire next.
    uint24 public rewardEpochIdToExpireNext;

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
        require(msg.sender == flareDaemon, "only flare daemon");
        _;
    }

    /// Modifier for allowing only if reward epoch is initialized.
    modifier onlyIfInitialized(uint256 _rewardEpochId) {
        require(rewardEpochState[_rewardEpochId].signingPolicySignStartTs != 0, "reward epoch not initialized yet");
        _;
    }

    /**
     * @dev Constructor.
     * @param _governanceSettings Governance settings contract.
     * @param _initialGovernance Initial governance address.
     * @param _addressUpdater Address updater contract.
     * @param _flareDaemon FlareDaemon contract address.
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
                    (uint256 random, bool isSecureRandom, uint64 randomTs) = _getRandom();
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
                submit1Addresses,
                submitSignaturesAddresses
            );
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
     * @inheritdoc IFlareSystemManager
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
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(_newSigningPolicyHash);
        address signingPolicyAddress = ECDSA.recover(signedMessageHash, _signature.v, _signature.r, _signature.s);
        (address voter, uint16 weight) = voterRegistry.getVoterWithNormalisedWeight(
            _rewardEpochId - 1, signingPolicyAddress);
        require(voter != address(0), "signature invalid");
        require(state.signingPolicyVotes.voters[voter].signTs == 0, "signing address already signed");
        // save signing address timestamp and block number
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
     * @inheritdoc IFlareSystemManager
     */
    function signUptimeVote(
        uint24 _rewardEpochId,
        bytes32 _uptimeVoteHash,
        Signature calldata _signature
    )
        external
    {
        require(_uptimeVoteHash != bytes32(0), "uptime vote hash zero");
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
     * @inheritdoc IFlareSystemManager
     */
    function signRewards(
        uint24 _rewardEpochId,
        uint64 _noOfWeightBasedClaims,
        bytes32 _rewardsHash,
        Signature calldata _signature
    )
        external
    {
        require(_rewardsHash != bytes32(0), "rewards hash zero");
        RewardEpochState storage state = rewardEpochState[_rewardEpochId];
        require(_rewardEpochId < getCurrentRewardEpochId(), "epoch not ended yet");
        require(rewardEpochState[_rewardEpochId + 1].signingPolicySignEndTs != 0, "new signing policy not signed yet");
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

    /**
     * Method for setting rewards hash and number of weight based claims.
     * @param _rewardEpochId Reward epoch id of the rewards.
     * @param _noOfWeightBasedClaims Number of weight based claims.
     * @param _rewardsHash Rewards hash.
     * @dev Only governance can call this method.
     */
    function setRewardsData(
        uint24 _rewardEpochId,
        uint64 _noOfWeightBasedClaims,
        bytes32 _rewardsHash
    )
        external onlyImmediateGovernance
    {
        require(_rewardEpochId < getCurrentRewardEpochId(), "epoch not ended yet");
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

    /**
     * Sets whether to trigger rewards epoch expiration and vote power block cleanup after each epoch
     * @dev Only governance can call this method.
     */
    function setTriggerExpirationAndCleanup(bool _triggerExpirationAndCleanup) external onlyGovernance {
        triggerExpirationAndCleanup = _triggerExpirationAndCleanup;
    }

    /**
     * Method for changing the signing policy settings.
     * @param _signingPolicyThresholdPPM Signing policy threshold, in parts per million.
     * @param _signingPolicyMinNumberOfVoters Minimum number of voters for signing policy.
     * @dev Only governance can call this method.
     */
    function changeSigningPolicySettings(
        uint24 _signingPolicyThresholdPPM,
        uint16 _signingPolicyMinNumberOfVoters
    )
        external onlyGovernance
    {
        require(_signingPolicyThresholdPPM <= PPM_MAX, "threshold too high");
        require(_signingPolicyMinNumberOfVoters > 0, "zero voters");
        signingPolicyThresholdPPM = _signingPolicyThresholdPPM;
        signingPolicyMinNumberOfVoters = _signingPolicyMinNumberOfVoters;
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
     * @inheritdoc IFlareSystemManager
     */
    function getVotePowerBlock(uint256 _rewardEpochId)
        external view
        returns(uint64 _votePowerBlock)
    {
        _votePowerBlock = rewardEpochState[_rewardEpochId].votePowerBlock;
        require(_votePowerBlock != 0, "vote power block not initialized yet");
    }

    /**
     * @inheritdoc IFlareSystemManager
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
     * @inheritdoc IFlareSystemManager
     */
    function getStartVotingRoundId(uint256 _rewardEpochId)
        external view
        onlyIfInitialized(_rewardEpochId)
        returns(uint32)
    {
        return rewardEpochState[_rewardEpochId].startVotingRoundId;
    }

    /**
     * @inheritdoc IFlareSystemManager
     */
    function getThreshold(uint256 _rewardEpochId)
        external view
        onlyIfInitialized(_rewardEpochId)
        returns(uint16)
    {
        return rewardEpochState[_rewardEpochId].threshold;
    }

    /**
     * @inheritdoc IFlareSystemManager
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
     * @inheritdoc IFlareSystemManager
     */
    function isVoterRegistrationEnabled() external view returns (bool) {
        uint256 nextRewardEpochId = getCurrentRewardEpochId() + 1;
        return _isVoterRegistrationEnabled(nextRewardEpochId, rewardEpochState[nextRewardEpochId]);
    }

    /**
     * @inheritdoc IRandomProvider
     */
    function getCurrentRandom() external view returns(uint256 _currentRandom) {
        (_currentRandom, , ) = _getRandom();
    }

    /**
     * @inheritdoc IRandomProvider
     */
    function getCurrentRandomWithQuality()
        external view
        returns(uint256 _currentRandom, bool _isSecureRandom)
    {
        (_currentRandom, _isSecureRandom, ) = _getRandom();
    }

    /**
     * @inheritdoc IIFlareSystemManager
     */
    function getRewarEpochStartInfo(uint24 _rewardEpochId)
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
     * @inheritdoc IIFlareSystemManager
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
     * @inheritdoc IIFlareSystemManager
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
     * @inheritdoc IIFlareSystemManager
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
     * @inheritdoc IIFlareSystemManager
     */
    function getVoterUptimeVoteSignInfo(uint24 _rewardEpochId, address _voter)
        external view
        returns(
            uint64 _uptimeVoteSignTs,
            uint64 _uptimeVoteSignBlock
        )
    {
        RewardEpochState storage state = rewardEpochState[_rewardEpochId];
        VoterData storage data = state.uptimeVoteVotes[uptimeVoteHash[_rewardEpochId]].voters[_voter];
        _uptimeVoteSignTs = data.signTs;
        _uptimeVoteSignBlock = data.signBlock;
    }

    /**
     * @inheritdoc IIFlareSystemManager
     */
    function getVoterRewardsSignInfo(uint24 _rewardEpochId, address _voter)
        external view
        returns(
            uint64 _rewardsSignTs,
            uint64 _rewardsSignBlock
        )
    {
        RewardEpochState storage state = rewardEpochState[_rewardEpochId];
        bytes32 messageHash = keccak256(abi.encode(
            _rewardEpochId, noOfWeightBasedClaims[_rewardEpochId], rewardsHash[_rewardEpochId]));
        VoterData storage data = state.rewardVotes[messageHash].voters[_voter];
        _rewardsSignTs = data.signTs;
        _rewardsSignBlock = data.signBlock;
    }

    /**
     * @inheritdoc IIFlareSystemManager
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
     * @inheritdoc IFlareDaemonize
     */
    function switchToFallbackMode() external pure returns (bool) {
        // do nothing - there is no fallback mode in FlareSystemManager contract
        return false;
    }

    /**
     * @inheritdoc IFlareDaemonize
     */
    function getContractName() external pure returns (string memory) {
        return "FlareSystemManager";
    }

    /**
     * @inheritdoc IFlareSystemManager
     */
    function getCurrentRewardEpochId() public view returns(uint24 _currentRewardEpochId) {
        _currentRewardEpochId = _getCurrentRewardEpochId();
        if (_isNextRewardEpochId(_currentRewardEpochId + 1)) {
            // first transaction in the block (daemonize() call will change `currentRewardEpochExpectedEndTs` value)
            _currentRewardEpochId += 1;
        }
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
        require(_settings.signingPolicyMinNumberOfVoters > 0, "zero voters");

        randomAcquisitionMaxDurationSeconds = _settings.randomAcquisitionMaxDurationSeconds;
        randomAcquisitionMaxDurationBlocks = _settings.randomAcquisitionMaxDurationBlocks;
        newSigningPolicyInitializationStartSeconds = _settings.newSigningPolicyInitializationStartSeconds;
        newSigningPolicyMinNumberOfVotingRoundsDelay = _settings.newSigningPolicyMinNumberOfVotingRoundsDelay;
        rewardExpiryOffsetSeconds = _settings.rewardExpiryOffsetSeconds;
        voterRegistrationMinDurationSeconds = _settings.voterRegistrationMinDurationSeconds;
        voterRegistrationMinDurationBlocks = _settings.voterRegistrationMinDurationBlocks;
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
     * Returns the current random number.
     * @return _random Current random number.
     * @return _secure Indicates if the random number is secure.
     * @return _randomTs Timestamp when the random number was generated.
     */
    function _getRandom() internal view returns (uint256 _random, bool _secure, uint64 _randomTs) {
        return relay.getRandomNumber();
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
}
