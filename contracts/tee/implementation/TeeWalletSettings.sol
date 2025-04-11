// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../utils/implementation/AddressUpdatable.sol";
import "../../tee/interface/IITeeWalletOpTypeConstants.sol";
import "../../tee/interface/IITeeWalletOpTypeSettings.sol";
import "../../userInterfaces/tee/ITeeWalletManager.sol";
import "../../userInterfaces/tee/ITeeWalletProjectManager.sol";
import "../../userInterfaces/tee/ITeeInstructions.sol";
import "../../userInterfaces/IFlareSystemsManager.sol";

abstract contract TeeWalletSettings is IITeeWalletOpTypeConstants, IITeeWalletOpTypeSettings, AddressUpdatable {

    /// TeeWalletProjectManager contract.
    ITeeWalletProjectManager public teeWalletProjectManager;
    /// TeeWalletManager contract.
    ITeeWalletManager public teeWalletManager;
    /// TeeInstructions contract.
    ITeeInstructions public teeInstructions;
    /// Flare systems manager contract.
    IFlareSystemsManager public flareSystemsManager;

    bytes32 public immutable opType;
    bytes32 public constant SET_PAUSING_ADDRESSES = bytes32("SET_PAUSING_ADDRESSES");

    mapping (bytes32 walletId => uint256) private setPausingAddressesCounter;

    /**
     * Constructor.
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
     * @inheritdoc IITeeWalletOpTypeSettings
     */
    function setPausingAddresses(
        bytes32 _walletId,
        address[] calldata _pausingAddresses
    )
        external payable
    {
        require(_pausingAddresses.length > 0, "addresses length zero");
        bytes32 projectId = teeWalletManager.getWalletProjectId(_walletId);
        require(teeWalletProjectManager.getOwner(projectId) == msg.sender, "only wallet owner");
        ITeeWalletManager.WalletStatus walletStatus = teeWalletManager.getWalletStatus(_walletId);
        require(walletStatus == ITeeWalletManager.WalletStatus.PRODUCTION ||
            walletStatus == ITeeWalletManager.WalletStatus.PAUSED, "only production or paused status");

        (ITeeRegistry.TeeMachine[] memory receivingTees, ITeeWalletManager.TeeIdKeyIdPair[] memory teeIdKeyIdPairs) =
            teeWalletManager.receivingTeesAndKeys(_walletId);

        SetPausingAddresses memory message = SetPausingAddresses({
            walletId: _walletId,
            teeIdKeyIdPairs: teeIdKeyIdPairs,
            pausingAddresses: _pausingAddresses
        });
        bytes32 instructionId = keccak256(abi.encode(
            opType, SET_PAUSING_ADDRESSES, _walletId, setPausingAddressesCounter[_walletId]++
        ));
        teeInstructions.sendInstructions{value: msg.value}(
            instructionId,
            receivingTees,
            flareSystemsManager.getCurrentRewardEpochId(),
            opType,
            SET_PAUSING_ADDRESSES,
            abi.encode(message)
        );
    }

    /**
     * @inheritdoc IITeeWalletOpTypeConstants
     */
    function getOpTypeConstants(bytes32 _walletId) external view virtual returns(bytes memory);

    /**
     * @inheritdoc AddressUpdatable
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal virtual override
    {
        flareSystemsManager = IFlareSystemsManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsManager"));
        teeWalletProjectManager = ITeeWalletProjectManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeWalletProjectManager"));
        teeWalletManager = ITeeWalletManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeWalletManager"));
        teeInstructions = ITeeInstructions(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeInstructions"));
    }
}

