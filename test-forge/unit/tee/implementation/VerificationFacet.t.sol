// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test, Vm } from "forge-std/Test.sol";
import { FlareTeeManagerDeployer } from "../../../utils/FlareTeeManagerDeployer.sol";
import { IIFlareTeeManager } from "../../../../contracts/tee/interface/IIFlareTeeManager.sol";
import {
    IVerification
} from "../../../../contracts/userInterfaces/tee/IVerification.sol";
import { IMachineManager } from "../../../../contracts/userInterfaces/tee/IMachineManager.sol";
import { IInstructions } from "../../../../contracts/userInterfaces/tee/IInstructions.sol";
import { IWalletManager } from "../../../../contracts/userInterfaces/tee/IWalletManager.sol";
import { ITeeExtensionStateVerifier } from "../../../../contracts/userInterfaces/tee/ITeeExtensionStateVerifier.sol";
import { IFdc2Hub } from "../../../../contracts/userInterfaces/fdc2/IFdc2Hub.sol";
import { IFdc2Verification } from "../../../../contracts/userInterfaces/fdc2/IFdc2Verification.sol";
import { ITeeAvailabilityCheck } from "../../../../contracts/userInterfaces/fdc2/ITeeAvailabilityCheck.sol";
import { ProtocolsV2Interface } from "../../../../contracts/userInterfaces/LTS/ProtocolsV2Interface.sol";
import { RandomNumberV2Interface } from "../../../../contracts/userInterfaces/LTS/RandomNumberV2Interface.sol";
import { IFlareGovernance } from "../../../../contracts/userInterfaces/IFlareGovernance.sol";
import { ITeeCommonErrors } from "../../../../contracts/userInterfaces/tee/ITeeCommonErrors.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import { Signature } from "../../../../contracts/userInterfaces/ISignature.sol";
import { PublicKey } from "../../../../contracts/userInterfaces/IPublicKey.sol";
import { IDiamond } from "../../../../contracts/diamond/interfaces/IDiamond.sol";
import { IDiamondCut } from "../../../../contracts/diamond/interfaces/IDiamondCut.sol";
import { IIRewardManager } from "../../../../contracts/protocol/interface/IIRewardManager.sol";
import { MachineManager } from "../../../../contracts/tee/library/MachineManager.sol";
import { Verification } from "../../../../contracts/tee/library/Verification.sol";
import { ExtensionManager } from "../../../../contracts/tee/library/ExtensionManager.sol";
import { WalletManager } from "../../../../contracts/tee/library/WalletManager.sol";
import { WalletKeyManager } from "../../../../contracts/tee/library/WalletKeyManager.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

interface ITestVerificationStateHelper {
    function setTeeMachineState(
        address _teeId,
        uint256 _extensionId,
        address _owner,
        address _teeProxyId,
        string calldata _url,
        IMachineManager.TeeStatus _status,
        bytes32 _codeHash,
        bytes32 _platform,
        uint32 _initialSigningPolicyId,
        address _initialTeeId
    ) external;

    function setTeeMachineState(
        address _teeId,
        uint256 _extensionId,
        address _owner,
        IMachineManager.TeeStatus _status
    ) external;

    function setTeeMachineStatus(
        address _teeId,
        IMachineManager.TeeStatus _status
    ) external;

    function setupCodeHashPlatform(
        uint256 _extensionId,
        bytes32 _codeHash,
        bytes32 _platform,
        bool _supported
    ) external;

    function setExtensionStateVerifier(
        uint256 _extensionId,
        address _stateVerifier
    ) external;

    function setTeeMachineInitialTeeId(
        address _teeId,
        address _initialTeeId
    ) external;

    function setChallenge(
        address _teeId,
        bytes32 _challenge,
        uint256 _challengeTs
    ) external;

