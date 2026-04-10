// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { FlareGovernance } from "../library/FlareGovernance.sol";
import { AddressUpdatable } from "../../utils/implementation/AddressUpdatable.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import { TeeVerification } from "../library/TeeVerification.sol";
import { TeeFeeCalculator } from "../library/TeeFeeCalculator.sol";
import { TeeExtensionRegistry } from "../library/TeeExtensionRegistry.sol";
import { LibDiamond } from "../../diamond/libraries/LibDiamond.sol";
import { IDiamondCut } from "../../diamond/interfaces/IDiamondCut.sol";
import { IDiamondLoupe } from "../../diamond/interfaces/IDiamondLoupe.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title FlareTeeManagerInit
 * @notice Initialization contract for FlareTeeManager Diamond.
 * @dev Called via delegatecall from the Diamond constructor. Sets up governance,
 *      address updater, verification settings, and default fee.
 *      This contract is NOT a facet — it is only used during diamondCut init.
 */
contract FlareTeeManagerInit is AddressUpdatable {

    /**
     * @dev Constructor marks this implementation as initialised to prevent
     *      direct usage (same pattern as GovernedProxyImplementation).
     */
    constructor() AddressUpdatable(address(1)) {
        FlareGovernance.initialise(IGovernanceSettings(address(0x1111)), address(0x1111));
    }

    /**
     * Initialise the FlareTeeManager Diamond.
     * @param _governanceSettings The governance settings contract.
     * @param _initialGovernance The initial governance address.
     * @param _addressUpdater The address updater contract address.
     * @param _availabilityCheckValidityDurationSeconds Duration for availability check validity.
     * @param _signingPolicyValidityDurationInRewardEpochs Signing policy validity in reward epochs.
     * @param _challengeValidityDurationSeconds Challenge validity duration.
     * @param _defaultFee Default fee for operations.
     */
    function init(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        uint64 _availabilityCheckValidityDurationSeconds,
        uint64 _signingPolicyValidityDurationInRewardEpochs,
        uint64 _challengeValidityDurationSeconds,
        uint256 _defaultFee
    )
        external
    {
        // adding ERC165 data
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;

        // Initialize governance (FlareGovernance ERC-7201 namespaced storage)
        FlareGovernance.initialise(_governanceSettings, _initialGovernance);

        // Set address updater (its own diamond-compatible storage slot)
        setAddressUpdaterValue(_addressUpdater);

        // Initialize verification settings
        TeeVerification.updateSettings(
            _availabilityCheckValidityDurationSeconds,
            _signingPolicyValidityDurationInRewardEpochs,
            _challengeValidityDurationSeconds
        );

        // Set default fee
        TeeFeeCalculator.getState().defaultFee = _defaultFee;

        // Reserve extension id 0 for system use
        TeeExtensionRegistry.getState().extensionsCounter = 1;
    }

    /**
     * @dev Not used — TeeAddressUpdatableFacet handles address updates.
     */
    function _updateContractAddresses(
        bytes32[] memory,
        address[] memory
    )
        internal pure override
    {
        // intentionally empty
    }
}
