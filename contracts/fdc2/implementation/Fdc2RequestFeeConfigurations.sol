// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { GovernedProxyImplementation } from "../../governance/implementation/GovernedProxyImplementation.sol";
import { GovernedBase } from "../../governance/implementation/GovernedBase.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import { IFdc2RequestFeeConfigurations } from "../../userInterfaces/fdc2/IFdc2RequestFeeConfigurations.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

/**
 * Fdc2RequestFeeConfigurations contract.
 *
 * This contract is used to manage the flare tee data connector requests fee configuration.
 */
contract Fdc2RequestFeeConfigurations is IFdc2RequestFeeConfigurations, GovernedProxyImplementation, UUPSUpgradeable {

    /// Mapping of type and source to fee.
    mapping(bytes32 typeAndSource => uint256 fee) private typeAndSourceFees;

    /**
     * Constructor that initializes with invalid parameters to prevent direct deployment/updates.
     */
    constructor() GovernedProxyImplementation() {}

    /**
     * Proxyable initialization method. Can be called only once, from the proxy constructor
     * (single call is assured by GovernedBase.initialise).
     */
    function initialize(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance
    )
        external virtual
    {
        GovernedBase.initialise(_governanceSettings, _initialGovernance);
    }

    /**
     * Sets the fee for a given type and source.
     * @param _type The type to set the fee for.
     * @param _source The source to set the fee for.
     * @param _fee The fee to set.
     * @dev Only governance can call this method.
     */
    function setTypeAndSourceFee(
        bytes32 _type,
        bytes32 _source,
        uint256 _fee
    )
        external
        onlyGovernance
    {
        _setSingleTypeAndSourceFee(_type, _source, _fee);
    }

    /**
     * Removes the fee for a given type and source.
     * @param _type The type to remove.
     * @param _source The source to remove.
     * @dev Only governance can call this method.
     */
    function removeTypeAndSourceFee(
        bytes32 _type,
        bytes32 _source
    )
        external
        onlyGovernance
    {
        _removeSingleTypeAndSourceFee(_type, _source);
    }

    /**
     * Sets the fees for multiple types and sources.
     * @param _types The types to set the fees for.
     * @param _sources The sources to set the fees for.
     * @param _fees The fees to set.
     * @dev Only governance can call this method.
     */
    function setTypeAndSourceFees(
        bytes32[] memory _types,
        bytes32[] memory _sources,
        uint256[] memory _fees
    )
        external
        onlyGovernance
    {
        require(_types.length == _sources.length && _types.length == _fees.length, LengthsMismatch());
        for (uint256 i = 0; i < _types.length; i++) {
            _setSingleTypeAndSourceFee(_types[i], _sources[i], _fees[i]);
        }
    }

    /**
     * Removes the fees for multiple types and sources.
     * @param _types The types to remove.
     * @param _sources The sources to remove.
     * @dev Only governance can call this method.
     */
    function removeTypeAndSourceFees(
        bytes32[] memory _types,
        bytes32[] memory _sources
    )
        external
        onlyGovernance
    {
        require(_types.length == _sources.length, LengthsMismatch());
        for (uint256 i = 0; i < _types.length; i++) {
            _removeSingleTypeAndSourceFee(_types[i], _sources[i]);
        }
    }

    /**
     * @inheritdoc IFdc2RequestFeeConfigurations
     */
    function getTypeAndSourceFee(
        bytes32 _type,
        bytes32 _source
    )
        external view
        returns (uint256 _fee)
    {
        _fee = typeAndSourceFees[_joinTypeAndSource(_type, _source)];
        require(_fee > 0, TypeAndSourceCombinationNotSupported());
    }

    /**
     * Returns the current implementation address.
     * @return The current implementation address.
     */
    function implementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    /**
     * @inheritdoc UUPSUpgradeable
     * @dev Only governance can call this method.
     */
    function upgradeToAndCall(
        address _newImplementation,
        bytes memory _data
    )
        public payable virtual override
        onlyGovernance
    {
        super.upgradeToAndCall(_newImplementation, _data);
    }

    ////////////////////////// Internal functions ///////////////////////////////////////////////

    /**
     * Unused. Present just to satisfy UUPSUpgradeable requirement.
     * The real check is in onlyGovernance modifier on upgradeToAndCall.
     */
    function _authorizeUpgrade(
        address _newImplementation
    )
        internal virtual override
    {}

    /**
     * Sets the fee for a given type and source.
     */
    function _setSingleTypeAndSourceFee(
        bytes32 _type,
        bytes32 _source,
        uint256 _fee
    )
        internal
    {
        require(_fee > 0, FeeMustBeGreaterThanZero());
        typeAndSourceFees[_joinTypeAndSource(_type, _source)] = _fee;
        emit TypeAndSourceFeeSet(_type, _source, _fee);
    }

    /**
     * Removes a given type and source by setting the fee to 0.
     */
    function _removeSingleTypeAndSourceFee(
        bytes32 _type,
        bytes32 _source
    )
        internal
    {
        // Same as setting this to 0 but we want to emit a different event + gas savings
        require(typeAndSourceFees[_joinTypeAndSource(_type, _source)] > 0, FeeNotSet());
        delete typeAndSourceFees[_joinTypeAndSource(_type, _source)];
        emit TypeAndSourceFeeRemoved(_type, _source);
    }

    /**
     * Joins a type and source into a single bytes32 value.
     */
    function _joinTypeAndSource(
        bytes32 _type,
        bytes32 _source
    )
        internal pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_type, _source));
    }
}