    function setWalletState(
        bytes32 _walletId,
        bytes32 _projectId,
        IWalletManager.WalletStatus _status
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
 * @title TestVerificationStateHelper
 * @notice Test-only facet added to the diamond to write directly to ERC-7201 storage,
 *         bypassing the full registration/attestation lifecycle flows.
 */
contract TestVerificationStateHelper is ITestVerificationStateHelper {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    function setTeeMachineState(
        address _teeId,
        uint256 _extensionId,
        address _owner,
        address _teeProxyId,
        string calldata _url,
        IMachineManager.TeeStatus _status,
        bytes32 _codeHash,
        bytes32 _platform,
        uint32 _initialSigningPolicyId,
        address _initialTeeId
    )
        external
    {
        MachineManager.State storage s = MachineManager.getState();
        s.teeMachineStates[_teeId] = MachineManager.TeeMachineState({
            extensionId: _extensionId,
            teePublicKey: PublicKey(bytes32(0), bytes32(0)),
            initialTeeId: _initialTeeId,
            initialSigningPolicyId: _initialSigningPolicyId,
            owner: _owner,
            teeProxyId: _teeProxyId,
            status: _status,
            lastStatusChangeTs: uint64(block.timestamp),
            codeHash: _codeHash,
            platform: _platform,
            governanceHash: bytes32(0),
            url: _url
        });
        if (_status == IMachineManager.TeeStatus.PRODUCTION) {
            s.activeTeeIds.add(_teeId);
            s.extensionActiveTeeIds[_extensionId].add(_teeId);
        }
    }

    function setTeeMachineState(
        address _teeId,
        uint256 _extensionId,
        address _owner,
        IMachineManager.TeeStatus _status
    )
        external
    {
        MachineManager.State storage s = MachineManager.getState();
        s.teeMachineStates[_teeId] = MachineManager.TeeMachineState({
            extensionId: _extensionId,
            teePublicKey: PublicKey(bytes32(0), bytes32(0)),
            initialTeeId: _teeId,
            initialSigningPolicyId: 1,
            owner: _owner,
            teeProxyId: address(0),
            status: _status,
            lastStatusChangeTs: uint64(block.timestamp),
            codeHash: bytes32(0),
            platform: bytes32(0),
            governanceHash: bytes32(0),
            url: ""
        });
        if (_status == IMachineManager.TeeStatus.PRODUCTION) {
            s.activeTeeIds.add(_teeId);
            s.extensionActiveTeeIds[_extensionId].add(_teeId);
        }
    }

    function setTeeMachineStatus(
        address _teeId,
        IMachineManager.TeeStatus _status
    )
        external
    {
        MachineManager.State storage s = MachineManager.getState();
        MachineManager.TeeMachineState storage state = s.teeMachineStates[_teeId];
        state.status = _status;
        if (_status == IMachineManager.TeeStatus.PRODUCTION) {
            s.activeTeeIds.add(_teeId);
            s.extensionActiveTeeIds[state.extensionId].add(_teeId);
        } else {
            s.activeTeeIds.remove(_teeId);
            s.extensionActiveTeeIds[state.extensionId].remove(_teeId);
        }
    }

    function setupCodeHashPlatform(
        uint256 _extensionId,
        bytes32 _codeHash,
        bytes32 _platform,
        bool _supported
    )
        external
    {
        ExtensionManager.State storage s = ExtensionManager.getState();
        if (_supported) {
            s.extensions[_extensionId].codeHashToVersion[_codeHash].platforms.add(_platform);
            s.extensions[_extensionId].codeHashPlatformDisabled[_codeHash][_platform] = false;
        } else {
            s.extensions[_extensionId].codeHashToVersion[_codeHash].platforms.remove(_platform);
        }
    }

    function setExtensionStateVerifier(
        uint256 _extensionId,
        address _stateVerifier
    )
        external
    {
        ExtensionManager.getState().extensions[_extensionId].stateVerifier =
            ITeeExtensionStateVerifier(_stateVerifier);
    }

    function setTeeMachineInitialTeeId(
        address _teeId,
        address _initialTeeId
    )
        external
    {
        MachineManager.getState().teeMachineStates[_teeId].initialTeeId = _initialTeeId;
    }

    function setChallenge(
        address _teeId,
        bytes32 _challenge,
        uint256 _challengeTs
    )
        external
    {
        Verification.State storage s = Verification.getState();
        s.challenges[_teeId] = _challenge;
        s.challengeTs[_teeId] = _challengeTs;
    }

    function setWalletState(
        bytes32 _walletId,
        bytes32 _projectId,
        IWalletManager.WalletStatus _status
    )
        external
    {
        WalletManager.State storage s = WalletManager.getState();
        s.wallets[_walletId].projectId = _projectId;
        s.wallets[_walletId].status = _status;
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
        WalletKeyManager.State storage s = WalletKeyManager.getState();
        WalletKeyManager.TeeWalletKeysState storage keys = s.walletKeys[_walletId];
        keys.multisigThreshold = _multisigThreshold;
        keys.keyIds.push(_keyId);
        keys.keyDefinitions[_keyId].publicKey = _publicKey;
        keys.keyDefinitions[_keyId].teeIds.push(_teeId);
    }
}

// solhint-disable-next-line max-states-count
contract VerificationFacetTest is Test {

    IIFlareTeeManager private flareTeeManager;
    ITestVerificationStateHelper private stateHelper;

    address private initialGovernance;
    address private addressUpdater;
    address private relay;
    address private fdc2Hub;
    address private flareSystemsManager;
    address private fdc2Verification;
    address private rewardManager;

    address private owner;
    address private teeId;
    address private teeProxyId;
    uint256 private randomNumber;
    uint256 private extensionId;
    ITeeAvailabilityCheck.Proof private proof;
    string private url;
    uint256 private rewardEpochId;
    address[] private cosigners;
    bytes32 private sourceId;
    uint32 private signingPolicyId;
    bytes32 private instructionId;

    // Wallet-specific state
    bytes32 private walletId;
    bytes32 private projectId;
    uint64 private multisigThreshold;
    bytes private publicKey;
    uint64[] private keyIds;

    function setUp() public {
        owner = makeAddr("owner");
        teeId = makeAddr("teeId");
        teeProxyId = makeAddr("teeProxyId");
        extensionId = 0;
        url = "url";
        sourceId = bytes32("TEE");
        signingPolicyId = 1;
        rewardEpochId = 1;
        instructionId = bytes32("instructionId");

        proof.requestBody.teeId = teeId;
        proof.responseBody.status = ITeeAvailabilityCheck.AvailabilityCheckStatus.OK;
        proof.header.thresholdBIPS = 0;
        proof.header.attestationType = bytes32("TeeAvailabilityCheck");
        proof.header.sourceId = sourceId;
        proof.requestBody.teeProxyId = teeProxyId;
        proof.requestBody.url = url;
        proof.responseBody.initialSigningPolicyId = signingPolicyId;
        proof.responseBody.codeHash = keccak256("codeHash");
        proof.responseBody.platform = keccak256("platform");
        proof.responseBody.lastSigningPolicyId = uint32(rewardEpochId);

        cosigners = new address[](2);
        cosigners[0] = makeAddr("cosigner1");
        cosigners[1] = makeAddr("cosigner2");

        initialGovernance = makeAddr("initialGovernance");
        addressUpdater = makeAddr("AddressUpdater");

        relay = makeAddr("Relay");
        fdc2Hub = makeAddr("Fdc2Hub");
        flareSystemsManager = makeAddr("FlareSystemsManager");
        fdc2Verification = makeAddr("Fdc2Verification");
        rewardManager = makeAddr("RewardManager");

        flareTeeManager = FlareTeeManagerDeployer.deployFacets(FlareTeeManagerDeployer.DeployParams({
            governanceSettings: IGovernanceSettings(makeAddr("governanceSettings")),
            initialGovernance: initialGovernance,
            addressUpdater: addressUpdater,
            availabilityCheckValidityDurationSeconds: 1 hours,
            signingPolicyValidityDurationInRewardEpochs: 1,
            challengeValidityDurationSeconds: 1 minutes,
            defaultFee: 1000,
            publicExtensionCreationEnabled: true,
            emergencyUnpauseGracePeriodSeconds: 7200
        }));

        // Add TestVerificationStateHelper facet to the diamond
        TestVerificationStateHelper helperImpl = new TestVerificationStateHelper();
        bytes4 sel10Param = bytes4(keccak256(
            "setTeeMachineState(address,uint256,address,address,string,"
            "uint8,bytes32,bytes32,uint32,address)"
        ));
        bytes4 sel4Param = bytes4(keccak256(
            "setTeeMachineState(address,uint256,address,uint8)"
        ));

        bytes4[] memory uniqueSelectors = new bytes4[](9);
        uniqueSelectors[0] = sel10Param;
        uniqueSelectors[1] = ITestVerificationStateHelper.setTeeMachineStatus.selector;
        uniqueSelectors[2] = ITestVerificationStateHelper.setupCodeHashPlatform.selector;
        uniqueSelectors[3] = ITestVerificationStateHelper.setExtensionStateVerifier.selector;
        uniqueSelectors[4] = ITestVerificationStateHelper.setTeeMachineInitialTeeId.selector;
        uniqueSelectors[5] = ITestVerificationStateHelper.setChallenge.selector;
        uniqueSelectors[6] = ITestVerificationStateHelper.setWalletState.selector;
        uniqueSelectors[7] = ITestVerificationStateHelper.setKeyState.selector;
        uniqueSelectors[8] = sel4Param;

        IDiamond.FacetCut[] memory cuts = new IDiamond.FacetCut[](1);
        cuts[0] = IDiamond.FacetCut(
            address(helperImpl),
            IDiamond.FacetCutAction.Add,
            uniqueSelectors
        );
        vm.prank(initialGovernance);
        IDiamondCut(address(flareTeeManager)).diamondCut(cuts, address(0), "");
        stateHelper = ITestVerificationStateHelper(address(flareTeeManager));

        // Update contract addresses (external contracts only for the diamond)
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
        addresses[5] = rewardManager;

        vm.prank(addressUpdater);
        flareTeeManager.updateContractAddresses(nameHashes, addresses);

        // Set up diamond state through the helper facet
        // Register tee machine in PRODUCTION status with matching proof data
        stateHelper.setTeeMachineState(
            teeId,
            extensionId,
            owner,
            teeProxyId,
            url,
            IMachineManager.TeeStatus.PRODUCTION,
            proof.responseBody.codeHash,
            proof.responseBody.platform,
            signingPolicyId,
            // initialTeeId left at zero so the verifier accepts an empty system-state payload (the
            // default in this test's proof). Tests that want a rejection set a non-zero
            // initialTeeId via `setTeeMachineInitialTeeId`.
            address(0)
        );

        // Set up extension with supported code hash + platform
        stateHelper.setupCodeHashPlatform(
            extensionId, proof.responseBody.codeHash, proof.responseBody.platform, true
        );

        // Mock external contract calls
        _mockVerifySigningPolicySignatures(rewardEpochId);
        _mockGetCurrentRewardEpochId(uint24(rewardEpochId));
        _mockRecoverCosigners(cosigners);

        vm.mockCall(
            relay,
            abi.encodeWithSelector(
                RandomNumberV2Interface.getRandomNumber.selector
            ),
            abi.encode(randomNumber, true, 1)
        );

        vm.mockCall(
            fdc2Hub,
            abi.encodeWithSelector(
                IFdc2Hub.requestAttestation.selector
            ),
            abi.encode("")
        );

        vm.mockCall(
            rewardManager,
            abi.encodeWithSelector(
                IIRewardManager.receiveRewards.selector
            ),
            abi.encode()
        );

        // =====================================================================
        // Wallet-specific setup
        // =====================================================================
        walletId = bytes32("walletId");
        projectId = bytes32("projectId");
        multisigThreshold = 1;
        publicKey = hex"0123456789abcdef";
        keyIds = new uint64[](1);
        keyIds[0] = 1;

        // Set wallet state
        stateHelper.setWalletState(walletId, projectId, IWalletManager.WalletStatus.PRODUCTION);

        // Set key state
        stateHelper.setKeyState(walletId, keyIds[0], publicKey, teeId, multisigThreshold);

        // Fund the test contract (sender of requestTeeAttestation) for the non-zero instruction fee.
        vm.deal(address(this), 1 ether);
    }

    // =========================================================================
    // Machine verification tests
    // =========================================================================

    // initialize
    function testInitialize() public {
        vm.expectEmit();
        emit IVerification.SettingsUpdated(1 hours, 1, 1 minutes);
        FlareTeeManagerDeployer.deployFacets(FlareTeeManagerDeployer.DeployParams({
            governanceSettings: IGovernanceSettings(makeAddr("governanceSettings")),
            initialGovernance: initialGovernance,
            addressUpdater: addressUpdater,
            availabilityCheckValidityDurationSeconds: 1 hours,
            signingPolicyValidityDurationInRewardEpochs: 1,
            challengeValidityDurationSeconds: 1 minutes,
            defaultFee: 1000,
            publicExtensionCreationEnabled: true,
            emergencyUnpauseGracePeriodSeconds: 7200
        }));
    }

    // requestTeeAttestation
    function testRequestTeeAttestation() public {
        bytes32 challenge = bytes32(0);
        vm.expectEmit();
        emit IVerification.TeeAttestationRequested(teeId, challenge);
        flareTeeManager.requestTeeAttestation{value: 1000}(teeId, address(0));

        vm.warp(2 minutes);
        challenge = keccak256(abi.encode(teeId, vm.getBlockTimestamp(), randomNumber));
        vm.expectEmit();
        emit IVerification.TeeAttestationRequested(teeId, challenge);
        flareTeeManager.requestTeeAttestation{value: 1000}(teeId, address(0));
    }

    function testRequestTeeAttestationWithClaimBackAddress() public {
        address claimBack = makeAddr("claimBack");
        vm.recordLogs();
        flareTeeManager.requestTeeAttestation{value: 1000}(teeId, claimBack);
        // Verify TeeInstructionsSent event carries the claimBackAddress
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bool foundInstructionsSent = false;
        bytes32 instructionsSentTopic = IInstructions.TeeInstructionsSent.selector;
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == instructionsSentTopic) {
                foundInstructionsSent = true;
                // claimBackAddress is encoded in the non-indexed data
                (
                    , // teeMachines
                    , // opType
                    , // opCommand
                    , // message
                    , // cosigners
                    , // cosignersThreshold
                    address loggedClaimBack,
                    // fee
                ) = abi.decode(
                    entries[i].data,
                    (IMachineManager.TeeMachine[], bytes32, bytes32,
                    bytes, address[], uint64, address, uint256)
                );
                assertEq(loggedClaimBack, claimBack);
                break;
            }
        }
        assertTrue(foundInstructionsSent);
    }

