// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../../contracts/ftdc/implementation/FtdcHub.sol";
import "../../../../contracts/tee/implementation/TeeInstructions.sol";
import "../../../../contracts/tee/implementation/TeeInstructionsProxy.sol";

contract FtdcHubTest is Test {

    FtdcHub private ftdcHub;

    address private governance;
    address private addressUpdater;
    address private mockTeeRegistry;
    address private mockTeeFeeCalculator;
    TeeInstructions private teeInstructions;
    TeeInstructions private teeInstructionsImpl;
    TeeInstructionsProxy private teeInstructionsProxy;
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
        ftdcHub = new FtdcHub(
            IGovernanceSettings(address(this)),
            governance,
            addressUpdater,
            minThresholdBIPS,
            defaultNumberOfTees
        );

        teeInstructionsImpl = new TeeInstructions();
        teeInstructionsProxy = new TeeInstructionsProxy(
            IGovernanceSettings(address(this)),
            governance,
            addressUpdater,
            address(teeInstructionsImpl)
        );
        teeInstructions = TeeInstructions(address(teeInstructionsProxy));

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
        ftdcHub.updateContractAddresses(contractNameHashes, contractAddresses);

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
        instructionInitiators[0] = address(ftdcHub);
        teeInstructions.registerInstructionInitiators(instructionInitiators);
        _mockReceiveRewards();

        _mockGetRequestFee();
        teeIds = new address[](2);
        urls = new string[](2);
        teeIds[0] = makeAddr("teeId1");
        teeIds[1] = makeAddr("teeId2");
        urls[0] = "url1";
        urls[1] = "url2";

        _mockGetTeeMachine(teeIds[0], urls[0]);
        _mockGetTeeMachine(teeIds[1], urls[1]);
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
        vm.expectRevert("min threshold invalid");
        ftdcHub.setMinThresholdBIPS(0);

        vm.prank(governance);
        vm.expectRevert("min threshold invalid");
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
        vm.expectRevert("default number of tees zero");
        ftdcHub.setDefaultNumberOfTees(0);

        vm.expectRevert("only governance");
        ftdcHub.setDefaultNumberOfTees(5);
    }

    function testRequestAttestationRevertThresholdInvalid() public {
        vm.expectRevert("threshold invalid");
        ftdcHub.requestAttestation(minThresholdBIPS - 1, 1, new address[](0), new address[](0), 0, "");

        vm.expectRevert("threshold invalid");
        ftdcHub.requestAttestation(1e4 + 1, 1, new address[](0), new address[](0), 0, "");
    }

    function testRequestAttestationRevertTeesInvalid() public {
        vm.expectRevert("numberOfTees and teeIds invalid");
        teeIds = new address[](1);
        teeIds[0] = makeAddr("teeId");
        ftdcHub.requestAttestation(minThresholdBIPS, 2, teeIds, new address[](0), 0, "");
    }

    function testRequestAttestationRevertTeeNotAvailable() public {
        address teeId = makeAddr("teeId");
        _mockGetTeeMachineStatus(teeId, ITeeRegistry.TeeStatus.PAUSED_FOR_UPGRADE);
        teeIds = new address[](1);
        teeIds[0] = teeId;
        vm.expectRevert("tee machine not available");
        ftdcHub.requestAttestation(minThresholdBIPS, 1, teeIds, new address[](0), 0, "");
    }

    function testRequestAttestationRevertFeeTooLow() public {
        address teeId = makeAddr("teeId");
        _mockGetTeeMachineStatus(teeId, ITeeRegistry.TeeStatus.PRODUCTION);
        teeIds = new address[](1);
        teeIds[0] = teeId;
        _mockCalculateFeeByTeeIds(teeIds, 15);
        vm.expectRevert("fee to low");
        ftdcHub.requestAttestation{value: requestFee + 15 - 1} (minThresholdBIPS, 1, teeIds, new address[](0), 0, "");
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
        bytes32 instructionId = keccak256(abi.encode(FTDC_OP_TYPE, PROVE, attestationRequest, 0));
        (ITeeRegistry.TeeMachine[] memory teeMachines, address[] memory teeMachineIds) = _getTeeMachines(2);

        IFtdcHub.FtdcProve memory message = IFtdcHub.FtdcProve({
            teeIds: teeMachineIds,
            thresholdBIPS: minThresholdBIPS,
            cosigners: new address[](0),
            cosignersThreshold: 0,
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
        ftdcHub.requestAttestation{value: requestFee + 15} (
            minThresholdBIPS, 0, teeIds, new address[](0), 0, attestationRequest
        );
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
        bytes32 instructionId = keccak256(abi.encode(FTDC_OP_TYPE, PROVE, attestationRequest, 0));
        (ITeeRegistry.TeeMachine[] memory teeMachines, address[] memory teeMachineIds) = _getTeeMachines(1);

        IFtdcHub.FtdcProve memory message = IFtdcHub.FtdcProve({
            teeIds: teeMachineIds,
            thresholdBIPS: minThresholdBIPS,
            cosigners: new address[](0),
            cosignersThreshold: 0,
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
        ftdcHub.requestAttestation{value: requestFee + 15} (
            minThresholdBIPS, 0, new address[](0), new address[](0), 0, attestationRequest
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
        bytes32 instructionId = keccak256(abi.encode(FTDC_OP_TYPE, PROVE, attestationRequest, 0));
        (ITeeRegistry.TeeMachine[] memory teeMachines, address[] memory teeMachineIds) = _getTeeMachines(2);

        IFtdcHub.FtdcProve memory message = IFtdcHub.FtdcProve({
            teeIds: teeMachineIds,
            thresholdBIPS: minThresholdBIPS,
            cosigners: new address[](0),
            cosignersThreshold: 0,
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
        ftdcHub.requestAttestation{value: requestFee + 15} (
            minThresholdBIPS, 2, new address[](0), new address[](0), 0, attestationRequest
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
                _teeIds
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

    function _mockGetTeeMachine(address _teeId, string memory _url) internal {
        vm.mockCall(
            mockTeeRegistry,
            abi.encodeWithSelector(
                ITeeRegistry.getTeeMachine.selector,
                _teeId
            ),
            abi.encode(ITeeRegistry.TeeMachine({
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

    function _getTeeMachines(uint256 _num) internal view returns (
        ITeeRegistry.TeeMachine[] memory,
        address[] memory
    ) {
        ITeeRegistry.TeeMachine[] memory teeMachines = new ITeeRegistry.TeeMachine[](_num);

        address[] memory teeMachineIds = new address[](_num);

        for (uint256 i = 0; i < _num; i++) {
            teeMachines[i] = ITeeRegistry.TeeMachine({
                teeId: teeIds[i],
                teeProxyId: teeIds[i], // for testing purposes
                url: urls[i]
            });

            teeMachineIds[i] = teeIds[i];
        }

        return (teeMachines, teeMachineIds);

    }

}