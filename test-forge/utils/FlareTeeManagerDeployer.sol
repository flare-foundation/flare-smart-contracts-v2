// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

// Diamond infrastructure
import { FlareTeeManager } from "../../contracts/tee/diamond/FlareTeeManager.sol";
import { IDiamond } from "../../contracts/diamond/interfaces/IDiamond.sol";
import { IDiamondCut } from "../../contracts/diamond/interfaces/IDiamondCut.sol";
import { DiamondLoupeFacet } from "../../contracts/diamond/facets/DiamondLoupeFacet.sol";

// TEE facets — day-1
import { DiamondGovernanceFacet } from "../../contracts/tee/facets/DiamondGovernanceFacet.sol";
import { ExtensionManagerFacet } from "../../contracts/tee/facets/ExtensionManagerFacet.sol";
import { InstructionsFacet } from "../../contracts/tee/facets/InstructionsFacet.sol";
import { MachineManagerFacet } from "../../contracts/tee/facets/MachineManagerFacet.sol";
import { VerificationFacet } from "../../contracts/tee/facets/VerificationFacet.sol";
import { OperationFeesFacet } from "../../contracts/tee/facets/OperationFeesFacet.sol";
import { OwnerAllowlistFacet } from "../../contracts/tee/facets/OwnerAllowlistFacet.sol";
import { SystemStateVerifierFacet } from "../../contracts/tee/facets/SystemStateVerifierFacet.sol";
import { ExternalAddressesFacet } from "../../contracts/tee/facets/ExternalAddressesFacet.sol";
import { WalletProjectManagerFacet } from "../../contracts/tee/facets/WalletProjectManagerFacet.sol";
import { WalletKeyManagerFacet } from "../../contracts/tee/facets/WalletKeyManagerFacet.sol";
import { WalletManagerFacet } from "../../contracts/tee/facets/WalletManagerFacet.sol";
import { WalletBackupManagerFacet } from "../../contracts/tee/facets/WalletBackupManagerFacet.sol";
import { VrfFacet } from "../../contracts/tee/facets/VrfFacet.sol";

// TEE facets — later
import { ReplicationFacet } from "../../contracts/tee/facets/ReplicationFacet.sol";
import { ExtensionGovernanceFacet } from "../../contracts/tee/facets/ExtensionGovernanceFacet.sol";
import { UpgradeManagerFacet } from "../../contracts/tee/facets/UpgradeManagerFacet.sol";
import { WalletResumeFacet } from "../../contracts/tee/facets/WalletResumeFacet.sol";

// Init contracts
import { FlareTeeManagerInit } from "../../contracts/tee/facets/FlareTeeManagerInit.sol";
import { ReplicationInit } from "../../contracts/tee/facets/ReplicationInit.sol";

// TEE interfaces (for selector references)
import { IIExtensionManager } from "../../contracts/tee/interface/IIExtensionManager.sol";
import { IIInstructions } from "../../contracts/tee/interface/IIInstructions.sol";
import { IIVerification } from "../../contracts/tee/interface/IIVerification.sol";
import { IIOperationFees } from "../../contracts/tee/interface/IIOperationFees.sol";
import { IIReplication } from "../../contracts/tee/interface/IIReplication.sol";
import { IExtensionManager } from "../../contracts/userInterfaces/tee/IExtensionManager.sol";
import { IInstructions } from "../../contracts/userInterfaces/tee/IInstructions.sol";
import { IMachineManager } from "../../contracts/userInterfaces/tee/IMachineManager.sol";
import { IOwnerAllowlist } from "../../contracts/userInterfaces/tee/IOwnerAllowlist.sol";
import { IExtensionGovernance } from "../../contracts/userInterfaces/tee/IExtensionGovernance.sol";
import { IReplication } from "../../contracts/userInterfaces/tee/IReplication.sol";
import { IVerification } from "../../contracts/userInterfaces/tee/IVerification.sol";
import { ISystemStateVerifier } from "../../contracts/userInterfaces/tee/ISystemStateVerifier.sol";
import { IUpgradeManager } from "../../contracts/userInterfaces/tee/IUpgradeManager.sol";
import { IOperationFees } from "../../contracts/userInterfaces/tee/IOperationFees.sol";
import { IWalletProjectManager } from "../../contracts/userInterfaces/tee/IWalletProjectManager.sol";
import { IWalletKeyManager } from "../../contracts/userInterfaces/tee/IWalletKeyManager.sol";
import { IWalletManager } from "../../contracts/userInterfaces/tee/IWalletManager.sol";
import { IWalletResume } from "../../contracts/userInterfaces/tee/IWalletResume.sol";
import { IWalletBackupManager } from "../../contracts/userInterfaces/tee/IWalletBackupManager.sol";
import { IVrf } from "../../contracts/userInterfaces/tee/IVrf.sol";
import { IIFlareTeeManager } from "../../contracts/tee/interface/IIFlareTeeManager.sol";

