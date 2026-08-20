// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { FlareTeeManagerDeployer } from "../utils/FlareTeeManagerDeployer.sol";
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
    TeeOracleFeedStoreProxy
} from "../../contracts/tee/extensions/oracle/proxy/TeeOracleFeedStoreProxy.sol";
import {
    ITeeOracleInstructionsSender
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
}

/**
 * @title TeeOracleIntegrationTest
 * @notice End-to-end flow of the TEE oracle extension against a real FlareTeeManager
 *         diamond and a real Fdc2Verification: reserved extension registration, sender
 *         wiring, configuration publications, a feed update request through the diamond,
 *         a genuinely signed feed update submission, and the paid feed read.
 */
contract TeeOracleIntegrationTest is Test {

    uint256 private constant EXTENSION_ID = 1;
    bytes21 private constant FEED_ID = bytes21(bytes.concat(bytes1(uint8(0x20)), bytes("USDX/USD")));
    uint256 private constant INSTRUCTION_FEE = 1000; // diamond default fee
    uint256 private constant READ_FEE = 3;

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
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = TeeOracleMachineSetupFacet.setupTeeMachineState.selector;
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

        TeeOracleFeedStore feedStoreImpl = new TeeOracleFeedStore();
        feedStore = TeeOracleFeedStore(address(new TeeOracleFeedStoreProxy(
            IGovernanceSettings(address(this)),
            initialGovernance,
            addressUpdater,
            ITeeOracleInstructionsSender(address(sender)),
            FEED_ID,
            feeDestination,
            address(feedStoreImpl)
        )));
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
        // 1. governance publishes endpoints and admins to the machine (pre-production:
        //    immediate execution; the fee rides as msg.value straight to the diamond)
        address[] memory teeIds = new address[](1);
        teeIds[0] = teeId;
        vm.deal(initialGovernance, 2 * INSTRUCTION_FEE);
        vm.startPrank(initialGovernance);
        sender.setEndpoints{value: INSTRUCTION_FEE}(FEED_ID, teeIds, _makeGroups(), claimBack);
        sender.setAdmins{value: INSTRUCTION_FEE}(FEED_ID, teeIds, _makeRoles(), claimBack);
        vm.stopPrank();
        assertEq(sender.expectedEndpointsVersion(FEED_ID, teeId), 1);
        assertEq(sender.expectedAdminsVersion(FEED_ID, teeId), 1);
        // the whole instruction fee reached the reward manager
        assertEq(rewardManager.balance, 2 * INSTRUCTION_FEE);

        // 2. anyone requests a feed update from the configured machine
        address requester = makeAddr("requester");
        vm.deal(requester, INSTRUCTION_FEE);
        vm.prank(requester);
        bytes32 instructionId =
            sender.requestFeedUpdate{value: INSTRUCTION_FEE}(FEED_ID, teeIds);
        assertNotEq(instructionId, bytes32(0));

        // 3. the machine answers with a signed feed update carrying its current commitments
        ITeeOracleFeedStore.FeedUpdate memory feedUpdate = ITeeOracleFeedStore.FeedUpdate({
            extensionId: EXTENSION_ID,
            feedId: FEED_ID,
            value: 99954321,
            decimals: 8,
            observedAt: uint64(vm.getBlockTimestamp()) - 1,
            endpointsHash: sender.expectedEndpointsHash(FEED_ID, teeId),
            adminsHash: sender.expectedAdminsHash(FEED_ID, teeId)
        });
        feedStore.submitFeedUpdate(feedUpdate, _sign(feedUpdate));

        // 4. the paid read serves the value; the read fee reaches the fee destination
        (int256 value, int8 decimals, uint64 timestamp) = feedStore.getCurrentFeed{value: READ_FEE}();
        assertEq(value, 99954321);
        assertEq(decimals, 8);
        assertEq(timestamp, uint64(vm.getBlockTimestamp()) - 1);
        assertEq(feeDestination.balance, READ_FEE);
    }

    function testSubmitFeedUpdateRejectsUnregisteredSigner() public {
        // a signer that is not a machine at all fails inside the diamond's machine lookup
        // (the revert bubbles through the real verifier and the store untouched)
        (, uint256 foreignKey) = makeAddrAndKey("foreignSigner");
        ITeeOracleFeedStore.FeedUpdate memory feedUpdate = ITeeOracleFeedStore.FeedUpdate({
            extensionId: EXTENSION_ID,
            feedId: FEED_ID,
            value: 1,
            decimals: 0,
            observedAt: uint64(vm.getBlockTimestamp()) - 1,
            endpointsHash: keccak256("endpoints"),
            adminsHash: keccak256("admins")
        });
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            foreignKey,
            SignedPayload.ethSignedHash(TEE_ORACLE_FEED, keccak256(abi.encode(feedUpdate)))
        );
        vm.expectRevert(abi.encodeWithSignature("TeeNotFound()"));
        feedStore.submitFeedUpdate(feedUpdate, Signature(v, r, s));
    }

    function testSubmitFeedUpdateRejectsTamperedUpdate() public {
        // publish commitments so only the signature binding can fail
        address[] memory teeIds = new address[](1);
        teeIds[0] = teeId;
        vm.deal(initialGovernance, 2 * INSTRUCTION_FEE);
        vm.startPrank(initialGovernance);
        sender.setEndpoints{value: INSTRUCTION_FEE}(FEED_ID, teeIds, _makeGroups(), claimBack);
        sender.setAdmins{value: INSTRUCTION_FEE}(FEED_ID, teeIds, _makeRoles(), claimBack);
        vm.stopPrank();

        ITeeOracleFeedStore.FeedUpdate memory feedUpdate = ITeeOracleFeedStore.FeedUpdate({
            extensionId: EXTENSION_ID,
            feedId: FEED_ID,
            value: 99954321,
            decimals: 8,
            observedAt: uint64(vm.getBlockTimestamp()) - 1,
            endpointsHash: sender.expectedEndpointsHash(FEED_ID, teeId),
            adminsHash: sender.expectedAdminsHash(FEED_ID, teeId)
        });
        Signature memory signature = _sign(feedUpdate);

        // tampering with the signed value changes the digest, so recovery yields a
        // different address that is no machine at all
        feedUpdate.value = 1;
        vm.expectRevert(abi.encodeWithSignature("TeeNotFound()"));
        feedStore.submitFeedUpdate(feedUpdate, signature);
    }

    // -------------------------------------------------------------------------
    // helpers
    // -------------------------------------------------------------------------

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
