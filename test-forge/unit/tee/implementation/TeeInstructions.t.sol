// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../../../../contracts/tee/implementation/TeeInstructions.sol";
import "../../../../contracts/protocol/implementation/RewardManager.sol";
import "../../../../contracts/tee/proxy/TeeInstructionsProxy.sol";
import "../../../../contracts/tee/implementation/TeeExtensionRegistry.sol";
import "../../../../contracts/tee/proxy/TeeExtensionRegistryProxy.sol";

contract TeeInstructionsTest is Test {

    TeeInstructions private teeInstructions;
    TeeInstructions private teeInstructionsImpl;
    TeeInstructionsProxy private teeInstructionsProxy;

    address private governance;
    address private addressUpdater;
    address private teeMachineRegistryMock;
    address private teeFeeCalculatorMock;

    TeeExtensionRegistry private teeExtensionRegistry;
    TeeExtensionRegistryProxy private teeExtensionRegistryProxy;
    TeeExtensionRegistry private teeExtensionRegistryImpl;
    RewardManager private rewardManager;
    address private mockFSM;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    uint256 private fee;

    bytes32 private constant XRP_OP_TYPE = bytes32("F_XRP");

    function setUp() public {
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");

        teeInstructionsImpl = new TeeInstructions();
        teeInstructionsProxy = new TeeInstructionsProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            address(teeInstructionsImpl)
        );
        teeInstructions = TeeInstructions(address(teeInstructionsProxy));

        rewardManager = new RewardManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            address(0),
            0
        );

        teeExtensionRegistryImpl = new TeeExtensionRegistry();
        teeExtensionRegistryProxy = new TeeExtensionRegistryProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            address(teeExtensionRegistryImpl)
        );
        teeExtensionRegistry = TeeExtensionRegistry(address(teeExtensionRegistryProxy));

        teeMachineRegistryMock = makeAddr("teeMachineRegistryMock");
        teeFeeCalculatorMock = makeAddr("teeFeeCalculatorMock");
        mockFSM = makeAddr("flareSystemsManagerMock");

        vm.startPrank(addressUpdater);
        contractNameHashes = new bytes32[](2);
        contractAddresses = new address[](2);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("TeeExtensionRegistry"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = address(teeExtensionRegistry);
        teeInstructions.updateContractAddresses(contractNameHashes, contractAddresses);

        contractNameHashes = new bytes32[](6);
        contractAddresses = new address[](6);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractAddresses[0] = addressUpdater;
        contractNameHashes[1] = keccak256(abi.encode("TeeMachineRegistry"));
        contractAddresses[1] = teeMachineRegistryMock;
        contractNameHashes[2] = keccak256(abi.encode("TeeGovernance"));
        contractAddresses[2] = makeAddr("teeGovernance");
        contractNameHashes[3] = keccak256(abi.encode("TeeFeeCalculator"));
        contractAddresses[3] = teeFeeCalculatorMock;
        contractNameHashes[4] = keccak256(abi.encode("FlareSystemsManager"));
        contractAddresses[4] = mockFSM;
        contractNameHashes[5] = keccak256(abi.encode("RewardManager"));
        contractAddresses[5] = address(rewardManager);
        teeExtensionRegistry.updateContractAddresses(contractNameHashes, contractAddresses);

        // set contracts on reward manager
        contractNameHashes = new bytes32[](8);
        contractAddresses = new address[](8);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("VoterRegistry"));
        contractNameHashes[2] = keccak256(abi.encode("ClaimSetupManager"));
        contractNameHashes[3] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[4] = keccak256(abi.encode("FlareSystemsCalculator"));
        contractNameHashes[5] = keccak256(abi.encode("PChainStakeMirror"));
        contractNameHashes[6] = keccak256(abi.encode("WNat"));
        contractNameHashes[7] = keccak256(abi.encode("FtsoRewardManager"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = makeAddr("voterRegistry");
        contractAddresses[2] = makeAddr("claimSetupManager");
        contractAddresses[3] = mockFSM;
        contractAddresses[4] = makeAddr("flareSystemsCalculator");
        contractAddresses[5] = makeAddr("pChainStakeMirror");
        contractAddresses[6] = makeAddr("wNat");
        contractAddresses[7] = makeAddr("FtsoRewardManagerProxy");
        rewardManager.updateContractAddresses(contractNameHashes, contractAddresses);
        vm.stopPrank();

        // set reward offers manager list on reward manager
        address[] memory rewardOffersManagers = new address[](1);
        rewardOffersManagers[0] = address(teeExtensionRegistry);
        vm.prank(governance);
        rewardManager.setRewardOffersManagerList(rewardOffersManagers);

        // set TeeInstructions as system instruction initiator on TeeExtensionRegistry
        vm.prank(governance);
        address[] memory systemInstructionInitiator = new address[](1);
        systemInstructionInitiator[0] = address(teeInstructions);
        teeExtensionRegistry.registerSystemInstructionInitiators(systemInstructionInitiator);

        _mockGetExtensionId(0);
        fee = 2987; // example fee
        _mockCalculateFeeByTeeIds(fee);
    }

    function testRegisterInstructionInitiators() public {
        address[] memory instructionInitiators = new address[](3);
        instructionInitiators[0] = makeAddr("instructionInitiator1");
        instructionInitiators[1] = makeAddr("instructionInitiator2");
        instructionInitiators[2] = makeAddr("instructionInitiator3");
        vm.prank(governance);
        teeInstructions.registerInstructionInitiators(instructionInitiators);

        // assert
        address[] memory result = teeInstructions.getInstructionInitiators();
        assertEq(result.length, 3);
        assertEq(result[0], instructionInitiators[0]);
        assertEq(result[1], instructionInitiators[1]);
        assertEq(result[2], instructionInitiators[2]);
    }

    function testRegisterInstructionInitiatorsRevert() public {
        vm.expectRevert("only governance");
        teeInstructions.registerInstructionInitiators(new address[](0));
    }

    function testUnregisterInstructionInitiators() public {
        testRegisterInstructionInitiators();
        address[] memory instructionInitiators = new address[](2);
        instructionInitiators[0] = makeAddr("instructionInitiator1");
        instructionInitiators[1] = makeAddr("instructionInitiator3");
        vm.prank(governance);
        teeInstructions.unregisterInstructionInitiators(instructionInitiators);

        // assert
        address[] memory result = teeInstructions.getInstructionInitiators();
        assertEq(result.length, 1);
        assertEq(result[0], makeAddr("instructionInitiator2"));
    }

    function testSendInstructionsRevert() public {
        vm.expectRevert(ITeeInstructions.OnlyInstructionInitiator.selector);
        teeInstructions.sendInstructions(
            bytes32(0),
            new address[](0),
            bytes32(0),
            bytes32(0),
            new bytes(0)
        );
    }

    function testSendInstructions() public {
        testRegisterInstructionInitiators();
        ITeeMachineRegistry.TeeMachine[] memory teeMachines = new ITeeMachineRegistry.TeeMachine[](2);
        address[] memory teeIds = new address[](2);
        teeIds[0] = makeAddr("teeId1");
        teeIds[1] = makeAddr("teeId2");
        teeMachines[0] = ITeeMachineRegistry.TeeMachine({
            teeId: makeAddr("teeId1"),
            teeProxyId: makeAddr("teeProxyId1"),
            url: "url1"
        });
        teeMachines[1] = ITeeMachineRegistry.TeeMachine({
            teeId: makeAddr("teeId2"),
            teeProxyId: makeAddr("teeProxyId2"),
            url: "url2"
        });
        uint24 currentRewardEpochId = 100;
        vm.mockCall(
            mockFSM,
            abi.encodeWithSelector(ProtocolsV2Interface.getCurrentRewardEpochId.selector),
            abi.encode(currentRewardEpochId)
        );

        for (uint256 i = 0; i < teeMachines.length; i++) {
            vm.mockCall(
                teeMachineRegistryMock,
                abi.encodeWithSelector(
                    ITeeMachineRegistry.getTeeMachine.selector,
                    teeIds[i]
                ),
                abi.encode(teeMachines[i])
            );
        }

        address sender = makeAddr("instructionInitiator1");
        vm.prank(sender);
        vm.deal(sender, 1 ether);
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            bytes32("instructionId"),
            currentRewardEpochId,
            teeMachines,
            bytes32(XRP_OP_TYPE),
            bytes32("PAY"),
            abi.encode("message"),
            fee
        );
        teeInstructions.sendInstructions{value: fee} (
            bytes32("instructionId"),
            teeIds,
            bytes32(XRP_OP_TYPE),
            bytes32("PAY"),
            abi.encode("message")
        );
        assertEq(address(rewardManager).balance, fee);
        assertEq(sender.balance, 1 ether - fee);
    }

    function _mockGetExtensionId(uint256 _extensionId) internal {
        vm.mockCall(
            teeMachineRegistryMock,
            abi.encodeWithSelector(
                ITeeMachineRegistry.getExtensionId.selector
            ),
            abi.encode(_extensionId)
        );
    }

    function _mockCalculateFeeByTeeIds(uint256 _fee) internal {
        vm.mockCall(
            teeFeeCalculatorMock,
            abi.encodeWithSelector(
                ITeeFeeCalculator.calculateFeeByTeeIds.selector
            ),
            abi.encode(_fee)
        );
    }
}