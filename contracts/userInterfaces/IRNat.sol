// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./IRNatAccount.sol";
import "./IWNat.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IRNat is IERC20Metadata {

    event RNatAccountCreated(address owner, IRNatAccount rNatAccount);
    event ProjectAdded(uint256 indexed id, string name, address distributor, bool currentMonthDistributionEnabled);
    event ProjectUpdated(uint256 indexed id, string name, address distributor, bool currentMonthDistributionEnabled);
    event RewardsAssigned(uint256 indexed projectId, uint256 indexed month, uint128 amount);
    event RewardsUnassigned(uint256 indexed projectId, uint256 indexed month, uint128 amount);
    event RewardsDistributed(
        uint256 indexed projectId,
        uint256 indexed month,
        address[] recipients,
        uint128[] amounts
    );
    event RewardsClaimed(uint256 indexed projectId, uint256 indexed month, address indexed owner, uint128 amount);
    event UnclaimedRewardsUnassigned(uint256 indexed projectId, uint256 indexed month, uint128 amount);
    event UnassignedRewardsWithdrawn(address recipient, uint128 amount);
    event DistributionPermissionUpdated(uint256[] projectIds, bool disabled);
    event ClaimingPermissionUpdated(uint256[] projectIds, bool disabled);

    /**
     * Distributes the rewards of a project for a given month to a list of recipients.
     * It must be called by the project's distributor.
     * It can only be called for the last or current month (if enabled).
     * @param _projectId The id of the project.
     * @param _month The month of the rewards.
     * @param _recipients The addresses of the recipients.
     * @param _amountsWei The amounts of rewards to distribute to each recipient (in wei).
     */
    function distributeRewards(
        uint256 _projectId,
        uint256 _month,
        address[] calldata _recipients,
        uint128[] calldata _amountsWei
    )
        external;

    /**
     * Claim rewards for a list of projects up to the given month.
     * @param _projectIds The ids of the projects.
     * @param _month The month up to which (including) rewards will be claimed.
     * @return _claimedRewardsWei The total amount of rewards claimed (in wei).
     */
    function claimRewards(
        uint256[] calldata _projectIds,
        uint256 _month
    )
        external
        returns (
            uint128 _claimedRewardsWei
        );

    /**
     * Sets the addresses of executors and adds the owner as an executor.
     *
     * If any of the executors is a registered executor, some fee needs to be paid.
     * @param _executors The new executors. All old executors will be deleted and replaced by these.
     */
    function setClaimExecutors(address[] calldata _executors) external payable;

    /**
     * Allows the caller to withdraw `WNat` wrapped tokens from their RNat account to the owner account.
     * In case there are some self-destruct native tokens left on the contract,
     * they can be transferred to the owner account using this method and `_wrap = false`.
     * @param _amount Amount of tokens to transfer (in wei).
     * @param _wrap If `true`, the tokens will be sent wrapped in `WNat`. If `false`, they will be sent as `Nat`.
     */
    function withdraw(uint128 _amount, bool _wrap) external;

    /**
     * Allows the caller to withdraw `WNat` wrapped tokens from their RNat account to the owner account.
     * If some tokens are still locked, only 50% of them will be withdrawn, the rest will be burned as a penalty.
     * In case there are some self-destruct native tokens left on the contract,
     * they can be transferred to the owner account using this method and `_wrap = false`.
     * @param _wrap If `true`, the tokens will be sent wrapped in `WNat`. If `false`, they will be sent as `Nat`.
     */
    function withdrawAll(bool _wrap) external;

    /**
     * Allows the caller to transfer ERC-20 tokens from their RNat account to the owner account.
     *
     * The main use case is to move ERC-20 tokes received by mistake (by an airdrop, for example) out of the
     * RNat account and move them into the main account, where they can be more easily managed.
     *
     * Reverts if the target token is the `WNat` contract: use method `withdraw` or `withdrawAll` for that.
     * @param _token Target token contract address.
     * @param _amount Amount of tokens to transfer.
     */
    function transferExternalToken(IERC20 _token, uint256 _amount) external;

    /**
     * Gets owner's RNat account. If it doesn't exist it reverts.
     * @param _owner Account to query.
     * @return Address of its RNat account.
     */
    function getRNatAccount(address _owner) external view returns (IRNatAccount);

    /**
     * Returns the timestamp of the start of the first month.
     */
    function firstMonthStartTs() external view returns (uint256);

    /**
     * Returns the `WNat` contract.
     */
    function wNat() external view returns(IWNat);

    /**
     * Gets the current month.
     * @return The current month.
     */
    function getCurrentMonth() external view returns (uint256);

    /**
     * Gets the total number of projects.
     * @return The total number of projects.
     */
    function getProjectsCount() external view returns (uint256);

    /**
     * Gets the basic information of all projects.
     * @return _names The names of the projects.
     * @return _claimingDisabled Whether claiming is disabled for each project.
     */
    function getProjectsBasicInfo() external view returns (string[] memory _names, bool[] memory _claimingDisabled);

    /**
     * Gets the information of a project.
     * @param _projectId The id of the project.
     * @return _name The name of the project.
     * @return _distributor The address of the distributor.
     * @return _currentMonthDistributionEnabled Whether distribution is enabled for the current month.
     * @return _distributionDisabled Whether distribution is disabled.
     * @return _claimingDisabled Whether claiming is disabled.
     * @return _totalAssignedRewards The total amount of rewards assigned to the project (in wei).
     * @return _totalDistributedRewards The total amount of rewards distributed by the project (in wei).
     * @return _totalClaimedRewards The total amount of rewards claimed from the project (in wei).
     * @return _totalUnassignedUnclaimedRewards The total amount of unassigned unclaimed rewards (in wei).
     * @return _monthsWithRewards The months with rewards.
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
        );

    /**
     * Gets the rewards information of a project for a given month.
     * @param _projectId The id of the project.
     * @param _month The month of the rewards.
     * @return _assignedRewards The amount of rewards assigned to the project for the month (in wei).
     * @return _distributedRewards The amount of rewards distributed by the project for the month (in wei).
     * @return _claimedRewards The amount of rewards claimed from the project for the month (in wei).
     * @return _unassignedUnclaimedRewards The amount of unassigned unclaimed rewards for the month (in wei).
     */
    function getProjectRewardsInfo(uint256 _projectId, uint256 _month)
        external view
        returns (
            uint128 _assignedRewards,
            uint128 _distributedRewards,
            uint128 _claimedRewards,
            uint128 _unassignedUnclaimedRewards
        );

    /**
     * Gets the rewards information of a project for a given month and owner.
     * @param _projectId The id of the project.
     * @param _month The month of the rewards.
     * @param _owner The address of the owner.
     * @return _assignedRewards The amount of rewards assigned to the owner for the month (in wei).
     * @return _claimedRewards The amount of rewards claimed by the owner for the month (in wei).
     * @return _claimable Whether the rewards are claimable by the owner.
     */
    function getOwnerRewardsInfo(uint256 _projectId, uint256 _month, address _owner)
        external view
        returns (
            uint128 _assignedRewards,
            uint128 _claimedRewards,
            bool _claimable
        );

    /**
     * Gets the claimable rewards of a project for a given owner.
     * @param _projectId The id of the project.
     * @param _owner The address of the owner.
     * @return The amount of rewards claimable by the owner (in wei).
     */
    function getClaimableRewards(uint256 _projectId, address _owner) external view returns (uint128);

    /**
     * Gets owner's balances of `WNat`, `RNat` and locked tokens.
     * @param _owner The address of the owner.
     * @return _wNatBalance The balance of `WNat` (in wei).
     * @return _rNatBalance The balance of `RNat` (in wei).
     * @return _lockedBalance The locked/vested balance (in wei).
     */
    function getBalancesOf(
        address _owner
    )
        external view
        returns (
            uint256 _wNatBalance,
            uint256 _rNatBalance,
            uint256 _lockedBalance
        );

    /**
     * Gets totals rewards information.
     * @return _totalAssignableRewards The total amount of assignable rewards (in wei).
     * @return _totalAssignedRewards The total amount of assigned rewards (in wei).
     * @return _totalClaimedRewards The total amount of claimed rewards (in wei).
     * @return _totalWithdrawnRewards The total amount of withdrawn rewards (in wei).
     * @return _totalWithdrawnAssignableRewards The total amount of withdrawn once assignable rewards (in wei).
     */
    function getRewardsInfo()
        external view
        returns (
            uint256 _totalAssignableRewards,
            uint256 _totalAssignedRewards,
            uint256 _totalClaimedRewards,
            uint256 _totalWithdrawnRewards,
            uint256 _totalWithdrawnAssignableRewards
        );
}