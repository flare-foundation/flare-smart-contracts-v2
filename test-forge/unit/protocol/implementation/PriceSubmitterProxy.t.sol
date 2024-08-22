// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../../contracts/protocol/implementation/PriceSubmitterProxy.sol";

contract PriceSubmitterProxyTest is Test {

    PriceSubmitterProxy private priceSubmitterProxy;

    address private addressUpdater;
    address private mockRelay;
    address private voterWhitelister;
    address private ftsoManager;
    address private ftsoRegistry;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    address private voter;

    function setUp() public {
        addressUpdater = makeAddr("addressUpdater");

        priceSubmitterProxy = new PriceSubmitterProxy(addressUpdater);

        mockRelay = makeAddr("mockRelay");
        voterWhitelister = makeAddr("voterWhitelister");
        ftsoManager = makeAddr("ftsoManager");
        ftsoRegistry = makeAddr("ftsoRegistry");

        vm.prank(addressUpdater);
        contractNameHashes = new bytes32[](5);
        contractAddresses = new address[](5);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("Relay"));
        contractNameHashes[2] = keccak256(abi.encode("FtsoManager"));
        contractNameHashes[3] = keccak256(abi.encode("FtsoRegistry"));
        contractNameHashes[4] = keccak256(abi.encode("VoterWhitelister"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = mockRelay;
        contractAddresses[2] = ftsoManager;
        contractAddresses[3] = ftsoRegistry;
        contractAddresses[4] = voterWhitelister;
        priceSubmitterProxy.updateContractAddresses(contractNameHashes, contractAddresses);
    }

    function testSubmitHash() public {
        vm.expectRevert("not supported");
        priceSubmitterProxy.submitHash(0, bytes32(0));
    }

    function testSubmitPriceHashes() public {
        vm.expectRevert("not supported");
        priceSubmitterProxy.submitPriceHashes(0, new uint256[](0), new bytes32[](0));
    }

    function testRevealPrices() public {
        vm.expectRevert("not supported");
        priceSubmitterProxy.revealPrices(0, new uint256[](0), new uint256[](0), 0);
    }

    function testRevealPricesSongbird() public {
        vm.expectRevert("not supported");
        priceSubmitterProxy.revealPrices(0, new uint256[](0), new uint256[](0), new uint256[](0));
    }

    function testGetCurrentRandom() public {
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(IRelay.getRandomNumber.selector),
            abi.encode(123, false, 987)
        );
        assertEq(priceSubmitterProxy.getCurrentRandom(), 123);
    }

    function testGetRandom() public {
        vm.expectRevert("not supported");
        priceSubmitterProxy.getRandom(7);
    }

    function testGetFtsoManager() public {
        assertEq(address(priceSubmitterProxy.getFtsoManager()), ftsoManager);
    }

    function testGetFtsoRegistry() public {
        assertEq(address(priceSubmitterProxy.getFtsoRegistry()), ftsoRegistry);
    }

    function testGetVoterWhitelister() public {
        assertEq(address(priceSubmitterProxy.getVoterWhitelister()), voterWhitelister);
    }

    function testVoterWhitelistBitmap() public {
        vm.expectRevert("not supported");
        priceSubmitterProxy.voterWhitelistBitmap(makeAddr("voter"));
    }

    function testGetCurrentRandomWithQuality() public {
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(IRelay.getRandomNumber.selector),
            abi.encode(123, true, 987)
        );
        (uint256 currentRandom, bool isSecureRandom) = priceSubmitterProxy.getCurrentRandomWithQuality();
        assertEq(currentRandom, 123);
        assertTrue(isSecureRandom);

        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(IRelay.getRandomNumber.selector),
            abi.encode(456, false, 1987)
        );
        (currentRandom, isSecureRandom) = priceSubmitterProxy.getCurrentRandomWithQuality();
        assertEq(currentRandom, 456);
        assertFalse(isSecureRandom);
    }

}