// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

/**
 * @title IFlareGovernance
 * @notice Public interface for Flare governance — the hash-based timelock variant.
 * @dev Implemented by `FlareGovernedBase` (used by FlareUpgradeableBase-derived UUPS
 *      contracts) and by `DiamondGovernanceFacet` on the TEE Diamond. Other facets
 *      use internal-only modifiers from `FlareGovernedAccess`. Uses hash-based timelock —
 *      the executor provides the full encoded call at execution time, verified
 *      against the stored hash. Matches the FAssets IGoverned interface pattern.
 */
interface IFlareGovernance {

    /**
     * Governance call was timelocked. It can be executed after `allowedAfterTimestamp` by one of the executors.
     * @param encodedCall ABI encoded call data, to be used in executeGovernanceCall
     * @param encodedCallHash keccak256 hash of the ABI encoded call data
     * @param allowedAfterTimestamp the earliest timestamp when the call can be executed
     */
    event GovernanceCallTimelocked(
        bytes encodedCall,
        bytes32 encodedCallHash,
        uint256 allowedAfterTimestamp
    );

    /**
     * Previously timelocked governance call was executed.
     * @param encodedCallHash keccak256 hash of the ABI encoded call data
     *      (same as `GovernanceCallTimelocked.encodedCallHash`)
     */
    event TimelockedGovernanceCallExecuted(bytes32 encodedCallHash);

    /**
     * Previously timelocked governance call was canceled.
     * @param encodedCallHash keccak256 hash of the ABI encoded call data
     *      (same as `GovernanceCallTimelocked.encodedCallHash`)
     */
    event TimelockedGovernanceCallCanceled(bytes32 encodedCallHash);

    /**
     * Governed contract was initialised (not yet in production mode).
     * @param initialGovernance the governance address used until switch to production mode
     */
    event GovernanceInitialised(address initialGovernance);

    /**
     * The governed contract has switched to production mode.
     * Timelocks are now enabled and the governance address is `governanceSettings.getGovernanceAddress()`.
     * @param governanceSettings the system contract holding governance address, timelock and executors settings
     */
    event GovernedProductionModeEntered(address governanceSettings);

    error OnlyExecutor();
    error OnlyGovernance();
    error TimelockCallNotFound();
    error TimelockNotAllowedYet();
    error AlreadyInProductionMode();
    error GovernedAlreadyInitialized();
    error GovernedAddressZero();

    /**
     * @notice Execute the timelocked governance calls once the timelock period expires.
     * @dev Only executor can call this method.
     * @param _encodedCall ABI encoded call data (signature and parameters).
     *      You should use `encodedCall` parameter from `GovernanceCallTimelocked` event.
     */
    function executeGovernanceCall(
        bytes calldata _encodedCall
    )
        external;

    /**
     * Returns the current effective governance address.
     */
    function governance()
        external view
        returns (address);

    /**
     * Returns the governance settings contract address.
     */
    function governanceSettings()
        external view
        returns (IGovernanceSettings);

    /**
     * True after switching to production mode.
     */
    function productionMode()
        external view
        returns (bool);

    /**
     * Check if an address is one of the executors defined in `governanceSettings`.
     */
    function isExecutor(
        address _address
    )
        external view
        returns (bool);
}
