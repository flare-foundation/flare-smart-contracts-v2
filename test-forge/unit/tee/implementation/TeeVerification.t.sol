// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../../../../contracts/tee/implementation/TeeVerification.sol";
import "../../../../contracts/tee/proxy/TeeVerificationProxy.sol";

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
    IPMWMultisigAccountConfigured.Proof private PMWProof;
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

        PMWProof.header.thresholdBIPS = 0;
        PMWProof.header.attestationType = PMW_MULTISIG_ACCOUNT_CONFIGURED_ATTESTATION_TYPE;
        PMWProof.header.sourceId = sourceId;
        PMWProof.requestBody.publicKeys = new bytes[](1);
        PMWProof.requestBody.publicKeys[0] = publicKey;
        PMWProof.responseBody.status = IPMWMultisigAccountConfigured.PMWMultisigAccountStatus.OK;
        PMWProof.requestBody.threshold = multisigThreshold;

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
        _mockGetTeeExtensionStateVerifier();
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


    function testRequestAvailabilityCheckAttestationRevertInvalidExtension() public {
        _mockGetExtensionId(extensionId + 1);
        vm.expectRevert(ITeeVerification.InvalidExtension.selector);
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


    function testConfirmAvailabilityRevertInvalidAttestation() public {
        proof.header.thresholdBIPS = 1;
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


    function testConfirmAvailabilityRevertInvalidRequestBody() public {
        proof.requestBody.url = "invalidUrl";
        vm.expectRevert(ITeeVerification.InvalidRequestBody.selector);
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


    function testVerifyAvailabilityCheckProof() public {
        testSetCosigners();
        _mockGetTeeMachineStatus(ITeeMachineRegistry.TeeStatus.INITIALIZED);
        bool isValid = teeVerification.verifyAvailabilityCheckProof(proof);
        assertTrue(isValid);
    }


    // requestPMWMultisigAccountConfiguredAttestation
    function testRequestPMWMultisigAccountConfiguredAttestationRevertWalletAddressZero() public {
        walletAddress = "";
        vm.expectRevert(ITeeVerification.WalletAddressZero.selector);
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
        vm.expectRevert(ITeeVerification.InvalidAttestation.selector);
        teeVerification.verifyPMWMultisigAccountConfiguredProof(walletId, walletId, PMWProof);
    }


    function testVerifyPMWMultisigAccountConfiguredProofRevertInvalidRequestBody1() public {
        PMWProof.requestBody.threshold = multisigThreshold + 1;
        vm.expectRevert(ITeeVerification.InvalidRequestBody.selector);
        teeVerification.verifyPMWMultisigAccountConfiguredProof(walletId, sourceId, PMWProof);
    }


    function testVerifyPMWMultisigAccountConfiguredProofRevertInvalidRequestBody2() public {
        PMWProof.requestBody.publicKeys[0] = abi.encode("invalidPublicKey");
        vm.expectRevert(ITeeVerification.InvalidRequestBody.selector);
        teeVerification.verifyPMWMultisigAccountConfiguredProof(walletId, sourceId, PMWProof);
    }


    function testVerifyPMWMultisigAccountConfiguredProof() public {
        bool isVerified =
            teeVerification.verifyPMWMultisigAccountConfiguredProof(walletId, sourceId, PMWProof);
        assertEq(isVerified, true);
        PMWProof.responseBody.status = IPMWMultisigAccountConfigured.PMWMultisigAccountStatus.ERROR;
        isVerified =
            teeVerification.verifyPMWMultisigAccountConfiguredProof(walletId, sourceId, PMWProof);
        assertEq(isVerified, false);
    }


    // setCosigners
    function testSetCosignersRevertOnlyGovernance() public {
        vm.expectRevert("only governance");
        teeVerification.setCosigners(cosigners, 10);
    }


    function testSetCosignersRevertInvalidThreshold() public {
        vm.prank(initialGovernance);
        vm.expectRevert(ITeeVerification.InvalidThreshold.selector);
        teeVerification.setCosigners(cosigners, 10);
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


    function _mockGetTeeExtensionStateVerifier() private {
        vm.mockCall(
            teeExtensionRegistry,
            abi.encodeWithSelector(
                ITeeExtensionRegistry.getTeeExtensionStateVerifier.selector
            ),
            abi.encode(ITeeExtensionStateVerifier(address(0)))
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