    // requestAvailabilityCheckAttestation
    function testRequestAvailabilityCheckAttestationRevertChallengeExpired() public {
        vm.warp(2 hours);
        vm.expectRevert(
            abi.encodeWithSelector(
                IVerification.ChallengeExpired.selector,
                0
            )
        );
        flareTeeManager.requestAvailabilityCheckAttestation(teeId, instructionId, teeId, address(0), address(0));
    }

    function testRequestAvailabilityCheckAttestation() public {
        stateHelper.setTeeMachineStatus(teeId, IMachineManager.TeeStatus.INITIALIZED);
        flareTeeManager.requestAvailabilityCheckAttestation(teeId, instructionId, teeId, address(0), address(0));
    }

    function testRequestAvailabilityCheckAttestationWithProofOwnerAndClaimBack() public {
        address proofOwner = makeAddr("proofOwner");
        address claimBack = makeAddr("claimBack");
        stateHelper.setTeeMachineStatus(teeId, IMachineManager.TeeStatus.INITIALIZED);
        vm.expectCall(
            fdc2Hub,
            _buildAvailabilityCheckExpectCallData(proofOwner, claimBack)
        );
        flareTeeManager.requestAvailabilityCheckAttestation(teeId, instructionId, teeId, proofOwner, claimBack);
    }

