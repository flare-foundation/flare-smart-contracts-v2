// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { TeeExtensionRegistry } from "../../../../contracts/tee/implementation/TeeExtensionRegistry.sol";
import { ITeeExtensionRegistry } from "../../../../contracts/userInterfaces/tee/ITeeExtensionRegistry.sol";
import { TeeExtensionRegistryProxy } from "../../../../contracts/tee/proxy/TeeExtensionRegistryProxy.sol";
import { ITeeExtensionStateVerifier } from "../../../../contracts/userInterfaces/tee/ITeeExtensionStateVerifier.sol";
import { ITeeWalletProjectOpTypeConstants } from
    "../../../../contracts/userInterfaces/tee/ITeeWalletProjectOpTypeConstants.sol";
import { ITeeMachineRegistry } from "../../../../contracts/userInterfaces/tee/ITeeMachineRegistry.sol";
import { ITeeGovernance } from "../../../../contracts/userInterfaces/tee/ITeeGovernance.sol";
import { ITeeFeeCalculator } from "../../../../contracts/userInterfaces/tee/ITeeFeeCalculator.sol";
import { IGovernanceSettings } from "flare-smart-contracts/contracts/userInterfaces/IGovernanceSettings.sol";
import { ProtocolsV2Interface } from "../../../../contracts/userInterfaces/LTS/ProtocolsV2Interface.sol";
import { IIRewardManager } from "../../../../contracts/protocol/interface/IIRewardManager.sol";

