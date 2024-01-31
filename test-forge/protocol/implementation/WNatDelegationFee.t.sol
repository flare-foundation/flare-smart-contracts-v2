// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../contracts/protocol/implementation/WNatDelegationFee.sol";

contract WNatDelegationFeeTest is Test {

    WNatDelegationFee private feeManager;
    address private addressUpdater;
    address private mockFlareSystemsManager;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    address private voter;

    function setUp() public {
        addressUpdater = makeAddr("addressUpdater");
        feeManager = new WNatDelegationFee(addressUpdater, 2, 2000);

        vm.prank(addressUpdater);
        mockFlareSystemsManager = makeAddr("mockFlareSystemsManager");
        contractNameHashes = new bytes32[](2);
        contractAddresses = new address[](2);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("FlareSystemsManager"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = mockFlareSystemsManager;
        feeManager.updateContractAddresses(contractNameHashes, contractAddresses);

        voter = makeAddr("voter");
    }


    function testConstructorOffsetTooSmall() public {
        vm.expectRevert("offset too small");
        new WNatDelegationFee(addressUpdater, 1, 2000);
    }

    function testSetFeePercentage() public {
        _mockGetCurrentEpochId(0);
        assertEq(feeManager.getVoterCurrentFeePercentage(voter), 2000); // default fee
        (uint256[] memory percentageBIPS, uint256[] memory validFrom, bool[] memory isFixed) =
            feeManager.getVoterScheduledFeePercentageChanges(voter);
        assertEq(percentageBIPS.length, 0);

        vm.startPrank(voter);
        // see fee too high
        vm.expectRevert("fee percentage invalid");
        feeManager.setVoterFeePercentage(uint16(10000 + 1));
        // set fee 10 %
        assertEq(feeManager.setVoterFeePercentage(uint16(1000)), 0 + 2);
        assertEq(feeManager.getVoterFeePercentage(voter, 2), 1000);
        // change again (to 5 %)
        assertEq(feeManager.setVoterFeePercentage(uint16(500)), 0 + 2);
        assertEq(feeManager.getVoterFeePercentage(voter, 2), 500);
        // move to epoch 1 and set fee to 15 %
        _mockGetCurrentEpochId(1);
        assertEq(feeManager.setVoterFeePercentage(uint16(1500)), 1 + 2);

        (percentageBIPS, validFrom, isFixed) =
            feeManager.getVoterScheduledFeePercentageChanges(voter);
        assertEq(percentageBIPS.length, 2);
        assertEq(percentageBIPS[0], 500);
        assertEq(percentageBIPS[1], 1500);
        assertEq(validFrom[0], 2);
        assertEq(validFrom[1], 3);
        assertEq(isFixed[0], true);
        assertEq(isFixed[1], false);

        // move to epoch 2
        _mockGetCurrentEpochId(2);
        assertEq(feeManager.getVoterCurrentFeePercentage(voter), 500);
        // move to epoch 3
        _mockGetCurrentEpochId(3);
        assertEq(feeManager.getVoterCurrentFeePercentage(voter), 1500);
        vm.stopPrank();
    }

    function testUpdateInThePastRevert() public {
        _mockGetCurrentEpochId(10);
        assertEq(feeManager.setVoterFeePercentage(uint16(1000)), 10 + 2);

        // go back in time
        _mockGetCurrentEpochId(9);
        vm.expectRevert();
        feeManager.setVoterFeePercentage(uint16(500));
    }

    function testGetVoterFeePercentageRevert() public {
        _mockGetCurrentEpochId(1);
        vm.expectRevert("invalid reward epoch id");
        feeManager.getVoterFeePercentage(voter, 6);
    }

    //// helper functions
    function _mockGetCurrentEpochId(uint256 _epochId) private {
        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(IFlareSystemsManager.getCurrentRewardEpochId.selector),
            abi.encode(_epochId)
        );
    }


}