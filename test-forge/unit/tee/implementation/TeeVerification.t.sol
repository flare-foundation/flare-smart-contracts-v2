// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { TeeVerification } from "../../../../contracts/tee/implementation/TeeVerification.sol";
import { TeeVerificationProxy } from "../../../../contracts/tee/proxy/TeeVerificationProxy.sol";
import { IITeeSystemStateVerifier } from "../../../../contracts/tee/interface/IITeeSystemStateVerifier.sol";
import { ITeeMachineRegistry } from "../../../../contracts/userInterfaces/tee/ITeeMachineRegistry.sol";
import { ITeeWalletManager } from "../../../../contracts/userInterfaces/tee/ITeeWalletManager.sol";
import { ITeeExtensionRegistry } from "../../../../contracts/userInterfaces/tee/ITeeExtensionRegistry.sol";
import { ITeeExtensionStateVerifier } from "../../../../contracts/userInterfaces/tee/ITeeExtensionStateVerifier.sol";
import { ITeeVerification } from "../../../../contracts/userInterfaces/tee/ITeeVerification.sol";
import { ITeeReplication } from "../../../../contracts/userInterfaces/tee/ITeeReplication.sol";
import { ITeeWalletKeyManager } from "../../../../contracts/userInterfaces/tee/ITeeWalletKeyManager.sol";
import { ITeeWalletProjectManager } from "../../../../contracts/userInterfaces/tee/ITeeWalletProjectManager.sol";
import { IFtdcHub } from "../../../../contracts/userInterfaces/ftdc/IFtdcHub.sol";
import { IFtdcVerification } from "../../../../contracts/userInterfaces/ftdc/IFtdcVerification.sol";
import { ITeeAvailabilityCheck } from "../../../../contracts/userInterfaces/ftdc/ITeeAvailabilityCheck.sol";
import {
    IPMWMultisigAccountConfigured,
    PMW_MULTISIG_ACCOUNT_CONFIGURED_ATTESTATION_TYPE
} from "../../../../contracts/userInterfaces/ftdc/IPMWMultisigAccountConfigured.sol";
import { ProtocolsV2Interface } from "../../../../contracts/userInterfaces/LTS/ProtocolsV2Interface.sol";
import { RandomNumberV2Interface } from "../../../../contracts/userInterfaces/LTS/RandomNumberV2Interface.sol";
import { IGovernanceSettings} from "flare-smart-contracts/contracts/userInterfaces/IGovernanceSettings.sol";

