// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../../../../contracts/tee/implementation/TeePaymentsEVM.sol";
import "../../../../contracts/tee/implementation/TeeInstructions.sol";
import "../../../../contracts/tee/proxy/TeePaymentsProxy.sol";

contract TeePaymentsEVMTest is Test {

    TeePaymentsEVM private teePaymentsEVM;
    TeePaymentsProxy private teePaymentsProxy;
    TeePaymentsEVM private teePaymentsEVMImpl;

    address private mockTeeWalletManager;
    address private mockFSM;
    address private mockTeeFeeCalculator;
    address private mockTeeInstructions;
    TeeInstructions private teeInstructions;
    address private mockRewardManager;
    address private mockTeeWalletProjectManager;
    address private mockTeeWalletKeyManager;
    address private teeVerificationMock;

    address private governance;
    address private addressUpdater;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    bytes32 private immutable opType = bytes32("opType");
    bytes32 private constant SOURCE_ID = bytes32("XRP");
    bytes32 public constant PAY = bytes32("PAY");
    bytes32 public constant REISSUE = bytes32("REISSUE");
    bytes32 private walletId;
    address private walletOwner;
    bytes32 private projectId;
    uint256 private chainId;

    function setUp() public {
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");
        mockTeeWalletManager = makeAddr("teeWalletManager");
        mockFSM = makeAddr("flareSystemsManager");
        mockTeeFeeCalculator = makeAddr("teeFeeCalculator");
        mockTeeInstructions = makeAddr("teeInstructions");
        mockRewardManager = makeAddr("rewardManager");
        mockTeeWalletProjectManager = makeAddr("teeWalletProjectManager");
        mockTeeWalletKeyManager = makeAddr("teeWalletKeyManager");
        teeVerificationMock = makeAddr("teeVerificationMock");

        teePaymentsEVMImpl = new TeePaymentsEVM();
        teePaymentsProxy = new TeePaymentsProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            5, // max batch size
            300, // max batch duration seconds
            opType,
            SOURCE_ID,
            address(teePaymentsEVMImpl)
        );
        teePaymentsEVM = TeePaymentsEVM(address(teePaymentsProxy));

        walletId = bytes32("walletId");
        walletOwner = makeAddr("walletOwner");
        projectId = bytes32("projectId");
        _mockGetWalletProjectId(walletId, projectId);
        _mockGetOwner(projectId, walletOwner);

        chainId = 14;

        vm.prank(addressUpdater);
        contractNameHashes = new bytes32[](7);
        contractAddresses = new address[](7);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("TeeWalletManager"));
        contractNameHashes[2] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[3] = keccak256(abi.encode("TeeVerification"));
        contractNameHashes[4] = keccak256(abi.encode("TeeInstructions"));
        contractNameHashes[5] = keccak256(abi.encode("TeeWalletProjectManager"));
        contractNameHashes[6] = keccak256(abi.encode("TeeWalletKeyManager"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = mockTeeWalletManager;
        contractAddresses[2] = mockFSM;
        contractAddresses[3] = teeVerificationMock;
        contractAddresses[4] = mockTeeInstructions;
        contractAddresses[5] = mockTeeWalletProjectManager;
        contractAddresses[6] = mockTeeWalletKeyManager;
        teePaymentsEVM.updateContractAddresses(contractNameHashes, contractAddresses);
    }

    function testSetChainId() public {
        assertEq(teePaymentsEVM.getChainId(projectId), 0);
        vm.prank(walletOwner);
        teePaymentsEVM.setChainId(projectId, chainId);
        assertEq(teePaymentsEVM.getChainId(projectId), chainId);
    }

    function testSetChainIdRevertOnlyProjectOwner() public {
        vm.expectRevert(ITeePaymentsEVM.OnlyProjectOwner.selector);
        teePaymentsEVM.setChainId(projectId, chainId);
    }

    function testSetChainIdRevertChainIdZero() public {
        vm.prank(walletOwner);
        vm.expectRevert(ITeePaymentsEVM.ChainIdZero.selector);
        teePaymentsEVM.setChainId(projectId, 0);
    }

    function testSetChainIdRevertAlreadySet() public {
        testSetChainId();
        vm.prank(walletOwner);
        vm.expectRevert(ITeePaymentsEVM.ChainIdAlreadySet.selector);
        teePaymentsEVM.setChainId(projectId, 15);
    }

    function testGetOpType() public {
        assertEq(teePaymentsEVM.getOpType(), opType);
    }

    function testGetOpTypeConstants() public {
        vm.prank(walletOwner);
        teePaymentsEVM.setChainId(projectId, chainId);

        bytes memory opTypeConstants = teePaymentsEVM.getOpTypeConstants(projectId);
        bytes memory const = abi.encode(ITeePaymentsEVM.OpTypeConstantsEVM(chainId));
        assertEq(opTypeConstants, const);

        // get chainId
        ITeePaymentsEVM.OpTypeConstantsEVM memory opTypeConstantsEVM = abi.decode(
            opTypeConstants, (ITeePaymentsEVM.OpTypeConstantsEVM)
        );
        assertEq(opTypeConstantsEVM.chainId, chainId);
    }

    function testGetOpTypeConstantsRevert() public {
        vm.expectRevert(ITeePaymentsEVM.ChainIdNotSet.selector);
        teePaymentsEVM.getOpTypeConstants(walletId);
    }

    //// mocks and helpers ////
    function _mockGetWalletProjectId(bytes32 _walletId, bytes32 _projectId) internal {
        vm.mockCall(
            mockTeeWalletManager,
            abi.encodeWithSelector(ITeeWalletManager.getWalletProjectId.selector, _walletId),
            abi.encode(_projectId)
        );
    }

     function _mockGetOwner(bytes32 _projectId, address _walletOwner) internal {
        vm.mockCall(
            mockTeeWalletProjectManager,
            abi.encodeWithSelector(ITeeWalletProjectManager.getOwner.selector, _projectId),
            abi.encode(_walletOwner)
        );
    }

}