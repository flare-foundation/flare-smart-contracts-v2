// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;
pragma abicoder v2;

import { IICleanable, GovernedAndFlareDaemonized, FlareDaemon, IFlareDaemonize, ReentrancyGuard,
         IIGovernanceVotePower, AddressUpdatable, SafePct, SafeMath, SafeCast }
    from "../../flattened/FlareSmartContracts.sol";
import "../protocol/interface/ICChainStake.sol";
import "./CChainStakeBase.sol";



/**
 * Contract used for C-Chain stakes and delegations.
 */
contract CChainStake is ICChainStake, CChainStakeBase, GovernedAndFlareDaemonized,
        IFlareDaemonize, IICleanable, AddressUpdatable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeCast for uint256;
    using SafePct for uint256;

    /**
     * Structure with data needed to end stakes
     */
    struct CChainStakingData {
        address owner;
        address account;
        uint256 weightWei;
    }

    /// Indicates if staking is activated.
    bool public active;
    /// Minimum stake duration in seconds.
    uint256 public minStakeDurationSeconds;
    /// Maximum stake duration in seconds.
    uint256 public maxStakeDurationSeconds;
    /// Minimum stake amount in Wei.
    uint256 public minStakeAmountWei;
    /// Max number of stake ends that Flare daemon updates per block.
    uint256 public maxUpdatesPerBlock;
    /// Indicates timestamp of stake ends that Flare daemon will trigger next.
    uint256 public nextTimestampToTrigger;

    /// Mapping from stake end time to the list of staking data
    mapping(uint256 => CChainStakingData[]) public endTimeToStakingDataList;

    /// mapping from address to the claimable/restakable amount (sum of expired stakes)
    mapping(address => uint256) public totalExpiredStakeWei;

    // addresses
    /// The contract to use for governance vote power and delegation.
    /// Here only to properly update governance VP at stake start/end,
    /// all actual operations go directly to governance VP contract.
    IIGovernanceVotePower public governanceVotePower;
    /// The contract that is allowed to set cleanupBlockNumber.
    /// Usually this will be an instance of CleanupBlockNumberManager.
    address public cleanupBlockNumberManager;

    /**
     * Event emitted when max updates per block is set.
     * @param maxUpdatesPerBlock new number of max updated per block
     */
    event MaxUpdatesPerBlockSet(uint256 maxUpdatesPerBlock);

    /**
     * Event emitted when the stake is confirmed.
     * @param owner The address who opened the stake.
     * @param account Account to which the stake was added.
     * @param amountWei Stake amount (in wei).
     */
    event StakeConfirmed(
        address indexed owner,
        address indexed account,
        uint256 amountWei
    );

    /**
     * Event emitted when the stake has ended.
     * @param owner The address whose stake has ended.
     * @param account Account from which the stake was removed.
     * @param amountWei Stake amount (in wei).
     */
    event StakeEnded(
        address indexed owner,
        address indexed account,
        uint256 amountWei
    );

    /// This method can only be called when the CChainStake is active.
    modifier whenActive {
        require(active, "not active");
        _;
    }

    /**
     * Initializes the contract with default parameters
     * @param _governance Address identifying the governance address.
     * @param _flareDaemon Address identifying the flare daemon contract.
     * @param _addressUpdater Address identifying the address updater contract.
     * @param _minStakeDurationSeconds Minimum stake duration in seconds.
     * @param _maxStakeDurationSeconds Maximum stake duration in seconds.
     * @param _minStakeAmountWei Minimum stake amount in Wei.
     * @param _maxUpdatesPerBlock Max number of updates (stake ends) per block.
     */
    constructor(
        address _governance,
        FlareDaemon _flareDaemon,
        address _addressUpdater,
        uint256 _minStakeAmountWei,
        uint256 _minStakeDurationSeconds,
        uint256 _maxStakeDurationSeconds,
        uint256 _maxUpdatesPerBlock
    )
        GovernedAndFlareDaemonized(_governance, _flareDaemon) AddressUpdatable(_addressUpdater)
    {
        minStakeAmountWei = _minStakeAmountWei;
        minStakeDurationSeconds = _minStakeDurationSeconds;
        maxStakeDurationSeconds = _maxStakeDurationSeconds;
        maxUpdatesPerBlock = _maxUpdatesPerBlock;
        emit MaxUpdatesPerBlockSet(_maxUpdatesPerBlock);
    }

    /**
     * Activates CChainStake contract - enable mirroring.
     * @dev Only governance can call this.
     */
    function activate() external onlyImmediateGovernance {
        active = true;
        if (nextTimestampToTrigger == 0) {
            nextTimestampToTrigger = block.timestamp;
        }
    }

    /**
     * Deactivates CChainStake contract - disable mirroring.
     * @dev Only governance can call this.
     */
    function deactivate() external onlyImmediateGovernance {
        active = false;
    }

    /**
     * @inheritdoc IFlareDaemonize
     * @dev Only flare daemon can call this.
     * Reduce balances and vote powers for stakes that just ended.
     */
    function daemonize() external override onlyFlareDaemon returns (bool) {
        uint256 nextTimestampToTriggerTmp = nextTimestampToTrigger;
        // flare daemon trigger. once every block
        if (nextTimestampToTriggerTmp == 0) return false;

        uint256 maxUpdatesPerBlockTemp = maxUpdatesPerBlock;
        uint256 noOfUpdates = 0;
        while (nextTimestampToTriggerTmp <= block.timestamp) {
            for (uint256 i = endTimeToStakingDataList[nextTimestampToTriggerTmp].length; i > 0; i--) {
                noOfUpdates++;
                if (noOfUpdates > maxUpdatesPerBlockTemp) {
                    break;
                } else {
                    CChainStakingData memory data = endTimeToStakingDataList[nextTimestampToTriggerTmp][i - 1];
                    endTimeToStakingDataList[nextTimestampToTriggerTmp].pop();
                    _decreaseStakeAmount(data);
                }
            }
            if (noOfUpdates > maxUpdatesPerBlockTemp) {
                break;
            } else {
                nextTimestampToTriggerTmp++;
            }
        }

        nextTimestampToTrigger = nextTimestampToTriggerTmp;
        return true;
    }

    /**
     * Stake funds.
     * @param _account Account address to stake to
     * @param _endTime End time of stake
     */
    function stake(
        address _account,
        uint256 _endTime
    )
        external payable whenActive
    {
        require(msg.value >= minStakeAmountWei, "staking amount too low");
        require(_endTime >= block.timestamp + minStakeDurationSeconds, "staking time too short");
        require(_endTime <= block.timestamp + maxStakeDurationSeconds, "staking time too long");

        CChainStakingData memory cChainStakingData = CChainStakingData(msg.sender, _account, msg.value);
        endTimeToStakingDataList[_endTime].push(cChainStakingData);
        _increaseStakeAmount(cChainStakingData);
    }

    /**
     * Restake funds that has expired.
     * @param _account Account address to stake to
     * @param _endTime End time of stake
     */
    function restake(
        address _account,
        uint256 _endTime
    )
        external whenActive
    {
        uint256 amountWei = totalExpiredStakeWei[msg.sender];
        require(totalExpiredStakeWei[msg.sender] >= minStakeAmountWei, "staking amount too low");
        require(_endTime >= block.timestamp + minStakeDurationSeconds, "staking time too short");
        require(_endTime <= block.timestamp + maxStakeDurationSeconds, "staking time too long");

        CChainStakingData memory cChainStakingData = CChainStakingData(msg.sender, _account, amountWei);
        delete totalExpiredStakeWei[msg.sender];
        endTimeToStakingDataList[_endTime].push(cChainStakingData);
        _increaseStakeAmount(cChainStakingData);
    }

    /**
     * Claim funds that has expired.
     */
    function claim(address payable _recipient)
        external
        nonReentrant
    {
        uint256 amountWei = totalExpiredStakeWei[msg.sender];
        delete totalExpiredStakeWei[msg.sender];

        /* solhint-disable avoid-low-level-calls */
        //slither-disable-next-line arbitrary-send-eth
        (bool success, ) = _recipient.call{value: amountWei}("");
        /* solhint-enable avoid-low-level-calls */
        require(success, "claim failed");
    }

    /**
     * Sets max number of updates (stake ends) per block (a daemonize call).
     * @param _maxUpdatesPerBlock Max number of updates (stake ends) per block
     * @dev Only governance can call this.
     */
    function setMaxUpdatesPerBlock(uint256 _maxUpdatesPerBlock) external onlyGovernance {
        maxUpdatesPerBlock = _maxUpdatesPerBlock;
        emit MaxUpdatesPerBlockSet(_maxUpdatesPerBlock);
    }


    /**
     * @inheritdoc IFlareDaemonize
     * @dev Only flare daemon can call this.
     */
    function switchToFallbackMode() external override onlyFlareDaemon returns (bool) {
        if (maxUpdatesPerBlock > 0) {
            maxUpdatesPerBlock = maxUpdatesPerBlock.mulDiv(4, 5);
            emit MaxUpdatesPerBlockSet(maxUpdatesPerBlock);
            return true;
        }
        return false;
    }

    /**
     * @inheritdoc IICleanable
     * @dev The method can be called only by `cleanupBlockNumberManager`.
     */
    function setCleanupBlockNumber(uint256 _blockNumber) external override {
        require(msg.sender == cleanupBlockNumberManager, "only cleanup block manager");
        _setCleanupBlockNumber(_blockNumber);
    }

    /**
     * @inheritdoc IICleanable
     * @dev Only governance can call this.
     */
    function setCleanerContract(address _cleanerContract) external override onlyGovernance {
        _setCleanerContract(_cleanerContract);
    }

    /**
     * @inheritdoc IICleanable
     */
    function cleanupBlockNumber() external view override returns (uint256) {
        return _cleanupBlockNumber();
    }

    /**
     * Returns the list of CChainStakingData that end at given `_endTime`.
     * @param _endTime Time when stakes end, in seconds from UNIX epoch.
     * @return List of CChainStakingData.
     */
    function getTransactionList(uint256 _endTime) external view returns (CChainStakingData[] memory) {
        return endTimeToStakingDataList[_endTime];
    }

    /**
     * @inheritdoc IFlareDaemonize
     */
    function getContractName() external pure override returns (string memory) {
        return "CChainStake";
    }

    /**
     * @inheritdoc ICChainStake
     */
    function totalSupply() public view override returns(uint256) {
        return CheckPointable.totalSupplyAt(block.number);
    }

    /**
     * @inheritdoc ICChainStake
     */
    function balanceOf(address _owner) public view override returns (uint256) {
        return CheckPointable.balanceOfAt(_owner, block.number);
    }

    /**
     * @inheritdoc ICChainStake
     */
    function totalSupplyAt(
        uint256 _blockNumber
    )
        public view
        override(ICChainStake, CheckPointable)
        returns(uint256)
    {
        return CheckPointable.totalSupplyAt(_blockNumber);
    }

    /**
     * @inheritdoc ICChainStake
     */
    function balanceOfAt(
        address _owner,
        uint256 _blockNumber
    )
        public view
        override(ICChainStake, CheckPointable)
        returns (uint256)
    {
        return CheckPointable.balanceOfAt(_owner, _blockNumber);
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
        cleanupBlockNumberManager =
            _getContractAddress(_contractNameHashes, _contractAddresses, "CleanupBlockNumberManager");
        governanceVotePower = IIGovernanceVotePower(
            _getContractAddress(_contractNameHashes, _contractAddresses, "GovernanceVotePower"));
    }

    /**
     * Increase balance for owner and add vote power to account.
     */
    function _increaseStakeAmount(CChainStakingData memory _data) internal {
        _mintForAtNow(_data.owner, _data.weightWei); // increase balance
        _increaseVotePower(_data.owner, _data.account, _data.weightWei);

        // update governance vote powers
        governanceVotePower.updateAtTokenTransfer(address(0), _data.owner, 0, 0, _data.weightWei);

        emit StakeConfirmed(_data.owner, _data.account, _data.weightWei);
    }

    /**
     * Decrease balance for owner and remove vote power from account.
     */
    function _decreaseStakeAmount(CChainStakingData memory _data) internal {
        _burnForAtNow(_data.owner, _data.weightWei); // decrease balance
        _decreaseVotePower(_data.owner, _data.account, _data.weightWei);

        // update governance vote powers
        governanceVotePower.updateAtTokenTransfer(_data.owner, address(0), 0, 0, _data.weightWei);
        totalExpiredStakeWei[_data.owner] += _data.weightWei;

        emit StakeEnded(_data.owner, _data.account, _data.weightWei);
    }
}
