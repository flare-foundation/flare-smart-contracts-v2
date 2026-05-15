// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IFdc2InflationConfigurations } from "../../userInterfaces/fdc2/IFdc2InflationConfigurations.sol";
import { IFdc2RequestFeeConfigurations } from "../../userInterfaces/fdc2/IFdc2RequestFeeConfigurations.sol";
import { Governed } from "../../governance/implementation/Governed.sol";
import { AddressUpdatable } from "../../utils/implementation/AddressUpdatable.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

/**
 * Fdc2InflationConfigurations contract.
 *
 * This contract is used to manage the FDC2 inflation configurations.
 */
contract Fdc2InflationConfigurations is Governed, AddressUpdatable, IFdc2InflationConfigurations {

    /// The FDC2 request fee configurations contract.
    IFdc2RequestFeeConfigurations public fdc2RequestFeeConfigurations;

    /// The FDC2 configurations.
    Fdc2Configuration[] internal fdc2Configurations;

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
     * Allows governance to add new FDC2 configurations.
     * @param _configs The FDC2 configurations.
     * @dev Only governance can call this method.
     */
    function addFdc2Configurations(
        Fdc2Configuration[] calldata _configs
    )
        external
        onlyGovernance
    {
        for (uint256 i = 0; i < _configs.length; i++) {
            _checkFdc2Configuration(_configs[i]);
            fdc2Configurations.push(_configs[i]);
        }
    }

    /**
     * Allows governance to replace the existing FDC2 configurations.
     * @param _indices The indices of the FDC2 configurations to replace.
     * @param _configs The FDC2 configurations.
     * @dev Only governance can call this method.
     */
    function replaceFdc2Configurations(
        uint256[] calldata _indices,
        Fdc2Configuration[] calldata _configs
    )
        external
        onlyGovernance
    {
        uint256 length = fdc2Configurations.length;
        require(_indices.length == _configs.length, LengthsMismatch());
        for (uint256 i = 0; i < _indices.length; i++) {
            require(length > _indices[i], InvalidIndex());
            _checkFdc2Configuration(_configs[i]);
            fdc2Configurations[_indices[i]] = _configs[i];
        }
    }

    /**
     * Allows governance to remove an existing FDC2 configuration.
     * @param _index The index of the FDC2 configuration to remove.
     * @dev Only governance can call this method.
     */
    function removeFdc2Configuration(
        uint256 _index
    )
        external
        onlyGovernance
    {
        uint256 length = fdc2Configurations.length;
        require(length > _index, InvalidIndex());

        fdc2Configurations[_index] = fdc2Configurations[length - 1]; // length > 0
        fdc2Configurations.pop();
    }

    /**
     * @inheritdoc IFdc2InflationConfigurations
     */
    function getFdc2Configuration(
        uint256 _index
    )
        external view
        returns (Fdc2Configuration memory)
    {
        require(fdc2Configurations.length > _index, InvalidIndex());
        return fdc2Configurations[_index];
    }

    /**
     * @inheritdoc IFdc2InflationConfigurations
     */
    function getFdc2Configurations()
        external view
        returns (Fdc2Configuration[] memory)
    {
        return fdc2Configurations;
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
        fdc2RequestFeeConfigurations = IFdc2RequestFeeConfigurations(
            _getContractAddress(_contractNameHashes, _contractAddresses, "Fdc2RequestFeeConfigurations"));
    }

    /**
     * Checks the FDC2 configuration and reverts if invalid.
     * @param _configuration The FDC2 configuration.
     */
    function _checkFdc2Configuration(
        Fdc2Configuration calldata _configuration
    )
        internal view
    {
        // Check if the fee is set for the given type and source - call should revert if not.
        fdc2RequestFeeConfigurations.getTypeAndSourceFee(_configuration.attestationType, _configuration.sourceId);
    }
}