    // confirmAvailability
    function testConfirmAvailabilityRevertTeeMachineNotAvailable() public {
        stateHelper.setTeeMachineStatus(teeId, IMachineManager.TeeStatus.PAUSED);
        vm.expectRevert(ITeeCommonErrors.TeeMachineNotAvailable.selector);
        flareTeeManager.confirmAvailability(proof);
    }

    function testConfirmAvailabilityRevertInvalidAvailabilityCheckStatus() public {
        proof.responseBody.status = ITeeAvailabilityCheck.AvailabilityCheckStatus.OBSOLETE;
        vm.expectRevert(ITeeCommonErrors.InvalidAvailabilityCheckStatus.selector);
        flareTeeManager.confirmAvailability(proof);

    }

    function testConfirmAvailabilityRevertVersionNotSupported() public {
        stateHelper.setupCodeHashPlatform(
            extensionId, proof.responseBody.codeHash, proof.responseBody.platform, false
        );
        vm.expectRevert(ITeeCommonErrors.VersionNotSupported.selector);
        flareTeeManager.confirmAvailability(proof);

    }

    function testConfirmAvailabilityRevertInvalidAttestation1() public {
        proof.header.thresholdBIPS = 1;
        vm.expectRevert(IVerification.InvalidAttestation.selector);
        flareTeeManager.confirmAvailability(proof);
    }

