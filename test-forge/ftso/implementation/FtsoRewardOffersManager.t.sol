// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";

import "../../../contracts/ftso/implementation/FtsoRewardOffersManager.sol";
import "forge-std/console2.sol";

contract FtsoRewardOffersManagerTest is Test {

    FtsoRewardOffersManager private ftsoRewardOffersManager;

    address private governance;
    address private addressUpdater;
    address private mockFlareSystemManager;
    address private mockRewardManager;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    function setUp() public {
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");

        ftsoRewardOffersManager = new FtsoRewardOffersManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            10,
            2,
            3600
        );

        mockFlareSystemManager = makeAddr("flareSystemManager");
        mockRewardManager = makeAddr("rewardManager");

        vm.startPrank(addressUpdater);
        contractNameHashes = new bytes32[](3);
        contractAddresses = new address[](3);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("FlareSystemManager"));
        contractNameHashes[2] = keccak256(abi.encode("RewardManager"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = mockFlareSystemManager;
        contractAddresses[2] = mockRewardManager;
        ftsoRewardOffersManager.updateContractAddresses(contractNameHashes, contractAddresses);
        vm.stopPrank();
    }

    // set and get tests
    function testSetOfferSettings() public {
        assertEq(ftsoRewardOffersManager.minimalOfferValueWei(), 10);
        assertEq(ftsoRewardOffersManager.maxRewardEpochsInTheFuture(), 2);
        assertEq(ftsoRewardOffersManager.lastOfferBeforeRewardEpochEndSeconds(), 3600);

        vm.prank(governance);
        ftsoRewardOffersManager.setOfferSettings(20, 4, 7200);
        assertEq(ftsoRewardOffersManager.minimalOfferValueWei(), 20);
        assertEq(ftsoRewardOffersManager.maxRewardEpochsInTheFuture(), 4);
        assertEq(ftsoRewardOffersManager.lastOfferBeforeRewardEpochEndSeconds(), 7200);
    }

    function testSetAndGetDecimals() public {
        bytes8 feedSymbol = bytes8("ETH/USD");
        assertEq(ftsoRewardOffersManager.getDecimals(feedSymbol), 5); // default decimals

        vm.prank(governance);
        ftsoRewardOffersManager.setDecimals(feedSymbol, 6);
        assertEq(ftsoRewardOffersManager.getDecimals(feedSymbol), 6);
    }

    function testGetContractName() public {
        assertEq(ftsoRewardOffersManager.getContractName(), "FtsoRewardOffersManager");
    }

    // offerRewards tests



}