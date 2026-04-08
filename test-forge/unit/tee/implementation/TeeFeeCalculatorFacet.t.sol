// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { FlareTeeManagerDeployer } from "../../../utils/FlareTeeManagerDeployer.sol";
import { IIFlareTeeManager } from "../../../../contracts/tee/interface/IIFlareTeeManager.sol";
import { ITeeFeeCalculatorFacet } from "../../../../contracts/userInterfaces/tee/ITeeFeeCalculatorFacet.sol";
import { ITeeCommonErrors } from "../../../../contracts/userInterfaces/tee/ITeeCommonErrors.sol";
import { IFlareGovernance } from "../../../../contracts/userInterfaces/tee/IFlareGovernance.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

contract TeeFeeCalculatorFacetTest is Test {

    IIFlareTeeManager private flareTeeManager;
    address private initialGovernance;
    address private addressUpdater;
    IGovernanceSettings private governanceSettings;

    uint256 private defaultFee;

    function setUp() public {
        initialGovernance = makeAddr("initialGovernance");
        addressUpdater = makeAddr("AddressUpdater");
        governanceSettings = IGovernanceSettings(makeAddr("governanceSettings"));
        defaultFee = 1000;

        flareTeeManager = FlareTeeManagerDeployer.deployDay1Facets(FlareTeeManagerDeployer.Day1DeployParams({
            governanceSettings: governanceSettings,
            initialGovernance: initialGovernance,
            addressUpdater: addressUpdater,
            availabilityCheckValidityDurationSeconds: 3600,
            signingPolicyValidityDurationInRewardEpochs: 6,
            challengeValidityDurationSeconds: 600,
            defaultFee: defaultFee
        }));
        vm.startPrank(initialGovernance);
        FlareTeeManagerDeployer.deployLaterFacets(flareTeeManager, FlareTeeManagerDeployer.LaterDeployParams({
            pauseBeforeUpgradeMinDurationSeconds: 600
        }));
        vm.stopPrank();
    }


    function testSetOperationFeesRevertOnlyGovernance() public {
        vm.expectRevert(IFlareGovernance.OnlyGovernance.selector);
        flareTeeManager.setOperationFees(
            new bytes32[](0),
            new bytes32[](0),
            new uint256[](0)
        );
    }

    function testSetOperationFeesRevertLengthsMismatch1() public {
        vm.expectRevert(ITeeCommonErrors.LengthsMismatch.selector);
        vm.prank(initialGovernance);
        flareTeeManager.setOperationFees(
            new bytes32[](1),
            new bytes32[](2),
            new uint256[](1)
        );
    }

    function testSetOperationFeesRevertLengthsMismatch2() public {
        vm.expectRevert(ITeeCommonErrors.LengthsMismatch.selector);
        vm.prank(initialGovernance);
        flareTeeManager.setOperationFees(
            new bytes32[](1),
            new bytes32[](1),
            new uint256[](2)
        );
    }

    function testSetOperationFees() public {
        bytes32[] memory opTypes = new bytes32[](2);
        bytes32[] memory opCommands = new bytes32[](2);
        uint256[] memory fees = new uint256[](2);
        opTypes[0] = bytes32("F_XRP");
        opTypes[1] = bytes32("F_BTC");
        opCommands[0] = bytes32("PAY");
        opCommands[1] = bytes32("REISSUE");
        fees[0] = 100;
        fees[1] = 200;

        vm.prank(initialGovernance);
        vm.expectEmit();
        emit ITeeFeeCalculatorFacet.OperationFeesSet(opTypes, opCommands, fees);
        flareTeeManager.setOperationFees(opTypes, opCommands, fees);

        // assert
        assertEq(flareTeeManager.getOperationFee(opTypes[0], opCommands[0]), fees[0]);
        assertEq(flareTeeManager.getOperationFee(opTypes[1], opCommands[1]), fees[1]);
        // no fee set
        assertEq(flareTeeManager.getOperationFee(opTypes[0], opCommands[1]), 0);
    }

    function testSetDefaultFeeRevertOnlyGovernance() public {
        vm.expectRevert(IFlareGovernance.OnlyGovernance.selector);
        flareTeeManager.setDefaultFee(defaultFee);
    }

    function testSetDefaultFee() public {
        vm.prank(initialGovernance);
        vm.expectEmit();
        emit ITeeFeeCalculatorFacet.DefaultFeeSet(defaultFee + 1);
        flareTeeManager.setDefaultFee(defaultFee + 1);
    }

    function testGetDefaultFee() public view {
        assertEq(flareTeeManager.getDefaultFee(), defaultFee);
    }

    function testCalculateFeeByTeeIds() public {
        testSetOperationFees();

        address[] memory teeIds = new address[](2);
        teeIds[0] = makeAddr("teeId1");
        teeIds[1] = makeAddr("teeId2");

        assertEq(flareTeeManager.calculateFeeByTeeIds(bytes32("F_XRP"), bytes32("PAY"), teeIds),
            100 * teeIds.length);
        assertEq(flareTeeManager.calculateFeeByTeeIds(bytes32("F_BTC"), bytes32("REISSUE"), teeIds),
            200 * teeIds.length);
        // no fee set
        assertEq(flareTeeManager.calculateFeeByTeeIds(bytes32("F_BTC"), bytes32("PAY"), teeIds),
            teeIds.length * defaultFee);
    }

}