    function testConfirmAvailabilityRevertInvalidAttestation2() public {
        proof.header.attestationType = keccak256("invalidAttestationType");
        vm.expectRevert(IVerification.InvalidAttestation.selector);
        flareTeeManager.confirmAvailability(proof);
    }

    function testConfirmAvailabilityRevertInvalidAttestation3() public {
        proof.header.sourceId = keccak256("invalidSourceId");
        vm.expectRevert(IVerification.InvalidAttestation.selector);
        flareTeeManager.confirmAvailability(proof);
    }

    function testConfirmAvailabilityRevertAvailabilityCheckTimestampInvalid() public {
        vm.warp(0);
        vm.expectRevert(ITeeCommonErrors.AvailabilityCheckTimestampInvalid.selector);
        flareTeeManager.confirmAvailability(proof);
    }

    function testConfirmAvailabilityRevertChallengeExpired() public {
        vm.warp(2 hours);
        vm.expectRevert(
            abi.encodeWithSelector(
                IVerification.ChallengeExpired.selector,
                0
            )
        );
        flareTeeManager.confirmAvailability(proof);
    }

    function testConfirmAvailabilityRevertInvalidSigningPolicy() public {
        _mockVerifySigningPolicySignatures(rewardEpochId + 2);
        vm.expectRevert(IFdc2Verification.InvalidSigningPolicy.selector);
        flareTeeManager.confirmAvailability(proof);
    }

