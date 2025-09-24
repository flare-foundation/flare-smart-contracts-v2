// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { FtdcHub } from "../../../../contracts/ftdc/implementation/FtdcHub.sol";
import { TeeExtensionRegistry } from "../../../../contracts/tee/implementation/TeeExtensionRegistry.sol";
import { TeeExtensionRegistryProxy } from "../../../../contracts/tee/proxy/TeeExtensionRegistryProxy.sol";
import { ITeeFeeCalculator } from "../../../../contracts/userInterfaces/tee/ITeeFeeCalculator.sol";
import { ITeeMachineRegistry } from "../../../../contracts/userInterfaces/tee/ITeeMachineRegistry.sol";
import { ITeeExtensionRegistry } from "../../../../contracts/userInterfaces/tee/ITeeExtensionRegistry.sol";
import { ITeeReplication } from "../../../../contracts/userInterfaces/tee/ITeeReplication.sol";
import { IFtdcHub } from "../../../../contracts/userInterfaces/ftdc/IFtdcHub.sol";
import { IFtdcRequestFeeConfigurations } from
    "../../../../contracts/userInterfaces/ftdc/IFtdcRequestFeeConfigurations.sol";
import { ProtocolsV2Interface } from "../../../../contracts/userInterfaces/LTS/ProtocolsV2Interface.sol";
import { IIRewardManager } from "../../../../contracts/protocol/interface/IIRewardManager.sol";
import { IGovernanceSettings } from "flare-smart-contracts/contracts/userInterfaces/IGovernanceSettings.sol";

