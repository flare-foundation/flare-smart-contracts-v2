// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "flare-smart-contracts/contracts/userInterfaces/IPChainStakeMirror.sol";
import "flare-smart-contracts/contracts/tokenPools/interface/IITokenPool.sol";
import "../../governance/implementation/AddressUpdatable.sol";
import "../../governance/implementation/Governed.sol";
import "../interface/IWNat.sol";
import "../interface/IClaimSetupManager.sol";
import "../lib/SafePct.sol";
import "./VoterWhitelister.sol";
import "./Finalisation.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

//solhint-disable-next-line max-states-count
contract RewardManager is Governed, AddressUpdatable, ReentrancyGuard, IITokenPool {
    using MerkleProof for bytes32[];
    using SafeCast for uint256;
    using SafePct for uint256;

    uint256 constant internal MAX_BIPS = 1e4;
    uint256 constant internal PPM_MAX = 1e6;
    address payable constant internal BURN_ADDRESS = payable(0x000000000000000000000000000000000000dEaD);

    enum ClaimType { DIRECT, FEE, WNAT, MIRROR, CCHAIN }

    struct UnclaimedRewardState {   // Used for storing unclaimed reward info.
        bool initialised;           // Information if already initialised
                                    // amount and weight might be 0 if all users already claimed
        uint120 amount;             // Total unclaimed amount.
        uint128 weight;             // Total unclaimed weight.
    }

    struct RewardClaimWithProof {
        bytes32[] merkleProof;
        uint64 rId;
        RewardClaim body;
    }

    struct RewardClaim {
        ClaimType claimType;
        uint120 amount;
        address beneficiary; // c-chain address or node id (bytes20) in case of type MIRROR
    }

    struct FeePercentage {          // used for storing data provider fee percentage settings
        uint16 value;               // fee percentage value (value between 0 and 1e4)
        uint240 validFromEpoch;     // id of the reward epoch from which the value is valid
    }

    mapping(address => uint256) private rewardOwnerNextClaimableEpoch;
    mapping(uint64 => uint64) private epochVotePowerBlock;
    mapping(uint64 => uint120) private epochTotalRewards;
    mapping(uint64 => uint120) private epochInitialisedRewards;
    mapping(uint64 => uint120) private epochClaimedRewards;
    mapping(uint64 => uint120) private epochBurnedRewards;

    uint64 public immutable feePercentageUpdateOffset; // fee percentage update timelock measured in reward epochs
    uint16 public immutable defaultFeePercentageBIPS; // default value for fee percentage
    mapping(address => FeePercentage[]) public dataProviderFeePercentages;

    /// Epochs before the token distribution event at Flare launch were not be claimable.
    /// This variable holds the first reward epoch that was claimable.
    uint256 public firstClaimableRewardEpoch;
    // id of the first epoch to expire. Closed = expired and unclaimed funds sent back
    uint256 private nextRewardEpochToExpire;
    // reward epoch when setInitialRewardData is called (set to +1) - used for forwarding closeExpiredRewardEpoch
    uint256 private initialRewardEpoch;

    mapping(uint64 => mapping(ClaimType =>
        mapping(address => UnclaimedRewardState))) public epochTypeProviderUnclaimedReward;
    // per reward epoch mark direct and fee claims (not weight based) that were already processed (paid out)
    mapping(uint64 => mapping(bytes32 => bool)) internal epochProcessedRewardClaims;
    // number of initialised weight based claims per reward epoch
    mapping(uint64 => uint256) internal epochNoOfInitialisedWeightBasedClaims;

    // Totals
    uint256 private totalClaimedWei;     // rewards that were claimed in time
    uint256 private totalExpiredWei;     // rewards that were not claimed in time and expired
    uint256 private totalUnearnedWei;    // rewards that were unearned (ftso fallback) and thus not distributed
    uint256 private totalBurnedWei;      // rewards that were unearned or expired and thus burned
    uint256 private totalFundsReceivedWei;
    uint256 private totalInflationReceivedWei;
    uint256 private totalInflationAuthorizedWei;

    uint256 private lastBalance;

    /// The VoterWhitelister contract.
    VoterWhitelister public voterWhitelister;
    IClaimSetupManager public claimSetupManager;
    Finalisation public finalisation;
    IPChainStakeMirror public pChainStakeMirror;
    IWNat public wNat;
    bool public active;

    event FeePercentageChanged(
        address indexed dataProvider,
        uint64 value,
        uint64 validFromEpoch
    );

    /**
     * Emitted when a data provider claims its FTSO rewards.
     * @param voter Address of the voter (or node id) that accrued the reward.
     * @param whoClaimed Address that actually performed the claim.
     * @param sentTo Address that received the reward.
     * @param claimType Claim type
     * @param rewardEpoch ID of the reward epoch where the reward was accrued.
     * @param amount Amount of rewarded native tokens (wei).
     */
    event RewardClaimed(
        address indexed voter,
        address indexed whoClaimed,
        address indexed sentTo,
        uint64 rewardEpoch,
        ClaimType claimType,
        uint120 amount
    );

    modifier mustBalance {
        _;
        _checkMustBalance();
    }

    /// This method can only be called if the contract is `active`.
    modifier onlyIfActive() {
        _checkOnlyActive();
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
        address _governance,
        address _addressUpdater,
        uint64 _feePercentageUpdateOffset,
        uint16 _defaultFeePercentageBIPS
    ) Governed(_governanceSettings, _governance) AddressUpdatable(_addressUpdater) {
        feePercentageUpdateOffset = _feePercentageUpdateOffset;
        defaultFeePercentageBIPS = _defaultFeePercentageBIPS;
    }

    function claim(
        address _rewardOwner,
        address payable _recipient,
        uint64 _rewardEpoch,
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
        _handleSelfDestructProceeds();
        require(_isRewardClaimable(_rewardEpoch, finalisation.getCurrentRewardEpoch()), "not claimable");
        uint120 burnAmountWei;
        (_rewardAmountWei, burnAmountWei) = _processProofs(_rewardOwner, _recipient, _proofs);

        _rewardAmountWei += _claimWeightBasedRewards(
            _rewardOwner, _recipient, _rewardEpoch, _minClaimableRewardEpoch(), false);

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

        //slither-disable-next-line reentrancy-eth      // guarded by nonReentrant
        //solhint-disable-next-line reentrancy
        lastBalance = address(this).balance;
    }

    // it supports only claiming from weight based claims
    //slither-disable-next-line reentrancy-eth          // guarded by nonReentrant
    function autoClaim(
        address[] calldata _rewardOwners,
        uint64 _rewardEpoch,
        RewardClaimWithProof[] calldata _proofs
    )
        external
        onlyIfActive
        mustBalance
        nonReentrant
    {
        _handleSelfDestructProceeds();
        for (uint256 i = 0; i < _rewardOwners.length; i++) {
            _checkNonzeroRecipient(_rewardOwners[i]);
        }

        uint256 currentRewardEpoch = finalisation.getCurrentRewardEpoch();
        require(_isRewardClaimable(_rewardEpoch, currentRewardEpoch), "not claimable");

        (address[] memory claimAddresses, uint256 executorFeeValue) =
            claimSetupManager.getAutoClaimAddressesAndExecutorFee(msg.sender, _rewardOwners);

        // initialise only weight based claims
        _processProofs(address(0), address(0), _proofs);

        uint64 minClaimableEpoch = _minClaimableRewardEpoch();
        for (uint256 i = 0; i < _rewardOwners.length; i++) {
            address rewardOwner = _rewardOwners[i];
            address claimAddress = claimAddresses[i];
            // claim for owner
            uint256 rewardAmount = _claimWeightBasedRewards(
                rewardOwner, claimAddress, _rewardEpoch, minClaimableEpoch, false);
            if (rewardOwner != claimAddress) {
                // claim for PDA (only WNat)
                rewardAmount += _claimWeightBasedRewards(
                    claimAddress, claimAddress, _rewardEpoch, minClaimableEpoch, true);
            }
            require(rewardAmount >= executorFeeValue, "claimed amount too small");
            rewardAmount -= executorFeeValue;
            if (rewardAmount > 0) {
                _transferOrWrap(claimAddress, rewardAmount, true);
            }
        }

        _transferOrWrap(msg.sender, executorFeeValue * _rewardOwners.length, false);

        //slither-disable-next-line reentrancy-eth      // guarded by nonReentrant
        lastBalance = address(this).balance;
    }

    /**
     * @notice Allows data provider to set (or update last) fee percentage.
     * @param _feePercentageBIPS    number representing fee percentage in BIPS
     * @return Returns the reward epoch number when the setting becomes effective.
     */
    function setDataProviderFeePercentage(uint16 _feePercentageBIPS) external returns (uint256) {
        require(_feePercentageBIPS <= MAX_BIPS, "fee percentage invalid");

        uint64 rewardEpoch = finalisation.getCurrentRewardEpoch() + feePercentageUpdateOffset;
        FeePercentage[] storage fps = dataProviderFeePercentages[msg.sender];

        // determine whether to update the last setting or add a new one
        uint256 position = fps.length;
        if (position > 0) {
            // do not allow updating the settings in the past
            // (this can only happen if the sharing percentage epoch offset is updated)
            require(rewardEpoch >= fps[position - 1].validFromEpoch, "fee percentage update failed");

            if (rewardEpoch == fps[position - 1].validFromEpoch) {
                // update
                position = position - 1;
            }
        }
        if (position == fps.length) {
            // add
            fps.push();
        }

        // apply setting
        fps[position].value = uint16(_feePercentageBIPS);
        assert(rewardEpoch < 2**240);
        fps[position].validFromEpoch = uint240(rewardEpoch);

        emit FeePercentageChanged(msg.sender, _feePercentageBIPS, rewardEpoch);
        return rewardEpoch;
    }


    /**
     * @notice Returns the current fee percentage of `_dataProvider`
     * @param _dataProvider         address representing data provider
     */
    function getDataProviderCurrentFeePercentage(address _dataProvider) external view returns (uint16) {
        return _getDataProviderFeePercentage(_dataProvider, finalisation.getCurrentRewardEpoch());
    }

    /**
     * @notice Returns the scheduled fee percentage changes of `_dataProvider`
     * @param _dataProvider         address representing data provider
     * @return _feePercentageBIPS   positional array of fee percentages in BIPS
     * @return _validFromEpoch      positional array of block numbers the fee setings are effective from
     * @return _fixed               positional array of boolean values indicating if settings are subjected to change
     */
    function getDataProviderScheduledFeePercentageChanges(
        address _dataProvider
    )
        external view
        returns (
            uint256[] memory _feePercentageBIPS,
            uint256[] memory _validFromEpoch,
            bool[] memory _fixed
        )
    {
        FeePercentage[] storage fps = dataProviderFeePercentages[_dataProvider];
        if (fps.length > 0) {
            uint256 currentEpoch = finalisation.getCurrentRewardEpoch();
            uint256 position = fps.length;
            while (position > 0 && fps[position - 1].validFromEpoch > currentEpoch) {
                position--;
            }
            uint256 count = fps.length - position;
            if (count > 0) {
                _feePercentageBIPS = new uint256[](count);
                _validFromEpoch = new uint256[](count);
                _fixed = new bool[](count);
                for (uint256 i = 0; i < count; i++) {
                    _feePercentageBIPS[i] = fps[i + position].value;
                    _validFromEpoch[i] = fps[i + position].validFromEpoch;
                    _fixed[i] = (_validFromEpoch[i] - currentEpoch) != feePercentageUpdateOffset;
                }
            }
        }
    }

    function getRewardEpochToExpireNext() external view returns (uint256) {
        return nextRewardEpochToExpire;
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
     * @notice Returns fee percentage setting for `_dataProvider` at `_rewardEpoch`.
     * @param _dataProvider         address representing a data provider
     * @param _rewardEpoch          reward epoch number
     */
    function _getDataProviderFeePercentage(
        address _dataProvider,
        uint256 _rewardEpoch
    )
        internal view
        returns (uint16)
    {
        FeePercentage[] storage fps = dataProviderFeePercentages[_dataProvider];
        uint256 index = fps.length;
        while (index > 0) {
            index--;
            if (_rewardEpoch >= fps[index].validFromEpoch) {
                return fps[index].value;
            }
        }
        return defaultFeePercentageBIPS;
    }

    function _getBurnFactor(uint64 _rewardEpoch, address _rewardOwner) internal view returns(uint256) {
        return finalisation.getRewardsFeeBurnFactor(_rewardEpoch, _rewardOwner);
    }

    function _getVotePower(
        uint64 _rewardEpoch,
        address _beneficiary,
        ClaimType _claimType
    )
        internal view
        returns (uint128)
    {
        uint256 votePowerBlock = _getVotePowerBlock(_rewardEpoch);
        if (_claimType == ClaimType.WNAT) {
            return wNat.votePowerOfAt(_beneficiary, votePowerBlock).toUint128();
        } else if (_claimType == ClaimType.MIRROR) {
            return pChainStakeMirror.votePowerOfAt(bytes20(_beneficiary), votePowerBlock).toUint128();
        } else if (_claimType == ClaimType.CCHAIN) {
            return 0; // TODO cChain.votePowerOfAt(_beneficiary, votePowerBlock).toUint128();
        } else {
            return 0;
        }
    }

    function _getVotePowerBlock(uint64 _rewardEpoch) internal view returns (uint256) {
        return finalisation.getVotePowerBlock(_rewardEpoch); // TODO - save locally?
    }

    function _processProofs(
        address _rewardOwner,
        address _recipient,
        RewardClaimWithProof[] calldata _proofs
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
            } else { // weight based claims
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
        require(rewardClaim.beneficiary == _rewardOwner, "wrong beneficiary");
        bytes32 claimHash = keccak256(abi.encode(rewardClaim));
        if (!epochProcessedRewardClaims[_proof.rId][claimHash]) {
            // not claimed yet - check if valid merkle proof
            bytes32 merkleRoot = finalisation.getConfirmedMerkleRoot(REWARDS_PROTOCOL_ID, _proof.rId);
            require(_proof.merkleProof.verify(merkleRoot, claimHash), "merkle proof invalid");
            // initialise reward amount
            _rewardAmountWei = _initialiseRewardAmount(_proof.rId, rewardClaim.amount);
            if (rewardClaim.claimType == ClaimType.FEE) {
                uint256 burnFactor = _getBurnFactor(_proof.rId, _rewardOwner);
                if (burnFactor > 0) {
                    // calculate burn amount
                    _burnAmountWei = Math.min(_rewardAmountWei, uint256(_rewardAmountWei).
                        mulDiv(burnFactor, PPM_MAX)).toUint120();
                    // reduce reward amount
                    _rewardAmountWei -= _burnAmountWei; // _burnAmountWei <= _rewardAmountWei
                    // update total burned amount per epoch
                    epochBurnedRewards[_proof.rId] += _burnAmountWei;
                    // emit event how much of the reward was burned
                    // TODO - different event?
                    emit RewardClaimed(
                        _rewardOwner,
                        _rewardOwner,
                        BURN_ADDRESS,
                        _proof.rId,
                        ClaimType.FEE,
                        _burnAmountWei
                    );
                }
            }
            // update total claimed amount per epoch
            epochClaimedRewards[_proof.rId] += _rewardAmountWei;
            // mark as claimed
            epochProcessedRewardClaims[_proof.rId][claimHash] = true;
            // emit event
            emit RewardClaimed(
                _rewardOwner,
                _rewardOwner,
                _recipient,
                _proof.rId,
                rewardClaim.claimType,
                _rewardAmountWei
            );
        }
    }

    function _initialiseWeightBasedClaim(RewardClaimWithProof calldata _proof) internal {
        RewardClaim calldata rewardClaim = _proof.body;
        UnclaimedRewardState storage state =
            epochTypeProviderUnclaimedReward[_proof.rId][rewardClaim.claimType][rewardClaim.beneficiary];
        if (!state.initialised) {
            // not initialised yet - check if valid merkle proof
            bytes32 merkleRoot = finalisation.getConfirmedMerkleRoot(REWARDS_PROTOCOL_ID, _proof.rId);
            bytes32 claimHash = keccak256(abi.encode(rewardClaim));
            require(_proof.merkleProof.verify(merkleRoot, claimHash), "merkle proof invalid");
            // mark as initialised
            state.initialised = true;
            // initialise reward amount
            state.amount = _initialiseRewardAmount(_proof.rId, rewardClaim.amount);
            // initialise weight
            state.weight = _getVotePower(_proof.rId, rewardClaim.beneficiary, rewardClaim.claimType);
            // increase the number of initialised weight based claims
            epochNoOfInitialisedWeightBasedClaims[_proof.rId] += 1;
        }
    }

    function _initialiseRewardAmount(
        uint64 _rewardEpoch,
        uint120 _rewardClaimAmount
    )
        internal
        returns (uint120 _rewardAmount)
    {
        // get total reward amount
        uint120 totalRewards = epochTotalRewards[_rewardEpoch];
        if (totalRewards == 0) {
            // if not initialised yet, do it now
            //_totalRewards = TODO get information from offers/poll?
            epochTotalRewards[_rewardEpoch] = totalRewards;
        }
        // get already initalised rewards
        uint120 initialisedRewards = epochInitialisedRewards[_rewardEpoch];
        _rewardAmount = _rewardClaimAmount;
        if (totalRewards < initialisedRewards + _rewardClaimAmount) {
            // reduce reward amount in case of invalid off-chain calculations
            _rewardAmount = totalRewards - initialisedRewards; // totalRewards >= initialisedRewards
        }
        // increase initialised reward amount
        epochInitialisedRewards[_rewardEpoch] += _rewardAmount;
    }

    function _claimWeightBasedRewards(
        address _rewardOwner,
        address _recipient,
        uint64 _rewardEpoch,
        uint64 _minClaimableEpoch,
        bool _onlyWNat
    )
        internal
        returns (uint120 _rewardAmountWei)
    {
        for (uint64 epoch = _nextClaimableEpoch(_rewardOwner, _minClaimableEpoch); epoch <= _rewardEpoch; epoch++) {
            // check if all weight based claims were already initialised
            // (in this case zero unclaimed rewards are actually zeros)
            bool allClaimsInitialised = epochNoOfInitialisedWeightBasedClaims[epoch]
                == finalisation.noOfWeightBasedClaims(epoch);
            uint256 votePowerBlock = _getVotePowerBlock(epoch);
            uint120 rewardAmount = 0;

            // WNAT claims
            rewardAmount += _claimWNatRewards(_rewardOwner, _recipient, epoch, votePowerBlock, allClaimsInitialised);

            if (!_onlyWNat) {
                // MIRROR claims
                rewardAmount += _claimMirrorRewards(
                    _rewardOwner, _recipient, epoch, votePowerBlock, allClaimsInitialised);

                // CCHAIN claims
                // TODO
            }

            // update total claimed amount per epoch
            epochClaimedRewards[epoch] += rewardAmount;
            _rewardAmountWei += rewardAmount;
        }

        // mark epochs up to `_rewardEpoch` as claimed
        if (rewardOwnerNextClaimableEpoch[_rewardOwner] < _rewardEpoch + 1) {
            rewardOwnerNextClaimableEpoch[_rewardOwner] = _rewardEpoch + 1;
        }
    }

    function _claimWNatRewards(
        address _rewardOwner,
        address _recipient,
        uint64 _epoch,
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
            if (delegatorBalance > delegatedVotePower &&
                voterWhitelister.getVoterSigningAddress(_epoch, _rewardOwner) != address(0))
            {
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
        uint64 _epoch,
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
        voterWhitelister = VoterWhitelister(
            _getContractAddress(_contractNameHashes, _contractAddresses, "VoterWhitelister"));
        claimSetupManager = IClaimSetupManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "ClaimSetupManager"));
        finalisation = Finalisation(
            _getContractAddress(_contractNameHashes, _contractAddresses, "Finalisation"));
        pChainStakeMirror = IPChainStakeMirror(
            _getContractAddress(_contractNameHashes, _contractAddresses, "PChainStakeMirror"));
        wNat = IWNat(
            _getContractAddress(_contractNameHashes, _contractAddresses, "WNat"));
    }

    /**
     * Reports if rewards for `_rewardEpoch` are claimable.
     * @param _rewardEpoch          reward epoch number
     * @param _currentRewardEpoch   number of the current reward epoch
     */
    function _isRewardClaimable(uint256 _rewardEpoch, uint256 _currentRewardEpoch) internal view returns (bool) {
        return _rewardEpoch >= firstClaimableRewardEpoch &&
               _rewardEpoch >= nextRewardEpochToExpire &&
               _rewardEpoch < _currentRewardEpoch;
    }

    function _nextClaimableEpoch(address _rewardOwner, uint256 _minClaimableEpoch) internal view returns (uint64) {
        return Math.max(rewardOwnerNextClaimableEpoch[_rewardOwner], _minClaimableEpoch).toUint64();
    }

    function _minClaimableRewardEpoch() internal view returns (uint64) {
        return Math.max(firstClaimableRewardEpoch,
            Math.max(_getInitialRewardEpoch(), nextRewardEpochToExpire)).toUint64();
    }

    /**
     * Return initial reward epoch number
     * @return _initialRewardEpoch Initial reward epoch number.
     */
    function _getInitialRewardEpoch() internal view returns (uint256 _initialRewardEpoch) {
        _initialRewardEpoch = initialRewardEpoch == 0 ? 0 : initialRewardEpoch - 1;
    }

    function _handleSelfDestructProceeds() internal returns (uint256 _expectedBalance) {
        _expectedBalance = lastBalance + msg.value;
        uint256 currentBalance = address(this).balance;
        if (currentBalance > _expectedBalance) {
            // Then assume extra were self-destruct proceeds and burn it
            //slither-disable-next-line arbitrary-send-eth
            BURN_ADDRESS.transfer(currentBalance - _expectedBalance);
        } else if (currentBalance < _expectedBalance) {
            // This is a coding error
            assert(false);
        }
    }

    function _getExpectedBalance() private view returns(uint256 _balanceExpectedWei) {
        return totalFundsReceivedWei -totalClaimedWei - totalBurnedWei;
    }

    function _checkExecutorAndAllowedRecipient(address _rewardOwner, address _recipient) private view {
        if (msg.sender == _rewardOwner) {
            return;
        }
        claimSetupManager.checkExecutorAndAllowedRecipient(msg.sender, _rewardOwner, _recipient);
    }


    function _checkMustBalance() private view {
        require(address(this).balance == _getExpectedBalance(), "out of balance");
    }

    function _checkOnlyActive() private view {
        require(active, "reward manager deactivated");
    }

    function _checkNonzeroRecipient(address _address) private pure {
        require(_address != address(0), "recipient zero");
    }
}
