// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { FlareTeeManagerDeployer } from "../../../utils/FlareTeeManagerDeployer.sol";
import { IIFlareTeeManager } from "../../../../contracts/tee/interface/IIFlareTeeManager.sol";
import { IDiamondLoupe } from "../../../../contracts/diamond/interfaces/IDiamondLoupe.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

contract DiamondLoupeFacetTest is Test {

    IIFlareTeeManager private flareTeeManager;
    IDiamondLoupe private loupe;
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
            defaultFee: 1000,
            publicExtensionCreationEnabled: true,
            emergencyUnpauseGracePeriodSeconds: 7200
        }));
        vm.startPrank(initialGovernance);
        FlareTeeManagerDeployer.deployLaterFacets(flareTeeManager, FlareTeeManagerDeployer.LaterDeployParams({
            pauseBeforeUpgradeMinDurationSeconds: 600
        }));
        vm.stopPrank();

        loupe = IDiamondLoupe(address(flareTeeManager));
    }

    function testFacets() public view {
        IDiamondLoupe.Facet[] memory allFacets = loupe.facets();
        assertEq(allFacets.length, 21, "deployer creates 21 facets");
    }

    function testFacetAddresses() public view {
        address[] memory addresses = loupe.facetAddresses();
        assertEq(addresses.length, 21, "should have 21 unique facet addresses");
    }

    function testFacetFunctionSelectors() public view {
        // Find the DiamondLoupeFacet address by looking up one of its known selectors
        address loupeFacetAddr = loupe.facetAddress(IDiamondLoupe.facets.selector);
        assertTrue(loupeFacetAddr != address(0), "loupe facet should exist");

        bytes4[] memory selectors = loupe.facetFunctionSelectors(loupeFacetAddr);
        assertEq(selectors.length, 4, "DiamondLoupeFacet has 4 selectors");
    }

    function testFacetAddress() public view {
        // Verify facetAddress returns a non-zero address for a known selector
        address facetAddr = loupe.facetAddress(IDiamondLoupe.facetAddresses.selector);
        assertTrue(facetAddr != address(0), "known selector should resolve to a facet");

        // Verify the same facet handles all loupe selectors
        address facetAddr2 = loupe.facetAddress(IDiamondLoupe.facets.selector);
        assertEq(facetAddr, facetAddr2, "all loupe selectors should point to same facet");

        // Verify unknown selector returns address(0)
        address unknownAddr = loupe.facetAddress(bytes4(0xdeadbeef));
        assertEq(unknownAddr, address(0), "unknown selector should return address(0)");
    }
}
