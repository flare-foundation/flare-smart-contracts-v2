// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../userInterfaces/IFdcRequestFeeConfigurations.sol";
import "../../governance/implementation/Governed.sol";

/**
 * FdcRequestFeeConfigurations contract.
 *
 * This contract is used to manage the FDC requests fee configuration.
 */
contract FdcRequestFeeConfigurations is Governed, IFdcRequestFeeConfigurations {

    /// Mapping of type and source to fee.
    mapping(bytes32 typeAndSource => uint256 fee) public typeAndSourceFees;

    /**
    * Constructor.
    * @param _governanceSettings The address of the GovernanceSettings contract.
    * @param _initialGovernance The initial governance address.
    */
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance
    )
        Governed(_governanceSettings, _initialGovernance)
    { }

    /**
     * Sets the fee for a given type and source.
     * @param _type The type to set the fee for.
     * @param _source The source to set the fee for.
     * @param _fee The fee to set.
     * @dev Only governance can call this method.
     */
    function setTypeAndSourceFee(bytes32 _type, bytes32 _source, uint256 _fee) external onlyGovernance {
        _setSingleTypeAndSourceFee(_type, _source, _fee);
    }

    /**
     * Removes the fee for a given type and source.
     * @param _type The type to remove.
     * @param _source The source to remove.
     * @dev Only governance can call this method.
     */
    function removeTypeAndSourceFee(bytes32 _type, bytes32 _source) external onlyGovernance {
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
        external onlyGovernance
    {
        require(_types.length == _sources.length && _types.length == _fees.length, "length mismatch");
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
        external onlyGovernance
    {
        require(_types.length == _sources.length, "length mismatch");
        for (uint256 i = 0; i < _types.length; i++) {
            _removeSingleTypeAndSourceFee(_types[i], _sources[i]);
        }
    }

    /**
    * @inheritdoc IFdcRequestFeeConfigurations
    */
    function getRequestFee(bytes calldata _data) external view returns (uint256 _fee) {
        _fee = _getBaseFee(_data);
        require(_fee > 0, "Type and source combination not supported");
    }

    ////////////////////////// Internal functions ///////////////////////////////////////////////

    /**
     * Sets the fee for a given type and source.
     */
    function _setSingleTypeAndSourceFee(bytes32 _type, bytes32 _source, uint256 _fee) internal {
        require(_fee > 0, "Fee must be greater than 0");
        typeAndSourceFees[_joinTypeAndSource(_type, _source)] = _fee;
        emit TypeAndSourceFeeSet(_type, _source, _fee);
    }

    /**
     * Removes a given type and source by setting the fee to 0.
     */
    function _removeSingleTypeAndSourceFee(bytes32 _type, bytes32 _source) internal {
        // Same as setting this to 0 but we want to emit a different event + gas savings
        require(typeAndSourceFees[_joinTypeAndSource(_type, _source)] > 0, "Fee not set");
        delete typeAndSourceFees[_joinTypeAndSource(_type, _source)];
        emit TypeAndSourceFeeRemoved(_type, _source);
    }

    /**
     * Calculates the base fee for an attestation request.
     */
    function _getBaseFee(bytes calldata _data) internal view returns (uint256) {
        require(_data.length >= 64, "Request data too short, should at least specify type and source");
        bytes32 _type = abi.decode(_data[:32], (bytes32));
        bytes32 _source = abi.decode(_data[32:64], (bytes32));
        return _getTypeAndSourceFee(_type, _source);
    }

    /**
     * Returns the fee for a given type and source.
     */
    function _getTypeAndSourceFee(bytes32 _type, bytes32 _source) internal view returns (uint256 _fee) {
        _fee = typeAndSourceFees[_joinTypeAndSource(_type, _source)];
    }

    /**
     * Joins a type and source into a single bytes32 value.
     */
    function _joinTypeAndSource(bytes32 _type, bytes32 _source) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_type, _source));
    }
}
