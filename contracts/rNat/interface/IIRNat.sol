// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;


import "../../userInterfaces/IRNat.sol";

/**
 * Internal interface for the `RNat` contract.
 */
interface IIRNat is IRNat {
    /**
     * Emitted when the `libraryAddress` has been set.
     */
    event LibraryAddressSet(address libraryAddress);

    /**
     * Method for adding new projects.
     * @param _names The names of the projects.
     * @param _distributors The addresses of the distributors.
     * @param _currentMonthDistributionEnabledList The list of booleans indicating if the distribution
     *          is enabled for the current month.
     */
    function addProjects(
        string[] calldata _names,
        address[] calldata _distributors,
        bool[] calldata _currentMonthDistributionEnabledList
    )
        external;

    /**
     * Method for updating the project.
     * @param _projectId The project id.
     * @param _name The name of the project.
     * @param _distributor The address of the distributor.
     * @param _currentMonthDistributionEnabled The boolean indicating if the distribution
     *          is enabled for the current month.
     */
    function updateProject(
        uint256 _projectId,
        string calldata _name,
        address _distributor,
        bool _currentMonthDistributionEnabled
    )
        external;

    /**
     * Method for assigning rewards to the projects.
     * @param _month The month for which the rewards are assigned.
     * @param _projectIds The ids of the projects.
     * @param _amountsWei The amounts of the rewards (in wei).
     */
    function assignRewards(
        uint256 _month,
        uint256[] calldata _projectIds,
        uint128[] calldata _amountsWei
    )
        external;

    /**
     * Disables the distribution for the projects.
     * @param _projectIds The ids of the projects.
     */
    function disableDistribution(uint256[] memory _projectIds) external;

    /**
     * Disables the claiming for the projects.
     * @param _projectIds The ids of the projects.
     */
    function disableClaiming(uint256[] memory _projectIds) external;

    /**
     * Method for unassigning rewards from the project. Can only be called for the past months with expired
     * distributon deadline. In case of disabled distribution governance can call this for all months.
     * @param _projectId The project id.
     * @param _months The months for which the rewards will be unassigned.
     */
    function unassignRewards(uint256 _projectId, uint256[] memory _months) external;

}
