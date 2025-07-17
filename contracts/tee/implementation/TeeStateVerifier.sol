
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../interface/IITeeStateVerifier.sol";
import "../../utils/implementation/AddressUpdatable.sol";
import "../../governance/implementation/GovernedProxyImplementation.sol";
import "../../userInterfaces/tee/ITeeVersionManager.sol";
import "../../userInterfaces/tee/ITeeRegistry.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

/**
 * TeeStateVerifier is used for verifying TEE machine state.
 */
contract TeeStateVerifier is IITeeStateVerifier, GovernedProxyImplementation, AddressUpdatable, UUPSUpgradeable {

    /// TEE version manager contract.
    ITeeVersionManager public teeVersionManager;
    /// TEE registry contract.
    ITeeRegistry public teeRegistry;

    /**
     * Constructor that initializes with invalid parameters to prevent direct deployment/updates.
     */
    constructor()
        GovernedProxyImplementation() AddressUpdatable(address(0))
    { }

    /**
     * Proxyable initialization method. Can be called only once, from the proxy constructor
     * (single call is assured by GovernedBase.initialise).
     */
    function initialize(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater
    )
        external
    {
        GovernedBase.initialise(_governanceSettings, _initialGovernance);
        AddressUpdatable.setAddressUpdaterValue(_addressUpdater);
    }

    /**
     * @inheritdoc ITeeStateVerifier
     */
    function verifyTeeMachineState(
        address _teeId,
        bytes calldata _state
    )
        external view
        returns (bool _isValid) {
            IITeeStateVerifier.TeeMachineState memory state = abi.decode(_state, (IITeeStateVerifier.TeeMachineState));
            ITeeRegistry.TeeMachineWithAttestationData memory teeMachine =
                teeRegistry.getTeeMachineWithAttestationData(_teeId);
            // Check if the TEE machine is active and the state matches the initial TEE ID and governance hash.
            return
                state.status == IITeeStateVerifier.TeeMachineStatus.ACTIVE &&
                state.initialTeeId == teeMachine.initialTeeId &&
                state.teeGovernanceHash == teeVersionManager.getTeeGovernanceHash(teeMachine.codeHash);
        }

    /////////////////////////////// UUPS UPGRADABLE ///////////////////////////////

    function implementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    /**
     * @inheritdoc UUPSUpgradeable
     * @dev Only governance can call this method.
     */
    function upgradeToAndCall(address newImplementation, bytes memory data)
        public payable override
        onlyGovernance
        onlyProxy
    {
        super.upgradeToAndCall(newImplementation, data);
    }

    /**
     * Unused. Present just to satisfy UUPSUpgradeable requirement.
     * The real check is in onlyGovernance modifier on upgradeToAndCall.
     */
    function _authorizeUpgrade(address newImplementation) internal override {}

    /**
     * @inheritdoc AddressUpdatable
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal override
    {
        teeVersionManager = ITeeVersionManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeVersionManager"));
        teeRegistry = ITeeRegistry(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeRegistry"));
    }

}
