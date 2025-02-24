// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../governance/implementation/Governed.sol";
import "../../utils/implementation/AddressUpdatable.sol";
import "../../userInterfaces/tee/ITeeFeeCalculator.sol";
import "../../userInterfaces/tee/ITeeWalletManager.sol";
/**
 * TeeFeeCalculator is used for calculating fees for TEE operations.
 */

contract TeeFeeCalculator is Governed, AddressUpdatable, ITeeFeeCalculator {

    /// The TeeWalletManager contract.
    ITeeWalletManager public teeWalletManager;

    mapping(bytes32 opType => mapping(bytes32 opCommand => uint256))
            internal operationFee;

    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        uint256 _defaultFee
    )
        Governed(_governanceSettings, _initialGovernance) AddressUpdatable(_addressUpdater)
    {
    }

    /**
     * Sets fees for operations.
     * @param _opTypes List of operation types.
     * @param _opCommands List of operation commands.
     * @param _fees List of fees.
     * @dev Only governance can call this method.
     */
    function setOperationFees(
        bytes32[] memory _opTypes,
        bytes32[] memory _opCommands,
        uint256[] memory _fees
    )
        external onlyGovernance
    {
        require(_opTypes.length == _opCommands.length && _opTypes.length == _fees.length, "lengths mismatch");
        for (uint256 i = 0; i < _opTypes.length; i++) {
            operationFee[_opTypes[i]][_opCommands[i]] = _fees[i];
            emit OperationFeeSet(_opTypes[i], _opCommands[i], _fees[i]);
        }
    }

    /**
     * @inheritdoc ITeeFeeCalculator
     */
    function getOperationFee(bytes32 _opType, bytes32 _opCommand) external view override returns (uint256) {
        return operationFee[_opType][_opCommand];
    }

    /**
     * @inheritdoc ITeeFeeCalculator
     */
    function calculateFeeByWalletId(
        bytes32 _opType,
        bytes32 _opCommand,
        bytes32 _walletId
    )
        external view returns (uint256)
    {
        return operationFee[_opType][_opCommand] * teeWalletManager.getFeeFactor(_walletId);
    }

    /**
     * @inheritdoc ITeeFeeCalculator
     */
    function calculateFeeByTeeIds(
        bytes32 _opType,
        bytes32 _opCommand,
        address[] memory _teeIds,
        address[] memory _backupTeeIds

    )
        external view returns (uint256)
    {
        return operationFee[_opType][_opCommand] * (_teeIds.length + _backupTeeIds.length);
    }

    /**
     * @inheritdoc AddressUpdatable
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal override
    {
        teeWalletManager = ITeeWalletManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeWalletManager"));
    }

}
