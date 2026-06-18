// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { FlareTeeManagerDeployer } from "../../../utils/FlareTeeManagerDeployer.sol";
import { IIFlareTeeManager } from "../../../../contracts/tee/interface/IIFlareTeeManager.sol";
import { IOperationFees } from "../../../../contracts/userInterfaces/tee/IOperationFees.sol";
import { ITeeCommonErrors } from "../../../../contracts/userInterfaces/tee/ITeeCommonErrors.sol";
import { IFlareGovernance } from "../../../../contracts/userInterfaces/IFlareGovernance.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

contract OperationFeesFacetTest is Test {

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

        flareTeeManager = FlareTeeManagerDeployer.deployFacets(FlareTeeManagerDeployer.DeployParams({
            governanceSettings: governanceSettings,
            initialGovernance: initialGovernance,
            addressUpdater: addressUpdater,
            availabilityCheckValidityDurationSeconds: 3600,
            signingPolicyValidityDurationInRewardEpochs: 6,
            challengeValidityDurationSeconds: 600,
            defaultFee: defaultFee,
            publicExtensionCreationEnabled: true,
            emergencyUnpauseGracePeriodSeconds: 7200
        }));
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
        emit IOperationFees.OperationFeesSet(opTypes, opCommands, fees);
        flareTeeManager.setOperationFees(opTypes, opCommands, fees);

        // assert
        assertEq(flareTeeManager.getOperationFee(opTypes[0], opCommands[0]), fees[0]);
        assertEq(flareTeeManager.getOperationFee(opTypes[1], opCommands[1]), fees[1]);
        // no specific fee set - falls back to the default fee
        assertEq(flareTeeManager.getOperationFee(opTypes[0], opCommands[1]), defaultFee);
    }

    function testSetDefaultFeeRevertOnlyGovernance() public {
        vm.expectRevert(IFlareGovernance.OnlyGovernance.selector);
        flareTeeManager.setDefaultFee(defaultFee);
    }

    function testSetDefaultFee() public {
        vm.prank(initialGovernance);
        vm.expectEmit();
        emit IOperationFees.DefaultFeeSet(defaultFee + 1);
        flareTeeManager.setDefaultFee(defaultFee + 1);
    }

    function testSetDefaultFeeRevertDefaultFeeZero() public {
        vm.prank(initialGovernance);
        vm.expectRevert(IOperationFees.DefaultFeeZero.selector);
        flareTeeManager.setDefaultFee(0);
    }

    function testGetDefaultFee() public {
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
