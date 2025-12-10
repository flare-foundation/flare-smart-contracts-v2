// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { GovernedProxyImplementation } from "../../governance/implementation/GovernedProxyImplementation.sol";
import { GovernedBase } from "../../governance/implementation/GovernedBase.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import { ITeeFeeCalculator } from "../../userInterfaces/tee/ITeeFeeCalculator.sol";
import { IGovernanceSettings } from "flare-smart-contracts/contracts/userInterfaces/IGovernanceSettings.sol";

/**
 * TeeFeeCalculator is used for calculating fees for TEE operations.
 */
contract TeeFeeCalculator is ITeeFeeCalculator, GovernedProxyImplementation, UUPSUpgradeable {

    /// Default fee for operations.
    uint256 private defaultFee;

    mapping(bytes32 opType => mapping(bytes32 opCommand => uint256 fee)) internal operationFee;

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
        address _initialGovernance,
        uint256 _defaultFee
    )
        external virtual
    {
        GovernedBase.initialise(_governanceSettings, _initialGovernance);

        defaultFee = _defaultFee;
        emit DefaultFeeSet(_defaultFee);
    }

    /**
     * Sets fees for operations.
     * @param _opTypes List of operation types.
     * @param _opCommands List of operation commands.
     * @param _fees List of fees.
     * @dev Only governance can call this method.
     */
    function setOperationFees(
        bytes32[] calldata _opTypes,
        bytes32[] calldata _opCommands,
        uint256[] calldata _fees
    )
        external onlyGovernance
    {
        require(_opTypes.length == _opCommands.length && _opTypes.length == _fees.length, LengthsMismatch());
        for (uint256 i = 0; i < _opTypes.length; i++) {
            operationFee[_opTypes[i]][_opCommands[i]] = _fees[i];
            emit OperationFeeSet(_opTypes[i], _opCommands[i], _fees[i]);
        }
    }

    /**
     * Sets the default fee.
     * @param _defaultFee The new default fee.
     * @dev Only governance can call this method.
     */
    function setDefaultFee(uint256 _defaultFee) external onlyGovernance {
        defaultFee = _defaultFee;
        emit DefaultFeeSet(_defaultFee);
    }

    /**
     * @inheritdoc ITeeFeeCalculator
     */
    function getDefaultFee() external view returns (uint256) {
        return defaultFee;
    }

    /**
     * @inheritdoc ITeeFeeCalculator
     */
    function getOperationFee(bytes32 _opType, bytes32 _opCommand) external view returns (uint256) {
        return operationFee[_opType][_opCommand];
    }

    /**
     * @inheritdoc ITeeFeeCalculator
     */
    function calculateFeeByTeeIds(
        bytes32 _opType,
        bytes32 _opCommand,
        address[] memory _teeIds
    )
        external view returns (uint256 _fee)
    {
        _fee = operationFee[_opType][_opCommand];
        if (_fee == 0) {
            _fee = defaultFee;
        }
        _fee *= _teeIds.length;
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
    function upgradeToAndCall(address _newImplementation, bytes memory _data)
        public payable virtual override
        onlyGovernance
    {
        super.upgradeToAndCall(_newImplementation, _data);
    }

    /**
     * Unused. Present just to satisfy UUPSUpgradeable requirement.
     * The real check is in onlyGovernance modifier on upgradeToAndCall.
     */
    function _authorizeUpgrade(address _newImplementation) internal virtual override {}
}
