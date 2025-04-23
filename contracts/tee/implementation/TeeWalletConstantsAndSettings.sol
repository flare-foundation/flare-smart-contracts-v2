// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../utils/implementation/AddressUpdatable.sol";
import "../interface/IITeeWalletConstantsAndSettings.sol";
import "../../userInterfaces/tee/ITeeWalletManager.sol";
import "../../userInterfaces/tee/ITeeWalletKeyManager.sol";
import "../../userInterfaces/tee/ITeeWalletProjectManager.sol";
import "../../userInterfaces/tee/ITeeFeeCalculator.sol";
import "../../userInterfaces/tee/ITeeInstructions.sol";
import "../../userInterfaces/IFlareSystemsManager.sol";

abstract contract TeeWalletConstantsAndSettings is IITeeWalletConstantsAndSettings, AddressUpdatable {

    /// TeeWalletProjectManager contract.
    ITeeWalletProjectManager public teeWalletProjectManager;
    /// TeeWalletManager contract.
    ITeeWalletManager public teeWalletManager;
    /// TeeWalletKeyManager contract.
    ITeeWalletKeyManager public teeWalletKeyManager;
    /// TeeFeeCalculator contract.
    ITeeFeeCalculator public teeFeeCalculator;
    /// TeeInstructions contract.
    ITeeInstructions public teeInstructions;
    /// Flare systems manager contract.
    IFlareSystemsManager public flareSystemsManager;

    bytes32 public opType;

    /**
     * Constructor.
     * @param _addressUpdater The address updater contract.
     * @param _opType The operation type.
     */
    constructor(
        address _addressUpdater,
        bytes32 _opType
    )
        AddressUpdatable(_addressUpdater)
    {
        opType = _opType;
    }

    /**
     * @inheritdoc IITeeWalletOpTypeConstants
     */
    function getOpTypeConstants(bytes32 _walletId) external view virtual returns(bytes memory);

    function setOpTypeAndAddressUpdater(address _addressUpdater, bytes32 _opType) internal {
        AddressUpdatable.setAddressUpdaterValue(_addressUpdater);
        opType = _opType;
    }

    /**
     * @inheritdoc AddressUpdatable
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal virtual override
    {
        teeWalletProjectManager = ITeeWalletProjectManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeWalletProjectManager"));
        teeWalletManager = ITeeWalletManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeWalletManager"));
        teeWalletKeyManager = ITeeWalletKeyManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeWalletKeyManager"));
        teeFeeCalculator = ITeeFeeCalculator(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeFeeCalculator"));
        teeInstructions = ITeeInstructions(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeInstructions"));
        flareSystemsManager = IFlareSystemsManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsManager"));
    }
}

