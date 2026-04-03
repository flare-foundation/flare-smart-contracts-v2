// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ITeeWalletVerificationFacet } from "../../userInterfaces/tee/ITeeWalletVerificationFacet.sol";
import { ITeeVerificationFacet } from "../../userInterfaces/tee/ITeeVerificationFacet.sol";
import { ITeeWalletManagerFacet } from "../../userInterfaces/tee/ITeeWalletManagerFacet.sol";
import { IPMWMultisigAccountConfigured, PMW_MULTISIG_ACCOUNT_CONFIGURED_ATTESTATION_TYPE }
    from "../../userInterfaces/fdc2/IPMWMultisigAccountConfigured.sol";
import { IFdc2Hub } from "../../userInterfaces/fdc2/IFdc2Hub.sol";
import { IFdc2Verification } from "../../userInterfaces/fdc2/IFdc2Verification.sol";
import { IFlareSystemsManager } from "../../userInterfaces/IFlareSystemsManager.sol";
import { TeeVerification } from "../library/TeeVerification.sol";
import { TeeWalletManager } from "../library/TeeWalletManager.sol";
import { TeeWalletKeyManager } from "../library/TeeWalletKeyManager.sol";
import { TeeExternalAddresses } from "../library/TeeExternalAddresses.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title TeeWalletVerificationFacet
 * @notice Facet for PMW (Personal Multisig Wallet) attestation and verification.
 */
contract TeeWalletVerificationFacet is ITeeWalletVerificationFacet {
    using EnumerableSet for EnumerableSet.AddressSet;

    /**
     * @inheritdoc ITeeWalletVerificationFacet
     */
    function requestPMWMultisigAccountConfiguredAttestation(
        bytes32 _walletId,
        bytes32 _sourceId,
        string calldata _accountAddress,
        address _testOnTeeId,
        address _proofOwner,
        address _claimBackAddress
    )
        external payable
    {
        require(bytes(_accountAddress).length > 0, AccountAddressZero());
        ITeeWalletManagerFacet.WalletStatus walletStatus = TeeWalletManager.getWalletStatus(_walletId);
        require(
            walletStatus == ITeeWalletManagerFacet.WalletStatus.PRODUCTION ||
                walletStatus == ITeeWalletManagerFacet.WalletStatus.PAUSED,
            OnlyProductionOrPausedStatus()
        );

        (uint64 multisigThreshold, uint64[] memory keyIds, ) =
            TeeWalletKeyManager.getWalletKeysInfo(_walletId);
        IPMWMultisigAccountConfigured.RequestBody memory requestBody =
            IPMWMultisigAccountConfigured.RequestBody({
                accountAddress: _accountAddress,
                publicKeys: new bytes[](keyIds.length),
                threshold: multisigThreshold
            });
        for (uint256 i = 0; i < keyIds.length; i++) {
            requestBody.publicKeys[i] = TeeWalletKeyManager.getWalletKeyPublicKey(_walletId, keyIds[i]);
        }

        TeeVerification.State storage verState = TeeVerification.getState();
        TeeVerification.requestFdc2Attestation(
            _testOnTeeId,
            verState.cosigners.values(),
            verState.cosignersThreshold,
            PMW_MULTISIG_ACCOUNT_CONFIGURED_ATTESTATION_TYPE,
            _sourceId,
            abi.encode(requestBody),
            _proofOwner,
            _claimBackAddress
        );
    }

    /**
     * @inheritdoc ITeeWalletVerificationFacet
     */
    function verifyPMWMultisigAccountConfiguredProof(
        bytes32 _walletId,
        IPMWMultisigAccountConfigured.Proof calldata _proof
    )
        external
        returns (bool)
    {
        IFdc2Hub.Fdc2ResponseHeader calldata header = _proof.header;
        require(
            header.thresholdBIPS == 0 &&
                header.attestationType == PMW_MULTISIG_ACCOUNT_CONFIGURED_ATTESTATION_TYPE,
            ITeeVerificationFacet.InvalidAttestation()
        );

        {
            IPMWMultisigAccountConfigured.RequestBody calldata requestBody = _proof.requestBody;
            (uint64 multisigThreshold, uint64[] memory keyIds, ) =
                TeeWalletKeyManager.getWalletKeysInfo(_walletId);
            require(
                multisigThreshold == requestBody.threshold &&
                    keyIds.length == requestBody.publicKeys.length,
                ITeeVerificationFacet.InvalidRequestBody()
            );
            for (uint256 i = 0; i < keyIds.length; i++) {
                bytes memory publicKey = TeeWalletKeyManager.getWalletKeyPublicKey(_walletId, keyIds[i]);
                require(
                    keccak256(requestBody.publicKeys[i]) == keccak256(publicKey),
                    ITeeVerificationFacet.InvalidRequestBody()
                );
            }
        }

        bytes32 messageHash = keccak256(abi.encode(
            keccak256(abi.encode(header)),
            keccak256(abi.encode(_proof.requestBody)),
            keccak256(abi.encode(_proof.responseBody))
        ));

        TeeExternalAddresses.State storage ext = TeeExternalAddresses.getState();
        uint256 currentRewardEpochId =
            IFlareSystemsManager(ext.flareSystemsManager).getCurrentRewardEpochId();

        if (_proof.signatures.teeSignatures.length > 0) {
            IFdc2Verification(ext.fdc2Verification).verifyTeeSignatures(
                _proof.signatures.teeSignatures, messageHash
            );
        } else {
            TeeVerification.checkSigningPolicySignatures(
                currentRewardEpochId, messageHash, _proof.signatures.signingPolicySignatures
            );
        }
        TeeVerification.checkCosignerSignatures(
            TeeVerification.toCosignersMessageHash(messageHash),
            _proof.signatures.cosignerSignatures
        );

        return _proof.responseBody.status == IPMWMultisigAccountConfigured.PMWMultisigAccountStatus.OK;
    }
}