// solhint-disable-next-line max-states-count
contract TeeExtensionRegistryTest is Test {

    TeeExtensionRegistry private teeExtensionRegistry;
    TeeExtensionRegistry private teeExtensionRegistryImpl;
    TeeExtensionRegistryProxy private teeExtensionRegistryProxy;

    address private initialGovernance;
    address private addressUpdater;
    address private teeMachineRegistry;
    address private teeFeeCalculator;
    address private flareSystemsManager;
    address private rewardManager;
    address private teeGovernance;

    bytes32 private instructionId;
    address[] private teeIds;
    bytes32 private opType;
    bytes32[] private opTypes;
    bytes32 private opCommand;
    bytes private message;
    uint256 private extensionId;
    address[] private instructionInitiators;
    ITeeExtensionStateVerifier private teeExtensionStateVerifier;
    address private owner;
    address private newOwner;
    uint24 private currentRewardEpochId;
    string private url;
    string private version;
    bytes32 private codeHash;
    bytes32 private governanceHash;
    bytes32 private platform;
    bytes32[] private platforms;
    ITeeWalletProjectOpTypeConstants[] private opTypeConstantsProviders;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;


    function setUp() public {
        owner = makeAddr("owner");
        newOwner = makeAddr("newOwner");
        instructionId = keccak256("instructionId");
        teeIds = new address[](2);
        teeIds[0] = makeAddr("teeId1");
        teeIds[1] = makeAddr("teeId2");
        opType = keccak256("opType");
        opTypes = new bytes32[](1);
        opTypes[0] = opType;
        opCommand = keccak256("opCommand");
        message = abi.encode("message");
        extensionId = 1;
        instructionInitiators = new address[](1);
        instructionInitiators[0] = address(this);
        currentRewardEpochId = 1;
        url = "url";
        version = "1.0";
        codeHash = keccak256("codeHash");
        governanceHash = keccak256("governanceHash");
        platform = keccak256("GOOGLE_INTEL");
        platforms = new bytes32[](1);
        platforms[0] = platform;
        opTypeConstantsProviders = new ITeeWalletProjectOpTypeConstants[](1);
        opTypeConstantsProviders[0] = ITeeWalletProjectOpTypeConstants(makeAddr("opTypeConstantsProviders"));

        initialGovernance = makeAddr("initialGovernance");
        addressUpdater = makeAddr("addressUpdater");

        teeExtensionRegistryImpl = new TeeExtensionRegistry();
        teeExtensionRegistryProxy = new TeeExtensionRegistryProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            initialGovernance,
            addressUpdater,
            address(teeExtensionRegistryImpl)
        );
        teeExtensionRegistry = TeeExtensionRegistry(address(teeExtensionRegistryProxy));

        contractNameHashes = new bytes32[](6);
        contractAddresses = new address[](6);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("TeeGovernance"));
        contractNameHashes[2] = keccak256(abi.encode("TeeMachineRegistry"));
        contractNameHashes[3] = keccak256(abi.encode("TeeFeeCalculator"));
        contractNameHashes[4] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[5] = keccak256(abi.encode("RewardManager"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = makeAddr("TeeGovernance");
        contractAddresses[2] = makeAddr("TeeMachineRegistry");
        contractAddresses[3] = makeAddr("TeeFeeCalculator");
        contractAddresses[4] = makeAddr("FlareSystemsManager");
        contractAddresses[5] = makeAddr("RewardManager");

        vm.prank(addressUpdater);
        teeExtensionRegistry.updateContractAddresses(contractNameHashes, contractAddresses);

        teeMachineRegistry = address(teeExtensionRegistry.teeMachineRegistry());
        teeFeeCalculator = address(teeExtensionRegistry.teeFeeCalculator());
        rewardManager = address(teeExtensionRegistry.rewardManager());
        teeGovernance = address(teeExtensionRegistry.teeGovernance());
        flareSystemsManager = address(teeExtensionRegistry.flareSystemsManager());

        _mockGetExtensionId(teeIds[0], extensionId);
        _mockGetExtensionId(teeIds[1], extensionId);
        _mockCalculateFeeByTeeIds(0);
        _mockGetTeeMachineStatus(ITeeMachineRegistry.TeeStatus.PRODUCTION);
        _mockGetTeeMachine(teeIds[0]);
        _mockGetTeeMachine(teeIds[1]);
        _mockGetLatestTeeGovernanceHash(governanceHash);
        _mockGetOpType(opType);

        vm.mockCall(
            flareSystemsManager,
            abi.encodeWithSelector(
                ProtocolsV2Interface.getCurrentRewardEpochId.selector
            ),
            abi.encode(currentRewardEpochId)
        );

        vm.mockCall(
            rewardManager,
            abi.encodeWithSelector(
                IIRewardManager.receiveRewards.selector
            ),
            abi.encode("")
        );
    }


    // sendInstructions
    function testSendInstructionsRevertInstructionIdEmpty() public {
        vm.expectRevert(ITeeExtensionRegistry.InstructionIdEmpty.selector);
        teeExtensionRegistry.sendInstructions(bytes32(0), teeIds, opType, opCommand, message, new address[](0), 0);
    }


    function testSendInstructionsRevertNoTeeMachinesSpecified() public {
        vm.expectRevert(ITeeExtensionRegistry.NoTeeMachinesSpecified.selector);
        teeExtensionRegistry.sendInstructions(
            instructionId, new address[](0), opType, opCommand, message, new address[](0), 0
        );
    }


    function testSendInstructionsRevertOperationTypeEmpty() public {
        vm.expectRevert(ITeeExtensionRegistry.OperationTypeEmpty.selector);
        teeExtensionRegistry.sendInstructions(
            instructionId, teeIds, bytes32(0), opCommand, message, new address[](0), 0
        );
    }


    function testSendInstructionsRevertOperationCommandEmpty() public {
        vm.expectRevert(ITeeExtensionRegistry.OperationCommandEmpty.selector);
        teeExtensionRegistry.sendInstructions(instructionId, teeIds, opType, bytes32(0), message, new address[](0), 0);
    }


    function testSendInstructionsRevertMessageEmpty() public {
        vm.expectRevert(ITeeExtensionRegistry.MessageEmpty.selector);
        teeExtensionRegistry.sendInstructions(
            instructionId, teeIds, opType, opCommand, new bytes(0), new address[](0), 0
        );
    }


    function testSendInstructionsRevertExtensionIdMismatch() public {
        _mockGetExtensionId(teeIds[1], extensionId + 1);
        vm.expectRevert(ITeeExtensionRegistry.ExtensionIdMismatch.selector);
        teeExtensionRegistry.sendInstructions(instructionId, teeIds, opType, opCommand, message, new address[](0), 0);
    }


    function testSendInstructionsRevertOnlyInstructionsSender() public {
        vm.expectRevert(ITeeExtensionRegistry.OnlyInstructionsSender.selector);
        teeExtensionRegistry.sendInstructions(instructionId, teeIds, opType, opCommand, message, new address[](0), 0);
    }


    function testSendInstructionsRevertSystemOpTypeNotAllowed() public {
        testRegister();
        opType = bytes32("F_");
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeExtensionRegistry.SystemOpTypeNotAllowed.selector,
                opType
            )
        );
        teeExtensionRegistry.sendInstructions(instructionId, teeIds, opType, opCommand, message, new address[](0), 0);
    }


    function testSendInstructionsRevertFeeTooLow() public {
        testRegister();
        _mockCalculateFeeByTeeIds(100000);
        vm.expectRevert(ITeeExtensionRegistry.FeeTooLow.selector);
        teeExtensionRegistry.sendInstructions(instructionId, teeIds, opType, opCommand, message, new address[](0), 0);
    }


    function testSendInstructionsRevertTeeMachineNotAvailable() public {
        testRegister();
        _mockGetTeeMachineStatus(ITeeMachineRegistry.TeeStatus.PAUSED);
        vm.expectRevert(ITeeExtensionRegistry.TeeMachineNotAvailable.selector);
        teeExtensionRegistry.sendInstructions(instructionId, teeIds, opType, opCommand, message, new address[](0), 0);
    }

    function testSendInstructionsRevertCosignersThresholdTooHigh() public {
        testRegister();
        vm.expectRevert(ITeeExtensionRegistry.CosignersThresholdTooHigh.selector);
        teeExtensionRegistry.sendInstructions(instructionId, teeIds, opType, opCommand, message, new address[](0), 1);
    }


    function testSendInstructions() public {
        ITeeMachineRegistry.TeeMachine[] memory teeMachines = new ITeeMachineRegistry.TeeMachine[](2);
        teeMachines[0] = ITeeMachineRegistry.TeeMachine(
            teeIds[0],
            teeIds[0],
            url
        );
        teeMachines[1] = ITeeMachineRegistry.TeeMachine(
            teeIds[1],
            teeIds[1],
            url
        );
        testRegister();
        vm.expectEmit();
        address[] memory cosigners = new address[](2);
        cosigners[0] = makeAddr("cosigner1");
        cosigners[1] = makeAddr("cosigner2");
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            extensionId,
            instructionId,
            currentRewardEpochId,
            teeMachines,
            opType,
            opCommand,
            message,
            cosigners,
            1,
            0
        );
        teeExtensionRegistry.sendInstructions(instructionId, teeIds, opType, opCommand, message, cosigners, 1);
    }


    // register
    function testRegisterRevertInvalidInstructionsSender() public {
        vm.expectRevert(ITeeExtensionRegistry.InvalidInstructionsSender.selector);
        teeExtensionRegistry.register(teeExtensionStateVerifier, address(0));
    }


    function testRegister() public {
        vm.prank(owner);
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeExtensionRegistered(extensionId, owner);
        emit ITeeExtensionRegistry.TeeExtensionContractsSet(
            extensionId, teeExtensionStateVerifier, address(this)
        );
        teeExtensionRegistry.register(teeExtensionStateVerifier, address(this));
    }


    // setExtensionContracts
    function testSetExtensionContractsRevertOnlyOwner() public {
        testRegister();
        vm.expectRevert(ITeeExtensionRegistry.OnlyOwner.selector);
        teeExtensionRegistry.setExtensionContracts(extensionId, teeExtensionStateVerifier, owner);
    }


    function testSetExtensionContractsRevertInvalidInstructionsSender() public {
        testRegister();
        vm.prank(owner);
        vm.expectRevert(ITeeExtensionRegistry.InvalidInstructionsSender.selector);
        teeExtensionRegistry.setExtensionContracts(extensionId, teeExtensionStateVerifier, address(0));
    }


    function testSetExtensionContracts() public {
        testRegister();
        vm.prank(owner);
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeExtensionContractsSet(
            extensionId, teeExtensionStateVerifier, owner
        );
        teeExtensionRegistry.setExtensionContracts(extensionId, teeExtensionStateVerifier, owner);
    }


    // addTeeVersion
    function testAddTeeVersionRevertOnlyOwner() public {
        vm.expectRevert(ITeeExtensionRegistry.OnlyOwner.selector);
        teeExtensionRegistry.addTeeVersion(extensionId, version, codeHash, platforms, governanceHash);
    }


    function testAddTeeVersionRevertVersionEmpty() public {
        testRegister();
        vm.prank(owner);
        vm.expectRevert(ITeeExtensionRegistry.VersionEmpty.selector);
        teeExtensionRegistry.addTeeVersion(extensionId, "", codeHash, platforms, governanceHash);
    }


    function testAddTeeVersionRevertCodeHashZero() public {
        testRegister();
        vm.prank(owner);
        vm.expectRevert(ITeeExtensionRegistry.CodeHashZero.selector);
        teeExtensionRegistry.addTeeVersion(extensionId, version, "", platforms, governanceHash);
    }


    function testAddTeeVersionRevertNoPlatforms() public {
        testRegister();
        vm.prank(owner);
        vm.expectRevert(ITeeExtensionRegistry.NoPlatforms.selector);
        teeExtensionRegistry.addTeeVersion(extensionId, version, codeHash, new bytes32[](0), governanceHash);
    }


    function testAddTeeVersionRevertUnsupportedPlatform() public {
        testRegister();
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeExtensionRegistry.UnsupportedPlatform.selector,
                platforms[0]
            )
        );
        teeExtensionRegistry.addTeeVersion(extensionId, version, codeHash, platforms, governanceHash);
    }


    function testAddTeeVersionRevertVersionAlreadyExists() public {
        testAddTeeVersion();
        vm.prank(owner);
        vm.expectRevert(ITeeExtensionRegistry.VersionAlreadyExists.selector);
        teeExtensionRegistry.addTeeVersion(extensionId, version, codeHash, platforms, governanceHash);
    }


    function testAddTeeVersionRevertPlatformAlreadyExists() public {
        testRegister();
        testAddSupportedPlatforms();
        platforms = new bytes32[](2);
        platforms[0] = platform;
        platforms[1] = platforms[0];
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeExtensionRegistry.PlatformAlreadyExists.selector,
                platforms[1]
            )
        );
        teeExtensionRegistry.addTeeVersion(extensionId, version, codeHash, platforms, governanceHash);
    }


    function testAddTeeVersionRevertInvalidGovernanceHash() public {
        testRegister();
        testAddSupportedPlatforms();
        _mockGetLatestTeeGovernanceHash(keccak256("invalidGovernanceHash"));
        vm.prank(owner);
        vm.expectRevert(ITeeGovernance.InvalidGovernanceHash.selector);
        teeExtensionRegistry.addTeeVersion(extensionId, version, codeHash, platforms, governanceHash);
    }


    function testAddTeeVersion() public {
        testRegister();
        testAddSupportedPlatforms();
        vm.prank(owner);
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeVersionAdded(
            extensionId, codeHash, version, platforms, governanceHash
        );
        teeExtensionRegistry.addTeeVersion(extensionId, version, codeHash, platforms, governanceHash);
    }


    // disableCodeHashPlatform
    function testDisableCodeHashPlatformRevertOnlyOwner() public {
        testRegister();
        vm.expectRevert(ITeeExtensionRegistry.OnlyOwner.selector);
        teeExtensionRegistry.disableCodeHashPlatform(extensionId, codeHash, platform);
        vm.expectRevert(ITeeExtensionRegistry.OnlyOwner.selector);
        teeExtensionRegistry.disableCodeHashPlatform(extensionId + 1, codeHash, platform);
    }


    function testDisableCodeHashPlatformRevertInvalidCodeHash() public {
        testRegister();
        vm.prank(owner);
        vm.expectRevert(ITeeExtensionRegistry.InvalidCodeHash.selector);
        teeExtensionRegistry.disableCodeHashPlatform(extensionId, keccak256("invalidCodeHash"), platform);
    }


    function testDisableCodeHashPlatformRevertInvalidPlatform() public {
        testAddTeeVersion();
        vm.prank(owner);
        vm.expectRevert(ITeeExtensionRegistry.InvalidPlatform.selector);
        teeExtensionRegistry.disableCodeHashPlatform(extensionId, codeHash, keccak256("invalidPlatform"));
    }


    function testDisableCodeHashPlatform() public {
        testAddTeeVersion();
        vm.prank(owner);
        vm.expectEmit();
        emit ITeeExtensionRegistry.CodeHashPlatformDisabled(extensionId, codeHash, platform);
        teeExtensionRegistry.disableCodeHashPlatform(extensionId, codeHash, platform);
    }


    function testDisableCodeHashPlatformAll() public {
        testAddTeeVersion();
        vm.prank(owner);
        vm.expectEmit();
        emit ITeeExtensionRegistry.CodeHashPlatformDisabled(extensionId, codeHash, platform);
        teeExtensionRegistry.disableCodeHashPlatform(extensionId, codeHash, bytes32(0));
    }


    // addOrUpdateSupportedWalletProjectOpTypes
    function testAddOrUpdateSupportedWalletProjectOpTypesRevertOnlyOwner() public {
        testRegister();
        vm.expectRevert(ITeeExtensionRegistry.OnlyOwner.selector);
        teeExtensionRegistry.addOrUpdateSupportedWalletProjectOpTypes(extensionId, opTypeConstantsProviders);
    }


    function testAddOrUpdateSupportedWalletProjectOpTypesRevertOpTypeEmpty() public {
        testRegister();
        _mockGetOpType(bytes32(0));
        vm.prank(owner);
        vm.expectRevert(ITeeExtensionRegistry.OpTypeEmpty.selector);
        teeExtensionRegistry.addOrUpdateSupportedWalletProjectOpTypes(extensionId, opTypeConstantsProviders);
    }


    function testAddOrUpdateSupportedWalletProjectOpTypes1() public {
        testRegister();
        bytes32 opType1 = bytes32("FSOMETHING");
        _mockGetOpType(opType1);
        vm.prank(owner);
        teeExtensionRegistry.addOrUpdateSupportedWalletProjectOpTypes(extensionId, opTypeConstantsProviders);
    }

    function testAddOrUpdateSupportedWalletProjectOpTypes2() public {
        testRegister();
        bytes32 opType1 = bytes32("A_SOMETHING");
        _mockGetOpType(opType1);
        vm.prank(owner);
        teeExtensionRegistry.addOrUpdateSupportedWalletProjectOpTypes(extensionId, opTypeConstantsProviders);
    }

    function testAddOrUpdateSupportedWalletProjectOpTypesRevertSystemOpTypeNotAllowed1() public {
        testRegister();
        bytes32 opType1 = bytes32("F_SOMETHING");
        _mockGetOpType(opType1);
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeExtensionRegistry.SystemOpTypeNotAllowed.selector,
                bytes32(opType1)
            )
        );
        teeExtensionRegistry.addOrUpdateSupportedWalletProjectOpTypes(extensionId, opTypeConstantsProviders);
    }


    function testAddOrUpdateSupportedWalletProjectOpTypes() public {
        testRegister();
        vm.prank(owner);
        vm.expectEmit();
        emit ITeeExtensionRegistry.SupportedWalletProjectOpTypeAdded(extensionId, opType);
        teeExtensionRegistry.addOrUpdateSupportedWalletProjectOpTypes(extensionId, opTypeConstantsProviders);
    }


    // removeSupportedWalletProjectOpTypes
    function testRemoveSupportedWalletProjectOpTypesRevertOnlyOwner() public {
        testRegister();
        vm.expectRevert(ITeeExtensionRegistry.OnlyOwner.selector);
        teeExtensionRegistry.removeSupportedWalletProjectOpTypes(extensionId, opTypes);
    }


    function testRemoveSupportedWalletProjectOpTypes() public {
        testAddOrUpdateSupportedWalletProjectOpTypes();
        vm.prank(owner);
        vm.expectEmit();
        emit ITeeExtensionRegistry.SupportedWalletProjectOpTypeRemoved(extensionId, opTypes[0]);
        teeExtensionRegistry.removeSupportedWalletProjectOpTypes(extensionId, opTypes);
    }


    // proposeNewOwner
    function testProposeNewOwnerRevertOnlyOwner() public {
        testRegister();
        vm.expectRevert(ITeeExtensionRegistry.OnlyOwner.selector);
        teeExtensionRegistry.proposeNewOwner(extensionId, newOwner);
    }


    function testProposeNewOwnerRevertSystemOwnedExtensionId() public {
        testRegister();
        vm.prank(initialGovernance);
        vm.expectRevert(ITeeExtensionRegistry.SystemOwnedExtensionId.selector);
        teeExtensionRegistry.proposeNewOwner(0, newOwner);
    }


    function testProposeNewOwner() public {
        testRegister();
        vm.prank(owner);
        vm.expectEmit();
        emit ITeeExtensionRegistry.NewOwnerProposed(extensionId, owner, newOwner);
        teeExtensionRegistry.proposeNewOwner(extensionId, newOwner);
    }


    // confirmOwnership
    function testConfirmOwnershipRevertOnlyProposedOwner() public {
        testProposeNewOwner();
        vm.expectRevert(ITeeExtensionRegistry.OnlyProposedOwner.selector);
        teeExtensionRegistry.confirmOwnership(extensionId);
    }


    function testConfirmOwnership() public {
        testProposeNewOwner();
        vm.prank(newOwner);
        vm.expectEmit();
        emit ITeeExtensionRegistry.NewOwnerConfirmed(extensionId, newOwner);
        teeExtensionRegistry.confirmOwnership(extensionId);
        // should not revert OnlyOwner
        vm.prank(newOwner);
        vm.expectRevert(ITeeExtensionRegistry.VersionEmpty.selector);
        teeExtensionRegistry.addTeeVersion(extensionId, "", codeHash, platforms, governanceHash);
    }


    // addSupportedPlatforms
    function testAddSupportedPlatformsRevertOnlyGovernance() public {
        vm.expectRevert("only governance");
        teeExtensionRegistry.addSupportedPlatforms(platforms);
    }


    function testAddSupportedPlatformsRevertPlatformEmpty() public {
        platforms[0] = bytes32(0);
        vm.prank(initialGovernance);
        vm.expectRevert(ITeeExtensionRegistry.PlatformEmpty.selector);
        teeExtensionRegistry.addSupportedPlatforms(platforms);
    }


    function testAddSupportedPlatformsRevertPlatformAlreadyExists() public {
        testAddSupportedPlatforms();
        vm.prank(initialGovernance);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeExtensionRegistry.PlatformAlreadyExists.selector,
                platforms[0]
               )
        );
        teeExtensionRegistry.addSupportedPlatforms(platforms);
    }


    function testAddSupportedPlatforms() public {
        vm.prank(initialGovernance);
        vm.expectEmit();
        emit ITeeExtensionRegistry.SupportedPlatformAdded(platforms[0]);
        teeExtensionRegistry.addSupportedPlatforms(platforms);
    }


    // registerSystemInstructionInitiators
    function testRegisterSystemInstructionInitiatorsRevertOnlyGovernance() public {
        vm.expectRevert("only governance");
        teeExtensionRegistry.registerSystemInstructionInitiators(instructionInitiators);
    }


    function testRegisterSystemInstructionInitiators() public {
        vm.prank(initialGovernance);
        teeExtensionRegistry.registerSystemInstructionInitiators(instructionInitiators);
        // getSystemInstructionInitiators
        address[] memory returnedInstructionInitiators =
            teeExtensionRegistry.getSystemInstructionInitiators();
        assertEq(returnedInstructionInitiators.length, 1);
        assertEq(returnedInstructionInitiators[0], address(this));
    }


    // unregisterSystemInstructionInitiators
    function testUnregisterSystemInstructionInitiatorsRevertOnlyGovernance() public {
        vm.expectRevert("only governance");
        teeExtensionRegistry.unregisterSystemInstructionInitiators(instructionInitiators);
    }


    function testUnregisterSystemInstructionInitiators() public {
        testRegisterSystemInstructionInitiators();
        vm.prank(initialGovernance);
        teeExtensionRegistry.unregisterSystemInstructionInitiators(instructionInitiators);
        // getSystemInstructionInitiators
        address[] memory returnedInstructionInitiators =
            teeExtensionRegistry.getSystemInstructionInitiators();
        assertEq(returnedInstructionInitiators.length, 0);
    }


    // getExtensionOwner
    function testGetExtensionOwner() public {
        assertEq(teeExtensionRegistry.getExtensionOwner(extensionId + 1), address(0));
        assertEq(teeExtensionRegistry.getExtensionOwner(0), initialGovernance);
        testRegister();
        assertEq(teeExtensionRegistry.getExtensionOwner(extensionId), owner);
    }


    // getTeeExtensionStateVerifier
    function testGetTeeExtensionStateVerifier() public {
        assertEq(
            address(teeExtensionRegistry.getTeeExtensionStateVerifier(extensionId)),
            address(0)
        );
        testSetExtensionContracts();
        assertEq(
            address(teeExtensionRegistry.getTeeExtensionStateVerifier(extensionId)),
            address(teeExtensionStateVerifier)
        );
    }


    // getTeeExtensionInstructionsSender
    function testGetTeeExtensionInstructionsSender() public {
        assertEq(teeExtensionRegistry.getTeeExtensionInstructionsSender(extensionId), address(0));
        testRegister();
        assertEq(teeExtensionRegistry.getTeeExtensionInstructionsSender(extensionId), address(this));
    }


    // getWalletProjectOpTypeConstantsProvider
    function testGetWalletProjectOpTypeConstantsProviderRevertOperationTypeConstantsProviderNotSet() public {
        testRegister();
        vm.expectRevert(ITeeExtensionRegistry.OperationTypeConstantsProviderNotSet.selector);
        teeExtensionRegistry.getWalletProjectOpTypeConstantsProvider(extensionId, opType);

        vm.expectRevert(ITeeExtensionRegistry.OperationTypeConstantsProviderNotSet.selector);
        teeExtensionRegistry.getWalletProjectOpTypeConstantsProvider(extensionId, keccak256("invalidOpType"));
    }


    function testGetWalletProjectOpTypeConstantsProvider() public {
        testAddOrUpdateSupportedWalletProjectOpTypes();
        assertEq(
            address(teeExtensionRegistry.getWalletProjectOpTypeConstantsProvider(extensionId, opType)),
            address(opTypeConstantsProviders[0])
        );
    }


    // getSupportedWalletProjectOpTypes
    function testGetSupportedWalletProjectOpTypes() public {
        bytes32[] memory returnedSupportedOpTypes =
            teeExtensionRegistry.getSupportedWalletProjectOpTypes(extensionId);
        assertEq(returnedSupportedOpTypes.length, 0);
        testAddOrUpdateSupportedWalletProjectOpTypes();
        returnedSupportedOpTypes = teeExtensionRegistry.getSupportedWalletProjectOpTypes(extensionId);
        assertEq(returnedSupportedOpTypes.length, 1);
        assertEq(returnedSupportedOpTypes[0], opType);
    }


    // isWalletProjectOpTypeSupported
    function testIsWalletProjectOpTypeSupported() public {
        testAddOrUpdateSupportedWalletProjectOpTypes();
        assertFalse(
            teeExtensionRegistry.isWalletProjectOpTypeSupported(extensionId + 1, opType)
        );
        assertTrue(
            teeExtensionRegistry.isWalletProjectOpTypeSupported(extensionId, opType)
        );
    }


    // isCodeHashPlatformSupported
    function testIsCodeHashPlatformSupported() public {
        bool val = teeExtensionRegistry.isCodeHashPlatformSupported(extensionId, codeHash, platform);
        assertFalse(val);
        testAddTeeVersion();
        val = teeExtensionRegistry.isCodeHashPlatformSupported(extensionId, codeHash, platform);
        assertTrue(val);
        vm.prank(owner);
        teeExtensionRegistry.disableCodeHashPlatform(extensionId, codeHash, platform);
        val = teeExtensionRegistry.isCodeHashPlatformSupported(extensionId, codeHash, platform);
        assertFalse(val);
    }


    // codeHashPlatformDisabled
    function testCodeHashPlatformDisabled() public {
        bool val = teeExtensionRegistry.codeHashPlatformDisabled(extensionId, codeHash, platform);
        assertFalse(val);
        testAddTeeVersion();
        val = teeExtensionRegistry.codeHashPlatformDisabled(extensionId, codeHash, platform);
        assertFalse(val);
        vm.prank(owner);
        teeExtensionRegistry.disableCodeHashPlatform(extensionId, codeHash, platform);
        val = teeExtensionRegistry.codeHashPlatformDisabled(extensionId, codeHash, platform);
        assertTrue(val);
    }


    // getTeeGovernanceHash
    function testGetTeeGovernanceHash() public {
        bytes32 returnedGovernanceHash = teeExtensionRegistry.getTeeGovernanceHash(extensionId, codeHash);
        assertEq(returnedGovernanceHash, bytes32(0));
        testAddTeeVersion();
        returnedGovernanceHash = teeExtensionRegistry.getTeeGovernanceHash(extensionId, codeHash);
        assertEq(returnedGovernanceHash, governanceHash);
    }


    // getCodeHashInfo
    function testGetCodeHashInfo() public {
        (bytes32 returnedGovernanceHash, string memory returnedVersion, bytes32[] memory returnedPlatforms) =
            teeExtensionRegistry.getCodeHashInfo(extensionId, codeHash);
        assertEq(returnedGovernanceHash, bytes32(0));
        assertEq(returnedVersion, "");
        assertEq(returnedPlatforms.length, 0);
        testAddTeeVersion();
        (returnedGovernanceHash, returnedVersion, returnedPlatforms) =
            teeExtensionRegistry.getCodeHashInfo(extensionId, codeHash);
        assertEq(returnedGovernanceHash, governanceHash);
        assertEq(returnedVersion, version);
        assertEq(returnedPlatforms.length, 1);
        assertEq(returnedPlatforms[0], platforms[0]);
    }


    function _mockGetExtensionId(address _teeId, uint256 _extensionId) private {
        vm.mockCall(
            teeMachineRegistry,
            abi.encodeWithSelector(
                ITeeMachineRegistry.getExtensionId.selector,
                _teeId
            ),
            abi.encode(_extensionId)
        );
    }


    function _mockCalculateFeeByTeeIds(uint256 _fee) private {
        vm.mockCall(
            teeFeeCalculator,
            abi.encodeWithSelector(
                ITeeFeeCalculator.calculateFeeByTeeIds.selector
            ),
            abi.encode(_fee)
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


    function _mockGetTeeMachine(address _teeId) private {
        vm.mockCall(
            teeMachineRegistry,
            abi.encodeWithSelector(
                ITeeMachineRegistry.getTeeMachine.selector,
                _teeId
            ),
            abi.encode(ITeeMachineRegistry.TeeMachine(
                _teeId,
                _teeId,
                url
            ))
        );
    }


    function _mockGetLatestTeeGovernanceHash(bytes32 _governanceHash) private {
        vm.mockCall(
            teeGovernance,
            abi.encodeWithSelector(
                ITeeGovernance.getLatestTeeGovernanceHash.selector
            ),
            abi.encode(_governanceHash)
        );
    }


    function _mockGetOpType(bytes32 _opType) private {
        vm.mockCall(
            address(opTypeConstantsProviders[0]),
            abi.encodeWithSelector(
                ITeeWalletProjectOpTypeConstants.getOpType.selector
            ),
            abi.encode(_opType)
        );
    }
}