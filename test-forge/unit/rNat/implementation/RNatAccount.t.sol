// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../../contracts/rNat/implementation/RNatAccount.sol";
import "../../../mock/IWNatMock.sol";
import "flare-smart-contracts/contracts/token/interface/IIVPContract.sol";
import "flare-smart-contracts/contracts/token/interface/IIGovernanceVotePower.sol";
import "../../../../contracts/userInterfaces/ICChainStake.sol";
import "../../../mock/ERC20Mock.sol";
import "flare-smart-contracts/contracts/userInterfaces/IClaimSetupManager.sol";

contract RNatAccountTest is Test {

    RNatAccount private rNatAccount;
    IRNat private mockRNat;
    address private owner;
    IWNatMock private wNat;
    address private governance;
    IIVPContract private vpContract;
    IIGovernanceVotePower private governanceVotePower;

    event ClaimExecutorsSet(address[] executors);

    function setUp() public {
        rNatAccount = new RNatAccount();
        mockRNat = IRNat(makeAddr("rNat"));
        owner = makeAddr("owner");
        governance = makeAddr("governance");

        // deploy WNat contract
        wNat = IWNatMock(deployCode(
            "artifacts-forge/FlareSmartContracts.sol/WNat.json",
            abi.encode(governance, "Wrapped NAT", "WNat")
        ));
        vpContract = IIVPContract(deployCode(
            "artifacts-forge/FlareSmartContracts.sol/VPContract.json",
            abi.encode(wNat, false)
        ));
        governanceVotePower = IIGovernanceVotePower(deployCode(
            "GovernanceVotePower.sol",
            abi.encode(wNat, makeAddr("pChain"), makeAddr("cChain"))
        ));
        vm.startPrank(governance);
        wNat.setReadVpContract(vpContract);
        wNat.setWriteVpContract(vpContract);
        vm.stopPrank();

        vm.deal(address(mockRNat), 1000);
    }

    // initialization
    function testInitialize() public {
        assertEq(rNatAccount.owner(), address(0));
        assertEq(address(rNatAccount.rNat()), address(0));

        rNatAccount.initialize(owner, mockRNat);

        assertEq(rNatAccount.owner(), owner);
        assertEq(address(rNatAccount.rNat()), address(mockRNat));
    }

    function testInitializeRevertAlreadyInitialized() public {
        rNatAccount.initialize(owner, mockRNat);
        vm.expectRevert("owner already set");
        rNatAccount.initialize(owner, mockRNat);
    }

    function testInitializeRevertOwnerZero() public {
        vm.expectRevert("owner address zero");
        rNatAccount.initialize(address(0), mockRNat);
    }

    function testInitializeRevertRNatZero() public {
        vm.expectRevert("rNat address zero");
        rNatAccount.initialize(owner, IRNat(address(0)));
    }

    // receive rewards
    function testReceiveRewards() public {
        testInitialize();
        uint256[] memory months = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        months[0] = 0;
        months[1] = 1;
        months[2] = 3;
        amounts[0] = 100;
        amounts[1] = 200;
        amounts[2] = 300;
        assertEq(wNat.balanceOf(address(rNatAccount)), 0);

        vm.startPrank(address(mockRNat));
        rNatAccount.receiveRewards{ value: 600 } (wNat, months, amounts);
        assertEq(wNat.balanceOf(address(rNatAccount)), 600);
        assertEq(rNatAccount.wNatBalance(wNat), 600);
        vm.stopPrank();
    }

    function testReceiveRewardsRevertOnlyRNat() public {
        testInitialize();
        uint256[] memory months = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        months[0] = 0;
        months[1] = 1;
        months[2] = 3;
        amounts[0] = 100;
        amounts[1] = 200;
        amounts[2] = 300;
        vm.expectRevert("only rNat");
        rNatAccount.receiveRewards{ value: 600 } (wNat, months, amounts);
    }

    function testTransferExternalToken() public {
        testInitialize();
        ERC20Mock token = new ERC20Mock("XTOK", "XToken");
        // Mint tokens
        token.mintAmount(address(rNatAccount), 100);
        assertEq(token.balanceOf(address(rNatAccount)), 100);
        // Should allow transfer
        vm.prank(address(mockRNat));
        rNatAccount.transferExternalToken(wNat, token, 70);

        assertEq(token.balanceOf(address(rNatAccount)), 30);
        assertEq(token.balanceOf(owner), 70);
    }

    function testTransferExternalTokenRevert() public {
        testInitialize();
        vm.prank(address(mockRNat));
        vm.expectRevert("Transfer from wNat not allowed");
        rNatAccount.transferExternalToken(wNat, wNat, 70);
    }

    // owner is already on a list of executors
    function testSetClaimExecutors1() public {
        testInitialize();
        IIClaimSetupManager claimSetupManager = IIClaimSetupManager(makeAddr("claimSetupManager"));
        vm.mockCall(
            address(claimSetupManager),
            abi.encodeWithSelector(IClaimSetupManager.setClaimExecutors.selector),
            abi.encode(0)
        );

        address[] memory executors = new address[](2);
        executors[0] = makeAddr("executor1");
        executors[1] = owner;

        uint256 balanceBefore = owner.balance;
        vm.deal(address(rNatAccount), 1000);

        vm.prank(address(mockRNat));
        vm.expectEmit();
        emit ClaimExecutorsSet(executors);
        rNatAccount.setClaimExecutors(claimSetupManager, executors);
        // 1000 is sent back to owner
        assertEq(owner.balance, 1000 + balanceBefore);
    }

    // add owner to the list of executors
    function testSetClaimExecutors2() public {
        testInitialize();
        IIClaimSetupManager claimSetupManager = IIClaimSetupManager(makeAddr("claimSetupManager"));
        vm.mockCall(
            address(claimSetupManager),
            abi.encodeWithSelector(IClaimSetupManager.setClaimExecutors.selector),
            abi.encode(0)
        );

        address[] memory executors = new address[](1);
        executors[0] = makeAddr("executor1");

        address[] memory executorsWithOwner = new address[](2);
        executorsWithOwner[0] = executors[0];
        executorsWithOwner[1] = owner;

        vm.prank(address(mockRNat));
        vm.expectEmit();
        emit ClaimExecutorsSet(executorsWithOwner);
        rNatAccount.setClaimExecutors(claimSetupManager, executors);
    }

    function testTransferCurrentBalanceRevert() public {
        testInitialize();

        address[] memory executors = new address[](1);
        executors[0] = makeAddr("executor1");

        IIClaimSetupManager claimSetupManager = IIClaimSetupManager(makeAddr("claimSetupManager"));
        vm.mockCall(
            address(claimSetupManager),
            abi.encodeWithSelector(IClaimSetupManager.setClaimExecutors.selector),
            abi.encode(0)
        );

        vm.deal(address(rNatAccount), 1000);

        vm.mockCallRevert(
            owner,
            abi.encode(),
            abi.encode()
        );

        vm.prank(address(mockRNat));
        vm.expectRevert("transfer failed");
        rNatAccount.setClaimExecutors(claimSetupManager, executors);
    }

    function testWithdrawRevert() public {
        testInitialize();
        vm.mockCall(
            address(wNat),
            abi.encodeWithSelector(bytes4(keccak256("transfer(address,uint256)"))),
            abi.encode(false)
        );
        vm.prank(address(mockRNat));
        vm.expectRevert("transfer failed");
        rNatAccount.withdraw(wNat, 0, 0, true);
    }

    function testWithdraw() public {
        testInitialize();
        vm.mockCall(
            address(wNat),
            abi.encodeWithSelector(bytes4(keccak256("transfer(address,uint256)"))),
            abi.encode(false)
        );
        vm.prank(address(mockRNat));
        vm.expectRevert("transfer failed");
        rNatAccount.withdrawAll(wNat, 0, true);
    }

}