    function testConfirmAvailabilityRevertInvalidResponseData() public {
        _mockGetCurrentRewardEpochId(uint24(rewardEpochId + 100));
        _mockVerifySigningPolicySignatures(rewardEpochId + 100);
        vm.expectRevert(ITeeCommonErrors.InvalidResponseData.selector);
        flareTeeManager.confirmAvailability(proof);
    }

    function testConfirmAvailabilityRevertInvalidResponseData1() public {
        // Mark the machine with a non-zero stored `initialTeeId`. The verifier requires the stored
        // `initialTeeId` to be zero for an empty system-state payload, so the payload is rejected.
        stateHelper.setTeeMachineInitialTeeId(proof.requestBody.teeId, makeAddr("storedInitialTeeId"));
        vm.expectRevert(ITeeCommonErrors.InvalidResponseData.selector);
        flareTeeManager.confirmAvailability(proof);
    }

    function testConfirmAvailabilityRevertInvalidResponseData2() public {
        proof.responseBody.initialSigningPolicyId = signingPolicyId + 1;
        vm.expectRevert(ITeeCommonErrors.InvalidResponseData.selector);
        flareTeeManager.confirmAvailability(proof);
    }

    function testConfirmAvailability() public {
        vm.expectEmit();
        emit IVerification.AvailabilityCheckValidityExtended(
            teeId,
            owner,
            proof.header.timestamp + 1 hours
        );
        flareTeeManager.confirmAvailability(proof);
    }

