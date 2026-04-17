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
import { IIExtensionManagerFacet } from "../../contracts/tee/interface/IIExtensionManagerFacet.sol";
import { IIInstructionsFacet } from "../../contracts/tee/interface/IIInstructionsFacet.sol";
import { IIVerificationFacet } from "../../contracts/tee/interface/IIVerificationFacet.sol";
import { IIOperationFeesFacet } from "../../contracts/tee/interface/IIOperationFeesFacet.sol";
import { IIReplicationFacet } from "../../contracts/tee/interface/IIReplicationFacet.sol";
import { IExtensionManagerFacet } from "../../contracts/userInterfaces/tee/IExtensionManagerFacet.sol";
import { IInstructionsFacet } from "../../contracts/userInterfaces/tee/IInstructionsFacet.sol";
import { IMachineManagerFacet } from "../../contracts/userInterfaces/tee/IMachineManagerFacet.sol";
import { IOwnerAllowlistFacet } from "../../contracts/userInterfaces/tee/IOwnerAllowlistFacet.sol";
import { IExtensionGovernanceFacet } from "../../contracts/userInterfaces/tee/IExtensionGovernanceFacet.sol";
import { IReplicationFacet } from "../../contracts/userInterfaces/tee/IReplicationFacet.sol";
import { IVerificationFacet } from "../../contracts/userInterfaces/tee/IVerificationFacet.sol";
import { ISystemStateVerifierFacet } from "../../contracts/userInterfaces/tee/ISystemStateVerifierFacet.sol";
import { IUpgradeManagerFacet } from "../../contracts/userInterfaces/tee/IUpgradeManagerFacet.sol";
import { IOperationFeesFacet } from "../../contracts/userInterfaces/tee/IOperationFeesFacet.sol";
import { IWalletProjectManagerFacet } from "../../contracts/userInterfaces/tee/IWalletProjectManagerFacet.sol";
import { IWalletKeyManagerFacet } from "../../contracts/userInterfaces/tee/IWalletKeyManagerFacet.sol";
import { IWalletManagerFacet } from "../../contracts/userInterfaces/tee/IWalletManagerFacet.sol";
import { IWalletResumeFacet } from "../../contracts/userInterfaces/tee/IWalletResumeFacet.sol";
import { IWalletBackupManagerFacet } from "../../contracts/userInterfaces/tee/IWalletBackupManagerFacet.sol";
import { IVrfFacet } from "../../contracts/userInterfaces/tee/IVrfFacet.sol";
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
            s[0] = IExtensionManagerFacet.register.selector;
            s[1] = IExtensionManagerFacet.addTeeVersion.selector;
            s[2] = IExtensionManagerFacet.getExtensionOwner.selector;
            s[3] = IExtensionManagerFacet.getTeeExtensionStateVerifier.selector;
            s[4] = IExtensionManagerFacet.getTeeExtensionInstructionsSender.selector;
            s[5] = IExtensionManagerFacet.isCodeHashPlatformSupported.selector;
            s[6] = IExtensionManagerFacet.getTeeGovernanceHash.selector;
            s[7] = IExtensionManagerFacet.getCodeHashInfo.selector;
            s[8] = IIExtensionManagerFacet.addSystemSupportedPlatforms.selector;
            s[9] = IIExtensionManagerFacet.addSystemSupportedKeyTypesAndSigningAlgos.selector;
            s[10] = IExtensionManagerFacet.addSupportedKeyTypes.selector;
            s[11] = IExtensionManagerFacet.extensionsCounter.selector;
            s[12] = IExtensionManagerFacet.isKeyTypeSupported.selector;
            s[13] = IExtensionManagerFacet.setExtensionContracts.selector;
            s[14] = IExtensionManagerFacet.disableCodeHashPlatform.selector;
            s[15] = IExtensionManagerFacet.removeSupportedKeyTypes.selector;
            s[16] = IExtensionManagerFacet.proposeNewOwner.selector;
            s[17] = IExtensionManagerFacet.confirmOwnership.selector;
            s[18] = IExtensionManagerFacet.getSystemSupportedPlatforms.selector;
            s[19] = IExtensionManagerFacet.getSystemSupportedKeyTypes.selector;
            s[20] = IExtensionManagerFacet.isSigningAlgoSupported.selector;
            s[21] = IExtensionManagerFacet.getSupportedCodeHashes.selector;
            s[22] = IExtensionManagerFacet.isCodeHashPlatformDisabled.selector;
            s[23] = IExtensionManagerFacet.getSystemSupportedSigningAlgos.selector;
            s[24] = IExtensionManagerFacet.getSupportedKeyTypes.selector;
            cuts[2] = IDiamond.FacetCut(
                address(new ExtensionManagerFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 3: InstructionsFacet
        {
            bytes4[] memory s = new bytes4[](6);
            s[0] = IInstructionsFacet.sendInstructions.selector;
            // sendSystemInstructions overloads
            s[1] = bytes4(keccak256(
                "sendSystemInstructions(bytes32,address[],"
                "(bytes32,bytes32,bytes,address[],uint64,address))"
            ));
            s[2] = bytes4(keccak256(
                "sendSystemInstructions(bytes32,(address,address,string)[],"
                "(bytes32,bytes32,bytes,address[],uint64,address))"
            ));
            s[3] = IIInstructionsFacet.registerSystemInstructionsSenders.selector;
            s[4] = IIInstructionsFacet.unregisterSystemInstructionsSenders.selector;
            s[5] = IInstructionsFacet.getSystemInstructionsSenders.selector;
            cuts[3] = IDiamond.FacetCut(
                address(new InstructionsFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 5: MachineManagerFacet
        {
            bytes4[] memory s = new bytes4[](20);
            s[0] = IMachineManagerFacet.register.selector;
            s[1] = IMachineManagerFacet.toProduction.selector;
            s[2] = IMachineManagerFacet.pause.selector;
            s[3] = IMachineManagerFacet.getTeeMachineStatus.selector;
            s[4] = IMachineManagerFacet.getExtensionId.selector;
            s[5] = IMachineManagerFacet.getTeeMachine.selector;
            s[6] = IMachineManagerFacet.getInitialSigningPolicyId.selector;
            s[7] = IMachineManagerFacet.pauseWithProof.selector;
            s[8] = IMachineManagerFacet.ban.selector;
            s[9] = IMachineManagerFacet.unban.selector;
            s[10] = IMachineManagerFacet.proposeNewOwner.selector;
            s[11] = IMachineManagerFacet.confirmOwnership.selector;
            s[12] = IMachineManagerFacet.updateTeeMachineSettings.selector;
            s[13] = IMachineManagerFacet.getTeeMachineOwner.selector;
            s[14] = IMachineManagerFacet.getTeeMachineWithAttestationData.selector;
            s[15] = IMachineManagerFacet.getRandomTeeIds.selector;
            s[16] = IMachineManagerFacet.getAllActiveTeeMachines.selector;
            s[17] = IMachineManagerFacet.getActiveTeeMachines.selector;
            s[18] = IMachineManagerFacet.getPublicKey.selector;
            s[19] = IMachineManagerFacet.getLastStatusChangeTs.selector;
            cuts[4] = IDiamond.FacetCut(
                address(new MachineManagerFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 6: VerificationFacet (includes wallet verification)
        {
            bytes4[] memory s = new bytes4[](11);
            s[0] = IVerificationFacet.requestTeeAttestation.selector;
            s[1] = IIVerificationFacet.setCosigners.selector;
            s[2] = IVerificationFacet.requestAvailabilityCheckAttestation.selector;
            s[3] = IVerificationFacet.confirmAvailability.selector;
            s[4] = IVerificationFacet.verifyAvailabilityCheckProof.selector;
            s[5] = IIVerificationFacet.updateSettings.selector;
            s[6] = IVerificationFacet.getCosigners.selector;
            s[7] = IVerificationFacet.getSettings.selector;
            s[8] = IVerificationFacet.getAvailabilityCheckValidity.selector;
            s[9] = IVerificationFacet.requestPMWMultisigAccountConfiguredAttestation.selector;
            s[10] = IVerificationFacet.verifyPMWMultisigAccountConfiguredProof.selector;
            cuts[5] = IDiamond.FacetCut(
                address(new VerificationFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 7: OperationFeesFacet
        {
            bytes4[] memory s = new bytes4[](5);
            s[0] = IIOperationFeesFacet.setOperationFees.selector;
            s[1] = IIOperationFeesFacet.setDefaultFee.selector;
            s[2] = IOperationFeesFacet.getDefaultFee.selector;
            s[3] = IOperationFeesFacet.getOperationFee.selector;
            s[4] = IOperationFeesFacet.calculateFeeByTeeIds.selector;
            cuts[6] = IDiamond.FacetCut(
                address(new OperationFeesFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 8: OwnerAllowlistFacet
        {
            bytes4[] memory s = new bytes4[](14);
            s[0] = IOwnerAllowlistFacet.addAllowedTeeMachineOwners.selector;
            s[1] = IOwnerAllowlistFacet.isAllowedTeeMachineOwner.selector;
            s[2] = IOwnerAllowlistFacet.getAllowedTeeMachineOwners.selector;
            s[3] = IOwnerAllowlistFacet.addAllowedTeeWalletProjectOwners.selector;
            s[4] = IOwnerAllowlistFacet.isAllowedTeeWalletProjectOwner.selector;
            s[5] = IOwnerAllowlistFacet.removeAllowedTeeMachineOwners.selector;
            s[6] = IOwnerAllowlistFacet.removeAllowedTeeWalletProjectOwners.selector;
            s[7] = IOwnerAllowlistFacet.allowAllTeeMachineOwners.selector;
            s[8] = IOwnerAllowlistFacet.disallowAllTeeMachineOwners.selector;
            s[9] = IOwnerAllowlistFacet.allowAllTeeWalletProjectOwners.selector;
            s[10] = IOwnerAllowlistFacet.disallowAllTeeWalletProjectOwners.selector;
            s[11] = IOwnerAllowlistFacet.getAllowedTeeWalletProjectOwners.selector;
            s[12] = IOwnerAllowlistFacet.allTeeMachineOwnersAllowed.selector;
            s[13] = IOwnerAllowlistFacet.allTeeWalletProjectOwnersAllowed.selector;
            cuts[7] = IDiamond.FacetCut(
                address(new OwnerAllowlistFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 9: SystemStateVerifierFacet
        {
            bytes4[] memory s = new bytes4[](1);
            s[0] = ISystemStateVerifierFacet.verifyTeeSystemState.selector;
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
            s[0] = IWalletProjectManagerFacet.createProject.selector;
            s[1] = IWalletProjectManagerFacet.getOwner.selector;
            s[2] = IWalletProjectManagerFacet.getExtensionId.selector;
            s[3] = IWalletProjectManagerFacet.getKeyType.selector;
            s[4] = IWalletProjectManagerFacet.setBackupManager.selector;
            s[5] = IWalletProjectManagerFacet.proposeNewOwner.selector;
            s[6] = IWalletProjectManagerFacet.confirmOwnership.selector;
            s[7] = IWalletProjectManagerFacet.getSigningAlgo.selector;
            s[8] = IWalletProjectManagerFacet.getBackupManager.selector;
            cuts[10] = IDiamond.FacetCut(
                address(new WalletProjectManagerFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 12: WalletKeyManagerFacet
        {
            bytes4[] memory s = new bytes4[](9);
            s[0] = IWalletKeyManagerFacet.addKey.selector;
            s[1] = IWalletKeyManagerFacet.confirmKey.selector;
            s[2] = IWalletKeyManagerFacet.setMultisigThreshold.selector;
            s[3] = IWalletKeyManagerFacet.receivingTeesAndKeys.selector;
            s[4] = IWalletKeyManagerFacet.getWalletKeysInfo.selector;
            s[5] = IWalletKeyManagerFacet.deleteKey.selector;
            s[6] = IWalletKeyManagerFacet.cleanUpTeeIds.selector;
            s[7] = IWalletKeyManagerFacet.getWalletKeyPublicKey.selector;
            s[8] = IWalletKeyManagerFacet.getWalletKeyTeeIds.selector;
            cuts[11] = IDiamond.FacetCut(
                address(new WalletKeyManagerFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 13: WalletManagerFacet
        {
            bytes4[] memory s = new bytes4[](14);
            s[0] = IWalletManagerFacet.createWallet.selector;
            s[1] = IWalletManagerFacet.setAdmins.selector;
            s[2] = IWalletManagerFacet.confirmAdmin.selector;
            s[3] = IWalletManagerFacet.setCosigners.selector;
            s[4] = IWalletManagerFacet.confirmCosigner.selector;
            s[5] = IWalletManagerFacet.closeWalletInitialization.selector;
            s[6] = IWalletManagerFacet.enableWallet.selector;
            s[7] = IWalletManagerFacet.getWalletProjectId.selector;
            s[8] = IWalletManagerFacet.getWalletCosignersAndThreshold.selector;
            s[9] = IWalletManagerFacet.getWalletStatus.selector;
            s[10] = IWalletManagerFacet.pauseWallet.selector;
            s[11] = IWalletManagerFacet.getProjectWalletIds.selector;
            s[12] = IWalletManagerFacet.getWalletAdminsPublicKeysAndThreshold.selector;
            s[13] = IWalletManagerFacet.getWalletAdminsAndThreshold.selector;
            cuts[12] = IDiamond.FacetCut(
                address(new WalletManagerFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 14: WalletBackupManagerFacet
        {
            bytes4[] memory s = new bytes4[](1);
            s[0] = IWalletBackupManagerFacet.backupRestore.selector;
            cuts[13] = IDiamond.FacetCut(
                address(new WalletBackupManagerFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 15: VrfFacet
        {
            bytes4[] memory s = new bytes4[](3);
            s[0] = IVrfFacet.requestVrf.selector;
            s[1] = IVrfFacet.setVrfAuthorizationAddress.selector;
            s[2] = IVrfFacet.getVrfAuthorizationAddress.selector;
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
            s[0] = IReplicationFacet.toPauseForUpgrade.selector;
            s[1] = IReplicationFacet.replicateFrom.selector;
            s[2] = IReplicationFacet.confirmReplicate.selector;
            s[3] = IReplicationFacet.getReplicatingTeeId.selector;
            s[4] = IIReplicationFacet.setPauseBeforeUpgradeMinDurationSeconds.selector;
            cuts[0] = IDiamond.FacetCut(
                address(new ReplicationFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 1: ExtensionGovernanceFacet
        {
            bytes4[] memory s = new bytes4[](14);
            s[0] = IExtensionGovernanceFacet.setNewTeeGovernance.selector;
            s[1] = IExtensionGovernanceFacet.getLatestTeeGovernanceHash.selector;
            s[2] = IExtensionGovernanceFacet.getTeeGovernanceThreshold.selector;
            s[3] = IExtensionGovernanceFacet.setTeePausingAddresses.selector;
            s[4] = IExtensionGovernanceFacet.signTeePausingAddresses.selector;
            s[5] = IExtensionGovernanceFacet.isTeeGovernanceSigner.selector;
            s[6] = IExtensionGovernanceFacet.getTeeGovernance.selector;
            s[7] = IExtensionGovernanceFacet.getLatestTeeGovernance.selector;
            s[8] = IExtensionGovernanceFacet.isGovernanceHashValid.selector;
            s[9] = IExtensionGovernanceFacet.getTeePausingAddresses.selector;
            s[10] = IExtensionGovernanceFacet.getLatestTeePausingAddresses.selector;
            s[11] = IExtensionGovernanceFacet.isTeePausingAddressesSigner.selector;
            s[12] = IExtensionGovernanceFacet.hasSignedTeePausingAddresses.selector;
            cuts[1] = IDiamond.FacetCut(
                address(new ExtensionGovernanceFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 2: UpgradeManagerFacet
        {
            bytes4[] memory s = new bytes4[](10);
            s[0] = IUpgradeManagerFacet.createNewTeeUpgrade.selector;
            s[1] = IUpgradeManagerFacet.addTeeUpgradePaths.selector;
            s[2] = IUpgradeManagerFacet.finalizeTeeUpgrade.selector;
            s[3] = IUpgradeManagerFacet.signTeeUpgrade.selector;
            s[4] = IUpgradeManagerFacet.isTeeUpgradeFinalized.selector;
            s[5] = IUpgradeManagerFacet.isTeeUpgradeSigned.selector;
            s[6] = IUpgradeManagerFacet.getTeeUpgradesCount.selector;
            s[7] = IUpgradeManagerFacet.getTeeUpgradePaths.selector;
            s[8] = IUpgradeManagerFacet.isTeeUpgradePathValid.selector;
            s[9] = IUpgradeManagerFacet.getTeeUpgradeSignatures.selector;
            cuts[2] = IDiamond.FacetCut(
                address(new UpgradeManagerFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 3: WalletResumeFacet
        {
            bytes4[] memory s = new bytes4[](2);
            s[0] = IWalletResumeFacet.setPausingAddresses.selector;
            s[1] = IWalletResumeFacet.resume.selector;
            cuts[3] = IDiamond.FacetCut(
                address(new WalletResumeFacet()), IDiamond.FacetCutAction.Add, s
            );
        }
    }
}
