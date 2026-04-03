// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

// Diamond infrastructure
import { FlareTeeManager } from "../../contracts/tee/diamond/FlareTeeManager.sol";
import { IDiamond } from "../../contracts/diamond/interfaces/IDiamond.sol";
import { IDiamondCut } from "../../contracts/diamond/interfaces/IDiamondCut.sol";
import { DiamondLoupeFacet } from "../../contracts/diamond/facets/DiamondLoupeFacet.sol";

// TEE facets
import { FlareTeeManagerDiamondCutFacet } from "../../contracts/tee/facets/FlareTeeManagerDiamondCutFacet.sol";
import { TeeExtensionRegistryFacet } from "../../contracts/tee/facets/TeeExtensionRegistryFacet.sol";
import { TeeMachineRegistryFacet } from "../../contracts/tee/facets/TeeMachineRegistryFacet.sol";
import { TeeVerificationFacet } from "../../contracts/tee/facets/TeeVerificationFacet.sol";
import { TeeFeeCalculatorFacet } from "../../contracts/tee/facets/TeeFeeCalculatorFacet.sol";
import { TeeOwnerAllowlistFacet } from "../../contracts/tee/facets/TeeOwnerAllowlistFacet.sol";
import { TeeSystemStateVerifierFacet } from "../../contracts/tee/facets/TeeSystemStateVerifierFacet.sol";
import { TeeAddressUpdatableFacet } from "../../contracts/tee/facets/TeeAddressUpdatableFacet.sol";
import { TeeReplicationFacet } from "../../contracts/tee/facets/TeeReplicationFacet.sol";
import { TeeGovernanceFacet } from "../../contracts/tee/facets/TeeGovernanceFacet.sol";
import { TeeVersionManagerFacet } from "../../contracts/tee/facets/TeeVersionManagerFacet.sol";
import { TeeWalletProjectManagerFacet } from "../../contracts/tee/facets/TeeWalletProjectManagerFacet.sol";
import { TeeWalletKeyManagerFacet } from "../../contracts/tee/facets/TeeWalletKeyManagerFacet.sol";
import { TeeWalletManagerFacet } from "../../contracts/tee/facets/TeeWalletManagerFacet.sol";
import { TeeWalletBackupManagerFacet } from "../../contracts/tee/facets/TeeWalletBackupManagerFacet.sol";
import { TeeWalletVerificationFacet } from "../../contracts/tee/facets/TeeWalletVerificationFacet.sol";
import { TeeVrfFacet } from "../../contracts/tee/facets/TeeVrfFacet.sol";

// TEE interfaces (for selector references)
import { IITeeExtensionRegistryFacet } from "../../contracts/tee/interface/IITeeExtensionRegistryFacet.sol";
import { IITeeVerificationFacet } from "../../contracts/tee/interface/IITeeVerificationFacet.sol";
import { IITeeFeeCalculatorFacet } from "../../contracts/tee/interface/IITeeFeeCalculatorFacet.sol";
import { IITeeReplicationFacet } from "../../contracts/tee/interface/IITeeReplicationFacet.sol";
import { ITeeExtensionRegistryFacet } from "../../contracts/userInterfaces/tee/ITeeExtensionRegistryFacet.sol";
import { ITeeMachineRegistryFacet } from "../../contracts/userInterfaces/tee/ITeeMachineRegistryFacet.sol";
import { ITeeOwnerAllowlistFacet } from "../../contracts/userInterfaces/tee/ITeeOwnerAllowlistFacet.sol";
import { ITeeGovernanceFacet } from "../../contracts/userInterfaces/tee/ITeeGovernanceFacet.sol";
import { ITeeReplicationFacet } from "../../contracts/userInterfaces/tee/ITeeReplicationFacet.sol";
import { ITeeVerificationFacet } from "../../contracts/userInterfaces/tee/ITeeVerificationFacet.sol";
import { ITeeSystemStateVerifierFacet } from "../../contracts/userInterfaces/tee/ITeeSystemStateVerifierFacet.sol";
import { ITeeVersionManagerFacet } from "../../contracts/userInterfaces/tee/ITeeVersionManagerFacet.sol";
import { ITeeFeeCalculatorFacet } from "../../contracts/userInterfaces/tee/ITeeFeeCalculatorFacet.sol";
import { ITeeWalletProjectManagerFacet } from "../../contracts/userInterfaces/tee/ITeeWalletProjectManagerFacet.sol";
import { ITeeWalletKeyManagerFacet } from "../../contracts/userInterfaces/tee/ITeeWalletKeyManagerFacet.sol";
import { ITeeWalletManagerFacet } from "../../contracts/userInterfaces/tee/ITeeWalletManagerFacet.sol";
import { ITeeWalletBackupManagerFacet } from "../../contracts/userInterfaces/tee/ITeeWalletBackupManagerFacet.sol";
import { ITeeWalletVerificationFacet } from "../../contracts/userInterfaces/tee/ITeeWalletVerificationFacet.sol";
import { ITeeVrfFacet } from "../../contracts/userInterfaces/tee/ITeeVrfFacet.sol";
import { IIFlareTeeManager } from "../../contracts/tee/interface/IIFlareTeeManager.sol";