    // confirmAvailability with TEE signatures
    function testConfirmAvailabilityWithTeeSignatures() public {
        address[] memory signingTeeIds = new address[](1);
        signingTeeIds[0] = teeId;
        _mockVerifyTeeSignatures(signingTeeIds);
        _addMockTeeSignatureToProof();

        vm.expectEmit();
        emit IVerification.AvailabilityCheckValidityExtended(
            teeId,
            owner,
            proof.header.timestamp + 1 hours
        );
        flareTeeManager.confirmAvailability(proof);
    }

    // confirmAvailability with TEE signatures bypasses signing policy check
    function testConfirmAvailabilityTeeSignaturesBypassSigningPolicy() public {
        _mockVerifySigningPolicySignatures(rewardEpochId + 100);
        address[] memory signingTeeIds = new address[](1);
        signingTeeIds[0] = teeId;
        _mockVerifyTeeSignatures(signingTeeIds);
        _addMockTeeSignatureToProof();

        vm.expectEmit();
        emit IVerification.AvailabilityCheckValidityExtended(
            teeId,
            owner,
            proof.header.timestamp + 1 hours
        );
        flareTeeManager.confirmAvailability(proof);
    }

    // setCosigners
    function testSetCosignersRevertOnlyGovernance() public {
        vm.expectRevert(IFlareGovernance.OnlyGovernance.selector);
        flareTeeManager.setCosigners(cosigners, 10);
    }

    // cosigners.length < threshold
    function testSetCosignersRevertInvalidThreshold1() public {
        vm.prank(initialGovernance);
        vm.expectRevert(ITeeCommonErrors.InvalidThreshold.selector);
        flareTeeManager.setCosigners(cosigners, 10);
    }

    // cosigners.length != 0 && threshold == 0
    function testSetCosignersRevertInvalidThreshold2() public {
        vm.prank(initialGovernance);
        vm.expectRevert(ITeeCommonErrors.InvalidThreshold.selector);
        flareTeeManager.setCosigners(cosigners, 0);
    }

