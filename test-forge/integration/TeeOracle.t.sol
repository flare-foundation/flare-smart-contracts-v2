// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { FlareTeeManagerDeployer } from "../utils/FlareTeeManagerDeployer.sol";
import { TeeOracleFeedStoreDeployer } from "../utils/TeeOracleFeedStoreDeployer.sol";
import { IIFlareTeeManager } from "../../contracts/tee/interface/IIFlareTeeManager.sol";
import { IDiamond } from "../../contracts/diamond/interfaces/IDiamond.sol";
import { IDiamondCut } from "../../contracts/diamond/interfaces/IDiamondCut.sol";
import { IMachineManager } from "../../contracts/userInterfaces/tee/IMachineManager.sol";
import { MachineManager } from "../../contracts/tee/library/MachineManager.sol";
import {
    ITeeExtensionStateVerifier
} from "../../contracts/userInterfaces/tee/ITeeExtensionStateVerifier.sol";
import { PublicKey } from "../../contracts/userInterfaces/IPublicKey.sol";
import { Signature } from "../../contracts/userInterfaces/ISignature.sol";
import { SignedPayload } from "../../contracts/utils/lib/SignedPayload.sol";
import { Fdc2Verification } from "../../contracts/fdc2/implementation/Fdc2Verification.sol";
import { Fdc2VerificationProxy } from "../../contracts/fdc2/proxy/Fdc2VerificationProxy.sol";
import {
    TeeOracleInstructionsSender
} from "../../contracts/tee/extensions/oracle/implementation/TeeOracleInstructionsSender.sol";
import {
    TeeOracleInstructionsSenderProxy
} from "../../contracts/tee/extensions/oracle/proxy/TeeOracleInstructionsSenderProxy.sol";
import {
    TeeOracleFeedStore
} from "../../contracts/tee/extensions/oracle/implementation/TeeOracleFeedStore.sol";
import {
    ITeeOracleInstructionsSender,
    TEE_ORACLE_OP_TYPE,
    SET_ENDPOINTS_COMMAND,
    SET_ADMINS_COMMAND
} from "../../contracts/userInterfaces/tee/ITeeOracleInstructionsSender.sol";
import {
    ITeeOracleFeedStore,
    TEE_ORACLE_FEED
} from "../../contracts/userInterfaces/tee/ITeeOracleFeedStore.sol";
import { IFeeCalculator } from "../../contracts/userInterfaces/IFeeCalculator.sol";
import { ProtocolsV2Interface } from "../../contracts/userInterfaces/LTS/ProtocolsV2Interface.sol";
import { RandomNumberV2Interface } from "../../contracts/userInterfaces/LTS/RandomNumberV2Interface.sol";
import { IIRewardManager } from "../../contracts/protocol/interface/IIRewardManager.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

/**
 * @title TeeOracleMachineSetupFacet
 * @notice Test helper facet cut into the diamond to fabricate a PRODUCTION machine on the
 *         oracle extension directly through the library, bypassing the full
 *         registration/attestation flow. Also registers the machine in the active sets so
 *         `getRandomTeeIds` can select it.
 */
contract TeeOracleMachineSetupFacet {
    using EnumerableSet for EnumerableSet.AddressSet;

    function setupTeeMachineState(
        address _teeId,
        uint256 _extensionId,
        string calldata _url
    )
        external
    {
        MachineManager.State storage s = MachineManager.getState();
        s.teeMachineStates[_teeId] = MachineManager.TeeMachineState({
            extensionId: _extensionId,
            teePublicKey: PublicKey(bytes32(0), bytes32(0)),
            initialTeeId: _teeId,
            initialSigningPolicyId: 0,
            owner: msg.sender,
            teeProxyId: _teeId,
            status: IMachineManager.TeeStatus.PRODUCTION,
            lastStatusChangeTs: uint64(block.timestamp),
            codeHash: bytes32(0),
            platform: bytes32(0),
            governanceHash: bytes32(0),
            url: _url
        });
        s.activeTeeIds.add(_teeId);
        s.extensionActiveTeeIds[_extensionId].add(_teeId);
    }

    /// Moves a fabricated machine to another status through the library, so it leaves the
    /// extension's active set exactly as a real status change would.
    function changeTeeMachineState(
        address _teeId,
        IMachineManager.TeeStatus _status
    )
        external
    {
        MachineManager.changeStatus(_teeId, _status);
    }
}

/**
 * @title TeeOracleIntegrationTest
 * @notice End-to-end flow of the TEE oracle extension against a real FlareTeeManager
 *         diamond and a real Fdc2Verification: reserved extension registration, sender
 *         wiring, a governance configuration publication that auto-dispatches to the live
 *         active set, a permissionless push for a machine registered later, a feed update
 *         request through the diamond, a genuinely signed feed update submission, and the
 *         paid feed read.
 */
