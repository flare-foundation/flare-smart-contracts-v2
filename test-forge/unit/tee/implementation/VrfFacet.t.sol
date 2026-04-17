// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { FlareTeeManagerDeployer } from "../../../utils/FlareTeeManagerDeployer.sol";
import { IIFlareTeeManager } from "../../../../contracts/tee/interface/IIFlareTeeManager.sol";
import { IVrfFacet } from "../../../../contracts/userInterfaces/tee/IVrfFacet.sol";
import { IMachineManagerFacet } from "../../../../contracts/userInterfaces/tee/IMachineManagerFacet.sol";
import { IWalletManagerFacet } from "../../../../contracts/userInterfaces/tee/IWalletManagerFacet.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import { IDiamondCut } from "../../../../contracts/diamond/interfaces/IDiamondCut.sol";
import { IDiamond } from "../../../../contracts/diamond/interfaces/IDiamond.sol";
import { ProtocolsV2Interface } from "../../../../contracts/userInterfaces/LTS/ProtocolsV2Interface.sol";
import { IIRewardManager } from "../../../../contracts/protocol/interface/IIRewardManager.sol";
import { MachineManager } from "../../../../contracts/tee/library/MachineManager.sol";
import { WalletManager } from "../../../../contracts/tee/library/WalletManager.sol";
import { WalletProjectManager } from "../../../../contracts/tee/library/WalletProjectManager.sol";
import { WalletKeyManager } from "../../../../contracts/tee/library/WalletKeyManager.sol";

/**
 * Helper init contract to inject TEE machine state directly into Diamond storage.
 */
contract TeeVrfTestMachineInit {
    function initMachine(
        address _teeId,
        address _owner,
        address _teeProxyId,
        string calldata _url,
        uint256 _extensionId,
        IMachineManagerFacet.TeeStatus _status
    )
        external
    {
        MachineManager.State storage state = MachineManager.getState();
        MachineManager.TeeMachineState storage m = state.teeMachineStates[_teeId];
        m.owner = _owner;
        m.teeProxyId = _teeProxyId;
        m.url = _url;
        m.extensionId = _extensionId;
        m.status = _status;
        m.initialTeeId = _teeId;
    }
}

/**
 * Helper init contract to inject wallet, project and key state into Diamond storage.
 */
contract TeeVrfTestWalletInit {
    function initProject(
        bytes32 _projectId,
        address _owner,
        uint256 _extensionId
    )
        external
    {
        WalletProjectManager.State storage state = WalletProjectManager.getState();
        state.projects[_projectId].owner = _owner;
        state.projects[_projectId].extensionId = _extensionId;
    }

    function initWallet(
        bytes32 _walletId,
        bytes32 _projectId,
        IWalletManagerFacet.WalletStatus _status
    )
        external
    {
        WalletManager.State storage state = WalletManager.getState();
        state.wallets[_walletId].projectId = _projectId;
        state.wallets[_walletId].status = _status;
    }

    function initWalletKey(
        bytes32 _walletId,
        uint64 _keyId,
        address[] calldata _teeIds
    )
        external
    {
        WalletKeyManager.State storage state = WalletKeyManager.getState();
        WalletKeyManager.TeeWalletKeysState storage keys = state.walletKeys[_walletId];
        WalletKeyManager.KeyDefinition storage keyDef = keys.keyDefinitions[_keyId];
        for (uint256 i = 0; i < _teeIds.length; i++) {
            keyDef.teeIds.push(_teeIds[i]);
        }
    }
}

