// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { IWalletResume } from "../../userInterfaces/tee/IWalletResume.sol";
import { IWalletManager, WALLET_OP_TYPE } from "../../userInterfaces/tee/IWalletManager.sol";
import { IInstructions } from "../../userInterfaces/tee/IInstructions.sol";
import { TeeIdKeyIdPair } from "../../userInterfaces/tee/ITeeIdKeyIdPair.sol";
import { WalletManager } from "../library/WalletManager.sol";
import { WalletKeyManager } from "../library/WalletKeyManager.sol";
import { WalletProjectManager } from "../library/WalletProjectManager.sol";
import { MachineManager } from "../library/MachineManager.sol";
import { Instructions } from "../library/Instructions.sol";
import { WalletResume } from "../library/WalletResume.sol";

/**
 * @title WalletResumeFacet
 * @notice Facet for TEE wallet pausing-address and resume operations.
 */
contract WalletResumeFacet is IWalletResume {

    bytes32 internal constant SET_PAUSING_ADDRESSES = bytes32("SET_PAUSING_ADDRESSES");
    bytes32 internal constant RESUME = bytes32("RESUME");

    modifier onlyOwner(bytes32 _walletId) {
        _checkOnlyOwner(_walletId);
        _;
    }

    /**
     * @inheritdoc IWalletResume
     */
    function setPausingAddresses(
        bytes32 _walletId,
        address[] calldata _pausingAddresses,
        address _claimBackAddress
    )
        external payable
        onlyOwner(_walletId)
    {
        IWalletManager.WalletStatus walletStatus = WalletManager.getWalletStatus(_walletId);
        require(
            walletStatus == IWalletManager.WalletStatus.PRODUCTION
                || walletStatus == IWalletManager.WalletStatus.PAUSED,
            OnlyProductionOrPausedStatus()
        );
        // The list may be empty, but any provided entry must be a non-zero, unique address.
        for (uint256 i = 0; i < _pausingAddresses.length; i++) {
            require(_pausingAddresses[i] != address(0), InvalidAddress());
            for (uint256 j = i + 1; j < _pausingAddresses.length; j++) {
                require(_pausingAddresses[i] != _pausingAddresses[j], AddressAlreadyInSet(_pausingAddresses[i]));
            }
        }
        TeeIdKeyIdPair[] memory teeIdKeyIdPairs = WalletKeyManager.receivingTeesAndKeys(_walletId);

        WalletResume.State storage rs = WalletResume.getState();
        SetPausingAddresses memory message = SetPausingAddresses({
            walletId: _walletId,
            nonce: rs.setPausingAddressesNonce[_walletId]++,
            teeIdKeyIdPairs: teeIdKeyIdPairs,
            pausingAddresses: _pausingAddresses
        });
        (address[] memory admins, uint64 adminsThreshold) =
            WalletManager.getWalletAdminsAndThreshold(_walletId);

        address[] memory teeIds = _toTeeIds(teeIdKeyIdPairs);
        Instructions.removeDuplicates(teeIds);
        Instructions.sendInstructions(
            bytes32(0),
            teeIds,
            IInstructions.TeeInstructionParams(
                WALLET_OP_TYPE,
                SET_PAUSING_ADDRESSES,
                abi.encode(message),
                admins,
                adminsThreshold,
                _claimBackAddress
            )
        );
        emit PausingAddressesSet(_walletId, message.nonce, _pausingAddresses);
    }

    /**
     * @inheritdoc IWalletResume
     */
    function resume(
        bytes32 _walletId,
        ResumeKeyData[] calldata _keysData,
        address _claimBackAddress
    )
        external payable
        onlyOwner(_walletId)
    {
        IWalletManager.WalletStatus walletStatus = WalletManager.getWalletStatus(_walletId);
        require(
            walletStatus == IWalletManager.WalletStatus.PRODUCTION
                || walletStatus == IWalletManager.WalletStatus.PAUSED,
            OnlyProductionOrPausedStatus()
        );

        uint256 numOfKeys = _keysData.length;
        address[] memory teeIds = new address[](numOfKeys);
        uint256 extensionId = WalletProjectManager.getExtensionId(WalletManager.getWalletProjectId(_walletId));
        for (uint256 i = 0; i < numOfKeys; i++) {
            address teeId = _keysData[i].teeId;
            uint64 keyId = _keysData[i].keyId;
            // Mirror the validations enforced by every other key-bearing wallet flow: the TEE must
            // belong to the wallet's project extension, must currently hold the (wallet, key) pair,
            // and must be in production. The ResumeKeyData.nonce is an off-chain value (not the
            // on-chain key-management nonce), so it is forwarded to the TEE without on-chain checks.
            require(extensionId == MachineManager.getExtensionId(teeId), ExtensionIdMismatch());
            require(WalletKeyManager.isKeyAvailable(teeId, _walletId, keyId), WrongKeyId());
            MachineManager.checkTeeMachineInProduction(teeId);
            teeIds[i] = teeId;
        }

        Resume memory message = Resume({
            walletId: _walletId,
            keysData: _keysData
        });
        Instructions.removeDuplicates(teeIds);
        Instructions.sendInstructions(
            bytes32(0),
            teeIds,
            IInstructions.TeeInstructionParams(
                WALLET_OP_TYPE,
                RESUME,
                abi.encode(message),
                new address[](0),
                0,
                _claimBackAddress
            )
        );
        emit WalletResumed(_walletId, _keysData);
    }

    function _checkOnlyOwner(
        bytes32 _walletId
    )
        private view
    {
        address owner = WalletProjectManager.getOwner(
            WalletManager.getWalletProjectId(_walletId)
        );
        require(owner == msg.sender, OnlyOwner());
    }

    function _toTeeIds(
        TeeIdKeyIdPair[] memory _teeIdKeyIdPairs
    )
        private pure
        returns (address[] memory _teeIds)
    {
        _teeIds = new address[](_teeIdKeyIdPairs.length);
        for (uint256 i = 0; i < _teeIdKeyIdPairs.length; i++) {
            _teeIds[i] = _teeIdKeyIdPairs[i].teeId;
        }
    }
}
