// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { FlareGovernance } from "../../governance/lib/FlareGovernance.sol";
import { AddressUpdatable } from "../../utils/implementation/AddressUpdatable.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import { Verification } from "../library/Verification.sol";
import { OperationFees } from "../library/OperationFees.sol";
import { ExtensionManager } from "../library/ExtensionManager.sol";
import { OwnerAllowlist } from "../library/OwnerAllowlist.sol";
import { LibDiamond } from "../../diamond/libraries/LibDiamond.sol";
import { IDiamondCut } from "../../diamond/interfaces/IDiamondCut.sol";
import { IDiamondLoupe } from "../../diamond/interfaces/IDiamondLoupe.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title FlareTeeManagerInit
 * @notice Initialization contract for FlareTeeManager Diamond.
 * @dev Called via delegatecall from the Diamond constructor. Sets up governance,
 *      address updater, verification settings, and default fee.
 *      This contract is NOT a facet — it is only used during diamondCut init.
 */
contract FlareTeeManagerInit is Initializable, AddressUpdatable {

    /**
     * @dev Constructor locks OZ's `_initialized` flag to prevent direct use of this
     *      contract's bytecode (anti-selfdestruct). The diamond's storage at the OZ
     *      slot is what governs the `initializer` guard on `init(...)` at runtime.
     */
    constructor() AddressUpdatable(address(1)) {
        _disableInitializers();
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
     * @param _publicExtensionCreationEnabled If true, anyone may call
     *        IExtensionManager.register() from day 1 (global extension-owner
     *        allowlist starts in "allow all" mode). If false, the allowlist is
     *        closed and governance must seed or open it later. Reserved-id
     *        minting via registerReserved is always governance-only and is
     *        unaffected by this flag.
     */
    function init(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        uint64 _availabilityCheckValidityDurationSeconds,
        uint64 _signingPolicyValidityDurationInRewardEpochs,
        uint64 _challengeValidityDurationSeconds,
        uint256 _defaultFee,
        bool _publicExtensionCreationEnabled
    )
        external
        initializer
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
        Verification.updateSettings(
            _availabilityCheckValidityDurationSeconds,
            _signingPolicyValidityDurationInRewardEpochs,
            _challengeValidityDurationSeconds
        );

        // Set default fee
        OperationFees.getState().defaultFee = _defaultFee;

        // Public registration starts at PUBLIC_EXTENSION_ID_START; reserved
        // ids (1..65535) and id 0 are not assigned via this counter.
        ExtensionManager.getState().nextPublicExtensionId = ExtensionManager.PUBLIC_EXTENSION_ID_START;

        // Configure initial state of the global extension-owner allowlist.
        OwnerAllowlist.getState().allExtensionOwnersAllowed = _publicExtensionCreationEnabled;
    }

    /**
     * @dev Not used — ExternalAddressesFacet handles address updates.
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