// solhint-disable-next-line max-states-count
contract FtdcHubTest is Test {

    FtdcHub private ftdcHub;

    address private governance;
    address private addressUpdater;
    address private mockTeeMachineRegistry;
    address private mockTeeFeeCalculator;
    address private mockTeeReplication;
    address private mockFlareSystemsManager;
    address private mockFtdcRequestFeeConfigurations;
    address private mockRewardManager;

    TeeExtensionRegistry private teeExtensionRegistry;
    TeeExtensionRegistry private teeExtensionRegistryImpl;
    TeeExtensionRegistryProxy private teeExtensionRegistryProxy;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    uint16 private minThresholdBIPS;
    uint8 private defaultNumberOfTees;

    bytes32 private constant FTDC_OP_TYPE = bytes32("F_FTDC");
    bytes32 private constant PROVE = bytes32("PROVE");
    uint256 private requestFee = 10;

    address[] private teeIds;
    string[] private urls;

    function setUp() public {
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");
        minThresholdBIPS = 5000;
        defaultNumberOfTees = 1;
        ftdcHub = new FtdcHub(
            IGovernanceSettings(address(this)),
            governance,
            addressUpdater,
            minThresholdBIPS,
            defaultNumberOfTees
        );

        teeExtensionRegistryImpl = new TeeExtensionRegistry();
        teeExtensionRegistryProxy = new TeeExtensionRegistryProxy(
            IGovernanceSettings(address(this)),
            governance,
            addressUpdater,
            address(teeExtensionRegistryImpl)
        );
        teeExtensionRegistry = TeeExtensionRegistry(address(teeExtensionRegistryProxy));

        mockTeeMachineRegistry = makeAddr("mockTeeMachineRegistry");
        mockTeeFeeCalculator = makeAddr("mockTeeFeeCalculator");
        mockTeeReplication = makeAddr("mockTeeReplication");
        mockFlareSystemsManager = makeAddr("mockFlareSystemsManager");
        mockFtdcRequestFeeConfigurations = makeAddr("mockFtdcRequestFeeConfigurations");
        mockRewardManager = makeAddr("rewardManager");

        // set contract addresses
        vm.startPrank(addressUpdater);
        contractNameHashes = new bytes32[](7);
        contractAddresses = new address[](7);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractAddresses[0] = addressUpdater;
        contractNameHashes[1] = keccak256(abi.encode("TeeMachineRegistry"));
        contractAddresses[1] = mockTeeMachineRegistry;
        contractNameHashes[2] = keccak256(abi.encode("RewardManager"));
        contractAddresses[2] = mockRewardManager;
        contractNameHashes[3] = keccak256(abi.encode("TeeExtensionRegistry"));
        contractAddresses[3] = address(teeExtensionRegistry);
        contractNameHashes[4] = keccak256(abi.encode("FlareSystemsManager"));
        contractAddresses[4] = mockFlareSystemsManager;
        contractNameHashes[5] = keccak256(abi.encode("FtdcRequestFeeConfigurations"));
        contractAddresses[5] = mockFtdcRequestFeeConfigurations;
        contractNameHashes[6] = keccak256(abi.encode("TeeReplication"));
        contractAddresses[6] = mockTeeReplication;
        ftdcHub.updateContractAddresses(contractNameHashes, contractAddresses);

        contractNameHashes = new bytes32[](6);
        contractAddresses = new address[](6);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("TeeGovernance"));
        contractNameHashes[2] = keccak256(abi.encode("TeeMachineRegistry"));
        contractNameHashes[3] = keccak256(abi.encode("TeeFeeCalculator"));
        contractNameHashes[4] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[5] = keccak256(abi.encode("RewardManager"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = makeAddr("teeGovernance");
        contractAddresses[2] = mockTeeMachineRegistry;
        contractAddresses[3] = mockTeeFeeCalculator;
        contractAddresses[4] = mockFlareSystemsManager;
        contractAddresses[5] = mockRewardManager;
        teeExtensionRegistry.updateContractAddresses(contractNameHashes, contractAddresses);
        vm.stopPrank();

        // set FtdcHub contract as system instruction initiator on TeeExtensionRegistry
        vm.startPrank(governance);
        address[] memory systemInstructionsSender = new address[](1);
        systemInstructionsSender[0] = address(ftdcHub);
        teeExtensionRegistry.registerSystemInstructionsSenders(systemInstructionsSender);
        vm.stopPrank();
        _mockReceiveRewards();

        _mockGetTypeAndSourceFee();
        teeIds = new address[](2);
        urls = new string[](2);
        teeIds[0] = makeAddr("teeId1");
        teeIds[1] = makeAddr("teeId2");
        urls[0] = "url1";
        urls[1] = "url2";

        _mockGetTeeMachine(teeIds[0], urls[0]);
        _mockGetTeeMachine(teeIds[1], urls[1]);

        _mockGetExtensionId(0);
        _mockCalculateFeeByTeeIds(15);
    }

    function testSetMinThresholdBIPS() public {
        uint16 newMinThresholdBIPS = 3000;
        assertEq(ftdcHub.minThresholdBIPS(), minThresholdBIPS);
        vm.prank(governance);
        ftdcHub.setMinThresholdBIPS(newMinThresholdBIPS);
        assertEq(ftdcHub.minThresholdBIPS(), newMinThresholdBIPS);
    }

    function testSetMinThresholdBIPSRevert() public {
        vm.prank(governance);
        vm.expectRevert(IFtdcHub.MinThresholdInvalid.selector);
        ftdcHub.setMinThresholdBIPS(0);

        vm.prank(governance);
        vm.expectRevert(IFtdcHub.MinThresholdInvalid.selector);
        ftdcHub.setMinThresholdBIPS(1e4 + 1);

        vm.expectRevert("only governance");
        ftdcHub.setMinThresholdBIPS(3000);
    }

    function testDefaultNumberOfTees() public {
        uint8 newDefaultNumberOfTees = 5;
        assertEq(ftdcHub.defaultNumberOfTees(), defaultNumberOfTees);
        vm.prank(governance);
        ftdcHub.setDefaultNumberOfTees(newDefaultNumberOfTees);
        assertEq(ftdcHub.defaultNumberOfTees(), newDefaultNumberOfTees);
    }

    function testDefaultNumberOfTeesRevert() public {
        vm.prank(governance);
        vm.expectRevert(IFtdcHub.DefaultNumberOfTeesZero.selector);
        ftdcHub.setDefaultNumberOfTees(0);

        vm.expectRevert("only governance");
        ftdcHub.setDefaultNumberOfTees(5);
    }

    function testRequestAttestationRevertThresholdInvalid() public {
        vm.expectRevert(IFtdcHub.ThresholdInvalid.selector);
        ftdcHub.requestAttestation(minThresholdBIPS - 1, 1, new address[](0), new address[](0), 0, "", "", "");

        vm.expectRevert(IFtdcHub.ThresholdInvalid.selector);
        ftdcHub.requestAttestation(1e4 + 1, 1, new address[](0), new address[](0), 0, "", "", "");
    }

    function testRequestAttestationRevertTeesInvalid() public {
        vm.expectRevert(IFtdcHub.NumberOfTeesAndTeeIdsInvalid.selector);
        teeIds = new address[](1);
        teeIds[0] = makeAddr("teeId");
        ftdcHub.requestAttestation(minThresholdBIPS, 2, teeIds, new address[](0), 0, "", "", "");
    }

    function testRequestAttestationRevertTeeMachineNotAvailable() public {
        address teeId = makeAddr("teeId");
        _mockGetTeeMachineStatus(teeId, ITeeMachineRegistry.TeeStatus.PAUSED_FOR_UPGRADE);
        _mockGetTeeReplicatingTeeId(teeId, address(0));
        teeIds = new address[](1);
        teeIds[0] = teeId;
        vm.expectRevert(IFtdcHub.TeeMachineNotAvailable.selector);
        ftdcHub.requestAttestation(minThresholdBIPS, 1, teeIds, new address[](0), 0, "", "", "");
    }

    function testRequestAttestationRevertOnlySystemExtensionId() public {
        _mockGetExtensionId(1);
        address teeId = makeAddr("teeId");
        _mockGetTeeMachine(teeId, "url");
        _mockGetTeeMachineStatus(teeId, ITeeMachineRegistry.TeeStatus.PRODUCTION);
        teeIds = new address[](1);
        teeIds[0] = teeId;
        vm.expectRevert(
            abi.encodeWithSelector(
                IFtdcHub.OnlySystemExtensionId.selector,
                teeId
            )
        );
        ftdcHub.requestAttestation(minThresholdBIPS, 0, teeIds, new address[](0), 0, "", "", "");
    }

    function testRequestAttestationRevertFeeTooLow() public {
        address teeId = makeAddr("teeId");
        _mockGetTeeMachine(teeId, "url");
        _mockGetTeeMachineStatus(teeId, ITeeMachineRegistry.TeeStatus.PRODUCTION);
        teeIds = new address[](1);
        teeIds[0] = teeId;
        vm.expectRevert(IFtdcHub.FeeTooLow.selector);
        ftdcHub.requestAttestation{value: requestFee - 1} (
            minThresholdBIPS, 1, teeIds, new address[](0), 0, "", "", ""
        );
    }

    // list of teeIds provided
    function testRequestAttestation1() public {
        _mockGetTeeMachineStatus(teeIds[0], ITeeMachineRegistry.TeeStatus.PRODUCTION);
        _mockGetTeeMachineStatus(teeIds[1], ITeeMachineRegistry.TeeStatus.PRODUCTION);
        address[] memory teeIdsForFee = new address[](2);
        teeIdsForFee[0] = teeIds[0];
        teeIdsForFee[1] = teeIds[1];
        _mockGetCurrentRewardEpochId(123);
        bytes32 attestationType = "PMWPaymentStatus";
        bytes32 sourceId = "XRP";
        bytes memory attestationRequest = "attestationRequest";
        bytes32 instructionId = keccak256(abi.encode(FTDC_OP_TYPE, PROVE, 0));

        IFtdcHub.FtdcAttestationRequest memory message = IFtdcHub.FtdcAttestationRequest({
            header: IFtdcHub.FtdcRequestHeader({
                attestationType: attestationType,
                sourceId: sourceId,
                thresholdBIPS: minThresholdBIPS
            }),
            requestBody: attestationRequest
        });
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            0,
            instructionId,
            123,
            _getTeeMachines(2),
            FTDC_OP_TYPE,
            PROVE,
            abi.encode(message),
            new address[](0),
            0,
            15
        );
        ftdcHub.requestAttestation{value: requestFee + 15} (
            minThresholdBIPS, 0, teeIds, new address[](0), 0, attestationType, sourceId, attestationRequest
        );
    }

    // list of teeIds not provided and number is also not (it will take default)
    function testRequestAttestation2() public {
        _mockGetTeeMachineStatus(teeIds[0], ITeeMachineRegistry.TeeStatus.PRODUCTION);
        address[] memory teeIdsForFee = new address[](1);
        teeIdsForFee[0] = teeIds[0];

        vm.mockCall(
            mockTeeMachineRegistry,
            abi.encodeWithSelector(
                ITeeMachineRegistry.getRandomTeeIds.selector, 0, 1
            ),
            abi.encode(teeIdsForFee)
        );

        _mockGetCurrentRewardEpochId(123);
        bytes32 attestationType = "PMWPaymentStatus";
        bytes32 sourceId = "XRP";
        bytes memory attestationRequest = "attestationRequest";
        bytes32 instructionId = keccak256(abi.encode(FTDC_OP_TYPE, PROVE, 0));

        IFtdcHub.FtdcAttestationRequest memory message = IFtdcHub.FtdcAttestationRequest({
            header: IFtdcHub.FtdcRequestHeader({
                attestationType: attestationType,
                sourceId: sourceId,
                thresholdBIPS: minThresholdBIPS
            }),
            requestBody: attestationRequest
        });
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            0,
            instructionId,
            123,
            _getTeeMachines(1),
            FTDC_OP_TYPE,
            PROVE,
            abi.encode(message),
            new address[](0),
            0,
            15
        );
        ftdcHub.requestAttestation{value: requestFee + 15} (
            minThresholdBIPS, 0, new address[](0), new address[](0), 0, attestationType, sourceId, attestationRequest
        );
    }

    // list of teeIds is not provided but the number is
    function testRequestAttestation3() public {
        _mockGetTeeMachineStatus(teeIds[0], ITeeMachineRegistry.TeeStatus.PRODUCTION);
        _mockGetTeeMachineStatus(teeIds[1], ITeeMachineRegistry.TeeStatus.PRODUCTION);
        vm.mockCall(
            mockTeeMachineRegistry,
            abi.encodeWithSelector(
                ITeeMachineRegistry.getRandomTeeIds.selector, 0, 2
            ),
            abi.encode(teeIds)
        );
        address[] memory teeIdsForFee = new address[](2);
        teeIdsForFee[0] = teeIds[0];
        teeIdsForFee[1] = teeIds[1];
        _mockGetCurrentRewardEpochId(123);
        bytes32 attestationType = "PMWPaymentStatus";
        bytes32 sourceId = "XRP";
        bytes memory attestationRequest = "attestationRequest";
        bytes32 instructionId = keccak256(abi.encode(FTDC_OP_TYPE, PROVE, 0));

        IFtdcHub.FtdcAttestationRequest memory message = IFtdcHub.FtdcAttestationRequest({
            header: IFtdcHub.FtdcRequestHeader({
                attestationType: attestationType,
                sourceId: sourceId,
                thresholdBIPS: minThresholdBIPS
            }),
            requestBody: attestationRequest
        });
        vm.expectEmit();
        emit ITeeExtensionRegistry.TeeInstructionsSent(
            0,
            instructionId,
            123,
            _getTeeMachines(2),
            FTDC_OP_TYPE,
            PROVE,
            abi.encode(message),
            new address[](0),
            0,
            15
        );
        ftdcHub.requestAttestation{value: requestFee + 15} (
            minThresholdBIPS, 2, new address[](0), new address[](0), 0, attestationType, sourceId, attestationRequest
        );
    }

    /// Helper and mock functions ///
    function _mockGetTeeMachineStatus(address _teeId, ITeeMachineRegistry.TeeStatus _status) internal {
        vm.mockCall(
            mockTeeMachineRegistry,
            abi.encodeWithSelector(
                ITeeMachineRegistry.getTeeMachineStatus.selector,
                _teeId
            ),
            abi.encode(_status)
        );
    }

    function _mockGetTeeReplicatingTeeId(address _teeId, address _replicatingTeeId) internal {
        vm.mockCall(
            mockTeeReplication,
            abi.encodeWithSelector(
                ITeeReplication.getReplicatingTeeId.selector,
                _teeId
            ),
            abi.encode(_replicatingTeeId)
        );
    }


    function _mockGetTypeAndSourceFee() internal {
        vm.mockCall(
            mockFtdcRequestFeeConfigurations,
            abi.encodeWithSelector(IFtdcRequestFeeConfigurations.getTypeAndSourceFee.selector),
            abi.encode(requestFee)
        );
    }

    function _mockGetTeeMachine(address _teeId, string memory _url) internal {
        vm.mockCall(
            mockTeeMachineRegistry,
            abi.encodeWithSelector(
                ITeeMachineRegistry.getTeeMachine.selector,
                _teeId
            ),
            abi.encode(ITeeMachineRegistry.TeeMachine({
                teeId: _teeId,
                teeProxyId: _teeId, // for testing purposes
                url: _url
            }))
        );
    }

    function _mockGetCurrentRewardEpochId(uint256 _rewardEpochId) internal {
        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(
                ProtocolsV2Interface.getCurrentRewardEpochId.selector
            ),
            abi.encode(_rewardEpochId)
        );
    }

    function _mockReceiveRewards() internal {
        vm.mockCall(
            mockRewardManager,
            abi.encodeWithSelector(IIRewardManager.receiveRewards.selector),
            abi.encode()
        );
    }

    function _mockGetExtensionId(uint256 _extensionId) internal {
        vm.mockCall(
            mockTeeMachineRegistry,
            abi.encodeWithSelector(
                ITeeMachineRegistry.getExtensionId.selector
            ),
            abi.encode(_extensionId)
        );
    }

    function _mockCalculateFeeByTeeIds(uint256 _fee) internal {
        vm.mockCall(
            mockTeeFeeCalculator,
            abi.encodeWithSelector(
                ITeeFeeCalculator.calculateFeeByTeeIds.selector
            ),
            abi.encode(_fee)
        );
    }

    function _getTeeMachines(
        uint256 _num
    )
        internal view
        returns (ITeeMachineRegistry.TeeMachine[] memory _teeMachines)
    {
        _teeMachines = new ITeeMachineRegistry.TeeMachine[](_num);

        for (uint256 i = 0; i < _num; i++) {
            _teeMachines[i] = ITeeMachineRegistry.TeeMachine({
                teeId: teeIds[i],
                teeProxyId: teeIds[i], // for testing purposes
                url: urls[i]
            });
        }
    }
}