// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../../../../contracts/tee/implementation/TeeReplication.sol";
import "../../../../contracts/tee/proxy/TeeReplicationProxy.sol";

// solhint-disable-next-line max-states-count
contract TeeReplicationTest is Test {

    TeeReplication private teeReplication;
    TeeReplication private teeReplicationImpl;
    TeeReplicationProxy private teeReplicationProxy;

    address private initialGovernance;
    address private addressUpdater;
    address private teeMachineRegistry;
    address private teeExtensionRegistry;
    address private teeVersionManager;
    address private teeVerification;

    address private owner;
    uint256 private extensionId;

    address private teeId;
    address[] private teeIds;
    address private newTeeId;
    uint256 private teeUpgradeId;
    string private url;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    function setUp() public {
        teeId = makeAddr("teeId");
        teeIds = new address[](1);
        teeIds[0] = teeId;
        newTeeId = makeAddr("newTeeId");
        teeUpgradeId = 1;
        url = "url";

        owner = makeAddr("owner");

        initialGovernance = makeAddr("initialGovernance");
        addressUpdater = makeAddr("addressUpdater");

        teeReplicationImpl = new TeeReplication();
        teeReplicationProxy = new TeeReplicationProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            initialGovernance,
            addressUpdater,
            1 minutes, // pauseBeforeUpgradeMinDurationSeconds
            address(teeReplicationImpl)
        );
        teeReplication = TeeReplication(address(teeReplicationProxy));

        contractNameHashes = new bytes32[](5);
        contractAddresses = new address[](5);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("TeeExtensionRegistry"));
        contractNameHashes[2] = keccak256(abi.encode("TeeVersionManager"));
        contractNameHashes[3] = keccak256(abi.encode("TeeMachineRegistry"));
        contractNameHashes[4] = keccak256(abi.encode("TeeVerification"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = makeAddr("TeeExtensionRegistry");
        contractAddresses[2] = makeAddr("TeeVersionManager");
        contractAddresses[3] = makeAddr("TeeMachineRegistry");
        contractAddresses[4] = makeAddr("TeeVerification");

        vm.prank(addressUpdater);
        teeReplication.updateContractAddresses(contractNameHashes, contractAddresses);

        teeExtensionRegistry = address(teeReplication.teeExtensionRegistry());
        teeVersionManager = address(teeReplication.teeVersionManager());
        teeMachineRegistry = address(teeReplication.teeMachineRegistry());
        teeVerification = address(teeReplication.teeVerification());

        _mockGetTeeMachineOwner(teeId, owner);
        _mockGetTeeMachineOwner(newTeeId, owner);
        _mockGetExtensionId(teeId, extensionId);
        _mockGetExtensionId(newTeeId, extensionId);
        _mockIsCodeHashPlatformSupported(extensionId, true);
        _mockGetTeeMachineWithAttestationData(teeId);
        _mockGetTeeMachineWithAttestationData(newTeeId);
        _mockIsTeeUpgradePathValid(true);
        _mockIsTeeUpgradeSigned(true);
        _mockVerifyAvailabilityCheckProof(true);
        _mockGetLastStatusChangeTs(teeId);
        _mockGetLastStatusChangeTs(newTeeId);

        vm.mockCall(
            teeMachineRegistry,
            abi.encodeWithSelector(
                IITeeMachineRegistry.changeStatus.selector,
                teeId,
                ITeeMachineRegistry.TeeStatus.PAUSED_FOR_UPGRADE
            ),
            abi.encode(0)
        );

        vm.mockCall(
            teeExtensionRegistry,
            abi.encodeWithSelector(
                ITeeExtensionRegistry.sendInstructions.selector
            ),
            abi.encode(0)
        );

        vm.mockCall(
            teeMachineRegistry,
            abi.encodeWithSelector(
                IITeeMachineRegistry.replicate.selector
            ),
            abi.encode(0)
        );
    }


    // toPauseForUpgrade
    function testToPauseForUpgradeRevertOnlyOwner() public {
        vm.expectRevert(ITeeReplication.OnlyMachineOwner.selector);
        teeReplication.toPauseForUpgrade(teeId);
    }


    function testToPauseForUpgradeRevertInvalidTeeStatus() public {
        vm.startPrank(owner);
        vm.expectRevert(ITeeReplication.InvalidTeeStatus.selector);
        _mockGetTeeMachineStatus(teeId, ITeeMachineRegistry.TeeStatus.INITIALIZED);
        teeReplication.toPauseForUpgrade(teeId);
    }


    function testToPauseForUpgradeRevertTooSoon() public {
        _mockGetTeeMachineStatus(teeId, ITeeMachineRegistry.TeeStatus.PAUSED);
        _mockGetLastStatusChangeTs(0);
        vm.prank(owner);
        vm.expectRevert(ITeeReplication.TooSoon.selector);
        teeReplication.toPauseForUpgrade(teeId);
    }


    function testToPauseForUpgrade() public {
        _mockGetTeeMachineStatus(teeId, ITeeMachineRegistry.TeeStatus.PAUSED);
        vm.prank(owner);
        vm.expectEmit();
        emit ITeeReplication.TeeMachinePausedForUpgrade(teeId);
        vm.warp(1 days);
        teeReplication.toPauseForUpgrade(teeId);
    }


    // replicateFrom
    function testReplicateFromRevertOnlyMachineOwner() public {
        ITeeAvailabilityCheck.Proof memory proof = _createAvailabilityCheckProof(newTeeId, url);
        vm.expectRevert(ITeeReplication.OnlyMachineOwner.selector);
        teeReplication.replicateFrom(teeId, proof, teeUpgradeId);

        _mockGetTeeMachineOwner(newTeeId, address(this));
        vm.expectRevert(ITeeReplication.OnlyMachineOwner.selector);
        teeReplication.replicateFrom(teeId, proof, teeUpgradeId);
    }


    function testReplicateFromRevertInvalidTeeStatus() public {
        ITeeAvailabilityCheck.Proof memory proof = _createAvailabilityCheckProof(newTeeId, url);
        _mockGetTeeMachineStatus(teeId, ITeeMachineRegistry.TeeStatus.INITIALIZED);
        vm.expectRevert(ITeeMachineRegistry.InvalidTeeStatus.selector);
        vm.prank(owner);
        teeReplication.replicateFrom(teeId, proof, teeUpgradeId);

        _mockGetTeeMachineStatus(teeId, ITeeMachineRegistry.TeeStatus.PAUSED_FOR_UPGRADE);
        _mockGetTeeMachineStatus(newTeeId, ITeeMachineRegistry.TeeStatus.PRODUCTION);
        vm.expectRevert(ITeeMachineRegistry.InvalidTeeStatus.selector);
        vm.prank(owner);
        teeReplication.replicateFrom(teeId, proof, teeUpgradeId);
    }


    function testReplicateFromRevertExtensionMismatch() public {
        ITeeAvailabilityCheck.Proof memory proof = _createAvailabilityCheckProof(newTeeId, url);
        testReplicateFromRevertInvalidTeeStatus();
        _mockGetTeeMachineStatus(newTeeId, ITeeMachineRegistry.TeeStatus.INITIALIZED);
        _mockGetExtensionId(newTeeId, extensionId + 1);
        vm.expectRevert(ITeeReplication.ExtensionMismatch.selector);
        vm.prank(owner);
        teeReplication.replicateFrom(teeId, proof, teeUpgradeId);
    }


    function testReplicateFromRevertVersionNotSupported() public {
        ITeeAvailabilityCheck.Proof memory proof = _setupReplicateFrom();
        _mockIsCodeHashPlatformSupported(extensionId, false);
        vm.expectRevert(ITeeReplication.VersionNotSupported.selector);
        vm.prank(owner);
        teeReplication.replicateFrom(teeId, proof, teeUpgradeId);
    }


    function testReplicateFromRevertInvalidUpgradePath() public {
        ITeeAvailabilityCheck.Proof memory proof = _setupReplicateFrom();
        _mockIsTeeUpgradePathValid(false);
        vm.expectRevert(ITeeReplication.InvalidUpgradePath.selector);
        vm.prank(owner);
        teeReplication.replicateFrom(teeId, proof, teeUpgradeId);
    }


    function testReplicateFromRevertTeeUpgradeNotSigned() public {
        ITeeAvailabilityCheck.Proof memory proof = _setupReplicateFrom();
        _mockIsTeeUpgradeSigned(false);
        vm.expectRevert(ITeeReplication.TeeUpgradeNotSigned.selector);
        vm.prank(owner);
        teeReplication.replicateFrom(teeId, proof, teeUpgradeId);
    }


    function testReplicateFromRevertInvalidAvailabilityCheckStatus() public {
        ITeeAvailabilityCheck.Proof memory proof = _setupReplicateFrom();
        proof.responseBody.status = ITeeAvailabilityCheck.AvailabilityCheckStatus.DOWN;
        vm.expectRevert(ITeeReplication.InvalidAvailabilityCheckStatus.selector);
        vm.prank(owner);
        teeReplication.replicateFrom(teeId, proof, teeUpgradeId);
    }


    function testReplicateFromRevertAvailabilityCheckTimestampInvalid() public {
        ITeeAvailabilityCheck.Proof memory proof = _setupReplicateFrom();
        proof.header.timestamp = 0;
        vm.expectRevert(ITeeReplication.AvailabilityCheckTimestampInvalid.selector);
        vm.prank(owner);
        teeReplication.replicateFrom(teeId, proof, teeUpgradeId);
    }

    function testReplicateFromRevertInvalidResponseData() public {
        ITeeAvailabilityCheck.Proof memory proof = _setupReplicateFrom();
        _mockVerifyAvailabilityCheckProof(false);
        vm.expectRevert(ITeeReplication.InvalidResponseData.selector);
        vm.prank(owner);
        teeReplication.replicateFrom(teeId, proof, teeUpgradeId);
    }


    function testReplicateFrom() public {
        ITeeAvailabilityCheck.Proof memory proof = _setupReplicateFrom();
        vm.expectEmit();
        emit ITeeReplication.TeeMachineReplicationTriggered(teeId, newTeeId, teeUpgradeId);
        vm.prank(owner);
        teeReplication.replicateFrom(teeId, proof, teeUpgradeId);
    }


    // confirmReplicate
    function testConfirmReplicateRevertOnlyMachineOwner() public {
        ITeeAvailabilityCheck.Proof memory proof = _createAvailabilityCheckProof(teeId, url);
        vm.expectRevert(ITeeReplication.OnlyMachineOwner.selector);
        teeReplication.confirmReplicate(newTeeId, proof);

        _mockGetTeeMachineOwner(newTeeId, address(this));
        vm.expectRevert(ITeeReplication.OnlyMachineOwner.selector);
        vm.prank(owner);
        teeReplication.confirmReplicate(newTeeId, proof);
    }


    function testConfirmReplicateRevertReplicationNotValid() public {
        ITeeAvailabilityCheck.Proof memory proof = _createAvailabilityCheckProof(teeId, url);
        vm.expectRevert(ITeeReplication.ReplicationNotValid.selector);
        vm.prank(owner);
        teeReplication.confirmReplicate(newTeeId, proof);
    }


    function testConfirmReplicate() public {
        testReplicateFrom();
        ITeeAvailabilityCheck.Proof memory proof = _createAvailabilityCheckProof(teeId, url);
        vm.expectEmit();
        emit ITeeReplication.TeeMachineReplicationConfirmed(teeId, newTeeId);
        vm.prank(owner);
        teeReplication.confirmReplicate(newTeeId, proof);
    }


    // setPauseBeforeUpgradeMinDurationSeconds
    function testSetPauseBeforeUpgradeMinDurationSecondsRevertOnlyGovernance() public {
        vm.expectRevert("only governance");
        teeReplication.setPauseBeforeUpgradeMinDurationSeconds(1 days);
    }


    function testSetPauseBeforeUpgradeMinDurationSecondsRevertInvalidDuration() public {
        vm.prank(initialGovernance);
        vm.expectRevert(ITeeReplication.InvalidDuration.selector);
        teeReplication.setPauseBeforeUpgradeMinDurationSeconds(2 days);
    }


    function testSetPauseBeforeUpgradeMinDurationSeconds() public {
        vm.expectEmit();
        emit ITeeReplication.PauseBeforeUpgradeMinDurationSecondsSet(1 days);
        vm.prank(initialGovernance);
        teeReplication.setPauseBeforeUpgradeMinDurationSeconds(1 days);
    }


    // getReplicatingTeeId
    function testGetReplicatingTeeId() public {
        testReplicateFrom();
        assertEq(teeReplication.getReplicatingTeeId(teeId), newTeeId);
    }


    function _mockGetTeeMachineStatus(
        address _teeId,
        ITeeMachineRegistry.TeeStatus _status
    )
        private
    {
        vm.mockCall(
            teeMachineRegistry,
            abi.encodeWithSelector(
                ITeeMachineRegistry.getTeeMachineStatus.selector,
                _teeId
            ),
            abi.encode(_status)
        );
    }


    function _mockGetLastStatusChangeTs(uint256 _ts) private {
        vm.mockCall(
            teeMachineRegistry,
            abi.encodeWithSelector(
                ITeeMachineRegistry.getLastStatusChangeTs.selector,
                teeId
            ),
            abi.encode(_ts)
        );
    }


    function _mockGetTeeMachineOwner(
        address __teeId,
        address _owner
    )
        private
    {
        vm.mockCall(
            teeMachineRegistry,
            abi.encodeWithSelector(
                ITeeMachineRegistry.getTeeMachineOwner.selector,
                __teeId
            ),
            abi.encode(_owner)
        );
    }


    function _mockGetExtensionId(
        address _teeId,
        uint256 _extensionId
    )
        private
    {
        vm.mockCall(
            teeMachineRegistry,
            abi.encodeWithSelector(
                ITeeMachineRegistry.getExtensionId.selector,
                _teeId
            ),
            abi.encode(_extensionId)
        );
    }


    function _mockIsCodeHashPlatformSupported(
        uint256 _extensionId,
        bool _isSupported
    )
        private
    {
        vm.mockCall(
            teeExtensionRegistry,
            abi.encodeWithSelector(
                ITeeExtensionRegistry.isCodeHashPlatformSupported.selector,
                _extensionId
            ),
            abi.encode(_isSupported)
        );
    }


    function _mockGetTeeMachineWithAttestationData(address _teeId) private {
        vm.mockCall(
            teeMachineRegistry,
            abi.encodeWithSelector(
                ITeeMachineRegistry.getTeeMachineWithAttestationData.selector,
                _teeId
            ),
            abi.encode(
                ITeeMachineRegistry.TeeMachineWithAttestationData(
                    _teeId, _teeId, url, keccak256("codeHash"), keccak256("platform")
                )
            )
        );
    }


    function _mockIsTeeUpgradePathValid(bool _isValid) private {
        vm.mockCall(
            teeVersionManager,
            abi.encodeWithSelector(
                ITeeVersionManager.isTeeUpgradePathValid.selector,
                teeUpgradeId
            ),
            abi.encode(_isValid)
        );
    }


    function _mockIsTeeUpgradeSigned(bool _isSigned) private {
        vm.mockCall(
            teeVersionManager,
            abi.encodeWithSelector(
                ITeeVersionManager.isTeeUpgradeSigned.selector,
                teeUpgradeId
            ),
            abi.encode(_isSigned)
        );
    }


    function _mockVerifyAvailabilityCheckProof(bool _isValid) private {
        vm.mockCall(
            teeVerification,
            abi.encodeWithSelector(
                ITeeVerification.verifyAvailabilityCheckProof.selector
            ),
            abi.encode(_isValid)
        );
    }


    function _mockGetLastStatusChangeTs(address _teeId) private {
        vm.mockCall(
            teeMachineRegistry,
            abi.encodeWithSelector(
                ITeeMachineRegistry.getLastStatusChangeTs.selector,
                _teeId
            ),
            abi.encode(1)
        );
    }


    function _setupReplicateFrom() private returns (ITeeAvailabilityCheck.Proof memory) {
        _mockGetTeeMachineStatus(teeId, ITeeMachineRegistry.TeeStatus.PAUSED_FOR_UPGRADE);
        _mockGetTeeMachineStatus(newTeeId, ITeeMachineRegistry.TeeStatus.INITIALIZED);
        return _createAvailabilityCheckProof(newTeeId, url);
    }


    function _createAvailabilityCheckProof(
        address _teeId,
        string memory _url
    )
        private pure
        returns (ITeeAvailabilityCheck.Proof memory)
    {
        IFtdcVerification.FtdcSignatures memory sigs;
        IFtdcHub.FtdcResponseHeader memory header;
        header.timestamp = 1;
        ITeeAvailabilityCheck.RequestBody memory reqBody = ITeeAvailabilityCheck.RequestBody(
            _teeId,
            _url,
            keccak256("challenge")
        );
        ITeeAvailabilityCheck.ResponseBody memory repBody = ITeeAvailabilityCheck.ResponseBody(
            ITeeAvailabilityCheck.AvailabilityCheckStatus.OK,
            header.timestamp,
            keccak256("codeHash"),
            keccak256("platform"),
            0,
            0,
            ITeeAvailabilityCheck.TeeState(new bytes(0), 0, new bytes(0), 0)
        );

        return ITeeAvailabilityCheck.Proof(
            sigs,
            header,
            reqBody,
            repBody
        );
    }
}