// solhint-disable-next-line max-states-count
contract TeeVerificationTest is Test {

    TeeVerification private teeVerification;
    TeeVerification private teeVerificationImpl;
    TeeVerificationProxy private teeVerificationProxy;

    address private initialGovernance;
    address private addressUpdater;
    address private relay;
    address private teeMachineRegistry;
    address private teeReplication;
    address private teeExtensionRegistry;
    address private ftdcHub;
    address private flareSystemsManager;
    address private ftdcVerification;
    address private teeWalletManager;
    address private teeWalletKeyManager;
    address private teeWalletProjectManager;
    address private teeSystemStateVerifier;

    address private owner;
    address private teeId;
    uint256 private randomNumber;
    uint256 private extensionId;
    ITeeAvailabilityCheck.Proof private proof;
    string private url;
    uint256 private rewardEpochId;
    address[] private cosigners;
    bytes32 private walletId;
    string private walletAddress;
    uint64[] private keyIds;
    IPMWMultisigAccountConfigured.Proof private pmwProof;
    bytes32 private sourceId;
    uint64 private multisigThreshold;
    bytes private publicKey;
    bytes32 private opType;
    uint32 private signingPolicyId;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;


    function setUp() public {
        owner = makeAddr("owner");
        teeId = makeAddr("teeId");
        extensionId = 0;
        url = "url";
        sourceId = bytes32("TEE");
        multisigThreshold = 1;
        opType = keccak256("OP_TYPE");
        publicKey = abi.encode("publicKey");
        signingPolicyId = 1;
        rewardEpochId = 1;

        proof.requestBody.teeId = teeId;
        proof.responseBody.status = ITeeAvailabilityCheck.AvailabilityCheckStatus.OK;
        proof.header.thresholdBIPS = 0;
        proof.header.attestationType = bytes32("TeeAvailabilityCheck");
        proof.header.sourceId = sourceId;
        proof.requestBody.url = url;
        proof.responseBody.initialSigningPolicyId = signingPolicyId;
        proof.responseBody.codeHash = keccak256("codeHash");
        proof.responseBody.platform = keccak256("platform");
        proof.responseBody.lastSigningPolicyId = uint32(rewardEpochId);

        pmwProof.header.thresholdBIPS = 0;
        pmwProof.header.attestationType = PMW_MULTISIG_ACCOUNT_CONFIGURED_ATTESTATION_TYPE;
        pmwProof.header.sourceId = sourceId;
        pmwProof.requestBody.publicKeys = new bytes[](1);
        pmwProof.requestBody.publicKeys[0] = publicKey;
        pmwProof.responseBody.status = IPMWMultisigAccountConfigured.PMWMultisigAccountStatus.OK;
        pmwProof.requestBody.threshold = multisigThreshold;

        walletId = keccak256("walletId");
        walletAddress = "walletAddress";

        cosigners = new address[](2);
        cosigners[0] = makeAddr("cosigner1");
        cosigners[1] = makeAddr("cosigner2");
        keyIds = new uint64[](1);
        keyIds[0] = 1;

        initialGovernance = makeAddr("initialGovernance");
        addressUpdater = makeAddr("addressUpdater");

        teeVerificationImpl = new TeeVerification();
        testInitialize();
        teeVerification = TeeVerification(address(teeVerificationProxy));

        contractNameHashes = new bytes32[](12);
        contractAddresses = new address[](12);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("TeeExtensionRegistry"));
        contractNameHashes[2] = keccak256(abi.encode("TeeMachineRegistry"));
        contractNameHashes[3] = keccak256(abi.encode("TeeWalletProjectManager"));
        contractNameHashes[4] = keccak256(abi.encode("TeeWalletManager"));
        contractNameHashes[5] = keccak256(abi.encode("TeeWalletKeyManager"));
        contractNameHashes[6] = keccak256(abi.encode("TeeSystemStateVerifier"));
        contractNameHashes[7] = keccak256(abi.encode("TeeReplication"));
        contractNameHashes[8] = keccak256(abi.encode("FtdcHub"));
        contractNameHashes[9] = keccak256(abi.encode("FtdcVerification"));
        contractNameHashes[10] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[11] = keccak256(abi.encode("Relay"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = makeAddr("TeeExtensionRegistry");
        contractAddresses[2] = makeAddr("TeeMachineRegistry");
        contractAddresses[3] = makeAddr("TeeWalletProjectManager");
        contractAddresses[4] = makeAddr("TeeWalletManager");
        contractAddresses[5] = makeAddr("TeeWalletKeyManager");
        contractAddresses[6] = makeAddr("TeeSystemStateVerifier");
        contractAddresses[7] = makeAddr("TeeReplication");
        contractAddresses[8] = makeAddr("FtdcHub");
        contractAddresses[9] = makeAddr("FtdcVerification");
        contractAddresses[10] = makeAddr("FlareSystemsManager");
        contractAddresses[11] = makeAddr("Relay");

        vm.prank(addressUpdater);
        teeVerification.updateContractAddresses(contractNameHashes, contractAddresses);

        relay = address(teeVerification.relay());
        teeMachineRegistry = address(teeVerification.teeMachineRegistry());
        teeReplication = address(teeVerification.teeReplication());
        teeExtensionRegistry = address(teeVerification.teeExtensionRegistry());
        ftdcHub = address(teeVerification.ftdcHub());
        flareSystemsManager = address(teeVerification.flareSystemsManager());
        ftdcVerification = address(teeVerification.ftdcVerification());
        teeWalletManager = address(teeVerification.teeWalletManager());
        teeWalletKeyManager = address(teeVerification.teeWalletKeyManager());
        teeWalletProjectManager = address(teeVerification.teeWalletProjectManager());
        teeSystemStateVerifier = address(teeVerification.teeSystemStateVerifier());

        _mockGetReplicatingTeeId(teeId);
        _mockGetExtensionId(extensionId);
        _mockGetTeeMachineStatus(ITeeMachineRegistry.TeeStatus.PRODUCTION);
        _mockIsCodeHashPlatformSupported(true);
        _mockVerifySigningPolicySignatures(rewardEpochId);
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.PRODUCTION);
        _mockGetCurrentRewardEpochId(uint24(rewardEpochId));
        _mockVerifyTeeSystemState(true);
        _mockGetTeeExtensionStateVerifier(address(0));
        _mockVerifyCosignerSignatures(cosigners);

        vm.mockCall(
            relay,
            abi.encodeWithSelector(
                RandomNumberV2Interface.getRandomNumber.selector
            ),
            abi.encode(randomNumber, true, 1)
        );

        vm.mockCall(
            teeMachineRegistry,
            abi.encodeWithSelector(
                ITeeMachineRegistry.getTeeMachineWithAttestationData.selector
            ),
            abi.encode(ITeeMachineRegistry.TeeMachineWithAttestationData(
                teeId,
                teeId,
                url,
                proof.responseBody.codeHash,
                proof.responseBody.platform
            ))
        );

        vm.mockCall(
            teeExtensionRegistry,
            abi.encodeWithSelector(
                ITeeExtensionRegistry.sendInstructions.selector
            ),
            abi.encode("")
        );

        vm.mockCall(
            teeMachineRegistry,
            abi.encodeWithSelector(
                ITeeMachineRegistry.getTeeMachine.selector
            ),
            abi.encode(ITeeMachineRegistry.TeeMachine(teeId, teeId, url))
        );

        vm.mockCall(
            ftdcHub,
            abi.encodeWithSelector(
                IFtdcHub.requestAttestation.selector
            ),
            abi.encode("")
        );

        vm.mockCall(
            teeWalletKeyManager,
            abi.encodeWithSelector(
                ITeeWalletKeyManager.getWalletKeysInfo.selector
            ),
            abi.encode(multisigThreshold, keyIds, 1)
        );

        vm.mockCall(
            teeWalletManager,
            abi.encodeWithSelector(
                ITeeWalletManager.getWalletProjectId.selector
            ),
            abi.encode(1)
        );

        vm.mockCall(
            teeWalletProjectManager,
            abi.encodeWithSelector(
                ITeeWalletProjectManager.getOpType.selector
            ),
            abi.encode(opType)
        );

        vm.mockCall(
            teeWalletKeyManager,
            abi.encodeWithSelector(
                ITeeWalletKeyManager.getWalletKeyPublicKey.selector
            ),
            abi.encode(publicKey)
        );

        vm.mockCall(
            teeMachineRegistry,
            abi.encodeWithSelector(
                ITeeMachineRegistry.getInitialSigningPolicyId.selector
            ),
            abi.encode(signingPolicyId)
        );

        vm.mockCall(
            teeMachineRegistry,
            abi.encodeWithSelector(
                ITeeMachineRegistry.getTeeMachineOwner.selector
            ),
            abi.encode(owner)
        );
    }


    // initialize
    function testInitializeRevertInvalidDurationAvailability() public {
        vm.expectRevert(ITeeVerification.InvalidDuration.selector);
        teeVerificationProxy = new TeeVerificationProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            initialGovernance,
            addressUpdater,
            1,
            1,
            1,
            address(teeVerificationImpl)
        );
    }


    function testInitializeRevertInvalidDurationSigningPolicy() public {
        vm.expectRevert(ITeeVerification.InvalidDuration.selector);
        teeVerificationProxy = new TeeVerificationProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            initialGovernance,
            addressUpdater,
            1 hours,
            0,
            1,
            address(teeVerificationImpl)
        );
    }

    function testInitializeRevertInvalidDurationChallenge() public {
        vm.expectRevert(ITeeVerification.InvalidDuration.selector);
        teeVerificationProxy = new TeeVerificationProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            initialGovernance,
            addressUpdater,
            1 hours,
            1,
            1,
            address(teeVerificationImpl)
        );
    }


    function testInitialize() public {
        vm.expectEmit();
        emit ITeeVerification.SettingsUpdated(1 hours, 1, 1 minutes);
        teeVerificationProxy = new TeeVerificationProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            initialGovernance,
            addressUpdater,
            1 hours,
            1,
            1 minutes,
            address(teeVerificationImpl)
        );
    }


    // requestTeeAttestation
    function testRequestTeeAttestation() public {
        bytes32 challenge = bytes32(0);
        vm.expectEmit();
        emit ITeeVerification.TeeAttestationRequested(teeId, challenge);
        teeVerification.requestTeeAttestation(teeId);

        vm.warp(2 minutes);
        challenge = keccak256(abi.encode(teeId, block.timestamp, randomNumber));
        vm.expectEmit();
        emit ITeeVerification.TeeAttestationRequested(teeId, challenge);
        teeVerification.requestTeeAttestation(teeId);
    }


    // requestAvailabilityCheckAttestation
    function testRequestAvailabilityCheckAttestationRevertChallengeExpired() public {
        vm.warp(2 hours);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeVerification.ChallengeExpired.selector,
                0
            )
        );
        teeVerification.requestAvailabilityCheckAttestation(teeId, teeId);
    }


    function testRequestAvailabilityCheckAttestation() public {
        _mockGetTeeMachineStatus(ITeeMachineRegistry.TeeStatus.INITIALIZED);
        _mockGetReplicatingTeeId(address(0));
        teeVerification.requestAvailabilityCheckAttestation(teeId, teeId);
    }


    // confirmAvailability
    function testConfirmAvailabilityRevertTeeMachineNotAvailable() public {
        _mockGetTeeMachineStatus(ITeeMachineRegistry.TeeStatus.PAUSED);
        vm.expectRevert(ITeeVerification.TeeMachineNotAvailable.selector);
        teeVerification.confirmAvailability(proof);
    }


    function testConfirmAvailabilityRevertInvalidAvailabilityCheckStatus() public {
        proof.responseBody.status = ITeeAvailabilityCheck.AvailabilityCheckStatus.OBSOLETE;
        vm.expectRevert(ITeeVerification.InvalidAvailabilityCheckStatus.selector);
        teeVerification.confirmAvailability(proof);

    }


    function testConfirmAvailabilityRevertVersionNotSupported() public {
        _mockIsCodeHashPlatformSupported(false);
        vm.expectRevert(ITeeVerification.VersionNotSupported.selector);
        teeVerification.confirmAvailability(proof);

    }

    function testConfirmAvailabilityRevertInvalidAttestation1() public {
        proof.header.thresholdBIPS = 1;
        vm.expectRevert(ITeeVerification.InvalidAttestation.selector);
        teeVerification.confirmAvailability(proof);
    }

    function testConfirmAvailabilityRevertInvalidAttestation2() public {
        proof.header.attestationType = keccak256("invalidAttestationType");
        vm.expectRevert(ITeeVerification.InvalidAttestation.selector);
        teeVerification.confirmAvailability(proof);
    }

    function testConfirmAvailabilityRevertInvalidAttestation3() public {
        proof.header.sourceId = keccak256("invalidSourceId");
        vm.expectRevert(ITeeVerification.InvalidAttestation.selector);
        teeVerification.confirmAvailability(proof);
    }

    function testConfirmAvailabilityRevertAvailabilityCheckTimestampInvalid() public {
        vm.warp(0);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeVerification.AvailabilityCheckTimestampInvalid.selector,
                0
            )
        );
        teeVerification.confirmAvailability(proof);
    }

    function testConfirmAvailabilityRevertChallengeExpired() public {
        vm.warp(2 hours);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeVerification.ChallengeExpired.selector,
                0
            )
        );
        teeVerification.confirmAvailability(proof);
    }

    function testConfirmAvailabilityRevertInvalidSigningPolicy() public {
        _mockVerifySigningPolicySignatures(rewardEpochId + 2);
        vm.expectRevert(ITeeVerification.InvalidSigningPolicy.selector);
        teeVerification.confirmAvailability(proof);
    }

    function testConfirmAvailabilityRevertInvalidInitialSigningPolicy() public {
        proof.responseBody.initialSigningPolicyId = signingPolicyId + 1;
        vm.expectRevert(ITeeVerification.InvalidInitialSigningPolicy.selector);
        teeVerification.confirmAvailability(proof);
    }

    function testConfirmAvailabilityRevertAvailabilityCheckValidityExpired() public {
        _mockGetCurrentRewardEpochId(uint24(rewardEpochId + 100));
        _mockVerifySigningPolicySignatures(rewardEpochId + 100);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeVerification.AvailabilityCheckValidityExpired.selector,
                0
            )
        );
        teeVerification.confirmAvailability(proof);
    }


    function testConfirmAvailabilityRevertInvalidResponseData() public {
        _mockVerifyTeeSystemState(false);
        vm.expectRevert(ITeeVerification.InvalidResponseData.selector);
        teeVerification.confirmAvailability(proof);
    }


    function testConfirmAvailability() public {
        vm.expectEmit();
        emit ITeeVerification.AvailabilityCheckValidityExtended(
            teeId,
            owner,
            proof.header.timestamp + 1 hours
        );
        teeVerification.confirmAvailability(proof);
    }


    // verifyAvailabilityCheckProof
    function testVerifyAvailabilityCheckProofRevertCosignersThresholdNotMet() public {
        testSetCosigners();
        _mockVerifyCosignerSignatures(new address[](0));
        _mockGetTeeMachineStatus(ITeeMachineRegistry.TeeStatus.INITIALIZED);
        vm.expectRevert(ITeeVerification.CosignersThresholdNotMet.selector);
        teeVerification.verifyAvailabilityCheckProof(proof);
    }


    function testVerifyAvailabilityCheckProofRevertInvalidCosigner() public {
        testSetCosigners();
        address[] memory invalidCosigners = new address[](1);
        invalidCosigners[0] = makeAddr("invalidCosigner");
        _mockVerifyCosignerSignatures(invalidCosigners);
        _mockGetTeeMachineStatus(ITeeMachineRegistry.TeeStatus.INITIALIZED);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeVerification.InvalidCosigner.selector,
                invalidCosigners[0]
            )
        );
        teeVerification.verifyAvailabilityCheckProof(proof);
    }


    function testVerifyAvailabilityCheckProofRevertInvalidInitialSigningPolicy() public {
        proof.responseBody.initialSigningPolicyId = uint32(rewardEpochId + 1);
        _mockGetTeeMachineStatus(ITeeMachineRegistry.TeeStatus.INITIALIZED);
        vm.expectRevert(ITeeVerification.InvalidInitialSigningPolicy.selector);
        teeVerification.verifyAvailabilityCheckProof(proof);
    }

    // header.timestamp >= block.timestamp
    function testVerifyAvailabilityCheckRevertTimestampInvalid1() public {
        testRequestTeeAttestation();
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeVerification.AvailabilityCheckTimestampInvalid.selector,
                120
            )
        );
        teeVerification.verifyAvailabilityCheckProof(proof);
    }

    // header.timestamp < challengeTs[teeId]
    function testVerifyAvailabilityCheckRevertTimestampInvalid2() public {
        proof.header.timestamp = 1;
        // block.timestamp == 0
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeVerification.AvailabilityCheckTimestampInvalid.selector,
                0
            )
        );
        teeVerification.verifyAvailabilityCheckProof(proof);
    }

    function testVerifyAvailabilityCheckRevertInvalidRequestBody1() public {
        proof.requestBody.url = "invalidUrl";
        vm.expectRevert(ITeeVerification.InvalidRequestBody.selector);
        teeVerification.verifyAvailabilityCheckProof(proof);
    }

    function testVerifyAvailabilityCheckRevertInvalidRequestBody2() public {
        proof.requestBody.challenge = keccak256("invalidChallenge");
        vm.expectRevert(ITeeVerification.InvalidRequestBody.selector);
        teeVerification.verifyAvailabilityCheckProof(proof);
    }

    // initialSigningPolicyId > currentRewardEpochId
    // machine status == INITIALIZED
    function testVerifyAvailabilityCheckRevertInvalidInitialSigningPolicy1() public {
        _mockGetTeeMachineStatus(ITeeMachineRegistry.TeeStatus.INITIALIZED);
        // currentRewardEpochId == 1
        proof.responseBody.initialSigningPolicyId = 2;
        vm.expectRevert(ITeeVerification.InvalidInitialSigningPolicy.selector);
        teeVerification.verifyAvailabilityCheckProof(proof);
    }

    // initialSigningPolicyId + signingPolicyValidityDurationInRewardEpochs (== 1) < currentRewardEpochId
    // machine status == INITIALIZED
    function testVerifyAvailabilityCheckRevertInvalidInitialSigningPolicy2() public {
        _mockGetTeeMachineStatus(ITeeMachineRegistry.TeeStatus.INITIALIZED);
        _mockGetCurrentRewardEpochId(10);
        _mockVerifySigningPolicySignatures(10);
        proof.responseBody.initialSigningPolicyId = 1;
        vm.expectRevert(ITeeVerification.InvalidInitialSigningPolicy.selector);
        teeVerification.verifyAvailabilityCheckProof(proof);
    }

    // machine status != INITIALIZED
    function testVerifyAvailabilityCheckRevertInvalidInitialSigningPolicy3() public {
        proof.responseBody.initialSigningPolicyId = signingPolicyId + 1;
        vm.expectRevert(ITeeVerification.InvalidInitialSigningPolicy.selector);
        teeVerification.verifyAvailabilityCheckProof(proof);
    }

    function testVerifyAvailabilityCheckRevertAvailabilityCheckValidityExpired() public {
        _mockGetCurrentRewardEpochId(uint24(rewardEpochId + 100));
        _mockVerifySigningPolicySignatures(rewardEpochId + 100);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeVerification.AvailabilityCheckValidityExpired.selector,
                0
            )
        );
        teeVerification.verifyAvailabilityCheckProof(proof);
    }

    // true
    function testVerifyAvailabilityCheckProof1() public {
        testSetCosigners();
        assertTrue(teeVerification.verifyAvailabilityCheckProof(proof));
    }

    // codeHash doesn't match
    function testVerifyAvailabilityCheckProof2() public {
        testSetCosigners();
        proof.responseBody.codeHash = keccak256("invalidCodeHash");
        assertFalse(teeVerification.verifyAvailabilityCheckProof(proof));
    }

    // platform doesn't match
    function testVerifyAvailabilityCheckProof3() public {
        testSetCosigners();
        proof.responseBody.platform = keccak256("invalidPlatform");
        assertFalse(teeVerification.verifyAvailabilityCheckProof(proof));
    }

    // lastSigningPolicyId is too old
    function testVerifyAvailabilityCheckProof4() public {
        vm.prank(initialGovernance);
        teeVerification.updateSettings(1 hours, 4, 1 minutes);
        testSetCosigners();
        _mockGetTeeMachineStatus(ITeeMachineRegistry.TeeStatus.INITIALIZED);
        _mockGetCurrentRewardEpochId(uint24(rewardEpochId + 2));
        _mockVerifySigningPolicySignatures(rewardEpochId + 2);
        proof.responseBody.lastSigningPolicyId = uint32(rewardEpochId);
        assertFalse(teeVerification.verifyAvailabilityCheckProof(proof));
    }

    //  verifyTeeSystemState -> false
    function testVerifyAvailabilityCheckProof5() public {
        testSetCosigners();
        _mockVerifyTeeSystemState(false);
        assertFalse(teeVerification.verifyAvailabilityCheckProof(proof));
    }

    // address(teeStateVerifier) != address(0) && verifyTeeState -> false
    function testVerifyAvailabilityCheckProof6() public {
        testSetCosigners();
        address teeStateVerifier = makeAddr("teeStateVerifier");
        _mockGetTeeExtensionStateVerifier(teeStateVerifier);
        vm.mockCall(
            teeStateVerifier,
            abi.encodeWithSelector(
                ITeeExtensionStateVerifier.verifyTeeState.selector
            ),
            abi.encode(false)
        );
        assertFalse(teeVerification.verifyAvailabilityCheckProof(proof));
    }

    // address(teeStateVerifier) == address(0) && state.stateVersion != bytes32(0)
    function testVerifyAvailabilityCheckProof7() public {
        testSetCosigners();
        proof.responseBody.state.stateVersion = bytes32("stateVersion");
        assertFalse(teeVerification.verifyAvailabilityCheckProof(proof));
    }

    // address(teeStateVerifier) == address(0) && state.state.length != 0
    function testVerifyAvailabilityCheckProof8() public {
        testSetCosigners();
        proof.responseBody.state.state = "state";
        assertFalse(teeVerification.verifyAvailabilityCheckProof(proof));
    }

    // address(teeStateVerifier) != address(0) && verifyTeeState -> true
    function testVerifyAvailabilityCheckProof9() public {
        testSetCosigners();
        address teeStateVerifier = makeAddr("teeStateVerifier");
        _mockGetTeeExtensionStateVerifier(teeStateVerifier);
        vm.mockCall(
            teeStateVerifier,
            abi.encodeWithSelector(
                ITeeExtensionStateVerifier.verifyTeeState.selector
            ),
            abi.encode(true)
        );
        assertTrue(teeVerification.verifyAvailabilityCheckProof(proof));
    }

    // requestPMWMultisigAccountConfiguredAttestation
    function testRequestPMWMultisigAccountConfiguredAttestationRevertAccountAddressZero() public {
        walletAddress = "";
        vm.expectRevert(ITeeVerification.AccountAddressZero.selector);
        teeVerification.requestPMWMultisigAccountConfiguredAttestation(walletId, sourceId, walletAddress, teeId);
    }


    function testRequestPMWMultisigAccountConfiguredAttestationRevertOnlyProductionOrPausedStatus() public {
        _mockGetWalletStatus(ITeeWalletManager.WalletStatus.INITIALIZED);
        vm.expectRevert(ITeeVerification.OnlyProductionOrPausedStatus.selector);
        teeVerification.requestPMWMultisigAccountConfiguredAttestation(walletId, sourceId, walletAddress, teeId);
    }


    function testRequestPMWMultisigAccountConfiguredAttestation() public {
        teeVerification.requestPMWMultisigAccountConfiguredAttestation(walletId, sourceId, walletAddress, teeId);
    }


    // verifyPMWMultisigAccountConfiguredProof
    function testVerifyPMWMultisigAccountConfiguredProofRevertInvalidAttestation() public {
        pmwProof.header.thresholdBIPS = 1;
        vm.expectRevert(ITeeVerification.InvalidAttestation.selector);
        teeVerification.verifyPMWMultisigAccountConfiguredProof(walletId, pmwProof);
    }


    function testVerifyPMWMultisigAccountConfiguredProofRevertInvalidAttestation2() public {
        pmwProof.header.attestationType = bytes32("invalidAttestationType");
        vm.expectRevert(ITeeVerification.InvalidAttestation.selector);
        teeVerification.verifyPMWMultisigAccountConfiguredProof(walletId, pmwProof);
    }


    function testVerifyPMWMultisigAccountConfiguredProofRevertInvalidRequestBody1() public {
        pmwProof.requestBody.threshold = multisigThreshold + 1;
        vm.expectRevert(ITeeVerification.InvalidRequestBody.selector);
        teeVerification.verifyPMWMultisigAccountConfiguredProof(walletId, pmwProof);
    }


    function testVerifyPMWMultisigAccountConfiguredProofRevertInvalidRequestBody2() public {
        pmwProof.requestBody.publicKeys[0] = abi.encode("invalidPublicKey");
        vm.expectRevert(ITeeVerification.InvalidRequestBody.selector);
        teeVerification.verifyPMWMultisigAccountConfiguredProof(walletId, pmwProof);
    }


    function testVerifyPMWMultisigAccountConfiguredProof() public {
        bool isVerified =
            teeVerification.verifyPMWMultisigAccountConfiguredProof(walletId, pmwProof);
        assertEq(isVerified, true);
        pmwProof.responseBody.status = IPMWMultisigAccountConfigured.PMWMultisigAccountStatus.ERROR;
        isVerified =
            teeVerification.verifyPMWMultisigAccountConfiguredProof(walletId, pmwProof);
        assertEq(isVerified, false);
    }


    // setCosigners
    function testSetCosignersRevertOnlyGovernance() public {
        vm.expectRevert("only governance");
        teeVerification.setCosigners(cosigners, 10);
    }


    // cosigners.length < threshold
    function testSetCosignersRevertInvalidThreshold1() public {
        vm.prank(initialGovernance);
        vm.expectRevert(ITeeVerification.InvalidThreshold.selector);
        teeVerification.setCosigners(cosigners, 10);
    }

    // cosigners.length != 0 && threshold == 0
    function testSetCosignersRevertInvalidThreshold2() public {
        vm.prank(initialGovernance);
        vm.expectRevert(ITeeVerification.InvalidThreshold.selector);
        teeVerification.setCosigners(cosigners, 0);
    }


    function testSetCosignersRevertInvalidCosigner() public {
        cosigners[0] = address(0);
        vm.prank(initialGovernance);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeVerification.InvalidCosigner.selector,
                cosigners[0]
            )
        );
        teeVerification.setCosigners(cosigners, 1);
    }

    function testSetCosignersRevertDuplicatedCosigner() public {
        cosigners[1] = cosigners[0];
        vm.prank(initialGovernance);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeVerification.DuplicatedCosigner.selector,
                cosigners[1]
            )
        );
        teeVerification.setCosigners(cosigners, 1);
    }


    function testSetCosigners() public {
        vm.prank(initialGovernance);
        vm.expectEmit();
        emit ITeeVerification.CosignersSet(cosigners, 1);
        teeVerification.setCosigners(cosigners, 1);
    }


    // updateSettings
    function testUpdateSettingsRevertOnlyGovernance() public {
        vm.expectRevert("only governance");
        teeVerification.updateSettings(1, 1, 1);
    }


    function testUpdateSettings() public {
        vm.prank(initialGovernance);
        vm.expectEmit();
        emit ITeeVerification.SettingsUpdated(1 hours, 1, 1 minutes);
        teeVerification.updateSettings(1 hours, 1, 1 minutes);
    }


    // getCosigners
    function testGetCosigners() public {
        (address[] memory returnedCosigners, uint64 returnedCosignersThreshold) =
            teeVerification.getCosigners();
        assertEq(returnedCosigners.length, 0);
        assertEq(returnedCosignersThreshold, 0);

        testSetCosigners();
        (returnedCosigners, returnedCosignersThreshold) = teeVerification.getCosigners();
        assertEq(returnedCosigners.length, 2);
        assertEq(returnedCosigners[0], cosigners[0]);
        assertEq(returnedCosigners[1], cosigners[1]);
        assertEq(returnedCosignersThreshold, 1);
    }


    // getSettings
    function testGetSettings() public {
        (uint256 availabilityCheck, uint256 challenge) = teeVerification.getSettings();
        assertEq(availabilityCheck, 1 hours);
        assertEq(challenge, 1 minutes);
    }


    function _mockGetReplicatingTeeId(address _teeId) private {
        vm.mockCall(
            teeReplication,
            abi.encodeWithSelector(
                ITeeReplication.getReplicatingTeeId.selector
            ),
            abi.encode(_teeId)
        );
    }


    function _mockGetExtensionId(uint256 _extensionId) private {
        vm.mockCall(
            teeMachineRegistry,
            abi.encodeWithSelector(
                ITeeMachineRegistry.getExtensionId.selector
            ),
            abi.encode(_extensionId)
        );
    }


    function _mockGetTeeMachineStatus(ITeeMachineRegistry.TeeStatus _status) private {
        vm.mockCall(
            teeMachineRegistry,
            abi.encodeWithSelector(
                ITeeMachineRegistry.getTeeMachineStatus.selector
            ),
            abi.encode(_status)
        );
    }


    function _mockIsCodeHashPlatformSupported(bool _isSupported) private {
        vm.mockCall(
            teeExtensionRegistry,
            abi.encodeWithSelector(
                ITeeExtensionRegistry.isCodeHashPlatformSupported.selector
            ),
            abi.encode(_isSupported)
        );
    }


    function _mockVerifySigningPolicySignatures(uint256 _rewardEpochId) private {
        vm.mockCall(
            ftdcVerification,
            abi.encodeWithSelector(
                IFtdcVerification.verifySigningPolicySignatures.selector
            ),
            abi.encode(_rewardEpochId)
        );
    }


    function _mockVerifyCosignerSignatures(address[] memory _cosignersList) private {
        vm.mockCall(
            ftdcVerification,
            abi.encodeWithSelector(
                IFtdcVerification.verifyCosignerSignatures.selector
            ),
            abi.encode(_cosignersList)
        );
    }


    function _mockGetWalletStatus(ITeeWalletManager.WalletStatus _status) private {
        vm.mockCall(
            teeWalletManager,
            abi.encodeWithSelector(
                ITeeWalletManager.getWalletStatus.selector
            ),
            abi.encode(_status)
        );
    }


    function _mockGetCurrentRewardEpochId(uint24 _rewardEpochId) private {
        vm.mockCall(
            flareSystemsManager,
            abi.encodeWithSelector(
                ProtocolsV2Interface.getCurrentRewardEpochId.selector
            ),
            abi.encode(uint24(_rewardEpochId))
        );
    }


    function _mockGetTeeExtensionStateVerifier(address _stateVerifier) private {
        vm.mockCall(
            teeExtensionRegistry,
            abi.encodeWithSelector(
                ITeeExtensionRegistry.getTeeExtensionStateVerifier.selector
            ),
            abi.encode(ITeeExtensionStateVerifier(_stateVerifier))
        );
    }


    function _mockVerifyTeeSystemState(bool _val) private {
        vm.mockCall(
            teeSystemStateVerifier,
            abi.encodeWithSelector(
                IITeeSystemStateVerifier.verifyTeeSystemState.selector
            ),
            abi.encode(_val)
        );
    }
}
