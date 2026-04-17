// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IWalletResumeFacet } from "../../userInterfaces/tee/IWalletResumeFacet.sol";
import { IWalletManagerFacet, WALLET_OP_TYPE } from "../../userInterfaces/tee/IWalletManagerFacet.sol";
import { IInstructionsFacet } from "../../userInterfaces/tee/IInstructionsFacet.sol";
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
contract WalletResumeFacet is IWalletResumeFacet {

    bytes32 internal constant SET_PAUSING_ADDRESSES = bytes32("SET_PAUSING_ADDRESSES");
    bytes32 internal constant RESUME = bytes32("RESUME");

    modifier onlyOwner(bytes32 _walletId) {
        _checkOnlyOwner(_walletId);
        _;
    }

    /**
     * @inheritdoc IWalletResumeFacet
     */
    function setPausingAddresses(
        bytes32 _walletId,
        address[] calldata _pausingAddresses,
        address _claimBackAddress
    )
        external payable
        onlyOwner(_walletId)
    {
        IWalletManagerFacet.WalletStatus walletStatus = WalletManager.getWalletStatus(_walletId);
        require(
            walletStatus == IWalletManagerFacet.WalletStatus.PRODUCTION
                || walletStatus == IWalletManagerFacet.WalletStatus.PAUSED,
            OnlyProductionOrPausedStatus()
        );
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

        Instructions.sendInstructions(
            bytes32(0),
            _toTeeIds(teeIdKeyIdPairs),
            IInstructionsFacet.TeeInstructionParams(
                WALLET_OP_TYPE,
                SET_PAUSING_ADDRESSES,
                abi.encode(message),
                admins,
                adminsThreshold,
                _claimBackAddress
            )
        );
    }

    /**
     * @inheritdoc IWalletResumeFacet
     */
    function resume(
        bytes32 _walletId,
        ResumeKeyData[] calldata _keysData,
        address _claimBackAddress
    )
        external payable
        onlyOwner(_walletId)
    {
        IWalletManagerFacet.WalletStatus walletStatus = WalletManager.getWalletStatus(_walletId);
        require(
            walletStatus == IWalletManagerFacet.WalletStatus.PRODUCTION
                || walletStatus == IWalletManagerFacet.WalletStatus.PAUSED,
            OnlyProductionOrPausedStatus()
        );

        uint256 numOfKeys = _keysData.length;
        address[] memory teeIds = new address[](numOfKeys);
        (, uint64[] memory keyIds, ) = WalletKeyManager.getWalletKeysInfo(_walletId);
        for (uint256 i = 0; i < numOfKeys; i++) {
            bool found = false;
            for (uint256 j = 0; j < keyIds.length; j++) {
                if (keyIds[j] == _keysData[i].keyId) {
                    found = true;
                    break;
                }
            }
            require(found, WrongKeyId());
            MachineManager.checkTeeMachineInProduction(_keysData[i].teeId);
            teeIds[i] = _keysData[i].teeId;
        }

        Resume memory message = Resume({
            walletId: _walletId,
            keysData: _keysData
        });
        Instructions.sendInstructions(
            bytes32(0),
            teeIds,
            IInstructionsFacet.TeeInstructionParams(
                WALLET_OP_TYPE,
                RESUME,
                abi.encode(message),
                new address[](0),
                0,
                _claimBackAddress
            )
        );
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