contract TeeOracleIntegrationTest is Test {

    uint256 private constant EXTENSION_ID = 1;
    bytes21 private constant FEED_ID = bytes21(bytes.concat(bytes1(uint8(0x20)), bytes("USDX/USD")));
    uint256 private constant INSTRUCTION_FEE = 1000; // diamond default fee
    uint256 private constant READ_FEE = 3;
    // deployment defaults: threshold 1 (behaves as a single-signature store), 1% relative
    // deviation, no absolute allowance
    uint8 private constant REQUIRED_SIGNATURES = 1;
    uint16 private constant MAX_SPREAD_BIPS = 100;
    uint64 private constant MAX_SPREAD_ABSOLUTE = 0;

    IIFlareTeeManager private flareTeeManager;
    Fdc2Verification private fdc2Verification;
    TeeOracleInstructionsSender private sender;
    TeeOracleFeedStore private feedStore;

    address private initialGovernance;
    address private addressUpdater;
    address private extensionOwner;
    address private flareSystemsManager;
    address private rewardManager;
    address private relay;
    address private feeCalculator;
    address private feeDestination;
    address private claimBack;

    address private teeId;
    uint256 private teePrivateKey;

    function setUp() public {
        vm.warp(1_700_000_000);

        initialGovernance = makeAddr("initialGovernance");
        addressUpdater = makeAddr("AddressUpdater");
        extensionOwner = makeAddr("extensionOwner");
        flareSystemsManager = makeAddr("FlareSystemsManager");
        rewardManager = makeAddr("RewardManager");
        relay = makeAddr("Relay");
        feeCalculator = makeAddr("FeeCalculator");
        feeDestination = makeAddr("feeDestination");
        // the wallet governance names as the claim-back destination of a publication's dispatch
        claimBack = makeAddr("claimBack");
        (teeId, teePrivateKey) = makeAddrAndKey("teeMachine");

        // deploy the TEE diamond
        flareTeeManager = FlareTeeManagerDeployer.deployFacets(
            FlareTeeManagerDeployer.DeployParams({
                governanceSettings: IGovernanceSettings(address(this)),
                initialGovernance: initialGovernance,
                addressUpdater: addressUpdater,
                availabilityCheckValidityDurationSeconds: 3600,
                signingPolicyValidityDurationInRewardEpochs: 6,
                challengeValidityDurationSeconds: 600,
                defaultFee: INSTRUCTION_FEE,
                publicExtensionCreationEnabled: false,
                emergencyUnpauseGracePeriodSeconds: 7200
            })
        );

        // cut the machine-setup helper facet into the diamond
        TeeOracleMachineSetupFacet setupFacet = new TeeOracleMachineSetupFacet();
        IDiamond.FacetCut[] memory cuts = new IDiamond.FacetCut[](1);
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = TeeOracleMachineSetupFacet.setupTeeMachineState.selector;
        selectors[1] = TeeOracleMachineSetupFacet.changeTeeMachineState.selector;
        cuts[0] = IDiamond.FacetCut(address(setupFacet), IDiamond.FacetCutAction.Add, selectors);
        vm.prank(initialGovernance);
        IDiamondCut(address(flareTeeManager)).diamondCut(cuts, address(0), "");

        // wire the diamond
        bytes32[] memory contractNameHashes = new bytes32[](6);
        address[] memory contractAddresses = new address[](6);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[2] = keccak256(abi.encode("RewardManager"));
        contractNameHashes[3] = keccak256(abi.encode("Relay"));
        contractNameHashes[4] = keccak256(abi.encode("Fdc2Hub"));
        contractNameHashes[5] = keccak256(abi.encode("Fdc2Verification"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = flareSystemsManager;
        contractAddresses[2] = rewardManager;
        contractAddresses[3] = relay;
        contractAddresses[4] = makeAddr("Fdc2Hub");
        contractAddresses[5] = makeAddr("Fdc2VerificationForDiamond");
        vm.prank(addressUpdater);
        flareTeeManager.updateContractAddresses(contractNameHashes, contractAddresses);

        // mock only external infrastructure
        vm.mockCall(
            relay,
            abi.encodeWithSelector(RandomNumberV2Interface.getRandomNumber.selector),
            abi.encode(uint256(12345), true, uint256(0))
        );
        vm.mockCall(
            flareSystemsManager,
            abi.encodeWithSelector(ProtocolsV2Interface.getCurrentRewardEpochId.selector),
            abi.encode(uint256(1))
        );
        vm.mockCall(
            rewardManager,
            abi.encodeWithSelector(IIRewardManager.receiveRewards.selector),
            ""
        );
        vm.mockCall(
            feeCalculator,
            abi.encodeWithSelector(IFeeCalculator.calculateFeeByIds.selector),
            abi.encode(READ_FEE)
        );

        // deploy the real Fdc2Verification
        Fdc2Verification fdc2VerImpl = new Fdc2Verification();
        Fdc2VerificationProxy fdc2VerProxy = new Fdc2VerificationProxy(
            IGovernanceSettings(address(this)), initialGovernance, addressUpdater, address(fdc2VerImpl)
        );
        fdc2Verification = Fdc2Verification(address(fdc2VerProxy));
        bytes32[] memory verNameHashes = new bytes32[](3);
        address[] memory verAddresses = new address[](3);
        verNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        verNameHashes[1] = keccak256(abi.encode("FlareTeeManager"));
        verNameHashes[2] = keccak256(abi.encode("Relay"));
        verAddresses[0] = addressUpdater;
        verAddresses[1] = address(flareTeeManager);
        verAddresses[2] = relay;
        vm.prank(addressUpdater);
        fdc2Verification.updateContractAddresses(verNameHashes, verAddresses);

        // deploy the TEE oracle extension contracts
        TeeOracleInstructionsSender senderImpl = new TeeOracleInstructionsSender();
        sender = TeeOracleInstructionsSender(address(new TeeOracleInstructionsSenderProxy(
            IGovernanceSettings(address(this)),
            initialGovernance,
            addressUpdater,
            EXTENSION_ID,
            address(senderImpl)
        )));
        bytes32[] memory senderNameHashes = new bytes32[](2);
        address[] memory senderAddresses = new address[](2);
        senderNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        senderNameHashes[1] = keccak256(abi.encode("FlareTeeManager"));
        senderAddresses[0] = addressUpdater;
        senderAddresses[1] = address(flareTeeManager);
        vm.prank(addressUpdater);
        sender.updateContractAddresses(senderNameHashes, senderAddresses);

        _deployFeedStore();
        bytes32[] memory storeNameHashes = new bytes32[](3);
        address[] memory storeAddresses = new address[](3);
        storeNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        storeNameHashes[1] = keccak256(abi.encode("Fdc2Verification"));
        storeNameHashes[2] = keccak256(abi.encode("FeeCalculator"));
        storeAddresses[0] = addressUpdater;
        storeAddresses[1] = address(fdc2Verification);
        storeAddresses[2] = feeCalculator;
        vm.prank(addressUpdater);
        feedStore.updateContractAddresses(storeNameHashes, storeAddresses);

        // register the reserved extension and its instructions sender
        vm.prank(initialGovernance);
        flareTeeManager.registerReserved(EXTENSION_ID, extensionOwner);
        vm.prank(extensionOwner);
        flareTeeManager.setExtensionContracts(
            EXTENSION_ID, ITeeExtensionStateVerifier(address(0)), address(sender)
        );

        // fabricate a PRODUCTION machine on the extension
        TeeOracleMachineSetupFacet(address(flareTeeManager)).setupTeeMachineState(
            teeId, EXTENSION_ID, "https://tee.example.com"
        );
    }

    function testEndToEndFeedFlow() public {
        // 1. governance publishes endpoints and admins for the feed (pre-production: immediate
        //    execution) with the instruction fee attached. No machines are named: the
        //    publication resolves the extension's live active set itself and dispatches to it,
        //    so the fleet converges in the publishing transaction.
        address[] memory teeIds = new address[](1);
        teeIds[0] = teeId;
        // the executor sizes the fee from get*PublicationFee, read in the executing block
        (address[] memory publicationTargets, uint256 publicationFee) =
            sender.getEndpointsPublicationFee();
        assertEq(publicationTargets.length, 1);
        assertEq(publicationTargets[0], teeId);
        assertEq(publicationFee, INSTRUCTION_FEE);
        vm.deal(initialGovernance, 2 * INSTRUCTION_FEE);
        vm.startPrank(initialGovernance);
        sender.setEndpoints{value: publicationFee}(FEED_ID, _makeGroups(), claimBack);
        (, uint256 adminsPublicationFee) = sender.getAdminsPublicationFee();
        sender.setAdmins{value: adminsPublicationFee}(FEED_ID, _makeRoles(), claimBack);
        vm.stopPrank();
        assertEq(sender.endpointsVersion(FEED_ID), 1);
        assertEq(sender.adminsVersion(FEED_ID), 1);
        assertEq(sender.expectedEndpointsVersion(FEED_ID, teeId), 1);
        assertEq(sender.expectedAdminsVersion(FEED_ID, teeId), 1);
        assertTrue(sender.isTeeIdConfigured(FEED_ID, teeId));
        // the whole instruction fee reached the reward manager; nothing stayed behind
        assertEq(rewardManager.balance, 2 * INSTRUCTION_FEE);
        assertEq(initialGovernance.balance, 0);
        assertEq(address(sender).balance, 0);
        // the fleet has converged: nothing left to push
        assertEq(sender.getEndpointsPushTargets(FEED_ID).length, 0);
        assertEq(sender.getAdminsPushTargets(FEED_ID).length, 0);

        // 2. anyone requests a feed update from the configured machine
        address requester = makeAddr("requester");
        vm.deal(requester, INSTRUCTION_FEE);
        vm.prank(requester);
        bytes32 instructionId =
            sender.requestFeedUpdate{value: INSTRUCTION_FEE}(FEED_ID, teeIds);
        assertNotEq(instructionId, bytes32(0));

        // 3. the machine answers with a signed feed update carrying the feed's published
        //    configuration generation
        ITeeOracleFeedStore.FeedUpdate memory feedUpdate = ITeeOracleFeedStore.FeedUpdate({
            extensionId: EXTENSION_ID,
            feedId: FEED_ID,
            value: 99954321,
            decimals: 8,
            observedAt: uint64(vm.getBlockTimestamp()) - 1,
            endpointsHash: sender.latestEndpointsHash(FEED_ID),
            adminsHash: sender.latestAdminsHash(FEED_ID)
        });
        feedStore.submitFeedUpdates(_one(feedUpdate, _sign(feedUpdate)));

        // 4. the paid read serves the value; the read fee reaches the fee destination
        (int256 value, int8 decimals, uint64 timestamp) = feedStore.getCurrentFeed{value: READ_FEE}();
        assertEq(value, 99954321);
        assertEq(decimals, 8);
        assertEq(timestamp, uint64(vm.getBlockTimestamp()) - 1);
        assertEq(feeDestination.balance, READ_FEE);
    }

    function testSubmitFeedUpdatesOneSignatureRejectsUnregisteredSigner() public {
        // a signer that is not a machine at all fails inside the diamond's machine lookup
        // (the revert bubbles through the real verifier and the store untouched). The
        // configuration is published first, so the signature is the only thing left to fail on -
        // the store checks that the feed HAS a published generation before it verifies anything.
        _publishAndDispatch();
        (, uint256 foreignKey) = makeAddrAndKey("foreignSigner");
        ITeeOracleFeedStore.FeedUpdate memory feedUpdate = ITeeOracleFeedStore.FeedUpdate({
            extensionId: EXTENSION_ID,
            feedId: FEED_ID,
            value: 1,
            decimals: 0,
            observedAt: uint64(vm.getBlockTimestamp()) - 1,
            endpointsHash: sender.latestEndpointsHash(FEED_ID),
            adminsHash: sender.latestAdminsHash(FEED_ID)
        });
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            foreignKey,
            SignedPayload.ethSignedHash(TEE_ORACLE_FEED, keccak256(abi.encode(feedUpdate)))
        );
        vm.expectRevert(abi.encodeWithSignature("TeeNotFound()"));
        feedStore.submitFeedUpdates(_one(feedUpdate, Signature(v, r, s)));
    }

    function testSubmitFeedUpdatesOneSignatureRejectsTamperedUpdate() public {
        // publish the configuration so only the signature binding can fail
        _publishAndDispatch();

        ITeeOracleFeedStore.FeedUpdate memory feedUpdate = ITeeOracleFeedStore.FeedUpdate({
            extensionId: EXTENSION_ID,
            feedId: FEED_ID,
            value: 99954321,
            decimals: 8,
            observedAt: uint64(vm.getBlockTimestamp()) - 1,
            endpointsHash: sender.latestEndpointsHash(FEED_ID),
            adminsHash: sender.latestAdminsHash(FEED_ID)
        });
        Signature memory signature = _sign(feedUpdate);

        // tampering with the signed value changes the digest, so recovery yields a
        // different address that is no machine at all
        feedUpdate.value = 1;
        vm.expectRevert(abi.encodeWithSignature("TeeNotFound()"));
        feedStore.submitFeedUpdates(_one(feedUpdate, signature));
    }

    function testLateMachineConvergesThroughPermissionlessPush() public {
        // the fleet is configured while only one machine exists
        _publishAndDispatch();

        // a second machine is registered only afterwards - with no governance call available,
        // it can still be brought current by anyone
        (address lateTeeId, uint256 lateKey) = makeAddrAndKey("lateTeeMachine");
        TeeOracleMachineSetupFacet(address(flareTeeManager)).setupTeeMachineState(
            lateTeeId, EXTENSION_ID, "https://late-tee.example.com"
        );
        address[] memory targets = sender.getEndpointsPushTargets(FEED_ID);
        assertEq(targets.length, 1, "only the lagging machine still needs a push");
        assertEq(targets[0], lateTeeId);

        // the pusher supplies the configuration values too - nothing stores them, so they come
        // from the publication's log; the contract re-encodes them with the version it holds
        address anyone = makeAddr("anyone");
        vm.deal(anyone, 2 * INSTRUCTION_FEE);
        vm.startPrank(anyone);
        sender.pushEndpoints{value: INSTRUCTION_FEE}(FEED_ID, targets, _makeGroups());
        sender.pushAdmins{value: INSTRUCTION_FEE}(
            FEED_ID, sender.getAdminsPushTargets(FEED_ID), _makeRoles());
        vm.stopPrank();
        assertTrue(sender.isTeeIdConfigured(FEED_ID, lateTeeId));
        assertEq(sender.getEndpointsPushTargets(FEED_ID).length, 0);

        // and it can now serve the feed
        ITeeOracleFeedStore.FeedUpdate memory feedUpdate = ITeeOracleFeedStore.FeedUpdate({
            extensionId: EXTENSION_ID,
            feedId: FEED_ID,
            value: 100010000,
            decimals: 8,
            observedAt: uint64(vm.getBlockTimestamp()) - 1,
            endpointsHash: sender.latestEndpointsHash(FEED_ID),
            adminsHash: sender.latestAdminsHash(FEED_ID)
        });
        (uint8 v, bytes32 r, bytes32 sig) = vm.sign(
            lateKey,
            SignedPayload.ethSignedHash(TEE_ORACLE_FEED, keccak256(abi.encode(feedUpdate)))
        );
        feedStore.submitFeedUpdates(_one(feedUpdate, Signature(v, r, sig)));
        (int256 value,,) = feedStore.getCurrentFeed{value: READ_FEE}();
        assertEq(value, 100010000);
    }

    function testPublicationWithoutFeeReverts() public {
        // a short fee is the executor's to fix, so it is not swallowed: the sender forwards the
        // whole msg.value and the diamond's own floor rejects it, rolling the publication back
        (, uint256 fee) = sender.getEndpointsPublicationFee();
        assertEq(fee, INSTRUCTION_FEE);
        vm.expectRevert(abi.encodeWithSignature("FeeTooLow()"));
        vm.prank(initialGovernance);
        sender.setEndpoints(FEED_ID, _makeGroups(), claimBack);
        assertEq(sender.endpointsVersion(FEED_ID), 0);
        assertEq(sender.latestEndpointsHash(FEED_ID), bytes32(0));
        assertEq(rewardManager.balance, 0);
    }

    function testPausedPublicationIsPushedAfterUnpause() public {
        // the extension is paused - possibly BECAUSE the live configuration is wrong - so the
        // diamond refuses every dispatch. A corrected configuration must still land on chain,
        // with no value attached since a skipped dispatch creates no instruction to pay for.
        vm.prank(extensionOwner);
        flareTeeManager.emergencyPauseExtension(EXTENSION_ID);
        // the preview mirrors the publication rather than the raw active set: no targets, no
        // fee, so an executor who reads only this attaches nothing and avoids ValueNotNeeded
        (address[] memory paused, uint256 pausedFee) = sender.getEndpointsPublicationFee();
        assertEq(paused.length, 0, "a paused extension dispatches to nobody");
        assertEq(pausedFee, 0);
        vm.deal(initialGovernance, INSTRUCTION_FEE);
        vm.expectRevert(ITeeOracleInstructionsSender.ValueNotNeeded.selector);
        vm.prank(initialGovernance);
        sender.setEndpoints{value: INSTRUCTION_FEE}(FEED_ID, _makeGroups(), claimBack);

        // the values land with no dispatch at all, so the publication EVENT is the only record
        // of the payload - and it is emitted anyway, precisely so the push below has something to
        // supply. A keeper reads it from there; the test does exactly that.
        vm.recordLogs();
        vm.startPrank(initialGovernance);
        sender.setEndpoints(FEED_ID, _makeGroups(), claimBack);
        sender.setAdmins(FEED_ID, _makeRoles(), claimBack);
        vm.stopPrank();
        Vm.Log[] memory logs = vm.getRecordedLogs();
        ITeeOracleInstructionsSender.EndpointGroup[] memory loggedGroups = _groupsFromLogs(logs);
        ITeeOracleInstructionsSender.AdminRole[] memory loggedRoles = _rolesFromLogs(logs);
        assertEq(keccak256(abi.encode(loggedGroups)), keccak256(abi.encode(_makeGroups())));
        assertEq(keccak256(abi.encode(loggedRoles)), keccak256(abi.encode(_makeRoles())));
        assertEq(sender.endpointsVersion(FEED_ID), 1);
        assertEq(sender.adminsVersion(FEED_ID), 1);
        assertEq(sender.expectedEndpointsVersion(FEED_ID, teeId), 0);
        assertEq(rewardManager.balance, 0, "a skipped dispatch pays no instruction fee");
        assertFalse(sender.isTeeIdConfigured(FEED_ID, teeId));

        // once unpaused, a keeper reads the exact target set and fee, then pushes both kinds
        vm.prank(extensionOwner);
        flareTeeManager.emergencyUnpauseExtension(EXTENSION_ID);
        address keeper = makeAddr("keeper");
        vm.deal(keeper, 2 * INSTRUCTION_FEE);
        address[] memory targets = sender.getEndpointsPushTargets(FEED_ID);
        assertEq(targets.length, 1);
        assertEq(targets[0], teeId);
        // the push has no fee preview of its own - the list is dispatched as given, so the
        // diamond's own fee calculator prices it exactly
        uint256 endpointsFee = flareTeeManager.calculateFeeByTeeIds(
            TEE_ORACLE_OP_TYPE, SET_ENDPOINTS_COMMAND, targets);
        assertEq(endpointsFee, INSTRUCTION_FEE);
        address[] memory adminTargets = sender.getAdminsPushTargets(FEED_ID);
        uint256 adminsFee = flareTeeManager.calculateFeeByTeeIds(
            TEE_ORACLE_OP_TYPE, SET_ADMINS_COMMAND, adminTargets);
        vm.startPrank(keeper);
        sender.pushEndpoints{value: endpointsFee}(FEED_ID, targets, loggedGroups);
        sender.pushAdmins{value: adminsFee}(FEED_ID, adminTargets, loggedRoles);
        vm.stopPrank();

        assertTrue(sender.isTeeIdConfigured(FEED_ID, teeId));
        // the instruction fee reached the reward manager, paid by the pusher
        assertEq(rewardManager.balance, 2 * INSTRUCTION_FEE);
        assertEq(keeper.balance, 0);
        assertEq(sender.getEndpointsPushTargets(FEED_ID).length, 0);
        assertEq(sender.getAdminsPushTargets(FEED_ID).length, 0);
    }

    function testPushToAMachineOutOfProductionRevertsInTheDiamond() public {
        // the sender does not pre-check PRODUCTION status - the diamond does. A machine that
        // leaves PRODUCTION leaves the extension's active set, so the straggler view stops
        // offering it, and naming it explicitly reverts with the diamond's own error instead of
        // being silently dropped from a list the caller paid for.
        _publishAndDispatch();
        TeeOracleMachineSetupFacet(address(flareTeeManager)).changeTeeMachineState(
            teeId, IMachineManager.TeeStatus.PAUSED
        );
        (address[] memory publicationTargets, uint256 publicationFee) =
            sender.getEndpointsPublicationFee();
        assertEq(publicationTargets.length, 0, "the machine left the active set");
        assertEq(publicationFee, 0);
        assertEq(sender.getEndpointsPushTargets(FEED_ID).length, 0);

        address[] memory teeIds = new address[](1);
        teeIds[0] = teeId;
        address keeper = makeAddr("keeper");
        vm.deal(keeper, INSTRUCTION_FEE);
        vm.expectRevert(abi.encodeWithSignature("TeeMachineNotAvailable()"));
        vm.prank(keeper);
        sender.pushEndpoints{value: INSTRUCTION_FEE}(FEED_ID, teeIds, _makeGroups());
        assertEq(keeper.balance, INSTRUCTION_FEE, "the fee never left the caller");
    }

    function testPublicationInvalidatesMachinesUntilTheyAdoptIt() public {
        // the store gates on the FEED's latest published generation, so a publication that
        // never reached a machine already rejects that machine's updates
        _publishAndDispatch();
        ITeeOracleFeedStore.FeedUpdate memory feedUpdate = ITeeOracleFeedStore.FeedUpdate({
            extensionId: EXTENSION_ID,
            feedId: FEED_ID,
            value: 99954321,
            decimals: 8,
            observedAt: uint64(vm.getBlockTimestamp()) - 2,
            endpointsHash: sender.latestEndpointsHash(FEED_ID),
            adminsHash: sender.latestAdminsHash(FEED_ID)
        });
        feedStore.submitFeedUpdates(_one(feedUpdate, _sign(feedUpdate)));

        // a second publication: the machine's previous-generation update is already refused,
        // whether or not its new instruction has been executed by the enclave yet
        (, uint256 fee) = sender.getEndpointsPublicationFee();
        vm.deal(initialGovernance, fee);
        vm.prank(initialGovernance);
        sender.setEndpoints{value: fee}(FEED_ID, _makeGroups(), claimBack);
        feedUpdate.observedAt = uint64(vm.getBlockTimestamp()) - 1;
        feedUpdate.value = 12345678;
        vm.expectRevert(ITeeOracleFeedStore.StaleEndpoints.selector);
        feedStore.submitFeedUpdates(_one(feedUpdate, _sign(feedUpdate)));

        // and accepted again as soon as the machine runs the new generation
        feedUpdate.endpointsHash = sender.latestEndpointsHash(FEED_ID);
        feedStore.submitFeedUpdates(_one(feedUpdate, _sign(feedUpdate)));
        (int256 value,,) = feedStore.getCurrentFeed{value: READ_FEE}();
        assertEq(value, 12345678);
    }

    function testPublicationOverpaysWhenTheFleetShrinksAfterTheFeeQuote() public {
        // a second machine joins, so the publication is quoted for two
        (address secondTeeId,) = makeAddrAndKey("secondTeeMachine");
        TeeOracleMachineSetupFacet(address(flareTeeManager)).setupTeeMachineState(
            secondTeeId, EXTENSION_ID, "https://tee2.example.com"
        );
        (address[] memory quoted, uint256 quotedFee) = sender.getEndpointsPublicationFee();
        assertEq(quoted.length, 2);
        assertEq(quotedFee, 2 * INSTRUCTION_FEE);

        // one of them is paused before the execution lands, so it leaves the active set and the
        // quoted value is twice the fee of the single target the publication actually snapshots.
        // L-01, accepted rather than fixed: the diamond enforces only a floor and hands the WHOLE
        // value to the reward manager in the same transaction, so the publication succeeds and the
        // surplus joins that epoch's rewards. Neither the sender nor the diamond offers a claim;
        // the claim-back address is only recorded in the event for the off-chain reward
        // calculation, which decides any return - claimed, if attributed, through the
        // RewardManager. Hence "read the view in the block the execution lands in".
        TeeOracleMachineSetupFacet(address(flareTeeManager)).changeTeeMachineState(
            secondTeeId, IMachineManager.TeeStatus.PAUSED
        );
        (address[] memory fresh, uint256 freshFee) = sender.getEndpointsPublicationFee();
        assertEq(fresh.length, 1);
        assertEq(fresh[0], teeId);
        assertEq(freshFee, INSTRUCTION_FEE);

        vm.deal(initialGovernance, quotedFee);
        vm.prank(initialGovernance);
        sender.setEndpoints{value: quotedFee}(FEED_ID, _makeGroups(), claimBack);
        assertEq(sender.endpointsVersion(FEED_ID), 1, "published");
        assertEq(sender.expectedEndpointsVersion(FEED_ID, teeId), 1);
        assertEq(sender.expectedEndpointsVersion(FEED_ID, secondTeeId), 0, "not a target");
        assertEq(initialGovernance.balance, 0, "the whole value, surplus included, left the payer");
        assertEq(
            rewardManager.balance, quotedFee, "fee AND surplus both went to the reward manager"
        );
    }

    function testSameIdPauseUnpauseKeepsTheRecordedVersionAndIsNotAPushTarget() public {
        // L-02, pinned as current behaviour rather than left accidental: the per-machine record
        // says what was DISPATCHED, and a machine paused and unpaused under the SAME id with no
        // publication in between keeps it.
        _publishAndDispatch();
        assertTrue(sender.isTeeIdConfigured(FEED_ID, teeId));
        assertEq(sender.getEndpointsPushTargets(FEED_ID).length, 0);

        TeeOracleMachineSetupFacet(address(flareTeeManager)).changeTeeMachineState(
            teeId, IMachineManager.TeeStatus.PAUSED
        );
        // out of the active set, so out of the view - which is what makes the view follow the
        // diamond rather than keep its own eligibility rules
        assertEq(sender.getEndpointsPushTargets(FEED_ID).length, 0);
        assertEq(sender.getAdminsPushTargets(FEED_ID).length, 0);

        TeeOracleMachineSetupFacet(address(flareTeeManager)).changeTeeMachineState(
            teeId, IMachineManager.TeeStatus.PRODUCTION
        );
        // back in the active set, still recorded at the latest version, therefore STILL not a push
        // target - even though its enclave may have lost its local state while paused. Nothing on
        // chain can tell the difference, so a keeper must react to restart / lost-state signals of
        // its own and push explicitly; the lagging-target views are not a complete convergence
        // mechanism.
        assertEq(sender.expectedEndpointsVersion(FEED_ID, teeId), 1);
        assertEq(sender.expectedAdminsVersion(FEED_ID, teeId), 1);
        assertEq(sender.getEndpointsPushTargets(FEED_ID).length, 0, "omitted, by design");
        assertEq(sender.getAdminsPushTargets(FEED_ID).length, 0);

        // and the explicit push always works, since it applies no version filter
        address[] memory teeIds = new address[](1);
        teeIds[0] = teeId;
        address keeper = makeAddr("keeper");
        vm.deal(keeper, 2 * INSTRUCTION_FEE);
        vm.startPrank(keeper);
        sender.pushEndpoints{value: INSTRUCTION_FEE}(FEED_ID, teeIds, _makeGroups());
        sender.pushAdmins{value: INSTRUCTION_FEE}(FEED_ID, teeIds, _makeRoles());
        vm.stopPrank();
        assertTrue(sender.isTeeIdConfigured(FEED_ID, teeId));
        assertEq(sender.expectedEndpointsVersion(FEED_ID, teeId), 1, "idempotent re-dispatch");
    }

    function testPushTargetViewsStillReportLaggingMachinesWhileEmergencyPaused() public {
        // I-01, deliberate: unlike get*PublicationFee these views are NOT pause-aware. Their
        // output is a diagnosis, not a value to attach, and "who is behind" stays true while
        // paused - so callers check the pause state separately instead of being blinded exactly
        // when a problem is being diagnosed.
        _publishAndDispatch();
        (address[] memory lateTeeIds,) = flareTeeManager.getActiveTeeMachines(EXTENSION_ID);
        assertEq(lateTeeIds.length, 1);
        // a second machine joins after the publication, so it is genuinely lagging
        (address lateTeeId,) = makeAddrAndKey("lateTeeMachineForPauseView");
        TeeOracleMachineSetupFacet(address(flareTeeManager)).setupTeeMachineState(
            lateTeeId, EXTENSION_ID, "https://late.example.com"
        );
        assertEq(sender.getEndpointsPushTargets(FEED_ID).length, 1);

        vm.prank(extensionOwner);
        flareTeeManager.emergencyPauseExtension(EXTENSION_ID);
        address[] memory targets = sender.getEndpointsPushTargets(FEED_ID);
        assertEq(targets.length, 1, "still reported while paused");
        assertEq(targets[0], lateTeeId);
        assertEq(sender.getAdminsPushTargets(FEED_ID).length, 1);
        // while the ACTIONABLE views do go quiet, mirroring what a publication would do
        (address[] memory publicationTargets, uint256 publicationFee) =
            sender.getEndpointsPublicationFee();
        assertEq(publicationTargets.length, 0);
        assertEq(publicationFee, 0);
        // and acting on the diagnostic without checking the pause reverts in the diamond
        address keeper = makeAddr("keeper");
        vm.deal(keeper, INSTRUCTION_FEE);
        vm.expectRevert(
            abi.encodeWithSignature("EmergencyPauseActive(uint256)", EXTENSION_ID)
        );
        vm.prank(keeper);
        sender.pushEndpoints{value: INSTRUCTION_FEE}(FEED_ID, targets, _makeGroups());
    }

    function testRequestFeedUpdateRejectsAZeroFirstTargetBeforeAskingTheManager() public {
        // L-03: the local rules run before the manager is consulted, so a zero FIRST element is
        // reported as this contract's own ZeroTeeId and not as the registry's TeeNotFound
        _publishAndDispatch();
        address[] memory teeIds = new address[](2);
        teeIds[0] = address(0);
        teeIds[1] = teeId;
        vm.expectRevert(ITeeOracleInstructionsSender.ZeroTeeId.selector);
        sender.requestFeedUpdate(FEED_ID, teeIds);

        // a duplicate first pair is likewise local
        teeIds[0] = teeId;
        teeIds[1] = teeId;
        vm.expectRevert(ITeeOracleInstructionsSender.DuplicateTeeId.selector);
        sender.requestFeedUpdate(FEED_ID, teeIds);
    }

    function testRequestFeedUpdateRejectsAnUnregisteredFirstTargetWithTheManagerError() public {
        // an id that is no machine at all is a question only the registry can answer, so the
        // manager's TeeNotFound is the honest error here
        _publishAndDispatch();
        address[] memory teeIds = new address[](1);
        teeIds[0] = makeAddr("neverRegistered");
        vm.expectRevert(abi.encodeWithSignature("TeeNotFound()"));
        sender.requestFeedUpdate(FEED_ID, teeIds);
    }

    function testEndToEndThresholdFeedFlow() public {
        // three real PRODUCTION machines, one published configuration generation for all of them,
        // and a 2-of-3 threshold: the store stores the median of three genuinely signed
        // observations of the same event
        uint256[] memory keys = _setupMachines(3);
        _publishAndDispatch();
        vm.prank(initialGovernance);
        feedStore.setSubmissionPolicy(_policy(2, 100, 0));

        uint64 observedAt = uint64(vm.getBlockTimestamp()) - 1;
        ITeeOracleFeedStore.SignedFeedUpdate[] memory batch =
            _signedBatch(_int32s(99954321, 99954700, 99954500), 8, observedAt, keys);
        feedStore.submitFeedUpdates(batch);

        (int256 value, int8 decimals, uint64 timestamp) = feedStore.getCurrentFeed{value: READ_FEE}();
        assertEq(value, 99954500, "the middle observation, not the first or the last");
        assertEq(decimals, 8);
        assertEq(timestamp, observedAt);
        // the same batch cannot land twice: the common observedAt ratchets
        vm.expectRevert(ITeeOracleFeedStore.NotNewer.selector);
        feedStore.submitFeedUpdates(batch);
    }

    function testThresholdFlowSubmissionReturnsTheAggregation() public {
        // the submission itself reports what it aggregated, so the dry run an off-chain caller
        // does is an eth_call on THIS function - no separate preview view to drift from it
        uint256[] memory keys = _setupMachines(3);
        _publishAndDispatch();
        vm.prank(initialGovernance);
        feedStore.setSubmissionPolicy(_policy(3, 100, 0));

        ITeeOracleFeedStore.SignedFeedUpdate[] memory batch = _signedBatch(
            _int32s(99954321, 99954700, 99954500), 8, uint64(vm.getBlockTimestamp()) - 1, keys);
        ITeeOracleFeedStore.FeedAggregation memory aggregation = feedStore.submitFeedUpdates(batch);
        assertEq(aggregation.median, 99954500);
        assertEq(aggregation.minValue, 99954321);
        assertEq(aggregation.maxValue, 99954700);
        assertEq(aggregation.decimals, 8);
        assertEq(aggregation.allowedDeviation, 999545, "100 BIPS of abs(median), floored");
        assertEq(aggregation.outlierTeeIds.length, 0, "inside the bound, so no FeedOutliers");
        assertEq(aggregation.outlierDeviations.length, 0);

        // and the stored feed is exactly the returned median
        (int256 value, int8 decimals,) = feedStore.getCurrentFeed{value: READ_FEE}();
        assertEq(value, aggregation.median);
        assertEq(decimals, aggregation.decimals);
    }

    function testThresholdFlowRejectsSpreadTooBig() public {
        uint256[] memory keys = _setupMachines(3);
        _publishAndDispatch();
        vm.prank(initialGovernance);
        feedStore.setSubmissionPolicy(_policy(2, 100, 0));

        // one machine reports 20% away from the others: at N = 3 that machine IS one of the
        // median's neighbours, so the median is not well determined and the batch is refused -
        // the trace names the bracketing values and the median
        ITeeOracleFeedStore.SignedFeedUpdate[] memory batch = _signedBatch(
            _int32s(99954321, 120000000, 99954500), 8, uint64(vm.getBlockTimestamp()) - 1, keys);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeOracleFeedStore.SpreadTooBig.selector, int256(99954321), int256(120000000),
                int256(99954500), int8(8)
            )
        );
        feedStore.submitFeedUpdates(batch);
        // nothing was stored - the feed is still unpublished
        vm.expectRevert(ITeeOracleFeedStore.NoValuePublished.selector);
        feedStore.getCurrentFeed{value: READ_FEE}();
    }

    function testThresholdFlowFlagsAnOutlierAndStillPublishes() public {
        // five real machines, one of them 20% off: at N = 5 the outlier is no longer a neighbour
        // of the median, so the feed updates and the machine is named in FeedOutliers. This is
        // the behaviour a consumer like FAssets depends on - one faulty machine must not be able
        // to stall the feed - while the divergence still lands on chain.
        uint256[] memory keys = _setupMachines(5);
        _publishAndDispatch();
        vm.prank(initialGovernance);
        feedStore.setSubmissionPolicy(_policy(3, 100, 0));

        int32[] memory values = new int32[](5);
        values[0] = 99954000;
        values[1] = 99954250;
        values[2] = 99954500;
        values[3] = 99954750;
        values[4] = 120000000;
        uint64 observedAt = uint64(vm.getBlockTimestamp()) - 1;
        ITeeOracleFeedStore.SignedFeedUpdate[] memory batch =
            _signedBatch(values, 8, observedAt, keys);

        address[] memory expectedTeeIds = new address[](1);
        expectedTeeIds[0] = vm.addr(keys[4]);
        int256[] memory expectedDeviations = new int256[](1);
        expectedDeviations[0] = 120000000 - 99954500;
        vm.expectEmit();
        emit ITeeOracleFeedStore.FeedOutliers(
            observedAt, 99954500, 8, expectedTeeIds, expectedDeviations);
        ITeeOracleFeedStore.FeedAggregation memory aggregation = feedStore.submitFeedUpdates(batch);

        // the returned report is the event's own arrays, so a dry run sees the same divergence
        assertEq(aggregation.outlierTeeIds, expectedTeeIds);
        assertEq(aggregation.outlierDeviations, expectedDeviations);
        assertEq(aggregation.median, 99954500);
        assertEq(aggregation.decimals, 8);

        (int256 value,,) = feedStore.getCurrentFeed{value: READ_FEE}();
        assertEq(value, 99954500);
    }

    function testThresholdFlowRejectsDuplicateSigner() public {
        uint256[] memory keys = _setupMachines(3);
        _publishAndDispatch();
        vm.prank(initialGovernance);
        feedStore.setSubmissionPolicy(_policy(2, 100, 0));

        // the same machine signs two different observations: two valid signatures, one machine,
        // so the threshold is not met
        keys[1] = keys[0];
        ITeeOracleFeedStore.SignedFeedUpdate[] memory batch = _signedBatch(
            _int32s(99954321, 99954400, 99954500), 8, uint64(vm.getBlockTimestamp()) - 1, keys);
        vm.expectRevert(ITeeOracleFeedStore.DuplicateTeeId.selector);
        feedStore.submitFeedUpdates(batch);
    }

    function testThresholdFlowRejectsDemotedMachine() public {
        uint256[] memory keys = _setupMachines(3);
        _publishAndDispatch();
        vm.prank(initialGovernance);
        feedStore.setSubmissionPolicy(_policy(2, 100, 0));

        ITeeOracleFeedStore.SignedFeedUpdate[] memory batch = _signedBatch(
            _int32s(99954321, 99954700, 99954500), 8, uint64(vm.getBlockTimestamp()) - 1, keys);
        // one contributor leaves PRODUCTION between signing and submission: the diamond's own
        // error bubbles and takes the batch with it, rather than the batch quietly proceeding
        // with the remaining two signatures
        TeeOracleMachineSetupFacet(address(flareTeeManager)).changeTeeMachineState(
            vm.addr(keys[2]), IMachineManager.TeeStatus.PAUSED
        );
        vm.expectRevert(abi.encodeWithSignature("TeeMachineNotAvailable()"));
        feedStore.submitFeedUpdates(batch);
    }

    function testThresholdFlowRejectsMixedConfigGenerations() public {
        uint256[] memory keys = _setupMachines(3);
        _publishAndDispatch();
        vm.prank(initialGovernance);
        feedStore.setSubmissionPolicy(_policy(2, 100, 0));

        ITeeOracleFeedStore.SignedFeedUpdate[] memory batch = _signedBatch(
            _int32s(99954321, 99954700, 99954500), 8, uint64(vm.getBlockTimestamp()) - 1, keys);
        // one machine still runs the previous generation - a mid-rollout batch is refused as a
        // whole, which is why a threshold is a reason to keep the fleet configuration homogeneous
        batch[1].feedUpdate.endpointsHash = keccak256("previous generation");
        batch[1].signature = _signWith(keys[1], batch[1].feedUpdate);
        vm.expectRevert(ITeeOracleFeedStore.StaleEndpoints.selector);
        feedStore.submitFeedUpdates(batch);
    }

    function testThresholdFlowPausedExtensionRejectsTheWholeBatch() public {
        uint256[] memory keys = _setupMachines(3);
        _publishAndDispatch();
        vm.prank(initialGovernance);
        feedStore.setSubmissionPolicy(_policy(2, 100, 0));
        vm.prank(extensionOwner);
        flareTeeManager.emergencyPauseExtension(EXTENSION_ID);

        ITeeOracleFeedStore.SignedFeedUpdate[] memory batch = _signedBatch(
            _int32s(99954321, 99954700, 99954500), 8, uint64(vm.getBlockTimestamp()) - 1, keys);
        vm.expectRevert(
            abi.encodeWithSignature("ExtensionEmergencyPaused(uint256)", EXTENSION_ID));
        feedStore.submitFeedUpdates(batch);
    }

    function testThresholdFlowGas() public {
        // the same measurement as the unit suite's, but against the REAL Fdc2Verification and a
        // real diamond: this is what a contributing signature actually costs (ecrecover plus the
        // machine lookup). Reported in docs/tee-oracle-threshold-feed-plan-2026-08-31.md.
        uint256[] memory keys = _setupMachines(9);
        _publishAndDispatch();

        // warm-up, so the measurements below are on a dirty slot and warm callees
        _measureThresholdGas(1, keys, uint64(vm.getBlockTimestamp()) - 5);
        emit log_named_uint(
            "gas N=1 (real verifier)",
            _measureThresholdGas(1, keys, uint64(vm.getBlockTimestamp()) - 4)
        );
        emit log_named_uint(
            "gas N=3 (real verifier)",
            _measureThresholdGas(3, keys, uint64(vm.getBlockTimestamp()) - 3)
        );
        emit log_named_uint(
            "gas N=5 (real verifier)",
            _measureThresholdGas(5, keys, uint64(vm.getBlockTimestamp()) - 2)
        );
        emit log_named_uint(
            "gas N=9 (real verifier)",
            _measureThresholdGas(9, keys, uint64(vm.getBlockTimestamp()) - 1)
        );
    }

    // -------------------------------------------------------------------------
    // helpers
    // -------------------------------------------------------------------------

    /// Submits a `_count`-element batch signed by the first `_count` machines and returns the gas
    /// the call consumed.
    function _measureThresholdGas(
        uint256 _count,
        uint256[] memory _keys,
        uint64 _observedAt
    )
        private
        returns (uint256)
    {
        vm.prank(initialGovernance);
        feedStore.setSubmissionPolicy(_policy(uint8(_count), 100, 0));
        uint256[] memory keys = new uint256[](_count);
        for (uint256 i = 0; i < _count; i++) {
            keys[i] = _keys[i];
        }
        ITeeOracleFeedStore.SignedFeedUpdate[] memory batch =
            _signedBatch(_uniformValues(_count, 99954321), 8, _observedAt, keys);
        uint256 gasBefore = gasleft();
        feedStore.submitFeedUpdates(batch);
        return gasBefore - gasleft();
    }

    /// Registers `_count - 1` further PRODUCTION machines on the extension (setUp registers the
    /// first) and returns all signing keys. Called by the threshold tests only, so the
    /// single-machine tests keep their exact active-set expectations.
    function _setupMachines(uint256 _count)
        private
        returns (uint256[] memory _keys)
    {
        _keys = new uint256[](_count);
        _keys[0] = teePrivateKey;
        for (uint256 i = 1; i < _count; i++) {
            (address extraTeeId, uint256 extraKey) =
                makeAddrAndKey(string.concat("teeMachine", vm.toString(i + 1)));
            TeeOracleMachineSetupFacet(address(flareTeeManager)).setupTeeMachineState(
                extraTeeId, EXTENSION_ID, "https://tee.example.com"
            );
            _keys[i] = extraKey;
        }
    }

    /// Deploys the feed store with the deployment-default submission policy, through the shared
    /// test deployer (see `TeeOracleFeedStoreDeployer` for why the `new` lives there).
    function _deployFeedStore()
        private
    {
        feedStore = new TeeOracleFeedStoreDeployer().deploy(
            IGovernanceSettings(address(this)),
            initialGovernance,
            addressUpdater,
            ITeeOracleInstructionsSender(address(sender)),
            FEED_ID,
            feeDestination,
            ITeeOracleFeedStore.SubmissionPolicy({
                requiredSignatures: REQUIRED_SIGNATURES,
                maxSpreadBIPS: MAX_SPREAD_BIPS,
                maxSpreadAbsolute: MAX_SPREAD_ABSOLUTE
            })
        );
    }

    /// Publishes both configuration kinds for the feed with enough value attached for the
    /// extension's whole live active set, so the publication's auto-dispatch delivers them.
    function _publishAndDispatch()
        private
    {
        (address[] memory active,) = flareTeeManager.getActiveTeeMachines(EXTENSION_ID);
        uint256 fee = active.length * INSTRUCTION_FEE;
        // the version is assigned by the contract, so this helper works on an already-published
        // feed exactly as it does on a fresh one
        vm.deal(initialGovernance, 2 * fee);
        vm.startPrank(initialGovernance);
        sender.setEndpoints{value: fee}(FEED_ID, _makeGroups(), claimBack);
        sender.setAdmins{value: fee}(FEED_ID, _makeRoles(), claimBack);
        vm.stopPrank();
    }

    /// A one-element submission batch. `submitFeedUpdates` is the only submission entry point,
    /// so a single signature is submitted as an array of one - which is also exactly the
    /// threshold-1 case these tests exercise.
    function _one(
        ITeeOracleFeedStore.FeedUpdate memory _feedUpdate,
        Signature memory _signature
    )
        private pure
        returns (ITeeOracleFeedStore.SignedFeedUpdate[] memory _batch)
    {
        _batch = new ITeeOracleFeedStore.SignedFeedUpdate[](1);
        _batch[0] = ITeeOracleFeedStore.SignedFeedUpdate(_feedUpdate, _signature);
    }

    function _signedBatch(
        int32[] memory _valuesPerElement,
        int8 _decimals,
        uint64 _observedAt,
        uint256[] memory _keys
    )
        private view
        returns (ITeeOracleFeedStore.SignedFeedUpdate[] memory _batch)
    {
        _batch = new ITeeOracleFeedStore.SignedFeedUpdate[](_valuesPerElement.length);
        for (uint256 i = 0; i < _valuesPerElement.length; i++) {
            ITeeOracleFeedStore.FeedUpdate memory feedUpdate = ITeeOracleFeedStore.FeedUpdate({
                extensionId: EXTENSION_ID,
                feedId: FEED_ID,
                value: _valuesPerElement[i],
                decimals: _decimals,
                observedAt: _observedAt,
                endpointsHash: sender.latestEndpointsHash(FEED_ID),
                adminsHash: sender.latestAdminsHash(FEED_ID)
            });
            _batch[i] = ITeeOracleFeedStore.SignedFeedUpdate({
                feedUpdate: feedUpdate,
                signature: _signWith(_keys[i], feedUpdate)
            });
        }
    }

    function _signWith(
        uint256 _privateKey,
        ITeeOracleFeedStore.FeedUpdate memory _feedUpdate
    )
        private view
        returns (Signature memory)
    {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            _privateKey,
            SignedPayload.ethSignedHash(TEE_ORACLE_FEED, keccak256(abi.encode(_feedUpdate)))
        );
        return Signature(v, r, s);
    }

    function _sign(
        ITeeOracleFeedStore.FeedUpdate memory _feedUpdate
    )
        private view
        returns (Signature memory)
    {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            teePrivateKey,
            SignedPayload.ethSignedHash(TEE_ORACLE_FEED, keccak256(abi.encode(_feedUpdate)))
        );
        return Signature(v, r, s);
    }

    function _policy(
        uint8 _requiredSignatures,
        uint16 _maxSpreadBIPS,
        uint64 _maxSpreadAbsolute
    )
        private pure
        returns (ITeeOracleFeedStore.SubmissionPolicy memory)
    {
        return ITeeOracleFeedStore.SubmissionPolicy({
            requiredSignatures: _requiredSignatures,
            maxSpreadBIPS: _maxSpreadBIPS,
            maxSpreadAbsolute: _maxSpreadAbsolute
        });
    }

    function _int32s(int32 _a, int32 _b, int32 _c)
        private pure
        returns (int32[] memory _list)
    {
        _list = new int32[](3);
        _list[0] = _a;
        _list[1] = _b;
        _list[2] = _c;
    }

    /// `_count` elements all reporting the same value, so the deviation bound is out of the way.
    function _uniformValues(uint256 _count, int32 _value)
        private pure
        returns (int32[] memory _list)
    {
        _list = new int32[](_count);
        for (uint256 i = 0; i < _count; i++) {
            _list[i] = _value;
        }
    }

    /// The groups carried by the last `EndpointsPublished` log - how a keeper actually obtains the
    /// values it hands straight back to `pushEndpoints`, since nothing stores them.
    function _groupsFromLogs(
        Vm.Log[] memory _logs
    )
        private pure
        returns (ITeeOracleInstructionsSender.EndpointGroup[] memory _groups)
    {
        bool found = false;
        for (uint256 i = 0; i < _logs.length; i++) {
            Vm.Log memory entry = _logs[i];
            if (entry.topics[0] == ITeeOracleInstructionsSender.EndpointsPublished.selector) {
                (, _groups) = abi.decode(
                    entry.data, (bytes32, ITeeOracleInstructionsSender.EndpointGroup[]));
                found = true;
            }
        }
        require(found, "no EndpointsPublished log");
    }

    /// See `_groupsFromLogs`.
    function _rolesFromLogs(
        Vm.Log[] memory _logs
    )
        private pure
        returns (ITeeOracleInstructionsSender.AdminRole[] memory _roles)
    {
        bool found = false;
        for (uint256 i = 0; i < _logs.length; i++) {
            Vm.Log memory entry = _logs[i];
            if (entry.topics[0] == ITeeOracleInstructionsSender.AdminsPublished.selector) {
                (, _roles) = abi.decode(
                    entry.data, (bytes32, ITeeOracleInstructionsSender.AdminRole[]));
                found = true;
            }
        }
        require(found, "no AdminsPublished log");
    }

    function _makeGroups()
        private pure
        returns (ITeeOracleInstructionsSender.EndpointGroup[] memory _groups)
    {
        ITeeOracleInstructionsSender.Endpoint[] memory endpoints =
            new ITeeOracleInstructionsSender.Endpoint[](2);
        endpoints[0] = ITeeOracleInstructionsSender.Endpoint({
            kind: ITeeOracleInstructionsSender.EndpointKind.PUBLIC,
            url: "https://flare-api.flare.network/ext/C/rpc",
            urlHash: bytes32(0),
            secretRef: ""
        });
        endpoints[1] = ITeeOracleInstructionsSender.Endpoint({
            kind: ITeeOracleInstructionsSender.EndpointKind.PRIVATE,
            url: "",
            urlHash: keccak256("salted private url"),
            secretRef: "hex_cash_url"
        });
        _groups = new ITeeOracleInstructionsSender.EndpointGroup[](1);
        _groups[0] = ITeeOracleInstructionsSender.EndpointGroup({
            group: bytes32("flare"),
            threshold: 1,
            endpoints: endpoints
        });
    }

    function _makeRoles()
        private pure
        returns (ITeeOracleInstructionsSender.AdminRole[] memory _roles)
    {
        address[] memory backingAdmins = new address[](1);
        backingAdmins[0] = address(uint160(0xB001));
        address[] memory providerAdmins = new address[](2);
        providerAdmins[0] = address(uint160(0xA001));
        providerAdmins[1] = address(uint160(0xA002));
        _roles = new ITeeOracleInstructionsSender.AdminRole[](2);
        _roles[0] = ITeeOracleInstructionsSender.AdminRole({
            role: bytes32("backing"),
            threshold: 1,
            admins: backingAdmins
        });
        _roles[1] = ITeeOracleInstructionsSender.AdminRole({
            role: bytes32("providers"),
            threshold: 2,
            admins: providerAdmins
        });
    }
}