contract VrfFacetTest is Test {

    IIFlareTeeManager private flareTeeManager;

    TeeVrfTestMachineInit private machineInit;
    TeeVrfTestWalletInit private walletInit;

    address private governance;
    address private addressUpdater;
    address private flareSystemsManagerMock;
    address private rewardManagerMock;

    address private walletOwner;
    address private authAddress;
    bytes32 private walletId;
    bytes32 private projectId;
    uint64 private keyId;
    address private teeId;
    bytes private nonce;

    function setUp() public {
        governance = makeAddr("governance");
        addressUpdater = makeAddr("AddressUpdater");
        flareSystemsManagerMock = makeAddr("FlareSystemsManager");
        rewardManagerMock = makeAddr("RewardManager");

        flareTeeManager = FlareTeeManagerDeployer.deployDay1Facets(FlareTeeManagerDeployer.Day1DeployParams({
            governanceSettings: IGovernanceSettings(makeAddr("governanceSettings")),
            initialGovernance: governance,
            addressUpdater: addressUpdater,
            availabilityCheckValidityDurationSeconds: 3600,
            signingPolicyValidityDurationInRewardEpochs: 6,
            challengeValidityDurationSeconds: 600,
            defaultFee: 0
        }));
        vm.startPrank(governance);
        FlareTeeManagerDeployer.deployLaterFacets(flareTeeManager, FlareTeeManagerDeployer.LaterDeployParams({
            pauseBeforeUpgradeMinDurationSeconds: 600
        }));
        vm.stopPrank();

        // Update contract addresses
        bytes32[] memory nameHashes = new bytes32[](6);
        address[] memory addresses = new address[](6);
        nameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        nameHashes[1] = keccak256(abi.encode("FlareSystemsManager"));
        nameHashes[2] = keccak256(abi.encode("RewardManager"));
        nameHashes[3] = keccak256(abi.encode("Relay"));
        nameHashes[4] = keccak256(abi.encode("Fdc2Hub"));
        nameHashes[5] = keccak256(abi.encode("Fdc2Verification"));
        addresses[0] = addressUpdater;
        addresses[1] = flareSystemsManagerMock;
        addresses[2] = rewardManagerMock;
        addresses[3] = makeAddr("Relay");
        addresses[4] = makeAddr("Fdc2Hub");
        addresses[5] = makeAddr("Fdc2Verification");
        vm.prank(addressUpdater);
        flareTeeManager.updateContractAddresses(nameHashes, addresses);

        // Deploy helper init contracts
        machineInit = new TeeVrfTestMachineInit();
        walletInit = new TeeVrfTestWalletInit();

        // Mock external calls that Instructions makes
        vm.mockCall(
            flareSystemsManagerMock,
            abi.encodeWithSelector(ProtocolsV2Interface.getCurrentRewardEpochId.selector),
            abi.encode(uint24(1))
        );
        vm.mockCall(
            rewardManagerMock,
            abi.encodeWithSelector(IIRewardManager.receiveRewards.selector),
            abi.encode(uint256(1))
        );

        walletOwner = makeAddr("walletOwner");
        authAddress = makeAddr("authAddress");
        walletId = keccak256(abi.encode("walletId"));
        projectId = keccak256(abi.encode("projectId"));
        keyId = 0;
        teeId = makeAddr("teeId");
        nonce = bytes("test-nonce");

        // Inject project state
        _initProject(projectId, walletOwner, 0);

        // Inject wallet state (default CREATED status; tests override as needed)
        _initWallet(walletId, projectId, IWalletManagerFacet.WalletStatus.CREATED);

        // Fund test addresses
        vm.deal(authAddress, 1 ether);
    }

    // =========================================================================
    // requestVrf tests
    // =========================================================================

    function testRequestVrfRevertNonceEmpty() public {
        vm.prank(authAddress);
        vm.expectRevert(IVrfFacet.NonceEmpty.selector);
        flareTeeManager.requestVrf(walletId, keyId, bytes(""), address(0));
    }

    function testRequestVrfRevertOnlyAuthorizationAddress() public {
        // set auth address, then call from a different address
        vm.prank(walletOwner);
        flareTeeManager.setVrfAuthorizationAddress(walletId, authAddress);

        vm.prank(makeAddr("randomCaller"));
        vm.expectRevert(IVrfFacet.OnlyAuthorizationAddress.selector);
        flareTeeManager.requestVrf(walletId, keyId, nonce, address(0));
    }

    function testRequestVrfRevertOnlyAuthorizationAddressNoAuthSet() public {
        // no auth address set (default address(0))
        vm.prank(walletOwner);
        vm.expectRevert(IVrfFacet.OnlyAuthorizationAddress.selector);
        flareTeeManager.requestVrf(walletId, keyId, nonce, address(0));
    }

    function testRequestVrfRevertWalletNotInProduction() public {
        _setupAuthAddress();
        _initWallet(walletId, projectId, IWalletManagerFacet.WalletStatus.INITIALIZED);
        vm.prank(authAddress);
        vm.expectRevert(IVrfFacet.WalletNotInProduction.selector);
        flareTeeManager.requestVrf(walletId, keyId, nonce, address(0));
    }

    function testRequestVrfRevertNoTeesForKey() public {
        _setupAuthAddress();
        _initWallet(walletId, projectId, IWalletManagerFacet.WalletStatus.PRODUCTION);
        // no tee ids for the key (empty by default)
        vm.prank(authAddress);
        vm.expectRevert(IVrfFacet.NoTeesForKey.selector);
        flareTeeManager.requestVrf(walletId, keyId, nonce, address(0));
    }

    function testRequestVrfRevertNoTeesForKeyAllNonProduction() public {
        address[] memory teeIds = new address[](2);
        teeIds[0] = makeAddr("tee0");
        teeIds[1] = makeAddr("tee1");
        _setupAuthAddress();
        _initWallet(walletId, projectId, IWalletManagerFacet.WalletStatus.PRODUCTION);
        _initWalletKey(walletId, keyId, teeIds);
        // all TEEs are not in PRODUCTION
        _initTeeMachine(teeIds[0], IMachineManagerFacet.TeeStatus.INITIALIZED);
        _initTeeMachine(teeIds[1], IMachineManagerFacet.TeeStatus.SUSPENDED);
        vm.prank(authAddress);
        vm.expectRevert(IVrfFacet.NoTeesForKey.selector);
        flareTeeManager.requestVrf(walletId, keyId, nonce, address(0));
    }

    function testRequestVrf() public {
        address[] memory teeIds = new address[](1);
        teeIds[0] = teeId;
        _setupHappyPath(teeIds);

        vm.prank(authAddress);
        vm.expectEmit(true, false, false, false, address(flareTeeManager));
        emit IVrfFacet.VrfRequested(walletId, 0, bytes32(0));
        bytes32 returnedId = flareTeeManager.requestVrf(walletId, keyId, nonce, address(0));
        assertTrue(returnedId != bytes32(0));
    }

    function testRequestVrfWithClaimBackAddress() public {
        address claimBack = makeAddr("claimBack");
        address[] memory teeIds = new address[](1);
        teeIds[0] = teeId;
        _setupHappyPath(teeIds);

        vm.prank(authAddress);
        bytes32 returnedId = flareTeeManager.requestVrf(walletId, keyId, nonce, claimBack);
        assertTrue(returnedId != bytes32(0));
    }

    function testRequestVrfForwardsValue() public {
        address[] memory teeIds = new address[](1);
        teeIds[0] = teeId;
        _setupHappyPath(teeIds);

        vm.deal(authAddress, 1 ether);
        vm.expectCall(
            rewardManagerMock,
            1 ether,
            abi.encodePacked(IIRewardManager.receiveRewards.selector)
        );
        vm.prank(authAddress);
        flareTeeManager.requestVrf{value: 1 ether}(walletId, keyId, nonce, address(0));
    }

    function testRequestVrfMultipleTees() public {
        address[] memory teeIds = new address[](3);
        teeIds[0] = makeAddr("teeId0");
        teeIds[1] = makeAddr("teeId1");
        teeIds[2] = makeAddr("teeId2");
        _setupHappyPath(teeIds);

        vm.prank(authAddress);
        vm.expectEmit(true, false, false, false, address(flareTeeManager));
        emit IVrfFacet.VrfRequested(walletId, 0, bytes32(0));
        bytes32 returnedId = flareTeeManager.requestVrf(walletId, keyId, nonce, address(0));
        assertTrue(returnedId != bytes32(0));
    }

    function testRequestVrfFiltersNonProductionTees() public {
        address[] memory teeIds = new address[](3);
        teeIds[0] = makeAddr("teeProduction");
        teeIds[1] = makeAddr("teeSuspended");
        teeIds[2] = makeAddr("teeProduction2");
        _setupAuthAddress();
        _initWallet(walletId, projectId, IWalletManagerFacet.WalletStatus.PRODUCTION);
        _initWalletKey(walletId, keyId, teeIds);
        _initTeeMachine(teeIds[0], IMachineManagerFacet.TeeStatus.PRODUCTION);
        _initTeeMachine(teeIds[1], IMachineManagerFacet.TeeStatus.SUSPENDED);
        _initTeeMachine(teeIds[2], IMachineManagerFacet.TeeStatus.PRODUCTION);

        vm.prank(authAddress);
        vm.expectEmit(true, false, false, false, address(flareTeeManager));
        emit IVrfFacet.VrfRequested(walletId, 0, bytes32(0));
        bytes32 returnedId = flareTeeManager.requestVrf(walletId, keyId, nonce, address(0));
        assertTrue(returnedId != bytes32(0));
    }

    // =========================================================================
    // setVrfAuthorizationAddress tests
    // =========================================================================

    function testSetVrfAuthorizationAddress() public {
        vm.prank(walletOwner);
        vm.expectEmit();
        emit IVrfFacet.VrfAuthorizationAddressSet(walletId, authAddress);
        flareTeeManager.setVrfAuthorizationAddress(walletId, authAddress);

        assertEq(flareTeeManager.getVrfAuthorizationAddress(walletId), authAddress);
    }

    function testSetVrfAuthorizationAddressToZero() public {
        // first set to non-zero
        vm.prank(walletOwner);
        flareTeeManager.setVrfAuthorizationAddress(walletId, authAddress);
        assertEq(flareTeeManager.getVrfAuthorizationAddress(walletId), authAddress);

        // then set to zero to disable
        vm.prank(walletOwner);
        vm.expectEmit();
        emit IVrfFacet.VrfAuthorizationAddressSet(walletId, address(0));
        flareTeeManager.setVrfAuthorizationAddress(walletId, address(0));

        assertEq(flareTeeManager.getVrfAuthorizationAddress(walletId), address(0));
    }

    function testSetVrfAuthorizationAddressRevertOnlyWalletOwner() public {
        vm.prank(makeAddr("notOwner"));
        vm.expectRevert(IVrfFacet.OnlyWalletOwner.selector);
        flareTeeManager.setVrfAuthorizationAddress(walletId, authAddress);
    }

    // =========================================================================
    // getVrfAuthorizationAddress tests
    // =========================================================================

    function testGetVrfAuthorizationAddressDefault() public view {
        assertEq(flareTeeManager.getVrfAuthorizationAddress(walletId), address(0));
    }

    // =========================================================================
    // Helpers
    // =========================================================================

    function _setupAuthAddress() internal {
        vm.prank(walletOwner);
        flareTeeManager.setVrfAuthorizationAddress(walletId, authAddress);
    }

    function _setupHappyPath(address[] memory _teeIds) internal {
        _setupAuthAddress();
        _initWallet(walletId, projectId, IWalletManagerFacet.WalletStatus.PRODUCTION);
        _initWalletKey(walletId, keyId, _teeIds);
        for (uint256 i = 0; i < _teeIds.length; i++) {
            _initTeeMachine(_teeIds[i], IMachineManagerFacet.TeeStatus.PRODUCTION);
        }
    }

    function _initProject(
        bytes32 _projectId,
        address _owner,
        uint256 _extensionId
    ) internal {
        IDiamond.FacetCut[] memory emptyCuts = new IDiamond.FacetCut[](0);
        vm.prank(governance);
        IDiamondCut(address(flareTeeManager)).diamondCut(
            emptyCuts,
            address(walletInit),
            abi.encodeCall(TeeVrfTestWalletInit.initProject, (_projectId, _owner, _extensionId))
        );
    }

    function _initWallet(
        bytes32 _walletId,
        bytes32 _projectId,
        IWalletManagerFacet.WalletStatus _status
    ) internal {
        IDiamond.FacetCut[] memory emptyCuts = new IDiamond.FacetCut[](0);
        vm.prank(governance);
        IDiamondCut(address(flareTeeManager)).diamondCut(
            emptyCuts,
            address(walletInit),
            abi.encodeCall(TeeVrfTestWalletInit.initWallet, (_walletId, _projectId, _status))
        );
    }

    function _initWalletKey(
        bytes32 _walletId,
        uint64 _keyId,
        address[] memory _teeIds
    ) internal {
        IDiamond.FacetCut[] memory emptyCuts = new IDiamond.FacetCut[](0);
        vm.prank(governance);
        IDiamondCut(address(flareTeeManager)).diamondCut(
            emptyCuts,
            address(walletInit),
            abi.encodeCall(TeeVrfTestWalletInit.initWalletKey, (_walletId, _keyId, _teeIds))
        );
    }

    function _initTeeMachine(
        address _teeId,
        IMachineManagerFacet.TeeStatus _status
    ) internal {
        IDiamond.FacetCut[] memory emptyCuts = new IDiamond.FacetCut[](0);
        vm.prank(governance);
        IDiamondCut(address(flareTeeManager)).diamondCut(
            emptyCuts,
            address(machineInit),
            abi.encodeCall(TeeVrfTestMachineInit.initMachine, (
                _teeId, makeAddr("teeOwner"), makeAddr("teeProxyId"), "https://tee.url", 0, _status
            ))
        );
    }

}
