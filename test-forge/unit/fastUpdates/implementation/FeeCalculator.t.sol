// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../../contracts/fastUpdates/implementation/FeeCalculator.sol";

contract FeeCalculatorTest is Test {

    FeeCalculator private feeCalculator;
    address private governance;
    address private addressUpdater;
    address private mockFastUpdatesConfiguration;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    bytes21[] private feedIds;

    event FeedFeeSet(bytes21 indexed feedId, uint256 fee);
    event CategoryFeeSet(uint8 indexed category, uint256 fee);
    event FeedFeeRemoved(bytes21 indexed feedId);
    event CategoryFeeRemoved(uint8 indexed category);
    event DefaultFeeSet(uint256 fee);

    function setUp() public {
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");

        feeCalculator = new FeeCalculator(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            10
        );

        mockFastUpdatesConfiguration = makeAddr("mockFastUpdatesConfiguration");

        vm.startPrank(addressUpdater);
        contractNameHashes = new bytes32[](2);
        contractAddresses = new address[](2);
        contractNameHashes[0] = keccak256(abi.encode("FastUpdatesConfiguration"));
        contractNameHashes[1] = keccak256(abi.encode("AddressUpdater"));
        contractAddresses[0] = mockFastUpdatesConfiguration;
        contractAddresses[1] = addressUpdater;
        feeCalculator.updateContractAddresses(contractNameHashes, contractAddresses);
        vm.stopPrank();

        _setFeedIds();
    }

    function testSetDefaultFee() public {
        assertEq(feeCalculator.defaultFee(), 10);
        vm.prank(governance);
        vm.expectEmit();
        emit DefaultFeeSet(100);
        feeCalculator.setDefaultFee(100);
        assertEq(feeCalculator.defaultFee(), 100);
    }

    function testSetDefaultFeeRevertOnlyGovernance() public {
        vm.expectRevert("only governance");
        feeCalculator.setDefaultFee(100);
    }

    function testSetDefaultFeeRevertZero() public {
        vm.expectRevert("default fee zero");
        vm.prank(governance);
        feeCalculator.setDefaultFee(0);
    }

    function testSetCategoriesFees() public {
        uint8[] memory categories = new uint8[](2);
        categories[0] = 1;
        categories[1] = 2;
        uint256[] memory fees = new uint256[](2);
        fees[0] = 10;
        fees[1] = 20;
        vm.prank(governance);
        vm.expectEmit();
        emit CategoryFeeSet(1, 10);
        vm.expectEmit();
        emit CategoryFeeSet(2, 20);
        feeCalculator.setCategoriesFees(categories, fees);
        assertEq(feeCalculator.getCategoryFee(1), 10);
        assertEq(feeCalculator.getCategoryFee(2), 20);
    }

    function testSetCategoriesFees1() public {
        testSetCategoriesFees();
        uint8[] memory categories = new uint8[](1);
        categories[0] = 1;
        uint256[] memory fees = new uint256[](1);
        fees[0] = 0;
        vm.prank(governance);
        feeCalculator.setCategoriesFees(categories, fees);
        assertEq(feeCalculator.getCategoryFee(1), 0);
        assertEq(feeCalculator.getCategoryFee(2), 20);
    }

    function testSetCategoriesFeesRevert() public {
        uint8[] memory categories = new uint8[](2);
        categories[0] = 1;
        categories[1] = 2;
        uint256[] memory fees = new uint256[](1);
        fees[0] = 10;
        vm.prank(governance);
        vm.expectRevert("lengths mismatch");
        feeCalculator.setCategoriesFees(categories, fees);
    }

    function testCategoriesDefaultFeesRevert1() public {
        vm.expectRevert("only governance");
        feeCalculator.setCategoriesFees(new uint8[](0), new uint256[](0));
    }

    function testGetCategoryFeeRevert() public {
        vm.expectRevert("category fee not set; default fee will be used");
        feeCalculator.getCategoryFee(1);
    }

    function testSetFeedsFees() public {
        uint256[] memory fees = new uint256[](8);
        for (uint256 i = 0; i < 8; i++) {
            fees[i] = i * 10;
            vm.expectEmit();
            emit FeedFeeSet(feedIds[i], i * 10);
        }
        vm.prank(governance);
        feeCalculator.setFeedsFees(feedIds, fees);
    }

    function testSetFeedsFeesRevert() public {
        uint256[] memory fees = new uint256[](1);
        fees[0] = 10;
        vm.prank(governance);
        vm.expectRevert("lengths mismatch");
        feeCalculator.setFeedsFees(feedIds, fees);
    }

    function testSetFeedsFeesRevert1() public{
        vm.expectRevert("only governance");
        feeCalculator.setFeedsFees(new bytes21[](0), new uint256[](0));
    }

    function testGetFeedFee() public {
        testSetFeedsFees();
        for (uint256 i = 0; i < 8; i++) {
            assertEq(feeCalculator.getFeedFee(feedIds[i]), i * 10);
        }
    }

    function getFeedFeeRevert() public {
        vm.expectRevert("feed fee not set; category feed or default fee will be used");
        feeCalculator.getFeedFee(_getFeedId(uint8(4), "feed0"));
    }

    function testRemoveFeedsFees() public {
        testSetFeedsFees();
        assertEq(feeCalculator.getFeedFee(feedIds[0]), 0);
        assertEq(feeCalculator.getFeedFee(feedIds[1]), 10);
        assertEq(feeCalculator.getFeedFee(feedIds[2]), 20);
        bytes21[] memory feedsToRemove = new bytes21[](2);
        feedsToRemove[0] = feedIds[0];
        feedsToRemove[1] = feedIds[1];

        vm.expectEmit();
        emit FeedFeeRemoved(feedIds[0]);
        vm.expectEmit();
        emit FeedFeeRemoved(feedIds[1]);
        vm.prank(governance);
        feeCalculator.removeFeedsFees(feedsToRemove);

        assertEq(feeCalculator.getFeedFee(feedIds[2]), 20);
        vm.expectRevert("feed fee not set; category feed or default fee will be used");
        feeCalculator.getFeedFee(feedIds[0]);
        vm.expectRevert("feed fee not set; category feed or default fee will be used");
        feeCalculator.getFeedFee(feedIds[1]);
    }

    function testRemoveCategoriesFees() public {
        testSetCategoriesFees();
        assertEq(feeCalculator.getCategoryFee(1), 10);
        assertEq(feeCalculator.getCategoryFee(2), 20);
        uint8[] memory categoriesToRemove = new uint8[](1);
        categoriesToRemove[0] = 1;

        vm.expectEmit();
        emit CategoryFeeRemoved(1);
        vm.prank(governance);
        feeCalculator.removeCategoriesFees(categoriesToRemove);

        assertEq(feeCalculator.getCategoryFee(2), 20);
        vm.expectRevert("category fee not set; default fee will be used");
        feeCalculator.getCategoryFee(1);
    }

    // function testCalculateFee1() public {
    //     // no default fees set (i.e. all are 0), no overrides set
    //     uint256[] memory indices = new uint256[](8);
    //     for (uint256 i = 0; i < 8; i++) {
    //         indices[i] = i;
    //     }
    //     assertEq(feeCalculator.calculateFee(indices), 0);
    // }

    // function testCalculateFee2() public {
    //     // set default fee for group 1 to 10 and for group 2 to 20
    //     uint8[] memory categories = new uint8[](2);
    //     categories[0] = 1;
    //     categories[1] = 2;
    //     uint256[] memory fees = new uint256[](2);
    //     fees[0] = 10;
    //     fees[1] = 20;
    //     vm.prank(governance);
    //     feeCalculator.setCategoriesDefaultFees(categories, fees);

    //     // no overrides set
    //     uint256[] memory indices = new uint256[](8);
    //     for (uint256 i = 0; i < 8; i++) {
    //         indices[i] = i;
    //     }
    //     assertEq(feeCalculator.calculateFee(indices), 10 * 2 + 20 * 3 + 0 * 3);
    // }

    // function testCalculateFee3() public {
    //     // set default fee for group 1 to 10 and for group 2 to 20
    //     uint8[] memory categories = new uint8[](2);
    //     categories[0] = 1;
    //     categories[1] = 2;
    //     uint256[] memory fees = new uint256[](2);
    //     fees[0] = 10;
    //     fees[1] = 20;
    //     vm.prank(governance);
    //     feeCalculator.setCategoriesDefaultFees(categories, fees);

    //     // override fee for feed0 and feed2 to 0
    //     uint256[] memory feedFees = new uint256[](2);
    //     feedFees[0] = 0;
    //     feedFees[1] = 0;
    //     bytes21[] memory feedIdsToSet = new bytes21[](2);
    //     feedIdsToSet[0] = feedIds[0];
    //     feedIdsToSet[1] = feedIds[2];
    //     vm.prank(governance);
    //     feeCalculator.setFeedsFees(feedIdsToSet, feedFees);

    //     uint256[] memory indices = new uint256[](8);
    //     for (uint256 i = 0; i < 8; i++) {
    //         indices[i] = i;
    //     }

    //     assertEq(feeCalculator.calculateFee(indices), 10 * 1 + 20 * 2 + 0 * 5);
    // }

    // function testCalculateFee4() public {
    //     // default fee for all groups is 0
    //     uint8[] memory categories = new uint8[](1);
    //     categories[0] = 3;
    //     uint256[] memory fees = new uint256[](1);
    //     fees[0] = 1000;
    //     vm.prank(governance);
    //     feeCalculator.setCategoriesDefaultFees(categories, fees);

    //     // set (override) fee for feeds feed0-feed6
    //     uint256[] memory feedFees = new uint256[](7);
    //     bytes21[] memory feedIdsToSet = new bytes21[](7);
    //     for (uint256 i = 0; i < 7; i++) {
    //         feedFees[i] = (i + 1) * 10;
    //         feedIdsToSet[i] = feedIds[i];

    //     }
    //     vm.prank(governance);
    //     feeCalculator.setFeedsFees(feedIdsToSet, feedFees);

    //     uint256[] memory indices = new uint256[](8);
    //     for (uint256 i = 0; i < 8; i++) {
    //         indices[i] = i;
    //     }

    //     assertEq(feeCalculator.calculateFee(indices), 10 + 20 + 30 + 40 + 50 + 60 + 70 + 1000);
    // }

    // function testCalculateFee5() public {
    //     // default fee for all groups 1 and 2 is 0, for group 3 1000


    //     // set (override) fee for feeds feed0-feed6
    //     uint256[] memory feedFees = new uint256[](7);
    //     bytes21[] memory feedIdsToSet = new bytes21[](7);
    //     for (uint256 i = 0; i < 7; i++) {
    //         feedFees[i] = (i + 1) * 10;
    //         feedIdsToSet[i] = feedIds[i];

    //     }
    //     vm.prank(governance);
    //     feeCalculator.setFeedsFees(feedIdsToSet, feedFees);

    //     uint256[] memory indices = new uint256[](8);
    //     for (uint256 i = 0; i < 8; i++) {
    //         indices[i] = i;
    //     }

    //     assertEq(feeCalculator.calculateFee(indices), 10 + 20 + 30 + 40 + 50 + 60 + 70 + 0);
    // }

    ////
    function _getFeedId(uint8 _category, string memory _name) internal pure returns(bytes21) {
        bytes memory nameBytes = bytes(_name);
        require(nameBytes.length <= 20, "name too long");
        return bytes21(bytes.concat(bytes1(_category), nameBytes));
    }

    function _setFeedIds() internal {
        feedIds = new bytes21[](8);
        for (uint256 i = 0; i < 8; i++) {
            if (i < 2) {
                feedIds[i] = _getFeedId(uint8(1), string.concat("feed", vm.toString(i)));
            } else if (i < 5) {
                feedIds[i] = _getFeedId(uint8(2), string.concat("feed", vm.toString(i)));
            } else {
                feedIds[i] = _getFeedId(uint8(3), string.concat("feed", vm.toString(i)));
            }
            vm.mockCall(
                mockFastUpdatesConfiguration,
                abi.encodeWithSelector(IFastUpdatesConfiguration.getFeedId.selector, i),
                abi.encode(feedIds[i])
            );
        }
    }

}