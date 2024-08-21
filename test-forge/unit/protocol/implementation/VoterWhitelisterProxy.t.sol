// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../../contracts/protocol/implementation/VoterWhitelisterProxy.sol";
import "../interface/IIIPriceSubmitter.sol";

contract VoterWhitelisterProxyTest is Test {

    VoterWhitelisterProxy private voterWhitelisterProxy;

    IIIPriceSubmitter private priceSubmitter;
    address private mockFtsoManager;
    address private mockFtsoRegistry;
    address private addressUpdater;
    address private governance;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    event VoterRemovedFromWhitelist(address voter, uint256 ftsoIndex);

    function setUp() public {
        addressUpdater = makeAddr("addressUpdater");
        governance = makeAddr("governance");

        // price submitter
        deployCodeTo(
            "artifacts-forge/FlareSmartContracts.sol/PriceSubmitter.json",
            abi.encode(),
            0x1000000000000000000000000000000000000003
        );
        priceSubmitter = IIIPriceSubmitter(0x1000000000000000000000000000000000000003);
        priceSubmitter.initialiseFixedAddress();
        address submitterGovernance = address(0xfffEc6C83c8BF5c3F4AE0cCF8c45CE20E4560BD7);
        vm.prank(submitterGovernance);
        priceSubmitter.setAddressUpdater(addressUpdater);

        // voter whitelister proxy
        voterWhitelisterProxy = new VoterWhitelisterProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            priceSubmitter
        );

        mockFtsoManager = makeAddr("mockFtsoManager");
        mockFtsoRegistry = makeAddr("mockFtsoRegistry");

        contractNameHashes = new bytes32[](4);
        contractAddresses = new address[](4);
        contractNameHashes[0] = keccak256(abi.encode("FtsoRegistry"));
        contractNameHashes[1] = keccak256(abi.encode("FtsoManager"));
        contractNameHashes[2] = keccak256(abi.encode("VoterWhitelister"));
        contractNameHashes[3] = keccak256(abi.encode("AddressUpdater"));
        contractAddresses[0] = mockFtsoRegistry;
        contractAddresses[1] = mockFtsoManager;
        contractAddresses[2] = address(voterWhitelisterProxy);
        contractAddresses[3] = addressUpdater;
        vm.prank(addressUpdater);
        priceSubmitter.updateContractAddresses(contractNameHashes, contractAddresses);
    }

    function test() public {
        // whitelist new voters
        address[] memory voters = new address[](100);
        vm.startPrank(address(voterWhitelisterProxy));
        for (uint256 i = 0; i < 100; i++) {
            address voter = makeAddr(string.concat("voter", vm.toString(i + 1)));
            voters[i] = voter;
            priceSubmitter.voterWhitelisted(voter, 0);
            priceSubmitter.voterWhitelisted(voter, 1);
            assertNotEq(priceSubmitter.voterWhitelistBitmap(voter), 0);
        }
        priceSubmitter.voterWhitelisted(voters[99], 2);
        vm.stopPrank();

        vm.startPrank(governance);
        // remove voters from whitelist for ftso with index 0
        for (uint256 i = 0; i < 100; i++) {
            vm.expectEmit();
            emit VoterRemovedFromWhitelist(voters[i], 0);
        }
        voterWhitelisterProxy.votersRemovedFromWhitelist(voters, 0);
        for (uint256 i = 0; i < 100; i++) {
            assertNotEq(priceSubmitter.voterWhitelistBitmap(voters[i]), 0);
        }

        // remove voters from whitelist for ftso with index 1
        voterWhitelisterProxy.votersRemovedFromWhitelist(voters, 1);
        for (uint256 i = 0; i < 99; i++) {
            assertEq(priceSubmitter.voterWhitelistBitmap(voters[i]), 0);
        }
        assertNotEq(priceSubmitter.voterWhitelistBitmap(voters[99]), 0);

        // remove voter100 from whitelist for ftso with index 2
        address[] memory voter100 = new address[](1);
        voter100[0] = voters[99];
        voterWhitelisterProxy.votersRemovedFromWhitelist(voter100, 2);
        assertEq(priceSubmitter.voterWhitelistBitmap(voter100[0]), 0);
    }

}