// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../userInterfaces/IFdcInflationConfigurations.sol";
import "../../userInterfaces/IFdcRequestFeeConfigurations.sol";
import "../../governance/implementation/Governed.sol";
import "../../utils/implementation/AddressUpdatable.sol";

/**
 * FdcInflationConfigurations contract.
 *
 * This contract is used to manage the FDC inflation configurations.
 */
contract FdcInflationConfigurations is Governed, AddressUpdatable, IFdcInflationConfigurations {

    /// The FDC Hub contract.
    IFdcRequestFeeConfigurations public fdcRequestFeeConfigurations;

    /// The FDC configurations.
    FdcConfiguration[] internal fdcConfigurations;

    /**
     * Constructor.
     * @param _governanceSettings The address of the GovernanceSettings contract.
     * @param _initialGovernance The initial governance address.
     * @param _addressUpdater The address of the AddressUpdater contract.
     */
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater
    )
        Governed(_governanceSettings, _initialGovernance) AddressUpdatable(_addressUpdater)
    { }

    /**
     * Allows governance to add new FDC configurations.
     * @param _configs The FDC configurations.
     * @dev Only governance can call this method.
     */
    function addFdcConfigurations(FdcConfiguration[] calldata _configs) external onlyGovernance {
        for (uint256 i = 0; i < _configs.length; i++) {
            _checkFdcConfiguration(_configs[i]);
            fdcConfigurations.push(_configs[i]);
        }
    }

    /**
     * Allows governance to replace the existing FDC configurations.
     * @param _indices The indices of the FDC configurations to replace.
     * @param _configs The FDC configurations.
     * @dev Only governance can call this method.
     */
    function replaceFdcConfigurations(
        uint256[] calldata _indices,
        FdcConfiguration[] calldata _configs
    )
        external onlyGovernance
    {
        uint256 length = fdcConfigurations.length;
        require(_indices.length == _configs.length, "lengths mismatch");
        for (uint256 i = 0; i < _indices.length; i++) {
            require(length > _indices[i], "invalid index");
            _checkFdcConfiguration(_configs[i]);
            fdcConfigurations[_indices[i]] = _configs[i];
        }
    }

    /**
     * Allows governance to remove an existing FDC configuration.
     * @param _index The index of the FDC configuration to remove.
     * @dev Only governance can call this method.
     */
    function removeFdcConfiguration(uint256 _index) external onlyGovernance {
        uint256 length = fdcConfigurations.length;
        require(length > _index, "invalid index");

        fdcConfigurations[_index] = fdcConfigurations[length - 1]; // length > 0
        fdcConfigurations.pop();
    }

    /**
     * @inheritdoc IFdcInflationConfigurations
     */
    function getFdcConfiguration(uint256 _index) external view returns(FdcConfiguration memory) {
        require(fdcConfigurations.length > _index, "invalid index");
        return fdcConfigurations[_index];
    }

    /**
     * @inheritdoc IFdcInflationConfigurations
     */
    function getFdcConfigurations() external view returns(FdcConfiguration[] memory) {
        return fdcConfigurations;
    }

    /**
     * Implementation of the AddressUpdatable abstract method.
     * @dev It can be overridden if other contracts are needed.
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal override
    {
        fdcRequestFeeConfigurations = IFdcRequestFeeConfigurations(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FdcRequestFeeConfigurations"));
    }

    /**
     * Checks the FDC configuration and reverts if invalid.
     * @param _configuration The FDC configuration.
     */
    function _checkFdcConfiguration(FdcConfiguration calldata _configuration) internal view {
        // Check if the fee is set for the given type and source - call should revert if not.
        fdcRequestFeeConfigurations.getRequestFee(abi.encode(_configuration.attestationType, _configuration.source));
    }
}