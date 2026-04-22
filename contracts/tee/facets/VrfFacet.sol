// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IVrfFacet } from "../../userInterfaces/tee/IVrfFacet.sol";
import { IInstructionsFacet } from "../../userInterfaces/tee/IInstructionsFacet.sol";
import { IMachineManagerFacet } from "../../userInterfaces/tee/IMachineManagerFacet.sol";
import { IWalletManagerFacet, WALLET_OP_TYPE } from "../../userInterfaces/tee/IWalletManagerFacet.sol";
import { WalletManager } from "../library/WalletManager.sol";
import { WalletProjectManager } from "../library/WalletProjectManager.sol";
import { WalletKeyManager } from "../library/WalletKeyManager.sol";
import { MachineManager } from "../library/MachineManager.sol";
import { Instructions } from "../library/Instructions.sol";
import { Vrf } from "../library/Vrf.sol";

/**
 * @title VrfFacet
 * @notice Facet for instructing TEE machines to generate VRF proofs.
 */
contract VrfFacet is IVrfFacet {

    bytes32 internal constant VRF = bytes32("VRF");

    /**
     * @inheritdoc IVrfFacet
     */
    function requestVrf(
        bytes32 _walletId,
        uint64 _keyId,
        bytes calldata _nonce,
        address _claimBackAddress
    )
        external payable
        returns (bytes32 _instructionId)
    {
        require(_nonce.length > 0, NonceEmpty());
        require(Vrf.getState().vrfAuthorizationAddresses[_walletId] == msg.sender, OnlyAuthorizationAddress());
        require(
            WalletManager.getWalletStatus(_walletId) == IWalletManagerFacet.WalletStatus.PRODUCTION,
            WalletNotInProduction()
        );
        address[] memory teeIds = WalletKeyManager.getWalletKeyTeeIds(_walletId, _keyId);
        // remove all tee ids that are not in production status
        uint256 productionTeeCount = 0;
        for (uint256 i = 0; i < teeIds.length; i++) {
            if (MachineManager.getTeeMachineStatus(teeIds[i]) ==
                IMachineManagerFacet.TeeStatus.PRODUCTION)
            {
                teeIds[productionTeeCount] = teeIds[i];
                productionTeeCount++;
            }
        }
        require(productionTeeCount > 0, NoTeesForKey());

        // solhint-disable-next-line no-inline-assembly
        assembly { mstore(teeIds, productionTeeCount) }

        VrfInstructionMessage memory message = VrfInstructionMessage({
            walletId: _walletId,
            keyId: _keyId,
            nonce: _nonce
        });
        _instructionId = Instructions.sendInstructions(
            bytes32(0),
            teeIds,
            IInstructionsFacet.TeeInstructionParams(
                WALLET_OP_TYPE,
                VRF,
                abi.encode(message),
                new address[](0),
                0,
                _claimBackAddress
            )
        );
        emit VrfRequested(_walletId, _keyId, _instructionId);
    }

    /**
     * @inheritdoc IVrfFacet
     */
    function setVrfAuthorizationAddress(
        bytes32 _walletId,
        address _authorizationAddress
    )
        external
    {
        bytes32 projectId = WalletManager.getWalletProjectId(_walletId);
        require(WalletProjectManager.getOwner(projectId) == msg.sender, OnlyWalletOwner());
        Vrf.getState().vrfAuthorizationAddresses[_walletId] = _authorizationAddress;
        emit VrfAuthorizationAddressSet(_walletId, _authorizationAddress);
    }

    /**
     * @inheritdoc IVrfFacet
     */
    function getVrfAuthorizationAddress(
        bytes32 _walletId
    )
        external view
        returns (address)
    {
        return Vrf.getState().vrfAuthorizationAddresses[_walletId];
    }
}
