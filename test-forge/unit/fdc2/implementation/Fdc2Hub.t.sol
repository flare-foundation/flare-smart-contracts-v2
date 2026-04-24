// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { Fdc2Hub } from "../../../../contracts/fdc2/implementation/Fdc2Hub.sol";
import { Fdc2HubProxy } from "../../../../contracts/fdc2/proxy/Fdc2HubProxy.sol";
import { IOperationFees } from "../../../../contracts/userInterfaces/tee/IOperationFees.sol";
import { IMachineManager } from "../../../../contracts/userInterfaces/tee/IMachineManager.sol";
import { IReplication } from "../../../../contracts/userInterfaces/tee/IReplication.sol";
import { IFdc2Hub } from "../../../../contracts/userInterfaces/fdc2/IFdc2Hub.sol";
import { IFdc2RequestFeeConfigurations } from
    "../../../../contracts/userInterfaces/fdc2/IFdc2RequestFeeConfigurations.sol";
import { ProtocolsV2Interface } from "../../../../contracts/userInterfaces/LTS/ProtocolsV2Interface.sol";
import { IIRewardManager } from "../../../../contracts/protocol/interface/IIRewardManager.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

// solhint-disable-next-line max-states-count
contract Fdc2HubTest is Test {

    bytes32 private constant FDC2_OP_TYPE = bytes32("F_FDC2");
    bytes32 private constant PROVE = bytes32("PROVE");

    Fdc2Hub private fdc2Hub;
    Fdc2Hub private fdc2HubImpl;
    Fdc2HubProxy private fdc2HubProxy;

    address private governance;
    address private addressUpdater;
    address private flareTeeManager;
    address private mockFlareSystemsManager;
    address private mockFdc2RequestFeeConfigurations;
    address private mockRewardManager;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    uint16 private minThresholdBIPS;
    uint8 private defaultNumberOfTees;

    uint256 private requestFee = 10;

    address[] private teeIds;
    string[] private urls;

    function setUp() public {
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");
        minThresholdBIPS = 5000;
        defaultNumberOfTees = 1;
        fdc2HubImpl = new Fdc2Hub();
        fdc2HubProxy = new Fdc2HubProxy(
            IGovernanceSettings(address(this)),
            governance,
            addressUpdater,
            minThresholdBIPS,
            defaultNumberOfTees,
            address(fdc2HubImpl)
        );
        fdc2Hub = Fdc2Hub(address(fdc2HubProxy));

        flareTeeManager = makeAddr("flareTeeManager");
        mockFlareSystemsManager = makeAddr("mockFlareSystemsManager");
        mockFdc2RequestFeeConfigurations = makeAddr("mockFdc2RequestFeeConfigurations");
        mockRewardManager = makeAddr("rewardManager");

        // set contract addresses
        vm.startPrank(addressUpdater);
        contractNameHashes = new bytes32[](5);
        contractAddresses = new address[](5);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractAddresses[0] = addressUpdater;
        contractNameHashes[1] = keccak256(abi.encode("FlareTeeManager"));
        contractAddresses[1] = flareTeeManager;
        contractNameHashes[2] = keccak256(abi.encode("FlareSystemsManager"));
        contractAddresses[2] = mockFlareSystemsManager;
        contractNameHashes[3] = keccak256(abi.encode("RewardManager"));
        contractAddresses[3] = mockRewardManager;
        contractNameHashes[4] = keccak256(abi.encode("Fdc2RequestFeeConfigurations"));
        contractAddresses[4] = mockFdc2RequestFeeConfigurations;
        fdc2Hub.updateContractAddresses(contractNameHashes, contractAddresses);
        vm.stopPrank();
        _mockReceiveRewards();
        _mockSendSystemInstructions();

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
        assertEq(fdc2Hub.minThresholdBIPS(), minThresholdBIPS);
        vm.prank(governance);
        fdc2Hub.setMinThresholdBIPS(newMinThresholdBIPS);
        assertEq(fdc2Hub.minThresholdBIPS(), newMinThresholdBIPS);
    }

    function testSetMinThresholdBIPSRevert() public {
        vm.prank(governance);
        vm.expectRevert(IFdc2Hub.MinThresholdInvalid.selector);
        fdc2Hub.setMinThresholdBIPS(0);

        vm.prank(governance);
        vm.expectRevert(IFdc2Hub.MinThresholdInvalid.selector);
        fdc2Hub.setMinThresholdBIPS(1e4 + 1);

        vm.expectRevert("only governance");
        fdc2Hub.setMinThresholdBIPS(3000);
    }

    function testDefaultNumberOfTees() public {
        uint8 newDefaultNumberOfTees = 5;
        assertEq(fdc2Hub.defaultNumberOfTees(), defaultNumberOfTees);
        vm.prank(governance);
        fdc2Hub.setDefaultNumberOfTees(newDefaultNumberOfTees);
        assertEq(fdc2Hub.defaultNumberOfTees(), newDefaultNumberOfTees);
    }

    function testDefaultNumberOfTeesRevert() public {
        vm.prank(governance);
        vm.expectRevert(IFdc2Hub.DefaultNumberOfTeesZero.selector);
        fdc2Hub.setDefaultNumberOfTees(0);

        vm.expectRevert("only governance");
        fdc2Hub.setDefaultNumberOfTees(5);
    }

    function testRequestAttestationRevertThresholdInvalid() public {
        vm.expectRevert(IFdc2Hub.ThresholdInvalid.selector);
        fdc2Hub.requestAttestation(
            IFdc2Hub.Fdc2AttestationRequest({
                header: IFdc2Hub.Fdc2RequestHeader("", "", minThresholdBIPS - 1, address(0)),
                requestBody: ""
            }),
            1, new address[](0), new address[](0), 0, address(0)
        );

        vm.expectRevert(IFdc2Hub.ThresholdInvalid.selector);
        fdc2Hub.requestAttestation(
            IFdc2Hub.Fdc2AttestationRequest({
                header: IFdc2Hub.Fdc2RequestHeader("", "", 1e4 + 1, address(0)),
                requestBody: ""
            }),
            1, new address[](0), new address[](0), 0, address(0)
        );
    }

    function testRequestAttestationRevertTeesInvalid() public {
        vm.expectRevert(IFdc2Hub.NumberOfTeesAndTeeIdsInvalid.selector);
        teeIds = new address[](1);
        teeIds[0] = makeAddr("teeId");
        fdc2Hub.requestAttestation(
            IFdc2Hub.Fdc2AttestationRequest({
                header: IFdc2Hub.Fdc2RequestHeader("", "", minThresholdBIPS, address(0)),
                requestBody: ""
            }),
            2, teeIds, new address[](0), 0, address(0)
        );
    }

    function testRequestAttestationRevertDuplicatedTeeId() public {
        address teeId = makeAddr("teeId");
        _mockGetTeeMachineStatus(teeId, IMachineManager.TeeStatus.PAUSED_FOR_UPGRADE);
        _mockGetTeeReplicatingTeeId(teeId, address(0));
        teeIds = new address[](2);
        teeIds[0] = teeId;
        teeIds[1] = teeId;
        vm.expectRevert(
            abi.encodeWithSelector(
                IFdc2Hub.DuplicatedTeeId.selector,
                teeId
            )
        );
        fdc2Hub.requestAttestation(
            IFdc2Hub.Fdc2AttestationRequest({
                header: IFdc2Hub.Fdc2RequestHeader("", "", minThresholdBIPS, address(0)),
                requestBody: ""
            }),
            2, teeIds, new address[](0), 0, address(0)
        );
    }

    function testRequestAttestationRevertTeeMachineNotAvailable() public {
        address teeId = makeAddr("teeId");
        _mockGetTeeMachineStatus(teeId, IMachineManager.TeeStatus.PAUSED_FOR_UPGRADE);
        _mockGetTeeReplicatingTeeId(teeId, address(0));
        teeIds = new address[](1);
        teeIds[0] = teeId;
        vm.expectRevert(IFdc2Hub.TeeMachineNotAvailable.selector);
        fdc2Hub.requestAttestation(
            IFdc2Hub.Fdc2AttestationRequest({
                header: IFdc2Hub.Fdc2RequestHeader("", "", minThresholdBIPS, address(0)),
                requestBody: ""
            }),
            1, teeIds, new address[](0), 0, address(0)
        );
    }

    function testRequestAttestationRevertOnlySystemExtensionId() public {
        _mockGetExtensionId(1);
        address teeId = makeAddr("teeId");
        _mockGetTeeMachine(teeId, "url");
        _mockGetTeeMachineStatus(teeId, IMachineManager.TeeStatus.PRODUCTION);
        teeIds = new address[](1);
        teeIds[0] = teeId;
        vm.expectRevert(
            abi.encodeWithSelector(
                IFdc2Hub.OnlySystemExtensionId.selector,
                teeId
            )
        );
        fdc2Hub.requestAttestation(
            IFdc2Hub.Fdc2AttestationRequest({
                header: IFdc2Hub.Fdc2RequestHeader("", "", minThresholdBIPS, address(0)),
                requestBody: ""
            }),
            0, teeIds, new address[](0), 0, address(0)
        );
    }

    function testRequestAttestationRevertFeeTooLow() public {
        address teeId = makeAddr("teeId");
        _mockGetTeeMachine(teeId, "url");
        _mockGetTeeMachineStatus(teeId, IMachineManager.TeeStatus.PRODUCTION);
        teeIds = new address[](1);
        teeIds[0] = teeId;
        vm.expectRevert(IFdc2Hub.FeeTooLow.selector);
        fdc2Hub.requestAttestation{value: requestFee - 1} (
            IFdc2Hub.Fdc2AttestationRequest({
                header: IFdc2Hub.Fdc2RequestHeader("", "", minThresholdBIPS, address(0)),
                requestBody: ""
            }),
            1, teeIds, new address[](0), 0, address(0)
        );
    }

    // list of teeIds provided
    function testRequestAttestation1() public {
        _mockGetTeeMachineStatus(teeIds[0], IMachineManager.TeeStatus.PRODUCTION);
        _mockGetTeeMachineStatus(teeIds[1], IMachineManager.TeeStatus.PRODUCTION);
        address[] memory teeIdsForFee = new address[](2);
        teeIdsForFee[0] = teeIds[0];
        teeIdsForFee[1] = teeIds[1];
        _mockGetCurrentRewardEpochId(123);
        bytes32 attestationType = "PMWPaymentStatus";
        bytes32 sourceId = "XRP";
        bytes memory attestationRequest = "attestationRequest";

        IFdc2Hub.Fdc2AttestationRequest memory message = IFdc2Hub.Fdc2AttestationRequest({
            header: IFdc2Hub.Fdc2RequestHeader({
                attestationType: attestationType,
                sourceId: sourceId,
                thresholdBIPS: minThresholdBIPS,
                proofOwner: address(0)
            }),
            requestBody: attestationRequest
        });
        fdc2Hub.requestAttestation{value: requestFee + 15} (
            message, 0, teeIds, new address[](0), 0, address(0)
        );
    }

    function testRequestAttestationWithProofOwnerAndClaimBack() public {
        _mockGetTeeMachineStatus(teeIds[0], IMachineManager.TeeStatus.PRODUCTION);
        _mockGetTeeMachineStatus(teeIds[1], IMachineManager.TeeStatus.PRODUCTION);
        address[] memory teeIdsForFee = new address[](2);
        teeIdsForFee[0] = teeIds[0];
        teeIdsForFee[1] = teeIds[1];
        _mockGetCurrentRewardEpochId(123);
        bytes32 attestationType = "PMWPaymentStatus";
        bytes32 sourceId = "XRP";
        bytes memory attestationRequest = "attestationRequest";
        address proofOwner = makeAddr("proofOwner");
        address claimBack = makeAddr("claimBack");

        IFdc2Hub.Fdc2AttestationRequest memory message = IFdc2Hub.Fdc2AttestationRequest({
            header: IFdc2Hub.Fdc2RequestHeader({
                attestationType: attestationType,
                sourceId: sourceId,
                thresholdBIPS: minThresholdBIPS,
                proofOwner: proofOwner
            }),
            requestBody: attestationRequest
        });
        fdc2Hub.requestAttestation{value: requestFee + 15} (
            message, 0, teeIds, new address[](0), 0, claimBack
        );
    }

    // list of teeIds not provided and number is also not (it will take default)
    function testRequestAttestation2() public {
        _mockGetTeeMachineStatus(teeIds[0], IMachineManager.TeeStatus.PRODUCTION);
        address[] memory teeIdsForFee = new address[](1);
        teeIdsForFee[0] = teeIds[0];

        vm.mockCall(
            flareTeeManager,
            abi.encodeWithSelector(
                IMachineManager.getRandomTeeIds.selector, 0, 1
            ),
            abi.encode(teeIdsForFee)
        );

        _mockGetCurrentRewardEpochId(123);
        bytes32 attestationType = "PMWPaymentStatus";
        bytes32 sourceId = "XRP";
        bytes memory attestationRequest = "attestationRequest";

        IFdc2Hub.Fdc2AttestationRequest memory message = IFdc2Hub.Fdc2AttestationRequest({
            header: IFdc2Hub.Fdc2RequestHeader({
                attestationType: attestationType,
                sourceId: sourceId,
                thresholdBIPS: minThresholdBIPS,
                proofOwner: address(0)
            }),
            requestBody: attestationRequest
        });
        fdc2Hub.requestAttestation{value: requestFee + 15} (
            message, 0, new address[](0), new address[](0), 0, address(0)
        );
    }

    // list of teeIds is not provided but the number is
    function testRequestAttestation3() public {
        _mockGetTeeMachineStatus(teeIds[0], IMachineManager.TeeStatus.PRODUCTION);
        _mockGetTeeMachineStatus(teeIds[1], IMachineManager.TeeStatus.PRODUCTION);
        vm.mockCall(
            flareTeeManager,
            abi.encodeWithSelector(
                IMachineManager.getRandomTeeIds.selector, 0, 2
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

        IFdc2Hub.Fdc2AttestationRequest memory message = IFdc2Hub.Fdc2AttestationRequest({
            header: IFdc2Hub.Fdc2RequestHeader({
                attestationType: attestationType,
                sourceId: sourceId,
                thresholdBIPS: minThresholdBIPS,
                proofOwner: address(0)
            }),
            requestBody: attestationRequest
        });
        fdc2Hub.requestAttestation{value: requestFee + 15} (
            message, 2, new address[](0), new address[](0), 0, address(0)
        );
    }

    /// Helper and mock functions ///
    function _mockGetTeeMachineStatus(address _teeId, IMachineManager.TeeStatus _status) internal {
        vm.mockCall(
            flareTeeManager,
            abi.encodeWithSelector(
                IMachineManager.getTeeMachineStatus.selector,
                _teeId
            ),
            abi.encode(_status)
        );
    }

    function _mockGetTeeReplicatingTeeId(address _teeId, address _replicatingTeeId) internal {
        vm.mockCall(
            flareTeeManager,
            abi.encodeWithSelector(
                IReplication.getReplicatingTeeId.selector,
                _teeId
            ),
            abi.encode(_replicatingTeeId)
        );
    }

    function _mockGetTypeAndSourceFee() internal {
        vm.mockCall(
            mockFdc2RequestFeeConfigurations,
            abi.encodeWithSelector(IFdc2RequestFeeConfigurations.getTypeAndSourceFee.selector),
            abi.encode(requestFee)
        );
    }

    function _mockGetTeeMachine(address _teeId, string memory _url) internal {
        vm.mockCall(
            flareTeeManager,
            abi.encodeWithSelector(
                IMachineManager.getTeeMachine.selector,
                _teeId
            ),
            abi.encode(IMachineManager.TeeMachine({
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
            flareTeeManager,
            abi.encodeWithSelector(
                IMachineManager.getExtensionId.selector
            ),
            abi.encode(_extensionId)
        );
    }

    function _mockCalculateFeeByTeeIds(uint256 _fee) internal {
        vm.mockCall(
            flareTeeManager,
            abi.encodeWithSelector(
                IOperationFees.calculateFeeByTeeIds.selector
            ),
            abi.encode(_fee)
        );
    }

    function _mockSendSystemInstructions() internal {
        // sendSystemInstructions(bytes32,(address,address,string)[],(bytes32,bytes32,bytes,address[],uint64,address))
        bytes4 sel = bytes4(keccak256(
            "sendSystemInstructions(bytes32,"
            "(address,address,string)[],"
            "(bytes32,bytes32,bytes,address[],uint64,address))"
        ));
        vm.mockCall(
            flareTeeManager,
            abi.encodePacked(sel),
            abi.encode(bytes32(uint256(1)))
        );
    }

    function _getTeeMachines(
        uint256 _num
    )
        internal view
        returns (IMachineManager.TeeMachine[] memory _teeMachines)
    {
        _teeMachines = new IMachineManager.TeeMachine[](_num);

        for (uint256 i = 0; i < _num; i++) {
            _teeMachines[i] = IMachineManager.TeeMachine({
                teeId: teeIds[i],
                teeProxyId: teeIds[i], // for testing purposes
                url: urls[i]
            });
        }
    }
}