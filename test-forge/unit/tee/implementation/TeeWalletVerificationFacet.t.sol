// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { FlareTeeManagerDeployer } from "../../../utils/FlareTeeManagerDeployer.sol";
import { IIFlareTeeManager } from "../../../../contracts/tee/interface/IIFlareTeeManager.sol";
import { ITeeVerificationFacet } from
    "../../../../contracts/userInterfaces/tee/ITeeVerificationFacet.sol";
import { ITeeWalletVerificationFacet } from
    "../../../../contracts/userInterfaces/tee/ITeeWalletVerificationFacet.sol";
import { ITeeWalletManagerFacet } from
    "../../../../contracts/userInterfaces/tee/ITeeWalletManagerFacet.sol";
import { ITeeMachineRegistryFacet } from
    "../../../../contracts/userInterfaces/tee/ITeeMachineRegistryFacet.sol";
import { ITeeCommonErrors } from "../../../../contracts/userInterfaces/tee/ITeeCommonErrors.sol";
import {
    IPMWMultisigAccountConfigured,
    PMW_MULTISIG_ACCOUNT_CONFIGURED_ATTESTATION_TYPE
} from "../../../../contracts/userInterfaces/fdc2/IPMWMultisigAccountConfigured.sol";
import { IFdc2Hub } from "../../../../contracts/userInterfaces/fdc2/IFdc2Hub.sol";
import { IFdc2Verification } from "../../../../contracts/userInterfaces/fdc2/IFdc2Verification.sol";
import { ProtocolsV2Interface } from
    "../../../../contracts/userInterfaces/LTS/ProtocolsV2Interface.sol";
import { RandomNumberV2Interface } from
    "../../../../contracts/userInterfaces/LTS/RandomNumberV2Interface.sol";
import { PublicKey } from "../../../../contracts/userInterfaces/IPublicKey.sol";
import { Signature } from "../../../../contracts/userInterfaces/ISignature.sol";
import { IGovernanceSettings } from
    "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import { IDiamond } from "../../../../contracts/diamond/interfaces/IDiamond.sol";
import { IDiamondCut } from "../../../../contracts/diamond/interfaces/IDiamondCut.sol";
import { TeeMachineRegistry } from "../../../../contracts/tee/library/TeeMachineRegistry.sol";
import { TeeWalletManager } from "../../../../contracts/tee/library/TeeWalletManager.sol";
import { TeeWalletKeyManager } from "../../../../contracts/tee/library/TeeWalletKeyManager.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";


interface IPMWTestStateHelper {
    function setTeeMachineState(
        address _teeId,
        uint256 _extensionId,
        address _owner,
        ITeeMachineRegistryFacet.TeeStatus _status
    ) external;

    function setWalletState(
        bytes32 _walletId,
        bytes32 _projectId,
        ITeeWalletManagerFacet.WalletStatus _status
    ) external;

    function setKeyState(
        bytes32 _walletId,
        uint64 _keyId,
        bytes calldata _publicKey,
        address _teeId,
        uint64 _multisigThreshold
    ) external;
}

/**
 * @title PMWTestStateHelper
 * @notice Test-only facet that writes directly to ERC-7201 diamond storage,
 *         bypassing the full wallet lifecycle flows.
 */