import { IFlareGovernance } from "../../contracts/userInterfaces/tee/IFlareGovernance.sol";
import { FlareGovernance } from "../../contracts/tee/library/FlareGovernance.sol";
import { AddressUpdatable } from "../../contracts/utils/implementation/AddressUpdatable.sol";
import { TeeVerification } from "../../contracts/tee/library/TeeVerification.sol";
import { TeeFeeCalculator } from "../../contracts/tee/library/TeeFeeCalculator.sol";
import { TeeExtensionRegistry } from "../../contracts/tee/library/TeeExtensionRegistry.sol";
import { TeeReplication } from "../../contracts/tee/library/TeeReplication.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import { ITeeVerificationFacet } from "../../contracts/userInterfaces/tee/ITeeVerificationFacet.sol";

/**
 * @title FlareTeeManagerCombinedInit
 * @notice Combined init for FlareTeeManager Diamond that initializes both the core
 *         and replication settings in a single delegatecall from the constructor.
 */
contract FlareTeeManagerCombinedInit is AddressUpdatable {

    constructor() AddressUpdatable(address(1)) {
        FlareGovernance.initialise(IGovernanceSettings(address(0x1111)), address(0x1111));
    }

    function init(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        uint64 _availabilityCheckValidityDurationSeconds,
        uint64 _signingPolicyValidityDurationInRewardEpochs,
        uint64 _challengeValidityDurationSeconds,
        uint256 _defaultFee,
        uint256 _pauseBeforeUpgradeMinDurationSeconds
    )
        external
    {
        // Core FlareTeeManager init
        FlareGovernance.initialise(_governanceSettings, _initialGovernance);
        setAddressUpdaterValue(_addressUpdater);

        TeeVerification.validateDuration(_availabilityCheckValidityDurationSeconds, 1 hours, 365 days);
        TeeVerification.validateDuration(_signingPolicyValidityDurationInRewardEpochs, 1, 100);
        TeeVerification.validateDuration(_challengeValidityDurationSeconds, 1 minutes, 1 days);

        TeeVerification.State storage verState = TeeVerification.getState();
        verState.availabilityCheckValidityDurationSeconds = _availabilityCheckValidityDurationSeconds;
        verState.signingPolicyValidityDurationInRewardEpochs = _signingPolicyValidityDurationInRewardEpochs;
        verState.challengeValidityDurationSeconds = _challengeValidityDurationSeconds;

        emit ITeeVerificationFacet.SettingsUpdated(
            _availabilityCheckValidityDurationSeconds,
            uint24(_signingPolicyValidityDurationInRewardEpochs),
            _challengeValidityDurationSeconds
        );

        TeeFeeCalculator.getState().defaultFee = _defaultFee;
        TeeExtensionRegistry.getState().extensionsCounter = 1;

        // Replication init
        TeeReplication.setPauseBeforeUpgradeMinDurationSeconds(_pauseBeforeUpgradeMinDurationSeconds);
    }

    function _updateContractAddresses(bytes32[] memory, address[] memory) internal pure override {
        // intentionally empty
    }
}

