//  function testSetFeePercentage() public {
//         _mockGetCurrentEpochId(0);
//         address dataProvider = makeAddr("dataProvider");
//         assertEq(rewardManager.getDataProviderCurrentFeePercentage(dataProvider), 2000); // default fee
//         (uint256[] memory percentageBIPS, uint256[] memory validFrom, bool[] memory isFixed) =
//             rewardManager.getDataProviderScheduledFeePercentageChanges(dataProvider);
//         assertEq(percentageBIPS.length, 0);

//         vm.startPrank(dataProvider);
//         // see fee too high
//         vm.expectRevert("fee percentage invalid");
//         rewardManager.setDataProviderFeePercentage(uint16(10000 + 1));
//         // set fee 10 %
//         assertEq(rewardManager.setDataProviderFeePercentage(uint16(1000)), 0 + 2);
//         assertEq(rewardManager.getDataProviderFeePercentage(dataProvider, 2), 1000);
//         // change again (to 5 %)
//         assertEq(rewardManager.setDataProviderFeePercentage(uint16(500)), 0 + 2);
//         assertEq(rewardManager.getDataProviderFeePercentage(dataProvider, 2), 500);
//         // move to epoch 1 and set fee to 15 %
//         _mockGetCurrentEpochId(1);
//         assertEq(rewardManager.setDataProviderFeePercentage(uint16(1500)), 1 + 2);

//         (percentageBIPS, validFrom, isFixed) =
//             rewardManager.getDataProviderScheduledFeePercentageChanges(dataProvider);
//         assertEq(percentageBIPS.length, 2);
//         assertEq(percentageBIPS[0], 500);
//         assertEq(percentageBIPS[1], 1500);
//         assertEq(validFrom[0], 2);
//         assertEq(validFrom[1], 3);
//         assertEq(isFixed[0], true);
//         assertEq(isFixed[1], false);

//         // move to epoch 2
//         _mockGetCurrentEpochId(2);
//         assertEq(rewardManager.getDataProviderCurrentFeePercentage(dataProvider), 500);
//         // move to epoch 3
//         _mockGetCurrentEpochId(3);
//         assertEq(rewardManager.getDataProviderCurrentFeePercentage(dataProvider), 1500);
//         vm.stopPrank();
//     }


    // function testConstructorOffsetTooSmall() public {
    //     vm.expectRevert("offset too small");
    //     new RewardManager(
    //         IGovernanceSettings(makeAddr("governanceSettings")),
    //         governance,
    //         addressUpdater,
    //         1,
    //         2000
    //     );
    // }