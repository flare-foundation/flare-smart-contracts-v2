// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../../../../contracts/tee/implementation/TeeMachineRegistry.sol";
import "../../../../contracts/tee/proxy/TeeMachineRegistryProxy.sol";

contract TeeMachineRegistryTest is Test {

    TeeMachineRegistry private teeMachineRegistry;
    TeeMachineRegistry private teeMachineRegistryImpl;
    TeeMachineRegistryProxy private teeMachineRegistryProxy;

    address private owner;
    address private invalidOwner;

    address private initialGovernance;
    address private addressUpdater;
    address private teeExtensionRegistry;
    address private teeOwnerAllowlist;
    address private teeVerification;
    address private teeReplication;
    address private relay;

    uint256 private extensionId;
    address private teeId;
    address private teeProxyId;
    string private url;
    bytes32 private codeHash;
    bytes32 private platform;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    address private newTeeId;

    function setUp() public {
        owner = makeAddr("owner");
        invalidOwner = makeAddr("invalidOwner");

        initialGovernance = makeAddr("initialGovernance");
        addressUpdater = makeAddr("addressUpdater");

        extensionId = 1;
        teeId = makeAddr("teeId");
        url = "url";
        codeHash = keccak256("codeHash");
        platform = keccak256("platform");

        teeMachineRegistryImpl = new TeeMachineRegistry();
        teeMachineRegistryProxy = new TeeMachineRegistryProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            initialGovernance,
            addressUpdater,
            address(teeMachineRegistryImpl)
        );
        teeMachineRegistry = TeeMachineRegistry(address(teeMachineRegistryProxy));

        teeProxyId = address(teeMachineRegistryProxy);

        contractNameHashes = new bytes32[](6);
        contractAddresses = new address[](6);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("TeeExtensionRegistry"));
        contractNameHashes[2] = keccak256(abi.encode("TeeOwnerAllowlist"));
        contractNameHashes[3] = keccak256(abi.encode("TeeVerification"));
        contractNameHashes[4] = keccak256(abi.encode("TeeReplication"));
        contractNameHashes[5] = keccak256(abi.encode("Relay"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = makeAddr("TeeExtensionRegistry");
        contractAddresses[2] = makeAddr("TeeOwnerAllowlist");
        contractAddresses[3] = makeAddr("TeeVerification");
        contractAddresses[4] = makeAddr("TeeReplication");
        contractAddresses[5] = makeAddr("Relay");

        vm.prank(addressUpdater);
        teeMachineRegistry.updateContractAddresses(contractNameHashes, contractAddresses);

        teeExtensionRegistry = address(teeMachineRegistry.teeExtensionRegistry());
        teeOwnerAllowlist = address(teeMachineRegistry.teeOwnerAllowlist());
        teeVerification = address(teeMachineRegistry.teeVerification());
        teeReplication = address(teeMachineRegistry.teeReplication());
        relay = address(teeMachineRegistry.relay());

        newTeeId = makeAddr("newTeeId");

        _mockIsAllowedTeeMachineOwner(extensionId);
        _mockIsAllowedTeeMachineOwner(extensionId + 1);
        _mockIsCodeHashPlatformSupported(extensionId);
        _mockIsCodeHashPlatformSupported(extensionId + 1);

        vm.mockCall(
            teeVerification,
            abi.encodeWithSelector(
                ITeeVerification.requestTeeAttestation.selector,
                teeId
            ),
            ""
        );
    }


    // register
    function testRegisterRevertOwnerNotAllowed() public {
        _mockIsAllowedTeeMachineOwner(false);
        vm.expectRevert(ITeeMachineRegistry.OwnerNotAllowed.selector);
        teeMachineRegistry.register(extensionId, teeId, teeProxyId, url, codeHash, platform);
    }


    function testRegisterRevertInvalidTeeId() public {
        vm.expectRevert(ITeeMachineRegistry.InvalidTeeId.selector);
        vm.prank(owner);
        teeMachineRegistry.register(extensionId, address(0), teeProxyId, url, codeHash, platform);
    }


    function testRegisterRevertInvalidTeeProxyId() public {
        vm.expectRevert(ITeeMachineRegistry.InvalidTeeProxyId.selector);
        vm.prank(owner);
        teeMachineRegistry.register(extensionId, teeId, address(0), url, codeHash, platform);
    }


    function testRegisterRevertInvalidUrl() public {
        vm.expectRevert(ITeeMachineRegistry.InvalidUrl.selector);
        vm.prank(owner);
        teeMachineRegistry.register(extensionId, teeId, teeProxyId, "", codeHash, platform);
    }


    function testRegisterRevertAlreadyRegistered() public {
        vm.startPrank(owner);
        teeMachineRegistry.register(extensionId, teeId, teeProxyId, url, codeHash, platform);
        vm.expectRevert(ITeeMachineRegistry.AlreadyRegistered.selector);
        teeMachineRegistry.register(extensionId, teeId, teeProxyId, url, codeHash, platform);
        vm.stopPrank();
    }


    function testRegisterRevertVersionNotSupported() public {
        _mockIsCodeHashPlatformSupported(false);
        vm.expectRevert(ITeeMachineRegistry.VersionNotSupported.selector);
        vm.prank(owner);
        teeMachineRegistry.register(extensionId, teeId, teeProxyId, url, codeHash, platform);
    }


    function testRegister() public {
        vm.expectEmit();
        vm.prank(owner);
        emit ITeeMachineRegistry.TeeMachineRegistered(teeId, teeProxyId, owner, extensionId, url, codeHash, platform);
        teeMachineRegistry.register(extensionId, teeId, teeProxyId, url, codeHash, platform);
    }


    // toProduction
    function testToProductionRevertInvalidTeeStatus() public {
        testRegister();
        ITeeAvailabilityCheck.Proof memory proof = _createAvailabilityCheckProof(teeId, url);
        vm.expectRevert(ITeeMachineRegistry.InvalidTeeStatus.selector);
        teeMachineRegistry.toProduction(proof);
    }


    function testToProductionRevertVersionNotSupported() public {
        testRegister();
        _mockIsCodeHashPlatformSupported(false);
        ITeeAvailabilityCheck.Proof memory proof = _createAvailabilityCheckProof(teeId, url);
        vm.prank(owner);
        vm.expectRevert(ITeeMachineRegistry.VersionNotSupported.selector);
        teeMachineRegistry.toProduction(proof);
    }


    function testToProductionRevertInvalidAvailabilityCheckStatus() public {
        testRegister();
        ITeeAvailabilityCheck.Proof memory proof = _createAvailabilityCheckProof(teeId, url);
        proof.responseBody.status = ITeeAvailabilityCheck.AvailabilityCheckStatus.DOWN;
        vm.prank(owner);
        vm.expectRevert(ITeeMachineRegistry.InvalidAvailabilityCheckStatus.selector);
        teeMachineRegistry.toProduction(proof);
    }


    function testToProductionRevertAcTimestampInvalid() public {
        testRegister();
        ITeeAvailabilityCheck.Proof memory proof = _createAvailabilityCheckProof(teeId, url);
        proof.header.timestamp = 0;
        vm.prank(owner);
        vm.expectRevert(ITeeMachineRegistry.AcTimestampInvalid.selector);
        teeMachineRegistry.toProduction(proof);
    }


    function testToProductionRevertInvalidResponseData() public {
        testRegister();
        ITeeAvailabilityCheck.Proof memory proof = _createAvailabilityCheckProof(teeId, url);
        _mockVerifyAvailabilityCheckProof(false);
        vm.prank(owner);
        vm.expectRevert(ITeeMachineRegistry.InvalidResponseData.selector);
        teeMachineRegistry.toProduction(proof);
    }


    function testToProduction() public {
        testRegister();
        _changeStateToProduction();
    }


    // pause
    function testPauseRevertInvalidTeeStatus() public {
        vm.expectRevert(ITeeMachineRegistry.InvalidTeeStatus.selector);
        teeMachineRegistry.pause(teeId);
    }


    function testPauseRevertOnlyOwnerOrDisabledVersion() public {
        testToProduction();
        _mockCodeHashPlatformDisabledFalse();
        vm.expectRevert(ITeeMachineRegistry.OnlyOwnerOrDisabledVersion.selector);
        teeMachineRegistry.pause(teeId);
    }


    function testPause() public {
        testToProduction();
        vm.prank(owner);
        vm.expectEmit();
        emit ITeeMachineRegistry.TeeMachinePaused(teeId, false);
        teeMachineRegistry.pause(teeId);
    }


    // pauseWithProof
    function testPauseWithProofRevertInvalidTeeStatus() public {
        testRegister();
        ITeeAvailabilityCheck.Proof memory proof = _createAvailabilityCheckProof(teeId, url);
        vm.expectRevert(ITeeMachineRegistry.InvalidTeeStatus.selector);
        teeMachineRegistry.pauseWithProof(proof);
    }


    function testPauseWithProofRevertInvalidResponseDataOrAvailabilityCheckStatus() public {
        testToProduction();
        ITeeAvailabilityCheck.Proof memory proof = _createAvailabilityCheckProof(teeId, url);
        vm.expectRevert(ITeeMachineRegistry.InvalidResponseDataOrAvailabilityCheckStatus.selector);
        teeMachineRegistry.pauseWithProof(proof);
    }


    function testPauseWithProofRevertAcTimestampInvalid() public {
        testToProduction();
        ITeeAvailabilityCheck.Proof memory proof = _createAvailabilityCheckProof(teeId, url);
        proof.header.timestamp = 0;
        _mockVerifyAvailabilityCheckProofFalse(proof);
        vm.expectRevert(ITeeMachineRegistry.AcTimestampInvalid.selector);
        teeMachineRegistry.pauseWithProof(proof);
    }


    function testPauseWithProof() public {
        testToProduction();
        ITeeAvailabilityCheck.Proof memory proof = _createAvailabilityCheckProof(teeId, url);
        _mockVerifyAvailabilityCheckProofFalse(proof);
        vm.expectEmit();
        emit ITeeMachineRegistry.TeeMachinePaused(teeId, true);
        teeMachineRegistry.pauseWithProof(proof);
    }


    // proposeNewOwner
    function testProposeNewOwnerRevertOnlyOwner() public {
        vm.expectRevert(ITeeMachineRegistry.OnlyOwner.selector);
        teeMachineRegistry.proposeNewOwner(teeId, address(0));
    }


    function testProposeNewOwnerRevertOwnerNotAllowed() public {
        testRegister();
        _mockIsAllowedTeeMachineOwner(false);
        vm.prank(owner);
        vm.expectRevert(ITeeMachineRegistry.OwnerNotAllowed.selector);
        teeMachineRegistry.proposeNewOwner(teeId, invalidOwner);
    }


    function testProposeNewOwner() public {
        testRegister();
        vm.prank(owner);
        vm.expectEmit();
        emit ITeeMachineRegistry.NewOwnerProposed(teeId, owner, invalidOwner);
        _mockInvalidOwnerIsAllowedTeeMachineOwner();
        teeMachineRegistry.proposeNewOwner(teeId, invalidOwner);
    }


    // confirmOwnership
    function testConfirmOwnershipRevertOwnerNotAllowed() public {
        testRegister();
        vm.prank(owner);
        teeMachineRegistry.proposeNewOwner(teeId, address(0));
        _mockIsAllowedTeeMachineOwner(false);
        vm.expectRevert(ITeeMachineRegistry.OwnerNotAllowed.selector);
        teeMachineRegistry.confirmOwnership(teeId);
    }


    function testConfirmOwnershipRevertOnlyProposedOwner() public {
        testProposeNewOwner();
        vm.expectRevert(ITeeMachineRegistry.OnlyProposedOwner.selector);
        _mockIsAllowedTeeMachineOwner(true);
        teeMachineRegistry.confirmOwnership(teeId);
    }


    function testConfirmOwnership() public {
        testProposeNewOwner();
        vm.prank(invalidOwner);
        vm.expectEmit();
        emit ITeeMachineRegistry.NewOwnerConfirmed(teeId, invalidOwner);
        teeMachineRegistry.confirmOwnership(teeId);
    }


    // setTeeProxyId
    function testSetTeeProxyIdRevertOnlyOwner() public {
        vm.expectRevert(ITeeMachineRegistry.OnlyOwner.selector);
        teeMachineRegistry.setTeeProxyId(teeId, address(0));
    }


    function testSetTeeProxyIdRevertInvalidTeeProxyId() public {
        testRegister();
        vm.expectRevert(ITeeMachineRegistry.InvalidTeeProxyId.selector);
        vm.prank(owner);
        teeMachineRegistry.setTeeProxyId(teeId, address(0));
    }


    function testSetTeeProxyId() public {
        address newTeeProxyId = makeAddr("newTeeProxyId");
        testRegister();
        vm.prank(owner);
        vm.expectEmit();
        emit ITeeMachineRegistry.TeeProxyIdSet(teeId, newTeeProxyId);
        teeMachineRegistry.setTeeProxyId(teeId, newTeeProxyId);
    }


    // changeStatus
    function testChangeStatusRevertOnlyTeeReplicationContract() public {
        vm.expectRevert(ITeeMachineRegistry.OnlyTeeReplicationContract.selector);
        teeMachineRegistry.changeStatus(teeId, ITeeMachineRegistry.TeeStatus.INITIALIZED);
    }


    function testChangeStatusRevertTeeNotFound() public {
        vm.prank(teeReplication);
        vm.expectRevert(ITeeMachineRegistry.TeeNotFound.selector);
        teeMachineRegistry.changeStatus(teeId, ITeeMachineRegistry.TeeStatus.INITIALIZED);
    }


    function testChangeStatusRevertInvalidTeeStatus() public {
        testToProduction();
        vm.startPrank(teeReplication);
        vm.expectRevert(ITeeMachineRegistry.InvalidTeeStatus.selector);
        teeMachineRegistry.changeStatus(teeId, ITeeMachineRegistry.TeeStatus.REPLICATING);

        vm.expectRevert(ITeeMachineRegistry.InvalidTeeStatus.selector);
        teeMachineRegistry.changeStatus(teeId, ITeeMachineRegistry.TeeStatus.PAUSED_FOR_UPGRADE);

        vm.expectRevert(ITeeMachineRegistry.InvalidNewStatus.selector);
        teeMachineRegistry.changeStatus(teeId, ITeeMachineRegistry.TeeStatus.INITIALIZED);

        vm.stopPrank();
    }


    // replicate
    function testReplicateRevertOnlyTeeReplicationContract() public {
        ITeeAvailabilityCheck.Proof memory proof = _createAvailabilityCheckProof(teeId, url);
        vm.expectRevert(ITeeMachineRegistry.OnlyTeeReplicationContract.selector);
        teeMachineRegistry.replicate(newTeeId, proof);
    }


    function testReplicateRevertTeeNotFound() public {
        ITeeAvailabilityCheck.Proof memory proof = _createAvailabilityCheckProof(teeId, url);
        vm.prank(teeReplication);
        vm.expectRevert(ITeeMachineRegistry.TeeNotFound.selector);
        teeMachineRegistry.replicate(newTeeId, proof);

        testRegister();
        vm.expectRevert(ITeeMachineRegistry.TeeNotFound.selector);
        vm.prank(teeReplication);
        teeMachineRegistry.replicate(newTeeId, proof);
    }


    function testReplicateRevertInvalidTeeStatus() public {
        ITeeAvailabilityCheck.Proof memory proof = _createAvailabilityCheckProof(teeId, url);
        testToProduction();
        vm.prank(owner);
        teeMachineRegistry.register(extensionId, newTeeId, teeProxyId, url, codeHash, platform);
        vm.expectRevert(ITeeMachineRegistry.InvalidTeeStatus.selector);
        vm.prank(teeReplication);
        teeMachineRegistry.replicate(newTeeId, proof);

        vm.prank(owner);
        teeMachineRegistry.pause(teeId);
        vm.prank(teeReplication);
        teeMachineRegistry.changeStatus(teeId, ITeeMachineRegistry.TeeStatus.PAUSED_FOR_UPGRADE);
        vm.expectRevert(ITeeMachineRegistry.InvalidTeeStatus.selector);
        vm.prank(teeReplication);
        teeMachineRegistry.replicate(newTeeId, proof);
    }


    function testReplicateRevertOwnerMismatch() public {
        _mockInvalidOwnerIsAllowedTeeMachineOwner();
        ITeeAvailabilityCheck.Proof memory proof = _setupReplicate();

        // change the owner of teeId to invalidOwner
        vm.prank(owner);
        teeMachineRegistry.proposeNewOwner(teeId, invalidOwner);
        vm.prank(invalidOwner);
        teeMachineRegistry.confirmOwnership(teeId);

        vm.expectRevert(ITeeMachineRegistry.OwnerMismatch.selector);
        vm.prank(teeReplication);
        teeMachineRegistry.replicate(newTeeId, proof);
    }


    function testReplicateRevertExtensionIdMismatch() public {
        ITeeAvailabilityCheck.Proof memory proof = _createAvailabilityCheckProof(teeId, url);
        testToProduction();
        vm.prank(owner);
        teeMachineRegistry.register(extensionId + 1, newTeeId, teeProxyId, url, codeHash, platform);

        vm.prank(owner);
        teeMachineRegistry.pause(teeId);
        vm.prank(teeReplication);
        teeMachineRegistry.changeStatus(teeId, ITeeMachineRegistry.TeeStatus.PAUSED_FOR_UPGRADE);

        vm.prank(teeReplication);
        teeMachineRegistry.changeStatus(newTeeId, ITeeMachineRegistry.TeeStatus.REPLICATING);

        vm.prank(teeReplication);
        vm.expectRevert(ITeeMachineRegistry.ExtensionIdMismatch.selector);
        teeMachineRegistry.replicate(newTeeId, proof);
    }


    function testReplicateRevertVersionNotSupported() public {
        ITeeAvailabilityCheck.Proof memory proof = _setupReplicate();
        _mockIsCodeHashPlatformSupported(false);
        vm.expectRevert(ITeeMachineRegistry.VersionNotSupported.selector);
        vm.prank(teeReplication);
        teeMachineRegistry.replicate(newTeeId, proof);
    }


    function testReplicateRevertInvalidAvailabilityCheckStatus() public {
        ITeeAvailabilityCheck.Proof memory proof = _setupReplicate();
        proof.responseBody.status = ITeeAvailabilityCheck.AvailabilityCheckStatus.DOWN;
        vm.prank(teeReplication);
        vm.expectRevert(ITeeMachineRegistry.InvalidAvailabilityCheckStatus.selector);
        teeMachineRegistry.replicate(newTeeId, proof);
    }


    function testReplicateRevertAcTimestampInvalid() public {
        ITeeAvailabilityCheck.Proof memory proof = _setupReplicate();
        proof.header.timestamp = 0;
        vm.prank(teeReplication);
        vm.expectRevert(ITeeMachineRegistry.AcTimestampInvalid.selector);
        teeMachineRegistry.replicate(newTeeId, proof);
    }


    function testReplicateRevertInvalidResponseData() public {
        ITeeAvailabilityCheck.Proof memory proof = _setupReplicate();
        _mockVerifyAvailabilityCheckProof(false);
        vm.prank(teeReplication);
        vm.expectRevert(ITeeMachineRegistry.InvalidResponseData.selector);
        teeMachineRegistry.replicate(newTeeId, proof);
    }


    function testReplicate() public {
        ITeeAvailabilityCheck.Proof memory proof = _setupReplicate();
        _mockVerifyAvailabilityCheckProof(true);
        vm.prank(teeReplication);
        vm.expectEmit();
        emit ITeeMachineRegistry.TeeMachinePutIntoProduction(teeId);
        teeMachineRegistry.replicate(newTeeId, proof);
    }


    // getTeeMachineStatus
    function testGetTeeMachineStatusRevertTeeNotFound() public {
        vm.expectRevert(ITeeMachineRegistry.TeeNotFound.selector);
        teeMachineRegistry.getTeeMachineStatus(teeId);
    }


    function testGetTeeMachineStatus() public {
        testRegister();
        assertTrue(teeMachineRegistry.getTeeMachineStatus(teeId) == ITeeMachineRegistry.TeeStatus.INITIALIZED);
        _changeStateToProduction();
        assertTrue(teeMachineRegistry.getTeeMachineStatus(teeId) == ITeeMachineRegistry.TeeStatus.PRODUCTION);
    }


    // getTeeMachineOwner
    function testGetTeeMachineOwnerRevertTeeNotFound() public {
        vm.expectRevert(ITeeMachineRegistry.TeeNotFound.selector);
        teeMachineRegistry.getTeeMachineOwner(teeId);
    }


    function testGetTeeMachineOwner() public {
        testRegister();
        assertEq(teeMachineRegistry.getTeeMachineOwner(teeId), owner);
    }


    // getInitialSigningPolicyId
    function testGetInitialSigningPolicyIdRevertTeeNotFound() public {
        vm.expectRevert(ITeeMachineRegistry.TeeNotFound.selector);
        teeMachineRegistry.getInitialSigningPolicyId(teeId);
    }


    function testGetInitialSigningPolicyId() public {
        testRegister();
        assertEq(teeMachineRegistry.getInitialSigningPolicyId(teeId), 0);
    }


    // getTeeMachine
    function testGetTeeMachineRevertTeeNotFound() public {
        vm.expectRevert(ITeeMachineRegistry.TeeNotFound.selector);
        teeMachineRegistry.getTeeMachine(teeId);
    }


    function testGetTeeMachine() public {
        testRegister();
        ITeeMachineRegistry.TeeMachine memory teeMachine = teeMachineRegistry.getTeeMachine(teeId);
        assertEq(teeMachine.teeId, teeId);
        assertEq(teeMachine.teeProxyId, teeProxyId);
        assertEq(teeMachine.url, url);
    }


    // getTeeMachineWithAttestationData
    function testGetTeeMachineWithAttestationDataRevertTeeNotFound() public {
        vm.expectRevert(ITeeMachineRegistry.TeeNotFound.selector);
        teeMachineRegistry.getTeeMachineWithAttestationData(teeId);
    }


    function testGetTeeMachineWithAttestationData() public {
        testRegister();
        ITeeMachineRegistry.TeeMachineWithAttestationData memory teeMachineAttData =
            teeMachineRegistry.getTeeMachineWithAttestationData(teeId);
        assertEq(teeMachineAttData.teeId, teeId);
        assertEq(teeMachineAttData.initialTeeId, teeId);
        assertEq(teeMachineAttData.url, url);
        assertEq(teeMachineAttData.codeHash, codeHash);
        assertEq(teeMachineAttData.platform, platform);
    }


    // getRandomTeeIds
    function testGetRandomTeeIdsRevertTooMany() public {
        vm.expectRevert(ITeeMachineRegistry.TooMany.selector);
        teeMachineRegistry.getRandomTeeIds(extensionId, 1);
    }


    function testGetRandomTeeIds() public {
        testToProduction();
        ITeeAvailabilityCheck.Proof memory proof = _createAvailabilityCheckProof(newTeeId, url);
        vm.startPrank(owner);
        teeMachineRegistry.register(extensionId, newTeeId, teeProxyId, url, codeHash, platform);
        teeMachineRegistry.toProduction(proof);
        vm.stopPrank();

        _mockGetRandomNumber();
        address[] memory teeIds = teeMachineRegistry.getRandomTeeIds(extensionId, 1);
        assertEq(teeIds.length, 1);
        assertTrue(teeIds[0] == teeId || teeIds[0] == newTeeId);
    }


    // getAllActiveTeeMachines
    function testGetAllActiveTeeMachines() public {
        (address[] memory teeIds, string[] memory urls) = teeMachineRegistry.getAllActiveTeeMachines();
        assertEq(teeIds.length, 0);
        assertEq(urls.length, 0);

        testToProduction();
        (teeIds, urls) = teeMachineRegistry.getAllActiveTeeMachines();
        assertEq(teeIds.length, 1);
        assertEq(urls.length, 1);
        assertEq(teeIds[0], teeId);
        assertEq(urls[0], url);
    }


    // getActiveTeeMachines
    function testGetActiveTeeMachines() public {
        (address[] memory teeIds, string[] memory urls) = teeMachineRegistry.getActiveTeeMachines(extensionId);
        assertEq(teeIds.length, 0);
        assertEq(urls.length, 0);

        testToProduction();
        (teeIds, urls) = teeMachineRegistry.getActiveTeeMachines(extensionId);
        assertEq(teeIds.length, 1);
        assertEq(urls.length, 1);
        assertEq(teeIds[0], teeId);
        assertEq(urls[0], url);
    }


    // getExtensionId
    function testGetExtensionIdRevertTeeNotFound() public {
        vm.expectRevert(ITeeMachineRegistry.TeeNotFound.selector);
        teeMachineRegistry.getExtensionId(teeId);
    }


    function testGetExtensionId() public {
        testRegister();
        assertEq(teeMachineRegistry.getExtensionId(teeId), extensionId);
    }


    // getLastStatusChangeTs
    function testGetLastStatusChangeTsRevertTeeNotFound() public {
        vm.expectRevert(ITeeMachineRegistry.TeeNotFound.selector);
        teeMachineRegistry.getLastStatusChangeTs(teeId);
    }


    function testGetLastStatusChangeTs() public {
        testRegister();
        // 1 is foundry's default block.timestamp value
        assertEq(teeMachineRegistry.getLastStatusChangeTs(teeId), 1);
    }


    function _mockIsCodeHashPlatformSupported(bool _isSupported) private {
        vm.mockCall(
            teeExtensionRegistry,
            abi.encodeWithSelector(
                ITeeExtensionRegistry.isCodeHashPlatformSupported.selector,
                extensionId,
                codeHash,
                platform
            ),
            abi.encode(_isSupported)
        );
    }


    function _mockIsAllowedTeeMachineOwner(bool _isAllowed) private {
        vm.mockCall(
            teeOwnerAllowlist,
            abi.encodeWithSelector(
                ITeeOwnerAllowlist.isAllowedTeeMachineOwner.selector,
                extensionId
            ),
            abi.encode(_isAllowed)
        );
    }


    function _mockInvalidOwnerIsAllowedTeeMachineOwner() private {
        vm.mockCall(
            teeOwnerAllowlist,
            abi.encodeWithSelector(
                ITeeOwnerAllowlist.isAllowedTeeMachineOwner.selector,
                extensionId,
                invalidOwner
            ),
            abi.encode(true)
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


    function _mockGetRandomNumber() private {
        vm.mockCall(
            relay,
            abi.encodeWithSelector(
                RandomNumberV2Interface.getRandomNumber.selector
            ),
            abi.encode(teeId, false, uint256(0))
        );
    }


    function _changeStateToProduction() private {
        _mockIsCodeHashPlatformSupported(true);
        _mockVerifyAvailabilityCheckProof(true);
        ITeeAvailabilityCheck.Proof memory proof = _createAvailabilityCheckProof(teeId, url);
        vm.expectEmit();
        emit ITeeMachineRegistry.TeeMachinePutIntoProduction(teeId);
        vm.prank(owner);
        teeMachineRegistry.toProduction(proof);
    }


    function _mockCodeHashPlatformDisabledFalse() private {
        vm.mockCall(
            teeExtensionRegistry,
            abi.encodeWithSelector(
                ITeeExtensionRegistry.codeHashPlatformDisabled.selector,
                extensionId,
                codeHash,
                platform
            ),
            abi.encode(false)
        );
    }


    function _mockVerifyAvailabilityCheckProofFalse(ITeeAvailabilityCheck.Proof memory proof) private {
        vm.mockCall(
            teeVerification,
            abi.encodeWithSelector(
                ITeeVerification.verifyAvailabilityCheckProof.selector,
                proof
            ),
            abi.encode(false)
        );
    }


    function _mockIsAllowedTeeMachineOwner(uint256 _extensionId) private {
        vm.mockCall(
            teeOwnerAllowlist,
            abi.encodeWithSelector(
                ITeeOwnerAllowlist.isAllowedTeeMachineOwner.selector,
                _extensionId,
                owner
            ),
            abi.encode(true)
        );
    }


    function _mockIsCodeHashPlatformSupported(uint256 _extensionId) private {
        vm.mockCall(
            teeExtensionRegistry,
            abi.encodeWithSelector(
                ITeeExtensionRegistry.isCodeHashPlatformSupported.selector,
                _extensionId,
                codeHash,
                platform
            ),
            abi.encode(true)
        );
    }


    function _changeStatePause() private {
        vm.startPrank(owner); // to override existing startPrank
        vm.expectEmit();
        emit ITeeMachineRegistry.TeeMachinePaused(teeId, false);
        teeMachineRegistry.pause(teeId);
        vm.stopPrank();
    }


    function _setupReplicate() private returns (ITeeAvailabilityCheck.Proof memory) {
        testReplicateRevertInvalidTeeStatus();
        vm.prank(teeReplication);
        teeMachineRegistry.changeStatus(newTeeId, ITeeMachineRegistry.TeeStatus.REPLICATING);
        return _createAvailabilityCheckProof(teeId, url);
    }


    function _createAvailabilityCheckProof(
        address _teeId,
        string memory _url
    )
        private view
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
            codeHash,
            platform,
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