/**
 * @title FlareTeeManagerDeployer
 * @notice Shared test utility for deploying the FlareTeeManager Diamond with all facets.
 *         Can be used by any forge test that needs a fully-deployed FlareTeeManager.
 */
library FlareTeeManagerDeployer {

    struct DeployParams {
        IGovernanceSettings governanceSettings;
        address initialGovernance;
        address addressUpdater;
        uint64 availabilityCheckValidityDurationSeconds;
        uint64 signingPolicyValidityDurationInRewardEpochs;
        uint64 challengeValidityDurationSeconds;
        uint256 defaultFee;
        uint256 pauseBeforeUpgradeMinDurationSeconds;
    }

    function deploy(DeployParams memory _params) internal returns (IIFlareTeeManager) {
        IDiamond.FacetCut[] memory cuts = _buildFacetCuts();

        FlareTeeManagerCombinedInit combinedInit = new FlareTeeManagerCombinedInit();
        bytes memory initCalldata = abi.encodeCall(
            FlareTeeManagerCombinedInit.init,
            (
                _params.governanceSettings,
                _params.initialGovernance,
                _params.addressUpdater,
                _params.availabilityCheckValidityDurationSeconds,
                _params.signingPolicyValidityDurationInRewardEpochs,
                _params.challengeValidityDurationSeconds,
                _params.defaultFee,
                _params.pauseBeforeUpgradeMinDurationSeconds
            )
        );

        FlareTeeManager flareTeeManagerDiamond = new FlareTeeManager(
            cuts,
            FlareTeeManager.DiamondArgs({
                init: address(combinedInit),
                initCalldata: initCalldata
            })
        );

        return IIFlareTeeManager(address(flareTeeManagerDiamond));
    }

    function _buildFacetCuts() private returns (IDiamond.FacetCut[] memory cuts) {
        cuts = new IDiamond.FacetCut[](18);

        // 0: FlareTeeManagerDiamondCutFacet (diamondCut + FlareGovernance selectors)
        {
            bytes4[] memory s = new bytes4[](8);
            s[0] = IDiamondCut.diamondCut.selector;
            s[1] = IFlareGovernance.executeGovernanceCall.selector;
            s[2] = IFlareGovernance.cancelGovernanceCall.selector;
            s[3] = IFlareGovernance.switchToProductionMode.selector;
            s[4] = IFlareGovernance.governance.selector;
            s[5] = IFlareGovernance.governanceSettings.selector;
            s[6] = IFlareGovernance.productionMode.selector;
            s[7] = IFlareGovernance.isExecutor.selector;
            cuts[0] = IDiamond.FacetCut(
                address(new FlareTeeManagerDiamondCutFacet()), IDiamond.FacetCutAction.Add, s
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

        // 2: TeeExtensionRegistryFacet
        {
            bytes4[] memory s = new bytes4[](31);
            s[0] = ITeeExtensionRegistryFacet.register.selector;
            s[1] = ITeeExtensionRegistryFacet.addTeeVersion.selector;
            s[2] = ITeeExtensionRegistryFacet.getExtensionOwner.selector;
            s[3] = ITeeExtensionRegistryFacet.getTeeExtensionStateVerifier.selector;
            s[4] = ITeeExtensionRegistryFacet.getTeeExtensionInstructionsSender.selector;
            s[5] = ITeeExtensionRegistryFacet.isCodeHashPlatformSupported.selector;
            s[6] = ITeeExtensionRegistryFacet.getTeeGovernanceHash.selector;
            s[7] = ITeeExtensionRegistryFacet.getCodeHashInfo.selector;
            s[8] = IITeeExtensionRegistryFacet.registerSystemInstructionsSenders.selector;
            s[9] = IITeeExtensionRegistryFacet.addSystemSupportedPlatforms.selector;
            s[10] = IITeeExtensionRegistryFacet.addSystemSupportedKeyTypesAndSigningAlgos.selector;
            s[11] = ITeeExtensionRegistryFacet.addSupportedKeyTypes.selector;
            s[12] = ITeeExtensionRegistryFacet.sendInstructions.selector;
            s[13] = ITeeExtensionRegistryFacet.extensionsCounter.selector;
            s[14] = ITeeExtensionRegistryFacet.isKeyTypeSupported.selector;
            // sendSystemInstructions overloads
            s[15] = bytes4(keccak256(
                "sendSystemInstructions(bytes32,address[],"
                "(bytes32,bytes32,bytes,address[],uint64,address))"
            ));
            s[16] = bytes4(keccak256(
                "sendSystemInstructions(bytes32,(address,address,string)[],"
                "(bytes32,bytes32,bytes,address[],uint64,address))"
            ));
            s[17] = ITeeExtensionRegistryFacet.setExtensionContracts.selector;
            s[18] = ITeeExtensionRegistryFacet.disableCodeHashPlatform.selector;
            s[19] = ITeeExtensionRegistryFacet.removeSupportedKeyTypes.selector;
            s[20] = ITeeExtensionRegistryFacet.proposeNewOwner.selector;
            s[21] = ITeeExtensionRegistryFacet.confirmOwnership.selector;
            s[22] = IITeeExtensionRegistryFacet.unregisterSystemInstructionsSenders.selector;
            s[23] = ITeeExtensionRegistryFacet.getSystemSupportedPlatforms.selector;
            s[24] = ITeeExtensionRegistryFacet.getSystemSupportedKeyTypes.selector;
            s[25] = ITeeExtensionRegistryFacet.getSystemInstructionsSenders.selector;
            s[26] = ITeeExtensionRegistryFacet.isSigningAlgoSupported.selector;
            s[27] = ITeeExtensionRegistryFacet.getSupportedCodeHashes.selector;
            s[28] = ITeeExtensionRegistryFacet.isCodeHashPlatformDisabled.selector;
            s[29] = ITeeExtensionRegistryFacet.getSystemSupportedSigningAlgos.selector;
            s[30] = ITeeExtensionRegistryFacet.getSupportedKeyTypes.selector;
            cuts[2] = IDiamond.FacetCut(
                address(new TeeExtensionRegistryFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 3: TeeMachineRegistryFacet
        {
            bytes4[] memory s = new bytes4[](20);
            s[0] = ITeeMachineRegistryFacet.register.selector;
            s[1] = ITeeMachineRegistryFacet.toProduction.selector;
            s[2] = ITeeMachineRegistryFacet.pause.selector;
            s[3] = ITeeMachineRegistryFacet.getTeeMachineStatus.selector;
            s[4] = ITeeMachineRegistryFacet.getExtensionId.selector;
            s[5] = ITeeMachineRegistryFacet.getTeeMachine.selector;
            s[6] = ITeeMachineRegistryFacet.getInitialSigningPolicyId.selector;
            s[7] = ITeeMachineRegistryFacet.pauseWithProof.selector;
            s[8] = ITeeMachineRegistryFacet.ban.selector;
            s[9] = ITeeMachineRegistryFacet.unban.selector;
            s[10] = ITeeMachineRegistryFacet.proposeNewOwner.selector;
            s[11] = ITeeMachineRegistryFacet.confirmOwnership.selector;
            s[12] = ITeeMachineRegistryFacet.updateTeeMachineSettings.selector;
            s[13] = ITeeMachineRegistryFacet.getTeeMachineOwner.selector;
            s[14] = ITeeMachineRegistryFacet.getTeeMachineWithAttestationData.selector;
            s[15] = ITeeMachineRegistryFacet.getRandomTeeIds.selector;
            s[16] = ITeeMachineRegistryFacet.getAllActiveTeeMachines.selector;
            s[17] = ITeeMachineRegistryFacet.getActiveTeeMachines.selector;
            s[18] = ITeeMachineRegistryFacet.getPublicKey.selector;
            s[19] = ITeeMachineRegistryFacet.getLastStatusChangeTs.selector;
            cuts[3] = IDiamond.FacetCut(
                address(new TeeMachineRegistryFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 4: TeeVerificationFacet
        {
            bytes4[] memory s = new bytes4[](9);
            s[0] = ITeeVerificationFacet.requestTeeAttestation.selector;
            s[1] = IITeeVerificationFacet.setCosigners.selector;
            s[2] = ITeeVerificationFacet.requestAvailabilityCheckAttestation.selector;
            s[3] = ITeeVerificationFacet.confirmAvailability.selector;
            s[4] = ITeeVerificationFacet.verifyAvailabilityCheckProof.selector;
            s[5] = IITeeVerificationFacet.updateSettings.selector;
            s[6] = ITeeVerificationFacet.getCosigners.selector;
            s[7] = ITeeVerificationFacet.getSettings.selector;
            s[8] = ITeeVerificationFacet.getAvailabilityCheckValidity.selector;
            cuts[4] = IDiamond.FacetCut(
                address(new TeeVerificationFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 5: TeeFeeCalculatorFacet
        {
            bytes4[] memory s = new bytes4[](5);
            s[0] = IITeeFeeCalculatorFacet.setOperationFees.selector;
            s[1] = IITeeFeeCalculatorFacet.setDefaultFee.selector;
            s[2] = ITeeFeeCalculatorFacet.getDefaultFee.selector;
            s[3] = ITeeFeeCalculatorFacet.getOperationFee.selector;
            s[4] = ITeeFeeCalculatorFacet.calculateFeeByTeeIds.selector;
            cuts[5] = IDiamond.FacetCut(
                address(new TeeFeeCalculatorFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 6: TeeOwnerAllowlistFacet
        {
            bytes4[] memory s = new bytes4[](14);
            s[0] = ITeeOwnerAllowlistFacet.addAllowedTeeMachineOwners.selector;
            s[1] = ITeeOwnerAllowlistFacet.isAllowedTeeMachineOwner.selector;
            s[2] = ITeeOwnerAllowlistFacet.getAllowedTeeMachineOwners.selector;
            s[3] = ITeeOwnerAllowlistFacet.addAllowedTeeWalletProjectOwners.selector;
            s[4] = ITeeOwnerAllowlistFacet.isAllowedTeeWalletProjectOwner.selector;
            s[5] = ITeeOwnerAllowlistFacet.removeAllowedTeeMachineOwners.selector;
            s[6] = ITeeOwnerAllowlistFacet.removeAllowedTeeWalletProjectOwners.selector;
            s[7] = ITeeOwnerAllowlistFacet.allowAllTeeMachineOwners.selector;
            s[8] = ITeeOwnerAllowlistFacet.disallowAllTeeMachineOwners.selector;
            s[9] = ITeeOwnerAllowlistFacet.allowAllTeeWalletProjectOwners.selector;
            s[10] = ITeeOwnerAllowlistFacet.disallowAllTeeWalletProjectOwners.selector;
            s[11] = ITeeOwnerAllowlistFacet.getAllowedTeeWalletProjectOwners.selector;
            s[12] = ITeeOwnerAllowlistFacet.allTeeMachineOwnersAllowed.selector;
            s[13] = ITeeOwnerAllowlistFacet.allTeeWalletProjectOwnersAllowed.selector;
            cuts[6] = IDiamond.FacetCut(
                address(new TeeOwnerAllowlistFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 7: TeeSystemStateVerifierFacet
        {
            bytes4[] memory s = new bytes4[](1);
            s[0] = ITeeSystemStateVerifierFacet.verifyTeeSystemState.selector;
            cuts[7] = IDiamond.FacetCut(
                address(new TeeSystemStateVerifierFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 8: TeeAddressUpdatableFacet
        {
            bytes4[] memory s = new bytes4[](2);
            s[0] = bytes4(keccak256("updateContractAddresses(bytes32[],address[])"));
            s[1] = bytes4(keccak256("getAddressUpdater()"));
            cuts[8] = IDiamond.FacetCut(
                address(new TeeAddressUpdatableFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 9: TeeReplicationFacet
        {
            bytes4[] memory s = new bytes4[](5);
            s[0] = ITeeReplicationFacet.toPauseForUpgrade.selector;
            s[1] = ITeeReplicationFacet.replicateFrom.selector;
            s[2] = ITeeReplicationFacet.confirmReplicate.selector;
            s[3] = ITeeReplicationFacet.getReplicatingTeeId.selector;
            s[4] = IITeeReplicationFacet.setPauseBeforeUpgradeMinDurationSeconds.selector;
            cuts[9] = IDiamond.FacetCut(
                address(new TeeReplicationFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 10: TeeGovernanceFacet
        {
            bytes4[] memory s = new bytes4[](14);
            s[0] = ITeeGovernanceFacet.setNewTeeGovernance.selector;
            s[1] = ITeeGovernanceFacet.getLatestTeeGovernanceHash.selector;
            s[2] = ITeeGovernanceFacet.getTeeGovernanceThreshold.selector;
            s[3] = ITeeGovernanceFacet.setTeePausingAddresses.selector;
            s[4] = ITeeGovernanceFacet.signTeePausingAddresses.selector;
            s[5] = ITeeGovernanceFacet.isTeeGovernanceSigner.selector;
            s[6] = ITeeGovernanceFacet.getTeeGovernance.selector;
            s[7] = ITeeGovernanceFacet.getLatestTeeGovernance.selector;
            s[8] = ITeeGovernanceFacet.isGovernanceHashValid.selector;
            s[9] = ITeeGovernanceFacet.getTeePausingAddresses.selector;
            s[10] = ITeeGovernanceFacet.getLatestTeePausingAddresses.selector;
            s[11] = ITeeGovernanceFacet.isTeePausingAddressesSigner.selector;
            s[12] = ITeeGovernanceFacet.hasSignedTeePausingAddresses.selector;
            // getSystemSupportedSigningAlgos is on TeeExtensionRegistryFacet, not here
            cuts[10] = IDiamond.FacetCut(
                address(new TeeGovernanceFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 11: TeeVersionManagerFacet
        {
            bytes4[] memory s = new bytes4[](10);
            s[0] = ITeeVersionManagerFacet.createNewTeeUpgrade.selector;
            s[1] = ITeeVersionManagerFacet.addTeeUpgradePaths.selector;
            s[2] = ITeeVersionManagerFacet.finalizeTeeUpgrade.selector;
            s[3] = ITeeVersionManagerFacet.signTeeUpgrade.selector;
            s[4] = ITeeVersionManagerFacet.isTeeUpgradeFinalized.selector;
            s[5] = ITeeVersionManagerFacet.isTeeUpgradeSigned.selector;
            s[6] = ITeeVersionManagerFacet.getTeeUpgradesCount.selector;
            s[7] = ITeeVersionManagerFacet.getTeeUpgradePaths.selector;
            s[8] = ITeeVersionManagerFacet.isTeeUpgradePathValid.selector;
            s[9] = ITeeVersionManagerFacet.getTeeUpgradeSignatures.selector;
            cuts[11] = IDiamond.FacetCut(
                address(new TeeVersionManagerFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 12: TeeWalletProjectManagerFacet
        {
            bytes4[] memory s = new bytes4[](9);
            s[0] = ITeeWalletProjectManagerFacet.createProject.selector;
            s[1] = ITeeWalletProjectManagerFacet.getOwner.selector;
            s[2] = ITeeWalletProjectManagerFacet.getExtensionId.selector;
            s[3] = ITeeWalletProjectManagerFacet.getKeyType.selector;
            s[4] = ITeeWalletProjectManagerFacet.setBackupManager.selector;
            s[5] = ITeeWalletProjectManagerFacet.proposeNewOwner.selector;
            s[6] = ITeeWalletProjectManagerFacet.confirmOwnership.selector;
            s[7] = ITeeWalletProjectManagerFacet.getSigningAlgo.selector;
            s[8] = ITeeWalletProjectManagerFacet.getBackupManager.selector;
            cuts[12] = IDiamond.FacetCut(
                address(new TeeWalletProjectManagerFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 13: TeeWalletKeyManagerFacet
        {
            bytes4[] memory s = new bytes4[](9);
            s[0] = ITeeWalletKeyManagerFacet.addKey.selector;
            s[1] = ITeeWalletKeyManagerFacet.confirmKey.selector;
            s[2] = ITeeWalletKeyManagerFacet.setMultisigThreshold.selector;
            s[3] = ITeeWalletKeyManagerFacet.receivingTeesAndKeys.selector;
            s[4] = ITeeWalletKeyManagerFacet.getWalletKeysInfo.selector;
            s[5] = ITeeWalletKeyManagerFacet.deleteKey.selector;
            s[6] = ITeeWalletKeyManagerFacet.cleanUpTeeIds.selector;
            s[7] = ITeeWalletKeyManagerFacet.getWalletKeyPublicKey.selector;
            s[8] = ITeeWalletKeyManagerFacet.getWalletKeyTeeIds.selector;
            cuts[13] = IDiamond.FacetCut(
                address(new TeeWalletKeyManagerFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 14: TeeWalletManagerFacet
        {
            bytes4[] memory s = new bytes4[](16);
            s[0] = ITeeWalletManagerFacet.createWallet.selector;
            s[1] = ITeeWalletManagerFacet.setAdmins.selector;
            s[2] = ITeeWalletManagerFacet.confirmAdmin.selector;
            s[3] = ITeeWalletManagerFacet.setCosigners.selector;
            s[4] = ITeeWalletManagerFacet.confirmCosigner.selector;
            s[5] = ITeeWalletManagerFacet.closeWalletInitialization.selector;
            s[6] = ITeeWalletManagerFacet.enableWallet.selector;
            s[7] = ITeeWalletManagerFacet.getWalletProjectId.selector;
            s[8] = ITeeWalletManagerFacet.getWalletCosignersAndThreshold.selector;
            s[9] = ITeeWalletManagerFacet.getWalletStatus.selector;
            s[10] = ITeeWalletManagerFacet.pauseWallet.selector;
            s[11] = ITeeWalletManagerFacet.setPausingAddresses.selector;
            s[12] = ITeeWalletManagerFacet.resume.selector;
            s[13] = ITeeWalletManagerFacet.getProjectWalletIds.selector;
            s[14] = ITeeWalletManagerFacet.getWalletAdminsPublicKeysAndThreshold.selector;
            s[15] = ITeeWalletManagerFacet.getWalletAdminsAndThreshold.selector;
            cuts[14] = IDiamond.FacetCut(
                address(new TeeWalletManagerFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 15: TeeWalletBackupManagerFacet
        {
            bytes4[] memory s = new bytes4[](1);
            s[0] = ITeeWalletBackupManagerFacet.backupRestore.selector;
            cuts[15] = IDiamond.FacetCut(
                address(new TeeWalletBackupManagerFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 16: TeeWalletVerificationFacet
        {
            bytes4[] memory s = new bytes4[](2);
            s[0] = ITeeWalletVerificationFacet.verifyPMWMultisigAccountConfiguredProof.selector;
            s[1] = ITeeWalletVerificationFacet.requestPMWMultisigAccountConfiguredAttestation.selector;
            cuts[16] = IDiamond.FacetCut(
                address(new TeeWalletVerificationFacet()), IDiamond.FacetCutAction.Add, s
            );
        }

        // 17: TeeVrfFacet
        {
            bytes4[] memory s = new bytes4[](3);
            s[0] = ITeeVrfFacet.requestVrf.selector;
            s[1] = ITeeVrfFacet.setVrfAuthorizationAddress.selector;
            s[2] = ITeeVrfFacet.getVrfAuthorizationAddress.selector;
            cuts[17] = IDiamond.FacetCut(
                address(new TeeVrfFacet()), IDiamond.FacetCutAction.Add, s
            );
        }
    }
}
