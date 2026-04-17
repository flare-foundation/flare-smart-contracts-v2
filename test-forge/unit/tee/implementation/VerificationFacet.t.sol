// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test, Vm } from "forge-std/Test.sol";
import { FlareTeeManagerDeployer } from "../../../utils/FlareTeeManagerDeployer.sol";
import { IIFlareTeeManager } from "../../../../contracts/tee/interface/IIFlareTeeManager.sol";
import {
    IVerificationFacet
} from "../../../../contracts/userInterfaces/tee/IVerificationFacet.sol";
import { IMachineManagerFacet } from "../../../../contracts/userInterfaces/tee/IMachineManagerFacet.sol";
import { IInstructionsFacet } from "../../../../contracts/userInterfaces/tee/IInstructionsFacet.sol";
import { IWalletManagerFacet } from "../../../../contracts/userInterfaces/tee/IWalletManagerFacet.sol";
import { ITeeExtensionStateVerifier } from "../../../../contracts/userInterfaces/tee/ITeeExtensionStateVerifier.sol";
import { IFdc2Hub } from "../../../../contracts/userInterfaces/fdc2/IFdc2Hub.sol";
import { IFdc2Verification } from "../../../../contracts/userInterfaces/fdc2/IFdc2Verification.sol";
import { ITeeAvailabilityCheck } from "../../../../contracts/userInterfaces/fdc2/ITeeAvailabilityCheck.sol";
import {
    IPMWMultisigAccountConfigured,
    PMW_MULTISIG_ACCOUNT_CONFIGURED_ATTESTATION_TYPE
} from "../../../../contracts/userInterfaces/fdc2/IPMWMultisigAccountConfigured.sol";
import { ProtocolsV2Interface } from "../../../../contracts/userInterfaces/LTS/ProtocolsV2Interface.sol";
import { RandomNumberV2Interface } from "../../../../contracts/userInterfaces/LTS/RandomNumberV2Interface.sol";
import { IFlareGovernance } from "../../../../contracts/userInterfaces/tee/IFlareGovernance.sol";
import { ITeeCommonErrors } from "../../../../contracts/userInterfaces/tee/ITeeCommonErrors.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import { Signature } from "../../../../contracts/userInterfaces/ISignature.sol";
import { PublicKey } from "../../../../contracts/userInterfaces/IPublicKey.sol";
import { IDiamond } from "../../../../contracts/diamond/interfaces/IDiamond.sol";
import { IDiamondCut } from "../../../../contracts/diamond/interfaces/IDiamondCut.sol";
import { IIRewardManager } from "../../../../contracts/protocol/interface/IIRewardManager.sol";
import { MachineManager } from "../../../../contracts/tee/library/MachineManager.sol";
import { Verification } from "../../../../contracts/tee/library/Verification.sol";
import { Replication } from "../../../../contracts/tee/library/Replication.sol";
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
        IMachineManagerFacet.TeeStatus _status,
        bytes32 _codeHash,
        bytes32 _platform,
        uint32 _initialSigningPolicyId,
        address _initialTeeId
    ) external;

    function setTeeMachineState(
        address _teeId,
        uint256 _extensionId,
        address _owner,
        IMachineManagerFacet.TeeStatus _status
    ) external;

    function setTeeMachineStatus(
        address _teeId,
        IMachineManagerFacet.TeeStatus _status
    ) external;

    function setReplicatingTeeId(
        address _oldTeeId,
        address _newTeeId
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

    function setTeeGovernanceHash(
        uint256 _extensionId,
        bytes32 _codeHash,
        bytes32 _governanceHash
    ) external;

    function setChallenge(
        address _teeId,
        bytes32 _challenge,
        uint256 _challengeTs
    ) external;

    function setWalletState(
        bytes32 _walletId,
        bytes32 _projectId,
        IWalletManagerFacet.WalletStatus _status
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
        IMachineManagerFacet.TeeStatus _status,
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
            lastStatusChangeTs: block.timestamp,
            codeHash: _codeHash,
            platform: _platform,
            url: _url
        });
        if (_status == IMachineManagerFacet.TeeStatus.PRODUCTION) {
            s.activeTeeIds.add(_teeId);
            s.extensionActiveTeeIds[_extensionId].add(_teeId);
        }
    }

    function setTeeMachineState(
        address _teeId,
        uint256 _extensionId,
        address _owner,
        IMachineManagerFacet.TeeStatus _status
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
            lastStatusChangeTs: block.timestamp,
            codeHash: bytes32(0),
            platform: bytes32(0),
            url: ""
        });
        if (_status == IMachineManagerFacet.TeeStatus.PRODUCTION) {
            s.activeTeeIds.add(_teeId);
            s.extensionActiveTeeIds[_extensionId].add(_teeId);
        }
    }

    function setTeeMachineStatus(
        address _teeId,
        IMachineManagerFacet.TeeStatus _status
    )
        external
    {
        MachineManager.State storage s = MachineManager.getState();
        MachineManager.TeeMachineState storage state = s.teeMachineStates[_teeId];
        state.status = _status;
        if (_status == IMachineManagerFacet.TeeStatus.PRODUCTION) {
            s.activeTeeIds.add(_teeId);
            s.extensionActiveTeeIds[state.extensionId].add(_teeId);
        } else {
            s.activeTeeIds.remove(_teeId);
            s.extensionActiveTeeIds[state.extensionId].remove(_teeId);
        }
    }

    function setReplicatingTeeId(
        address _oldTeeId,
        address _newTeeId
    )
        external
    {
        Replication.getState().replicatingTeeIds[_oldTeeId] = _newTeeId;
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

    function setTeeGovernanceHash(
        uint256 _extensionId,
        bytes32 _codeHash,
        bytes32 _governanceHash
    )
        external
    {
        ExtensionManager.getState().extensions[_extensionId]
            .codeHashToVersion[_codeHash].governanceHash = _governanceHash;
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
        IWalletManagerFacet.WalletStatus _status
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

    bytes4 private constant SEND_SYSTEM_INSTRUCTIONS_SELECTOR = bytes4(keccak256(
        "sendSystemInstructions(bytes32,(address,address,string)[],(bytes32,bytes32,bytes,address[],uint64,address))"
    ));

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
    string private walletAddress;
    uint64 private multisigThreshold;
    bytes private publicKey;
    uint64[] private keyIds;
    IPMWMultisigAccountConfigured.Proof private pmwProof;

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

        flareTeeManager = FlareTeeManagerDeployer.deployDay1Facets(FlareTeeManagerDeployer.Day1DeployParams({
            governanceSettings: IGovernanceSettings(makeAddr("governanceSettings")),
            initialGovernance: initialGovernance,
            addressUpdater: addressUpdater,
            availabilityCheckValidityDurationSeconds: 1 hours,
            signingPolicyValidityDurationInRewardEpochs: 1,
            challengeValidityDurationSeconds: 1 minutes,
            defaultFee: 0
        }));
        vm.startPrank(initialGovernance);
        FlareTeeManagerDeployer.deployLaterFacets(flareTeeManager, FlareTeeManagerDeployer.LaterDeployParams({
            pauseBeforeUpgradeMinDurationSeconds: 600
        }));
        vm.stopPrank();

        // Add TestVerificationStateHelper facet to the diamond
        TestVerificationStateHelper helperImpl = new TestVerificationStateHelper();
        bytes4[] memory helperSelectors = new bytes4[](11);
        helperSelectors[0] = bytes4(keccak256(
            "setTeeMachineState(address,uint256,address,address,string,"
            "uint8,bytes32,bytes32,uint32,address)"
        ));
        helperSelectors[1] = ITestVerificationStateHelper.setTeeMachineStatus.selector;
        helperSelectors[2] = ITestVerificationStateHelper.setReplicatingTeeId.selector;
        helperSelectors[3] = ITestVerificationStateHelper.setupCodeHashPlatform.selector;
        helperSelectors[4] = ITestVerificationStateHelper.setExtensionStateVerifier.selector;
        helperSelectors[5] = ITestVerificationStateHelper.setTeeGovernanceHash.selector;
        helperSelectors[6] = ITestVerificationStateHelper.setChallenge.selector;
        helperSelectors[7] = ITestVerificationStateHelper.setWalletState.selector;
        helperSelectors[8] = ITestVerificationStateHelper.setKeyState.selector;
        helperSelectors[9] = bytes4(keccak256(
            "setTeeMachineState(address,uint256,address,uint8)"
        ));
        helperSelectors[10] = bytes4(0); // placeholder, filled below

        // Deduplicate: compute overloaded selectors manually
        bytes4 sel10Param = bytes4(keccak256(
            "setTeeMachineState(address,uint256,address,address,string,"
            "uint8,bytes32,bytes32,uint32,address)"
        ));
        bytes4 sel4Param = bytes4(keccak256(
            "setTeeMachineState(address,uint256,address,uint8)"
        ));

        // Rebuild with only unique selectors (10 total)
        bytes4[] memory uniqueSelectors = new bytes4[](10);
        uniqueSelectors[0] = sel10Param;
        uniqueSelectors[1] = ITestVerificationStateHelper.setTeeMachineStatus.selector;
        uniqueSelectors[2] = ITestVerificationStateHelper.setReplicatingTeeId.selector;
        uniqueSelectors[3] = ITestVerificationStateHelper.setupCodeHashPlatform.selector;
        uniqueSelectors[4] = ITestVerificationStateHelper.setExtensionStateVerifier.selector;
        uniqueSelectors[5] = ITestVerificationStateHelper.setTeeGovernanceHash.selector;
        uniqueSelectors[6] = ITestVerificationStateHelper.setChallenge.selector;
        uniqueSelectors[7] = ITestVerificationStateHelper.setWalletState.selector;
        uniqueSelectors[8] = ITestVerificationStateHelper.setKeyState.selector;
        uniqueSelectors[9] = sel4Param;

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
            IMachineManagerFacet.TeeStatus.PRODUCTION,
            proof.responseBody.codeHash,
            proof.responseBody.platform,
            signingPolicyId,
            teeId // initialTeeId
        );

        // Set up extension with supported code hash + platform
        stateHelper.setupCodeHashPlatform(
            extensionId, proof.responseBody.codeHash, proof.responseBody.platform, true
        );

        // Set replication: teeId maps to teeId (no replication)
        stateHelper.setReplicatingTeeId(teeId, teeId);

        // Mock external contract calls
        _mockVerifySigningPolicySignatures(rewardEpochId);
        _mockGetCurrentRewardEpochId(uint24(rewardEpochId));
        _mockVerifyCosignerSignatures(cosigners);

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
        walletAddress = "rAccountAddress123";
        multisigThreshold = 1;
        publicKey = hex"0123456789abcdef";
        keyIds = new uint64[](1);
        keyIds[0] = 1;

        // Set wallet state
        stateHelper.setWalletState(walletId, projectId, IWalletManagerFacet.WalletStatus.PRODUCTION);

        // Set key state
        stateHelper.setKeyState(walletId, keyIds[0], publicKey, teeId, multisigThreshold);

        // Set up PMW proof fields
        pmwProof.header.thresholdBIPS = 0;
        pmwProof.header.attestationType = PMW_MULTISIG_ACCOUNT_CONFIGURED_ATTESTATION_TYPE;
        pmwProof.requestBody.accountAddress = walletAddress;
        pmwProof.requestBody.threshold = multisigThreshold;
        pmwProof.requestBody.publicKeys = new bytes[](1);
        pmwProof.requestBody.publicKeys[0] = publicKey;
        pmwProof.responseBody.status = IPMWMultisigAccountConfigured.PMWMultisigAccountStatus.OK;
    }

    // =========================================================================
    // Machine verification tests
    // =========================================================================

    // initialize
    function testInitialize() public {
        vm.expectEmit();
        emit IVerificationFacet.SettingsUpdated(1 hours, 1, 1 minutes);
        FlareTeeManagerDeployer.deployDay1Facets(FlareTeeManagerDeployer.Day1DeployParams({
            governanceSettings: IGovernanceSettings(makeAddr("governanceSettings")),
            initialGovernance: initialGovernance,
            addressUpdater: addressUpdater,
            availabilityCheckValidityDurationSeconds: 1 hours,
            signingPolicyValidityDurationInRewardEpochs: 1,
            challengeValidityDurationSeconds: 1 minutes,
            defaultFee: 1000
        }));
    }

    // requestTeeAttestation
    function testRequestTeeAttestation() public {
        bytes32 challenge = bytes32(0);
        vm.expectEmit();
        emit IVerificationFacet.TeeAttestationRequested(teeId, challenge);
        flareTeeManager.requestTeeAttestation(teeId, address(0));

        vm.warp(2 minutes);
        challenge = keccak256(abi.encode(teeId, block.timestamp, randomNumber));
        vm.expectEmit();
        emit IVerificationFacet.TeeAttestationRequested(teeId, challenge);
        flareTeeManager.requestTeeAttestation(teeId, address(0));
    }

    function testRequestTeeAttestationWithClaimBackAddress() public {
        address claimBack = makeAddr("claimBack");
        vm.recordLogs();
        flareTeeManager.requestTeeAttestation(teeId, claimBack);
        // Verify TeeInstructionsSent event carries the claimBackAddress
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bool foundInstructionsSent = false;
        bytes32 instructionsSentTopic = IInstructionsFacet.TeeInstructionsSent.selector;
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
                    (IMachineManagerFacet.TeeMachine[], bytes32, bytes32,
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
                IVerificationFacet.ChallengeExpired.selector,
                0
            )
        );
        flareTeeManager.requestAvailabilityCheckAttestation(teeId, instructionId, teeId, address(0), address(0));
    }

    function testRequestAvailabilityCheckAttestation() public {
        stateHelper.setTeeMachineStatus(teeId, IMachineManagerFacet.TeeStatus.INITIALIZED);
        stateHelper.setReplicatingTeeId(teeId, address(0));
        flareTeeManager.requestAvailabilityCheckAttestation(teeId, instructionId, teeId, address(0), address(0));
    }

    function testRequestAvailabilityCheckAttestationWithProofOwnerAndClaimBack() public {
        address proofOwner = makeAddr("proofOwner");
        address claimBack = makeAddr("claimBack");
        stateHelper.setTeeMachineStatus(teeId, IMachineManagerFacet.TeeStatus.INITIALIZED);
        stateHelper.setReplicatingTeeId(teeId, address(0));
        vm.expectCall(
            fdc2Hub,
            _buildAvailabilityCheckExpectCallData(proofOwner, claimBack)
        );
        flareTeeManager.requestAvailabilityCheckAttestation(teeId, instructionId, teeId, proofOwner, claimBack);
    }

    // confirmAvailability
    function testConfirmAvailabilityRevertTeeMachineNotAvailable() public {
        stateHelper.setTeeMachineStatus(teeId, IMachineManagerFacet.TeeStatus.PAUSED);
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
        vm.expectRevert(IVerificationFacet.InvalidAttestation.selector);
        flareTeeManager.confirmAvailability(proof);
    }

    function testConfirmAvailabilityRevertInvalidAttestation2() public {
        proof.header.attestationType = keccak256("invalidAttestationType");
        vm.expectRevert(IVerificationFacet.InvalidAttestation.selector);
        flareTeeManager.confirmAvailability(proof);
    }

    function testConfirmAvailabilityRevertInvalidAttestation3() public {
        proof.header.sourceId = keccak256("invalidSourceId");
        vm.expectRevert(IVerificationFacet.InvalidAttestation.selector);
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
                IVerificationFacet.ChallengeExpired.selector,
                0
            )
        );
        flareTeeManager.confirmAvailability(proof);
    }

    function testConfirmAvailabilityRevertInvalidSigningPolicy() public {
        _mockVerifySigningPolicySignatures(rewardEpochId + 2);
        vm.expectRevert(IVerificationFacet.InvalidSigningPolicy.selector);
        flareTeeManager.confirmAvailability(proof);
    }

    function testConfirmAvailabilityRevertInvalidResponseData() public {
        _mockGetCurrentRewardEpochId(uint24(rewardEpochId + 100));
        _mockVerifySigningPolicySignatures(rewardEpochId + 100);
        vm.expectRevert(ITeeCommonErrors.InvalidResponseData.selector);
        flareTeeManager.confirmAvailability(proof);
    }

    function testConfirmAvailabilityRevertInvalidResponseData1() public {
        // Make verifyTeeSystemState return false by setting a non-zero governance hash
        stateHelper.setTeeGovernanceHash(
            extensionId, proof.responseBody.codeHash, keccak256("nonZeroHash")
        );
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
        emit IVerificationFacet.AvailabilityCheckValidityExtended(
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
        emit IVerificationFacet.AvailabilityCheckValidityExtended(
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
        emit IVerificationFacet.AvailabilityCheckValidityExtended(
            teeId,
            owner,
            proof.header.timestamp + 1 hours
        );
        flareTeeManager.confirmAvailability(proof);
    }

    // verifyAvailabilityCheckProof
    function testVerifyAvailabilityCheckProofRevertCosignersThresholdNotMet() public {
        testSetCosigners();
        _mockVerifyCosignerSignatures(new address[](0));
        stateHelper.setTeeMachineStatus(teeId, IMachineManagerFacet.TeeStatus.INITIALIZED);
        vm.expectRevert(IVerificationFacet.CosignersThresholdNotMet.selector);
        flareTeeManager.verifyAvailabilityCheckProof(proof);
    }

    function testVerifyAvailabilityCheckProofRevertInvalidCosigner() public {
        testSetCosigners();
        address[] memory invalidCosigners = new address[](1);
        invalidCosigners[0] = makeAddr("invalidCosigner");
        _mockVerifyCosignerSignatures(invalidCosigners);
        stateHelper.setTeeMachineStatus(teeId, IMachineManagerFacet.TeeStatus.INITIALIZED);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeCommonErrors.InvalidCosigner.selector,
                invalidCosigners[0]
            )
        );
        flareTeeManager.verifyAvailabilityCheckProof(proof);
    }

    // header.timestamp >= block.timestamp
    function testVerifyAvailabilityCheckRevertTimestampInvalid1() public {
        testRequestTeeAttestation();
        vm.expectRevert(ITeeCommonErrors.AvailabilityCheckTimestampInvalid.selector);
        flareTeeManager.verifyAvailabilityCheckProof(proof);
    }

    // header.timestamp < challengeTs[teeId]
    function testVerifyAvailabilityCheckRevertTimestampInvalid2() public {
        proof.header.timestamp = 1;
        // block.timestamp == 0
        vm.expectRevert(ITeeCommonErrors.AvailabilityCheckTimestampInvalid.selector);
        flareTeeManager.verifyAvailabilityCheckProof(proof);
    }

    function testVerifyAvailabilityCheckRevertInvalidRequestBody1() public {
        proof.requestBody.url = "invalidUrl";
        vm.expectRevert(IVerificationFacet.InvalidRequestBody.selector);
        flareTeeManager.verifyAvailabilityCheckProof(proof);
    }

    function testVerifyAvailabilityCheckRevertInvalidRequestBody2() public {
        proof.requestBody.challenge = keccak256("invalidChallenge");
        vm.expectRevert(IVerificationFacet.InvalidRequestBody.selector);
        flareTeeManager.verifyAvailabilityCheckProof(proof);
    }

    function testVerifyAvailabilityCheckRevertInvalidRequestBody3() public {
        proof.requestBody.teeProxyId = makeAddr("invalidTeeProxyId");
        vm.expectRevert(IVerificationFacet.InvalidRequestBody.selector);
        flareTeeManager.verifyAvailabilityCheckProof(proof);
    }

    // true
    function testVerifyAvailabilityCheckProof1() public {
        testSetCosigners();
        assertTrue(flareTeeManager.verifyAvailabilityCheckProof(proof));
    }

    // codeHash doesn't match
    function testVerifyAvailabilityCheckProof2() public {
        testSetCosigners();
        proof.responseBody.codeHash = keccak256("invalidCodeHash");
        assertFalse(flareTeeManager.verifyAvailabilityCheckProof(proof));
    }

    // platform doesn't match
    function testVerifyAvailabilityCheckProof3() public {
        testSetCosigners();
        proof.responseBody.platform = keccak256("invalidPlatform");
        assertFalse(flareTeeManager.verifyAvailabilityCheckProof(proof));
    }

    // lastSigningPolicyId is too old
    function testVerifyAvailabilityCheckProof4() public {
        vm.prank(initialGovernance);
        flareTeeManager.updateSettings(1 hours, 4, 1 minutes);
        testSetCosigners();
        stateHelper.setTeeMachineStatus(teeId, IMachineManagerFacet.TeeStatus.INITIALIZED);
        _mockGetCurrentRewardEpochId(uint24(rewardEpochId + 2));
        _mockVerifySigningPolicySignatures(rewardEpochId + 2);
        proof.responseBody.lastSigningPolicyId = uint32(rewardEpochId);
        assertFalse(flareTeeManager.verifyAvailabilityCheckProof(proof));
    }

    //  verifyTeeSystemState -> false
    function testVerifyAvailabilityCheckProof5() public {
        testSetCosigners();
        // Make verifyTeeSystemState return false by setting a non-zero governance hash
        stateHelper.setTeeGovernanceHash(
            extensionId, proof.responseBody.codeHash, keccak256("nonZeroHash")
        );
        assertFalse(flareTeeManager.verifyAvailabilityCheckProof(proof));
    }

    // address(teeStateVerifier) != address(0) && verifyTeeState -> false
    function testVerifyAvailabilityCheckProof6() public {
        testSetCosigners();
        address teeStateVerifier = makeAddr("teeStateVerifier");
        stateHelper.setExtensionStateVerifier(extensionId, teeStateVerifier);
        vm.mockCall(
            teeStateVerifier,
            abi.encodeWithSelector(
                ITeeExtensionStateVerifier.verifyTeeState.selector
            ),
            abi.encode(false)
        );
        assertFalse(flareTeeManager.verifyAvailabilityCheckProof(proof));
    }

    // address(teeStateVerifier) == address(0) && state.stateVersion != bytes32(0)
    function testVerifyAvailabilityCheckProof7() public {
        testSetCosigners();
        proof.responseBody.state.stateVersion = bytes32("stateVersion");
        assertFalse(flareTeeManager.verifyAvailabilityCheckProof(proof));
    }

    // address(teeStateVerifier) == address(0) && state.state.length != 0
    function testVerifyAvailabilityCheckProof8() public {
        testSetCosigners();
        proof.responseBody.state.state = "state";
        assertFalse(flareTeeManager.verifyAvailabilityCheckProof(proof));
    }

    // initialSigningPolicyId > currentRewardEpochId
    // machine status == INITIALIZED
    function testVerifyAvailabilityCheckProof9() public {
        proof.responseBody.initialSigningPolicyId = signingPolicyId + 1;
        stateHelper.setTeeMachineStatus(teeId, IMachineManagerFacet.TeeStatus.INITIALIZED);
        assertFalse(flareTeeManager.verifyAvailabilityCheckProof(proof));
    }

    // initialSigningPolicyId + signingPolicyValidityDurationInRewardEpochs (== 1) < currentRewardEpochId
    // machine status == INITIALIZED
    function testVerifyAvailabilityCheckProof10() public {
        stateHelper.setTeeMachineStatus(teeId, IMachineManagerFacet.TeeStatus.INITIALIZED);
        _mockGetCurrentRewardEpochId(10);
        _mockVerifySigningPolicySignatures(10);
        proof.responseBody.initialSigningPolicyId = 1;
        assertFalse(flareTeeManager.verifyAvailabilityCheckProof(proof));
    }

    // initialSigningPolicyId > currentRewardEpochId
    // machine status != INITIALIZED
    function testVerifyAvailabilityCheckProof11() public {
        proof.responseBody.initialSigningPolicyId = signingPolicyId + 1;
        assertFalse(flareTeeManager.verifyAvailabilityCheckProof(proof));
    }

    // availability check validity expired
    // machine status != INITIALIZED
    function testVerifyAvailabilityCheckProof12() public {
        _mockGetCurrentRewardEpochId(uint24(rewardEpochId + 100));
        _mockVerifySigningPolicySignatures(rewardEpochId + 100);
        assertFalse(flareTeeManager.verifyAvailabilityCheckProof(proof));
    }

    // address(teeStateVerifier) != address(0) && verifyTeeState -> true
    function testVerifyAvailabilityCheckProof13() public {
        testSetCosigners();
        address teeStateVerifier = makeAddr("teeStateVerifier");
        stateHelper.setExtensionStateVerifier(extensionId, teeStateVerifier);
        vm.mockCall(
            teeStateVerifier,
            abi.encodeWithSelector(
                ITeeExtensionStateVerifier.verifyTeeState.selector
            ),
            abi.encode(true)
        );
        assertTrue(flareTeeManager.verifyAvailabilityCheckProof(proof));
    }

    // verifyAvailabilityCheckProof with TEE signatures
    function testVerifyAvailabilityCheckProofWithTeeSignatures() public {
        testSetCosigners();
        address[] memory signingTeeIds = new address[](1);
        signingTeeIds[0] = teeId;
        _mockVerifyTeeSignatures(signingTeeIds);
        _addMockTeeSignatureToProof();

        assertTrue(flareTeeManager.verifyAvailabilityCheckProof(proof));
    }

    // verifyAvailabilityCheckProof with TEE signatures bypasses signing policy check
    function testVerifyAvailabilityCheckProofTeeSignaturesBypassSigningPolicy() public {
        testSetCosigners();
        _mockVerifySigningPolicySignatures(rewardEpochId + 100);
        address[] memory signingTeeIds = new address[](1);
        signingTeeIds[0] = teeId;
        _mockVerifyTeeSignatures(signingTeeIds);
        _addMockTeeSignatureToProof();

        assertTrue(flareTeeManager.verifyAvailabilityCheckProof(proof));
    }

    // verifyAvailabilityCheckProof with TEE signatures for INITIALIZED status (cosigners still checked)
    function testVerifyAvailabilityCheckProofWithTeeSignaturesInitialized() public {
        testSetCosigners();
        stateHelper.setTeeMachineStatus(teeId, IMachineManagerFacet.TeeStatus.INITIALIZED);
        address[] memory signingTeeIds = new address[](1);
        signingTeeIds[0] = makeAddr("teeIdInProduction");
        _mockVerifyTeeSignatures(signingTeeIds);
        _addMockTeeSignatureToProof();

        assertTrue(flareTeeManager.verifyAvailabilityCheckProof(proof));
    }

    // verifyAvailabilityCheckProof with TEE signatures - INITIALIZED status, cosigner check still fails
    function testVerifyAvailabilityCheckProofWithTeeSignaturesInitializedRevertCosignersThresholdNotMet()
        public
    {
        testSetCosigners();
        stateHelper.setTeeMachineStatus(teeId, IMachineManagerFacet.TeeStatus.INITIALIZED);
        _mockVerifyCosignerSignatures(new address[](0));
        address[] memory signingTeeIds = new address[](1);
        signingTeeIds[0] = makeAddr("teeIdInProduction");
        _mockVerifyTeeSignatures(signingTeeIds);
        _addMockTeeSignatureToProof();

        vm.expectRevert(IVerificationFacet.CosignersThresholdNotMet.selector);
        flareTeeManager.verifyAvailabilityCheckProof(proof);
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
        emit IVerificationFacet.CosignersSet(cosigners, 1);
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

    function testUpdateSettings() public {
        vm.prank(initialGovernance);
        vm.expectEmit();
        emit IVerificationFacet.SettingsUpdated(1 hours, 1, 1 minutes);
        flareTeeManager.updateSettings(1 hours, 1, 1 minutes);
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
    // Wallet verification tests (PMW)
    // =========================================================================

    function testRequestPMWMultisigAccountConfiguredAttestationRevertAccountAddressZero() public {
        vm.expectRevert(IVerificationFacet.AccountAddressZero.selector);
        flareTeeManager.requestPMWMultisigAccountConfiguredAttestation(
            walletId, sourceId, "", address(0), address(0), address(0)
        );
    }

    function testRequestPMWMultisigAccountConfiguredAttestationRevertOnlyProductionOrPausedStatus()
        public
    {
        stateHelper.setWalletState(walletId, projectId, IWalletManagerFacet.WalletStatus.CREATED);
        vm.expectRevert(ITeeCommonErrors.OnlyProductionOrPausedStatus.selector);
        flareTeeManager.requestPMWMultisigAccountConfiguredAttestation(
            walletId, sourceId, walletAddress, address(0), address(0), address(0)
        );
    }

    function testRequestPMWMultisigAccountConfiguredAttestation() public {
        flareTeeManager.requestPMWMultisigAccountConfiguredAttestation(
            walletId, sourceId, walletAddress, address(0), address(0), address(0)
        );
    }

    function testRequestPMWMultisigAccountConfiguredAttestationWithProofOwnerAndClaimBack() public {
        address proofOwner = makeAddr("proofOwner");
        address claimBack = makeAddr("claimBack");
        vm.expectCall(
            fdc2Hub,
            _buildPMWExpectCallData(proofOwner, claimBack)
        );
        flareTeeManager.requestPMWMultisigAccountConfiguredAttestation(
            walletId, sourceId, walletAddress, address(0), proofOwner, claimBack
        );
    }

    function testVerifyPMWMultisigAccountConfiguredProofRevertInvalidAttestation() public {
        pmwProof.header.thresholdBIPS = 1;
        vm.expectRevert(IVerificationFacet.InvalidAttestation.selector);
        flareTeeManager.verifyPMWMultisigAccountConfiguredProof(walletId, pmwProof);
    }

    function testVerifyPMWMultisigAccountConfiguredProofRevertInvalidAttestation2() public {
        pmwProof.header.attestationType = keccak256("invalidAttestationType");
        vm.expectRevert(IVerificationFacet.InvalidAttestation.selector);
        flareTeeManager.verifyPMWMultisigAccountConfiguredProof(walletId, pmwProof);
    }

    function testVerifyPMWMultisigAccountConfiguredProofRevertInvalidRequestBody1() public {
        pmwProof.requestBody.threshold = multisigThreshold + 1;
        vm.expectRevert(IVerificationFacet.InvalidRequestBody.selector);
        flareTeeManager.verifyPMWMultisigAccountConfiguredProof(walletId, pmwProof);
    }

    function testVerifyPMWMultisigAccountConfiguredProofRevertInvalidRequestBody2() public {
        pmwProof.requestBody.publicKeys[0] = hex"ff";
        vm.expectRevert(IVerificationFacet.InvalidRequestBody.selector);
        flareTeeManager.verifyPMWMultisigAccountConfiguredProof(walletId, pmwProof);
    }

    function testVerifyPMWMultisigAccountConfiguredProof() public {
        assertTrue(
            flareTeeManager.verifyPMWMultisigAccountConfiguredProof(walletId, pmwProof)
        );
    }

    function testVerifyPMWMultisigAccountConfiguredProofWithTeeSignatures() public {
        address[] memory signingTeeIds = new address[](1);
        signingTeeIds[0] = teeId;
        _mockVerifyTeeSignatures(signingTeeIds);
        _addMockTeeSignatureToPmwProof();

        assertTrue(
            flareTeeManager.verifyPMWMultisigAccountConfiguredProof(walletId, pmwProof)
        );
    }

    function testVerifyPMWMultisigAccountConfiguredProofWithTeeSignaturesStatusError() public {
        address[] memory signingTeeIds = new address[](1);
        signingTeeIds[0] = teeId;
        _mockVerifyTeeSignatures(signingTeeIds);
        _addMockTeeSignatureToPmwProof();

        pmwProof.responseBody.status = IPMWMultisigAccountConfigured.PMWMultisigAccountStatus.ERROR;
        assertFalse(
            flareTeeManager.verifyPMWMultisigAccountConfiguredProof(walletId, pmwProof)
        );
    }

    function testVerifyPMWMultisigAccountConfiguredProofTeeSignaturesBypassSigningPolicy()
        public
    {
        _mockVerifySigningPolicySignatures(rewardEpochId + 100);
        address[] memory signingTeeIds = new address[](1);
        signingTeeIds[0] = teeId;
        _mockVerifyTeeSignatures(signingTeeIds);
        _addMockTeeSignatureToPmwProof();

        assertTrue(
            flareTeeManager.verifyPMWMultisigAccountConfiguredProof(walletId, pmwProof)
        );
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

    function _mockVerifyCosignerSignatures(address[] memory _cosignersList) private {
        vm.mockCall(
            fdc2Verification,
            abi.encodeWithSelector(
                IFdc2Verification.verifyCosignerSignatures.selector
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

    function _addMockTeeSignatureToPmwProof() private {
        pmwProof.signatures.teeSignatures.push(
            Signature(27, bytes32(uint256(1)), bytes32(uint256(2)))
        );
    }

    function _buildTeeAttestationExpectCallData(
        address _claimBack
    ) private view returns (bytes memory) {
        IMachineManagerFacet.TeeMachine[] memory teeMachines = new IMachineManagerFacet.TeeMachine[](1);
        teeMachines[0] = IMachineManagerFacet.TeeMachine(teeId, teeProxyId, url);
        IVerificationFacet.TeeAttestation memory message = IVerificationFacet.TeeAttestation({
            teeMachine: IMachineManagerFacet.TeeMachineWithAttestationData(
                teeId, teeId, url, proof.responseBody.codeHash, proof.responseBody.platform
            ),
            challenge: bytes32(0)
        });
        return abi.encodeWithSelector(
            SEND_SYSTEM_INSTRUCTIONS_SELECTOR,
            bytes32(0),
            teeMachines,
            IInstructionsFacet.TeeInstructionParams(
                bytes32("F_REG"),
                bytes32("TEE_ATTESTATION"),
                abi.encode(message),
                new address[](0),
                uint64(0),
                _claimBack
            )
        );
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

    function _buildPMWExpectCallData(
        address _proofOwner,
        address _claimBack
    ) private view returns (bytes memory) {
        bytes[] memory publicKeys = new bytes[](1);
        publicKeys[0] = publicKey;
        IPMWMultisigAccountConfigured.RequestBody memory requestBody =
            IPMWMultisigAccountConfigured.RequestBody({
                accountAddress: walletAddress,
                publicKeys: publicKeys,
                threshold: multisigThreshold
            });
        IFdc2Hub.Fdc2AttestationRequest memory attestationRequest = IFdc2Hub.Fdc2AttestationRequest({
            header: IFdc2Hub.Fdc2RequestHeader({
                attestationType: PMW_MULTISIG_ACCOUNT_CONFIGURED_ATTESTATION_TYPE,
                sourceId: sourceId,
                thresholdBIPS: 0,
                proofOwner: _proofOwner
            }),
            requestBody: abi.encode(requestBody)
        });
        // _testOnTeeId == address(0) => numberOfTees = 1, teeIds = empty
        return abi.encodeWithSelector(
            IFdc2Hub.requestAttestation.selector,
            attestationRequest,
            uint256(1),
            new address[](0),
            new address[](0),
            uint64(0),
            _claimBack
        );
    }
}