contract PMWTestStateHelper is IPMWTestStateHelper {
    using EnumerableSet for EnumerableSet.AddressSet;

    function setTeeMachineState(
        address _teeId,
        uint256 _extensionId,
        address _owner,
        ITeeMachineRegistryFacet.TeeStatus _status
    )
        external
    {
        TeeMachineRegistry.State storage s = TeeMachineRegistry.getState();
        s.teeMachineStates[_teeId] = TeeMachineRegistry.TeeMachineState({
            extensionId: _extensionId,
            teePublicKey: PublicKey(bytes32(0), bytes32(0)),
            initialTeeId: _teeId,
            initialSigningPolicyId: 1,
            owner: _owner,
            teeProxyId: _teeId,
            status: _status,
            lastStatusChangeTs: block.timestamp,
            codeHash: bytes32(0),
            platform: bytes32(0),
            url: "teeUrl"
        });
        if (_status == ITeeMachineRegistryFacet.TeeStatus.PRODUCTION) {
            s.activeTeeIds.add(_teeId);
            s.extensionActiveTeeIds[_extensionId].add(_teeId);
        }
    }

    function setWalletState(
        bytes32 _walletId,
        bytes32 _projectId,
        ITeeWalletManagerFacet.WalletStatus _status
    )
        external
    {
        TeeWalletManager.State storage s = TeeWalletManager.getState();
        TeeWalletManager.TeeWalletState storage wallet = s.wallets[_walletId];
        wallet.projectId = _projectId;
        wallet.status = _status;
    }

    function setKeyState(
        bytes32 _walletId,
        uint64 _keyId,
        bytes calldata _publicKey,
        address _teeId,
        uint64 _multisigThreshold
    )
        external
    {
        TeeWalletKeyManager.State storage s = TeeWalletKeyManager.getState();
        TeeWalletKeyManager.TeeWalletKeysState storage keys = s.walletKeys[_walletId];
        keys.keyIdCounter = _keyId + 1;
        keys.multisigThreshold = _multisigThreshold;
        keys.keyIds.push(_keyId);
        TeeWalletKeyManager.KeyDefinition storage keyDef = keys.keyDefinitions[_keyId];
        keyDef.publicKey = _publicKey;
        keyDef.teeIds.push(_teeId);
    }
}

