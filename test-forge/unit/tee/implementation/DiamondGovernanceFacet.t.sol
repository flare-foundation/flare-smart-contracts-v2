// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { FlareTeeManagerDeployer } from "../../../utils/FlareTeeManagerDeployer.sol";
import { IIFlareTeeManager } from "../../../../contracts/tee/interface/IIFlareTeeManager.sol";
import { IFlareGovernance } from "../../../../contracts/userInterfaces/IFlareGovernance.sol";
import { IIFlareGovernance } from "../../../../contracts/governance/interface/IIFlareGovernance.sol";
import { IDiamondCut } from "../../../../contracts/diamond/interfaces/IDiamondCut.sol";
import { IDiamond } from "../../../../contracts/diamond/interfaces/IDiamond.sol";
import { IDiamondLoupe } from "../../../../contracts/diamond/interfaces/IDiamondLoupe.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

contract MockFacet {
    function mockFunction() external pure returns (uint256) {
        return 42;
    }
}

contract DiamondGovernanceFacetTest is Test {

    IIFlareTeeManager private flareTeeManager;
    address private initialGovernance;
    address private addressUpdater;
    IGovernanceSettings private governanceSettings;

    function setUp() public {
        initialGovernance = makeAddr("initialGovernance");
        addressUpdater = makeAddr("AddressUpdater");
        governanceSettings = IGovernanceSettings(makeAddr("governanceSettings"));

        flareTeeManager = FlareTeeManagerDeployer.deployDay1Facets(FlareTeeManagerDeployer.Day1DeployParams({
            governanceSettings: governanceSettings,
            initialGovernance: initialGovernance,
            addressUpdater: addressUpdater,
            availabilityCheckValidityDurationSeconds: 3600,
            signingPolicyValidityDurationInRewardEpochs: 6,
            challengeValidityDurationSeconds: 600,
            defaultFee: 1000
        }));
        vm.startPrank(initialGovernance);
        FlareTeeManagerDeployer.deployLaterFacets(flareTeeManager, FlareTeeManagerDeployer.LaterDeployParams({
            pauseBeforeUpgradeMinDurationSeconds: 600
        }));
        vm.stopPrank();
    }

    function testGovernance() public view {
        assertEq(
            IFlareGovernance(address(flareTeeManager)).governance(),
            initialGovernance
        );
    }

    function testGovernanceSettings() public view {
        assertEq(
            address(IFlareGovernance(address(flareTeeManager)).governanceSettings()),
            address(governanceSettings)
        );
    }

    function testProductionMode() public view {
        assertFalse(IFlareGovernance(address(flareTeeManager)).productionMode());
    }

    function testIsExecutor() public {
        address randomAddr = makeAddr("randomAddr");
        vm.mockCall(
            address(governanceSettings),
            abi.encodeWithSelector(IGovernanceSettings.isExecutor.selector, randomAddr),
            abi.encode(false)
        );
        assertFalse(IFlareGovernance(address(flareTeeManager)).isExecutor(randomAddr));
    }

    function testDiamondCutRevertOnlyGovernance() public {
        address nonGovernance = makeAddr("nonGovernance");

        IDiamond.FacetCut[] memory cuts = new IDiamond.FacetCut[](0);

        vm.prank(nonGovernance);
        vm.expectRevert(IFlareGovernance.OnlyGovernance.selector);
        IDiamondCut(address(flareTeeManager)).diamondCut(
            cuts,
            address(0),
            ""
        );
    }

    function testDiamondCutAddFacet() public {
        MockFacet mockFacet = new MockFacet();

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacet.mockFunction.selector;

        IDiamond.FacetCut[] memory cuts = new IDiamond.FacetCut[](1);
        cuts[0] = IDiamond.FacetCut({
            facetAddress: address(mockFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: selectors
        });

        vm.prank(initialGovernance);
        IDiamondCut(address(flareTeeManager)).diamondCut(
            cuts,
            address(0),
            ""
        );

        // Verify the new selector is routed to the mock facet
        address resolvedFacet = IDiamondLoupe(address(flareTeeManager)).facetAddress(
            MockFacet.mockFunction.selector
        );
        assertEq(resolvedFacet, address(mockFacet));
    }

    function testSwitchToProductionModeRevertOnlyGovernance() public {
        address nonGovernance = makeAddr("nonGovernance");

        vm.prank(nonGovernance);
        vm.expectRevert(IFlareGovernance.OnlyGovernance.selector);
        IIFlareGovernance(address(flareTeeManager)).switchToProductionMode();
    }
}
