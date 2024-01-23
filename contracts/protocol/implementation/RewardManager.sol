// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "flare-smart-contracts/contracts/userInterfaces/IPChainStakeMirror.sol";
import "flare-smart-contracts/contracts/tokenPools/interface/IITokenPool.sol";
import "../../utils/implementation/TokenPoolBase.sol";
import "../../governance/implementation/Governed.sol";
import "../interface/IWNat.sol";
import "../interface/IRewardManager.sol";
import "../interface/ICChainStake.sol";
import "../interface/IClaimSetupManager.sol";
import "../../utils/lib/SafePct.sol";
import "../../utils/lib/AddressSet.sol";
import "./FlareSystemManager.sol";
import "./FlareSystemCalculator.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * Reward manager contract.
 */
//solhint-disable-next-line max-states-count
contract RewardManager is Governed, TokenPoolBase, AddressUpdatable, ReentrancyGuard, IITokenPool, IRewardManager {
    using MerkleProof for bytes32[];
    using AddressSet for AddressSet.State;
    using SafeCast for uint256;
    using SafePct for uint256;

    /// Struct used for storing unclaimed reward data.
    struct UnclaimedRewardState {
        bool initialised;           // Information if already initialised
                                    // amount and weight might be 0 if all users already claimed
        uint120 amount;             // Total unclaimed amount.
        uint128 weight;             // Total unclaimed weight.
    }

    uint256 constant internal MAX_BIPS = 1e4;
    uint256 constant internal PPM_MAX = 1e6;
    uint24 constant internal FIRST_CLAIMABLE_EPOCH = type(uint24).max;

    mapping(address => uint24) private rewardOwnerNextClaimableEpochId;
    mapping(uint256 => uint256) private epochVotePowerBlock;
    mapping(uint256 => uint120) private epochTotalRewards;
    mapping(uint256 => uint120) private epochInitialisedRewards;
    mapping(uint256 => uint120) private epochClaimedRewards;
    mapping(uint256 => uint120) private epochBurnedRewards;

    /// This variable holds the first reward epoch id that was claimable.
    uint24 public firstClaimableRewardEpochId;
    // Id of the next reward epoch to expire. Closed = expired and unclaimed funds are burned.
    uint24 private nextRewardEpochIdToExpire;
    // Reward epoch id when setInitialRewardData is called (set to +1) - used for forwarding closeExpiredRewardEpoch
    uint24 private initialRewardEpochId;

    mapping(uint256 => mapping(ClaimType =>
        mapping(address => UnclaimedRewardState))) internal epochTypeProviderUnclaimedReward;
    // per reward epoch mark direct and fee claims (not weight based) that were already processed (paid out)
    mapping(uint256 => mapping(bytes32 => bool)) internal epochProcessedRewardClaims;
    // number of initialised weight based claims per reward epoch
    mapping(uint256 => uint256) internal epochNoOfInitialisedWeightBasedClaims;

    // Totals
    uint256 private totalClaimedWei;     // rewards that were claimed in time
    uint256 private totalBurnedWei;      // rewards that were unearned or expired and thus burned
    uint256 private totalFundsReceivedWei;
    uint256 private totalInflationReceivedWei;
    uint256 private totalInflationAuthorizedWei;

    /// The ClaimSetupManager contract.
    IClaimSetupManager public claimSetupManager;
    /// The FlareSystemManager contract.
    FlareSystemManager public flareSystemManager;
    /// The FlareSystemCalculator contract.
    FlareSystemCalculator public flareSystemCalculator;
    /// The PChainStakeMirror contract.
    IPChainStakeMirror public pChainStakeMirror;
    /// Indicates if P-Chain stakes mirror is enabled.
    bool public pChainStakeMirrorEnabled;
    /// The WNAT contract.
    IWNat public wNat;
    /// The CChainStake contract.
    ICChainStake public cChainStake;
    /// Indicates if C-Chain stakes are enabled.
    bool public cChainStakeEnabled;
    /// Indicates if the contract is active - claims are enabled.
    bool public active;

    /// Address of the old `RewardManager`, replaced by this one.
    address public oldRewardManager;
    /// Address of the new `RewardManager` that replaced this one.
    address public newRewardManager;

    /// List of reward offers managers.
    AddressSet.State internal rewardOffersManagerSet;

    /**
     * Emitted when a data provider claims its FTSO rewards.
     * @param voter Address of the voter (or node id) that accrued the reward.
     * @param whoClaimed Address that actually performed the claim.
     * @param sentTo Address that received the reward.
     * @param rewardEpochId Id of the reward epoch where the reward was accrued.
     * @param claimType Claim type
     * @param amount Amount of rewarded native tokens (wei).
     */
    event RewardClaimed(
        address indexed voter,
        address indexed whoClaimed,
        address indexed sentTo,
        uint24 rewardEpochId,
        ClaimType claimType,
        uint120 amount
    );

    /**
     * Unclaimed rewards have expired and are now inaccessible.
     *
     * `getUnclaimedRewardState()` can be used to retrieve more information.
     * @param rewardEpochId Id of the reward epoch that has just expired.
     */
    event RewardClaimsExpired(
        uint256 rewardEpochId
    );

    /**
     * Emitted when reward claims have been enabled.
     * @param rewardEpochId First claimable reward epoch.
     */
    event RewardClaimsEnabled(
        uint256 rewardEpochId
    );

    /// This method can only be called if the contract is `active`.
    modifier onlyIfActive() {
        _checkIfActive();
        _;
    }

    /// This method can only be called by reward offers manager.
    modifier onlyRewardOffersManager() {
        _checkRewardOffersManager();
        _;
    }

    /// Only the reward owner and its authorized executors can call this method.
    /// Executors can only send rewards to authorized recipients.
    /// See `ClaimSetupManager`.
    modifier onlyExecutorAndAllowedRecipient(address _rewardOwner, address _recipient) {
        _checkExecutorAndAllowedRecipient(_rewardOwner, _recipient);
        _;
    }

    /**
     * Constructor.
     * @param _governanceSettings Address of the GovernanceSettings contract.
     * @param _initialGovernance The initial governance address.
     * @param _addressUpdater Address of the AddressUpdater contract.
     */
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater
    )
        Governed(_governanceSettings, _initialGovernance) AddressUpdatable(_addressUpdater)
    {
        firstClaimableRewardEpochId = FIRST_CLAIMABLE_EPOCH;
    }

    /**
     * Claim rewards for `_rewardOwner` and transfer them to `_recipient`.
     * It can be called by reward owner or its authorized executor.
     * @param _rewardOwner Address of the reward owner.
     * @param _recipient Address of the reward recipient.
     * @param _rewardEpochId Id of the reward epoch up to which the rewards are claimed.
     * @param _wrap Indicates if the reward should be wrapped (deposited) to the WNAT contract.
     * @param _proofs Array of reward claims with merkle proofs.
     * @return _rewardAmountWei Amount of rewarded native tokens (wei).
     */
    function claim(
        address _rewardOwner,
        address payable _recipient,
        uint24 _rewardEpochId,
        bool _wrap,
        RewardClaimWithProof[] calldata _proofs
    )
        external
        onlyIfActive
        mustBalance
        nonReentrant
        onlyExecutorAndAllowedRecipient(_rewardOwner, _recipient)
        returns (uint256 _rewardAmountWei)
    {
        _checkNonzeroRecipient(_recipient);

        uint24 currentRewardEpochId = _getCurrentRewardEpochId();
        require(_isRewardClaimable(_rewardEpochId, currentRewardEpochId), "not claimable");

        uint24 minClaimableEpochId = _minClaimableRewardEpochId();
        uint120 burnAmountWei;
        (_rewardAmountWei, burnAmountWei) = _processProofs(_rewardOwner, _recipient, _proofs, minClaimableEpochId);

        _rewardAmountWei += _claimWeightBasedRewards(
            _rewardOwner, _recipient, _rewardEpochId, minClaimableEpochId, false);

        if (burnAmountWei > 0) {
            totalBurnedWei += burnAmountWei;
            //slither-disable-next-line arbitrary-send-eth
            BURN_ADDRESS.transfer(burnAmountWei);
        }

        if (_rewardAmountWei > 0) {
            //solhint-disable-next-line reentrancy
            totalClaimedWei += _rewardAmountWei;
            _transferOrWrap(_recipient, _rewardAmountWei, _wrap);
        }
    }

    /**
     * Claim rewards for `_rewardOwners` and their PDAs.
     * Rewards are deposited to the WNAT (to reward owner or PDA if enabled).
     * It can be called by reward owner or its authorized executor.
     * Only claiming from weight based claims is supported.
     * @param _rewardOwners Array of reward owners.
     * @param _rewardEpochId Id of the reward epoch up to which the rewards are claimed.
     * @param _proofs Array of reward claims with merkle proofs.
     */
    //slither-disable-next-line reentrancy-eth          // guarded by nonReentrant
    function autoClaim(
        address[] calldata _rewardOwners,
        uint24 _rewardEpochId,
        RewardClaimWithProof[] calldata _proofs
    )
        external
        onlyIfActive
        mustBalance
        nonReentrant
    {
        for (uint256 i = 0; i < _rewardOwners.length; i++) {
            _checkNonzeroRecipient(_rewardOwners[i]);
        }

        uint24 currentRewardEpochId = _getCurrentRewardEpochId();
        require(_isRewardClaimable(_rewardEpochId, currentRewardEpochId), "not claimable");

        (address[] memory claimAddresses, uint256 executorFeeValue) =
            claimSetupManager.getAutoClaimAddressesAndExecutorFee(msg.sender, _rewardOwners);

        uint24 minClaimableEpochId = _minClaimableRewardEpochId();
        // initialise only weight based claims
        _processProofs(address(0), address(0), _proofs, minClaimableEpochId);

        uint256 totalClaimed;
        for (uint256 i = 0; i < _rewardOwners.length; i++) {
            address rewardOwner = _rewardOwners[i];
            address claimAddress = claimAddresses[i];
            // claim for owner
            uint256 rewardAmount = _claimWeightBasedRewards(
                rewardOwner, claimAddress, _rewardEpochId, minClaimableEpochId, false);
            if (rewardOwner != claimAddress) {
                // claim for PDA (only WNat)
                rewardAmount += _claimWeightBasedRewards(
                    claimAddress, claimAddress, _rewardEpochId, minClaimableEpochId, true);
            }
            require(rewardAmount >= executorFeeValue, "claimed amount too small");
            totalClaimed += rewardAmount;
            rewardAmount -= executorFeeValue;
            if (rewardAmount > 0) {
                _transferOrWrap(claimAddress, rewardAmount, true);
            }
        }
        totalClaimedWei += totalClaimed;
        _transferOrWrap(msg.sender, executorFeeValue * _rewardOwners.length, false);
    }

    /**
     * Enables reward claims from the current reward epoch id onwards.
     * @dev Only governance can call this method.
     */
    function enableClaims() external onlyImmediateGovernance {
        require(firstClaimableRewardEpochId == FIRST_CLAIMABLE_EPOCH, "already enabled");
        firstClaimableRewardEpochId = _getCurrentRewardEpochId();
        emit RewardClaimsEnabled(firstClaimableRewardEpochId);
    }

    /**
     * Enables P-Chain stakes mirror.
     * @dev Only governance can call this method.
     */
    function enablePChainStakeMirror() external onlyGovernance {
        pChainStakeMirrorEnabled = true;
    }

    /**
     * Enables C-Chain stakes.
     * @dev Only governance can call this method.
     */
    function enableCChainStake() external onlyGovernance {
        cChainStakeEnabled = true;
    }

    /**
     * Sets reward offers manager list.
     * @dev Only governance can call this method.
     */
    function setRewardOffersManagerList(address[] calldata _rewardOffersManagerList) external onlyGovernance {
        rewardOffersManagerSet.replaceAll(_rewardOffersManagerList);
    }

    /**
     * Adds daily authorized inflation.
     * @param _toAuthorizeWei Amount of inflation to authorize (wei).
     * @dev Only reward offers manager can call this method.
     */
    function addDailyAuthorizedInflation(uint256 _toAuthorizeWei) external onlyRewardOffersManager {
        totalInflationAuthorizedWei = totalInflationAuthorizedWei + _toAuthorizeWei;
    }

    /**
     * Receives funds from reward offers manager.
     * @param _rewardEpochId ID of the reward epoch for which the funds are received.
     * @param _inflation Indicates if the funds come from the inflation (true) or from the community (false).
     * @dev Only reward offers manager can call this method.
     */
    function receiveRewards(
        uint24 _rewardEpochId,
        bool _inflation
    )
        external payable
        onlyRewardOffersManager mustBalance
    {
        require(_rewardEpochId >= _getCurrentRewardEpochId(), "reward epoch id in the past");
        epochTotalRewards[_rewardEpochId] += msg.value.toUint120();
        totalFundsReceivedWei += msg.value;
        if (_inflation) {
            totalInflationReceivedWei = totalInflationReceivedWei + msg.value;
        }
    }

    /**
     * Sets old reward manager to which closing expired reward epochs will be forwarded.
     * Should be called at the time of switching to this reward manager, can be called only once.
     * @dev Only governance can call this method.
     */
    function setOldRewardManager(address _oldRewardManager) external onlyGovernance {
        require(oldRewardManager == address(0), "already set");
        require(_oldRewardManager != address(0), "address zero");
        oldRewardManager = _oldRewardManager;
    }

    /**
     * Copy initial reward data from `flareSystemManager` before starting up this new reward manager.
     * Should be called at the time of switching to the new reward manager, can be called only once.
     * @dev Only governance can call this method.
     */
    function setInitialRewardData() external onlyGovernance {
        require(!active && initialRewardEpochId == 0 && nextRewardEpochIdToExpire == 0, "not initial state");
        initialRewardEpochId = _getCurrentRewardEpochId() + 1; // in order to distinguish from 0
        nextRewardEpochIdToExpire = flareSystemManager.rewardEpochIdToExpireNext();
    }

    /**
     * Sets new reward manager which will take over closing expired reward epochs.
     * Should be called at the time of switching to the new reward manager, can be called only once.
     * @dev Only governance can call this method.
     */
    function setNewRewardManager(address _newRewardManager) external onlyGovernance {
        require(newRewardManager == address(0), "already set");
        require(_newRewardManager != address(0), "address zero");
        newRewardManager = _newRewardManager;
    }

    /**
     * Collects funds from expired reward epoch and calculates totals.
     *
     * Triggered by FlareSystemManager on finalization of a reward epoch.
     * Operation is irreversible: when some reward epoch is closed according to current
     * settings, it cannot be reopened even if new parameters would
     * allow it, because `nextRewardEpochIdToExpire` in FlareSystemManager never decreases.
     * @param _rewardEpochId Id of the reward epoch to close.
     */
    function closeExpiredRewardEpoch(uint256 _rewardEpochId) external {
        require(msg.sender == address(flareSystemManager) || msg.sender == newRewardManager, "only managers");
        require(nextRewardEpochIdToExpire == _rewardEpochId, "wrong epoch id");
        if (oldRewardManager != address(0) && _rewardEpochId < initialRewardEpochId + 50) {
            RewardManager(oldRewardManager).closeExpiredRewardEpoch(_rewardEpochId);
        }

        nextRewardEpochIdToExpire = (_rewardEpochId + 1).toUint24();
        emit RewardClaimsExpired(_rewardEpochId);
        uint256 burnAmountWei = epochTotalRewards[_rewardEpochId] - epochClaimedRewards[_rewardEpochId];
        if (burnAmountWei > 0) {
            totalBurnedWei += burnAmountWei;
            //slither-disable-next-line arbitrary-send-eth
            BURN_ADDRESS.transfer(burnAmountWei);
        }
    }

    /**
     * Activates the contract - enables claims.
     * @dev Only immediate governance can call this method.
     */
    function activate() external onlyImmediateGovernance {
        active = true;
    }

    /**
     * Deactivates the contract - disables claims.
     * @dev Only immediate governance can call this method.
     */
    function deactivate() external onlyImmediateGovernance {
        active = false;
    }

    /**
     * Get the current cleanup block number.
     * @return The currently set cleanup block number.
     */
    function cleanupBlockNumber() external view returns (uint256) {
        return wNat.cleanupBlockNumber();
    }

    /**
     * Gets the unclaimed reward state for a reward owner, reward epoch id and claim type.
     * @param _rewardOwner Address of the reward owner to query.
     * @param _rewardEpochId Id of the reward epoch to query.
     * @param _claimType Claim type to query.
     * @return _state Unclaimed reward state.
     */
    function getUnclaimedRewardState(
        address _rewardOwner,
        uint24 _rewardEpochId,
        ClaimType _claimType
    )
        external view
        returns (
            UnclaimedRewardState memory _state
        )
    {
        return epochTypeProviderUnclaimedReward[_rewardEpochId][_claimType][_rewardOwner];
    }

    /**
     * Returns reward offers manager list.
     */
    function getRewardOffersManagerList() external view returns(address[] memory) {
        return rewardOffersManagerSet.list;
    }

    /**
     * Returns token pool supply data.
     * @return _lockedFundsWei Total amount of funds ever locked in the token pool (wei).
     * `_lockedFundsWei` - `_totalClaimedWei` is the amount currently locked and outside the circulating supply.
     * @return _totalInflationAuthorizedWei Total inflation authorized amount (wei).
     * @return _totalClaimedWei Total claimed amount (wei).
     */
    function getTokenPoolSupplyData()
        external view override
        returns (
            uint256 _lockedFundsWei,
            uint256 _totalInflationAuthorizedWei,
            uint256 _totalClaimedWei
        )
    {
        //_lockedFundsWei = offers from community
        _lockedFundsWei = totalFundsReceivedWei - totalInflationReceivedWei;
        _totalInflationAuthorizedWei = totalInflationAuthorizedWei;
        _totalClaimedWei = totalClaimedWei + totalBurnedWei;
    }

    /**
     * Returns expected balance of reward manager.
     */
    function getExpectedBalance() external view returns(uint256) {
        return _getExpectedBalance();
    }

    /**
     * Returns the start and the end of the reward epoch range for which the reward is claimable.
     * **NOTE**: If rewards hash was not signed yet, some epoch might not be claimable.
     * @return _startEpochId The oldest epoch id that allows reward claiming.
     * @return _endEpochId The newest epoch id that allows reward claiming.
     */
    function getEpochIdsWithClaimableRewards() external view
        returns (uint256 _startEpochId, uint256 _endEpochId)
    {
        _startEpochId = _minClaimableRewardEpochId();
        uint256 currentRewardEpochId = _getCurrentRewardEpochId();
        require(currentRewardEpochId > 0, "no epoch with claimable rewards");
        _endEpochId = currentRewardEpochId - 1;
    }

    /**
     * Returns totals.
     * @return _totalFundsReceivedWei Total amount of funds ever received (wei).
     * @return _totalClaimedWei Total claimed amount (wei).
     * @return _totalBurnedWei Total burned amount (wei).
     * @return _totalInflationAuthorizedWei Total inflation authorized amount (wei).
     * @return _totalInflationReceivedWei Total inflation received amount (wei).
     */
    function getTotals()
        external view
        returns (
            uint256 _totalFundsReceivedWei,
            uint256 _totalClaimedWei,
            uint256 _totalBurnedWei,
            uint256 _totalInflationAuthorizedWei,
            uint256 _totalInflationReceivedWei
        )
    {
        return (
            totalFundsReceivedWei,
            totalClaimedWei,
            totalBurnedWei,
            totalInflationAuthorizedWei,
            totalInflationReceivedWei
        );
    }

     /**
     * Returns current reward epoch id.
     */
    function getCurrentRewardEpochId() external view returns (uint24) {
        return _getCurrentRewardEpochId();
    }

    /**
     * Returns initial reward epoch id.
     */
    function getInitialRewardEpochId() external view returns (uint256) {
        return _getInitialRewardEpochId();
    }

    /**
     * Returns the reward epoch id that will expire next once a new reward epoch starts.
     */
    function getRewardEpochIdToExpireNext() external view returns (uint256) {
        return nextRewardEpochIdToExpire;
    }

    /**
     * Returns the next claimable reward epoch for a reward owner.
     * @param _rewardOwner Address of the reward owner to query.
     */
    function nextClaimableRewardEpochId(address _rewardOwner) external view returns (uint256) {
        return _nextClaimableEpochId(_rewardOwner, _minClaimableRewardEpochId());
    }

    /**
     * Claims from DIRECT and FEE claims and initialises weight based claims.
     * @param _rewardOwner Address of the reward owner.
     * @param _recipient Address of the reward recipient.
     * @param _proofs Array of reward claims with merkle proofs.
     * @param _minClaimableEpochId Minimum claimable epoch id.
     * @return _rewardAmountWei Reward amount in native tokens (wei).
     * @return _burnAmountWei Burn amount in native tokens (wei).
     */
    function _processProofs(
        address _rewardOwner,
        address _recipient,
        RewardClaimWithProof[] calldata _proofs,
        uint24 _minClaimableEpochId
    )
        internal
        returns(
            uint120 _rewardAmountWei,
            uint120 _burnAmountWei
        )
    {
        for (uint256 i = 0; i < _proofs.length; i++) {
            ClaimType claimType = _proofs[i].body.claimType;
            if (claimType == ClaimType.DIRECT || claimType == ClaimType.FEE) {
                if (_rewardOwner != address(0)) {
                    (uint120 rewardAmountWei, uint120 burnAmountWei) =
                        _claimFromDirectOrFeeClaim(_rewardOwner, _recipient, _proofs[i]);
                    _rewardAmountWei += rewardAmountWei;
                    _burnAmountWei += burnAmountWei;
                }
            } else if (_proofs[i].body.rewardEpochId >= _minClaimableEpochId) {
                _initialiseWeightBasedClaim(_proofs[i]);
            }
        }
    }

    /**
     * Claims from DIRECT or FEE claim and returns the reward amount and burn amount.
     * @param _rewardOwner Address of the reward owner.
     * @param _recipient Address of the reward recipient.
     * @param _proof Reward claim with merkle proof.
     * @return _rewardAmountWei Reward amount in native tokens (wei).
     * @return _burnAmountWei Burn amount in native tokens (wei).
     */
    function _claimFromDirectOrFeeClaim(
        address _rewardOwner,
        address _recipient,
        RewardClaimWithProof calldata _proof
    )
        internal
        returns (
            uint120 _rewardAmountWei,
            uint120 _burnAmountWei
        )
    {
        RewardClaim calldata rewardClaim = _proof.body;
        require(address(rewardClaim.beneficiary) == _rewardOwner, "wrong beneficiary");
        bytes32 claimHash = keccak256(abi.encode(rewardClaim));
        if (!epochProcessedRewardClaims[rewardClaim.rewardEpochId][claimHash]) {
            // not claimed yet - check if valid merkle proof
            bytes32 rewardsHash = flareSystemManager.rewardsHash(rewardClaim.rewardEpochId);
            require(_proof.merkleProof.verifyCalldata(rewardsHash, claimHash), "merkle proof invalid");
            // initialise reward amount
            _rewardAmountWei = _initRewardAmount(rewardClaim.rewardEpochId, rewardClaim.amount);
            if (rewardClaim.claimType == ClaimType.FEE) {
                uint256 burnFactor = flareSystemCalculator
                    .calculateBurnFactorPPM(rewardClaim.rewardEpochId, _rewardOwner);
                if (burnFactor > 0) {
                    // calculate burn amount
                    _burnAmountWei = Math.min(uint256(_rewardAmountWei).mulDiv(burnFactor, PPM_MAX),
                        _rewardAmountWei).toUint120();
                    // reduce reward amount
                    _rewardAmountWei -= _burnAmountWei; // _burnAmountWei <= _rewardAmountWei
                    // update total burned amount per epoch
                    epochBurnedRewards[rewardClaim.rewardEpochId] += _burnAmountWei;
                    // emit event how much of the reward was burned
                    emit RewardClaimed(
                        _rewardOwner,
                        _rewardOwner,
                        BURN_ADDRESS,
                        rewardClaim.rewardEpochId,
                        ClaimType.FEE,
                        _burnAmountWei
                    );
                }
            }
            // update total claimed amount per epoch
            epochClaimedRewards[rewardClaim.rewardEpochId] += _rewardAmountWei;
            // mark as claimed
            epochProcessedRewardClaims[rewardClaim.rewardEpochId][claimHash] = true;
            // emit event
            emit RewardClaimed(
                _rewardOwner,
                _rewardOwner,
                _recipient,
                rewardClaim.rewardEpochId,
                rewardClaim.claimType,
                _rewardAmountWei
            );
        }
    }

    /**
     * Initialises weight based claim.
     * @param _proof Reward claim with merkle proof.
     */
    function _initialiseWeightBasedClaim(RewardClaimWithProof calldata _proof) internal {
        RewardClaim calldata rewardClaim = _proof.body;
        UnclaimedRewardState storage state = epochTypeProviderUnclaimedReward
            [rewardClaim.rewardEpochId][rewardClaim.claimType][address(rewardClaim.beneficiary)];
        if (!state.initialised) {
            // not initialised yet - check if valid merkle proof
            bytes32 rewardsHash = flareSystemManager.rewardsHash(rewardClaim.rewardEpochId);
            bytes32 claimHash = keccak256(abi.encode(rewardClaim));
            require(_proof.merkleProof.verifyCalldata(rewardsHash, claimHash), "merkle proof invalid");
            // mark as initialised
            state.initialised = true;
            // initialise reward amount
            state.amount = _initRewardAmount(rewardClaim.rewardEpochId, rewardClaim.amount);
            // initialise weight
            state.weight = _initVotePower(rewardClaim.rewardEpochId, rewardClaim.beneficiary, rewardClaim.claimType);
            // increase the number of initialised weight based claims
            epochNoOfInitialisedWeightBasedClaims[rewardClaim.rewardEpochId] += 1;
        }
    }

    /**
     * Initialises reward amount.
     * @param _rewardEpochId Id of the reward epoch.
     * @param _rewardClaimAmount Reward amount of the claim.
     * @return _rewardAmount Initialised reward amount.
     */
    function _initRewardAmount(
        uint24 _rewardEpochId,
        uint120 _rewardClaimAmount
    )
        internal
        returns (uint120 _rewardAmount)
    {
        // get total reward amount
        uint120 totalRewards = epochTotalRewards[_rewardEpochId];
        // get already initalised rewards
        uint120 initialisedRewards = epochInitialisedRewards[_rewardEpochId];
        _rewardAmount = _rewardClaimAmount;
        if (totalRewards < initialisedRewards + _rewardClaimAmount) {
            // reduce reward amount in case of invalid off-chain calculations
            _rewardAmount = totalRewards - initialisedRewards; // totalRewards >= initialisedRewards
        }
        // increase initialised reward amount
        epochInitialisedRewards[_rewardEpochId] += _rewardAmount;
    }

    /**
     * Claims weight based rewards.
     */
    function _claimWeightBasedRewards(
        address _rewardOwner,
        address _recipient,
        uint24 _rewardEpochId,
        uint24 _minClaimableEpochId,
        bool _onlyWNat
    )
        internal
        returns (uint120 _rewardAmountWei)
    {
        uint24 nextClaimableEpochId = _nextClaimableEpochId(_rewardOwner, _minClaimableEpochId);
        for (uint24 epoch = nextClaimableEpochId; epoch <= _rewardEpochId; epoch++) {
            // check if all weight based claims were already initialised
            // (in this case zero unclaimed rewards are actually zeros)
            uint256 noOfWeightBasedClaims = flareSystemManager.noOfWeightBasedClaims(epoch);
            if (noOfWeightBasedClaims == 0) {
                require(flareSystemManager.rewardsHash(epoch) != bytes32(0), "rewards hash zero");
            }
            bool allClaimsInitialised = epochNoOfInitialisedWeightBasedClaims[epoch] >= noOfWeightBasedClaims;
            uint256 votePowerBlock = _getVotePowerBlock(epoch);
            uint120 rewardAmount = 0;

            // WNAT claims
            rewardAmount += _claimWNatRewards(_rewardOwner, _recipient, epoch, votePowerBlock, allClaimsInitialised);

            if (!_onlyWNat) {
                // MIRROR claims
                if (address(pChainStakeMirror) != address(0)) {
                    rewardAmount += _claimMirrorRewards(
                        _rewardOwner, _recipient, epoch, votePowerBlock, allClaimsInitialised);
                }

                // CCHAIN claims
                if (address(cChainStake) != address(0)) {
                    rewardAmount += _claimCChainRewards(
                        _rewardOwner, _recipient, epoch, votePowerBlock, allClaimsInitialised);
                }
            }

            // update total claimed amount per epoch
            epochClaimedRewards[epoch] += rewardAmount;
            _rewardAmountWei += rewardAmount;
        }

        // mark epochs up to `_rewardEpochId` as claimed
        if (rewardOwnerNextClaimableEpochId[_rewardOwner] < _rewardEpochId + 1) {
            rewardOwnerNextClaimableEpochId[_rewardOwner] = _rewardEpochId + 1;
        }
    }

    /**
     * Claims WNAT rewards.
     */
    function _claimWNatRewards(
        address _rewardOwner,
        address _recipient,
        uint24 _epoch,
        uint256 _votePowerBlock,
        bool _allClaimsInitialised
    )
        internal
        returns (uint120 _rewardAmountWei)
    {
        uint256 delegatorBalance = wNat.balanceOfAt(_rewardOwner, _votePowerBlock);
        if (delegatorBalance > 0) { // _rewardOwner had some funds wrapped at _votePowerBlock
            uint256 delegatedBIPS = 0;
            (address[] memory delegates, uint256[] memory bips, , ) = wNat.delegatesOfAt(
                _rewardOwner, _votePowerBlock);
            if (delegates.length > 0) { // _rewardOwner had some delegations at _votePowerBlock
                for (uint256 i = 0; i < delegates.length; i++) {
                    UnclaimedRewardState storage state =
                        epochTypeProviderUnclaimedReward[_epoch][ClaimType.WNAT][delegates[i]];
                    // check if reward state is already initialised
                    require(_allClaimsInitialised || state.initialised, "not initialised");
                    // calculate weight that corresponds to the delegate at index `i`
                    uint256 weight = delegatorBalance.mulDiv(bips[i], MAX_BIPS);
                    // increase delegated bips
                    delegatedBIPS += bips[i];
                    // reduce remaining amount and weight
                    uint120 claimRewardAmount = _claimRewardAmount(state, weight);
                    // increase total reward amount
                    _rewardAmountWei += claimRewardAmount;
                    // emit event
                    emit RewardClaimed(
                        delegates[i],
                        _rewardOwner,
                        _recipient,
                        _epoch,
                        ClaimType.WNAT,
                        claimRewardAmount
                    );
                }
            }

            // if delegatedBIPS < MAX_BIPS - undelegated vote power or some revocations
            if (delegatedBIPS < MAX_BIPS) {
                // get undelegated vote power including revocations
                uint256 undelegatedVotePower = wNat.undelegatedVotePowerOfAt(_rewardOwner, _votePowerBlock);
                if (undelegatedVotePower > 0) {
                    UnclaimedRewardState storage state =
                        epochTypeProviderUnclaimedReward[_epoch][ClaimType.WNAT][_rewardOwner];
                    // check if reward state is already initialised
                    require(_allClaimsInitialised || state.initialised, "not initialised");
                    // reduce remaining amount and weight
                    uint120 claimRewardAmount =
                        _claimRewardAmount(state, undelegatedVotePower);
                    // increase total reward amount
                    _rewardAmountWei += claimRewardAmount;
                    // emit event
                    emit RewardClaimed(
                        _rewardOwner,
                        _rewardOwner,
                        _recipient,
                        _epoch,
                        ClaimType.WNAT,
                        claimRewardAmount
                    );
                }
            }
        }
    }

    /**
     * Claims MIRROR rewards.
     */
    function _claimMirrorRewards(
        address _rewardOwner,
        address _recipient,
        uint24 _epoch,
        uint256 _votePowerBlock,
        bool _allClaimsInitialised
    )
        internal
        returns (uint120 _rewardAmountWei)
    {
        (bytes20[] memory nodeIds, uint256[] memory weights) = pChainStakeMirror.stakesOfAt(
            _rewardOwner, _votePowerBlock);
        for (uint256 i = 0; i < nodeIds.length; i++) { // _rewardOwner had some stakes at _votePowerBlock
            UnclaimedRewardState storage state =
                epochTypeProviderUnclaimedReward[_epoch][ClaimType.MIRROR][address(nodeIds[i])];
            // check if reward state is already initialised
            require(_allClaimsInitialised || state.initialised, "not initialised");
            // reduce remaining amount and weight
            uint120 claimRewardAmount = _claimRewardAmount(state, weights[i]);
            // increase total reward amount
            _rewardAmountWei += claimRewardAmount;
            // emit event
            emit RewardClaimed(
                address(nodeIds[i]),
                _rewardOwner,
                _recipient,
                _epoch,
                ClaimType.MIRROR,
                claimRewardAmount
            );
        }
    }

    /**
     * Claims CCHAIN rewards.
     */
    function _claimCChainRewards(
        address _rewardOwner,
        address _recipient,
        uint24 _epoch,
        uint256 _votePowerBlock,
        bool _allClaimsInitialised
    )
        internal
        returns (uint120 _rewardAmountWei)
    {
        (address[] memory accounts, uint256[] memory weights) = cChainStake.stakesOfAt(
            _rewardOwner, _votePowerBlock);
        for (uint256 i = 0; i < accounts.length; i++) { // _rewardOwner had some stakes at _votePowerBlock
            UnclaimedRewardState storage state =
                epochTypeProviderUnclaimedReward[_epoch][ClaimType.CCHAIN][accounts[i]];
            // check if reward state is already initialised
            require(_allClaimsInitialised || state.initialised, "not initialised");
            // reduce remaining amount and weight
            uint120 claimRewardAmount = _claimRewardAmount(state, weights[i]);
            // increase total reward amount
            _rewardAmountWei += claimRewardAmount;
            // emit event
            emit RewardClaimed(
                accounts[i],
                _rewardOwner,
                _recipient,
                _epoch,
                ClaimType.CCHAIN,
                claimRewardAmount
            );
        }
    }

    /**
     * Claims and returns the reward amount
     * @param _state                unclaimed reward state
     * @param _rewardWeight         number representing reward weight
     * @return _rewardAmount        number representing reward amount
     */
    function _claimRewardAmount(
        UnclaimedRewardState storage _state,
        uint256 _rewardWeight
    )
        internal
        returns (uint120 _rewardAmount)
    {
        if (_rewardWeight == 0) {
            return 0;
        }

        uint120 unclaimedRewardAmount = _state.amount;
        if (unclaimedRewardAmount == 0) {
            return 0;
        }
        uint128 unclaimedRewardWeight = _state.weight;
        if (_rewardWeight == unclaimedRewardWeight) {
            _state.weight = 0;
            _state.amount = 0;
            return unclaimedRewardAmount;
        }
        assert(_rewardWeight < unclaimedRewardWeight);
        _rewardAmount = uint256(unclaimedRewardAmount).mulDiv(_rewardWeight, unclaimedRewardWeight).toUint120();
        _state.weight -= _rewardWeight.toUint128();
        _state.amount -= _rewardAmount;
    }

    /**
     * Transfers or wrap (deposit) `_rewardAmount` to `_recipient`.
     * @param _recipient Adress representing the reward recipient.
     * @param _rewardAmount Reward amount in native tokens (wei).
     * @param _wrap Flag indicating if the transfer should be wrapped (deposited) to WNAT.
     * @dev Uses low level call to transfer funds.
     */
    function _transferOrWrap(address _recipient, uint256 _rewardAmount, bool _wrap) internal {
        if (_wrap) {
            // transfer total amount (state is updated and events are emitted elsewhere)
            //slither-disable-next-line arbitrary-send-eth
            wNat.depositTo{value: _rewardAmount}(_recipient);
        } else {
            // transfer total amount (state is updated and events are emitted elsewhere)
            /* solhint-disable avoid-low-level-calls */
            //slither-disable-next-line arbitrary-send-eth
            (bool success, ) = _recipient.call{value: _rewardAmount}("");
            /* solhint-enable avoid-low-level-calls */
            require(success, "transfer failed");
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
        claimSetupManager = IClaimSetupManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "ClaimSetupManager"));
        flareSystemManager = FlareSystemManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemManager"));
        flareSystemCalculator = FlareSystemCalculator(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemCalculator"));
        if (pChainStakeMirrorEnabled) {
            pChainStakeMirror = IPChainStakeMirror(
                _getContractAddress(_contractNameHashes, _contractAddresses, "PChainStakeMirror"));
        }
        if (cChainStakeEnabled) {
            cChainStake = ICChainStake(_getContractAddress(_contractNameHashes, _contractAddresses, "CChainStake"));
        }
        wNat = IWNat(
            _getContractAddress(_contractNameHashes, _contractAddresses, "WNat"));
    }

    /**
     * Initialises reward epoch vote power and returns it.
     * @param _rewardEpochId Reward epoch id.
     * @param _beneficiary Address of the reward beneficiary.
     * @param _claimType Claim type.
     */
    function _initVotePower(
        uint24 _rewardEpochId,
        bytes20 _beneficiary,
        ClaimType _claimType
    )
        internal
        returns (uint128)
    {
        uint256 votePowerBlock = epochVotePowerBlock[_rewardEpochId];
        if (votePowerBlock == 0) {
            votePowerBlock = flareSystemManager.getVotePowerBlock(_rewardEpochId);
            epochVotePowerBlock[_rewardEpochId] = votePowerBlock;
        }
        if (_claimType == ClaimType.WNAT) {
            return wNat.votePowerOfAt(address(_beneficiary), votePowerBlock).toUint128();
        } else if (_claimType == ClaimType.MIRROR) {
            return pChainStakeMirror.votePowerOfAt(_beneficiary, votePowerBlock).toUint128();
        } else { //_claimType == ClaimType.CCHAIN
            return cChainStake.votePowerOfAt(address(_beneficiary), votePowerBlock).toUint128();
        }
    }

    /**
     * Returns reward epoch vote power block.
     * @param _rewardEpochId Reward epoch id.
     */
    function _getVotePowerBlock(uint24 _rewardEpochId) internal view returns (uint256 _votePowerBlock) {
        _votePowerBlock = epochVotePowerBlock[_rewardEpochId];
        if (_votePowerBlock == 0) {
            _votePowerBlock = flareSystemManager.getVotePowerBlock(_rewardEpochId);
        }
    }

    /**
     * Reports if rewards for `_rewardEpochId` are claimable.
     * @param _rewardEpochId Reward epoch id.
     * @param _currentRewardEpochId Id of the current reward epoch.
     */
    function _isRewardClaimable(uint24 _rewardEpochId, uint24 _currentRewardEpochId) internal view returns (bool) {
        return _rewardEpochId >= firstClaimableRewardEpochId &&
               _rewardEpochId >= nextRewardEpochIdToExpire &&
               _rewardEpochId < _currentRewardEpochId;
    }

    /**
     * Returns next claimable epoch id for `_rewardOwner`.
     * @param _rewardOwner Address of the reward owner.
     * @param _minClaimableEpochId Minimum claimable epoch id.
     */
    function _nextClaimableEpochId(address _rewardOwner, uint256 _minClaimableEpochId) internal view returns (uint24) {
        return Math.max(rewardOwnerNextClaimableEpochId[_rewardOwner], _minClaimableEpochId).toUint24();
    }

    /**
     * Returns minimum claimable epoch id.
     */
    function _minClaimableRewardEpochId() internal view returns (uint24) {
        return Math.max(firstClaimableRewardEpochId,
            Math.max(_getInitialRewardEpochId(), nextRewardEpochIdToExpire)).toUint24();
    }

    /**
     * Returns initial reward epoch id.
     * @return _initialRewardEpochId Initial reward epoch id.
     */
    function _getInitialRewardEpochId() internal view returns (uint256 _initialRewardEpochId) {
        (,_initialRewardEpochId) = Math.trySub(initialRewardEpochId, 1);
    }

    /**
     * Returns current reward epoch id.
     */
    function _getCurrentRewardEpochId() internal view returns (uint24) {
        return flareSystemManager.getCurrentRewardEpochId();
    }

    /**
     * Returns expected balance of reward manager (wei).
     */
    function _getExpectedBalance() internal view override returns(uint256) {
        return totalFundsReceivedWei - totalClaimedWei - totalBurnedWei;
    }

    /**
     * Checks if the caller is the reward owner or the executor and that recipient is allowed.
     * @param _rewardOwner Address of the reward owner.
     * @param _recipient Address of the reward recipient.
     */
    function _checkExecutorAndAllowedRecipient(address _rewardOwner, address _recipient) private view {
        if (msg.sender == _rewardOwner) {
            return;
        }
        claimSetupManager.checkExecutorAndAllowedRecipient(msg.sender, _rewardOwner, _recipient);
    }

    /**
     * Checks if the contract is active.
     */
    function _checkIfActive() private view {
        require(active, "reward manager deactivated");
    }

    /**
     * Checks if caller is reward offers manager.
     */
    function _checkRewardOffersManager() private view {
        require(rewardOffersManagerSet.index[msg.sender] != 0, "only reward offers manager");
    }

    /**
     * Checks if recipient is not zero address.
     */
    function _checkNonzeroRecipient(address _recipient) private pure {
        require(_recipient != address(0), "recipient zero");
    }
}
