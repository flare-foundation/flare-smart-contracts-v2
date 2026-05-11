// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { WNatDelegationFee } from "../../../../contracts/protocol/implementation/WNatDelegationFee.sol";
import { IWNatDelegationFee } from "../../../../contracts/userInterfaces/IWNatDelegationFee.sol";
import { ProtocolsV2Interface } from "../../../../contracts/userInterfaces/LTS/ProtocolsV2Interface.sol";

contract WNatDelegationFeeTest is Test {

    WNatDelegationFee private feeManager;
    address private addressUpdater;
    address private mockFlareSystemsManager;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    address private voter;

    function setUp() public {
        addressUpdater = makeAddr("addressUpdater");
        feeManager = new WNatDelegationFee(addressUpdater, 2, 2000, 2000);

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
        vm.expectRevert(IWNatDelegationFee.OffsetTooSmall.selector);
        new WNatDelegationFee(addressUpdater, 1, 2000, 2000);
    }

    function testConstructorMinFeeInvalid() public {
        vm.expectRevert(IWNatDelegationFee.MinFeePercentageInvalid.selector);
        new WNatDelegationFee(addressUpdater, 2, 2000, 10001);
    }

    function testConstructorDefaultFeeBelowMin() public {
        vm.expectRevert(IWNatDelegationFee.DefaultFeePercentageInvalid.selector);
        new WNatDelegationFee(addressUpdater, 2, 1999, 2000);
    }

    function testConstructorDefaultFeeAboveMax() public {
        vm.expectRevert(IWNatDelegationFee.DefaultFeePercentageInvalid.selector);
        new WNatDelegationFee(addressUpdater, 2, 10001, 2000);
    }

    function testMinFeeBIPS() public view {
        assertEq(feeManager.minFeeBIPS(), uint16(2000));
    }

    function testSetFeePercentage() public {
        _mockGetCurrentEpochId(0);
        assertEq(feeManager.getVoterCurrentFeePercentage(voter), 2000); // default fee
        (uint256[] memory percentageBIPS, uint256[] memory validFrom, bool[] memory isFixed) =
            feeManager.getVoterScheduledFeePercentageChanges(voter);
        assertEq(percentageBIPS.length, 0);

        vm.startPrank(voter);
        // see fee too high
        vm.expectRevert(IWNatDelegationFee.FeePercentageInvalid.selector);
        feeManager.setVoterFeePercentage(uint16(10000 + 1));
        // see fee too low (below 20% minimum)
        vm.expectRevert(IWNatDelegationFee.FeePercentageInvalid.selector);
        feeManager.setVoterFeePercentage(uint16(1999));
        // set fee 25 %
        assertEq(feeManager.setVoterFeePercentage(uint16(2500)), 0 + 2);
        assertEq(feeManager.getVoterFeePercentage(voter, 2), 2500);
        // change again (to 30 %)
        assertEq(feeManager.setVoterFeePercentage(uint16(3000)), 0 + 2);
        assertEq(feeManager.getVoterFeePercentage(voter, 2), 3000);
        // move to epoch 1 and set fee to 40 %
        _mockGetCurrentEpochId(1);
        assertEq(feeManager.setVoterFeePercentage(uint16(4000)), 1 + 2);

        (percentageBIPS, validFrom, isFixed) =
            feeManager.getVoterScheduledFeePercentageChanges(voter);
        assertEq(percentageBIPS.length, 2);
        assertEq(percentageBIPS[0], 3000);
        assertEq(percentageBIPS[1], 4000);
        assertEq(validFrom[0], 2);
        assertEq(validFrom[1], 3);
        assertEq(isFixed[0], true);
        assertEq(isFixed[1], false);

        // move to epoch 2
        _mockGetCurrentEpochId(2);
        assertEq(feeManager.getVoterCurrentFeePercentage(voter), 3000);
        // move to epoch 3
        _mockGetCurrentEpochId(3);
        assertEq(feeManager.getVoterCurrentFeePercentage(voter), 4000);
        vm.stopPrank();
    }

    function testUpdateInThePastRevert() public {
        _mockGetCurrentEpochId(10);
        assertEq(feeManager.setVoterFeePercentage(uint16(2500)), 10 + 2);

        // go back in time
        _mockGetCurrentEpochId(9);
        vm.expectRevert();
        feeManager.setVoterFeePercentage(uint16(3000));
    }

    function testGetVoterFeePercentageRevert() public {
        _mockGetCurrentEpochId(1);
        vm.expectRevert(IWNatDelegationFee.InvalidRewardEpochId.selector);
        feeManager.getVoterFeePercentage(voter, 6);
    }

    //// helper functions
    function _mockGetCurrentEpochId(uint256 _epochId) private {
        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(ProtocolsV2Interface.getCurrentRewardEpochId.selector),
            abi.encode(_epochId)
        );
    }


}