import { IFlareGovernance } from "../../contracts/userInterfaces/tee/IFlareGovernance.sol";
import { IIFlareGovernance } from "../../contracts/tee/interface/IIFlareGovernance.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

/**
 * @title FlareTeeManagerDeployer
 * @notice Shared test utility for deploying the FlareTeeManager Diamond.
 *         Mirrors the production deployment pattern (DeployTeeContracts.s.sol):
 *         - deployDay1Facets(): creates diamond with 15 day-1 facets + FlareTeeManagerInit
 *         - deployLaterFacets(): adds 4 later facets via diamondCut + ReplicationInit
 *           Caller must vm.prank(initialGovernance) before calling deployLaterFacets.
 */
library FlareTeeManagerDeployer {

    struct Day1DeployParams {
        IGovernanceSettings governanceSettings;
        address initialGovernance;
        address addressUpdater;
        uint64 availabilityCheckValidityDurationSeconds;
        uint64 signingPolicyValidityDurationInRewardEpochs;
        uint64 challengeValidityDurationSeconds;
        uint256 defaultFee;
    }

    struct LaterDeployParams {
        uint256 pauseBeforeUpgradeMinDurationSeconds;
    }

    function deployDay1Facets(Day1DeployParams memory _params) internal returns (IIFlareTeeManager) {
        IDiamond.FacetCut[] memory cuts = _buildDay1FacetCuts();

        FlareTeeManagerInit initContract = new FlareTeeManagerInit();
        bytes memory initCalldata = abi.encodeCall(
            FlareTeeManagerInit.init,
            (
                _params.governanceSettings,
                _params.initialGovernance,
                _params.addressUpdater,
                _params.availabilityCheckValidityDurationSeconds,
                _params.signingPolicyValidityDurationInRewardEpochs,
                _params.challengeValidityDurationSeconds,
                _params.defaultFee
            )
        );

        FlareTeeManager diamond = new FlareTeeManager(
            cuts,
            FlareTeeManager.DiamondArgs({
                init: address(initContract),
                initCalldata: initCalldata
            })
        );

        return IIFlareTeeManager(address(diamond));
    }

    function deployLaterFacets(
        IIFlareTeeManager _diamond,
        LaterDeployParams memory _params
    )
        internal
    {
        IDiamond.FacetCut[] memory cuts = _buildLaterFacetCuts();

        ReplicationInit replicationInit = new ReplicationInit();
        bytes memory initCalldata = abi.encodeCall(
            ReplicationInit.init,
            (_params.pauseBeforeUpgradeMinDurationSeconds)
        );

        IDiamondCut(address(_diamond)).diamondCut(
            cuts,
            address(replicationInit),
            initCalldata
        );
    }

    // =========================================================================
    // Day-1 facet cuts (15 facets)
    // =========================================================================

    function _buildDay1FacetCuts() private returns (IDiamond.FacetCut[] memory cuts) {
        cuts = new IDiamond.FacetCut[](15);

        // 0: DiamondGovernanceFacet (diamondCut + FlareGovernance selectors)
        {
            bytes4[] memory s = new bytes4[](8);
            s[0] = IDiamondCut.diamondCut.selector;
            s[1] = IFlareGovernance.executeGovernanceCall.selector;
            s[2] = IIFlareGovernance.cancelGovernanceCall.selector;
            s[3] = IIFlareGovernance.switchToProductionMode.selector;
            s[4] = IFlareGovernance.governance.selector;
            s[5] = IFlareGovernance.governanceSettings.selector;
            s[6] = IFlareGovernance.productionMode.selector;
            s[7] = IFlareGovernance.isExecutor.selector;
            cuts[0] = IDiamond.FacetCut(
                address(new DiamondGovernanceFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 1: DiamondLoupeFacet
        {
            bytes4[] memory s = new bytes4[](4);
            s[0] = DiamondLoupeFacet.facets.selector;
            s[1] = DiamondLoupeFacet.facetFunctionSelectors.selector;
            s[2] = DiamondLoupeFacet.facetAddresses.selector;
            s[3] = DiamondLoupeFacet.facetAddress.selector;
            cuts[1] = IDiamond.FacetCut(
                address(new DiamondLoupeFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 2: ExtensionManagerFacet
        {
            bytes4[] memory s = new bytes4[](25);
            s[0] = IExtensionManager.register.selector;
            s[1] = IExtensionManager.addTeeVersion.selector;
            s[2] = IExtensionManager.getExtensionOwner.selector;
            s[3] = IExtensionManager.getTeeExtensionStateVerifier.selector;
            s[4] = IExtensionManager.getTeeExtensionInstructionsSender.selector;
            s[5] = IExtensionManager.isCodeHashPlatformSupported.selector;
            s[6] = IExtensionManager.getTeeGovernanceHash.selector;
            s[7] = IExtensionManager.getCodeHashInfo.selector;
            s[8] = IIExtensionManager.addSystemSupportedPlatforms.selector;
            s[9] = IIExtensionManager.addSystemSupportedKeyTypesAndSigningAlgos.selector;
            s[10] = IExtensionManager.addSupportedKeyTypes.selector;
            s[11] = IExtensionManager.extensionsCounter.selector;
            s[12] = IExtensionManager.isKeyTypeSupported.selector;
            s[13] = IExtensionManager.setExtensionContracts.selector;
            s[14] = IExtensionManager.disableCodeHashPlatform.selector;
            s[15] = IExtensionManager.removeSupportedKeyTypes.selector;
            s[16] = IExtensionManager.proposeNewOwner.selector;
            s[17] = IExtensionManager.confirmOwnership.selector;
            s[18] = IExtensionManager.getSystemSupportedPlatforms.selector;
            s[19] = IExtensionManager.getSystemSupportedKeyTypes.selector;
            s[20] = IExtensionManager.isSigningAlgoSupported.selector;
            s[21] = IExtensionManager.getSupportedCodeHashes.selector;
            s[22] = IExtensionManager.isCodeHashPlatformDisabled.selector;
            s[23] = IExtensionManager.getSystemSupportedSigningAlgos.selector;
            s[24] = IExtensionManager.getSupportedKeyTypes.selector;
            cuts[2] = IDiamond.FacetCut(
                address(new ExtensionManagerFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 3: InstructionsFacet
        {
            bytes4[] memory s = new bytes4[](6);
            s[0] = IInstructions.sendInstructions.selector;
            // sendSystemInstructions overloads
            s[1] = bytes4(keccak256(
                "sendSystemInstructions(bytes32,address[],"
                "(bytes32,bytes32,bytes,address[],uint64,address))"
            ));
            s[2] = bytes4(keccak256(
                "sendSystemInstructions(bytes32,(address,address,string)[],"
                "(bytes32,bytes32,bytes,address[],uint64,address))"
            ));
            s[3] = IIInstructions.registerSystemInstructionsSenders.selector;
            s[4] = IIInstructions.unregisterSystemInstructionsSenders.selector;
            s[5] = IInstructions.getSystemInstructionsSenders.selector;
            cuts[3] = IDiamond.FacetCut(
                address(new InstructionsFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 5: MachineManagerFacet
        {
            bytes4[] memory s = new bytes4[](20);
            s[0] = IMachineManager.register.selector;
            s[1] = IMachineManager.toProduction.selector;
            s[2] = IMachineManager.pause.selector;
            s[3] = IMachineManager.getTeeMachineStatus.selector;
            s[4] = IMachineManager.getExtensionId.selector;
            s[5] = IMachineManager.getTeeMachine.selector;
            s[6] = IMachineManager.getInitialSigningPolicyId.selector;
            s[7] = IMachineManager.pauseWithProof.selector;
            s[8] = IMachineManager.ban.selector;
            s[9] = IMachineManager.unban.selector;
            s[10] = IMachineManager.proposeNewOwner.selector;
            s[11] = IMachineManager.confirmOwnership.selector;
            s[12] = IMachineManager.updateTeeMachineSettings.selector;
            s[13] = IMachineManager.getTeeMachineOwner.selector;
            s[14] = IMachineManager.getTeeMachineWithAttestationData.selector;
            s[15] = IMachineManager.getRandomTeeIds.selector;
            s[16] = IMachineManager.getAllActiveTeeMachines.selector;
            s[17] = IMachineManager.getActiveTeeMachines.selector;
            s[18] = IMachineManager.getPublicKey.selector;
            s[19] = IMachineManager.getLastStatusChangeTs.selector;
            cuts[4] = IDiamond.FacetCut(
                address(new MachineManagerFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 6: VerificationFacet (includes wallet verification)
        {
            bytes4[] memory s = new bytes4[](11);
            s[0] = IVerification.requestTeeAttestation.selector;
            s[1] = IIVerification.setCosigners.selector;
            s[2] = IVerification.requestAvailabilityCheckAttestation.selector;
            s[3] = IVerification.confirmAvailability.selector;
            s[4] = IVerification.verifyAvailabilityCheckProof.selector;
            s[5] = IIVerification.updateSettings.selector;
            s[6] = IVerification.getCosigners.selector;
            s[7] = IVerification.getSettings.selector;
            s[8] = IVerification.getAvailabilityCheckValidity.selector;
            s[9] = IVerification.requestPMWMultisigAccountConfiguredAttestation.selector;
            s[10] = IVerification.verifyPMWMultisigAccountConfiguredProof.selector;
            cuts[5] = IDiamond.FacetCut(
                address(new VerificationFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 7: OperationFeesFacet
        {
            bytes4[] memory s = new bytes4[](5);
            s[0] = IIOperationFees.setOperationFees.selector;
            s[1] = IIOperationFees.setDefaultFee.selector;
            s[2] = IOperationFees.getDefaultFee.selector;
            s[3] = IOperationFees.getOperationFee.selector;
            s[4] = IOperationFees.calculateFeeByTeeIds.selector;
            cuts[6] = IDiamond.FacetCut(
                address(new OperationFeesFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 8: OwnerAllowlistFacet
        {
            bytes4[] memory s = new bytes4[](14);
            s[0] = IOwnerAllowlist.addAllowedTeeMachineOwners.selector;
            s[1] = IOwnerAllowlist.isAllowedTeeMachineOwner.selector;
            s[2] = IOwnerAllowlist.getAllowedTeeMachineOwners.selector;
            s[3] = IOwnerAllowlist.addAllowedTeeWalletProjectOwners.selector;
            s[4] = IOwnerAllowlist.isAllowedTeeWalletProjectOwner.selector;
            s[5] = IOwnerAllowlist.removeAllowedTeeMachineOwners.selector;
            s[6] = IOwnerAllowlist.removeAllowedTeeWalletProjectOwners.selector;
            s[7] = IOwnerAllowlist.allowAllTeeMachineOwners.selector;
            s[8] = IOwnerAllowlist.disallowAllTeeMachineOwners.selector;
            s[9] = IOwnerAllowlist.allowAllTeeWalletProjectOwners.selector;
            s[10] = IOwnerAllowlist.disallowAllTeeWalletProjectOwners.selector;
            s[11] = IOwnerAllowlist.getAllowedTeeWalletProjectOwners.selector;
            s[12] = IOwnerAllowlist.allTeeMachineOwnersAllowed.selector;
            s[13] = IOwnerAllowlist.allTeeWalletProjectOwnersAllowed.selector;
            cuts[7] = IDiamond.FacetCut(
                address(new OwnerAllowlistFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 9: SystemStateVerifierFacet
        {
            bytes4[] memory s = new bytes4[](1);
            s[0] = ISystemStateVerifier.verifyTeeSystemState.selector;
            cuts[8] = IDiamond.FacetCut(
                address(new SystemStateVerifierFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 10: ExternalAddressesFacet
        {
            bytes4[] memory s = new bytes4[](2);
            s[0] = bytes4(keccak256("updateContractAddresses(bytes32[],address[])"));
            s[1] = bytes4(keccak256("getAddressUpdater()"));
            cuts[9] = IDiamond.FacetCut(
                address(new ExternalAddressesFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 11: WalletProjectManagerFacet
        {
            bytes4[] memory s = new bytes4[](9);
            s[0] = IWalletProjectManager.createProject.selector;
            s[1] = IWalletProjectManager.getOwner.selector;
            s[2] = IWalletProjectManager.getExtensionId.selector;
            s[3] = IWalletProjectManager.getKeyType.selector;
            s[4] = IWalletProjectManager.setBackupManager.selector;
            s[5] = IWalletProjectManager.proposeNewOwner.selector;
            s[6] = IWalletProjectManager.confirmOwnership.selector;
            s[7] = IWalletProjectManager.getSigningAlgo.selector;
            s[8] = IWalletProjectManager.getBackupManager.selector;
            cuts[10] = IDiamond.FacetCut(
                address(new WalletProjectManagerFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 12: WalletKeyManagerFacet
        {
            bytes4[] memory s = new bytes4[](9);
            s[0] = IWalletKeyManager.addKey.selector;
            s[1] = IWalletKeyManager.confirmKey.selector;
            s[2] = IWalletKeyManager.setMultisigThreshold.selector;
            s[3] = IWalletKeyManager.receivingTeesAndKeys.selector;
            s[4] = IWalletKeyManager.getWalletKeysInfo.selector;
            s[5] = IWalletKeyManager.deleteKey.selector;
            s[6] = IWalletKeyManager.cleanUpTeeIds.selector;
            s[7] = IWalletKeyManager.getWalletKeyPublicKey.selector;
            s[8] = IWalletKeyManager.getWalletKeyTeeIds.selector;
            cuts[11] = IDiamond.FacetCut(
                address(new WalletKeyManagerFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 13: WalletManagerFacet
        {
            bytes4[] memory s = new bytes4[](14);
            s[0] = IWalletManager.createWallet.selector;
            s[1] = IWalletManager.setAdmins.selector;
            s[2] = IWalletManager.confirmAdmin.selector;
            s[3] = IWalletManager.setCosigners.selector;
            s[4] = IWalletManager.confirmCosigner.selector;
            s[5] = IWalletManager.closeWalletInitialization.selector;
            s[6] = IWalletManager.enableWallet.selector;
            s[7] = IWalletManager.getWalletProjectId.selector;
            s[8] = IWalletManager.getWalletCosignersAndThreshold.selector;
            s[9] = IWalletManager.getWalletStatus.selector;
            s[10] = IWalletManager.pauseWallet.selector;
            s[11] = IWalletManager.getProjectWalletIds.selector;
            s[12] = IWalletManager.getWalletAdminsPublicKeysAndThreshold.selector;
            s[13] = IWalletManager.getWalletAdminsAndThreshold.selector;
            cuts[12] = IDiamond.FacetCut(
                address(new WalletManagerFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 14: WalletBackupManagerFacet
        {
            bytes4[] memory s = new bytes4[](1);
            s[0] = IWalletBackupManager.backupRestore.selector;
            cuts[13] = IDiamond.FacetCut(
                address(new WalletBackupManagerFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 15: VrfFacet
        {
            bytes4[] memory s = new bytes4[](3);
            s[0] = IVrf.requestVrf.selector;
            s[1] = IVrf.setVrfAuthorizationAddress.selector;
            s[2] = IVrf.getVrfAuthorizationAddress.selector;
            cuts[14] = IDiamond.FacetCut(
                address(new VrfFacet()), IDiamond.FacetCutAction.Add, s
            );
        }
    }

    // =========================================================================
    // Later facet cuts (4 facets)
    // =========================================================================

    function _buildLaterFacetCuts() private returns (IDiamond.FacetCut[] memory cuts) {
        cuts = new IDiamond.FacetCut[](4);

        // 0: ReplicationFacet
        {
            bytes4[] memory s = new bytes4[](5);
            s[0] = IReplication.toPauseForUpgrade.selector;
            s[1] = IReplication.replicateFrom.selector;
            s[2] = IReplication.confirmReplicate.selector;
            s[3] = IReplication.getReplicatingTeeId.selector;
            s[4] = IIReplication.setPauseBeforeUpgradeMinDurationSeconds.selector;
            cuts[0] = IDiamond.FacetCut(
                address(new ReplicationFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 1: ExtensionGovernanceFacet
        {
            bytes4[] memory s = new bytes4[](14);
            s[0] = IExtensionGovernance.setNewTeeGovernance.selector;
            s[1] = IExtensionGovernance.getLatestTeeGovernanceHash.selector;
            s[2] = IExtensionGovernance.getTeeGovernanceThreshold.selector;
            s[3] = IExtensionGovernance.setTeePausingAddresses.selector;
            s[4] = IExtensionGovernance.signTeePausingAddresses.selector;
            s[5] = IExtensionGovernance.isTeeGovernanceSigner.selector;
            s[6] = IExtensionGovernance.getTeeGovernance.selector;
            s[7] = IExtensionGovernance.getLatestTeeGovernance.selector;
            s[8] = IExtensionGovernance.isGovernanceHashValid.selector;
            s[9] = IExtensionGovernance.getTeePausingAddresses.selector;
            s[10] = IExtensionGovernance.getLatestTeePausingAddresses.selector;
            s[11] = IExtensionGovernance.isTeePausingAddressesSigner.selector;
            s[12] = IExtensionGovernance.hasSignedTeePausingAddresses.selector;
            cuts[1] = IDiamond.FacetCut(
                address(new ExtensionGovernanceFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 2: UpgradeManagerFacet
        {
            bytes4[] memory s = new bytes4[](10);
            s[0] = IUpgradeManager.createNewTeeUpgrade.selector;
            s[1] = IUpgradeManager.addTeeUpgradePaths.selector;
            s[2] = IUpgradeManager.finalizeTeeUpgrade.selector;
            s[3] = IUpgradeManager.signTeeUpgrade.selector;
            s[4] = IUpgradeManager.isTeeUpgradeFinalized.selector;
            s[5] = IUpgradeManager.isTeeUpgradeSigned.selector;
            s[6] = IUpgradeManager.getTeeUpgradesCount.selector;
            s[7] = IUpgradeManager.getTeeUpgradePaths.selector;
            s[8] = IUpgradeManager.isTeeUpgradePathValid.selector;
            s[9] = IUpgradeManager.getTeeUpgradeSignatures.selector;
            cuts[2] = IDiamond.FacetCut(
                address(new UpgradeManagerFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 3: WalletResumeFacet
        {
            bytes4[] memory s = new bytes4[](2);
            s[0] = IWalletResume.setPausingAddresses.selector;
            s[1] = IWalletResume.resume.selector;
            cuts[3] = IDiamond.FacetCut(
                address(new WalletResumeFacet()), IDiamond.FacetCutAction.Add, s
            );
        }
    }
}