// solhint-disable-next-line max-states-count
contract TeeWalletVerificationFacetTest is Test {

    IIFlareTeeManager private flareTeeManager;

    address private initialGovernance;
    address private addressUpdater;
    address private relay;
    address private fdc2Hub;
    address private flareSystemsManager;
    address private fdc2Verification;

    address private teeId;
    address private owner;

    bytes32 private walletId;
    bytes32 private projectId;
    string private walletAddress;
    uint64 private multisigThreshold;
    bytes private publicKey;
    uint64[] private keyIds;
    bytes32 private sourceId;
    uint256 private rewardEpochId;
    address[] private cosigners;

    IPMWMultisigAccountConfigured.Proof private pmwProof;


    function setUp() public {
        initialGovernance = makeAddr("initialGovernance");
        addressUpdater = makeAddr("AddressUpdater");
        relay = makeAddr("Relay");
        fdc2Hub = makeAddr("Fdc2Hub");
        flareSystemsManager = makeAddr("FlareSystemsManager");
        fdc2Verification = makeAddr("Fdc2Verification");

        owner = makeAddr("owner");
        teeId = makeAddr("teeId");

        sourceId = bytes32("TEE");
        rewardEpochId = 1;
        walletId = keccak256("walletId");
        projectId = keccak256("projectId");
        walletAddress = "walletAddress";
        multisigThreshold = 1;
        publicKey = abi.encode("publicKey");

        cosigners = new address[](2);
        cosigners[0] = makeAddr("cosigner1");
        cosigners[1] = makeAddr("cosigner2");

        keyIds = new uint64[](1);
        keyIds[0] = 1;

        // Deploy FlareTeeManager Diamond
        flareTeeManager = FlareTeeManagerDeployer.deployDay1Facets(FlareTeeManagerDeployer.Day1DeployParams({
            governanceSettings: IGovernanceSettings(makeAddr("governanceSettings")),
            initialGovernance: initialGovernance,
            addressUpdater: addressUpdater,
            availabilityCheckValidityDurationSeconds: 1 hours,
            signingPolicyValidityDurationInRewardEpochs: 1,
            challengeValidityDurationSeconds: 1 minutes,
            defaultFee: 1000
        }));
        vm.startPrank(initialGovernance);
        FlareTeeManagerDeployer.deployLaterFacets(flareTeeManager, FlareTeeManagerDeployer.LaterDeployParams({
            pauseBeforeUpgradeMinDurationSeconds: 600
        }));
        vm.stopPrank();

        // Add PMWTestStateHelper facet to the diamond
        PMWTestStateHelper helperImpl = new PMWTestStateHelper();
        bytes4[] memory helperSelectors = new bytes4[](3);
        helperSelectors[0] = IPMWTestStateHelper.setTeeMachineState.selector;
        helperSelectors[1] = IPMWTestStateHelper.setWalletState.selector;
        helperSelectors[2] = IPMWTestStateHelper.setKeyState.selector;

        IDiamond.FacetCut[] memory cuts = new IDiamond.FacetCut[](1);
        cuts[0] = IDiamond.FacetCut(
            address(helperImpl),
            IDiamond.FacetCutAction.Add,
            helperSelectors
        );
        vm.prank(initialGovernance);
        IDiamondCut(address(flareTeeManager)).diamondCut(cuts, address(0), "");

        // Update contract addresses
        bytes32[] memory nameHashes = new bytes32[](6);
        address[] memory addresses = new address[](6);
        nameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        nameHashes[1] = keccak256(abi.encode("Relay"));
        nameHashes[2] = keccak256(abi.encode("Fdc2Hub"));
        nameHashes[3] = keccak256(abi.encode("Fdc2Verification"));
        nameHashes[4] = keccak256(abi.encode("FlareSystemsManager"));
        nameHashes[5] = keccak256(abi.encode("RewardManager"));
        addresses[0] = addressUpdater;
        addresses[1] = relay;
        addresses[2] = fdc2Hub;
        addresses[3] = fdc2Verification;
        addresses[4] = flareSystemsManager;
        addresses[5] = makeAddr("RewardManager");
        vm.prank(addressUpdater);
        flareTeeManager.updateContractAddresses(nameHashes, addresses);

        // Set up diamond state through the helper facet
        IPMWTestStateHelper helper = IPMWTestStateHelper(address(flareTeeManager));

        // Set teeId as PRODUCTION TEE machine
        helper.setTeeMachineState(
            teeId, 1, owner, ITeeMachineRegistryFacet.TeeStatus.PRODUCTION
        );

        // Set wallet state to PRODUCTION
        helper.setWalletState(walletId, projectId, ITeeWalletManagerFacet.WalletStatus.PRODUCTION);

        // Set key state with multisig threshold and public key
        helper.setKeyState(walletId, keyIds[0], publicKey, teeId, multisigThreshold);

        // Set up PMW proof
        pmwProof.header.thresholdBIPS = 0;
        pmwProof.header.attestationType = PMW_MULTISIG_ACCOUNT_CONFIGURED_ATTESTATION_TYPE;
        pmwProof.header.sourceId = sourceId;
        pmwProof.requestBody.publicKeys = new bytes[](1);
        pmwProof.requestBody.publicKeys[0] = publicKey;
        pmwProof.responseBody.status = IPMWMultisigAccountConfigured.PMWMultisigAccountStatus.OK;
        pmwProof.requestBody.threshold = multisigThreshold;

        // Mock external contract calls
        _mockVerifySigningPolicySignatures(rewardEpochId);
        _mockGetCurrentRewardEpochId(uint24(rewardEpochId));
        _mockVerifyCosignerSignatures(cosigners);

        vm.mockCall(
            relay,
            abi.encodeWithSelector(RandomNumberV2Interface.getRandomNumber.selector),
            abi.encode(uint256(0), true, 1)
        );

        vm.mockCall(
            fdc2Hub,
            abi.encodeWithSelector(IFdc2Hub.requestAttestation.selector),
            abi.encode("")
        );
    }


    // requestPMWMultisigAccountConfiguredAttestation
    function testRequestPMWMultisigAccountConfiguredAttestationRevertAccountAddressZero() public {
        vm.expectRevert(ITeeWalletVerificationFacet.AccountAddressZero.selector);
        flareTeeManager.requestPMWMultisigAccountConfiguredAttestation(
            walletId, sourceId, "", teeId, address(0), address(0)
        );
    }


    function testRequestPMWMultisigAccountConfiguredAttestationRevertOnlyProductionOrPausedStatus()
        public
    {
        bytes32 wallet2Id = keccak256("wallet2Id");
        IPMWTestStateHelper(address(flareTeeManager)).setWalletState(
            wallet2Id, projectId, ITeeWalletManagerFacet.WalletStatus.INITIALIZED
        );
        vm.expectRevert(ITeeCommonErrors.OnlyProductionOrPausedStatus.selector);
        flareTeeManager.requestPMWMultisigAccountConfiguredAttestation(
            wallet2Id, sourceId, walletAddress, teeId, address(0), address(0)
        );
    }


    function testRequestPMWMultisigAccountConfiguredAttestation() public {
        flareTeeManager.requestPMWMultisigAccountConfiguredAttestation(
            walletId, sourceId, walletAddress, teeId, address(0), address(0)
        );
    }


    function testRequestPMWMultisigAccountConfiguredAttestationWithProofOwnerAndClaimBack()
        public
    {
        address proofOwner = makeAddr("proofOwner");
        address claimBack = makeAddr("claimBack");
        vm.expectCall(
            fdc2Hub,
            _buildPMWExpectCallData(proofOwner, claimBack)
        );
        flareTeeManager.requestPMWMultisigAccountConfiguredAttestation(
            walletId, sourceId, walletAddress, teeId, proofOwner, claimBack
        );
    }


    // verifyPMWMultisigAccountConfiguredProof
    function testVerifyPMWMultisigAccountConfiguredProofRevertInvalidAttestation() public {
        pmwProof.header.thresholdBIPS = 1;
        vm.expectRevert(ITeeVerificationFacet.InvalidAttestation.selector);
        flareTeeManager.verifyPMWMultisigAccountConfiguredProof(walletId, pmwProof);
    }


    function testVerifyPMWMultisigAccountConfiguredProofRevertInvalidAttestation2() public {
        pmwProof.header.attestationType = bytes32("invalidAttestationType");
        vm.expectRevert(ITeeVerificationFacet.InvalidAttestation.selector);
        flareTeeManager.verifyPMWMultisigAccountConfiguredProof(walletId, pmwProof);
    }


    function testVerifyPMWMultisigAccountConfiguredProofRevertInvalidRequestBody1() public {
        pmwProof.requestBody.threshold = multisigThreshold + 1;
        vm.expectRevert(ITeeVerificationFacet.InvalidRequestBody.selector);
        flareTeeManager.verifyPMWMultisigAccountConfiguredProof(walletId, pmwProof);
    }


    function testVerifyPMWMultisigAccountConfiguredProofRevertInvalidRequestBody2() public {
        pmwProof.requestBody.publicKeys[0] = abi.encode("invalidPublicKey");
        vm.expectRevert(ITeeVerificationFacet.InvalidRequestBody.selector);
        flareTeeManager.verifyPMWMultisigAccountConfiguredProof(walletId, pmwProof);
    }


    function testVerifyPMWMultisigAccountConfiguredProof() public {
        bool isVerified =
            flareTeeManager.verifyPMWMultisigAccountConfiguredProof(walletId, pmwProof);
        assertEq(isVerified, true);
        pmwProof.responseBody.status =
            IPMWMultisigAccountConfigured.PMWMultisigAccountStatus.ERROR;
        isVerified =
            flareTeeManager.verifyPMWMultisigAccountConfiguredProof(walletId, pmwProof);
        assertEq(isVerified, false);
    }


    // verifyPMWMultisigAccountConfiguredProof with TEE signatures
    function testVerifyPMWMultisigAccountConfiguredProofWithTeeSignatures() public {
        address[] memory signingTeeIds = new address[](1);
        signingTeeIds[0] = teeId;
        _mockVerifyTeeSignatures(signingTeeIds);
        _addMockTeeSignatureToPmwProof();

        bool isVerified =
            flareTeeManager.verifyPMWMultisigAccountConfiguredProof(walletId, pmwProof);
        assertEq(isVerified, true);
    }


    function testVerifyPMWMultisigAccountConfiguredProofWithTeeSignaturesStatusError() public {
        address[] memory signingTeeIds = new address[](1);
        signingTeeIds[0] = teeId;
        _mockVerifyTeeSignatures(signingTeeIds);
        _addMockTeeSignatureToPmwProof();
        pmwProof.responseBody.status =
            IPMWMultisigAccountConfigured.PMWMultisigAccountStatus.ERROR;

        bool isVerified =
            flareTeeManager.verifyPMWMultisigAccountConfiguredProof(walletId, pmwProof);
        assertEq(isVerified, false);
    }


    // TEE signatures bypass signing policy
    function testVerifyPMWMultisigAccountConfiguredProofTeeSignaturesBypassSigningPolicy()
        public
    {
        // set signing policy to return invalid epoch that would cause revert
        _mockVerifySigningPolicySignatures(rewardEpochId + 100);
        address[] memory signingTeeIds = new address[](1);
        signingTeeIds[0] = teeId;
        _mockVerifyTeeSignatures(signingTeeIds);
        _addMockTeeSignatureToPmwProof();

        bool isVerified =
            flareTeeManager.verifyPMWMultisigAccountConfiguredProof(walletId, pmwProof);
        assertEq(isVerified, true);
    }


    // ===== Mock helpers =====

    function _mockVerifySigningPolicySignatures(uint256 _rewardEpochId) private {
        vm.mockCall(
            fdc2Verification,
            abi.encodeWithSelector(IFdc2Verification.verifySigningPolicySignatures.selector),
            abi.encode(_rewardEpochId)
        );
    }


    function _mockVerifyCosignerSignatures(address[] memory _cosignersList) private {
        vm.mockCall(
            fdc2Verification,
            abi.encodeWithSelector(IFdc2Verification.verifyCosignerSignatures.selector),
            abi.encode(_cosignersList)
        );
    }


    function _mockGetCurrentRewardEpochId(uint24 _rewardEpochId) private {
        vm.mockCall(
            flareSystemsManager,
            abi.encodeWithSelector(ProtocolsV2Interface.getCurrentRewardEpochId.selector),
            abi.encode(_rewardEpochId)
        );
    }


    function _mockVerifyTeeSignatures(address[] memory _signingTeeIds) private {
        vm.mockCall(
            fdc2Verification,
            abi.encodeWithSelector(IFdc2Verification.verifyTeeSignatures.selector),
            abi.encode(_signingTeeIds)
        );
    }


    function _addMockTeeSignatureToPmwProof() private {
        pmwProof.signatures.teeSignatures.push(
            Signature(27, bytes32(uint256(1)), bytes32(uint256(2)))
        );
    }


    function _buildPMWExpectCallData(
        address _proofOwner,
        address _claimBack
    ) private view returns (bytes memory) {
        IPMWMultisigAccountConfigured.RequestBody memory requestBody =
            IPMWMultisigAccountConfigured.RequestBody({
                accountAddress: walletAddress,
                publicKeys: new bytes[](keyIds.length),
                threshold: multisigThreshold
            });
        for (uint256 i = 0; i < keyIds.length; i++) {
            requestBody.publicKeys[i] = publicKey;
        }
        IFdc2Hub.Fdc2AttestationRequest memory attestationRequest =
            IFdc2Hub.Fdc2AttestationRequest({
                header: IFdc2Hub.Fdc2RequestHeader({
                    attestationType: PMW_MULTISIG_ACCOUNT_CONFIGURED_ATTESTATION_TYPE,
                    sourceId: sourceId,
                    thresholdBIPS: 0,
                    proofOwner: _proofOwner
                }),
                requestBody: abi.encode(requestBody)
            });
        address[] memory teeIdsParam = new address[](1);
        teeIdsParam[0] = teeId;
        return abi.encodeWithSelector(
            IFdc2Hub.requestAttestation.selector,
            attestationRequest,
            uint256(0),
            teeIdsParam,
            new address[](0),
            uint64(0),
            _claimBack
        );
    }
}
