// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./CloneFactory.sol";
import "../interface/IIRNat.sol";
import "../interface/IIRNatAccount.sol";
import "../../governance/implementation/Governed.sol";
import "../../incentivePool/implementation/IncentivePoolReceiver.sol";
import "../../protocol/interface/IIClaimSetupManager.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


/**
 * RNat is a non-transferable linearly vested token (12 months). This contract is used for managing all processes
 * related to the RNat token - assigning, distributing, claiming and withdrawing.
 */
contract RNat is IIRNat, Governed, IncentivePoolReceiver, CloneFactory, ReentrancyGuard {

    /// Struct used to store the project data.
    struct Project {
        string name;
        address distributor;
        bool currentMonthDistributionEnabled;
        bool distributionDisabled;
        bool claimingDisabled;
        uint128 totalAssignedRewards;
        uint128 totalDistributedRewards;
        uint128 totalClaimedRewards;
        uint128 totalUnassignedUnclaimedRewards;
        mapping(uint256 month => MonthlyRewards) monthlyRewards;
        uint256[] monthsWithRewards; // sorted list of months with rewards
        // equal to project.monthsWithRewards.length when all rewards are claimed and the last month is in the past
        mapping(address owner => uint256 index) lastClaimingMonthIndex;
    }

    /// Struct used to store the monthly rewards data.
    struct MonthlyRewards {
        uint128 assignedRewards;
        uint128 distributedRewards; // distributedRewards <= assignedRewards
        uint128 claimedRewards; // claimedRewards <= distributedRewards
        uint128 unassignedUnclaimedRewards; // unassignedUnclaimedRewards <= distributedRewards - claimedRewards
        mapping(address owner => Rewards) rewards;
    }

    /// Struct used to store the rewards data for the owner.
    struct Rewards {
        uint128 assignedRewards;
        uint128 claimedRewards;
    }

    /// The duration of a month in seconds.
    uint256 public constant MONTH = 30 days;
    /// The timestamp of the first month start.
    uint256 public immutable firstMonthStartTs;

    /// @inheritdoc IERC20Metadata
    string public name;
    /// @inheritdoc IERC20Metadata
    string public symbol;
    /// @inheritdoc IERC20Metadata
    uint8 public immutable decimals;

    /// Total assignable rewards received from the funding address or the incentive pool.
    uint128 internal totalAssignableRewards;
    /// Already assigned rewards.
    uint128 internal totalAssignedRewards;
    /// Total claimed rewards.
    uint128 internal totalClaimedRewards;
    /// Total withdrawn rewards.
    uint128 internal totalWithdrawnRewards;
    /// Total withdrawn assignable rewards (needed for the circulating supply calculation).
    uint128 internal totalWithdrawnAssignableRewards;

    /// Indicates if the incentive pool is enabled.
    bool public incentivePoolEnabled;

    /// The `ClaimSetupManager` contract.
    IIClaimSetupManager public claimSetupManager;
    /// The `WNat` contract.
    IWNat public wNat;

    /// The address of the library contract (RNatAccount).
    address public libraryAddress;
    /// The manager address.
    address public manager;
    /// The funding address.
    address public fundingAddress;

    Project[] internal projects;

    mapping(address owner => IIRNatAccount) private ownerToRNatAccount;
    mapping(IIRNatAccount => address owner) private rNatAccountToOwner;

    modifier onlyManager() {
        _checkOnlyManager();
        _;
    }

    /**
     * Constructor.
     * @param _governanceSettings The address of the GovernanceSettings contract.
     * @param _initialGovernance The initial governance address.
     * @param _addressUpdater The address of the AddressUpdater contract.
     * @param _manager The manager address.
     * @param _firstMonthStartTs The timestamp of the first month start.
     */
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _manager,
        uint256 _firstMonthStartTs
    )
        Governed(_governanceSettings, _initialGovernance) IncentivePoolReceiver(_addressUpdater)
    {
        require(_firstMonthStartTs <= block.timestamp, "first month start in the future");
        _checkNonzeroAddress(_manager);
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        manager = _manager;
        firstMonthStartTs = _firstMonthStartTs;
    }

    /**
     * External payable function to receive rewards from the funding address.
     */
    function receiveRewards() external payable mustBalance {
        require(msg.sender == fundingAddress, "not a funding address");
        totalAssignableRewards += uint128(msg.value);
    }

    //////////////////////////// Protocol's distributor functions ////////////////////////////

    /**
     * @inheritdoc IRNat
     */
    function distributeRewards(
        uint256 _projectId,
        uint256 _month,
        address[] calldata _recipients,
        uint128[] calldata _amountsWei
    )
        external
    {
        require(_recipients.length == _amountsWei.length, "lengths mismatch");
        Project storage project = _getProject(_projectId);
        _checkDistributionEnabled(project);
        uint256 currentMonth = _getCurrentMonth();
        require(currentMonth == _month + 1 || (project.currentMonthDistributionEnabled && currentMonth == _month),
            "distribution for month disabled");
        require(project.distributor == msg.sender, "only distributor");
        uint128 totalAmount = 0;
        MonthlyRewards storage monthlyRewards = project.monthlyRewards[_month];
        for (uint256 i = 0; i < _recipients.length; i++) {
            _checkNonzeroAddress(_recipients[i]);
            monthlyRewards.rewards[_recipients[i]].assignedRewards += _amountsWei[i];
            totalAmount += _amountsWei[i];
        }
        require(monthlyRewards.distributedRewards + totalAmount <= monthlyRewards.assignedRewards,
            "exceeds assigned rewards");
        monthlyRewards.distributedRewards += totalAmount;
        project.totalDistributedRewards += totalAmount;
        emit RewardsDistributed(_projectId, _month, _recipients, _amountsWei);
    }

    //////////////////////////// User's functions ////////////////////////////

    /**
     * @inheritdoc IRNat
     */
    //slither-disable-next-line reentrancy-eth
    function claimRewards(
        uint256[] calldata _projectIds,
        uint256 _month
    )
        external
        mustBalance
        nonReentrant
        returns (
            uint128 _claimedRewardsWei
        )
    {
        uint256 currentMonth = _getCurrentMonth();
        require(_month <= currentMonth, "month in the future");
        for (uint256 i = 0; i < _projectIds.length; i++) {
            _claimedRewardsWei += _claimRewards(_projectIds[i], _month, currentMonth);
        }
        totalClaimedRewards += _claimedRewardsWei;
        emit Transfer(address(0), msg.sender, _claimedRewardsWei);
    }

    /**
     * @inheritdoc IRNat
     */
    function setClaimExecutors(address[] calldata _executors) external payable {
        _getOrCreateRNatAccount().setClaimExecutors{value: msg.value}(claimSetupManager, _executors);
    }

    /**
     * @inheritdoc IRNat
     */
    function withdraw(uint128 _amount, bool _wrap) external mustBalance {
        uint128 amount = _getOrCreateRNatAccount().withdraw(wNat, firstMonthStartTs, _amount, _wrap);
        totalWithdrawnRewards += amount;
        emit Transfer(msg.sender, address(0), amount);
    }

    /**
     * @inheritdoc IRNat
     */
    function withdrawAll(bool _wrap) external mustBalance {
        uint128 amount = _getOrCreateRNatAccount().withdrawAll(wNat, firstMonthStartTs, _wrap);
        totalWithdrawnRewards += amount;
        emit Transfer(msg.sender, address(0), amount);
    }

    /**
     * @inheritdoc IRNat
     */
    function transferExternalToken(IERC20 _token, uint256 _amount) external nonReentrant {
        _getOrCreateRNatAccount().transferExternalToken(wNat, _token, _amount);
    }

    //////////////////////////// Manager's functions ////////////////////////////

    /**
     * @inheritdoc IIRNat
     */
    function addProjects(
        string[] calldata _names,
        address[] calldata _distributors,
        bool[] calldata _currentMonthDistributionEnabledList
    )
        external
        onlyManager
    {
        require(_names.length == _distributors.length && _names.length == _currentMonthDistributionEnabledList.length,
            "lengths mismatch");
        for (uint256 i = 0; i < _names.length; i++) {
            _checkNonzeroAddress(_distributors[i]);
            uint256 projectId = projects.length;
            projects.push();
            Project storage project = projects[projectId];
            project.name = _names[i];
            project.distributor = _distributors[i];
            project.currentMonthDistributionEnabled = _currentMonthDistributionEnabledList[i];
            emit ProjectAdded(projectId, _names[i], _distributors[i], _currentMonthDistributionEnabledList[i]);
        }
    }

    /**
     * @inheritdoc IIRNat
     */
    function updateProject(
        uint256 _projectId,
        string calldata _name,
        address _distributor,
        bool _currentMonthDistributionEnabled
    )
        external
        onlyManager
    {
        Project storage project = _getProject(_projectId);
        _checkNonzeroAddress(_distributor);
        project.name = _name;
        project.distributor = _distributor;
        project.currentMonthDistributionEnabled = _currentMonthDistributionEnabled;
        emit ProjectUpdated(_projectId, _name, _distributor, _currentMonthDistributionEnabled);
    }

    /**
     * @inheritdoc IIRNat
     */
    function assignRewards(
        uint256 _month,
        uint256[] calldata _projectIds,
        uint128[] calldata _amountsWei
    )
        external
        onlyManager
    {
        require(_month + 1 >= _getCurrentMonth(), "month too far in the past");
        require(_projectIds.length == _amountsWei.length, "lengths mismatch");
        uint128 totalAmount = 0;
        for (uint256 i = 0; i < _projectIds.length; i++) {
            Project storage project = _getProject(_projectIds[i]);
            _checkDistributionEnabled(project);
            project.totalAssignedRewards += _amountsWei[i];
            MonthlyRewards storage monthlyRewards = project.monthlyRewards[_month];
            monthlyRewards.assignedRewards += _amountsWei[i];
            totalAmount += _amountsWei[i];
            uint256 index = project.monthsWithRewards.length;
            if (index == 0 || project.monthsWithRewards[index - 1] < _month) {
                project.monthsWithRewards.push(_month); // this should  be true most of the time
            } else {
                while (index > 0 && project.monthsWithRewards[index - 1] >= _month) {
                    index--;
                }
                if (project.monthsWithRewards[index] != _month) {
                    project.monthsWithRewards.push();
                    for (uint256 j = project.monthsWithRewards.length - 1; j > index; j--) {
                        project.monthsWithRewards[j] = project.monthsWithRewards[j - 1];
                    }
                    project.monthsWithRewards[index] = _month;
                }
            }
            emit RewardsAssigned(_projectIds[i], _month, _amountsWei[i]);
        }
        require(totalAssignedRewards + totalAmount <= totalAssignableRewards, "exceeds assignable rewards");
        totalAssignedRewards += totalAmount;
    }

    /**
     * @inheritdoc IIRNat
     */
    function disableDistribution(uint256[] memory _projectIds) external onlyManager {
        for (uint256 i = 0; i < _projectIds.length; i++) {
            Project storage project = _getProject(_projectIds[i]);
            project.distributionDisabled = true;
        }
        emit DistributionPermissionUpdated(_projectIds, true);
    }

    /**
     * @inheritdoc IIRNat
     */
    function disableClaiming(uint256[] memory _projectIds) external onlyManager {
        for (uint256 i = 0; i < _projectIds.length; i++) {
            Project storage project = _getProject(_projectIds[i]);
            project.claimingDisabled = true;
        }
        emit ClaimingPermissionUpdated(_projectIds, true);
    }

    //////////////////////////// Manager's + Governance's functions ////////////////////////////

    /**
     * @inheritdoc IIRNat
     */
    function unassignRewards(uint256 _projectId, uint256[] memory _months) external {
        require (msg.sender == manager || msg.sender == governance(), "only manager or governance");
        Project storage project = _getProject(_projectId);
        uint256 currentMonth = _getCurrentMonth();
        uint128 totalAmount = 0;
        for (uint256 i = 0; i < _months.length; i++) {
            require(_months[i] + 1 < currentMonth || (project.distributionDisabled && msg.sender == governance()),
                "unassignment not allowed");
            MonthlyRewards storage monthlyRewards = project.monthlyRewards[_months[i]];
            uint128 amount = monthlyRewards.assignedRewards - monthlyRewards.distributedRewards;
            monthlyRewards.assignedRewards -= amount;
            totalAmount += amount;
            emit RewardsUnassigned(_projectId, _months[i], amount);
        }
        project.totalAssignedRewards -= totalAmount;
        totalAssignedRewards -= totalAmount;
    }

    //////////////////////////// Governance's functions ////////////////////////////

    /**
     * Method for unassigning unclaimed rewards from the project. Can only be called by governance when the claiming
     * is disabled for the project. In case of non-zero unassigned unclaimed rewards this permanently disables the
     * distribution and claiming of the rewards for the project.
     * @param _projectId The project id.
     * @param _months The months for which the rewards are unassigned.
     */
    function unassignUnclaimedRewards(uint256 _projectId, uint256[] memory _months) external onlyImmediateGovernance {
        Project storage project = _getProject(_projectId);
        require(project.claimingDisabled, "claiming not disabled");
        uint128 totalAmount = 0;
        for (uint256 i = 0; i < _months.length; i++) {
            MonthlyRewards storage monthlyRewards = project.monthlyRewards[_months[i]];
            uint128 amount = monthlyRewards.distributedRewards -
                monthlyRewards.unassignedUnclaimedRewards - monthlyRewards.claimedRewards;
            monthlyRewards.unassignedUnclaimedRewards += amount;
            totalAmount += amount;
            emit UnclaimedRewardsUnassigned(_projectId, _months[i], amount);
        }

        project.totalUnassignedUnclaimedRewards += totalAmount;
        totalAssignedRewards -= totalAmount;
        project.distributionDisabled = true;
        uint256[] memory projectIds = new uint256[](1);
        projectIds[0] = _projectId;
        emit DistributionPermissionUpdated(projectIds, true);
    }

    /**
     * Method for enabling the distribution for the projects. It reverts in case of permanently disabled claiming.
     * @param _projectIds The ids of the projects.
     */
    function enableDistribution(uint256[] memory _projectIds) external onlyImmediateGovernance {
        for (uint256 i = 0; i < _projectIds.length; i++) {
            Project storage project = _getProject(_projectIds[i]);
            _checkClaimingNotPermanentlyDisabled(project);
            project.distributionDisabled = false;
        }
        emit DistributionPermissionUpdated(_projectIds, false);
    }

    /**
     * Method for enabling the claiming for the projects. It reverts in case of permanently disabled claiming.
     * @param _projectIds The ids of the projects.
     */
    function enableClaiming(uint256[] memory _projectIds) external onlyImmediateGovernance {
        for (uint256 i = 0; i < _projectIds.length; i++) {
            Project storage project = _getProject(_projectIds[i]);
            _checkClaimingNotPermanentlyDisabled(project);
            project.claimingDisabled = false;
        }
        emit ClaimingPermissionUpdated(_projectIds, false);
    }

    /**
     * Method for setting the manager address.
     * @param _manager The manager address.
     */
    function setManager(address _manager) external onlyImmediateGovernance {
        _checkNonzeroAddress(_manager);
        manager = _manager;
    }

    /**
     * Method for setting the funding address.
     * @param _fundingAddress The funding address.
     */
    function setFundingAddress(address _fundingAddress) external onlyGovernance {
        fundingAddress = _fundingAddress;
    }

    /**
     * Sets the library address.
     * @dev Only governance can call this.
     */
    function setLibraryAddress(address _libraryAddress) external onlyGovernance {
        require(_isContract(_libraryAddress), "not a contract");
        libraryAddress = _libraryAddress;
        emit LibraryAddressSet(libraryAddress);
    }

    /**
     * Method for withdrawing unassigned rewards from this contract. Can be used for moving the rewards to the
     * new contract or for burning. Only governance can call this.
     * @param _recipient The recipient of the rewards.
     * @param _amount The amount of the rewards.
     */
    function withdrawUnassignedRewards(address _recipient, uint128 _amount) external mustBalance onlyGovernance {
        _checkNonzeroAddress(_recipient);
        require(totalAssignableRewards - totalAssignedRewards >= _amount, "insufficient assignable rewards");
        totalAssignableRewards -= _amount;
        totalWithdrawnAssignableRewards += _amount;
        emit UnassignedRewardsWithdrawn(_recipient, _amount);
        /* solhint-disable avoid-low-level-calls */
        //slither-disable-next-line arbitrary-send-eth
        (bool success, ) = _recipient.call{value: _amount}("");
        /* solhint-enable avoid-low-level-calls */
        require(success, "Transfer failed");
    }

    /**
     * Enables the incentive pool.
     */
    function enableIncentivePool() external onlyGovernance {
        incentivePoolEnabled = true;
    }

    //////////////////////////// View functions ////////////////////////////

    /**
     * @inheritdoc IRNat
     */
    function getRNatAccount(address _owner) external view returns (IRNatAccount) {
        return _getRNatAccount(_owner);
    }

    /**
     * @inheritdoc IRNat
     */
    function getCurrentMonth() external view returns (uint256) {
        return _getCurrentMonth();
    }

    /**
     * @inheritdoc IRNat
     */
    function getProjectsCount() external view returns (uint256) {
        return projects.length;
    }

    /**
     * @inheritdoc IRNat
     */
    function getProjectsBasicInfo() external view returns (string[] memory _names, bool[] memory _claimingDisabled) {
        _names = new string[](projects.length);
        _claimingDisabled = new bool[](projects.length);
        for (uint256 i = 0; i < projects.length; i++) {
            _names[i] = projects[i].name;
            _claimingDisabled[i] = projects[i].claimingDisabled;
        }
    }

    /**
     * @inheritdoc IRNat
     */
    function getProjectInfo(uint256 _projectId)
        external view
        returns (
            string memory _name,
            address _distributor,
            bool _currentMonthDistributionEnabled,
            bool _distributionDisabled,
            bool _claimingDisabled,
            uint128 _totalAssignedRewards,
            uint128 _totalDistributedRewards,
            uint128 _totalClaimedRewards,
            uint128 _totalUnassignedUnclaimedRewards,
            uint256[] memory _monthsWithRewards
        )
    {
        Project storage project = _getProject(_projectId);
        return (
            project.name,
            project.distributor,
            project.currentMonthDistributionEnabled,
            project.distributionDisabled,
            project.claimingDisabled,
            project.totalAssignedRewards,
            project.totalDistributedRewards,
            project.totalClaimedRewards,
            project.totalUnassignedUnclaimedRewards,
            project.monthsWithRewards
        );
    }

    /**
     * @inheritdoc IRNat
     */
    function getProjectRewardsInfo(uint256 _projectId, uint256 _month)
        external view
        returns (
            uint128 _assignedRewards,
            uint128 _distributedRewards,
            uint128 _claimedRewards,
            uint128 _unassignedUnclaimedRewards
        )
    {
        Project storage project = _getProject(_projectId);
        MonthlyRewards storage monthlyRewards = project.monthlyRewards[_month];
        return (
            monthlyRewards.assignedRewards,
            monthlyRewards.distributedRewards,
            monthlyRewards.claimedRewards,
            monthlyRewards.unassignedUnclaimedRewards
        );
    }

    /**
     * @inheritdoc IRNat
     */
    function getOwnerRewardsInfo(uint256 _projectId, uint256 _month, address _owner)
        external view
        returns (
            uint128 _assignedRewards,
            uint128 _claimedRewards,
            bool _claimable
        )
    {
        Project storage project = _getProject(_projectId);
        if (_month > _getCurrentMonth()) {
            return (0, 0, false);
        }
        MonthlyRewards storage monthlyRewards = project.monthlyRewards[_month];
        Rewards storage rewards = monthlyRewards.rewards[_owner];
        return (
            rewards.assignedRewards,
            rewards.claimedRewards,
            !project.claimingDisabled
        );
    }

    /**
     * @inheritdoc IRNat
     */
    function getClaimableRewards(uint256 _projectId, address _owner) external view returns (uint128) {
        Project storage project = _getProject(_projectId);
        if (project.claimingDisabled) {
            return 0;
        }
        uint256 currentMonth = _getCurrentMonth();
        uint256 claimingMonthIndex = project.lastClaimingMonthIndex[_owner];
        uint256 length = project.monthsWithRewards.length - claimingMonthIndex;
        uint128 totalAmount = 0;
        for (uint256 i = 0; i < length; i++) {
            uint256 month = project.monthsWithRewards[claimingMonthIndex];
            if (currentMonth < month) { // future months are not claimable
                break;
            }
            MonthlyRewards storage monthlyRewards = project.monthlyRewards[month];
            Rewards storage rewards = monthlyRewards.rewards[_owner];
            totalAmount += rewards.assignedRewards - rewards.claimedRewards;
            claimingMonthIndex++;
        }
        return totalAmount;
    }

    /**
     * @inheritdoc IERC20
     */
    function totalSupply() external view returns (uint256) {
        return totalClaimedRewards - totalWithdrawnRewards;
    }

    /**
     * @inheritdoc IERC20
     */
    function balanceOf(address _owner) external view returns(uint256) {
        return _getRNatAccount(_owner).rNatBalance();
    }

    /**
     * @inheritdoc IRNat
     */
    function getBalancesOf(
        address _owner
    )
        external view
        returns (
            uint256 _wNatBalance,
            uint256 _rNatBalance,
            uint256 _lockedBalance
        )
    {
        IIRNatAccount rNatAccount = _getRNatAccount(_owner);
        _wNatBalance = rNatAccount.wNatBalance(wNat);
        _rNatBalance = rNatAccount.rNatBalance();
        _lockedBalance = rNatAccount.lockedBalance(firstMonthStartTs);
    }

    /**
     * @inheritdoc IRNat
     */
    function getRewardsInfo()
        external view
        returns (
            uint256 _totalAssignableRewards,
            uint256 _totalAssignedRewards,
            uint256 _totalClaimedRewards,
            uint256 _totalWithdrawnRewards,
            uint256 _totalWithdrawnAssignableRewards
        )
    {
        return (
            totalAssignableRewards,
            totalAssignedRewards,
            totalClaimedRewards,
            totalWithdrawnRewards,
            totalWithdrawnAssignableRewards
        );
    }

    /**
     * @inheritdoc IITokenPool
     */
    function getTokenPoolSupplyData()
        external view
        returns (
            uint256 _lockedFundsWei,
            uint256 _totalInflationAuthorizedWei,
            uint256 _totalClaimedWei
        )
    {
        // values should not decrease
        _lockedFundsWei = totalAssignableRewards + totalWithdrawnAssignableRewards;
        _totalInflationAuthorizedWei = 0;
        _totalClaimedWei = totalWithdrawnRewards + totalWithdrawnAssignableRewards;
    }

    /**
     * Implement this function to allow updating incentive receiver contracts through `AddressUpdater`.
     * @return Contract name.
     */
    function getContractName() external pure returns (string memory) {
        return "RNat";
    }

    //////////////////////////// ERC20 functions (disabled) ////////////////////////////

    /**
     * @inheritdoc IERC20
     * @dev Disabled. Non-transferable token.
     */
    function transfer(address, uint256) external pure returns (bool) {
        revert("transfer not supported");
    }

    /**
     * @inheritdoc IERC20
     * @dev Disabled. Non-transferable token.
     */
    function allowance(address, address) external pure returns (uint256) {
        revert("allowance not supported");
    }

    /**
     * @inheritdoc IERC20
     * @dev Disabled. Non-transferable token.
     */
    function approve(address, uint256) external pure returns (bool) {
        revert("approval not supported");
    }

    /**
     * @inheritdoc IERC20
     * @dev Disabled. Non-transferable token.
     */
    function transferFrom(address, address, uint256) external pure returns (bool) {
        revert("transfer not supported");
    }

    //////////////////////////// Internal functions ////////////////////////////

    /**
     * Returns the RNat account data. If the account for the msg.sender does not exist, it creates a new one.
     */
    function _getOrCreateRNatAccount() internal returns (IIRNatAccount _rNatAccount) {
        _rNatAccount = ownerToRNatAccount[msg.sender];
        if (address(_rNatAccount) != address(0)) {
            return _rNatAccount;
        }
        require(libraryAddress != address(0), "library address not set yet");

        // create RNat account
        _rNatAccount = IIRNatAccount(payable(createClone(libraryAddress)));
        require(_isContract(address(_rNatAccount)), "clone not created successfully");
        _rNatAccount.initialize(msg.sender, this);
        rNatAccountToOwner[_rNatAccount] = msg.sender;
        ownerToRNatAccount[msg.sender] = _rNatAccount;
        emit RNatAccountCreated(msg.sender, _rNatAccount);

        // register owner as executor if not a registered executor (fee == 0)
        uint256 fee = claimSetupManager.getExecutorCurrentFeeValue(msg.sender);
        if (fee == 0) {
            _rNatAccount.setClaimExecutors(claimSetupManager, new address[](0));
        }

        return _rNatAccount;
    }

    /**
     * Claims rewards for the sender for the given project, up to the given month.
     * @param _projectId The project id.
     * @param _month The month up to which to claim rewards.
     * @param _currentMonth The current month.
     * @return _totalAmount The total amount of claimed rewards.
     */
    function _claimRewards(
        uint256 _projectId,
        uint256 _month,
        uint256 _currentMonth
    )
        internal
        returns (uint128 _totalAmount)
    {
        Project storage project = _getProject(_projectId);
        require(!project.claimingDisabled, "claiming disabled");
        uint256 claimingMonthIndex = project.lastClaimingMonthIndex[msg.sender];
        uint256 length = project.monthsWithRewards.length - claimingMonthIndex;
        uint256[] memory months = new uint256[](length);
        uint256[] memory amounts = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            uint256 month = project.monthsWithRewards[claimingMonthIndex];
            if (_month < month) { // can be a month in the future
                break;
            }
            MonthlyRewards storage monthlyRewards = project.monthlyRewards[month];
            Rewards storage rewards = monthlyRewards.rewards[msg.sender];
            months[i] = month;
            uint128 amount = rewards.assignedRewards - rewards.claimedRewards;
            _totalAmount += amount;
            monthlyRewards.claimedRewards += amount;
            rewards.claimedRewards += amount;
            if (amount > 0) {
                amounts[i] = amount;
                emit RewardsClaimed(_projectId, month, msg.sender, amount);
            }
            claimingMonthIndex++;
        }
        project.totalClaimedRewards += _totalAmount;

        // decrease claimingMonthIndex to the last month with assignable rewards (one month before the current month)
        while (claimingMonthIndex > 0 && project.monthsWithRewards[claimingMonthIndex - 1] + 1 >= _currentMonth) {
            claimingMonthIndex--;
        }
        // can be equal to project.monthsWithRewards.length
        project.lastClaimingMonthIndex[msg.sender] = claimingMonthIndex;
        // transfer (wrap) rewards
        _getOrCreateRNatAccount().receiveRewards{value: _totalAmount}(wNat, months, amounts);
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
        if (incentivePoolEnabled) {
            super._updateContractAddresses(_contractNameHashes, _contractAddresses);
        }
        claimSetupManager = IIClaimSetupManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "ClaimSetupManager"));
        IWNat newWNat = IWNat(payable(_getContractAddress(_contractNameHashes, _contractAddresses, "WNat")));
        if (address(wNat) == address(0)) {
            wNat = newWNat;
            require(wNat.decimals() == decimals, "decimals mismatch");
        } else if (newWNat != wNat) {
            revert("wrong wNat address");
        }
    }

    /**
     * @inheritdoc IncentivePoolReceiver
     */
    function _receiveIncentive() internal override {
        totalAssignableRewards += uint128(msg.value);
    }

    /**
     * @inheritdoc IncentivePoolReceiver
     */
    function _getExpectedBalance() internal override view returns(uint256 _balanceExpectedWei) {
        return totalAssignableRewards - totalClaimedRewards;
    }

    /**
     * Returns the project by id.
     */
    function _getProject(uint256 _projectId) internal view returns (Project storage) {
        require(_projectId < projects.length, "invalid project id");
        return projects[_projectId];
    }

    /**
     * Returns the RNat account of the owner.
     */
    function _getRNatAccount(
        address _owner
    )
        internal view
        returns (
            IIRNatAccount _rNatAccount
        )
    {
        _rNatAccount = ownerToRNatAccount[_owner];
        require(address(_rNatAccount) != address(0), "no RNat account");
    }

    /**
     * Returns the current month.
     */
    function _getCurrentMonth() internal view returns (uint256) {
        return (block.timestamp - firstMonthStartTs) / MONTH;
    }

    /**
     * @inheritdoc IncentivePoolReceiver
     */
    function _setDailyAuthorizedIncentive(uint256 _toAuthorizeWei) internal pure override {
        // do nothing
    }

    /**
     * Checks if the address is a contract.
     */
    function _isContract(address _addr) private view returns (bool){
        uint32 size;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    /**
     * Checks if distribution is enabled.
     */
    function _checkDistributionEnabled(Project storage _project) private view {
        require(!_project.distributionDisabled, "distribution disabled");
    }

    /**
     * Checks if claiming is not permanently disabled.
     */
    function _checkClaimingNotPermanentlyDisabled(Project storage _project) private view {
        require(_project.totalUnassignedUnclaimedRewards == 0, "claiming permanently disabled");
    }

    /**
     * Checks if the sender is the manager.
     */
    function _checkOnlyManager() private view {
        require(msg.sender == manager, "only manager");
    }

    /**
     * Checks if the address is not zero.
     */
    function _checkNonzeroAddress(address _address) private pure {
        require(_address != address(0), "address zero");
    }
}
