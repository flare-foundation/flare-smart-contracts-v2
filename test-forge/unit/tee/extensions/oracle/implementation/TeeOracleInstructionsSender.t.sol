// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import {
    TeeOracleInstructionsSender
} from "../../../../../../contracts/tee/extensions/oracle/implementation/TeeOracleInstructionsSender.sol";
import {
    TeeOracleInstructionsSenderProxy
} from "../../../../../../contracts/tee/extensions/oracle/proxy/TeeOracleInstructionsSenderProxy.sol";
import {
    ITeeOracleInstructionsSender,
    TEE_ORACLE_OP_TYPE,
    GET_FEED_COMMAND,
    SET_ENDPOINTS_COMMAND,
    SET_ADMINS_COMMAND,
    GET_FEED_REQUEST_V1
} from "../../../../../../contracts/userInterfaces/tee/ITeeOracleInstructionsSender.sol";
import { IInstructions } from "../../../../../../contracts/userInterfaces/tee/IInstructions.sol";
import { IMachineManager } from "../../../../../../contracts/userInterfaces/tee/IMachineManager.sol";
import { IFlareGovernance } from "../../../../../../contracts/userInterfaces/IFlareGovernance.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

contract TeeOracleInstructionsSenderTest is Test {

    uint256 private constant EXTENSION_ID = 1;
    bytes32 private constant INSTRUCTION_ID = keccak256("instructionId");
    uint256 private constant TIMELOCK = 3600;

    TeeOracleInstructionsSender private sender;
    TeeOracleInstructionsSender private senderImpl;

    address private governance;
    address private productionGovernance;
    address private executor;
    address private addressUpdater;
    address private flareTeeManager;
    address private teeId1;
    address private teeId2;
    address private claimBack;
    IGovernanceSettings private governanceSettings;

    function setUp() public {
        vm.warp(1_700_000_000);

        governance = makeAddr("governance");
        productionGovernance = makeAddr("productionGovernance");
        executor = makeAddr("executor");
        addressUpdater = makeAddr("addressUpdater");
        teeId1 = makeAddr("teeId1");
        teeId2 = makeAddr("teeId2");
        claimBack = makeAddr("claimBack");
        governanceSettings = IGovernanceSettings(makeAddr("governanceSettings"));

        senderImpl = new TeeOracleInstructionsSender();
        TeeOracleInstructionsSenderProxy proxy = new TeeOracleInstructionsSenderProxy(
            governanceSettings,
            governance,
            addressUpdater,
            EXTENSION_ID,
            address(senderImpl)
        );
        sender = TeeOracleInstructionsSender(address(proxy));

        bytes32[] memory contractNameHashes = new bytes32[](2);
        address[] memory contractAddresses = new address[](2);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("FlareTeeManager"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = makeAddr("FlareTeeManager");
        vm.prank(addressUpdater);
        sender.updateContractAddresses(contractNameHashes, contractAddresses);

        flareTeeManager = address(sender.flareTeeManager());

        _mockSendInstructions();
        _mockGetExtensionId(teeId1, EXTENSION_ID);
        _mockGetExtensionId(teeId2, EXTENSION_ID);
    }

    // -------------------------------------------------------------------------
    // initialization
    // -------------------------------------------------------------------------

    function testInitialState() public {
        assertEq(sender.extensionId(), EXTENSION_ID);
        assertEq(sender.endpointsVersion(), 0);
        assertEq(sender.adminsVersion(), 0);
        assertEq(sender.governance(), governance);
        assertEq(sender.implementation(), address(senderImpl));
    }

    function testInitializeEmitsEvent() public {
        vm.expectEmit();
        emit ITeeOracleInstructionsSender.InstructionsSenderInitialised(EXTENSION_ID);
        new TeeOracleInstructionsSenderProxy(
            governanceSettings,
            governance,
            addressUpdater,
            EXTENSION_ID,
            address(senderImpl)
        );
    }

    function testInitializeRevertInvalidExtensionId() public {
        vm.expectRevert(ITeeOracleInstructionsSender.InvalidExtensionId.selector);
        new TeeOracleInstructionsSenderProxy(
            governanceSettings,
            governance,
            addressUpdater,
            0,
            address(senderImpl)
        );
    }

    function testReinitializeReverts() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        sender.initialize(governanceSettings, governance, addressUpdater, EXTENSION_ID);
    }

    function testImplementationCannotBeInitialized() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        senderImpl.initialize(governanceSettings, governance, addressUpdater, EXTENSION_ID);
    }

    // -------------------------------------------------------------------------
    // requestFeedUpdate
    // -------------------------------------------------------------------------

    function testRequestFeedUpdate() public {
        address[] memory teeIds = new address[](1);
        teeIds[0] = teeId1;
        _mockGetRandomTeeIds(teeIds);

        // the entire msg.value is forwarded and the caller is the claim-back address
        vm.expectCall(
            flareTeeManager,
            42,
            abi.encodeCall(
                IInstructions.sendInstructions,
                (teeIds, _params(GET_FEED_COMMAND, GET_FEED_REQUEST_V1, address(this)))
            )
        );
        vm.expectEmit();
        emit ITeeOracleInstructionsSender.FeedUpdateRequested(address(this), INSTRUCTION_ID);
        bytes32 instructionId = sender.requestFeedUpdate{value: 42}();
        assertEq(instructionId, INSTRUCTION_ID);
    }

    function testRequestFeedUpdateIsPermissionless() public {
        address[] memory teeIds = new address[](1);
        teeIds[0] = teeId1;
        _mockGetRandomTeeIds(teeIds);
        address anyone = makeAddr("anyone");
        vm.deal(anyone, 1 ether);
        vm.prank(anyone);
        sender.requestFeedUpdate{value: 1}();
    }

    // -------------------------------------------------------------------------
    // setEndpoints
    // -------------------------------------------------------------------------

    function testSetEndpoints() public {
        ITeeOracleInstructionsSender.EndpointGroup[] memory groups = _makeGroups(2, 3);
        bytes memory message = abi.encode(
            ITeeOracleInstructionsSender.Endpoints({version: 1, groups: groups})
        );
        bytes32 endpointsHash = keccak256(message);

        vm.expectEmit();
        emit ITeeOracleInstructionsSender.EndpointsSet(teeId1, 1, endpointsHash);
        vm.expectEmit();
        emit ITeeOracleInstructionsSender.EndpointsSet(teeId2, 1, endpointsHash);
        // one instruction to all targeted machines, full msg.value forwarded
        vm.expectCall(
            flareTeeManager,
            7,
            abi.encodeCall(
                IInstructions.sendInstructions,
                (_bothTees(), _params(SET_ENDPOINTS_COMMAND, message, claimBack))
            )
        );
        vm.deal(governance, 7);
        vm.prank(governance);
        sender.setEndpoints{value: 7}(_bothTees(), groups, claimBack);

        // one version and hash per publication, shared by every targeted machine
        assertEq(sender.endpointsVersion(), 1);
        assertEq(sender.expectedEndpointsHash(teeId1), endpointsHash);
        assertEq(sender.expectedEndpointsHash(teeId2), endpointsHash);
        assertEq(sender.expectedEndpointsVersion(teeId1), 1);
        assertEq(sender.expectedEndpointsVersion(teeId2), 1);
    }

    function testSetEndpointsIdenticalContentGetsNewVersionAndHash() public {
        ITeeOracleInstructionsSender.EndpointGroup[] memory groups = _makeGroups(1, 1);
        vm.startPrank(governance);
        sender.setEndpoints(_oneTee(), groups, claimBack);
        bytes32 firstHash = sender.expectedEndpointsHash(teeId1);
        sender.setEndpoints(_oneTee(), groups, claimBack);
        vm.stopPrank();
        assertEq(sender.endpointsVersion(), 2);
        assertEq(sender.expectedEndpointsVersion(teeId1), 2);
        // the version is inside the encoded payload, so the hash moves too
        assertNotEq(sender.expectedEndpointsHash(teeId1), firstHash);
    }

    function testSetEndpointsPartialRollout() public {
        ITeeOracleInstructionsSender.EndpointGroup[] memory groups = _makeGroups(1, 1);
        vm.startPrank(governance);
        sender.setEndpoints(_bothTees(), groups, claimBack);
        sender.setEndpoints(_oneTee(), groups, claimBack);
        vm.stopPrank();
        // only the re-published machine moves to the new generation
        assertEq(sender.expectedEndpointsVersion(teeId1), 2);
        assertEq(sender.expectedEndpointsVersion(teeId2), 1);
    }

    function testSetEndpointsRevertOnlyGovernance() public {
        vm.expectRevert(IFlareGovernance.OnlyGovernance.selector);
        sender.setEndpoints(_oneTee(), _makeGroups(1, 1), claimBack);
    }

    function testSetEndpointsRevertNoTeeIds() public {
        vm.expectRevert(ITeeOracleInstructionsSender.NoTeeIds.selector);
        vm.prank(governance);
        sender.setEndpoints(new address[](0), _makeGroups(1, 1), claimBack);
    }

    function testSetEndpointsRevertZeroTeeId() public {
        address[] memory teeIds = new address[](2);
        teeIds[0] = teeId1;
        teeIds[1] = address(0);
        vm.expectRevert(ITeeOracleInstructionsSender.ZeroTeeId.selector);
        vm.prank(governance);
        sender.setEndpoints(teeIds, _makeGroups(1, 1), claimBack);
    }

    function testSetEndpointsRevertDuplicateTeeId() public {
        address[] memory teeIds = new address[](2);
        teeIds[0] = teeId1;
        teeIds[1] = teeId1;
        vm.expectRevert(ITeeOracleInstructionsSender.DuplicateTeeId.selector);
        vm.prank(governance);
        sender.setEndpoints(teeIds, _makeGroups(1, 1), claimBack);
    }

    function testSetEndpointsRevertTeeIdNotInExtension() public {
        // this sender could be registered as the instructions sender of a foreign
        // extension - targets must be pinned to its own extension
        _mockGetExtensionId(teeId1, EXTENSION_ID + 1);
        vm.expectRevert(ITeeOracleInstructionsSender.TeeIdNotInExtension.selector);
        vm.prank(governance);
        sender.setEndpoints(_oneTee(), _makeGroups(1, 1), claimBack);
    }

    function testSetEndpointsRevertNoGroups() public {
        vm.expectRevert(ITeeOracleInstructionsSender.NoGroups.selector);
        vm.prank(governance);
        sender.setEndpoints(_oneTee(), new ITeeOracleInstructionsSender.EndpointGroup[](0), claimBack);
    }

    function testSetEndpointsRevertEmptyGroup() public {
        ITeeOracleInstructionsSender.EndpointGroup[] memory groups = _makeGroups(1, 1);
        groups[0].group = bytes32(0);
        vm.expectRevert(ITeeOracleInstructionsSender.EmptyGroup.selector);
        vm.prank(governance);
        sender.setEndpoints(_oneTee(), groups, claimBack);
    }

    function testSetEndpointsRevertDuplicateGroup() public {
        ITeeOracleInstructionsSender.EndpointGroup[] memory groups = _makeGroups(2, 1);
        groups[1].group = groups[0].group;
        vm.expectRevert(ITeeOracleInstructionsSender.DuplicateGroup.selector);
        vm.prank(governance);
        sender.setEndpoints(_oneTee(), groups, claimBack);
    }

    function testSetEndpointsRevertNoEndpoints() public {
        ITeeOracleInstructionsSender.EndpointGroup[] memory groups = _makeGroups(1, 1);
        groups[0].endpoints = new ITeeOracleInstructionsSender.Endpoint[](0);
        vm.expectRevert(ITeeOracleInstructionsSender.NoEndpoints.selector);
        vm.prank(governance);
        sender.setEndpoints(_oneTee(), groups, claimBack);
    }

    function testSetEndpointsRevertZeroThreshold() public {
        ITeeOracleInstructionsSender.EndpointGroup[] memory groups = _makeGroups(1, 2);
        groups[0].threshold = 0;
        vm.expectRevert(ITeeOracleInstructionsSender.InvalidThreshold.selector);
        vm.prank(governance);
        sender.setEndpoints(_oneTee(), groups, claimBack);
    }

    function testSetEndpointsRevertThresholdAboveEndpointCount() public {
        ITeeOracleInstructionsSender.EndpointGroup[] memory groups = _makeGroups(1, 2);
        groups[0].threshold = 3;
        vm.expectRevert(ITeeOracleInstructionsSender.InvalidThreshold.selector);
        vm.prank(governance);
        sender.setEndpoints(_oneTee(), groups, claimBack);
    }

    function testSetEndpointsRevertPublicEndpointWithoutUrl() public {
        ITeeOracleInstructionsSender.EndpointGroup[] memory groups = _makeGroups(1, 1);
        groups[0].endpoints[0].url = "";
        vm.expectRevert(ITeeOracleInstructionsSender.InvalidEndpoint.selector);
        vm.prank(governance);
        sender.setEndpoints(_oneTee(), groups, claimBack);
    }

    function testSetEndpointsRevertPublicEndpointWithUrlHash() public {
        ITeeOracleInstructionsSender.EndpointGroup[] memory groups = _makeGroups(1, 1);
        groups[0].endpoints[0].urlHash = keccak256("hash");
        vm.expectRevert(ITeeOracleInstructionsSender.InvalidEndpoint.selector);
        vm.prank(governance);
        sender.setEndpoints(_oneTee(), groups, claimBack);
    }

    function testSetEndpointsRevertPrivateEndpointWithUrl() public {
        ITeeOracleInstructionsSender.EndpointGroup[] memory groups = _makeGroups(1, 1);
        groups[0].endpoints[0].kind = ITeeOracleInstructionsSender.EndpointKind.PRIVATE;
        groups[0].endpoints[0].urlHash = keccak256("hash");
        // url still set - inconsistent
        vm.expectRevert(ITeeOracleInstructionsSender.InvalidEndpoint.selector);
        vm.prank(governance);
        sender.setEndpoints(_oneTee(), groups, claimBack);
    }

    function testSetEndpointsRevertPrivateEndpointWithoutUrlHash() public {
        ITeeOracleInstructionsSender.EndpointGroup[] memory groups = _makeGroups(1, 1);
        groups[0].endpoints[0].kind = ITeeOracleInstructionsSender.EndpointKind.PRIVATE;
        groups[0].endpoints[0].url = "";
        vm.expectRevert(ITeeOracleInstructionsSender.InvalidEndpoint.selector);
        vm.prank(governance);
        sender.setEndpoints(_oneTee(), groups, claimBack);
    }

    function testSetEndpointsAcceptsPrivateEndpoint() public {
        ITeeOracleInstructionsSender.EndpointGroup[] memory groups = _makeGroups(1, 1);
        groups[0].endpoints[0] = ITeeOracleInstructionsSender.Endpoint({
            kind: ITeeOracleInstructionsSender.EndpointKind.PRIVATE,
            url: "",
            urlHash: keccak256("salted private url"),
            secretRef: "hex_cash_url"
        });
        vm.prank(governance);
        sender.setEndpoints(_oneTee(), groups, claimBack);
        assertEq(sender.endpointsVersion(), 1);
    }

    // -------------------------------------------------------------------------
    // setAdmins
    // -------------------------------------------------------------------------

    function testSetAdmins() public {
        ITeeOracleInstructionsSender.AdminRole[] memory roles = _makeRoles(2, 3);
        bytes memory message = abi.encode(
            ITeeOracleInstructionsSender.Admins({version: 1, roles: roles})
        );
        bytes32 adminsHash = keccak256(message);

        vm.expectEmit();
        emit ITeeOracleInstructionsSender.AdminsSet(teeId1, 1, adminsHash);
        vm.expectCall(
            flareTeeManager,
            0,
            abi.encodeCall(
                IInstructions.sendInstructions,
                (_oneTee(), _params(SET_ADMINS_COMMAND, message, claimBack))
            )
        );
        vm.prank(governance);
        sender.setAdmins(_oneTee(), roles, claimBack);

        assertEq(sender.adminsVersion(), 1);
        assertEq(sender.expectedAdminsHash(teeId1), adminsHash);
        assertEq(sender.expectedAdminsVersion(teeId1), 1);
        // endpoints and admins version independently
        assertEq(sender.endpointsVersion(), 0);
    }

    function testSetAdminsRevertOnlyGovernance() public {
        vm.expectRevert(IFlareGovernance.OnlyGovernance.selector);
        sender.setAdmins(_oneTee(), _makeRoles(1, 1), claimBack);
    }

    function testSetAdminsRevertNoRoles() public {
        vm.expectRevert(ITeeOracleInstructionsSender.NoRoles.selector);
        vm.prank(governance);
        sender.setAdmins(_oneTee(), new ITeeOracleInstructionsSender.AdminRole[](0), claimBack);
    }

    function testSetAdminsRevertEmptyRole() public {
        ITeeOracleInstructionsSender.AdminRole[] memory roles = _makeRoles(1, 1);
        roles[0].role = bytes32(0);
        vm.expectRevert(ITeeOracleInstructionsSender.EmptyRole.selector);
        vm.prank(governance);
        sender.setAdmins(_oneTee(), roles, claimBack);
    }

    function testSetAdminsRevertDuplicateRole() public {
        ITeeOracleInstructionsSender.AdminRole[] memory roles = _makeRoles(2, 1);
        roles[1].role = roles[0].role;
        vm.expectRevert(ITeeOracleInstructionsSender.DuplicateRole.selector);
        vm.prank(governance);
        sender.setAdmins(_oneTee(), roles, claimBack);
    }

    function testSetAdminsRevertNoAdmins() public {
        ITeeOracleInstructionsSender.AdminRole[] memory roles = _makeRoles(1, 1);
        roles[0].admins = new address[](0);
        vm.expectRevert(ITeeOracleInstructionsSender.NoAdmins.selector);
        vm.prank(governance);
        sender.setAdmins(_oneTee(), roles, claimBack);
    }

    function testSetAdminsRevertZeroThreshold() public {
        ITeeOracleInstructionsSender.AdminRole[] memory roles = _makeRoles(1, 2);
        roles[0].threshold = 0;
        vm.expectRevert(ITeeOracleInstructionsSender.InvalidThreshold.selector);
        vm.prank(governance);
        sender.setAdmins(_oneTee(), roles, claimBack);
    }

    function testSetAdminsRevertThresholdAboveAdminCount() public {
        ITeeOracleInstructionsSender.AdminRole[] memory roles = _makeRoles(1, 2);
        roles[0].threshold = 3;
        vm.expectRevert(ITeeOracleInstructionsSender.InvalidThreshold.selector);
        vm.prank(governance);
        sender.setAdmins(_oneTee(), roles, claimBack);
    }

    function testSetAdminsRevertZeroAdmin() public {
        ITeeOracleInstructionsSender.AdminRole[] memory roles = _makeRoles(1, 2);
        roles[0].admins[1] = address(0);
        vm.expectRevert(ITeeOracleInstructionsSender.ZeroAdmin.selector);
        vm.prank(governance);
        sender.setAdmins(_oneTee(), roles, claimBack);
    }

    function testSetAdminsRevertDuplicateAdmin() public {
        ITeeOracleInstructionsSender.AdminRole[] memory roles = _makeRoles(1, 2);
        roles[0].admins[1] = roles[0].admins[0];
        vm.expectRevert(ITeeOracleInstructionsSender.DuplicateAdmin.selector);
        vm.prank(governance);
        sender.setAdmins(_oneTee(), roles, claimBack);
    }

    function testSetAdminsAllowsOverlappingRoles() public {
        // the same admin may appear in two different roles
        ITeeOracleInstructionsSender.AdminRole[] memory roles = _makeRoles(2, 1);
        roles[1].admins[0] = roles[0].admins[0];
        vm.prank(governance);
        sender.setAdmins(_oneTee(), roles, claimBack);
        assertEq(sender.adminsVersion(), 1);
    }

    // -------------------------------------------------------------------------
    // governance timelock (production mode)
    // -------------------------------------------------------------------------

    function testSetEndpointsTimelockedWithExecutorAttachedValue() public {
        _switchToProduction();

        ITeeOracleInstructionsSender.EndpointGroup[] memory groups = _makeGroups(1, 1);
        bytes memory call = abi.encodeCall(sender.setEndpoints, (_oneTee(), groups, claimBack));

        // recording does not execute the body
        vm.prank(productionGovernance);
        (bool ok,) = address(sender).call(call);
        assertTrue(ok);
        assertEq(sender.endpointsVersion(), 0, "must not execute immediately");

        // the executor attaches the fee at execution time; it is forwarded to the dispatch
        vm.warp(vm.getBlockTimestamp() + TIMELOCK);
        vm.deal(executor, 13);
        vm.expectCall(
            flareTeeManager,
            13,
            abi.encodeWithSelector(IInstructions.sendInstructions.selector)
        );
        vm.prank(executor);
        IFlareGovernance(address(sender)).executeGovernanceCall{value: 13}(call);
        assertEq(sender.endpointsVersion(), 1);
    }

    function testSetEndpointsRecordingRevertsWithValue() public {
        _switchToProduction();
        vm.deal(productionGovernance, 1);
        vm.expectRevert(IFlareGovernance.TimelockValueNotAllowed.selector);
        vm.prank(productionGovernance);
        sender.setEndpoints{value: 1}(_oneTee(), _makeGroups(1, 1), claimBack);
    }

    // -------------------------------------------------------------------------
    // upgrade / address updater
    // -------------------------------------------------------------------------

    function testUpgradeToAndCallPreservesState() public {
        vm.prank(governance);
        sender.setEndpoints(_oneTee(), _makeGroups(1, 1), claimBack);
        bytes32 endpointsHash = sender.expectedEndpointsHash(teeId1);

        TeeOracleInstructionsSender newImpl = new TeeOracleInstructionsSender();
        vm.prank(governance);
        sender.upgradeToAndCall(address(newImpl), "");
        assertEq(sender.implementation(), address(newImpl));
        assertEq(sender.extensionId(), EXTENSION_ID);
        assertEq(sender.endpointsVersion(), 1);
        assertEq(sender.expectedEndpointsHash(teeId1), endpointsHash);
    }

    function testUpgradeToAndCallRevertOnlyGovernance() public {
        TeeOracleInstructionsSender newImpl = new TeeOracleInstructionsSender();
        vm.expectRevert(IFlareGovernance.OnlyGovernance.selector);
        sender.upgradeToAndCall(address(newImpl), "");
    }

    function testUpdateContractAddressesRevertOnlyAddressUpdater() public {
        bytes32[] memory contractNameHashes = new bytes32[](0);
        address[] memory contractAddresses = new address[](0);
        vm.expectRevert("only address updater");
        sender.updateContractAddresses(contractNameHashes, contractAddresses);
    }

    // -------------------------------------------------------------------------
    // helpers
    // -------------------------------------------------------------------------

    function _oneTee() private view returns (address[] memory _teeIds) {
        _teeIds = new address[](1);
        _teeIds[0] = teeId1;
    }

    function _bothTees() private view returns (address[] memory _teeIds) {
        _teeIds = new address[](2);
        _teeIds[0] = teeId1;
        _teeIds[1] = teeId2;
    }

    function _params(
        bytes32 _opCommand,
        bytes memory _message,
        address _claimBackAddress
    )
        private pure
        returns (IInstructions.TeeInstructionParams memory)
    {
        return IInstructions.TeeInstructionParams({
            opType: TEE_ORACLE_OP_TYPE,
            opCommand: _opCommand,
            message: _message,
            cosigners: new address[](0),
            cosignersThreshold: 0,
            claimBackAddress: _claimBackAddress
        });
    }

    function _makeGroups(
        uint256 _groupCount,
        uint256 _endpointCount
    )
        private pure
        returns (ITeeOracleInstructionsSender.EndpointGroup[] memory _groups)
    {
        _groups = new ITeeOracleInstructionsSender.EndpointGroup[](_groupCount);
        for (uint256 i = 0; i < _groupCount; i++) {
            ITeeOracleInstructionsSender.Endpoint[] memory endpoints =
                new ITeeOracleInstructionsSender.Endpoint[](_endpointCount);
            for (uint256 j = 0; j < _endpointCount; j++) {
                endpoints[j] = ITeeOracleInstructionsSender.Endpoint({
                    kind: ITeeOracleInstructionsSender.EndpointKind.PUBLIC,
                    url: string.concat("https://rpc", vm.toString(j), ".example.com/{secret}"),
                    urlHash: bytes32(0),
                    secretRef: string.concat("api_key_", vm.toString(j))
                });
            }
            _groups[i] = ITeeOracleInstructionsSender.EndpointGroup({
                group: bytes32(uint256(i + 1)),
                threshold: uint64(_endpointCount),
                endpoints: endpoints
            });
        }
    }

    function _makeRoles(
        uint256 _roleCount,
        uint256 _adminCount
    )
        private pure
        returns (ITeeOracleInstructionsSender.AdminRole[] memory _roles)
    {
        _roles = new ITeeOracleInstructionsSender.AdminRole[](_roleCount);
        for (uint256 i = 0; i < _roleCount; i++) {
            address[] memory admins = new address[](_adminCount);
            for (uint256 j = 0; j < _adminCount; j++) {
                admins[j] = address(uint160(0x1000 * (i + 1) + j + 1));
            }
            _roles[i] = ITeeOracleInstructionsSender.AdminRole({
                role: bytes32(uint256(i + 1)),
                threshold: uint64(_adminCount),
                admins: admins
            });
        }
    }

    function _mockSendInstructions() private {
        vm.mockCall(
            flareTeeManager,
            abi.encodeWithSelector(IInstructions.sendInstructions.selector),
            abi.encode(INSTRUCTION_ID)
        );
    }

    function _mockGetRandomTeeIds(address[] memory _teeIds) private {
        vm.mockCall(
            flareTeeManager,
            abi.encodeWithSelector(IMachineManager.getRandomTeeIds.selector, EXTENSION_ID, 1),
            abi.encode(_teeIds)
        );
    }

    function _mockGetExtensionId(address _teeId, uint256 _extensionId) private {
        vm.mockCall(
            flareTeeManager,
            abi.encodeWithSelector(IMachineManager.getExtensionId.selector, _teeId),
            abi.encode(_extensionId)
        );
    }

    function _switchToProduction() private {
        vm.prank(governance);
        sender.switchToProductionMode();
        vm.mockCall(
            address(governanceSettings),
            abi.encodeWithSelector(IGovernanceSettings.getGovernanceAddress.selector),
            abi.encode(productionGovernance)
        );
        vm.mockCall(
            address(governanceSettings),
            abi.encodeWithSelector(IGovernanceSettings.getTimelock.selector),
            abi.encode(TIMELOCK)
        );
        vm.mockCall(
            address(governanceSettings),
            abi.encodeWithSelector(IGovernanceSettings.isExecutor.selector, executor),
            abi.encode(true)
        );
    }
}
