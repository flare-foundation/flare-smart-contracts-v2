// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../../contracts/tee/implementation/TeeDataConnector.sol";
import "../../../../contracts/tee/implementation/TeeInstructions.sol";

contract TeeDataConnectorTest is Test {

    TeeDataConnector private teeDataConnector;

    address private governance;
    address private addressUpdater;
    address private mockTeeRegistry;
    address private mockTeeFeeCalculator;
    TeeInstructions private teeInstructions;
    address private mockFlareSystemsManager;
    address private mockFtdcRequestFeeConfigurations;
    address private mockRewardManager;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    uint16 private minThresholdBIPS;
    uint8 private defaultNumberOfTees;

    bytes32 private constant FTDC_OP_TYPE = bytes32("FTDC");
    bytes32 private constant PROVE = bytes32("PROVE");
    uint256 private requestFee = 10;

    address[] private teeIds;
    address[] private owners;
    string[] private urls;

    event TeeInstructionsSent(
        bytes32 indexed instructionId,
        uint24 indexed rewardEpochId,
        ITeeRegistry.TeeMachine[] teeMachines,
        bytes32 opType,
        bytes32 opCommand,
        bytes message,
        uint256 fee
    );

    function setUp() public {
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");
        minThresholdBIPS = 2000;
        defaultNumberOfTees = 1;
        teeDataConnector = new TeeDataConnector(
            IGovernanceSettings(address(this)),
            governance,
            addressUpdater,
            minThresholdBIPS,
            defaultNumberOfTees
        );

        teeInstructions = new TeeInstructions(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater
        );

        mockTeeRegistry = makeAddr("mockTeeRegistry");
        mockTeeFeeCalculator = makeAddr("mockTeeFeeCalculator");
        mockFlareSystemsManager = makeAddr("mockFlareSystemsManager");
        mockFtdcRequestFeeConfigurations = makeAddr("mockFtdcRequestFeeConfigurations");
        mockRewardManager = makeAddr("rewardManager");

        // set contract addresses
        contractNameHashes = new bytes32[](6);
        contractAddresses = new address[](6);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractAddresses[0] = addressUpdater;
        contractNameHashes[1] = keccak256(abi.encode("TeeRegistry"));
        contractAddresses[1] = mockTeeRegistry;
        contractNameHashes[2] = keccak256(abi.encode("TeeFeeCalculator"));
        contractAddresses[2] = mockTeeFeeCalculator;
        contractNameHashes[3] = keccak256(abi.encode("TeeInstructions"));
        contractAddresses[3] = address(teeInstructions);
        contractNameHashes[4] = keccak256(abi.encode("FlareSystemsManager"));
        contractAddresses[4] = mockFlareSystemsManager;
        contractNameHashes[5] = keccak256(abi.encode("FtdcRequestFeeConfigurations"));
        contractAddresses[5] = mockFtdcRequestFeeConfigurations;
        vm.prank(addressUpdater);
        teeDataConnector.updateContractAddresses(contractNameHashes, contractAddresses);

        vm.prank(addressUpdater);
        contractNameHashes = new bytes32[](2);
        contractAddresses = new address[](2);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("RewardManager"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = mockRewardManager;
        teeInstructions.updateContractAddresses(contractNameHashes, contractAddresses);

        // set data connector contract as instruction initiator on TeeInstructions
        vm.prank(governance);
        address[] memory instructionInitiators = new address[](1);
        instructionInitiators[0] = address(teeDataConnector);
        teeInstructions.registerInstructionInitiators(instructionInitiators);
        _mockReceiveRewards();

        _mockGetRequestFee();
        teeIds = new address[](2);
        owners = new address[](2);
        urls = new string[](2);
        teeIds[0] = makeAddr("teeId1");
        teeIds[1] = makeAddr("teeId2");
        owners[0] = makeAddr("owner1");
        owners[1] = makeAddr("owner2");
        urls[0] = "url1";
        urls[1] = "url2";

        _mockGetTeeMachineWithAttestationData(teeIds[0], owners[0], urls[0]);
        _mockGetTeeMachineWithAttestationData(teeIds[1], owners[1], urls[1]);
    }

    function testSetMinThresholdBIPS() public {
        uint16 newMinThresholdBIPS = 3000;
        assertEq(teeDataConnector.minThresholdBIPS(), minThresholdBIPS);
        vm.prank(governance);
        teeDataConnector.setMinThresholdBIPS(newMinThresholdBIPS);
        assertEq(teeDataConnector.minThresholdBIPS(), newMinThresholdBIPS);
    }

    function testSetMinThresholdBIPSRevert() public {
        vm.prank(governance);
        vm.expectRevert("min threshold invalid");
        teeDataConnector.setMinThresholdBIPS(0);

        vm.prank(governance);
        vm.expectRevert("min threshold invalid");
        teeDataConnector.setMinThresholdBIPS(1e4 + 1);

        vm.expectRevert("only governance");
        teeDataConnector.setMinThresholdBIPS(3000);
    }

    function testDefaultNumberOfTees() public {
        uint8 newDefaultNumberOfTees = 5;
        assertEq(teeDataConnector.defaultNumberOfTees(), defaultNumberOfTees);
        vm.prank(governance);
        teeDataConnector.setDefaultNumberOfTees(newDefaultNumberOfTees);
        assertEq(teeDataConnector.defaultNumberOfTees(), newDefaultNumberOfTees);
    }

    function testDefaultNumberOfTeesRevert() public {
        vm.prank(governance);
        vm.expectRevert("default number of tees zero");
        teeDataConnector.setDefaultNumberOfTees(0);

        vm.expectRevert("only governance");
        teeDataConnector.setDefaultNumberOfTees(5);
    }

    function testRequestAttestationRevertThresholdInvalid() public {
        vm.expectRevert("threshold invalid");
        teeDataConnector.requestAttestation(minThresholdBIPS - 1, 1, new address[](0), "");

        vm.expectRevert("threshold invalid");
        teeDataConnector.requestAttestation(1e4 + 1, 1, new address[](0), "");
    }

    function testRequestAttestationRevertTeesInvalid() public {
        vm.expectRevert("numberOfTees and teeIds invalid");
        teeIds = new address[](1);
        teeIds[0] = makeAddr("teeId");
        teeDataConnector.requestAttestation(minThresholdBIPS, 2, teeIds, "");
    }

    function testRequestAttestationRevertTeeNotAvailable() public {
        address teeId = makeAddr("teeId");
        _mockGetTeeMachineStatus(teeId, ITeeRegistry.TeeStatus.PAUSED_FOR_UPGRADE);
        teeIds = new address[](1);
        teeIds[0] = teeId;
        vm.expectRevert("tee machine not available");
        teeDataConnector.requestAttestation(minThresholdBIPS, 1, teeIds, "");
    }

    function testRequestAttestationRevertFeeTooLow() public {
        address teeId = makeAddr("teeId");
        _mockGetTeeMachineStatus(teeId, ITeeRegistry.TeeStatus.PRODUCTION);
        teeIds = new address[](1);
        teeIds[0] = teeId;
        _mockCalculateFeeByTeeIds(teeIds, 15);
        vm.expectRevert("fee to low");
        teeDataConnector.requestAttestation{value: requestFee + 15 - 1} (minThresholdBIPS, 1, teeIds, "");
    }

    // list of teeIds provided
    function testRequestAttestation1() public {
        _mockGetTeeMachineStatus(teeIds[0], ITeeRegistry.TeeStatus.PRODUCTION);
        _mockGetTeeMachineStatus(teeIds[1], ITeeRegistry.TeeStatus.PRODUCTION);
        address[] memory teeIdsForFee = new address[](2);
        teeIdsForFee[0] = teeIds[0];
        teeIdsForFee[1] = teeIds[1];
        _mockCalculateFeeByTeeIds(teeIdsForFee, 15);
        _mockGetCurrentRewardEpochId(123);
        bytes memory attestationRequest = "attestationRequest";
        bytes32 instructionId = keccak256(abi.encode(FTDC_OP_TYPE, PROVE, attestationRequest));
        (ITeeRegistry.TeeMachine[] memory teeMachines,
            ITeeRegistry.TeeMachineWithAttestationData[] memory teeMachinesWithAttestationData) = _getTeeMachines(2);

        ITeeDataConnector.FtdcProve memory message = ITeeDataConnector.FtdcProve({
            teeMachines: teeMachinesWithAttestationData,
            thresholdBIPS: minThresholdBIPS,
            attestationRequest: attestationRequest
        });
        vm.expectEmit();
        emit TeeInstructionsSent(
            instructionId,
            123,
            teeMachines,
            FTDC_OP_TYPE,
            PROVE,
            abi.encode(message),
            requestFee + 15
        );
        teeDataConnector.requestAttestation{value: requestFee + 15} (minThresholdBIPS, 0, teeIds, attestationRequest);
    }

    // list of teeIds not provided and number is also not (it will take default)
    function testRequestAttestation2() public {
        _mockGetTeeMachineStatus(teeIds[0], ITeeRegistry.TeeStatus.PRODUCTION);
        address[] memory teeIdsForFee = new address[](1);
        teeIdsForFee[0] = teeIds[0];

        vm.mockCall(
            mockTeeRegistry,
            abi.encodeWithSelector(
                ITeeRegistry.getRandomTeeIds.selector,
                1
            ),
            abi.encode(teeIdsForFee)
        );

        _mockCalculateFeeByTeeIds(teeIdsForFee, 15);
        _mockGetCurrentRewardEpochId(123);
        bytes memory attestationRequest = "attestationRequest";
        bytes32 instructionId = keccak256(abi.encode(FTDC_OP_TYPE, PROVE, attestationRequest));
        (ITeeRegistry.TeeMachine[] memory teeMachines,
            ITeeRegistry.TeeMachineWithAttestationData[] memory teeMachinesWithAttestationData) = _getTeeMachines(1);

        ITeeDataConnector.FtdcProve memory message = ITeeDataConnector.FtdcProve({
            teeMachines: teeMachinesWithAttestationData,
            thresholdBIPS: minThresholdBIPS,
            attestationRequest: attestationRequest
        });
        vm.expectEmit();
        emit TeeInstructionsSent(
            instructionId,
            123,
            teeMachines,
            FTDC_OP_TYPE,
            PROVE,
            abi.encode(message),
            requestFee + 15
        );
        teeDataConnector.requestAttestation{value: requestFee + 15} (
            minThresholdBIPS, 0, new address[](0), attestationRequest
        );
    }

    // list of teeIds is not provided but the number is
    function testRequestAttestation3() public {
        _mockGetTeeMachineStatus(teeIds[0], ITeeRegistry.TeeStatus.PRODUCTION);
        _mockGetTeeMachineStatus(teeIds[1], ITeeRegistry.TeeStatus.PRODUCTION);
        vm.mockCall(
            mockTeeRegistry,
            abi.encodeWithSelector(
                ITeeRegistry.getRandomTeeIds.selector,
                2
            ),
            abi.encode(teeIds)
        );
        address[] memory teeIdsForFee = new address[](2);
        teeIdsForFee[0] = teeIds[0];
        teeIdsForFee[1] = teeIds[1];
        _mockCalculateFeeByTeeIds(teeIdsForFee, 15);
        _mockGetCurrentRewardEpochId(123);
        bytes memory attestationRequest = "attestationRequest";
        bytes32 instructionId = keccak256(abi.encode(FTDC_OP_TYPE, PROVE, attestationRequest));
        (ITeeRegistry.TeeMachine[] memory teeMachines,
            ITeeRegistry.TeeMachineWithAttestationData[] memory teeMachinesWithAttestationData) = _getTeeMachines(2);

        ITeeDataConnector.FtdcProve memory message = ITeeDataConnector.FtdcProve({
            teeMachines: teeMachinesWithAttestationData,
            thresholdBIPS: minThresholdBIPS,
            attestationRequest: attestationRequest
        });
        vm.expectEmit();
        emit TeeInstructionsSent(
            instructionId,
            123,
            teeMachines,
            FTDC_OP_TYPE,
            PROVE,
            abi.encode(message),
            requestFee + 15
        );
        teeDataConnector.requestAttestation{value: requestFee + 15} (
            minThresholdBIPS, 2, new address[](0), attestationRequest
        );
    }

    /// Helper and mock functions ///
    function _mockGetTeeMachineStatus(address _teeId, ITeeRegistry.TeeStatus _status) internal {
        vm.mockCall(
            mockTeeRegistry,
            abi.encodeWithSelector(
                ITeeRegistry.getTeeMachineStatus.selector,
                _teeId
            ),
            abi.encode(_status)
        );
    }

    function _mockCalculateFeeByTeeIds(address[] memory _teeIds, uint256 _fee) internal {
        vm.mockCall(
            mockTeeFeeCalculator,
            abi.encodeWithSelector(
                ITeeFeeCalculator.calculateFeeByTeeIds.selector,
                FTDC_OP_TYPE,
                PROVE,
                _teeIds,
                new address[](0)
            ),
            abi.encode(_fee)
        );
    }

    function _mockGetRequestFee() internal {
        vm.mockCall(
            mockFtdcRequestFeeConfigurations,
            abi.encodeWithSelector(IFtdcRequestFeeConfigurations.getRequestFee.selector),
            abi.encode(requestFee)
        );
    }

    function _mockGetTeeMachineWithAttestationData(address _teeId, address _owner, string memory _url) internal {
        vm.mockCall(
            mockTeeRegistry,
            abi.encodeWithSelector(
                ITeeRegistry.getTeeMachineWithAttestationData.selector,
                _teeId
            ),
            abi.encode(ITeeRegistry.TeeMachineWithAttestationData({
                teeId: _teeId,
                owner: _owner,
                url: _url,
                codeHash: bytes32(0),
                platform: bytes32(0)
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

    function _getTeeMachines(uint256 _num) internal view returns (
        ITeeRegistry.TeeMachine[] memory,
        ITeeRegistry.TeeMachineWithAttestationData[] memory
    ) {
        ITeeRegistry.TeeMachine[] memory teeMachines = new ITeeRegistry.TeeMachine[](_num);

        ITeeRegistry.TeeMachineWithAttestationData[] memory teeMachinesWithAttestationData =
            new ITeeRegistry.TeeMachineWithAttestationData[](_num);

        for (uint256 i = 0; i < _num; i++) {
            teeMachines[i] = ITeeRegistry.TeeMachine({
                teeId: teeIds[i],
                owner: owners[i],
                url: urls[i]
            });

            teeMachinesWithAttestationData[i] = ITeeRegistry.TeeMachineWithAttestationData({
                teeId: teeIds[i],
                owner: owners[i],
                url: urls[i],
                codeHash: bytes32(0),
                platform: bytes32(0)
            });
        }
        return (teeMachines, teeMachinesWithAttestationData);

    }

}