    function testSetCosignersRevertInvalidCosigner() public {
        cosigners[0] = address(0);
        vm.prank(initialGovernance);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeCommonErrors.InvalidCosigner.selector,
                cosigners[0]
            )
        );
        flareTeeManager.setCosigners(cosigners, 1);
    }

    function testSetCosignersRevertDuplicatedCosigner() public {
        cosigners[1] = cosigners[0];
        vm.prank(initialGovernance);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeCommonErrors.DuplicatedCosigner.selector,
                cosigners[1]
            )
        );
        flareTeeManager.setCosigners(cosigners, 1);
    }

    function testSetCosigners() public {
        vm.prank(initialGovernance);
        vm.expectEmit();
        emit IVerification.CosignersSet(cosigners, 1);
        flareTeeManager.setCosigners(cosigners, 1);
    }

    // updateSettings
    function testUpdateSettingsRevertOnlyGovernance() public {
        vm.expectRevert(IFlareGovernance.OnlyGovernance.selector);
        flareTeeManager.updateSettings(1, 1, 1);
    }

    function testUpdateSettingsRevertInvalidDurationAvailability() public {
        vm.prank(initialGovernance);
        vm.expectRevert(ITeeCommonErrors.InvalidDuration.selector);
        flareTeeManager.updateSettings(1, 1, 1 minutes);
    }

    function testUpdateSettingsRevertInvalidDurationSigningPolicy() public {
        vm.prank(initialGovernance);
        vm.expectRevert(ITeeCommonErrors.InvalidDuration.selector);
        flareTeeManager.updateSettings(1 hours, 0, 1 minutes);
    }

    function testUpdateSettingsRevertInvalidDurationChallenge() public {
        vm.prank(initialGovernance);
        vm.expectRevert(ITeeCommonErrors.InvalidDuration.selector);
        flareTeeManager.updateSettings(1 hours, 1, 1);
    }

    function testUpdateSettingsRevertInvalidDurationChallengeTooLong() public {
        vm.prank(initialGovernance);
        vm.expectRevert(ITeeCommonErrors.InvalidDuration.selector);
        flareTeeManager.updateSettings(1 hours, 1, 1 hours + 1);
    }

    function testUpdateSettings() public {
        vm.prank(initialGovernance);
        vm.expectEmit();
        emit IVerification.SettingsUpdated(1 hours, 1, 1 minutes);
        flareTeeManager.updateSettings(1 hours, 1, 1 minutes);
    }

    // The challenge validity duration accepts the inclusive maximum of one hour.
    function testUpdateSettingsChallengeMaxOneHour() public {
        vm.prank(initialGovernance);
        vm.expectEmit();
        emit IVerification.SettingsUpdated(1 hours, 1, 1 hours);
        flareTeeManager.updateSettings(1 hours, 1, 1 hours);
    }

    // getCosigners
    function testGetCosigners() public {
        (address[] memory returnedCosigners, uint64 returnedCosignersThreshold) =
            flareTeeManager.getCosigners();
        assertEq(returnedCosigners.length, 0);
        assertEq(returnedCosignersThreshold, 0);

        testSetCosigners();
        (returnedCosigners, returnedCosignersThreshold) = flareTeeManager.getCosigners();
        assertEq(returnedCosigners.length, 2);
        assertEq(returnedCosigners[0], cosigners[0]);
        assertEq(returnedCosigners[1], cosigners[1]);
        assertEq(returnedCosignersThreshold, 1);
    }

    // getSettings
    function testGetSettings() public {
        (uint256 availabilityCheck, uint256 challenge) = flareTeeManager.getSettings();
        assertEq(availabilityCheck, 1 hours);
        assertEq(challenge, 1 minutes);
    }

    // =========================================================================
    // Mock helpers
    // =========================================================================

    function _mockVerifySigningPolicySignatures(uint256 _rewardEpochId) private {
        vm.mockCall(
            fdc2Verification,
            abi.encodeWithSelector(
                IFdc2Verification.verifySigningPolicySignatures.selector
            ),
            abi.encode(_rewardEpochId)
        );
    }

    function _mockRecoverCosigners(address[] memory _cosignersList) private {
        vm.mockCall(
            fdc2Verification,
            abi.encodeWithSelector(
                IFdc2Verification.recoverCosigners.selector
            ),
            abi.encode(_cosignersList)
        );
    }

    function _mockGetCurrentRewardEpochId(uint24 _rewardEpochId) private {
        vm.mockCall(
            flareSystemsManager,
            abi.encodeWithSelector(
                ProtocolsV2Interface.getCurrentRewardEpochId.selector
            ),
            abi.encode(_rewardEpochId)
        );
    }

    function _mockVerifyTeeSignatures(address[] memory _signingTeeIds) private {
        vm.mockCall(
            fdc2Verification,
            abi.encodeWithSelector(
                IFdc2Verification.verifyTeeSignatures.selector
            ),
            abi.encode(_signingTeeIds)
        );
    }

    function _addMockTeeSignatureToProof() private {
        proof.signatures.teeSignatures.push(Signature(27, bytes32(uint256(1)), bytes32(uint256(2))));
    }

    function _buildAvailabilityCheckExpectCallData(
        address _proofOwner,
        address _claimBack
    ) private view returns (bytes memory) {
        ITeeAvailabilityCheck.RequestBody memory requestBody = ITeeAvailabilityCheck.RequestBody({
            teeId: teeId,
            teeProxyId: teeProxyId,
            url: url,
            challenge: bytes32(0),
            instructionId: instructionId
        });
        IFdc2Hub.Fdc2AttestationRequest memory attestationRequest = IFdc2Hub.Fdc2AttestationRequest({
            header: IFdc2Hub.Fdc2RequestHeader({
                attestationType: bytes32("TeeAvailabilityCheck"),
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
