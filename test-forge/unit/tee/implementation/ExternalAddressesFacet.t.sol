// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { FlareTeeManagerDeployer } from "../../../utils/FlareTeeManagerDeployer.sol";
import { IIFlareTeeManager } from "../../../../contracts/tee/interface/IIFlareTeeManager.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

contract ExternalAddressesFacetTest is Test {

    IIFlareTeeManager private flareTeeManager;
    address private initialGovernance;
    address private addressUpdater;
    IGovernanceSettings private governanceSettings;

    function setUp() public {
        initialGovernance = makeAddr("initialGovernance");
        addressUpdater = makeAddr("AddressUpdater");
        governanceSettings = IGovernanceSettings(makeAddr("governanceSettings"));

        flareTeeManager = FlareTeeManagerDeployer.deployFacets(FlareTeeManagerDeployer.DeployParams({
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
    }

    function testUpdateContractAddressesRevertOnlyAddressUpdater() public {
        address nonUpdater = makeAddr("nonUpdater");

        bytes32[] memory nameHashes = new bytes32[](6);
        nameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        nameHashes[1] = keccak256(abi.encode("FlareSystemsManager"));
        nameHashes[2] = keccak256(abi.encode("RewardManager"));
        nameHashes[3] = keccak256(abi.encode("Relay"));
        nameHashes[4] = keccak256(abi.encode("Fdc2Hub"));
        nameHashes[5] = keccak256(abi.encode("Fdc2Verification"));

        address[] memory addresses = new address[](6);
        addresses[0] = addressUpdater;
        addresses[1] = makeAddr("FlareSystemsManager");
        addresses[2] = makeAddr("RewardManager");
        addresses[3] = makeAddr("Relay");
        addresses[4] = makeAddr("Fdc2Hub");
        addresses[5] = makeAddr("Fdc2Verification");

        vm.prank(nonUpdater);
        vm.expectRevert("only address updater");
        flareTeeManager.updateContractAddresses(nameHashes, addresses);
    }

    function testUpdateContractAddresses() public {
        address newAddressUpdater = makeAddr("NewAddressUpdater");
        address flareSystemsManager = makeAddr("FlareSystemsManager");
        address rewardManager = makeAddr("RewardManager");
        address relay = makeAddr("Relay");
        address fdc2Hub = makeAddr("Fdc2Hub");
        address fdc2Verification = makeAddr("Fdc2Verification");

        bytes32[] memory nameHashes = new bytes32[](6);
        nameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        nameHashes[1] = keccak256(abi.encode("FlareSystemsManager"));
        nameHashes[2] = keccak256(abi.encode("RewardManager"));
        nameHashes[3] = keccak256(abi.encode("Relay"));
        nameHashes[4] = keccak256(abi.encode("Fdc2Hub"));
        nameHashes[5] = keccak256(abi.encode("Fdc2Verification"));

        address[] memory addresses = new address[](6);
        addresses[0] = newAddressUpdater;
        addresses[1] = flareSystemsManager;
        addresses[2] = rewardManager;
        addresses[3] = relay;
        addresses[4] = fdc2Hub;
        addresses[5] = fdc2Verification;

        vm.prank(addressUpdater);
        flareTeeManager.updateContractAddresses(nameHashes, addresses);

        // After update, the address updater should be the new one
        (bool ok1, bytes memory data1) = address(flareTeeManager).staticcall(
            abi.encodeWithSignature("getAddressUpdater()")
        );
        assertTrue(ok1);
        assertEq(abi.decode(data1, (address)), newAddressUpdater);
    }

    function testGetAddressUpdater() public view {
        (bool ok, bytes memory data) = address(flareTeeManager).staticcall(
            abi.encodeWithSignature("getAddressUpdater()")
        );
        assertTrue(ok);
        assertEq(abi.decode(data, (address)), addressUpdater);
    }
}
