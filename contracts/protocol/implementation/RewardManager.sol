// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "flare-smart-contracts/contracts/userInterfaces/IPChainStakeMirror.sol";
import "flare-smart-contracts/contracts/tokenPools/interface/IITokenPool.sol";
import "../../utils/implementation/TokenPoolBase.sol";
import "../../governance/implementation/Governed.sol";
import "../interface/IWNat.sol";
import "../interface/ICChainStake.sol";
import "../interface/IClaimSetupManager.sol";
import "../../utils/lib/SafePct.sol";
import "../../utils/lib/AddressSet.sol";
import "./VoterRegistry.sol";
import "./FlareSystemManager.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

//solhint-disable-next-line max-states-count
contract RewardManager is Governed, TokenPoolBase, AddressUpdatable, ReentrancyGuard, IITokenPool {
    using MerkleProof for bytes32[];
    using AddressSet for AddressSet.State;
    using SafeCast for uint256;
    using SafePct for uint256;

    enum ClaimType { DIRECT, FEE, WNAT, MIRROR, CCHAIN }

    struct UnclaimedRewardState {   // Used for storing unclaimed reward info.
        bool initialised;           // Information if already initialised
                                    // amount and weight might be 0 if all users already claimed
        uint120 amount;             // Total unclaimed amount.
        uint128 weight;             // Total unclaimed weight.
    }

    struct RewardClaimWithProof {
        bytes32[] merkleProof;
        RewardClaim body;
    }

    struct RewardClaim {
        uint24 rewardEpochId;
        bytes20 beneficiary; // c-chain address or node id (bytes20) in case of type MIRROR
        uint120 amount; // in wei
        ClaimType claimType;
    }

    struct FeePercentage {          // used for storing data provider fee percentage settings
        uint16 value;               // fee percentage value (value between 0 and 1e4)
        uint24 validFromEpochId;    // id of the reward epoch from which the value is valid
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

    /// Epoch ids before the token distribution event at Flare launch were not be claimable.
    /// This variable holds the first reward epoch that was claimable.
    uint24 public firstClaimableRewardEpochId;
    // id of the first epoch to expire. Closed = expired and unclaimed funds sent back
    uint24 private nextRewardEpochIdToExpire;
    // reward epoch when setInitialRewardData is called (set to +1) - used for forwarding closeExpiredRewardEpochId
    uint24 private initialRewardEpochId;

    uint24 public immutable feePercentageUpdateOffset; // fee percentage update timelock measured in reward epochs
    uint16 public immutable defaultFeePercentageBIPS; // default value for fee percentage
    mapping(address => FeePercentage[]) public dataProviderFeePercentages;

    mapping(uint256 => mapping(ClaimType =>
        mapping(address => UnclaimedRewardState))) public epochTypeProviderUnclaimedReward;
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

    /// The VoterRegistry contract.
    VoterRegistry public voterRegistry;
    IClaimSetupManager public claimSetupManager;
    FlareSystemManager public flareSystemManager;
    IPChainStakeMirror public pChainStakeMirror;
    IWNat public wNat;
    ICChainStake public cChainStake;
    bool public cChainStakeEnabled;
    bool public active;

    /// Address of the old `RewardManager`, replaced by this one.
    address public oldRewardManager;
    /// Address of the new `RewardManager` that replaced this one.
    address public newRewardManager;

    AddressSet.State internal rewardOffersManagerSet;

    event FeePercentageChanged(
        address indexed dataProvider,
        uint16 value,
        uint24 validFromEpochId
    );

    /**
     * Emitted when a data provider claims its FTSO rewards.
     * @param voter Address of the voter (or node id) that accrued the reward.
     * @param whoClaimed Address that actually performed the claim.
     * @param sentTo Address that received the reward.
     * @param claimType Claim type
     * @param rewardEpochId ID of the reward epoch where the reward was accrued.
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
     * `getUnclaimedReward()` can be used to retrieve more information.
     * @param rewardEpochId ID of the reward epoch that has just expired.
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

    /// This method can only be called by reward offers manager
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

    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        uint24 _feePercentageUpdateOffset,
        uint16 _defaultFeePercentageBIPS
    )
        Governed(_governanceSettings, _initialGovernance) AddressUpdatable(_addressUpdater)
    {
        require(_feePercentageUpdateOffset > 1, "offset too small");
        feePercentageUpdateOffset = _feePercentageUpdateOffset;
        defaultFeePercentageBIPS = _defaultFeePercentageBIPS;
        firstClaimableRewardEpochId = FIRST_CLAIMABLE_EPOCH;
    }

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
        if (epochVotePowerBlock[currentRewardEpochId] == 0) {
            epochVotePowerBlock[currentRewardEpochId] =
                flareSystemManager.getVotePowerBlock(currentRewardEpochId);
        }
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

    // it supports only claiming from weight based claims
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
        if (epochVotePowerBlock[currentRewardEpochId] == 0) {
            epochVotePowerBlock[currentRewardEpochId] =
                flareSystemManager.getVotePowerBlock(currentRewardEpochId);
        }
        require(_isRewardClaimable(_rewardEpochId, currentRewardEpochId), "not claimable");

        (address[] memory claimAddresses, uint256 executorFeeValue) =
            claimSetupManager.getAutoClaimAddressesAndExecutorFee(msg.sender, _rewardOwners);

        uint24 minClaimableEpochId = _minClaimableRewardEpochId();
        // initialise only weight based claims
        _processProofs(address(0), address(0), _proofs, minClaimableEpochId);

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
            rewardAmount -= executorFeeValue;
            if (rewardAmount > 0) {
                _transferOrWrap(claimAddress, rewardAmount, true);
            }
        }

        _transferOrWrap(msg.sender, executorFeeValue * _rewardOwners.length, false);
    }

    /**
     * @dev Only governance can call this method.
     */
    function enableClaims() external onlyImmediateGovernance {
        require(firstClaimableRewardEpochId == FIRST_CLAIMABLE_EPOCH, "already enabled");
        firstClaimableRewardEpochId = _getCurrentRewardEpochId();
        emit RewardClaimsEnabled(firstClaimableRewardEpochId);
    }

    /**
     * Enables C-Chain stakes.
     * @dev Only governance can call this method.
     */
    function enableCChainStake() external onlyGovernance {
        cChainStakeEnabled = true;
    }

    function setRewardOffersManagerList(address[] calldata _rewardOffersManagerList) external onlyGovernance {
        rewardOffersManagerSet.replaceAll(_rewardOffersManagerList);
    }

    function addDailyAuthorizedInflation(uint256 _toAuthorizeWei) external onlyRewardOffersManager {
        totalInflationAuthorizedWei = totalInflationAuthorizedWei + _toAuthorizeWei;
    }

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
     * Copy initial reward data from `oldFtsoRewardManager` before starting up this new reward manager.
     * Should be called at the time of switching to the new reward manager, can be called only once, and only
     * by governance.
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
     * @param _rewardEpochId ID of the epoch to close.
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
     * Allows data provider to set (or update last) fee percentage.
     * @param _feePercentageBIPS    number representing fee percentage in BIPS
     * @return Returns the reward epoch number when the setting becomes effective.
     */
    function setDataProviderFeePercentage(uint16 _feePercentageBIPS) external returns (uint256) {
        require(_feePercentageBIPS <= MAX_BIPS, "fee percentage invalid");

        uint24 rewardEpochId = _getCurrentRewardEpochId() + feePercentageUpdateOffset;
        FeePercentage[] storage fps = dataProviderFeePercentages[msg.sender];

        // determine whether to update the last setting or add a new one
        uint256 position = fps.length;
        if (position > 0) {
            // do not allow updating the settings in the past
            assert(rewardEpochId >= fps[position - 1].validFromEpochId);

            if (rewardEpochId == fps[position - 1].validFromEpochId) {
                // update
                position = position - 1;
            }
        }
        if (position == fps.length) {
            // add
            fps.push();
        }

        // apply setting
        fps[position].value = _feePercentageBIPS;
        fps[position].validFromEpochId = rewardEpochId;

        emit FeePercentageChanged(msg.sender, _feePercentageBIPS, rewardEpochId);
        return rewardEpochId;
    }

    function getRewardOffersManagerList() external view returns(address[] memory) {
        return rewardOffersManagerSet.list;
    }

    /**
     * Returns the current fee percentage of `_dataProvider`
     * @param _dataProvider         address representing data provider
     */
    function getDataProviderCurrentFeePercentage(address _dataProvider) external view returns (uint16) {
        return _getDataProviderFeePercentage(_dataProvider, _getCurrentRewardEpochId());
    }

    /**
     * Returns the fee percentage of `_dataProvider` for given reward epoch id
     * @param _dataProvider         address representing data provider
     * @param _rewardEpochId        reward epoch id
     * **NOTE:** fee percentage might still change for future reward epoch ids
     */
    function getDataProviderFeePercentage(
        address _dataProvider,
        uint256 _rewardEpochId
    )
        external view
        returns (uint16)
    {
        return _getDataProviderFeePercentage(_dataProvider, _rewardEpochId);
    }

    /**
     * Returns the scheduled fee percentage changes of `_dataProvider`
     * @param _dataProvider         address representing data provider
     * @return _feePercentageBIPS   positional array of fee percentages in BIPS
     * @return _validFromEpochId    positional array of block numbers the fee setings are effective from
     * @return _fixed               positional array of boolean values indicating if settings are subjected to change
     */
    function getDataProviderScheduledFeePercentageChanges(
        address _dataProvider
    )
        external view
        returns (
            uint256[] memory _feePercentageBIPS,
            uint256[] memory _validFromEpochId,
            bool[] memory _fixed
        )
    {
        FeePercentage[] storage fps = dataProviderFeePercentages[_dataProvider];
        if (fps.length > 0) {
            uint256 currentEpochId = flareSystemManager.getCurrentRewardEpochId();
            uint256 position = fps.length;
            while (position > 0 && fps[position - 1].validFromEpochId > currentEpochId) {
                position--;
            }
            uint256 count = fps.length - position;
            if (count > 0) {
                _feePercentageBIPS = new uint256[](count);
                _validFromEpochId = new uint256[](count);
                _fixed = new bool[](count);
                for (uint256 i = 0; i < count; i++) {
                    _feePercentageBIPS[i] = fps[i + position].value;
                    _validFromEpochId[i] = fps[i + position].validFromEpochId;
                    _fixed[i] = (_validFromEpochId[i] - currentEpochId) != feePercentageUpdateOffset;
                }
            }
        }
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
     * Return expected balance of reward manager
     */
    function getExpectedBalance() external view returns(uint256) {
        return _getExpectedBalance();
    }

    /**
     * Returns the start and the end of the reward epoch range for which the reward is claimable
     * @return _startEpochId        the oldest epoch id that allows reward claiming
     * @return _endEpochId          the newest epoch id that allows reward claiming
     */
    function getEpochIdsWithClaimableRewards() external view
        returns (uint256 _startEpochId, uint256 _endEpochId)
    {
        _startEpochId = _minClaimableRewardEpochId();
        uint256 currentRewardEpochId = _getCurrentRewardEpochId();
        require(currentRewardEpochId > 0, "no epoch with claimable rewards");
        _endEpochId = currentRewardEpochId - 1;
    }

    function getTotals()
        external view
        returns (
            uint256 _totalClaimedWei,
            uint256 _totalBurnedWei,
            uint256 _totalInflationAuthorizedWei,
            uint256 _totalInflationReceivedWei
        )
    {
        return (
            totalClaimedWei,
            totalBurnedWei,
            totalInflationAuthorizedWei,
            totalInflationReceivedWei
        );
    }

     /**
     * Return current reward epoch number
     */
    function getCurrentRewardEpochId() external view returns (uint24) {
        return _getCurrentRewardEpochId();
    }

    /**
     * Return initial reward epoch number
     */
    function getInitialRewardEpochId() external view returns (uint256) {
        return _getInitialRewardEpochId();
    }

    /**
     * Returns the reward epoch that will expire next once a new reward epoch starts.
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
     * claims from DIRECT and FEE claims and initialises weight based claims
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
            _rewardAmountWei = _initialiseRewardAmount(rewardClaim.rewardEpochId, rewardClaim.amount);
            if (rewardClaim.claimType == ClaimType.FEE) {
                uint256 burnFactor = _getBurnFactor(rewardClaim.rewardEpochId, _rewardOwner);
                if (burnFactor > 0) {
                    // calculate burn amount
                    _burnAmountWei = Math.min(_rewardAmountWei, uint256(_rewardAmountWei).
                        mulDiv(burnFactor, PPM_MAX)).toUint120();
                    // reduce reward amount
                    _rewardAmountWei -= _burnAmountWei; // _burnAmountWei <= _rewardAmountWei
                    // update total burned amount per epoch
                    epochBurnedRewards[rewardClaim.rewardEpochId] += _burnAmountWei;
                    // emit event how much of the reward was burned
                    // TODO - different event?
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
            state.amount = _initialiseRewardAmount(rewardClaim.rewardEpochId, rewardClaim.amount);
            // initialise weight
            state.weight = _getVotePower(rewardClaim.rewardEpochId, rewardClaim.beneficiary, rewardClaim.claimType);
            // increase the number of initialised weight based claims
            epochNoOfInitialisedWeightBasedClaims[rewardClaim.rewardEpochId] += 1;
        }
    }

    function _initialiseRewardAmount(
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
            bool allClaimsInitialised = epochNoOfInitialisedWeightBasedClaims[epoch]
                >= flareSystemManager.noOfWeightBasedClaims(epoch);
            uint256 votePowerBlock = _getVotePowerBlock(epoch);
            uint120 rewardAmount = 0;

            // WNAT claims
            rewardAmount += _claimWNatRewards(_rewardOwner, _recipient, epoch, votePowerBlock, allClaimsInitialised);

            if (!_onlyWNat) {
                // MIRROR claims
                rewardAmount += _claimMirrorRewards(
                    _rewardOwner, _recipient, epoch, votePowerBlock, allClaimsInitialised);

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
            uint256 delegatedVotePower = 0;
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
                    // increase delegated vote power
                    delegatedVotePower += weight;
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

            // if undelegated vote power > 0 and _rewardOwner is a voter - claim self delegation rewards
            if (delegatorBalance > delegatedVotePower && voterRegistry.isVoterRegistered(_rewardOwner, _epoch)) {
                UnclaimedRewardState storage state =
                    epochTypeProviderUnclaimedReward[_epoch][ClaimType.WNAT][_rewardOwner];
                // check if reward state is already initialised
                require(_allClaimsInitialised || state.initialised, "not initialised");
                // reduce remaining amount and weight
                uint120 claimRewardAmount = _claimRewardAmount(state, delegatorBalance - delegatedVotePower);
                // increase total reward amount
                _rewardAmountWei += claimRewardAmount;
                // emit event
                emit RewardClaimed(_rewardOwner, _rewardOwner, _recipient, _epoch, ClaimType.WNAT, claimRewardAmount);
            }
        }
    }

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
     * @param _recipient            address representing the reward recipient
     * @param _rewardAmount         number representing the amount to transfer
     * @param _wrap                 should reward be wrapped immediately
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
     * Implementation of the AddressUpdatable abstract method.
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal override
    {
        voterRegistry = VoterRegistry(
            _getContractAddress(_contractNameHashes, _contractAddresses, "VoterRegistry"));
        claimSetupManager = IClaimSetupManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "ClaimSetupManager"));
        flareSystemManager = FlareSystemManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemManager"));
        pChainStakeMirror = IPChainStakeMirror(
            _getContractAddress(_contractNameHashes, _contractAddresses, "PChainStakeMirror"));
        if (cChainStakeEnabled) {
            cChainStake = ICChainStake(_getContractAddress(_contractNameHashes, _contractAddresses, "CChainStake"));
        }
        wNat = IWNat(
            _getContractAddress(_contractNameHashes, _contractAddresses, "WNat"));
    }

    /**
     * Returns fee percentage setting for `_dataProvider` at `_rewardEpochId`.
     * @param _dataProvider         address representing a data provider
     * @param _rewardEpochId        reward epoch id
     */
    function _getDataProviderFeePercentage(
        address _dataProvider,
        uint256 _rewardEpochId
    )
        internal view
        returns (uint16)
    {
        FeePercentage[] storage fps = dataProviderFeePercentages[_dataProvider];
        uint256 index = fps.length;
        while (index > 0) {
            index--;
            if (_rewardEpochId >= fps[index].validFromEpochId) {
                return fps[index].value;
            }
        }
        return defaultFeePercentageBIPS;
    }

    function _getBurnFactor(uint24 _rewardEpochId, address _rewardOwner) internal view returns(uint256) {
        return flareSystemManager.getRewardsFeeBurnFactor(_rewardEpochId, _rewardOwner);
    }

    function _getVotePower(
        uint24 _rewardEpochId,
        bytes20 _beneficiary,
        ClaimType _claimType
    )
        internal view
        returns (uint128)
    {
        uint256 votePowerBlock = _getVotePowerBlock(_rewardEpochId);
        if (_claimType == ClaimType.WNAT) {
            return wNat.votePowerOfAt(address(_beneficiary), votePowerBlock).toUint128(); // TODO check revocation
        } else if (_claimType == ClaimType.MIRROR) {
            return pChainStakeMirror.votePowerOfAt(_beneficiary, votePowerBlock).toUint128();
        } else if (_claimType == ClaimType.CCHAIN) {
            return cChainStake.votePowerOfAt(address(_beneficiary), votePowerBlock).toUint128();
        } else {
            return 0;
        }
    }

    /**
     * Return reward epoch vote power block
     * @param _rewardEpochId          reward epoch number
     */
    function _getVotePowerBlock(uint24 _rewardEpochId) internal view returns (uint256 _votePowerBlock) {
        _votePowerBlock = epochVotePowerBlock[_rewardEpochId];
        if (_votePowerBlock == 0) {
            _votePowerBlock = flareSystemManager.getVotePowerBlock(_rewardEpochId);
        }
    }

    /**
     * Reports if rewards for `_rewardEpochId` are claimable.
     * @param _rewardEpochId          reward epoch number
     * @param _currentRewardEpochId   number of the current reward epoch
     */
    function _isRewardClaimable(uint24 _rewardEpochId, uint24 _currentRewardEpochId) internal view returns (bool) {
        return _rewardEpochId >= firstClaimableRewardEpochId &&
               _rewardEpochId >= nextRewardEpochIdToExpire &&
               _rewardEpochId < _currentRewardEpochId;
    }

    function _nextClaimableEpochId(address _rewardOwner, uint256 _minClaimableEpochId) internal view returns (uint24) {
        return Math.max(rewardOwnerNextClaimableEpochId[_rewardOwner], _minClaimableEpochId).toUint24();
    }

    function _minClaimableRewardEpochId() internal view returns (uint24) {
        return Math.max(firstClaimableRewardEpochId,
            Math.max(_getInitialRewardEpochId(), nextRewardEpochIdToExpire)).toUint24();
    }

    /**
     * Return initial reward epoch number
     * @return _initialRewardEpochId Initial reward epoch number.
     */
    function _getInitialRewardEpochId() internal view returns (uint256 _initialRewardEpochId) {
        (,_initialRewardEpochId) = Math.trySub(initialRewardEpochId, 1);
    }

    /**
     * Return current reward epoch number
     */
    function _getCurrentRewardEpochId() internal view returns (uint24) {
        return flareSystemManager.getCurrentRewardEpochId();
    }

    function _getExpectedBalance() internal view override returns(uint256 _balanceExpectedWei) {
        return totalFundsReceivedWei - totalClaimedWei - totalBurnedWei;
    }

    function _checkExecutorAndAllowedRecipient(address _rewardOwner, address _recipient) private view {
        if (msg.sender == _rewardOwner) {
            return;
        }
        claimSetupManager.checkExecutorAndAllowedRecipient(msg.sender, _rewardOwner, _recipient);
    }

    function _checkIfActive() private view {
        require(active, "reward manager deactivated");
    }

    function _checkRewardOffersManager() private view {
        require(rewardOffersManagerSet.index[msg.sender] != 0, "only reward offers manager");
    }

    function _checkNonzeroRecipient(address _address) private pure {
        require(_address != address(0), "recipient zero");
    }
}
